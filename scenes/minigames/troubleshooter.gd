extends Node3D
## The Troubleshooter Mini-Game
## Customer calls with network problems. Diagnose the root cause.
## Read diagnostic clues and select the correct answer from A/B/C/D.
##
## Teaches: Network troubleshooting, diagnostic reading, root cause analysis

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const TOTAL_CASES: int = 5
const CORRECT_POINTS: float = 100.0
const SPEED_BONUS: float = 50.0
const SPEED_THRESHOLD: float = 3.0  # Seconds — answer under this for bonus
const NAV_COOLDOWN: float = 0.2     # Seconds between option changes

var _base: Node3D

# Case data
var _cases: Array[Dictionary] = []
var _current_case: int = -1
var _case_timer: float = 0.0
var _case_active: bool = false
var _case_resolved: bool = false
var _resolve_timer: float = 0.0  # Brief pause between cases

# Per-player state
var _player_selection: Dictionary = {}   # { pid: int } — 0-3 (A/B/C/D)
var _player_answered: Dictionary = {}    # { pid: bool }
var _player_nav_cooldown: Dictionary = {} # { pid: float }

var _p2_prev_keys := {}

func _p2_just_pressed(key: int) -> bool:
	var currently: bool = Input.is_key_pressed(key)
	var was: bool = _p2_prev_keys.get(key, false)
	_p2_prev_keys[key] = currently
	return currently and not was

# Feedback
var _last_results: Dictionary = {}  # { pid: { correct: bool, points: float } }

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "The Troubleshooter"
	_base.concept_taught = "Network troubleshooting, diagnostics, root cause analysis"
	_base.duration_seconds = 60.0
	_base.buff_stat = "range"
	_base.buff_value = 15
	_base.music_index = 5
	add_child(_base)

	_build_cases()

func _build_cases() -> void:
	_cases = [
		{
			"complaint": "Customer says internet is very slow, pages take forever to load.",
			"clues": [
				"Ping: 250ms average (normally 15ms)",
				"Signal: -52 dBm (good)",
				"Error rate: 0.1% (normal)",
			],
			"options": ["A) Congestion", "B) Cable fault", "C) Interference", "D) Alignment"],
			"correct": 0,
			"answer_label": "CONGESTION — High latency with good signal = network overload",
		},
		{
			"complaint": "Customer has zero connectivity. Nothing works at all.",
			"clues": [
				"Ping: Request timed out",
				"Signal: No signal detected",
				"Error rate: N/A",
			],
			"options": ["A) Wrong channel", "B) Cable disconnected", "C) Interference", "D) Congestion"],
			"correct": 1,
			"answer_label": "CABLE DISCONNECTED — No signal at all = physical layer issue",
		},
		{
			"complaint": "Connection drops randomly throughout the day, then comes back.",
			"clues": [
				"Ping: 12ms when working, timeout when not",
				"Signal: Fluctuates -55 to -78 dBm",
				"Error rate: 8.5% (very high)",
			],
			"options": ["A) Congestion", "B) Wrong firmware", "C) Interference", "D) Bad password"],
			"correct": 2,
			"answer_label": "INTERFERENCE — Intermittent drops + signal fluctuation = RF interference",
		},
		{
			"complaint": "Customer connected but speed test shows 20 Mbps on a 100 Mbps plan.",
			"clues": [
				"Ping: 8ms (excellent)",
				"Signal: -48 dBm (excellent)",
				"Channel width: 20 MHz (should be 80 MHz)",
			],
			"options": ["A) Cable fault", "B) Alignment", "C) Congestion", "D) Wrong channel width"],
			"correct": 3,
			"answer_label": "WRONG CHANNEL WIDTH — Good signal, low throughput = bandwidth config issue",
		},
		{
			"complaint": "VoIP calls have choppy audio and video freezes on Zoom.",
			"clues": [
				"Ping: 18ms (good)",
				"Signal: -61 dBm (marginal)",
				"Packet loss: 4.2% (high, should be <0.5%)",
			],
			"options": ["A) Alignment issue", "B) Congestion", "C) Wrong channel", "D) Bad cable"],
			"correct": 0,
			"answer_label": "ALIGNMENT ISSUE — Marginal signal + packet loss = dish needs realignment",
		},
	]

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_start_game()

func _start_game() -> void:
	_current_case = -1
	_last_results.clear()
	for pid in _base.player_ids:
		_player_selection[pid] = 0
		_player_answered[pid] = false
		_player_nav_cooldown[pid] = 0.0

	_build_environment()
	_next_case()

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0F172A")
	env.ambient_light_color = Color("#22C55E")
	env.ambient_light_energy = 0.3
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.6
	add_child(sun)

