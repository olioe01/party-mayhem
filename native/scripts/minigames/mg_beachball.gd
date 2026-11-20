extends Minigame
## Labdazápor (1 a 3 ellen) – trópusi strandmedence. A három ellenfél egy keskeny rózsaszín gerendán áll
## a víz fölött, az egyedül játszó elölről, a peremről hajigálja feléjük a nagy narancssárga strandlabdákat.
## Akit eltalál, a vízbe pottyan és kiesik. Ha 30 mp alatt mindhárom leesik, az egyedül játszó nyer;
## ha legalább egy fent marad, az ellenfelek.

const K = preload("res://scripts/minigames/mg_kit.gd")

const LIMIT := 30.0
const BEAM_Z := -2.6
const BEAM_Y := 0.75
const BEAM_HALF := 4.0             # a gerenda fél hossza
const RIVAL_SPEED := 3.7
const RIVAL_R := 0.36
const SOLO_Z := 5.2
const AIM_SPEED := 5.5
const AIM_MAX := 4.3
const THROW_CD := 0.75
const FLY := 0.95                  # a labda ennyi idő alatt ér a gerendához
const BALL_R := 0.42
const HIT_DX := 0.7                # ennyire kell a labdának a figura vonalába érnie

var solo = null
var rivals: Array = []
var rs: Array = []                 # ellenfelek állapota
var ss: Dictionary = {}            # az egyedül játszó állapota
var balls: Array = []
var splashes: Array = []
var crowd: Array = []
var water_mat: StandardMaterial3D
var over := false
var win_solo := false
var end_t := 0.0
var aim_dots: Array = []
var aim_ring: MeshInstance3D


func meta() -> Dictionary:
	return {"id": "beachball", "name": "Labdazápor", "icon": "🏐", "color": "#ff922b", "modes": ["1v3"], "min_players": 4, "own_end": true,
		"tagline": "Lökd a vízbe mind a hármat!",
		"desc": "Strandmedence trópusi pálmákkal. Az egyedül játszó a medence pereméről nagy strandlabdákat hajigál a keskeny rózsaszín gerendán álló három ellenfélre. Akit eltalál, a vízbe pottyan és kiesik. Ha 30 másodperc alatt mindhárom leesik, az egyedül játszó nyer – ha legalább egy fent marad, a hármas csapat.",
		"controls": "Egyedül: a joystickkal célzol jobbra-balra, a DOBÁS gombbal dobsz. Ellenfél: a joystickkal jobbra-balra futsz a gerendán, és kitérsz a labdák elől."}


func layout(p) -> Dictionary:
	if p == solo:
		return {"mode": "stick", "btn": "🏐 DOBÁS", "cd": int(THROW_CD * 1000), "title": "🏐 Célozz és dobj!"}
	return {"mode": "stick", "noBtn": true, "title": "🏃 Térj ki a labdák elől!"}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	_split()
	make_env("#2f9be0", "#bfeaff", 1.0)
	make_camera(Vector3(0, 6.6, 11.8), Vector3(0, 0.6, -1.4), 46)
	var sun := make_sun(Vector3(-55, -30, 0), 1.25, "#fff3d6")
	sun.shadow_blur = 2.0
	_build_pool()
	_build_beach()
	for i in rivals.size():
		var p = rivals[i]
		var m := player_model(p, 0.95)
		var x := (i - (rivals.size() - 1) / 2.0) * 2.4
		rs.append({"p": p, "i": i, "m": m, "x": x, "vx": 0.0, "ix": 0.0, "in": true, "fall_t": -1.0, "yaw": 0.0, "bal": 0.0,
			"arms": K.build_arms(m, (p.color as Color).to_html(), 0.42), "face": K.build_face(m), "kb_t": -10.0, "ai_t": 0.0, "goal": x})
	if solo != null:
		var m := player_model(solo, 1.0)
		ss = {"p": solo, "m": m, "aim": 0.0, "ix": 0.0, "cd": 0.0, "throw_t": -10.0, "arms": K.build_arms(m, (solo.color as Color).to_html(), 0.42),
			"face": K.build_face(m), "kb_t": -10.0, "ai_t": 0.0, "hold": 0.0}
	_build_aim()
	_sync(0.0)


