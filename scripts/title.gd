class_name Title
extends Control
## Pantalla de título: arte de fondo, nombre del juego y botón JUGAR.
## Los toques se gestionan a mano (el ratón no se emula desde el toque).

const MAIN_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const BG_PATH := "res://assets/arte/titulo.jpg"
const AMBER := Color(0.95, 0.72, 0.3)

var bg: Texture2D
var font: Font
var t := 0.0
var starting := false
var fade_out := 0.0
var launched := false
var version_text := ""


func _ready() -> void:
	font = ThemeDB.fallback_font
	bg = load(BG_PATH) as Texture2D
	if FileAccess.file_exists("res://version.txt"):
		version_text = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func play_rect() -> Rect2:
	var vs := view_size()
	return Rect2(vs.x * 0.5 - 170.0, vs.y - 200.0, 340.0, 84.0)


func start_game() -> void:
	if t < 0.5:
		return # evita un toque accidental justo al abrir
	starting = true


func _process(delta: float) -> void:
	t += delta
	if starting:
		fade_out = minf(1.0, fade_out + delta * 3.0)
		if fade_out >= 1.0 and not launched:
			launched = true
			get_tree().change_scene_to_file(INTRO_SCENE)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and play_rect().has_point(st.position):
			start_game()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_SPACE):
			start_game()


func _text(pos: Vector2, s: String, size: int, col: Color, width: float, outline: int = 8) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, outline, Color(0, 0, 0, 0.9))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _draw() -> void:
	var vs := view_size()
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	if bg:
		var ts := bg.get_size()
		var zoom := 1.0 + 0.05 * clampf(t / 25.0, 0.0, 1.0)
		var sz := ts * maxf(vs.x / ts.x, vs.y / ts.y) * zoom
		draw_texture_rect(bg, Rect2((vs - sz) * 0.5, sz), false)
	# Degradados para que el texto se lea sobre la imagen.
	var top_h := vs.y * 0.4
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, top_h), Vector2(0, top_h)]),
		PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
	var bot_y := vs.y * 0.6
	draw_polygon(
		PackedVector2Array([Vector2(0, bot_y), Vector2(vs.x, bot_y), Vector2(vs.x, vs.y), Vector2(0, vs.y)]),
		PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.85)]))
	var title_size := int(clampf(vs.y * 0.12, 44.0, 96.0))
	_text(Vector2(0.0, vs.y * 0.17), "EL TURNO DE LA SAL", title_size, Color(0.96, 0.9, 0.74), vs.x, 10)
	_text(Vector2(0.0, vs.y * 0.17 + 46.0), "Capítulo 1 · La subasta a oscuras", 28, Color(0.78, 0.88, 0.9), vs.x, 6)
	var r := play_rect()
	var pulse := 0.65 + 0.35 * sin(t * 2.4)
	draw_rect(r, Color(0.06, 0.12, 0.15, 0.88))
	draw_rect(r, Color(AMBER.r, AMBER.g, AMBER.b, pulse), false, 4.0)
	_text(Vector2(r.position.x, r.position.y + 55.0), "JUGAR", 38, Color(1, 0.95, 0.85), r.size.x, 6)
	if version_text != "":
		draw_string(font, Vector2(16.0, vs.y - 14.0), version_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(0.0, vs.y - 14.0), "Modelos: Quaternius · Texturas: Poly Haven (CC0)", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 15, Color(1, 1, 1, 0.5))
	var black := maxf(1.0 - t / 0.8, fade_out)
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, black))
