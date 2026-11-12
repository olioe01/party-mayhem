extends Node
## Hálózat: beépített webszerver (a telefonos kontroller oldala) + WebSocket a telefonoknak.
## A telefonok ugyanazt a vezérlő-protokollt kapják, mint a böngészős változatban:
##   host -> telefon: {e:"ctrl", d:{kind:"layout"|"status"|"vibrate", ...}}
##   telefon -> host: {e:"player:join", d:{pid,name}}, {e:"player:input", d:{t:..., lid:...}}
## Itt élnek a botok és a "kérdezz és várj a válaszra" (ask) logika is.

signal player_joined(pid: String, pname: String, is_bot: bool)
signal player_left(pid: String)
signal player_input(pid: String, msg: Dictionary)

const BASE_PORT := 3000
const MIME := {
	"html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
	"png": "image/png", "svg": "image/svg+xml", "ttf": "font/ttf", "json": "application/json", "ico": "image/x-icon",
}

var http_port := 0
var ws_port := 0
var addresses: PackedStringArray = []
var server_error := ""

var _http := TCPServer.new()
var _ws := TCPServer.new()
var _http_conns: Array = []        # {peer, buf, t, closing}
var _ws_conns: Array = []          # {ws: WebSocketPeer, pid, t}
var _pid_conn := {}                # pid -> conn dict
var _web_zip: ZIPReader = null
var _web_cache := {}

var status_provider: Callable = func(_pid): return null
var layouts := {}                  # pid -> utolsó elrendezés
var bots := {}                     # pid -> true
var away := {}                     # lecsatlakozott játékosok (bot vezérli őket)
var _seq := 0
var _asks: Array = []


class Ask:
	extends RefCounted
	signal done(msg: Dictionary)
	var pid := ""
	var types: Array = []
	var lid := 0
	var finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open_web_bundle()
	_start_servers()
	addresses = _lan_addresses()


# ------------------------------------------------------------------ szerverek
func _start_servers() -> void:
	for i in 10:
		var p := BASE_PORT + i * 10
		if _http.listen(p, "*") == OK:
			if _ws.listen(p + 1, "*") == OK:
				http_port = p
				ws_port = p + 1
				print("Party Mayhem: telefonos oldal a ", p, ". porton, WebSocket: ", p + 1)
				return
			_http.stop()
	server_error = "Nem sikerült megnyitni a hálózati portot (3000–3091 foglalt)."
	push_error(server_error)


func _lan_addresses() -> PackedStringArray:
	var scored: Array = []
	for itf in IP.get_local_interfaces():
		var name: String = str(itf.get("friendly", itf.get("name", ""))).to_lower()
		if name.contains("vethernet") or name.contains("virtual") or name.contains("vmware") or name.contains("docker") \
				or name.contains("loopback") or name.begins_with("veth") or name.begins_with("br-") or name.contains("wsl") \
				or name.contains("hyper-v") or name.contains("bluetooth") or name.contains("tailscale") or name.contains("zerotier"):
			continue
		for a in itf.get("addresses", []):
			var ip := str(a)
			if not ip.is_valid_ip_address() or ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
				continue
			var score := 3
			if ip.begins_with("192.168."): score = 0
			elif ip.begins_with("10."): score = 1
			elif ip.begins_with("172."): score = 2
			if name.contains("wi-fi") or name.contains("wifi") or name.contains("wlan") or name.begins_with("wl"): score -= 1
			scored.append([score, ip])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out := PackedStringArray()
	for s in scored:
		if not out.has(s[1]): out.append(s[1])
	if out.is_empty():
		for ip in IP.get_local_addresses():
			if ip.is_valid_ip_address() and not ip.contains(":") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				out.append(ip)
	return out


func join_url() -> String:
	var forced := OS.get_environment("PUBLIC_HOST")
	var host := forced if forced != "" else (addresses[0] if addresses.size() else "localhost")
	return "http://%s:%d" % [host, http_port] if http_port != 80 else "http://%s" % host


func _process(_dt: float) -> void:
	_poll_http()
	_poll_ws()


# ------------------------------------------------------------------ webszerver
func _open_web_bundle() -> void:
	if FileAccess.file_exists("res://web/index.html"):
		return
	_web_zip = ZIPReader.new()
	if _web_zip.open("res://web.zip") != OK:
		_web_zip = null
		push_error("Hiányzik a telefonos kontroller (res://web.zip)")


