class_name Hud
extends CanvasLayer
## Interfaz táctil: stick flotante, arrastre de cámara, botones, barra de reserva y mensajes.
## Los toques se gestionan a mano en _input (multitáctil, sin ratón emulado).

signal hook_pressed
signal dodge_pressed
signal force_pressed
signal action_pressed
signal ampoule_pressed
signal restart_pressed
signal settings_toggled(open: bool)
signal docs_toggled(open: bool)
signal dialogue_finished
signal update_pressed
signal browser_pressed
signal quality_pressed
signal play_again_pressed
signal cam_dragged(delta: Vector2)

const STICK_RADIUS := 90.0
const DEADZONE := 0.15
const BAR_POS := Vector2(24.0, 44.0)
const BAR_SIZE := Vector2(380.0, 26.0)

var level: Level
var canvas: Control
var font: Font
var touches: Dictionary = {}
var stick_index := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var move_vec := Vector2.ZERO
var held: Dictionary = {}
var message := ""
var message_t := 0.0
var last_message := ""
var message_log: Array[String] = []
var banner := ""
var banner_t := 0.0
var objective := ""
var obj_ratio := -1.0
var prompts: Array[String] = []
var cost_preview := 0.0
var fade := 0.0
var fade_target := 0.0
var flash := 0.0
var end_visible := false
var end_lines: Array[String] = []
var time := 0.0
var vignette: GradientTexture2D
var settings_visible := false
var doc_visible := false
var dialog_visible := false
var dialog_lines: Array[String] = []
var dialog_i := 0
var dialog_t := 0.0
var doc_list: Array[Dictionary] = []
var doc_page := 0
var version_text := "dev"
var updater: Updater


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists("res://version.txt"):
		version_text = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	font = ThemeDB.fallback_font
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_ui)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.7))
	g.set_offset(0, 0.55)
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 0.5)
	vignette.width = 128
	vignette.height = 128


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func buttons() -> Dictionary:
	var vs := view_size()
	return {
		"hook": {"c": Vector2(vs.x - 125.0, vs.y - 125.0), "r": 66.0, "t": "GANCHO"},
		"dodge": {"c": Vector2(vs.x - 270.0, vs.y - 70.0), "r": 46.0, "t": "ESQUIVA"},
		"force": {"c": Vector2(vs.x - 285.0, vs.y - 185.0), "r": 46.0, "t": "FUERZA"},
		"action": {"c": Vector2(vs.x - 190.0, vs.y - 285.0), "r": 46.0, "t": "ACCIÓN"},
		"ampoule": {"c": Vector2(vs.x - 75.0, vs.y - 285.0), "r": 46.0, "t": "AMPOLLA"},
		"restart": {"c": Vector2(vs.x - 44.0, 44.0), "r": 26.0, "t": "↻"},
		"settings": {"c": Vector2(vs.x - 104.0, 44.0), "r": 26.0, "t": "⚙"},
	}


func button_center(bname: String) -> Vector2:
	var b: Dictionary = buttons()[bname]
	return b["c"]


func play_again_rect() -> Rect2:
	var vs := view_size()
	return Rect2(vs.x * 0.5 - 160.0, vs.y * 0.5 + 110.0, 320.0, 76.0)


func settings_panel() -> Rect2:
	return Rect2(view_size() * 0.5 - Vector2(260, 230), Vector2(520, 460))


func settings_rect(which: String) -> Rect2:
	var vs := view_size()
	if which == "update":
		return Rect2(vs.x * 0.5 - 200.0, vs.y * 0.5 + 10.0, 400.0, 64.0)
	if which == "quality":
		return Rect2(vs.x * 0.5 - 200.0, vs.y * 0.5 - 84.0, 400.0, 48.0)
	if which == "browser":
		return Rect2(vs.x * 0.5 - 200.0, vs.y * 0.5 + 82.0, 400.0, 44.0)
	return Rect2(vs.x * 0.5 - 200.0, vs.y * 0.5 + 134.0, 400.0, 44.0)


