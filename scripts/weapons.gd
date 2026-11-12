class_name Weapons
extends RefCounted
## Armas del juego modeladas con piezas: gancho de inspección de Sira y bastón del guardia.
## Orden de ejes: el arma apunta hacia -X (como en el hueso de la muñeca), con la empuñadura en el origen.


static func _iron() -> StandardMaterial3D:
	return Gfx.mat_gloss(Color(0.32, 0.33, 0.36), 0.35)


static func _brass() -> StandardMaterial3D:
	return Gfx.mat_gloss(Color(0.55, 0.4, 0.17), 0.3)


static func _leather() -> StandardMaterial3D:
	return Gfx.mat_gloss(Color(0.12, 0.08, 0.055), 0.65)


static func _along_x(mi: MeshInstance3D, x: float) -> MeshInstance3D:
	mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	mi.position = Vector3(x, 0.0, 0.0)
	return mi


static func _seg(parent: Node3D, a: Vector3, b: Vector3, thick: float, m: Material) -> void:
	var box := Gfx.box_m(Vector3.ONE, m)
	Gfx.place_beam(box, a, b, thick)
	parent.add_child(box)


## Gancho de inspección: empuñadura de cuerda, remate de latón, caña de hierro y gancho curvo con punta.
static func hook() -> Node3D:
	var root := Node3D.new()
	root.name = "GanchoInspeccion"
	var grip := _along_x(Gfx.cyl_m(0.03, 0.34, _leather()), -0.13)
	root.add_child(grip)
	for i in 7:
		var wrap := _along_x(Gfx.cyl_m(0.036, 0.018, Gfx.mat_cloth(Color(0.42, 0.32, 0.18))), 0.02 - i * 0.045)
		root.add_child(wrap)
	var pommel := Gfx.sphere_m(0.048, _brass())
	pommel.position = Vector3(0.05, 0.0, 0.0)
	root.add_child(pommel)
	var ring := Gfx.torus_m(0.008, 0.036, _brass())
	ring.position = Vector3(0.1, 0.0, 0.0)
	ring.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	root.add_child(ring)
	var collar := _along_x(Gfx.cyl_m(0.046, 0.04, _brass(), 0.036), -0.3)
	root.add_child(collar)
	var collar2 := _along_x(Gfx.cyl_m(0.04, 0.025, _brass()), -0.34)
	root.add_child(collar2)
	var shaft := _along_x(Gfx.cyl_m(0.022, 0.34, _iron()), -0.5)
	root.add_child(shaft)
	# Gancho: arco de 245 grados que sube y vuelve hacia la mano; se afina hacia la punta.
	var x0 := -0.67
	var r := 0.12
	var n := 12
	var prev := Vector3(x0, 0.0, 0.0)
	for i in range(1, n + 1):
		var t := float(i) / n
		var a := t * PI * 1.36
		var p := Vector3(x0 - r * sin(a), r - r * cos(a), 0.0)
		_seg(root, prev, p, lerpf(0.046, 0.016, t), _iron())
		prev = p
	var tip := Gfx.cyl_m(0.0, 0.07, _iron(), 0.02)
	tip.position = prev + Vector3(0.025, -0.03, 0.0)
	tip.rotation_degrees = Vector3(0.0, 0.0, -42.0)
	root.add_child(tip)
	return root


## Bastón de guardia: madera con bandas de hierro, tachuelas, correa de muñeca y puño de cuero.
## «accent» es el material de las bandas y la cabeza: el guardia lo hace brillar al anunciar un golpe.
static func baton(accent: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "BastonGuardia"
	var wood := Gfx.mat_wood()
	var shaft := _along_x(Gfx.cyl_m(0.036, 0.78, wood, 0.05), -0.3)
	root.add_child(shaft)
	var grip := _along_x(Gfx.cyl_m(0.04, 0.26, _leather()), 0.0)
	root.add_child(grip)
	var knob := Gfx.sphere_m(0.05, _iron())
	knob.position = Vector3(0.14, 0.0, 0.0)
	root.add_child(knob)
	var strap := Gfx.torus_m(0.008, 0.05, _leather())
	strap.position = Vector3(0.04, -0.05, 0.0)
	strap.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	root.add_child(strap)
	for x in [-0.2, -0.45, -0.66]:
		var band := _along_x(Gfx.cyl_m(0.058, 0.04, accent), x)
		root.add_child(band)
		for k in 4:
			var stud := Gfx.sphere_m(0.011, _iron())
			var ang := k * PI * 0.5
			stud.position = Vector3(x, cos(ang) * 0.06, sin(ang) * 0.06)
			root.add_child(stud)
	var head := Gfx.sphere_m(0.06, accent)
	head.position = Vector3(-0.7, 0.0, 0.0)
	head.scale = Vector3(1.4, 1.0, 1.0)
	root.add_child(head)
	return root
