class_name ProgressionManager
extends Node
## Manages player career progression, currencies, unlocks, and save/load.
## 5 Phases: Rookie → Técnico → Senior → Ingeniero → Leyenda

## ═══════════ CONSTANTS ═══════════

enum Phase { ROOKIE = 1, TECNICO = 2, SENIOR = 3, INGENIERO = 4, LEYENDA = 5 }

const PHASE_NAMES := {
	Phase.ROOKIE: "Rookie",
	Phase.TECNICO: "Técnico",
	Phase.SENIOR: "Senior",
	Phase.INGENIERO: "Ingeniero",
	Phase.LEYENDA: "Leyenda",
}

const PHASE_COLORS := {
	Phase.ROOKIE: Color("#9CA3AF"),
	Phase.TECNICO: Color("#3B82F6"),
	Phase.SENIOR: Color("#F59E0B"),
	Phase.INGENIERO: Color("#8B5CF6"),
	Phase.LEYENDA: Color("#EF4444"),
}

## SP required to advance to next phase
const PHASE_SP_REQUIREMENTS := {
	Phase.ROOKIE: 0,
	Phase.TECNICO: 500,
	Phase.SENIOR: 2000,
	Phase.INGENIERO: 5000,
	Phase.LEYENDA: 12000,
}

## KT (Knowledge Tokens) required for each phase
const PHASE_KT_REQUIREMENTS := {
	Phase.ROOKIE: 0,
	Phase.TECNICO: 0,
	Phase.SENIOR: 50,
	Phase.INGENIERO: 200,
	Phase.LEYENDA: 500,
}

## Wins required for each phase
const PHASE_WIN_REQUIREMENTS := {
	Phase.ROOKIE: 0,
	Phase.TECNICO: 3,
	Phase.SENIOR: 15,
	Phase.INGENIERO: 40,
	Phase.LEYENDA: 80,
}

## Characters unlocked per phase (all unlocked for demo — gate later for full release)
const PHASE_CHARACTER_UNLOCKS := {
	Phase.ROOKIE: ["RICO", "ING. VERO", "DON AURELIO", "MORXEL"],
	Phase.TECNICO: ["RICO", "ING. VERO", "DON AURELIO", "MORXEL"],
	Phase.SENIOR: ["RICO", "ING. VERO", "DON AURELIO", "MORXEL"],
	Phase.INGENIERO: ["RICO", "ING. VERO", "DON AURELIO", "MORXEL"],
	Phase.LEYENDA: ["RICO", "ING. VERO", "DON AURELIO", "MORXEL"],
}

## Vendors available per phase
const PHASE_VENDOR_UNLOCKS := {
	Phase.ROOKIE: ["Cambium", "Ubiquiti"],
	Phase.TECNICO: ["Cambium", "Ubiquiti"],
	Phase.SENIOR: ["Cambium", "Ubiquiti", "Mikrotik"],
	Phase.INGENIERO: ["Cambium", "Ubiquiti", "Mikrotik", "Mimosa", "Telrad"],
	Phase.LEYENDA: ["Cambium", "Ubiquiti", "Mikrotik", "Mimosa", "Telrad"],
}

## SP rewards
const SP_FIGHT_WIN: int = 100
const SP_FIGHT_LOSS: int = 25
const SP_PERFECT_WIN: int = 200  ## No damage taken
const SP_MINIGAME_WIN: int = 75
const SP_MINIGAME_LOSE: int = 30

## KT rewards (mini-games only)
const KT_MINIGAME_WIN: int = 15
const KT_MINIGAME_LOSE: int = 5
const KT_MINIGAME_PERFECT: int = 30  ## Top score threshold

## ═══════════ STATE ═══════════

var current_phase: int = Phase.ROOKIE
var signal_points: int = 0
var knowledge_tokens: int = 0
var total_wins: int = 0
var total_losses: int = 0
var total_fights: int = 0
var total_minigames: int = 0
var best_minigame_scores: Dictionary = {}  ## { "minigame_name": float }
var campaign_chapters_complete: Array[int] = []

## Fight result from last match (read by victory screen)
var last_fight_result: Dictionary = {}

const SAVE_PATH: String = "user://signal_smash_save.json"

## ═══════════ LIFECYCLE ═══════════

func _ready() -> void:
	load_game()
	print("[PROGRESSION] Phase: %s | SP: %d | KT: %d | Wins: %d" % [
		PHASE_NAMES[current_phase], signal_points, knowledge_tokens, total_wins])

## ═══════════ QUERIES ═══════════

func get_phase_name() -> String:
	return PHASE_NAMES.get(current_phase, "Unknown")

func get_phase_color() -> Color:
	return PHASE_COLORS.get(current_phase, Color.WHITE)

func is_character_unlocked(char_name: String) -> bool:
	var unlocked: Array = PHASE_CHARACTER_UNLOCKS.get(current_phase, [])
	return char_name in unlocked

