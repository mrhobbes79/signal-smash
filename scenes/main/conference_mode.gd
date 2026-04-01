extends Control
## CONFERENCE MODE — One-tap tournament for WISPA booth operators.
## Press any button → 4-player bracket auto-starts.
## Semifinal 1 → Mini-Game → Semifinal 2 → Mini-Game → Final → Champion
## Zero friction, zero menus, zero gaming knowledge required.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const GOOD := Color("#22C55E")
const CRIT := Color("#EF4444")

const P_COLORS: Array[Color] = [Color("#2563EB"), Color("#7C3AED"), Color("#D97706"), Color("#059669")]
const P_ACCENTS: Array[Color] = [Color("#FCD34D"), Color("#06B6D4"), Color("#D97706"), Color("#10B981")]
const P_NAMES: Array[String] = ["RICO", "VERO", "AURELIO", "MORXEL"]
const P_ROLES: Array[String] = ["Cable Specialist", "Spectrum Engineer", "Old School Veteran", "Reality Hacker"]

enum Phase { WAITING, COUNTDOWN, SEMI1, MINI1, SEMI2, MINI2, FINAL, MINI_FINAL, CHAMPION }

var _phase: Phase = Phase.WAITING
var _countdown: float = 3.0
var _time: float = 0.0
var _round_timer: float = 0.0
var _champion_timer: float = 0.0

## Bracket: [semi1_p1, semi1_p2, semi2_p1, semi2_p2]
var _bracket: Array[int] = [0, 1, 2, 3]
var _semi1_winner: int = -1
var _semi2_winner: int = -1
var _final_winner: int = -1

## Simulated fight scores (since we can't run actual fights inline)
var _fight_scores: Array[float] = [0.0, 0.0]
var _fight_timer: float = 0.0
const FIGHT_DURATION: float = 10.0

var _draw_node: Control

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _ConferenceDraw.new()
	_draw_node.conf = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	if AudioManager:
		AudioManager.play_music_monterrey()

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

	match _phase:
		Phase.COUNTDOWN:
			_countdown -= delta
			if _countdown <= 0.0:
				_start_fight(Phase.SEMI1, _bracket[0], _bracket[1])
		Phase.SEMI1, Phase.SEMI2, Phase.FINAL:
			_update_fight(delta)
		Phase.MINI1, Phase.MINI2, Phase.MINI_FINAL:
			_round_timer -= delta
			if _round_timer <= 0.0:
				_advance_from_mini()
		Phase.CHAMPION:
			_champion_timer += delta

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match _phase:
		Phase.WAITING:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_phase = Phase.COUNTDOWN
				_countdown = 3.0
				if AudioManager:
					AudioManager.play_sfx("fight_start")
			elif event.keycode == KEY_ESCAPE:
				if AudioManager:
					AudioManager.stop_music()
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
		Phase.CHAMPION:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				# Restart tournament
				_phase = Phase.WAITING
				_semi1_winner = -1
				_semi2_winner = -1
				_final_winner = -1
				_champion_timer = 0.0
			elif event.keycode == KEY_ESCAPE:
				if AudioManager:
					AudioManager.stop_music()
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _start_fight(phase: Phase, p1_idx: int, p2_idx: int) -> void:
	_phase = phase
	_fight_scores = [0.0, 0.0]
	_fight_timer = 0.0
	if AudioManager:
		AudioManager.play_sfx("countdown")

func _update_fight(delta: float) -> void:
	_fight_timer += delta

	# Simulate fight — random scoring with momentum
	_fight_scores[0] += randf_range(0.5, 2.0) * delta * 10.0
	_fight_scores[1] += randf_range(0.5, 2.0) * delta * 10.0

	# Random big hits
	if randi() % 120 == 0:
		var target: int = randi() % 2
		_fight_scores[target] += randf_range(5, 15)
		if AudioManager:
			AudioManager.play_sfx("hit_light")

	if _fight_timer >= FIGHT_DURATION:
		_end_fight()

