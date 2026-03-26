extends Node3D
## Weather Dodge Mini-Game
## Active signal link that degrades with weather events.
## Players adjust transmission power to maintain link quality.
## Too much power = interference, too little = link drops.
##
## Teaches: Link budgets, weather fade margins, power control

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const LINK_MAX: float = 100.0
const POWER_ADJUST_SPEED: float = 60.0  # Units per second
const SCORE_PER_SECOND: float = 20.0    # Points per second while link > 50%
const WEATHER_SCROLL_SPEED: float = 80.0 # Pixels per second

var _base: Node3D

# Per-player state
var _player_power: Dictionary = {}       # { pid: float } — current power (0-100)
var _player_link: Dictionary = {}        # { pid: float } — link quality (0-100)

# Weather system
var _weather_events: Array[Dictionary] = []  # { type, intensity, x_pos, width }
var _weather_spawn_timer: float = 0.0
var _weather_types: Array[Dictionary] = [
	{ "name": "RAIN", "color": Color("#3B82F6"), "intensity_range": Vector2(0.2, 0.5) },
	{ "name": "SNOW", "color": Color("#E2E8F0"), "intensity_range": Vector2(0.3, 0.6) },
	{ "name": "SOLAR FLARE", "color": Color("#F59E0B"), "intensity_range": Vector2(0.5, 0.9) },
]

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Weather Dodge"
	_base.concept_taught = "Link budgets, weather fade margins, power control"
	_base.duration_seconds = 45.0
	_base.buff_stat = "stability"
	_base.buff_value = 15
	_base.music_index = 3
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_start_game()

func _start_game() -> void:
	_weather_events.clear()
	_weather_spawn_timer = 1.0
	for pid in _base.player_ids:
		_player_power[pid] = 50.0
		_player_link[pid] = 100.0

	_build_environment()

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1E293B")
	env.ambient_light_color = Color("#94A3B8")
	env.ambient_light_energy = 0.3
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 0.6
	add_child(sun)

func _process(delta: float) -> void:
	if not _base.is_running:
		return

	# Spawn weather events
	_weather_spawn_timer -= delta
	if _weather_spawn_timer <= 0.0:
		_spawn_weather()
		_weather_spawn_timer = randf_range(1.5, 3.5)

	# Scroll weather events
	for i in range(_weather_events.size() - 1, -1, -1):
		_weather_events[i]["x_pos"] -= WEATHER_SCROLL_SPEED * delta
		if _weather_events[i]["x_pos"] + _weather_events[i]["width"] < 0:
			_weather_events.remove_at(i)

	# Process player inputs
	_process_inputs(delta)

	# Update link quality and scores
	for pid in _base.player_ids:
		_update_link(pid, delta)

func _spawn_weather() -> void:
	var type_idx: int = randi() % _weather_types.size()
	var wt: Dictionary = _weather_types[type_idx]
	var intensity: float = randf_range(wt["intensity_range"].x, wt["intensity_range"].y)
	var viewport_w: float = 1280.0  # Approximate
	var event := {
		"type": wt["name"],
		"color": wt["color"],
		"intensity": intensity,
		"x_pos": viewport_w + 50.0,
		"width": randf_range(120.0, 250.0),
	}
	_weather_events.append(event)

func _process_inputs(delta: float) -> void:
	# P1 (WASD)
	if 1 in _base.player_ids:
		var p1_v: float = Input.get_axis("move_back", "move_forward")
		_player_power[1] += p1_v * POWER_ADJUST_SPEED * delta
		_player_power[1] = clampf(_player_power[1], 0.0, 100.0)

	# P2 (Arrows)
	if 2 in _base.player_ids:
		var p2_v: float = 0.0
		if Input.is_key_pressed(KEY_UP):
			p2_v += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			p2_v -= 1.0
		_player_power[2] += p2_v * POWER_ADJUST_SPEED * delta
		_player_power[2] = clampf(_player_power[2], 0.0, 100.0)

func _get_weather_intensity_at(x_center: float) -> float:
	## Returns combined weather intensity hitting the given x position
	var total: float = 0.0
	for event in _weather_events:
		var ex: float = event["x_pos"]
		var ew: float = event["width"]
		if x_center >= ex and x_center <= ex + ew:
			total += event["intensity"]
	return clampf(total, 0.0, 1.0)

func _update_link(pid: int, delta: float) -> void:
	var viewport_w: float = 1280.0
	# P1 manages left link (x = 25%), P2 manages right link (x = 75%)
	var link_x: float = viewport_w * 0.25 if pid == 1 else viewport_w * 0.75
	var weather_intensity: float = _get_weather_intensity_at(link_x)

	# Sweet spot: power should be roughly (40 + weather_intensity * 50)
	var ideal_power: float = 40.0 + weather_intensity * 50.0
	var power_diff: float = absf(_player_power[pid] - ideal_power)

	# Too high = interference penalty, too low = fade penalty
	var penalty: float = 0.0
	if _player_power[pid] > ideal_power + 10.0:
		# Interference — over-power
		penalty = (_player_power[pid] - ideal_power - 10.0) * 0.8
	elif _player_power[pid] < ideal_power - 10.0:
		# Under-powered — link fade
		penalty = (ideal_power - 10.0 - _player_power[pid]) * 1.2

	# Link quality trends toward (100 - penalty), smoothly
	var target_link: float = clampf(LINK_MAX - penalty, 0.0, LINK_MAX)
	_player_link[pid] = lerpf(_player_link[pid], target_link, delta * 3.0)

	# Score if link > 50%
	if _player_link[pid] > 50.0:
		_base.add_score(pid, SCORE_PER_SECOND * delta)

