extends Minigame
## Toronyépítő (3D) – a daru ide-oda lengeti a blokkot, koppintásra leejted. Ami lelóg, az
## letörik, így a torony egyre keskenyebb. Az időkeret végén a legmagasabb torony nyer.

const LIMIT := 38.0
const BH := 0.36
const DEPTH := 1.3
const HOVER := 1.25
const DROP := 0.16

var lane := 3.0
var amp := 1.1
var w0 := 1.3
var st: Array = []
var pieces: Array = []       # lehulló darabok
var cam_base := Vector3.ZERO
var box_mesh: BoxMesh


func meta() -> Dictionary:
	return {"id": "tower", "name": "Toronyépítő", "icon": "🏗️", "color": "#fcc419", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Pontosan ejtsd, magasra építsd!",
		"desc": "A daru ide-oda lengeti a blokkot a tornyod fölött. Koppints, és leejti! Ami lelóg a toronyról, az letörik, így a torony egyre keskenyebb – a pontos találat viszont nem veszít semmit. Ha teljesen mellé ejted, a blokk elvész. Az nyer, akinek a legmagasabb a tornya, amikor lejár az idő.",
		"controls": "Koppints az EJTSD gombra, amikor a blokk pont a torony fölött van."}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "🏗️ EJTSD!", "hint": "Akkor koppints, amikor a blokk pont a torony fölött van!", "rapid": true}


func _ready() -> void:
	make_env("#1864ab", "#d0ebff", 0.9)
	var n := players.size()
	lane = minf(3.4, 19.0 / maxi(1, n))
	amp = lane * 0.36
	w0 = lane * 0.42
	cam_base = Vector3(0, 6.2, 17.5)
	make_camera(cam_base, Vector3(0, 4.6, 0), 46)
	make_sun(Vector3(-45, -30, 0), 1.2)
	Chars3D.box(self, 90, 1.0, 50, Chars3D.mat("#74b816", {"rough": 0.95}), Vector3(0, -0.5, 0))
	var rnd := BoardLayout.Seeded.new(21)
	for i in 16:
		var bx := -34.0 + i * 4.6
		var h := 5.0 + rnd.next() * 12.0
		Chars3D.box(self, 3.4, h, 3.0, Chars3D.mat(["#4dabf7", "#748ffc", "#91a7ff", "#74c0fc"][i % 4], {"rough": 0.8}), Vector3(bx, h / 2.0, -12.0 - rnd.next() * 4.0))
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, BH, DEPTH)
	for i in n:
		var p = players[i]
		var x := (i - (n - 1) / 2.0) * lane
		Chars3D.box(self, lane * 0.9, 0.3, DEPTH + 1.0, Chars3D.mat("#868e96", {"rough": 0.8}), Vector3(x, 0.15, 0))
		var m := player_model(p, 1.1)
		var s := {"p": p, "x": x, "m": m, "blocks": 0, "top_cx": 0.0, "top_w": w0, "top_y": 0.3, "state": "swing", "st_t": 0.0, "ph": randf() * TAU,
			"off": 0.0, "cur": null, "rope": null, "last": "", "last_t": -9.0, "bot_t": 0.0, "bot_tol": 0.1, "perf": 0}
		_add_block(s, 0.0, w0, 0.3 + BH / 2.0, 0)
		s.top_y = 0.3 + BH
		s.blocks = 0
		s.cur = _mk_block(s, w0, 1)
		s.rope = Chars3D.cyl(self, 0.03, 0.03, 30.0, Chars3D.mat("#343a40"), 0, 0, 0, 6)
		_new_swing(s)
		st.append(s)
	_sync(0.0)


func _col(s: Dictionary, level: int) -> StandardMaterial3D:
	var c: Color = s.p.color
	c = c.lightened(0.28) if level % 2 == 0 else c.darkened(0.08)
	return Chars3D.mat("#" + c.to_html(false), {"rough": 0.45})


