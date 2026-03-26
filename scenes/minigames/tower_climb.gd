extends Node3D
## Tower Climb Race Mini-Game
## Players race to climb a tower by tapping buttons rhythmically.
## Tap too fast without pause = slip back. Secure harness at checkpoints.
##
## Teaches: Pacing, risk management, checkpoint discipline

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const MAX_HEIGHT: float = 100.0
const CLIMB_AMOUNT: float = 5.0
const SLIP_PENALTY: float = 10.0
const CHECKPOINT_SKIP_PENALTY: float = 15.0
const TAP_COOLDOWN: float = 0.3
const CHECKPOINTS: Array[float] = [25.0, 50.0, 75.0]

var _base: Node3D

# Per player
var _player_height: Dictionary = {}        # { pid: float }
var _player_last_tap: Dictionary = {}      # { pid: float } — time of last tap
var _player_secured: Dictionary = {}       # { pid: Array[bool] } — checkpoint secured flags
var _player_finished: Dictionary = {}      # { pid: bool }
var _player_slip_flash: Dictionary = {}    # { pid: float } — visual flash timer

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Tower Climb"
	_base.concept_taught = "Pacing, risk management, checkpoint discipline"
	_base.duration_seconds = 45.0
	_base.buff_stat = "speed"
	_base.buff_value = 15
	_base.music_index = 3
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	for pid in _base.player_ids:
		_player_height[pid] = 0.0
		_player_last_tap[pid] = -1.0
		_player_secured[pid] = [false, false, false]
		_player_finished[pid] = false
		_player_slip_flash[pid] = 0.0

func _process(delta: float) -> void:
	if not _base.is_running:
		return
	_process_inputs(delta)
	# Update slip flash timers
	for pid in _base.player_ids:
		if _player_slip_flash[pid] > 0.0:
			_player_slip_flash[pid] -= delta

func _process_inputs(_delta: float) -> void:
	# P1 — confirm = J/attack, action = J/attack alternate (we use attack for confirm, jump for action)
	if 1 in _base.player_ids and not _player_finished[1]:
		if Input.is_action_just_pressed("attack"):
			_try_climb(1)
		if Input.is_action_just_pressed("jump"):
			_try_secure(1)

	# P2 — confirm = L/Shift, action = L/Shift alternate
	if 2 in _base.player_ids and not _player_finished[2]:
		if Input.is_key_pressed(KEY_L) and Engine.get_physics_frames() % 15 == 0:
			pass  # We need just_pressed behavior for L
		if Input.is_key_pressed(KEY_SHIFT):
			pass
		# Use frame-based debounce for P2
		if Input.is_key_pressed(KEY_L) and not Input.is_key_pressed(KEY_SHIFT):
			if Engine.get_physics_frames() % 10 == 0:
				_try_climb(2)
		if Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_L):
			if Engine.get_physics_frames() % 10 == 0:
				_try_secure(2)

