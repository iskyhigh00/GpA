class_name Player
extends CharacterBody3D
## Sira: movimiento en tercera persona, cámara orbital, gancho y esquiva.

const SPEED := 4.6
const ACCEL := 45.0
const GRAVITY := 24.0
const HOOK_RANGE := 2.3
const HOOK_COOLDOWN := 0.55
const SWING_TIME := 0.28
const DODGE_TIME := 0.3
const DODGE_SPEED := 10.5
const DODGE_COOLDOWN := 0.9
const DODGE_INVULN := 0.38
const CAM_DIST := 6.0
const CAM_SENS := 0.0055

var level: Level
var sim_move := Vector2.ZERO
var touch_move := Vector2.ZERO
var cam_yaw := -PI * 0.5
var cam_pitch := 0.7
var cam_total := 0.0
var facing := -PI * 0.5
var hook_cd := 0.0
var hurt_cd := 0.0
var swing_t := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var invuln := 0.0
var dodge_dir := Vector3.ZERO
var shake := 0.0
var locked := false
var body_pivot: Node3D
var roll_node: Node3D
var rig: Rig
var cam: Camera3D
var cam_focus := Vector3.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0.0, 0.85, 0.0)
	add_child(cs)
	body_pivot = Node3D.new()
	add_child(body_pivot)
	roll_node = Node3D.new()
	roll_node.position = Vector3(0.0, 0.9, 0.0)
	body_pivot.add_child(roll_node)
	rig = Rig.build(Color(0.86, 0.72, 0.62), Color(0.1, 0.24, 0.3), Color(0.1, 0.11, 0.14), Color(0.1, 0.07, 0.06))
	rig.root.position = Vector3(0.0, -0.9, 0.0)
	roll_node.add_child(rig.root)
	# Bufanda, bolsa y gancho de inspección en la mano derecha.
	var scarf := Gfx.cyl_m(0.2, 0.12, Gfx.mat_cloth(Color(0.8, 0.6, 0.2)))
	scarf.position = Vector3(0.0, 0.86, 0.0)
	rig.body.add_child(scarf)
	var bag := Gfx.box_m(Vector3(0.3, 0.26, 0.14), Gfx.mat_wood())
	bag.position = Vector3(-0.26, -0.05, 0.22)
	rig.hips.add_child(bag)
	var metal := Gfx.mat_gloss(Color(0.6, 0.62, 0.68), 0.3)
	var shaft := Gfx.box_m(Vector3(0.05, 0.05, 0.75), metal)
	shaft.position = Vector3(0.0, -0.62, -0.3)
	rig.arm_r.add_child(shaft)
	var hook_a := Gfx.box_m(Vector3(0.05, 0.05, 0.22), metal)
	hook_a.position = Vector3(0.0, -0.62, -0.7)
	rig.arm_r.add_child(hook_a)
	var hook_b := Gfx.box_m(Vector3(0.05, 0.2, 0.05), metal)
	hook_b.position = Vector3(0.0, -0.52, -0.8)
	rig.arm_r.add_child(hook_b)
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 62.0
	cam.far = 80.0
	add_child(cam)
	cam.make_current()
	body_pivot.rotation.y = facing
	cam_focus = global_position + Vector3(0.0, 1.5, 0.0)


func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func cam_forward() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))


func cam_right() -> Vector3:
	return Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))


func rotate_cam(d: Vector2) -> void:
	cam_yaw -= d.x * CAM_SENS
	cam_total += absf(d.x) * CAM_SENS
	cam_pitch = clampf(cam_pitch + d.y * CAM_SENS * 0.7, 0.2, 1.15)


func add_shake(a: float) -> void:
	shake = minf(0.5, maxf(shake, a))


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	locked = false
	hurt_cd = 0.0
	hook_cd = 0.0
	dodge_t = 0.0
	dodge_cd = 0.0
	invuln = 0.0
	cam_focus = pos + Vector3(0.0, 1.5, 0.0)


func _read_move() -> Vector2:
	var key := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (key + touch_move + sim_move).limit_length(1.0)


func _move_dir() -> Vector3:
	var mv := _read_move()
	return cam_right() * mv.x + cam_forward() * (-mv.y)


func do_hook() -> void:
	if locked or hook_cd > 0.0 or dodge_t > 0.0:
		return
	hook_cd = HOOK_COOLDOWN
	swing_t = SWING_TIME
	level.spend_hook()
	level.play("swish")
	var g := level.guard
	var to := g.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if not g.can_be_hit():
		return
	if d < 3.2 and d > 0.05:
		facing = atan2(-to.x, -to.z)
	if d <= HOOK_RANGE:
		g.take_hit()


func do_dodge() -> void:
	if locked or dodge_cd > 0.0 or dodge_t > 0.0:
		return
	var dir := _move_dir()
	if dir.length() < 0.2:
		dir = forward()
	dodge_dir = dir.normalized()
	facing = atan2(-dodge_dir.x, -dodge_dir.z)
	dodge_t = DODGE_TIME
	dodge_cd = DODGE_COOLDOWN
	invuln = DODGE_INVULN
	swing_t = 0.0
	level.play("dodge")


func _physics_process(delta: float) -> void:
	if level.hitstop_t > 0.0:
		return
	hook_cd = maxf(0.0, hook_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	swing_t = maxf(0.0, swing_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	var dir := Vector3.ZERO if locked else _move_dir()
	if dodge_t > 0.0:
		dodge_t = maxf(0.0, dodge_t - delta)
		velocity.x = dodge_dir.x * DODGE_SPEED
		velocity.z = dodge_dir.z * DODGE_SPEED
	else:
		var want := dir * SPEED
		velocity.x = move_toward(velocity.x, want.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, want.z, ACCEL * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if dir.length() > 0.1 and swing_t <= 0.0 and dodge_t <= 0.0:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), minf(1.0, 14.0 * delta))
	body_pivot.rotation.y = facing
	_animate(delta)


func _animate(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	rig.locomotion(delta, hs, SPEED)
	if rig.step_flag and is_on_floor() and dodge_t <= 0.0:
		level.play("step", -16.0)
	if swing_t > 0.0:
		rig.pose_attack(1.0 - swing_t / SWING_TIME)
	if dodge_t > 0.0:
		var u := 1.0 - dodge_t / DODGE_TIME
		roll_node.rotation.x = -TAU * u
		rig.leg_l.rotation.x = 1.2
		rig.leg_r.rotation.x = 1.2
		rig.arm_l.rotation.x = 1.4
		rig.arm_r.rotation.x = 1.4
	else:
		roll_node.rotation.x = 0.0


func _process(delta: float) -> void:
	var target := global_position + Vector3(0.0, 1.5, 0.0)
	cam_focus = cam_focus.lerp(target, 1.0 - exp(-14.0 * delta))
	var focus := cam_focus
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	var want := focus + off * CAM_DIST
	var q := PhysicsRayQueryParameters3D.create(focus, want, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		want = hp + (focus - want).normalized() * 0.25
	shake = maxf(0.0, shake - delta * 2.2)
	if shake > 0.0:
		want += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.35
	cam.global_position = want
	cam.look_at(focus, Vector3.UP)