# ═══════════ DRAWING via CanvasLayer ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _WeatherDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _WeatherDraw extends Control:
	var game: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Background
		draw_rect(Rect2(0, 0, s.x, s.y), Color("#1E293B"))

		# Title
		draw_string(font, Vector2(s.x / 2.0 - 100, 35), "WEATHER DODGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#06B6D4"))
		draw_string(font, Vector2(s.x / 2.0 - 160, 60), "Adjust power to maintain link through weather!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0", 0.5))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var timer_col: Color = Color("#22C55E") if time_left > 15 else (Color("#F59E0B") if time_left > 5 else Color("#EF4444"))
		draw_string(font, Vector2(s.x - 80, 35), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, timer_col)

		# Weather zone (middle band)
		var weather_y: float = s.y * 0.15
		var weather_h: float = s.y * 0.25
		draw_rect(Rect2(0, weather_y, s.x, weather_h), Color("#0F172A", 0.5))
		draw_string(font, Vector2(10, weather_y + 18), "WEATHER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))

		# Draw weather events
		for event in game._weather_events:
			var ex: float = event["x_pos"]
			var ew: float = event["width"]
			var ec: Color = event["color"]
			var intensity: float = event["intensity"]
			draw_rect(Rect2(ex, weather_y, ew, weather_h), Color(ec, 0.3 + intensity * 0.4))
			draw_string(font, Vector2(ex + 5, weather_y + weather_h / 2.0), event["type"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ec, 0.9))
			draw_string(font, Vector2(ex + 5, weather_y + weather_h / 2.0 + 18), "%.0f%%" % (intensity * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ec)

		# Player link zones — P1 left quarter, P2 right quarter
		for pid in game._base.player_ids:
			var link_x: float = s.x * 0.05 if pid == 1 else s.x * 0.55
			var panel_w: float = s.x * 0.4
			var panel_y: float = s.y * 0.5
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var name_str: String = "P%d — %s LINK" % [pid, "LEFT" if pid == 1 else "RIGHT"]

			# Link indicator line in weather zone
			var indicator_x: float = s.x * 0.25 if pid == 1 else s.x * 0.75
			draw_line(Vector2(indicator_x, weather_y), Vector2(indicator_x, weather_y + weather_h), Color(col, 0.6), 3.0)

			# Panel background
			draw_rect(Rect2(link_x, panel_y, panel_w, s.y * 0.4), Color("#0F172A", 0.6))

			# Player name
			draw_string(font, Vector2(link_x + 10, panel_y + 25), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)

			# Link quality bar
			var link_val: float = game._player_link.get(pid, 0.0)
			var bar_x: float = link_x + 10
			var bar_y: float = panel_y + 40
			var bar_w: float = panel_w - 20
			var bar_h: float = 30.0
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#374151"))
			var link_col: Color
			if link_val > 70.0:
				link_col = Color("#22C55E")
			elif link_val > 50.0:
				link_col = Color("#F59E0B")
			else:
				link_col = Color("#EF4444")
			draw_rect(Rect2(bar_x, bar_y, bar_w * (link_val / 100.0), bar_h), link_col)
			draw_string(font, Vector2(bar_x + bar_w / 2.0 - 30, bar_y + 22), "LINK: %.0f%%" % link_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

			# Active/Inactive indicator
			if link_val > 50.0:
				var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) / 2.0
				draw_string(font, Vector2(bar_x, bar_y + 50), "SCORING +", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#22C55E", 0.5 + pulse * 0.5))
			else:
				draw_string(font, Vector2(bar_x, bar_y + 50), "LINK DOWN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#EF4444"))

			# Power slider
			var power_val: float = game._player_power.get(pid, 50.0)
			var slider_y: float = panel_y + 110
			draw_string(font, Vector2(bar_x, slider_y), "TX POWER:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0", 0.7))
			draw_rect(Rect2(bar_x + 100, slider_y - 12, bar_w - 110, 16), Color("#374151"))
			draw_rect(Rect2(bar_x + 100, slider_y - 12, (bar_w - 110) * (power_val / 100.0), 16), Color("#06B6D4"))
			# Slider knob
			var knob_x: float = bar_x + 100 + (bar_w - 110) * (power_val / 100.0)
			draw_rect(Rect2(knob_x - 3, slider_y - 16, 6, 24), Color.WHITE)
			draw_string(font, Vector2(knob_x + 10, slider_y + 2), "%.0f" % power_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#06B6D4"))

			# Sweet spot hint
			var weather_at_link: float = game._get_weather_intensity_at(s.x * (0.25 if pid == 1 else 0.75))
			var ideal: float = 40.0 + weather_at_link * 50.0
			var hint_x: float = bar_x + 100 + (bar_w - 110) * (ideal / 100.0)
			draw_line(Vector2(hint_x, slider_y - 18), Vector2(hint_x, slider_y + 10), Color("#22C55E", 0.4), 2.0)

			# Score
			var score: float = game._base.scores.get(pid, 0.0)
			draw_string(font, Vector2(bar_x, panel_y + s.y * 0.4 - 20), "SCORE: %.0f" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Controls
		draw_string(font, Vector2(40, s.y - 15), "P1: W/S adjust power", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 220, s.y - 15), "P2: Up/Down adjust power", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