func read_web_file(path: String) -> PackedByteArray:
	if _web_cache.has(path):
		return _web_cache[path]
	var data := PackedByteArray()
	if _web_zip:
		if _web_zip.file_exists(path):
			data = _web_zip.read_file(path)
	else:
		var f := FileAccess.open("res://web/" + path, FileAccess.READ)
		if f:
			data = f.get_buffer(f.get_length())
	if data.size() and not path.ends_with(".js") and not path.ends_with(".html") and not path.ends_with(".css"):
		_web_cache[path] = data
	return data


func _poll_http() -> void:
	while _http.is_connection_available():
		var peer := _http.take_connection()
		peer.set_no_delay(true)
		_http_conns.append({"peer": peer, "buf": PackedByteArray(), "t": Time.get_ticks_msec(), "closing": false})
	var now := Time.get_ticks_msec()
	for c in _http_conns.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		var st := peer.get_status()
		if st != StreamPeerTCP.STATUS_CONNECTED or now - c.t > 8000 or (c.closing and now - c.t > 1500):
			peer.disconnect_from_host()
			_http_conns.erase(c)
			continue
		if c.closing:
			continue
		var avail := peer.get_available_bytes()
		if avail > 0:
			var r := peer.get_partial_data(avail)
			if r[0] == OK:
				c.buf.append_array(r[1])
		var s: String = c.buf.get_string_from_ascii()
		if s.contains("\r\n\r\n"):
			_answer_http(peer, s)
			c.closing = true
			c.t = now
		elif c.buf.size() > 16384:
			peer.disconnect_from_host()
			_http_conns.erase(c)


func _answer_http(peer: StreamPeerTCP, req: String) -> void:
	var first := req.get_slice("\r\n", 0).split(" ")
	if first.size() < 2 or (first[0] != "GET" and first[0] != "HEAD"):
		_send_http(peer, 405, "text/plain", "Method Not Allowed".to_utf8_buffer(), false)
		return
	var path := first[1].get_slice("?", 0).uri_decode()
	if path == "/" or path == "/index.html" or path == "/play":
		path = "/index.html"
	path = path.trim_prefix("/")
	if path.contains("..") or path.begins_with("."):
		_send_http(peer, 404, "text/plain", "Not found".to_utf8_buffer(), false)
		return
	var data := read_web_file(path)
	if data.is_empty():
		_send_http(peer, 404, "text/plain; charset=utf-8", "Nincs ilyen oldal".to_utf8_buffer(), false)
		return
	var ext := path.get_extension().to_lower()
	_send_http(peer, 200, MIME.get(ext, "application/octet-stream"), data, first[0] == "HEAD")


func _send_http(peer: StreamPeerTCP, code: int, mime: String, body: PackedByteArray, head_only: bool) -> void:
	var reason: String = {200: "OK", 404: "Not Found", 405: "Method Not Allowed"}.get(code, "OK")
	var hdr := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n" % [code, reason, mime, body.size()]
	peer.put_data(hdr.to_ascii_buffer())
	if not head_only:
		peer.put_data(body)


# ------------------------------------------------------------------ WebSocket
func _poll_ws() -> void:
	while _ws.is_connection_available():
		var tcp := _ws.take_connection()
		tcp.set_no_delay(true)
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 65536
		ws.outbound_buffer_size = 262144
		if ws.accept_stream(tcp) == OK:
			_ws_conns.append({"ws": ws, "pid": "", "t": Time.get_ticks_msec()})
	for c in _ws_conns.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var txt := ws.get_packet().get_string_from_utf8()
				_on_ws_message(c, txt)
		elif st == WebSocketPeer.STATE_CLOSED:
			_ws_conns.erase(c)
			if c.pid != "" and is_same(_pid_conn.get(c.pid), c):
				_pid_conn.erase(c.pid)
				player_left.emit(c.pid)


func _clean(v, max_len: int) -> String:
	var s := str(v if v != null else "")
	var out := ""
	for ch in s:
		if ch.unicode_at(0) >= 32:
			out += ch
	return out.strip_edges().left(max_len)


func _on_ws_message(c: Dictionary, txt: String) -> void:
	var m = JSON.parse_string(txt)
	if typeof(m) != TYPE_DICTIONARY:
		return
	var e := str(m.get("e", ""))
	var d = m.get("d", {})
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	if e == "player:join":
		var pid := _clean(d.get("pid"), 40)
		var pname := _clean(d.get("name"), 14)
		if pname == "": pname = "Játékos"
		if pid == "": return
		var old = _pid_conn.get(pid)
		if old and not is_same(old, c):
			old.pid = ""
			(old.ws as WebSocketPeer).close()
		c.pid = pid
		_pid_conn[pid] = c
		_raw_send(c, "host:online", {})
		away.erase(pid)
		player_joined.emit(pid, pname, false)
	elif e == "player:input":
		if c.pid == "":
			return
		handle_input(c.pid, d)


