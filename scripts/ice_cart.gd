class_name IceCart
extends Node3D
## Carro de hielo congelado al piso. Arrancarlo requiere fuerza prestada.

enum S { FROZEN, TREMBLING, ROLLING, STOPPED }

signal rolling_started
signal arrived

const HOME := Vector3(14.0, 0.0, 0.0)
const END := Vector3(17.5, 0.0, 0.0)
const TREMBLE_TIME := 1.0
const ROLL_TIME := 2.0

var state: S = S.FROZEN
var t := 0.0
var body: StaticBody3D
var crust: MeshInstance3D
var objective_material: BaseMaterial3D


func _ready() -> void:
	objective_material = Gfx.mat_steel().duplicate() as BaseMaterial3D
	body = Gfx.solid_m(self, Vector3(0.0, 0.7, 0.0), Vector3(2.0, 0.9, 1.1), objective_material, 2)
	body.get_child(1).queue_free()
	var iron := Gfx.mat_gloss(Color(0.1, 0.1, 0.11), 0.5)
	var wood := Gfx.mat_wood()
	# Plataforma de tablones sobre un chasis de acero.
	var bed := Gfx.box_m(Vector3(2.0, 0.1, 1.1), wood)
	bed.position = Vector3(0.0, -0.3, 0.0)
	body.add_child(bed)
	for sz in [-0.52, 0.52]:
		var rail := Gfx.box_m(Vector3(2.1, 0.12, 0.08), objective_material)
		rail.position = Vector3(0.0, -0.2, sz)
		body.add_child(rail)
	for sx in [-1.0, 1.0]:
		var end := Gfx.box_m(Vector3(0.08, 0.32, 1.1), objective_material)
		end.position = Vector3(sx, -0.1, 0.0)
		body.add_child(end)
	# Bloques de hielo escarchado, irregulares.
	var layout := [
		Vector3(-0.6, 0.0, -0.22), Vector3(0.0, 0.0, -0.25), Vector3(0.58, 0.0, -0.2),
		Vector3(-0.55, 0.0, 0.25), Vector3(0.05, 0.0, 0.27), Vector3(0.6, 0.0, 0.24),
		Vector3(-0.25, 0.4, 0.0), Vector3(0.3, 0.38, 0.02),
	]
	for i in layout.size():
		var p: Vector3 = layout[i]
		var sz := Vector3(0.5 + 0.06 * (i % 3), 0.38 + 0.04 * (i % 2), 0.42 + 0.05 * ((i + 1) % 3))
		var ice := Gfx.box_m(sz, Gfx.mat_ice())
		ice.position = Vector3(p.x, -0.1 + sz.y * 0.5 + p.y, p.z)
		ice.rotation_degrees = Vector3(0.0, 8.0 * (i - 3), 0.0)
		body.add_child(ice)
	# Ruedas con cubo y llanta.
	for sx in [-0.65, 0.65]:
		for sz in [-0.6, 0.6]:
			var w := Gfx.cyl_m(0.2, 0.1, iron)
			w.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			w.position = Vector3(sx, -0.45, sz)
			body.add_child(w)
			var hub := Gfx.cyl_m(0.07, 0.13, Gfx.mat_gloss(Color(0.5, 0.38, 0.17), 0.35))
			hub.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			hub.position = Vector3(sx, -0.45, sz)
			body.add_child(hub)
	# Barra de empuje y cadena.
	var bar := Gfx.cyl_m(0.025, 0.9, iron)
	bar.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	bar.position = Vector3(-1.45, 0.05, 0.0)
	body.add_child(bar)
	var grip := Gfx.cyl_m(0.03, 0.7, Gfx.mat_gloss(Color(0.12, 0.08, 0.05), 0.6))
	grip.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	grip.position = Vector3(-1.9, 0.05, 0.0)
	body.add_child(grip)
	# Escarcha en el suelo y carámbanos bajo el chasis (se quitan al desprenderse).
	crust = Gfx.box_mesh(Vector3(2.6, 0.12, 1.5), Color(0.8, 0.95, 1.0), 0.3)
	crust.position = Vector3(0.0, 0.07, 0.0)
	add_child(crust)
	for i in 7:
		var cone := Gfx.cyl_m(0.0, 0.2 + 0.05 * (i % 3), Gfx.mat_ice(), 0.035)
		cone.position = Vector3(-0.9 + i * 0.3, -0.34, 0.56 if i % 2 == 0 else -0.56)
		crust.add_child(cone)
	reset()


func reset() -> void:
	state = S.FROZEN
	t = 0.0
	position = HOME
	crust.visible = true
	_set_collision(true)


func _set_collision(on: bool) -> void:
	body.collision_layer = 2 if on else 0


func start() -> bool:
	if state != S.FROZEN:
		return false
	state = S.TREMBLING
	t = 0.0
	crust.visible = false
	_set_collision(false)
	return true


func _physics_process(delta: float) -> void:
	match state:
		S.TREMBLING:
			t += delta
			position = HOME + Vector3(0.0, 0.0, sin(t * 70.0) * 0.05)
			if t >= TREMBLE_TIME:
				state = S.ROLLING
				t = 0.0
				position = HOME
				rolling_started.emit()
		S.ROLLING:
			t += delta / ROLL_TIME
			var u := minf(t, 1.0)
			position = HOME.lerp(END, u * u)
			if t >= 1.0:
				state = S.STOPPED
				_set_collision(true)
				arrived.emit()
