class_name EquipmentLoader
extends RefCounted
## Loads equipment from vendor JSON files in data/vendors/.

static func load_all_equipment() -> Array:
	var all_items: Array = []
	var vendor_dir: String = "res://data/vendors/"
	var dir := DirAccess.open(vendor_dir)
	if dir == null:
		push_warning("[EQUIP] Cannot open vendor directory: %s" % vendor_dir)
		return all_items

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var items: Array = _load_vendor_file(vendor_dir + file_name)
			all_items.append_array(items)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[EQUIP] Loaded %d equipment items from vendors" % all_items.size())
	return all_items

static func _load_vendor_file(path: String) -> Array:
	var items: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[EQUIP] Cannot open: %s" % path)
		return items

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("[EQUIP] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return items

	var data: Dictionary = json.data
	var vendor_name: String = data.get("vendor", "Unknown")
	var vendor_color := Color(data.get("color", "#FFFFFF"))

	for item_data in data.get("equipment", []):
		var equip := Equipment.new()
		equip.id = item_data.get("id", "")
		equip.vendor = vendor_name
		equip.type = item_data.get("type", "")
		equip.model_name = item_data.get("model_name", "")
		equip.stat_range = item_data.get("stat_range", 0)
		equip.stat_speed = item_data.get("stat_speed", 0)
		equip.stat_stability = item_data.get("stat_stability", 0)
		equip.stat_power = item_data.get("stat_power", 0)
		equip.special_passive = item_data.get("special_passive", "")
		equip.rarity = item_data.get("rarity", "common")
		equip.description = item_data.get("description", "")
		equip.color = vendor_color
		items.append(equip)

	return items

static func find_by_id(items: Array, equip_id: String) -> Equipment:
	for item in items:
		if item.id == equip_id:
			return item
	return null

static func filter_by_type(items: Array, equip_type: String) -> Array:
	var filtered: Array = []
	for item in items:
		if item.type == equip_type:
			filtered.append(item)
	return filtered

static func filter_by_vendor(items: Array, vendor_name: String) -> Array:
	var filtered: Array = []
	for item in items:
		if item.vendor == vendor_name:
			filtered.append(item)
	return filtered
