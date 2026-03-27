extends Node3D
## CBRS Deployment Mini-Game
## Citizens Broadband Radio Service spectrum sharing.
## Players bid on GAA/PAL spectrum, deploy small cells, avoid incumbent radar.
##
## Teaches: CBRS, GAA vs PAL, SAS, incumbent protection, small cell deployment

const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

const SPECTRUM_BLOCKS := 8  # Available 10MHz blocks in 3.5GHz band
const BID_MIN := 5
const BID_MAX := 50
const DEPLOY_SCORE := 30.0  # Score per successful deployment
const RADAR_PENALTY := 40.0  # Score lost when radar hits
const RADAR_INTERVAL_MIN := 4.0
const RADAR_INTERVAL_MAX := 8.0
const DEPLOY_COOLDOWN := 2.0  # Seconds between deployments
const GAA_COLOR := Color("#22C55E")
const PAL_COLOR := Color("#3B82F6")
const RADAR_COLOR := Color("#EF4444")
const CELL_COLOR := Color("#06B6D4")

var _base: Node3D

# Per-player state
var _player_spectrum: Dictionary = {}  # { pid: Array[bool] } — owned blocks
var _player_spectrum_type: Dictionary = {}  # { pid: Array[int] } — 0=none, 1=GAA, 2=PAL
var _player_cells_deployed: Dictionary = {}  # { pid: int }
var _player_bid_amount: Dictionary = {}  # { pid: int }
var _player_selected_block: Dictionary = {}  # { pid: int }
var _player_deploy_cooldown: Dictionary = {}  # { pid: float }
var _player_mode: Dictionary = {}  # { pid: int } — 0=bid, 1=deploy

# Radar state
var _radar_timer: float = 0.0
var _radar_next: float = 6.0
var _radar_active: bool = false
var _radar_flash: float = 0.0
var _radar_affected_blocks: Array[int] = []

# CanvasLayer for _draw overlay
var _overlay: Control
var _canvas: CanvasLayer

func _ready() -> void:
	_base = Node3D.new()
	_base.set_script(MiniGameBaseScript)
	_base.game_name = "CBRS Deployment"
	_base.concept_taught = "CBRS, GAA vs PAL, SAS, incumbent radar protection"
	_base.duration_seconds = 45.0
	_base.buff_stat = "power"
	_base.buff_value = 15
	_base.music_index = 4
	add_child(_base)

	# Overlay
	_canvas = CanvasLayer.new()
	_canvas.layer = 5
	add_child(_canvas)
	_overlay = _CBRSOverlay.new()
	_overlay.game = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)

func start(player_ids: Array) -> void:
	_base.start(player_ids)
	_start_game()

func _start_game() -> void:
	_radar_timer = 0.0
	_radar_next = randf_range(RADAR_INTERVAL_MIN, RADAR_INTERVAL_MAX)
	_radar_active = false

	for pid in _base.player_ids:
		_player_spectrum[pid] = []
		_player_spectrum_type[pid] = []
		for i in range(SPECTRUM_BLOCKS):
			_player_spectrum[pid].append(false)
			_player_spectrum_type[pid].append(0)
		_player_cells_deployed[pid] = 0
		_player_bid_amount[pid] = 10
		_player_selected_block[pid] = 0
		_player_deploy_cooldown[pid] = 0.0
		_player_mode[pid] = 0  # start in bid mode

	_build_environment()

