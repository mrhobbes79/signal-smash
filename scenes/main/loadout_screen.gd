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

	# Play loadout music
	if AudioManager:
		AudioManager.play_music_loadout()

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
					AudioManager.play_sfx("equip")
			KEY_D:
				_p1_item_index[slot] = (_p1_item_index[slot] + 1) % _items_by_type[slot].size()
				_p1_equipped[slot] = _items_by_type[slot][_p1_item_index[slot]]
				if AudioManager:
					AudioManager.play_sfx("equip")
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
					AudioManager.play_sfx("equip")
			KEY_RIGHT:
				_p2_item_index[slot2] = (_p2_item_index[slot2] + 1) % _items_by_type[slot2].size()
				_p2_equipped[slot2] = _items_by_type[slot2][_p2_item_index[slot2]]
				if AudioManager:
					AudioManager.play_sfx("equip")
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

	# Both ready — store equipment and go to fight
	if _p1_ready and _p2_ready:
		GameMgr.p1_equipment = _p1_equipped.duplicate()
		GameMgr.p2_equipment = _p2_equipped.duplicate()
		if AudioManager:
			AudioManager.play_sfx("fight_start")
			AudioManager.stop_music()
		get_tree().change_scene_to_file("res://scenes/main/arena_select.tscn")

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
		var p1_data := GameMgr.get_p1()
		_draw_player_panel(Vector2(15, 70), s.x / 2.0 - 25, s.y - 150, "P1 " + p1_data["name"], p1_data["color"],
			screen._p1_slot_index, screen._p1_equipped, screen._p1_ready, screen._items_by_type, screen._p1_item_index)

		# P2 panel (right half)
		var p2_data := GameMgr.get_p2()
		_draw_player_panel(Vector2(s.x / 2.0 + 10, 70), s.x / 2.0 - 25, s.y - 150, "P2 " + p2_data["name"], p2_data["color"],
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
		draw_string(font, Vector2(pos.x + 15, pos.y + 35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
		if is_ready:
			draw_string(font, Vector2(pos.x + width - 110, pos.y + 35), "READY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOOD)

		# Equipment slots
		var slot_y: float = pos.y + 55
		var slot_h: float = (height - 140) / 3.0
		var icon_size: float = minf(slot_h - 16, 120)

		for i in range(3):
			var slot_name: String = slot_names[i]
			var is_active: bool = i == active_slot and not is_ready
			var slot_color: Color = SLOT_COLORS.get(slot_name, ACCENT)
			var item = equipped.get(slot_name)

			# Slot background
			var slot_rect := Rect2(pos.x + 10, slot_y, width - 20, slot_h - 8)
			draw_rect(slot_rect, Color(slot_color, 0.06))
			if is_active:
				draw_rect(slot_rect, Color(slot_color, 0.35), false, 3.0)
				draw_string(font, Vector2(pos.x + 16, slot_y + 28), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, slot_color)

			# ═══ EQUIPMENT ICON (BIG) ═══
			var icon_x: float = pos.x + 20
			var icon_y: float = slot_y + 6
			var ic := icon_size
			var item_color: Color = item.color if item != null else Color(slot_color, 0.2)
			var icon_cx: float = icon_x + ic / 2.0
			var icon_cy: float = icon_y + ic / 2.0

			# Icon background box
			draw_rect(Rect2(icon_x, icon_y, ic, ic), Color(0.08, 0.08, 0.12))
			draw_rect(Rect2(icon_x, icon_y, ic, ic), Color(slot_color, 0.35), false, 2.0)

			if item != null:
				match slot_name:
					"radio":
						_draw_radio_icon(icon_cx, icon_cy, ic, item_color, slot_color)
					"antenna":
						_draw_antenna_icon(icon_cx, icon_cy, ic, item_color, slot_color)
					"router":
						_draw_router_icon(icon_cx, icon_cy, ic, item_color, slot_color)
			else:
				match slot_name:
					"radio":
						_draw_radio_icon(icon_cx, icon_cy, ic, Color(slot_color, 0.15), Color(slot_color, 0.1))
					"antenna":
						_draw_antenna_icon(icon_cx, icon_cy, ic, Color(slot_color, 0.15), Color(slot_color, 0.1))
					"router":
						_draw_router_icon(icon_cx, icon_cy, ic, Color(slot_color, 0.15), Color(slot_color, 0.1))

			# ═══ TEXT INFO (offset right for icon) ═══
			var text_x: float = icon_x + ic + 16
			var text_w: float = width - ic - 60

			# Slot label
			draw_string(font, Vector2(text_x, slot_y + 26), slot_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, slot_color)

			if item != null:
				# Equipped item name (BIG)
				draw_string(font, Vector2(text_x, slot_y + 52), "%s %s" % [item.vendor, item.model_name], HORIZONTAL_ALIGNMENT_LEFT, int(text_w), 20, TEXT)

				# Stat bars (visual, bigger)
				var bar_y: float = slot_y + 60
				var bar_w: float = minf(text_w - 10, 200)
				var bar_h: float = 12.0
				var stats_arr := [
					["RNG", item.stat_range, Color("#3B82F6")],
					["SPD", item.stat_speed, Color("#22C55E")],
					["DEF", item.stat_stability, Color("#F59E0B")],
					["PWR", item.stat_power, Color("#EF4444")],
				]
				for stat in stats_arr:
					var val: int = stat[1]
					if val == 0:
						continue
					bar_y += 18
					draw_string(font, Vector2(text_x, bar_y), stat[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(TEXT, 0.5))
					draw_rect(Rect2(text_x + 38, bar_y - 10, bar_w, bar_h), Color(0.12, 0.12, 0.15))
					var fill: float = clampf(absf(val) / 20.0, 0.05, 1.0) * bar_w
					var bar_col: Color = stat[2] if val > 0 else CRIT
					draw_rect(Rect2(text_x + 38, bar_y - 10, fill, bar_h), bar_col)
					draw_string(font, Vector2(text_x + 42 + fill, bar_y), "%+d" % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, bar_col)

				# Rarity badge
				var rarity_color: Color = WARN if item.rarity == "rare" else Color(TEXT, 0.4)
				draw_string(font, Vector2(pos.x + width - 100, slot_y + 26), "[%s]" % item.rarity.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, rarity_color)

				# Special passive (if any)
				if item.special_passive != "":
					var sp_name: String = item.special_passive.replace("_", " ").to_upper()
					var sp_y: float = slot_y + slot_h - 42
					draw_string(font, Vector2(text_x, sp_y), "Q SPECIAL:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WARN)
					draw_string(font, Vector2(text_x + 85, sp_y), sp_name, HORIZONTAL_ALIGNMENT_LEFT, int(text_w - 85), 13, Color(WARN, 0.8))

				# Description
				draw_string(font, Vector2(text_x, slot_y + slot_h - 22), item.description, HORIZONTAL_ALIGNMENT_LEFT, int(text_w), 14, Color(TEXT, 0.4))
			else:
				draw_string(font, Vector2(text_x, slot_y + 52), "< Empty >", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.3))
				draw_string(font, Vector2(text_x, slot_y + 76), "Browse with A/D or ←/→", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.2))

			# Item counter
			if is_active and slot_name in items_by_type:
				var idx: int = item_indices.get(slot_name, 0)
				var total: int = items_by_type[slot_name].size()
				draw_string(font, Vector2(pos.x + width - 100, slot_y + 50), "%d / %d" % [idx, total - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))

			slot_y += slot_h

		# Total stat modifiers
		var stats: Dictionary = screen._get_total_stats(equipped)
		var stats_y: float = pos.y + height - 70
		draw_rect(Rect2(pos.x + 10, stats_y, width - 20, 60), Color(ACCENT, 0.06))
		draw_string(font, Vector2(pos.x + 15, stats_y + 22), "TOTAL MODIFIERS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ACCENT)

		var stat_x: float = pos.x + 15
		for stat_name in ["range", "speed", "stability", "power"]:
			var val: int = stats[stat_name]
			var stat_label: String = stat_name.substr(0, 3).to_upper()
			var stat_col: Color = GOOD if val > 0 else (CRIT if val < 0 else Color(TEXT, 0.4))
			draw_string(font, Vector2(stat_x, stats_y + 48), "%s: %+d" % [stat_label, val], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, stat_col)
			stat_x += (width - 30) / 4.0

	## ═══════════ EQUIPMENT ICONS ═══════════

	func _draw_radio_icon(cx: float, cy: float, sz: float, col: Color, accent: Color) -> void:
		## Radio — Dish/sector antenna with signal waves
		var r: float = sz * 0.3
		# Dish base (rectangle)
		draw_rect(Rect2(cx - r * 0.2, cy + r * 0.3, r * 0.4, r * 0.8), Color(col, 0.8))
		# Dish reflector (arc shape via thick lines)
		var dish_r: float = r * 1.1
		for a in range(-40, 41, 8):
			var rad: float = deg_to_rad(float(a) - 90)
			var x1: float = cx + cos(rad) * dish_r * 0.9
			var y1: float = cy - sin(rad) * dish_r * 0.6 - r * 0.2
			var x2: float = cx + cos(rad) * dish_r
			var y2: float = cy - sin(rad) * dish_r * 0.7 - r * 0.2
			draw_line(Vector2(x1, y1), Vector2(x2, y2), col, 2.5)
		# Feed horn (small circle at center)
		draw_circle(Vector2(cx, cy - r * 0.2), r * 0.15, accent)
		# Signal waves
		for w in range(3):
			var wave_r: float = r * 0.4 + w * r * 0.3
			var wave_alpha: float = 0.7 - w * 0.2
			draw_arc(Vector2(cx, cy - r * 0.2), wave_r, deg_to_rad(-45), deg_to_rad(45), 8, Color(accent, wave_alpha), 1.5)

	func _draw_antenna_icon(cx: float, cy: float, sz: float, col: Color, accent: Color) -> void:
		## Antenna — Panel antenna with mounting bracket
		var r: float = sz * 0.3
		# Panel body (tall rectangle)
		draw_rect(Rect2(cx - r * 0.5, cy - r * 1.0, r * 1.0, r * 1.6), col)
		# Panel inner (darker)
		draw_rect(Rect2(cx - r * 0.35, cy - r * 0.8, r * 0.7, r * 1.2), Color(col, 0.6))
		# Mounting pole
		draw_rect(Rect2(cx - r * 0.08, cy + r * 0.6, r * 0.16, r * 0.6), Color(0.5, 0.5, 0.5))
		# Bracket arms
		draw_line(Vector2(cx - r * 0.4, cy + r * 0.7), Vector2(cx - r * 0.08, cy + r * 0.9), Color(0.6, 0.6, 0.6), 2.0)
		draw_line(Vector2(cx + r * 0.4, cy + r * 0.7), Vector2(cx + r * 0.08, cy + r * 0.9), Color(0.6, 0.6, 0.6), 2.0)
		# Signal indicator LEDs
		for i in range(3):
			var led_y: float = cy - r * 0.6 + i * r * 0.4
			var led_col: Color = accent if i < 2 else Color(1, 0.3, 0.3)
			draw_circle(Vector2(cx, led_y), r * 0.08, led_col)
		# Connector at bottom
		draw_rect(Rect2(cx - r * 0.12, cy + r * 1.15, r * 0.24, r * 0.12), accent)

	func _draw_router_icon(cx: float, cy: float, sz: float, col: Color, accent: Color) -> void:
		## Router — Box with ports and status LEDs
		var r: float = sz * 0.3
		# Router body
		draw_rect(Rect2(cx - r * 1.1, cy - r * 0.4, r * 2.2, r * 1.0), col)
		# Top edge (slight 3D effect)
		draw_rect(Rect2(cx - r * 1.1, cy - r * 0.4, r * 2.2, r * 0.15), Color(col, 1.2 if col.v > 0.3 else 0.8))
		# Status LEDs row
		for i in range(4):
			var lx: float = cx - r * 0.7 + i * r * 0.45
			var led_col: Color
			if i == 0:
				led_col = Color(0.2, 1.0, 0.2)  # Power = green
			elif i < 3:
				led_col = accent  # Activity
			else:
				led_col = Color(1.0, 0.6, 0.1)  # Warning
			draw_circle(Vector2(lx, cy - r * 0.15), r * 0.08, led_col)
		# Ethernet ports (bottom row)
		for i in range(4):
			var px: float = cx - r * 0.7 + i * r * 0.45
			draw_rect(Rect2(px - r * 0.1, cy + r * 0.15, r * 0.2, r * 0.2), Color(0.15, 0.15, 0.2))
			draw_rect(Rect2(px - r * 0.1, cy + r * 0.15, r * 0.2, r * 0.2), Color(0.3, 0.3, 0.35), false, 1.0)
		# Small antennas on top
		draw_line(Vector2(cx - r * 0.6, cy - r * 0.4), Vector2(cx - r * 0.7, cy - r * 1.0), Color(0.5, 0.5, 0.5), 2.0)
		draw_circle(Vector2(cx - r * 0.7, cy - r * 1.0), r * 0.06, accent)
		draw_line(Vector2(cx + r * 0.6, cy - r * 0.4), Vector2(cx + r * 0.7, cy - r * 1.0), Color(0.5, 0.5, 0.5), 2.0)
		draw_circle(Vector2(cx + r * 0.7, cy - r * 1.0), r * 0.06, accent)
