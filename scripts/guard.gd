class_name Guard
extends CharacterBody3D
## Guardia del Telar: patrulla el paso sur, ve con cono y línea de vista, investiga ruidos,
## persigue y alterna golpe corto, golpe pesado (señalado en el piso) y bloqueo.

enum S { PATROL, INVESTIGATE, CHASE, WINDUP, STUNNED, DISARMED, STANDDOWN, BLOCK }

signal hit_taken(hits: int)

const SIGHT_RANGE := 7.5
const SIGHT_HALF := 0.7
const NEAR_SIGHT := 1.8
const DETECT_TIME := 0.45
const WALK_SPEED := 1.7
const INVESTIGATE_SPEED := 2.6
const CHASE_SPEED := 3.8
const JAB_DAMAGE := 12.0
const SLAM_DAMAGE := 22.0
const SLAM_RADIUS := 2.7
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
var attack_seq := 0
var swings_seen := 0
var slam := false
var lost_t := 0.0
var path_t := 0.0
var next_pt := Vector3.ZERO
var target := Vector3.ZERO
var last_seen := Vector3.ZERO
var knock := Vector3.ZERO
var visual: Node3D
var rig: Rig
var last_state: S = S.PATROL
var baton: MeshInstance3D
var baton_mat: StandardMaterial3D
var dropped: MeshInstance3D
var ring: MeshInstance3D
var cone: MeshInstance3D
var cone_mat: StandardMaterial3D
var lantern: OmniLight3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 7
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	rig = ModelRig.build_model("res://assets/personajes/Guardia_de_la_Lonja.gltf", 1.0, 1.08)
	if rig == null:
		rig = Rig.build(Color(0.8, 0.64, 0.55), Color(0.2, 0.24, 0.2), Color(0.12, 0.13, 0.13), Color(0.08, 0.08, 0.08), true)
	visual.add_child(rig.root)
	var cap_mat := Gfx.mat_gloss(Color(0.12, 0.14, 0.17), 0.35)
	baton_mat = Gfx.mat_glow(Color(0.9, 0.5, 0.15), 0.2).duplicate() as StandardMaterial3D
	if rig.is_model:
		# Huesos del modelo: en la cabeza Y sube y Z mira al frente; en la muñeca -X apunta hacia delante.
		CharacterStyle.style_guard(rig as ModelRig)
		baton = Gfx.box_m(Vector3(0.85, 0.09, 0.09), baton_mat)
		baton.position = Vector3(-0.34, 0.07, 0.0)
	else:
		var helmet := Gfx.sphere_m(0.23, cap_mat)
		helmet.position = Vector3(0.0, 0.2, 0.02)
		helmet.scale = Vector3(1.0, 0.8, 1.0)
		rig.head.add_child(helmet)
		var brim := Gfx.box_m(Vector3(0.5, 0.04, 0.4), cap_mat)
		brim.position = Vector3(0.0, 0.12, -0.08)
		rig.head.add_child(brim)
		for sx in [-0.2, 0.2]:
			var stripe := Gfx.box_m(Vector3(0.06, 0.5, 0.52), Gfx.mat_glow(Color(0.9, 0.75, 0.2), 0.6))
			stripe.position = Vector3(sx, 0.4, 0.0)
			rig.body.add_child(stripe)
		baton = Gfx.box_m(Vector3(0.09, 0.09, 0.85), baton_mat)
		baton.position = Vector3(0.0, -0.62, -0.38)
	rig.arm_r.add_child(baton)
	lantern = OmniLight3D.new()
	lantern.position = Vector3(0.0, 1.5, -0.4)
	lantern.light_color = Color(1.0, 0.8, 0.5)
	lantern.omni_range = 4.0
	lantern.light_energy = 0.8
	visual.add_child(lantern)
	dropped = Gfx.box_m(Vector3(0.09, 0.09, 0.85), baton_mat)
	dropped.top_level = true
	add_child(dropped)
	ring = Gfx.disc(SLAM_RADIUS, Color(1.0, 0.15, 0.1, 0.0))
	Gfx.no_shadow(ring)
	ring.top_level = true
	add_child(ring)
	cone = MeshInstance3D.new()
	Gfx.no_shadow(cone)
	cone_mat = Gfx.glow_mat(Color(1.0, 0.9, 0.3, 0.25))
	cone.material_override = cone_mat
	cone.position = Vector3(0.0, 0.04, 0.0)
	visual.add_child(cone)
	reset()