func _build_environment() -> void:
	# Ground — city grid
	var ground := ProceduralMesh.create_platform(20.0, 20.0, 0.2, Color("#1F2937"))
	ground.position.y = -0.1
	add_child(ground)

	# CBRS tower (center background)
	var tower := ProceduralMesh.create_cylinder(0.1, 5.0, 6, Color("#6B7280"))
	tower.position = Vector3(0, 2.5, -6.0)
	add_child(tower)
	var sas_box := ProceduralMesh.create_box(Vector3(0.8, 0.4, 0.4), Color("#1E40AF"))
	sas_box.position = Vector3(0, 5.2, -6.0)
	add_child(sas_box)
	var sas_label := Label3D.new()
	sas_label.text = "SAS"
	sas_label.font_size = 28
	sas_label.position = Vector3(0, 5.8, -6.0)
	sas_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sas_label.modulate = Color("#3B82F6")
	sas_label.outline_size = 3
	sas_label.outline_modulate = Color.BLACK
	add_child(sas_label)

	# Small cell tower representations
	for i in range(4):
		var cell_tower := ProceduralMesh.create_cylinder(0.04, 1.5, 6, Color("#9CA3AF"))
		cell_tower.position = Vector3(-4.0 + i * 2.8, 0.75, -2.0)
		add_child(cell_tower)
		var cell_top := ProceduralMesh.create_box(Vector3(0.3, 0.15, 0.15), CELL_COLOR)
		cell_top.position = Vector3(-4.0 + i * 2.8, 1.6, -2.0)
		add_child(cell_top)

	# Radar dish (left side, threatening)
	var radar_base := ProceduralMesh.create_cylinder(0.15, 3.0, 6, Color("#78716C"))
	radar_base.position = Vector3(-8.0, 1.5, -4.0)
	add_child(radar_base)
	var radar_dish := ProceduralMesh.create_cone(0.8, 0.5, 8, RADAR_COLOR)
	radar_dish.position = Vector3(-8.0, 3.3, -4.0)
	radar_dish.rotation_degrees.x = -90.0
	add_child(radar_dish)
	var radar_label := Label3D.new()
	radar_label.text = "INCUMBENT RADAR"
	radar_label.font_size = 20
	radar_label.position = Vector3(-8.0, 4.0, -4.0)
	radar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	radar_label.modulate = RADAR_COLOR
	radar_label.outline_size = 2
	radar_label.outline_modulate = Color.BLACK
	add_child(radar_label)

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

	# Radar events
	_radar_timer += delta
	if _radar_flash > 0.0:
		_radar_flash -= delta
	if _radar_timer >= _radar_next:
		_trigger_radar()
		_radar_timer = 0.0
		_radar_next = randf_range(RADAR_INTERVAL_MIN, RADAR_INTERVAL_MAX)

	# Deploy cooldowns
	for pid in _base.player_ids:
		if _player_deploy_cooldown[pid] > 0.0:
			_player_deploy_cooldown[pid] -= delta

	# Passive score for owned spectrum
	for pid in _base.player_ids:
		var owned: int = 0
		for i in range(SPECTRUM_BLOCKS):
			if _player_spectrum[pid][i]:
				owned += 1
		if owned > 0:
			_base.add_score(pid, float(owned) * 2.0 * delta)

	if _overlay:
		_overlay.queue_redraw()

func _process_inputs(_delta: float) -> void:
	# P1: A/D select block, W/S adjust bid, Space bid/deploy, Tab toggle mode
	if 1 in _base.player_ids:
		if Input.is_action_just_pressed("move_left"):
			_player_selected_block[1] = maxi(_player_selected_block[1] - 1, 0)
		if Input.is_action_just_pressed("move_right"):
			_player_selected_block[1] = mini(_player_selected_block[1] + 1, SPECTRUM_BLOCKS - 1)
		if Input.is_action_just_pressed("move_forward"):
			_player_bid_amount[1] = mini(_player_bid_amount[1] + 5, BID_MAX)
		if Input.is_action_just_pressed("move_back"):
			_player_bid_amount[1] = maxi(_player_bid_amount[1] - 5, BID_MIN)
		if Input.is_action_just_pressed("jump"):
			if _player_mode[1] == 0:
				_bid_spectrum(1)
			else:
				_deploy_cell(1)
		if Input.is_action_just_pressed("attack"):
			_player_mode[1] = 1 - _player_mode[1]

	# P2: Arrows select block, Up/Down bid, Shift bid/deploy, Ctrl toggle mode
	if 2 in _base.player_ids:
		if Input.is_key_pressed(KEY_LEFT) and not _p2_left_held:
			_player_selected_block[2] = maxi(_player_selected_block[2] - 1, 0)
			_p2_left_held = true
		elif not Input.is_key_pressed(KEY_LEFT):
			_p2_left_held = false
		if Input.is_key_pressed(KEY_RIGHT) and not _p2_right_held:
			_player_selected_block[2] = mini(_player_selected_block[2] + 1, SPECTRUM_BLOCKS - 1)
			_p2_right_held = true
		elif not Input.is_key_pressed(KEY_RIGHT):
			_p2_right_held = false
		if Input.is_key_pressed(KEY_UP) and not _p2_up_held:
			_player_bid_amount[2] = mini(_player_bid_amount[2] + 5, BID_MAX)
			_p2_up_held = true
		elif not Input.is_key_pressed(KEY_UP):
			_p2_up_held = false
		if Input.is_key_pressed(KEY_DOWN) and not _p2_down_held:
			_player_bid_amount[2] = maxi(_player_bid_amount[2] - 5, BID_MIN)
			_p2_down_held = true
		elif not Input.is_key_pressed(KEY_DOWN):
			_p2_down_held = false
		if Input.is_key_pressed(KEY_SHIFT) and not _p2_shift_held:
			if _player_mode[2] == 0:
				_bid_spectrum(2)
			else:
				_deploy_cell(2)
			_p2_shift_held = true
		elif not Input.is_key_pressed(KEY_SHIFT):
			_p2_shift_held = false
		if (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_L)) and not _p2_ctrl_held:
			_player_mode[2] = 1 - _player_mode[2]
			_p2_ctrl_held = true
		elif not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_L):
			_p2_ctrl_held = false

