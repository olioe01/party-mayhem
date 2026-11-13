extends Node
## Online játék több gép között – mindenki a saját gépén futtatja és látja a játékot.
##
## Működés: a játék fix, 60 lépés/mp ütemben fut. A hoszt minden bemenetet (telefonok,
## billentyűk, kattintások) lépésszámmal megjelölve szétküld; a vendég gépek ugyanazokat
## a lépéseket ugyanazokkal a bemenetekkel játsszák le, így ugyanazt látják – videó nélkül,
## pár bájt/lépés forgalommal. Minden jelenetváltásnál a hoszt a teljes állapotot is átküldi
## (Snapshot), és mindenki abból folytatja: innen tud valaki menet közben beszállni, és
## ezért nem tudnak a gépek tartósan eltérni egymástól.
##
## A vendég gép telefonjai a saját gépükhöz csatlakoznak (saját QR-kód), az továbbítja
## a bemenetüket a hosztnak.

signal changed

const PROTO := 1
const TICK := 1.0 / 60.0
const BUFFER := 2              # a vendég ennyi lépéssel jár a hoszt mögött (hálózati ingadozás ellen)
const DEFAULT_PORT := 3001
const CODE_ALPHA := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const PC_EVENTS := ["join", "leave", "in", "key", "click"]

var client := false            # true: egy másik gép szobájában vendég
var tick := 0
var catching := false          # épp felzárkózik (gyorsított lejátszás)
var error := ""                # az utolsó csatlakozási hiba, a panel mutatja
var verbose := false
var version := "dev"           # a build azonosítója (build_id.txt): csak egyező verziók játszhatnak együtt
var ck_ok := 0                 # jelenetváltások, ahol a vendég állapota bájtra egyezett a hosztéval
var ck_bad := 0

# --- közös
var _acc := 0.0
var _timers: Array = []        # [esedékes lépés, Callable]

# --- hoszt
var _pending: Array = []       # a következő lépésben végrehajtandó események
var _log: Array = []           # [[lépés, [esemény…]], …] a legutóbbi mentés óta
var _ck_bytes := PackedByteArray()
var _ck_tick := 0
var _out_ev: Array = []
var _out_ck: Array = []
var _pcs: Array = []           # élő vendég gépek (a Net kapcsolat-szótárai)
var _hello: Array = []         # most jelentkezett gépek, a képkocka végén kapnak kezdőállapotot

# --- vendég
var _ws: WebSocketPeer = null
var _addr := ""
var _state := ""               # "" | "connecting" | "online" | "retry"
var _state_t := 0
var _retries := 0
var _hello_sent := false
var _host_tick := 0
var _in_ev := {}               # lépés -> [esemény…]
var _in_ck := {}               # lépés -> mentés
var _init_tick := -1
var _refill := false

# --- szoba megnyitása az internet felé (UPnP)
var upnp_state := ""           # "" | "working" | "ok" | "fail"
var upnp_msg := ""
var public_ip := ""
var _upnp: UPNP = null
var _upnp_thread: Thread = null
var _upnp_port := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://build_id.txt", FileAccess.READ)
	if f:
		version = f.get_as_text().strip_edges()


func _exit_tree() -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
	if _upnp and upnp_state == "ok":
		_upnp.delete_port_mapping(_upnp_port, "TCP")


func log_line(s: String) -> void:
	if verbose:
		print("[sync] ", s)


# ------------------------------------------------------------------ ütemezés
## A Main hívja képkockánként: ennyi játéklépést futtat le.
func frame(dt: float) -> void:
	_poll_client()
	if client:
		_client_frame(dt)
	else:
		_host_frame(dt)


func _steps(dt: float) -> int:
	_acc += dt
	# a 0,25-ös ráhagyás miatt 60 Hz-es kijelzőn képkockánként pontosan egy lépés jut
	var n := clampi(int(floor(_acc / TICK + 0.25)), 0, 8)
	_acc = clampf(_acc - n * TICK, -TICK, TICK)
	return n


