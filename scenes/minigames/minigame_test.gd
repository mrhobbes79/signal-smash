extends Node3D
## SIGNAL SMASH — Mini-Game Select & Test
## Visual grid selection for all mini-games.
## Arrow keys navigate, ENTER starts, ESC returns to menu.

const AntennaAlignScene = preload("res://scenes/minigames/antenna_align.tscn")
const SpectrumSniperScene = preload("res://scenes/minigames/spectrum_sniper.tscn")
const CableRunScene = preload("res://scenes/minigames/cable_run.tscn")
const TowerClimbScene = preload("res://scenes/minigames/tower_climb.tscn")
const PingPongScene = preload("res://scenes/minigames/ping_pong.tscn")
const FirewallFrenzyScene = preload("res://scenes/minigames/firewall_frenzy.tscn")
const IPPuzzleScene = preload("res://scenes/minigames/ip_puzzle.tscn")
const WeatherDodgeScene = preload("res://scenes/minigames/weather_dodge.tscn")
const BandwidthAuctionScene = preload("res://scenes/minigames/bandwidth_auction.tscn")
const TroubleshooterScene = preload("res://scenes/minigames/troubleshooter.tscn")
const WiFi7ChannelsScene = preload("res://scenes/minigames/wifi7_channels.tscn")
const CBRSDeployScene = preload("res://scenes/minigames/cbrs_deploy.tscn")
const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const DIM := Color("#64748B")
const PANEL := Color("#1E293B")

const MINI_NAMES: Array[String] = [
	"ANTENNA ALIGN", "SPECTRUM SNIPER", "CABLE RUN",
	"TOWER CLIMB", "PING PONG", "FIREWALL FRENZY",
	"IP PUZZLE", "WEATHER DODGE", "BANDWIDTH AUCTION",
	"TROUBLESHOOTER", "WIFI 7 CHANNELS", "CBRS DEPLOY",
]

const MINI_DESCS: Array[String] = [
	"Align your dish to\nthe target signal.",
	"Find the cleanest\nchannel in spectrum.",
	"Route cable through\nthe maze correctly.",
	"Race to climb the\ntower! Tap rhythm.",
	"Packet pong! Keep\ndata flowing past.",
	"Block bad packets,\nallow good ones.",
	"Assemble the correct\nIP and subnet mask.",
	"Keep signal alive\nthrough weather.",
	"Bid on spectrum\nblocks for coverage.",
	"Diagnose network\nproblems from clues.",
	"Manage 3 WiFi 7\nlinks across bands.",
	"Deploy CBRS cells.\nAvoid radar!",
]

const MINI_COLORS: Array[Color] = [
	Color("#3B82F6"), Color("#8B5CF6"), Color("#22C55E"),
	Color("#F59E0B"), Color("#06B6D4"), Color("#EF4444"),
	Color("#A855F7"), Color("#64748B"), Color("#F97316"),
	Color("#DC2626"), Color("#0EA5E9"), Color("#84CC16"),
]

const MINI_ICONS: Array[String] = [
	"📡", "📻", "🔌", "🗼", "🏓", "🛡",
	"🔢", "🌧", "💰", "🔧", "📶", "📱",
]

const GRID_COLS: int = 4

var _scenes: Array = []
var _current_scene_idx: int = 0
var _minigame: Node3D
var _camera: Camera3D
var _selecting: bool = true
var _time: float = 0.0
var _draw_node: Control

func _ready() -> void:
	_scenes = [
		AntennaAlignScene, SpectrumSniperScene, CableRunScene,
		TowerClimbScene, PingPongScene, FirewallFrenzyScene, IPPuzzleScene,
		WeatherDodgeScene, BandwidthAuctionScene, TroubleshooterScene,
		WiFi7ChannelsScene, CBRSDeployScene,
	]
	_build_camera()
	_build_hud()

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 4, 8)
	_camera.rotation_degrees.x = -20
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	# Background for selection screen
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg_rect)

	_draw_node = _MiniGameSelectDraw.new()
	_draw_node.host = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	if _draw_node:
		_draw_node.queue_redraw()

func _start_minigame() -> void:
	_selecting = false
	if _draw_node:
		_draw_node.visible = false

	# Remove old mini-game if exists
	if _minigame:
		_minigame.queue_free()
		await get_tree().process_frame

	# Create mini-game
	_minigame = _scenes[_current_scene_idx].instantiate()
	add_child(_minigame)

	# Get the MiniGameBase child and connect completion
	await get_tree().process_frame
	var base = _minigame.get_child(0) if _minigame.get_child_count() > 0 else null
	if base and base.has_signal("game_completed"):
		base.game_completed.connect(_on_minigame_completed)

	# Start
	var pids: Array[int] = [1, 2]
	_minigame.start(pids)

