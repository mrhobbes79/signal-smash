class_name ProceduralMesh
extends RefCounted
## Utility class for creating low-poly 3D meshes procedurally.
## All meshes use flat shading for the low-poly aesthetic.

static func create_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

static func create_cylinder(radius: float, height: float, segments: int, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

static func create_cone(radius: float, height: float, segments: int, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.01
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

static func create_sphere(radius: float, segments: int, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

static func create_capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 2
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

static func create_platform(width: float, depth: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_material(color)
	return mesh_instance

static func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if color.v > 0.9 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Flat shading for low-poly look
	mat.detail_enabled = false
	return mat