## Játékidőhöz kötött időzítő (lépésben számol, ezért minden gépen ugyanakkor jár le).
func after(sec: float, fn: Callable) -> void:
	_timers.append([tick + maxi(1, roundi(sec / TICK)), fn])


func clear_timers() -> void:
	_timers.clear()


func _run_timers() -> void:
	if _timers.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for tm in _timers:
		if tm[0] <= tick: due.append(tm)
		else: keep.append(tm)
	_timers = keep
	for tm in due:
		var fn: Callable = tm[1]
		if fn.is_valid():
			fn.call()


## Bemenet beküldése: a hosztnál a következő lépésbe kerül, a vendég a hosztnak továbbítja.
func submit(ev: Dictionary) -> void:
	if client:
		if _ws and _state == "online" and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.send_text(JSON.stringify({"e": "pc:ev", "d": ev}))
	else:
		_pending.append(ev)


func _apply(ev: Dictionary) -> void:
	match str(ev.get("k", "")):
		"join":
			var pid := str(ev.get("pid", ""))
			Net.away.erase(pid)
			Net.player_joined.emit(pid, str(ev.get("name", "Játékos")), false)
		"leave":
			Net.player_left.emit(str(ev.get("pid", "")))
		"in":
			var m = ev.get("m")
			if typeof(m) == TYPE_DICTIONARY:
				Net.handle_input(str(ev.get("pid", "")), m)
		"key":
			Main.I.sim_key(int(ev.get("c", 0)))
		"click":
			Main.I.sim_click(Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))))
		"relobby":
			if G.phase == "lobby":
				Main.I.set_scene(LobbyScene.new())
		"start":
			if G.phase == "lobby":
				Game.start_game()


# ------------------------------------------------------------------ hoszt
func _host_frame(dt: float) -> void:
	var n := _steps(dt)
	for i in n:
		tick += 1
		var evs := _pending
		_pending = []
		for ev in evs:
			_apply((ev as Dictionary).duplicate(true))
		_run_timers()
		Main.I.step(TICK)
		if not evs.is_empty():
			_out_ev.append([tick, evs])
			if _ck_tick != tick:      # a mentés előtti események már benne vannak a mentésben
				_log.append([tick, evs])
	if n > 0:
		_flush()
	_welcome_new()


## A Main hívja jelenetváltáskor: innen indul az új szakasz.
func host_checkpoint(bytes: PackedByteArray) -> void:
	_ck_bytes = bytes
	_ck_tick = tick
	_log.clear()
	_out_ck.append([tick, bytes])
	if verbose:
		log_line("hoszt mentés %d. lépés: %s, %d bájt, kör %d, játékosok: %s" % [tick, Snapshot.scene_name(Main.I._next), bytes.size(), G.round,
			", ".join(G.players.map(func(p): return "%s@%d %d🪙 %d👑" % [p.name, p.node, p.coins, p.crowns]))])


func _flush() -> void:
	if _pcs.is_empty():
		_out_ev.clear()
		_out_ck.clear()
		return
	var pkt := {"t": "s", "n": tick}
	if not _out_ev.is_empty():
		pkt["e"] = _out_ev
	if not _out_ck.is_empty():
		pkt["c"] = _out_ck
	var bytes := var_to_bytes(pkt)
	for c in _pcs:
		_send_pc(c, bytes)
	_out_ev = []
	_out_ck = []


func _send_pc(c: Dictionary, bytes: PackedByteArray) -> void:
	var ws: WebSocketPeer = c.ws
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send(bytes)


