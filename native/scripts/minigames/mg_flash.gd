extends Minigame
## Zseblámpás bújócska (3D) – sötét pályán a kereső zseblámpával vadászik, a többiek a ládák
## mögött bujkálnak és kristályokat gyűjtenek. Akit a fénykúp megvilágít, kiesik.
## 4 játékosnál 1 a 3 ellen megy; más létszámnál a játék sorsol keresőt (7+ játékosnál kettőt).

const LIMIT := 45.0
const AX := 11.5
const AZ := 7.2
const BODY := 0.42
const RANGE := 6.0
const HALF_ANG := 0.42
const CATCH := 0.7
const GRACE := 2.5
const CRATES := [
	[-6.5, -3.2, 1.2, 0.8], [6.5, -3.2, 1.2, 0.8], [-6.5, 3.2, 1.2, 0.8], [6.5, 3.2, 1.2, 0.8],
	[0.0, -4.2, 0.8, 1.0], [0.0, 4.2, 0.8, 1.0], [-3.2, 0.0, 0.7, 1.5], [3.2, 0.0, 0.7, 1.5],
	[-9.3, 0.0, 0.7, 0.9], [9.3, 0.0, 0.7, 0.9],
]

var st: Array = []
var gems: Array = []
var gem_t := 0.5
var hiders := 0
var caught := 0
var end_at := -1.0


func meta() -> Dictionary:
	return {"id": "flash", "name": "Zseblámpás bújócska", "icon": "🔦", "color": "#ffd43b", "modes": ["ffa", "1v3"],
		"tagline": "Bújj a fény elől!",
		"desc": "Sötét van! A kereső a zseblámpájával vadászik: akit a fénykúpja megvilágít, kiesik. A bújók a ládák mögé húzódva kristályokat gyűjtenek – a láda eltakarja a fényt. A kereső annyival jobb, minél több bújót kap el; a bújók a kristályokért és a túlélésért kapnak pontot.",
		"controls": "A joystickkal mozogsz. Keresőként arra világítasz, amerre mész. Bújóként gyűjtsd a kristályokat, és maradj takarásban!"}


func _seeker(p) -> bool:
	var s := _get(p)
	return not s.is_empty() and s.seek


func layout(p) -> Dictionary:
	if _seeker(p):
		return {"mode": "stick", "noBtn": true, "title": "🔦 Te vagy a kereső! Világíts rájuk!"}
	return {"mode": "stick", "noBtn": true, "title": "🙈 Bújj el, és gyűjts kristályt!"}