func reset() -> void:
	state = S.PATROL
	hits = 0
	alert_count = 0
	attack_seq = 0
	swings_seen = 0
	chasing_session = false
	detect = 0.0
	pi = 1
	timer = 0.0
	waiting = false
	attack_cd = 0.0
	lost_t = 0.0
	path_t = 0.0
	knock = Vector3.ZERO
	yaw = -PI * 0.5
	global_position = HOME
	velocity = Vector3.ZERO
	baton.visible = true
	dropped.visible = false
	ring.visible = false
	baton_mat.emission_energy_multiplier = 0.2
	visual.rotation.y = yaw
	last_state = S.PATROL
	rig.reset_pose()


func can_be_hit() -> bool:
	return state != S.DISARMED and state != S.STANDDOWN


func take_hit() -> bool:
	if not can_be_hit():
		return false
	swings_seen += 1
	var away := _flat_to(level.player.global_position)
	if state == S.CHASE and swings_seen % 3 == 0:
		state = S.BLOCK
		timer = 0.7
		level.on_guard_block(global_position + Vector3(0.0, 1.2, 0.0))
		level.player.hook_cd += 0.45
		return false
	hits += 1
	hit_taken.emit(hits)
	level.on_guard_hit(hits, global_position + Vector3(0.0, 1.3, 0.0))
	ring.visible = false
	baton_mat.emission_energy_multiplier = 0.2
	if away.length() > 0.05:
		knock = -away.normalized() * 5.0
	if hits >= 2:
		level.bark("derrota")
		state = S.DISARMED
		velocity = Vector3.ZERO
		baton.visible = false
		dropped.visible = true
		dropped.global_position = global_position + Vector3(0.0, 0.05, 0.0) + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.9
	else:
		level.bark("golpe")
		_begin_session()
		state = S.STUNNED
		timer = 1.2
	return true


func stagger(secs: float) -> void:
	if state == S.WINDUP or state == S.CHASE:
		state = S.STUNNED
		timer = secs
		ring.visible = false
		baton_mat.emission_energy_multiplier = 0.2


func investigate(pos: Vector3) -> void:
	if state != S.PATROL and state != S.INVESTIGATE:
		return
	if state == S.PATROL:
		level.bark("ruido")
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
	ring.visible = false
	baton_mat.emission_energy_multiplier = 0.2


