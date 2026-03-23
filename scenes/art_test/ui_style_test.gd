class_name UIStyleTest
extends CanvasLayer
## NOC Dashboard-style HUD overlay for art style testing.
## Simulates the spectator view with signal meters, packet loss, and LINK DOWN alerts.

const NOC_BG := Color("#0F172A")
const NOC_TEXT := Color("#E2E8F0")
const SIGNAL_GOOD := Color("#22C55E")
const SIGNAL_WARN := Color("#F59E0B")
const SIGNAL_CRIT := Color("#EF4444")
const ACCENT := Color("#06B6D4")

var player1_signal: float = 85.0
var player2_signal: float = 72.0
var _uptime: float = 0.0
var _link_down_visible: bool = false
var _link_down_timer: float = 0.0

func _ready() -> void:
	layer = 10

func _process(delta: float) -> void:
	_uptime += delta
	# Simulate signal fluctuation
	player1_signal = clampf(player1_signal + randf_range(-2.0, 2.0) * delta * 10.0, 10.0, 100.0)
	player2_signal = clampf(player2_signal + randf_range(-3.0, 1.5) * delta * 10.0, 0.0, 100.0)

	if _link_down_visible:
		_link_down_timer -= delta
		if _link_down_timer <= 0.0:
			_link_down_visible = false

	queue_redraw()

func trigger_link_down() -> void:
	_link_down_visible = true
	_link_down_timer = 2.0
	player2_signal = 0.0

func _draw() -> void:
	var screen_size := get_viewport().get_visible_rect().size

	# Top bar (NOC dashboard header)
	draw_rect(Rect2(0, 0, screen_size.x, 50), NOC_BG)
	_draw_text("SIGNAL SMASH // NOC DASHBOARD", Vector2(20, 35), ACCENT, 20)
	_draw_text("UPTIME: %s" % _format_uptime(_uptime), Vector2(screen_size.x - 250, 35), NOC_TEXT, 18)

	# Player 1 signal meter (left)
	_draw_signal_panel(Vector2(20, 70), "RICO", player1_signal, ACCENT)

	# Player 2 signal meter (right)
	_draw_signal_panel(Vector2(screen_size.x - 320, 70), "ING. VERO", player2_signal, Color("#7C3AED"))

	# Bottom bar (stats)
	var bottom_y := screen_size.y - 60
	draw_rect(Rect2(0, bottom_y, screen_size.x, 60), NOC_BG)
	var packet_loss1 := (100.0 - player1_signal) * 0.3
	var packet_loss2 := (100.0 - player2_signal) * 0.5
	_draw_text("PKT LOSS: %.1f%%" % packet_loss1, Vector2(20, bottom_y + 35), _signal_color(100.0 - packet_loss1 * 3), 16)
	_draw_text("PKT LOSS: %.1f%%" % packet_loss2, Vector2(screen_size.x - 250, bottom_y + 35), _signal_color(100.0 - packet_loss2 * 3), 16)
	_draw_text("LATENCY: %dms" % int(randf_range(1, 15)), Vector2(screen_size.x / 2.0 - 80, bottom_y + 35), ACCENT, 16)

	# LINK DOWN alert
	if _link_down_visible:
		var flash_alpha := abs(sin(_link_down_timer * 8.0))
		var alert_color := Color(SIGNAL_CRIT, flash_alpha)
		draw_rect(Rect2(screen_size.x / 2.0 - 200, screen_size.y / 2.0 - 40, 400, 80), Color(NOC_BG, 0.9))
		draw_rect(Rect2(screen_size.x / 2.0 - 200, screen_size.y / 2.0 - 40, 400, 80), alert_color, false, 3.0)
		_draw_text("LINK DOWN", Vector2(screen_size.x / 2.0 - 80, screen_size.y / 2.0 + 15), alert_color, 36)

func _draw_signal_panel(pos: Vector2, name: String, signal_pct: float, name_color: Color) -> void:
	# Panel background
	draw_rect(Rect2(pos.x, pos.y, 300, 100), Color(NOC_BG, 0.85))
	draw_rect(Rect2(pos.x, pos.y, 300, 100), ACCENT, false, 1.0)

	# Player name
	_draw_text(name, Vector2(pos.x + 10, pos.y + 25), name_color, 18)

	# Signal value
	var sig_color := _signal_color(signal_pct)
	_draw_text("%.0f dBm" % (-90.0 + signal_pct * 0.5), Vector2(pos.x + 200, pos.y + 25), sig_color, 16)

	# Signal bar
	var bar_width := 260.0
	var bar_height := 20.0
	var bar_pos := Vector2(pos.x + 20, pos.y + 50)

	# Background bar
	draw_rect(Rect2(bar_pos.x, bar_pos.y, bar_width, bar_height), Color(0.2, 0.2, 0.2))

	# Fill bar with gradient color
	var fill_width := bar_width * (signal_pct / 100.0)
	draw_rect(Rect2(bar_pos.x, bar_pos.y, fill_width, bar_height), sig_color)

	# Signal percentage
	_draw_text("%.0f%%" % signal_pct, Vector2(pos.x + 120, pos.y + 90), sig_color, 22)

func _draw_text(text: String, pos: Vector2, color: Color, size: int) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _signal_color(pct: float) -> Color:
	if pct > 70.0:
		return SIGNAL_GOOD
	elif pct > 30.0:
		return SIGNAL_WARN
	else:
		return SIGNAL_CRIT

func _format_uptime(seconds: float) -> String:
	var hrs := int(seconds) / 3600
	var mins := (int(seconds) % 3600) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d:%02d" % [hrs, mins, secs]
