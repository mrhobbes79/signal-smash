class_name Equipment
extends Resource
## A piece of vendor equipment that modifies fighter stats.
## Three slots per fighter: radio, antenna, router.

@export var id: String = ""
@export var vendor: String = ""
@export var type: String = ""           ## "radio" | "antenna" | "router"
@export var model_name: String = ""
@export var stat_range: int = 0
@export var stat_speed: int = 0
@export var stat_stability: int = 0
@export var stat_power: int = 0
@export var special_passive: String = ""
@export var rarity: String = "common"   ## "common" | "rare" | "legendary"
@export var description: String = ""
@export var color: Color = Color.WHITE

func get_stat_summary() -> String:
	var parts: Array[String] = []
	if stat_range != 0:
		parts.append("RNG %+d" % stat_range)
	if stat_speed != 0:
		parts.append("SPD %+d" % stat_speed)
	if stat_stability != 0:
		parts.append("DEF %+d" % stat_stability)
	if stat_power != 0:
		parts.append("PWR %+d" % stat_power)
	return " | ".join(parts) if parts.size() > 0 else "No stat bonus"