func _ready() -> void:
	make_env("#01030a", "#0b1230", 0.3)
	env.glow_intensity = 0.9
	make_camera(Vector3(0, 21.0, 12.5), Vector3(0, 0, 0.9), 50)
	make_sun(Vector3(-65, -30, 0), 0.16, "#8fb4ff")
	Chars3D.box(self, 80, 1.0, 60, Chars3D.mat("#0b1026", {"rough": 1.0}), Vector3(0, -0.56, 0))
	Chars3D.box(self, AX * 2, 1.0, AZ * 2, Chars3D.mat("#495057", {"rough": 0.9}), Vector3(0, -0.5, 0))
	for sz in [-1.0, 1.0]:
		Chars3D.box(self, AX * 2 + 1.0, 1.4, 0.5, Chars3D.mat("#343a40", {"rough": 0.9}), Vector3(0, 0.7, sz * (AZ + 0.25)))
		Chars3D.box(self, 0.5, 1.4, AZ * 2, Chars3D.mat("#343a40", {"rough": 0.9}), Vector3(sz * (AX + 0.25), 0.7, 0))
	for cr in CRATES:
		Chars3D.box(self, cr[2] * 2, 1.7, cr[3] * 2, Chars3D.mat("#a47148", {"rough": 0.85}), Vector3(cr[0], 0.85, cr[1]))
		Chars3D.box(self, cr[2] * 2 + 0.08, 0.14, cr[3] * 2 + 0.08, Chars3D.mat("#7f5539", {"rough": 0.85}), Vector3(cr[0], 1.7, cr[1]))
	# szerepek
	var n := players.size()
	var seekers: Array = []
	if teams.size() == 2:
		seekers = teams[0] if teams[0].size() < teams[1].size() else teams[1]
	else:
		var sh: Array = players.duplicate()
		sh.shuffle()
		seekers = sh.slice(0, 2 if n >= 7 else 1)
	var spots := [Vector2(-9.5, -5.5), Vector2(9.5, 5.5), Vector2(9.5, -5.5), Vector2(-9.5, 5.5), Vector2(-4.5, -5.8), Vector2(4.5, 5.8), Vector2(4.5, -5.8), Vector2(-4.5, 5.8)]
	var hi := 0
	var si := 0
	for p in players:
		var seek: bool = seekers.has(p)
		var m := player_model(p, 1.15)
		var pos := Vector2.ZERO
		if seek:
			pos = Vector2(-1.3 + si * 2.6 if seekers.size() > 1 else 0.0, 1.8)
			si += 1
		else:
			pos = spots[hi % spots.size()]
			hi += 1
		var s := {"p": p, "seek": seek, "x": pos.x, "z": pos.y, "ix": 0.0, "iy": 0.0, "yaw": 0.0, "m": m, "out": false, "lit": 0.0, "gems": 0,
			"catches": 0, "ai_t": 0.0, "tx": 0.0, "tz": 0.0, "spot": null, "glow": null}
		if seek:
			var sp := SpotLight3D.new()
			sp.light_color = Color("#fff3bf")
			sp.light_energy = 0.0
			sp.spot_range = RANGE + 1.5
			sp.spot_angle = rad_to_deg(HALF_ANG) + 3.0
			sp.spot_attenuation = 0.6
			sp.shadow_enabled = true
			add_child(sp)
			s.spot = sp
			var gl := OmniLight3D.new()
			gl.light_color = Color("#ffe066")
			gl.light_energy = 0.8
			gl.omni_range = 2.2
			add_child(gl)
			s.glow = gl
		else:
			var disc := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.5
			cy.bottom_radius = 0.5
			cy.height = 0.04
			disc.mesh = cy
			disc.material_override = Chars3D.mat(p.color_hex, {"emit": p.color_hex, "emit_e": 1.4})
			add_child(disc)
			s.glow = disc
		st.append(s)
	hiders = st.filter(func(s): return not s.seek).size()
	for i in 4:
		_spawn_gem()
	_sync(0.0)


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func _blocked(x: float, z: float, r: float) -> bool:
	for cr in CRATES:
		if absf(x - cr[0]) < cr[2] + r and absf(z - cr[1]) < cr[3] + r:
			return true
	return false


## van-e láda a két pont között
func _los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	for cr in CRATES:
		var t0 := 0.0
		var t1 := 1.0
		var ok := true
		for ax in 2:
			var lo: float = cr[ax] - cr[ax + 2]
			var hi: float = cr[ax] + cr[ax + 2]
			if absf(d[ax]) < 0.0001:
				if a[ax] < lo or a[ax] > hi:
					ok = false
					break
			else:
				var u: float = (lo - a[ax]) / d[ax]
				var v: float = (hi - a[ax]) / d[ax]
				t0 = maxf(t0, minf(u, v))
				t1 = minf(t1, maxf(u, v))
				if t0 > t1:
					ok = false
					break
		if ok:
			return false
	return true


func _spawn_gem() -> void:
	for tries in 30:
		var x := randf_range(-AX + 1.0, AX - 1.0)
		var z := randf_range(-AZ + 1.0, AZ - 1.0)
		if _blocked(x, z, 0.6):
			continue
		var g := Node3D.new()
		add_child(g)
		var gm := Chars3D.mat("#63e6be", {"emit": "#20c997", "emit_e": 2.6, "rough": 0.2})
		Chars3D.cone(g, 0.26, 0.4, gm, 0, 0.75, 0, 6)
		Chars3D.cone(g, 0.26, 0.4, gm, 0, 0.35, 0, 6, Vector3(PI, 0, 0))
		g.position = Vector3(x, 0, z)
		gems.append({"x": x, "z": z, "node": g, "dead": false})
		return


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "stick":
		return
	var s := _get(p)
	if s.is_empty() or s.out:
		return
	s.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)
	s.iy = clampf(float(msg.get("y", 0)), -1.0, 1.0)


