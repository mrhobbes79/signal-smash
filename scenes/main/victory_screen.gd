extends Control
## Victory Screen — Shown after a fight ends.
## Displays winner, SP/KT earned, phase progress, and options.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const GOOD := Color("#22C55E")
const CRIT := Color("#EF4444")

var _time: float = 0.0
var _draw_node: Control
var _result: Dictionary = {}
var _phase_before: int = 0
var _phase_after: int = 0
var _leveled_up: bool = false

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _VictoryDraw.new()
	_draw_node.screen = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# Get result from progression manager
	if Progression:
		_result = Progression.last_fight_result
		_phase_before = _result.get("phase_before", Progression.current_phase)
		_phase_after = Progression.current_phase
		_leveled_up = _phase_after > _phase_before

	if AudioManager:
		if _result.get("won", false):
			AudioManager.play_sfx("victory")
		else:
			AudioManager.play_sfx("link_down")

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if _time < 1.0:
		return  # Prevent accidental skip

	match event.keycode:
		KEY_ENTER, KEY_SPACE:
			# Rematch — go back to character select
			get_tree().change_scene_to_file("res://scenes/main/character_select.tscn")
		KEY_ESCAPE:
			# Main menu
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


class _VictoryDraw extends Control:
	var screen: Node

	func _draw() -> void:
		if screen == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = screen._time
		var result: Dictionary = screen._result
		var won: bool = result.get("won", false)
		var perfect: bool = result.get("perfect", false)

		# ═══════════ HEADER ═══════════
		var header_color: Color = GOOD if won else CRIT
		var pulse: float = (sin(t * 3.0) + 1.0) / 2.0

		# Round score
		var p1r: int = result.get("p1_rounds", 0)
		var p2r: int = result.get("p2_rounds", 0)
		var round_text: String = "  [%d - %d]" % [p1r, p2r] if p1r + p2r > 0 else ""

		if won:
			draw_string(font, Vector2(s.x / 2.0 - 180, s.y * 0.12), "SIGNAL LOCKED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(header_color, 0.7 + pulse * 0.3))
			if round_text:
				draw_string(font, Vector2(s.x / 2.0 - 60, s.y * 0.18), round_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(ACCENT, 0.7))
			if perfect:
				draw_string(font, Vector2(s.x / 2.0 - 130, s.y * 0.22), "ZERO PACKET LOSS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(WARN, 0.5 + pulse * 0.5))
		else:
			draw_string(font, Vector2(s.x / 2.0 - 160, s.y * 0.12), "LINK DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(header_color, 0.7 + pulse * 0.3))
			if round_text:
				draw_string(font, Vector2(s.x / 2.0 - 60, s.y * 0.18), round_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(ACCENT, 0.7))
			draw_string(font, Vector2(s.x / 2.0 - 140, s.y * 0.22), "Signal lost. Retry?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(TEXT, 0.5))

		# Divider
		draw_rect(Rect2(s.x * 0.1, s.y * 0.22, s.x * 0.8, 2), Color(ACCENT, 0.3))

		# ═══════════ REWARDS ═══════════
		var ry: float = s.y * 0.28
		draw_string(font, Vector2(s.x * 0.15, ry), "REWARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ACCENT)
		ry += 40

		# SP earned
		var sp: int = result.get("sp_earned", 0)
		draw_string(font, Vector2(s.x * 0.15, ry), "Signal Points:", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
		draw_string(font, Vector2(s.x * 0.55, ry), "+%d SP" % sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOOD)
		ry += 35

		# KT earned
		var kt: int = result.get("kt_earned", 0)
		if kt > 0:
			draw_string(font, Vector2(s.x * 0.15, ry), "Knowledge Tokens:", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
			draw_string(font, Vector2(s.x * 0.55, ry), "+%d KT" % kt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, WARN)
			ry += 35

		# Totals
		ry += 15
		draw_rect(Rect2(s.x * 0.1, ry - 10, s.x * 0.8, 1), Color(ACCENT, 0.15))
		ry += 10
		draw_string(font, Vector2(s.x * 0.15, ry), "Total SP: %d" % Progression.signal_points, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))
		draw_string(font, Vector2(s.x * 0.5, ry), "Total KT: %d" % Progression.knowledge_tokens, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))
		ry += 25
		draw_string(font, Vector2(s.x * 0.15, ry), "Wins: %d" % Progression.total_wins, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))
		draw_string(font, Vector2(s.x * 0.5, ry), "Fights: %d" % Progression.total_fights, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))

		# ═══════════ PHASE PROGRESS ═══════════
		ry += 50
		draw_rect(Rect2(s.x * 0.1, ry - 10, s.x * 0.8, 1), Color(ACCENT, 0.15))

		var phase_color: Color = Progression.get_phase_color()
		draw_string(font, Vector2(s.x * 0.15, ry + 10), "RANK:", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ACCENT)
		draw_string(font, Vector2(s.x * 0.28, ry + 10), Progression.get_phase_name().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, phase_color)

		# Phase-up celebration
		if screen._leveled_up:
			var lu_pulse: float = (sin(t * 5.0) + 1.0) / 2.0
			draw_string(font, Vector2(s.x * 0.55, ry + 10), "RANK UP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(WARN, 0.5 + lu_pulse * 0.5))

		# Progress bar toward next phase
		ry += 40
		var progress: float = Progression.get_phase_progress()
		var reqs := Progression.get_next_phase_requirements()

		if not reqs.get("maxed", false):
			draw_string(font, Vector2(s.x * 0.15, ry), "Next rank progress:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))
			ry += 18

			# Progress bar bg
			var bar_x: float = s.x * 0.15
			var bar_w: float = s.x * 0.7
			var bar_h: float = 18.0
			draw_rect(Rect2(bar_x, ry, bar_w, bar_h), Color(0.1, 0.1, 0.15))
			# Progress bar fill
			var fill_w: float = bar_w * clampf(progress, 0.0, 1.0)
			draw_rect(Rect2(bar_x, ry, fill_w, bar_h), phase_color)
			# Percentage
			draw_string(font, Vector2(bar_x + bar_w + 10, ry + 14), "%d%%" % int(progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, phase_color)

			# Requirements
			ry += 30
			draw_string(font, Vector2(s.x * 0.15, ry), "Need: %d/%d SP | %d/%d KT | %d/%d Wins" % [
				Progression.signal_points, reqs["sp"],
				Progression.knowledge_tokens, reqs["kt"],
				Progression.total_wins, reqs["wins"],
			], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.35))
		else:
			draw_string(font, Vector2(s.x * 0.15, ry), "MAX RANK — LEYENDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(WARN, 0.7 + pulse * 0.3))

		# ═══════════ BOTTOM CONTROLS ═══════════
		var bottom_y: float = s.y - 80
		draw_rect(Rect2(0, bottom_y, s.x, 80), BG)
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		draw_string(font, Vector2(s.x / 2.0 - 180, bottom_y + 35), "ENTER = Rematch", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOOD)
		draw_string(font, Vector2(s.x / 2.0 + 40, bottom_y + 35), "ESC = Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(TEXT, 0.4))
