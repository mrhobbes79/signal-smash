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

const ATTACK_DAMAGE: float = 8.0
const ATTACK_KNOCKBACK: float = 3.0

var _fighter1: CharacterBody3D
var _fighter2: CharacterBody3D
var _camera: Camera3D
var _hud_label: Label

func _ready() -> void:
	_build_arena()
	_build_fighters()
	_build_camera()
	_build_hud()
	_build_lighting()

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
	_fighter2.set("use_manual_input", true)
	add_child(_fighter2)

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

	# Model (procedural blockout)
	var model_node := Node3D.new()
	model_node.name = "Model"

	var body := ProceduralMesh.create_capsule(0.3, 0.9, primary)
	body.position.y = 0.6
	model_node.add_child(body)

	var head := ProceduralMesh.create_sphere(0.22, 8, Color("#D4A574"))
	head.position.y = 1.35
	model_node.add_child(head)

	var arm_l := ProceduralMesh.create_cylinder(0.08, 0.5, 6, secondary)
	arm_l.position = Vector3(-0.42, 0.65, 0.0)
	model_node.add_child(arm_l)

	var arm_r := ProceduralMesh.create_cylinder(0.08, 0.5, 6, secondary)
	arm_r.position = Vector3(0.42, 0.65, 0.0)
	model_node.add_child(arm_r)

	var leg_l := ProceduralMesh.create_cylinder(0.1, 0.5, 6, secondary)
	leg_l.position = Vector3(-0.15, 0.15, 0.0)
	model_node.add_child(leg_l)

	var leg_r := ProceduralMesh.create_cylinder(0.1, 0.5, 6, secondary)
	leg_r.position = Vector3(0.15, 0.15, 0.0)
	model_node.add_child(leg_r)

	# Name label
	var label := Label3D.new()
	label.text = fighter_name
	label.font_size = 40
	label.position.y = 1.8
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

func _process(_delta: float) -> void:
	_update_p2_movement()
	_update_hud()
	_update_camera()

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
Controls P2: Arrows move | RShift jump | RCtrl attack
R = Reset fighters""" % [
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
	# Reset fighters
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_fighter1.position = Vector3(-3.0, 1.0, 0.0)
		_fighter1.reset_fighter()
		_fighter2.position = Vector3(3.0, 1.0, 0.0)
		_fighter2.reset_fighter()

	# Player 2 controls (arrow keys + right shift/ctrl)
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
