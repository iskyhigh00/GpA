class_name RailLamp
extends Node3D
## Lámpara sobre riel: barre el paso norte, avisa con una señal antes de moverse
## y se deja atraer por el ruido.

enum S { DWELL, SIGNAL, MOVING, ATTRACTED }

signal signal_emitted
signal spotted

const A_X := 5.0
const B_X := 13.0
const RAIL_Z := -6.5
const HEIGHT := 4.0
const SPEED := 4.0
# Desde x = 5 o x = 13 hasta el borde más lejano del paso en x = 9 hay 4,27 m.
const RADIUS := 4.4
const DETECT_TIME := 0.5
const DWELL_TIME := 0.8
const SIGNAL_TIME := 0.9
const ATTRACT_TIME := 8.0

var level: Level
var state: S = S.DWELL
var t := DWELL_TIME
var head_x := A_X
var going_to_b := true
var aim := Vector3(A_X, 0.0, RAIL_Z)
var attract_pos := Vector3.ZERO
var detect := 0.0
var spot_cd := 0.0
var signals_emitted := 0
var head: MeshInstance3D
var head_mat: StandardMaterial3D
var disc: MeshInstance3D
var disc_mat: StandardMaterial3D
var ray: MeshInstance3D
var pool: OmniLight3D


func _ready() -> void:
	top_level = true
	var rail := Gfx.box_mesh(Vector3(B_X - A_X + 2.0, 0.12, 0.12), Color(0.3, 0.3, 0.33))
	rail.position = Vector3((A_X + B_X) * 0.5, HEIGHT + 0.25, RAIL_Z)
	add_child(rail)
	head = Gfx.box_mesh(Vector3(0.5, 0.35, 0.5), Color(1.0, 0.85, 0.4), 1.2)
	head_mat = head.material_override as StandardMaterial3D
	add_child(head)
	disc = Gfx.disc(RADIUS, Color(1.0, 0.9, 0.5, 0.28))
	disc_mat = disc.material_override as StandardMaterial3D
	add_child(disc)
	ray = Gfx.beam(Color(1.0, 0.95, 0.6, 0.12))
	add_child(ray)
	pool = OmniLight3D.new()
	pool.light_color = Color(1.0, 0.9, 0.6)
	pool.light_energy = 2.2
	pool.omni_range = 5.5
	add_child(pool)
	reset()


func reset() -> void:
	state = S.DWELL
	t = DWELL_TIME
	head_x = A_X
	going_to_b = true
	aim = Vector3(A_X, 0.0, RAIL_Z)
	detect = 0.0
	spot_cd = 0.0
	_update_visuals()


func attract(pos: Vector3) -> void:
	state = S.ATTRACTED
	t = ATTRACT_TIME
	attract_pos = pos
	detect = 0.0


func _physics_process(delta: float) -> void:
	spot_cd = maxf(0.0, spot_cd - delta)
	match state:
		S.DWELL:
			t -= delta
			if t <= 0.0:
				state = S.SIGNAL
				t = SIGNAL_TIME
				signals_emitted += 1
				signal_emitted.emit()
		S.SIGNAL:
			t -= delta
			if t <= 0.0:
				state = S.MOVING
		S.MOVING:
			var dest := B_X if going_to_b else A_X
			head_x = move_toward(head_x, dest, SPEED * delta)
			if is_equal_approx(head_x, dest):
				going_to_b = not going_to_b
				state = S.DWELL
				t = DWELL_TIME
		S.ATTRACTED:
			t -= delta
			head_x = move_toward(head_x, clampf(attract_pos.x, A_X, B_X), SPEED * delta)
			if t <= 0.0:
				state = S.DWELL
				t = DWELL_TIME
	var desired := attract_pos if state == S.ATTRACTED else Vector3(head_x, 0.0, RAIL_Z)
	aim = aim.move_toward(desired, 12.0 * delta)
	_detect_player(delta)
	_update_visuals()


func _detect_player(delta: float) -> void:
	if level == null or level.player == null:
		return
	var p := level.player.global_position
	var d := Vector2(p.x - aim.x, p.z - aim.z).length()
	if d <= RADIUS and level.phase == Level.Phase.PLAY and not level.player.locked:
		detect += delta
		if detect >= DETECT_TIME and spot_cd <= 0.0:
			detect = 0.0
			spot_cd = 2.0
			spotted.emit()
	else:
		detect = maxf(0.0, detect - delta * 0.7)


func _update_visuals() -> void:
	var from := Vector3(head_x, HEIGHT, RAIL_Z)
	head.position = from
	var blink := state == S.SIGNAL and int(t * 10.0) % 2 == 0
	head_mat.emission_energy_multiplier = 4.0 if blink else 1.0
	head_mat.albedo_color = Color(1.0, 0.25, 0.2) if blink else Color(1.0, 0.85, 0.4)
	head_mat.emission = head_mat.albedo_color
	disc.position = aim + Vector3(0.0, 0.04, 0.0)
	disc_mat.albedo_color = Color(1.0, 0.3, 0.25, 0.4) if blink else Color(1.0, 0.9, 0.5, 0.28)
	Gfx.place_beam(ray, from, aim, 0.07)
	pool.position = aim + Vector3(0.0, 2.2, 0.0)
