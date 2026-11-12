class_name PortAtmosphere
extends Node3D
## Ambiente de la lonja. Todos los emisores se reutilizan durante el nivel.

enum Zone { CLINIC, MARKET, YARD }

const AMBIENT: Array[Color] = [Color(0.65, 0.51, 0.37), Color(0.40, 0.49, 0.64), Color(0.39, 0.57, 0.47)]
const FOG: Array[Color] = [Color(0.14, 0.10, 0.07), Color(0.07, 0.11, 0.16), Color(0.08, 0.15, 0.12)]
const DRIP_FALL := 0.56
const DRIP_SAMPLE_START := 3.59
const DRIP_SAMPLE_LENGTH := 0.38
const DRIP_AUDIO := "res://assets/audio/juego/amb_goteo.ogg"

class SteamJet:
	var emitter: CPUParticles3D
	var period: float
	var clock: float

class Drip:
	var drop: MeshInstance3D
	var splash: CPUParticles3D
	var sound: AudioStreamPlayer3D
	var floor: Vector3
	var height: float
	var period: float
	var clock: float

var environment: Environment
var player: Node3D
var dust: Array[CPUParticles3D] = []
var steam: Array[SteamJet] = []
var drips: Array[Drip] = []
var effects_enabled := false


static func zone_at(pos: Vector3) -> Zone:
	if pos.x < Level.DOOR_X:
		return Zone.CLINIC
	if pos.x > Level.DIVIDER_X:
		return Zone.YARD
	return Zone.MARKET


func _tag(node: Node3D, zone: Zone) -> void:
	node.set_meta("atmosphere_zone", zone)
	add_child(node)


func build(player_node: Node3D, env: Environment) -> void:
	player = player_node
	environment = env
	add_steam(Vector3(-0.8, 2.67, -9.74), Vector3(0.15, 0.7, 0.85), 4.3, 2.6)
	add_steam(Vector3(6.4, 2.18, -9.78), Vector3(-0.25, 0.55, 1.0), 5.7, 2.0)
	var stream := load(DRIP_AUDIO) as AudioStreamOggVorbis
	if stream != null:
		stream = stream.duplicate() as AudioStreamOggVorbis
		stream.loop = false
	add_drip(Vector3(-11.2, 0.022, -3.45), 2.92, 6.1, 3.4, stream)
	add_drip(Vector3(6.5, 0.022, -7.5), 3.34, 4.9, 2.8, stream)
	add_drip(Vector3(18.4, 0.022, 5.9), 3.3, 6.7, 2.2, stream)
	_update_color(player.position, 1.0)


func add_beam(from: Vector3, to: Vector3, tint: Color) -> void:
	var beam := to - from
	var particles := _particles("PolvoVitral", 14, 4.5, Vector2(0.043, 0.043), Color(tint, 0.72))
	particles.transform = Transform3D(Basis.looking_at(beam, Vector3.UP), from.lerp(to, 0.5))
	particles.local_coords = true
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.23, 0.23, beam.length() * 0.42)
	particles.direction = Vector3(0.12, 0.25, -1.0)
	particles.spread = 24.0
	particles.initial_velocity_min = 0.025
	particles.initial_velocity_max = 0.08
	particles.gravity = Vector3.ZERO
	particles.preprocess = 3.0
	_tag(particles, zone_at(from))
	dust.append(particles)


func add_steam(pos: Vector3, direction: Vector3, period: float, offset: float) -> void:
	var jet := SteamJet.new()
	jet.period = period
	jet.clock = offset
	jet.emitter = _particles("VaporTuberia", 12, 1.65, Vector2(0.35, 0.35), Color(0.73, 0.82, 0.90, 0.32))
	jet.emitter.position = pos
	jet.emitter.one_shot = true
	jet.emitter.explosiveness = 0.78
	jet.emitter.direction = direction.normalized()
	jet.emitter.spread = 24.0
	jet.emitter.initial_velocity_min = 0.5
	jet.emitter.initial_velocity_max = 1.25
	jet.emitter.gravity = Vector3(0.0, 0.35, 0.0)
	jet.emitter.scale_amount_min = 0.55
	jet.emitter.scale_amount_max = 1.35
	var scale_growth := Curve.new()
	scale_growth.add_point(Vector2(0.0, 0.48))
	scale_growth.add_point(Vector2(0.35, 0.84))
	scale_growth.add_point(Vector2(1.0, 1.0))
	jet.emitter.scale_amount_curve = scale_growth
	_tag(jet.emitter, zone_at(pos))
	steam.append(jet)


