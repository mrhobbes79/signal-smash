extends Control
## SIGNAL SMASH — Campaign Chapter Gameplay
## Self-contained mini-game per chapter with story intro/outro dialog.
## Uses CanvasLayer + custom _draw() for 2D gameplay rendering.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const SUCCESS := Color("#22C55E")
const FAIL := Color("#EF4444")

enum State { INTRO, GAMEPLAY, OUTRO, RESULTS }

var _state: int = State.INTRO
var _time: float = 0.0
var _chapter: int = 1
var _draw_node: Control

## Dialog
var _dialog_lines: Array[String] = []
var _dialog_index: int = 0
var _typewriter_pos: int = 0
var _typewriter_timer: float = 0.0
const TYPEWRITER_SPEED: float = 0.03

## Gameplay state (shared across chapters)
var _score: float = 0.0
var _max_score: float = 0.0
var _game_timer: float = 0.0
var _game_active: bool = false

## Chapter-specific state
# Ch1: Morse code
var _morse_sequences: Array[float] = []
var _morse_index: int = 0
var _morse_target_time: float = 0.0
var _morse_window: float = 0.3
var _morse_flash_timer: float = 0.0
var _morse_result: String = ""

# Ch2: Radio tuning
var _radio_freq: float = 50.0
var _radio_targets: Array[float] = []
var _radio_found: int = 0
var _radio_lock_timer: float = 0.0
var _radio_time_left: float = 30.0
var _radio_signal_strength: float = 0.0

# Ch3: Tower placement
var _tower_grid: Array[Vector2i] = []  ## placed towers
var _tower_cities: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 2), Vector2i(5, 3), Vector2i(7, 4)]
var _tower_budget: int = 5
var _tower_cursor: Vector2i = Vector2i(4, 2)
var _tower_connected: Array[bool] = [false, false, false, false]

# Ch4: Quiz
var _quiz_index: int = 0
var _quiz_selected: int = 0
var _quiz_answered: bool = false
var _quiz_correct_count: int = 0
var _quiz_questions: Array[Dictionary] = [
	{"q": "What is the default channel for 2.4GHz WiFi?", "opts": ["Channel 1", "Channel 6", "Channel 11", "Channel 36"], "ans": 1},
	{"q": "What does SSID stand for?", "opts": ["Signal Service ID", "Service Set Identifier", "System Signal ID", "Secure Set ID"], "ans": 1},
	{"q": "Which security protocol is strongest?", "opts": ["WEP", "WPA", "WPA2", "WPA3"], "ans": 3},
	{"q": "What is the max speed of 802.11ac?", "opts": ["54 Mbps", "300 Mbps", "1.3 Gbps", "6.9 Gbps"], "ans": 2},
	{"q": "Best channel width for long-range PtP?", "opts": ["5 MHz", "20 MHz", "40 MHz", "80 MHz"], "ans": 1},
]

# Ch5: Resource allocation
var _resource_tokens: Array[int] = [3, 3, 4]  ## DSL, Cable, Wireless (10 total)
var _resource_cursor: int = 0
var _resource_submitted: bool = false
const RESOURCE_TOTAL: int = 10
const RESOURCE_OPTIMAL: Array[int] = [2, 3, 5]  ## Best allocation

# Ch6: Dish alignment
var _dish_angles: Array[float] = [0.0, 0.0, 0.0]
var _dish_targets: Array[float] = [45.0, 120.0, 270.0]
var _dish_current: int = 0
var _dish_aligned: Array[bool] = [false, false, false]
var _dish_time_left: float = 45.0
var _dish_tolerance: float = 5.0

# Ch7: Boss fight
var _boss_time_left: float = 60.0
var _boss_player_x: float = 0.5  ## 0-1 normalized
var _boss_papers: Array[Dictionary] = []  ## {x: float, y: float}
var _boss_paper_timer: float = 0.0
var _boss_hits: int = 0
var _boss_antenna_progress: float = 0.0
var _boss_installing: bool = false

## Story dialog per chapter
const INTRO_DIALOG: Dictionary = {
	1: ["In the early 1900s, I was just a young telegraph operator...",
		"The world communicated through dots and dashes — Morse code.",
		"Let me show you how it all began. Listen for the rhythm..."],
	2: ["By the 1920s, radio changed everything.",
		"Families gathered around receivers, tuning through static to find a signal.",
		"Find the stations hidden in the noise."],
	3: ["The 1960s brought microwave links — towers connecting cities across vast distances.",
		"I helped build some of those first relay chains.",
		"Place your towers wisely. Budget is tight, but cities must connect."],
	4: ["The 1990s... WiFi! The wireless revolution arrived in our homes.",
		"But configuring those early access points? That was the real challenge.",
		"Show me you know your WiFi fundamentals."],
	5: ["The 2000s were the Broadband Wars. DSL, cable, wireless — everyone fighting for speed.",
		"As a WISP operator, I had to be smarter than the big companies.",
		"Allocate your resources wisely across the technologies."],
	6: ["The 2010s. This is when I became a true WISP pioneer.",
		"Installing antennas on towers, aligning dishes in wind and rain...",
		"Align the dishes precisely. Every dB matters out here."],
	7: ["And now, the 2020s. 5G, fiber, and... El Regulador.",
		"He wants to shut down independent WISPs. Says we are 'obsolete'.",
		"Dodge his regulations while we install the final antenna. The community depends on us!"],
}

