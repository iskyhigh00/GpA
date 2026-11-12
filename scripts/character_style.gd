class_name CharacterStyle
extends RefCounted
## Rediseño de los modelos de Quaternius con paleta oscura y accesorios hechos por código.
## Ejes de hueso medidos: en Torso/Chest/Neck/Head +Y sube, +Z mira al frente y +X es la izquierda del personaje.


## Cambia el color de cada material por nombre («Green», «Skin»…) o por «Malla/Material».
## Valor: Color, o [Color, rugosidad, metalizado].
static func recolor(model: Node3D, map: Dictionary) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var spec: Variant = map.get("%s/%s" % [mi.name, mat.resource_name], map.get(mat.resource_name, null))
			if spec == null:
				continue
			var nm := mat.duplicate() as BaseMaterial3D
			if spec is Color:
				nm.albedo_color = spec as Color
				nm.roughness = 0.85
			else:
				var arr: Array = spec
				nm.albedo_color = arr[0] as Color
				nm.roughness = float(arr[1])
				nm.metallic = float(arr[2])
			if mat.resource_name != "Skin" and not Gfx.headless:
				nm.normal_enabled = true
				nm.normal_texture = Gfx.fabric_normal()
				nm.normal_scale = 0.7
				nm.uv1_triplanar = true
				nm.uv1_world_triplanar = false
				nm.uv1_scale = Vector3.ONE * 5.0
			nm.rim_enabled = true
			nm.rim = 0.45
			nm.rim_tint = 0.5
			mi.set_surface_override_material(i, nm)


static func _leather() -> StandardMaterial3D:
	return Gfx.mat_gloss(Color(0.09, 0.06, 0.045), 0.55)


static func _brass() -> StandardMaterial3D:
	return Gfx.mat_gloss(Color(0.55, 0.4, 0.17), 0.35)


static func style_sira(rig: ModelRig) -> void:
	recolor(rig.model, {
		"Green": Color(0.05, 0.11, 0.14),
		"LightGreen": Color(0.08, 0.15, 0.18),
		"White": Color(0.5, 0.49, 0.45),
		"Brown2": Color(0.09, 0.065, 0.05),
		"Brown_02": Color(0.07, 0.06, 0.055),
		"Brown": Color(0.05, 0.04, 0.035),
		"Gold": [Color(0.5, 0.37, 0.17), 0.45, 0.4],
		"Hair_Brown": Color(0.04, 0.035, 0.035),
		"Adventurer_Legs/Skin": Color(0.06, 0.07, 0.09),
		"Adventurer_Feet/Brown_02": Color(0.05, 0.045, 0.045),
		"Skin": Color(0.74, 0.63, 0.58),
	})
	var torso := rig._attach("Torso")
	var chest := rig.body
	# Abrigo largo de inspectora que cuelga del torso y se mueve al correr.
	var coat_mat := Gfx.mat_cloth(Color(0.05, 0.1, 0.13))
	var coat := Node3D.new()
	torso.add_child(coat)
	var skirt := Gfx.cyl_m(0.19, 0.7, coat_mat, 0.27)
	skirt.position = Vector3(0.0, -0.37, -0.02)
	skirt.scale = Vector3(1.0, 1.0, 0.8)
	coat.add_child(skirt)
	var hem := Gfx.cyl_m(0.275, 0.05, Gfx.mat_cloth(Color(0.09, 0.15, 0.17)), 0.28)
	hem.position = Vector3(0.0, -0.72, -0.02)
	hem.scale = Vector3(1.0, 1.0, 0.8)
	coat.add_child(hem)
	rig.coat = coat
	# Cuello alto y bufanda.
	var collar := Gfx.cyl_m(0.12, 0.13, coat_mat, 0.17)
	collar.position = Vector3(0.0, 0.18, 0.0)
	chest.add_child(collar)
	var scarf := Gfx.torus_m(0.04, 0.14, Gfx.mat_cloth(Color(0.55, 0.38, 0.14)))
	scarf.position = Vector3(0.0, 0.2, 0.01)
	chest.add_child(scarf)
	var tail := Gfx.box_m(Vector3(0.09, 0.42, 0.025), Gfx.mat_cloth(Color(0.55, 0.38, 0.14)))
	tail.position = Vector3(0.1, -0.02, -0.14)
	tail.rotation_degrees = Vector3(-8.0, 0.0, 8.0)
	chest.add_child(tail)
	# Correa cruzada, cinturón con hebilla y bolsas.
	var strap := Gfx.box_m(Vector3(0.07, 0.62, 0.025), _leather())
	strap.position = Vector3(0.0, 0.0, 0.135)
	strap.rotation_degrees = Vector3(0.0, 0.0, 32.0)
	chest.add_child(strap)
	var belt := Gfx.cyl_m(0.2, 0.07, _leather(), 0.2)
	belt.position = Vector3(0.0, -0.17, 0.0)
	torso.add_child(belt)
	var buckle := Gfx.box_m(Vector3(0.07, 0.07, 0.025), _brass())
	buckle.position = Vector3(0.0, -0.17, 0.2)
	torso.add_child(buckle)
	for sx in [-0.17, 0.17]:
		var pouch := Gfx.box_m(Vector3(0.1, 0.12, 0.07), _leather())
		pouch.position = Vector3(sx, -0.26, 0.1)
		torso.add_child(pouch)
	# Coleta.
	var pony := Gfx.capsule_m(0.05, 0.36, Gfx.mat_cloth(Color(0.04, 0.035, 0.035)))
	pony.position = Vector3(0.0, 0.07, -0.17)
	pony.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	rig.head.add_child(pony)