func _end_fight() -> void:
	var winner_local: int = 0 if _fight_scores[0] >= _fight_scores[1] else 1

	if AudioManager:
		AudioManager.play_sfx("round_end")

	match _phase:
		Phase.SEMI1:
			_semi1_winner = _bracket[0] if winner_local == 0 else _bracket[1]
			_phase = Phase.MINI1
			_round_timer = 3.0
		Phase.SEMI2:
			_semi2_winner = _bracket[2] if winner_local == 0 else _bracket[3]
			_phase = Phase.MINI2
			_round_timer = 3.0
		Phase.FINAL:
			_final_winner = _semi1_winner if winner_local == 0 else _semi2_winner
			_phase = Phase.CHAMPION
			_champion_timer = 0.0
			if AudioManager:
				AudioManager.play_sfx("victory")

func _advance_from_mini() -> void:
	match _phase:
		Phase.MINI1:
			_start_fight(Phase.SEMI2, _bracket[2], _bracket[3])
		Phase.MINI2:
			_start_fight(Phase.FINAL, _semi1_winner, _semi2_winner)
		Phase.MINI_FINAL:
			pass

func _get_fight_players() -> Array[int]:
	match _phase:
		Phase.SEMI1: return [_bracket[0], _bracket[1]]
		Phase.SEMI2: return [_bracket[2], _bracket[3]]
		Phase.FINAL: return [_semi1_winner, _semi2_winner]
	return [0, 1]