const OUTRO_DIALOG: Dictionary = {
	1: ["The telegraph taught me patience. Every signal matters.",
		"This was just the beginning..."],
	2: ["Radio showed me that the airwaves belong to everyone.",
		"And with that power comes responsibility."],
	3: ["Those towers still stand today. Infrastructure built right lasts generations.",
		"Now the signals would travel even further..."],
	4: ["WiFi democratized connectivity. No wires, no limits.",
		"But the real revolution was yet to come."],
	5: ["The big companies had money, but we had ingenuity.",
		"Wireless proved that community networks could compete."],
	6: ["Every dish I aligned connected another family.",
		"That is the true meaning of being a WISP pioneer."],
	7: ["El Regulador could not stop us. The community is too strong.",
		"From Morse code to 5G — the signal never dies. Viva los WISPs!"],
}

## SP/KT rewards per chapter
const CHAPTER_SP: int = 150
const CHAPTER_KT: int = 20

func _ready() -> void:
	_chapter = CampaignData.current_chapter if CampaignData else 1
	_chapter = clampi(_chapter, 1, 7)

	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _ChapterDraw.new()
	_draw_node.chapter = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# Start with intro dialog
	_start_intro()

func _start_intro() -> void:
	_state = State.INTRO
	_dialog_lines = []
	var lines: Array = INTRO_DIALOG.get(_chapter, ["..."])
	for line in lines:
		_dialog_lines.append(line)
	_dialog_index = 0
	_typewriter_pos = 0
	_typewriter_timer = 0.0

func _start_gameplay() -> void:
	_state = State.GAMEPLAY
	_game_active = true
	_game_timer = 0.0
	_score = 0.0
	_init_chapter_gameplay()

func _init_chapter_gameplay() -> void:
	match _chapter:
		1:
			_morse_sequences = [0.5, 1.0, 0.5, 1.5, 0.5, 1.0, 0.5, 1.5, 0.5, 1.0]
			_morse_index = 0
			_morse_target_time = 1.5
			_max_score = 10.0
			_morse_result = ""
		2:
			_radio_targets = [22.0, 41.0, 63.0, 78.0, 92.0]
			_radio_found = 0
			_radio_freq = 50.0
			_radio_time_left = 30.0
			_radio_lock_timer = 0.0
			_max_score = 5.0
		3:
			_tower_grid = []
			_tower_budget = 5
			_tower_cursor = Vector2i(4, 2)
			_tower_connected = [false, false, false, false]
			_max_score = 4.0
		4:
			_quiz_index = 0
			_quiz_selected = 0
			_quiz_answered = false
			_quiz_correct_count = 0
			_max_score = 5.0
		5:
			_resource_tokens = [3, 3, 4]
			_resource_cursor = 0
			_resource_submitted = false
			_max_score = 100.0
		6:
			_dish_angles = [0.0, 0.0, 0.0]
			_dish_targets = [45.0, 120.0, 270.0]
			_dish_current = 0
			_dish_aligned = [false, false, false]
			_dish_time_left = 45.0
			_max_score = 3.0
		7:
			_boss_time_left = 60.0
			_boss_player_x = 0.5
			_boss_papers = []
			_boss_paper_timer = 0.0
			_boss_hits = 0
			_boss_antenna_progress = 0.0
			_boss_installing = false
			_max_score = 100.0

func _start_outro() -> void:
	_state = State.OUTRO
	_game_active = false
	_dialog_lines = []
	var lines: Array = OUTRO_DIALOG.get(_chapter, ["..."])
	for line in lines:
		_dialog_lines.append(line)
	_dialog_index = 0
	_typewriter_pos = 0
	_typewriter_timer = 0.0

func _show_results() -> void:
	_state = State.RESULTS
	# Mark chapter complete and award rewards (only on first completion)
	if Progression:
		if _chapter not in Progression.campaign_chapters_complete:
			Progression.campaign_chapters_complete.append(_chapter)
			Progression.signal_points += CHAPTER_SP
			Progression.knowledge_tokens += CHAPTER_KT
		Progression.save_game()

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

	match _state:
		State.INTRO, State.OUTRO:
			_update_typewriter(delta)
		State.GAMEPLAY:
			_update_gameplay(delta)

func _update_typewriter(delta: float) -> void:
	if _dialog_index >= _dialog_lines.size():
		return
	var current_line: String = _dialog_lines[_dialog_index]
	if _typewriter_pos < current_line.length():
		_typewriter_timer += delta
		if _typewriter_timer >= TYPEWRITER_SPEED:
			_typewriter_timer -= TYPEWRITER_SPEED
			_typewriter_pos += 1