func _try_climb(pid: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = _player_last_tap[pid]
	var elapsed: float = now - last if last >= 0.0 else 999.0

	# Check if tapping too fast (no cooldown respected)
	if elapsed < TAP_COOLDOWN:
		# Slip!
		_player_height[pid] = maxf(_player_height[pid] - SLIP_PENALTY, 0.0)
		_player_slip_flash[pid] = 0.5
		_player_last_tap[pid] = now
		if AudioManager:
			AudioManager.play_sfx("hit_light")
		return

	# Check if skipped a checkpoint (not secured)
	var next_checkpoint_idx: int = _get_next_unsecured_checkpoint(pid)
	if next_checkpoint_idx >= 0:
		var cp_height: float = CHECKPOINTS[next_checkpoint_idx]
		if _player_height[pid] < cp_height and _player_height[pid] + CLIMB_AMOUNT >= cp_height:
			if not _player_secured[pid][next_checkpoint_idx]:
				# Climbing past unsecured checkpoint — slip!
				_player_height[pid] = maxf(_player_height[pid] - CHECKPOINT_SKIP_PENALTY, 0.0)
				_player_slip_flash[pid] = 0.8
				_player_last_tap[pid] = now
				if AudioManager:
					AudioManager.play_sfx("ko")
				return

	# Normal climb
	_player_height[pid] = minf(_player_height[pid] + CLIMB_AMOUNT, MAX_HEIGHT)
	_player_last_tap[pid] = now
	if AudioManager:
		AudioManager.play_sfx("align_beep")

	# Check win
	if _player_height[pid] >= MAX_HEIGHT:
		_player_finished[pid] = true
		_base.add_score(pid, 500.0)
		if AudioManager:
			AudioManager.play_sfx("signal_lock")

func _try_secure(pid: int) -> void:
	# Find nearest unsecured checkpoint within range
	for i in range(CHECKPOINTS.size()):
		if _player_secured[pid][i]:
			continue
		var cp: float = CHECKPOINTS[i]
		if absf(_player_height[pid] - cp) <= 3.0:
			_player_secured[pid][i] = true
			_base.add_score(pid, 50.0)
			if AudioManager:
				AudioManager.play_sfx("score")
			return

func _get_next_unsecured_checkpoint(pid: int) -> int:
	for i in range(CHECKPOINTS.size()):
		if not _player_secured[pid][i]:
			return i
	return -1

# ═══════════ DRAWING ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _TowerDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _TowerDraw extends Control:
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
		draw_string(font, Vector2(s.x / 2.0 - 80, 35), "TOWER CLIMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#06B6D4"))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var tc: Color = Color("#22C55E") if time_left > 10 else Color("#EF4444")
		draw_string(font, Vector2(s.x - 80, 35), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tc)

		# Draw towers for each player
		var tower_width: float = 80.0
		var tower_height: float = s.y - 180.0
		var tower_bottom: float = s.y - 80.0

		for pid in game._base.player_ids:
			var tower_x: float = s.x * 0.25 if pid == 1 else s.x * 0.75
			tower_x -= tower_width / 2.0
			var player_color: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var name_str: String = "RICO" if pid == 1 else "VERO"

			# Tower background
			draw_rect(Rect2(tower_x, tower_bottom - tower_height, tower_width, tower_height), Color("#1E293B"))
			draw_rect(Rect2(tower_x, tower_bottom - tower_height, tower_width, tower_height), Color("#374151"), false, 2.0)

			# Checkpoints
			for i in range(game.CHECKPOINTS.size()):
				var cp: float = game.CHECKPOINTS[i]
				var cp_y: float = tower_bottom - (cp / game.MAX_HEIGHT) * tower_height
				var secured: bool = game._player_secured[pid][i] if pid in game._player_secured else false
				var cp_color: Color = Color("#22C55E") if secured else Color("#F59E0B")
				draw_line(Vector2(tower_x, cp_y), Vector2(tower_x + tower_width, cp_y), cp_color, 2.0)
				var cp_label: String = "%d" % int(cp)
				if secured:
					cp_label += " OK"
				draw_string(font, Vector2(tower_x + tower_width + 5, cp_y + 5), cp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cp_color)

			# Finish line
			var finish_y: float = tower_bottom - tower_height
			draw_line(Vector2(tower_x, finish_y), Vector2(tower_x + tower_width, finish_y), Color("#22C55E"), 3.0)
			draw_string(font, Vector2(tower_x + tower_width + 5, finish_y + 5), "100 TOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#22C55E"))

			# Player dot
			var height: float = game._player_height.get(pid, 0.0)
			var dot_y: float = tower_bottom - (height / game.MAX_HEIGHT) * tower_height
			var dot_color: Color = player_color
			if game._player_slip_flash.get(pid, 0.0) > 0.0:
				dot_color = Color("#EF4444")
			draw_circle(Vector2(tower_x + tower_width / 2.0, dot_y), 12.0, dot_color)

			# Player name and height
			draw_string(font, Vector2(tower_x, tower_bottom + 25), "%s: %.0f" % [name_str, height], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, player_color)

			# Finished indicator
			if game._player_finished.get(pid, false):
				draw_string(font, Vector2(tower_x, tower_bottom - tower_height - 25), "SUMMIT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#22C55E"))

			# Score
			var score: float = game._base.scores.get(pid, 0.0)
			draw_string(font, Vector2(tower_x, tower_bottom + 50), "%.0f pts" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, player_color)

		# Instructions
		draw_string(font, Vector2(40, s.y - 15), "P1: J climb | Space secure harness", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 280, s.y - 15), "P2: L climb | Shift secure harness", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))

		# Rhythm hint
		draw_string(font, Vector2(s.x / 2.0 - 120, 65), "Tap rhythmically! Too fast = SLIP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#F59E0B", 0.6))
