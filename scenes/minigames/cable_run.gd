extends Node3D
## Cable Run Mini-Game
## Route a cable from point A to B through a maze avoiding obstacles.
## At the end, select the correct connector type for bonus points.
## Teaches: Cable management, connector types, proper routing

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const GRID_W: int = 10
const GRID_H: int = 8
const MOVE_COOLDOWN: float = 0.12
const OBSTACLE_PENALTY: float = -20.0
const FINISH_BONUS: float = 150.0
const CONNECTOR_BONUS: float = 80.0
const CORRECT_CONNECTOR: int = 0  # Index of correct answer — randomized

var _base: Node3D

# Grid: 0=empty, 1=obstacle, 2=start, 3=end
var _grid: Array = []

# Per player
var _player_pos: Dictionary = {}       # { pid: Vector2i }
var _player_path: Dictionary = {}      # { pid: Array[Vector2i] }
var _player_finished: Dictionary = {}  # { pid: bool }
var _player_move_timer: Dictionary = {}
var _player_selecting: Dictionary = {} # { pid: bool } — choosing connector
var _player_connector_idx: Dictionary = {} # { pid: int }

var _connectors: Array[String] = ["RJ45", "SMA", "N-Type", "F-Type"]
var _correct_connector_idx: int = 0
var _start_pos := Vector2i(0, 4)
var _end_pos := Vector2i(9, 4)

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Cable Run"
	_base.concept_taught = "Cable management, connector types"
	_base.duration_seconds = 30.0
	_base.buff_stat = "stability"
	_base.buff_value = 10
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_generate_grid()
	_correct_connector_idx = randi() % _connectors.size()

	for pid in _base.player_ids:
		_player_pos[pid] = _start_pos
		_player_path[pid] = [_start_pos]
		_player_finished[pid] = false
		_player_move_timer[pid] = 0.0
		_player_selecting[pid] = false
		_player_connector_idx[pid] = 0

	_build_environment()

func _generate_grid() -> void:
	_grid.clear()
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(0)
		_grid.append(row)

	# Set start and end
	_grid[_start_pos.y][_start_pos.x] = 2
	_grid[_end_pos.y][_end_pos.x] = 3

	# Place random obstacles (30% density, avoid start/end and a clear path)
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _grid[y][x] != 0:
				continue
			# Keep row 4 mostly clear (simple path)
			if y == 4 and randf() < 0.85:
				continue
			if randf() < 0.3:
				_grid[y][x] = 1

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0F172A")
	env.ambient_light_color = Color("#06B6D4")
	env.ambient_light_energy = 0.5
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -20, 0)
	sun.light_energy = 0.7
	add_child(sun)

func _process(delta: float) -> void:
	if not _base.is_running:
		return
	_process_inputs(delta)

func _process_inputs(delta: float) -> void:
	for pid in _base.player_ids:
		_player_move_timer[pid] -= delta

	# P1
	if 1 in _base.player_ids and not _player_finished[1]:
		if _player_selecting[1]:
			_process_connector_select(1)
		else:
			_process_movement(1, delta)

	# P2
	if 2 in _base.player_ids and not _player_finished[2]:
		if _player_selecting[2]:
			_process_connector_select_p2(2)
		else:
			_process_movement_p2(2, delta)

func _process_movement(pid: int, _delta: float) -> void:
	if _player_move_timer[pid] > 0:
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x = -1
	elif Input.is_action_pressed("move_right"):
		dir.x = 1
	elif Input.is_action_pressed("move_forward"):
		dir.y = -1
	elif Input.is_action_pressed("move_back"):
		dir.y = 1

	if dir != Vector2i.ZERO:
		_try_move(pid, dir)

func _process_movement_p2(pid: int, _delta: float) -> void:
	if _player_move_timer[pid] > 0:
		return
	var dir := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x = -1
	elif Input.is_key_pressed(KEY_RIGHT):
		dir.x = 1
	elif Input.is_key_pressed(KEY_UP):
		dir.y = -1
	elif Input.is_key_pressed(KEY_DOWN):
		dir.y = 1

	if dir != Vector2i.ZERO:
		_try_move(pid, dir)