func _welcome_new() -> void:
	if _hello.is_empty():
		return
	var later: Array = []
	for c in _hello:
		# ha régóta áll a lobby, előbb friss mentést készítünk, hogy ne kelljen percekig visszajátszani
		if c.get("wait_ck", -1) < 0 and G.phase == "lobby" and tick - _ck_tick > 600:
			c["wait_ck"] = _ck_tick
			c["wait_t"] = tick
			_pending.append({"k": "relobby"})
		if c.get("wait_ck", -1) >= 0 and c.wait_ck == _ck_tick and tick - int(c.wait_t) < 180:
			later.append(c)
			continue
		_send_pc(c, var_to_bytes({"t": "init", "tick": _ck_tick, "ck": _ck_bytes}))
		var i := 0
		while i < _log.size():
			_send_pc(c, var_to_bytes({"t": "s", "n": int(_log[min(i + 300, _log.size()) - 1][0]), "e": _log.slice(i, i + 300)}))
			i += 300
		_send_pc(c, var_to_bytes({"t": "s", "n": tick}))
		_pcs.append(c)
		log_line("vendég gép csatlakozott (%d összesen), kezdőállapot: %d. lépés, %d bájt" % [_pcs.size(), _ck_tick, _ck_bytes.size()])
		changed.emit()
	_hello = later


func pc_count() -> int:
	return _pcs.size()


## Egy másik gép jelentkezett a WebSocket-szerveren (a Net hívja).
func pc_hello(c: Dictionary, d: Dictionary) -> void:
	var problem := ""
	if int(d.get("v", 0)) != PROTO or str(d.get("b", "")) != version:
		problem = "Eltérő játékverzió (a szobáé: %s) – mindenkinek ugyanaz a PartyMayhem.exe kell." % version
	elif client:
		problem = "Ez a gép maga is vendég egy másik szobában."
	if problem != "":
		_send_pc(c, var_to_bytes({"t": "err", "m": problem}))
		(c.ws as WebSocketPeer).close(1000, "refused")
		return
	c["pc"] = true
	c["pids"] = {}
	_hello.append(c)


## Vendég gépről érkező bemenet (annak telefonjai, billentyűi).
func pc_event(c: Dictionary, d: Dictionary) -> void:
	if client or not c.get("pc", false):
		return
	var k := str(d.get("k", ""))
	if not PC_EVENTS.has(k):
		return
	var pids: Dictionary = c.pids
	match k:
		"join":
			var pid := Net.clean(d.get("pid"), 40)
			var pname := Net.clean(d.get("name"), 14)
			if pid == "" or pids.size() >= 16:
				return
			pids[pid] = true
			_pending.append({"k": "join", "pid": pid, "name": pname if pname != "" else "Játékos"})
		"leave":
			var pid := str(d.get("pid", ""))
			if pids.erase(pid):
				_pending.append({"k": "leave", "pid": pid})
		"in":
			var pid := str(d.get("pid", ""))
			var m = d.get("m")
			if pids.has(pid) and typeof(m) == TYPE_DICTIONARY and m.size() <= 8:
				_pending.append({"k": "in", "pid": pid, "m": m})
		"key":
			_pending.append({"k": "key", "c": int(d.get("c", 0))})
		"click":
			_pending.append({"k": "click", "x": float(d.get("x", 0)), "y": float(d.get("y", 0))})


func pc_closed(c: Dictionary) -> void:
	_hello.erase(c)
	if _pcs.has(c):
		_pcs.erase(c)
		log_line("vendég gép lecsatlakozott (%d maradt)" % _pcs.size())
		changed.emit()
	if not client:
		for pid in c.get("pids", {}):
			_pending.append({"k": "leave", "pid": pid})


# ------------------------------------------------------------------ vendég
## Csatlakozás egy szobához. A szöveg lehet szobakód (pl. ABC-DEFG) vagy cím (IP vagy IP:port).
func join(text: String) -> bool:
	var a := parse_target(text)
	if a == "":
		error = "Ez nem érvényes szobakód vagy cím."
		changed.emit()
		return false
	if client or _ws:
		_close_ws()
		if client:
			_become_host("")
	_addr = a
	_retries = 0
	error = ""
	_connect()
	return true