## A csapatok közül az egyfős az egyedül játszó (a párbajban mindig a mezőre lépő).
func _split() -> void:
	if teams.size() == 2:
		var a: Array = teams[0]
		var b: Array = teams[1]
		var one: Array = a if a.size() == 1 else b
		solo = one[0] if one.size() > 0 else null
		rivals = (b if one == a else a).duplicate()
	elif players.size() > 0:
		solo = players[0]
		rivals = players.slice(1, 4)
	rivals = rivals.filter(func(p): return players.has(p))


func _build_pool() -> void:
	var deck := Chars3D.mat("#f1dfb6", {"rough": 0.8})
	var tile := Chars3D.mat("#e9f8ff", {"rough": 0.35})
	var tile2 := Chars3D.mat("#4dabf7", {"rough": 0.35})
	Chars3D.box(self, 60, 1.0, 50, deck, Vector3(0, -0.6, -6))
	# a medence: kék csempés fal, áttetsző víz
	Chars3D.box(self, 14.4, 1.2, 11.0, tile2, Vector3(0, -1.0, -1.2))
	for side in [-1, 1]:
		Chars3D.box(self, 0.5, 0.25, 11.5, tile, Vector3(side * 7.3, -0.02, -1.2))
	Chars3D.box(self, 15.1, 0.25, 0.5, tile, Vector3(0, -0.02, -7.0))
	Chars3D.box(self, 15.1, 0.25, 0.5, tile, Vector3(0, -0.02, 4.55))
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14.2, 11.0)
	pm.subdivide_width = 24
	pm.subdivide_depth = 18
	water.mesh = pm
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.16, 0.66, 0.95, 0.78)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.08
	water_mat.metallic = 0.2
	water_mat.emission_enabled = true
	water_mat.emission = Color("#1c7ed6")
	water_mat.emission_energy_multiplier = 0.25
	water.material_override = water_mat
	water.position = Vector3(0, -0.15, -1.2)
	add_child(water)
	# sávkötelek a vízen
	for z in [-5.2, 1.8]:
		for k in 24:
			var c := "#ff6b6b" if k % 2 else "#ffffff"
			Chars3D.lsphere(self, 0.11, Chars3D.mat(c, {"rough": 0.4}), -6.9 + k * 0.6, -0.1, z, 1, 0.8, 1, 6, 3)
	# a rózsaszín gerenda és a lábai
	var pink := Chars3D.mat("#ff6fb1", {"rough": 0.35})
	var pink2 := Chars3D.mat("#e64980", {"rough": 0.4})
	Chars3D.box(self, BEAM_HALF * 2 + 0.6, 0.22, 0.42, pink, Vector3(0, BEAM_Y - 0.11, BEAM_Z))
	for side in [-1, 1]:
		Chars3D.box(self, 0.3, 1.2, 0.3, pink2, Vector3(side * (BEAM_HALF + 0.1), BEAM_Y - 0.75, BEAM_Z))
		Chars3D.lsphere(self, 0.24, pink2, side * (BEAM_HALF + 0.3), BEAM_Y + 0.05, BEAM_Z, 1, 1, 1, 8, 5)
	# az egyedül játszó dobóemelvénye a medence elején
	Chars3D.box(self, 2.4, 0.5, 1.6, Chars3D.mat("#ffd43b", {"rough": 0.5}), Vector3(0, 0.2, SOLO_Z))
	Chars3D.box(self, 2.6, 0.08, 1.8, Chars3D.mat("#fff3bf", {"rough": 0.5}), Vector3(0, 0.48, SOLO_Z))
	# tartalék labdák kosárban
	Chars3D.cyl(self, 0.55, 0.45, 0.5, Chars3D.mat("#7950f2", {"rough": 0.5}), 1.7, 0.7, SOLO_Z + 0.3, 12)
	for k in 3:
		_ball_mesh(self, Vector3(1.55 + (k % 2) * 0.3, 1.05 + k * 0.12, SOLO_Z + 0.2 + (k - 1) * 0.2), 0.28)