func is_vendor_unlocked(vendor_name: String) -> bool:
	var unlocked: Array = PHASE_VENDOR_UNLOCKS.get(current_phase, [])
	return vendor_name in unlocked

func get_unlocked_characters() -> Array:
	return PHASE_CHARACTER_UNLOCKS.get(current_phase, ["RICO", "ING. VERO"])

func get_next_phase_requirements() -> Dictionary:
	var next: int = mini(current_phase + 1, Phase.LEYENDA)
	if current_phase >= Phase.LEYENDA:
		return {"sp": 0, "kt": 0, "wins": 0, "maxed": true}
	return {
		"sp": PHASE_SP_REQUIREMENTS[next],
		"kt": PHASE_KT_REQUIREMENTS[next],
		"wins": PHASE_WIN_REQUIREMENTS[next],
		"maxed": false,
	}

func get_phase_progress() -> float:
	## Returns 0.0-1.0 progress toward next phase
	if current_phase >= Phase.LEYENDA:
		return 1.0
	var reqs := get_next_phase_requirements()
	var sp_prog: float = clampf(float(signal_points) / maxf(reqs["sp"], 1), 0.0, 1.0)
	var kt_prog: float = 1.0 if reqs["kt"] == 0 else clampf(float(knowledge_tokens) / maxf(reqs["kt"], 1), 0.0, 1.0)
	var win_prog: float = clampf(float(total_wins) / maxf(reqs["wins"], 1), 0.0, 1.0)
	return (sp_prog + kt_prog + win_prog) / 3.0

func can_advance_phase() -> bool:
	if current_phase >= Phase.LEYENDA:
		return false
	var reqs := get_next_phase_requirements()
	return signal_points >= reqs["sp"] and knowledge_tokens >= reqs["kt"] and total_wins >= reqs["wins"]

## ═══════════ ACTIONS ═══════════

func record_fight_win(damage_taken: float) -> Dictionary:
	total_wins += 1
	total_fights += 1
	var perfect: bool = damage_taken <= 0.01
	var sp_earned: int = SP_PERFECT_WIN if perfect else SP_FIGHT_WIN
	signal_points += sp_earned

	last_fight_result = {
		"won": true,
		"perfect": perfect,
		"sp_earned": sp_earned,
		"kt_earned": 0,
		"damage_taken": damage_taken,
	}

	_check_phase_advance()
	save_game()
	return last_fight_result

func record_fight_loss(damage_dealt: float) -> Dictionary:
	total_losses += 1
	total_fights += 1
	signal_points += SP_FIGHT_LOSS

	last_fight_result = {
		"won": false,
		"perfect": false,
		"sp_earned": SP_FIGHT_LOSS,
		"kt_earned": 0,
		"damage_dealt": damage_dealt,
	}

	save_game()
	return last_fight_result

func record_minigame_result(minigame_name: String, score: float, is_winner: bool) -> Dictionary:
	total_minigames += 1
	var perfect: bool = score >= 95.0
	var sp: int = SP_MINIGAME_WIN if is_winner else SP_MINIGAME_LOSE
	var kt: int
	if perfect:
		kt = KT_MINIGAME_PERFECT
	elif is_winner:
		kt = KT_MINIGAME_WIN
	else:
		kt = KT_MINIGAME_LOSE

	signal_points += sp
	knowledge_tokens += kt

	# Track best scores
	if minigame_name not in best_minigame_scores or score > best_minigame_scores[minigame_name]:
		best_minigame_scores[minigame_name] = score

	var result := {
		"won": is_winner,
		"perfect": perfect,
		"sp_earned": sp,
		"kt_earned": kt,
		"score": score,
	}

	_check_phase_advance()
	save_game()
	return result

func _check_phase_advance() -> void:
	if can_advance_phase():
		current_phase = mini(current_phase + 1, Phase.LEYENDA)
		print("[PROGRESSION] ★ PHASE UP! Now: %s" % get_phase_name())
		if AudioManager:
			AudioManager.play_sfx("victory")

## ═══════════ SAVE / LOAD ═══════════

func save_game() -> void:
	var data := {
		"version": 1,
		"phase": current_phase,
		"sp": signal_points,
		"kt": knowledge_tokens,
		"wins": total_wins,
		"losses": total_losses,
		"fights": total_fights,
		"minigames": total_minigames,
		"best_scores": best_minigame_scores,
		"campaign_complete": campaign_chapters_complete,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[PROGRESSION] Failed to parse save file")
		return
	var data: Dictionary = json.data
	current_phase = data.get("phase", Phase.ROOKIE)
	signal_points = data.get("sp", 0)
	knowledge_tokens = data.get("kt", 0)
	total_wins = data.get("wins", 0)
	total_losses = data.get("losses", 0)
	total_fights = data.get("fights", 0)
	total_minigames = data.get("minigames", 0)
	best_minigame_scores = data.get("best_scores", {})
	var loaded_campaign: Array = data.get("campaign_complete", [])
	campaign_chapters_complete = []
	for ch in loaded_campaign:
		campaign_chapters_complete.append(int(ch))
