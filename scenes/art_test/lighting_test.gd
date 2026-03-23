class_name LightingTest
extends Node3D
## Lighting presets for testing different city moods.
## Toggle between presets with L key.

enum Preset { MONTERREY_SUNSET, RIO_STORM, DALLAS_NIGHT, MIAMI_BEACH }

const PRESET_NAMES := {
	Preset.MONTERREY_SUNSET: "Monterrey Sunset",
	Preset.RIO_STORM: "Rio Storm",
	Preset.DALLAS_NIGHT: "Dallas Night",
	Preset.MIAMI_BEACH: "Miami Beach",
}

const PRESET_DATA := {
	Preset.MONTERREY_SUNSET: {
		"sun_color": Color("#FCD34D"),
		"sun_energy": 1.3,
		"sun_rotation": Vector3(-25, -50, 0),
		"ambient_color": Color("#EA580C"),
		"ambient_energy": 0.4,
		"bg_color": Color("#FDE68A"),
	},
	Preset.RIO_STORM: {
		"sun_color": Color("#94A3B8"),
		"sun_energy": 0.5,
		"sun_rotation": Vector3(-60, -30, 0),
		"ambient_color": Color("#475569"),
		"ambient_energy": 0.6,
		"bg_color": Color("#334155"),
	},
	Preset.DALLAS_NIGHT: {
		"sun_color": Color("#06B6D4"),
		"sun_energy": 0.3,
		"sun_rotation": Vector3(-70, -20, 0),
		"ambient_color": Color("#1E3A5F"),
		"ambient_energy": 0.2,
		"bg_color": Color("#0F172A"),
	},
	Preset.MIAMI_BEACH: {
		"sun_color": Color("#FFFFFF"),
		"sun_energy": 1.8,
		"sun_rotation": Vector3(-40, -60, 0),
		"ambient_color": Color("#F97316"),
		"ambient_energy": 0.5,
		"bg_color": Color("#FEF3C7"),
	},
}

var current_preset: Preset = Preset.MONTERREY_SUNSET
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment

signal preset_changed(preset_name: String)

func setup(sun: DirectionalLight3D, world_env: WorldEnvironment) -> void:
	_sun = sun
	_world_env = world_env
	apply_preset(current_preset)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		cycle_preset()

func cycle_preset() -> void:
	current_preset = ((current_preset as int) + 1) % Preset.size() as Preset
	apply_preset(current_preset)
	preset_changed.emit(PRESET_NAMES[current_preset])

func apply_preset(preset: Preset) -> void:
	var data: Dictionary = PRESET_DATA[preset]

	if _sun:
		_sun.light_color = data["sun_color"]
		_sun.light_energy = data["sun_energy"]
		_sun.rotation_degrees = data["sun_rotation"]

	if _world_env and _world_env.environment:
		_world_env.environment.ambient_light_color = data["ambient_color"]
		_world_env.environment.ambient_light_energy = data["ambient_energy"]
		_world_env.environment.background_color = data["bg_color"]

func get_current_name() -> String:
	return PRESET_NAMES[current_preset]
