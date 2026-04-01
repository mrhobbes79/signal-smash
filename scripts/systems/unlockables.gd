class_name Unlockables
extends Node
## Unlockables system — victory dances, title cards, uniforms, emotes.
## Checks Progression data to determine what the player has earned.
## Autoload-ready (register as "Unlockables" in project.godot).

## ═══════════ DATA ═══════════

const UNLOCKABLES := [
	{"id": "dance_signal_lock", "name": "Signal Lock Dance", "type": "victory_dance", "condition": "win_5", "description": "Celebrate with a signal lock pose"},
	{"id": "dance_five_nines", "name": "Five Nines Shuffle", "type": "victory_dance", "condition": "win_20", "description": "99.999% uptime dance"},
	{"id": "dance_packet_drop", "name": "Packet Drop", "type": "victory_dance", "condition": "win_50", "description": "Drop it like a lost packet"},
	{"id": "title_rookie_installer", "name": "Rookie Installer", "type": "title_card", "condition": "phase_2", "description": "Reached Tecnico rank"},
	{"id": "title_signal_master", "name": "Signal Master", "type": "title_card", "condition": "phase_4", "description": "Reached Ingeniero rank"},
	{"id": "title_leyenda", "name": "Leyenda Viviente", "type": "title_card", "condition": "phase_5", "description": "Reached Leyenda rank"},
	{"id": "uniform_monterrey", "name": "Monterrey Crew", "type": "uniform", "condition": "arena_monterrey", "description": "Regional uniform -- Monterrey"},
	{"id": "uniform_cdmx", "name": "CDMX Tech", "type": "uniform", "condition": "arena_cdmx", "description": "Regional uniform -- Mexico City"},
	{"id": "uniform_rio", "name": "Rio Wireless", "type": "uniform", "condition": "arena_rio", "description": "Regional uniform -- Rio de Janeiro"},
	{"id": "uniform_miami", "name": "Miami Neon", "type": "uniform", "condition": "arena_miami", "description": "Regional uniform -- Miami"},
	{"id": "emote_gg", "name": "GG Signal", "type": "emote", "condition": "win_10", "description": "Good game signal emote"},
	{"id": "emote_ping", "name": "Low Ping", "type": "emote", "condition": "minigame_10", "description": "Show off low latency"},
]

## Currently unlocked IDs (persisted via save)
var unlocked: Array[String] = []

## Arena visit tracking — keys are arena city names (lowercase)
var arenas_visited: Dictionary = {}

const SAVE_PATH: String = "user://signal_smash_unlockables.json"

## ═══════════ LIFECYCLE ═══════════

func _ready() -> void:
	load_unlockables()
	check_unlocks()
	print("[UNLOCKABLES] %d / %d unlocked" % [unlocked.size(), UNLOCKABLES.size()])

## ═══════════ QUERIES ═══════════

func is_unlocked(id: String) -> bool:
	return id in unlocked

func get_unlocked_by_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in UNLOCKABLES:
		if item["type"] == type and item["id"] in unlocked:
			result.append(item)
	return result

func get_all_by_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in UNLOCKABLES:
		if item["type"] == type:
			result.append(item)
	return result

func get_unlock_progress() -> Dictionary:
	return {
		"unlocked": unlocked.size(),
		"total": UNLOCKABLES.size(),
		"percent": (float(unlocked.size()) / float(UNLOCKABLES.size())) * 100.0,
	}

## ═══════════ ARENA TRACKING ═══════════

func record_arena_visit(arena_city: String) -> void:
	var key := arena_city.to_lower().replace(" ", "_")
	arenas_visited[key] = true
	save_unlockables()

## ═══════════ UNLOCK CHECK ═══════════

func check_unlocks() -> Array[String]:
	## Returns newly unlocked IDs this check cycle.
	var newly_unlocked: Array[String] = []

	for item in UNLOCKABLES:
		var id: String = item["id"]
		if id in unlocked:
			continue

		var condition: String = item["condition"]
		if _evaluate_condition(condition):
			unlocked.append(id)
			newly_unlocked.append(id)
			print("[UNLOCKABLES] NEW UNLOCK: %s — %s" % [item["name"], item["description"]])

	if newly_unlocked.size() > 0:
		save_unlockables()

	return newly_unlocked

func _evaluate_condition(condition: String) -> bool:
	# Get progression reference (autoload)
	var prog: Node = get_node_or_null("/root/Progression")
	if prog == null:
		return false

	# win_N — total wins >= N
	if condition.begins_with("win_"):
		var threshold: int = condition.get_slice("_", 1).to_int()
		return prog.total_wins >= threshold

	# phase_N — current phase >= N
	if condition.begins_with("phase_"):
		var threshold: int = condition.get_slice("_", 1).to_int()
		return prog.current_phase >= threshold

	# arena_X — has visited arena X
	if condition.begins_with("arena_"):
		var arena_key: String = condition.substr(6)  # everything after "arena_"
		return arena_key in arenas_visited

	# minigame_N — total minigames >= N
	if condition.begins_with("minigame_"):
		var threshold: int = condition.get_slice("_", 1).to_int()
		return prog.total_minigames >= threshold

	return false

## ═══════════ SAVE / LOAD ═══════════

func save_unlockables() -> void:
	var data := {
		"version": 1,
		"unlocked": unlocked,
		"arenas_visited": arenas_visited,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_unlockables() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[UNLOCKABLES] Failed to parse save file")
		return
	if not json.data is Dictionary:
		push_warning("[UNLOCKABLES] Save file data is not a Dictionary, resetting to defaults")
		return
	var data: Dictionary = json.data
	# Restore unlocked list
	var saved_unlocked: Array = data.get("unlocked", [])
	unlocked.clear()
	for id in saved_unlocked:
		unlocked.append(str(id))
	# Restore arena visits
	arenas_visited = data.get("arenas_visited", {})
