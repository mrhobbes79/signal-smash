extends Node3D
## Antenna Align-Off Mini-Game
## Two players race to align dish antennas to a target signal.
## Use stick/keys to adjust azimuth (horizontal) and elevation (vertical).
## Signal meter shows dBm reading. Closest to target wins.
##
## Teaches: RF alignment, dBm readings, azimuth/elevation

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const TARGET_AZIMUTH: float = 0.0    # Degrees — randomized on start
const TARGET_ELEVATION: float = 0.0  # Degrees — randomized on start
const ALIGN_SPEED: float = 45.0      # Degrees per second
const PERFECT_DBM: float = -40.0     # Best possible signal
const WORST_DBM: float = -90.0       # No signal
const LOCK_THRESHOLD: float = 3.0    # Degrees — within this = "locked"
const SCORE_PER_SECOND_LOCKED: float = 50.0  # Points while locked on target
const BEEP_INTERVAL_MIN: float = 0.05  # Fastest beep when aligned
const BEEP_INTERVAL_MAX: float = 0.8   # Slowest beep when far

var _base: Node3D  # MiniGameBase instance

# Per-player state
var _player_azimuth: Dictionary = {}    # { pid: float }
var _player_elevation: Dictionary = {}  # { pid: float }
var _player_dishes: Dictionary = {}     # { pid: Node3D }
var _player_meters: Dictionary = {}     # { pid: Label3D }
var _player_locked: Dictionary = {}     # { pid: bool }
var _player_beep_timer: Dictionary = {} # { pid: float }

var _target_az: float = 0.0
var _target_el: float = 0.0

# Visual
var _target_marker: MeshInstance3D

func _ready() -> void:
	# Create MiniGameBase as child
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Antenna Align-Off"
	_base.concept_taught = "RF alignment, dBm readings, azimuth/elevation"
	_base.duration_seconds = 30.0
	_base.buff_stat = "range"
	_base.buff_value = 15
	add_child(_base)

	# Mini-game handles its own _process loop
	# MiniGameBase handles timer and score display

func start(player_ids: Array[int]) -> void:
	_base.start(player_ids)
	_start_game()

func _start_game() -> void:
	# Randomize target
	_target_az = randf_range(-60.0, 60.0)
	_target_el = randf_range(-30.0, 30.0)

	# Build scene
	_build_environment()

	for pid in _base.player_ids:
		_player_azimuth[pid] = randf_range(-80.0, 80.0)
		_player_elevation[pid] = randf_range(-40.0, 40.0)
		_player_locked[pid] = false
		_player_beep_timer[pid] = 0.0
		_build_player_dish(pid)

func _build_environment() -> void:
	# Ground
	var ground := ProceduralMesh.create_platform(20.0, 20.0, 0.2, Color("#1F2937"))
	ground.position.y = -0.1
	add_child(ground)

	# Target tower in the distance
	var tower := ProceduralMesh.create_cylinder(0.15, 6.0, 6, Color("#6B7280"))
	tower.position = Vector3(0, 3.0, -8.0)
	add_child(tower)

	var tower_antenna := ProceduralMesh.create_cone(0.3, 0.6, 6, Color("#22C55E"))
	tower_antenna.position = Vector3(0, 6.3, -8.0)
	add_child(tower_antenna)

	# Target signal indicator (pulsing green)
	_target_marker = ProceduralMesh.create_sphere(0.2, 8, Color("#22C55E"))
	_target_marker.position = Vector3(0, 6.8, -8.0)
	add_child(_target_marker)

	# Lighting
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0F172A")
	env.ambient_light_color = Color("#06B6D4")
	env.ambient_light_energy = 0.3
	env_node.environment = env
	add_child(env_node)

func _build_player_dish(pid: int) -> void:
	var x_offset: float = -3.5 if pid == 1 else 3.5

	# Dish mount (pole)
	var pole := ProceduralMesh.create_cylinder(0.08, 2.0, 6, Color("#9CA3AF"))
	pole.position = Vector3(x_offset, 1.0, 0.0)
	add_child(pole)

	# Dish (cone = parabolic dish approximation)
	var dish := Node3D.new()
	dish.position = Vector3(x_offset, 2.2, 0.0)

	var dish_mesh := ProceduralMesh.create_cone(0.6, 0.4, 8, Color("#E2E8F0"))
	dish_mesh.rotation_degrees.x = -90.0
	dish.add_child(dish_mesh)

	# Feed horn (small cylinder at focal point)
	var feed := ProceduralMesh.create_cylinder(0.05, 0.3, 6, Color("#F59E0B"))
	feed.position.z = 0.4
	feed.rotation_degrees.x = 90.0
	dish.add_child(feed)

	add_child(dish)
	_player_dishes[pid] = dish

	# Signal meter label
	var meter := Label3D.new()
	meter.font_size = 32
	meter.position = Vector3(x_offset, 3.2, 0.0)
	meter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	meter.outline_size = 4
	meter.outline_modulate = Color.BLACK
	add_child(meter)
	_player_meters[pid] = meter

	# Player label
	var name_label := Label3D.new()
	name_label.text = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]
	name_label.font_size = 28
	name_label.position = Vector3(x_offset, 0.3, 1.5)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = Color("#2563EB") if pid == 1 else Color("#7C3AED")
	name_label.outline_size = 3
	name_label.outline_modulate = Color.BLACK
	add_child(name_label)

	# Instructions
	var instr := Label3D.new()
	if pid == 1:
		instr.text = "A/D = Azimuth\nW/S = Elevation"
	else:
		instr.text = "←/→ = Azimuth\n↑/↓ = Elevation"
	instr.font_size = 18
	instr.position = Vector3(x_offset, 0.0, 1.5)
	instr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instr.modulate = Color("#9CA3AF")
	instr.outline_size = 2
	instr.outline_modulate = Color.BLACK
	add_child(instr)

