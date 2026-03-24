extends Control
## SIGNAL SMASH — Main Menu
## NOC Dashboard aesthetic. Animated title, mode selection.
## Press ENTER or click buttons to navigate.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const P1_COLOR := Color("#2563EB")

var _selected_index: int = 0
var _menu_items: Array[String] = ["TOURNAMENT", "CONFERENCE MODE", "MINI-GAME TEST", "ART TEST"]
var _scene_paths: Array[String] = [
	"res://scenes/main/character_select.tscn",
	"res://scenes/fighters/fight_test.tscn",
	"res://scenes/minigames/minigame_test.tscn",
	"res://scenes/art_test/art_style_test.tscn",
]
var _time: float = 0.0
var _draw_node: Control

func _ready() -> void:
	# Background color
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	# Custom draw layer
	_draw_node = _MenuDraw.new()
	_draw_node.menu = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()
	# Start menu music
	if not _music_started and AudioManager:
		AudioManager.play_music_menu()
		_music_started = true

var _music_started: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_selected_index = (_selected_index - 1 + _menu_items.size()) % _menu_items.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_DOWN, KEY_S:
				_selected_index = (_selected_index + 1) % _menu_items.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_ENTER, KEY_SPACE:
				if AudioManager:
					AudioManager.play_sfx("menu_select")
				_select_item()
			KEY_ESCAPE:
				get_tree().quit()

func _select_item() -> void:
	if AudioManager:
		AudioManager.stop_music()
	var path: String = _scene_paths[_selected_index]
	get_tree().change_scene_to_file(path)


class _MenuDraw extends Control:
	var menu: Node

	func _draw() -> void:
		if menu == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = menu._time

		# ═══════════ TITLE ═══════════
		var title_y: float = s.y * 0.2
		var pulse: float = (sin(t * 2.0) + 1.0) / 2.0

		# Title glow line
		var glow_color := Color(ACCENT, 0.3 + pulse * 0.3)
		draw_rect(Rect2(s.x * 0.15, title_y - 50, s.x * 0.7, 2), glow_color)

		# SIGNAL SMASH title
		draw_string(font, Vector2(s.x / 2.0 - 220, title_y), "SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, ACCENT)
		draw_string(font, Vector2(s.x / 2.0 + 30, title_y), "SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, WARN)

		# Subtitle
		draw_string(font, Vector2(s.x / 2.0 - 200, title_y + 40), "The Connectathon // WISP Tournament", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(TEXT, 0.6))

		# Bottom glow line
		draw_rect(Rect2(s.x * 0.15, title_y + 55, s.x * 0.7, 2), glow_color)

		# ═══════════ MENU ITEMS ═══════════
		var menu_start_y: float = s.y * 0.45
		var item_height: float = 60.0

		for i in range(menu._menu_items.size()):
			var item_y: float = menu_start_y + i * item_height
			var is_selected: bool = i == menu._selected_index

			if is_selected:
				# Selection highlight
				var sel_pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(s.x * 0.25, item_y - 30, s.x * 0.5, 45), Color(ACCENT, 0.1 + sel_pulse * 0.1))
				draw_rect(Rect2(s.x * 0.25, item_y - 30, s.x * 0.5, 45), ACCENT, false, 2.0)
				# Arrow indicator
				draw_string(font, Vector2(s.x * 0.25 + 10, item_y), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ACCENT)
				# Selected text
				draw_string(font, Vector2(s.x / 2.0 - 100, item_y), menu._menu_items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ACCENT)
			else:
				draw_string(font, Vector2(s.x / 2.0 - 100, item_y), menu._menu_items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(TEXT, 0.5))

		# ═══════════ BOTTOM INFO ═══════════
		var bottom_y := s.y - 80
		draw_rect(Rect2(0, bottom_y, s.x, 80), Color(BG, 0.9))
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))

		draw_string(font, Vector2(20, bottom_y + 30), "↑↓ Navigate  |  ENTER Select  |  ESC Quit", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))
		draw_string(font, Vector2(20, bottom_y + 55), "For WISPA, WISPMX & ABRINT Communities", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.4))
		draw_string(font, Vector2(s.x - 250, bottom_y + 30), "Rigel Open Labs", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.3))
		draw_string(font, Vector2(s.x - 250, bottom_y + 55), "#SignalSmash v0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.3))

		# ═══════════ DECORATIVE ═══════════
		# Scanning line effect
		var scan_y: float = fmod(t * 100.0, s.y)
		draw_rect(Rect2(0, scan_y, s.x, 1), Color(ACCENT, 0.05))

		# Corner brackets (NOC style)
		var bracket_size: float = 30.0
		var m: float = 15.0
		# Top-left
		draw_line(Vector2(m, m), Vector2(m + bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		# Top-right
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m - bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		# Bottom-left
		draw_line(Vector2(m, s.y - m), Vector2(m + bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)
		# Bottom-right
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)
