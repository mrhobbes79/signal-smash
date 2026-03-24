class_name EquipmentManager
extends RefCounted
## Manages equipment loadouts per fighter. Each fighter has 3 slots.
## Stats flow: Base Stats + Equipment Modifiers = Final Stats

const EquipmentScript = preload("res://scripts/equipment/equipment.gd")

## Loadout: { "radio": Equipment, "antenna": Equipment, "router": Equipment }
var loadout: Dictionary = { "radio": null, "antenna": null, "router": null }
var owned_equipment: Array = []  ## All equipment player owns

func equip(item: Resource) -> bool:
	if item == null or not "type" in item:
		return false
	var slot: String = item.type
	if slot not in loadout:
		return false
	loadout[slot] = item
	return true

func unequip(slot: String) -> void:
	if slot in loadout:
		loadout[slot] = null

func get_equipped(slot: String) -> Resource:
	return loadout.get(slot)

func get_stat_modifier(stat_name: String) -> int:
	var total: int = 0
	for slot in loadout:
		var item: Resource = loadout[slot]
		if item == null:
			continue
		match stat_name:
			"range":
				total += item.stat_range
			"speed":
				total += item.stat_speed
			"stability":
				total += item.stat_stability
			"power":
				total += item.stat_power
	return total

func get_all_modifiers() -> Dictionary:
	return {
		"range": get_stat_modifier("range"),
		"speed": get_stat_modifier("speed"),
		"stability": get_stat_modifier("stability"),
		"power": get_stat_modifier("power"),
	}

func get_equipped_summary() -> String:
	var parts: Array[String] = []
	for slot in ["radio", "antenna", "router"]:
		var item: Resource = loadout[slot]
		if item:
			parts.append("%s: %s %s" % [slot.to_upper(), item.vendor, item.model_name])
		else:
			parts.append("%s: Empty" % slot.to_upper())
	return "\n".join(parts)
