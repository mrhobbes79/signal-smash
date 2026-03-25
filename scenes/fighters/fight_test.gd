extends Node3D
## Fight test scene — two procedural fighters on a simple platform.
## Tests: movement, jumping, double jump, basic attack with knockback, KO, ring-out.
##
## Controls (Player 1 — Keyboard):
##   WASD       — Move
##   Space      — Jump / Double Jump
##   J          — Attack
##
## Controls (Player 2 — second player on keyboard for testing):
##   Arrow Keys — Move (mapped in this script)
##   RShift     — Jump
##   RCtrl      — Attack

const FighterBaseScript = preload("res://scripts/fighters/fighter_base.gd")
const StateMachineScript = preload("res://scripts/fighters/state_machine.gd")
const FighterStateScript = preload("res://scripts/fighters/fighter_state.gd")
const IdleStateScript = preload("res://scripts/fighters/states/idle_state.gd")
const RunStateScript = preload("res://scripts/fighters/states/run_state.gd")
const JumpStateScript = preload("res://scripts/fighters/states/jump_state.gd")
const FallStateScript = preload("res://scripts/fighters/states/fall_state.gd")
const AttackStateScript = preload("res://scripts/fighters/states/attack_state.gd")
const HitStateScript = preload("res://scripts/fighters/states/hit_state.gd")
const KOStateScript = preload("res://scripts/fighters/states/ko_state.gd")

const SpectatorHUDScript = preload("res://scenes/ui/spectator_hud.gd")

const ATTACK_DAMAGE: float = 8.0
const ATTACK_KNOCKBACK: float = 3.0

var _fighter1: CharacterBody3D
var _fighter2: CharacterBody3D
var _camera: Camera3D
var _hud_label: Label
var _spectator_hud: CanvasLayer
var _spectator_mode: bool = false

func _ready() -> void:
	_build_arena()
	_build_fighters()
	_build_camera()
	_build_hud()
	_build_lighting()
	_build_spectator_hud()
	# Start fight music
	if AudioManager:
		AudioManager.play_music_monterrey()

var _hazard_antenna: Node3D
var _hazard_area: Area3D
const HAZARD_SPEED: float = 40.0  # Degrees per second
const HAZARD_KNOCKBACK: float = 8.0
const HAZARD_DAMAGE: float = 12.0

func _build_arena() -> void:
	# Main platform (with collision)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(16.0, 0.5, 8.0), Color("#EA580C"))

	# Platform edge (visual only)
	var edge := ProceduralMesh.create_platform(16.2, 8.2, 0.1, Color("#9A3412"))
	edge.position.y = -0.55
	add_child(edge)

	# Left elevated platform (with collision)
	_add_solid_platform(Vector3(-5.0, 2.0, 0.0), Vector3(3.5, 0.3, 3.0), Color("#78350F"))

	# Right elevated platform (with collision)
	_add_solid_platform(Vector3(5.0, 2.0, 0.0), Vector3(3.5, 0.3, 3.0), Color("#78350F"))

	# Ground visual (far below for depth, visual only)
	var ground := ProceduralMesh.create_platform(60.0, 60.0, 0.1, Color("#451a03"))
	ground.position.y = -12.0
	add_child(ground)

	# ═══ ARENA DECORATION ═══

	# Tower 1 (left back) — antenna tower with cross bars
	_build_tower(Vector3(-6.0, 0.0, -3.0), 5.5, Color("#6B7280"), Color("#FCD34D"))

	# Tower 2 (right back) — shorter tower
	_build_tower(Vector3(6.0, 0.0, -3.0), 4.0, Color("#6B7280"), Color("#FCD34D"))

	# Cable between towers (visual)
	var cable := ProceduralMesh.create_cylinder(0.02, 12.5, 4, Color.BLACK)
	cable.position = Vector3(0.0, 4.5, -3.0)
	cable.rotation_degrees.z = 90.0
	add_child(cable)

	# Cerro de la Silla backdrop (mountains)
	_build_mountains()

	# Rooftop elements — small equipment boxes
	var equip_box1 := ProceduralMesh.create_box(Vector3(0.6, 0.4, 0.5), Color("#4B5563"))
	equip_box1.position = Vector3(-7.0, 0.2, 1.5)
	add_child(equip_box1)

	var equip_box2 := ProceduralMesh.create_box(Vector3(0.8, 0.3, 0.6), Color("#374151"))
	equip_box2.position = Vector3(7.0, 0.15, 2.0)
	add_child(equip_box2)

	# Small satellite dish (decoration)
	var dish_pole := ProceduralMesh.create_cylinder(0.04, 1.0, 4, Color("#9CA3AF"))
	dish_pole.position = Vector3(-7.0, 0.9, -1.5)
	add_child(dish_pole)
	var dish := ProceduralMesh.create_cone(0.3, 0.2, 6, Color("#E2E8F0"))
	dish.position = Vector3(-7.0, 1.5, -1.5)
	dish.rotation_degrees.x = -45.0
	add_child(dish)

	# ═══ SECTOR ANTENNA HAZARD ═══
	_build_hazard()

