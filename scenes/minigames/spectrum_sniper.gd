extends Node3D
## Spectrum Sniper Mini-Game
## Waterfall spectrum display. Find the cleanest channel and lock in before opponent.
## Channels change every 5 seconds simulating dynamic RF environment.
## Teaches: Spectrum analysis, channel selection, interference

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const NUM_CHANNELS: int = 12
const CHANNEL_CHANGE_INTERVAL: float = 5.0
const LOCK_TIME: float = 1.0  # Hold on channel for 1s to lock
const SCORE_PER_LOCK: float = 100.0

var _base: Node3D
var _channel_noise: Array[float] = []  # Interference level per channel (0=clean, 1=noisy)
var _change_timer: float = 0.0

# Per player
var _player_cursor: Dictionary = {}     # { pid: int } — current channel index
var _player_lock_timer: Dictionary = {} # { pid: float } — time held on current channel
var _player_locked_channel: Dictionary = {} # { pid: int } — last locked channel (-1 = none)
var _player_labels: Dictionary = {}

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Spectrum Sniper"
	_base.concept_taught = "Spectrum analysis, channel selection"
	_base.duration_seconds = 45.0
	_base.buff_stat = "power"
	_base.buff_value = 20
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_randomize_channels()
	_change_timer = CHANNEL_CHANGE_INTERVAL

	for pid in _base.player_ids:
		_player_cursor[pid] = NUM_CHANNELS / 2
		_player_lock_timer[pid] = 0.0
		_player_locked_channel[pid] = -1

	_build_environment()

func _randomize_channels() -> void:
	_channel_noise.clear()
	# Generate noise levels — most channels noisy, 2-3 clean
	for i in range(NUM_CHANNELS):
		_channel_noise.append(randf_range(0.3, 1.0))
	# Make 2-3 channels clean
	var clean_count: int = randi_range(2, 3)
	for c in range(clean_count):
		var idx: int = randi() % NUM_CHANNELS
		_channel_noise[idx] = randf_range(0.0, 0.15)

func _build_environment() -> void:
	# Dark background
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0F172A")
	env.ambient_light_color = Color("#06B6D4")
	env.ambient_light_energy = 0.4
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.8
	add_child(sun)

func _process(delta: float) -> void:
	if not _base.is_running:
		return

	# Channel change timer
	_change_timer -= delta
	if _change_timer <= 0.0:
		_randomize_channels()
		_change_timer = CHANNEL_CHANGE_INTERVAL
		# Reset locks
		for pid in _base.player_ids:
			_player_lock_timer[pid] = 0.0
			_player_locked_channel[pid] = -1

	# Process inputs
	_process_inputs(delta)

func _process_inputs(delta: float) -> void:
	# P1
	if 1 in _base.player_ids:
		if Input.is_action_just_pressed("move_left"):
			_player_cursor[1] = maxi(_player_cursor[1] - 1, 0)
			_player_lock_timer[1] = 0.0
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_action_just_pressed("move_right"):
			_player_cursor[1] = mini(_player_cursor[1] + 1, NUM_CHANNELS - 1)
			_player_lock_timer[1] = 0.0
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_action_pressed("attack"):
			_try_lock(1, delta)

	# P2
	if 2 in _base.player_ids:
		if Input.is_key_pressed(KEY_LEFT) and not Input.is_key_pressed(KEY_RIGHT):
			if Engine.get_physics_frames() % 10 == 0:
				_player_cursor[2] = maxi(_player_cursor[2] - 1, 0)
				_player_lock_timer[2] = 0.0
		if Input.is_key_pressed(KEY_RIGHT) and not Input.is_key_pressed(KEY_LEFT):
			if Engine.get_physics_frames() % 10 == 0:
				_player_cursor[2] = mini(_player_cursor[2] + 1, NUM_CHANNELS - 1)
				_player_lock_timer[2] = 0.0
		if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_L):
			_try_lock(2, delta)

func _try_lock(pid: int, delta: float) -> void:
	_player_lock_timer[pid] += delta
	if _player_lock_timer[pid] >= LOCK_TIME and _player_locked_channel[pid] != _player_cursor[pid]:
		# Lock successful!
		_player_locked_channel[pid] = _player_cursor[pid]
		var noise: float = _channel_noise[_player_cursor[pid]]
		var quality: float = 1.0 - noise  # Clean channel = high score
		var points: float = SCORE_PER_LOCK * quality
		_base.add_score(pid, points)
		_player_lock_timer[pid] = 0.0
		if AudioManager:
			if quality > 0.7:
				AudioManager.play_sfx("signal_lock")
			else:
				AudioManager.play_sfx("hit_light")
		print("[MINI] P%d locked CH%d — noise: %.0f%%, points: %.0f" % [pid, _player_cursor[pid] + 1, noise * 100, points])