func _try_move(pid: int, dir: Vector2i) -> void:
	var new_pos: Vector2i = _player_pos[pid] + dir

	# Bounds check
	if new_pos.x < 0 or new_pos.x >= GRID_W or new_pos.y < 0 or new_pos.y >= GRID_H:
		return

	_player_move_timer[pid] = MOVE_COOLDOWN
	_player_pos[pid] = new_pos
	_player_path[pid].append(new_pos)

	# Check obstacle
	if _grid[new_pos.y][new_pos.x] == 1:
		_base.add_score(pid, OBSTACLE_PENALTY)
		if AudioManager:
			AudioManager.play_sfx("hit_light")
	else:
		if AudioManager:
			AudioManager.play_sfx("align_beep")

	# Check finish
	if new_pos == _end_pos:
		_player_selecting[pid] = true
		_base.add_score(pid, FINISH_BONUS)
		if AudioManager:
			AudioManager.play_sfx("score")

func _process_connector_select(pid: int) -> void:
	if Input.is_action_just_pressed("move_left"):
		_player_connector_idx[pid] = (_player_connector_idx[pid] - 1 + _connectors.size()) % _connectors.size()
		if AudioManager:
			AudioManager.play_sfx("menu_move")
	elif Input.is_action_just_pressed("move_right"):
		_player_connector_idx[pid] = (_player_connector_idx[pid] + 1) % _connectors.size()
		if AudioManager:
			AudioManager.play_sfx("menu_move")
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump"):
		_confirm_connector(pid)

func _process_connector_select_p2(pid: int) -> void:
	if Input.is_key_pressed(KEY_LEFT) and Engine.get_physics_frames() % 15 == 0:
		_player_connector_idx[pid] = (_player_connector_idx[pid] - 1 + _connectors.size()) % _connectors.size()
		if AudioManager:
			AudioManager.play_sfx("menu_move")
	elif Input.is_key_pressed(KEY_RIGHT) and Engine.get_physics_frames() % 15 == 0:
		_player_connector_idx[pid] = (_player_connector_idx[pid] + 1) % _connectors.size()
		if AudioManager:
			AudioManager.play_sfx("menu_move")
	elif Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_L):
		_confirm_connector(pid)

func _confirm_connector(pid: int) -> void:
	_player_finished[pid] = true
	if _player_connector_idx[pid] == _correct_connector_idx:
		_base.add_score(pid, CONNECTOR_BONUS)
		if AudioManager:
			AudioManager.play_sfx("signal_lock")
		print("[MINI] P%d correct connector! +%.0f bonus" % [pid, CONNECTOR_BONUS])
	else:
		if AudioManager:
			AudioManager.play_sfx("ko")
		print("[MINI] P%d wrong connector!" % pid)

