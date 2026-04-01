class_name FighterBase
extends CharacterBody3D
## Base fighter class. Handles physics, signal (health), knockback, and provides
## shared functionality for all characters.

## Movement constants
const MOVE_SPEED: float = 8.0
const JUMP_FORCE: float = 12.0
const DOUBLE_JUMP_FORCE: float = 10.0
const GRAVITY: float = 30.0
const FRICTION: float = 0.85
const AIR_FRICTION: float = 0.95
const MAX_FALL_SPEED: float = 25.0

## Combat constants
const KNOCKBACK_BASE: float = 4.0
const KNOCKBACK_GROWTH: float = 0.04
const HITSTUN_BASE: float = 0.2

## Signal (health) — 100% = full health, 0% = KO
var signal_percent: float = 100.0
var damage_accumulated: float = 0.0  ## Smash-style: more damage = more knockback

## State
var player_id: int = 0
var facing_right: bool = true
var can_double_jump: bool = true
var drop_through_timer: float = 0.0
var is_grounded: bool = false
var is_invincible: bool = false
var hitstun_timer: float = 0.0

## Equipment modifiers (applied from loadout)
var equip_speed_mod: float = 0.0     ## Adds to MOVE_SPEED
var equip_power_mod: float = 0.0     ## Multiplier on attack damage (0.0 = no bonus)
var equip_defense_mod: float = 0.0   ## Reduces incoming damage
var equip_range_mod: float = 0.0     ## Scales hitbox size
var equip_specials: Array[String] = []  ## Active special passives from equipment

## Special ability state
var special_cooldown: float = 0.0
var special_active_timer: float = 0.0
var special_shield_active: bool = false

## FULL SIGNAL COMBO meter (0.0 to 100.0)
var combo_meter: float = 0.0
var combo_active: bool = false
var combo_timer: float = 0.0
const COMBO_HIT_CHARGE: float = 12.0   ## Meter gained per hit landed
const COMBO_TAKE_CHARGE: float = 5.0   ## Meter gained when taking damage
const COMBO_MAX: float = 100.0

## Input
var input_direction: Vector3 = Vector3.ZERO
var use_manual_input: bool = false  ## If true, skip read_input() — input set externally
var device_id: int = -1  ## Gamepad device index (-1 = keyboard)

## References
@onready var state_machine: StateMachine = $StateMachine
@onready var model: Node3D = $Model
@onready var hurtbox: Area3D = $Hurtbox

func _ready() -> void:
	# States resolve their fighter reference lazily via tree traversal
	pass

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		velocity.y = max(velocity.y, -MAX_FALL_SPEED)
	else:
		if not is_grounded:
			is_grounded = true
			can_double_jump = true

	if not is_on_floor():
		is_grounded = false

	# Hitstun countdown
	if hitstun_timer > 0.0:
		hitstun_timer -= delta

	# Special cooldown
	if special_cooldown > 0.0:
		special_cooldown -= delta

	# Special active timer
	if special_active_timer > 0.0:
		special_active_timer -= delta
		if special_active_timer <= 0.0:
			_deactivate_special()

	# Drop-through platform logic (Layer 9 = one-way platforms only, Layer 1 = ground stays solid)
	if drop_through_timer > 0.0:
		drop_through_timer -= delta
		set_collision_mask_value(9, false)  # Disable one-way platform collision
	else:
		set_collision_mask_value(9, true)   # Re-enable one-way platform collision

	move_and_slide()

	# Check ring-out (fell below arena)
	if global_position.y < -10.0 and signal_percent > 0.0:
		trigger_ko()
	# Clamp position so KO'd fighter doesn't fall forever
	if signal_percent <= 0.0:
		velocity = Vector3.ZERO
		if global_position.y < -10.0:
			global_position.y = -10.0

## Read movement input for this player's device
func read_input() -> void:
	if use_manual_input:
		return  # Input is set externally

	input_direction = Vector3.ZERO

	if device_id >= 0:
		# Gamepad input — read directly from device
		var lx: float = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var ly: float = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		if absf(lx) > 0.2:
			input_direction.x = lx
		if absf(ly) > 0.2:
			input_direction.z = ly
	else:
		# Keyboard input (P1 default)
		input_direction.x = Input.get_axis("move_left", "move_right")
		input_direction.z = Input.get_axis("move_forward", "move_back")

	# Update facing direction
	if input_direction.x > 0.1:
		facing_right = true
		if model:
			model.rotation_degrees.y = 0.0
	elif input_direction.x < -0.1:
		facing_right = false
		if model:
			model.rotation_degrees.y = 180.0