func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.out:
		return
	s.ai_t -= dt
	var here := Vector2(s.x, s.z)
	if s.ai_t <= 0:
		s.ai_t = randf_range(0.3, 0.6)
		var best := INF
		if s.seek:
			for o in st:
				if o.seek or o.out:
					continue
				var d := here.distance_to(Vector2(o.x, o.z)) + randf() * 3.0
				if d < best:
					best = d
					s.tx = o.x + randf_range(-1.5, 1.5)
					s.tz = o.z + randf_range(-1.5, 1.5)
		else:
			for g in gems:
				var d := here.distance_to(Vector2(g.x, g.z)) + randf() * 2.0
				if d < best:
					best = d
					s.tx = g.x
					s.tz = g.z
	var dir := Vector2(s.tx - s.x, s.tz - s.z)
	if dir.length() > 0.3:
		dir = dir.normalized()
	if not s.seek:
		for o in st:
			if not o.seek:
				continue
			var away := here - Vector2(o.x, o.z)
			var dist := away.length()
			if dist < 8.0 and dist > 0.01:
				var facing := Vector2(sin(o.yaw), cos(o.yaw)).dot(away / dist)
				dir += away / dist * (2.6 if facing > 0.6 else 0.7) * (1.0 - dist / 8.0) * 2.0
		if dir.length() > 1.0:
			dir = dir.normalized()
	s.ix = dir.x
	s.iy = dir.y


func update(dt: float) -> void:
	for s in st:
		if s.out:
			continue
		var inp := Vector2(s.ix, s.iy)
		if inp.length() > 1.0:
			inp = inp.normalized()
		var sp := 4.3 if s.seek else 5.2
		if s.seek and t < GRACE:
			sp = 0.0
		var nx: float = clampf(s.x + inp.x * sp * dt, -AX + BODY, AX - BODY)
		var nz: float = clampf(s.z + inp.y * sp * dt, -AZ + BODY, AZ - BODY)
		if not _blocked(nx, s.z, BODY):
			s.x = nx
		if not _blocked(s.x, nz, BODY):
			s.z = nz
		if inp.length() > 0.25:
			var want := atan2(inp.x, inp.y)
			if s.seek:
				var diff := wrapf(want - s.yaw, -PI, PI)
				s.yaw += clampf(diff, -3.6 * dt, 3.6 * dt)
			else:
				s.yaw = lerp_angle(s.yaw, want, minf(1.0, dt * 12.0))
	# fénykúp
	for h in st:
		if h.seek or h.out:
			continue
		var lit := false
		if t >= GRACE:
			for sk in st:
				if not sk.seek:
					continue
				var a := Vector2(sk.x, sk.z)
				var b := Vector2(h.x, h.z)
				var d := b - a
				var dist := d.length()
				if dist > RANGE:
					continue
				var hit := dist < 0.9
				if not hit:
					hit = acos(clampf(Vector2(sin(sk.yaw), cos(sk.yaw)).dot(d / dist), -1.0, 1.0)) < HALF_ANG and _los(a, b)
				if hit:
					lit = true
					h.lit += dt
					if h.lit >= CATCH:
						_catch(sk, h)
					break
		if not lit:
			h.lit = maxf(0.0, h.lit - dt * 1.0)
	# kristályok
	gem_t -= dt
	if gem_t <= 0 and gems.size() < 4 + hiders / 2:
		gem_t = 1.4
		_spawn_gem()
	for g in gems:
		for h in st:
			if h.seek or h.out:
				continue
			if Vector2(h.x - g.x, h.z - g.z).length() < 0.8:
				g.dead = true
				h.gems += 1
				Audio.play("coin")
				Net.vibrate(h.p.pid, 30)
				var q := screen(Vector3(g.x, 0.8, g.z))
				Main.I.burst(q.x, q.y, {"n": 12, "colors": ["#63e6be", "#ffffff"], "speed": 220, "life": 0.5})
				Main.I.float_text(q.x, q.y - 16, "+1", Color("#96f2d7"), 26)
				break
	for g in gems:
		if g.dead:
			g.node.queue_free()
	gems = gems.filter(func(g): return not g.dead)
	if end_at < 0 and (t >= LIMIT or caught >= hiders):
		end_at = t + 1.2
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)


