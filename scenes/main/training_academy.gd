extends Control
## SIGNAL SMASH — Training Academy
## Hub scene with 4 tabs: Training Rooms, Crew Quarters, Leaderboard Hall, Equipment Workshop.
## NOC Dashboard aesthetic with custom _draw() rendering.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const DIM := Color("#64748B")
const PANEL := Color("#1E293B")

## ═══════════ TABS ═══════════

enum Tab { TRAINING, CREW, LEADERBOARD, WORKSHOP }

const TAB_NAMES := ["TRAINING ROOMS", "CREW QUARTERS", "LEADERBOARD HALL", "EQUIPMENT WORKSHOP"]

var _current_tab: int = Tab.TRAINING
var _time: float = 0.0
var _draw_node: Control

## ═══════════ TRAINING TAB STATE ═══════════

const MINIGAMES := [
	{"name": "Antenna Align", "key": "antenna_align", "scene": "res://scenes/minigames/antenna_align.tscn"},
	{"name": "Bandwidth Auction", "key": "bandwidth_auction", "scene": "res://scenes/minigames/bandwidth_auction.tscn"},
	{"name": "Cable Run", "key": "cable_run", "scene": "res://scenes/minigames/cable_run.tscn"},
	{"name": "Firewall Frenzy", "key": "firewall_frenzy", "scene": "res://scenes/minigames/firewall_frenzy.tscn"},
	{"name": "IP Puzzle", "key": "ip_puzzle", "scene": "res://scenes/minigames/ip_puzzle.tscn"},
	{"name": "Ping Pong", "key": "ping_pong", "scene": "res://scenes/minigames/ping_pong.tscn"},
	{"name": "Spectrum Sniper", "key": "spectrum_sniper", "scene": "res://scenes/minigames/spectrum_sniper.tscn"},
	{"name": "Tower Climb", "key": "tower_climb", "scene": "res://scenes/minigames/tower_climb.tscn"},
	{"name": "Troubleshooter", "key": "troubleshooter", "scene": "res://scenes/minigames/troubleshooter.tscn"},
	{"name": "Weather Dodge", "key": "weather_dodge", "scene": "res://scenes/minigames/weather_dodge.tscn"},
]

var _minigame_index: int = 0

## ═══════════ CREW TAB STATE ═══════════

const CHARACTERS := [
	{
		"name": "RICO",
		"role": "Cable Specialist",
		"color": Color("#2563EB"),
		"accent": Color("#FCD34D"),
		"stats": {"SPD": 7, "PWR": 6, "RNG": 7, "DEF": 5},
		"catchphrase": "Señal confirmada!",
	},
	{
		"name": "ING. VERO",
		"role": "Spectrum Engineer",
		"color": Color("#7C3AED"),
		"accent": Color("#06B6D4"),
		"stats": {"SPD": 5, "PWR": 5, "RNG": 8, "DEF": 7},
		"catchphrase": "Canal limpio detectado.",
	},
	{
		"name": "DON AURELIO",
		"role": "Old School Veteran",
		"color": Color("#92400E"),
		"accent": Color("#D97706"),
		"stats": {"SPD": 3, "PWR": 9, "RNG": 5, "DEF": 9},
		"catchphrase": "En mis tiempos...",
	},
	{
		"name": "MORXEL",
		"role": "Reality Hacker",
		"color": Color("#059669"),
		"accent": Color("#10B981"),
		"stats": {"SPD": 9, "PWR": 8, "RNG": 6, "DEF": 2},
		"catchphrase": "root@signal:~# sudo smash",
	},
]

var _crew_index: int = 0

## ═══════════ LIFECYCLE ═══════════

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _AcademyDraw.new()
	_draw_node.academy = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

## ═══════════ INPUT ═══════════

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	match event.keycode:
		KEY_ESCAPE:
			if AudioManager:
				AudioManager.play_sfx("menu_move")
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

		KEY_LEFT, KEY_A:
			_current_tab = (_current_tab - 1 + TAB_NAMES.size()) % TAB_NAMES.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")

		KEY_RIGHT, KEY_D:
			_current_tab = (_current_tab + 1) % TAB_NAMES.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")

		KEY_UP, KEY_W:
			_navigate_list(-1)

		KEY_DOWN, KEY_S:
			_navigate_list(1)

		KEY_ENTER, KEY_SPACE:
			_select_action()

func _navigate_list(direction: int) -> void:
	match _current_tab:
		Tab.TRAINING:
			_minigame_index = (_minigame_index + direction + MINIGAMES.size()) % MINIGAMES.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		Tab.CREW:
			_crew_index = (_crew_index + direction + CHARACTERS.size()) % CHARACTERS.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")