func _on_minigame_completed(results: Dictionary) -> void:
	_selecting = true
	if _draw_node:
		_draw_node.visible = true
	if _minigame:
		_minigame.queue_free()
		_minigame = null

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	if _selecting:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_current_scene_idx = (_current_scene_idx - 1 + _scenes.size()) % _scenes.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_RIGHT, KEY_D:
				_current_scene_idx = (_current_scene_idx + 1) % _scenes.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_UP, KEY_W:
				_current_scene_idx = (_current_scene_idx - GRID_COLS + _scenes.size()) % _scenes.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_DOWN, KEY_S:
				_current_scene_idx = (_current_scene_idx + GRID_COLS) % _scenes.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_ENTER, KEY_SPACE:
				if AudioManager:
					AudioManager.play_sfx("menu_select")
				_start_minigame()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
	else:
		match event.keycode:
			KEY_ESCAPE:
				# Return to selection from active game
				_selecting = true
				if _draw_node:
					_draw_node.visible = true
				if _minigame:
					_minigame.queue_free()
					_minigame = null
			KEY_R:
				_selecting = true
				if _draw_node:
					_draw_node.visible = true
				if _minigame:
					_minigame.queue_free()
					_minigame = null


class _MiniGameSelectDraw extends Control:
	var host: Node

	func _draw() -> void:
		if host == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = host._time

		# ═══════════ HEADER ═══════════
		var header_h: float = 80.0
		draw_rect(Rect2(0, 0, s.x, header_h), PANEL)
		draw_rect(Rect2(0, header_h - 2, s.x, 2), Color(ACCENT, 0.5))

		draw_string(font, Vector2(30, 35), "SIGNAL SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ACCENT, 0.6))
		draw_string(font, Vector2(30, 62), "MINI-GAME SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ACCENT)

		# Game count
		var count_text: String = "%d GAMES AVAILABLE" % host._scenes.size()
		draw_string(font, Vector2(s.x - 260, 50), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(DIM, 0.7))

		# ═══════════ CARD GRID ═══════════
		var grid_top: float = header_h + 20
		var margin_x: float = 40.0
		var grid_w: float = s.x - margin_x * 2.0
		var cols: int = GRID_COLS
		var rows: int = ceili(float(host._scenes.size()) / cols)
		var card_gap: float = 14.0
		var card_w: float = (grid_w - (cols - 1) * card_gap) / cols
		var card_h: float = mini((s.y - grid_top - 100) / rows - card_gap, 160.0)

		for i in range(host._scenes.size()):
			var col: int = i % cols
			var row: int = i / cols
			var cx: float = margin_x + col * (card_w + card_gap)
			var cy: float = grid_top + row * (card_h + card_gap)
			var is_sel: bool = i == host._current_scene_idx
			var card_color: Color = MINI_COLORS[i] if i < MINI_COLORS.size() else ACCENT

			# Card background
			if is_sel:
				var pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(card_color, 0.15 + pulse * 0.1))
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(card_color, 0.7 + pulse * 0.3), false, 3.0)
			else:
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(PANEL, 0.8))
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(card_color, 0.25), false, 1.5)

			# Color accent bar at top
			draw_rect(Rect2(cx, cy, card_w, 4), card_color)

			# Icon
			var icon_str: String = MINI_ICONS[i] if i < MINI_ICONS.size() else "?"
			draw_string(font, Vector2(cx + 12, cy + 36), icon_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

			# Game name
			var name_str: String = MINI_NAMES[i] if i < MINI_NAMES.size() else "GAME %d" % (i + 1)
			var name_col: Color = card_color if is_sel else Color(TEXT, 0.8)
			draw_string(font, Vector2(cx + 48, cy + 34), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, name_col)

			# Description (multiline)
			var desc_str: String = MINI_DESCS[i] if i < MINI_DESCS.size() else ""
			var desc_lines: PackedStringArray = desc_str.split("\n")
			var desc_y: float = cy + 58
			for line in desc_lines:
				draw_string(font, Vector2(cx + 12, desc_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(TEXT, 0.5))
				desc_y += 17.0

			# Index badge
			var idx_text: String = "%d" % (i + 1)
			draw_string(font, Vector2(cx + card_w - 24, cy + 20), idx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(DIM, 0.5))

		# ═══════════ BOTTOM NAV ═══════════
		var bottom_y := s.y - 50
		draw_rect(Rect2(0, bottom_y, s.x, 50), Color(PANEL, 0.9))
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		var nav_text: String = "Arrow Keys / WASD  Navigate  |  ENTER  Start Game  |  ESC  Back to Menu"
		draw_string(font, Vector2(30, bottom_y + 32), nav_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))

		# Selected game info on right side of nav bar
		var sel_name: String = MINI_NAMES[host._current_scene_idx] if host._current_scene_idx < MINI_NAMES.size() else ""
		draw_string(font, Vector2(s.x - 280, bottom_y + 32), "Selected: %s" % sel_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ACCENT, 0.7))

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