func _connect() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 16 << 20
	_ws.outbound_buffer_size = 1 << 20
	_ws.max_queued_packets = 16384
	_hello_sent = false
	_state_t = Time.get_ticks_msec()
	if _ws.connect_to_url("ws://" + _addr) != OK:
		_ws = null
		_fail("Nem sikerült csatlakozni ide: %s" % _addr)
		return
	if _state != "retry":
		_state = "connecting"
	log_line("csatlakozás: %s" % _addr)
	changed.emit()


func _close_ws() -> void:
	if _ws:
		_ws.close()
	_ws = null


## Kilépés a szobából (a felhasználó kérésére).
func leave() -> void:
	_close_ws()
	if client:
		_become_host("")
	_state = ""
	changed.emit()


func state() -> String:
	return _state


func address() -> String:
	return _addr


func _fail(msg: String) -> void:
	_close_ws()
	_state = ""
	if client:
		_become_host(msg)
	else:
		error = msg
	log_line("hiba: %s" % msg)
	changed.emit()


func _poll_client() -> void:
	if _ws == null:
		if _state == "retry" and Time.get_ticks_msec() - _state_t > 1500:
			_connect()
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _hello_sent:
			_hello_sent = true
			_ws.send_text(JSON.stringify({"e": "pc:hello", "d": {"v": PROTO, "b": version}}))
		while _ws and _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet()
			if _ws.was_string_packet():
				continue
			var m = bytes_to_var(raw)
			if typeof(m) == TYPE_DICTIONARY:
				_on_host_msg(m)
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		if (_state == "online" or _state == "retry") and _retries < 5:
			# megszakadt: néhányszor megpróbáljuk újra; siker esetén a hoszt friss állapotot küld
			_retries += 1
			_state = "retry"
			_state_t = Time.get_ticks_msec()
			log_line("megszakadt, újrapróbálkozás (%d)" % _retries)
			changed.emit()
		elif _state == "online" or _state == "retry":
			_fail("Megszakadt a kapcsolat a szobával.")
		else:
			_fail("Nem sikerült csatlakozni. Jó a kód? Fut a játék a másik gépen, és megnyitotta a szobát?")
	elif Time.get_ticks_msec() - _state_t > 9000:
		if _state == "retry" and _retries < 5:
			_retries += 1
			_close_ws()
			_state_t = Time.get_ticks_msec()
		elif _state == "retry":
			_fail("Megszakadt a kapcsolat a szobával.")
		elif _state == "connecting":
			_fail("Nem érhető el a szoba (időtúllépés). Jó a kód, és a hoszt megnyitotta a szobát?")


func _on_host_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"err":
			_retries = 99
			_fail(str(m.get("m", "A szoba elutasította a csatlakozást.")))
		"init":
			_begin_client(int(m.get("tick", 0)), m.get("ck", PackedByteArray()))
		"s":
			if not client:
				return
			for e in m.get("e", []):
				_in_ev[int(e[0])] = e[1]
			for c in m.get("c", []):
				_in_ck[int(c[0])] = c[1]
			_host_tick = max(_host_tick, int(m.get("n", 0)))


func _begin_client(t0: int, ck) -> void:
	if typeof(ck) != TYPE_PACKED_BYTE_ARRAY or ck.is_empty():
		_fail("Hibás kezdőállapot érkezett.")
		return
	# ha nálunk voltak vendégek, őket elengedjük: egy gép nem lehet egyszerre hoszt és vendég
	for c in _pcs + _hello:
		(c.ws as WebSocketPeer).close(1000, "host left")
	_pcs.clear()
	_hello.clear()
	client = true
	_state = "online"
	_retries = 0
	error = ""
	_pending.clear()
	_log.clear()
	_out_ev.clear()
	_out_ck.clear()
	_timers.clear()
	_in_ev.clear()
	_in_ck.clear()
	_in_ck[t0] = ck
	_init_tick = t0
	tick = t0 - 1
	_host_tick = t0
	_acc = 0.0
	_refill = false
	log_line("csatlakozva, kezdőállapot: %d. lépés, %d bájt" % [t0, ck.size()])
	# a nálunk lévő telefonok jelentkeznek a hosztnál
	for ph in Net.local_phones():
		submit({"k": "join", "pid": ph.pid, "name": ph.name})
	changed.emit()