func _mk_block(s: Dictionary, w: float, level: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	mi.material_override = _col(s, level)
	mi.scale.x = w
	add_child(mi)
	return mi


func _add_block(s: Dictionary, cx: float, w: float, y: float, level: int) -> void:
	var mi := _mk_block(s, w, level)
	mi.position = Vector3(s.x + cx, y, 0)


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func _speed(s: Dictionary) -> float:
	return minf(5.2, 2.3 + s.blocks * 0.11)


func _new_swing(s: Dictionary) -> void:
	s.state = "swing"
	s.st_t = 0.0
	s.ph = randf() * TAU
	s.bot_t = randf_range(0.35, 1.0)
	var r := randf()
	s.bot_tol = (randf_range(0.03, 0.2) if r < 0.75 else randf_range(0.3, 0.8)) * s.top_w
	var cur: MeshInstance3D = s.cur
	cur.visible = true
	cur.scale.x = s.top_w
	cur.material_override = _col(s, s.blocks + 1)


func _offset(s: Dictionary) -> float:
	return sin(s.st_t * _speed(s) + s.ph) * amp


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var s := _get(p)
	if s.is_empty() or s.state != "swing" or s.st_t < 0.12:
		return
	s.off = _offset(s)
	s.state = "drop"
	s.st_t = 0.0
	Audio.play("step", 0.8)


func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.state != "swing":
		return
	s.bot_t -= dt
	if s.bot_t > 0:
		return
	if absf(_offset(s) - s.top_cx) < s.bot_tol:
		input(p, {"t": "tap"})


func update(dt: float) -> void:
	for s in st:
		s.st_t += dt
		if s.state == "drop" and s.st_t >= DROP:
			_place(s)
		elif s.state == "wait" and s.st_t >= 0.55:
			_new_swing(s)
		elif s.state == "miss" and s.st_t >= 1.0:
			_new_swing(s)
	for pc in pieces:
		pc.vy -= 22.0 * dt
		var mi: MeshInstance3D = pc.node
		mi.position += Vector3(pc.vx * dt, pc.vy * dt, 0)
		mi.rotation.z += pc.rot * dt
		if mi.position.y < -3.0:
			pc.dead = true
			mi.queue_free()
	pieces = pieces.filter(func(pc): return not pc.get("dead", false))
	if t >= LIMIT:
		finished = true
	_sync(dt)


func _piece(s: Dictionary, cx: float, w: float, y: float, dir: float) -> void:
	var mi := _mk_block(s, w, s.blocks + 1)
	mi.position = Vector3(s.x + cx, y, 0)
	pieces.append({"node": mi, "vx": dir * 1.6, "vy": 1.0, "rot": -dir * 4.0})


func _place(s: Dictionary) -> void:
	var d: float = s.off - s.top_cx
	var w: float = s.top_w
	var y: float = s.top_y + BH / 2.0
	var q := screen(Vector3(s.x + s.top_cx, s.top_y + BH, 0))
	(s.cur as MeshInstance3D).visible = false
	if absf(d) <= maxf(0.05, w * 0.07):
		# tökéletes: nem veszít a szélességből, sőt kicsit vissza is nő
		s.perf += 1
		s.top_w = minf(w0, w + 0.06)
		_add_block(s, s.top_cx, s.top_w, y, s.blocks + 1)
		s.last = "TÖKÉLETES!"
		Audio.play("coin", 1.0 + minf(0.6, s.perf * 0.08))
		Net.vibrate(s.p.pid, [30, 20, 60])
		Main.I.burst(q.x, q.y, {"n": 16, "colors": ["#ffd43b", "#ffffff"], "speed": 240, "life": 0.5})
	elif w - absf(d) < 0.1:
		s.perf = 0
		_piece(s, s.off, w, y, signf(d))
		s.last = "Mellé!"
		s.last_t = t
		s.state = "miss"
		s.st_t = 0.0
		Audio.play("bad")
		Net.vibrate(s.p.pid, 150)
		(s.m as Chars3D.CharModel).emote("sad")
		return
	else:
		s.perf = 0
		var nw := w - absf(d)
		var ncx: float = s.top_cx + d / 2.0
		_add_block(s, ncx, nw, y, s.blocks + 1)
		_piece(s, ncx + signf(d) * (nw / 2.0 + absf(d) / 2.0), absf(d), y, signf(d))
		s.top_cx = ncx
		s.top_w = nw
		s.last = ""
		Audio.play("land", 1.1)
	s.blocks += 1
	s.top_y += BH
	s.last_t = t
	s.state = "wait"
	s.st_t = 0.0
	(s.m as Chars3D.CharModel).land = 0.7


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	var maxh := 0.0
	for s in st:
		maxh = maxf(maxh, s.top_y)
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		m.position = Vector3(s.x, 0.3 + a.y, DEPTH / 2.0 + 0.75)
		m.rotation.y = a.spin
		var cur: MeshInstance3D = s.cur
		var rope: MeshInstance3D = s.rope
		var hy: float = s.top_y + HOVER
		if s.state == "swing":
			var off := _offset(s)
			cur.position = Vector3(s.x + off, hy, 0)
			rope.position = Vector3(s.x + off, hy + BH / 2.0 + 15.0, 0)
		elif s.state == "drop":
			var k: float = clampf(s.st_t / DROP, 0.0, 1.0)
			cur.position = Vector3(s.x + s.off, lerpf(hy, s.top_y + BH / 2.0, k * k), 0)
			rope.position = Vector3(s.x + s.off, hy + BH / 2.0 + 15.0, 0)
		else:
			rope.position.y = hy + BH / 2.0 + 15.0 + 0.5
	var lift := maxf(0.0, maxh - 6.5)
	var target := cam_base + Vector3(0, lift * 0.85, lift * 0.25)
	cam.position = cam.position.lerp(target, minf(1.0, dt * 3.0))


func ranking() -> Array:
	return rank_by(_rank_score, _rank_label)


func _rank_score(p) -> float:
	var s := _get(p)
	return float(s.blocks) + float(s.top_w) * 0.01


func _rank_label(p) -> String:
	return "%d emelet" % _get(p).blocks


func draw(c: CanvasItem) -> void:
	for s in st:
		var foot := screen(Vector3(s.x, 0.0, DEPTH / 2.0 + 0.75))
		var tix := team_of(s.p)
		var ncol: Color = MgFlow.TEAM_COLORS[tix].lightened(0.4) if tix >= 0 else Color.WHITE
		D.text(c, s.p.name, foot.x, foot.y + 18, {"size": 17, "stroke": Color.BLACK, "sw": 5, "maxw": 130, "color": ncol})
		D.text(c, "%d emelet" % s.blocks, foot.x, foot.y + 42, {"size": 22, "color": Color("#ffd43b"), "stroke": Color.BLACK, "sw": 5})
		if t - s.last_t < 0.8 and s.last != "":
			var q := screen(Vector3(s.x, s.top_y + 0.5, 0))
			D.text(c, s.last, q.x, q.y - (t - s.last_t) * 24, {"size": 20, "color": Color("#ff8787") if s.last == "Mellé!" else Color("#ffe066"), "stroke": Color.BLACK, "sw": 5, "maxw": 150})
	D.timer_hud(c, LIMIT - t)
	D.text(c, "🏗️ Ami lelóg, letörik – a legmagasabb torony nyer!", 30, 36, {"size": 20, "align": "left", "stroke": Color.BLACK, "sw": 5})
