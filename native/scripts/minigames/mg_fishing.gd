extends Minigame
## Horgászverseny (3D) – koppints, amikor az úszó lemerül. Aki korán ránt, annak elúszik a
## hal. Kis hal 1 pont, nagy hal 3 pont, ócska bakancs −1. A víz alatti árnyékból látszik,
## mi közeledik: a bakancsot érdemes békén hagyni. A fogások sorrendje mindenkinél ugyanaz.

const LIMIT := 45.0
const SHORE_Z := -2.2
const BOB_Z := 1.6
const KINDS := {
	"small": {"val": 1, "win": 0.8, "icon": "🐟", "name": "Kis hal"},
	"big": {"val": 3, "win": 0.52, "icon": "🐠", "name": "Nagy hal"},
	"boot": {"val": -1, "win": 0.85, "icon": "🥾", "name": "Bakancs"},
}

var lane := 3.0
var seq: Array = []
var st: Array = []


func meta() -> Dictionary:
	return {"id": "fishing", "name": "Horgászverseny", "icon": "🎣", "color": "#4dabf7", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Ránts, amikor kapás van!",
		"desc": "Mindenki a saját úszóját figyeli. Amikor az úszó lemerül, koppints gyorsan! Ha korán rántasz, elúszik a hal. A víz alatti árnyék elárulja, mi jön: a kis hal 1 pont, a nagy hal 3 pont (de gyorsabban elszökik), az ócska bakancs viszont −1 – azt hagyd békén!",
		"controls": "Koppints a RÁNTS gombra, amikor lemerül az úszód. Az apró rezdülés még nem kapás!"}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "🎣 RÁNTS!", "hint": "Akkor koppints, amikor lemerül az úszó! A bakancsot hagyd békén.", "rapid": true}


func _ready() -> void:
	for i in 60:
		var r := randf()
		seq.append("small" if r < 0.5 else ("big" if r < 0.73 else "boot"))
	seq[0] = "small"
	make_env("#1c7ed6", "#d0ebff", 0.95)
	var n := players.size()
	lane = minf(3.2, 18.0 / maxi(1, n))
	make_camera(Vector3(0, 9.5, 11.5), Vector3(0, 0.3, -0.2), 46)
	make_sun(Vector3(-52, 20, 0), 1.25)
	# tó, part, stég
	Chars3D.box(self, 90, 1.0, 60, Chars3D.mat("#1864ab", {"rough": 0.9}), Vector3(0, -1.0, 0))
	Chars3D.box(self, 90, 0.1, 60, Chars3D.mat("#339af0", {"rough": 0.08, "metal": 0.25, "alpha": 0.78}), Vector3(0, -0.12, 0))
	Chars3D.box(self, 90, 1.6, 20, Chars3D.mat("#69b34c", {"rough": 0.95}), Vector3(0, -0.5, SHORE_Z - 11.2))
	Chars3D.box(self, maxf(10.0, n * lane + 1.0), 0.25, 2.2, Chars3D.mat("#b08968", {"rough": 0.8}), Vector3(0, 0.28, SHORE_Z))
	var rnd := BoardLayout.Seeded.new(8)
	for i in 12:
		var g := Node3D.new()
		g.position = Vector3(-26 + i * 4.8 + rnd.next() * 2.0, 0.3, SHORE_Z - 4.0 - rnd.next() * 6.0)
		g.scale = Vector3.ONE * (1.6 + rnd.next() * 1.2)
		add_child(g)
		Chars3D.cyl(g, 0.08, 0.11, 0.6, Chars3D.mat("#8b5e34"), 0, 0.3, 0, 8)
		Chars3D.cone(g, 0.45, 1.1, Chars3D.mat("#2f9e44"), 0, 1.1, 0, 8)
	var shadow_m := Chars3D.mat("#0b2545", {"alpha": 0.6, "rough": 1.0})
	var boot_m := Chars3D.mat("#5c3d1e", {"alpha": 0.8, "rough": 1.0})
	for i in n:
		var p = players[i]
		var x := (i - (n - 1) / 2.0) * lane
		for sx in [-1.0, 1.0]:
			Chars3D.cyl(self, 0.1, 0.1, 1.4, Chars3D.mat("#7f5539"), x + sx * lane * 0.4, -0.3, SHORE_Z + 0.9, 8)
		var m := player_model(p, 1.2)
		# bot és úszó
		var rod := Chars3D.cyl(self, 0.03, 0.045, 2.6, Chars3D.mat("#5c3d1e"), x + 0.35, 1.9, SHORE_Z + 1.2, 6, Vector3(0.95, 0, 0))
		var bob := Node3D.new()
		add_child(bob)
		Chars3D.sphere(bob, 0.2, Chars3D.mat("#fa5252", {"rough": 0.3}), 0, 0.08, 0)
		Chars3D.sphere(bob, 0.2, Chars3D.mat("#ffffff", {"rough": 0.3}), 0, -0.02, 0, 1.02, 0.6, 1.02)
		Chars3D.cyl(bob, 0.02, 0.02, 0.3, Chars3D.mat(p.color_hex), 0, 0.35, 0, 6)
		# árnyékok: kis hal, nagy hal, bakancs
		var sh := {}
		var g1 := Node3D.new()
		add_child(g1)
		Chars3D.sphere(g1, 0.3, shadow_m, 0, 0, 0, 1.0, 0.12, 0.42)
		Chars3D.cone(g1, 0.16, 0.26, shadow_m, -0.36, 0, 0, 4, Vector3(0, 0, -PI / 2))
		sh["small"] = g1
		var g2 := Node3D.new()
		add_child(g2)
		Chars3D.sphere(g2, 0.62, shadow_m, 0, 0, 0, 1.0, 0.1, 0.45)
		Chars3D.cone(g2, 0.32, 0.46, shadow_m, -0.74, 0, 0, 4, Vector3(0, 0, -PI / 2))
		sh["big"] = g2
		var g3 := Node3D.new()
		add_child(g3)
		Chars3D.box(g3, 0.3, 0.06, 0.62, boot_m, Vector3(-0.18, 0, 0))
		Chars3D.box(g3, 0.62, 0.06, 0.3, boot_m, Vector3(0.0, 0, 0.3))
		sh["boot"] = g3
		st.append({"p": p, "x": x, "m": m, "rod": rod, "bob": bob, "sh": sh, "idx": 0, "state": "wait", "st_t": 0.0, "dur": 2.0,
			"score": 0, "caught": 0, "best": 0.0, "last": "", "last_t": -9.0, "last_icon": "", "nib": [], "bot_at": -1.0, "ang": randf() * TAU, "dip": 0.0})
	for s in st:
		_begin_wait(s, true)
	_sync(0.0)


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func _kind(s: Dictionary) -> String:
	return seq[s.idx % seq.size()]