func _build_beach() -> void:
	# pálmák, napernyők, nyugágyak, nézők
	for c in [Vector3(-9.5, 0, -6.5), Vector3(9.8, 0, -7.0), Vector3(-10.5, 0, 1.5), Vector3(10.6, 0, 2.5), Vector3(-6.0, 0, -10.0), Vector3(5.0, 0, -10.5)]:
		_palm(c)
	var cols := ["#ff6b6b", "#ffd43b", "#4dabf7", "#51cf66", "#b197fc"]
	for i in 4:
		var x := -9.0 + i * 6.0 if i < 2 else 3.0 + (i - 2) * 6.0
		_umbrella(Vector3(x if absf(x) > 8.0 else signf(x) * 8.6, 0, 6.2), cols[i % cols.size()])
	# lelátó a medence mögött, nézőkkel
	var bench := Chars3D.mat("#adb5bd", {"rough": 0.7})
	for row in 3:
		Chars3D.box(self, 16, 0.4, 0.9, bench, Vector3(0, 0.2 + row * 0.55, -8.4 - row * 0.9))
		for k in 12:
			var x := -7.0 + k * 1.27 + (row % 2) * 0.5
			var g := Node3D.new()
			g.position = Vector3(x, 0.4 + row * 0.55, -8.4 - row * 0.9)
			add_child(g)
			var col: String = ["#ff8787", "#74c0fc", "#ffd8a8", "#d0bfff", "#8ce99a", "#ffe066"][(k + row * 2) % 6]
			Chars3D.lsphere(g, 0.28, Chars3D.mat(col, {"rough": 0.6}), 0, 0.3, 0, 1, 1.15, 0.9, 8, 5)
			Chars3D.lsphere(g, 0.18, Chars3D.mat("#ffe0c2", {"rough": 0.6}), 0, 0.72, 0, 1, 1, 1, 8, 5)
			crowd.append({"g": g, "ph": FX.fr(0, TAU), "y": g.position.y})


func _palm(pos: Vector3) -> void:
	var trunk := Chars3D.mat("#a47148", {"rough": 0.9})
	var leaf := Chars3D.mat("#2f9e44", {"rough": 0.8})
	var p := pos
	var lean := Vector3(FX.fr(-0.25, 0.25), 1.0, FX.fr(-0.2, 0.2)).normalized()
	for k in 6:
		var q := p + lean * 0.7
		var mi := Chars3D.lcyl(self, 0.16 - k * 0.012, 0.19 - k * 0.012, 0.75, trunk, 0, 0, 0, 7)
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, lean)), (p + q) / 2.0)
		p = q
	for k in 7:
		var a := k * TAU / 7.0
		var dir := Vector3(cos(a), -0.35, sin(a)).normalized()
		var lf := Chars3D.lsphere(self, 1.0, leaf, 0, 0, 0, 1.2, 0.08, 0.32, 6, 3)
		lf.transform = Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.35), p + dir * 0.9)
		lf.scale = Vector3(1.2, 0.08, 0.32)
	for k in 3:
		Chars3D.lsphere(self, 0.13, Chars3D.mat("#6b4226"), p.x + cos(k * 2.1) * 0.15, p.y - 0.15, p.z + sin(k * 2.1) * 0.15, 1, 1, 1, 6, 3)


func _umbrella(pos: Vector3, col: String) -> void:
	Chars3D.lcyl(self, 0.04, 0.04, 2.2, Chars3D.mat("#f8f9fa"), pos.x, 1.1, pos.z, 6)
	Chars3D.lcone(self, 1.3, 0.55, Chars3D.mat(col, {"rough": 0.6}), pos.x, 2.3, pos.z, 8)
	Chars3D.box(self, 0.8, 0.12, 1.8, Chars3D.mat("#ffffff", {"rough": 0.6}), Vector3(pos.x + 1.0, 0.25, pos.z + 0.4), Vector3(0.2, 0, 0))