func _client_frame(dt: float) -> void:
	var backlog := _host_tick - tick
	var n := _steps(dt)
	var was := catching
	catching = backlog > 45
	if catching != was:
		_set_quiet(catching)
	if catching:
		# gyorsított lejátszás: annyi lépés, amennyi egy képkockába belefér
		var t0 := Time.get_ticks_usec()
		while client and tick < _host_tick and Time.get_ticks_usec() - t0 < 12000:
			_client_tick()
		_acc = 0.0
		return
	if _refill:
		if backlog < BUFFER:
			return
		_refill = false
	if backlog - n > BUFFER + 2:
		n += 1
	n = min(n, backlog)
	if backlog == 0:
		_refill = true
	for i in n:
		if not client:
			return
		_client_tick()


func _client_tick() -> void:
	tick += 1
	var evs = _in_ev.get(tick)
	if evs != null:
		_in_ev.erase(tick)
		for ev in evs:
			if typeof(ev) == TYPE_DICTIONARY:
				_apply(ev)
	_run_timers()
	Main.I.step(TICK)


func _set_quiet(on: bool) -> void:
	Audio.quiet = on
	Net.quiet = on
	if not on:
		Net.resend_all()
	changed.emit()


## A Main kéri a lépés elején: van-e erre a lépésre mentés a hoszttól?
func take_checkpoint():
	var ck = _in_ck.get(tick)
	if ck != null:
		_in_ck.erase(tick)
	return ck


func is_init_checkpoint() -> bool:
	return tick == _init_tick


## A vendég a saját (a hoszttól függetlenül kiszámolt) állapotát összeveti a hosztéval.
func note_checkpoint(same: bool, mine: PackedByteArray, theirs: PackedByteArray) -> void:
	if same:
		ck_ok += 1
		log_line("mentés %d. lépés: EGYEZIK (%d bájt)" % [tick, theirs.size()])
		return
	ck_bad += 1
	log_line("mentés %d. lépés: ELTÉR (saját %d bájt, hoszt %d bájt) – a hoszté érvényes" % [tick, mine.size(), theirs.size()])
	if verbose:
		var dir := OS.get_environment("SYNC_DUMP")
		if dir != "":
			DirAccess.make_dir_recursive_absolute(dir)
			for pair in [["mine", mine], ["host", theirs]]:
				var f := FileAccess.open("%s/%d_%s.txt" % [dir, tick, pair[0]], FileAccess.WRITE)
				if f and not (pair[1] as PackedByteArray).is_empty():
					f.store_string(Snapshot.describe(pair[1]))


func _become_host(msg: String) -> void:
	client = false
	_state = ""
	error = msg
	_pending.clear()
	_log.clear()
	_in_ev.clear()
	_in_ck.clear()
	_timers.clear()
	_init_tick = -1
	if catching:
		catching = false
	_set_quiet(false)
	# vissza a saját lobbyba: csak a nálunk lévő telefonok maradnak
	var local := {}
	for ph in Net.local_phones():
		local[ph.pid] = true
	G.players = G.players.filter(func(p): return local.has(p.pid))
	for p in G.players:
		p.connected = true
		p.ready = false
	Net.bots.clear()
	Net.away.clear()
	Net.cancel_asks()
	G.phase = "lobby"
	Game.update_vip()
	Main.I.set_scene(LobbyScene.new(), true)
	log_line("vissza a saját lobbyba")


