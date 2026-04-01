extends Node3D
## Main art style test scene controller.
## Places characters on the arena and provides interactive controls for evaluation.
##
## Controls:
##   Mouse drag     — Orbit camera around scene
##   Scroll         — Zoom in/out
##   1-4            — Switch character focus (Rico, Vero, Aurelio, MorXel)
##   F1-F8          — Switch city color palette
##   L              — Cycle lighting preset
##   Space          — Trigger attack animation
##   K              — Trigger LINK DOWN alert
##   R              — Reset camera

var _camera_pivot: Node3D
var _camera: Camera3D
var _camera_distance: float = 12.0
var _camera_rotation: Vector2 = Vector2(-25, 30)
var _mouse_dragging: bool = false

var _arena: ArenaBlockout
var _characters: Array[CharacterBlockout] = []
var _current_character: int = 0
var _hud: UIStyleTest
var _lighting: LightingTest
var _instructions_label: Label

const CITY_NAMES := ["Monterrey", "CDMX", "Rio", "Dallas", "Bogota", "Buenos Aires", "Miami", "WISPA"]
const CHAR_NAMES := ["Rico", "Vero", "Aurelio", "MorXel"]

func _ready() -> void:
	_setup_camera()
	_setup_arena()
	_setup_characters()
	_setup_hud()
	_setup_lighting()
	_setup_instructions()

func _setup_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.position = Vector3(0, 2, 0)
	add_child(_camera_pivot)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0, _camera_distance)
	_camera.fov = 50.0
	_camera_pivot.add_child(_camera)

	_update_camera()

func _setup_arena() -> void:
	_arena = ArenaBlockout.new()
	add_child(_arena)

func _setup_characters() -> void:
	# Rico (center-left)
	var rico := CharacterBlockout.new()
	rico.character_name = "Rico"
	rico.position = Vector3(-2.0, 0.0, 0.0)
	add_child(rico)
	_characters.append(rico)

	# Vero (center-right)
	var vero := CharacterBlockout.new()
	vero.character_name = "Vero"
	vero.position = Vector3(2.0, 0.0, 0.0)
	vero.rotation_degrees.y = 180.0
	add_child(vero)
	_characters.append(vero)

	# Aurelio (far left, on platform)
	var aurelio := CharacterBlockout.new()
	aurelio.character_name = "Aurelio"
	aurelio.position = Vector3(-5.5, 1.7, 0.0)
	add_child(aurelio)
	_characters.append(aurelio)

	# MorXel (far right, on platform)
	var morxel := CharacterBlockout.new()
	morxel.character_name = "MorXel"
	morxel.position = Vector3(5.5, 2.7, 0.0)
	add_child(morxel)
	_characters.append(morxel)

func _setup_hud() -> void:
	_hud = UIStyleTest.new()
	add_child(_hud)

func _setup_lighting() -> void:
	_lighting = LightingTest.new()
	add_child(_lighting)
	# Lighting setup will connect after arena builds its sun and environment
	await get_tree().process_frame
	await get_tree().process_frame
	# Find the arena's DirectionalLight3D and WorldEnvironment
	var sun: DirectionalLight3D
	var env: WorldEnvironment
	for child in _arena.get_children():
		if child is DirectionalLight3D:
			sun = child
		elif child is WorldEnvironment:
			env = child
	if sun and env:
		_lighting.setup(sun, env)

func _setup_instructions() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	_instructions_label = Label.new()
	_instructions_label.text = _get_instructions_text()
	_instructions_label.position = Vector2(20, 120)
	_instructions_label.add_theme_color_override("font_color", Color("#06B6D4"))
	_instructions_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_instructions_label.add_theme_constant_override("shadow_offset_x", 1)
	_instructions_label.add_theme_constant_override("shadow_offset_y", 1)
	_instructions_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(_instructions_label)

func _get_instructions_text() -> String:
	return """SIGNAL SMASH — Art Style Test

Controls:
  Mouse Drag  — Orbit camera
  Scroll      — Zoom in/out
  1-4         — Focus character (Rico/Vero/Aurelio/MorXel)
  F1-F8       — City palette (MTY/CDMX/RIO/DAL/BOG/BUE/MIA/WISPA)
  L           — Cycle lighting preset
  Space       — Trigger attack animation
  K           — Trigger LINK DOWN alert
  R           — Reset camera
  ESC         — Back to menu

Current: %s | %s | %s""" % [
		CHAR_NAMES[_current_character],
		_arena.current_city if _arena else "Monterrey",
		_lighting.get_current_name() if _lighting else "Monterrey Sunset"
	]

func _input(event: InputEvent) -> void:
	# Mouse orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(5.0, _camera_distance - 1.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(25.0, _camera_distance + 1.0)
			_update_camera()

	if event is InputEventMouseMotion and _mouse_dragging:
		_camera_rotation.y += event.relative.x * 0.3
		_camera_rotation.x = clampf(_camera_rotation.x - event.relative.y * 0.3, -80, 80)
		_update_camera()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			# Character switching (1-4)
			KEY_1:
				_focus_character(0)
			KEY_2:
				_focus_character(1)
			KEY_3:
				_focus_character(2)
			KEY_4:
				_focus_character(3)
			# City palette switching (F1-F8)
			KEY_F1:
				_switch_city(0)
			KEY_F2:
				_switch_city(1)
			KEY_F3:
				_switch_city(2)
			KEY_F4:
				_switch_city(3)
			KEY_F5:
				_switch_city(4)
			KEY_F6:
				_switch_city(5)
			KEY_F7:
				_switch_city(6)
			KEY_F8:
				_switch_city(7)
			# Attack animation
			KEY_SPACE:
				if _current_character < _characters.size():
					_characters[_current_character].trigger_attack()
			# LINK DOWN alert
			KEY_K:
				_hud.trigger_link_down()
			# Reset camera
			KEY_R:
				_camera_rotation = Vector2(-25, 30)
				_camera_distance = 12.0
				_update_camera()
			# Back to main menu
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _focus_character(index: int) -> void:
	if index < _characters.size():
		_current_character = index
		# Move camera pivot to character
		var tween := create_tween()
		tween.tween_property(_camera_pivot, "position",
			_characters[index].position + Vector3(0, 2, 0), 0.5)
		_update_instructions()

func _switch_city(index: int) -> void:
	if index < CITY_NAMES.size():
		_arena.set_city(CITY_NAMES[index])
		# Re-setup lighting after arena rebuild
		await get_tree().create_timer(0.1).timeout
		var sun: DirectionalLight3D
		var env: WorldEnvironment
		for child in _arena.get_children():
			if child is DirectionalLight3D:
				sun = child
			elif child is WorldEnvironment:
				env = child
		if sun and env:
			_lighting.setup(sun, env)
		_update_instructions()

func _update_camera() -> void:
	_camera_pivot.rotation_degrees = Vector3(_camera_rotation.x, _camera_rotation.y, 0)
	_camera.position.z = _camera_distance

func _update_instructions() -> void:
	if _instructions_label:
		_instructions_label.text = _get_instructions_text()