class _ConferenceDraw extends Control:
	var conf: Node

	func _draw() -> void:
		if conf == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		match conf._phase:
			Phase.WAITING:
				_draw_waiting(s, font)
			Phase.COUNTDOWN:
				_draw_countdown(s, font)
			Phase.SEMI1, Phase.SEMI2, Phase.FINAL:
				_draw_fight(s, font)
			Phase.MINI1, Phase.MINI2, Phase.MINI_FINAL:
				_draw_mini_break(s, font)
			Phase.CHAMPION:
				_draw_champion(s, font)

		# Always draw bracket
		_draw_bracket(s, font)

	func _draw_waiting(s: Vector2, font: Font) -> void:
		# Big SIGNAL SMASH title
		draw_string(font, Vector2(s.x / 2.0 - 220, s.y * 0.25), "SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, ACCENT)
		draw_string(font, Vector2(s.x / 2.0 + 30, s.y * 0.25), "SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, WARN)

		draw_string(font, Vector2(s.x / 2.0 - 120, s.y * 0.25 + 40), "CONFERENCE MODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TEXT)

		# Pulsing "Press any button"
		var pulse: float = (sin(conf._time * 3.0) + 1.0) / 2.0
		draw_string(font, Vector2(s.x / 2.0 - 150, s.y * 0.55), "PRESS ENTER TO START TOURNAMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(GOOD, 0.4 + pulse * 0.6))

		# Player slots
		draw_string(font, Vector2(s.x / 2.0 - 100, s.y * 0.7), "4-PLAYER BRACKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ACCENT)
		for i in range(4):
			var px: float = s.x * 0.15 + i * s.x * 0.2
			draw_rect(Rect2(px, s.y * 0.75, s.x * 0.15, 50), Color(P_COLORS[i], 0.2))
			draw_rect(Rect2(px, s.y * 0.75, s.x * 0.15, 50), P_COLORS[i], false, 2.0)
			draw_string(font, Vector2(px + 15, s.y * 0.75 + 32), "P%d %s" % [i + 1, P_NAMES[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, P_COLORS[i])

	func _draw_countdown(s: Vector2, font: Font) -> void:
		var count: int = ceili(conf._countdown)
		var scale: float = 1.0 + (conf._countdown - floorf(conf._countdown)) * 0.5
		var size: int = int(96 * scale)
		var text: String = str(count) if count > 0 else "FIGHT!"
		var col: Color = WARN if count > 0 else CRIT
		draw_string(font, Vector2(s.x / 2.0 - 40, s.y / 2.0 + 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

	func _draw_fighter_silhouette(cx: float, cy: float, color: Color, accent: Color, scale: float, t: float, is_attacking: bool) -> void:
		# Head
		draw_circle(Vector2(cx, cy - 40 * scale), 20 * scale, color)
		# Body
		draw_rect(Rect2(cx - 16 * scale, cy - 18 * scale, 32 * scale, 50 * scale), color)
		# Legs
		draw_rect(Rect2(cx - 14 * scale, cy + 32 * scale, 10 * scale, 20 * scale), Color(color, 0.8))
		draw_rect(Rect2(cx + 4 * scale, cy + 32 * scale, 10 * scale, 20 * scale), Color(color, 0.8))
		# Equipment accent on chest
		draw_rect(Rect2(cx - 10 * scale, cy - 10 * scale, 20 * scale, 14 * scale), accent)
		# Arms
		if is_attacking:
			# Attack pose — arm extended
			draw_rect(Rect2(cx + 16 * scale, cy - 12 * scale, 28 * scale, 8 * scale), color)
			# Attack flash
			draw_circle(Vector2(cx + 46 * scale, cy - 8 * scale), 6 * scale, Color(accent, 0.5 + sin(t * 12.0) * 0.5))
		else:
			# Idle arms
			draw_rect(Rect2(cx - 24 * scale, cy - 8 * scale, 8 * scale, 24 * scale), Color(color, 0.8))
			draw_rect(Rect2(cx + 16 * scale, cy - 8 * scale, 8 * scale, 24 * scale), Color(color, 0.8))

	func _draw_fight(s: Vector2, font: Font) -> void:
		var players: Array[int] = conf._get_fight_players()
		var p1: int = players[0]
		var p2: int = players[1]
		var t: float = conf._time

		# Round label
		var round_name: String = "SEMIFINAL 1" if conf._phase == Phase.SEMI1 else ("SEMIFINAL 2" if conf._phase == Phase.SEMI2 else "GRAND FINAL")
		draw_string(font, Vector2(s.x / 2.0 - 80, 40), round_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, WARN)

		# Character silhouettes — fighting area
		var arena_y: float = s.y * 0.18
		var arena_h: float = s.y * 0.35
		# Arena floor
		draw_rect(Rect2(s.x * 0.1, arena_y + arena_h - 10, s.x * 0.8, 10), Color(ACCENT, 0.15))
		draw_rect(Rect2(s.x * 0.1, arena_y + arena_h - 2, s.x * 0.8, 2), Color(ACCENT, 0.3))

		# Determine attack states from fight scores (simulate hits)
		var p1_attacking: bool = fmod(t, 1.5) < 0.3 and conf._fight_timer > 0.5
		var p2_attacking: bool = fmod(t + 0.7, 1.5) < 0.3 and conf._fight_timer > 0.5

		# P1 fighter (facing right)
		var p1_cx: float = s.x * 0.3
		var p1_cy: float = arena_y + arena_h - 65
		# Idle sway
		p1_cy += sin(t * 2.5) * 3.0
		_draw_fighter_silhouette(p1_cx, p1_cy, P_COLORS[p1], P_ACCENTS[p1], 1.2, t, p1_attacking)
		# Name under fighter
		draw_string(font, Vector2(p1_cx - 30, arena_y + arena_h + 20), P_NAMES[p1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, P_COLORS[p1])
		draw_string(font, Vector2(p1_cx - 40, arena_y + arena_h + 38), P_ROLES[p1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.4))

		# P2 fighter (facing left — mirrored)
		var p2_cx: float = s.x * 0.7
		var p2_cy: float = arena_y + arena_h - 65
		p2_cy += sin(t * 2.5 + 1.0) * 3.0
		_draw_fighter_silhouette(p2_cx, p2_cy, P_COLORS[p2], P_ACCENTS[p2], 1.2, t, p2_attacking)
		draw_string(font, Vector2(p2_cx - 30, arena_y + arena_h + 20), P_NAMES[p2], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, P_COLORS[p2])
		draw_string(font, Vector2(p2_cx - 40, arena_y + arena_h + 38), P_ROLES[p2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.4))

		# VS between fighters
		var vs_pulse: float = (sin(t * 5.0) + 1.0) / 2.0
		draw_string(font, Vector2(s.x / 2.0 - 20, arena_y + arena_h - 50), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(CRIT, 0.6 + vs_pulse * 0.4))

		# Hit sparks (random visual flashes during combat)
		if conf._fight_timer > 0.5 and fmod(t, 0.8) < 0.15:
			var spark_x: float = s.x * 0.5 + sin(t * 7.0) * s.x * 0.12
			var spark_y: float = arena_y + arena_h * 0.5 + cos(t * 5.0) * 20.0
			draw_circle(Vector2(spark_x, spark_y), 5.0, Color(WARN, 0.8))
			draw_circle(Vector2(spark_x + 8, spark_y - 5), 3.0, Color(1.0, 1.0, 1.0, 0.6))

		# Score panels below the arena
		var panel_y: float = s.y * 0.65

		# P1 panel
		draw_rect(Rect2(s.x * 0.1, panel_y, s.x * 0.3, 80), Color(P_COLORS[p1], 0.15))
		draw_rect(Rect2(s.x * 0.1, panel_y, s.x * 0.3, 80), P_COLORS[p1], false, 2.0)
		draw_string(font, Vector2(s.x * 0.1 + 20, panel_y + 28), P_NAMES[p1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, P_COLORS[p1])
		draw_string(font, Vector2(s.x * 0.1 + 20, panel_y + 50), "Score: %.0f" % conf._fight_scores[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
		# Score bar
		var bar1_w: float = (s.x * 0.3 - 40) * minf(conf._fight_scores[0] / 100.0, 1.0)
		draw_rect(Rect2(s.x * 0.1 + 20, panel_y + 58, s.x * 0.3 - 40, 12), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(s.x * 0.1 + 20, panel_y + 58, bar1_w, 12), P_COLORS[p1])

		# Timer (center between panels)
		var remaining: float = maxf(FIGHT_DURATION - conf._fight_timer, 0.0)
		var tc: Color = GOOD if remaining > 3.0 else CRIT
		draw_string(font, Vector2(s.x / 2.0 - 15, panel_y + 50), "%.0f" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tc)

		# P2 panel
		draw_rect(Rect2(s.x * 0.6, panel_y, s.x * 0.3, 80), Color(P_COLORS[p2], 0.15))
		draw_rect(Rect2(s.x * 0.6, panel_y, s.x * 0.3, 80), P_COLORS[p2], false, 2.0)
		draw_string(font, Vector2(s.x * 0.6 + 20, panel_y + 28), P_NAMES[p2], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, P_COLORS[p2])
		draw_string(font, Vector2(s.x * 0.6 + 20, panel_y + 50), "Score: %.0f" % conf._fight_scores[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
		var bar2_w: float = (s.x * 0.3 - 40) * minf(conf._fight_scores[1] / 100.0, 1.0)
		draw_rect(Rect2(s.x * 0.6 + 20, panel_y + 58, s.x * 0.3 - 40, 12), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(s.x * 0.6 + 20, panel_y + 58, bar2_w, 12), P_COLORS[p2])

	func _draw_mini_break(s: Vector2, font: Font) -> void:
		var text: String
		match conf._phase:
			Phase.MINI1:
				text = "SEMIFINAL 1 COMPLETE — %s WINS!" % P_NAMES[conf._semi1_winner]
			Phase.MINI2:
				text = "SEMIFINAL 2 COMPLETE — %s WINS!" % P_NAMES[conf._semi2_winner]
			_:
				text = "ROUND COMPLETE"

		draw_string(font, Vector2(s.x / 2.0 - 200, s.y * 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOOD)

		var next_text: String
		match conf._phase:
			Phase.MINI1:
				next_text = "Next: SEMIFINAL 2 — %s vs %s" % [P_NAMES[conf._bracket[2]], P_NAMES[conf._bracket[3]]]
			Phase.MINI2:
				next_text = "Next: GRAND FINAL — %s vs %s" % [P_NAMES[conf._semi1_winner], P_NAMES[conf._semi2_winner]]
			_:
				next_text = ""

		draw_string(font, Vector2(s.x / 2.0 - 180, s.y * 0.5), next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ACCENT)
		draw_string(font, Vector2(s.x / 2.0 - 40, s.y * 0.6), "%.0f..." % conf._round_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, WARN)

	func _draw_champion(s: Vector2, font: Font) -> void:
		var pulse: float = (sin(conf._time * 4.0) + 1.0) / 2.0
		var champ: int = conf._final_winner

		# Champion announcement
		draw_string(font, Vector2(s.x / 2.0 - 180, s.y * 0.2), "CONNECTATHON CHAMPION", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(WARN, 0.7 + pulse * 0.3))

		# Champion name — big and colored
		draw_string(font, Vector2(s.x / 2.0 - 100, s.y * 0.38), P_NAMES[champ], HORIZONTAL_ALIGNMENT_LEFT, -1, 72, P_COLORS[champ])

		# Trophy (simple visual)
		var tx: float = s.x / 2.0
		var ty: float = s.y * 0.55
		draw_rect(Rect2(tx - 25, ty, 50, 40), WARN)  # Cup
		draw_rect(Rect2(tx - 35, ty + 40, 70, 8), WARN)  # Base
		draw_rect(Rect2(tx - 15, ty + 48, 30, 15), Color("#78350F"))  # Stand

		# Five nines
		draw_string(font, Vector2(s.x / 2.0 - 60, s.y * 0.78), "FIVE NINES!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(GOOD, 0.5 + pulse * 0.5))
		draw_string(font, Vector2(s.x / 2.0 - 80, s.y * 0.85), "99.999% UPTIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ACCENT)

		# Restart prompt
		draw_string(font, Vector2(s.x / 2.0 - 130, s.y * 0.93), "ENTER = New Tournament | ESC = Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))

	func _draw_bracket(s: Vector2, font: Font) -> void:
		# Tournament bracket at the bottom
		var by: float = s.y - 120
		var bw: float = s.x * 0.8
		var bx: float = s.x * 0.1

		draw_rect(Rect2(bx, by, bw, 105), Color(BG, 0.9))
		draw_rect(Rect2(bx, by, bw, 105), Color(ACCENT, 0.2), false, 1.0)
		draw_string(font, Vector2(bx + 10, by + 18), "BRACKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)

		# Semi 1
		var s1_col: Color = GOOD if conf._semi1_winner == conf._bracket[0] else (CRIT if conf._semi1_winner == conf._bracket[1] else TEXT)
		draw_string(font, Vector2(bx + 20, by + 42), P_NAMES[conf._bracket[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, P_COLORS[conf._bracket[0]] if conf._semi1_winner != conf._bracket[1] else Color(TEXT, 0.3))
		draw_string(font, Vector2(bx + 110, by + 42), "vs", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.4))
		draw_string(font, Vector2(bx + 140, by + 42), P_NAMES[conf._bracket[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, P_COLORS[conf._bracket[1]] if conf._semi1_winner != conf._bracket[0] else Color(TEXT, 0.3))
		if conf._semi1_winner >= 0:
			draw_string(font, Vector2(bx + 250, by + 42), "→ %s" % P_NAMES[conf._semi1_winner], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOOD)

		# Semi 2
		draw_string(font, Vector2(bx + 20, by + 65), P_NAMES[conf._bracket[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, P_COLORS[conf._bracket[2]] if conf._semi2_winner != conf._bracket[3] else Color(TEXT, 0.3))
		draw_string(font, Vector2(bx + 110, by + 65), "vs", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.4))
		draw_string(font, Vector2(bx + 140, by + 65), P_NAMES[conf._bracket[3]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, P_COLORS[conf._bracket[3]] if conf._semi2_winner != conf._bracket[2] else Color(TEXT, 0.3))
		if conf._semi2_winner >= 0:
			draw_string(font, Vector2(bx + 250, by + 65), "→ %s" % P_NAMES[conf._semi2_winner], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOOD)

		# Final
		var final_x: float = bx + bw * 0.5
		draw_string(font, Vector2(final_x, by + 42), "FINAL:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, WARN)
		if conf._semi1_winner >= 0 and conf._semi2_winner >= 0:
			draw_string(font, Vector2(final_x + 60, by + 42), "%s vs %s" % [P_NAMES[conf._semi1_winner], P_NAMES[conf._semi2_winner]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
		if conf._final_winner >= 0:
			draw_string(font, Vector2(final_x, by + 65), "CHAMPION: %s" % P_NAMES[conf._final_winner], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(WARN, (sin(conf._time * 4.0) + 1.0) / 2.0 * 0.5 + 0.5))
