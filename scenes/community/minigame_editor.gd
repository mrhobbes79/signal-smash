extends Control
## SIGNAL SMASH — Community Mini-Game Editor
## Grid-based editor where players can create custom mini-games.
## Place obstacles, set start/end positions, choose game type, save as JSON.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const GRID_COLOR := Color("#1E293B")
const OBSTACLE_COLOR := Color("#6366F1")
const START_COLOR := Color("#22C55E")
const END_COLOR := Color("#EF4444")
const ITEM_COLOR := Color("#FBBF24")

const GRID_W: int = 16
const GRID_H: int = 12
const CELL_SIZE: float = 40.0

const GAME_TYPES := ["race", "collect", "survive"]
const GAME_TYPE_DESCS := [
	"Reach the end position first!",
	"Gather all items on the grid!",
	"Avoid hazards for the duration!",
]

var _time: float = 0.0
var _draw_node: Control

# Editor state
var _cursor_x: int = 0
var _cursor_y: int = 0
var _grid: Array = []  # 2D array: 0=empty, 1=obstacle, 2=start, 3=end, 4=item
var _game_type_index: int = 0
var _mode: int = 0  # 0=edit, 1=type_select, 2=file_list, 3=playing
var _saved_files: Array[String] = []
var _selected_file_index: int = 0
var _status_msg: String = ""
var _status_timer: float = 0.0
var _minigame_name: String = "CUSTOM_01"

func _ready() -> void:
	# Initialize grid
	_grid.resize(GRID_H)
	for y in range(GRID_H):
		_grid[y] = []
		_grid[y].resize(GRID_W)
		for x in range(GRID_W):
			_grid[y][x] = 0

	# Default start and end positions
	_grid[1][1] = 2  # start
	_grid[GRID_H - 2][GRID_W - 2] = 3  # end

	# Background color
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	# Custom draw layer
	_draw_node = _EditorDraw.new()
	_draw_node.editor = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	_load_file_list()

func _process(delta: float) -> void:
	_time += delta
	if _status_timer > 0.0:
		_status_timer -= delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _mode != 0:
					_mode = 0
					if AudioManager:
						AudioManager.play_sfx("menu_move")
				else:
					get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
			_:
				if _mode == 0:
					_handle_edit_input(event)
				elif _mode == 1:
					_handle_type_select_input(event)
				elif _mode == 2:
					_handle_file_list_input(event)

func _handle_edit_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W:
			_cursor_y = maxi(_cursor_y - 1, 0)
		KEY_DOWN, KEY_S:
			_cursor_y = mini(_cursor_y + 1, GRID_H - 1)
		KEY_LEFT, KEY_A:
			_cursor_x = maxi(_cursor_x - 1, 0)
		KEY_RIGHT, KEY_D:
			_cursor_x = mini(_cursor_x + 1, GRID_W - 1)
		KEY_ENTER, KEY_SPACE:
			_toggle_cell()
		KEY_1:
			_set_cell(2)  # start
		KEY_2:
			_set_cell(3)  # end
		KEY_3:
			_set_cell(4)  # item
		KEY_BACKSPACE, KEY_DELETE:
			_grid[_cursor_y][_cursor_x] = 0
		KEY_T:
			_mode = 1  # type select
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_F5:
			_save_minigame()
		KEY_F6:
			_mode = 2  # file list
			_load_file_list()
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_F7:
			_play_test()
		KEY_C:
			_clear_grid()

func _handle_type_select_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_LEFT, KEY_A:
			_game_type_index = (_game_type_index - 1 + GAME_TYPES.size()) % GAME_TYPES.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_RIGHT, KEY_D:
			_game_type_index = (_game_type_index + 1) % GAME_TYPES.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_ENTER:
			_mode = 0
			if AudioManager:
				AudioManager.play_sfx("menu_select")

func _handle_file_list_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W:
			_selected_file_index = maxi(_selected_file_index - 1, 0)
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_DOWN, KEY_S:
			_selected_file_index = mini(_selected_file_index + 1, _saved_files.size() - 1)
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_ENTER:
			if _saved_files.size() > 0:
				_load_minigame(_saved_files[_selected_file_index])
				_mode = 0
				if AudioManager:
					AudioManager.play_sfx("menu_select")

func _toggle_cell() -> void:
	var current: int = _grid[_cursor_y][_cursor_x]
	if current == 0:
		_grid[_cursor_y][_cursor_x] = 1  # obstacle
	elif current == 1:
		_grid[_cursor_y][_cursor_x] = 0
	else:
		_grid[_cursor_y][_cursor_x] = 0
	if AudioManager:
		AudioManager.play_sfx("equip")