func _raw_send(c: Dictionary, e: String, d) -> void:
	var ws: WebSocketPeer = c.ws
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({"e": e, "d": d}))


func send(pid: String, msg: Dictionary) -> void:
	if bots.has(pid):
		return
	var c = _pid_conn.get(pid)
	if c:
		_raw_send(c, "ctrl", msg)


func phone_count() -> int:
	return _pid_conn.size()


# ------------------------------------------------------------------ kontroller-vezérlés
func is_bot(pid: String) -> bool:
	return bots.has(pid)


func is_auto(pid: String) -> bool:
	return bots.has(pid) or away.has(pid)


func handle_input(pid: String, msg: Dictionary) -> void:
	var t := str(msg.get("t", ""))
	var lid := int(msg.get("lid", 0))
	for i in _asks.size():
		var a: Ask = _asks[i]
		if a.pid == pid and a.lid == lid and a.types.has(t):
			_asks.remove_at(i)
			a.finished = true
			a.done.emit(msg)
			return
	player_input.emit(pid, msg)


func set_ctrl(pid: String, layout: Dictionary) -> int:
	_seq += 1
	layout["id"] = _seq
	layout["me"] = status_provider.call(pid)
	layouts[pid] = layout
	if is_auto(pid):
		_bot_react(pid, layout)
	if not bots.has(pid):
		send(pid, {"kind": "layout", "layout": layout})
	return _seq


func resend_layout(pid: String) -> bool:
	if not layouts.has(pid):
		return false
	var l: Dictionary = layouts[pid]
	l["me"] = status_provider.call(pid)
	send(pid, {"kind": "layout", "layout": l})
	return true


func push_status(pid: String) -> void:
	send(pid, {"kind": "status", "me": status_provider.call(pid)})


func vibrate(pid: String, pattern = 60) -> void:
	send(pid, {"kind": "vibrate", "pattern": pattern})


## Elrendezést küld és megvárja a választ (await-tel). Ha a játékos nem válaszol,
## a határidő után a bot-logika dönt helyette, hogy a játék ne akadjon el.
func ask(pid: String, layout: Dictionary, types: Array = ["choice", "tap", "num", "ready"], timeout_sec: float = 40.0) -> Dictionary:
	var a := Ask.new()
	a.pid = pid
	a.types = types
	_asks.append(a)
	a.lid = set_ctrl(pid, layout)
	get_tree().create_timer(timeout_sec, true).timeout.connect(func():
		if not a.finished: _bot_react(pid, layout, true))
	var msg: Dictionary = await a.done
	return msg


func cancel_asks() -> void:
	for a in _asks:
		a.finished = true
	_asks.clear()


func add_bot(bname: String) -> String:
	var pid := "bot-%06x" % (randi() & 0xffffff)
	bots[pid] = true
	player_joined.emit(pid, bname, true)
	return pid


func remove_bot(pid: String) -> void:
	bots.erase(pid)


func mark_away(pid: String) -> void:
	away[pid] = true
	if layouts.has(pid):
		_bot_react(pid, layouts[pid])


func _later(sec: float, f: Callable) -> void:
	get_tree().create_timer(max(0.0, sec), true).timeout.connect(f)


func _bot_react(pid: String, l: Dictionary, now := false) -> void:
	if not is_same(layouts.get(pid), l):
		return
	var d := func(a: float, b: float) -> float: return 0.0 if now else randf_range(a, b)
	var fire := func(msg: Dictionary):
		if is_same(layouts.get(pid), l):
			msg["lid"] = l.get("id", 0)
			handle_input(pid, msg)
	match str(l.get("mode", "")):
		"choice":
			var ok: Array = []
			var opts: Array = l.get("options", [])
			for i in opts.size():
				if not opts[i].get("disabled", false):
					ok.append(i)
			if ok.is_empty():
				return
			var v: int = ok.pick_random()
			var bp = l.get("botPick", null)
			if typeof(bp) == TYPE_INT and bp >= 0 and bp < opts.size() and not opts[bp].get("disabled", false):
				v = bp
			_later(d.call(0.6, 1.4), func(): fire.call({"t": "choice", "v": v}))
		"tap":
			if l.get("botAuto", false) or now:
				_later(d.call(0.5, 1.3), func(): fire.call({"t": "tap"}))
		"ready":
			_later(d.call(0.7, 2.2), func(): fire.call({"t": "ready"}))
		"lobby":
			if not l.get("ready", false):
				_later(d.call(0.2, 0.6), func(): fire.call({"t": "ready", "v": true}))
		"number":
			if now:
				fire.call({"t": "num", "v": 0})