func _build_tower(pos: Vector3, height: float, color: Color, accent: Color) -> void:
	# Main pole
	var pole := ProceduralMesh.create_cylinder(0.08, height, 6, color)
	pole.position = pos + Vector3(0, height / 2.0, 0)
	add_child(pole)

	# Cross bars
	for i in range(3):
		var bar := ProceduralMesh.create_cylinder(0.03, 1.0, 4, color)
		bar.position = pos + Vector3(0, height * 0.3 * (i + 1), 0)
		bar.rotation_degrees.z = 90.0
		add_child(bar)

	# Antenna on top
	var ant := ProceduralMesh.create_cone(0.2, 0.5, 6, accent)
	ant.position = pos + Vector3(0, height + 0.25, 0)
	add_child(ant)

	# Blinking light on top (red sphere)
	var light := ProceduralMesh.create_sphere(0.06, 6, Color("#EF4444"))
	light.position = pos + Vector3(0, height + 0.55, 0)
	add_child(light)

func _build_mountains() -> void:
	var mountain_color := Color("#78350F").lightened(0.15)

	# Cerro de la Silla silhouette — distinctive saddle shape
	# Left peak
	var peak1 := ProceduralMesh.create_cone(5.0, 9.0, 4, mountain_color)
	peak1.position = Vector3(-10.0, 0.0, -30.0)
	add_child(peak1)

	# Right peak (slightly taller — the "saddle")
	var peak2 := ProceduralMesh.create_cone(4.5, 11.0, 4, mountain_color.darkened(0.1))
	peak2.position = Vector3(-3.0, 0.0, -33.0)
	add_child(peak2)

	# Saddle connection (lower ridge)
	var ridge := ProceduralMesh.create_cone(3.0, 6.0, 4, mountain_color.darkened(0.05))
	ridge.position = Vector3(-6.5, 0.0, -28.0)
	add_child(ridge)

	# Distant mountains
	var bg1 := ProceduralMesh.create_cone(6.0, 7.0, 4, mountain_color.darkened(0.2))
	bg1.position = Vector3(8.0, 0.0, -35.0)
	add_child(bg1)

	var bg2 := ProceduralMesh.create_cone(4.0, 5.0, 4, mountain_color.darkened(0.25))
	bg2.position = Vector3(15.0, 0.0, -30.0)
	add_child(bg2)

func _build_hazard() -> void:
	# Rotating sector antenna — mounted on a pole in the center-back area
	# When it sweeps past a fighter, it deals damage and knockback

	# Hazard pivot (rotates)
	_hazard_antenna = Node3D.new()
	_hazard_antenna.position = Vector3(0.0, 0.0, -2.0)
	add_child(_hazard_antenna)

	# Base pole
	var pole := ProceduralMesh.create_cylinder(0.12, 2.0, 6, Color("#6B7280"))
	pole.position.y = 1.0
	_hazard_antenna.add_child(pole)

	# Rotating arm (extends outward)
	var arm := ProceduralMesh.create_cylinder(0.04, 3.0, 4, Color("#9CA3AF"))
	arm.position = Vector3(1.5, 2.1, 0.0)
	arm.rotation_degrees.z = 90.0
	_hazard_antenna.add_child(arm)

	# Sector antenna head (the dangerous part — cone shape)
	var sector := ProceduralMesh.create_cone(0.35, 0.8, 6, Color("#FCD34D"))
	sector.position = Vector3(3.0, 2.1, 0.0)
	sector.rotation_degrees.z = 90.0
	_hazard_antenna.add_child(sector)

	# Warning stripes on arm
	var warning := ProceduralMesh.create_box(Vector3(0.5, 0.08, 0.08), Color("#EF4444"))
	warning.position = Vector3(1.5, 2.1, 0.0)
	_hazard_antenna.add_child(warning)

	# Hazard collision area (Area3D on the sector head)
	_hazard_area = Area3D.new()
	_hazard_area.collision_layer = 1 << 7  # Layer 8 = Hazards
	_hazard_area.collision_mask = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)  # Scan player bodies
	_hazard_area.monitoring = true

	var hazard_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 0.8, 0.8)
	hazard_shape.shape = shape
	hazard_shape.position = Vector3(2.5, 2.1, 0.0)
	_hazard_area.add_child(hazard_shape)

	_hazard_antenna.add_child(_hazard_area)

	# Connect hazard to damage
	_hazard_area.body_entered.connect(_on_hazard_hit)

