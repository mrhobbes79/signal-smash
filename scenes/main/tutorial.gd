extends Control
## SIGNAL SMASH — Interactive Tutorial
## Plays on first launch (0 fights, 0 SP). NOC Dashboard aesthetic.
## Step-by-step guide to controls with input detection.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const SUCCESS := Color("#22C55E")

var _current_step: int = 0
var _total_steps: int = 7
var _time: float = 0.0
var _step_completed: bool = false
var _draw_node: Control

var _steps: Array[Dictionary] = [
	{
		"title": "WELCOME TO SIGNAL SMASH",
		"instruction": "Your training begins now, technician.",
		"hint": "Press ENTER to continue",
		"type": "press_enter",
	},
	{
		"title": "MOVEMENT",
		"instruction": "Use WASD to move. Try it!",
		"hint": "[W] [A] [S] [D]",
		"type": "wasd",
	},
	{
		"title": "JUMPING",
		"instruction": "Press SPACE to jump!",
		"hint": "[SPACE]",
		"type": "space",
	},
	{
		"title": "ATTACKING",
		"instruction": "Press J to attack!",
		"hint": "[J]",
		"type": "j_key",
	},
	{
		"title": "SPECIAL ABILITY",
		"instruction": "Press Q for your special power!",
		"hint": "[Q]",
		"type": "q_key",
	},
	{
		"title": "FULL SIGNAL COMBO",
		"instruction": "Fill your combo meter by fighting, then press E for a devastating ultimate attack!",
		"hint": "Press ENTER to continue",
		"type": "press_enter",
	},
	{
		"title": "YOU'RE READY!",
		"instruction": "Go to Tournament mode to fight! Good luck!",
		"hint": "Press ENTER to begin",
		"type": "finish",
	},
]

func _ready() -> void:
	# Background color
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	# Custom draw layer
	_draw_node = _TutorialDraw.new()
	_draw_node.tutorial = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ESC to skip tutorial at any time
		if event.keycode == KEY_ESCAPE:
			_go_to_main_menu()
			return

		var step_data: Dictionary = _steps[_current_step]
		var step_type: String = step_data["type"]

		match step_type:
			"press_enter":
				if event.keycode == KEY_ENTER:
					_advance_step()
			"wasd":
				if event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
					_advance_step()
			"space":
				if event.keycode == KEY_SPACE:
					_advance_step()
			"j_key":
				if event.keycode == KEY_J:
					_advance_step()
			"q_key":
				if event.keycode == KEY_Q:
					_advance_step()
			"finish":
				if event.keycode == KEY_ENTER:
					_go_to_main_menu()

func _advance_step() -> void:
	_current_step += 1
	if _current_step >= _total_steps:
		_go_to_main_menu()
	if AudioManager:
		AudioManager.play_sfx("menu_select")

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


