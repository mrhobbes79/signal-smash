extends Node3D
## Firewall Frenzy Mini-Game
## Packets (green=good, red=bad) stream toward a firewall line.
## Players toggle firewall rules to block/allow packets correctly.
##
## Teaches: Firewall rules, packet filtering, threat assessment

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const LANES_PER_PLAYER: int = 4
const TOTAL_LANES: int = 8
const SPAWN_INTERVAL: float = 0.5
const PACKET_MIN_SPEED: float = 120.0
const PACKET_MAX_SPEED: float = 250.0
const FIREWALL_X_PCT: float = 0.75  # Firewall at 75% across
const CORRECT_BLOCK_PTS: float = 20.0
const CORRECT_ALLOW_PTS: float = 10.0
const WRONG_BLOCK_PTS: float = -15.0
const WRONG_ALLOW_PTS: float = -25.0

var _base: Node3D

# Firewall state per lane: true = blocking, false = allowing
var _firewall_state: Array[bool] = []

# Packets: Array of dictionaries { lane: int, x: float, speed: float, is_bad: bool, active: bool }
var _packets: Array[Dictionary] = []
var _spawn_timers: Array[float] = []

# Per player
var _player_selected_lane: Dictionary = {}  # { pid: int } — relative lane (0-3)

var _p2_prev_keys := {}

func _p2_just_pressed(key: int) -> bool:
	var currently: bool = Input.is_key_pressed(key)
	var was: bool = _p2_prev_keys.get(key, false)
	_p2_prev_keys[key] = currently
	return currently and not was

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Firewall Frenzy"
	_base.concept_taught = "Firewall rules, packet filtering"
	_base.duration_seconds = 45.0
	_base.buff_stat = "stability"
	_base.buff_value = 15
	_base.music_index = 5
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)

	# Initialize firewall (all lanes blocking by default)
	_firewall_state.clear()
	for i in range(TOTAL_LANES):
		_firewall_state.append(true)

	# Initialize spawn timers
	_spawn_timers.clear()
	for i in range(TOTAL_LANES):
		_spawn_timers.append(randf_range(0.0, SPAWN_INTERVAL))

	_packets.clear()

	for pid in _base.player_ids:
		_player_selected_lane[pid] = 0

func _process(delta: float) -> void:
	if not _base.is_running:
		return
	_process_inputs(delta)
	_update_packets(delta)
	_spawn_packets(delta)

func _process_inputs(_delta: float) -> void:
	# P1 — manages lanes 0-3 (top half)
	if 1 in _base.player_ids:
		if Input.is_action_just_pressed("move_forward"):
			_player_selected_lane[1] = maxi(_player_selected_lane[1] - 1, 0)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_action_just_pressed("move_back"):
			_player_selected_lane[1] = mini(_player_selected_lane[1] + 1, LANES_PER_PLAYER - 1)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump"):
			var lane: int = _player_selected_lane[1]
			_firewall_state[lane] = not _firewall_state[lane]
			if AudioManager:
				AudioManager.play_sfx("menu_move")

	# P2 — manages lanes 4-7 (bottom half)
	if 2 in _base.player_ids:
		if _p2_just_pressed(KEY_UP):
			_player_selected_lane[2] = maxi(_player_selected_lane[2] - 1, 0)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if _p2_just_pressed(KEY_DOWN):
			_player_selected_lane[2] = mini(_player_selected_lane[2] + 1, LANES_PER_PLAYER - 1)
			if AudioManager:
				AudioManager.play_sfx("align_beep")
		if _p2_just_pressed(KEY_L):
			var lane: int = LANES_PER_PLAYER + _player_selected_lane[2]
			_firewall_state[lane] = not _firewall_state[lane]
			if AudioManager:
				AudioManager.play_sfx("menu_move")

func _spawn_packets(delta: float) -> void:
	# Cap total packets to prevent unbounded growth
	if _packets.size() >= 200:
		return
	for i in range(TOTAL_LANES):
		_spawn_timers[i] -= delta
		if _spawn_timers[i] <= 0.0:
			_spawn_timers[i] = SPAWN_INTERVAL + randf_range(-0.1, 0.2)
			var packet: Dictionary = {
				"lane": i,
				"x": 0.0,  # Start from left edge
				"speed": randf_range(PACKET_MIN_SPEED, PACKET_MAX_SPEED),
				"is_bad": randf() < 0.45,  # 45% chance of bad packet
				"active": true,
				"scored": false
			}
			_packets.append(packet)

func _update_packets(delta: float) -> void:
	var firewall_x: float = FIREWALL_X_PCT
	var packets_to_remove: Array[int] = []

	for i in range(_packets.size()):
		var pkt: Dictionary = _packets[i]
		if not pkt["active"]:
			continue

		pkt["x"] += pkt["speed"] * delta / 1000.0  # Normalize to 0-1 range

		# Check firewall collision
		if pkt["x"] >= firewall_x and not pkt["scored"]:
			pkt["scored"] = true
			var lane: int = pkt["lane"]
			var is_blocking: bool = _firewall_state[lane]
			var is_bad: bool = pkt["is_bad"]
			var owner_pid: int = 1 if lane < LANES_PER_PLAYER else 2

			if owner_pid in _base.player_ids:
				if is_blocking:
					if is_bad:
						_base.add_score(owner_pid, CORRECT_BLOCK_PTS)
						if AudioManager:
							AudioManager.play_sfx("score")
					else:
						_base.add_score(owner_pid, WRONG_BLOCK_PTS)
						if AudioManager:
							AudioManager.play_sfx("hit_light")
					pkt["active"] = false
				else:
					if is_bad:
						_base.add_score(owner_pid, WRONG_ALLOW_PTS)
						if AudioManager:
							AudioManager.play_sfx("ko")
					else:
						_base.add_score(owner_pid, CORRECT_ALLOW_PTS)

		# Remove if past right edge
		if pkt["x"] > 1.2:
			pkt["active"] = false

		_packets[i] = pkt

	# Clean up inactive packets periodically
	if Engine.get_physics_frames() % 60 == 0:
		var active_packets: Array[Dictionary] = []
		for pkt in _packets:
			if pkt["active"]:
				active_packets.append(pkt)
		_packets = active_packets