func _next_case() -> void:
	_current_case += 1
	if _current_case >= TOTAL_CASES:
		return

	_case_timer = 0.0
	_case_active = true
	_case_resolved = false
	_last_results.clear()

	for pid in _base.player_ids:
		_player_selection[pid] = 0
		_player_answered[pid] = false

func _resolve_case() -> void:
	_case_active = false
	_case_resolved = true
	_resolve_timer = 2.5  # Show result for 2.5 seconds

	var case_data: Dictionary = _cases[_current_case]
	for pid in _base.player_ids:
		var sel: int = _player_selection.get(pid, -1)
		var is_correct: bool = sel == case_data["correct"]
		var points: float = 0.0
		if is_correct:
			points = CORRECT_POINTS
			if _case_timer < SPEED_THRESHOLD:
				points += SPEED_BONUS
			_base.add_score(pid, points)
		_last_results[pid] = { "correct": is_correct, "points": points }

func _process(delta: float) -> void:
	if not _base.is_running:
		return

	if _current_case >= TOTAL_CASES:
		return

	if _case_active:
		_case_timer += delta
		_process_inputs(delta)

		# Check if all players answered
		var all_answered: bool = true
		for pid in _base.player_ids:
			if not _player_answered.get(pid, false):
				all_answered = false
				break
		if all_answered:
			_resolve_case()

	elif _case_resolved:
		_resolve_timer -= delta
		if _resolve_timer <= 0.0:
			_next_case()

func _process_inputs(delta: float) -> void:
	# Update cooldowns
	for pid in _base.player_ids:
		if _player_nav_cooldown.get(pid, 0.0) > 0:
			_player_nav_cooldown[pid] -= delta

	# P1 (WASD + J to confirm)
	if 1 in _base.player_ids and not _player_answered.get(1, false):
		if _player_nav_cooldown.get(1, 0.0) <= 0:
			var p1_v: float = Input.get_axis("move_forward", "move_back")  # Inverted: up = previous
			if p1_v < -0.5:
				_player_selection[1] = maxi(_player_selection[1] - 1, 0)
				_player_nav_cooldown[1] = NAV_COOLDOWN
				if AudioManager:
					AudioManager.play_sfx("align_beep")
			elif p1_v > 0.5:
				_player_selection[1] = mini(_player_selection[1] + 1, 3)
				_player_nav_cooldown[1] = NAV_COOLDOWN
				if AudioManager:
					AudioManager.play_sfx("align_beep")
		if Input.is_action_just_pressed("attack"):
			_player_answered[1] = true
			if AudioManager:
				AudioManager.play_sfx("signal_lock")

	# P2 (Arrows + L to confirm)
	if 2 in _base.player_ids and not _player_answered.get(2, false):
		if _p2_just_pressed(KEY_UP):
			_player_selection[2] = maxi(_player_selection[2] - 1, 0)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		elif _p2_just_pressed(KEY_DOWN):
			_player_selection[2] = mini(_player_selection[2] + 1, 3)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if _p2_just_pressed(KEY_SHIFT) or _p2_just_pressed(KEY_L):
			_player_answered[2] = true
			if AudioManager:
				AudioManager.play_sfx("signal_lock")

