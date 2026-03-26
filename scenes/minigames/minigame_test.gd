extends Node3D
## Mini-Game Test Scene
## Tests the Antenna Align-Off mini-game standalone.
## Press ENTER to start, R to restart.

const AntennaAlignScene = preload("res://scenes/minigames/antenna_align.tscn")
const SpectrumSniperScene = preload("res://scenes/minigames/spectrum_sniper.tscn")
const CableRunScene = preload("res://scenes/minigames/cable_run.tscn")
const TowerClimbScene = preload("res://scenes/minigames/tower_climb.tscn")
const PingPongScene = preload("res://scenes/minigames/ping_pong.tscn")
const FirewallFrenzyScene = preload("res://scenes/minigames/firewall_frenzy.tscn")
const IPPuzzleScene = preload("res://scenes/minigames/ip_puzzle.tscn")
const WeatherDodgeScene = preload("res://scenes/minigames/weather_dodge.tscn")
const BandwidthAuctionScene = preload("res://scenes/minigames/bandwidth_auction.tscn")
const TroubleshooterScene = preload("res://scenes/minigames/troubleshooter.tscn")
const MiniGameBaseScript = preload("res://scripts/minigames/minigame_base.gd")

var _scenes: Array = []
var _current_scene_idx: int = 0
var _minigame: Node3D
var _camera: Camera3D
var _status_label: Label
var _waiting_to_start: bool = true

func _ready() -> void:
	_scenes = [
		AntennaAlignScene, SpectrumSniperScene, CableRunScene,
		TowerClimbScene, PingPongScene, FirewallFrenzyScene, IPPuzzleScene,
		WeatherDodgeScene, BandwidthAuctionScene, TroubleshooterScene,
	]
	_build_camera()
	_build_hud()
	_show_start_prompt()

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 4, 8)
	_camera.rotation_degrees.x = -20
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 20)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color("#06B6D4"))
	_status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_status_label)

func _show_start_prompt() -> void:
	var names: Array[String] = [
		"ANTENNA ALIGN-OFF", "SPECTRUM SNIPER", "CABLE RUN",
		"TOWER CLIMB RACE", "PING PONG", "FIREWALL FRENZY", "IP PUZZLE",
		"WEATHER DODGE", "BANDWIDTH AUCTION", "THE TROUBLESHOOTER",
	]
	var descs: Array[String] = [
		"Align your dish antenna to the target signal.",
		"Find the cleanest channel in the spectrum.",
		"Route a cable through the maze. Pick the right connector!",
		"Race to climb the tower! Tap rhythmically, secure your harness.",
		"Packet pong! Keep the data flowing past your opponent.",
		"Block bad packets, allow good ones through your firewall.",
		"Assemble the correct IP address and subnet mask.",
		"Keep your signal link alive through rain, snow, and solar flares.",
		"Bid on spectrum blocks. Build the best coverage plan.",
		"Diagnose customer network problems from clues.",
	]
	var idx: int = clampi(_current_scene_idx, 0, names.size() - 1)
	_status_label.text = """SIGNAL SMASH — Mini-Game Test

%s
%s

TAB = Next mini-game | ENTER = Start | R = Restart | ESC = Menu

Current: [%d/%d] %s""" % [names[idx], descs[idx], idx + 1, _scenes.size(), names[idx]]

func _start_minigame() -> void:
	_waiting_to_start = false

	# Remove old mini-game if exists
	if _minigame:
		_minigame.queue_free()
		await get_tree().process_frame

	# Create mini-game
	_minigame = _scenes[_current_scene_idx].instantiate()
	add_child(_minigame)

	# Get the MiniGameBase child and connect completion
	await get_tree().process_frame
	var base = _minigame.get_child(0) if _minigame.get_child_count() > 0 else null
	if base and base.has_signal("game_completed"):
		base.game_completed.connect(_on_minigame_completed)

	# Start
	var pids: Array[int] = [1, 2]
	_minigame.start(pids)
	_status_label.text = "ALIGN YOUR ANTENNA! Closest to target wins."

func _on_minigame_completed(results: Dictionary) -> void:
	var result_text: String = "RESULTS:\n\n"
	for pid in results:
		var r: Dictionary = results[pid]
		var name_str: String = "RICO" if pid == 1 else "VERO"
		var winner_str: String = " ★ WINNER!" if r.get("is_winner", false) else ""
		result_text += "P%d %s: %.0f pts → +%d %s%s\n" % [
			pid, name_str, r["score"], r["buff_value"], r["buff_stat"], winner_str]

	result_text += "\nPress R to play again, ENTER for new round"
	_status_label.text = result_text
	_waiting_to_start = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and _waiting_to_start:
			_start_minigame()
		elif event.keycode == KEY_R:
			_waiting_to_start = true
			if _minigame:
				_minigame.queue_free()
				_minigame = null
			_show_start_prompt()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
		# Switch mini-game with Tab (cycle forward) or Shift+Tab (cycle back)
		elif event.keycode == KEY_TAB and _waiting_to_start:
			if Input.is_key_pressed(KEY_SHIFT):
				_current_scene_idx = (_current_scene_idx - 1 + _scenes.size()) % _scenes.size()
			else:
				_current_scene_idx = (_current_scene_idx + 1) % _scenes.size()
			if AudioManager:
				AudioManager.play_sfx("menu_move")
			_show_start_prompt()
		elif event.keycode == KEY_F1 and _waiting_to_start:
			_current_scene_idx = 2
			_show_start_prompt()