func _ball_mesh(parent: Node3D, pos: Vector3, r: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	Chars3D.sphere(g, r, Chars3D.mat("#ff922b", {"rough": 0.35}))
	for k in 3:
		var band := Chars3D.sphere(g, r * 1.01, Chars3D.mat(["#ffffff", "#ffd43b", "#ffffff"][k], {"rough": 0.35}), 0, 0, 0, 1.0, 1.0, 0.18)
		band.rotation.y = k * PI / 3.0
	return g


## Célzásjelző: pontsor a pályán és gyűrű a gerendán (mindenki látja, így ki lehet térni).
func _build_aim() -> void:
	var dot := Chars3D.mat("#ffffff", {"alpha": 0.75, "unshaded": true})
	for k in 9:
		var d := Chars3D.sphere(self, 0.07, dot)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aim_dots.append(d)
	aim_ring = MeshInstance3D.new()
	aim_ring.mesh = Chars3D.torus(0.5, 0.05)
	aim_ring.material_override = Chars3D.mat("#ffd43b", {"emit": "#ffd43b", "emit_e": 1.2, "unshaded": true})
	aim_ring.rotation.x = PI / 2
	add_child(aim_ring)


# ------------------------------------------------------------------ menet
func start() -> void:
	Audio.play("whoosh")


func _r(p) -> Dictionary:
	for r in rs:
		if r.p == p:
			return r
	return {}


func input(p, msg: Dictionary) -> void:
	if over:
		return
	if p == solo:
		if msg.get("kb", false):
			ss.kb_t = t
		match msg.get("t"):
			"stick": ss.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)
			"btn": _throw()
		return
	var r := _r(p)
	if r.is_empty():
		return
	if msg.get("kb", false):
		r.kb_t = t
	if msg.get("t") == "stick":
		r.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)


func _throw() -> void:
	if ss.is_empty() or float(ss.cd) > 0.0 or over:
		return
	ss.cd = THROW_CD
	ss.throw_t = t
	var from := Vector3(0.35, 1.75, SOLO_Z - 0.2)
	var to := Vector3(float(ss.aim), BEAM_Y + 0.75, BEAM_Z)
	balls.append({"from": from, "to": to, "t0": t, "node": _ball_mesh(self, from, BALL_R), "hit": false, "done": false, "sx": float(ss.aim)})
	Audio.play("jump")
	Net.vibrate(solo.pid, 40)


## Csak a fejlesztői tesztbotoknak és a lecsatlakozott játékosok helyett.
func bot(p, dt: float) -> void:
	if over:
		return
	if p == solo:
		if ss.is_empty() or t - float(ss.kb_t) < 1.5:
			return
		ss.ai_t -= dt
		var alive: Array = rs.filter(func(r): return r.in)
		if alive.is_empty():
			return
		var tgt: Dictionary = alive[0]
		for r in alive:
			if absf(float(r.x) - float(ss.aim)) < absf(float(tgt.x) - float(ss.aim)):
				tgt = r
		var lead: float = float(tgt.x) + float(tgt.vx) * FLY * 0.6
		ss.ix = clampf((lead - float(ss.aim)) * 1.5, -1.0, 1.0)
		if absf(lead - float(ss.aim)) < 0.5 and float(ss.cd) <= 0.0 and float(ss.ai_t) <= 0.0:
			ss.ai_t = randf_range(0.1, 0.5)
			_throw()
		return
	var r := _r(p)
	if r.is_empty() or not r.in or t - float(r.kb_t) < 1.5:
		return
	r.ai_t -= dt
	# veszély: a hozzá közeli célpontú, még repülő labda
	var danger := INF
	for b in balls:
		if b.done or b.hit:
			continue
		var k: float = (t - float(b.t0)) / FLY
		if k < 1.0 and absf(float(b.sx) - float(r.x)) < 1.2:
			danger = float(b.sx)
	if danger < INF and randf() < 0.85:
		var away := 1.0 if float(r.x) >= danger else -1.0
		if absf(float(r.x) + away * 1.5) > BEAM_HALF - 0.3:
			away = -away
		r.goal = clampf(danger + away * 1.6, -BEAM_HALF + 0.4, BEAM_HALF - 0.4)
	elif float(r.ai_t) <= 0.0:
		r.ai_t = randf_range(0.8, 2.0)
		r.goal = randf_range(-BEAM_HALF + 0.5, BEAM_HALF - 0.5)
	r.ix = clampf((float(r.goal) - float(r.x)) * 2.0, -1.0, 1.0)


