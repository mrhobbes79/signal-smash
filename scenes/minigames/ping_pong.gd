extends Node3D
## Ping Pong (Packet Pong) Mini-Game
## Classic pong but the ball is a "packet" bouncing between players.
## Ball speed increases each rally. Score when ball passes opponent's paddle.
##
## Teaches: Packet routing, latency, timing

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const PADDLE_SPEED: float = 400.0
const PADDLE_HEIGHT: float = 80.0
const PADDLE_WIDTH: float = 12.0
const BALL_SIZE: float = 10.0
const BALL_START_SPEED: float = 300.0
const BALL_SPEED_INCREMENT: float = 15.0
const BALL_MAX_SPEED: float = 700.0
const FIELD_MARGIN: float = 60.0

var _base: Node3D

# Game state
var _paddle_y: Dictionary = {}    # { pid: float }
var _ball_pos: Vector2 = Vector2.ZERO
var _ball_vel: Vector2 = Vector2.ZERO
var _ball_speed: float = BALL_START_SPEED
var _rally_count: int = 0
var _score_flash: float = 0.0
var _last_scorer: int = 0

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Packet Pong"
	_base.concept_taught = "Packet routing, latency, timing"
	_base.duration_seconds = 30.0
	_base.buff_stat = "speed"
	_base.buff_value = 10
	_base.music_index = 4
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	for pid in _base.player_ids:
		_paddle_y[pid] = 0.0  # Will be set relative to screen center
	_reset_ball(0)

func _reset_ball(direction: int) -> void:
	_ball_pos = Vector2.ZERO  # Center — adjusted in draw
	_ball_speed = BALL_START_SPEED + _rally_count * BALL_SPEED_INCREMENT * 0.5
	_ball_speed = minf(_ball_speed, BALL_MAX_SPEED)
	var angle: float = randf_range(-0.5, 0.5)
	if direction == 0:
		direction = 1 if randf() > 0.5 else -1
	_ball_vel = Vector2(direction * _ball_speed * cos(angle), _ball_speed * sin(angle))
	_rally_count = 0

func _process(delta: float) -> void:
	if not _base.is_running:
		return
	_process_inputs(delta)
	_update_ball(delta)
	if _score_flash > 0.0:
		_score_flash -= delta

func _process_inputs(delta: float) -> void:
	# P1 — WASD vertical
	if 1 in _base.player_ids:
		var v: float = 0.0
		if Input.is_action_pressed("move_forward"):
			v = -1.0
		elif Input.is_action_pressed("move_back"):
			v = 1.0
		_paddle_y[1] += v * PADDLE_SPEED * delta

	# P2 — Arrows vertical
	if 2 in _base.player_ids:
		var v: float = 0.0
		if Input.is_key_pressed(KEY_UP):
			v = -1.0
		elif Input.is_key_pressed(KEY_DOWN):
			v = 1.0
		_paddle_y[2] += v * PADDLE_SPEED * delta

func _update_ball(delta: float) -> void:
	# Ball uses screen-relative coordinates calculated in _draw
	# We store abstract positions and use field dimensions
	_ball_pos += _ball_vel * delta

	# Bounce off top/bottom (field height set to ~500 centered)
	var half_field_h: float = 250.0
	if _ball_pos.y < -half_field_h + BALL_SIZE:
		_ball_pos.y = -half_field_h + BALL_SIZE
		_ball_vel.y = absf(_ball_vel.y)
	elif _ball_pos.y > half_field_h - BALL_SIZE:
		_ball_pos.y = half_field_h - BALL_SIZE
		_ball_vel.y = -absf(_ball_vel.y)

	# Clamp paddles
	for pid in _base.player_ids:
		_paddle_y[pid] = clampf(_paddle_y[pid], -half_field_h + PADDLE_HEIGHT / 2.0, half_field_h - PADDLE_HEIGHT / 2.0)

	# Paddle collision
	var half_field_w: float = 350.0
	var paddle_x_offset: float = half_field_w - 20.0

	# P1 paddle (left)
	if 1 in _base.player_ids:
		if _ball_pos.x < -paddle_x_offset + PADDLE_WIDTH and _ball_vel.x < 0:
			if absf(_ball_pos.y - _paddle_y[1]) < PADDLE_HEIGHT / 2.0:
				_ball_vel.x = absf(_ball_vel.x)
				# Add spin based on where ball hits paddle
				var offset: float = (_ball_pos.y - _paddle_y[1]) / (PADDLE_HEIGHT / 2.0)
				_ball_vel.y += offset * 100.0
				_rally_count += 1
				_ball_speed = minf(_ball_speed + BALL_SPEED_INCREMENT, BALL_MAX_SPEED)
				_ball_vel = _ball_vel.normalized() * _ball_speed
				if AudioManager:
					AudioManager.play_sfx("align_beep")

	# P2 paddle (right)
	if 2 in _base.player_ids:
		if _ball_pos.x > paddle_x_offset - PADDLE_WIDTH and _ball_vel.x > 0:
			if absf(_ball_pos.y - _paddle_y[2]) < PADDLE_HEIGHT / 2.0:
				_ball_vel.x = -absf(_ball_vel.x)
				var offset: float = (_ball_pos.y - _paddle_y[2]) / (PADDLE_HEIGHT / 2.0)
				_ball_vel.y += offset * 100.0
				_rally_count += 1
				_ball_speed = minf(_ball_speed + BALL_SPEED_INCREMENT, BALL_MAX_SPEED)
				_ball_vel = _ball_vel.normalized() * _ball_speed
				if AudioManager:
					AudioManager.play_sfx("align_beep")

	# Score detection
	if _ball_pos.x < -half_field_w - 20:
		# P2 scores
		if 2 in _base.player_ids:
			_base.add_score(2, 100.0)
			_last_scorer = 2
		_score_flash = 0.5
		_reset_ball(-1)
		if AudioManager:
			AudioManager.play_sfx("score")
	elif _ball_pos.x > half_field_w + 20:
		# P1 scores
		if 1 in _base.player_ids:
			_base.add_score(1, 100.0)
			_last_scorer = 1
		_score_flash = 0.5
		_reset_ball(1)
		if AudioManager:
			AudioManager.play_sfx("score")