func alert(pos: Vector3) -> void:
	if state == S.DISARMED or state == S.STANDDOWN or state == S.STUNNED or state == S.WINDUP or state == S.BLOCK:
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
	if level == null or level.player == null or level.hitstop_t > 0.0:
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
			_windup(pp, delta)
		S.BLOCK:
			_face(pp, delta)
			timer -= delta
			if timer <= 0.0:
				state = S.CHASE
		S.STUNNED:
			timer -= delta
			if timer <= 0.0:
				state = S.CHASE
				last_seen = pp
				lost_t = 0.0
		_:
			pass
	if knock.length() > 0.1:
		velocity.x += knock.x
		velocity.z += knock.z
		knock = knock.move_toward(Vector3.ZERO, 22.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	visual.rotation.y = yaw
	_animate(delta)
	_update_cone()


func _windup(pp: Vector3, delta: float) -> void:
	_face(pp, delta)
	timer -= delta
	var pulse := 2.0 + 3.0 * absf(sin(timer * 18.0))
	baton_mat.emission_energy_multiplier = pulse
	if slam:
		ring.visible = true
		ring.global_position = global_position + Vector3(0.0, 0.05, 0.0)
		var m := ring.material_override as StandardMaterial3D
		m.albedo_color = Color(1.0, 0.15, 0.1, 0.18 + 0.25 * (1.0 - clampf(timer / 0.9, 0.0, 1.0)))
	if timer > 0.0:
		return
	baton_mat.emission_energy_multiplier = 0.2
	ring.visible = false
	rig.oneshot("Sword_Slash", 0.45, 1.8)
	var d := _flat_to(pp).length()
	state = S.CHASE
	if slam:
		level.play("slam")
		level.player.add_shake(0.35)
		if d <= SLAM_RADIUS:
			_strike(SLAM_DAMAGE)
		attack_cd = 2.0
	else:
		if d <= 2.2:
			_strike(JAB_DAMAGE)
		attack_cd = 1.3


func _strike(dmg: float) -> void:
	if not level.clear_line(global_position, level.player.global_position):
		return
	if level.player.invuln > 0.0:
		level.perfect_dodge()
		state = S.STUNNED
		timer = 1.1
	else:
		level.hurt_player(dmg)


func _animate(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if rig.is_model:
		_animate_model(delta, hs)
		return
	rig.locomotion(delta, hs, CHASE_SPEED)
	match state:
		S.WINDUP:
			var total := 0.9 if slam else 0.45
			rig.arm_r.rotation.x = lerpf(0.4, 2.8, 1.0 - clampf(timer / total, 0.0, 1.0))
			rig.body.rotation.x = 0.25
		S.BLOCK:
			rig.arm_r.rotation.x = 1.5
			rig.arm_l.rotation.x = 1.3
			rig.arm_r.rotation.z = 0.5
		S.STUNNED:
			rig.body.rotation.x = 0.4
			rig.head.rotation.x = 0.4
		S.DISARMED:
			rig.pose_surrender()
		S.CHASE:
			rig.arm_r.rotation.x = 0.9
			rig.body.rotation.x = -0.18
		_:
			pass


func _animate_model(delta: float, hs: float) -> void:
	if state != last_state:
		match state:
			S.STUNNED:
				rig.oneshot("HitRecieve", 0.0, 1.0)
			S.DISARMED:
				rig.oneshot("HitRecieve_2", 0.0, 0.9)
		last_state = state
	match state:
		S.WINDUP:
			var total := 0.9 if slam else 0.45
			rig.scrub("Sword_Slash", lerpf(0.0, 0.45, 1.0 - clampf(timer / total, 0.0, 1.0)))
		S.BLOCK:
			rig.scrub("Sword_Slash", 0.3)
		S.STUNNED, S.DISARMED:
			if rig.lock_t > 0.0:
				rig.locomotion(delta, 0.0, CHASE_SPEED)
			else:
				rig.scrub("HitRecieve" if state == S.STUNNED else "HitRecieve_2", 0.98)
		_:
			rig.locomotion(delta, hs, CHASE_SPEED)


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
			level.bark("pierde")
			state = S.INVESTIGATE
			target = last_seen
			waiting = false
			chasing_session = false
			detect = 0.0
			return
	var dist := _flat_to(pp).length()
	var next_is_slam := attack_seq % 3 == 2
	var reach := 2.4 if next_is_slam else 1.7
	if dist <= reach and attack_cd <= 0.0:
		level.bark("ataque")
		state = S.WINDUP
		slam = next_is_slam
		timer = 0.9 if slam else 0.45
		attack_seq += 1
		return
	if dist > 1.4:
		_step_target(last_seen, delta)
		_move_toward(next_pt, CHASE_SPEED, delta)
	else:
		_face(pp, delta)


func _update_cone() -> void:
	if state == S.DISARMED or state == S.STANDDOWN or state == S.STUNNED or state == S.BLOCK or state == S.WINDUP:
		cone.visible = false
		return
	cone.visible = true
	var ratio := clampf(detect / DETECT_TIME, 0.0, 1.0)
	if state == S.CHASE:
		cone_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.22)
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
