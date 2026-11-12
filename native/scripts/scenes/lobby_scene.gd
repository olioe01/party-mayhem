class_name LobbyScene
extends GameScene
## Lobby: csatlakozás QR-kóddal, figura választás, indítás. A háttérben a 3D tábla forog,
## a csatlakozott játékosok figurái a rajtnál várakoznak.

const ROUND_OPTIONS := [5, 10, 15, 20]

var url := ""
var qr_tex: Texture2D
var seen := {}
var going := false
var b3: Board3D
var orbit := 0.0


func enter() -> void:
	G.phase = "lobby"
	Audio.music("lobby")
	url = Net.join_url()
	qr_tex = _make_qr(url)
	if G.board == null:
		G.board = BoardLayout.build()
	b3 = Board3D.get_for(G.board)
	if b3.get_parent():
		b3.get_parent().remove_child(b3)
	add_child(b3)
	b3.activate()
	b3.set_dusk(false)
	b3._dusk_now = 0.0
	b3.cam_mode = "manual"
	refresh()


func exit() -> void:
	if b3 and b3.get_parent() == self:
		remove_child(b3)


func _make_qr(text: String) -> Texture2D:
	var m: Array = QR.encode(text)
	if m.is_empty():
		return null
	var n := m.size()
	var px := 10
	var q := 2
	var img := Image.create((n + q * 2) * px, (n + q * 2) * px, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var dark := Color("#1b1036")
	for y in n:
		for x in n:
			if m[y][x]:
				img.fill_rect(Rect2i((x + q) * px, (y + q) * px, px, px), dark)
	return ImageTexture.create_from_image(img)


func can_start() -> bool:
	if G.players.is_empty():
		return false
	for p in G.players:
		if not p.ready and p.connected:
			return false
	return true


func refresh() -> void:
	var can := can_start()
	var chars: Array = []
	for c in G.CHARS:
		chars.append({"id": c.id, "name": c.name})
	for p in G.players:
		var taken: Array = []
		for q in G.players:
			if q != p:
				taken.append(q.char_id)
		Net.set_ctrl(p.pid, {"mode": "lobby", "chars": chars, "taken": taken, "char": p.char_id, "ready": p.ready,
			"vip": p.pid == G.vip, "rounds": G.max_rounds, "roundOptions": ROUND_OPTIONS, "canStart": can, "count": G.players.size(),
			"gameMode": G.mode, "gameModes": G.MODES})


func players_changed() -> void:
	refresh()


func input(pid: String, msg: Dictionary) -> void:
	var p = G.by_pid(pid)
	if p == null:
		return
	var tt := str(msg.get("t", ""))
	if tt == "char":
		var v := str(msg.get("v", ""))
		var free := true
		for q in G.players:
			if q != p and q.char_id == v:
				free = false
		if free and G.CHARS.any(func(c): return c.id == v):
			p.char_id = v
			Audio.play("pop")
			b3.emote(p.pid, "happy")
	elif tt == "ready":
		p.ready = bool(msg.get("v", false))
		if p.ready:
			Audio.play("select")
			_cheer(p)
	elif tt == "rounds" and pid == G.vip and ROUND_OPTIONS.has(int(msg.get("v", 0))):
		G.max_rounds = int(msg.v)
		Audio.play("select")
	elif tt == "mode" and pid == G.vip:
		set_mode(str(msg.get("v", "")))
		return
	elif tt == "start" and pid == G.vip and can_start():
		go()
		return
	else:
		return
	refresh()


func set_mode(id: String) -> void:
	if id == G.mode or not G.MODES.any(func(m): return m.id == id):
		return
	G.mode = id
	Audio.play("select")
	refresh()


func _cheer(p) -> void:
	var i := G.players.find(p)
	var s := slot_pos(i)
	Main.I.burst(s.x, s.y - 10, {"n": 24, "colors": [p.color_hex, "#ffffff", "#ffd43b"], "speed": 380})
	b3.emote(p.pid, "cheer")


func go() -> void:
	if G.players.is_empty() or going:
		return
	going = true
	Audio.play("fanfare")
	Game.start_game()


func key(e: InputEventKey) -> void:
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		go()
	elif e.keycode == KEY_B:
		add_bot()
	elif e.keycode == KEY_J:
		set_mode("mountain" if G.mode == "crown" else "crown")
	elif e.keycode == KEY_RIGHT or e.keycode == KEY_LEFT:
		var i := ROUND_OPTIONS.find(G.max_rounds)
		var j := clampi((1 if i < 0 else i) + (1 if e.keycode == KEY_RIGHT else -1), 0, ROUND_OPTIONS.size() - 1)
		G.max_rounds = ROUND_OPTIONS[j]
		refresh()


func add_bot() -> void:
	if G.players.size() >= G.MAX_PLAYERS:
		return
	var n := G.players.filter(func(p): return p.is_bot).size() + 1
	Net.add_bot("Bot %d" % n)
	Audio.play("pop")


func remove_bot() -> void:
	for i in range(G.players.size() - 1, -1, -1):
		var b = G.players[i]
		if b.is_bot:
			Net.remove_bot(b.pid)
			G.players.remove_at(i)
			Game.update_vip()
			refresh()
			return


func slot_pos(i: int) -> Vector2:
	return Vector2(545 + (i % 4) * 182, 240 + (i / 4) * 205)


func update(dt: float) -> void:
	for p in G.players:
		if not seen.has(p.pid):
			seen[p.pid] = t
			Audio.play("pop")
	# a figurák a rajt körül állnak, a kamera lassan körbejár
	orbit += dt * 0.07
	var st: Dictionary = G.board.nodes[G.board.start]
	var pawns: Array = []
	var n := G.players.size()
	for i in n:
		var a = float(i) / max(1, n) * TAU
		pawns.append({"p": G.players[i], "x": st.x + cos(a) * 34 * min(1, n - 1), "y": st.y + sin(a) * 22 * min(1, n - 1), "h": 0.0, "current": false})
	var center := Board3D.w(st.x, st.y)
	b3.cam_pos = center + Vector3(sin(orbit) * 9.0, 4.2, cos(orbit) * 9.0)
	b3.cam_look_pos = center + Vector3(0, 0.6, 0)
	b3.render({"pawns": pawns, "crown": null}, dt)


func draw(c: CanvasItem) -> void:
	# sötétítés, hogy a feliratok olvashatók legyenek
	D.vgrad(c, Color(0.1, 0.04, 0.24, 0.72), Color(0.05, 0.03, 0.14, 0.55))
	var title := "PARTY MAYHEM"
	var x := 60.0
	var cols := ["#ff4d6d", "#ffd43b", "#51cf66", "#4dabf7", "#b197fc"]
	for i in title.length():
		var ch := title[i]
		var w := D.text_width(ch, 64)
		var y := 78 + sin(Main.I.time * 3.0 + i * 0.5) * 6
		D.text(c, ch, x + w / 2, y, {"size": 64, "color": Color(cols[i % 5]), "stroke": D.DARK, "sw": 10})
		x += w + 2
	D.text(c, "Táblás partijáték – a telefonod a kontroller!", 62, 128, {"size": 22, "color": Color("#d6ccff"), "align": "left"})

	D.panel(c, 50, 160, 380, 470, {"fill": Color(0.1, 0.06, 0.25, 0.82)})
	D.text(c, "📱 Csatlakozz!", 240, 196, {"size": 30})
	D.panel(c, 95, 222, 290, 290, {"r": 18, "fill": Color.WHITE, "stroke": null, "shadow": false})
	if qr_tex:
		c.draw_texture_rect(qr_tex, Rect2(105, 232, 270, 270), false)
	D.text(c, "Olvasd be, vagy írd be:", 240, 540, {"size": 19, "color": Color("#cfc6f5")})
	D.text(c, url.replace("http://", ""), 240, 574, {"size": 28, "color": Color("#ffd43b"), "maxw": 350})
	if Net.server_error != "":
		D.text(c, Net.server_error, 240, 607, {"size": 14, "color": Color("#ff8787"), "maxw": 360})
	else:
		D.text(c, "Ugyanazon a Wi-Fi hálózaton legyél!", 240, 607, {"size": 16, "color": Color("#a99fd6"), "bold": false})

	D.text(c, "Játékosok (%d/%d)" % [G.players.size(), G.MAX_PLAYERS], 470, 152, {"size": 26, "align": "left"})
	# játékmód-választó
	D.text(c, "Játékmód:", 700, 36, {"size": 20, "align": "left", "color": Color("#d6ccff")})
	for i in G.MODES.size():
		var gm: Dictionary = G.MODES[i]
		var sel: bool = gm.id == G.mode
		var mid: String = gm.id
		button(c, 700 + i * 275, 54, 262, 50, "%s %s" % [gm.icon, gm.name], func(): set_mode(mid),
			{"color": Color("#ffd43b") if sel else Color("#4b3a8a"), "text_color": Color("#2b1055") if sel else Color.WHITE, "size": 23})
	D.text(c, G.mode_info().desc, 700, 128, {"size": 17, "align": "left", "color": Color("#ffe8a3"), "maxw": 540, "bold": false})
	for i in G.MAX_PLAYERS:
		var s := slot_pos(i)
		var p = G.players[i] if i < G.players.size() else null
		if p == null:
			D.panel(c, s.x - 80, s.y - 75, 160, 185, {"r": 22, "fill": Color(1, 1, 1, 0.06), "stroke": Color(1, 1, 1, 0.18), "shadow": false})
			D.text(c, "?", s.x, s.y + 5, {"size": 48, "color": Color(1, 1, 1, 0.15)})
			continue
		D.panel(c, s.x - 80, s.y - 75, 160, 185, {"r": 22, "fill": Color(D.shade(p.color, -0.55), 0.92), "stroke": p.color})
		var age: float = t - seen.get(p.pid, t)
		var pop := D.ease_out_back(min(1.0, age * 2.5))
		var bob: float = abs(sin(Main.I.time * 5.0 + i)) * 10.0 if p.ready else 0.0
		D.avatar(c, p, s.x, s.y - bob, 44 * pop, {"alpha": 1.0 if p.connected else 0.4})
		D.text(c, p.name, s.x, s.y + 68, {"size": 22, "maxw": 150})
		D.text(c, "✔ KÉSZ" if p.ready else ("választ…" if p.connected else "lecsatlakozott"), s.x, s.y + 95,
			{"size": 17, "color": Color("#69db7c") if p.ready else Color("#bbbbbb")})
		if p.pid == G.vip:
			D.text(c, "⭐ VIP", s.x + 50, s.y - 58, {"size": 15, "color": Color("#ffd43b")})
		if p.is_bot:
			D.text(c, "🤖", s.x - 58, s.y - 56, {"size": 20})

	if G.is_mountain():
		D.text(c, "⛰️ %d mező a csúcsig · az első nyer" % MountainLayout.GOAL, 470, 668, {"size": 21, "align": "left", "color": Color("#ffe8a3"), "maxw": 370})
	else:
		D.text(c, "Körök:", 470, 668, {"size": 24, "align": "left"})
	for i in ROUND_OPTIONS.size():
		if G.is_mountain():
			break
		var r: int = ROUND_OPTIONS[i]
		var on: bool = r == G.max_rounds
		button(c, 555 + i * 72, 645, 62, 46, str(r), func():
			G.max_rounds = r
			Audio.play("select")
			refresh(), {"color": Color("#ffd43b") if on else Color("#4b3a8a"), "text_color": Color("#2b1055") if on else Color.WHITE, "size": 22})
	button(c, 855, 645, 110, 46, "+ Bot", add_bot, {"color": Color("#4dabf7"), "size": 20})
	button(c, 975, 645, 90, 46, "− Bot", remove_bot, {"color": Color("#868e96"), "size": 20})
	var can := not G.players.is_empty()
	button(c, 1080, 640, 160, 56, "INDÍTÁS", go, {"color": Color("#51cf66") if can else Color("#555555"), "size": 26})
	D.text(c, "A ⭐ VIP a telefonjáról is indíthat, ha mindenki kész. Itt: ENTER = indítás", 50, 668, {"size": 14, "color": Color("#b0a6e0"), "align": "left", "bold": false, "maxw": 400})
	D.text(c, "B = bot · J = játékmód · F = teljes képernyő · M = hang · P = FPS", 50, 690, {"size": 14, "color": Color("#b0a6e0"), "align": "left", "bold": false})
