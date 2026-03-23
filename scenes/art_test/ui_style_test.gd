class_name UIStyleTest
extends CanvasLayer
## NOC Dashboard-style HUD overlay for art style testing.
## Uses a Control child node for custom drawing since CanvasLayer doesn't support _draw().

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
var _draw_node: Control

func _ready() -> void:
	layer = 10
	_draw_node = _HUDDraw.new()
	_draw_node.hud = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_uptime += delta
	player1_signal = clampf(player1_signal + randf_range(-2.0, 2.0) * delta * 10.0, 10.0, 100.0)
	player2_signal = clampf(player2_signal + randf_range(-3.0, 1.5) * delta * 10.0, 0.0, 100.0)

	if _link_down_visible:
		_link_down_timer -= delta
		if _link_down_timer <= 0.0:
			_link_down_visible = false

	_draw_node.queue_redraw()

func trigger_link_down() -> void:
	_link_down_visible = true
	_link_down_timer = 2.0
	player2_signal = 0.0

func signal_color(pct: float) -> Color:
	if pct > 70.0:
		return SIGNAL_GOOD
	elif pct > 30.0:
		return SIGNAL_WARN
	else:
		return SIGNAL_CRIT

func format_uptime(seconds: float) -> String:
	var hrs := int(seconds) / 3600
	var mins := (int(seconds) % 3600) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d:%02d" % [hrs, mins, secs]


class _HUDDraw extends Control:
	var hud: UIStyleTest

	func _draw() -> void:
		if hud == null:
			return

		var screen_size := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Top bar
		draw_rect(Rect2(0, 0, screen_size.x, 50), UIStyleTest.NOC_BG)
		draw_string(font, Vector2(20, 35), "SIGNAL SMASH // NOC DASHBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyleTest.ACCENT)
		draw_string(font, Vector2(screen_size.x - 280, 35), "UPTIME: %s" % hud.format_uptime(hud._uptime), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyleTest.NOC_TEXT)

		# Player 1 panel (left)
		_draw_signal_panel(Vector2(20, 70), "RICO", hud.player1_signal, UIStyleTest.ACCENT)

		# Player 2 panel (right)
		_draw_signal_panel(Vector2(screen_size.x - 320, 70), "ING. VERO", hud.player2_signal, Color("#7C3AED"))

		# Bottom bar
		var bottom_y := screen_size.y - 60
		draw_rect(Rect2(0, bottom_y, screen_size.x, 60), UIStyleTest.NOC_BG)
		var pkt1 := (100.0 - hud.player1_signal) * 0.3
		var pkt2 := (100.0 - hud.player2_signal) * 0.5
		draw_string(font, Vector2(20, bottom_y + 35), "PKT LOSS: %.1f%%" % pkt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hud.signal_color(100.0 - pkt1 * 3))
		draw_string(font, Vector2(screen_size.x - 250, bottom_y + 35), "PKT LOSS: %.1f%%" % pkt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hud.signal_color(100.0 - pkt2 * 3))
		draw_string(font, Vector2(screen_size.x / 2.0 - 80, bottom_y + 35), "LATENCY: %dms" % int(randf_range(1, 15)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIStyleTest.ACCENT)

		# LINK DOWN alert
		if hud._link_down_visible:
			var flash_alpha: float = absf(sin(hud._link_down_timer * 8.0))
			var alert_color := Color(UIStyleTest.SIGNAL_CRIT, flash_alpha)
			draw_rect(Rect2(screen_size.x / 2.0 - 200, screen_size.y / 2.0 - 40, 400, 80), Color(UIStyleTest.NOC_BG, 0.9))
			draw_rect(Rect2(screen_size.x / 2.0 - 200, screen_size.y / 2.0 - 40, 400, 80), alert_color, false, 3.0)
			draw_string(font, Vector2(screen_size.x / 2.0 - 80, screen_size.y / 2.0 + 15), "LINK DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, alert_color)

	func _draw_signal_panel(pos: Vector2, player_name: String, signal_pct: float, name_color: Color) -> void:
		var font := ThemeDB.fallback_font

		# Panel background
		draw_rect(Rect2(pos.x, pos.y, 300, 100), Color(UIStyleTest.NOC_BG, 0.85))
		draw_rect(Rect2(pos.x, pos.y, 300, 100), UIStyleTest.ACCENT, false, 1.0)

		# Player name
		draw_string(font, Vector2(pos.x + 10, pos.y + 25), player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, name_color)

		# Signal value
		var sig_color := hud.signal_color(signal_pct)
		draw_string(font, Vector2(pos.x + 200, pos.y + 25), "%.0f dBm" % (-90.0 + signal_pct * 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sig_color)

		# Signal bar background
		var bar_width := 260.0
		var bar_height := 20.0
		var bar_pos := Vector2(pos.x + 20, pos.y + 50)
		draw_rect(Rect2(bar_pos.x, bar_pos.y, bar_width, bar_height), Color(0.2, 0.2, 0.2))

		# Signal bar fill
		var fill_width := bar_width * (signal_pct / 100.0)
		draw_rect(Rect2(bar_pos.x, bar_pos.y, fill_width, bar_height), sig_color)

		# Signal percentage
		draw_string(font, Vector2(pos.x + 120, pos.y + 90), "%.0f%%" % signal_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, sig_color)