func _select_action() -> void:
	match _current_tab:
		Tab.TRAINING:
			if AudioManager:
				AudioManager.play_sfx("menu_select")
			var selected_mg: Dictionary = MINIGAMES[_minigame_index]
			get_tree().change_scene_to_file(selected_mg["scene"])
		Tab.WORKSHOP:
			if AudioManager:
				AudioManager.play_sfx("menu_select")
			get_tree().change_scene_to_file("res://scenes/main/loadout_screen.tscn")

## ═══════════ DRAW ═══════════

class _AcademyDraw extends Control:
	var academy: Node

	func _draw() -> void:
		if academy == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = academy._time

		# ═══════════ HEADER ═══════════
		var header_h: float = 90.0
		draw_rect(Rect2(0, 0, s.x, header_h), PANEL)
		draw_rect(Rect2(0, header_h - 2, s.x, 2), Color(ACCENT, 0.5))

		# Title
		draw_string(font, Vector2(30, 40), "SIGNAL SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ACCENT, 0.6))
		draw_string(font, Vector2(30, 68), "TRAINING ACADEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ACCENT)

		# Phase badge (top-right)
		if Progression:
			var phase_color: Color = Progression.get_phase_color()
			var phase_name: String = Progression.get_phase_name().to_upper()
			draw_string(font, Vector2(s.x - 300, 35), "RANK: %s" % phase_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, phase_color)
			draw_string(font, Vector2(s.x - 300, 58), "%d SP  |  %d KT" % [Progression.signal_points, Progression.knowledge_tokens], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))

		# ═══════════ TAB BAR ═══════════
		var tab_y: float = header_h + 10
		var tab_w: float = s.x / TAB_NAMES.size()
		for i in range(TAB_NAMES.size()):
			var tx: float = i * tab_w
			var is_active: bool = i == academy._current_tab
			if is_active:
				draw_rect(Rect2(tx, tab_y, tab_w, 44), Color(ACCENT, 0.15))
				draw_rect(Rect2(tx, tab_y + 42, tab_w, 2), ACCENT)
				draw_string(font, Vector2(tx + tab_w / 2.0 - 80, tab_y + 30), TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ACCENT)
			else:
				draw_string(font, Vector2(tx + tab_w / 2.0 - 80, tab_y + 30), TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.6))

		# ═══════════ CONTENT AREA ═══════════
		var content_y: float = tab_y + 60
		match academy._current_tab:
			Tab.TRAINING:
				_draw_training(s, font, t, content_y)
			Tab.CREW:
				_draw_crew(s, font, t, content_y)
			Tab.LEADERBOARD:
				_draw_leaderboard(s, font, t, content_y)
			Tab.WORKSHOP:
				_draw_workshop(s, font, t, content_y)

		# ═══════════ BOTTOM NAV ═══════════
		var bottom_y := s.y - 50
		draw_rect(Rect2(0, bottom_y, s.x, 50), Color(PANEL, 0.9))
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		var nav_text: String = "←→ / A D  Switch Tab  |  ↑↓ / W S  Navigate  |  ENTER  Select  |  ESC  Back to Menu"
		draw_string(font, Vector2(30, bottom_y + 32), nav_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))

		# ═══════════ DECORATIVE ═══════════
		var scan_y: float = fmod(t * 80.0, s.y)
		draw_rect(Rect2(0, scan_y, s.x, 1), Color(ACCENT, 0.03))

		# Corner brackets
		var bs: float = 25.0
		var m: float = 10.0
		draw_line(Vector2(m, m), Vector2(m + bs, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + bs), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m - bs, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + bs), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m + bs, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - bs), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - bs, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - bs), Color(ACCENT, 0.3), 2.0)

	## ═══════════ TRAINING ROOMS ═══════════

	func _draw_training(s: Vector2, font: Font, t: float, cy: float) -> void:
		draw_string(font, Vector2(60, cy + 10), "SELECT A MINI-GAME TO PRACTICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.7))

		var list_y: float = cy + 40
		var item_h: float = 50.0
		var list_x: float = 60.0
		var list_w: float = s.x - 120.0

		for i in range(MINIGAMES.size()):
			var iy: float = list_y + i * item_h
			var is_sel: bool = i == academy._minigame_index
			var mg: Dictionary = MINIGAMES[i]

			if is_sel:
				var pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(list_x, iy, list_w, item_h - 6), Color(ACCENT, 0.08 + pulse * 0.07))
				draw_rect(Rect2(list_x, iy, list_w, item_h - 6), ACCENT, false, 1.5)
				draw_string(font, Vector2(list_x + 15, iy + 30), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
				draw_string(font, Vector2(list_x + 50, iy + 30), mg["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
			else:
				draw_rect(Rect2(list_x, iy, list_w, item_h - 6), Color(PANEL, 0.5))
				draw_string(font, Vector2(list_x + 50, iy + 30), mg["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(TEXT, 0.5))

			# Best score
			var best_score: float = 0.0
			if Progression and mg["key"] in Progression.best_minigame_scores:
				best_score = Progression.best_minigame_scores[mg["key"]]
			var score_text: String = "BEST: %.0f" % best_score if best_score > 0 else "—"
			var score_color: Color = WARN if best_score >= 95.0 else (Color(ACCENT, 0.6) if best_score > 0 else Color(DIM, 0.4))
			draw_string(font, Vector2(list_x + list_w - 180, iy + 30), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, score_color)

	## ═══════════ CREW QUARTERS ═══════════

	func _draw_crew(s: Vector2, font: Font, t: float, cy: float) -> void:
		draw_string(font, Vector2(60, cy + 10), "CHARACTER ROSTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.7))

		var card_w: float = (s.x - 160) / 4.0
		var card_h: float = s.y - cy - 120
		var card_y: float = cy + 35

		for i in range(CHARACTERS.size()):
			var ch: Dictionary = CHARACTERS[i]
			var cx: float = 60 + i * (card_w + 12)
			var is_sel: bool = i == academy._crew_index
			var unlocked: bool = true
			if Progression:
				unlocked = Progression.is_character_unlocked(ch["name"])

			# Card background
			if is_sel:
				var pulse: float = (sin(t * 3.0) + 1.0) / 2.0
				draw_rect(Rect2(cx, card_y, card_w, card_h), Color(ch["color"], 0.15 + pulse * 0.1))
				draw_rect(Rect2(cx, card_y, card_w, card_h), ch["color"], false, 2.0)
			else:
				draw_rect(Rect2(cx, card_y, card_w, card_h), Color(PANEL, 0.7))
				draw_rect(Rect2(cx, card_y, card_w, card_h), Color(DIM, 0.2), false, 1.0)

			# Lock overlay
			if not unlocked:
				draw_rect(Rect2(cx, card_y, card_w, card_h), Color(0, 0, 0, 0.5))
				draw_string(font, Vector2(cx + card_w / 2.0 - 40, card_y + card_h / 2.0), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.3, 0.3, 0.8))
				continue

			# Character color swatch
			draw_rect(Rect2(cx, card_y, card_w, 6), ch["color"])

			# Name
			var name_y: float = card_y + 40
			draw_string(font, Vector2(cx + 15, name_y), ch["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ch["color"])

			# Role
			draw_string(font, Vector2(cx + 15, name_y + 25), ch["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))

			# Stats
			var stats: Dictionary = ch["stats"]
			var stat_y: float = name_y + 60
			var stat_keys: Array = ["SPD", "PWR", "RNG", "DEF"]
			for si in range(stat_keys.size()):
				var key: String = stat_keys[si]
				var val: int = stats[key]
				var sy: float = stat_y + si * 36

				draw_string(font, Vector2(cx + 15, sy), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(DIM, 0.8))

				# Stat bar background
				var bar_x: float = cx + 60
				var bar_w: float = card_w - 100
				var bar_h: float = 12.0
				draw_rect(Rect2(bar_x, sy - 12, bar_w, bar_h), Color(0.1, 0.1, 0.15))

				# Stat bar fill
				var fill_ratio: float = val / 10.0
				var bar_color: Color = ch["accent"] if is_sel else Color(ch["color"], 0.6)
				draw_rect(Rect2(bar_x, sy - 12, bar_w * fill_ratio, bar_h), bar_color)

				# Value
				draw_string(font, Vector2(cx + card_w - 35, sy), str(val), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))

			# Catchphrase
			var catch_y: float = stat_y + stat_keys.size() * 36 + 20
			draw_string(font, Vector2(cx + 15, catch_y), "\"%s\"" % ch["catchphrase"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ch["accent"], 0.6))

	## ═══════════ LEADERBOARD HALL ═══════════

	func _draw_leaderboard(s: Vector2, font: Font, _t: float, cy: float) -> void:
		draw_string(font, Vector2(60, cy + 10), "CAREER STATISTICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.7))

		if not Progression:
			draw_string(font, Vector2(60, cy + 60), "No progression data available.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(TEXT, 0.5))
			return

		var col_x: float = 80.0
		var row_y: float = cy + 50
		var row_h: float = 42.0
		var val_x: float = 380.0

		# Phase
		var phase_color: Color = Progression.get_phase_color()
		draw_string(font, Vector2(col_x, row_y), "CURRENT PHASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.8))
		draw_string(font, Vector2(val_x, row_y), Progression.get_phase_name().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, phase_color)
		row_y += row_h

		# Divider
		draw_rect(Rect2(col_x, row_y - 10, s.x - 160, 1), Color(ACCENT, 0.15))
		row_y += 10

		# Fight stats
		var stats_data: Array = [
			["TOTAL WINS", str(Progression.total_wins), ACCENT],
			["TOTAL LOSSES", str(Progression.total_losses), Color(1, 0.4, 0.4, 0.8)],
			["TOTAL FIGHTS", str(Progression.total_fights), Color(TEXT, 0.7)],
			["TOTAL MINIGAMES", str(Progression.total_minigames), Color(TEXT, 0.7)],
			["SIGNAL POINTS (SP)", str(Progression.signal_points), ACCENT],
			["KNOWLEDGE TOKENS (KT)", str(Progression.knowledge_tokens), WARN],
		]

		for entry in stats_data:
			draw_string(font, Vector2(col_x, row_y), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.8))
			draw_string(font, Vector2(val_x, row_y), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, entry[2])
			row_y += row_h

		# Divider
		draw_rect(Rect2(col_x, row_y - 10, s.x - 160, 1), Color(ACCENT, 0.15))
		row_y += 15

		# Phase progress
		draw_string(font, Vector2(col_x, row_y), "PHASE PROGRESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.8))
		var progress: float = Progression.get_phase_progress()
		var bar_x: float = val_x
		var bar_w: float = 300.0
		draw_rect(Rect2(bar_x, row_y - 14, bar_w, 16), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(bar_x, row_y - 14, bar_w * clampf(progress, 0.0, 1.0), 16), phase_color)
		draw_string(font, Vector2(bar_x + bar_w + 15, row_y), "%d%%" % int(progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.6))
		row_y += row_h + 5

		# Best mini-game scores section
		draw_rect(Rect2(col_x, row_y - 10, s.x - 160, 1), Color(ACCENT, 0.15))
		row_y += 15
		draw_string(font, Vector2(col_x, row_y), "BEST MINI-GAME SCORES", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.8))
		row_y += row_h - 5

		# Two columns of mini-game scores
		var mg_col2_x: float = s.x / 2.0 + 40
		for i in range(MINIGAMES.size()):
			var mg: Dictionary = MINIGAMES[i]
			var mx: float = col_x if i < 5 else mg_col2_x
			var my: float = row_y + (i % 5) * 30.0
			var best: float = 0.0
			if mg["key"] in Progression.best_minigame_scores:
				best = Progression.best_minigame_scores[mg["key"]]
			var score_str: String = "%.0f" % best if best > 0 else "—"
			var sc: Color = WARN if best >= 95.0 else (Color(ACCENT, 0.6) if best > 0 else Color(DIM, 0.4))
			draw_string(font, Vector2(mx, my), mg["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))
			draw_string(font, Vector2(mx + 200, my), score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sc)

	## ═══════════ EQUIPMENT WORKSHOP ═══════════

	func _draw_workshop(s: Vector2, font: Font, t: float, cy: float) -> void:
		draw_string(font, Vector2(60, cy + 10), "EQUIPMENT WORKSHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(DIM, 0.7))

		# Center panel
		var panel_w: float = 500.0
		var panel_h: float = 200.0
		var px: float = (s.x - panel_w) / 2.0
		var py: float = cy + 80

		var pulse: float = (sin(t * 2.0) + 1.0) / 2.0
		draw_rect(Rect2(px, py, panel_w, panel_h), Color(PANEL, 0.8))
		draw_rect(Rect2(px, py, panel_w, panel_h), Color(ACCENT, 0.2 + pulse * 0.15), false, 2.0)

		# Icon area
		draw_string(font, Vector2(px + panel_w / 2.0 - 20, py + 60), "⚙", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(ACCENT, 0.5))

		# Text
		draw_string(font, Vector2(px + panel_w / 2.0 - 120, py + 110), "OPEN LOADOUT SCREEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
		draw_string(font, Vector2(px + panel_w / 2.0 - 140, py + 145), "Equip radios, antennas, and routers", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))
		draw_string(font, Vector2(px + panel_w / 2.0 - 60, py + 175), "Press ENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(WARN, 0.6 + pulse * 0.4))
