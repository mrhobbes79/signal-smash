extends Node3D
## WiFi 7 Channel Master Mini-Game
## Players manage 3 simultaneous links (2.4GHz + 5GHz + 6GHz) via MLO.
## 320MHz wide channels. Balance traffic across links — overload one = packet loss.
##
## Teaches: WiFi 7, Multi-Link Operation (MLO), 320MHz channels, band steering

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const BAND_NAMES := ["2.4 GHz", "5 GHz", "6 GHz"]
const BAND_COLORS := [Color("#F59E0B"), Color("#3B82F6"), Color("#8B5CF6")]
const BAND_MAX_CAPACITY := [40.0, 160.0, 320.0]  # MHz bandwidth per band
const OVERLOAD_THRESHOLD := 0.9  # 90% = danger zone
const PACKET_LOSS_THRESHOLD := 1.0  # 100% = dropping packets

const TRAFFIC_SPAWN_INTERVAL := 0.8  # seconds between new traffic bursts
const TRAFFIC_BURST_MIN := 10.0
const TRAFFIC_BURST_MAX := 80.0
const DRAIN_RATE := 30.0  # MHz freed per second naturally
const SCORE_PER_SECOND := 20.0  # Base score for keeping links healthy
const PENALTY_PER_LOSS := 15.0  # Score lost per packet drop

var _base: Node3D

# Per-player state
var _player_band_load: Dictionary = {}  # { pid: [float, float, float] }
var _player_active_band: Dictionary = {}  # { pid: int } — which band they're steering to
var _player_packet_losses: Dictionary = {}  # { pid: int }
var _player_packets_routed: Dictionary = {}  # { pid: int }

var _traffic_timer: float = 0.0
var _pending_traffic: Dictionary = {}  # { pid: float } — incoming traffic to route

# CanvasLayer for _draw overlay
var _overlay: Control
var _canvas: CanvasLayer

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "WiFi 7 Channel Master"
	_base.concept_taught = "WiFi 7 MLO, 320MHz channels, multi-band management"
	_base.duration_seconds = 45.0
	_base.buff_stat = "speed"
	_base.buff_value = 15
	_base.music_index = 3
	add_child(_base)

	# Overlay for 2D drawing
	_canvas = CanvasLayer.new()
	_canvas.layer = 5
	add_child(_canvas)
	_overlay = _WiFi7Overlay.new()
	_overlay.game = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_start_game()

func _start_game() -> void:
	_traffic_timer = 0.0
	for pid in _base.player_ids:
		_player_band_load[pid] = [0.0, 0.0, 0.0]
		_player_active_band[pid] = 1  # Default to 5GHz
		_player_packet_losses[pid] = 0
		_player_packets_routed[pid] = 0
		_pending_traffic[pid] = 0.0

	_build_environment()