func _set_cell(cell_type: int) -> void:
	# For start/end, clear existing first
	if cell_type == 2 or cell_type == 3:
		for y in range(GRID_H):
			for x in range(GRID_W):
				if _grid[y][x] == cell_type:
					_grid[y][x] = 0
	_grid[_cursor_y][_cursor_x] = cell_type
	if AudioManager:
		AudioManager.play_sfx("equip")

func _clear_grid() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			_grid[y][x] = 0
	_grid[1][1] = 2
	_grid[GRID_H - 2][GRID_W - 2] = 3
	_show_status("Grid cleared")

func _save_minigame() -> void:
	var dir_path := "user://custom_minigames/"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var data := {
		"name": _minigame_name,
		"type": GAME_TYPES[_game_type_index],
		"grid_w": GRID_W,
		"grid_h": GRID_H,
		"grid": [],
	}
	for y in range(GRID_H):
		var row := []
		for x in range(GRID_W):
			row.append(_grid[y][x])
		data["grid"].append(row)

	var file_path := dir_path + _minigame_name + ".json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		_show_status("Saved: %s" % file_path)
		_load_file_list()
	else:
		_show_status("ERROR: Could not save file")

func _load_file_list() -> void:
	_saved_files.clear()
	var dir_path := "user://custom_minigames/"
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				_saved_files.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	_saved_files.sort()

func _load_minigame(file_name: String) -> void:
	var file_path := "user://custom_minigames/" + file_name + ".json"
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_show_status("ERROR: Could not load file")
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		_show_status("ERROR: Invalid JSON")
		return

	var data: Dictionary = json.data
	_minigame_name = data.get("name", "CUSTOM_01")
	var type_str: String = data.get("type", "race")
	_game_type_index = GAME_TYPES.find(type_str)
	if _game_type_index < 0:
		_game_type_index = 0

	var grid_data: Array = data.get("grid", [])
	for y in range(mini(grid_data.size(), GRID_H)):
		var row: Array = grid_data[y]
		for x in range(mini(row.size(), GRID_W)):
			_grid[y][x] = int(row[x])

	_show_status("Loaded: %s" % file_name)

func _play_test() -> void:
	# Simple play test — just show a status for now (framework stub)
	_show_status("PLAY TEST: %s mode — %s" % [GAME_TYPES[_game_type_index], GAME_TYPE_DESCS[_game_type_index]])

func _show_status(msg: String) -> void:
	_status_msg = msg
	_status_timer = 3.0
	print("[EDITOR] %s" % msg)


