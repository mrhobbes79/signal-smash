extends Node3D
## Bandwidth Auction Mini-Game
## Auction bidding on spectrum blocks with varying quality.
## Players bid strategically — overspend on junk or miss a gem.
##
## Teaches: Spectrum licensing, cost-benefit analysis, auction strategy

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const TOTAL_ROUNDS: int = 8
const ROUND_DURATION: float = 5.0
const STARTING_BUDGET: float = 500.0
const BID_ADJUST_SPEED: float = 80.0  # Units per second

var _base: Node3D

# Auction state
var _current_round: int = 0
var _round_timer: float = 0.0
var _round_active: bool = false

# Current block
var _block_quality: int = 0         # 1-5 stars
var _block_freq: String = ""        # Display label
var _block_color: Color = Color.WHITE

# Per-player state
var _player_budget: Dictionary = {}   # { pid: float }
var _player_bid: Dictionary = {}      # { pid: float }
var _player_bid_locked: Dictionary = {} # { pid: bool }
var _player_won_blocks: Dictionary = {} # { pid: Array of { quality, freq, color } }

# History
var _auction_results: Array[Dictionary] = []  # { round, quality, winner, bid }

# Frequency labels
var _freq_labels: Array[String] = [
	"900 MHz", "2.4 GHz", "3.5 GHz", "5 GHz", "6 GHz",
	"11 GHz", "24 GHz", "60 GHz", "5.8 GHz", "3.65 GHz",
]
var _p2_prev_keys := {}

func _p2_just_pressed(key: int) -> bool:
	var currently: bool = Input.is_key_pressed(key)
	var was: bool = _p2_prev_keys.get(key, false)
	_p2_prev_keys[key] = currently
	return currently and not was

var _block_colors: Array[Color] = [
	Color("#EF4444"), Color("#F59E0B"), Color("#22C55E"),
	Color("#3B82F6"), Color("#8B5CF6"), Color("#EC4899"),
	Color("#06B6D4"), Color("#10B981"), Color("#F97316"), Color("#6366F1"),
]

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "Bandwidth Auction"
	_base.concept_taught = "Spectrum licensing, cost-benefit, auction strategy"
	_base.duration_seconds = 45.0
	_base.buff_stat = "power"
	_base.buff_value = 20
	_base.music_index = 4
	add_child(_base)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_start_game()

func _start_game() -> void:
	_current_round = 0
	_auction_results.clear()

	for pid in _base.player_ids:
		_player_budget[pid] = STARTING_BUDGET
		_player_bid[pid] = 0.0
		_player_bid_locked[pid] = false
		_player_won_blocks[pid] = []

	_build_environment()
	_start_round()

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0F172A")
	env.ambient_light_color = Color("#F59E0B")
	env.ambient_light_energy = 0.3
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.7
	add_child(sun)

func _start_round() -> void:
	_current_round += 1
	if _current_round > TOTAL_ROUNDS:
		return

	_round_timer = ROUND_DURATION
	_round_active = true

	# Generate new block
	_block_quality = randi_range(1, 5)
	_block_freq = _freq_labels[(_current_round - 1) % _freq_labels.size()]
	_block_color = _block_colors[(_current_round - 1) % _block_colors.size()]

	# Reset bids
	for pid in _base.player_ids:
		_player_bid[pid] = 0.0
		_player_bid_locked[pid] = false

func _resolve_round() -> void:
	_round_active = false
	var winner: int = 0
	var winning_bid: float = -1.0

	# Auto-lock any unlocked bids
	for pid in _base.player_ids:
		_player_bid_locked[pid] = true

	# Find highest bidder
	for pid in _base.player_ids:
		var bid: float = _player_bid[pid]
		if bid > winning_bid and bid <= _player_budget[pid] and bid > 0:
			winning_bid = bid
			winner = pid
		elif bid == winning_bid and bid > 0:
			# Tie — both lose
			winner = 0

	if winner > 0:
		_player_budget[winner] -= winning_bid
		var points: float = _block_quality * 50.0
		_base.add_score(winner, points)
		_player_won_blocks[winner].append({
			"quality": _block_quality,
			"freq": _block_freq,
			"color": _block_color,
		})
		_auction_results.append({
			"round": _current_round,
			"quality": _block_quality,
			"winner": winner,
			"bid": winning_bid,
		})
	else:
		_auction_results.append({
			"round": _current_round,
			"quality": _block_quality,
			"winner": 0,
			"bid": 0.0,
		})