func update(dt: float) -> void:
	if not over:
		_step(dt)
		if rs.all(func(r): return not r.in):
			_end(true)
		elif t >= LIMIT:
			_end(false)
	elif t - end_t >= 3.2:
		finished = true
	_balls_step()
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _step(dt: float) -> void:
	if not ss.is_empty():
		ss.cd = maxf(0.0, float(ss.cd) - dt)
		ss.aim = clampf(float(ss.aim) + float(ss.ix) * AIM_SPEED * dt, -AIM_MAX, AIM_MAX)
	for r in rs:
		if not r.in:
			continue
		var want: float = float(r.ix) * RIVAL_SPEED
		r.vx = lerpf(float(r.vx), want, minf(1.0, dt * 14.0))
		r.x = clampf(float(r.x) + float(r.vx) * dt, -BEAM_HALF + 0.3, BEAM_HALF - 0.3)
	# a gerendán egymáson nem tudnak átmenni
	for i in rs.size():
		for j in range(i + 1, rs.size()):
			var a: Dictionary = rs[i]
			var b: Dictionary = rs[j]
			if not a.in or not b.in:
				continue
			var d: float = float(b.x) - float(a.x)
			if absf(d) < RIVAL_R * 2:
				var push := (RIVAL_R * 2 - absf(d)) / 2.0 * (1.0 if d >= 0 else -1.0)
				a.x = clampf(float(a.x) - push, -BEAM_HALF + 0.3, BEAM_HALF - 0.3)
				b.x = clampf(float(b.x) + push, -BEAM_HALF + 0.3, BEAM_HALF - 0.3)


## Labdák: parabolapálya a gerendáig; a gerenda vonalában eltalálja, aki ott áll. Utána a vízbe esik.
func _balls_step() -> void:
	for b in balls:
		var k: float = (t - float(b.t0)) / FLY
		if not b.hit and k >= 1.0:
			b.hit = true
			if not over:
				var any := false
				for r in rs:
					if r.in and absf(float(r.x) - float(b.to.x)) < HIT_DX:
						r.in = false
						r.fall_t = t
						any = true
						Audio.play("hit")
						Net.vibrate(r.p.pid, [80, 40, 160])
						Net.set_ctrl(r.p.pid, {"mode": "wait", "icon": "💦", "title": "Csobbanás!", "text": "Eltaláltak – a vízbe estél. Szurkolj a csapatodnak!"})
						print_verbose("[duel] labdazápor: %s vízbe esett (%.2f mp)" % [r.p.name, t])
				if any:
					var q := screen(b.to)
					Main.I.float_text(q.x, q.y - 30, "TALÁLAT!", Color("#ffd43b"), 34)
		if k >= 1.75 and not b.done:
			b.done = true
			_splash(Vector3(b.to.x, -0.1, BEAM_Z - 2.2))
			(b.node as Node3D).queue_free()
	balls = balls.filter(func(b): return not b.done)


func _splash(pos: Vector3) -> void:
	Audio.play("splash")
	var q := screen(pos)
	Main.I.burst(q.x, q.y, {"n": 26, "colors": ["#ffffff", "#a5d8ff", "#74c0fc"], "speed": 280, "gravity": 500, "life": 0.7, "size": 6})
	splashes.append({"p": pos, "t0": t})


func _end(solo_won: bool) -> void:
	over = true
	win_solo = solo_won
	end_t = t
	Audio.play("fanfare" if solo_won else "win")
	Main.I.confetti(70)
	print_verbose("[duel] labdazápor vége: %s nyert" % ("az egyedül játszó" if solo_won else "a csapat"))


func ranking() -> Array:
	var out: Array = []
	for p in players:
		var is_solo: bool = p == solo
		var won: bool = win_solo if is_solo else not win_solo
		var r := _r(p)
		var lab := ("🏆 mindet a vízbe!" if won else "😓 maradt fent valaki") if is_solo else ("🏝️ fent maradt" if (not r.is_empty() and r.in) else "💦 vízbe esett")
		out.append({"pid": p.pid, "score": 1.0 if won else 0.0, "label": lab})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


# ------------------------------------------------------------------ látvány
func _ball_pos(b: Dictionary, k: float) -> Vector3:
	var from: Vector3 = b.from
	var to: Vector3 = b.to
	if k <= 1.0:
		return from.lerp(to, k) + Vector3(0, sin(k * PI) * 2.2, 0)
	# a gerenda után tovább repül, és a vízbe csobban
	var dir := (to - from) / 1.0
	var u := k - 1.0
	return to + Vector3(dir.x * u * 0.6, -u * u * 2.2 - u * 1.2, dir.z * u * 0.3)


