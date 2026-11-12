class_name Level
extends Node3D
## Demo del capítulo 1 «La subasta a oscuras». Todo el nivel se construye desde código.

enum Phase { TUTORIAL, PLAY, ENDED }

const START_POS := Vector3(-11.0, 0.1, 0.0)
const CHECK_POS := Vector3(-3.0, 0.1, 0.0)
const DOOR_X := -5.0
const DIVIDER_X := 9.0
const MAX_RESERVE := 100.0
const FORCE_COST := 35.0
const AMPOULE_GAIN := 50.0
const HOOK_COST := 2.0
const DEATH_DURATION := 12.0
const DEATH_FADE_TIME := 0.4
const CAM_GOAL := 1.5
const DESK_POS := Vector3(-13.5, 0.0, 2.8)
const KIT_POS := Vector3(16.5, 0.0, -3.5)
const GRATE_CENTER := Vector3(17.0, 0.0, 4.5)
const NAV_POINTS: Array[Vector3] = [
	Vector3(-6.3, 0.1, 0.0), Vector3(-3.7, 0.1, 0.0),
	Vector3(7.0, 0.1, -6.5), Vector3(11.0, 0.1, -6.5),
	Vector3(7.0, 0.1, 6.5), Vector3(11.0, 0.1, 6.5),
]
const RELEASE_URL := "https://github.com/iskyhigh00/GpA/releases/tag/latest"
const WEST_NAV_POINTS: Array[Vector3] = [
	Vector3(-2.5, 0.1, 4.2), Vector3(0.0, 0.1, 4.2), Vector3(4.4, 0.1, 4.2),
	Vector3(5.9, 0.1, 5.6), Vector3(5.9, 0.1, -4.7),
]
const METAL_FLOOR := Rect2(4.0, -2.0, 2.0, 4.0)
const METAL_NOISE_SPEED := 2.5
const METAL_NOISE_INTERVAL := 2.0
const WALL := Color(0.34, 0.39, 0.44)

var expansion := true
var phase: Phase = Phase.TUTORIAL
var tutorial_step := 1
var player: Player
var guard: Guard
var guards: Array[Guard] = []
var lookout: Guard
var lamp: RailLamp
var dock_lamp: RailLamp
var metal_noise_cooldown := 0.0
var tray: Tray
var cart: IceCart
var hud: Hud
var door_body: StaticBody3D
var door_shape: CollisionShape3D
var kit_cross: Array[MeshInstance3D] = []
var grate_plate: StaticBody3D
var grate_shape: CollisionShape3D
var grate_light: OmniLight3D
var grate_steam: GPUParticles3D
const AUDIO_DIR := "res://assets/audio/juego/"
const AMBIENCE: Array = [
	["amb_mercado", -12.0], ["amb_olas", -10.0], ["amb_bomba", -20.0], ["amb_goteo", -14.0], ["amb_silbato", -18.0],
]
var variants: Dictionary = {}
var ambience: Array[AudioStreamPlayer] = []
var heart: AudioStreamPlayer
var breath: AudioStreamPlayer
var breath_cd := 0.0
var was_low := false
var hitstop_t := 0.0
var update_opened := false
var quality_env: Environment
const BARKS: Dictionary = {
	"alerta": ["Alto. Zona cerrada.", "No deberías estar aquí.", "Identifícate. Ahora."],
	"pierde": ["Se ha ido.", "No veo nada."],
	"ruido": ["¿Quién anda ahí?", "Oigo pasos."],
	"golpe": ["¡Quieto!"],
	"ataque": ["Te tengo."],
	"derrota": ["Te dije que pararas."],
}
const INTRO: Array[String] = [
	"Tesa|Sira. Despertaste. No tenías pulso.",
	"Sira|¿Qué me hiciste?",
	"Tesa|Sangre y sal de junta. Lo que había.",
	"Sira|Hay un vaso en la mesa.",
	"Tesa|Sangre de un donante. Bebe cuando te falte reserva.",
	"Tesa|En tu puño había sal con una frase de Roque: «Sellen el paso Cendal también».",
	"Sira|Cendal. Es mi nombre. No sé qué puerta es.",
	"Sira|Necesito un carro de hielo para el contrapeso de la salida de servicio.",
]
const THOUGHTS: Dictionary = {
	"entra": "Huele a sal y a aceite.",
	"lampara": "La lámpara de riel cambia de lote. La señal parpadea.",
	"bandeja": "La bandeja de subasta rueda por el carril.",
	"ruido": "El ruido atrae al guardia. Y a la lámpara.",
}
var thoughts_done: Dictionary = {}
var pending_thoughts: Array = []
var bark_i: Dictionary = {}
var last_bark := ""
var posters := 0
var models_placed := 0
var static_mesh_counts := Vector2i.ZERO
var decals := 0
var updater: Updater

var reserve := MAX_RESERVE
var ampoules := 0
var kit_available := true
var grate_open := false
var door_open := false
var cam_progress := 0.0
var checkpoint_saved := false
var checkpoint := START_POS
var route := ""
var combat := false
var elapsed := 0.0
var done := false
var dying := false
var death_t := 0.0
var force_fails := 0
var signals_heard := 0
var sounds: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var pool_i := 0


static func register_inputs() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"hook": [KEY_J], "dodge": [KEY_SPACE], "force": [KEY_K], "action": [KEY_E], "ampoule": [KEY_R],
		"restart_cp": [KEY_T],
	}
	for a: String in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		var keys: Array = map[a]
		for k: int in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(a, ev)


func _ready() -> void:
	register_inputs()
	sounds = Sfx.build_all()
	for i in 8:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		pool.append(ap)
	_build_environment()
	Quality.load_saved()
	Quality.apply(get_viewport(), quality_env)
	Gfx.capture_static_meshes = Gfx.headless
	_build_world()
	if expansion:
		_build_west()
	Gfx.capture_static_meshes = false
	var moving: Array[Node3D] = [door_body, grate_plate]
	moving.append_array(kit_cross)
	static_mesh_counts = StaticBatch.build(self, moving)
	_build_entities()
	_build_hud()
	_set_objective()
	_start_audio()
	if not Gfx.headless:
		hud.open_dialogue(INTRO)


func _exit_tree() -> void:
	for ap in pool:
		ap.stop()
		ap.stream = null
	for ap in ambience:
		ap.stop()
	if heart:
		heart.stop()
	if breath:
		breath.stop()


# ---------------------------------------------------------------- construcción

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.025, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.5, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.11, 0.14)
	env.fog_density = 0.022
	env.glow_enabled = false
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.88
	quality_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
	moon.light_color = Color(0.55, 0.68, 0.95)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 26.0
	add_child(moon)
	var warm := OmniLight3D.new()
	warm.position = Vector3(-10.0, 2.8, 0.0)
	warm.light_color = Color(1.0, 0.8, 0.5)
	warm.omni_range = 11.0
	warm.light_energy = 1.5
	add_child(warm)
	for x in [2.0, 17.0]:
		var o := OmniLight3D.new()
		o.position = Vector3(x, 3.0, 0.0)
		o.light_color = Color(0.55, 0.78, 1.0)
		o.omni_range = 14.0
		o.light_energy = 1.1
		add_child(o)


func _wall(cx: float, cz: float, sx: float, sz: float, m: Material = null) -> void:
	var body := Gfx.solid_m(self, Vector3(cx, 1.6, cz), Vector3(sx, 3.2, sz), m if m else Gfx.mat_stone())
	# Moldura superior oscura (hija del muro, para que se desvanezca con él).
	var cap := Gfx.box_m(Vector3(sx + 0.12, 0.14, sz + 0.12), Gfx.mat_rust())
	cap.position = Vector3(0.0, 1.67, 0.0)
	body.add_child(cap)