var _p2_left_held: bool = false
var _p2_right_held: bool = false
var _p2_up_held: bool = false
var _p2_down_held: bool = false
var _p2_shift_held: bool = false
var _p2_ctrl_held: bool = false

func _bid_spectrum(pid: int) -> void:
	var block: int = _player_selected_block[pid]
	if _player_spectrum[pid][block]:
		return  # Already own it

	# Check if other player owns it as PAL (can't override PAL)
	for other_pid in _base.player_ids:
		if other_pid != pid and _player_spectrum[other_pid][block] and _player_spectrum_type[other_pid][block] == 2:
			return  # PAL blocks are protected

	# Determine GAA or PAL based on bid amount
	var is_pal: bool = _player_bid_amount[pid] >= 30
	_player_spectrum[pid][block] = true
	_player_spectrum_type[pid][block] = 2 if is_pal else 1
	_base.add_score(pid, 10.0)

	# If GAA, other player can still use same block (shared)
	# If PAL, revoke other player's GAA on that block
	if is_pal:
		for other_pid in _base.player_ids:
			if other_pid != pid and _player_spectrum[other_pid][block] and _player_spectrum_type[other_pid][block] == 1:
				_player_spectrum[other_pid][block] = false
				_player_spectrum_type[other_pid][block] = 0

func _deploy_cell(pid: int) -> void:
	if _player_deploy_cooldown[pid] > 0.0:
		return

	# Count owned blocks
	var owned: int = 0
	for i in range(SPECTRUM_BLOCKS):
		if _player_spectrum[pid][i]:
			owned += 1

	if owned == 0:
		return  # Need spectrum to deploy

	_player_cells_deployed[pid] += 1
	_player_deploy_cooldown[pid] = DEPLOY_COOLDOWN
	_base.add_score(pid, DEPLOY_SCORE)

func _trigger_radar() -> void:
	_radar_active = true
	_radar_flash = 1.5

	# Radar affects 2-3 random blocks
	_radar_affected_blocks.clear()
	var num_affected: int = randi_range(2, 3)
	for i in range(num_affected):
		_radar_affected_blocks.append(randi_range(0, SPECTRUM_BLOCKS - 1))

	# GAA users on affected blocks lose access, PAL users are protected
	for pid in _base.player_ids:
		for block in _radar_affected_blocks:
			if _player_spectrum[pid][block] and _player_spectrum_type[pid][block] == 1:
				# GAA — must vacate
				_player_spectrum[pid][block] = false
				_player_spectrum_type[pid][block] = 0
				_base.add_score(pid, -RADAR_PENALTY)
			# PAL users keep their spectrum (protected by SAS)


