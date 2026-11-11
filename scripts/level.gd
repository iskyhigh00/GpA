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
const CAM_GOAL := 1.5
const KIT_POS := Vector3(16.5, 0.0, -3.5)
const GRATE_CENTER := Vector3(17.0, 0.0, 4.5)
const NAV_POINTS: Array[Vector3] = [
	Vector3(-6.3, 0.1, 0.0), Vector3(-3.7, 0.1, 0.0),
	Vector3(7.0, 0.1, -6.5), Vector3(11.0, 0.1, -6.5),
	Vector3(7.0, 0.1, 6.5), Vector3(11.0, 0.1, 6.5),
]
const WALL := Color(0.34, 0.39, 0.44)

var phase: Phase = Phase.TUTORIAL
var tutorial_step := 1
var player: Player
var guard: Guard
var lamp: RailLamp
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
var music_player: AudioStreamPlayer
var hitstop_t := 0.0

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
	_build_world()
	_build_entities()
	_build_hud()
	_set_objective()
	if not Gfx.headless:
		music_player = AudioStreamPlayer.new()
		music_player.stream = Sfx.music()
		music_player.volume_db = -13.0
		add_child(music_player)
		music_player.play()


func _exit_tree() -> void:
	for ap in pool:
		ap.stop()
		ap.stream = null
	if music_player:
		music_player.stop()


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
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.88
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
	moon.light_color = Color(0.55, 0.68, 0.95)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 38.0
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
	Gfx.solid_m(self, Vector3(cx, 1.6, cz), Vector3(sx, 3.2, sz), m if m else Gfx.mat_stone())
	# Moldura superior oscura.
	var cap := Gfx.box_m(Vector3(sx + 0.12, 0.14, sz + 0.12), Gfx.mat_rust())
	cap.position = Vector3(cx, 3.27, cz)
	add_child(cap)


func _pipe_x(x0: float, x1: float, y: float, z: float, r: float) -> void:
	var p := Gfx.cyl_m(r, absf(x1 - x0), Gfx.mat_rust())
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


func _crate(pos: Vector3, size: Vector3) -> void:
	var b := Gfx.solid_m(self, pos, size, Gfx.mat_wood(), 2)
	for sy in [-1.0, 1.0]:
		var slat := Gfx.box_m(Vector3(size.x + 0.04, 0.07, size.z + 0.04), Gfx.mat_gloss(Color(0.1, 0.07, 0.05), 0.7))
		slat.position = Vector3(0.0, sy * (size.y * 0.5 - 0.05), 0.0)
		b.add_child(slat)


func _stall(pos: Vector3, size: Vector3) -> void:
	var b := Gfx.solid_m(self, pos, size, Gfx.mat_wood(), 2)
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
	add_child(l)


func _puddle(x: float, z: float, r: float) -> void:
	var p := Gfx.cyl_m(r, 0.01, Gfx.mat_gloss(Color(0.02, 0.03, 0.04), 0.03))
	p.position = Vector3(x, 0.02, z)
	Gfx.no_shadow(p)
	add_child(p)


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
	dust.amount = 90
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
	grate_steam = GPUParticles3D.new()
	grate_steam.amount = 24
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
	_wall(DIVIDER_X, -9.0, 0.4, 2.0)
	_wall(DIVIDER_X, 0.0, 0.4, 10.0)
	_wall(DIVIDER_X, 9.0, 0.4, 2.0)
	# Pilastras en el muro norte y este (no estorban las rutas).
	for x in [-2.0, 3.0, 13.0, 19.0]:
		Gfx.solid_m(self, Vector3(x, 1.6, -9.75), Vector3(0.7, 3.2, 0.5), Gfx.mat_rust(), 1)
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
	var cot := Gfx.prop_box(self, Vector3(-12.5, 0.4, -2.5), Vector3(2.0, 0.8, 0.9), Color(0.8, 0.82, 0.85))
	var blanket := Gfx.box_m(Vector3(1.2, 0.12, 0.95), Gfx.mat_cloth(Color(0.35, 0.12, 0.14)))
	blanket.position = Vector3(0.35, 0.44, 0.0)
	cot.add_child(blanket)
	var desk := Gfx.solid_m(self, Vector3(-13.5, 0.5, 2.8), Vector3(1.6, 1.0, 0.8), Gfx.mat_wood(), 2)
	for i in 3:
		var vial := Gfx.cyl_m(0.04, 0.16, Gfx.mat_glow(Color(0.85, 0.1, 0.2), 1.2))
		vial.position = Vector3(-0.4 + i * 0.25, 0.58, 0.0)
		desk.add_child(vial)
	var win := Gfx.box_m(Vector3(0.05, 1.4, 2.0), Gfx.mat_glow(Color(0.45, 0.6, 0.9), 1.4))
	win.position = Vector3(-14.95, 2.0, -0.5)
	add_child(win)
	var stain := Gfx.cyl_m(0.7, 0.01, Gfx.mat_cloth(Color(0.3, 0.03, 0.04)))
	stain.position = Vector3(-8.0, 0.025, 1.5)
	add_child(stain)
	_sign("CONSULTORIO", Vector3(-4.8, 2.85, 0.0), 90.0, Color(0.85, 0.85, 0.75), 0.008)
	_hang_lamp(-10.0, 0.0)
	# Lonja: puestos, cajas, barriles.
	_stall(Vector3(3.0, 0.5, 3.0), Vector3(1.6, 1.0, 1.2))
	_stall(Vector3(1.0, 0.5, -2.5), Vector3(1.4, 1.0, 1.0))
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
	_sign("LOTE 14", Vector3(17.0, 2.4, 9.93), 180.0, Color(0.85, 0.35, 0.3), 0.012)
	_sign("SUBASTA POR SECTORES", Vector3(-1.0, 2.5, 9.93), 180.0, Color(0.75, 0.8, 0.85), 0.01)
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
	Gfx.solid_m(self, Vector3(19.7, 1.0, 0.0), Vector3(0.5, 2.0, 1.4), Gfx.mat_rust(), 2)
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
	grate_plate.add_child(Gfx.box_m(Vector3(2.0, 0.1, 2.0), Gfx.mat_rust()))
	for i in 5:
		var bar := Gfx.box_m(Vector3(0.08, 0.06, 2.0), Gfx.mat_gloss(Color(0.12, 0.12, 0.13), 0.4))
		bar.position = Vector3(-0.8 + i * 0.4, 0.06, 0.0)
		grate_plate.add_child(bar)
	add_child(grate_plate)
	_build_particles()


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


