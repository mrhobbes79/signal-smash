extends Control
## SIGNAL SMASH — Custom Company Crew Creator
## NOC Dashboard aesthetic. Players create their own WISP company crew.
## Enter company name, select color and emblem, preview and save.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")

var _time: float = 0.0
var _draw_node: Control

# Input state
var _company_name: String = ""
var _color_index: int = 0
var _emblem_index: int = 0
var _active_field: int = 0  # 0=name, 1=color, 2=emblem
var _saved: bool = false
var _save_flash: float = 0.0

const MAX_NAME_LEN: int = 20

func _ready() -> void:
	# Background color
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	# Custom draw layer
	_draw_node = _CrewDraw.new()
	_draw_node.creator = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# Load existing crew data if present (prefer persisted Progression data)
	if Progression and Progression.crew_name != "":
		_company_name = Progression.crew_name
		_color_index = Progression.crew_color_index
		_emblem_index = Progression.crew_emblem_index
		# Sync back to GameMgr
		if GameMgr:
			GameMgr.custom_crew_name = _company_name
			GameMgr.custom_crew_color = GameMgr.CREW_COLORS[clampi(_color_index, 0, GameMgr.CREW_COLORS.size() - 1)]
			GameMgr.custom_crew_emblem = _emblem_index
	elif GameMgr:
		_company_name = GameMgr.custom_crew_name
		_color_index = GameMgr.CREW_COLORS.find(GameMgr.custom_crew_color)
		if _color_index < 0:
			_color_index = 0
		_emblem_index = GameMgr.custom_crew_emblem

func _process(delta: float) -> void:
	_time += delta
	if _save_flash > 0.0:
		_save_flash -= delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# Text input mode — when typing company name, capture ALL letters first
	if _active_field == 0:
		match event.keycode:
			KEY_UP, KEY_W:
				_active_field = 2
				if AudioManager:
					AudioManager.play_sfx("menu_move")
				return
			KEY_DOWN, KEY_S:
				_active_field = 1
				if AudioManager:
					AudioManager.play_sfx("menu_move")
				return
			KEY_BACKSPACE:
				if _company_name.length() > 0:
					_company_name = _company_name.substr(0, _company_name.length() - 1)
				return
			KEY_ENTER:
				_save_crew()
				return
			KEY_ESCAPE:
				if AudioManager:
					AudioManager.play_sfx("menu_move")
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
				return
			_:
				# ALL other keys go to text input (including A and D!)
				_handle_text_input(event)
				return

	# Color/Emblem field navigation
	match event.keycode:
		KEY_LEFT, KEY_A:
			if _active_field == 1:
				_color_index = (_color_index - 1 + GameMgr.CREW_COLORS.size()) % GameMgr.CREW_COLORS.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			elif _active_field == 2:
				_emblem_index = (_emblem_index - 1 + GameMgr.CREW_EMBLEMS.size()) % GameMgr.CREW_EMBLEMS.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
		KEY_RIGHT, KEY_D:
			if _active_field == 1:
				_color_index = (_color_index + 1) % GameMgr.CREW_COLORS.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			elif _active_field == 2:
				_emblem_index = (_emblem_index + 1) % GameMgr.CREW_EMBLEMS.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
		KEY_UP, KEY_W:
			_active_field = (_active_field - 1 + 3) % 3
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_DOWN, KEY_S:
			_active_field = (_active_field + 1) % 3
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_ENTER:
			_save_crew()
		KEY_ESCAPE:
			if AudioManager:
				AudioManager.play_sfx("menu_move")
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _handle_text_input(event: InputEventKey) -> void:
	if _company_name.length() >= MAX_NAME_LEN:
		return
	var unicode: int = event.unicode
	if unicode >= 32 and unicode <= 126:
		_company_name += char(unicode).to_upper()

func _save_crew() -> void:
	if _company_name.strip_edges().is_empty():
		return
	if GameMgr:
		GameMgr.custom_crew_name = _company_name.strip_edges()
		GameMgr.custom_crew_color = GameMgr.CREW_COLORS[_color_index]
		GameMgr.custom_crew_emblem = _emblem_index
	# Persist crew data to save file
	if Progression:
		Progression.crew_name = _company_name.strip_edges()
		Progression.crew_color_index = _color_index
		Progression.crew_emblem_index = _emblem_index
		Progression.save_game()
	_saved = true
	_save_flash = 2.0
	if AudioManager:
		AudioManager.play_sfx("menu_select")
	print("[CREW] Saved: %s (color %d, emblem %s)" % [_company_name, _color_index, GameMgr.CREW_EMBLEMS[_emblem_index]])

func _get_current_color() -> Color:
	if GameMgr:
		return GameMgr.CREW_COLORS[_color_index]
	return Color.WHITE

func _get_current_emblem() -> String:
	if GameMgr:
		return GameMgr.CREW_EMBLEMS[_emblem_index]
	return "circle"