const DIALOG_AUTO := 5.0


func dialog_panel() -> Rect2:
	var vs := view_size()
	return Rect2(vs.x * 0.5 - 480.0, vs.y - 224.0, 960.0, 176.0)


func dialog_skip_rect() -> Rect2:
	var pr := dialog_panel()
	return Rect2(pr.end.x - 150.0, pr.position.y - 46.0, 150.0, 40.0)


## Líneas con formato «Hablante|texto». Toque para avanzar; avanza solo a los 5 s; «Saltar» cierra.
func open_dialogue(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	dialog_lines = lines
	dialog_i = 0
	dialog_t = 0.0
	dialog_visible = true
	get_tree().paused = true
	reset_touches()


func advance_dialogue() -> void:
	dialog_i += 1
	dialog_t = 0.0
	if dialog_i >= dialog_lines.size():
		close_dialogue()


func close_dialogue() -> void:
	if not dialog_visible:
		return
	dialog_visible = false
	get_tree().paused = false
	dialogue_finished.emit()


func doc_panel() -> Rect2:
	var vs := view_size()
	return Rect2(vs.x * 0.5 - 540.0, 36.0, 1080.0, vs.y - 72.0)


func doc_button(which: String) -> Rect2:
	var pr := doc_panel()
	var y := pr.end.y - 64.0
	match which:
		"prev":
			return Rect2(pr.position.x + 24.0, y, 96.0, 48.0)
		"next":
			return Rect2(pr.position.x + 132.0, y, 96.0, 48.0)
		_:
			return Rect2(pr.end.x - 200.0, y, 176.0, 48.0)


func open_docs(list: Array[Dictionary], page: int = 0) -> void:
	if list.is_empty():
		return
	doc_list = list
	doc_page = clampi(page, 0, list.size() - 1)
	doc_visible = true
	get_tree().paused = true
	reset_touches()
	docs_toggled.emit(true)


func close_docs() -> void:
	doc_visible = false
	get_tree().paused = false
	docs_toggled.emit(false)


func set_settings(open: bool) -> void:
	settings_visible = open
	get_tree().paused = open
	reset_touches()
	settings_toggled.emit(open)


func reset_touches() -> void:
	touches.clear()
	stick_index = -1
	move_vec = Vector2.ZERO
	held.clear()


func prepare_respawn(keep_restart_touch: bool) -> void:
	var restart_touches: Array[int] = []
	if keep_restart_touch:
		for index: int in touches:
			var touch: Dictionary = touches[index]
			if touch["role"] == "btn" and touch["name"] == "restart":
				restart_touches.append(index)
	if dialog_visible:
		close_dialogue()
	if doc_visible:
		close_docs()
	if settings_visible:
		set_settings(false)
	else:
		reset_touches()
	for index in restart_touches:
		touches[index] = {"role": "btn", "name": "restart"}
	if not restart_touches.is_empty():
		held["restart"] = restart_touches.size()


func say(text: String, secs: float = 3.5) -> void:
	message = text
	message_t = secs
	last_message = text
	message_log.append(text)
	if message_log.size() > 200:
		message_log.pop_front()


func show_banner(text: String, secs: float = 1.2) -> void:
	banner = text
	banner_t = secs


func show_end(lines: Array[String]) -> void:
	end_lines = lines
	end_visible = true


func _process(delta: float) -> void:
	time += delta
	if dialog_visible:
		dialog_t += delta
		if dialog_t >= DIALOG_AUTO:
			advance_dialogue()
	message_t = maxf(0.0, message_t - delta)
	banner_t = maxf(0.0, banner_t - delta)
	fade = move_toward(fade, fade_target, delta * 2.5)
	flash = maxf(0.0, flash - delta * 2.5)
	canvas.queue_redraw()


# ---------------------------------------------------------------- toques

func _input(event: InputEvent) -> void:
	if doc_visible and (event.is_action_pressed("action") or event.is_action_pressed("ui_cancel")):
		close_docs()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position, d.relative)


