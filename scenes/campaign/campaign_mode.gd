extends Control
## SIGNAL SMASH — Campaign Mode: Don Aurelio's Story
## 7-chapter solo campaign through the history of wireless technology.
## NOC Dashboard aesthetic with vertical timeline chapter select.

const BG := Color("#0F172A")
const ACCENT := Color("#06B6D4")
const WARN := Color("#F59E0B")
const TEXT := Color("#E2E8F0")
const COMPLETE_COLOR := Color("#22C55E")
const LOCKED_COLOR := Color("#475569")

var _selected_index: int = 0
var _time: float = 0.0
var _draw_node: Control

## Chapter definitions: [number, title, era, description]
const CHAPTERS: Array[Dictionary] = [
	{"num": 1, "title": "The First Signal", "era": "1900s", "desc": "Telegraph era. Tap to send Morse code signals across the wire."},
	{"num": 2, "title": "Radio Waves", "era": "1920s", "desc": "AM radio. Tune your frequency to find hidden stations."},
	{"num": 3, "title": "Tower Builder", "era": "1960s", "desc": "Microwave links. Build a tower chain to connect distant cities."},
	{"num": 4, "title": "The Wireless Revolution", "era": "1990s", "desc": "Early WiFi. Configure access points with the correct settings."},
	{"num": 5, "title": "Broadband Wars", "era": "2000s", "desc": "DSL vs Cable vs Wireless. Race to deploy the fastest network."},
	{"num": 6, "title": "The WISP Pioneer", "era": "2010s", "desc": "Build your own WISP. Install antennas and align dishes."},
	{"num": 7, "title": "5G and Beyond", "era": "2020s+", "desc": "Modern era. Fight El Regulador to keep WISPs alive."},
]

func _ready() -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_draw_node = _CampaignDraw.new()
	_draw_node.hub = self
	_draw_node.set_anchors_preset(PRESET_FULL_RECT)
	_draw_node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(delta: float) -> void:
	_time += delta
	_draw_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_selected_index = (_selected_index - 1 + CHAPTERS.size()) % CHAPTERS.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_DOWN, KEY_S:
				_selected_index = (_selected_index + 1) % CHAPTERS.size()
				if AudioManager:
					AudioManager.play_sfx("menu_move")
			KEY_ENTER, KEY_SPACE:
				if AudioManager:
					AudioManager.play_sfx("menu_select")
				_start_chapter()
			KEY_ESCAPE:
				if AudioManager:
					AudioManager.play_sfx("menu_move")
				get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _start_chapter() -> void:
	var chapter_num: int = _selected_index + 1
	# Store which chapter to play
	CampaignData.current_chapter = chapter_num
	if AudioManager:
		AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/campaign/campaign_chapter.tscn")

func is_chapter_complete(chapter_num: int) -> bool:
	if Progression:
		return chapter_num in Progression.campaign_chapters_complete
	return false