# ═══════════ DRAWING via CanvasLayer ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _TroubleshootDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _TroubleshootDraw extends Control:
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

		# Title
		draw_string(font, Vector2(s.x / 2.0 - 120, 35), "THE TROUBLESHOOTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#22C55E"))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var timer_col: Color = Color("#22C55E") if time_left > 20 else (Color("#F59E0B") if time_left > 10 else Color("#EF4444"))
		draw_string(font, Vector2(s.x - 80, 35), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, timer_col)

		# Case counter
		var case_num: int = mini(game._current_case + 1, game.TOTAL_CASES)
		draw_string(font, Vector2(s.x / 2.0 - 50, 60), "Case %d / %d" % [case_num, game.TOTAL_CASES], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0", 0.6))

		if game._current_case >= game.TOTAL_CASES:
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y / 2.0), "ALL CASES CLOSED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#22C55E"))
			_draw_final_scores(s, font)
			return

		var case_data: Dictionary = game._cases[game._current_case]

		# Complaint panel
		var complaint_y: float = 75
		draw_rect(Rect2(40, complaint_y, s.x - 80, 50), Color("#1E293B"))
		draw_string(font, Vector2(50, complaint_y + 18), "CUSTOMER COMPLAINT:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#EF4444"))
		draw_string(font, Vector2(50, complaint_y + 38), case_data["complaint"], HORIZONTAL_ALIGNMENT_LEFT, s.x - 100, 14, Color("#E2E8F0"))

		# Diagnostic clues panel
		var clue_y: float = 140
		draw_rect(Rect2(40, clue_y, s.x - 80, 90), Color("#1E293B", 0.8))
		draw_string(font, Vector2(50, clue_y + 18), "DIAGNOSTICS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#06B6D4"))

		var clues: Array = case_data["clues"]
		for i in range(clues.size()):
			var cy: float = clue_y + 38 + i * 22
			draw_string(font, Vector2(60, cy), "> " + clues[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0", 0.9))

		# Speed indicator
		if game._case_active:
			var elapsed: float = game._case_timer
			var speed_col: Color = Color("#22C55E") if elapsed < game.SPEED_THRESHOLD else Color("#F59E0B")
			draw_string(font, Vector2(s.x - 160, clue_y + 18), "%.1fs" % elapsed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, speed_col)
			if elapsed < game.SPEED_THRESHOLD:
				draw_string(font, Vector2(s.x - 160, clue_y + 38), "SPEED BONUS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#22C55E", 0.7))

		# Player answer panels — side by side
		var options: Array = case_data["options"]
		for pid in game._base.player_ids:
			var panel_x: float = s.x * 0.05 if pid == 1 else s.x * 0.55
			var panel_w: float = s.x * 0.4
			var panel_y: float = s.y * 0.42
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var name_str: String = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]

			draw_rect(Rect2(panel_x, panel_y, panel_w, s.y * 0.45), Color("#1E293B", 0.7))
			draw_string(font, Vector2(panel_x + 10, panel_y + 22), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)

			var answered: bool = game._player_answered.get(pid, false)
			var selection: int = game._player_selection.get(pid, 0)

			# Draw options
			for i in range(options.size()):
				var opt_y: float = panel_y + 40 + i * 40
				var opt_rect := Rect2(panel_x + 10, opt_y, panel_w - 20, 34)
				var is_selected: bool = (i == selection)

				# Background
				if answered and is_selected:
					draw_rect(opt_rect, Color(col, 0.4))
				elif is_selected:
					var pulse: float = (sin(Time.get_ticks_msec() * 0.006) + 1.0) / 2.0
					draw_rect(opt_rect, Color(col, 0.15 + pulse * 0.15))
				else:
					draw_rect(opt_rect, Color("#374151", 0.3))

				# Selection indicator
				if is_selected:
					draw_rect(Rect2(panel_x + 10, opt_y, 4, 34), col)

				# Text
				var text_col: Color = Color.WHITE if is_selected else Color("#E2E8F0", 0.6)
				draw_string(font, Vector2(panel_x + 22, opt_y + 22), options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_col)

			# Status
			if answered:
				draw_string(font, Vector2(panel_x + 10, panel_y + 210), "ANSWER LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#22C55E"))
			else:
				draw_string(font, Vector2(panel_x + 10, panel_y + 210), "Navigate + Confirm", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.4))

			# Score
			var score: float = game._base.scores.get(pid, 0.0)
			draw_string(font, Vector2(panel_x + 10, panel_y + s.y * 0.45 - 20), "SCORE: %.0f" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Show result if case resolved
		if game._case_resolved:
			var result_y: float = s.y * 0.35
			draw_rect(Rect2(0, result_y - 10, s.x, 30), Color("#0F172A", 0.9))
			draw_string(font, Vector2(s.x / 2.0 - 200, result_y + 12), case_data["answer_label"], HORIZONTAL_ALIGNMENT_LEFT, s.x, 15, Color("#22C55E"))

			for pid in game._base.player_ids:
				var res: Dictionary = game._last_results.get(pid, {})
				var panel_x: float = s.x * 0.05 if pid == 1 else s.x * 0.55
				var ry: float = s.y * 0.42 + 230
				if res.get("correct", false):
					var pts: float = res.get("points", 0.0)
					draw_string(font, Vector2(panel_x + 10, ry), "CORRECT! +%.0f" % pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#22C55E"))
				else:
					draw_string(font, Vector2(panel_x + 10, ry), "WRONG +0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#EF4444"))

		# Controls
		draw_string(font, Vector2(40, s.y - 15), "P1: W/S navigate | J submit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 260, s.y - 15), "P2: Up/Down navigate | L submit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))

	func _draw_final_scores(s: Vector2, font: Font) -> void:
		for pid in game._base.player_ids:
			var score: float = game._base.scores.get(pid, 0.0)
			var name_str: String = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var sx: float = s.x * 0.2 if pid == 1 else s.x * 0.6
			draw_string(font, Vector2(sx, s.y * 0.6), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