# ------------------------------------------------------------------ szobakód
## IPv4-cím (+ port) rövid, lediktálható kóddá. Az alap portnál 7 jel: ABC-DEFG.
static func make_code(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var v := 0
	for s in parts:
		if not s.is_valid_int():
			return ""
		v = (v << 8) | (int(s) & 255)
	var n := 7
	if port != DEFAULT_PORT:
		v = (v << 16) | (port & 0xffff)
		n = 10
	var out := ""
	for i in n:
		out = CODE_ALPHA[v & 31] + out
		v >>= 5
	var cut := 3 if n == 7 else 5
	return out.substr(0, cut) + "-" + out.substr(cut)


## Szobakód vagy cím -> "gép:port", hibás bemenetre "".
static func parse_target(text: String) -> String:
	var s := text.strip_edges()
	for pre in ["ws://", "http://", "https://"]:
		s = s.trim_prefix(pre)
	s = s.trim_suffix("/")
	if s == "":
		return ""
	if s.contains(".") or s.contains(":") or s.to_lower() == "localhost":
		var host := s
		var port := DEFAULT_PORT
		if s.count(":") == 1:
			host = s.get_slice(":", 0)
			port = int(s.get_slice(":", 1))
		if host == "" or host.contains(" ") or port <= 0 or port > 65535 or s.count(":") > 1:
			return ""
		return "%s:%d" % [host, port]
	var clean := ""
	for ch in s.to_upper():
		if CODE_ALPHA.contains(ch):
			clean += ch
	if clean.length() != 7 and clean.length() != 10:
		return ""
	var v := 0
	for ch in clean:
		v = (v << 5) | CODE_ALPHA.find(ch)
	var port := DEFAULT_PORT
	if clean.length() == 10:
		port = v & 0xffff
		v >>= 16
	if v > 0xffffffff or port == 0:
		return ""
	return "%d.%d.%d.%d:%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255, port]


static func is_private_ip(ip: String) -> bool:
	if ip.begins_with("10.") or ip.begins_with("192.168.") or ip.begins_with("127.") or ip.begins_with("169.254."):
		return true
	var p := ip.split(".")
	if p.size() == 4 and p[0] == "172" and int(p[1]) >= 16 and int(p[1]) <= 31:
		return true
	if p.size() == 4 and p[0] == "100" and int(p[1]) >= 64 and int(p[1]) <= 127:
		return true    # szolgáltatói NAT (CGNAT)
	return false


func port() -> int:
	return Net.ws_port


## A helyi hálózaton (vagy VPN-en) használható kód / cím.
func lan_ip() -> String:
	return Net.addresses[0] if Net.addresses.size() else ""


# ------------------------------------------------------------------ UPnP
## Megkéri a routert, hogy engedje be a szoba portját az internet felől, és lekéri a nyilvános címet.
func open_room() -> void:
	if upnp_state == "working" or upnp_state == "ok":
		return
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
	upnp_state = "working"
	upnp_msg = ""
	_upnp_port = port()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(_upnp_port))
	changed.emit()


func _upnp_work(p: int) -> void:
	var u := UPNP.new()
	var ok := false
	var ip := ""
	var msg := ""
	if u.discover(2500, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		msg = "A router nem engedi az automatikus portnyitást (UPnP)."
	elif u.add_port_mapping(p, p, "Party Mayhem", "TCP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		msg = "A router elutasította a portnyitást."
	else:
		ip = u.query_external_address()
		if ip == "" or not ip.is_valid_ip_address():
			msg = "A router nem árulta el a nyilvános címet."
		elif is_private_ip(ip):
			msg = "A szolgáltatód nem ad nyilvános címet (közös NAT mögött vagy)."
		else:
			ok = true
	_upnp_done.call_deferred(u, ok, ip, msg)


func _upnp_done(u: UPNP, ok: bool, ip: String, msg: String) -> void:
	_upnp = u
	public_ip = ip if ok else ""
	upnp_msg = msg
	upnp_state = "ok" if ok else "fail"
	log_line("UPnP: %s %s %s" % [upnp_state, ip, msg])
	changed.emit()
