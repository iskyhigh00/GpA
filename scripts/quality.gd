class_name Quality
extends RefCounted
## Calidad gráfica elegible en Ajustes (calor y batería frente a nitidez). Se guarda en el teléfono.

const NAMES: Array[String] = ["Baja", "Media", "Alta"]
const SAVE_PATH := "user://calidad.cfg"
const DETAIL: Array[String] = [
	"3D al 60% · 30 FPS · sin brillo",
	"3D al 70% · 40 FPS · sin brillo",
	"3D al 100% · 60 FPS · brillo y suavizado",
]

static var level := 1


static func load_saved() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		level = clampi(int(cf.get_value("grafico", "nivel", 1)), 0, NAMES.size() - 1)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("grafico", "nivel", level)
	cf.save(SAVE_PATH)


static func cycle() -> void:
	level = (level + 1) % NAMES.size()
	save()


static func label() -> String:
	return "Calidad gráfica: " + NAMES[level]


static func apply(vp: Viewport, env: Environment) -> void:
	var s := [0.6, 0.7, 1.0][level] as float
	var fps := [30, 40, 60][level] as int
	var shadow := [1024, 1024, 2048][level] as int
	vp.scaling_3d_scale = s
	vp.msaa_3d = Viewport.MSAA_2X if level == 2 else Viewport.MSAA_DISABLED
	Engine.max_fps = fps
	RenderingServer.directional_shadow_atlas_set_size(shadow, true)
	if env:
		env.glow_enabled = level == 2