static func style_guard(rig: ModelRig) -> void:
	var back := rig.model.find_child("Backpack", true, false) as Node3D
	if back:
		back.visible = false
	recolor(rig.model, {
		"Green": Color(0.07, 0.09, 0.14),
		"LightGreen": Color(0.1, 0.12, 0.17),
		"Brown": Color(0.07, 0.07, 0.08),
		"Brown2": Color(0.08, 0.06, 0.05),
		"Hair": Color(0.04, 0.04, 0.04),
		"Skin": Color(0.7, 0.58, 0.52),
	})
	var torso := rig._attach("Torso")
	var chest := rig.body
	var steel := Gfx.mat_gloss(Color(0.1, 0.12, 0.15), 0.4)
	# Casco de estibador con visera y cubrenuca.
	var dome := SphereMesh.new()
	dome.radius = 0.175
	dome.height = 0.175
	dome.is_hemisphere = true
	var helm := MeshInstance3D.new()
	if not Gfx.headless:
		helm.mesh = dome
	helm.material_override = steel
	helm.position = Vector3(0.0, 0.12, 0.0)
	rig.head.add_child(helm)
	var band := Gfx.cyl_m(0.18, 0.03, Gfx.mat_gloss(Color(0.5, 0.4, 0.15), 0.4))
	band.position = Vector3(0.0, 0.125, 0.0)
	rig.head.add_child(band)
	var visor := Gfx.box_m(Vector3(0.3, 0.025, 0.14), steel)
	visor.position = Vector3(0.0, 0.135, 0.15)
	visor.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	rig.head.add_child(visor)
	var nape := Gfx.box_m(Vector3(0.28, 0.1, 0.03), steel)
	nape.position = Vector3(0.0, 0.07, -0.17)
	nape.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	rig.head.add_child(nape)
	# Chaleco con bandas reflectantes.
	var vest := Gfx.mat_cloth(Color(0.12, 0.14, 0.2))
	var refl := Gfx.mat_glow(Color(0.62, 0.52, 0.18), 0.2)
	var body := Gfx.box_m(Vector3(0.4, 0.42, 0.26), vest)
	body.position = Vector3(0.0, 0.0, 0.0)
	chest.add_child(body)
	for sx in [-0.12, 0.12]:
		var band_f := Gfx.box_m(Vector3(0.06, 0.44, 0.275), refl)
		band_f.position = Vector3(sx, 0.0, 0.0)
		chest.add_child(band_f)
	var hbar := Gfx.box_m(Vector3(0.42, 0.05, 0.275), refl)
	hbar.position = Vector3(0.0, -0.1, 0.0)
	chest.add_child(hbar)
	# Hombreras, cinturón y faldón corto.
	for sx in [-0.21, 0.21]:
		var pad := Gfx.sphere_m(0.09, steel)
		pad.position = Vector3(sx, 0.15, 0.0)
		pad.scale = Vector3(1.1, 0.55, 1.0)
		chest.add_child(pad)
	var skirt := Gfx.cyl_m(0.21, 0.4, vest, 0.3)
	skirt.position = Vector3(0.0, -0.3, -0.02)
	skirt.scale = Vector3(1.0, 1.0, 0.85)
	torso.add_child(skirt)
	var belt := Gfx.cyl_m(0.21, 0.08, _leather(), 0.21)
	belt.position = Vector3(0.0, -0.14, 0.0)
	torso.add_child(belt)
	var buckle := Gfx.box_m(Vector3(0.08, 0.08, 0.03), _brass())
	buckle.position = Vector3(0.0, -0.14, 0.21)
	torso.add_child(buckle)
	rig.coat = Node3D.new()
	torso.add_child(rig.coat)
	# Farol y llaves al cinto: luz cálida que acompaña al guardia.
	var lamp := Node3D.new()
	lamp.position = Vector3(0.27, -0.3, 0.06)
	torso.add_child(lamp)
	var glass := Gfx.cyl_m(0.05, 0.12, Gfx.mat_glow(Color(1.0, 0.75, 0.35), 2.0))
	lamp.add_child(glass)
	var cap_t := Gfx.cyl_m(0.055, 0.025, steel)
	cap_t.position = Vector3(0.0, 0.075, 0.0)
	lamp.add_child(cap_t)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.45)
	light.omni_range = 4.5
	light.light_energy = 0.9
	lamp.add_child(light)
	var keys := Gfx.torus_m(0.015, 0.05, _brass())
	keys.position = Vector3(-0.27, -0.2, 0.08)
	torso.add_child(keys)