## Creates a platform with both visual mesh and physics collision
func _add_solid_platform(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1  # Layer 1 = World
	body.collision_mask = 0

	# Visual mesh
	var mesh := ProceduralMesh.create_platform(size.x, size.z, size.y, color)
	body.add_child(mesh)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	add_child(body)

func _build_fighters() -> void:
	_fighter1 = _create_fighter(1, Vector3(-3.0, 1.0, 0.0), Color("#2563EB"), Color("#1E40AF"), Color("#FCD34D"), "RICO")
	add_child(_fighter1)

	_fighter2 = _create_fighter(2, Vector3(3.0, 1.0, 0.0), Color("#7C3AED"), Color("#4C1D95"), Color("#06B6D4"), "VERO")
	_fighter2.set("facing_right", false)
	add_child(_fighter2)

	# Assign controllers from InputManager
	_assign_controllers()

func _assign_controllers() -> void:
	if InputManager == null:
		# Fallback: P1 keyboard, P2 manual keyboard
		_fighter2.set("use_manual_input", true)
		var f2_sm = _fighter2.get_node_or_null("StateMachine")
		if f2_sm:
			f2_sm.process_input = false
		return

	var p1_device: int = InputManager.get_device(0)
	var p2_device: int = InputManager.get_device(1)

	# P1: keyboard (-1) or gamepad
	_fighter1.set("device_id", p1_device)

	# P2: if gamepad assigned, use it directly; otherwise manual keyboard
	if p2_device >= 0:
		# P2 has a gamepad — use device-based input
		_fighter2.set("device_id", p2_device)
		_fighter2.set("use_manual_input", false)
		print("[FIGHT] P2 using gamepad: %s" % InputManager.get_controller_name(p2_device))
	else:
		# P2 on keyboard (arrows) — manual input
		_fighter2.set("use_manual_input", true)
		var f2_sm = _fighter2.get_node_or_null("StateMachine")
		if f2_sm:
			f2_sm.process_input = false
		print("[FIGHT] P2 using keyboard (arrows)")

func _create_fighter(id: int, pos: Vector3, primary: Color, secondary: Color, accent: Color, fighter_name: String) -> CharacterBody3D:
	var fighter: CharacterBody3D = CharacterBody3D.new()
	fighter.set_script(FighterBaseScript)
	fighter.player_id = id
	fighter.position = pos

	# Collision shape
	var col_shape := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.2
	col_shape.shape = shape
	col_shape.position.y = 0.6
	fighter.add_child(col_shape)

	# Model (detailed procedural character)
	var model_node := Node3D.new()
	model_node.name = "Model"

	if fighter_name == "RICO":
		_build_rico_model(model_node, primary, secondary, accent)
	else:
		_build_vero_model(model_node, primary, secondary, accent)

	# Name label
	var label := Label3D.new()
	label.text = fighter_name
	label.font_size = 36
	label.position.y = 2.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = accent
	label.outline_size = 4
	label.outline_modulate = Color.BLACK
	model_node.add_child(label)

	fighter.add_child(model_node)

	# Hurtbox (Area3D — layer 7)
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 1 << 6   # Layer 7
	hurtbox.collision_mask = 1 << 5    # Scan layer 6 (hitboxes)
	var hurtbox_shape := CollisionShape3D.new()
	var hshape := CapsuleShape3D.new()
	hshape.radius = 0.4
	hshape.height = 1.4
	hurtbox_shape.shape = hshape
	hurtbox_shape.position.y = 0.7
	hurtbox.add_child(hurtbox_shape)
	fighter.add_child(hurtbox)

	# Hitbox (Area3D — layer 6, initially disabled)
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 1 << 5    # Layer 6
	hitbox.collision_mask = 1 << 6     # Scan layer 7 (hurtboxes)
	hitbox.monitoring = false

	var hitbox_shape := CollisionShape3D.new()
	var hit_s := BoxShape3D.new()
	hit_s.size = Vector3(1.0, 0.6, 0.8)
	hitbox_shape.shape = hit_s
	hitbox_shape.position = Vector3(0.6, 0.8, 0.0)
	hitbox.add_child(hitbox_shape)

	# Hitbox visual (red box, visible when active)
	var hit_visual := ProceduralMesh.create_box(Vector3(1.0, 0.6, 0.8), Color(1, 0, 0, 0.4))
	hit_visual.position = Vector3(0.6, 0.8, 0.0)
	hit_visual.visible = false
	hitbox.add_child(hit_visual)

	# Connect hitbox to damage
	hitbox.area_entered.connect(func(area: Area3D) -> void:
		if area.name == "Hurtbox" and area.get_parent() != fighter:
			var target = area.get_parent()
			if target and target.has_method("take_damage") and not target.is_invincible:
				target.take_damage(ATTACK_DAMAGE, fighter.global_position, ATTACK_KNOCKBACK)
				# Hit SFX
				if AudioManager:
					AudioManager.play_sfx("hit_light")
					if target.signal_percent <= 0.0:
						AudioManager.play_sfx("link_down", 3.0)
				print("[FIGHT] P%d hit P%d! Target signal: %.0f%%" % [
					fighter.player_id, target.player_id, target.signal_percent])
	)
	fighter.add_child(hitbox)

	# State machine
	var sm := Node.new()
	sm.set_script(StateMachineScript)
	sm.name = "StateMachine"

	var idle := Node.new()
	idle.set_script(IdleStateScript)
	idle.name = "Idle"
	sm.add_child(idle)
	sm.initial_state = idle

	var run := Node.new()
	run.set_script(RunStateScript)
	run.name = "Run"
	sm.add_child(run)

	var jump_s := Node.new()
	jump_s.set_script(JumpStateScript)
	jump_s.name = "Jump"
	sm.add_child(jump_s)

	var fall := Node.new()
	fall.set_script(FallStateScript)
	fall.name = "Fall"
	sm.add_child(fall)

	var attack := Node.new()
	attack.set_script(AttackStateScript)
	attack.name = "Attack"
	sm.add_child(attack)

	var hit := Node.new()
	hit.set_script(HitStateScript)
	hit.name = "Hit"
	sm.add_child(hit)

	var ko := Node.new()
	ko.set_script(KOStateScript)
	ko.name = "KO"
	sm.add_child(ko)

	fighter.add_child(sm)

	# Set collision layer per player
	fighter.collision_layer = 1 << id  # Layer 2 or 3
	fighter.collision_mask = 1         # Scan layer 1 (world)

	return fighter

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 5, 14)
	_camera.rotation_degrees.x = -15
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)