func _begin_wait(s: Dictionary, first := false) -> void:
	s.state = "wait"
	s.st_t = 0.0
	s.dur = randf_range(2.2, 3.4) if first else randf_range(1.5, 4.0)
	s.ang = randf() * TAU
	# apró rezdülések a kapás előtt
	var nib: Array = []
	var tt := randf_range(0.5, 1.2)
	while tt < s.dur - 0.5:
		if randf() < 0.6:
			nib.append(tt)
		tt += randf_range(0.5, 1.1)
	s.nib = nib


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var s := _get(p)
	if s.is_empty() or s.state == "cool":
		return
	var kind := _kind(s)
	var k: Dictionary = KINDS[kind]
	var q := screen(Vector3(s.x, 0.6, BOB_Z))
	if s.state == "wait":
		if s.st_t < 0.25:
			return
		s.last = "Korán rántottál – elúszott!"
		s.last_icon = "💨"
		Audio.play("bad")
		Net.vibrate(p.pid, 120)
		(s.m as Chars3D.CharModel).emote("sad")
		_cool(s, 1.3)
		return
	# kapás
	var val: int = k.val
	s.score = maxi(0, s.score + val)
	s.last = "%s  %s%d" % [k.name, "+" if val > 0 else "−", absi(val)]
	s.last_icon = k.icon
	if val > 0:
		s.caught += 1
		Audio.play("crown" if val > 1 else "coin")
		Net.vibrate(p.pid, [40, 30, 90] if val > 1 else 35)
		Main.I.burst(q.x, q.y, {"n": 26 if val > 1 else 12, "colors": ["#a5d8ff", "#ffffff", s.p.color_hex], "speed": 300})
		Main.I.float_text(q.x, q.y - 40, "%s +%d" % [k.icon, val], Color("#ffe066") if val > 1 else Color.WHITE, 40 if val > 1 else 30)
		(s.m as Chars3D.CharModel).emote("happy")
	else:
		Audio.play("fail")
		Net.vibrate(p.pid, [150, 60, 150])
		Main.I.float_text(q.x, q.y - 40, "🥾 −1", Color("#ff8787"), 36)
		(s.m as Chars3D.CharModel).emote("sad")
	Audio.play("splash")
	_cool(s, 0.9)


func _cool(s: Dictionary, sec: float) -> void:
	s.state = "cool"
	s.st_t = 0.0
	s.dur = sec
	s.last_t = t
	s.idx += 1


func bot(p, _dt: float) -> void:
	var s := _get(p)
	if s.state != "bite" or s.bot_at < 0:
		return
	if s.st_t >= s.bot_at:
		s.bot_at = -1.0
		input(p, {"t": "tap"})