# ═══════════ DRAWING ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _CableDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _CableDraw extends Control:
	var game: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Background
		draw_rect(Rect2(0, 0, s.x, s.y), Color("#0F172A"))

		# Title + timer
		draw_string(font, Vector2(s.x / 2.0 - 60, 35), "CABLE RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#06B6D4"))
		var time_left: int = ceili(game._base.time_remaining)
		var tc: Color = Color("#22C55E") if time_left > 10 else Color("#EF4444")
		draw_string(font, Vector2(s.x - 80, 35), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tc)

		# Grid
		var cell_size: float = minf((s.x - 100) / game.GRID_W, (s.y - 200) / game.GRID_H)
		var grid_x: float = (s.x - cell_size * game.GRID_W) / 2.0
		var grid_y: float = 80.0

		for y in range(game.GRID_H):
			for x in range(game.GRID_W):
				var cx: float = grid_x + x * cell_size
				var cy: float = grid_y + y * cell_size
				var cell: int = game._grid[y][x]

				# Cell background
				var bg_color: Color
				match cell:
					0: bg_color = Color("#1E293B")
					1: bg_color = Color("#7F1D1D")  # Obstacle — red/danger
					2: bg_color = Color("#166534")    # Start — green
					3: bg_color = Color("#1E40AF")    # End — blue
				draw_rect(Rect2(cx + 1, cy + 1, cell_size - 2, cell_size - 2), bg_color)

				# Labels
				if cell == 2:
					draw_string(font, Vector2(cx + 5, cy + cell_size / 2.0 + 5), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#22C55E"))
				elif cell == 3:
					draw_string(font, Vector2(cx + 8, cy + cell_size / 2.0 + 5), "END", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#3B82F6"))
				elif cell == 1:
					draw_string(font, Vector2(cx + cell_size / 2.0 - 5, cy + cell_size / 2.0 + 5), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#EF4444", 0.5))

		# Player paths
		for pid in game._base.player_ids:
			var path: Array = game._player_path.get(pid, [])
			var path_color: Color = Color("#2563EB", 0.4) if pid == 1 else Color("#7C3AED", 0.4)
			for cell_pos in path:
				var px: float = grid_x + cell_pos.x * cell_size
				var py: float = grid_y + cell_pos.y * cell_size
				draw_rect(Rect2(px + 3, py + 3, cell_size - 6, cell_size - 6), path_color)

		# Player cursors
		for pid in game._base.player_ids:
			var pos: Vector2i = game._player_pos.get(pid, Vector2i.ZERO)
			var px: float = grid_x + pos.x * cell_size
			var py: float = grid_y + pos.y * cell_size
			var cursor_color: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			draw_rect(Rect2(px + 2, py + 2, cell_size - 4, cell_size - 4), cursor_color, false, 3.0)
			var name_str: String = "P%d" % pid
			draw_string(font, Vector2(px + 5, py + cell_size / 2.0 + 5), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

		# Connector selection (if player reached end)
		var select_y: float = grid_y + game.GRID_H * cell_size + 20
		for pid in game._base.player_ids:
			if game._player_selecting.get(pid, false):
				var sx_offset: float = 40.0 if pid == 1 else s.x / 2.0 + 20
				var pc: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
				draw_string(font, Vector2(sx_offset, select_y), "P%d — Select connector:" % pid, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, pc)

				if not game._player_finished.get(pid, false):
					for ci in range(game._connectors.size()):
						var cx2: float = sx_offset + ci * 90
						var is_sel: bool = game._player_connector_idx.get(pid, 0) == ci
						var box_color: Color = pc if is_sel else Color("#374151")
						draw_rect(Rect2(cx2, select_y + 8, 80, 28), Color(box_color, 0.3))
						if is_sel:
							draw_rect(Rect2(cx2, select_y + 8, 80, 28), pc, false, 2.0)
						draw_string(font, Vector2(cx2 + 8, select_y + 30), game._connectors[ci], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if is_sel else Color("#9CA3AF"))
				else:
					var chose: String = game._connectors[game._player_connector_idx.get(pid, 0)]
					var correct: String = game._connectors[game._correct_connector_idx]
					var was_right: bool = game._player_connector_idx.get(pid, 0) == game._correct_connector_idx
					var result_text: String = "%s — %s!" % [chose, "CORRECT" if was_right else "WRONG (was %s)" % correct]
					var result_color: Color = Color("#22C55E") if was_right else Color("#EF4444")
					draw_string(font, Vector2(sx_offset, select_y + 30), result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, result_color)

		# Scores
		for pid in game._base.player_ids:
			var score: float = game._base.scores.get(pid, 0.0)
			var name_str: String = "RICO" if pid == 1 else "VERO"
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var sx2: float = 40 if pid == 1 else s.x - 200
			draw_string(font, Vector2(sx2, s.y - 20), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Controls
		draw_string(font, Vector2(40, s.y - 5), "P1: WASD move | J select", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 220, s.y - 5), "P2: Arrows move | L select", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
