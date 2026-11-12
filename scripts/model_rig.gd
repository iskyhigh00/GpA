class_name ModelRig
extends Rig
## Personaje con modelo glTF (Quaternius, CC0) y sus animaciones.
## Mismo contrato que Rig: «locomotion» elige idle/caminar/correr según la velocidad.
## Los modelos miran hacia +Z; aquí se giran para que miren hacia -Z como el resto del juego.

const LOOPING: Array[String] = ["Idle", "Idle_Neutral", "Idle_Sword", "Walk", "Run", "Run_Back", "Run_Left", "Run_Right"]
const WALK_REF := 1.5
const RUN_REF := 4.0
const RUN_FROM := 2.2

var model: Node3D
var new_pack := false
var skeleton: Skeleton3D
var anim: AnimationPlayer
var hand_r: Node3D
var current := ""
var holding := false
var last_ph := 0.0


## Devuelve null si el modelo no carga (quien llama usa entonces la figura provisional).
static func build_model(path: String, height_scale: float = 1.0, width_scale: float = 1.0) -> ModelRig:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var r := ModelRig.new()
	r.model = ps.instantiate() as Node3D
	if r.model == null:
		return null
	r.anim = r.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	r.skeleton = r.model.find_child("Skeleton3D", true, false) as Skeleton3D
	if r.anim == null or r.skeleton == null:
		r.model.free()
		return null
	Gfx.strip_meshes(r.model)
	r.is_model = true
	r.new_pack = path.contains("personajes_nuevos")
	r.model.rotation.y = PI
	r.root = Node3D.new()
	r.root.scale = Vector3(width_scale, height_scale, width_scale)
	r.root.add_child(r.model)
	for n in LOOPING:
		if r.anim.has_animation(n):
			r.anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	r.hand_r = r._attach("Wrist.R")
	r.arm_r = r.hand_r
	r.head = r._attach("Head")
	r.body = r._attach("Chest")
	r.hips = r._attach("Hips")
	# Nodos sin efecto, solo para que el código de poses procedurales no falle.
	r.arm_l = Node3D.new()
	r.leg_l = Node3D.new()
	r.leg_r = Node3D.new()
	r.coat = Node3D.new()
	for n in [r.arm_l, r.leg_l, r.leg_r, r.coat]:
		r.root.add_child(n)
	r.anim.play("Idle")
	return r


func _attach(bone: String) -> Node3D:
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	skeleton.add_child(a)
	return a


func reset_pose() -> void:
	lock_t = 0.0
	holding = false
	current = ""
	anim.speed_scale = 1.0
	anim.play("Idle", 0.0)


func clip_length(clip: String) -> float:
	return anim.get_animation(clip).length if anim.has_animation(clip) else 0.0


func locomotion(delta: float, speed: float, _max_speed: float) -> void:
	t += delta
	step_flag = false
	if lock_t > 0.0:
		lock_t -= delta
		return
	if holding:
		holding = false
		current = ""
	var clip := "Idle"
	var scale := 1.0
	coat.rotation.x = lerpf(coat.rotation.x, 0.4 * clampf(speed / RUN_REF, 0.0, 1.2), 0.12)
	if speed > 0.25:
		if speed >= RUN_FROM:
			clip = "Run"
			scale = clampf(speed / RUN_REF, 0.7, 1.35)
		else:
			clip = "Walk"
			scale = clampf(speed / WALK_REF, 0.6, 1.6)
	if current != clip or not anim.is_playing():
		current = clip
		anim.play(clip, 0.18)
	anim.speed_scale = scale
	if clip != "Idle":
		var dur := anim.current_animation_length
		if dur > 0.0:
			var ph := fposmod(anim.current_animation_position / dur * 2.0, 1.0)
			step_flag = ph < last_ph and speed > 0.5
			last_ph = ph


## Pose congelada de un clip en el instante u (0..1 de su duración).
func scrub(clip: String, u: float) -> void:
	if not anim.has_animation(clip):
		return
	lock_t = 0.0
	if not holding or current != clip:
		current = clip
		holding = true
		anim.speed_scale = 1.0
		anim.play(clip, 0.0)
		anim.pause()
	anim.seek(clampf(u, 0.0, 1.0) * anim.get_animation(clip).length, true)


## Reproduce un clip una vez desde u0; la locomoción queda bloqueada hasta que termine.
func oneshot(clip: String, u0: float = 0.0, speed: float = 1.0) -> void:
	if not anim.has_animation(clip):
		return
	var dur := anim.get_animation(clip).length
	holding = false
	current = clip
	anim.speed_scale = speed
	anim.play(clip, 0.05)
	anim.seek(clampf(u0, 0.0, 0.99) * dur, true)
	lock_t = (1.0 - u0) * dur / maxf(speed, 0.05)
