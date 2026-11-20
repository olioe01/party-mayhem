extends Node
## Cloudflare gyors-alagút (trycloudflare.com): ha a telefonok nem érik el a gépet a helyi
## hálózaton (vendég Wi-Fi, kliensizoláció, mobilnet), a lobbi gombjával nyilvános https
## címet nyitunk. Két alagút kell, mert a telefonos oldal (HTTP) és a WebSocket külön porton
## fut; a telefon a `/ws-host` címről tudja meg, melyik alagúton éri el a WebSocketet.
##
## A `cloudflared` programot keresi az exe mellett, a felhasználói mappában és a PATH-on;
## ha nincs meg, letölti a Cloudflare hivatalos GitHub-kiadásából a felhasználói mappába.
## Csak a hálózatot kezeli, a játékmenetre nem hat (valós idő itt rendben van).

const DL_WIN := "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
const DL_LINUX := "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
const URL_RE := "https://[a-z0-9-]+\\.trycloudflare\\.com"

var state := "off"          # off | download | starting | on | error
var message := ""
var page_url := ""          # https://xxx.trycloudflare.com (a telefonos oldal)
var ws_host := ""           # yyy.trycloudflare.com (a WebSocket)

var _procs: Array = []      # {pid, log, url, ready}
var _http: HTTPRequest = null
var _tried_download := false
var _started_ms := 0
var _poll_acc := 0.0
var _re := RegEx.create_from_string(URL_RE)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_kill_stale()


func _exit_tree() -> void:
	stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop()


func is_busy() -> bool:
	return state == "download" or state == "starting"


## A lobbi gombja: be/ki kapcsol.
func toggle(http_port: int, ws_port: int) -> void:
	if state == "on" or is_busy():
		stop()
		state = "off"
		message = ""
	else:
		start(http_port, ws_port)


func start(http_port: int, ws_port: int) -> void:
	stop()
	page_url = ""
	ws_host = ""
	if http_port <= 0:
		_fail("Nincs nyitott hálózati port.")
		return
	var exe := _find_exe()
	if exe == "":
		if _tried_download:
			_fail("A cloudflared nem indítható.")
		else:
			_download(http_port, ws_port)
		return
	state = "starting"
	message = "Cloudflare-alagút nyitása…"
	_started_ms = Time.get_ticks_msec()
	for port in [http_port, ws_port]:
		var log_path := ProjectSettings.globalize_path("user://cloudflared_%d.log" % port)
		DirAccess.remove_absolute(log_path)
		var pid := OS.create_process(exe, ["tunnel", "--no-autoupdate", "--logfile", log_path, "--url", "http://127.0.0.1:%d" % port])
		if pid <= 0:
			stop()
			if not _tried_download and exe == _path_name():
				_download(http_port, ws_port)
			else:
				_fail("A cloudflared nem indítható.")
			return
		_procs.append({"pid": pid, "log": log_path, "url": "", "ready": false, "port": port})
	set_meta("ports", [http_port, ws_port])
	_save_pids()


func stop() -> void:
	for p in _procs:
		if OS.is_process_running(p.pid):
			OS.kill(p.pid)
	_procs.clear()
	_save_pids()
	if _http:
		_http.cancel_request()
		_http.queue_free()
		_http = null
	page_url = ""
	ws_host = ""


func _fail(msg: String) -> void:
	stop()
	state = "error"
	message = msg
	push_warning("Cloudflare: " + msg)


