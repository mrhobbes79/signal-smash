extends CanvasLayer
## NOC Dashboard Spectator HUD
## Displays fight data as network monitoring: signal bars, packet loss,
## throughput, latency graph, LINK DOWN alerts, and auto-commentary.
## Designed for big screen readability at conferences.

const BG := Color("#0F172A")
const TEXT := Color("#E2E8F0")
const GOOD := Color("#22C55E")
const WARN := Color("#F59E0B")
const CRIT := Color("#EF4444")
const ACCENT := Color("#06B6D4")
const P1_COLOR := Color("#2563EB")
const P2_COLOR := Color("#7C3AED")

## Fighter references — set externally
var fighter1: CharacterBody3D
var fighter2: CharacterBody3D

var _uptime: float = 0.0
var _draw_node: Control

## Commentary system
var _commentary_text: String = ""
var _commentary_timer: float = 0.0
var _commentary_queue: Array[String] = []
var _last_p1_signal: float = 100.0
var _last_p2_signal: float = 100.0

## Hype callouts
var _hype_text: String = ""
var _hype_timer: float = 0.0
var _hype_scale: float = 1.0

## Announcer system — procedural voice-like tones + text overlays
var _announcer_text: String = ""
var _announcer_timer: float = 0.0
var _announcer_color: Color = Color("#06B6D4")

## Latency graph data
var _latency_history_p1: Array[float] = []
var _latency_history_p2: Array[float] = []
const GRAPH_POINTS: int = 60

func _ready() -> void:
	layer = 15
	_draw_node = _SpectatorDraw.new()
	_draw_node.hud = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# Initialize latency history
	for i in range(GRAPH_POINTS):
		_latency_history_p1.append(randf_range(2, 8))
		_latency_history_p2.append(randf_range(3, 10))

func _process(delta: float) -> void:
	_uptime += delta
	_commentary_timer -= delta
	_hype_timer -= delta
	_announcer_timer -= delta

	_update_latency_graph(delta)
	_check_commentary_triggers()

	_draw_node.queue_redraw()

func _update_latency_graph(delta: float) -> void:
	# Simulate latency based on fighter signal
	var p1_sig := _get_signal(fighter1)
	var p2_sig := _get_signal(fighter2)

	# Lower signal = higher latency spikes
	var p1_latency: float = randf_range(1, 5) + (100.0 - p1_sig) * 0.2
	var p2_latency: float = randf_range(1, 5) + (100.0 - p2_sig) * 0.2

	_latency_history_p1.append(p1_latency)
	_latency_history_p2.append(p2_latency)
	if _latency_history_p1.size() > GRAPH_POINTS:
		_latency_history_p1.pop_front()
	if _latency_history_p2.size() > GRAPH_POINTS:
		_latency_history_p2.pop_front()