func _pipe_x(x0: float, x1: float, y: float, z: float, r: float) -> void:
	var p := Gfx.cyl_m(r, absf(x1 - x0), Gfx.mat_steel())
	p.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	p.position = Vector3((x0 + x1) * 0.5, y, z)
	add_child(p)
	var n := int(absf(x1 - x0) / 4.0)
	for i in n + 1:
		var br := Gfx.box_m(Vector3(0.12, r * 2.6, 0.12), Gfx.mat_gloss(Color(0.08, 0.08, 0.09), 0.5))
		br.position = Vector3(minf(x0, x1) + 0.5 + i * 4.0, y, z)
		add_child(br)


func _barrel(x: float, z: float) -> void:
	var b := StaticBody3D.new()
	b.position = Vector3(x, 0.0, z)
	b.collision_layer = 2
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.4
	sh.height = 0.95
	cs.shape = sh
	cs.position = Vector3(0.0, 0.475, 0.0)
	b.add_child(cs)
	var body := Gfx.cyl_m(0.38, 0.95, Gfx.mat_rust(), 0.34)
	body.position = Vector3(0.0, 0.475, 0.0)
	b.add_child(body)
	for yy in [0.2, 0.75]:
		var band := Gfx.cyl_m(0.405, 0.06, Gfx.mat_gloss(Color(0.07, 0.07, 0.08), 0.4))
		band.position = Vector3(0.0, yy, 0.0)
		b.add_child(band)
	add_child(b)


func _crate(pos: Vector3, size: Vector3, layer: int = 2) -> void:
	var b := Gfx.solid_m(self, pos, size, Gfx.mat_mossy(), layer)
	for sy in [-1.0, 1.0]:
		var slat := Gfx.box_m(Vector3(size.x + 0.04, 0.07, size.z + 0.04), Gfx.mat_gloss(Color(0.1, 0.07, 0.05), 0.7))
		slat.position = Vector3(0.0, sy * (size.y * 0.5 - 0.05), 0.0)
		b.add_child(slat)


func _stall(pos: Vector3, size: Vector3) -> void:
	var b := Gfx.solid_m(self, pos, size, Gfx.mat_mossy(), 2)
	var ice := Gfx.box_m(Vector3(size.x * 0.9, 0.12, size.z * 0.85), Gfx.mat_gloss(Color(0.6, 0.8, 0.9), 0.15))
	ice.position = Vector3(0.0, size.y * 0.5 + 0.06, 0.0)
	b.add_child(ice)
	var fm := Gfx.mat_gloss(Color(0.62, 0.7, 0.75), 0.2)
	for i in 5:
		var f := Gfx.capsule_m(0.07, 0.42, fm)
		f.rotation_degrees = Vector3(0.0, i * 17.0, 90.0)
		f.position = Vector3(-size.x * 0.35 + i * size.x * 0.17, size.y * 0.5 + 0.17, (i % 2 - 0.5) * size.z * 0.3)
		b.add_child(f)


func _hang_lamp(x: float, z: float) -> void:
	var chain := Gfx.cyl_m(0.015, 0.7, Gfx.mat_gloss(Color(0.05, 0.05, 0.05), 0.5))
	chain.position = Vector3(x, 3.0, z)
	add_child(chain)
	var shade := Gfx.cyl_m(0.1, 0.22, Gfx.mat_rust(), 0.3)
	shade.position = Vector3(x, 2.55, z)
	add_child(shade)
	var bulb := Gfx.sphere_m(0.09, Gfx.mat_glow(Color(1.0, 0.8, 0.45), 3.0))
	bulb.position = Vector3(x, 2.42, z)
	add_child(bulb)


func _sign(text: String, pos: Vector3, rot_y: float, col: Color, px: float = 0.012) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	l.position = pos
	l.rotation_degrees.y = rot_y
	l.double_sided = false
	add_child(l)


func _puddle(x: float, z: float, r: float) -> void:
	var p := Gfx.cyl_m(r * 0.55, 0.01, Gfx.mat_gloss(Color(0.17, 0.21, 0.27), 0.3))
	p.position = Vector3(x, 0.02, z)
	Gfx.no_shadow(p)
	add_child(p)


func _arch(x: float, z0: float) -> void:
	var stone := Gfx.mat_stone()
	for sgn in [-1.0, 1.0]:
		var slab := Gfx.box_m(Vector3(0.6, 0.32, 1.85), stone)
		slab.position = Vector3(x, 2.88, z0 + sgn * 0.78)
		slab.rotation_degrees.x = 31.0 * sgn
		add_child(slab)
		var spring := Gfx.box_m(Vector3(0.7, 0.3, 0.5), Gfx.mat_rust())
		spring.position = Vector3(x, 2.3, z0 + sgn * 1.55)
		add_child(spring)
	var key := Gfx.box_m(Vector3(0.7, 0.4, 0.4), Gfx.mat_rust())
	key.position = Vector3(x, 3.35, z0)
	add_child(key)


func _column(x: float, z: float) -> void:
	var st := Gfx.mat_stone()
	var b := Gfx.solid_m(self, Vector3(x, 1.4, z), Vector3(0.7, 2.8, 0.7), Gfx.mat_rock(), 2)
	b.get_child(1).queue_free()
	var base := Gfx.box_m(Vector3(1.0, 0.3, 1.0), st)
	base.position = Vector3(0.0, -1.25, 0.0)
	b.add_child(base)
	var shaft := Gfx.cyl_m(0.3, 2.3, Gfx.mat_rock(), 0.34)
	shaft.position = Vector3(0.0, 0.0, 0.0)
	b.add_child(shaft)
	var cap := Gfx.box_m(Vector3(0.9, 0.32, 0.9), st)
	cap.position = Vector3(0.0, 1.2, 0.0)
	b.add_child(cap)
	for yy in [-0.7, 0.7]:
		var ring := Gfx.cyl_m(0.36, 0.1, Gfx.mat_rust())
		ring.position = Vector3(0.0, yy, 0.0)
		b.add_child(ring)


func _window(pos: Vector3, rot_y: float, c: Color, beam_to: Vector3) -> void:
	var w := Node3D.new()
	w.position = pos
	w.rotation_degrees.y = rot_y
	add_child(w)
	var glass := Gfx.box_m(Vector3(1.1, 1.8, 0.06), Gfx.mat_glass(c, 1.0))
	w.add_child(glass)
	var frame := Gfx.mat_rust()
	var v := Gfx.box_m(Vector3(0.08, 1.9, 0.1), frame)
	w.add_child(v)
	var h := Gfx.box_m(Vector3(1.2, 0.08, 0.1), frame)
	h.position = Vector3(0.0, 0.2, 0.0)
	w.add_child(h)
	for sx in [-0.6, 0.6]:
		var side := Gfx.box_m(Vector3(0.1, 1.9, 0.12), frame)
		side.position = Vector3(sx, 0.0, 0.0)
		w.add_child(side)
	var top := Gfx.box_m(Vector3(0.9, 0.5, 0.1), frame)
	top.position = Vector3(0.0, 1.0, 0.0)
	top.rotation_degrees.z = 45.0
	top.scale = Vector3(0.5, 0.5, 1.0)
	w.add_child(top)
	var ray := Gfx.beam(Color(c.r, c.g, c.b, 0.07))
	Gfx.no_shadow(ray)
	add_child(ray)
	Gfx.place_beam(ray, pos + Vector3(0.0, 0.2, 0.0), beam_to, 0.9)
	var sp := SpotLight3D.new()
	sp.position = pos + Vector3(0.0, 0.0, 0.0)
	sp.light_color = c
	sp.light_energy = 2.0
	sp.spot_range = 13.0
	sp.spot_angle = 38.0
	add_child(sp)
	sp.look_at(beam_to, Vector3.RIGHT)