class _CBRSOverlay extends Control:
	var game: Node

	func _draw() -> void:
		if game == null or game._base == null or not game._base.is_running:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Spectrum visualization (top center)
		var spec_x: float = s.x / 2.0 - (SPECTRUM_BLOCKS * 50.0) / 2.0
		var spec_y: float = 20.0
		var block_w: float = 45.0
		var block_h: float = 40.0

		draw_string(font, Vector2(spec_x, spec_y - 2), "3.5 GHz CBRS BAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#E2E8F0"))

		for i in range(SPECTRUM_BLOCKS):
			var bx: float = spec_x + i * 50.0
			var by: float = spec_y + 10

			# Block background
			draw_rect(Rect2(bx, by, block_w, block_h), Color(0.1, 0.1, 0.15))

			# Radar flash on affected blocks
			if game._radar_flash > 0.0 and i in game._radar_affected_blocks:
				draw_rect(Rect2(bx, by, block_w, block_h), Color(RADAR_COLOR, game._radar_flash * 0.5))

			# Per-player ownership (split block in half vertically)
			for p_idx in range(game._base.player_ids.size()):
				var pid: int = game._base.player_ids[p_idx]
				if game._player_spectrum[pid][i]:
					var half_h: float = block_h / 2.0
					var hy: float = by + p_idx * half_h
					var col: Color = GAA_COLOR if game._player_spectrum_type[pid][i] == 1 else PAL_COLOR
					draw_rect(Rect2(bx + 2, hy + 2, block_w - 4, half_h - 4), col)
					var type_str: String = "G" if game._player_spectrum_type[pid][i] == 1 else "P"
					draw_string(font, Vector2(bx + 16, hy + half_h - 4), type_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

			# Block number
			draw_string(font, Vector2(bx + 16, by + block_h + 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9CA3AF"))

		# Per-player info panels
		for p_idx in range(game._base.player_ids.size()):
			var pid: int = game._base.player_ids[p_idx]
			var panel_x: float = 30.0 if p_idx == 0 else s.x - 280.0
			var panel_y: float = s.y * 0.35

			var name_str: String = "P%d %s" % [pid, "RICO" if pid == 1 else "VERO"]
			var name_col: Color = Color("#2563EB") if pid == 1 else Color("#7C3AED")
			draw_string(font, Vector2(panel_x, panel_y), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, name_col)

			# Mode
			var mode_str: String = "BID MODE" if game._player_mode[pid] == 0 else "DEPLOY MODE"
			var mode_col: Color = Color("#F59E0B") if game._player_mode[pid] == 0 else Color("#22C55E")
			draw_string(font, Vector2(panel_x, panel_y + 25), mode_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, mode_col)

			# Selected block
			draw_string(font, Vector2(panel_x, panel_y + 50), "Block: %d" % (game._player_selected_block[pid] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#E2E8F0"))

			# Bid amount (only in bid mode)
			if game._player_mode[pid] == 0:
				var bid: int = game._player_bid_amount[pid]
				var bid_type: String = "PAL" if bid >= 30 else "GAA"
				var bid_col: Color = PAL_COLOR if bid >= 30 else GAA_COLOR
				draw_string(font, Vector2(panel_x, panel_y + 70), "Bid: $%d (%s)" % [bid, bid_type], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, bid_col)

			# Cells deployed
			draw_string(font, Vector2(panel_x, panel_y + 95), "Cells: %d" % game._player_cells_deployed[pid], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CELL_COLOR)

			# Cooldown
			if game._player_deploy_cooldown[pid] > 0.0:
				draw_string(font, Vector2(panel_x, panel_y + 115), "Deploy CD: %.1fs" % game._player_deploy_cooldown[pid], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#EF4444"))

			# Spectrum count
			var owned: int = 0
			var gaa_count: int = 0
			var pal_count: int = 0
			for i in range(SPECTRUM_BLOCKS):
				if game._player_spectrum[pid][i]:
					owned += 1
					if game._player_spectrum_type[pid][i] == 1:
						gaa_count += 1
					else:
						pal_count += 1
			draw_string(font, Vector2(panel_x, panel_y + 135), "Spectrum: %d GAA / %d PAL" % [gaa_count, pal_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9CA3AF"))

		# Radar warning
		if game._radar_flash > 0.0:
			var flash_alpha: float = clampf(game._radar_flash, 0.0, 1.0)
			draw_string(font, Vector2(s.x / 2.0 - 100, s.y * 0.6), "RADAR DETECTED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(RADAR_COLOR, flash_alpha))
			draw_string(font, Vector2(s.x / 2.0 - 130, s.y * 0.6 + 30), "GAA users must vacate!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(RADAR_COLOR, flash_alpha * 0.7))

		# Legend
		var legend_y: float = s.y - 50
		draw_string(font, Vector2(s.x / 2.0 - 250, legend_y), "GAA=Shared(bid<30)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GAA_COLOR)
		draw_string(font, Vector2(s.x / 2.0 - 100, legend_y), "PAL=Protected(bid>=30)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAL_COLOR)

		# Controls
		draw_string(font, Vector2(s.x / 2.0 - 250, legend_y + 18), "P1: A/D block, W/S bid, SPACE act, J mode  |  P2: ←→ block, ↑↓ bid, SHIFT act, CTRL mode", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9CA3AF"))
