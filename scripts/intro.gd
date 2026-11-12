class_name Intro
extends Control
## Introducción en seis cartelas con imagen (assets/intro/intro_01..06.png). Si falta una imagen
## se muestra la cartela sobre fondo oscuro. Toque o Espacio avanzan; «Saltar» pasa al juego.

const MAIN_SCENE := "res://scenes/main.tscn"
const IMAGE_DIR := "res://assets/intro/"
const AUTO_SECONDS := 7.5
const FADE := 0.6
const LINES: Array[String] = [
	"Jaula de inspección. La aguja fija no coincide con el vaso de presión, que vibra.",
	"En la galería que el tablero marca como vacía hay ropa tendida y una niña repasando las tablas.",
	"Sira lee una orden: abrir el depósito en la tercera señal. Manda una copia por el tubo neumático a Tesa.",
	"Roque sube la jaula vacía y cierra la rejilla superior desde la pasarela.",
	"Sira busca un rebosadero. El agua la golpea contra un pilote.",
	"Dos golpes en un tubo hueco. Tesa baja por el drenaje y encuentra a Sira sin pulso.",
]

var index := 0
var t := 0.0
var font: Font
var images: Array = []
var finished := false
var launched := false


func _ready() -> void:
	font = ThemeDB.fallback_font
	for i in LINES.size():
		var path := IMAGE_DIR + "intro_%02d.png" % (i + 1)
		images.append(load(path) if ResourceLoader.exists(path) else null)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func skip_rect() -> Rect2:
	var vs := view_size()
	return Rect2(vs.x - 190.0, 40.0, 150.0, 48.0)


func advance() -> void:
	if t < 0.35:
		return
	index += 1
	t = 0.0
	if index >= LINES.size():
		finish()


func finish() -> void:
	finished = true


func _process(delta: float) -> void:
	t += delta
	if not finished and t >= AUTO_SECONDS:
		advance()
	if finished and not launched:
		launched = true
		get_tree().change_scene_to_file(MAIN_SCENE)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if skip_rect().has_point(st.position):
				finish()
			else:
				advance()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_ESCAPE:
				finish()
			elif k.keycode == KEY_ENTER or k.keycode == KEY_SPACE:
				advance()


func _draw() -> void:
	var vs := view_size()
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	var i := mini(index, LINES.size() - 1)
	var alpha := clampf(t / FADE, 0.0, 1.0) * clampf((AUTO_SECONDS - t) / FADE + 1.0, 0.0, 1.0)
	var img := images[i] as Texture2D
	if img:
		var ts := img.get_size()
		var zoom := 1.0 + 0.06 * clampf(t / AUTO_SECONDS, 0.0, 1.0)
		var sz := ts * maxf(vs.x / ts.x, vs.y / ts.y) * zoom
		draw_texture_rect(img, Rect2((vs - sz) * 0.5, sz), false, Color(1, 1, 1, alpha))
	# Banda del texto.
	var band := Rect2(0.0, vs.y - 190.0, vs.x, 190.0)
	draw_rect(band, Color(0, 0, 0, 0.72 * alpha))
	draw_line(Vector2(80.0, band.position.y + 6.0), Vector2(vs.x - 80.0, band.position.y + 6.0), Color(0.75, 0.55, 0.28, 0.7 * alpha), 2.0)
	draw_multiline_string(font, Vector2(120.0, band.position.y + 70.0), LINES[i], HORIZONTAL_ALIGNMENT_LEFT, vs.x - 240.0, 32, 3, Color(0.93, 0.92, 0.86, alpha))
	draw_string(font, Vector2(120.0, vs.y - 24.0), "Toca para continuar   %d / %d" % [i + 1, LINES.size()], HORIZONTAL_ALIGNMENT_LEFT, 500.0, 18, Color(0.7, 0.72, 0.75, alpha))
	var sk := skip_rect()
	draw_rect(sk, Color(0.1, 0.1, 0.12, 0.8))
	draw_rect(sk, Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, Vector2(sk.position.x, sk.position.y + 33.0), "Saltar", HORIZONTAL_ALIGNMENT_CENTER, sk.size.x, 22, Color.WHITE)