func _cot(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_layer = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 0.8, 0.9)
	cs.shape = sh
	b.add_child(cs)
	var metal := Gfx.mat_gloss(Color(0.55, 0.57, 0.6), 0.3)
	for sx in [-0.9, 0.9]:
		for sz in [-0.38, 0.38]:
			var leg := Gfx.cyl_m(0.03, 0.62, metal)
			leg.position = Vector3(sx, -0.08, sz)
			b.add_child(leg)
	var frame := Gfx.box_m(Vector3(2.0, 0.05, 0.86), metal)
	frame.position = Vector3(0.0, 0.24, 0.0)
	b.add_child(frame)
	var mattress := Gfx.box_m(Vector3(1.94, 0.14, 0.8), Gfx.mat_cloth(Color(0.78, 0.76, 0.68)))
	mattress.position = Vector3(0.0, 0.33, 0.0)
	b.add_child(mattress)
	var pillow := Gfx.box_m(Vector3(0.4, 0.12, 0.55), Gfx.mat_cloth(Color(0.85, 0.84, 0.78)))
	pillow.position = Vector3(-0.7, 0.45, 0.0)
	b.add_child(pillow)
	var blanket := Gfx.box_m(Vector3(1.15, 0.12, 0.88), Gfx.mat_cloth(Color(0.32, 0.1, 0.12)))
	blanket.position = Vector3(0.3, 0.46, 0.0)
	blanket.rotation_degrees.y = 2.0
	b.add_child(blanket)
	var drape := Gfx.box_m(Vector3(1.15, 0.5, 0.05), Gfx.mat_cloth(Color(0.32, 0.1, 0.12)))
	drape.position = Vector3(0.3, 0.28, 0.46)
	b.add_child(drape)
	add_child(b)


func _consultorio_details() -> void:
	# Estantes con frascos en el muro sur del consultorio.
	var wood := Gfx.mat_wood()
	var cols: Array[Color] = [Color(0.2, 0.5, 0.3), Color(0.75, 0.5, 0.15), Color(0.7, 0.12, 0.18), Color(0.6, 0.7, 0.75)]
	for lvl in [1.25, 1.8]:
		var board := Gfx.box_m(Vector3(3.2, 0.06, 0.32), wood)
		board.position = Vector3(-12.8, lvl, 3.82)
		add_child(board)
		for i in 9:
			var bottle := Gfx.cyl_m(0.05 + 0.01 * (i % 3), 0.2 + 0.05 * (i % 4), Gfx.mat_glow(cols[i % 4], 0.5))
			bottle.position = Vector3(-14.2 + i * 0.34, lvl + 0.14, 3.82)
			add_child(bottle)
	# Tubo neumático de latón por el que Sira mandó la copia.
	var brass := Gfx.mat_gloss(Color(0.72, 0.52, 0.22), 0.3)
	var vtube := Gfx.cyl_m(0.07, 2.9, brass)
	vtube.position = Vector3(-14.8, 1.55, -3.75)
	add_child(vtube)
	var htube := Gfx.cyl_m(0.07, 9.3, brass)
	htube.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	htube.position = Vector3(-10.15, 3.0, -3.75)
	add_child(htube)
	for x in [-13.0, -9.5, -6.0]:
		var clamp_b := Gfx.box_m(Vector3(0.1, 0.22, 0.12), Gfx.mat_gloss(Color(0.1, 0.1, 0.11), 0.5))
		clamp_b.position = Vector3(x, 3.0, -3.78)
		add_child(clamp_b)
	var canister := Gfx.cyl_m(0.1, 0.34, Gfx.mat_gloss(Color(0.55, 0.38, 0.15), 0.35))
	canister.position = Vector3(-14.8, 0.45, -3.75)
	add_child(canister)
	_sign("TUBO NEUMÁTICO", Vector3(-12.5, 2.55, -3.95), 0.0, Color(0.85, 0.8, 0.6), 0.006)
	# Palangana y cortina sucia junto a la ventana.
	var basin := Gfx.cyl_m(0.28, 0.18, Gfx.mat_gloss(Color(0.75, 0.77, 0.8), 0.25), 0.2)
	basin.position = Vector3(-14.3, 0.95, 1.3)
	add_child(basin)
	var stand := Gfx.cyl_m(0.04, 0.85, Gfx.mat_gloss(Color(0.5, 0.52, 0.55), 0.3))
	stand.position = Vector3(-14.3, 0.45, 1.3)
	add_child(stand)


## Cartel de papel clavado en un muro. «normal_deg»: giro en Y (0: mira a +Z, 180: a -Z, 90: a +X, -90: a -X).
func _poster(file: String, pos: Vector3, normal_deg: float, w: float = 0.8) -> void:
	var m := Gfx.image_mat("res://assets/carteles/%s.png" % file, false)
	if m == null:
		return
	var q := Gfx.quad_m(Vector2(w, w * 1.5), m)
	q.position = pos
	q.rotation_degrees.y = normal_deg
	add_child(q)
	posters += 1


## Decal (plano con transparencia): en el suelo (wall = false) o en un muro con su orientación.
func _decal(file: String, pos: Vector3, size: float, rot_deg: float = 0.0, wall: bool = false, wall_deg: float = 0.0, tint: Color = Color.WHITE) -> void:
	var m := Gfx.image_mat("res://assets/decales/%s.png" % file, true, 0.55)
	if m == null:
		return
	if tint != Color.WHITE:
		m = m.duplicate() as StandardMaterial3D
		m.albedo_color = tint
	var q := Gfx.quad_m(Vector2(size, size), m)
	q.position = pos
	if wall:
		q.rotation_degrees = Vector3(0.0, wall_deg, rot_deg)
	else:
		q.rotation_degrees = Vector3(-90.0, rot_deg, 0.0)
	add_child(q)
	decals += 1


## Modelo glTF de assets/modelos (CC0) colocado como decorado.
func _model(name_id: String, pos: Vector3, rot_y: float, scale_f: float) -> Node3D:
	var path := "res://assets/modelos/%s/%s.gltf" % [name_id, name_id]
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * scale_f
	add_child(n)
	models_placed += 1
	return n


func _build_model_props() -> void:
	_model("ancla", Vector3(20.2, 0.05, 8.2), 30.0, 1.7)
	_model("red_pesca", Vector3(16.0, 0.0, -9.55), 0.0, 1.5)
	for x in [4.6, 5.3, 6.0, 14.2, 14.9]:
		_model("gancho_carnicero", Vector3(x, 1.9, -9.6), 90.0 + x * 20.0, 3.0)
	var rail := Gfx.cyl_m(0.04, 2.0, Gfx.mat_steel())
	rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rail.position = Vector3(5.3, 2.2, -9.6)
	add_child(rail)
	var rail2 := Gfx.cyl_m(0.04, 1.6, Gfx.mat_steel())
	rail2.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rail2.position = Vector3(14.55, 2.2, -9.6)
	add_child(rail2)