class _TutorialDraw extends Control:
	var tutorial: Node

	func _draw() -> void:
		if tutorial == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = tutorial._time
		var current: int = tutorial._current_step
		var total: int = tutorial._total_steps
		var step_data: Dictionary = tutorial._steps[current]

		# ═══════════ SCANNING LINE ═══════════
		var scan_y: float = fmod(t * 80.0, s.y)
		draw_rect(Rect2(0, scan_y, s.x, 1), Color(ACCENT, 0.05))

		# ═══════════ CORNER BRACKETS (NOC STYLE) ═══════════
		var bracket_size: float = 30.0
		var m: float = 15.0
		draw_line(Vector2(m, m), Vector2(m + bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m - bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m + bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)

		# ═══════════ HEADER ═══════════
		draw_string(font, Vector2(s.x / 2.0 - 120, 50), "SIGNAL SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ACCENT)
		draw_string(font, Vector2(s.x / 2.0 - 80, 75), "// TRAINING PROTOCOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))
		draw_rect(Rect2(s.x * 0.15, 85, s.x * 0.7, 2), Color(ACCENT, 0.3))

		# ═══════════ STEP NUMBER ═══════════
		var center_y: float = s.y * 0.35
		var step_label: String = "STEP %d / %d" % [current + 1, total]
		draw_string(font, Vector2(s.x / 2.0 - 60, center_y - 60), step_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))

		# ═══════════ PULSING BORDER BOX ═══════════
		var pulse: float = (sin(t * 3.0) + 1.0) / 2.0
		var box_x: float = s.x * 0.15
		var box_y: float = center_y - 40
		var box_w: float = s.x * 0.7
		var box_h: float = 200.0
		var border_color := Color(ACCENT, 0.3 + pulse * 0.4)
		draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(ACCENT, 0.05))
		draw_rect(Rect2(box_x, box_y, box_w, box_h), border_color, false, 2.0)

		# ═══════════ TITLE ═══════════
		var title: String = step_data["title"]
		var title_size: int = 42
		var title_x: float = s.x / 2.0 - float(title.length()) * 12.0
		draw_string(font, Vector2(title_x, center_y + 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, WARN)

		# ═══════════ INSTRUCTION ═══════════
		var instruction: String = step_data["instruction"]
		var instr_x: float = s.x / 2.0 - float(instruction.length()) * 5.5
		draw_string(font, Vector2(instr_x, center_y + 60), instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)

		# ═══════════ KEY HINT (animated) ═══════════
		var hint: String = step_data["hint"]
		var hint_pulse: float = (sin(t * 4.0) + 1.0) / 2.0
		var hint_color := Color(ACCENT, 0.5 + hint_pulse * 0.5)
		var hint_x: float = s.x / 2.0 - float(hint.length()) * 5.0
		draw_string(font, Vector2(hint_x, center_y + 110), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, hint_color)

		# Animated arrow pointing down at hint
		var arrow_y: float = center_y + 125 + sin(t * 3.0) * 8.0
		draw_string(font, Vector2(s.x / 2.0 - 8, arrow_y), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, hint_color)

		# ═══════════ COMPLETED STEPS (checkmarks) ═══════════
		var steps_y: float = s.y * 0.72
		for i in range(total):
			var dot_x: float = s.x / 2.0 - (total * 30.0) / 2.0 + i * 30.0
			if i < current:
				# Completed — checkmark
				draw_string(font, Vector2(dot_x, steps_y), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, SUCCESS)
			elif i == current:
				# Current — pulsing dot
				var dot_color := Color(ACCENT, 0.5 + pulse * 0.5)
				draw_circle(Vector2(dot_x + 6, steps_y - 5), 6.0, dot_color)
			else:
				# Future — dim dot
				draw_circle(Vector2(dot_x + 6, steps_y - 5), 4.0, Color(TEXT, 0.2))

		# ═══════════ PROGRESS BAR ═══════════
		var bar_y: float = s.y * 0.78
		var bar_x2: float = s.x * 0.2
		var bar_w2: float = s.x * 0.6
		var bar_h2: float = 8.0
		draw_rect(Rect2(bar_x2, bar_y, bar_w2, bar_h2), Color(0.1, 0.1, 0.15))
		var progress: float = float(current) / float(total)
		draw_rect(Rect2(bar_x2, bar_y, bar_w2 * progress, bar_h2), ACCENT)
		# Bar border
		draw_rect(Rect2(bar_x2, bar_y, bar_w2, bar_h2), Color(ACCENT, 0.3), false, 1.0)

		# ═══════════ BOTTOM INFO ═══════════
		var bottom_y := s.y - 50
		draw_rect(Rect2(0, bottom_y - 10, s.x, 60), Color(BG, 0.9))
		draw_rect(Rect2(0, bottom_y - 10, s.x, 1), Color(ACCENT, 0.3))
		draw_string(font, Vector2(20, bottom_y + 18), "ESC  Skip Tutorial", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.3))
		draw_string(font, Vector2(s.x - 250, bottom_y + 18), "Rigel Open Labs // #SignalSmash", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.3))
