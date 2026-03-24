extends Control
## Loadout Locker — Equip vendor gear before fighting.
## Warehouse-style UI. Each player picks equipment for 3 slots.
## Press ENTER when both players ready to fight.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const GOOD := Color("#22C55E")
const CRIT := Color("#EF4444")
const SLOT_COLORS := {
	"radio": Color("#3B82F6"),
	"antenna": Color("#F59E0B"),
	"router": Color("#22C55E"),
}

const EquipmentLoaderScript = preload("res://scripts/equipment/equipment_loader.gd")

var _all_equipment: Array = []
var _slot_names: Array[String] = ["radio", "antenna", "router"]

# P1 state
var _p1_slot_index: int = 0  # Which slot is selected (0=radio, 1=antenna, 2=router)
var _p1_item_index: Dictionary = { "radio": 0, "antenna": 0, "router": 0 }
var _p1_equipped: Dictionary = { "radio": null, "antenna": null, "router": null }
var _p1_ready: bool = false

# P2 state
var _p2_slot_index: int = 0
var _p2_item_index: Dictionary = { "radio": 0, "antenna": 0, "router": 0 }
var _p2_equipped: Dictionary = { "radio": null, "antenna": null, "router": null }
var _p2_ready: bool = false

# Items per slot type
var _items_by_type: Dictionary = {}

var _time: float = 0.0
var _draw_node: Control

func _ready() -> void:
	# Load all equipment
	_all_equipment = EquipmentLoaderScript.load_all_equipment()
	for slot in _slot_names:
		_items_by_type[slot] = EquipmentLoaderScript.filter_by_type(_all_equipment, slot)
		# Add "None" option at beginning
		_items_by_type[slot].insert(0, null)

	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _LoadoutDraw.new()
	_draw_node.screen = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# P1 (WASD + Space)
	if not _p1_ready:
		var slot: String = _slot_names[_p1_slot_index]
		match event.keycode:
			KEY_W:
				_p1_slot_index = (_p1_slot_index - 1 + 3) % 3
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_S:
				_p1_slot_index = (_p1_slot_index + 1) % 3
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_A:
				_p1_item_index[slot] = (_p1_item_index[slot] - 1 + _items_by_type[slot].size()) % _items_by_type[slot].size()
				_p1_equipped[slot] = _items_by_type[slot][_p1_item_index[slot]]
				if AudioManager:
					AudioManager.play_sfx("align_beep")
			KEY_D:
				_p1_item_index[slot] = (_p1_item_index[slot] + 1) % _items_by_type[slot].size()
				_p1_equipped[slot] = _items_by_type[slot][_p1_item_index[slot]]
				if AudioManager:
					AudioManager.play_sfx("align_beep")
			KEY_SPACE:
				_p1_ready = true
				if AudioManager:
					AudioManager.play_sfx("signal_lock")

	# P2 (Arrows + Shift)
	if not _p2_ready:
		var slot2: String = _slot_names[_p2_slot_index]
		match event.keycode:
			KEY_UP:
				_p2_slot_index = (_p2_slot_index - 1 + 3) % 3
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_DOWN:
				_p2_slot_index = (_p2_slot_index + 1) % 3
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_LEFT:
				_p2_item_index[slot2] = (_p2_item_index[slot2] - 1 + _items_by_type[slot2].size()) % _items_by_type[slot2].size()
				_p2_equipped[slot2] = _items_by_type[slot2][_p2_item_index[slot2]]
				if AudioManager:
					AudioManager.play_sfx("align_beep")
			KEY_RIGHT:
				_p2_item_index[slot2] = (_p2_item_index[slot2] + 1) % _items_by_type[slot2].size()
				_p2_equipped[slot2] = _items_by_type[slot2][_p2_item_index[slot2]]
				if AudioManager:
					AudioManager.play_sfx("align_beep")
			KEY_SHIFT:
				_p2_ready = true
				if AudioManager:
					AudioManager.play_sfx("signal_lock")

	# ESC
	if event.keycode == KEY_ESCAPE:
		if _p1_ready or _p2_ready:
			_p1_ready = false
			_p2_ready = false
		else:
			get_tree().change_scene_to_file("res://scenes/main/character_select.tscn")

	# Both ready
	if _p1_ready and _p2_ready:
		if AudioManager:
			AudioManager.play_sfx("victory")
			AudioManager.stop_music()
		get_tree().change_scene_to_file("res://scenes/fighters/fight_test.tscn")

func _get_total_stats(equipped: Dictionary) -> Dictionary:
	var totals := { "range": 0, "speed": 0, "stability": 0, "power": 0 }
	for slot in equipped:
		var item = equipped[slot]
		if item != null:
			totals["range"] += item.stat_range
			totals["speed"] += item.stat_speed
			totals["stability"] += item.stat_stability
			totals["power"] += item.stat_power
	return totals