func _build_decor_images() -> void:
	# Carteles de la lonja.
	_poster("cartel_bandejas", Vector3(-3.2, 1.75, 9.985), 180.0)
	_poster("cartel_subasta", Vector3(1.0, 1.75, 9.985), 180.0, 0.7)
	_poster("cartel_lote_14", Vector3(17.0, 1.75, 9.985), 180.0, 0.7)
	_poster("cartel_paso_restringido", Vector3(8.79, 1.7, -3.2), -90.0)
	_poster("cartel_compuertas", Vector3(22.99, 1.7, -3.0), -90.0, 0.7)
	# Consultorio: sangre, moho.
	_decal("mancha_sangre_seca", Vector3(-8.0, 0.03, 1.5), 1.7, 20.0)
	_decal("charco_sangre", Vector3(-12.0, 0.035, -1.6), 1.5, -35.0)
	_decal("moho_esquina", Vector3(-14.98, 0.7, 3.5), 1.6, 0.0, true, 90.0)
	_decal("moho_esquina", Vector3(-14.98, 0.7, -3.5), 1.6, 90.0, true, 90.0)
	# Lonja: grietas, óxido bajo las tuberías, sal en las juntas y manchas.
	_decal("grieta_larga", Vector3(6.0, 0.03, -2.0), 3.2, 30.0)
	_decal("grieta_larga", Vector3(15.0, 0.03, -6.0), 2.6, 120.0)
	_decal("grieta_larga", Vector3(-1.0, 0.03, 5.5), 2.8, 75.0)
	_decal("oxido_en_gotas", Vector3(3.0, 1.9, -9.98), 1.5, 0.0, true, 0.0)
	_decal("oxido_en_gotas", Vector3(16.0, 1.7, -9.98), 1.3, 0.0, true, 0.0)
	_decal("sal_en_juntas", Vector3(17.0, 0.03, 2.4), 2.6, 15.0)
	_decal("sal_en_juntas", Vector3(-3.5, 0.03, -3.5), 2.2, 50.0)
	_decal("mancha_sangre_seca", Vector3(10.5, 0.03, 7.6), 1.2, 140.0)
	_decal("charco_sangre", Vector3(6.4, 0.035, 8.6), 1.3, 10.0, false, 0.0, Color(0.85, 0.8, 0.8))


func _build_gothic() -> void:
	# Arcos sobre los dos pasos del muro divisor.
	_arch(DIVIDER_X, -6.5)
	_arch(DIVIDER_X, 6.5)
	# Columnas fuera de las rutas.
	for cp in [Vector2(4.5, 0.0), Vector2(11.5, -1.6), Vector2(11.5, 1.8), Vector2(19.0, -4.5)]:
		_column(cp.x, cp.y)
	# Vitrales con haces de luz sobre el muro norte.
	_window(Vector3(0.5, 1.9, -9.94), 0.0, Color(0.35, 0.55, 1.0), Vector3(0.5, 0.0, -5.5))
	_window(Vector3(6.0, 1.9, -9.94), 0.0, Color(1.0, 0.7, 0.3), Vector3(6.0, 0.0, -6.0))
	_window(Vector3(16.0, 1.9, -9.94), 0.0, Color(0.9, 0.25, 0.3), Vector3(16.0, 0.0, -5.0))
	_window(Vector3(-14.94, 1.9, 2.2), 90.0, Color(0.4, 0.6, 1.0), Vector3(-11.0, 0.0, 2.2))
	# Rodapié oscuro y juntas de las losas del suelo.
	var trim := Gfx.mat_gloss(Color(0.04, 0.04, 0.05), 0.5)
	for t in [Vector4(9.0, -9.9, 28.0, 0.12), Vector4(9.0, 9.9, 28.0, 0.12)]:
		var bt := Gfx.box_m(Vector3(t.z, 0.35, 0.2), trim)
		bt.position = Vector3(t.x, 0.18, t.y)
		add_child(bt)
	# Cuerdas enrolladas, bolardos y cadenas.
	for rp in [Vector3(21.2, 0.12, 7.5), Vector3(-3.5, 0.12, 9.2)]:
		var rope := Gfx.torus_m(0.12, 0.42, Gfx.mat_cloth(Color(0.35, 0.27, 0.15)))
		rope.position = rp
		add_child(rope)
	for bp in [Vector3(22.4, 0.0, 5.5), Vector3(22.4, 0.0, 8.0)]:
		var bol := Gfx.cyl_m(0.14, 0.7, Gfx.mat_rust(), 0.2)
		bol.position = bp + Vector3(0.0, 0.35, 0.0)
		add_child(bol)
		var head := Gfx.sphere_m(0.2, Gfx.mat_rust())
		head.position = bp + Vector3(0.0, 0.72, 0.0)
		add_child(head)
	for cx in [2.0, 8.0, 14.0, 20.0]:
		var chain := Gfx.cyl_m(0.02, 1.4, Gfx.mat_gloss(Color(0.06, 0.06, 0.06), 0.5))
		chain.position = Vector3(cx, 2.5, -9.7)
		add_child(chain)