class _EditorDraw extends Control:
	var editor: Node

	func _draw() -> void:
		if editor == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = editor._time

		# ═══════════ TITLE ═══════════
		var title_y: float = 30.0
		draw_string(font, Vector2(20, title_y), "MINI-GAME EDITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ACCENT)
		draw_string(font, Vector2(320, title_y), "Type: %s" % GAME_TYPES[editor._game_type_index].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, WARN)

		# ═══════════ GRID ═══════════
		var grid_offset_x: float = (s.x - GRID_W * CELL_SIZE) / 2.0
		var grid_offset_y: float = 60.0

		# Grid background
		draw_rect(Rect2(grid_offset_x - 2, grid_offset_y - 2, GRID_W * CELL_SIZE + 4, GRID_H * CELL_SIZE + 4), Color(GRID_COLOR, 0.5))

		# Draw cells
		for y in range(GRID_H):
			for x in range(GRID_W):
				var cell_x: float = grid_offset_x + x * CELL_SIZE
				var cell_y: float = grid_offset_y + y * CELL_SIZE
				var cell_val: int = editor._grid[y][x]

				# Cell background
				draw_rect(Rect2(cell_x, cell_y, CELL_SIZE - 1, CELL_SIZE - 1), Color(GRID_COLOR, 0.3))

				# Cell content
				match cell_val:
					1:  # obstacle
						draw_rect(Rect2(cell_x + 2, cell_y + 2, CELL_SIZE - 5, CELL_SIZE - 5), OBSTACLE_COLOR)
					2:  # start
						draw_rect(Rect2(cell_x + 2, cell_y + 2, CELL_SIZE - 5, CELL_SIZE - 5), START_COLOR)
						draw_string(font, Vector2(cell_x + 10, cell_y + 26), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
					3:  # end
						draw_rect(Rect2(cell_x + 2, cell_y + 2, CELL_SIZE - 5, CELL_SIZE - 5), END_COLOR)
						draw_string(font, Vector2(cell_x + 10, cell_y + 26), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
					4:  # item
						draw_rect(Rect2(cell_x + 6, cell_y + 6, CELL_SIZE - 13, CELL_SIZE - 13), ITEM_COLOR)

		# Cursor
		var cursor_x: float = grid_offset_x + editor._cursor_x * CELL_SIZE
		var cursor_y: float = grid_offset_y + editor._cursor_y * CELL_SIZE
		var cursor_pulse: float = (sin(t * 6.0) + 1.0) / 2.0
		draw_rect(Rect2(cursor_x - 1, cursor_y - 1, CELL_SIZE + 1, CELL_SIZE + 1), Color(Color.WHITE, 0.5 + cursor_pulse * 0.5), false, 2.0)

		# ═══════════ SIDEBAR ═══════════
		var sidebar_x: float = grid_offset_x + GRID_W * CELL_SIZE + 20
		var sidebar_y: float = grid_offset_y

		draw_string(font, Vector2(sidebar_x, sidebar_y + 20), "TOOLS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WARN)
		draw_string(font, Vector2(sidebar_x, sidebar_y + 45), "ENTER = Toggle Wall", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))
		draw_string(font, Vector2(sidebar_x, sidebar_y + 65), "1 = Set Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, START_COLOR)
		draw_string(font, Vector2(sidebar_x, sidebar_y + 85), "2 = Set End", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, END_COLOR)
		draw_string(font, Vector2(sidebar_x, sidebar_y + 105), "3 = Place Item", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ITEM_COLOR)
		draw_string(font, Vector2(sidebar_x, sidebar_y + 125), "DEL = Clear Cell", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))
		draw_string(font, Vector2(sidebar_x, sidebar_y + 145), "C = Clear All", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))

		draw_string(font, Vector2(sidebar_x, sidebar_y + 185), "ACTIONS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WARN)
		draw_string(font, Vector2(sidebar_x, sidebar_y + 210), "T = Game Type", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))
		draw_string(font, Vector2(sidebar_x, sidebar_y + 230), "F5 = Save", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))
		draw_string(font, Vector2(sidebar_x, sidebar_y + 250), "F6 = Load", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))
		draw_string(font, Vector2(sidebar_x, sidebar_y + 270), "F7 = Play Test", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))
		draw_string(font, Vector2(sidebar_x, sidebar_y + 290), "ESC = Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))

		# Cell position
		draw_string(font, Vector2(sidebar_x, sidebar_y + 330), "Pos: [%d, %d]" % [editor._cursor_x, editor._cursor_y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.6))

		# ═══════════ TYPE SELECT OVERLAY ═══════════
		if editor._mode == 1:
			draw_rect(Rect2(0, 0, s.x, s.y), Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(s.x / 2.0 - 120, s.y / 2.0 - 40), "SELECT GAME TYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ACCENT)
			for i in range(GAME_TYPES.size()):
				var ty: float = s.y / 2.0 + i * 40
				var col: Color = WARN if i == editor._game_type_index else Color(TEXT, 0.5)
				var prefix: String = "▶ " if i == editor._game_type_index else "  "
				draw_string(font, Vector2(s.x / 2.0 - 100, ty), "%s%s — %s" % [prefix, GAME_TYPES[i].to_upper(), GAME_TYPE_DESCS[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y / 2.0 + GAME_TYPES.size() * 40 + 20), "A/D Cycle  |  ENTER Confirm  |  ESC Cancel", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.4))

		# ═══════════ FILE LIST OVERLAY ═══════════
		if editor._mode == 2:
			draw_rect(Rect2(0, 0, s.x, s.y), Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(s.x / 2.0 - 120, s.y / 2.0 - 80), "SAVED MINI-GAMES", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ACCENT)
			if editor._saved_files.size() == 0:
				draw_string(font, Vector2(s.x / 2.0 - 100, s.y / 2.0), "(no saved files)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(TEXT, 0.5))
			else:
				for i in range(editor._saved_files.size()):
					var fy: float = s.y / 2.0 - 40 + i * 30
					var col: Color = WARN if i == editor._selected_file_index else Color(TEXT, 0.5)
					var prefix: String = "▶ " if i == editor._selected_file_index else "  "
					draw_string(font, Vector2(s.x / 2.0 - 100, fy), "%s%s" % [prefix, editor._saved_files[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y * 0.8), "↑↓ Select  |  ENTER Load  |  ESC Cancel", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.4))

		# ═══════════ STATUS MESSAGE ═══════════
		if editor._status_timer > 0.0:
			var alpha: float = clampf(editor._status_timer, 0.0, 1.0)
			draw_string(font, Vector2(20, s.y - 20), editor._status_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Color("#22C55E"), alpha))

		# ═══════════ DECORATIVE ═══════════
		var scan_y: float = fmod(t * 80.0, s.y)
		draw_rect(Rect2(0, scan_y, s.x, 1), Color(ACCENT, 0.03))