class _CampaignDraw extends Control:
	var hub: Node

	func _draw() -> void:
		if hub == null:
			return

		var s := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var t: float = hub._time

		# ═══════════ HEADER ═══════════
		var header_y: float = 50.0
		var pulse: float = (sin(t * 2.0) + 1.0) / 2.0

		# Top line
		draw_rect(Rect2(s.x * 0.1, header_y - 10, s.x * 0.8, 2), Color(ACCENT, 0.3 + pulse * 0.2))

		# Title
		draw_string(font, Vector2(s.x / 2.0 - 260, header_y + 30), "DON AURELIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, WARN)
		draw_string(font, Vector2(s.x / 2.0 + 60, header_y + 30), "CAMPAIGN", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, ACCENT)

		# Subtitle
		draw_string(font, Vector2(s.x / 2.0 - 180, header_y + 55), "A journey through the history of wireless", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TEXT, 0.5))

		# Bottom line
		draw_rect(Rect2(s.x * 0.1, header_y + 65, s.x * 0.8, 2), Color(ACCENT, 0.3 + pulse * 0.2))

		# ═══════════ TIMELINE ═══════════
		var timeline_x: float = s.x * 0.12
		var timeline_start_y: float = 140.0
		var item_h: float = (s.y - 220.0) / 7.0
		item_h = minf(item_h, 75.0)

		# Vertical timeline line
		draw_rect(Rect2(timeline_x + 15, timeline_start_y, 2, item_h * 7.0), Color(ACCENT, 0.2))

		for i in range(hub.CHAPTERS.size()):
			var ch: Dictionary = hub.CHAPTERS[i]
			var y: float = timeline_start_y + i * item_h
			var is_selected: bool = i == hub._selected_index
			var is_complete: bool = hub.is_chapter_complete(ch["num"])

			# Timeline node dot
			var dot_color: Color
			if is_complete:
				dot_color = COMPLETE_COLOR
			elif is_selected:
				dot_color = ACCENT
			else:
				dot_color = LOCKED_COLOR
			draw_circle(Vector2(timeline_x + 16, y + 20), 8.0, dot_color)
			if is_complete:
				draw_string(font, Vector2(timeline_x + 10, y + 26), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BG)

			# Chapter number
			var num_x: float = timeline_x + 35
			draw_string(font, Vector2(num_x, y + 18), "CH.%d" % ch["num"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.5))

			# Era tag
			draw_string(font, Vector2(num_x + 55, y + 18), "[%s]" % ch["era"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(WARN, 0.6))

			# Selection highlight
			var content_x: float = timeline_x + 35
			var content_w: float = s.x * 0.75
			if is_selected:
				var sel_pulse: float = (sin(t * 4.0) + 1.0) / 2.0
				draw_rect(Rect2(content_x - 5, y + 22, content_w, item_h - 28), Color(ACCENT, 0.05 + sel_pulse * 0.05))
				draw_rect(Rect2(content_x - 5, y + 22, content_w, item_h - 28), ACCENT, false, 1.5)

				# Title (large, selected)
				draw_string(font, Vector2(content_x, y + 42), ch["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ACCENT)

				# Description
				draw_string(font, Vector2(content_x, y + 60), ch["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.6))

				# Status
				if is_complete:
					draw_string(font, Vector2(content_x + content_w - 120, y + 42), "COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COMPLETE_COLOR)
				else:
					draw_string(font, Vector2(content_x + content_w - 120, y + 42), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(WARN, 0.8))

				# Arrow
				draw_string(font, Vector2(content_x - 20, y + 42), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)
			else:
				# Title (smaller, unselected)
				var title_color: Color = Color(TEXT, 0.5) if not is_complete else Color(COMPLETE_COLOR, 0.7)
				draw_string(font, Vector2(content_x, y + 42), ch["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, title_color)

		# ═══════════ COMPLETION SUMMARY ═══════════
		var completed_count: int = 0
		for i in range(hub.CHAPTERS.size()):
			if hub.is_chapter_complete(hub.CHAPTERS[i]["num"]):
				completed_count += 1

		var summary_y: float = s.y - 80.0
		draw_rect(Rect2(0, summary_y, s.x, 80), Color(BG, 0.9))
		draw_rect(Rect2(0, summary_y, s.x, 1), Color(ACCENT, 0.3))

		draw_string(font, Vector2(20, summary_y + 25), "Progress: %d / 7 chapters" % completed_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TEXT, 0.5))

		# Progress bar
		var bar_x: float = 250.0
		var bar_w: float = 200.0
		draw_rect(Rect2(bar_x, summary_y + 14, bar_w, 8), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(bar_x, summary_y + 14, bar_w * (completed_count / 7.0), 8), COMPLETE_COLOR)

		# Nav hints
		draw_string(font, Vector2(20, summary_y + 55), "↑↓ Navigate  |  ENTER Start Chapter  |  ESC Back to Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TEXT, 0.3))

		# ═══════════ DECORATIVE ═══════════
		# Scanning line
		var scan_y: float = fmod(t * 80.0, s.y)
		draw_rect(Rect2(0, scan_y, s.x, 1), Color(ACCENT, 0.04))

		# Corner brackets
		var bracket_size: float = 25.0
		var m: float = 10.0
		draw_line(Vector2(m, m), Vector2(m + bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m - bracket_size, m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m + bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - bracket_size, s.y - m), Color(ACCENT, 0.3), 2.0)
		draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - bracket_size), Color(ACCENT, 0.3), 2.0)