func _sync(dt: float) -> void:
	var tm: float = Main.I.time
	if water_mat:
		water_mat.uv1_offset = Vector3(sin(tm * 0.3) * 0.05, tm * 0.02, 0)
	for b in balls:
		var k: float = (t - float(b.t0)) / FLY
		var n: Node3D = b.node
		n.position = _ball_pos(b, k)
		n.rotation = Vector3(k * 9.0, k * 4.0, 0)
	for c in crowd:
		var g: Node3D = c.g
		g.position.y = float(c.y) + absf(sin(tm * 4.0 + c.ph)) * (0.18 if over else 0.06)
	for r in rs:
		_anim_rival(r, dt)
	if not ss.is_empty():
		_anim_solo(dt)
	# célzásjelző
	var show := not over and not ss.is_empty()
	aim_ring.visible = show
	for d in aim_dots:
		(d as Node3D).visible = show
	if show:
		var aim: float = ss.aim
		aim_ring.position = Vector3(aim, BEAM_Y + 0.02, BEAM_Z)
		aim_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(tm * 8.0))
		var fake := {"from": Vector3(0.35, 1.75, SOLO_Z - 0.2), "to": Vector3(aim, BEAM_Y + 0.75, BEAM_Z)}
		for k in aim_dots.size():
			(aim_dots[k] as Node3D).position = _ball_pos(fake, (k + 1.0) / (aim_dots.size() + 1.0))


func _anim_rival(r: Dictionary, dt: float) -> void:
	var m: Chars3D.CharModel = r.m
	var a := m.animate(dt)
	var tt: float = m.t
	var x: float = r.x
	var y := BEAM_Y
	var z := BEAM_Z
	var lean := 0.0
	var roll := sin(tt * 2.0 + r.i) * 0.05
	var spd := absf(float(r.vx))
	var arms_t: Array = [Vector3(-0.55, 0.62 + sin(tt * 3.0) * 0.08, 0.05), Vector3(0.55, 0.62 - sin(tt * 3.0) * 0.08, 0.05)]
	var face := Vector3(0.2, 1.05, 0.3)
	# közelgő labdánál ijedtség
	for b in balls:
		if not b.hit and absf(float(b.sx) - x) < 1.3:
			face = Vector3(0.7, 1.3, 0.9)
	if not r.in:
		var k: float = t - float(r.fall_t)
		# repül és belecsobban a vízbe, aztán ott bukdácsol
		var f := clampf(k / 0.7, 0.0, 1.0)
		z = BEAM_Z - f * 1.6
		y = BEAM_Y + sin(f * PI) * 0.9 - f * (BEAM_Y + 0.75)
		roll = f * 2.6
		lean = -f * 0.8
		face = Vector3(0.9, 1.3, 1.0)
		arms_t = [Vector3(-0.5, 1.0, 0.1), Vector3(0.5, 1.0, 0.1)]
		if f >= 1.0:
			y = -0.75 + sin(tt * 2.5) * 0.06
			roll = sin(tt * 1.6) * 0.15
			lean = 0.0
			arms_t = [Vector3(-0.5, 0.8 + sin(tt * 6.0) * 0.15, 0.2), Vector3(0.5, 0.8 - sin(tt * 6.0) * 0.15, 0.2)]
			face = Vector3(0.3, 1.0, -0.6)
			if r.get("splashed", false) == false:
				r.splashed = true
				_splash(Vector3(x, -0.1, z))
	elif over:
		if not win_solo:
			arms_t = [Vector3(-0.4, 1.15 + sin(tt * 10.0) * 0.08, 0.1), Vector3(0.4, 1.15 + sin(tt * 10.0 + 1) * 0.08, 0.1)]
			face = Vector3(0.85, 1.1, 0.6)
			y += absf(sin(tt * 7.0)) * 0.25
	else:
		# egyensúlyozás: futás közben dől, kitárt karok billegnek
		r.bal = lerpf(float(r.bal), float(r.vx) / RIVAL_SPEED, minf(1.0, dt * 6.0))
		roll += -float(r.bal) * 0.25 + sin(tt * 5.0 + r.i) * 0.04
		y += absf(sin(tt * 12.0)) * 0.06 * clampf(spd / RIVAL_SPEED, 0.0, 1.0)
	m.position = Vector3(x, y + a.y * 0.3, z)
	m.rotation = Vector3(lean, a.spin, roll + a.tilt)
	m.scale = Vector3.ONE * 0.95
	for j in 2:
		K.arm_to(r.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, r.face, face.x, face.y, face.z)


