class_name ArenaBlockout
extends Node3D
## Procedural low-poly arena blockout for art style testing.
## Creates the Azotea Monterrey arena with platforms, hazards, and backdrop.

const CITY_PALETTES := {
	"Monterrey": {
		"platform": Color("#EA580C"),
		"platform_dark": Color("#9A3412"),
		"accent": Color("#FCD34D"),
		"sky": Color("#FDE68A"),
		"ground": Color("#78350F"),
		"infrastructure": Color("#6B7280"),
	},
	"CDMX": {
		"platform": Color("#6B7280"),
		"platform_dark": Color("#374151"),
		"accent": Color("#3B82F6"),
		"sky": Color("#9CA3AF"),
		"ground": Color("#1F2937"),
		"infrastructure": Color("#4B5563"),
	},
	"Rio": {
		"platform": Color("#16A34A"),
		"platform_dark": Color("#166534"),
		"accent": Color("#FBBF24"),
		"sky": Color("#86EFAC"),
		"ground": Color("#064E3B"),
		"infrastructure": Color("#15803D"),
	},
	"Dallas": {
		"platform": Color("#1F2937"),
		"platform_dark": Color("#111827"),
		"accent": Color("#06B6D4"),
		"sky": Color("#0F172A"),
		"ground": Color("#030712"),
		"infrastructure": Color("#374151"),
	},
	"Bogota": {
		"platform": Color("#15803D"),
		"platform_dark": Color("#064E3B"),
		"accent": Color("#A3E635"),
		"sky": Color("#86EFAC"),
		"ground": Color("#052E16"),
		"infrastructure": Color("#166534"),
	},
	"Buenos Aires": {
		"platform": Color("#78716C"),
		"platform_dark": Color("#57534E"),
		"accent": Color("#FBBF24"),
		"sky": Color("#D6D3D1"),
		"ground": Color("#44403C"),
		"infrastructure": Color("#A8A29E"),
	},
	"Miami": {
		"platform": Color("#EC4899"),
		"platform_dark": Color("#BE185D"),
		"accent": Color("#06B6D4"),
		"sky": Color("#FDE68A"),
		"ground": Color("#F97316"),
		"infrastructure": Color("#F472B6"),
	},
	"WISPA": {
		"platform": Color("#1E3A5F"),
		"platform_dark": Color("#0F1D32"),
		"accent": Color("#F59E0B"),
		"sky": Color("#1E3A5F"),
		"ground": Color("#0F172A"),
		"infrastructure": Color("#FFFFFF"),
	},
}

var current_city: String = "Monterrey"
var _rotating_antenna: MeshInstance3D
var _city_label: Label3D
var _environment: WorldEnvironment
var _sun: DirectionalLight3D

func _ready() -> void:
	_build_arena()

func set_city(city: String) -> void:
	if city in CITY_PALETTES:
		current_city = city
		for child in get_children():
			child.queue_free()
		await get_tree().process_frame
		_build_arena()