func _hit_button(pos: Vector2) -> String:
	var all := buttons()
	for key: String in all:
		var b: Dictionary = all[key]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		if pos.distance_to(c) <= r + 12.0:
			return key
	return ""


func _press(index: int, pos: Vector2) -> void:
	if (level != null and level.dying) or touches.has(index):
		return
	if end_visible:
		if play_again_rect().has_point(pos):
			play_again_pressed.emit()
		return
	if dialog_visible:
		if dialog_skip_rect().has_point(pos):
			close_dialogue()
		else:
			advance_dialogue()
		return
	if doc_visible:
		if doc_button("prev").has_point(pos):
			doc_page = maxi(0, doc_page - 1)
		elif doc_button("next").has_point(pos):
			doc_page = mini(doc_list.size() - 1, doc_page + 1)
		elif doc_button("close").has_point(pos):
			close_docs()
		return
	if settings_visible:
		if settings_rect("update").has_point(pos):
			update_pressed.emit()
		elif settings_rect("quality").has_point(pos):
			quality_pressed.emit()
		elif settings_rect("browser").has_point(pos):
			browser_pressed.emit()
		elif settings_rect("close").has_point(pos) or not settings_panel().has_point(pos):
			set_settings(false)
		return
	var bname := _hit_button(pos)
	if bname == "settings":
		set_settings(true)
		return
	if bname != "":
		touches[index] = {"role": "btn", "name": bname}
		held[bname] = int(held.get(bname, 0)) + 1
		match bname:
			"hook":
				hook_pressed.emit()
			"dodge":
				dodge_pressed.emit()
			"force":
				force_pressed.emit()
			"action":
				action_pressed.emit()
			"ampoule":
				ampoule_pressed.emit()
			"restart":
				restart_pressed.emit()
		return
	if pos.x < view_size().x * 0.5 and stick_index == -1:
		stick_index = index
		stick_origin = pos
		stick_pos = pos
		move_vec = Vector2.ZERO
		touches[index] = {"role": "stick"}
	else:
		touches[index] = {"role": "cam"}


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if not touches.has(index):
		return
	var info: Dictionary = touches[index]
	var role: String = info["role"]
	if role == "stick":
		stick_pos = pos
		var v := (pos - stick_origin) / STICK_RADIUS
		v = v.limit_length(1.0)
		move_vec = Vector2.ZERO if v.length() < DEADZONE else v
	elif role == "cam":
		cam_dragged.emit(rel)


func _release(index: int) -> void:
	if not touches.has(index):
		return
	var info: Dictionary = touches[index]
	var role: String = info["role"]
	if role == "stick":
		stick_index = -1
		move_vec = Vector2.ZERO
	elif role == "btn":
		var bname: String = info["name"]
		held[bname] = maxi(0, int(held.get(bname, 1)) - 1)
	touches.erase(index)


# ---------------------------------------------------------------- dibujo

func _text(pos: Vector2, s: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	canvas.draw_string_outline(font, pos, s, align, width, size, 6, Color(0, 0, 0, 0.85))
	canvas.draw_string(font, pos, s, align, width, size, col)


func _draw_ui() -> void:
	var vs := view_size()
	canvas.draw_texture_rect(vignette, Rect2(Vector2.ZERO, vs), false)
	_draw_bar()
	_draw_texts(vs)
	_draw_controls(vs)
	if flash > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.05, 0.05, flash * 0.35))
	if fade > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.05, 0.0, 0.0, fade))
	if end_visible:
		_draw_end(vs)
	if settings_visible:
		_draw_settings(vs)
	if doc_visible:
		_draw_doc(vs)
	if dialog_visible:
		_draw_dialog(vs)