func _build_lighting() -> void:
	# World environment
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#FDE68A")
	env.ambient_light_color = Color("#EA580C")
	env.ambient_light_energy = 0.4
	world_env.environment = env
	add_child(world_env)

	# Sun
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -45, 0)
	sun.light_color = Color("#FCD34D")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

func _build_spectator_hud() -> void:
	_spectator_hud = CanvasLayer.new()
	_spectator_hud.set_script(SpectatorHUDScript)
	_spectator_hud.fighter1 = _fighter1
	_spectator_hud.fighter2 = _fighter2
	_spectator_hud.visible = false
	add_child(_spectator_hud)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_hud_label = Label.new()
	_hud_label.position = Vector2(20, 20)
	_hud_label.add_theme_font_size_override("font_size", 18)
	_hud_label.add_theme_color_override("font_color", Color("#06B6D4"))
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_hud_label)

func _process(delta: float) -> void:
	_update_p2_movement()
	_update_hazard(delta)
	_update_hud()
	_update_camera()

func _update_hazard(delta: float) -> void:
	if _hazard_antenna:
		_hazard_antenna.rotation_degrees.y += HAZARD_SPEED * delta

var _hazard_cooldown: Dictionary = {}  # { fighter_id: float } — prevent rapid re-hits

func _on_hazard_hit(body: Node3D) -> void:
	# Check if it's a fighter
	if not body.has_method("take_damage"):
		return

	var pid: int = body.get("player_id") if "player_id" in body else -1
	if pid < 0:
		return

	# Cooldown to prevent hitting same fighter every frame
	var now: float = Time.get_ticks_msec() / 1000.0
	if pid in _hazard_cooldown and now - _hazard_cooldown[pid] < 1.0:
		return
	_hazard_cooldown[pid] = now

	# Apply damage and knockback from hazard position
	body.take_damage(HAZARD_DAMAGE, _hazard_antenna.global_position, HAZARD_KNOCKBACK)

	if AudioManager:
		AudioManager.play_sfx("hit_heavy")

	print("[FIGHT] HAZARD hit P%d! Sector antenna sweep!" % pid)