func _build_arena() -> void:
	var palette: Dictionary = CITY_PALETTES[current_city]

	# World environment
	_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = palette["sky"]
	env.ambient_light_color = palette["accent"]
	env.ambient_light_energy = 0.3
	_environment.environment = env
	add_child(_environment)

	# Sun / directional light
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-35, -45, 0)
	_sun.light_color = Color.WHITE.lerp(palette["accent"], 0.3)
	_sun.light_energy = 1.2
	_sun.shadow_enabled = true
	add_child(_sun)

	# Main platform
	var main_platform := ProceduralMesh.create_platform(12.0, 8.0, 0.5, palette["platform"])
	main_platform.position.y = -0.25
	add_child(main_platform)

	# Platform edge trim
	var trim := ProceduralMesh.create_platform(12.2, 8.2, 0.1, palette["platform_dark"])
	trim.position.y = -0.55
	add_child(trim)

	# Left elevated platform
	var plat_left := ProceduralMesh.create_platform(3.0, 3.0, 0.4, palette["platform_dark"])
	plat_left.position = Vector3(-5.5, 1.5, 0.0)
	add_child(plat_left)

	# Right elevated platform
	var plat_right := ProceduralMesh.create_platform(3.0, 3.0, 0.4, palette["platform_dark"])
	plat_right.position = Vector3(5.5, 2.5, 0.0)
	add_child(plat_right)

	# Center top platform
	var plat_center := ProceduralMesh.create_platform(4.0, 2.5, 0.3, palette["accent"])
	plat_center.position = Vector3(0.0, 3.5, 0.0)
	add_child(plat_center)

	# Tower 1 (left back)
	_build_tower(Vector3(-4.0, 0.0, -3.5), 5.0, palette["infrastructure"], palette["accent"])

	# Tower 2 (right back)
	_build_tower(Vector3(4.0, 0.0, -3.5), 4.0, palette["infrastructure"], palette["accent"])

	# Rotating sector antenna (hazard)
	var hazard_base := ProceduralMesh.create_cylinder(0.15, 1.5, 6, palette["infrastructure"])
	hazard_base.position = Vector3(0.0, 0.75, -2.0)
	add_child(hazard_base)

	_rotating_antenna = ProceduralMesh.create_cone(0.4, 1.0, 6, palette["accent"])
	_rotating_antenna.position = Vector3(0.0, 1.8, -2.0)
	_rotating_antenna.rotation_degrees.z = 90.0
	add_child(_rotating_antenna)

	# Background mountains (Cerro de la Silla for Monterrey)
	_build_mountains(palette)

	# Cable runs (thin cylinders connecting towers)
	var cable := ProceduralMesh.create_cylinder(0.02, 8.5, 4, Color.BLACK)
	cable.position = Vector3(0.0, 4.0, -3.5)
	cable.rotation_degrees.z = 90.0
	add_child(cable)

	# Ground plane (extends far)
	var ground := ProceduralMesh.create_platform(60.0, 60.0, 0.1, palette["ground"])
	ground.position.y = -2.0
	add_child(ground)

	# City label
	_city_label = Label3D.new()
	_city_label.text = current_city.to_upper()
	_city_label.font_size = 72
	_city_label.position = Vector3(0.0, 5.5, -5.0)
	_city_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_city_label.modulate = palette["accent"]
	_city_label.outline_size = 6
	_city_label.outline_modulate = Color.BLACK
	add_child(_city_label)

func _build_tower(pos: Vector3, height: float, color: Color, accent: Color) -> void:
	# Tower pole
	var pole := ProceduralMesh.create_cylinder(0.08, height, 6, color)
	pole.position = pos + Vector3(0, height / 2.0, 0)
	add_child(pole)

	# Cross bars
	for i in range(3):
		var bar := ProceduralMesh.create_cylinder(0.03, 1.2, 4, color)
		bar.position = pos + Vector3(0, height * 0.3 * (i + 1), 0)
		bar.rotation_degrees.z = 90.0
		add_child(bar)

	# Antenna on top
	var antenna := ProceduralMesh.create_cone(0.2, 0.5, 6, accent)
	antenna.position = pos + Vector3(0, height + 0.25, 0)
	add_child(antenna)

func _build_mountains(palette: Dictionary) -> void:
	# Simplified mountain silhouette using triangular prisms
	var mountain_color: Color = palette["ground"].lightened(0.2)

	# Main peak (Cerro de la Silla shape for Monterrey)
	var peak1 := ProceduralMesh.create_cone(4.0, 8.0, 4, mountain_color)
	peak1.position = Vector3(-8.0, 0.0, -25.0)
	add_child(peak1)

	var peak2 := ProceduralMesh.create_cone(3.5, 10.0, 4, mountain_color.darkened(0.1))
	peak2.position = Vector3(-4.0, 0.0, -28.0)
	add_child(peak2)

	var peak3 := ProceduralMesh.create_cone(5.0, 7.0, 4, mountain_color.darkened(0.2))
	peak3.position = Vector3(3.0, 0.0, -22.0)
	add_child(peak3)

	var peak4 := ProceduralMesh.create_cone(3.0, 6.0, 4, mountain_color)
	peak4.position = Vector3(10.0, 0.0, -26.0)
	add_child(peak4)

func _process(delta: float) -> void:
	# Rotate the sector antenna hazard
	if _rotating_antenna:
		_rotating_antenna.rotation_degrees.y += 45.0 * delta
