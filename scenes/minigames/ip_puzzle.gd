extends Node3D
## IP Puzzle Mini-Game
## Players assemble correct IP addresses from number blocks.
## Navigate octets with horizontal, adjust values with vertical, submit with confirm.
##
## Teaches: IP addressing, subnetting, CIDR notation

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const CORRECT_PTS: float = 100.0
const WRONG_PTS: float = -20.0
const TOTAL_PUZZLES: int = 5
const OCTET_MIN: int = 0
const OCTET_MAX: int = 255
const VALUE_CHANGE_COOLDOWN: float = 0.08

var _base: Node3D

# Puzzle definitions: { target: "display string", octets: [int, int, int, int], cidr: int }
var _puzzles: Array[Dictionary] = []
var _current_puzzle: int = 0

# Per player
var _player_octets: Dictionary = {}          # { pid: [int, int, int, int] }
var _player_selected_octet: Dictionary = {}  # { pid: int } — 0-3
var _player_puzzle_index: Dictionary = {}    # { pid: int }
var _player_completed: Dictionary = {}       # { pid: int } — count of completed puzzles
var _player_value_timer: Dictionary = {}     # { pid: float }
var _player_flash: Dictionary = {}           # { pid: float } — feedback flash
var _player_flash_color: Dictionary = {}     # { pid: Color }

var _p2_prev_keys := {}

func _p2_just_pressed(key: int) -> bool:
	var currently: bool = Input.is_key_pressed(key)
	var was: bool = _p2_prev_keys.get(key, false)
	_p2_prev_keys[key] = currently
	return currently and not was

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "IP Puzzle"
	_base.concept_taught = "IP addressing, subnetting, CIDR notation"
	_base.duration_seconds = 30.0
	_base.buff_stat = "range"
	_base.buff_value = 10
	_base.music_index = 6
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_generate_puzzles()

	for pid in _base.player_ids:
		_player_octets[pid] = [0, 0, 0, 0]
		_player_selected_octet[pid] = 0
		_player_puzzle_index[pid] = 0
		_player_completed[pid] = 0
		_player_value_timer[pid] = 0.0
		_player_flash[pid] = 0.0
		_player_flash_color[pid] = Color.WHITE

func _generate_puzzles() -> void:
	_puzzles.clear()

	# Puzzle 1: Simple Class C network
	_puzzles.append({
		"display": "192.168.1.0/24",
		"octets": [192, 168, 1, 0],
		"hint": "Standard home network"
	})

	# Puzzle 2: Another Class C
	_puzzles.append({
		"display": "10.0.0.1/8",
		"octets": [10, 0, 0, 1],
		"hint": "Private Class A"
	})

	# Puzzle 3: Subnet gateway
	_puzzles.append({
		"display": "172.16.50.1/16",
		"octets": [172, 16, 50, 1],
		"hint": "Private Class B gateway"
	})

	# Puzzle 4: Specific subnet
	_puzzles.append({
		"display": "192.168.100.128/25",
		"octets": [192, 168, 100, 128],
		"hint": "Subnet with /25 mask"
	})

	# Puzzle 5: Tricky subnet
	_puzzles.append({
		"display": "10.255.255.254/8",
		"octets": [10, 255, 255, 254],
		"hint": "Last usable in 10.0.0.0/8"
	})

func _process(delta: float) -> void:
	if not _base.is_running:
		return
	_process_inputs(delta)
	# Update flash timers
	for pid in _base.player_ids:
		if _player_flash[pid] > 0.0:
			_player_flash[pid] -= delta