func _build_environment() -> void:
	# Ground
	var ground := ProceduralMesh.create_platform(20.0, 20.0, 0.2, Color("#0F172A"))
	ground.position.y = -0.1
	add_child(ground)

	# WiFi 7 router model (center)
	var router_body := ProceduralMesh.create_box(Vector3(1.5, 0.3, 0.8), Color("#1E293B"))
	router_body.position = Vector3(0, 0.5, -3.0)
	add_child(router_body)

	# Triple antennas for tri-band
	for i in range(3):
		var ant := ProceduralMesh.create_cylinder(0.03, 1.0, 6, BAND_COLORS[i])
		ant.position = Vector3(-0.5 + i * 0.5, 1.2, -3.0)
		add_child(ant)
		var tip := ProceduralMesh.create_sphere(0.06, 6, BAND_COLORS[i])
		tip.position = Vector3(-0.5 + i * 0.5, 1.8, -3.0)
		add_child(tip)

	# Band label towers
	for i in range(3):
		var tower := ProceduralMesh.create_cylinder(0.05, 2.0, 6, BAND_COLORS[i])
		tower.position = Vector3(-4.0 + i * 4.0, 1.0, 0.0)
		add_child(tower)
		var label := Label3D.new()
		label.text = BAND_NAMES[i]
		label.font_size = 24
		label.position = Vector3(-4.0 + i * 4.0, 2.5, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = BAND_COLORS[i]
		label.outline_size = 3
		label.outline_modulate = Color.BLACK
		add_child(label)

	# Lighting
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 0.8
	add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0F172A")
	env.ambient_light_color = Color("#06B6D4")
	env.ambient_light_energy = 0.2
	env_node.environment = env
	add_child(env_node)

func _process(delta: float) -> void:
	if not _base.is_running:
		return

	_process_inputs(delta)
	_traffic_timer += delta

	# Spawn traffic bursts
	if _traffic_timer >= TRAFFIC_SPAWN_INTERVAL:
		_traffic_timer = 0.0
		for pid in _base.player_ids:
			var burst: float = randf_range(TRAFFIC_BURST_MIN, TRAFFIC_BURST_MAX)
			_pending_traffic[pid] += burst

	# Process each player
	for pid in _base.player_ids:
		_update_player(pid, delta)

	if _overlay:
		_overlay.queue_redraw()

func _process_inputs(_delta: float) -> void:
	# P1: A/D to switch band, Space to route traffic
	if 1 in _base.player_ids:
		if Input.is_action_just_pressed("move_left"):
			_player_active_band[1] = maxi(_player_active_band[1] - 1, 0)
		if Input.is_action_just_pressed("move_right"):
			_player_active_band[1] = mini(_player_active_band[1] + 1, 2)
		if Input.is_action_just_pressed("jump"):
			_route_traffic(1)

	# P2: Arrow keys to switch band, Shift to route
	if 2 in _base.player_ids:
		if Input.is_key_pressed(KEY_LEFT) and not Input.is_key_pressed(KEY_RIGHT):
			if not _p2_left_held:
				_player_active_band[2] = maxi(_player_active_band[2] - 1, 0)
				_p2_left_held = true
		else:
			_p2_left_held = false
		if Input.is_key_pressed(KEY_RIGHT) and not Input.is_key_pressed(KEY_LEFT):
			if not _p2_right_held:
				_player_active_band[2] = mini(_player_active_band[2] + 1, 2)
				_p2_right_held = true
		else:
			_p2_right_held = false
		if Input.is_key_pressed(KEY_SHIFT):
			if not _p2_shift_held:
				_route_traffic(2)
				_p2_shift_held = true
		else:
			_p2_shift_held = false

var _p2_left_held: bool = false
var _p2_right_held: bool = false
var _p2_shift_held: bool = false

func _route_traffic(pid: int) -> void:
	if _pending_traffic[pid] <= 0.0:
		return
	var band: int = _player_active_band[pid]
	var amount: float = minf(_pending_traffic[pid], 20.0)
	_player_band_load[pid][band] += amount
	_pending_traffic[pid] -= amount
	_player_packets_routed[pid] += 1

func _update_player(pid: int, delta: float) -> void:
	var loads: Array = _player_band_load[pid]

	# Natural drain
	for i in range(3):
		loads[i] = maxf(loads[i] - DRAIN_RATE * delta, 0.0)

	# Check overload — packet loss
	var healthy: bool = true
	for i in range(3):
		var ratio: float = loads[i] / BAND_MAX_CAPACITY[i]
		if ratio >= PACKET_LOSS_THRESHOLD:
			# Drop excess and penalize
			loads[i] = BAND_MAX_CAPACITY[i] * 0.8
			_player_packet_losses[pid] += 1
			_base.add_score(pid, -PENALTY_PER_LOSS)
			healthy = false

	# Score for keeping links balanced and healthy
	if healthy:
		_base.add_score(pid, SCORE_PER_SECOND * delta)

	# Auto-route pending traffic if too much queued (simulates MLO)
	if _pending_traffic[pid] > 100.0:
		# Find least loaded band
		var min_load: float = 999999.0
		var min_band: int = 0
		for i in range(3):
			var ratio: float = loads[i] / BAND_MAX_CAPACITY[i]
			if ratio < min_load:
				min_load = ratio
				min_band = i
		var auto_amount: float = minf(_pending_traffic[pid] * 0.3, 30.0)
		loads[min_band] += auto_amount
		_pending_traffic[pid] -= auto_amount


class _WiFi7Overlay extends Control:
	var game: Node

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Draw per-player band meters
		for p_idx in range(game._base.player_ids.size()):
			var pid: int = game._base.player_ids[p_idx]
			var base_x: float = 30.0 if p_idx == 0 else s.x - 260.0
			var base_y: float = s.y * 0.3

			var name_str: String = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]
			var name_col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			draw_string(font, Vector2(base_x, base_y - 10), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, name_col)

			# Band load bars
			for i in range(3):
				var bar_y: float = base_y + i * 55
				var bar_w: float = 200.0
				var bar_h: float = 20.0
				var loads: Array = game._player_band_load[pid]
				var ratio: float = clampf(loads[i] / BAND_MAX_CAPACITY[i], 0.0, 1.0)

				# Band label
				draw_string(font, Vector2(base_x, bar_y + 15), BAND_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BAND_COLORS[i])

				# Bar background
				var bar_x: float = base_x + 60
				draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.15))

				# Bar fill
				var bar_color: Color = BAND_COLORS[i]
				if ratio >= PACKET_LOSS_THRESHOLD:
					bar_color = Color("#EF4444")
				elif ratio >= OVERLOAD_THRESHOLD:
					bar_color = Color("#F59E0B")
				draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), bar_color)

				# Capacity text
				draw_string(font, Vector2(bar_x + bar_w + 5, bar_y + 15), "%d/%d" % [int(loads[i]), int(BAND_MAX_CAPACITY[i])], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0"))

				# Active band indicator
				if game._player_active_band[pid] == i:
					draw_rect(Rect2(bar_x - 3, bar_y - 3, bar_w + 6, bar_h + 6), Color.WHITE, false, 2.0)
					draw_string(font, Vector2(base_x - 15, bar_y + 15), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

			# Pending traffic
			var pending: float = game._pending_traffic[pid]
			var pending_y: float = base_y + 175
			draw_string(font, Vector2(base_x, pending_y), "QUEUE: %.0f MHz" % pending, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#F59E0B") if pending > 50 else Color("#E2E8F0"))

			# Stats
			draw_string(font, Vector2(base_x, pending_y + 25), "Routed: %d  Lost: %d" % [game._player_packets_routed[pid], game._player_packet_losses[pid]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9CA3AF"))

		# Instructions
		draw_string(font, Vector2(s.x / 2.0 - 200, s.y - 30), "P1: A/D band, SPACE route  |  P2: ←/→ band, SHIFT route", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9CA3AF"))