func _process(delta: float) -> void:
	if not _base.is_running:
		return

	# Read inputs manually (since MiniGameBase._on_player_input override doesn't work with set_script)
	_process_inputs(delta)

	# Update each player's alignment
	for pid in _base.player_ids:
		_update_player(pid, delta)

	# Pulse target marker
	if _target_marker:
		var pulse: float = (sin(Time.get_ticks_msec() * 0.005) + 1.0) / 2.0
		_target_marker.scale = Vector3.ONE * (0.8 + pulse * 0.4)

func _process_inputs(delta: float) -> void:
	# P1 (WASD)
	if 1 in _base.player_ids:
		var p1_h: float = Input.get_axis("move_left", "move_right")
		var p1_v: float = Input.get_axis("move_back", "move_forward")
		_player_azimuth[1] += p1_h * ALIGN_SPEED * delta
		_player_elevation[1] += p1_v * ALIGN_SPEED * delta
		_player_azimuth[1] = clampf(_player_azimuth[1], -90.0, 90.0)
		_player_elevation[1] = clampf(_player_elevation[1], -45.0, 45.0)

	# P2 (Arrows)
	if 2 in _base.player_ids:
		var p2_h: float = 0.0
		var p2_v: float = 0.0
		if Input.is_key_pressed(KEY_LEFT):
			p2_h -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			p2_h += 1.0
		if Input.is_key_pressed(KEY_UP):
			p2_v += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			p2_v -= 1.0
		_player_azimuth[2] += p2_h * ALIGN_SPEED * delta
		_player_elevation[2] += p2_v * ALIGN_SPEED * delta
		_player_azimuth[2] = clampf(_player_azimuth[2], -90.0, 90.0)
		_player_elevation[2] = clampf(_player_elevation[2], -45.0, 45.0)

func _update_player(pid: int, delta: float) -> void:
	# Calculate alignment error
	var az_error: float = absf(_player_azimuth[pid] - _target_az)
	var el_error: float = absf(_player_elevation[pid] - _target_el)
	var total_error: float = az_error + el_error

	# Calculate dBm from error (closer = better signal)
	var max_error: float = 180.0  # Maximum possible error
	var error_ratio: float = clampf(total_error / max_error, 0.0, 1.0)
	var dbm: float = PERFECT_DBM + (WORST_DBM - PERFECT_DBM) * error_ratio

	# Check if locked
	var is_locked: bool = total_error < LOCK_THRESHOLD
	_player_locked[pid] = is_locked

	# Score while locked
	if is_locked:
		_base.add_score(pid, SCORE_PER_SECOND_LOCKED * delta)

	# Update dish rotation
	var dish: Node3D = _player_dishes.get(pid)
	if dish:
		dish.rotation_degrees.y = _player_azimuth[pid]
		dish.rotation_degrees.x = _player_elevation[pid]

	# Update signal meter
	var meter: Label3D = _player_meters.get(pid)
	if meter:
		meter.text = "%.0f dBm" % dbm
		if is_locked:
			meter.modulate = Color("#22C55E")
			meter.text += " LOCKED!"
		elif dbm > -55.0:
			meter.modulate = Color("#F59E0B")
		else:
			meter.modulate = Color("#EF4444")

	# Beep sound simulation (visual flash since no audio yet)
	_player_beep_timer[pid] -= delta
	if _player_beep_timer[pid] <= 0.0:
		var beep_interval: float = lerpf(BEEP_INTERVAL_MIN, BEEP_INTERVAL_MAX, error_ratio)
		_player_beep_timer[pid] = beep_interval
		# Flash the dish color briefly
		if dish and dish.get_child_count() > 0:
			var dish_mesh: MeshInstance3D = dish.get_child(0) as MeshInstance3D
			if dish_mesh and dish_mesh.material_override:
				var mat: StandardMaterial3D = dish_mesh.material_override as StandardMaterial3D
				if is_locked:
					mat.albedo_color = Color("#22C55E")
				elif dbm > -55.0:
					mat.albedo_color = Color("#F59E0B")
				else:
					mat.albedo_color = Color("#E2E8F0")