func _update_p2_movement() -> void:
	if _fighter2 == null:
		return
	var p2_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		p2_dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		p2_dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		p2_dir.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		p2_dir.z += 1.0

	_fighter2.set("input_direction", p2_dir)

	var f2_model = _fighter2.get_node_or_null("Model")
	if p2_dir.x > 0.1:
		_fighter2.set("facing_right", true)
		if f2_model:
			f2_model.rotation_degrees.y = 0.0
	elif p2_dir.x < -0.1:
		_fighter2.set("facing_right", false)
		if f2_model:
			f2_model.rotation_degrees.y = 180.0

func _update_hud() -> void:
	if _hud_label == null:
		return

	var sm1 = _fighter1.get("state_machine")
	var sm2 = _fighter2.get("state_machine")
	var state1: String = sm1.current_state.name if sm1 and sm1.current_state else "?"
	var state2: String = sm2.current_state.name if sm2 and sm2.current_state else "?"

	_hud_label.text = """SIGNAL SMASH — Fight Test (E0.1)

P1 RICO:  Signal %.0f%%  |  Damage %.0f  |  State: %s
P2 VERO:  Signal %.0f%%  |  Damage %.0f  |  State: %s

Controls P1: WASD move | SPACE jump | J attack
Controls P2: Arrows move | Shift jump | Ctrl/L attack
TAB = Toggle NOC Dashboard Spectator | R = Reset""" % [
		_fighter1.signal_percent, _fighter1.damage_accumulated, state1,
		_fighter2.signal_percent, _fighter2.damage_accumulated, state2
	]

func _update_camera() -> void:
	# Simple dynamic camera — track center between fighters
	if _fighter1 == null or _fighter2 == null:
		return
	var center: Vector3 = (_fighter1.global_position + _fighter2.global_position) / 2.0
	var dist: float = _fighter1.global_position.distance_to(_fighter2.global_position)
	var target_z: float = clampf(dist * 0.8 + 8.0, 10.0, 20.0)

	_camera.position = _camera.position.lerp(
		Vector3(center.x, center.y + 4.0, target_z), 0.05)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Reset fighters
		if event.keycode == KEY_R:
			_fighter1.position = Vector3(-3.0, 1.0, 0.0)
			_fighter1.reset_fighter()
			_fighter2.position = Vector3(3.0, 1.0, 0.0)
			_fighter2.reset_fighter()

		# Toggle spectator mode
		if event.keycode == KEY_TAB:
			_spectator_mode = not _spectator_mode
			_spectator_hud.visible = _spectator_mode
			_hud_label.visible = not _spectator_mode

		# Back to menu
		if event.keycode == KEY_ESCAPE:
			if AudioManager:
				AudioManager.stop_music()
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

	# Player 2 controls (arrow keys + shift/ctrl)
	if event is InputEventKey:
		_handle_p2_input(event)

func _handle_p2_input(event: InputEventKey) -> void:
	if _fighter2 == null:
		return

	var f2_sm = _fighter2.get_node_or_null("StateMachine")
	if f2_sm == null:
		return

	# P2 jump (Right Shift)
	if event.pressed and event.keycode == KEY_SHIFT:
		if _fighter2.is_on_floor():
			f2_sm._on_state_transition("jump")
		elif _fighter2.get("can_double_jump"):
			_fighter2.set("can_double_jump", false)
			_fighter2.velocity.y = _fighter2.DOUBLE_JUMP_FORCE
			f2_sm._on_state_transition("jump")

	# P2 attack (Right Ctrl or L key for easier testing)
	if event.pressed and (event.keycode == KEY_CTRL or event.keycode == KEY_L):
		f2_sm._on_state_transition("attack")

