class_name Rig
extends RefCounted
## Figura humana provisional (cápsulas y cajas) con animación procedural.

var root: Node3D
var hips: Node3D
var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var coat: Node3D
var weapon_mat: StandardMaterial3D
var phase := 0.0
var t := 0.0
var step_flag := false
## true en ModelRig (modelo glTF con animaciones); false en esta figura procedural.
var is_model := false
var lock_t := 0.0


## Solo los modelos con animaciones los usan; en la figura procedural no hacen nada.
func scrub(_clip: String, _u: float) -> void:
	pass


func oneshot(_clip: String, _u0: float = 0.0, _speed: float = 1.0) -> void:
	pass


func reset_pose() -> void:
	lock_t = 0.0


## «heavy» = más ancho (guardia). Origen en los pies, mira hacia -Z.
static func build(skin: Color, coat_c: Color, pants_c: Color, hair_c: Color, heavy: bool = false) -> Rig:
	var r := Rig.new()
	var w := 1.18 if heavy else 1.0
	r.root = Node3D.new()
	r.root.scale = Vector3.ONE * 0.9
	r.hips = Node3D.new()
	r.hips.position = Vector3(0.0, 0.95, 0.0)
	r.root.add_child(r.hips)
	var pants := Gfx.mat_cloth(pants_c)
	var boots := Gfx.mat_gloss(Color(0.05, 0.05, 0.06), 0.4)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.15 * side * w, 0.0, 0.0)
		r.hips.add_child(leg)
		var lm := Gfx.capsule_m(0.12 * w, 0.95, pants)
		lm.position = Vector3(0.0, -0.46, 0.0)
		leg.add_child(lm)
		var boot := Gfx.box_m(Vector3(0.2 * w, 0.14, 0.34), boots)
		boot.position = Vector3(0.0, -0.9, -0.06)
		leg.add_child(boot)
		if side < 0.0:
			r.leg_l = leg
		else:
			r.leg_r = leg
	r.coat = Node3D.new()
	r.hips.add_child(r.coat)
	var cm := Gfx.cyl_m(0.26 * w, 0.78 if not heavy else 0.55, Gfx.mat_cloth(coat_c), 0.4 * w)
	cm.position = Vector3(0.0, -0.3 if not heavy else -0.18, 0.0)
	r.coat.add_child(cm)
	r.body = Node3D.new()
	r.hips.add_child(r.body)
	var torso := Gfx.capsule_m(0.25 * w, 0.8, Gfx.mat_cloth(coat_c))
	torso.position = Vector3(0.0, 0.4, 0.0)
	r.body.add_child(torso)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.34 * side * w, 0.66, 0.0)
		r.body.add_child(arm)
		var am := Gfx.capsule_m(0.075 * w, 0.66, Gfx.mat_cloth(coat_c))
		am.position = Vector3(0.0, -0.28, 0.0)
		arm.add_child(am)
		var hand := Gfx.sphere_m(0.08, Gfx.mat_cloth(skin))
		hand.position = Vector3(0.0, -0.6, 0.0)
		arm.add_child(hand)
		if side < 0.0:
			r.arm_l = arm
		else:
			r.arm_r = arm
	var belt := Gfx.cyl_m(0.27 * w, 0.1, Gfx.mat_gloss(Color(0.07, 0.05, 0.04), 0.5), 0.27 * w)
	belt.position = Vector3(0.0, 0.08, 0.0)
	r.body.add_child(belt)
	var buckle := Gfx.box_m(Vector3(0.09, 0.09, 0.03), Gfx.mat_gloss(Color(0.8, 0.65, 0.3), 0.25))
	buckle.position = Vector3(0.0, 0.08, -0.27 * w)
	r.body.add_child(buckle)
	var collar := Gfx.cyl_m(0.21 * w, 0.14, Gfx.mat_cloth(coat_c), 0.27 * w)
	collar.position = Vector3(0.0, 0.84, 0.0)
	r.body.add_child(collar)
	for side in [-1.0, 1.0]:
		var pad := Gfx.sphere_m(0.13 * w, Gfx.mat_gloss(coat_c.darkened(0.3), 0.45))
		pad.position = Vector3(0.33 * side * w, 0.7, 0.0)
		pad.scale = Vector3(1.2, 0.7, 1.1)
		r.body.add_child(pad)
	r.head = Node3D.new()
	r.head.position = Vector3(0.0, 0.92, 0.0)
	r.body.add_child(r.head)
	var skull := Gfx.sphere_m(0.19, Gfx.mat_cloth(skin))
	skull.position = Vector3(0.0, 0.12, 0.0)
	r.head.add_child(skull)
	var hair := Gfx.sphere_m(0.2, Gfx.mat_cloth(hair_c))
	hair.position = Vector3(0.0, 0.16, 0.035)
	hair.scale = Vector3(1.0, 0.85, 1.0)
	r.head.add_child(hair)
	for side in [-1.0, 1.0]:
		var eye := Gfx.box_m(Vector3(0.035, 0.025, 0.02), Gfx.mat_glow(Color(0.8, 0.95, 1.0), 2.0))
		eye.position = Vector3(0.07 * side, 0.12, -0.175)
		r.head.add_child(eye)
	return r


## Camina/idle: «speed» en m/s, «max_speed» para normalizar.
func locomotion(delta: float, speed: float, max_speed: float) -> void:
	t += delta
	var k := clampf(speed / max_speed, 0.0, 1.0)
	if k > 0.05:
		phase += delta * (5.0 + 6.0 * k)
	var s := sin(phase) * k
	leg_l.rotation.x = s * 0.85
	leg_r.rotation.x = -s * 0.85
	arm_l.rotation.x = -s * 0.65
	arm_r.rotation.x = s * 0.65
	arm_l.rotation.z = 0.0
	arm_r.rotation.z = 0.0
	hips.position.y = 0.95 + absf(cos(phase)) * 0.06 * k
	body.rotation.x = -0.14 * k + sin(t * 1.6) * 0.012 * (1.0 - k)
	body.rotation.y = 0.0
	head.rotation.y = sin(t * 0.6) * 0.1 * (1.0 - k)
	head.rotation.x = 0.1 * k
	coat.rotation.x = -0.18 * k + sin(phase * 0.5) * 0.06 * k
	var flag := sin(phase) > 0.0
	step_flag = k > 0.3 and flag != (sin(phase - delta * 11.0) > 0.0)


func pose_attack(u: float) -> void:
	## u: 0 = preparado, 1 = golpe terminado. Brazo derecho de arriba-atrás hacia abajo-adelante.
	var e := 1.0 - pow(1.0 - u, 3.0)
	arm_r.rotation.x = lerpf(2.7, 0.3, e)
	arm_r.rotation.z = lerpf(-0.5, 0.2, e)
	body.rotation.y = lerpf(-0.6, 0.7, e)
	body.rotation.x = -0.2 * sin(u * PI)


func pose_surrender() -> void:
	arm_l.rotation.x = 2.9
	arm_r.rotation.x = 2.9
	arm_l.rotation.z = 0.3
	arm_r.rotation.z = -0.3
	hips.position.y = 0.72
	leg_l.rotation.x = 1.0
	leg_r.rotation.x = 0.7
	body.rotation.x = 0.15
	head.rotation.x = 0.35
