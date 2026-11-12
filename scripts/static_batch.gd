class_name StaticBatch
extends RefCounted
## Agrupa solo la geometría fija del escenario. Cada zona de 8 m tiene
## un MeshInstance3D por configuración de render y una superficie por material/formato.

const ZONE_SIZE := 8.0
const CPU_MESH := &"static_batch_cpu_mesh"

const ATTRIBUTES := [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]


class Surface:
	var material: Material
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()

	func append(arrays: Array, xf: Transform3D) -> void:
		var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var start := vertices.size()
		for vertex in src:
			vertices.append(xf * vertex)
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normal_basis := xf.basis.inverse().transposed()
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				normals.append((normal_basis * normal).normalized())
		var mirrored := xf.basis.determinant() < 0.0
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var values: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i in range(0, values.size(), 4):
				var tangent := (xf.basis * Vector3(values[i], values[i + 1], values[i + 2])).normalized()
				tangents.append_array([tangent.x, tangent.y, tangent.z, -values[i + 3] if mirrored else values[i + 3]])
		if arrays[Mesh.ARRAY_COLOR] != null:
			colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uv.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if arrays[Mesh.ARRAY_TEX_UV2] != null:
			uv2.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if src_indices.is_empty():
			src_indices.resize(src.size())
			for i in src.size():
				src_indices[i] = i
		for i in range(0, src_indices.size(), 3):
			indices.append(start + src_indices[i])
			indices.append(start + src_indices[i + (2 if mirrored else 1)])
			indices.append(start + src_indices[i + (1 if mirrored else 2)])

	func commit_to(target: ArrayMesh) -> void:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		if not tangents.is_empty():
			arrays[Mesh.ARRAY_TANGENT] = tangents
		if not colors.is_empty():
			arrays[Mesh.ARRAY_COLOR] = colors
		if not uv.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = uv
		if not uv2.is_empty():
			arrays[Mesh.ARRAY_TEX_UV2] = uv2
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		target.surface_set_material(target.get_surface_count() - 1, material)


class Zone:
	var origin: Vector3
	var sources: Array[MeshInstance3D] = []
	var surfaces: Dictionary = {}


static func mesh_of(instance: MeshInstance3D) -> Mesh:
	if instance.mesh != null:
		return instance.mesh
	return instance.get_meta(CPU_MESH) as Mesh if instance.has_meta(CPU_MESH) else null


static func count_meshes(node: Node) -> int:
	if node.is_queued_for_deletion():
		return 0
	var count := int(node is MeshInstance3D)
	for child in node.get_children():
		count += count_meshes(child)
	return count


static func build(world: Node3D, moving: Array[Node3D]) -> Vector2i:
	var before := count_meshes(world)
	var zones: Dictionary = {}
	var to_world := world.global_transform.affine_inverse()
	for child in world.get_children():
		_collect(child, moving, to_world, zones)
	for zone: Zone in zones.values():
		if zone.sources.size() < 2:
			continue
		var mesh := ArrayMesh.new()
		for surface: Surface in zone.surfaces.values():
			surface.commit_to(mesh)
		var first := zone.sources[0]
		var batch := MeshInstance3D.new()
		batch.name = "MallasEstaticas"
		batch.position = zone.origin
		batch.cast_shadow = first.cast_shadow
		batch.layers = first.layers
		batch.gi_mode = first.gi_mode
		if DisplayServer.get_name() == "headless":
			batch.set_meta(CPU_MESH, mesh)
		else:
			batch.mesh = mesh
		world.add_child(batch, true)
		for source in zone.sources:
			source.free()
	return Vector2i(before, count_meshes(world))


static func _collect(node: Node, moving: Array[Node3D], to_world: Transform3D, zones: Dictionary) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Node3D and (not node.visible or node in moving):
		return
	# player.gd cambia el material de los hijos del cuerpo que tapa la cámara.
	if node is StaticBody3D and (node.collision_layer & 1) != 0 and node.global_position.y > 0.5:
		return
	if node is MeshInstance3D and node.get_child_count() == 0:
		_add_instance(node, to_world, zones)
		return
	for child in node.get_children():
		_collect(child, moving, to_world, zones)


static func _add_instance(instance: MeshInstance3D, to_world: Transform3D, zones: Dictionary) -> void:
	var mesh := mesh_of(instance)
	if mesh == null or instance.material_overlay != null or instance.transparency > 0.0:
		return
	if mesh is ArrayMesh and mesh.get_blend_shape_count() > 0:
		return
	var xf := to_world * instance.global_transform
	if is_zero_approx(xf.basis.determinant()):
		return
	var parts: Array[Array] = []
	var materials: Array[BaseMaterial3D] = []
	for i in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			return
		var material := instance.material_override as BaseMaterial3D
		if instance.material_override == null:
			material = instance.get_surface_override_material(i) as BaseMaterial3D if instance.mesh != null else null
			if material == null:
				material = mesh.surface_get_material(i) as BaseMaterial3D
		if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return
		if material.uv1_triplanar and not material.uv1_world_triplanar:
			return
		var arrays := mesh.surface_get_arrays(i)
		if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null:
			return
		for slot in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_INDEX):
			if arrays[slot] != null:
				return
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
		if count == 0 or count % 3 != 0:
			return
		parts.append(arrays)
		materials.append(material)
	if parts.is_empty():
		return
	var cell := Vector2i(floori(xf.origin.x / ZONE_SIZE + 0.5), floori(xf.origin.z / ZONE_SIZE + 0.5))
	var key := "%d/%d/%d/%d/%d" % [cell.x, cell.y, instance.cast_shadow, instance.layers, instance.gi_mode]
	var zone := zones.get(key) as Zone
	if zone == null:
		zone = Zone.new()
		zone.origin = Vector3((cell.x - 0.5) * ZONE_SIZE, 0.0, (cell.y - 0.5) * ZONE_SIZE)
		zones[key] = zone
	zone.sources.append(instance)
	xf.origin -= zone.origin
	for i in parts.size():
		var arrays := parts[i]
		var format := 0
		for slot: int in ATTRIBUTES:
			if arrays[slot] != null:
				format |= 1 << slot
		var material := materials[i]
		var surface_key := "%d/%d" % [material.get_instance_id(), format]
		var surface := zone.surfaces.get(surface_key) as Surface
		if surface == null:
			surface = Surface.new()
			surface.material = material
			zone.surfaces[surface_key] = surface
		surface.append(arrays, xf)
