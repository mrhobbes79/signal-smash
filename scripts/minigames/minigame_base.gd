class_name MiniGameBase
extends Node3D
## Base class for all mini-games. Implement _on_start, _on_update, and _on_player_input.
## Emits game_completed with results dict when finished.

signal game_completed(results: Dictionary)
## results format: { player_id: { "score": float, "buff_stat": String, "buff_value": int } }

@export var game_name: String = "Mini-Game"
@export var concept_taught: String = ""
@export var duration_seconds: float = 30.0
@export var buff_stat: String = "range"
@export var buff_value: int = 10

var player_ids: Array = []
var scores: Dictionary = {}  # { player_id: float }
var time_remaining: float = 0.0
var is_running: bool = false
var is_finished: bool = false

## UI references (created by subclass or framework)
var _timer_label: Label3D
var _score_labels: Dictionary = {}  # { player_id: Label3D }
var _title_label: Label3D
var _instruction_label: Label3D

## P2 key tracking for just-pressed detection
var _p2_prev_keys: Dictionary = {}

## Returns true only on rising edge (key was not pressed last frame, is pressed now)
func _p2_just_pressed(keycode: int) -> bool:
	var currently_pressed: bool = Input.is_key_pressed(keycode)
	var was_pressed: bool = _p2_prev_keys.get(keycode, false)
	_p2_prev_keys[keycode] = currently_pressed
	return currently_pressed and not was_pressed

## Mini-game music index (0=Vivaldi/Antenna, 1=Bach/Spectrum, 2=Mozart/Cable)
@export var music_index: int = 0

## Called by the framework to start the mini-game
func start(p_player_ids: Array) -> void:
	player_ids = p_player_ids
	scores.clear()
	for pid in player_ids:
		scores[pid] = 0.0
	time_remaining = duration_seconds
	is_running = true
	is_finished = false
	_build_common_ui()
	# Play classical background music
	if AudioManager:
		AudioManager.play_music_minigame(music_index)
	_on_start()

## Override in subclass — set up mini-game visuals and state
func _on_start() -> void:
	pass

## Override in subclass — update mini-game logic
func _on_update(_delta: float) -> void:
	pass

## Override in subclass — handle player-specific input
func _on_player_input(_player_id: int, _action: String, _value: float) -> void:
	pass

func _process(delta: float) -> void:
	if not is_running:
		return

	time_remaining -= delta
	_update_timer_display()
	_update_score_display()
	_on_update(delta)

	# Read input for each player
	_read_player_inputs()

	if time_remaining <= 0.0:
		_finish()

func _read_player_inputs() -> void:
	# P1 inputs (WASD + Space)
	if 1 in player_ids:
		var p1_x: float = Input.get_axis("move_left", "move_right")
		var p1_y: float = Input.get_axis("move_forward", "move_back")
		if absf(p1_x) > 0.1:
			_on_player_input(1, "horizontal", p1_x)
		if absf(p1_y) > 0.1:
			_on_player_input(1, "vertical", p1_y)
		if Input.is_action_just_pressed("jump"):
			_on_player_input(1, "confirm", 1.0)
		if Input.is_action_just_pressed("attack"):
			_on_player_input(1, "action", 1.0)

	# P2 inputs (Arrow keys + Shift)
	if 2 in player_ids:
		var p2_x: float = 0.0
		var p2_y: float = 0.0
		if Input.is_key_pressed(KEY_LEFT):
			p2_x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			p2_x += 1.0
		if Input.is_key_pressed(KEY_UP):
			p2_y -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
			p2_y += 1.0
		if absf(p2_x) > 0.1:
			_on_player_input(2, "horizontal", p2_x)
		if absf(p2_y) > 0.1:
			_on_player_input(2, "vertical", p2_y)
		if _p2_just_pressed(KEY_SHIFT):
			_on_player_input(2, "confirm", 1.0)
		if _p2_just_pressed(KEY_CTRL) or _p2_just_pressed(KEY_L):
			_on_player_input(2, "action", 1.0)

func _finish() -> void:
	is_running = false
	is_finished = true
	time_remaining = 0.0

	# Stop music
	if AudioManager:
		AudioManager.stop_music()

	# Determine winner (handle ties)
	var winner_id: int = -1
	var best_score: float = -1.0
	var is_tie: bool = false
	for pid in scores:
		if scores[pid] > best_score:
			best_score = scores[pid]
			winner_id = pid
			is_tie = false
		elif scores[pid] == best_score and winner_id != -1:
			is_tie = true

	if is_tie:
		winner_id = -1  # No winner on tie

	# Build results
	var results: Dictionary = {}
	for pid in scores:
		var is_winner: bool = (pid == winner_id and winner_id > 0)
		results[pid] = {
			"score": scores[pid],
			"buff_stat": buff_stat,
			"buff_value": buff_value if is_winner else int(buff_value / 2.0),
			"is_winner": is_winner,
		}

	if is_tie:
		print("[MINI] %s complete! TIE at %.0f pts" % [game_name, best_score])
	else:
		print("[MINI] %s complete! Winner: P%d (%.0f pts)" % [game_name, winner_id, best_score])
	_on_finish(winner_id)

	# Wait a moment then emit completion
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	game_completed.emit(results)

## Override in subclass for custom finish behavior
func _on_finish(_winner_id: int) -> void:
	pass

func add_score(player_id: int, amount: float) -> void:
	if player_id in scores:
		scores[player_id] += amount

## Common UI elements
func _build_common_ui() -> void:
	# Title
	_title_label = Label3D.new()
	_title_label.text = game_name.to_upper()
	_title_label.font_size = 64
	_title_label.position = Vector3(0, 5.0, 0)
	_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title_label.modulate = Color("#06B6D4")
	_title_label.outline_size = 6
	_title_label.outline_modulate = Color.BLACK
	add_child(_title_label)

	# Concept taught
	_instruction_label = Label3D.new()
	_instruction_label.text = "Learn: %s" % concept_taught
	_instruction_label.font_size = 28
	_instruction_label.position = Vector3(0, 4.3, 0)
	_instruction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_instruction_label.modulate = Color("#F59E0B")
	_instruction_label.outline_size = 3
	_instruction_label.outline_modulate = Color.BLACK
	add_child(_instruction_label)

	# Timer
	_timer_label = Label3D.new()
	_timer_label.font_size = 48
	_timer_label.position = Vector3(0, 6.0, 0)
	_timer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_timer_label.modulate = Color("#22C55E")
	_timer_label.outline_size = 5
	_timer_label.outline_modulate = Color.BLACK
	add_child(_timer_label)

	# Score labels per player
	for i in range(player_ids.size()):
		var pid: int = player_ids[i]
		var label := Label3D.new()
		label.font_size = 36
		var x_offset: float = -3.0 if i == 0 else 3.0
		label.position = Vector3(x_offset, 4.8, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("#2563EB") if pid == 1 else Color("#7C3AED")
		label.outline_size = 4
		label.outline_modulate = Color.BLACK
		add_child(label)
		_score_labels[pid] = label

func _update_timer_display() -> void:
	if _timer_label:
		var secs: int = ceili(time_remaining)
		_timer_label.text = "%d" % secs
		if time_remaining <= 5.0:
			_timer_label.modulate = Color("#EF4444")
		elif time_remaining <= 10.0:
			_timer_label.modulate = Color("#F59E0B")

func _update_score_display() -> void:
	for pid in _score_labels:
		var label: Label3D = _score_labels[pid]
		var name_str: String = "RICO" if pid == 1 else "VERO"
		label.text = "%s: %.0f" % [name_str, scores.get(pid, 0.0)]
