extends Control
## Character Select Screen
## Shows 4 characters (2 playable, 2 locked). Each player picks independently.
## NOC Dashboard aesthetic. Press ENTER when both players ready.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const LOCKED := Color("#4B5563")

const CHARACTERS := [
	{
		"name": "RICO",
		"role": "Cable Specialist",
		"color": Color("#2563EB"),
		"accent": Color("#FCD34D"),
		"stats": {"SPD": 7, "PWR": 6, "RNG": 7, "DEF": 5},
		"locked": false,
		"catchphrase": "Señal confirmada!",
	},
	{
		"name": "ING. VERO",
		"role": "Spectrum Engineer",
		"color": Color("#7C3AED"),
		"accent": Color("#06B6D4"),
		"stats": {"SPD": 5, "PWR": 5, "RNG": 8, "DEF": 7},
		"locked": false,
		"catchphrase": "Canal limpio detectado.",
	},
	{
		"name": "DON AURELIO",
		"role": "Old School Veteran",
		"color": Color("#92400E"),
		"accent": Color("#D97706"),
		"stats": {"SPD": 3, "PWR": 9, "RNG": 5, "DEF": 9},
		"locked": false,
		"catchphrase": "En mis tiempos...",
	},
	{
		"name": "MORXEL",
		"role": "Reality Hacker",
		"color": Color("#059669"),
		"accent": Color("#10B981"),
		"stats": {"SPD": 9, "PWR": 8, "RNG": 6, "DEF": 2},
		"locked": false,
		"catchphrase": "root@signal:~# sudo smash",
	},
]

var _p1_index: int = 0
var _p2_index: int = 1
var _p1_ready: bool = false
var _p2_ready: bool = false
var _time: float = 0.0
var _draw_node: Control