func _process(delta: float) -> void:
	if not _base.is_running:
		return

	if _current_round > TOTAL_ROUNDS:
		return

	if _round_active:
		_round_timer -= delta
		_process_inputs(delta)

		# Check if all bids locked or time up
		var all_locked: bool = true
		for pid in _base.player_ids:
			if not _player_bid_locked.get(pid, false):
				all_locked = false
				break

		if _round_timer <= 0.0 or all_locked:
			_resolve_round()
			# Short delay then next round
			await get_tree().create_timer(1.0).timeout
			if not is_instance_valid(self):
				return
			if _base.is_running:
				_start_round()

func _process_inputs(delta: float) -> void:
	# P1 (WASD + J to confirm)
	if 1 in _base.player_ids and not _player_bid_locked.get(1, false):
		var p1_v: float = Input.get_axis("move_back", "move_forward")
		_player_bid[1] += p1_v * BID_ADJUST_SPEED * delta
		_player_bid[1] = clampf(_player_bid[1], 0.0, _player_budget.get(1, 0.0))
		if Input.is_action_just_pressed("attack"):
			_player_bid_locked[1] = true
			if AudioManager:
				AudioManager.play_sfx("signal_lock")

	# P2 (Arrows + L to confirm)
	if 2 in _base.player_ids and not _player_bid_locked.get(2, false):
		var p2_v: float = 0.0
		if Input.is_key_pressed(KEY_UP):
			p2_v += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			p2_v -= 1.0
		_player_bid[2] += p2_v * BID_ADJUST_SPEED * delta
		_player_bid[2] = clampf(_player_bid[2], 0.0, _player_budget.get(2, 0.0))
		if _p2_just_pressed(KEY_SHIFT) or _p2_just_pressed(KEY_L):
			_player_bid_locked[2] = true
			if AudioManager:
				AudioManager.play_sfx("signal_lock")

# ═══════════ DRAWING via CanvasLayer ═══════════

var _draw_layer: CanvasLayer
var _draw_control: Control

func _enter_tree() -> void:
	_draw_layer = CanvasLayer.new()
	_draw_layer.layer = 12
	add_child.call_deferred(_draw_layer)
	await get_tree().process_frame
	_draw_control = _AuctionDraw.new()
	_draw_control.game = self
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.add_child(_draw_control)