func _draw_bar() -> void:
	var reserve := 100.0 if level == null else level.reserve
	var ampoules := 0 if level == null else level.ampoules
	_text(Vector2(BAR_POS.x, BAR_POS.y - 10.0), "RESERVA  %d" % int(ceilf(reserve)), 20, Color(0.95, 0.85, 0.85))
	canvas.draw_rect(Rect2(BAR_POS - Vector2(3, 3), BAR_SIZE + Vector2(6, 6)), Color(0, 0, 0, 0.6))
	canvas.draw_rect(Rect2(BAR_POS, BAR_SIZE), Color(0.15, 0.05, 0.07))
	var w := BAR_SIZE.x * clampf(reserve / 100.0, 0.0, 1.0)
	canvas.draw_rect(Rect2(BAR_POS, Vector2(w, BAR_SIZE.y)), Color(0.75, 0.12, 0.2))
	if cost_preview > 0.0:
		var x0 := BAR_SIZE.x * clampf((reserve - cost_preview) / 100.0, 0.0, 1.0)
		var seg := Rect2(BAR_POS + Vector2(x0, 0.0), Vector2(w - x0, BAR_SIZE.y))
		var ok := reserve > cost_preview
		var col := Color(1.0, 0.65, 0.15) if ok else Color(1.0, 0.2, 0.2)
		canvas.draw_rect(seg, Color(col, 0.9))
		canvas.draw_rect(Rect2(BAR_POS + Vector2(x0, -3.0), Vector2(2.0, BAR_SIZE.y + 6.0)), Color.WHITE)
		var label := "−%d" % int(cost_preview) if ok else "−%d  ¡no alcanza!" % int(cost_preview)
		_text(BAR_POS + Vector2(x0 - 6.0, BAR_SIZE.y + 24.0), label, 22, col)
	canvas.draw_rect(Rect2(BAR_POS, BAR_SIZE), Color(1, 1, 1, 0.5), false, 2.0)
	for i in ampoules:
		var p := BAR_POS + Vector2(8.0 + i * 26.0, BAR_SIZE.y + 56.0)
		canvas.draw_rect(Rect2(p, Vector2(14.0, 26.0)), Color(0.85, 0.15, 0.25))
		canvas.draw_rect(Rect2(p + Vector2(3.0, -6.0), Vector2(8.0, 6.0)), Color(0.9, 0.9, 0.95))
	_text(BAR_POS + Vector2(0.0, BAR_SIZE.y + 100.0 if ampoules > 0 else BAR_SIZE.y + 76.0), "Ampollas: %d" % ampoules, 20, Color(0.95, 0.85, 0.85))


