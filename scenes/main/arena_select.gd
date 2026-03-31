extends Control
## Arena Select Screen — Pick an arena before the fight.
## Shows all 8 arenas in a grid. Navigate with arrows, confirm with ENTER.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")

var _selected: int = 0
var _time: float = 0.0
var _draw_node: Control

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _ArenaDraw.new()
	_draw_node.screen = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# Play arena select music
	if AudioManager:
		AudioManager.play_music_select()

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	var count: int = GameMgr.ARENA_DATA.size()
	var cols: int = 4
	var weather_count: int = GameMgr.WEATHER_NAMES.size()

	match event.keycode:
		KEY_LEFT, KEY_A:
			_selected = (_selected - 1 + count) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_RIGHT, KEY_D:
			_selected = (_selected + 1) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_UP:
			_selected = (_selected - cols + count) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_DOWN:
			_selected = (_selected + cols) % count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_W:
			GameMgr.selected_weather = (GameMgr.selected_weather - 1 + weather_count) % weather_count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_S:
			GameMgr.selected_weather = (GameMgr.selected_weather + 1) % weather_count
			if AudioManager:
				AudioManager.play_sfx("menu_move")
		KEY_ENTER, KEY_SPACE:
			GameMgr.selected_arena = _selected
			if AudioManager:
				AudioManager.play_sfx("menu_select")
				AudioManager.stop_music()
			get_tree().change_scene_to_file("res://scenes/fighters/fight_test.tscn")
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main/loadout_screen.tscn")
		KEY_R:
			# Random arena
			_selected = randi() % count
			if AudioManager:
				AudioManager.play_sfx("equip")


