class_name Gfx
extends RefCounted
## Ayudas para construir geometría provisional desde código.

## En modo headless (pruebas) el renderizador «dummy» no admite mallas: se omiten.
static var headless: bool = DisplayServer.get_name() == "headless"


static func mat(c: Color, rough: float = 0.9, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func box_mesh(size: Vector3, c: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	if not headless:
		mi.mesh = bm
	mi.material_override = mat(c, 0.9, emit)
	return mi


static func capsule_mesh(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	if not headless:
		mi.mesh = cm
	mi.material_override = mat(c)
	return mi


static func sphere_mesh(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	if not headless:
		mi.mesh = sm
	mi.material_override = mat(c)
	return mi


static func cyl_mesh(r: float, h: float, c: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	if not headless:
		mi.mesh = cm
	mi.material_override = mat(c, 0.5, emit)
	return mi


static func solid_box(parent: Node, pos: Vector3, size: Vector3, c: Color) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.add_child(box_mesh(size, c))
	parent.add_child(b)
	return b


static func glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func disc(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	if not headless:
		mi.mesh = cm
	mi.material_override = glow_mat(c)
	return mi


## Caja unitaria que se estira entre dos puntos (rayos de luz, rieles).
static func beam(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	if not headless:
		mi.mesh = bm
	mi.material_override = glow_mat(c)
	return mi


static func place_beam(n: Node3D, a: Vector3, b: Vector3, thick: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var z := d / l
	var ref := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x)
	n.transform = Transform3D(Basis(x * thick, y * thick, z * l), (a + b) * 0.5)


static func prop_box(parent: Node, pos: Vector3, size: Vector3, c: Color) -> StaticBody3D:
	var b := solid_box(parent, pos, size, c)
	b.collision_layer = 2
	return b