func _draw_texts(vs: Vector2) -> void:
	if objective != "":
		_text(Vector2(0.0, 36.0), objective, 24, Color(0.92, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		if obj_ratio >= 0.0:
			var bw := 320.0
			var bp := Vector2(vs.x * 0.5 - bw * 0.5, 52.0)
			canvas.draw_rect(Rect2(bp, Vector2(bw, 12.0)), Color(0, 0, 0, 0.6))
			canvas.draw_rect(Rect2(bp, Vector2(bw * clampf(obj_ratio, 0.0, 1.0), 12.0)), Color(0.4, 0.8, 0.9))
	if message_t > 0.0:
		_text(Vector2(0.0, 120.0), message, 26, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if banner_t > 0.0 and int(time * 8.0) % 2 == 0:
		var bs := Vector2(420.0, 52.0)
		var bp2 := Vector2(vs.x * 0.5 - bs.x * 0.5, 150.0)
		canvas.draw_rect(Rect2(bp2, bs), Color(0.8, 0.1, 0.1, 0.85))
		_text(Vector2(bp2.x, bp2.y + 36.0), "⚠ " + banner, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bs.x)
	var y := vs.y - 40.0 - 30.0 * (prompts.size() - 1)
	for line in prompts:
		_text(Vector2(0.0, y), line, 24, Color(1.0, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, vs.x - 360.0)
		y += 30.0


func _draw_controls(_vs: Vector2) -> void:
	if stick_index != -1:
		canvas.draw_circle(stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		canvas.draw_arc(stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
		var knob := stick_origin + (stick_pos - stick_origin).limit_length(STICK_RADIUS)
		canvas.draw_circle(knob, 38.0, Color(1, 1, 1, 0.45))
	else:
		var hint := Vector2(150.0, view_size().y - 140.0)
		canvas.draw_arc(hint, 70.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 3.0)
	var all := buttons()
	for key: String in all:
		var b: Dictionary = all[key]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var label: String = b["t"]
		var down := int(held.get(key, 0)) > 0
		var base := Color(0.8, 0.2, 0.25) if key == "hook" else Color(0.25, 0.4, 0.55)
		if key == "restart":
			base = Color(0.3, 0.3, 0.3)
		canvas.draw_circle(c, r, Color(base, 0.75 if down else 0.4))
		canvas.draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.8 if down else 0.5), 3.0)
		var fs := 26 if key == "restart" else (22 if key == "hook" else 16)
		_text(Vector2(c.x - r, c.y + fs * 0.35), label, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _draw_end(vs: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.04, 0.07, 0.82))
	_text(Vector2(0.0, vs.y * 0.5 - 130.0), "CAPÍTULO 1 · COMPLETADO", 44, Color(0.95, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_text(Vector2(0.0, vs.y * 0.5 - 90.0), "La subasta a oscuras", 26, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var y := vs.y * 0.5 - 30.0
	for line in end_lines:
		_text(Vector2(0.0, y), line, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		y += 40.0
	var r := play_again_rect()
	canvas.draw_rect(r, Color(0.25, 0.45, 0.6, 0.95))
	canvas.draw_rect(r, Color(1, 1, 1, 0.8), false, 3.0)
	_text(Vector2(r.position.x, r.position.y + 48.0), "Jugar de nuevo", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_settings(vs: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var panel := settings_panel()
	canvas.draw_rect(panel, Color(0.06, 0.09, 0.12, 0.96))
	canvas.draw_rect(panel, Color(1, 1, 1, 0.5), false, 3.0)
	_text(Vector2(panel.position.x, panel.position.y + 52.0), "AJUSTES", 36, Color(0.95, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(Vector2(panel.position.x, panel.position.y + 100.0), "Versión instalada:", 22, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_text(Vector2(panel.position.x, panel.position.y + 134.0), version_text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var qr := settings_rect("quality")
	canvas.draw_rect(qr, Color(0.3, 0.25, 0.4, 0.95))
	canvas.draw_rect(qr, Color(1, 1, 1, 0.8), false, 3.0)
	_text(Vector2(qr.position.x, qr.position.y + 32.0), Quality.label(), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, qr.size.x)
	_text(Vector2(panel.position.x, qr.end.y + 19.0), Quality.DETAIL[Quality.level], 15, Color(0.75, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var status_text := updater.status if updater else ""
	_text(Vector2(panel.position.x, panel.position.y + 228.0), status_text, 18, Color(0.85, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var u := settings_rect("update")
	canvas.draw_rect(u, Color(0.25, 0.45, 0.6, 0.95))
	if updater and updater.state == Updater.S.DOWNLOADING:
		canvas.draw_rect(Rect2(u.position, Vector2(u.size.x * updater.progress, u.size.y)), Color(0.3, 0.7, 0.5, 0.9))
	canvas.draw_rect(u, Color(1, 1, 1, 0.8), false, 3.0)
	var label := updater.button_label() if updater else "Buscar actualización"
	_text(Vector2(u.position.x, u.position.y + 42.0), label, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, u.size.x)
	var br := settings_rect("browser")
	canvas.draw_rect(br, Color(0.2, 0.25, 0.3, 0.9))
	canvas.draw_rect(br, Color(1, 1, 1, 0.5), false, 2.0)
	_text(Vector2(br.position.x, br.position.y + 31.0), "Abrir en el navegador", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	var c := settings_rect("close")
	canvas.draw_rect(c, Color(0.3, 0.3, 0.3, 0.9))
	canvas.draw_rect(c, Color(1, 1, 1, 0.6), false, 2.0)
	_text(Vector2(c.position.x, c.position.y + 31.0), "Cerrar", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, c.size.x)


func _draw_doc(vs: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.7))
	var pr := doc_panel()
	var paper := Color(0.86, 0.82, 0.7)
	var ink := Color(0.1, 0.09, 0.08)
	canvas.draw_rect(pr, paper)
	canvas.draw_rect(pr, Color(0.3, 0.22, 0.12), false, 4.0)
	var d: Dictionary = doc_list[doc_page]
	var inner := pr.size.x - 80.0
	canvas.draw_string(font, Vector2(pr.position.x + 40.0, pr.position.y + 52.0), str(d["titulo"]), HORIZONTAL_ALIGNMENT_LEFT, inner, 30, ink)
	canvas.draw_line(Vector2(pr.position.x + 40.0, pr.position.y + 66.0), Vector2(pr.end.x - 40.0, pr.position.y + 66.0), Color(ink, 0.5), 2.0)
	var text := str(d["texto"])
	var avail := pr.size.y - 66.0 - 100.0
	var size := 24
	while size > 15 and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, size).y > avail:
		size -= 1
	canvas.draw_multiline_string(font, Vector2(pr.position.x + 40.0, pr.position.y + 66.0 + size + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, inner, size, -1, ink)
	for which in ["prev", "next", "close"]:
		var r := doc_button(which)
		var on: bool = which == "close" or (which == "prev" and doc_page > 0) or (which == "next" and doc_page < doc_list.size() - 1)
		canvas.draw_rect(r, Color(0.25, 0.2, 0.12, 0.9 if on else 0.3))
		var label := "<" if which == "prev" else (">" if which == "next" else "Cerrar")
		canvas.draw_string(font, Vector2(r.position.x, r.position.y + 33.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, paper)
	canvas.draw_string(font, Vector2(pr.position.x + 250.0, pr.end.y - 30.0), "%d / %d" % [doc_page + 1, doc_list.size()], HORIZONTAL_ALIGNMENT_LEFT, 120.0, 22, ink)


func _draw_dialog(vs: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.35))
	var pr := dialog_panel()
	canvas.draw_rect(pr, Color(0.04, 0.06, 0.09, 0.94))
	canvas.draw_rect(pr, Color(0.8, 0.7, 0.45, 0.8), false, 3.0)
	var parts := dialog_lines[dialog_i].split("|", true, 1)
	var who := parts[0] if parts.size() > 1 else ""
	var said := parts[1] if parts.size() > 1 else parts[0]
	var col := Color(0.55, 0.85, 0.95) if who == "Sira" else Color(0.95, 0.8, 0.5)
	canvas.draw_string(font, Vector2(pr.position.x + 28.0, pr.position.y + 40.0), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 400.0, 24, col)
	canvas.draw_multiline_string(font, Vector2(pr.position.x + 28.0, pr.position.y + 80.0), said, HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 56.0, 28, 3, Color(0.95, 0.95, 0.92))
	canvas.draw_string(font, Vector2(pr.position.x + 28.0, pr.end.y - 12.0), "Toca para continuar   %d / %d" % [dialog_i + 1, dialog_lines.size()], HORIZONTAL_ALIGNMENT_LEFT, 500.0, 16, Color(0.7, 0.75, 0.8))
	var sk := dialog_skip_rect()
	canvas.draw_rect(sk, Color(0.2, 0.2, 0.25, 0.9))
	canvas.draw_rect(sk, Color(1, 1, 1, 0.5), false, 2.0)
	canvas.draw_string(font, Vector2(sk.position.x, sk.position.y + 28.0), "Saltar", HORIZONTAL_ALIGNMENT_CENTER, sk.size.x, 20, Color.WHITE)
