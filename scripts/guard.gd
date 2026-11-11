class_name Guard
extends CharacterBody3D
## Guardia del Telar: patrulla el paso sur, ve con cono y línea de vista, investiga ruidos y persigue.

enum S { PATROL, INVESTIGATE, CHASE, WINDUP, STUNNED, DISARMED, STANDDOWN }

signal hit_taken(hits: int)

const SIGHT_RANGE := 7.5
const SIGHT_HALF := 0.7
const NEAR_SIGHT := 1.8
const DETECT_TIME := 0.45
const WALK_SPEED := 1.7
const INVESTIGATE_SPEED := 2.6
const CHASE_SPEED := 3.8
const HIT_DAMAGE := 15.0
const GRAVITY := 24.0
const CONE_SEGS := 12
const HOME := Vector3(8.0, 0.1, 6.5)
const PATROL_PTS: Array[Vector3] = [Vector3(6.0, 0.1, 6.5), Vector3(12.5, 0.1, 6.5)]

var level: Level
var state: S = S.PATROL
var hits := 0
var alert_count := 0
var chasing_session := false
var detect := 0.0
var yaw := 0.0
var pi := 1
var timer := 0.0
var waiting := false
var attack_cd := 0.0
var lost_t := 0.0
var path_t := 0.0
var next_pt := Vector3.ZERO
var target := Vector3.ZERO
var last_seen := Vector3.ZERO
var visual: Node3D
var baton_pivot: Node3D
var dropped: MeshInstance3D
var cone: MeshInstance3D
var cone_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	var torso := Gfx.capsule_mesh(0.38, 1.6, Color(0.3, 0.33, 0.22))
	torso.position = Vector3(0.0, 0.85, 0.0)
	visual.add_child(torso)
	var head := Gfx.sphere_mesh(0.24, Color(0.85, 0.7, 0.6))
	head.position = Vector3(0.0, 1.75, 0.0)
	visual.add_child(head)
	var helmet := Gfx.box_mesh(Vector3(0.55, 0.16, 0.55), Color(0.15, 0.17, 0.2))
	helmet.position = Vector3(0.0, 1.95, 0.0)
	visual.add_child(helmet)
	baton_pivot = Node3D.new()
	baton_pivot.position = Vector3(0.5, 1.1, 0.0)
	visual.add_child(baton_pivot)
	var baton := Gfx.box_mesh(Vector3(0.08, 0.08, 0.8), Color(0.9, 0.5, 0.15))
	baton.position = Vector3(0.0, 0.0, -0.4)
	baton_pivot.add_child(baton)
	dropped = Gfx.box_mesh(Vector3(0.08, 0.08, 0.8), Color(0.9, 0.5, 0.15))
	dropped.top_level = true
	add_child(dropped)
	cone = MeshInstance3D.new()
	cone_mat = Gfx.glow_mat(Color(1.0, 0.9, 0.3, 0.25))
	cone.material_override = cone_mat
	cone.position = Vector3(0.0, 0.04, 0.0)
	visual.add_child(cone)
	reset()


func reset() -> void:
	state = S.PATROL
	hits = 0
	alert_count = 0
	chasing_session = false
	detect = 0.0
	pi = 1
	timer = 0.0
	waiting = false
	attack_cd = 0.0
	lost_t = 0.0
	path_t = 0.0
	yaw = -PI * 0.5
	global_position = HOME
	velocity = Vector3.ZERO
	baton_pivot.visible = true
	dropped.visible = false
	baton_pivot.rotation.x = 0.0
	visual.rotation.y = yaw


func can_be_hit() -> bool:
	return state != S.DISARMED and state != S.STANDDOWN


func take_hit() -> bool:
	if not can_be_hit():
		return false
	hits += 1
	hit_taken.emit(hits)
	level.on_guard_hit(hits)
	if hits >= 2:
		state = S.DISARMED
		velocity = Vector3.ZERO
		baton_pivot.visible = false
		dropped.visible = true
		dropped.global_position = global_position + Vector3(0.0, 0.05, 0.0) + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.9
	else:
		_begin_session()
		state = S.STUNNED
		timer = 1.2
	return true


func investigate(pos: Vector3) -> void:
	if state != S.PATROL and state != S.INVESTIGATE:
		return
	state = S.INVESTIGATE
	target = Vector3(pos.x, 0.1, pos.z)
	waiting = false
	path_t = 0.0


func stand_down() -> void:
	if state == S.DISARMED:
		return
	state = S.STANDDOWN
	velocity = Vector3.ZERO
	detect = 0.0
	chasing_session = false
	baton_pivot.rotation.x = 0.0


func alert(pos: Vector3) -> void:
	if state == S.DISARMED or state == S.STANDDOWN or state == S.STUNNED or state == S.WINDUP:
		return
	_begin_session()
	if state != S.CHASE:
		state = S.CHASE
		level.on_guard_alert()
	last_seen = pos
	lost_t = 0.0
	detect = 0.0


func _begin_session() -> void:
	if not chasing_session:
		chasing_session = true
		alert_count += 1


func _flat_to(p: Vector3) -> Vector3:
	var v := p - global_position
	v.y = 0.0
	return v


