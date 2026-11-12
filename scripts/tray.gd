class_name Tray
extends Node3D
## Bandeja metálica que rueda por un carril lateral y hace ruido al llegar.

enum S { READY, ROLLING, SPENT }

signal arrived(pos: Vector3)

const START_X := -3.2
const END_X := 7.0
const RAIL_Z := 9.55
const RAIL_Y := 0.95
const DURATION := 2.8

var state: S = S.READY
var t := 0.0
var objective_material: StandardMaterial3D


func _ready() -> void:
	var plate := Gfx.box_mesh(Vector3(0.9, 0.08, 0.6), Color(0.75, 0.78, 0.8))
	objective_material = plate.material_override as StandardMaterial3D
	add_child(plate)
	var rim := Gfx.box_mesh(Vector3(0.94, 0.14, 0.04), Color(0.6, 0.63, 0.66))
	rim.position = Vector3(0.0, 0.05, 0.3)
	add_child(rim)
	var fish := Gfx.box_mesh(Vector3(0.5, 0.07, 0.18), Color(0.55, 0.75, 0.85))
	fish.position = Vector3(0.0, 0.07, 0.0)
	add_child(fish)
	reset()


func start_pos() -> Vector3:
	return Vector3(START_X, 0.0, RAIL_Z - 1.2)


func noise_pos() -> Vector3:
	return Vector3(END_X, 0.0, 8.7)


func reset() -> void:
	state = S.READY
	t = 0.0
	position = Vector3(START_X, RAIL_Y, RAIL_Z)


func push() -> bool:
	if state != S.READY:
		return false
	state = S.ROLLING
	t = 0.0
	return true


func _physics_process(delta: float) -> void:
	if state != S.ROLLING:
		return
	t += delta / DURATION
	var u := minf(t, 1.0)
	position.x = lerpf(START_X, END_X, u * u)
	if t >= 1.0:
		state = S.SPENT
		arrived.emit(noise_pos())