# ---------------------------------------------------------------- utilidades

func play(sound: String, vol_db: float = 0.0) -> void:
	var s: AudioStream = sounds.get(sound)
	if s == null or Gfx.headless:
		return
	var ap := pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	ap.stream = s
	ap.volume_db = vol_db
	ap.play()


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0.0, 0.6, 0.0), b + Vector3(0.0, 0.6, 0.0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Siguiente punto a seguir para ir de «from» a «to» rodeando los muros (grafo pequeño de pasos).
func next_step(from: Vector3, to: Vector3) -> Vector3:
	if clear_line(from, to):
		return to
	var pts: Array[Vector3] = [from, to]
	pts.append_array(NAV_POINTS)
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
	return "Norte (sigilo)" if route != "sur" else "Sur (combate)"


# ---------------------------------------------------------------- reserva

func spend_hook() -> void:
	reserve = maxf(1.0, reserve - HOOK_COST)


func spend(amount: float) -> void:
	reserve = maxf(0.0, reserve - amount)
	if reserve <= 0.0:
		die()


func hurt_player(dmg: float) -> void:
	if player.hurt_cd > 0.0 or player.invuln > 0.0 or dying or done:
		return
	player.hurt_cd = 0.8
	player.add_shake(0.35)
	hud.flash = 1.0
	play("hit")
	spend(dmg)


func on_guard_hit(_hits: int, pos: Vector3) -> void:
	combat = true
	play("hit")
	hitstop_t = 0.07
	player.add_shake(0.2)
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


func on_guard_alert() -> void:
	hud.say("¡El guardia te vio!", 2.5)
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
	if tray.state == Tray.S.READY and flat_dist(p, tray.start_pos()) < 2.4:
		tray.push()
		play("push")
		hud.say("Empujas la bandeja por el carril…")
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
			guard.stand_down()
			play("rumble")
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
	death_t = 0.5
	dying = true
	player.locked = true
	hud.fade_target = 1.0


func die() -> void:
	if dying or done:
		return
	dying = true
	death_t = 1.0
	player.locked = true
	hud.fade_target = 1.0
	hud.flash = 1.0
	hud.say("Sin reserva. Vuelves al punto de control.", 2.5)


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
	guard.reset()
	lamp.reset()
	cart.reset()
	player.respawn_at(checkpoint)
	hud.fade_target = 0.0
	_set_objective()


func open_grate() -> void:
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
	]
	hud.show_end(lines)
	hud.objective = ""
	hud.prompts = []


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
	guard.investigate(pos)
	hud.say("¡Clang! La lámpara y el guardia miran hacia la bandeja.", 4.0)


func _on_lamp_signal() -> void:
	signals_heard += 1
	play("beep")
	hud.show_banner("CAMBIO DE LOTE", 0.9)


func _on_lamp_spotted() -> void:
	hud.say("¡La lámpara te encontró!", 2.5)
	guard.alert(player.global_position)


func _on_cart_rolling() -> void:
	play("rumble")


func _on_cart_arrived() -> void:
	play("thud")
	open_grate()
	hud.say("La rejilla se abre. Baja por el hueco.", 4.0)


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


# ---------------------------------------------------------------- bucle

func _process(_delta: float) -> void:
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
	if dying:
		death_t -= delta
		if death_t <= 0.0:
			_respawn()
	if tutorial_step == 1:
		hud.obj_ratio = cam_progress
	_check_progress()
	_update_prompts()


func _check_progress() -> void:
	var p := player.global_position
	if tutorial_step == 2 and p.x > DOOR_X + 0.6:
		tutorial_step = 0
		phase = Phase.PLAY
		checkpoint_saved = true
		checkpoint = CHECK_POS
		hud.say("Punto de control guardado.", 3.0)
		_set_objective()
	if route == "" and p.x > DIVIDER_X + 0.4 and absf(p.z) > 3.0:
		route = "norte" if p.z < 0.0 else "sur"
	if grate_open and p.y < -0.5 and not done:
		finish()


func _update_prompts() -> void:
	var lines: Array[String] = []
	var cost := 0.0
	var p := player.global_position
	if phase == Phase.PLAY and not done and not dying:
		if tray.state == Tray.S.READY and flat_dist(p, tray.start_pos()) < 2.4:
			lines.append("ACCIÓN: empujar la bandeja")
		if kit_available and flat_dist(p, KIT_POS) < 2.4:
			lines.append("ACCIÓN: abrir el botiquín de servicio")
		if cart.state == IceCart.S.FROZEN and flat_dist(p, IceCart.HOME) < 3.4:
			cost = FORCE_COST
			lines.append("FUERZA: arrancar el carro (cuesta %d)" % int(FORCE_COST))
	hud.prompts = lines
	hud.cost_preview = cost
