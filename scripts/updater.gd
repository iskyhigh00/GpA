class_name Updater
extends Node
## Actualización dentro de la app: consulta el release «latest», descarga el APK
## y lanza el instalador de Android. Si algo falla, el HUD ofrece abrir el navegador.

enum S { IDLE, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, INSTALLING, FAILED }

signal changed

const API_URL := "https://api.github.com/repos/iskyhigh00/GpA/releases/tags/latest"
const APK_PATH := "user://update.apk"

var state: S = S.IDLE
var status := ""
var progress := 0.0
var installed_sha := "dev"
var remote_sha := ""
var apk_url := ""
var offline := false
var http: HTTPRequest
var dl: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	offline = Gfx.headless
	http = HTTPRequest.new()
	http.request_completed.connect(_on_check_done)
	add_child(http)
	dl = HTTPRequest.new()
	dl.download_file = APK_PATH
	dl.request_completed.connect(_on_download_done)
	add_child(dl)


func set_installed(version_text: String) -> void:
	installed_sha = version_text.split(" ")[0]


func button_label() -> String:
	match state:
		S.CHECKING:
			return "Buscando…"
		S.UP_TO_DATE:
			return "Al día · volver a buscar"
		S.AVAILABLE:
			return "Descargar e instalar"
		S.DOWNLOADING:
			return "Descargando %d%%" % int(progress * 100.0)
		S.INSTALLING:
			return "Instalando…"
		S.FAILED:
			return "Reintentar"
		_:
			return "Buscar actualización"


func act() -> void:
	match state:
		S.AVAILABLE:
			download()
		S.CHECKING, S.DOWNLOADING, S.INSTALLING:
			pass
		_:
			check()


func _state(st: S, msg: String) -> void:
	state = st
	status = msg
	changed.emit()


func check() -> void:
	if offline:
		_state(S.FAILED, "Sin red en este entorno.")
		return
	_state(S.CHECKING, "Consultando la última versión…")
	var err := http.request(API_URL, ["User-Agent: turno-de-la-sal", "Accept: application/vnd.github+json"])
	if err != OK:
		_state(S.FAILED, "No se pudo iniciar la consulta.")


func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_state(S.FAILED, "Sin conexión.")
		return
	if code == 404:
		_state(S.FAILED, "No se puede leer el release (¿repositorio privado?).")
		return
	if code != 200:
		_state(S.FAILED, "Error %d al consultar." % code)
		return
	apply_release(JSON.parse_string(body.get_string_from_utf8()))


## Separado de la red para poder probarlo.
func apply_release(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		_state(S.FAILED, "Respuesta inesperada.")
		return
	var d: Dictionary = data
	remote_sha = str(d.get("target_commitish", ""))
	apk_url = ""
	var assets: Array = d.get("assets", [])
	for a: Dictionary in assets:
		if str(a.get("name", "")).ends_with(".apk"):
			apk_url = str(a.get("browser_download_url", ""))
	if apk_url == "":
		_state(S.FAILED, "El release no tiene APK.")
	elif installed_sha == "dev" or installed_sha == "desarrollo" or remote_sha.begins_with(installed_sha):
		_state(S.UP_TO_DATE, "Tienes la última versión.")
	else:
		_state(S.AVAILABLE, "Hay una versión nueva (%s)." % remote_sha.substr(0, 7))


func download() -> void:
	if offline or apk_url == "":
		_state(S.FAILED, "No hay descarga disponible.")
		return
	progress = 0.0
	_state(S.DOWNLOADING, "Descargando la actualización…")
	var err := dl.request(apk_url, ["User-Agent: turno-de-la-sal"])
	if err != OK:
		_state(S.FAILED, "No se pudo iniciar la descarga.")


func _process(_delta: float) -> void:
	if state == S.DOWNLOADING:
		var total := dl.get_body_size()
		if total > 0:
			progress = float(dl.get_downloaded_bytes()) / total
		changed.emit()


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_state(S.FAILED, "La descarga falló (%d). Prueba abrir en el navegador." % code)
		return
	progress = 1.0
	_state(S.INSTALLING, "Abriendo el instalador de Android…")
	if not install_apk():
		_state(S.FAILED, "No se pudo abrir el instalador. Usa «Abrir en el navegador».")


## Instala vía JNI (sin plugin): copia el APK a Descargas con MediaStore y lanza ACTION_VIEW.
func install_apk() -> bool:
	if OS.get_name() != "Android":
		return false
	var rt: Object = Engine.get_singleton("AndroidRuntime")
	if rt == null:
		return false
	var act_obj: Object = rt.call("getActivity")
	if act_obj == null:
		return false
	var uri_cls: Object = JavaClassWrapper.wrap("android.net.Uri")
	var intent_cls: Object = JavaClassWrapper.wrap("android.content.Intent")
	var pm: Object = act_obj.call("getPackageManager")
	if not pm.call("canRequestPackageInstalls"):
		var pkg: String = act_obj.call("getPackageName")
		var st: Object = intent_cls.call("Intent", "android.settings.MANAGE_UNKNOWN_APP_SOURCES", uri_cls.call("parse", "package:" + pkg))
		st.call("addFlags", 0x10000000)
		act_obj.call("startActivity", st)
		status = "Permite «instalar apps desconocidas» para esta app y toca de nuevo."
		return true
	var cv_cls: Object = JavaClassWrapper.wrap("android.content.ContentValues")
	var cv: Object = cv_cls.call("ContentValues")
	cv.call("put", "_display_name", "el-turno-de-la-sal-update.apk")
	cv.call("put", "mime_type", "application/vnd.android.package-archive")
	cv.call("put", "relative_path", "Download/")
	var resolver: Object = act_obj.call("getContentResolver")
	var uri: Object = resolver.call("insert", uri_cls.call("parse", "content://media/external/downloads"), cv)
	if uri == null:
		return false
	var os_stream: Object = resolver.call("openOutputStream", uri)
	if os_stream == null:
		return false
	os_stream.call("write", FileAccess.get_file_as_bytes(APK_PATH))
	os_stream.call("close")
	var it: Object = intent_cls.call("Intent", "android.intent.action.VIEW")
	it.call("setDataAndType", uri, "application/vnd.android.package-archive")
	it.call("addFlags", 0x10000001)
	act_obj.call("startActivity", it)
	return true