func add_drip(floor_pos: Vector3, height: float, period: float, offset: float, stream: AudioStream) -> void:
	var drip := Drip.new()
	drip.floor = floor_pos
	drip.height = height
	drip.period = period
	drip.clock = offset
	var zone := zone_at(floor_pos)
	drip.drop = Gfx.sphere_m(0.018, Gfx.glow_mat(Color(0.62, 0.78, 0.87, 0.75)))
	drip.drop.name = "Gota"
	drip.drop.scale = Vector3(0.63, 2.1, 0.63)
	Gfx.no_shadow(drip.drop)
	drip.drop.position = floor_pos + Vector3.UP * height
	drip.drop.hide()
	_tag(drip.drop, zone)
	drip.splash = _particles("Salpicadura", 7, 0.24, Vector2(0.028, 0.028), Color(0.55, 0.74, 0.85, 0.8))
	drip.splash.position = floor_pos
	drip.splash.one_shot = true
	drip.splash.explosiveness = 1.0
	drip.splash.direction = Vector3.UP
	drip.splash.spread = 61.0
	drip.splash.initial_velocity_min = 0.50
	drip.splash.initial_velocity_max = 1.22
	drip.splash.gravity = Vector3(0.0, -5.0, 0.0)
	_tag(drip.splash, zone)
	drip.sound = AudioStreamPlayer3D.new()
	drip.sound.name = "GoteoPosicional"
	drip.sound.position = floor_pos
	drip.sound.stream = stream
	drip.sound.max_distance = 7.5
	drip.sound.unit_size = 2.1
	drip.sound.volume_db = -10.0
	_tag(drip.sound, zone)
	drips.append(drip)


func _particles(label: String, count: int, lifetime: float, size: Vector2, color: Color) -> CPUParticles3D:
	var effect := CPUParticles3D.new()
	effect.name = label
	effect.amount = count
	effect.lifetime = lifetime
	effect.emitting = false
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	effect.color_ramp = fade
	if not Gfx.headless:
		var gradient := Gradient.new()
		gradient.set_color(0, color)
		gradient.set_color(1, Color(color, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		var material := Gfx.glow_mat(Color.WHITE)
		material.albedo_texture = texture
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = true
		var mesh := QuadMesh.new()
		mesh.size = size
		mesh.material = material
		effect.mesh = mesh
	return effect


func set_quality(quality: int) -> void:
	effects_enabled = quality > 0
	for beam in dust:
		beam.visible = effects_enabled
		beam.emitting = effects_enabled
	for jet in steam:
		jet.emitter.visible = effects_enabled
		jet.emitter.emitting = false
	for drip in drips:
		drip.drop.hide()
		drip.splash.visible = effects_enabled
		drip.splash.emitting = false
		drip.sound.stop()


func _process(delta: float) -> void:
	if player == null:
		return
	_update_color(player.position, 1.0 - exp(-3.0 * delta))
	if not effects_enabled:
		return
	for jet in steam:
		jet.clock += delta
		if jet.clock >= jet.period:
			jet.clock = fposmod(jet.clock, jet.period)
			jet.emitter.restart()
			jet.emitter.emitting = true
	for drip in drips:
		_update_drip(drip, delta)


func _update_drip(drip: Drip, delta: float) -> void:
	drip.clock += delta
	if drip.clock >= drip.period:
		drip.clock = fposmod(drip.clock, drip.period)
		drip.splash.restart()
		drip.splash.emitting = true
		if not Gfx.headless and drip.sound.stream != null:
			drip.sound.play(DRIP_SAMPLE_START)
	if drip.sound.playing and drip.clock >= DRIP_SAMPLE_LENGTH:
		drip.sound.stop()
	var falling := (drip.clock - (drip.period - DRIP_FALL)) / DRIP_FALL
	drip.drop.visible = falling >= 0.0
	if drip.drop.visible:
		drip.drop.position.y = drip.floor.y + drip.height * (1.0 - falling * falling)


func _update_color(pos: Vector3, amount: float) -> void:
	var enter_market := smoothstep(Level.DOOR_X - 0.65, Level.DOOR_X + 0.65, pos.x)
	var enter_yard := smoothstep(Level.DIVIDER_X - 0.65, Level.DIVIDER_X + 0.65, pos.x)
	var ambient := AMBIENT[Zone.CLINIC].lerp(AMBIENT[Zone.MARKET], enter_market).lerp(AMBIENT[Zone.YARD], enter_yard)
	var fog := FOG[Zone.CLINIC].lerp(FOG[Zone.MARKET], enter_market).lerp(FOG[Zone.YARD], enter_yard)
	environment.ambient_light_color = environment.ambient_light_color.lerp(ambient, amount)
	environment.fog_light_color = environment.fog_light_color.lerp(fog, amount)