func _anim_solo(dt: float) -> void:
	var m: Chars3D.CharModel = ss.m
	var a := m.animate(dt)
	var tt: float = m.t
	var k: float = t - float(ss.throw_t)
	var arms_t: Array = [Vector3(-0.38, 0.35, 0.15), Vector3(0.38, 0.35, 0.15)]
	var lean := 0.0
	# dobás: hátralendít, aztán előre
	if k < 0.4:
		var u := k / 0.4
		arms_t[1] = Vector3(0.35, 0.9 + 0.3 * (1.0 - u), -0.4 + u * 1.0)
		arms_t[0] = Vector3(-0.35, 0.6, 0.35)
		lean = sin(u * PI) * 0.3
	elif float(ss.cd) <= 0.0:
		# kézben a következő labda
		arms_t = [Vector3(-0.25, 0.75, 0.32), Vector3(0.25, 0.75, 0.32)]
	var face := Vector3(0.3, 1.0, 0.5)
	if over:
		if win_solo:
			arms_t = [Vector3(-0.4, 1.15 + sin(tt * 10.0) * 0.08, 0.1), Vector3(0.4, 1.15 + sin(tt * 10.0 + 1) * 0.08, 0.1)]
			face = Vector3(0.85, 1.1, 0.6)
		else:
			arms_t = [Vector3(-0.25, 0.0, 0.15), Vector3(0.25, 0.0, 0.15)]
			face = Vector3(0.1, 0.85, -0.9)
			lean = 0.35
	var aim: float = ss.aim
	var yaw := PI + atan2(aim, SOLO_Z - BEAM_Z) * 0.7
	m.position = Vector3(0, 0.52 + a.y * 0.3 + (absf(sin(tt * 7.0)) * 0.3 if over and win_solo else 0.0), SOLO_Z)
	m.rotation = Vector3(lean, yaw + a.spin, a.tilt)
	m.scale = Vector3.ONE
	for j in 2:
		K.arm_to(ss.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, ss.face, face.x, face.y, face.z)


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	for r in rs:
		var m: Node3D = r.m
		var q := screen(m.position + Vector3(0, 1.45, 0))
		D.text(c, ("💦 " if not r.in else "") + r.p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 5, "maxw": 140, "color": Color.WHITE if r.in else Color("#a5d8ff")})
	if not ss.is_empty():
		var q := screen((ss.m as Node3D).position + Vector3(0, 1.55, 0))
		D.text(c, "🏐 " + solo.name, q.x, q.y, {"size": 18, "stroke": Color.BLACK, "sw": 5, "maxw": 160, "color": Color("#ffd43b")})
	K.silver_timer(c, LIMIT - (end_t if over else t), 640, 46, 5.0, t)
	D.text(c, "🏐 Labdazápor", 24, 34, {"size": 26, "align": "left", "stroke": D.DARK, "sw": 6})
	D.text(c, "1 a 3 ellen · ha mind a vízbe esik, a dobó nyer", 24, 64, {"size": 16, "align": "left", "color": Color("#fff3bf"), "stroke": D.DARK, "sw": 5})
	var left := rs.filter(func(r): return r.in).size()
	D.panel(c, 1030, 20, 230, 54, {"r": 27, "fill": Color(0.05, 0.15, 0.3, 0.85), "stroke": Color("#74c0fc"), "lw": 3})
	D.text(c, "🏝️ Gerendán: %d" % left, 1145, 47, {"size": 22})
	if over:
		var txt := ("%s NYERT!" % solo.name.to_upper()) if win_solo and solo != null else "A CSAPAT NYERT!"
		K.banner(c, txt, t - end_t, 3.2, 300, Color("#ffe066"), 72)