func _build_particles() -> void:
	if Gfx.headless:
		return
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.8, 0.9, 1.0, 0.35)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = qm
	var dust := GPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.visibility_aabb = AABB(Vector3(-16.0, -2.0, -12.0), Vector3(32.0, 8.0, 24.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14.0, 1.6, 9.0)
	pm.direction = Vector3(0.4, 0.1, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	dust.process_material = pm
	dust.draw_pass_1 = quad
	dust.position = Vector3(9.0, 1.8, 0.0)
	add_child(dust)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.85, 0.9, 0.95, 0.12)
	var sq := QuadMesh.new()
	sq.size = Vector2(0.9, 0.9)
	sq.material = sm
	var mist := GPUParticles3D.new()
	mist.amount = 14
	mist.lifetime = 12.0
	mist.preprocess = 12.0
	mist.visibility_aabb = AABB(Vector3(-16.0, -1.0, -12.0), Vector3(32.0, 4.0, 24.0))
	var mm := ParticleProcessMaterial.new()
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mm.emission_box_extents = Vector3(14.0, 0.15, 9.0)
	mm.direction = Vector3(1.0, 0.0, 0.2)
	mm.spread = 25.0
	mm.initial_velocity_min = 0.1
	mm.initial_velocity_max = 0.3
	mm.gravity = Vector3.ZERO
	mm.scale_min = 2.0
	mm.scale_max = 4.0
	mist.process_material = mm
	var mqm := StandardMaterial3D.new()
	mqm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mqm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mqm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mqm.albedo_color = Color(0.55, 0.65, 0.75, 0.07)
	var mq := QuadMesh.new()
	mq.size = Vector2(2.0, 1.2)
	mq.material = mqm
	mist.draw_pass_1 = mq
	mist.position = Vector3(9.0, 0.5, 0.0)
	add_child(mist)
	grate_steam = GPUParticles3D.new()
	grate_steam.amount = 12
	grate_steam.lifetime = 3.0
	grate_steam.emitting = false
	grate_steam.visibility_aabb = AABB(Vector3(-3.0, -2.0, -3.0), Vector3(6.0, 8.0, 6.0))
	var sp := ParticleProcessMaterial.new()
	sp.direction = Vector3.UP
	sp.spread = 18.0
	sp.initial_velocity_min = 0.5
	sp.initial_velocity_max = 1.0
	sp.gravity = Vector3.ZERO
	sp.scale_min = 0.6
	sp.scale_max = 1.6
	grate_steam.process_material = sp
	grate_steam.draw_pass_1 = sq
	grate_steam.position = GRATE_CENTER + Vector3(0.0, 0.2, 0.0)
	add_child(grate_steam)


func spark(pos: Vector3, c: Color = Color(1.0, 0.8, 0.4)) -> void:
	if Gfx.headless:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	m.material = Gfx.mat_glow(c, 3.0)
	p.mesh = m
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _build_world() -> void:
	var stone := Gfx.mat_stone()
	var plaster := Gfx.mat_plaster()
	var floor_m := Gfx.mat_floor()
	# Suelo en losas, con hueco para la rejilla (x 16..18, z 3.5..5.5).
	Gfx.solid_m(self, Vector3(4.0, -0.25, -3.25), Vector3(38.0, 0.5, 13.5), floor_m)
	Gfx.solid_m(self, Vector3(4.0, -0.25, 7.75), Vector3(38.0, 0.5, 4.5), floor_m)
	Gfx.solid_m(self, Vector3(0.5, -0.25, 4.5), Vector3(31.0, 0.5, 2.0), floor_m)
	Gfx.solid_m(self, Vector3(20.5, -0.25, 4.5), Vector3(5.0, 0.5, 2.0), floor_m)
	var boards := Gfx.box_m(Vector3(9.6, 0.02, 7.6), Gfx.mat_wood())
	boards.position = Vector3(-10.0, 0.012, 0.0)
	add_child(boards)
	# Consultorio.
	_wall(-15.2, 0.0, 0.4, 8.4, plaster)
	_wall(-10.0, -4.2, 10.4, 0.4, plaster)
	_wall(-10.0, 4.2, 10.4, 0.4, plaster)
	# Lonja: muros exteriores.
	_wall(9.0, -10.2, 28.4, 0.4)
	_wall(9.0, 10.2, 28.4, 0.4)
	_wall(23.2, 0.0, 0.4, 20.4)
	_wall(-5.0, -5.7, 0.4, 9.0)
	_wall(-5.0, 5.7, 0.4, 9.0)
	# Muro divisor con paso norte (z -8..-5) y paso sur (z 5..8).
	_wall(DIVIDER_X, -9.0, 0.4, 2.0, Gfx.mat_brick())
	_wall(DIVIDER_X, 0.0, 0.4, 10.0, Gfx.mat_brick())
	_wall(DIVIDER_X, 9.0, 0.4, 2.0, Gfx.mat_brick())
	# Pilastras en el muro norte y este (no estorban las rutas).
	for x in [-2.0, 3.0, 13.0, 19.0]:
		Gfx.solid_m(self, Vector3(x, 1.6, -9.75), Vector3(0.7, 3.2, 0.5), Gfx.mat_rock(), 1)
	# Puerta del consultorio.
	door_body = StaticBody3D.new()
	door_body.position = Vector3(DOOR_X, 1.5, 0.0)
	door_shape = CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size = Vector3(0.3, 3.0, 2.4)
	door_shape.shape = ds
	door_body.add_child(door_shape)
	door_body.add_child(Gfx.box_m(Vector3(0.3, 3.0, 2.4), Gfx.mat_wood()))
	var handle := Gfx.sphere_m(0.07, Gfx.mat_gloss(Color(0.8, 0.65, 0.3), 0.2))
	handle.position = Vector3(0.22, 0.0, 0.8)
	door_body.add_child(handle)
	add_child(door_body)
	# Consultorio: camilla, mesa con ampollas, armario, ventana.
	_cot(Vector3(-12.5, 0.4, -2.5))
	_consultorio_details()
	var desk := Gfx.solid_m(self, Vector3(-13.5, 0.5, 2.8), Vector3(1.6, 1.0, 0.8), Gfx.mat_wood(), 2)
	for i in 3:
		var vial := Gfx.cyl_m(0.04, 0.16, Gfx.mat_glow(Color(0.85, 0.1, 0.2), 1.2))
		vial.position = Vector3(-0.4 + i * 0.25, 0.58, 0.0)
		desk.add_child(vial)
	for i in 2:
		var paper := Gfx.box_m(Vector3(0.42, 0.012, 0.3), Gfx.mat_cloth(Color(0.86, 0.82, 0.7)))
		paper.position = Vector3(0.25 - i * 0.55, 0.51, 0.1 - i * 0.12)
		paper.rotation_degrees.y = 14.0 - i * 31.0
		desk.add_child(paper)
	var win := Gfx.box_m(Vector3(0.05, 1.4, 2.0), Gfx.mat_glass(Color(0.45, 0.6, 0.9), 0.9))
	win.position = Vector3(-14.95, 2.0, -0.5)
	add_child(win)
	_sign("CONSULTORIO", Vector3(-4.8, 2.85, 0.0), 90.0, Color(0.85, 0.85, 0.75), 0.008)
	_hang_lamp(-10.0, 0.0)
	# Lonja: puestos, cajas, barriles.
	_stall(Vector3(3.0, 0.5, 3.0), Vector3(1.6, 1.0, 1.2))
	_stall(Vector3(4.6, 0.5, -3.9) if expansion else Vector3(1.0, 0.5, -2.5), Vector3(1.4, 1.0, 1.0))
	_crate(Vector3(20.5, 0.5, -6.0), Vector3(1.4, 1.0, 1.4))
	_crate(Vector3(21.0, 0.5, -1.5), Vector3(1.2, 1.0, 1.2))
	_crate(Vector3(20.6, 1.4, -6.0), Vector3(0.9, 0.8, 0.9))
	_barrel(21.8, -8.6)
	_barrel(20.9, -8.8)
	_barrel(22.0, 2.0)
	_barrel(14.0, 8.9)
	_barrel(15.0, 9.0)
	_pipe_x(-4.5, 22.5, 2.7, -9.85, 0.14)
	_pipe_x(-4.5, 22.5, 2.2, -9.85, 0.07)
	_pipe_x(9.5, 22.5, 2.7, 9.85, 0.12)
	for x in [-1.0, 5.0, 12.0, 18.0]:
		_hang_lamp(x, -8.6)
		_hang_lamp(x, 8.6)
	_sign("LONJA DEL CANDIL", Vector3(8.0, 2.5, -9.93), 0.0, Color(0.9, 0.78, 0.45), 0.014)
	for pd in [Vector3(-1.0, 0.0, 2.0), Vector3(6.0, 0.0, -1.0), Vector3(13.0, 0.0, 2.5), Vector3(19.0, 0.0, 7.0), Vector3(-3.5, 0.0, -6.0), Vector3(10.0, 0.0, -7.5)]:
		_puddle(pd.x, pd.z, 0.9 + fmod(pd.x * 0.37, 0.8))
	# Carril de la bandeja en el muro sur.
	var rail := Gfx.box_m(Vector3(Tray.END_X - Tray.START_X + 2.0, 0.08, 0.1), Gfx.mat_gloss(Color(0.5, 0.52, 0.56), 0.3))
	rail.position = Vector3((Tray.START_X + Tray.END_X) * 0.5, Tray.RAIL_Y - 0.08, Tray.RAIL_Z + 0.1)
	add_child(rail)
	# Botiquín de servicio.
	var kit := Gfx.solid_m(self, KIT_POS + Vector3(0.0, 0.6, 0.0), Vector3(1.0, 1.2, 0.6), Gfx.mat_gloss(Color(0.82, 0.85, 0.88), 0.4), 2)
	for sz: Vector3 in [Vector3(0.5, 0.14, 0.04), Vector3(0.14, 0.5, 0.04)]:
		var cross := Gfx.box_m(sz, Gfx.mat_glow(Color(0.85, 0.1, 0.15), 1.5))
		cross.position = Vector3(0.0, 0.0, 0.33)
		kit.add_child(cross)
		kit_cross.append(cross)
	# Contrapeso y rejilla.
	Gfx.solid_m(self, Vector3(19.7, 1.0, 0.0), Vector3(0.5, 2.0, 1.4), Gfx.mat_plate(), 2)
	var pit := Gfx.box_m(Vector3(2.0, 0.1, 2.0), Gfx.mat_cloth(Color(0.0, 0.0, 0.0)))
	pit.position = GRATE_CENTER + Vector3(0.0, -1.5, 0.0)
	add_child(pit)
	grate_light = OmniLight3D.new()
	grate_light.position = GRATE_CENTER + Vector3(0.0, -0.8, 0.0)
	grate_light.light_color = Color(1.0, 0.7, 0.4)
	grate_light.omni_range = 5.0
	grate_light.light_energy = 0.0
	add_child(grate_light)
	grate_plate = StaticBody3D.new()
	grate_plate.position = GRATE_CENTER + Vector3(0.0, -0.05, 0.0)
	grate_shape = CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(2.0, 0.1, 2.0)
	grate_shape.shape = gs
	grate_plate.add_child(grate_shape)
	grate_plate.add_child(Gfx.box_m(Vector3(2.0, 0.1, 2.0), Gfx.mat_plate()))
	for i in 5:
		var bar := Gfx.box_m(Vector3(0.08, 0.06, 2.0), Gfx.mat_gloss(Color(0.12, 0.12, 0.13), 0.4))
		bar.position = Vector3(-0.8 + i * 0.4, 0.06, 0.0)
		grate_plate.add_child(bar)
	add_child(grate_plate)
	_build_gothic()
	_build_decor_images()
	_build_model_props()
	_build_particles()


func _build_west() -> void:
	# La hilera de carga protege la salida del consultorio. Se rodea por el sur.
	for z: float in [-8.1, -4.9, -1.7, 1.5]:
		_crate(Vector3(-1.35, 1.05, z), Vector3(1.05, 2.1, 3.2), 1)
	# Entre los cajones y el divisor queda un corredor protegido, abierto por ambos extremos.
	for z: float in [-2.7, -1.35, 1.2, 2.55]:
		_crate(Vector3(7.0, 0.95, z), Vector3(1.15, 1.9, 1.32), 1)
	var steel := Gfx.mat(Color(0.13, 0.16, 0.18), 0.75)
	steel.metallic = 0.65
	for x in 2:
		for z in 4:
			var plate := Gfx.box_m(Vector3(0.97, 0.018, 0.97), steel)
			plate.position = Vector3(METAL_FLOOR.position.x + x + 0.5, 0.012, METAL_FLOOR.position.y + z + 0.5)
			add_child(plate)
	var light := Gfx.glow_mat(Color(0.47, 0.62, 0.74, 0.12))
	for center: Vector3 in [Vector3(2.55, 0.025, -6.8), Vector3(5.75, 0.025, 4.4)]:
		var footprint := Gfx.box_m(Vector3(1.7, 0.01, 2.1), light)
		Gfx.no_shadow(footprint)
		footprint.position = center
		add_child(footprint)


func _build_entities() -> void:
	player = Player.new()
	player.level = self
	player.position = START_POS
	add_child(player)
	tray = Tray.new()
	add_child(tray)
	tray.arrived.connect(_on_tray_arrived)
	lamp = RailLamp.new()
	lamp.level = self
	add_child(lamp)
	lamp.signal_emitted.connect(_on_lamp_signal)
	lamp.spotted.connect(_on_lamp_spotted)
	cart = IceCart.new()
	add_child(cart)
	cart.rolling_started.connect(_on_cart_rolling)
	cart.arrived.connect(_on_cart_arrived)
	guard = Guard.new()
	guard.level = self
	add_child(guard)
	guards.append(guard)
	if not expansion:
		return
	lookout = Guard.new()
	lookout.name = "Vigia"
	lookout.level = self
	lookout.lookout = true
	add_child(lookout)
	guards.append(lookout)
	dock_lamp = RailLamp.new()
	dock_lamp.name = "LamparaDesembarco"
	dock_lamp.level = self
	dock_lamp.axis = Vector3.BACK
	dock_lamp.rail_origin = Vector3(1.0, 0.0, 0.0)
	dock_lamp.start = -8.0
	dock_lamp.end = 8.0
	dock_lamp.radius = 2.0
	dock_lamp.speed = 4.0
	dock_lamp.wait_time = 1.0
	dock_lamp.detect_time = 0.24
	add_child(dock_lamp)
	dock_lamp.signal_emitted.connect(_on_dock_lamp_signal)
	dock_lamp.spotted.connect(_on_dock_lamp_spotted)


func _build_hud() -> void:
	hud = Hud.new()
	hud.level = self
	add_child(hud)
	hud.cam_dragged.connect(_on_cam_drag)
	hud.hook_pressed.connect(player.do_hook)
	hud.dodge_pressed.connect(player.do_dodge)
	hud.force_pressed.connect(try_force)
	hud.action_pressed.connect(do_action)
	hud.ampoule_pressed.connect(use_ampoule)
	hud.restart_pressed.connect(request_restart)
	hud.play_again_pressed.connect(_play_again)
	hud.browser_pressed.connect(_open_update)
	hud.quality_pressed.connect(_cycle_quality)
	updater = Updater.new()
	add_child(updater)
	updater.set_installed(hud.version_text)
	hud.updater = updater
	hud.update_pressed.connect(updater.act)
	hud.settings_toggled.connect(_on_settings_toggled)


# ---------------------------------------------------------------- utilidades

func _ld(file: String) -> AudioStream:
	var path := AUDIO_DIR + file + ".ogg"
	return load(path) if ResourceLoader.exists(path) else null


func _loop_player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var ap := AudioStreamPlayer.new()
	ap.stream = stream
	ap.volume_db = db
	add_child(ap)
	return ap


## Sonidos reales (assets/audio/juego); lo que no tenga archivo sigue usando el sintetizado.
func _start_audio() -> void:
	var over := {"beep": "campana", "clang": "clang", "tray_roll": "bandeja_rueda", "ice": "hielo", "cart_roll": "carro_rueda", "gong": "gong", "grate": "rejilla", "hook_hit": "impacto_gancho", "hurt": "golpe_recibido", "block": "bloqueo", "body_fall": "caida", "door": "puerta_abre", "door_shut": "puerta_cierra"}
	for key: String in over:
		var st := _ld(str(over[key]))
		if st:
			sounds[key] = st
	var steps: Array[AudioStream] = []
	for i in 3:
		var path := "res://assets/audio/paso_metal_mojado_0%d.wav" % (i + 1)
		if ResourceLoader.exists(path):
			steps.append(load(path))
	if not steps.is_empty():
		variants["step"] = steps
		if expansion:
			variants["paso_metal_mojado"] = steps
	if Gfx.headless:
		return
	for a: Array in AMBIENCE:
		var st := _ld(str(a[0]))
		if st:
			var ap := _loop_player(st, float(a[1]))
			ambience.append(ap)
			ap.play()
	var hs := _ld("latido")
	if hs:
		heart = _loop_player(hs, -60.0)
	var bs := _ld("respiracion")
	if bs:
		breath = _loop_player(bs, -8.0)


func _update_audio(delta: float) -> void:
	if heart == null:
		return
	var low := phase == Phase.PLAY and not done and not dying and reserve <= FORCE_COST
	var target := lerpf(-26.0, -6.0, 1.0 - clampf(reserve / FORCE_COST, 0.0, 1.0)) if low else -60.0
	heart.volume_db = move_toward(heart.volume_db, target, 40.0 * delta)
	if low and not heart.playing:
		heart.play()
	elif not low and heart.playing and heart.volume_db <= -58.0:
		heart.stop()
	breath_cd = maxf(0.0, breath_cd - delta)
	if low and not was_low and breath_cd <= 0.0 and breath:
		breath.play()
		breath_cd = 30.0
	was_low = low


func play(sound: String, vol_db: float = 0.0) -> void:
	var s: AudioStream = sounds.get(sound)
	if variants.has(sound):
		var vs: Array = variants[sound]
		s = vs[randi() % vs.size()]
	if s == null or Gfx.headless:
		return
	var ap := pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	ap.stream = s
	ap.volume_db = vol_db
	ap.play()


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func play_footstep(pos: Vector3) -> void:
	if lookout == null or not METAL_FLOOR.has_point(Vector2(pos.x, pos.z)):
		play("step", -16.0)


func clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0.0, 0.6, 0.0), b + Vector3(0.0, 0.6, 0.0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Siguiente punto a seguir para ir de «from» a «to» rodeando los muros (grafo pequeño de pasos).
func next_step(from: Vector3, to: Vector3) -> Vector3:
	if clear_line(from, to):
		return to
	var pts: Array[Vector3] = [from, to]
	pts.append_array(NAV_POINTS)
	if lookout != null:
		pts.append_array(WEST_NAV_POINTS)
	var n := pts.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var seen: Array[bool] = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		seen.append(false)
	dist[0] = 0.0
	for _k in n:
		var u := -1
		for i in n:
			if not seen[i] and (u == -1 or dist[i] < dist[u]):
				u = i
		if u == -1 or dist[u] == INF:
			break
		seen[u] = true
		for v in n:
			if seen[v]:
				continue
			var nd := dist[u] + pts[u].distance_to(pts[v])
			if nd < dist[v] and clear_line(pts[u], pts[v]):
				dist[v] = nd
				prev[v] = u
	if dist[1] == INF:
		return to
	var cur := 1
	while prev[cur] != 0:
		cur = prev[cur]
	return pts[cur]


func route_label() -> String:
	if route != "sur":
		return "Norte (sigilo)"
	return "Sur (combate)" if combat else "Sur (sin combate)"


# ---------------------------------------------------------------- reserva

func spend_hook() -> void:
	reserve = maxf(1.0, reserve - HOOK_COST)


func spend(amount: float) -> void:
	reserve = maxf(0.0, reserve - amount)
	if reserve <= 0.0:
		die()


func hurt_player(dmg: float, knockdown: float = 0.0) -> void:
	if player.hurt_cd > 0.0 or player.invuln > 0.0 or dying or done:
		return
	player.hurt_cd = 0.8
	player.add_shake(0.35)
	if knockdown > 0.0:
		player.knock_down(knockdown)
	else:
		player.flinch()
	hud.flash = 1.0
	play("hurt")
	spend(dmg)


func on_guard_hit(pos: Vector3, finisher: bool) -> void:
	combat = true
	play("hook_hit")
	hitstop_t = 0.1
	player.add_shake(0.42 if finisher else 0.3)
	spark(pos)


func on_guard_block(pos: Vector3) -> void:
	play("block")
	spark(pos, Color(0.7, 0.85, 1.0))
	player.add_shake(0.1)
	hud.say("¡Bloqueó! Esquiva y espera tu momento.", 2.0)


func perfect_dodge() -> void:
	play("perfect")
	hitstop_t = 0.05
	hud.say("¡Esquiva perfecta! Aprovecha el hueco.", 2.0)


## Frases cortas del guardia como subtítulo; no pisan un mensaje importante en curso.
func bark(kind: String) -> void:
	var lines: Array = BARKS.get(kind, [])
	if lines.is_empty() or hud.message_t > 0.8:
		return
	var i := int(bark_i.get(kind, 0))
	bark_i[kind] = i + 1
	last_bark = str(lines[i % lines.size()])
	hud.say("Guardia: «%s»" % last_bark, 2.2)


## Pensamiento de Sira como subtítulo, una sola vez; si hay un mensaje importante en curso, espera.
func think(id: String, delay: float = 0.0) -> void:
	if thoughts_done.has(id) or not THOUGHTS.has(id):
		return
	if delay > 0.0:
		pending_thoughts.append([delay, id])
		return
	if hud.message_t > 0.8:
		pending_thoughts.append([1.0, id])
		return
	thoughts_done[id] = true
	hud.say("Sira: «%s»" % str(THOUGHTS[id]), 3.0)


func _tick_thoughts(delta: float) -> void:
	for i in range(pending_thoughts.size() - 1, -1, -1):
		var entry: Array = pending_thoughts[i]
		entry[0] = float(entry[0]) - delta
		if float(entry[0]) <= 0.0:
			pending_thoughts.remove_at(i)
			think(str(entry[1]))


func on_guard_alert() -> void:
	if hud.message_t < 1.0:
		bark("alerta")
	play("alarm")


func use_ampoule() -> void:
	if dying or done:
		return
	if ampoules <= 0:
		hud.say("No tienes ampollas.")
		return
	if reserve >= MAX_RESERVE:
		hud.say("La reserva ya está llena.")
		return
	ampoules -= 1
	reserve = minf(MAX_RESERVE, reserve + AMPOULE_GAIN)
	play("pickup")
	hud.say("Ampolla: +50 de reserva.")


# ---------------------------------------------------------------- acciones

func do_action() -> void:
	if done:
		_play_again()
		return
	if dying:
		return
	var p := player.global_position
	if flat_dist(p, DESK_POS) < 2.4:
		hud.open_docs(Docs.get_docs(["orden", "dispensario"]))
		return
	if tray.state == Tray.S.READY and flat_dist(p, tray.start_pos()) < 2.4:
		tray.push()
		_update_objective_highlights()
		play("push")
		play("tray_roll", -2.0)
		hud.say("Empujas la bandeja por el carril…")
		think("bandeja", 2.2)
		return
	if kit_available and flat_dist(p, KIT_POS) < 2.4:
		kit_available = false
		ampoules += 1
		for c in kit_cross:
			c.visible = false
		play("pickup")
		hud.say("Tomas una ampolla del botiquín. Úsala con AMPOLLA (R).")
		return
	hud.say("No hay nada que usar aquí.", 1.5)


func try_force() -> void:
	if dying or done:
		return
	var p := player.global_position
	if cart.state == IceCart.S.FROZEN and flat_dist(p, IceCart.HOME) < 3.4:
		if reserve > FORCE_COST:
			reserve -= FORCE_COST
			cart.start()
			for patrol in guards:
				patrol.stand_down()
			play("ice", -2.0)
			hud.say("Fuerza prestada (−35): el carro se desprende.")
			_set_objective()
		else:
			force_fails += 1
			play("alarm")
			hud.say("Reserva insuficiente. Hay una ampolla en el botiquín de servicio, cerca del carro.", 5.0)
	else:
		hud.say("No hay nada que mover con fuerza aquí.", 1.5)


func request_restart() -> void:
	if done or dying:
		return
	_begin_respawn(0.5, true)


func die() -> void:
	if dying or done:
		return
	_begin_respawn(DEATH_DURATION)
	player.pose_death(0.0)
	hud.fade_target = 0.0
	hud.flash = 1.0
	play("body_fall")
	hud.say("Sin reserva. Vuelves al punto de control.", 2.5)


func _begin_respawn(delay: float, keep_restart_touch: bool = false) -> void:
	dying = true
	death_t = delay
	player.lock_for_respawn()
	cart.set_physics_process(false)
	hud.prepare_respawn(keep_restart_touch)
	hud.fade_target = 1.0
	_update_objective_highlights()


func _respawn() -> void:
	dying = false
	reserve = MAX_RESERVE
	ampoules = 0
	kit_available = true
	for c in kit_cross:
		c.visible = true
	grate_open = false
	combat = false
	route = ""
	grate_shape.set_deferred("disabled", false)
	grate_plate.position = GRATE_CENTER + Vector3(0.0, -0.05, 0.0)
	grate_plate.visible = true
	grate_light.light_energy = 0.0
	if grate_steam:
		grate_steam.emitting = false
	tray.reset()
	for patrol in guards:
		patrol.reset()
	lamp.reset()
	if dock_lamp != null:
		dock_lamp.reset()
		metal_noise_cooldown = 0.0
	cart.reset()
	cart.set_physics_process(true)
	player.respawn_at(checkpoint)
	hud.reset_touches()
	hud.fade_target = 0.0
	_set_objective()


func open_grate() -> void:
	play("grate", -4.0)
	grate_open = true
	grate_shape.set_deferred("disabled", true)
	grate_plate.visible = false
	grate_light.light_energy = 2.0
	if grate_steam:
		grate_steam.emitting = true
	_set_objective()


func finish() -> void:
	if done:
		return
	done = true
	phase = Phase.ENDED
	player.locked = true
	player.set_physics_process(false)
	var secs := int(elapsed)
	var lines: Array[String] = [
		"Ruta tomada: " + route_label(),
		"Combate: " + ("sí" if combat else "no"),
		"Tiempo: %d:%02d" % [secs / 60, secs % 60],
		"Continúa en el capítulo 2.",
	]
	hud.show_end(lines)
	hud.objective = ""
	hud.prompts = []
	_update_objective_highlights()


func _cycle_quality() -> void:
	Quality.cycle()
	Quality.apply(get_viewport(), quality_env)


func _on_settings_toggled(open: bool) -> void:
	if open and updater.state == Updater.S.IDLE:
		updater.check()


func _open_update() -> void:
	update_opened = true
	if not Gfx.headless:
		OS.shell_open(RELEASE_URL)


func _play_again() -> void:
	get_tree().reload_current_scene()


func skip_tutorial() -> void:
	cam_progress = 1.0
	_open_door()
	door_body.position.y = 4.8


# ---------------------------------------------------------------- eventos

func _on_cam_drag(d: Vector2) -> void:
	player.rotate_cam(d)
	if tutorial_step == 1:
		cam_progress = clampf(player.cam_total / CAM_GOAL, 0.0, 1.0)
		if cam_progress >= 1.0:
			_open_door()


func _open_door() -> void:
	if door_open:
		return
	door_open = true
	door_shape.set_deferred("disabled", true)
	tutorial_step = 2
	play("door")
	hud.say("La puerta se abrió.", 2.5)
	_set_objective()


func _on_tray_arrived(pos: Vector3) -> void:
	play("clang")
	lamp.attract(pos)
	for patrol in guards:
		patrol.investigate(pos)
	hud.say("¡Clang! La lámpara y el guardia miran hacia la bandeja.", 4.0)
	think("ruido", 4.6)


func _on_lamp_signal() -> void:
	signals_heard += 1
	if player.global_position.x < DOOR_X + 1.0:
		return
	play("beep")
	hud.show_banner("CAMBIO DE LOTE", 0.9)
	think("lampara", 1.5)


func _on_lamp_spotted() -> void:
	hud.say("¡La lámpara te encontró!", 2.5)
	guard.alert(player.global_position)


func _on_dock_lamp_signal() -> void:
	if phase == Phase.PLAY and not dying and player.global_position.x < DIVIDER_X:
		play("beep")
		hud.show_banner("LÁMPARA DE DESEMBARCO", dock_lamp.signal_time)


func _on_dock_lamp_spotted() -> void:
	lookout.investigate(player.global_position)
	hud.say("El vigía revisa la luz de desembarco.", 2.0)


func _update_metal_floor(delta: float) -> void:
	metal_noise_cooldown = maxf(0.0, metal_noise_cooldown - delta)
	if metal_noise_cooldown > 0.0 or phase != Phase.PLAY or dying or not player.is_on_floor():
		return
	var p := player.global_position
	if not METAL_FLOOR.has_point(Vector2(p.x, p.z)):
		return
	var motion := player.get_real_velocity()
	if Vector2(motion.x, motion.z).length() <= METAL_NOISE_SPEED:
		return
	metal_noise_cooldown = METAL_NOISE_INTERVAL
	play("paso_metal_mojado", -8.0)
	lookout.investigate(p)


func _on_cart_rolling() -> void:
	play("cart_roll", -3.0)


func _on_cart_arrived() -> void:
	play("thud")
	play("gong", -4.0)
	open_grate()
	hud.say("Sira: «Oigo el golpe doble en el pozo. Bajo.»", 4.0)


func _set_objective() -> void:
	if tutorial_step == 1:
		hud.objective = "Arrastra un dedo en la mitad derecha para mover la cámara"
	elif tutorial_step == 2:
		hud.objective = "Camina hasta la puerta (stick en la mitad izquierda)"
		hud.obj_ratio = -1.0
	elif grate_open:
		hud.objective = "Baja por el hueco de la rejilla"
	elif cart.state != IceCart.S.FROZEN:
		hud.objective = "El carro se mueve…"
	else:
		hud.objective = "Llega al carro de hielo. Norte: sigilo con la bandeja · Sur: guardia"
	_update_objective_highlights()


func objective_marker_target() -> Node3D:
	if phase != Phase.PLAY or dying:
		return null
	if grate_open:
		return grate_plate
	if cart.state != IceCart.S.FROZEN:
		return null
	if tray.state == Tray.S.READY and route == "":
		return tray
	return cart.body


func _update_objective_highlights() -> void:
	var target := objective_marker_target()
	var pulse := 0.18 + 0.12 * (0.5 + 0.5 * sin(elapsed * TAU / 1.5))
	_set_objective_emission(tray.objective_material, pulse if target == tray else 0.0)
	_set_objective_emission(cart.objective_material, pulse if target == cart.body else 0.0)


func _set_objective_emission(material: BaseMaterial3D, energy: float) -> void:
	if is_equal_approx(material.emission_energy_multiplier, energy) and material.emission_enabled == (energy > 0.0):
		return
	material.emission_enabled = energy > 0.0
	material.emission = Color(1.0, 0.73, 0.32)
	material.emission_energy_multiplier = energy


# ---------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_update_audio(delta)
	_update_objective_highlights()
	player.touch_move = hud.move_vec
	if Input.is_action_just_pressed("hook"):
		player.do_hook()
	if Input.is_action_just_pressed("dodge"):
		player.do_dodge()
	if Input.is_action_just_pressed("force"):
		try_force()
	if Input.is_action_just_pressed("action"):
		do_action()
	if Input.is_action_just_pressed("ampoule"):
		use_ampoule()
	if Input.is_action_just_pressed("restart_cp"):
		request_restart()


func _physics_process(delta: float) -> void:
	hitstop_t = maxf(0.0, hitstop_t - delta)
	if not done:
		elapsed += delta
	if door_open and door_body.position.y < 4.8:
		door_body.position.y = minf(4.8, door_body.position.y + 3.0 * delta)
	elif door_open and door_body.visible:
		door_body.visible = false
	if dying:
		death_t = maxf(0.0, death_t - delta)
		if player.death_animating:
			player.pose_death(1.0 - death_t / DEATH_DURATION)
			if death_t <= DEATH_FADE_TIME:
				hud.fade_target = 1.0
		if is_zero_approx(death_t):
			_respawn()
	if tutorial_step == 1:
		hud.obj_ratio = cam_progress
	_check_progress()
	if lookout != null:
		_update_metal_floor(delta)
	_tick_thoughts(delta)
	_update_prompts()


func _check_progress() -> void:
	var p := player.global_position
	if tutorial_step == 2 and p.x > DOOR_X + 0.6:
		tutorial_step = 0
		phase = Phase.PLAY
		checkpoint_saved = true
		checkpoint = CHECK_POS
		hud.say("Punto de control guardado.", 3.0)
		think("entra", 3.6)
		_set_objective()
	if route == "" and p.x > DIVIDER_X + 0.4 and absf(p.z) > 3.0:
		route = "norte" if p.z < 0.0 else "sur"
	if grate_open and p.y < -0.5 and not done:
		finish()


func _update_prompts() -> void:
	var lines: Array[String] = []
	var cost := 0.0
	var p := player.global_position
	if not done and not dying and flat_dist(p, DESK_POS) < 2.4:
		lines.append("ACCIÓN: leer los folios de la mesa")
	if phase == Phase.PLAY and not done and not dying:
		if dock_lamp != null and p.x < 0.5 and p.z > 3.4 and p.z < 5.2:
			lines.append("Desembarco: espera la campana y cruza fuera del haz")
		elif lookout != null and METAL_FLOOR.grow(0.7).has_point(Vector2(p.x, p.z)):
			lines.append("Camina despacio sobre las placas")
		if tray.state == Tray.S.READY and flat_dist(p, tray.start_pos()) < 2.4:
			lines.append("ACCIÓN: empujar la bandeja")
		if kit_available and flat_dist(p, KIT_POS) < 2.4:
			lines.append("ACCIÓN: abrir el botiquín de servicio")
		if cart.state == IceCart.S.FROZEN and flat_dist(p, IceCart.HOME) < 3.4:
			cost = FORCE_COST
			lines.append("FUERZA: arrancar el carro (cuesta %d)" % int(FORCE_COST))
	hud.prompts = lines
	hud.cost_preview = cost