func update(dt: float) -> void:
	for s in st:
		s.st_t += dt
		if s.state == "wait" and s.st_t >= s.dur:
			s.state = "bite"
			s.st_t = 0.0
			var kind := _kind(s)
			s.dur = KINDS[kind].win
			# a gép néha lekési a halat, a bakancsot többnyire kihagyja
			var react := randf_range(0.22, 0.75)
			s.bot_at = react if (kind != "boot" or randf() < 0.2) else -1.0
			Audio.play("pop", 0.8)
			var q := screen(Vector3(s.x, 0.0, BOB_Z))
			Main.I.burst(q.x, q.y, {"n": 8, "colors": ["#ffffff", "#a5d8ff"], "speed": 150, "life": 0.4})
		elif s.state == "bite" and s.st_t >= s.dur:
			var boot := _kind(s) == "boot"
			s.last = "Ügyes, kihagytad a bakancsot!" if boot else "Elszökött…"
			s.last_icon = "👍" if boot else "💨"
			_cool(s, 0.6)
		elif s.state == "cool" and s.st_t >= s.dur:
			_begin_wait(s)
	if t >= LIMIT:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		m.position = Vector3(s.x, 0.4 + a.y, SHORE_Z)
		m.rotation.y = a.spin
		var dip := 0.0
		if s.state == "bite":
			dip = 0.42 + sin(s.st_t * 30.0) * 0.05
		elif s.state == "wait":
			for nt in s.nib:
				var d: float = s.st_t - nt
				if d > 0 and d < 0.22:
					dip = sin(d / 0.22 * PI) * 0.1
		s.dip = lerpf(s.dip, dip, minf(1.0, dt * 25.0))
		var bob: Node3D = s.bob
		bob.visible = s.state != "cool"
		bob.position = Vector3(s.x, sin(Main.I.time * 2.0 + s.x) * 0.025 - s.dip, BOB_Z)
		(s.rod as MeshInstance3D).rotation.x = 0.95 - (0.35 if s.state == "cool" and s.st_t < 0.3 else 0.0)
		# árnyék: körözve közeledik az úszóhoz
		var kind := _kind(s)
		for kk in s.sh:
			(s.sh[kk] as Node3D).visible = false
		if s.state == "wait" or s.state == "bite":
			var g: Node3D = s.sh[kind]
			g.visible = true
			var k: float = clampf(s.st_t / s.dur, 0.0, 1.0) if s.state == "wait" else 1.0
			var r := lerpf(minf(1.5, lane * 0.42), 0.25, k)
			var ang: float = s.ang + (s.st_t if s.state == "wait" else 0.0) * 1.7
			if s.state == "bite":
				ang = s.ang + s.dur * 0.0 + Main.I.time * 9.0
				r = 0.15
			g.position = Vector3(s.x + cos(ang) * r, -0.05, BOB_Z + sin(ang) * r * 0.8)
			g.rotation.y = -ang - PI / 2


func ranking() -> Array:
	return rank_by(_rank_score, _rank_label)


func _rank_score(p) -> float:
	var s := _get(p)
	return float(s.score) + float(s.caught) * 0.01


func _rank_label(p) -> String:
	return "%d pont" % _get(p).score


func draw(c: CanvasItem) -> void:
	for s in st:
		# damil a bot végétől az úszóig
		var tip := screen(Vector3(s.x + 0.35, 2.65, SHORE_Z + 2.25))
		var bq := screen((s.bob as Node3D).position + Vector3(0, 0.2, 0))
		if s.state != "cool":
			c.draw_line(tip, bq, Color(1, 1, 1, 0.7), 1.5, true)
		if s.state == "bite":
			var pulse := 1.0 + sin(Main.I.time * 26.0) * 0.15
			D.text(c, "❗", bq.x, bq.y - 46, {"size": int(44 * pulse)})
		var foot := screen(Vector3(s.x, 0.4, SHORE_Z))
		var tix := team_of(s.p)
		var ncol: Color = MgFlow.TEAM_COLORS[tix].lightened(0.4) if tix >= 0 else Color.WHITE
		D.text(c, "%s  %d" % [s.p.name, s.score], foot.x, foot.y - 92, {"size": 18, "stroke": Color.BLACK, "sw": 5, "maxw": 150, "color": ncol})
		if t - s.last_t < 1.1 and s.last != "":
			var q := screen(Vector3(s.x, 0.3, BOB_Z))
			D.text(c, s.last_icon, q.x, q.y - 30 - (t - s.last_t) * 26, {"size": 34})
			D.text(c, s.last, q.x, q.y + 12, {"size": 16, "stroke": Color.BLACK, "sw": 5, "maxw": lane * 62.0, "color": Color("#fff3bf")})
	D.timer_hud(c, LIMIT - t)
	D.text(c, "🐟 +1    🐠 nagy hal +3    🥾 bakancs −1", 30, 36, {"size": 20, "align": "left", "stroke": Color.BLACK, "sw": 5})
	D.score_bar(c, st.map(func(s): return s.p), func(p): return _get(p).score, 680)