func _update_gameplay(delta: float) -> void:
	if not _game_active:
		return
	_game_timer += delta

	match _chapter:
		1: _update_ch1_morse(delta)
		2: _update_ch2_radio(delta)
		3: pass  ## Turn-based, handled in input
		4: pass  ## Turn-based, handled in input
		5: pass  ## Turn-based, handled in input
		6: _update_ch6_dish(delta)
		7: _update_ch7_boss(delta)

## ═══════════ CHAPTER UPDATES ═══════════

func _update_ch1_morse(delta: float) -> void:
	_morse_target_time -= delta
	_morse_flash_timer = maxf(_morse_flash_timer - delta, 0.0)
	if _morse_index >= _morse_sequences.size():
		_game_active = false
		_score = 0.0
		for c in _morse_result:
			if c == "O":
				_score += 1.0
		_start_outro()

func _update_ch2_radio(delta: float) -> void:
	_radio_time_left -= delta
	_radio_lock_timer = maxf(_radio_lock_timer - delta, 0.0)
	# Calculate signal strength to nearest target
	_radio_signal_strength = 0.0
	for tgt in _radio_targets:
		var dist: float = absf(_radio_freq - tgt)
		if dist < 5.0:
			_radio_signal_strength = maxf(_radio_signal_strength, 1.0 - dist / 5.0)
	if _radio_time_left <= 0.0:
		_game_active = false
		_score = float(_radio_found)
		_start_outro()

func _update_ch6_dish(delta: float) -> void:
	_dish_time_left -= delta
	# Check alignment
	if not _dish_aligned[_dish_current]:
		var diff: float = absf(_dish_angles[_dish_current] - _dish_targets[_dish_current])
		if diff <= _dish_tolerance:
			_dish_aligned[_dish_current] = true
			_score += 1.0
			if AudioManager:
				AudioManager.play_sfx("menu_select")
			# Auto-advance to next unaligned dish
			for i in range(3):
				if not _dish_aligned[i]:
					_dish_current = i
					break
	# Check completion
	var all_aligned: bool = _dish_aligned[0] and _dish_aligned[1] and _dish_aligned[2]
	if all_aligned or _dish_time_left <= 0.0:
		_game_active = false
		_start_outro()

func _update_ch7_boss(delta: float) -> void:
	_boss_time_left -= delta
	_boss_paper_timer += delta

	# Spawn papers
	if _boss_paper_timer >= 0.6:
		_boss_paper_timer = 0.0
		_boss_papers.append({"x": randf(), "y": 0.0})

	# Move papers down
	var to_remove: Array[int] = []
	for i in range(_boss_papers.size()):
		_boss_papers[i]["y"] += 0.4 * get_process_delta_time()
		# Check collision with player
		if _boss_papers[i]["y"] > 0.85 and _boss_papers[i]["y"] < 0.95:
			if absf(_boss_papers[i]["x"] - _boss_player_x) < 0.08:
				_boss_hits += 1
				if i not in to_remove:
					to_remove.append(i)
				if AudioManager:
					AudioManager.play_sfx("menu_move")
		if _boss_papers[i]["y"] > 1.0:
			if i not in to_remove:
				to_remove.append(i)

	to_remove.reverse()
	for i in to_remove:
		if i < _boss_papers.size():
			_boss_papers.remove_at(i)

	# Installing antenna (hold SPACE)
	if _boss_installing:
		_boss_antenna_progress += 0.5 * get_process_delta_time()

	# Win/lose
	if _boss_antenna_progress >= 1.0:
		_game_active = false
		_score = maxf(0.0, 100.0 - _boss_hits * 10.0)
		_start_outro()
	elif _boss_time_left <= 0.0:
		_game_active = false
		_score = maxf(0.0, _boss_antenna_progress * 100.0 - _boss_hits * 10.0)
		_start_outro()

## ═══════════ INPUT ═══════════

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	match _state:
		State.INTRO:
			_handle_dialog_input(event.keycode)
		State.GAMEPLAY:
			_handle_gameplay_input(event)
		State.OUTRO:
			_handle_dialog_input_outro(event.keycode)
		State.RESULTS:
			if event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/campaign/campaign_mode.tscn")

func _handle_dialog_input(keycode: int) -> void:
	if keycode == KEY_ENTER or keycode == KEY_SPACE:
		if _dialog_index < _dialog_lines.size():
			var current_line: String = _dialog_lines[_dialog_index]
			if _typewriter_pos < current_line.length():
				_typewriter_pos = current_line.length()
			else:
				_dialog_index += 1
				_typewriter_pos = 0
				_typewriter_timer = 0.0
				if _dialog_index >= _dialog_lines.size():
					_start_gameplay()
	elif keycode == KEY_ESCAPE:
		_start_gameplay()

func _handle_dialog_input_outro(keycode: int) -> void:
	if keycode == KEY_ENTER or keycode == KEY_SPACE:
		if _dialog_index < _dialog_lines.size():
			var current_line: String = _dialog_lines[_dialog_index]
			if _typewriter_pos < current_line.length():
				_typewriter_pos = current_line.length()
			else:
				_dialog_index += 1
				_typewriter_pos = 0
				_typewriter_timer = 0.0
				if _dialog_index >= _dialog_lines.size():
					_show_results()
	elif keycode == KEY_ESCAPE:
		_show_results()