## ═══════════ CHARACTER MODELS ═══════════

func _build_rico_model(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## Rico — Cable Specialist. Blue/yellow. Hard hat, cable whip on belt, tool pouch.

	# Boots (dark brown, chunky)
	var boot_l := ProceduralMesh.create_box(Vector3(0.14, 0.15, 0.2), Color("#3B2507"))
	boot_l.position = Vector3(-0.15, 0.08, 0.02)
	model.add_child(boot_l)
	var boot_r := ProceduralMesh.create_box(Vector3(0.14, 0.15, 0.2), Color("#3B2507"))
	boot_r.position = Vector3(0.15, 0.08, 0.02)
	model.add_child(boot_r)

	# Legs (work pants — secondary color)
	var leg_l := ProceduralMesh.create_cylinder(0.09, 0.45, 6, secondary)
	leg_l.position = Vector3(-0.15, 0.38, 0.0)
	model.add_child(leg_l)
	var leg_r := ProceduralMesh.create_cylinder(0.09, 0.45, 6, secondary)
	leg_r.position = Vector3(0.15, 0.38, 0.0)
	model.add_child(leg_r)

	# Belt
	var belt := ProceduralMesh.create_cylinder(0.32, 0.06, 8, Color("#1C1917"))
	belt.position.y = 0.6
	model.add_child(belt)

	# Belt buckle (accent)
	var buckle := ProceduralMesh.create_box(Vector3(0.08, 0.06, 0.05), accent)
	buckle.position = Vector3(0.0, 0.6, 0.3)
	model.add_child(buckle)

	# Tool pouch on belt (right side)
	var pouch := ProceduralMesh.create_box(Vector3(0.1, 0.12, 0.08), Color("#78350F"))
	pouch.position = Vector3(0.32, 0.58, 0.0)
	model.add_child(pouch)

	# Torso (work shirt — primary blue)
	var torso := ProceduralMesh.create_box(Vector3(0.5, 0.45, 0.3), primary)
	torso.position.y = 0.88
	model.add_child(torso)

	# Shirt collar (lighter blue)
	var collar := ProceduralMesh.create_box(Vector3(0.3, 0.06, 0.22), primary.lightened(0.2))
	collar.position.y = 1.13
	model.add_child(collar)

	# Arms (sleeves — primary color)
	var arm_l := ProceduralMesh.create_cylinder(0.08, 0.45, 6, primary)
	arm_l.position = Vector3(-0.34, 0.75, 0.0)
	arm_l.rotation_degrees.z = 12.0
	model.add_child(arm_l)
	var arm_r := ProceduralMesh.create_cylinder(0.08, 0.45, 6, primary)
	arm_r.position = Vector3(0.34, 0.75, 0.0)
	arm_r.rotation_degrees.z = -12.0
	model.add_child(arm_r)

	# Gloves (accent yellow)
	var glove_l := ProceduralMesh.create_sphere(0.09, 6, accent)
	glove_l.position = Vector3(-0.38, 0.52, 0.0)
	model.add_child(glove_l)
	var glove_r := ProceduralMesh.create_sphere(0.09, 6, accent)
	glove_r.position = Vector3(0.38, 0.52, 0.0)
	model.add_child(glove_r)

	# Neck
	var neck := ProceduralMesh.create_cylinder(0.08, 0.1, 6, Color("#D4A574"))
	neck.position.y = 1.18
	model.add_child(neck)

	# Head
	var head := ProceduralMesh.create_sphere(0.22, 8, Color("#D4A574"))
	head.position.y = 1.38
	model.add_child(head)

	# Eyes
	var eye_l := ProceduralMesh.create_sphere(0.045, 6, Color.WHITE)
	eye_l.position = Vector3(-0.09, 1.42, 0.18)
	model.add_child(eye_l)
	var pupil_l := ProceduralMesh.create_sphere(0.025, 6, Color.BLACK)
	pupil_l.position = Vector3(-0.09, 1.42, 0.22)
	model.add_child(pupil_l)
	var eye_r := ProceduralMesh.create_sphere(0.045, 6, Color.WHITE)
	eye_r.position = Vector3(0.09, 1.42, 0.18)
	model.add_child(eye_r)
	var pupil_r := ProceduralMesh.create_sphere(0.025, 6, Color.BLACK)
	pupil_r.position = Vector3(0.09, 1.42, 0.22)
	model.add_child(pupil_r)

	# Mouth (small dark line)
	var mouth := ProceduralMesh.create_box(Vector3(0.1, 0.02, 0.02), Color("#7C3030"))
	mouth.position = Vector3(0.0, 1.32, 0.2)
	model.add_child(mouth)

	# Hard hat (safety helmet — accent yellow)
	var hat_brim := ProceduralMesh.create_cylinder(0.28, 0.04, 8, accent)
	hat_brim.position.y = 1.52
	model.add_child(hat_brim)
	var hat_dome := ProceduralMesh.create_sphere(0.22, 8, accent)
	hat_dome.position.y = 1.58
	model.add_child(hat_dome)

	# Cable whip on back (coiled fiber — accent)
	var cable_coil := ProceduralMesh.create_cylinder(0.12, 0.2, 8, accent)
	cable_coil.position = Vector3(0.0, 0.9, -0.25)
	cable_coil.rotation_degrees.x = 15.0
	model.add_child(cable_coil)

	# Cable hanging end
	var cable_end := ProceduralMesh.create_cylinder(0.015, 0.35, 4, accent)
	cable_end.position = Vector3(0.1, 0.7, -0.28)
	cable_end.rotation_degrees.z = -30.0
	model.add_child(cable_end)

	# Company badge on chest
	var badge := ProceduralMesh.create_box(Vector3(0.1, 0.08, 0.02), Color.WHITE)
	badge.position = Vector3(-0.12, 1.0, 0.17)
	model.add_child(badge)

func _build_vero_model(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## Ing. Vero — Spectrum Engineer. Purple/cyan. Visor, spectrum scanner, lab coat style.

	# Boots (professional — dark purple)
	var boot_l := ProceduralMesh.create_box(Vector3(0.12, 0.13, 0.18), secondary)
	boot_l.position = Vector3(-0.13, 0.07, 0.02)
	model.add_child(boot_l)
	var boot_r := ProceduralMesh.create_box(Vector3(0.12, 0.13, 0.18), secondary)
	boot_r.position = Vector3(0.13, 0.07, 0.02)
	model.add_child(boot_r)

	# Legs (dark pants)
	var leg_l := ProceduralMesh.create_cylinder(0.08, 0.42, 6, secondary)
	leg_l.position = Vector3(-0.13, 0.35, 0.0)
	model.add_child(leg_l)
	var leg_r := ProceduralMesh.create_cylinder(0.08, 0.42, 6, secondary)
	leg_r.position = Vector3(0.13, 0.35, 0.0)
	model.add_child(leg_r)

	# Belt (thin, tech-style)
	var belt := ProceduralMesh.create_cylinder(0.28, 0.04, 8, accent)
	belt.position.y = 0.58
	model.add_child(belt)

	# Torso (lab coat / tech jacket — primary purple)
	var torso := ProceduralMesh.create_box(Vector3(0.46, 0.48, 0.28), primary)
	torso.position.y = 0.85
	model.add_child(torso)

	# Lab coat flaps (slightly lighter, extend below torso)
	var flap_l := ProceduralMesh.create_box(Vector3(0.15, 0.15, 0.12), primary.lightened(0.1))
	flap_l.position = Vector3(-0.15, 0.58, 0.1)
	model.add_child(flap_l)
	var flap_r := ProceduralMesh.create_box(Vector3(0.15, 0.15, 0.12), primary.lightened(0.1))
	flap_r.position = Vector3(0.15, 0.58, 0.1)
	model.add_child(flap_r)

	# Spectrum scanner on chest (glowing cyan device)
	var scanner := ProceduralMesh.create_box(Vector3(0.15, 0.1, 0.05), accent)
	scanner.position = Vector3(0.1, 0.95, 0.17)
	model.add_child(scanner)
	# Scanner screen (darker center)
	var screen := ProceduralMesh.create_box(Vector3(0.1, 0.06, 0.01), Color("#0F172A"))
	screen.position = Vector3(0.1, 0.95, 0.2)
	model.add_child(screen)

	# Arms (jacket sleeves)
	var arm_l := ProceduralMesh.create_cylinder(0.07, 0.42, 6, primary)
	arm_l.position = Vector3(-0.3, 0.72, 0.0)
	arm_l.rotation_degrees.z = 10.0
	model.add_child(arm_l)
	var arm_r := ProceduralMesh.create_cylinder(0.07, 0.42, 6, primary)
	arm_r.position = Vector3(0.3, 0.72, 0.0)
	arm_r.rotation_degrees.z = -10.0
	model.add_child(arm_r)

	# Hands (tech gloves — accent cyan)
	var hand_l := ProceduralMesh.create_sphere(0.07, 6, accent)
	hand_l.position = Vector3(-0.33, 0.5, 0.0)
	model.add_child(hand_l)
	var hand_r := ProceduralMesh.create_sphere(0.07, 6, accent)
	hand_r.position = Vector3(0.33, 0.5, 0.0)
	model.add_child(hand_r)

	# Handheld scanner in right hand
	var handheld := ProceduralMesh.create_box(Vector3(0.05, 0.15, 0.03), Color("#1E293B"))
	handheld.position = Vector3(0.35, 0.45, 0.05)
	model.add_child(handheld)
	var handheld_screen := ProceduralMesh.create_box(Vector3(0.04, 0.06, 0.01), accent)
	handheld_screen.position = Vector3(0.35, 0.5, 0.07)
	model.add_child(handheld_screen)

	# Neck
	var neck := ProceduralMesh.create_cylinder(0.07, 0.08, 6, Color("#C4956A"))
	neck.position.y = 1.13
	model.add_child(neck)

	# Head
	var head := ProceduralMesh.create_sphere(0.21, 8, Color("#C4956A"))
	head.position.y = 1.32
	model.add_child(head)

	# Hair (dark, tied back — shorter on sides)
	var hair := ProceduralMesh.create_sphere(0.22, 8, Color("#1C1917"))
	hair.position = Vector3(0.0, 1.38, -0.03)
	model.add_child(hair)
	# Ponytail
	var ponytail := ProceduralMesh.create_cylinder(0.04, 0.2, 4, Color("#1C1917"))
	ponytail.position = Vector3(0.0, 1.28, -0.2)
	ponytail.rotation_degrees.x = 30.0
	model.add_child(ponytail)

	# Eyes
	var eye_l := ProceduralMesh.create_sphere(0.04, 6, Color.WHITE)
	eye_l.position = Vector3(-0.08, 1.36, 0.17)
	model.add_child(eye_l)
	var pupil_l := ProceduralMesh.create_sphere(0.022, 6, Color.BLACK)
	pupil_l.position = Vector3(-0.08, 1.36, 0.21)
	model.add_child(pupil_l)
	var eye_r := ProceduralMesh.create_sphere(0.04, 6, Color.WHITE)
	eye_r.position = Vector3(0.08, 1.36, 0.17)
	model.add_child(eye_r)
	var pupil_r := ProceduralMesh.create_sphere(0.022, 6, Color.BLACK)
	pupil_r.position = Vector3(0.08, 1.36, 0.21)
	model.add_child(pupil_r)

	# Spectrum visor (cyan translucent band across eyes)
	var visor := ProceduralMesh.create_box(Vector3(0.3, 0.06, 0.05), Color(accent, 0.7))
	visor.position = Vector3(0.0, 1.37, 0.18)
	model.add_child(visor)

	# Antenna array on back (spectrum analysis equipment)
	var backpack := ProceduralMesh.create_box(Vector3(0.2, 0.25, 0.12), Color("#1E293B"))
	backpack.position = Vector3(0.0, 0.9, -0.22)
	model.add_child(backpack)
	# Small antennas on backpack
	var ant1 := ProceduralMesh.create_cylinder(0.015, 0.25, 4, accent)
	ant1.position = Vector3(-0.06, 1.15, -0.22)
	model.add_child(ant1)
	var ant2 := ProceduralMesh.create_cylinder(0.015, 0.2, 4, accent)
	ant2.position = Vector3(0.06, 1.12, -0.22)
	model.add_child(ant2)

	# ID badge
	var badge := ProceduralMesh.create_box(Vector3(0.08, 0.1, 0.02), Color.WHITE)
	badge.position = Vector3(-0.15, 0.98, 0.16)
	model.add_child(badge)
	var badge_text := ProceduralMesh.create_box(Vector3(0.06, 0.03, 0.01), primary)
	badge_text.position = Vector3(-0.15, 0.96, 0.18)
	model.add_child(badge_text)