## Check if a gamepad button was just pressed for this fighter's device
func is_device_button_pressed(button: int) -> bool:
	if device_id >= 0:
		return Input.is_joy_button_pressed(device_id, button)
	return false

## Get effective move speed (base + equipment)
func get_move_speed() -> float:
	return MOVE_SPEED + equip_speed_mod

## Get effective attack damage multiplier
func get_damage_multiplier() -> float:
	return 1.0 + equip_power_mod

## Get effective defense reduction (0.0 to ~0.5)
func get_defense_reduction() -> float:
	return clampf(equip_defense_mod, 0.0, 0.5)

## Get effective hitbox scale
func get_hitbox_scale() -> float:
	return 1.0 + equip_range_mod

## Apply knockback force from a hit
func apply_knockback(direction: Vector3, base_force: float) -> void:
	var knockback_multiplier: float = 1.0 + (damage_accumulated * KNOCKBACK_GROWTH)
	# Defense reduces knockback
	var defense_factor: float = 1.0 - get_defense_reduction()
	var force: float = base_force * knockback_multiplier * KNOCKBACK_BASE * defense_factor
	velocity = direction.normalized() * force
	velocity.y = max(velocity.y, maxf(force * 0.5, 3.0))
	hitstun_timer = HITSTUN_BASE * knockback_multiplier * defense_factor

## Take damage — increases damage_accumulated (Smash-style) and reduces signal
func take_damage(amount: float, attacker_position: Vector3, knockback_force: float) -> void:
	if is_invincible:
		return

	# Shield blocks one hit completely
	if special_shield_active:
		special_shield_active = false
		if AudioManager:
			AudioManager.play_sfx("signal_lock")
		print("[FIGHT] P%d SHIELD blocked the hit!" % player_id)
		return

	# Defense reduces incoming damage
	var actual_damage: float = amount * (1.0 - get_defense_reduction())
	damage_accumulated += actual_damage
	signal_percent = max(0.0, 100.0 - damage_accumulated)

	# Charge combo meter when taking damage (revenge mechanic)
	combo_meter = minf(combo_meter + COMBO_TAKE_CHARGE, COMBO_MAX)

	# Calculate knockback direction (away from attacker)
	var knock_dir: Vector3 = (global_position - attacker_position).normalized()
	if knock_dir.length() < 0.1:
		knock_dir = Vector3(1.0 if facing_right else -1.0, 0.5, 0.0)

	apply_knockback(knock_dir, knockback_force)

	# Transition to hit state
	if state_machine and state_machine.states.has("hit"):
		state_machine._on_state_transition("hit")

	# Check for KO
	if signal_percent <= 0.0:
		trigger_ko()

## KO — LINK DOWN
func trigger_ko() -> void:
	signal_percent = 0.0
	if state_machine and state_machine.states.has("ko"):
		state_machine._on_state_transition("ko")
	# Notify game manager
	print("[FIGHT] LINK DOWN: Player %d" % player_id)

## Reset fighter for new round
func reset_fighter() -> void:
	signal_percent = 100.0
	damage_accumulated = 0.0
	velocity = Vector3.ZERO
	hitstun_timer = 0.0
	is_invincible = false
	can_double_jump = true
	drop_through_timer = 0.0
	special_cooldown = 0.0
	special_active_timer = 0.0
	special_shield_active = false
	combo_meter = 0.0
	combo_active = false
	combo_timer = 0.0
	if state_machine and state_machine.states.has("idle"):
		state_machine._on_state_transition("idle")

## ═══════════ FULL SIGNAL COMBO ═══════════

func can_activate_combo() -> bool:
	return combo_meter >= COMBO_MAX and not combo_active and signal_percent > 0.0

func activate_combo() -> void:
	if not can_activate_combo():
		return
	combo_active = true
	combo_meter = 0.0
	combo_timer = 3.0  # 3 second combo sequence
	is_invincible = true
	print("[FIGHT] P%d FULL SIGNAL COMBO ACTIVATED!" % player_id)

## ═══════════ EQUIPMENT SPECIAL ABILITIES ═══════════

