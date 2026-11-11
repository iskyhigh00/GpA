class_name Player
extends CharacterBody3D
## Sira: movimiento en tercera persona, cámara orbital y ataque con el gancho.

const SPEED := 4.6
const ACCEL := 45.0
const GRAVITY := 24.0
const HOOK_RANGE := 2.3
const HOOK_COOLDOWN := 0.55
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
var locked := false
var body_pivot: Node3D
var hook_pivot: Node3D
var cam: Camera3D


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
	var torso := Gfx.capsule_mesh(0.33, 1.5, Color(0.25, 0.4, 0.55))
	torso.position = Vector3(0.0, 0.8, 0.0)
	body_pivot.add_child(torso)
	var head := Gfx.sphere_mesh(0.22, Color(0.9, 0.78, 0.65))
	head.position = Vector3(0.0, 1.65, 0.0)
	body_pivot.add_child(head)
	var scarf := Gfx.box_mesh(Vector3(0.5, 0.1, 0.5), Color(0.85, 0.7, 0.3))
	scarf.position = Vector3(0.0, 1.42, 0.0)
	body_pivot.add_child(scarf)
	hook_pivot = Node3D.new()
	hook_pivot.position = Vector3(0.4, 1.05, 0.0)
	body_pivot.add_child(hook_pivot)
	var handle := Gfx.box_mesh(Vector3(0.06, 0.06, 0.55), Color(0.55, 0.55, 0.6))
	handle.position = Vector3(0.0, 0.0, -0.3)
	hook_pivot.add_child(handle)
	var tip := Gfx.box_mesh(Vector3(0.22, 0.06, 0.06), Color(0.8, 0.8, 0.85))
	tip.position = Vector3(-0.08, 0.0, -0.58)
	hook_pivot.add_child(tip)
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 65.0
	cam.far = 90.0
	add_child(cam)
	cam.make_current()
	body_pivot.rotation.y = facing


func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func cam_forward() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))


func cam_right() -> Vector3:
	return Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))


func rotate_cam(d: Vector2) -> void:
	cam_yaw -= d.x * CAM_SENS
	cam_total += absf(d.x) * CAM_SENS
	cam_pitch = clampf(cam_pitch + d.y * CAM_SENS * 0.7, 0.15, 1.15)


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	locked = false
	hurt_cd = 0.0
	hook_cd = 0.0


func _read_move() -> Vector2:
	var key := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (key + touch_move + sim_move).limit_length(1.0)


func do_hook() -> void:
	if locked or hook_cd > 0.0:
		return
	hook_cd = HOOK_COOLDOWN
	swing_t = 0.25
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


func _physics_process(delta: float) -> void:
	hook_cd = maxf(0.0, hook_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	swing_t = maxf(0.0, swing_t - delta)
	var mv := Vector2.ZERO if locked else _read_move()
	var dir := cam_right() * mv.x + cam_forward() * (-mv.y)
	var want := dir * SPEED
	velocity.x = move_toward(velocity.x, want.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, want.z, ACCEL * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if dir.length() > 0.1 and swing_t <= 0.0:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), minf(1.0, 14.0 * delta))
	body_pivot.rotation.y = facing
	hook_pivot.rotation.y = lerpf(0.9, -0.9, 1.0 - swing_t / 0.25) if swing_t > 0.0 else 0.0


func _process(_delta: float) -> void:
	var focus := global_position + Vector3(0.0, 1.5, 0.0)
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	var want := focus + off * CAM_DIST
	var q := PhysicsRayQueryParameters3D.create(focus, want, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		want = hp + (focus - want).normalized() * 0.25
	cam.global_position = want
	cam.look_at(focus, Vector3.UP)