func _process_inputs(delta: float) -> void:
	# P1
	if 1 in _base.player_ids:
		_player_value_timer[1] -= delta
		if Input.is_action_just_pressed("move_left"):
			_player_selected_octet[1] = maxi(_player_selected_octet[1] - 1, 0)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_action_just_pressed("move_right"):
			_player_selected_octet[1] = mini(_player_selected_octet[1] + 1, 3)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_action_pressed("move_forward") and _player_value_timer[1] <= 0.0:
			_adjust_octet(1, 1)
			_player_value_timer[1] = VALUE_CHANGE_COOLDOWN
		if Input.is_action_pressed("move_back") and _player_value_timer[1] <= 0.0:
			_adjust_octet(1, -1)
			_player_value_timer[1] = VALUE_CHANGE_COOLDOWN
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump"):
			_submit_answer(1)

	# P2
	if 2 in _base.player_ids:
		_player_value_timer[2] -= delta
		if _p2_just_pressed(KEY_LEFT):
			_player_selected_octet[2] = maxi(_player_selected_octet[2] - 1, 0)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if _p2_just_pressed(KEY_RIGHT):
			_player_selected_octet[2] = mini(_player_selected_octet[2] + 1, 3)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_key_pressed(KEY_UP) and _player_value_timer[2] <= 0.0:
			_adjust_octet(2, 1)
			_player_value_timer[2] = VALUE_CHANGE_COOLDOWN
		if Input.is_key_pressed(KEY_DOWN) and _player_value_timer[2] <= 0.0:
			_adjust_octet(2, -1)
			_player_value_timer[2] = VALUE_CHANGE_COOLDOWN
		if _p2_just_pressed(KEY_L) or _p2_just_pressed(KEY_SHIFT):
			_submit_answer(2)

func _adjust_octet(pid: int, direction: int) -> void:
	var idx: int = _player_selected_octet[pid]
	var octets: Array = _player_octets[pid]
	octets[idx] = clampi(octets[idx] + direction, OCTET_MIN, OCTET_MAX)
	_player_octets[pid] = octets

func _submit_answer(pid: int) -> void:
	var puzzle_idx: int = _player_puzzle_index[pid]
	if puzzle_idx >= TOTAL_PUZZLES:
		return  # Already done all puzzles

	var puzzle: Dictionary = _puzzles[puzzle_idx]
	var target: Array = puzzle["octets"]
	var player_answer: Array = _player_octets[pid]

	var correct: bool = true
	for i in range(4):
		if player_answer[i] != target[i]:
			correct = false
			break

	if correct:
		_base.add_score(pid, CORRECT_PTS)
		_player_completed[pid] += 1
		_player_puzzle_index[pid] += 1
		_player_flash[pid] = 0.8
		_player_flash_color[pid] = Color("#22C55E")
		# Reset octets for next puzzle
		_player_octets[pid] = [0, 0, 0, 0]
		_player_selected_octet[pid] = 0
		if AudioManager:
			AudioManager.play_sfx("signal_lock")
	else:
		_base.add_score(pid, WRONG_PTS)
		_player_flash[pid] = 0.5
		_player_flash_color[pid] = Color("#EF4444")
		if AudioManager:
			AudioManager.play_sfx("hit_light")