func _check_commentary_triggers() -> void:
	if fighter1 == null or fighter2 == null:
		return

	var p1_sig := _get_signal(fighter1)
	var p2_sig := _get_signal(fighter2)

	# Dynamic character names
	var p1_name: String = GameMgr.get_p1().get("name", "P1")
	var p2_name: String = GameMgr.get_p2().get("name", "P2")

	# Big hit commentary + announcer hype
	if p1_sig < _last_p1_signal - 10.0:
		_add_commentary(_get_hit_commentary(p1_name, _last_p1_signal - p1_sig))
		var dmg1: float = _last_p1_signal - p1_sig
		if dmg1 >= 20.0:
			_trigger_announcer(_get_announcer_hype_line(), Color("#F59E0B"))
			if AudioManager:
				AudioManager.play_sfx("announce_hype")
	if p2_sig < _last_p2_signal - 10.0:
		_add_commentary(_get_hit_commentary(p2_name, _last_p2_signal - p2_sig))
		var dmg2: float = _last_p2_signal - p2_sig
		if dmg2 >= 20.0:
			_trigger_announcer(_get_announcer_hype_line(), Color("#F59E0B"))
			if AudioManager:
				AudioManager.play_sfx("announce_hype")

	# Low signal warning
	if p1_sig <= 25.0 and _last_p1_signal > 25.0:
		_add_commentary("⚠ %s's signal CRITICAL — one more hit and it's LINK DOWN!" % p1_name)
		_trigger_hype("SIGNAL CRITICAL!")
	if p2_sig <= 25.0 and _last_p2_signal > 25.0:
		_add_commentary("⚠ %s's signal CRITICAL — interference overload!" % p2_name)
		_trigger_hype("SIGNAL CRITICAL!")

	# KO commentary + announcer KO
	if p1_sig <= 0.0 and _last_p1_signal > 0.0:
		_add_commentary("🔴 %s LINK DOWN! Complete signal loss! %s takes the round!" % [p1_name, p2_name])
		_trigger_hype("LINK DOWN!")
		_trigger_announcer(_get_announcer_ko_line(p1_name), Color("#EF4444"))
		if AudioManager:
			AudioManager.play_sfx("announce_ko")
	if p2_sig <= 0.0 and _last_p2_signal > 0.0:
		_add_commentary("🔴 %s LINK DOWN! Total disconnection! %s dominates!" % [p2_name, p1_name])
		_trigger_hype("LINK DOWN!")
		_trigger_announcer(_get_announcer_ko_line(p2_name), Color("#EF4444"))
		if AudioManager:
			AudioManager.play_sfx("announce_ko")

	_last_p1_signal = p1_sig
	_last_p2_signal = p2_sig

	# Display next commentary
	if _commentary_timer <= 0.0 and _commentary_queue.size() > 0:
		_commentary_text = _commentary_queue.pop_front()
		_commentary_timer = 3.0

func _get_hit_commentary(target_name: String, damage: float) -> String:
	var lines: Array[String] = [
		"OH! %s takes %.0f%% signal degradation!" % [target_name, damage],
		"Direct hit on %s! That's a clean demodulation right there!" % target_name,
		"%s's throughput just TANKED! %.0f%% packet loss in one shot!" % [target_name, damage],
		"MASSIVE interference on %s's frequency! %.0f%% signal drop!" % [target_name, damage],
		"%s just got channel-bonded into next week! %.0f%% damage!" % [target_name, damage],
	]
	return lines[randi() % lines.size()]

func _add_commentary(text: String) -> void:
	_commentary_queue.append(text)

func _trigger_hype(text: String) -> void:
	_hype_text = text
	_hype_timer = 2.0
	_hype_scale = 2.0

## ═══════════ ANNOUNCER SYSTEM ═══════════

func _trigger_announcer(text: String, color: Color = Color("#06B6D4")) -> void:
	_announcer_text = text
	_announcer_timer = 2.5
	_announcer_color = color

func trigger_announcer_combo() -> void:
	## Called externally when FULL SIGNAL COMBO fires
	_trigger_announcer(_get_announcer_combo_line(), Color("#FCD34D"))
	if AudioManager:
		AudioManager.play_sfx("announce_combo")

func _get_announcer_hype_line() -> String:
	var lines: Array[String] = [
		"MASSIVE SIGNAL DROP!",
		"CRITICAL INTERFERENCE!",
		"HUGE DEMODULATION HIT!",
		"BANDWIDTH CRUSHED!",
		"PACKET STORM!",
		"SIGNAL DECIMATED!",
	]
	return lines[randi() % lines.size()]

func _get_announcer_ko_line(name: String) -> String:
	var lines: Array[String] = [
		"%s IS DOWN! LINK TERMINATED!" % name,
		"TOTAL SIGNAL LOSS FOR %s!" % name,
		"%s DISCONNECTED! IT'S OVER!" % name,
		"FLATLINE! %s HAS ZERO BARS!" % name,
	]
	return lines[randi() % lines.size()]

func _get_announcer_combo_line() -> String:
	var lines: Array[String] = [
		"FULL SIGNAL COMBO! UNBELIEVABLE!",
		"MAXIMUM THROUGHPUT ACHIEVED!",
		"FIVE NINES! FULL SIGNAL DEVASTATION!",
		"99.999% UPTIME COMBO! INCREDIBLE!",
	]
	return lines[randi() % lines.size()]

func _get_signal(fighter: CharacterBody3D) -> float:
	if fighter and fighter.has_method("get") and "signal_percent" in fighter:
		return fighter.signal_percent
	return 100.0