func _handle_gameplay_input(event: InputEventKey) -> void:
	if not _game_active:
		return

	match _chapter:
		1: _input_ch1_morse(event)
		2: _input_ch2_radio(event)
		3: _input_ch3_tower(event)
		4: _input_ch4_quiz(event)
		5: _input_ch5_resource(event)
		6: _input_ch6_dish(event)
		7: _input_ch7_boss(event)

func _input_ch1_morse(event: InputEventKey) -> void:
	if event.keycode == KEY_SPACE:
		if _morse_index < _morse_sequences.size():
			var target: float = _morse_sequences[_morse_index]
			var accuracy: float = absf(_game_timer - target - 0.5 * float(_morse_index))
			if accuracy < _morse_window:
				_morse_result += "O"
				_morse_flash_timer = 0.2
			else:
				_morse_result += "X"
			_morse_index += 1
			if AudioManager:
				AudioManager.play_sfx("menu_select")

func _input_ch2_radio(event: InputEventKey) -> void:
	match event.keycode:
		KEY_A, KEY_LEFT:
			_radio_freq = maxf(0.0, _radio_freq - 2.0)
		KEY_D, KEY_RIGHT:
			_radio_freq = minf(100.0, _radio_freq + 2.0)
		KEY_ENTER, KEY_SPACE:
			if _radio_lock_timer <= 0.0:
				# Check if near a target
				for i in range(_radio_targets.size()):
					if absf(_radio_freq - _radio_targets[i]) < 3.0:
						_radio_found += 1
						_radio_targets.remove_at(i)
						_radio_lock_timer = 0.5
						if AudioManager:
							AudioManager.play_sfx("menu_select")
						break

func _input_ch3_tower(event: InputEventKey) -> void:
	match event.keycode:
		KEY_LEFT, KEY_A:
			_tower_cursor.x = maxi(0, _tower_cursor.x - 1)
		KEY_RIGHT, KEY_D:
			_tower_cursor.x = mini(8, _tower_cursor.x + 1)
		KEY_UP, KEY_W:
			_tower_cursor.y = maxi(0, _tower_cursor.y - 1)
		KEY_DOWN, KEY_S:
			_tower_cursor.y = mini(5, _tower_cursor.y + 1)
		KEY_SPACE, KEY_ENTER:
			if _tower_budget > 0 and _tower_cursor not in _tower_grid:
				_tower_grid.append(_tower_cursor)
				_tower_budget -= 1
				_check_tower_connections()
				if AudioManager:
					AudioManager.play_sfx("menu_select")
		KEY_BACKSPACE:
			# Remove last tower
			if _tower_grid.size() > 0:
				_tower_grid.pop_back()
				_tower_budget += 1
				_check_tower_connections()
		KEY_TAB:
			# Finish / submit
			_game_active = false
			_score = 0.0
			for c in _tower_connected:
				if c:
					_score += 1.0
			_start_outro()

func _check_tower_connections() -> void:
	## Check if cities are connected through tower chain
	## Simple: city is connected if a tower is within 2 grid units
	for i in range(_tower_cities.size()):
		_tower_connected[i] = false
		for t in _tower_grid:
			var dist: float = Vector2(t).distance_to(Vector2(_tower_cities[i]))
			if dist <= 2.5:
				_tower_connected[i] = true
				break

func _input_ch4_quiz(event: InputEventKey) -> void:
	if _quiz_answered:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_quiz_index += 1
			_quiz_selected = 0
			_quiz_answered = false
			if _quiz_index >= _quiz_questions.size():
				_game_active = false
				_score = float(_quiz_correct_count)
				_start_outro()
		return

	match event.keycode:
		KEY_UP, KEY_W:
			_quiz_selected = (_quiz_selected - 1 + 4) % 4
		KEY_DOWN, KEY_S:
			_quiz_selected = (_quiz_selected + 1) % 4
		KEY_ENTER, KEY_SPACE:
			_quiz_answered = true
			var correct_idx: int = _quiz_questions[_quiz_index]["ans"]
			if _quiz_selected == correct_idx:
				_quiz_correct_count += 1
				_score += 100.0
			else:
				_score = maxf(0.0, _score - 20.0)
			if AudioManager:
				AudioManager.play_sfx("menu_select")

func _input_ch5_resource(event: InputEventKey) -> void:
	if _resource_submitted:
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_resource_cursor = (_resource_cursor - 1 + 3) % 3
		KEY_DOWN, KEY_S:
			_resource_cursor = (_resource_cursor + 1) % 3
		KEY_RIGHT, KEY_D:
			var total: int = _resource_tokens[0] + _resource_tokens[1] + _resource_tokens[2]
			if total < RESOURCE_TOTAL:
				_resource_tokens[_resource_cursor] += 1
		KEY_LEFT, KEY_A:
			if _resource_tokens[_resource_cursor] > 0:
				_resource_tokens[_resource_cursor] -= 1
		KEY_ENTER, KEY_SPACE:
			_resource_submitted = true
			# Score based on how close to optimal
			var diff: float = 0.0
			for i in range(3):
				diff += absf(float(_resource_tokens[i] - RESOURCE_OPTIMAL[i]))
			_score = maxf(0.0, 100.0 - diff * 15.0)
			_game_active = false
			_start_outro()