# ═══════════ DRAWING ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _IPDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _IPDraw extends Control:
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
		draw_string(font, Vector2(s.x / 2.0 - 60, 30), "IP PUZZLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#06B6D4"))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var tc: Color = Color("#22C55E") if time_left > 10 else Color("#EF4444")
		draw_string(font, Vector2(s.x - 80, 30), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tc)

		# Draw each player's puzzle area
		for pid in game._base.player_ids:
			var area_x: float = 40.0 if pid == 1 else s.x / 2.0 + 20.0
			var area_w: float = s.x / 2.0 - 60.0
			var area_y: float = 70.0
			var player_color: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var name_str: String = "RICO" if pid == 1 else "VERO"

			# Player header
			draw_string(font, Vector2(area_x, area_y), "P%d — %s" % [pid, name_str], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, player_color)

			# Current puzzle
			var puzzle_idx: int = game._player_puzzle_index.get(pid, 0)
			var completed: int = game._player_completed.get(pid, 0)

			if puzzle_idx >= game.TOTAL_PUZZLES:
				draw_string(font, Vector2(area_x, area_y + 40), "ALL PUZZLES COMPLETE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#22C55E"))
				draw_string(font, Vector2(area_x, area_y + 70), "%d / %d solved" % [completed, game.TOTAL_PUZZLES], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0"))
			else:
				var puzzle: Dictionary = game._puzzles[puzzle_idx]

				# Progress
				draw_string(font, Vector2(area_x, area_y + 30), "Puzzle %d / %d" % [puzzle_idx + 1, game.TOTAL_PUZZLES], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9CA3AF"))

				# Target IP
				draw_string(font, Vector2(area_x, area_y + 60), "TARGET:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#F59E0B"))
				draw_string(font, Vector2(area_x, area_y + 85), puzzle["display"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#F59E0B"))

				# Hint
				draw_string(font, Vector2(area_x, area_y + 110), puzzle.get("hint", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#6B7280"))

				# Player's octet inputs
				var octets: Array = game._player_octets.get(pid, [0, 0, 0, 0])
				var selected: int = game._player_selected_octet.get(pid, 0)
				var octet_w: float = 70.0
				var octet_h: float = 50.0
				var octet_y: float = area_y + 140.0
				var octet_start_x: float = area_x

				for i in range(4):
					var ox: float = octet_start_x + i * (octet_w + 15)
					var is_selected: bool = (i == selected)

					# Octet box
					var box_color: Color = Color("#1E293B")
					if is_selected:
						box_color = Color(player_color, 0.3)
					draw_rect(Rect2(ox, octet_y, octet_w, octet_h), box_color)

					# Border
					var border_color: Color = player_color if is_selected else Color("#374151")
					draw_rect(Rect2(ox, octet_y, octet_w, octet_h), border_color, false, 2.0 if is_selected else 1.0)

					# Value
					var val_str: String = "%d" % octets[i]
					draw_string(font, Vector2(ox + 10, octet_y + 35), val_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE if is_selected else Color("#9CA3AF"))

					# Up/Down arrows for selected
					if is_selected:
						draw_string(font, Vector2(ox + octet_w / 2.0 - 5, octet_y - 5), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, player_color)
						draw_string(font, Vector2(ox + octet_w / 2.0 - 5, octet_y + octet_h + 18), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, player_color)

					# Dot separator
					if i < 3:
						draw_string(font, Vector2(ox + octet_w + 3, octet_y + 35), ".", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#E2E8F0"))

				# Current assembled IP
				var assembled: String = "%d.%d.%d.%d" % [octets[0], octets[1], octets[2], octets[3]]
				draw_string(font, Vector2(area_x, octet_y + octet_h + 40), "Your answer: %s" % assembled, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0"))

			# Flash feedback
			var flash: float = game._player_flash.get(pid, 0.0)
			if flash > 0.0:
				var flash_color: Color = game._player_flash_color.get(pid, Color.WHITE)
				var flash_alpha: float = flash / 0.8
				draw_rect(Rect2(area_x, area_y - 10, area_w, 300), Color(flash_color, flash_alpha * 0.15))
				var result_text: String = "CORRECT!" if flash_color == Color("#22C55E") else "WRONG!"
				draw_string(font, Vector2(area_x + area_w / 2.0 - 40, area_y + 200), result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(flash_color, flash_alpha))

			# Score
			var score: float = game._base.scores.get(pid, 0.0)
			draw_string(font, Vector2(area_x, s.y - 40), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, player_color)

		# Divider
		draw_line(Vector2(s.x / 2.0, 50), Vector2(s.x / 2.0, s.y - 60), Color("#374151"), 1.0)

		# Controls
		draw_string(font, Vector2(40, s.y - 10), "P1: A/D select | W/S adjust | J submit", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 300, s.y - 10), "P2: Left/Right select | Up/Down adjust | L submit", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