# ═══════════ DRAWING ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _PongDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _PongDraw extends Control:
	var game: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var cx: float = s.x / 2.0
		var cy: float = s.y / 2.0

		# Background
		draw_rect(Rect2(0, 0, s.x, s.y), Color("#0F172A"))

		# Title
		draw_string(font, Vector2(cx - 70, 30), "PACKET PONG", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#06B6D4"))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var tc: Color = Color("#22C55E") if time_left > 10 else Color("#EF4444")
		draw_string(font, Vector2(s.x - 80, 30), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tc)

		# Field boundary
		var field_x: float = game.FIELD_MARGIN
		var field_y: float = 60.0
		var field_w: float = s.x - game.FIELD_MARGIN * 2
		var field_h: float = s.y - 140.0
		draw_rect(Rect2(field_x, field_y, field_w, field_h), Color("#1E293B"))
		draw_rect(Rect2(field_x, field_y, field_w, field_h), Color("#374151"), false, 2.0)

		# Center line (dashed)
		var dash_len: float = 15.0
		var dash_y: float = field_y
		while dash_y < field_y + field_h:
			draw_line(Vector2(cx, dash_y), Vector2(cx, minf(dash_y + dash_len, field_y + field_h)), Color("#374151"), 2.0)
			dash_y += dash_len * 2

		# Map game coordinates to screen
		var half_field_w: float = 350.0
		var half_field_h: float = 250.0
		var scale_x: float = field_w / (half_field_w * 2.0)
		var scale_y: float = field_h / (half_field_h * 2.0)

		# Paddles
		for pid in game._base.player_ids:
			var paddle_screen_x: float
			var player_color: Color
			if pid == 1:
				paddle_screen_x = field_x + 20
				player_color = Color("#2563EB")
			else:
				paddle_screen_x = field_x + field_w - 20 - game.PADDLE_WIDTH
				player_color = Color("#7C3AED")

			var paddle_screen_y: float = cy + game._paddle_y.get(pid, 0.0) * scale_y - game.PADDLE_HEIGHT * scale_y / 2.0
			draw_rect(Rect2(paddle_screen_x, paddle_screen_y, game.PADDLE_WIDTH, game.PADDLE_HEIGHT * scale_y), player_color)

		# Ball (packet)
		var ball_screen_x: float = cx + game._ball_pos.x * scale_x
		var ball_screen_y: float = cy + game._ball_pos.y * scale_y
		var ball_color: Color = Color("#22C55E")
		draw_circle(Vector2(ball_screen_x, ball_screen_y), game.BALL_SIZE, ball_color)
		# Packet trail effect
		var trail_pos: Vector2 = Vector2(ball_screen_x, ball_screen_y) - game._ball_vel.normalized() * 15.0 * scale_x
		draw_circle(trail_pos, game.BALL_SIZE * 0.6, Color(ball_color, 0.4))

		# Rally counter
		draw_string(font, Vector2(cx - 20, field_y + field_h + 20), "Rally: %d" % game._rally_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0", 0.5))

		# Score flash
		if game._score_flash > 0.0:
			var flash_alpha: float = game._score_flash / 0.5
			var scorer_name: String = "RICO" if game._last_scorer == 1 else "VERO"
			draw_string(font, Vector2(cx - 40, cy), "POINT %s!" % scorer_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#F59E0B", flash_alpha))

		# Scores
		for pid in game._base.player_ids:
			var score: float = game._base.scores.get(pid, 0.0)
			var name_str: String = "RICO" if pid == 1 else "VERO"
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var sx: float = 40 if pid == 1 else s.x - 200
			draw_string(font, Vector2(sx, s.y - 20), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Speed indicator
		var speed_pct: float = game._ball_speed / game.BALL_MAX_SPEED * 100.0
		draw_string(font, Vector2(cx - 30, field_y + field_h + 40), "Speed: %.0f%%" % speed_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F59E0B", 0.5))

		# Controls
		draw_string(font, Vector2(40, s.y - 5), "P1: W/S move paddle", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 200, s.y - 5), "P2: Up/Down move paddle", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