class _LoadoutDraw extends Control:
	var screen: Node

	func _draw() -> void:
		if screen == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font

		# Header
		draw_rect(Rect2(0, 0, s.x, 55), BG)
		draw_string(font, Vector2(s.x / 2.0 - 120, 38), "LOADOUT LOCKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ACCENT)
		draw_rect(Rect2(0, 55, s.x, 2), Color(ACCENT, 0.3))

		# P1 panel (left half)
		_draw_player_panel(Vector2(15, 70), s.x / 2.0 - 25, s.y - 150, "P1 RICO", Color("#2563EB"),
			screen._p1_slot_index, screen._p1_equipped, screen._p1_ready, screen._items_by_type, screen._p1_item_index)

		# P2 panel (right half)
		_draw_player_panel(Vector2(s.x / 2.0 + 10, 70), s.x / 2.0 - 25, s.y - 150, "P2 VERO", Color("#7C3AED"),
			screen._p2_slot_index, screen._p2_equipped, screen._p2_ready, screen._items_by_type, screen._p2_item_index)

		# Bottom controls
		var bottom_y := s.y - 65
		draw_rect(Rect2(0, bottom_y, s.x, 65), BG)
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		draw_string(font, Vector2(20, bottom_y + 25), "P1: W/S slot | A/D equip | SPACE ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#2563EB"))
		draw_string(font, Vector2(20, bottom_y + 48), "P2: ↑/↓ slot | ←/→ equip | SHIFT ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#7C3AED"))
		draw_string(font, Vector2(s.x - 200, bottom_y + 25), "ESC = Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(TEXT, 0.4))

		if screen._p1_ready and screen._p2_ready:
			var pulse: float = (sin(screen._time * 6.0) + 1.0) / 2.0
			draw_string(font, Vector2(s.x / 2.0 - 50, bottom_y + 40), "FIGHT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(GOOD, 0.5 + pulse * 0.5))

	func _draw_player_panel(pos: Vector2, width: float, height: float, title: String, color: Color,
			active_slot: int, equipped: Dictionary, is_ready: bool, items_by_type: Dictionary, item_indices: Dictionary) -> void:
		var font := ThemeDB.fallback_font
		var slot_names: Array[String] = ["radio", "antenna", "router"]

		# Panel border
		draw_rect(Rect2(pos.x, pos.y, width, height), Color(BG, 0.95))
		draw_rect(Rect2(pos.x, pos.y, width, height), color, false, 2.0)

		# Title
		draw_string(font, Vector2(pos.x + 15, pos.y + 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
		if is_ready:
			draw_string(font, Vector2(pos.x + width - 90, pos.y + 28), "READY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOOD)

		# Equipment slots
		var slot_y: float = pos.y + 50
		var slot_h: float = (height - 130) / 3.0

		for i in range(3):
			var slot_name: String = slot_names[i]
			var is_active: bool = i == active_slot and not is_ready
			var slot_color: Color = SLOT_COLORS.get(slot_name, ACCENT)
			var item = equipped.get(slot_name)

			# Slot background
			var slot_rect := Rect2(pos.x + 10, slot_y, width - 20, slot_h - 8)
			draw_rect(slot_rect, Color(slot_color, 0.05))
			if is_active:
				draw_rect(slot_rect, Color(slot_color, 0.3), false, 2.0)
				draw_string(font, Vector2(pos.x + 15, slot_y + 20), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, slot_color)

			# Slot label
			draw_string(font, Vector2(pos.x + 35, slot_y + 20), slot_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, slot_color)

			if item != null:
				# Equipped item
				draw_string(font, Vector2(pos.x + 35, slot_y + 42), "%s %s" % [item.vendor, item.model_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
				draw_string(font, Vector2(pos.x + 35, slot_y + 62), item.get_stat_summary(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(GOOD if true else TEXT, 0.7))

				# Rarity badge
				var rarity_color: Color = WARN if item.rarity == "rare" else Color(TEXT, 0.4)
				draw_string(font, Vector2(pos.x + width - 85, slot_y + 20), "[%s]" % item.rarity.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, rarity_color)

				# Description
				draw_string(font, Vector2(pos.x + 35, slot_y + 80), item.description, HORIZONTAL_ALIGNMENT_LEFT, int(width - 60), 11, Color(TEXT, 0.3))
			else:
				draw_string(font, Vector2(pos.x + 35, slot_y + 42), "< Empty — A/D to browse >", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.3))

			# Item counter
			if is_active and slot_name in items_by_type:
				var idx: int = item_indices.get(slot_name, 0)
				var total: int = items_by_type[slot_name].size()
				draw_string(font, Vector2(pos.x + width - 85, slot_y + 42), "%d / %d" % [idx, total - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, 0.4))

			slot_y += slot_h

		# Total stat modifiers
		var stats: Dictionary = screen._get_total_stats(equipped)
		var stats_y: float = pos.y + height - 60
		draw_rect(Rect2(pos.x + 10, stats_y, width - 20, 50), Color(ACCENT, 0.05))
		draw_string(font, Vector2(pos.x + 15, stats_y + 18), "TOTAL MODIFIERS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENT)

		var stat_x: float = pos.x + 15
		for stat_name in ["range", "speed", "stability", "power"]:
			var val: int = stats[stat_name]
			var stat_label: String = stat_name.substr(0, 3).to_upper()
			var stat_col: Color = GOOD if val > 0 else (CRIT if val < 0 else Color(TEXT, 0.4))
			draw_string(font, Vector2(stat_x, stats_y + 40), "%s: %+d" % [stat_label, val], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, stat_col)
			stat_x += (width - 30) / 4.0