func _process(dt: float) -> void:
	if state == "download" and _http:
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		message = "cloudflared letöltése… %d MB" % (got >> 20) + (" / %d MB" % (total >> 20) if total > 0 else "")
		return
	if _procs.is_empty():
		return
	_poll_acc += dt
	if _poll_acc < 0.4:
		return
	_poll_acc = 0.0
	var all_ready := true
	for p in _procs:
		if not OS.is_process_running(p.pid):
			var ports: Array = get_meta("ports", [0, 0])
			# Linuxon a nem létező PATH-os program is "elindul", csak azonnal kilép
			if state == "starting" and not _tried_download and _find_exe() == _path_name() and p.url == "":
				stop()
				_download(ports[0], ports[1])
			else:
				_fail("A Cloudflare-alagút leállt. Nincs internet?")
			return
		if not p.ready:
			var txt := FileAccess.get_file_as_string(p.log)
			if p.url == "":
				var m := _re.search(txt)
				if m:
					p.url = m.get_string()
			if p.url != "" and txt.contains("Registered tunnel connection"):
				p.ready = true
		all_ready = all_ready and p.ready
	if state == "starting":
		if all_ready:
			page_url = _procs[0].url
			ws_host = str(_procs[1].url).trim_prefix("https://")
			state = "on"
			message = ""
			print("Party Mayhem: Cloudflare-cím: ", page_url, "  (WebSocket: ", ws_host, ")")
		elif Time.get_ticks_msec() - _started_ms > 45000:
			_fail("A Cloudflare nem válaszolt időben. Nincs internet?")


# ------------------------------------------------------------------ árva folyamatok
## Ha a játékot erőszakkal állították le, a cloudflared tovább futhat: a következő induláskor
## leállítjuk, de csak akkor, ha az adott azonosítójú folyamat tényleg cloudflared.
func _pid_file() -> String:
	return "user://cloudflared.pids"


func _save_pids() -> void:
	var ids := PackedStringArray()
	for p in _procs:
		ids.append(str(p.pid))
	if ids.is_empty():
		if FileAccess.file_exists(_pid_file()):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_pid_file()))
		return
	var f := FileAccess.open(_pid_file(), FileAccess.WRITE)
	if f:
		f.store_string(",".join(ids))


func _kill_stale() -> void:
	if not FileAccess.file_exists(_pid_file()):
		return
	for s in FileAccess.get_file_as_string(_pid_file()).split(",", false):
		var pid := int(s)
		if pid > 0 and _is_cloudflared(pid):      # (is_process_running csak a saját gyerekeit látja)
			OS.kill(pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_pid_file()))


func _is_cloudflared(pid: int) -> bool:
	if OS.get_name() == "Windows":
		var out: Array = []
		OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/NH"], out)
		return out.size() > 0 and str(out[0]).to_lower().contains("cloudflared")
	var out: Array = []
	OS.execute("ps", ["-p", str(pid), "-o", "comm="], out)
	return out.size() > 0 and str(out[0]).strip_edges() == "cloudflared"


# ------------------------------------------------------------------ program keresése / letöltése
func _bin_name() -> String:
	return "cloudflared.exe" if OS.get_name() == "Windows" else "cloudflared"


func _path_name() -> String:
	return _bin_name()


func _user_bin() -> String:
	return ProjectSettings.globalize_path("user://" + _bin_name())


func _find_exe() -> String:
	var beside := OS.get_executable_path().get_base_dir().path_join(_bin_name())
	if FileAccess.file_exists(beside):
		return beside
	if FileAccess.file_exists(_user_bin()):
		return _user_bin()
	return _path_name()      # a PATH-on keresi az operációs rendszer


func _download(http_port: int, ws_port: int) -> void:
	_tried_download = true
	state = "download"
	message = "cloudflared letöltése…"
	_http = HTTPRequest.new()
	_http.download_file = _user_bin() + ".part"
	_http.max_redirects = 10
	add_child(_http)
	_http.request_completed.connect(func(result: int, code: int, _h, _b):
		if _http:
			_http.queue_free()
			_http = null
		var part := _user_bin() + ".part"
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			DirAccess.remove_absolute(part)
			_fail("A cloudflared letöltése nem sikerült (%d/%d)." % [result, code])
			return
		DirAccess.remove_absolute(_user_bin())
		DirAccess.rename_absolute(part, _user_bin())
		if OS.get_name() != "Windows":
			OS.execute("chmod", ["+x", _user_bin()])
		start(http_port, ws_port))
	var err := _http.request(DL_WIN if OS.get_name() == "Windows" else DL_LINUX)
	if err != OK:
		_fail("A cloudflared letöltése nem indult el.")