# ═══════════ DRAWING ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _FirewallDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _FirewallDraw extends Control:
	var game: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Background
		draw_rect(Rect2(0, 0, s.x, s.y), Color("#0F172A"))

		# Title
		draw_string(font, Vector2(s.x / 2.0 - 100, 30), "FIREWALL FRENZY", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#06B6D4"))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var tc: Color = Color("#22C55E") if time_left > 15 else Color("#EF4444")
		draw_string(font, Vector2(s.x - 80, 30), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tc)

		# Lane dimensions
		var field_y: float = 55.0
		var field_h: float = s.y - 130.0
		var lane_h: float = field_h / game.TOTAL_LANES
		var field_x: float = 40.0
		var field_w: float = s.x - 80.0
		var firewall_screen_x: float = field_x + field_w * game.FIREWALL_X_PCT

		# Player zone labels
		draw_string(font, Vector2(field_x, field_y - 5), "P1 ZONE (RICO)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#2563EB"))
		draw_string(font, Vector2(field_x, field_y + lane_h * game.LANES_PER_PLAYER - 5), "P2 ZONE (VERO)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#7C3AED"))

		# Draw lanes
		for i in range(game.TOTAL_LANES):
			var ly: float = field_y + i * lane_h
			var is_p1: bool = i < game.LANES_PER_PLAYER
			var zone_color: Color = Color("#1E293B") if is_p1 else Color("#1A1A2E")

			# Lane background
			draw_rect(Rect2(field_x, ly, field_w, lane_h - 2), zone_color)

			# Lane number
			draw_string(font, Vector2(field_x + 5, ly + lane_h / 2.0 + 5), "L%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#6B7280"))

			# Firewall indicator on this lane
			var fw_color: Color
			if game._firewall_state[i]:
				fw_color = Color("#EF4444", 0.6)  # Red = blocking
			else:
				fw_color = Color("#22C55E", 0.4)  # Green = allowing
			draw_rect(Rect2(firewall_screen_x - 3, ly, 6, lane_h - 2), fw_color)

			# Selection indicator
			var owner_pid: int = 1 if is_p1 else 2
			var relative_lane: int = i if is_p1 else i - game.LANES_PER_PLAYER
			if owner_pid in game._player_selected_lane:
				if game._player_selected_lane[owner_pid] == relative_lane:
					var sel_color: Color = Color("#2563EB") if is_p1 else Color("#7C3AED")
					draw_rect(Rect2(firewall_screen_x - 8, ly, 16, lane_h - 2), sel_color, false, 2.0)
					# Toggle label
					var state_text: String = "BLOCK" if game._firewall_state[i] else "ALLOW"
					draw_string(font, Vector2(firewall_screen_x + 12, ly + lane_h / 2.0 + 5), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sel_color)

		# Firewall vertical line
		draw_line(Vector2(firewall_screen_x, field_y), Vector2(firewall_screen_x, field_y + field_h), Color("#F59E0B"), 2.0)
		draw_string(font, Vector2(firewall_screen_x - 30, field_y + field_h + 15), "FIREWALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F59E0B"))

		# Divider between P1 and P2 zones
		var div_y: float = field_y + game.LANES_PER_PLAYER * lane_h
		draw_line(Vector2(field_x, div_y), Vector2(field_x + field_w, div_y), Color("#4B5563"), 2.0)

		# Draw packets
		for pkt in game._packets:
			if not pkt["active"]:
				continue
			var lane: int = pkt["lane"]
			var ly: float = field_y + lane * lane_h
			var px: float = field_x + pkt["x"] * field_w
			var pkt_size: float = lane_h * 0.5
			var pkt_color: Color = Color("#EF4444") if pkt["is_bad"] else Color("#22C55E")

			# Packet rectangle
			draw_rect(Rect2(px - pkt_size / 2.0, ly + (lane_h - pkt_size) / 2.0, pkt_size, pkt_size), pkt_color)

			# Label inside packet
			var label: String = "BAD" if pkt["is_bad"] else "OK"
			draw_string(font, Vector2(px - 8, ly + lane_h / 2.0 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

		# Scores
		for pid in game._base.player_ids:
			var score: float = game._base.scores.get(pid, 0.0)
			var name_str: String = "RICO" if pid == 1 else "VERO"
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var sx: float = 40 if pid == 1 else s.x - 200
			draw_string(font, Vector2(sx, s.y - 20), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Legend
		draw_rect(Rect2(s.x / 2.0 - 80, s.y - 35, 12, 12), Color("#22C55E"))
		draw_string(font, Vector2(s.x / 2.0 - 65, s.y - 25), "GOOD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#22C55E"))
		draw_rect(Rect2(s.x / 2.0 + 10, s.y - 35, 12, 12), Color("#EF4444"))
		draw_string(font, Vector2(s.x / 2.0 + 25, s.y - 25), "BAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#EF4444"))

		# Controls
		draw_string(font, Vector2(40, s.y - 5), "P1: W/S select lane | J toggle", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 260, s.y - 5), "P2: Up/Down select lane | L toggle", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E2E8F0", 0.3))