func can_see(p: Vector3) -> bool:
	var to := _flat_to(p)
	var d := to.length()
	if d > SIGHT_RANGE:
		return false
	if d > NEAR_SIGHT:
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		if fwd.dot(to / d) < cos(SIGHT_HALF):
			return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.4, 0.0), p + Vector3(0.0, 1.0, 0.0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _move_toward(dest: Vector3, speed: float, delta: float) -> float:
	var to := _flat_to(dest)
	var d := to.length()
	if d > 0.05:
		var dir := to / d
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), minf(1.0, 10.0 * delta))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	return d


func _face(p: Vector3, delta: float) -> void:
	var to := _flat_to(p)
	if to.length() > 0.05:
		yaw = lerp_angle(yaw, atan2(-to.x, -to.z), minf(1.0, 10.0 * delta))


func _step_target(dest: Vector3, delta: float) -> void:
	path_t -= delta
	if path_t <= 0.0:
		next_pt = level.next_step(global_position, dest)
		path_t = 0.25


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	var pp := level.player.global_position
	var sees := false
	if state == S.PATROL or state == S.INVESTIGATE or state == S.CHASE:
		sees = can_see(pp) and not level.player.locked
	velocity.x = 0.0
	velocity.z = 0.0
	match state:
		S.PATROL:
			_patrol(delta)
			_detect(sees, pp, delta)
		S.INVESTIGATE:
			_investigate(delta)
			_detect(sees, pp, delta)
		S.CHASE:
			_chase(sees, pp, delta)
		S.WINDUP:
			_face(pp, delta)
			baton_pivot.rotation.x = -1.2
			timer -= delta
			if timer <= 0.0:
				baton_pivot.rotation.x = 0.0
				if _flat_to(pp).length() <= 2.2:
					level.hurt_player(HIT_DAMAGE)
				attack_cd = 1.4
				state = S.CHASE
		S.STUNNED:
			timer -= delta
			if timer <= 0.0:
				state = S.CHASE
				last_seen = pp
				lost_t = 0.0
		_:
			pass
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	visual.rotation.y = yaw
	_update_cone()


func _patrol(delta: float) -> void:
	if waiting:
		timer -= delta
		if timer <= 0.0:
			waiting = false
			pi = (pi + 1) % PATROL_PTS.size()
		return
	var d := _move_toward(PATROL_PTS[pi], WALK_SPEED, delta)
	if d < 0.15:
		waiting = true
		timer = 1.0


func _investigate(delta: float) -> void:
	if waiting:
		timer -= delta
		yaw += sin(timer * 1.8) * 0.012
		if timer <= 0.0:
			state = S.PATROL
			waiting = false
			pi = 0 if global_position.distance_to(PATROL_PTS[0]) < global_position.distance_to(PATROL_PTS[1]) else 1
		return
	_step_target(target, delta)
	var d := _move_toward(next_pt, INVESTIGATE_SPEED, delta)
	if _flat_to(target).length() < 0.6 or (d < 0.1 and next_pt.is_equal_approx(target)):
		waiting = true
		timer = 6.0


func _detect(sees: bool, pp: Vector3, delta: float) -> void:
	if sees:
		var near := _flat_to(pp).length() < 3.5
		detect += delta * (2.0 if near else 1.0)
	else:
		detect = maxf(0.0, detect - delta)
	if detect >= DETECT_TIME:
		alert(pp)


func _chase(sees: bool, pp: Vector3, delta: float) -> void:
	if sees:
		lost_t = 0.0
		last_seen = pp
	else:
		lost_t += delta
		if lost_t > 5.0:
			state = S.INVESTIGATE
			target = last_seen
			waiting = false
			chasing_session = false
			detect = 0.0
			return
	var dist := _flat_to(pp).length()
	if dist <= 1.7 and attack_cd <= 0.0:
		state = S.WINDUP
		timer = 0.45
		return
	if dist > 1.4:
		_step_target(last_seen, delta)
		_move_toward(next_pt, CHASE_SPEED, delta)
	else:
		_face(pp, delta)


func _update_cone() -> void:
	if state == S.DISARMED or state == S.STANDDOWN or state == S.STUNNED:
		cone.visible = false
		return
	cone.visible = true
	var ratio := clampf(detect / DETECT_TIME, 0.0, 1.0)
	if state == S.CHASE or state == S.WINDUP:
		cone_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.4)
	else:
		cone_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.22).lerp(Color(1.0, 0.25, 0.2, 0.42), ratio)
	var origin := global_position + Vector3(0.0, 0.6, 0.0)
	var space := get_world_3d().direct_space_state
	var pts: Array[Vector3] = []
	for i in CONE_SEGS + 1:
		var a := -SIGHT_HALF + (2.0 * SIGHT_HALF) * float(i) / CONE_SEGS
		var local := Vector3(sin(a), 0.0, -cos(a))
		var world := local.rotated(Vector3.UP, yaw)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + world * SIGHT_RANGE, 1)
		var hit := space.intersect_ray(q)
		var reach := SIGHT_RANGE
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			reach = origin.distance_to(hp)
		pts.append(local * reach)
	var verts := PackedVector3Array()
	for i in CONE_SEGS:
		verts.append(Vector3.ZERO)
		verts.append(pts[i])
		verts.append(pts[i + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not Gfx.headless:
		cone.mesh = m