class _CrewDraw extends Control:
	var creator: Node

	func _draw() -> void:
		if creator == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = creator._time
		var crew_color: Color = creator._get_current_color()
		var emblem_name: String = creator._get_current_emblem()

		# ═══════════ TITLE ═══════════
		var title_y: float = s.y * 0.08
		var pulse: float = (sin(t * 2.0) + 1.0) / 2.0
		draw_rect(Rect2(s.x * 0.15, title_y - 10, s.x * 0.7, 2), Color(ACCENT, 0.3 + pulse * 0.3))
		draw_string(font, Vector2(s.x / 2.0 - 180, title_y + 20), "CREW CREATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, ACCENT)
		draw_string(font, Vector2(s.x / 2.0 - 180, title_y + 45), "Build your WISP company crew", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))
		draw_rect(Rect2(s.x * 0.15, title_y + 55, s.x * 0.7, 2), Color(ACCENT, 0.3 + pulse * 0.3))

		# ═══════════ FIELDS ═══════════
		var field_start_y: float = s.y * 0.22
		var field_height: float = 80.0
		var field_x: float = s.x * 0.1
		var field_w: float = s.x * 0.45

		# --- Company Name ---
		var name_y: float = field_start_y
		var name_selected: bool = creator._active_field == 0
		_draw_field_box(field_x, name_y, field_w, 60.0, name_selected, t)
		draw_string(font, Vector2(field_x + 10, name_y + 18), "COMPANY NAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(WARN, 0.8))
		var display_name: String = creator._company_name
		if name_selected:
			var cursor_visible: bool = fmod(t, 1.0) < 0.5
			if cursor_visible:
				display_name += "_"
		if display_name.is_empty() and not name_selected:
			display_name = "(enter name)"
		var name_color: Color = ACCENT if name_selected else Color(TEXT, 0.6)
		draw_string(font, Vector2(field_x + 10, name_y + 45), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, name_color)

		# --- Crew Color ---
		var color_y: float = field_start_y + field_height
		var color_selected: bool = creator._active_field == 1
		_draw_field_box(field_x, color_y, field_w, 60.0, color_selected, t)
		draw_string(font, Vector2(field_x + 10, color_y + 18), "CREW COLOR  (A/D to cycle)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(WARN, 0.8))
		# Color swatches
		for i in range(GameMgr.CREW_COLORS.size()):
			var swatch_x: float = field_x + 10 + i * 32.0
			var swatch_y: float = color_y + 28
			var swatch_col: Color = GameMgr.CREW_COLORS[i]
			draw_rect(Rect2(swatch_x, swatch_y, 26, 22), swatch_col)
			if i == creator._color_index:
				draw_rect(Rect2(swatch_x - 2, swatch_y - 2, 30, 26), Color.WHITE, false, 2.0)
				# Arrow above
				draw_string(font, Vector2(swatch_x + 4, swatch_y - 4), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

		# --- Emblem ---
		var emblem_y: float = field_start_y + field_height * 2
		var emblem_selected: bool = creator._active_field == 2
		_draw_field_box(field_x, emblem_y, field_w, 60.0, emblem_selected, t)
		draw_string(font, Vector2(field_x + 10, emblem_y + 18), "CREW EMBLEM  (A/D to cycle)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(WARN, 0.8))
		# Emblem icons as text
		var emblem_symbols := ["●", "■", "▲", "★", "⌇", "〜", "◈", "⊤"]
		for i in range(mini(emblem_symbols.size(), GameMgr.CREW_EMBLEMS.size())):
			var emb_x: float = field_x + 10 + i * 50.0
			var emb_y: float = emblem_y + 46
			var emb_color: Color = Color.WHITE if i == creator._emblem_index else Color(TEXT, 0.4)
			draw_string(font, Vector2(emb_x, emb_y), emblem_symbols[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, emb_color)
			# Label below
			draw_string(font, Vector2(emb_x - 4, emb_y + 16), GameMgr.CREW_EMBLEMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(TEXT, 0.3))
			if i == creator._emblem_index:
				draw_rect(Rect2(emb_x - 4, emb_y - 28, 40, 50), Color.WHITE, false, 2.0)

		# ═══════════ PREVIEW CARD ═══════════
		var card_x: float = s.x * 0.6
		var card_y: float = s.y * 0.2
		var card_w: float = s.x * 0.32
		var card_h: float = 300.0

		# Card background
		draw_rect(Rect2(card_x, card_y, card_w, card_h), Color(0.05, 0.05, 0.1, 0.9))
		draw_rect(Rect2(card_x, card_y, card_w, card_h), crew_color, false, 3.0)

		# Card header band
		draw_rect(Rect2(card_x, card_y, card_w, 40), Color(crew_color, 0.3))
		draw_string(font, Vector2(card_x + 15, card_y + 28), "COMPANY CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, crew_color)

		# Company name on card
		var card_name: String = creator._company_name if not creator._company_name.is_empty() else "YOUR COMPANY"
		draw_string(font, Vector2(card_x + 15, card_y + 80), card_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)

		# Emblem display (large)
		var emblem_cx: float = card_x + card_w / 2.0
		var emblem_cy: float = card_y + 160.0
		var emblem_size: float = 40.0
		_draw_emblem(emblem_cx, emblem_cy, emblem_size, emblem_name, crew_color)

		# Emblem name label
		draw_string(font, Vector2(emblem_cx - 40, emblem_cy + emblem_size + 20), emblem_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))

		# Color swatch on card
		draw_rect(Rect2(card_x + 15, card_y + card_h - 50, card_w - 30, 30), crew_color)
		draw_string(font, Vector2(card_x + 20, card_y + card_h - 28), "CREW COLOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

		# ═══════════ SAVE STATUS ═══════════
		if creator._save_flash > 0.0:
			var flash_alpha: float = clampf(creator._save_flash, 0.0, 1.0)
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y * 0.82), "CREW SAVED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(Color("#22C55E"), flash_alpha))

		# ═══════════ BOTTOM INFO ═══════════
		var bottom_y := s.y - 80
		draw_rect(Rect2(0, bottom_y, s.x, 80), Color(BG, 0.9))
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		draw_string(font, Vector2(20, bottom_y + 30), "↑↓ Field  |  A/D Cycle  |  Type Name  |  ENTER Save  |  ESC Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))
		draw_string(font, Vector2(20, bottom_y + 55), "Custom Company Crews — SIGNAL SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.4))

		# ═══════════ DECORATIVE ═══════════
		var scan_y: float = fmod(t * 100.0, s.y)
		draw_rect(Rect2(0, scan_y, s.x, 1), Color(ACCENT, 0.05))
		# Corner brackets
		var bracket_size: float = 30.0
		var m: float = 15.0
		draw_line(Vector2(m, m), Vector2(m + bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m - bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m + bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)

	func _draw_field_box(x: float, y: float, w: float, h: float, selected: bool, t: float) -> void:
		draw_rect(Rect2(x, y, w, h), Color(0.05, 0.05, 0.1, 0.8))
		if selected:
			var sel_pulse: float = (sin(t * 4.0) + 1.0) / 2.0
			draw_rect(Rect2(x, y, w, h), Color(ACCENT, 0.1 + sel_pulse * 0.1))
			draw_rect(Rect2(x, y, w, h), ACCENT, false, 2.0)
		else:
			draw_rect(Rect2(x, y, w, h), Color(TEXT, 0.15), false, 1.0)

	func _draw_emblem(cx: float, cy: float, size: float, emblem: String, color: Color) -> void:
		match emblem:
			"circle":
				draw_circle(Vector2(cx, cy), size, color)
			"square":
				draw_rect(Rect2(cx - size, cy - size, size * 2, size * 2), color)
			"triangle":
				var points := PackedVector2Array([
					Vector2(cx, cy - size),
					Vector2(cx - size, cy + size),
					Vector2(cx + size, cy + size),
				])
				draw_colored_polygon(points, color)
			"star":
				# 5-point star approximation
				var star_points := PackedVector2Array()
				for i in range(10):
					var angle: float = -PI / 2.0 + i * PI / 5.0
					var r: float = size if i % 2 == 0 else size * 0.4
					star_points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
				draw_colored_polygon(star_points, color)
			"antenna":
				draw_line(Vector2(cx, cy + size), Vector2(cx, cy - size), color, 4.0)
				draw_line(Vector2(cx - size * 0.5, cy - size * 0.3), Vector2(cx, cy - size), color, 3.0)
				draw_line(Vector2(cx + size * 0.5, cy - size * 0.3), Vector2(cx, cy - size), color, 3.0)
				draw_circle(Vector2(cx, cy - size), 5.0, color)
			"signal":
				# Signal wave arcs
				for i in range(3):
					var r: float = size * 0.4 * (i + 1)
					draw_arc(Vector2(cx, cy), r, -PI / 3.0, PI / 3.0, 12, color, 3.0)
				draw_circle(Vector2(cx, cy), 5.0, color)
			"router":
				draw_rect(Rect2(cx - size, cy - size * 0.4, size * 2, size * 0.8), color)
				# Antennas
				draw_line(Vector2(cx - size * 0.5, cy - size * 0.4), Vector2(cx - size * 0.7, cy - size), color, 3.0)
				draw_line(Vector2(cx + size * 0.5, cy - size * 0.4), Vector2(cx + size * 0.7, cy - size), color, 3.0)
				# LED dots
				for i in range(3):
					draw_circle(Vector2(cx - size * 0.5 + i * size * 0.5, cy), 3.0, Color.WHITE)
			"tower":
				# Tower lattice
				draw_line(Vector2(cx - size * 0.3, cy + size), Vector2(cx, cy - size), color, 3.0)
				draw_line(Vector2(cx + size * 0.3, cy + size), Vector2(cx, cy - size), color, 3.0)
				# Cross bars
				for i in range(3):
					var bar_y: float = cy + size - (size * 2.0 / 3.0) * (i + 0.5)
					var bar_hw: float = size * 0.3 * (1.0 - float(i) * 0.25)
					draw_line(Vector2(cx - bar_hw, bar_y), Vector2(cx + bar_hw, bar_y), color, 2.0)
				# Blinking light
				draw_circle(Vector2(cx, cy - size), 4.0, Color("#EF4444"))