class _ArenaDraw extends Control:
	var screen: Node

	func _draw() -> void:
		if screen == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = screen._time
		var arenas: Array = GameMgr.ARENA_DATA

		# Header
		draw_rect(Rect2(0, 0, s.x, 60), BG)
		draw_string(font, Vector2(s.x / 2.0 - 120, 42), "SELECT ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ACCENT)
		draw_rect(Rect2(0, 60, s.x, 2), Color(ACCENT, 0.3))

		# Arena grid (4x2)
		var cols: int = 4
		var rows: int = 2
		var margin: float = 20.0
		var card_w: float = (s.x - margin * (cols + 1)) / cols
		var card_h: float = (s.y - 160 - margin * (rows + 1)) / rows
		var grid_y: float = 80.0

		for i in range(arenas.size()):
			var arena: Dictionary = arenas[i]
			var col: int = i % cols
			var row: int = i / cols
			var cx: float = margin + col * (card_w + margin)
			var cy: float = grid_y + row * (card_h + margin)
			var is_sel: bool = i == screen._selected

			# Card background — arena sky gradient (4 bands for smoother look)
			var sky_top: Color = arena["sky_top"]
			var sky_bot: Color = arena["sky_bot"]
			for band in range(4):
				var t0: float = band / 4.0
				var t1: float = (band + 1) / 4.0
				var band_col: Color = sky_top.lerp(sky_bot, (t0 + t1) / 2.0)
				draw_rect(Rect2(cx, cy + card_h * t0, card_w, card_h * (t1 - t0)), band_col)

			var plat_color: Color = arena["color"]
			var accent_col: Color = arena["accent"]
			var arena_name: String = arena["name"]

			# Arena-specific silhouettes
			if arena_name.contains("Monterrey") and not arena_name.contains("WISPMX"):
				# Monterrey: mountains + rooftop + water tank + tower
				var mnt_y: float = cy + card_h * 0.35
				draw_polygon(PackedVector2Array([Vector2(cx, cy + card_h * 0.6), Vector2(cx + card_w * 0.3, mnt_y), Vector2(cx + card_w * 0.5, cy + card_h * 0.45), Vector2(cx + card_w * 0.7, mnt_y - 10), Vector2(cx + card_w, cy + card_h * 0.55), Vector2(cx + card_w, cy + card_h * 0.7), Vector2(cx, cy + card_h * 0.7)]), PackedColorArray([Color(plat_color, 0.4), Color(plat_color, 0.4), Color(plat_color, 0.4), Color(plat_color, 0.4), Color(plat_color, 0.4), Color(plat_color, 0.4), Color(plat_color, 0.4)]))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
				draw_rect(Rect2(cx + 20, cy + card_h - 50, card_w * 0.2, 12), Color(plat_color, 0.6))
				draw_rect(Rect2(cx + card_w - 30 - card_w * 0.2, cy + card_h - 46, card_w * 0.2, 12), Color(plat_color, 0.6))
				# Water tank (tinaco)
				draw_rect(Rect2(cx + card_w * 0.7, cy + card_h - 56, 14, 20), Color(0.3, 0.3, 0.3, 0.7))
				# Tower
				draw_rect(Rect2(cx + card_w * 0.15, cy + card_h * 0.25, 4, card_h * 0.45), Color(0.8, 0.2, 0.2, 0.6))
				draw_rect(Rect2(cx + card_w * 0.15 - 6, cy + card_h * 0.25, 16, 3), Color(0.7, 0.7, 0.7, 0.5))
			elif arena_name.contains("CDMX"):
				# CDMX: dense buildings + smog + Torre Latino silhouette
				for bi in range(8):
					var bx: float = cx + bi * (card_w / 8.0)
					var bh: float = card_h * (0.25 + fmod(float(bi * 37), 20.0) / 50.0)
					var bw: float = card_w / 9.0
					draw_rect(Rect2(bx + 2, cy + card_h - bh, bw, bh), Color(plat_color, 0.5 + float(bi % 3) * 0.1))
					# Windows
					for wy in range(3):
						draw_rect(Rect2(bx + 5, cy + card_h - bh + 8 + wy * 12, 4, 6), Color(accent_col, 0.3))
				# Torre Latino (taller)
				draw_rect(Rect2(cx + card_w * 0.45, cy + card_h * 0.2, 12, card_h * 0.6), Color(0.5, 0.55, 0.6, 0.7))
				draw_rect(Rect2(cx + card_w * 0.44, cy + card_h * 0.2, 16, 4), Color(0.6, 0.65, 0.7, 0.6))
				# Smog band
				draw_rect(Rect2(cx, cy + card_h * 0.3, card_w, card_h * 0.1), Color(0.6, 0.6, 0.5, 0.15))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
			elif arena_name.contains("Rio"):
				# Rio: Cristo Redentor + morros + colorful favela houses + ocean
				draw_rect(Rect2(cx, cy + card_h * 0.75, card_w, card_h * 0.25), Color(0.1, 0.5, 0.7, 0.4))
				# Morros
				draw_polygon(PackedVector2Array([Vector2(cx, cy + card_h * 0.7), Vector2(cx + card_w * 0.25, cy + card_h * 0.35), Vector2(cx + card_w * 0.45, cy + card_h * 0.65), Vector2(cx + card_w * 0.6, cy + card_h * 0.3), Vector2(cx + card_w, cy + card_h * 0.6), Vector2(cx + card_w, cy + card_h * 0.75), Vector2(cx, cy + card_h * 0.75)]), PackedColorArray([Color(0.1, 0.5, 0.2, 0.5), Color(0.1, 0.5, 0.2, 0.5), Color(0.1, 0.5, 0.2, 0.5), Color(0.1, 0.5, 0.2, 0.5), Color(0.1, 0.5, 0.2, 0.5), Color(0.1, 0.5, 0.2, 0.5), Color(0.1, 0.5, 0.2, 0.5)]))
				# Cristo silhouette
				draw_rect(Rect2(cx + card_w * 0.57, cy + card_h * 0.18, 4, 18), Color(0.8, 0.8, 0.8, 0.5))
				draw_rect(Rect2(cx + card_w * 0.5, cy + card_h * 0.2, 20, 3), Color(0.8, 0.8, 0.8, 0.5))
				# Colorful favela houses
				var fav_colors := [Color(0.9, 0.3, 0.2), Color(0.2, 0.6, 0.9), Color(0.9, 0.8, 0.2), Color(0.3, 0.8, 0.3), Color(0.9, 0.5, 0.1)]
				for fi in range(5):
					draw_rect(Rect2(cx + 10 + fi * (card_w - 20) / 5.0, cy + card_h - 38 - fmod(float(fi * 7), 10.0), (card_w - 30) / 5.5, 14 + fmod(float(fi * 5), 8.0)), Color(fav_colors[fi], 0.6))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
			elif arena_name.contains("Dallas"):
				# Dallas: server racks + blue LED glow + dark interior
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
				# Server racks
				for si in range(6):
					var sx: float = cx + 12 + si * (card_w - 24) / 6.0
					draw_rect(Rect2(sx, cy + card_h * 0.35, 10, card_h * 0.35), Color(0.15, 0.2, 0.25, 0.8))
					# LED dots
					for li in range(4):
						var led_col: Color = accent_col if fmod(t * 2.0 + float(si + li), 3.0) > 1.5 else Color(0.1, 0.4, 0.1, 0.5)
						draw_rect(Rect2(sx + 2, cy + card_h * 0.38 + li * 10, 3, 2), led_col)
				# Ceiling lights
				draw_rect(Rect2(cx + 15, cy + card_h * 0.28, card_w - 30, 3), Color(0.9, 0.95, 1.0, 0.3))
				# Neon floor strip
				draw_rect(Rect2(cx + 15, cy + card_h - 34, card_w - 30, 2), Color(accent_col, 0.5 + sin(t * 3.0) * 0.3))
			elif arena_name.contains("Bogot"):
				# Bogota: Andean mountains + fog + dense vegetation
				draw_polygon(PackedVector2Array([Vector2(cx, cy + card_h * 0.65), Vector2(cx + card_w * 0.2, cy + card_h * 0.25), Vector2(cx + card_w * 0.4, cy + card_h * 0.35), Vector2(cx + card_w * 0.6, cy + card_h * 0.2), Vector2(cx + card_w * 0.8, cy + card_h * 0.3), Vector2(cx + card_w, cy + card_h * 0.5), Vector2(cx + card_w, cy + card_h * 0.7), Vector2(cx, cy + card_h * 0.7)]), PackedColorArray([Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6), Color(0.15, 0.4, 0.15, 0.6)]))
				# Fog band
				draw_rect(Rect2(cx, cy + card_h * 0.4, card_w, card_h * 0.12), Color(0.85, 0.9, 0.85, 0.2))
				# Trees
				for ti in range(5):
					var tx: float = cx + 15 + ti * (card_w - 30) / 5.0
					draw_rect(Rect2(tx + 3, cy + card_h - 48, 3, 16), Color(0.35, 0.25, 0.15, 0.6))
					draw_circle(Vector2(tx + 4, cy + card_h - 50), 8.0, Color(0.1, 0.5, 0.15, 0.5))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
			elif arena_name.contains("Buenos"):
				# Buenos Aires: pampa + towers + obelisco + windmill
				draw_rect(Rect2(cx, cy + card_h * 0.6, card_w, card_h * 0.4), Color(0.6, 0.55, 0.3, 0.3))
				# Towers
				draw_rect(Rect2(cx + card_w * 0.15, cy + card_h * 0.25, 3, card_h * 0.45), Color(0.5, 0.5, 0.5, 0.5))
				draw_rect(Rect2(cx + card_w * 0.8, cy + card_h * 0.3, 3, card_h * 0.4), Color(0.5, 0.5, 0.5, 0.5))
				# Obelisco
				draw_polygon(PackedVector2Array([Vector2(cx + card_w * 0.5 - 3, cy + card_h * 0.65), Vector2(cx + card_w * 0.5, cy + card_h * 0.25), Vector2(cx + card_w * 0.5 + 3, cy + card_h * 0.65)]), PackedColorArray([Color(0.85, 0.85, 0.8, 0.6), Color(0.85, 0.85, 0.8, 0.6), Color(0.85, 0.85, 0.8, 0.6)]))
				# Windmill
				draw_rect(Rect2(cx + card_w * 0.35, cy + card_h * 0.35, 3, 20), Color(0.6, 0.5, 0.4, 0.5))
				draw_rect(Rect2(cx + card_w * 0.33, cy + card_h * 0.33, 10, 2), Color(0.7, 0.6, 0.5, 0.5))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
			elif arena_name.contains("Miami"):
				# Miami: Art Deco buildings + palm trees + sunset + beach
				draw_rect(Rect2(cx, cy + card_h * 0.8, card_w, card_h * 0.2), Color(0.85, 0.75, 0.55, 0.4))
				# Art Deco buildings
				var deco_colors := [Color(0.95, 0.6, 0.7), Color(0.6, 0.85, 0.9), Color(0.95, 0.85, 0.6), Color(0.7, 0.9, 0.75)]
				for di in range(4):
					var dx: float = cx + 8 + di * (card_w - 16) / 4.0
					var dh: float = card_h * (0.25 + fmod(float(di * 11), 12.0) / 50.0)
					draw_rect(Rect2(dx, cy + card_h - dh - 10, (card_w - 20) / 4.5, dh), Color(deco_colors[di], 0.5))
				# Palm tree
				draw_rect(Rect2(cx + card_w * 0.75, cy + card_h * 0.3, 3, card_h * 0.35), Color(0.5, 0.35, 0.2, 0.6))
				draw_polygon(PackedVector2Array([Vector2(cx + card_w * 0.73, cy + card_h * 0.32), Vector2(cx + card_w * 0.77, cy + card_h * 0.25), Vector2(cx + card_w * 0.82, cy + card_h * 0.3)]), PackedColorArray([Color(0.2, 0.6, 0.2, 0.5), Color(0.2, 0.6, 0.2, 0.5), Color(0.2, 0.6, 0.2, 0.5)]))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
			elif arena_name.contains("WISPMX"):
				# WISPMX: Mexican flag colors + fiesta decorations
				draw_rect(Rect2(cx, cy + card_h * 0.5, card_w / 3.0, card_h * 0.15), Color(0.0, 0.5, 0.15, 0.3))
				draw_rect(Rect2(cx + card_w / 3.0, cy + card_h * 0.5, card_w / 3.0, card_h * 0.15), Color(0.95, 0.95, 0.95, 0.3))
				draw_rect(Rect2(cx + card_w * 2.0 / 3.0, cy + card_h * 0.5, card_w / 3.0, card_h * 0.15), Color(0.8, 0.1, 0.1, 0.3))
				# Papel picado (triangular banners)
				for pi in range(6):
					var px: float = cx + 10 + pi * (card_w - 20) / 6.0
					var pcol: Color = [Color.RED, Color.GREEN, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE][pi]
					draw_polygon(PackedVector2Array([Vector2(px, cy + card_h * 0.35), Vector2(px + 10, cy + card_h * 0.35), Vector2(px + 5, cy + card_h * 0.45)]), PackedColorArray([Color(pcol, 0.5), Color(pcol, 0.5), Color(pcol, 0.5)]))
				# Banner line
				draw_line(Vector2(cx + 5, cy + card_h * 0.35), Vector2(cx + card_w - 5, cy + card_h * 0.35), Color(0.8, 0.8, 0.8, 0.4), 1.0)
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
			else:
				# WISPA / WISPA 2026: convention hall + screens + booth silhouettes
				# Stage/booth silhouettes
				for bi in range(4):
					var bx: float = cx + 10 + bi * (card_w - 20) / 4.0
					draw_rect(Rect2(bx, cy + card_h * 0.5, (card_w - 30) / 4.5, card_h * 0.2), Color(accent_col, 0.2))
				# Big screen
				draw_rect(Rect2(cx + card_w * 0.3, cy + card_h * 0.25, card_w * 0.4, card_h * 0.2), Color(accent_col, 0.3))
				draw_rect(Rect2(cx + card_w * 0.32, cy + card_h * 0.27, card_w * 0.36, card_h * 0.16), Color(0.1, 0.2, 0.4, 0.4))
				# Stage lights
				for li in range(3):
					var lx: float = cx + card_w * 0.25 + li * card_w * 0.25
					draw_circle(Vector2(lx, cy + card_h * 0.22), 4.0, Color(accent_col, 0.4 + sin(t * 2.0 + float(li)) * 0.2))
				draw_rect(Rect2(cx + 10, cy + card_h - 32, card_w - 20, 22), Color(plat_color, 0.9))
				# Side platforms
				draw_rect(Rect2(cx + 15, cy + card_h - 50, card_w * 0.2, 10), Color(plat_color, 0.5))
				draw_rect(Rect2(cx + card_w - 15 - card_w * 0.2, cy + card_h - 46, card_w * 0.2, 10), Color(plat_color, 0.5))

			# Selection border
			if is_sel:
				var pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(ACCENT, 0.5 + pulse * 0.5), false, 3.0)
				# Arrow
				draw_string(font, Vector2(cx + 5, cy + 22), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)
			else:
				draw_rect(Rect2(cx, cy, card_w, card_h), Color(0.3, 0.3, 0.4, 0.3), false, 1.0)

			# Arena name (large font with dark background for contrast)
			var name_bg_y: float = cy + card_h - 48
			draw_rect(Rect2(cx, name_bg_y, card_w, 32), Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(cx + 8, name_bg_y + 24), arena["name"], HORIZONTAL_ALIGNMENT_LEFT, int(card_w - 16), 22, Color.WHITE if is_sel else Color(TEXT, 0.8))
			# City (top banner with dark background)
			draw_rect(Rect2(cx, cy, card_w, 28), Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(cx + 8, cy + 22), arena["city"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.7))

		# Bottom bar
		var bottom_y := s.y - 65
		draw_rect(Rect2(0, bottom_y, s.x, 65), BG)
		draw_rect(Rect2(0, bottom_y, s.x, 1), Color(ACCENT, 0.3))
		draw_string(font, Vector2(20, bottom_y + 25), "Arrows/AD = Navigate | W/S = Weather | ENTER = Confirm | R = Random | ESC = Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.4))

		# Selected arena info
		var sel_arena: Dictionary = arenas[screen._selected]
		var weather_name: String = GameMgr.WEATHER_NAMES[GameMgr.selected_weather]
		draw_string(font, Vector2(20, bottom_y + 50), "Hazard: %s" % sel_arena["hazard"].replace("_", " ").capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, WARN)
		# Weather indicator
		var weather_col: Color = ACCENT
		if GameMgr.selected_weather == 1:
			weather_col = Color("#6366F1")  # Night = indigo
		elif GameMgr.selected_weather == 2:
			weather_col = Color("#EF4444")  # Storm = red
		draw_string(font, Vector2(s.x - 300, bottom_y + 50), "Weather: %s" % weather_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, weather_col)
