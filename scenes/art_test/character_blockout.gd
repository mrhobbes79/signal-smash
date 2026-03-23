class_name CharacterBlockout
extends Node3D
## Procedural low-poly character blockout for art style testing.
## Creates a character from geometric primitives with character-specific colors.

const CHARACTER_DATA := {
	"Rico": {
		"primary": Color("#2563EB"),
		"secondary": Color("#1E40AF"),
		"accent": Color("#FCD34D"),
		"skin": Color("#D4A574"),
		"role": "Cable Specialist",
	},
	"Vero": {
		"primary": Color("#7C3AED"),
		"secondary": Color("#4C1D95"),
		"accent": Color("#06B6D4"),
		"skin": Color("#C4956A"),
		"role": "Spectrum Engineer",
	},
	"Aurelio": {
		"primary": Color("#92400E"),
		"secondary": Color("#78350F"),
		"accent": Color("#D97706"),
		"skin": Color("#B8865A"),
		"role": "Old School Veteran",
		"locked": true,
	},
	"MorXel": {
		"primary": Color("#059669"),
		"secondary": Color("#064E3B"),
		"accent": Color("#10B981"),
		"skin": Color("#A0D4A0"),
		"role": "Reality Hacker",
		"locked": true,
	},
}

var character_name: String = "Rico"
var _time: float = 0.0
var _body_node: Node3D
var _arm_left: MeshInstance3D
var _arm_right: MeshInstance3D
var _is_attacking: bool = false
var _attack_time: float = 0.0

func _ready() -> void:
	_build_character()

func set_character(name: String) -> void:
	character_name = name
	# Clear existing
	for child in get_children():
		child.queue_free()
	# Rebuild
	await get_tree().process_frame
	_build_character()

func _build_character() -> void:
	var data: Dictionary = CHARACTER_DATA.get(character_name, CHARACTER_DATA["Rico"])
	var primary: Color = data["primary"]
	var secondary: Color = data["secondary"]
	var accent: Color = data["accent"]
	var skin: Color = data["skin"]

	_body_node = Node3D.new()
	add_child(_body_node)

	# Body (capsule)
	var body := ProceduralMesh.create_capsule(0.35, 1.0, primary)
	body.position.y = 1.0
	_body_node.add_child(body)

	# Head (sphere)
	var head := ProceduralMesh.create_sphere(0.25, 8, skin)
	head.position.y = 1.8
	_body_node.add_child(head)

	# Eyes (small spheres)
	var eye_left := ProceduralMesh.create_sphere(0.05, 6, Color.WHITE)
	eye_left.position = Vector3(-0.1, 1.85, 0.2)
	_body_node.add_child(eye_left)

	var pupil_left := ProceduralMesh.create_sphere(0.03, 6, Color.BLACK)
	pupil_left.position = Vector3(-0.1, 1.85, 0.24)
	_body_node.add_child(pupil_left)

	var eye_right := ProceduralMesh.create_sphere(0.05, 6, Color.WHITE)
	eye_right.position = Vector3(0.1, 1.85, 0.2)
	_body_node.add_child(eye_right)

	var pupil_right := ProceduralMesh.create_sphere(0.03, 6, Color.BLACK)
	pupil_right.position = Vector3(0.1, 1.85, 0.24)
	_body_node.add_child(pupil_right)

	# Arms (cylinders)
	_arm_left = ProceduralMesh.create_cylinder(0.1, 0.6, 6, secondary)
	_arm_left.position = Vector3(-0.5, 1.0, 0.0)
	_arm_left.rotation_degrees.z = 15.0
	_body_node.add_child(_arm_left)

	_arm_right = ProceduralMesh.create_cylinder(0.1, 0.6, 6, secondary)
	_arm_right.position = Vector3(0.5, 1.0, 0.0)
	_arm_right.rotation_degrees.z = -15.0
	_body_node.add_child(_arm_right)

	# Legs (cylinders)
	var leg_left := ProceduralMesh.create_cylinder(0.12, 0.7, 6, secondary)
	leg_left.position = Vector3(-0.18, 0.35, 0.0)
	_body_node.add_child(leg_left)

	var leg_right := ProceduralMesh.create_cylinder(0.12, 0.7, 6, secondary)
	leg_right.position = Vector3(0.18, 0.35, 0.0)
	_body_node.add_child(leg_right)

	# Equipment on back (small box — antenna/radio placeholder)
	var equipment := ProceduralMesh.create_box(Vector3(0.25, 0.3, 0.15), accent)
	equipment.position = Vector3(0.0, 1.2, -0.3)
	_body_node.add_child(equipment)

	# Small antenna on equipment
	var antenna := ProceduralMesh.create_cylinder(0.02, 0.4, 4, accent)
	antenna.position = Vector3(0.0, 1.55, -0.3)
	_body_node.add_child(antenna)

	# Name label
	var label := Label3D.new()
	label.text = character_name
	label.font_size = 48
	label.position.y = 2.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = accent
	label.outline_size = 4
	label.outline_modulate = Color.BLACK
	_body_node.add_child(label)

	# Role label (smaller, below name)
	var role_label := Label3D.new()
	role_label.text = data["role"]
	role_label.font_size = 24
	role_label.position.y = 2.05
	role_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	role_label.modulate = Color.WHITE
	role_label.outline_size = 3
	role_label.outline_modulate = Color.BLACK
	_body_node.add_child(role_label)

	# Locked overlay
	if data.get("locked", false):
		var lock_label := Label3D.new()
		lock_label.text = "COMING SOON"
		lock_label.font_size = 32
		lock_label.position.y = 2.55
		lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lock_label.modulate = Color("#EF4444")
		lock_label.outline_size = 4
		lock_label.outline_modulate = Color.BLACK
		_body_node.add_child(lock_label)

func _process(delta: float) -> void:
	_time += delta

	if _body_node == null:
		return

	# Idle bobbing animation
	_body_node.position.y = sin(_time * 2.0) * 0.05

	# Attack animation
	if _is_attacking:
		_attack_time += delta
		if _arm_right:
			_arm_right.rotation_degrees.x = sin(_attack_time * 15.0) * 60.0
		if _attack_time > 0.5:
			_is_attacking = false
			_attack_time = 0.0
			if _arm_right:
				_arm_right.rotation_degrees.x = 0.0

func trigger_attack() -> void:
	_is_attacking = true
	_attack_time = 0.0
