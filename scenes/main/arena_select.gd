extends Control
## Arena Select Screen — Pick an arena before the fight.
## Shows all 8 arenas in a grid. Navigate with arrows, confirm with ENTER.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")

var _selected: int = 0
var _time: float = 0.0
var _draw_node: Control

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _ArenaDraw.new()
	_draw_node.screen = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	var count: int = GameMgr.ARENA_DATA.size()
	var cols: int = 4
	var weather_count: int = GameMgr.WEATHER_NAMES.size()

	match event.keycode:
		KEY_LEFT, KEY_A:
			_selected = (_selected - 1 + count) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_RIGHT, KEY_D:
			_selected = (_selected + 1) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_UP:
			_selected = (_selected - cols + count) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_DOWN:
			_selected = (_selected + cols) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_W:
			GameMgr.selected_weather = (GameMgr.selected_weather - 1 + weather_count) % weather_count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_S:
			GameMgr.selected_weather = (GameMgr.selected_weather + 1) % weather_count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_ENTER, KEY_SPACE:
			GameMgr.selected_arena = _selected
			if AudioManager:
				AudioManager.play_sfx("menu_select")
				AudioManager.stop_music()
			get_tree().change_scene_to_file("res://scenes/fighters/fight_test.tscn")
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main/loadout_screen.tscn")
		KEY_R:
			# Random arena
			_selected = randi() % count
			if AudioManager:
				AudioManager.play_sfx("equip")


class _ArenaDraw extends Control:
	var screen: Node

	func _draw() -> void:
		if screen == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = screen._time
		var arenas: Array = GameMgr.ARENA_DATA

		# Header
		draw_rect(Rect2(0, 0, s.x, 60), BG)
		draw_string(font, Vector2(s.x / 2.0 - 120, 42), "SELECT ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ACCENT)
		draw_rect(Rect2(0, 60, s.x, 2), Color(ACCENT, 0.3))

		# Arena grid (4x2)
		var cols: int = 4
		var rows: int = 2
		var margin: float = 20.0
		var card_w: float = (s.x - margin * (cols + 1)) / cols
		var card_h: float = (s.y - 160 - margin * (rows + 1)) / rows
		var grid_y: float = 80.0

		for i in range(arenas.size()):
			var arena: Dictionary = arenas[i]
			var col: int = i % cols
			var row: int = i / cols
			var cx: float = margin + col * (card_w + margin)
			var cy: float = grid_y + row * (card_h + margin)
			var is_sel: bool = i == screen._selected

			# Card background — arena sky gradient
			var sky_top: Color = arena["sky_top"]
			var sky_bot: Color = arena["sky_bot"]
			# Simple gradient (top half / bottom half)
			draw_rect(Rect2(cx, cy, card_w, card_h / 2.0), sky_top)
			draw_rect(Rect2(cx, cy + card_h / 2.0, card_w, card_h / 2.0), sky_bot)

			# Platform silhouette at bottom
			var plat_color: Color = arena["color"]
			draw_rect(Rect2(cx + 10, cy + card_h - 30, card_w - 20, 20), Color(plat_color, 0.8))
			# Side platforms
			draw_rect(Rect2(cx + 15, cy + card_h - 50, card_w * 0.25, 12), Color(plat_color, 0.5))
			draw_rect(Rect2(cx + card_w - 15 - card_w * 0.25, cy + card_h - 45, card_w * 0.25, 12), Color(plat_color, 0.5))

			# Hazard icon (small accent dot)
			var accent_col: Color = arena["accent"]
			draw_circle(Vector2(cx + card_w / 2.0, cy + card_h * 0.4), 8.0, Color(accent_col, 0.6))

			# Selection border
			if is_sel:
				var pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(ACCENT, 0.5 + pulse * 0.5), false, 3.0)
				# Arrow
				draw_string(font, Vector2(cx + 5, cy + 22), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)
			else:
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(0.3, 0.3, 0.4, 0.3), false, 1.0)

			# Arena name
			draw_string(font, Vector2(cx + 8, cy + card_h - 38), arena["name"], HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 16), 16, Color.WHITE if is_sel else Color(TEXT, 0.6))
			# City
			draw_string(font, Vector2(cx + 8, cy + 20), arena["city"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(TEXT, 0.4))

		# Bottom bar
		var bottom_y := s.y - 65
		draw_rect(Rect2(0, bottom_y, s.x, 65), BG)
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		draw_string(font, Vector2(20, bottom_y + 25), "Arrows/AD = Navigate | W/S = Weather | ENTER = Confirm | R = Random | ESC = Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))

		# Selected arena info
		var sel_arena: Dictionary = arenas[screen._selected]
		var weather_name: String = GameMgr.WEATHER_NAMES[GameMgr.selected_weather]
		draw_string(font, Vector2(20, bottom_y + 50), "Hazard: %s" % sel_arena["hazard"].replace("_", " ").capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, WARN)
		# Weather indicator
		var weather_col: Color = ACCENT
		if GameMgr.selected_weather == 1:
			weather_col = Color("#6366F1")  # Night = indigo
		elif GameMgr.selected_weather == 2:
			weather_col = Color("#EF4444")  # Storm = red
		draw_string(font, Vector2(s.x - 300, bottom_y + 50), "Weather: %s" % weather_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, weather_col)