## Activate Q special — uses equipment special, or character default if none equipped
func activate_special() -> void:
	if special_cooldown > 0.0:
		return

	var sp: String
	if not equip_specials.is_empty():
		sp = equip_specials[0]  # Primary special from first equipped item
	else:
		# Default character specials (no equipment needed)
		sp = _get_default_special()

	if sp.is_empty():
		return

	special_cooldown = 5.0  # 5s cooldown for all specials

	match sp:
		"long_range_beam":
			# Extended range attack — temporarily doubles hitbox scale
			equip_range_mod += 0.8
			special_active_timer = 3.0
			print("[FIGHT] P%d SPECIAL: Long Range Beam! +80%% range for 3s" % player_id)
		"massive_mimo":
			# AoE burst — damage all nearby enemies instantly
			_aoe_burst(12.0, 5.0)
			print("[FIGHT] P%d SPECIAL: Massive MIMO AoE burst!" % player_id)
		"stable_link":
			# Shield — blocks next incoming hit completely
			special_shield_active = true
			special_active_timer = 4.0
			print("[FIGHT] P%d SPECIAL: Stable Link shield active for 4s!" % player_id)
		"gps_sync":
			# Speed boost
			equip_speed_mod += 4.0
			special_active_timer = 3.0
			print("[FIGHT] P%d SPECIAL: GPS Sync speed boost for 3s!" % player_id)
		"beam_focus":
			# Power boost — extra damage
			equip_power_mod += 0.5
			special_active_timer = 3.0
			print("[FIGHT] P%d SPECIAL: Beam Focus! +50%% power for 3s!" % player_id)
		"edge_routing":
			# Heal — recover some signal
			var heal: float = minf(20.0, 100.0 - signal_percent)
			damage_accumulated = maxf(0.0, damage_accumulated - heal)
			signal_percent = minf(100.0, signal_percent + heal)
			print("[FIGHT] P%d SPECIAL: Edge Routing! Healed %.0f%% signal" % [player_id, heal])
		"quick_link":
			# Dash forward — quick teleport lunge
			var dash_dir: float = 1.0 if facing_right else -1.0
			velocity.x = dash_dir * 25.0
			equip_speed_mod += 3.0
			special_active_timer = 2.0
			print("[FIGHT] P%d SPECIAL: Quick Link dash!" % player_id)
		"fast_routing":
			# Attack speed burst — reduces attack cooldown (via speed boost + brief invincibility)
			is_invincible = true
			equip_speed_mod += 5.0
			equip_power_mod += 0.3
			special_active_timer = 2.5
			print("[FIGHT] P%d SPECIAL: Fast Routing! Speed + invincible for 2.5s!" % player_id)
		_:
			# Generic boost for unknown specials
			equip_power_mod += 0.3
			special_active_timer = 3.0
			print("[FIGHT] P%d SPECIAL: %s activated!" % [player_id, sp])

	if AudioManager:
		AudioManager.play_sfx("install_complete")

## Deactivate timed special effects
func _deactivate_special() -> void:
	# Reset temporary modifiers to base equipment values
	var base_mods := {"range": 0.0, "speed": 0.0, "power": 0.0}
	# Recalculate from equipment for any player_id
	var equipment: Dictionary = {}
	if player_id == 1:
		equipment = GameMgr.p1_equipment
	elif player_id == 2:
		equipment = GameMgr.p2_equipment
	# P3/P4 have no equipment slots yet — base_mods stay at 0.0
	if not equipment.is_empty():
		var mods := GameMgr.get_equipment_modifiers(equipment)
		base_mods["range"] = mods["range"] / 100.0
		base_mods["speed"] = mods["speed"] / 10.0
		base_mods["power"] = mods["power"] / 50.0
	equip_range_mod = base_mods["range"]
	equip_speed_mod = base_mods["speed"]
	equip_power_mod = base_mods["power"]
	special_shield_active = false
	is_invincible = false

## AoE burst — damages all fighters in range
func _aoe_burst(damage: float, radius: float) -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if node != self and node is CharacterBody3D and node.has_method("take_damage"):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < radius:
				node.take_damage(damage, global_position, 5.0)
	if AudioManager:
		AudioManager.play_sfx("hit_heavy")

## Default special per character (used when no equipment is equipped)
func _get_default_special() -> String:
	# Lookup character name from GameMgr
	var char_data: Dictionary
	match player_id:
		1:
			char_data = GameMgr.get_p1()
		2:
			char_data = GameMgr.get_p2()
		3:
			char_data = GameMgr.get_char_data(2)  # 3rd character slot
		4:
			char_data = GameMgr.get_char_data(3)  # 4th character slot
		_:
			return ""

	var char_name: String = char_data.get("name", "")
	match char_name:
		"RICO":
			return "long_range_beam"  # Cable Whip — fiber lasso reach
		"ING. VERO":
			return "beam_focus"  # Spectrum Scan — focused power
		"DON AURELIO":
			return "stable_link"  # Old School Fix — shield/block
		"MORXEL":
			return "quick_link"  # Signal Ghost — teleport dash
		_:
			return "beam_focus"