class _AuctionDraw extends Control:
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
		draw_string(font, Vector2(s.x / 2.0 - 120, 35), "BANDWIDTH AUCTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#F59E0B"))

		# Timer
		var time_left: int = ceili(game._base.time_remaining)
		var timer_col: Color = Color("#22C55E") if time_left > 15 else (Color("#F59E0B") if time_left > 5 else Color("#EF4444"))
		draw_string(font, Vector2(s.x - 80, 35), "%d" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, timer_col)

		# Round indicator
		var round_str: String = "Round %d / %d" % [mini(game._current_round, game.TOTAL_ROUNDS), game.TOTAL_ROUNDS]
		draw_string(font, Vector2(s.x / 2.0 - 50, 60), round_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0", 0.6))

		if game._current_round > game.TOTAL_ROUNDS:
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y / 2.0), "AUCTION COMPLETE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#F59E0B"))
			_draw_scores(s, font)
			return

		# Current spectrum block
		var block_y: float = 80
		var block_w: float = s.x * 0.5
		var block_x: float = (s.x - block_w) / 2.0
		var block_h: float = 100.0

		draw_rect(Rect2(block_x, block_y, block_w, block_h), Color(game._block_color, 0.3))
		draw_rect(Rect2(block_x, block_y, block_w, block_h), Color(game._block_color, 0.8), false, 2.0)

		# Frequency label
		draw_string(font, Vector2(block_x + 15, block_y + 30), game._block_freq, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, game._block_color)

		# Quality stars
		var star_str: String = ""
		for i in range(5):
			star_str += "*" if i < game._block_quality else "."
		draw_string(font, Vector2(block_x + 15, block_y + 55), "Quality: %s (%d/5)" % [star_str, game._block_quality], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#F59E0B"))

		# Point value
		var value: float = game._block_quality * 50.0
		draw_string(font, Vector2(block_x + 15, block_y + 78), "Worth: %.0f pts" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#22C55E"))

		# Round timer bar
		if game._round_active:
			var round_pct: float = game._round_timer / game.ROUND_DURATION
			draw_rect(Rect2(block_x, block_y + block_h + 5, block_w, 6), Color("#374151"))
			var bar_col: Color = Color("#22C55E") if round_pct > 0.3 else Color("#EF4444")
			draw_rect(Rect2(block_x, block_y + block_h + 5, block_w * round_pct, 6), bar_col)

		# Player panels
		for pid in game._base.player_ids:
			var panel_x: float = s.x * 0.05 if pid == 1 else s.x * 0.55
			var panel_w: float = s.x * 0.4
			var panel_y: float = s.y * 0.4
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var name_str: String = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]

			# Panel bg
			draw_rect(Rect2(panel_x, panel_y, panel_w, s.y * 0.5), Color("#1E293B", 0.8))

			# Name
			draw_string(font, Vector2(panel_x + 10, panel_y + 25), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

			# Budget
			var budget: float = game._player_budget.get(pid, 0.0)
			draw_string(font, Vector2(panel_x + 10, panel_y + 50), "Budget: $%.0f" % budget, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0"))

			# Current bid
			var bid: float = game._player_bid.get(pid, 0.0)
			var locked: bool = game._player_bid_locked.get(pid, false)
			draw_string(font, Vector2(panel_x + 10, panel_y + 80), "BID:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0", 0.7))

			# Bid bar
			var bid_bar_x: float = panel_x + 70
			var bid_bar_w: float = panel_w - 80
			draw_rect(Rect2(bid_bar_x, panel_y + 66, bid_bar_w, 20), Color("#374151"))
			var bid_pct: float = bid / maxf(budget, 1.0)
			var bid_col: Color = Color("#06B6D4") if not locked else Color("#22C55E")
			draw_rect(Rect2(bid_bar_x, panel_y + 66, bid_bar_w * clampf(bid_pct, 0.0, 1.0), 20), bid_col)
			draw_string(font, Vector2(bid_bar_x + 5, panel_y + 82), "$%.0f" % bid, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

			if locked:
				draw_string(font, Vector2(panel_x + 10, panel_y + 105), "BID LOCKED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#22C55E"))
			else:
				var pulse: float = (sin(Time.get_ticks_msec() * 0.005) + 1.0) / 2.0
				draw_string(font, Vector2(panel_x + 10, panel_y + 105), "Use vertical + confirm to bid", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3 + pulse * 0.3))

			# Won blocks
			draw_string(font, Vector2(panel_x + 10, panel_y + 130), "Won Blocks:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0", 0.6))
			var won: Array = game._player_won_blocks.get(pid, [])
			for i in range(won.size()):
				var wb: Dictionary = won[i]
				var bx: float = panel_x + 10 + i * 55
				var by: float = panel_y + 140
				draw_rect(Rect2(bx, by, 50, 30), Color(wb["color"], 0.5))
				var stars: String = ""
				for _q in range(wb["quality"]):
					stars += "*"
				draw_string(font, Vector2(bx + 5, by + 20), stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F59E0B"))

			# Score
			var score: float = game._base.scores.get(pid, 0.0)
			draw_string(font, Vector2(panel_x + 10, panel_y + s.y * 0.5 - 20), "SCORE: %.0f" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

		# Last round result
		if game._auction_results.size() > 0 and not game._round_active:
			var last: Dictionary = game._auction_results[game._auction_results.size() - 1]
			var result_str: String
			if last["winner"] > 0:
				result_str = "P%d won for $%.0f!" % [last["winner"], last["bid"]]
			else:
				result_str = "No winner — bid tie or no bids!"
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y * 0.35), result_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#F59E0B"))

		# Controls
		draw_string(font, Vector2(40, s.y - 15), "P1: W/S bid | J lock bid", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))
		draw_string(font, Vector2(s.x - 240, s.y - 15), "P2: Up/Down bid | L lock bid", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E2E8F0", 0.3))

	func _draw_scores(s: Vector2, font: Font) -> void:
		for pid in game._base.player_ids:
			var score: float = game._base.scores.get(pid, 0.0)
			var name_str: String = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]
			var col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			var sx: float = s.x * 0.2 if pid == 1 else s.x * 0.6
			draw_string(font, Vector2(sx, s.y * 0.6), "%s: %.0f pts" % [name_str, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