func _catch(sk: Dictionary, h: Dictionary) -> void:
	h.out = true
	caught += 1
	sk.catches += 1
	Audio.play("fail")
	Audio.play("bell")
	Net.vibrate(h.p.pid, [250, 80, 250])
	Net.vibrate(sk.p.pid, [40, 30, 80])
	var q := screen(Vector3(h.x, 1.0, h.z))
	Main.I.burst(q.x, q.y, {"n": 34, "colors": ["#fff3bf", "#ffd43b", "#ffffff"], "speed": 340})
	Main.I.float_text(q.x, q.y - 30, "MEGVAN!", Color("#ffd43b"), 40)
	(h.m as Chars3D.CharModel).emote("dizzy")
	(sk.m as Chars3D.CharModel).emote("happy")
	Net.set_ctrl(h.p.pid, {"mode": "wait", "icon": "🔦", "title": "Megtaláltak!", "text": "%d kristályt gyűjtöttél" % h.gems})


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var moving: bool = Vector2(s.ix, s.iy).length() > 0.25 and not s.out
		var hop: float = absf(sin(Main.I.time * 12.0 + s.x)) * 0.13 if moving else 0.0
		m.position = Vector3(s.x, a.y + hop, s.z)
		m.rotation.y = s.yaw + a.spin
		if s.seek:
			var sp: SpotLight3D = s.spot
			var fwd := Vector3(sin(s.yaw), -0.16, cos(s.yaw)).normalized()
			sp.position = Vector3(s.x, 1.25, s.z) + fwd * 0.3
			sp.basis = Basis.looking_at(fwd, Vector3.UP)
			sp.light_energy = 0.0 if t < GRACE and t > 0.0 else (14.0 if t >= GRACE else 0.0)
			(s.glow as OmniLight3D).position = Vector3(s.x, 1.4, s.z)
		else:
			var disc: MeshInstance3D = s.glow
			disc.position = Vector3(s.x, 0.03, s.z)
			disc.visible = not s.out
			m.scale = Vector3.ONE * (0.8 if s.out else 1.15)
	for g in gems:
		(g.node as Node3D).rotation.y = Main.I.time * 2.0
		(g.node as Node3D).position.y = sin(Main.I.time * 3.0 + g.x) * 0.08


func _score(s: Dictionary) -> float:
	if teams.size() == 2:
		if s.seek:
			return 10.0 * caught / maxf(1.0, hiders)
		return (0.0 if s.out else 10.0) + s.gems * 0.01
	if s.seek:
		return float(roundi(12.0 * s.catches / maxf(1.0, hiders))) + 0.5
	return float(s.gems) + (0.0 if s.out else 5.0)


func ranking() -> Array:
	return rank_by(func(p): return _score(_get(p)), _rank_label)


func _rank_label(p) -> String:
	var s := _get(p)
	if s.seek:
		return "🔦 %d elkapva" % s.catches
	return "💎 %d%s" % [s.gems, "" if s.out else " + túlélte"]


func draw(c: CanvasItem) -> void:
	for s in st:
		var q := screen(Vector3(s.x, 1.9, s.z))
		var col: Color = Color("#ffe066") if s.seek else s.p.color.lightened(0.5)
		if s.out:
			col = Color("#868e96")
		var label: String = ("🔦 " if s.seek else "") + s.p.name + ("" if s.seek else "  💎%d" % s.gems)
		D.text(c, label, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 5, "maxw": 160, "color": col})
		if not s.seek and not s.out and s.lit > 0.02:
			var k: float = clampf(s.lit / CATCH, 0.0, 1.0)
			c.draw_arc(Vector2(q.x, q.y - 26), 13, -PI / 2, -PI / 2 + TAU * k, 24, Color("#ffd43b"), 5, true)
			D.text(c, "❗", q.x, q.y - 26, {"size": 16})
		if s.out:
			D.text(c, "✖", q.x, q.y - 24, {"size": 22, "color": Color("#ff6b6b"), "stroke": Color.BLACK, "sw": 5})
	D.timer_hud(c, LIMIT - t)
	D.text(c, "🔦 Elkapva: %d / %d" % [caught, hiders], 30, 36, {"size": 24, "align": "left", "stroke": Color.BLACK, "sw": 6})
	D.text(c, "A ládák eltakarják a fényt", 30, 68, {"size": 17, "align": "left", "color": Color("#ced4da"), "stroke": Color.BLACK, "sw": 4})
	if t < GRACE:
		D.text(c, "🙈 Bújjatok el! A lámpa mindjárt felkapcsol…", 640, 110, {"size": 34, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 9})
