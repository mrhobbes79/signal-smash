class_name GameManager
extends Node
## Game manager for SIGNAL SMASH.
## Handles game state, selected characters, and global configuration.

enum GameState { MENU, CHARACTER_SELECT, FIGHTING, MINI_GAME, VICTORY, SPECTATOR }

const CHARACTER_DATA := [
	{
		"name": "RICO",
		"color": Color("#2563EB"),
		"secondary": Color("#1E40AF"),
		"accent": Color("#FCD34D"),
	},
	{
		"name": "ING. VERO",
		"color": Color("#7C3AED"),
		"secondary": Color("#4C1D95"),
		"accent": Color("#06B6D4"),
	},
	{
		"name": "DON AURELIO",
		"color": Color("#92400E"),
		"secondary": Color("#5C2D0E"),
		"accent": Color("#D97706"),
	},
	{
		"name": "MORXEL",
		"color": Color("#059669"),
		"secondary": Color("#064E3B"),
		"accent": Color("#10B981"),
	},
]

# Custom Company Crew
var custom_crew_name: String = ""
var custom_crew_color: Color = Color.WHITE
var custom_crew_emblem: int = 0
const CREW_COLORS := [Color("#EF4444"), Color("#F59E0B"), Color("#22C55E"), Color("#3B82F6"), Color("#8B5CF6"), Color("#EC4899"), Color("#06B6D4"), Color("#84CC16"), Color("#F97316"), Color("#6366F1"), Color("#14B8A6"), Color("#E11D48")]
const CREW_EMBLEMS := ["circle", "square", "triangle", "star", "antenna", "signal", "router", "tower"]

var current_state: GameState = GameState.MENU
var player_count: int = 0

# Selected character indices (set by character_select, read by fight_test)
var p1_char_index: int = 0
var p2_char_index: int = 1

# Equipped items per player (set by loadout_screen, read by fight_test)
# Keys: "radio", "antenna", "router" — values: Equipment resource or null
var p1_equipment: Dictionary = { "radio": null, "antenna": null, "router": null }
var p2_equipment: Dictionary = { "radio": null, "antenna": null, "router": null }

# Selected arena
var selected_arena: int = 0

# Weather variant: 0=Normal, 1=Night, 2=Storm
var selected_weather: int = 0
const WEATHER_NAMES := ["Normal", "Night", "Storm"]

const ARENA_DATA := [
	{
		"name": "Azotea Monterrey",
		"city": "Monterrey",
		"color": Color("#EA580C"),
		"accent": Color("#FCD34D"),
		"sky_top": Color("#FF8C42"),
		"sky_bot": Color("#C04000"),
		"hazard": "rotating_antenna",
		"music": "monterrey",
	},
	{
		"name": "Torre CDMX",
		"city": "CDMX",
		"color": Color("#64748B"),
		"accent": Color("#3B82F6"),
		"sky_top": Color("#94A3B8"),
		"sky_bot": Color("#CBD5E1"),
		"hazard": "swinging_cables",
		"music": "cdmx",
	},
	{
		"name": "Favela Rio",
		"city": "Rio de Janeiro",
		"color": Color("#16A34A"),
		"accent": Color("#FDE047"),
		"sky_top": Color("#38BDF8"),
		"sky_bot": Color("#86EFAC"),
		"hazard": "rain_fade",
		"music": "rio",
	},
	{
		"name": "Data Center Dallas",
		"city": "Dallas",
		"color": Color("#1E293B"),
		"accent": Color("#06B6D4"),
		"sky_top": Color("#0F172A"),
		"sky_bot": Color("#1E293B"),
		"hazard": "cooling_vents",
		"music": "dallas",
	},
	{
		"name": "Selva Bogotá",
		"city": "Bogotá",
		"color": Color("#166534"),
		"accent": Color("#A3E635"),
		"sky_top": Color("#6B7280"),
		"sky_bot": Color("#D1FAE5"),
		"hazard": "foliage_block",
		"music": "bogota",
	},
	{
		"name": "Pampa Buenos Aires",
		"city": "Buenos Aires",
		"color": Color("#78716C"),
		"accent": Color("#F59E0B"),
		"sky_top": Color("#9CA3AF"),
		"sky_bot": Color("#FDE68A"),
		"hazard": "lightning",
		"music": "buenos_aires",
	},
	{
		"name": "Beach Miami",
		"city": "Miami",
		"color": Color("#F472B6"),
		"accent": Color("#FB923C"),
		"sky_top": Color("#F97316"),
		"sky_bot": Color("#EC4899"),
		"hazard": "interference_zones",
		"music": "miami",
	},
	{
		"name": "WISPA Convention",
		"city": "WISPA",
		"color": Color("#1D4ED8"),
		"accent": Color("#FFFFFF"),
		"sky_top": Color("#1E3A8A"),
		"sky_bot": Color("#3B82F6"),
		"hazard": "crowd_projectiles",
		"music": "wispa",
	},
	{
		"name": "WISPA 2026",
		"city": "WISPA Dallas",
		"color": Color("#7C3AED"),
		"accent": Color("#FBBF24"),
		"sky_top": Color("#4C1D95"),
		"sky_bot": Color("#7C3AED"),
		"hazard": "rotating_antenna",
		"music": "wispa",
	},
	{
		"name": "WISPMX Monterrey",
		"city": "WISPMX",
		"color": Color("#DC2626"),
		"accent": Color("#16A34A"),
		"sky_top": Color("#991B1B"),
		"sky_bot": Color("#DC2626"),
		"hazard": "rotating_antenna",
		"music": "monterrey",
	},
]

func get_arena() -> Dictionary:
	return ARENA_DATA[selected_arena]

func get_char_data(index: int) -> Dictionary:
	return CHARACTER_DATA[index]

func get_p1() -> Dictionary:
	return CHARACTER_DATA[p1_char_index]

func get_p2() -> Dictionary:
	return CHARACTER_DATA[p2_char_index]

## Get total equipment stat modifiers for a player's loadout
func get_equipment_modifiers(equipment: Dictionary) -> Dictionary:
	var mods := { "range": 0, "speed": 0, "stability": 0, "power": 0 }
	for slot in equipment:
		var item = equipment[slot]
		if item != null:
			mods["range"] += item.stat_range
			mods["speed"] += item.stat_speed
			mods["stability"] += item.stat_stability
			mods["power"] += item.stat_power
	return mods

## Get all special passives from equipment
func get_equipment_specials(equipment: Dictionary) -> Array[String]:
	var specials: Array[String] = []
	for slot in equipment:
		var item = equipment[slot]
		if item != null and item.special_passive != "":
			specials.append(item.special_passive)
	return specials

func _ready() -> void:
	print("SIGNAL SMASH — Game Manager initialized")
