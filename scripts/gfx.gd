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


# ---------------------------------------------------------------- materiales procedurales

static var _mats: Dictionary = {}


static func _noise_tex(seed_v: int, freq: float, c0: Color, c1: Color, normal: bool = false, size: int = 256) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = size
	t.height = size
	t.seamless = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	else:
		var g := Gradient.new()
		g.set_color(0, c0)
		g.set_color(1, c1)
		t.color_ramp = g
	return t


## Material con ruido triplanar (sirve para cajas de cualquier tamaño sin UV).
static func _tri(key: String, seed_v: int, c0: Color, c1: Color, rough: float, metal: float, freq: float, scale_f: float) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale_f
	m.albedo_color = Color.WHITE
	if headless:
		m.albedo_color = c0.lerp(c1, 0.5)
	else:
		m.albedo_texture = _noise_tex(seed_v, freq, c0, c1)
		m.normal_enabled = true
		m.normal_texture = _noise_tex(seed_v + 11, freq * 1.6, c0, c1, true)
		m.normal_scale = 0.8
	_mats[key] = m
	return m


## Material PBR real (Poly Haven, CC0): color + normal GL + ARM (AO, rugosidad, metal) en triplanar.
static func _pbr(key: String, folder: String, base: String, res: String, scale_f: float, metal: float) -> BaseMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var root := "res://assets/texturas/%s/%s_" % [folder, base]
	var diff := root + "diff_" + res + ".jpg"
	if not ResourceLoader.exists(diff):
		return null
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(diff)
	m.normal_enabled = true
	m.normal_texture = load(root + "nor_gl_" + res + ".jpg")
	m.normal_scale = 1.0
	m.orm_texture = load(root + "arm_" + res + ".jpg")
	m.ao_enabled = true
	m.ao_light_affect = 0.7
	m.roughness = 1.0
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale_f
	_mats[key] = m
	return m


static func mat_rust() -> BaseMaterial3D:
	var m := _pbr("rust", "rusty_metal_sheet", "rusty_metal_sheet", "1k", 0.5, 0.2)
	return m if m else _tri("rust", 3, Color(0.12, 0.07, 0.05), Color(0.5, 0.27, 0.12), 0.55, 0.6, 0.012, 0.35)


static func mat_stone() -> BaseMaterial3D:
	var m := _pbr("stone", "rock_wall_08", "rock_wall_08", "2k", 0.3, 0.0)
	return m if m else _tri("stone", 5, Color(0.1, 0.13, 0.15), Color(0.34, 0.4, 0.42), 0.35, 0.0, 0.01, 0.3)


static func mat_floor() -> BaseMaterial3D:
	var m := _pbr("floor", "stone_tiles", "stone_tiles", "2k", 0.28, 0.0)
	return m if m else _tri("floor", 8, Color(0.05, 0.07, 0.09), Color(0.22, 0.27, 0.3), 0.22, 0.1, 0.008, 0.22)


static func mat_wood() -> BaseMaterial3D:
	var m := _pbr("wood", "weathered_planks", "weathered_planks", "1k", 0.6, 0.0)
	return m if m else _tri("wood", 12, Color(0.12, 0.07, 0.04), Color(0.38, 0.23, 0.12), 0.8, 0.0, 0.03, 0.5)


static func mat_plaster() -> BaseMaterial3D:
	var m := _pbr("plaster", "rough_plaster_broken", "rough_plaster_broken", "1k", 0.4, 0.0)
	return m if m else _tri("plaster", 14, Color(0.3, 0.3, 0.27), Color(0.58, 0.56, 0.5), 0.9, 0.0, 0.02, 0.3)


static func mat_plate() -> BaseMaterial3D:
	var m := _pbr("plate", "metal_plate", "metal_plate", "1k", 0.8, 0.12)
	return m if m else mat_rust()


static func mat_cobble() -> BaseMaterial3D:
	var m := _pbr("cobble", "cobblestone_floor_001", "cobblestone_floor_001", "1k", 0.5, 0.0)
	return m if m else mat_floor()


static func mat_rock() -> BaseMaterial3D:
	var m := _pbr("rock", "rock_3", "rock_3", "1k", 0.4, 0.0)
	return m if m else mat_stone()


static func mat_cloth(c: Color) -> StandardMaterial3D:
	var key := "cloth%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	_mats[key] = m
	return m


static func mat_gloss(c: Color, rough: float = 0.06) -> StandardMaterial3D:
	var key := "gloss%s%f" % [c.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.3
	_mats[key] = m
	return m


static func mat_glow(c: Color, energy: float) -> StandardMaterial3D:
	var key := "glow%s%f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


static func box_m(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	if not headless:
		mi.mesh = bm
	mi.material_override = m
	return mi


static func cyl_m(r: float, h: float, m: Material, r_bottom: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r_bottom < 0.0 else r_bottom
	cm.height = h
	cm.radial_segments = 12
	if not headless:
		mi.mesh = cm
	mi.material_override = m
	return mi


static func capsule_m(r: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 4
	if not headless:
		mi.mesh = cm
	mi.material_override = m
	return mi


static func sphere_m(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	if not headless:
		mi.mesh = sm
	mi.material_override = m
	return mi


static func solid_m(parent: Node, pos: Vector3, size: Vector3, m: Material, layer: int = 1) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_layer = layer
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.add_child(box_m(size, m))
	parent.add_child(b)
	return b


static func no_shadow(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func torus_m(inner: float, outer: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 16
	tm.ring_segments = 8
	if not headless:
		mi.mesh = tm
	mi.material_override = m
	return mi