func _get_damage(fighter: CharacterBody3D) -> float:
	if fighter and "damage_accumulated" in fighter:
		return fighter.damage_accumulated
	return 0.0

func _get_state(fighter: CharacterBody3D) -> String:
	var sm = fighter.get_node_or_null("StateMachine") if fighter else null
	if sm and sm.current_state:
		return sm.current_state.name
	return "?"

static func signal_color(pct: float) -> Color:
	if pct > 70.0:
		return GOOD
	elif pct > 30.0:
		return WARN
	else:
		return CRIT

static func format_uptime(seconds: float) -> String:
	var hrs := int(seconds) / 3600
	var mins := (int(seconds) % 3600) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d:%02d" % [hrs, mins, secs]


## Inner class that handles all custom drawing
class _SpectatorDraw extends Control:
	var hud: Node  # Reference to parent spectator HUD

	func _draw() -> void:
		if hud == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var f1 = hud.fighter1
		var f2 = hud.fighter2
		var p1_sig: float = hud._get_signal(f1)
		var p2_sig: float = hud._get_signal(f2)

		# ═══════════ TOP BAR ═══════════
		draw_rect(Rect2(0, 0, s.x, 60), BG)
		# Title
		draw_string(font, Vector2(20, 42), "SIGNAL SMASH // NOC DASHBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ACCENT)
		# Uptime
		draw_string(font, Vector2(s.x - 300, 42), "UPTIME: %s" % hud.format_uptime(hud._uptime), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)

		# ═══════════ PLAYER PANELS ═══════════
		var p1_name: String = GameMgr.get_p1().get("name", "P1")
		var p2_name: String = GameMgr.get_p2().get("name", "P2")
		_draw_player_panel(Vector2(20, 75), p1_name, "P1", p1_sig, hud._get_damage(f1), hud._get_state(f1), P1_COLOR, s.x / 2.0 - 40)
		_draw_player_panel(Vector2(s.x / 2.0 + 20, 75), p2_name, "P2", p2_sig, hud._get_damage(f2), hud._get_state(f2), P2_COLOR, s.x / 2.0 - 40)

		# ═══════════ LATENCY GRAPH ═══════════
		var graph_y: float = s.y - 180
		draw_rect(Rect2(20, graph_y, s.x - 40, 100), Color(BG, 0.9))
		draw_rect(Rect2(20, graph_y, s.x - 40, 100), ACCENT, false, 1.0)
		draw_string(font, Vector2(30, graph_y + 18), "LATENCY (ms)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)

		_draw_graph(Vector2(30, graph_y + 25), Vector2(s.x / 2.0 - 50, 65), hud._latency_history_p1, P1_COLOR)
		_draw_graph(Vector2(s.x / 2.0 + 10, graph_y + 25), Vector2(s.x / 2.0 - 50, 65), hud._latency_history_p2, P2_COLOR)

		# ═══════════ BOTTOM BAR ═══════════
		var bottom_y := s.y - 65
		draw_rect(Rect2(0, bottom_y, s.x, 65), BG)

		# Packet loss
		var pkt1: float = (100.0 - p1_sig) * 0.4
		var pkt2: float = (100.0 - p2_sig) * 0.4
		draw_string(font, Vector2(20, bottom_y + 25), "P1 PKT LOSS: %.1f%%" % pkt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hud.signal_color(100.0 - pkt1 * 2.5))
		draw_string(font, Vector2(s.x - 250, bottom_y + 25), "P2 PKT LOSS: %.1f%%" % pkt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hud.signal_color(100.0 - pkt2 * 2.5))

		# Throughput
		var tp1: float = p1_sig * 10.0  # Fake Mbps based on signal
		var tp2: float = p2_sig * 10.0
		draw_string(font, Vector2(20, bottom_y + 50), "THROUGHPUT: %.0f Mbps" % tp1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
		draw_string(font, Vector2(s.x - 250, bottom_y + 50), "THROUGHPUT: %.0f Mbps" % tp2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)

		# Center stats
		draw_string(font, Vector2(s.x / 2.0 - 60, bottom_y + 25), "ROUND 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)
		draw_string(font, Vector2(s.x / 2.0 - 80, bottom_y + 50), "SIGNAL SMASH v0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.5))

		# ═══════════ COMMENTARY ═══════════
		if hud._commentary_timer > 0.0 and hud._commentary_text != "":
			var comment_y := s.y - 250
			draw_rect(Rect2(40, comment_y, s.x - 80, 45), Color(BG, 0.9))
			draw_rect(Rect2(40, comment_y, s.x - 80, 45), WARN, false, 1.0)
			draw_string(font, Vector2(55, comment_y + 30), hud._commentary_text, HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 110), 18, WARN)

		# ═══════════ HYPE CALLOUT ═══════════
		if hud._hype_timer > 0.0:
			hud._hype_scale = lerpf(hud._hype_scale, 1.0, 0.1)
			var hype_alpha: float = clampf(hud._hype_timer / 2.0, 0.0, 1.0)
			var hype_size: int = int(72 * hud._hype_scale)
			var hype_color: Color
			if hud._hype_text == "LINK DOWN!":
				var flash: float = absf(sin(hud._hype_timer * 8.0))
				hype_color = Color(CRIT, flash)
			else:
				hype_color = Color(WARN, hype_alpha)
			var hype_x: float = s.x / 2.0 - float(hype_size) * 2.0
			draw_string(font, Vector2(hype_x, s.y / 2.0), hud._hype_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hype_size, hype_color)

		# ═══════════ ANNOUNCER OVERLAY ═══════════
		if hud._announcer_timer > 0.0 and hud._announcer_text != "":
			var ann_alpha: float = clampf(hud._announcer_timer / 2.5, 0.0, 1.0)
			var ann_y: float = s.y * 0.3
			# Background bar
			draw_rect(Rect2(s.x * 0.15, ann_y - 5, s.x * 0.7, 40), Color(BG, 0.85 * ann_alpha))
			draw_rect(Rect2(s.x * 0.15, ann_y - 5, s.x * 0.7, 40), Color(hud._announcer_color, 0.6 * ann_alpha), false, 2.0)
			# Announcer text centered
			draw_string(font, Vector2(s.x * 0.5 - 200, ann_y + 25), hud._announcer_text, HORIZONTAL_ALIGNMENT_CENTER, 400, 24, Color(hud._announcer_color, ann_alpha))

	func _draw_player_panel(pos: Vector2, name: String, player_tag: String, signal_pct: float, damage: float, state: String, color: Color, width: float) -> void:
		var font := ThemeDB.fallback_font
		var h: float = 80.0

		# Panel bg
		draw_rect(Rect2(pos.x, pos.y, width, h), Color(BG, 0.9))
		draw_rect(Rect2(pos.x, pos.y, width, h), color, false, 2.0)

		# Player name + tag
		draw_string(font, Vector2(pos.x + 15, pos.y + 28), "%s [%s]" % [name, player_tag], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)

		# Signal dBm
		var dbm: float = -90.0 + signal_pct * 0.5
		var sig_col: Color = hud.signal_color(signal_pct)
		draw_string(font, Vector2(pos.x + width - 150, pos.y + 28), "%.0f dBm" % dbm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, sig_col)

		# Signal bar
		var bar_x: float = pos.x + 15
		var bar_y: float = pos.y + 40
		var bar_w: float = width - 30
		var bar_h: float = 16.0
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(bar_x, bar_y, bar_w * (signal_pct / 100.0), bar_h), sig_col)

		# Signal percentage + state
		draw_string(font, Vector2(pos.x + 15, pos.y + 73), "SIGNAL: %.0f%%" % signal_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sig_col)
		draw_string(font, Vector2(pos.x + width - 150, pos.y + 73), "STATE: %s" % state.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)

	func _draw_graph(pos: Vector2, size: Vector2, data: Array, color: Color) -> void:
		if data.size() < 2:
			return
		var max_val: float = 50.0
		var points: PackedVector2Array = []
		for i in range(data.size()):
			var x: float = pos.x + (float(i) / float(data.size() - 1)) * size.x
			var y: float = pos.y + size.y - (clampf(data[i], 0, max_val) / max_val) * size.y
			points.append(Vector2(x, y))
		if points.size() >= 2:
			draw_polyline(points, color, 1.5, true)