# ═══════════ DRAWING via CanvasLayer ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _SpectrumDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _SpectrumDraw extends Control:
	var game: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var ch_width: float = (s.x - 80) / game.NUM_CHANNELS
		var graph_y: float = s.y * 0.25
		var graph_h: float = s.y * 0.45

		# Background
		draw_rect(Rect2(0, 0, s.x, s.y), Color("#0F172A"))

		# Title
		draw_string(font, Vector2(s.x / 2.0 - 100, 35), "SPECTRUM SNIPER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#06B6D4"))
		draw_string(font, Vector2(s.x / 2.0 - 130, 60), "Find the clean channel! Hold J/L to lock", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0", 0.5))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var timer_col: Color = Color("#22C55E") if time_left > 10 else (Color("#F59E0B") if time_left > 5 else Color("#EF4444"))
		draw_string(font, Vector2(s.x - 80, 35), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, timer_col)

		# Channel change warning
		if game._change_timer < 1.5:
			var flash: float = absf(sin(game._change_timer * 8.0))
			draw_string(font, Vector2(s.x / 2.0 - 80, 85), "CHANNELS SHIFTING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Color("#EF4444"), flash))

		# Spectrum waterfall
		for i in range(game.NUM_CHANNELS):
			var x: float = 40 + i * ch_width
			var noise: float = game._channel_noise[i]

			# Channel bar (height = noise level, inverted — tall = noisy = bad)
			var bar_h: float = graph_h * noise
			var bar_color: Color
			if noise < 0.2:
				bar_color = Color("#22C55E")  # Clean = green
			elif noise < 0.5:
				bar_color = Color("#F59E0B")  # Medium = yellow
			else:
				bar_color = Color("#EF4444")  # Noisy = red

			# Animated noise effect
			var noise_offset: float = sin(Time.get_ticks_msec() * 0.01 + i * 0.5) * graph_h * 0.05
			draw_rect(Rect2(x + 2, graph_y + graph_h - bar_h + noise_offset, ch_width - 4, bar_h), Color(bar_color, 0.7))

			# Channel label
			draw_string(font, Vector2(x + ch_width / 2.0 - 10, graph_y + graph_h + 20), "CH%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.5))

			# Noise percentage
			draw_string(font, Vector2(x + ch_width / 2.0 - 15, graph_y + graph_h + 38), "%.0f%%" % (noise * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, bar_color)

		# Player cursors
		for pid in game._base.player_ids:
			var cursor_ch: int = game._player_cursor.get(pid, 0)
			var cx: float = 40 + cursor_ch * ch_width
			var cursor_color: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var label: String = "P%d" % pid

			# Cursor triangle above channel
			var tri_y: float = graph_y - 25
			draw_rect(Rect2(cx, tri_y, ch_width, 18), Color(cursor_color, 0.8))
			draw_string(font, Vector2(cx + 5, tri_y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

			# Lock progress bar
			var lock_pct: float = game._player_lock_timer.get(pid, 0.0) / game.LOCK_TIME
			if lock_pct > 0.0:
				draw_rect(Rect2(cx, tri_y - 6, ch_width * lock_pct, 4), Color("#22C55E"))

			# Locked indicator
			var locked_ch: int = game._player_locked_channel.get(pid, -1)
			if locked_ch >= 0:
				var lx: float = 40 + locked_ch * ch_width
				draw_rect(Rect2(lx, graph_y + graph_h + 45, ch_width, 3), cursor_color)

		# Scores
		for pid in game._base.player_ids:
			var score: float = game._base.scores.get(pid, 0.0)
			var name_str: String = "RICO" if pid == 1 else "VERO"
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var sx: float = 40 if pid == 1 else s.x - 200
			draw_string(font, Vector2(sx, s.y - 40), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Controls reminder
		draw_string(font, Vector2(40, s.y - 15), "P1: A/D move | J lock", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 220, s.y - 15), "P2: ←/→ move | L lock", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