func _input_ch6_dish(event: InputEventKey) -> void:
	if _dish_aligned[_dish_current]:
		# Switch to next unaligned
		for i in range(3):
			if not _dish_aligned[i]:
				_dish_current = i
				break
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_dish_angles[_dish_current] = fmod(_dish_angles[_dish_current] - 3.0 + 360.0, 360.0)
		KEY_RIGHT, KEY_D:
			_dish_angles[_dish_current] = fmod(_dish_angles[_dish_current] + 3.0, 360.0)
		KEY_TAB:
			# Cycle through dishes
			_dish_current = (_dish_current + 1) % 3

func _input_ch7_boss(event: InputEventKey) -> void:
	match event.keycode:
		KEY_LEFT, KEY_A:
			_boss_player_x = maxf(0.05, _boss_player_x - 0.05)
		KEY_RIGHT, KEY_D:
			_boss_player_x = minf(0.95, _boss_player_x + 0.05)
		KEY_SPACE:
			_boss_installing = not _boss_installing


## ═══════════ DRAW ═══════════

class _ChapterDraw extends Control:
	var chapter: Node

	func _draw() -> void:
		if chapter == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = chapter._time
		var ch: int = chapter._chapter

		match chapter._state:
			State.INTRO, State.OUTRO:
				_draw_dialog(s, font, t)
			State.GAMEPLAY:
				_draw_gameplay(s, font, t, ch)
			State.RESULTS:
				_draw_results(s, font, t)

	func _draw_dialog(s: Vector2, font: Font, t: float) -> void:
		var is_intro: bool = chapter._state == State.INTRO
		var title: String = "CHAPTER %d" % chapter._chapter
		var ch_data: Dictionary = {}
		for c in chapter.CHAPTERS_INFO:
			if c["num"] == chapter._chapter:
				ch_data = c
				break

		# Header
		var header_color: Color = ACCENT if is_intro else WARN
		draw_string(font, Vector2(s.x / 2.0 - 100, 60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, header_color)

		if ch_data.size() > 0:
			draw_string(font, Vector2(s.x / 2.0 - 150, 90), ch_data.get("title", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(TEXT, 0.6))

		# Dialog box
		var box_y: float = s.y * 0.35
		var box_h: float = s.y * 0.35
		var box_x: float = s.x * 0.1
		var box_w: float = s.x * 0.8
		draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.05, 0.07, 0.12, 0.95))
		draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(ACCENT, 0.3), false, 2.0)

		# Speaker name
		draw_string(font, Vector2(box_x + 20, box_y + 30), "DON AURELIO:", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, WARN)

		# Typewriter text
		if chapter._dialog_index < chapter._dialog_lines.size():
			var full_line: String = chapter._dialog_lines[chapter._dialog_index]
			var visible: String = full_line.substr(0, chapter._typewriter_pos)
			draw_string(font, Vector2(box_x + 20, box_y + 70), visible, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)

			# Cursor blink
			if chapter._typewriter_pos < full_line.length():
				var blink: float = fmod(t * 3.0, 1.0)
				if blink < 0.5:
					var cursor_x: float = box_x + 20 + chapter._typewriter_pos * 9.5
					draw_rect(Rect2(cursor_x, box_y + 55, 10, 20), ACCENT)

		# Progress dots
		var dot_y: float = box_y + box_h - 30
		for i in range(chapter._dialog_lines.size()):
			var dot_color: Color
			if i < chapter._dialog_index:
				dot_color = SUCCESS
			elif i == chapter._dialog_index:
				dot_color = ACCENT
			else:
				dot_color = Color(TEXT, 0.2)
			draw_circle(Vector2(box_x + 20 + i * 20, dot_y), 5.0, dot_color)

		# Continue prompt
		var prompt: String = "ENTER to continue" if is_intro else "ENTER to continue"
		var prompt_pulse: float = (sin(t * 3.0) + 1.0) / 2.0
		draw_string(font, Vector2(s.x / 2.0 - 80, s.y - 60), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ACCENT, 0.4 + prompt_pulse * 0.4))

	func _draw_gameplay(s: Vector2, font: Font, t: float, ch: int) -> void:
		# Chapter header bar
		draw_rect(Rect2(0, 0, s.x, 40), Color(0.05, 0.07, 0.12, 0.9))
		draw_string(font, Vector2(15, 28), "CH.%d" % ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)

		match ch:
			1: _draw_ch1(s, font, t)
			2: _draw_ch2(s, font, t)
			3: _draw_ch3(s, font, t)
			4: _draw_ch4(s, font, t)
			5: _draw_ch5(s, font, t)
			6: _draw_ch6(s, font, t)
			7: _draw_ch7(s, font, t)

	func _draw_ch1(s: Vector2, font: Font, t: float) -> void:
		# Morse code timing game
		draw_string(font, Vector2(100, 28), "MORSE CODE — Press SPACE on the beat!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)

		var center_y: float = s.y * 0.5
		# Telegraph line
		draw_rect(Rect2(50, center_y, s.x - 100, 3), Color(WARN, 0.3))

		# Progress
		var idx: int = chapter._morse_index
		draw_string(font, Vector2(s.x / 2.0 - 60, center_y - 60), "Sequence: %d / 10" % idx, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)

		# Results so far
		for i in range(chapter._morse_result.length()):
			var c: String = chapter._morse_result[i]
			var col: Color = SUCCESS if c == "O" else FAIL
			draw_circle(Vector2(100 + i * 40, center_y + 50), 12.0, col)

		# Flash on tap
		if chapter._morse_flash_timer > 0.0:
			draw_circle(Vector2(s.x / 2.0, center_y), 30.0, Color(WARN, chapter._morse_flash_timer * 3.0))

		# Timing indicator
		var pulse: float = fmod(t * 2.0, 1.0)
		draw_circle(Vector2(s.x / 2.0, center_y), 15.0 + pulse * 10.0, Color(ACCENT, 0.3 - pulse * 0.3))

	func _draw_ch2(s: Vector2, font: Font, t: float) -> void:
		# Radio tuning
		draw_string(font, Vector2(100, 28), "RADIO TUNING — A/D to tune, ENTER to lock", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)

		var dial_y: float = s.y * 0.4
		# Frequency dial
		draw_rect(Rect2(80, dial_y, s.x - 160, 30), Color(0.1, 0.1, 0.15))
		var freq_x: float = 80 + (chapter._radio_freq / 100.0) * (s.x - 160)
		draw_rect(Rect2(freq_x - 2, dial_y - 10, 4, 50), ACCENT)

		# Frequency labels
		draw_string(font, Vector2(80, dial_y - 15), "0 MHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.3))
		draw_string(font, Vector2(s.x - 140, dial_y - 15), "100 MHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.3))
		draw_string(font, Vector2(freq_x - 20, dial_y + 60), "%.1f MHz" % chapter._radio_freq, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ACCENT)

		# Signal strength meter
		var str_y: float = s.y * 0.6
		draw_string(font, Vector2(s.x / 2.0 - 60, str_y), "SIGNAL:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))
		var bar_w: float = 200.0
		draw_rect(Rect2(s.x / 2.0 - 100, str_y + 10, bar_w, 15), Color(0.1, 0.1, 0.15))
		var str_color: Color = SUCCESS if chapter._radio_signal_strength > 0.8 else WARN if chapter._radio_signal_strength > 0.4 else FAIL
		draw_rect(Rect2(s.x / 2.0 - 100, str_y + 10, bar_w * chapter._radio_signal_strength, 15), str_color)

		# Static noise visualization
		for _i in range(20):
			var nx: float = randf() * s.x
			var ny: float = randf() * s.y * 0.3 + s.y * 0.15
			draw_rect(Rect2(nx, ny, 2, 2), Color(TEXT, randf() * 0.1 * (1.0 - chapter._radio_signal_strength)))

		# Stats
		draw_string(font, Vector2(s.x / 2.0 - 80, s.y - 80), "Stations found: %d / 5" % chapter._radio_found, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
		draw_string(font, Vector2(s.x / 2.0 - 60, s.y - 55), "Time: %.1fs" % chapter._radio_time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN if chapter._radio_time_left > 10.0 else FAIL)

	func _draw_ch3(s: Vector2, font: Font, _t: float) -> void:
		# Tower placement grid
		draw_string(font, Vector2(100, 28), "TOWER BUILDER — Arrows move, SPACE place, TAB submit", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)

		var grid_x: float = s.x * 0.15
		var grid_y: float = s.y * 0.2
		var cell_w: float = (s.x * 0.7) / 9.0
		var cell_h: float = (s.y * 0.55) / 6.0

		# Draw grid
		for gx in range(9):
			for gy in range(6):
				var rx: float = grid_x + gx * cell_w
				var ry: float = grid_y + gy * cell_h
				draw_rect(Rect2(rx, ry, cell_w, cell_h), Color(TEXT, 0.05), false, 1.0)

		# Draw cities
		for i in range(chapter._tower_cities.size()):
			var city: Vector2i = chapter._tower_cities[i]
			var cx: float = grid_x + city.x * cell_w + cell_w / 2.0
			var cy: float = grid_y + city.y * cell_h + cell_h / 2.0
			var city_color: Color = SUCCESS if chapter._tower_connected[i] else WARN
			draw_circle(Vector2(cx, cy), cell_w * 0.35, city_color)
			draw_string(font, Vector2(cx - 5, cy + 5), "%c" % (65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BG)

		# Draw placed towers
		for tw in chapter._tower_grid:
			var tx: float = grid_x + tw.x * cell_w + cell_w / 2.0
			var ty: float = grid_y + tw.y * cell_h + cell_h / 2.0
			draw_rect(Rect2(tx - 4, ty - cell_h * 0.4, 8, cell_h * 0.4), ACCENT)
			draw_circle(Vector2(tx, ty - cell_h * 0.4), 6.0, ACCENT)

		# Draw cursor
		var cur_x: float = grid_x + chapter._tower_cursor.x * cell_w
		var cur_y: float = grid_y + chapter._tower_cursor.y * cell_h
		draw_rect(Rect2(cur_x, cur_y, cell_w, cell_h), Color(ACCENT, 0.2))
		draw_rect(Rect2(cur_x, cur_y, cell_w, cell_h), ACCENT, false, 2.0)

		# Budget
		draw_string(font, Vector2(grid_x, s.y - 60), "Towers remaining: %d" % chapter._tower_budget, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)

	func _draw_ch4(s: Vector2, font: Font, _t: float) -> void:
		# WiFi quiz
		draw_string(font, Vector2(100, 28), "WIFI CONFIG QUIZ — W/S select, ENTER confirm", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)

		if chapter._quiz_index >= chapter._quiz_questions.size():
			return

		var q: Dictionary = chapter._quiz_questions[chapter._quiz_index]
		var qy: float = s.y * 0.25

		# Question
		draw_string(font, Vector2(s.x * 0.1, qy), "Q%d: %s" % [chapter._quiz_index + 1, q["q"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)

		# Options
		var opts: Array = q["opts"]
		for i in range(opts.size()):
			var oy: float = qy + 60 + i * 50
			var is_sel: bool = i == chapter._quiz_selected
			var opt_color: Color

			if chapter._quiz_answered:
				if i == q["ans"]:
					opt_color = SUCCESS
				elif i == chapter._quiz_selected:
					opt_color = FAIL
				else:
					opt_color = Color(TEXT, 0.3)
			else:
				opt_color = ACCENT if is_sel else Color(TEXT, 0.5)

			if is_sel and not chapter._quiz_answered:
				draw_rect(Rect2(s.x * 0.12, oy - 22, s.x * 0.6, 35), Color(ACCENT, 0.1))
				draw_string(font, Vector2(s.x * 0.13, oy), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)

			draw_string(font, Vector2(s.x * 0.17, oy), "%s" % opts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, opt_color)

		# Score
		draw_string(font, Vector2(s.x * 0.1, s.y - 60), "Correct: %d / %d" % [chapter._quiz_correct_count, chapter._quiz_index + (1 if chapter._quiz_answered else 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)

	func _draw_ch5(s: Vector2, font: Font, _t: float) -> void:
		# Resource allocation
		draw_string(font, Vector2(100, 28), "BROADBAND WARS — A/D adjust, W/S select, ENTER submit", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)

		var labels: Array[String] = ["DSL", "CABLE", "WIRELESS"]
		var colors: Array[Color] = [Color("#3B82F6"), Color("#EF4444"), Color("#22C55E")]
		var center_y: float = s.y * 0.35

		var total: int = chapter._resource_tokens[0] + chapter._resource_tokens[1] + chapter._resource_tokens[2]

		for i in range(3):
			var iy: float = center_y + i * 80
			var is_sel: bool = i == chapter._resource_cursor

			if is_sel:
				draw_rect(Rect2(s.x * 0.1, iy - 25, s.x * 0.8, 60), Color(ACCENT, 0.08))
				draw_string(font, Vector2(s.x * 0.1, iy), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)

			draw_string(font, Vector2(s.x * 0.15, iy), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, colors[i])

			# Token bar
			var bar_x: float = s.x * 0.35
			for j in range(chapter.RESOURCE_TOTAL):
				var bx: float = bar_x + j * 30
				var filled: bool = j < chapter._resource_tokens[i]
				if filled:
					draw_rect(Rect2(bx, iy - 10, 24, 24), colors[i])
				else:
					draw_rect(Rect2(bx, iy - 10, 24, 24), Color(TEXT, 0.1))
				draw_rect(Rect2(bx, iy - 10, 24, 24), Color(TEXT, 0.2), false, 1.0)

			draw_string(font, Vector2(bar_x + chapter.RESOURCE_TOTAL * 30 + 10, iy + 5), "%d" % chapter._resource_tokens[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)

		# Total
		draw_string(font, Vector2(s.x * 0.15, s.y - 80), "Total tokens: %d / %d" % [total, chapter.RESOURCE_TOTAL], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT if total <= chapter.RESOURCE_TOTAL else FAIL)
		draw_string(font, Vector2(s.x * 0.15, s.y - 55), "Hint: Wireless is the future...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(WARN, 0.4))

	func _draw_ch6(s: Vector2, font: Font, _t: float) -> void:
		# Dish alignment
		draw_string(font, Vector2(100, 28), "DISH ALIGNMENT — A/D rotate, TAB switch dish", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)
		draw_string(font, Vector2(s.x - 200, 28), "Time: %.1fs" % chapter._dish_time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN if chapter._dish_time_left > 15.0 else FAIL)

		for i in range(3):
			var dx: float = s.x * (0.2 + i * 0.25)
			var dy: float = s.y * 0.45
			var is_current: bool = i == chapter._dish_current
			var is_aligned: bool = chapter._dish_aligned[i]

			# Dish base
			var base_color: Color = SUCCESS if is_aligned else (ACCENT if is_current else Color(TEXT, 0.3))
			draw_circle(Vector2(dx, dy), 50.0, Color(base_color, 0.2))
			draw_circle(Vector2(dx, dy), 50.0, base_color, false, 2.0)

			# Dish arm (current angle)
			var angle_rad: float = deg_to_rad(chapter._dish_angles[i])
			var arm_end := Vector2(dx + cos(angle_rad) * 45.0, dy + sin(angle_rad) * 45.0)
			draw_line(Vector2(dx, dy), arm_end, base_color, 3.0)
			draw_circle(arm_end, 6.0, base_color)

			# Target indicator (subtle hint)
			var target_rad: float = deg_to_rad(chapter._dish_targets[i])
			var target_end := Vector2(dx + cos(target_rad) * 55.0, dy + sin(target_rad) * 55.0)
			draw_circle(target_end, 4.0, Color(WARN, 0.3))

			# Label
			draw_string(font, Vector2(dx - 25, dy + 70), "Dish %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, base_color)
			draw_string(font, Vector2(dx - 15, dy + 88), "%.0f°" % chapter._dish_angles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.5))

			if is_aligned:
				draw_string(font, Vector2(dx - 30, dy + 106), "ALIGNED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SUCCESS)

	func _draw_ch7(s: Vector2, font: Font, t: float) -> void:
		# Boss fight
		draw_string(font, Vector2(100, 28), "EL REGULADOR — A/D dodge, SPACE install antenna", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN)
		draw_string(font, Vector2(s.x - 200, 28), "Time: %.1fs" % chapter._boss_time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WARN if chapter._boss_time_left > 20.0 else FAIL)

		# Boss at top
		var boss_y: float = s.y * 0.1
		var boss_pulse: float = (sin(t * 3.0) + 1.0) / 2.0
		draw_rect(Rect2(s.x * 0.35, boss_y, s.x * 0.3, 40), Color(FAIL, 0.2 + boss_pulse * 0.1))
		draw_string(font, Vector2(s.x * 0.38, boss_y + 28), "EL REGULADOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, FAIL)

		# Falling papers
		for paper in chapter._boss_papers:
			var px: float = paper["x"] * s.x
			var py: float = paper["y"] * s.y
			draw_rect(Rect2(px - 10, py - 8, 20, 16), Color(FAIL, 0.7))
			draw_string(font, Vector2(px - 6, py + 4), "§", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)

		# Player
		var player_x: float = chapter._boss_player_x * s.x
		var player_y: float = s.y * 0.9
		draw_rect(Rect2(player_x - 15, player_y - 20, 30, 20), WARN)
		draw_string(font, Vector2(player_x - 8, player_y - 5), "DA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BG)

		# Antenna progress bar
		var ant_x: float = s.x * 0.7
		var ant_y: float = s.y * 0.85
		draw_string(font, Vector2(ant_x, ant_y), "ANTENNA:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
		draw_rect(Rect2(ant_x, ant_y + 8, 150, 12), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(ant_x, ant_y + 8, 150 * chapter._boss_antenna_progress, 12), SUCCESS)
		draw_string(font, Vector2(ant_x + 155, ant_y + 18), "%.0f%%" % (chapter._boss_antenna_progress * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)

		# Installing indicator
		if chapter._boss_installing:
			var inst_pulse: float = (sin(t * 6.0) + 1.0) / 2.0
			draw_string(font, Vector2(player_x - 40, player_y - 35), "INSTALLING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SUCCESS, 0.5 + inst_pulse * 0.5))

		# Hits
		draw_string(font, Vector2(20, s.y - 30), "Hits taken: %d" % chapter._boss_hits, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, FAIL if chapter._boss_hits > 3 else TEXT)

	func _draw_results(s: Vector2, font: Font, t: float) -> void:
		var center_x: float = s.x / 2.0
		var pulse: float = (sin(t * 2.0) + 1.0) / 2.0

		# Title
		draw_string(font, Vector2(center_x - 120, s.y * 0.25), "CHAPTER COMPLETE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, SUCCESS)

		# Score
		draw_string(font, Vector2(center_x - 80, s.y * 0.4), "Score: %.0f / %.0f" % [chapter._score, chapter._max_score], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TEXT)

		# Rewards
		draw_string(font, Vector2(center_x - 80, s.y * 0.5), "+%d SP" % chapter.CHAPTER_SP, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
		draw_string(font, Vector2(center_x - 80, s.y * 0.55), "+%d KT" % chapter.CHAPTER_KT, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WARN)

		# Continue
		draw_string(font, Vector2(center_x - 100, s.y * 0.75), "ENTER to return to hub", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ACCENT, 0.5 + pulse * 0.5))

## Chapter info for dialog header display
const CHAPTERS_INFO: Array[Dictionary] = [
	{"num": 1, "title": "The First Signal"},
	{"num": 2, "title": "Radio Waves"},
	{"num": 3, "title": "Tower Builder"},
	{"num": 4, "title": "The Wireless Revolution"},
	{"num": 5, "title": "Broadband Wars"},
	{"num": 6, "title": "The WISP Pioneer"},
	{"num": 7, "title": "5G and Beyond"},
]