func _is_locked(index: int) -> bool:
	var char_name: String = CHARACTERS[index]["name"]
	if Progression:
		return not Progression.is_character_unlocked(char_name)
	return CHARACTERS[index]["locked"]

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _SelectDraw.new()
	_draw_node.sel = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# Play character select music
	if AudioManager:
		AudioManager.play_music_select()

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# P1 controls (WASD + Space)
	if not _p1_ready:
		match event.keycode:
			KEY_A:
				_p1_index = (_p1_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
				var safety: int = 0
				while _is_locked(_p1_index) and safety < CHARACTERS.size():
					_p1_index = (_p1_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
					safety += 1
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_D:
				_p1_index = (_p1_index + 1) % CHARACTERS.size()
				var safety: int = 0
				while _is_locked(_p1_index) and safety < CHARACTERS.size():
					_p1_index = (_p1_index + 1) % CHARACTERS.size()
					safety += 1
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_SPACE:
				_p1_ready = true
				if AudioManager:
					AudioManager.play_sfx("signal_lock")

	# P2 controls (Arrows + Shift)
	if not _p2_ready:
		match event.keycode:
			KEY_LEFT:
				_p2_index = (_p2_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
				var safety: int = 0
				while _is_locked(_p2_index) and safety < CHARACTERS.size():
					_p2_index = (_p2_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
					safety += 1
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_RIGHT:
				_p2_index = (_p2_index + 1) % CHARACTERS.size()
				var safety: int = 0
				while _is_locked(_p2_index) and safety < CHARACTERS.size():
					_p2_index = (_p2_index + 1) % CHARACTERS.size()
					safety += 1
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_SHIFT:
				_p2_ready = true
				if AudioManager:
					AudioManager.play_sfx("signal_lock")

	# Cancel ready
	if event.keycode == KEY_ESCAPE:
		if _p1_ready or _p2_ready:
			_p1_ready = false
			_p2_ready = false
		else:
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

	# Both ready — store selections and go to loadout screen
	if _p1_ready and _p2_ready:
		if _p1_index == _p2_index:
			# Same character selected — bump P2 to next available
			_p2_index = (_p2_index + 1) % CHARACTERS.size()
			var safety: int = 0
			while (_is_locked(_p2_index) or _p2_index == _p1_index) and safety < CHARACTERS.size():
				_p2_index = (_p2_index + 1) % CHARACTERS.size()
				safety += 1
			_p2_ready = false
			if AudioManager:
				AudioManager.play_sfx("menu_move")
			return
		if AudioManager:
			AudioManager.play_sfx("menu_select")
		GameMgr.p1_char_index = _p1_index
		GameMgr.p2_char_index = _p2_index
		get_tree().change_scene_to_file("res://scenes/main/loadout_screen.tscn")


class _SelectDraw extends Control:
	var sel: Node

	func _draw() -> void:
		if sel == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = sel._time

		# ═══════════ HEADER ═══════════
		draw_rect(Rect2(0, 0, s.x, 60), BG)
		draw_string(font, Vector2(s.x / 2.0 - 130, 42), "SELECT YOUR CREW", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ACCENT)
		draw_rect(Rect2(0, 60, s.x, 2), Color(ACCENT, 0.3))

		# ═══════════ CHARACTER CARDS ═══════════
		var card_w: float = s.x / 4.0 - 20
		var card_h: float = s.y * 0.55
		var card_y: float = 90.0

		for i in range(sel.CHARACTERS.size()):
			var ch: Dictionary = sel.CHARACTERS[i]
			var card_x: float = 15.0 + i * (card_w + 12)
			var is_locked: bool = not Progression.is_character_unlocked(ch["name"]) if Progression else ch["locked"]
			var p1_sel: bool = i == sel._p1_index
			var p2_sel: bool = i == sel._p2_index
			var color: Color = LOCKED if is_locked else ch["color"]

			# Card background
			draw_rect(Rect2(card_x, card_y, card_w, card_h), Color(BG, 0.95))

			# Selection borders
			if p1_sel:
				var p1_pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(card_x, card_y, card_w, card_h), Color(Color("#2563EB"), 0.5 + p1_pulse * 0.5), false, 3.0)
				draw_string(font, Vector2(card_x + 10, card_y + 20), "▶ P1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#2563EB"))
				if sel._p1_ready:
					draw_string(font, Vector2(card_x + card_w - 80, card_y + 20), "READY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#22C55E"))
			if p2_sel:
				var p2_pulse: float = (sin(t * 4.0 + 1.5) + 1.0) / 2.0
				draw_rect(Rect2(card_x + 3, card_y + 3, card_w - 6, card_h - 6), Color(Color("#7C3AED"), 0.4 + p2_pulse * 0.4), false, 3.0)
				draw_string(font, Vector2(card_x + 10, card_y + 40), "▶ P2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#7C3AED"))
				if sel._p2_ready:
					draw_string(font, Vector2(card_x + card_w - 80, card_y + 40), "READY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#22C55E"))

			if not p1_sel and not p2_sel:
				draw_rect(Rect2(card_x, card_y, card_w, card_h), Color(color, 0.2), false, 1.0)

			# Character visual area (colored block representing the character)
			var vis_y: float = card_y + 55
			var vis_h: float = card_h * 0.45
			draw_rect(Rect2(card_x + 20, vis_y, card_w - 40, vis_h), Color(color, 0.15))

			if is_locked:
				# Locked overlay
				draw_string(font, Vector2(card_x + card_w / 2.0 - 70, vis_y + vis_h / 2.0 - 10), "COMING SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#EF4444"))
				var lock_pulse: float = (sin(t * 2.0 + float(i)) + 1.0) / 2.0
				draw_string(font, Vector2(card_x + card_w / 2.0 - 10, vis_y + vis_h / 2.0 + 25), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(LOCKED, 0.5 + lock_pulse * 0.5))
			else:
				# Character silhouette (simple shapes)
				var cx: float = card_x + card_w / 2.0
				var cy: float = vis_y + vis_h / 2.0
				# Head
				draw_circle(Vector2(cx, cy - 30), 18, color)
				# Body
				draw_rect(Rect2(cx - 15, cy - 10, 30, 40), color)
				# Accent equipment
				draw_rect(Rect2(cx - 8, cy - 5, 16, 12), ch["accent"])

			# Name
			var name_y: float = card_y + 55 + vis_h + 30
			draw_string(font, Vector2(card_x + 15, name_y), ch["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color if not is_locked else LOCKED)

			# Role
			draw_string(font, Vector2(card_x + 15, name_y + 25), ch["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.5))

			# Stats bars (only for unlocked)
			if not is_locked:
				var stat_y: float = name_y + 40
				var stats: Dictionary = ch["stats"]
				for stat_name in stats:
					var val: int = stats[stat_name]
					draw_string(font, Vector2(card_x + 15, stat_y + 12), stat_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.4))
					# Bar bg
					draw_rect(Rect2(card_x + 55, stat_y + 2, card_w - 80, 10), Color(0.15, 0.15, 0.15))
					# Bar fill
					var fill_w: float = (card_w - 80) * (float(val) / 10.0)
					draw_rect(Rect2(card_x + 55, stat_y + 2, fill_w, 10), ch["accent"])
					stat_y += 18

			# Catchphrase
			if not is_locked:
				draw_string(font, Vector2(card_x + 15, card_y + card_h - 15), "\"%s\"" % ch["catchphrase"], HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 30), 12, Color(TEXT, 0.3))

		# ═══════════ BOTTOM BAR ═══════════
		var bottom_y := s.y - 70
		draw_rect(Rect2(0, bottom_y, s.x, 70), BG)
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))

		draw_string(font, Vector2(20, bottom_y + 25), "P1: A/D select | SPACE ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#2563EB"))
		draw_string(font, Vector2(20, bottom_y + 50), "P2: ←/→ select | SHIFT ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#7C3AED"))
		draw_string(font, Vector2(s.x - 250, bottom_y + 25), "ESC = Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))

		if sel._p1_ready and sel._p2_ready:
			var go_pulse: float = (sin(t * 6.0) + 1.0) / 2.0
			draw_string(font, Vector2(s.x / 2.0 - 50, bottom_y + 40), "FIGHT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(Color("#22C55E"), 0.5 + go_pulse * 0.5))
