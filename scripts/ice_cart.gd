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
	for i in 3:
		var ice := Gfx.box_mesh(Vector3(0.55, 0.45, 0.8), Color(0.7, 0.9, 1.0), 0.2)
		ice.position = Vector3(-0.65 + i * 0.65, 0.58, 0.0)
		body.add_child(ice)
	for sx in [-0.7, 0.7]:
		for sz in [-0.5, 0.5]:
			var w := Gfx.cyl_mesh(0.18, 0.12, Color(0.12, 0.12, 0.14))
			w.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			w.position = Vector3(sx, -0.45, sz)
			body.add_child(w)
	crust = Gfx.box_mesh(Vector3(2.6, 0.12, 1.5), Color(0.8, 0.95, 1.0), 0.3)
	crust.position = Vector3(0.0, 0.07, 0.0)
	add_child(crust)
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
