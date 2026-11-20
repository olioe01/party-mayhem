extends Minigame
## Rönkzápor (1 a 3 ellen) – erdei tisztás sziklákkal és vízeséssel. A három ellenfél hátul, egy-egy
## farakás mellől hajigálja a nagy rönköket; mindenki a saját színes célkeresztjével céloz. Az egyedül
## játszó elöl, a kijelölt réten szaladgál és kerülget. 3 szíve van: ha mind elfogy 30 mp alatt,
## a csapat nyer; ha kibírja, ő.

const K = preload("res://scripts/minigames/mg_kit.gd")

const LIMIT := 30.0
const AX := 5.2                    # az egyedül játszó terepe: x ∈ [-AX, AX]
const Z0 := 0.4                    #                           z ∈ [Z0, Z1]
const Z1 := 4.8
const SOLO_SPEED := 4.8
const SOLO_R := 0.4
const HEARTS := 3
const SAFE := 1.3                  # találat után ennyi ideig sérthetetlen
const RIVAL_Z := -6.2
const AIM_SPEED := 7.0
const THROW_CD := 1.7
const FLY := 1.15
const HIT_R := 0.95                # a becsapódás ennyire találja el

var solo = null
var rivals: Array = []
var rs: Array = []
var ss: Dictionary = {}
var logs: Array = []
var falls: Array = []              # vízesés-hab gömbök
var over := false
var win_solo := false
var end_t := 0.0


func meta() -> Dictionary:
	return {"id": "logs", "name": "Rönkzápor", "icon": "🪵", "color": "#8a5a32", "modes": ["1v3"], "min_players": 4, "own_end": true,
		"tagline": "Kerüld ki a repülő rönköket!",
		"desc": "Erdei tisztás vízeséssel. A három ellenfél hátul, a farakások mellől hajigálja a nagy rönköket – mindegyik a saját színes célkeresztjével céloz. Az egyedül játszó elöl szaladgál és kerülget: 3 szíve van, minden találat egyet visz el. Ha 30 másodpercig kibírja, ő nyer; ha elfogy mindhárom szíve, a csapat.",
		"controls": "Egyedül: a joystickkal futsz, figyeld a földön a célkereszteket! Ellenfél: a joystickkal mozgatod a célkeresztedet, a DOBÁS gombbal hajítasz (kis várakozás jár utána)."}


func layout(p) -> Dictionary:
	if p == solo:
		return {"mode": "stick", "noBtn": true, "title": "🏃 Kerüld ki a rönköket!"}
	return {"mode": "stick", "btn": "🪵 DOBÁS", "cd": int(THROW_CD * 1000), "title": "🎯 Célozz és dobj!"}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	_split()
	make_env("#3a8fd8", "#cfeec8", 1.0)
	make_camera(Vector3(0, 9.2, 11.6), Vector3(0, 0.4, -0.6), 48)
	var sun := make_sun(Vector3(-58, -25, 0), 1.25, "#fff1d6")
	sun.shadow_blur = 2.0
	_build_forest()
	for i in rivals.size():
		var p = rivals[i]
		var x := (i - (rivals.size() - 1) / 2.0) * 4.2
		var m := player_model(p, 1.0)
		_log_pile(Vector3(x + 1.0, 0, RIVAL_Z - 0.3))
		var ring := MeshInstance3D.new()
		ring.mesh = Chars3D.torus(0.55, 0.06)
		ring.material_override = Chars3D.mat((p.color as Color).to_html(), {"emit": (p.color as Color).to_html(), "emit_e": 1.4, "unshaded": true})
		ring.rotation.x = PI / 2
		add_child(ring)
		var cross := Chars3D.mat((p.color as Color).to_html(), {"emit": (p.color as Color).to_html(), "emit_e": 1.4, "unshaded": true})
		var c1 := Chars3D.box(ring, 0.06, 0.06, 1.3, cross, Vector3.ZERO)
		var c2 := Chars3D.box(ring, 1.3, 0.06, 0.06, cross, Vector3.ZERO)
		c1.rotation.x = PI / 2
		c2.rotation.x = PI / 2
		rs.append({"p": p, "i": i, "m": m, "x": x, "ax": (i - 1) * 2.5, "az": 2.6, "ix": 0.0, "iy": 0.0, "cd": randf_range(0.6, 1.2), "throw_t": -10.0,
			"ring": ring, "arms": K.build_arms(m, (p.color as Color).to_html(), 0.42), "face": K.build_face(m), "kb_t": -10.0, "ai_t": 0.0})
	if solo != null:
		var m := player_model(solo, 1.0)
		var feet: Array = []
		for side in [-1, 1]:
			feet.append(Chars3D.lsphere(m, 0.09, Chars3D.mat(D.shade(solo.color, -0.45).to_html()), side * 0.14, 0.04, 0.05, 1.0, 0.55, 1.4, 8, 4))
		ss = {"p": solo, "m": m, "x": 0.0, "z": 2.6, "vx": 0.0, "vz": 0.0, "ix": 0.0, "iy": 0.0, "hearts": HEARTS, "hit_t": -10.0, "yaw": PI,
			"arms": K.build_arms(m, (solo.color as Color).to_html(), 0.42), "face": K.build_face(m), "feet": feet, "kb_t": -10.0, "ai_t": 0.0, "tx": 0.0, "tz": 2.6}
	_sync(0.0)


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


func _build_forest() -> void:
	var grass := Chars3D.mat("#7cc15a", {"rough": 0.95})
	var grass2 := Chars3D.mat("#94d36f", {"rough": 0.95})
	var dirt := Chars3D.mat("#b08a5a", {"rough": 1.0})
	Chars3D.box(self, 70, 1, 50, grass, Vector3(0, -0.5, -8))
	# az egyedül játszó réte: világosabb fű, kötélkorlát
	Chars3D.box(self, AX * 2 + 0.8, 0.04, Z1 - Z0 + 0.8, grass2, Vector3(0, 0.0, (Z0 + Z1) / 2.0))
	var post := Chars3D.mat("#8a5a32", {"rough": 0.9})
	var rope := Chars3D.mat("#f1dfb6", {"rough": 0.8})
	for x in [-AX - 0.4, AX + 0.4]:
		for z in [Z0 - 0.4, Z1 + 0.4]:
			Chars3D.lcyl(self, 0.08, 0.09, 0.8, post, x, 0.4, z, 6)
	Chars3D.box(self, AX * 2 + 0.8, 0.04, 0.04, rope, Vector3(0, 0.65, Z1 + 0.4))
	Chars3D.box(self, AX * 2 + 0.8, 0.04, 0.04, rope, Vector3(0, 0.65, Z0 - 0.4))
	for x in [-AX - 0.4, AX + 0.4]:
		Chars3D.box(self, 0.04, 0.04, Z1 - Z0 + 0.8, rope, Vector3(x, 0.65, (Z0 + Z1) / 2.0))
	# ösvény a dobók előtt
	Chars3D.box(self, 14, 0.03, 1.6, dirt, Vector3(0, 0.0, RIVAL_Z + 0.3))
	# fák
	for c in [Vector2(-9.5, -4.0), Vector2(9.0, -3.5), Vector2(-11.0, 2.0), Vector2(11.5, 2.5), Vector2(-7.5, -9.5), Vector2(7.0, -10.0), Vector2(-13.0, -7.0), Vector2(13.0, -7.5)]:
		_tree(Vector3(c.x, 0, c.y), FX.fr(1.0, 1.4))
	# nagy sziklák
	var rock := Chars3D.mat("#8d939b", {"rough": 0.95})
	var rock2 := Chars3D.mat("#737a83", {"rough": 0.95})
	for c in [Vector3(-8.0, 0, 3.5), Vector3(8.4, 0, 4.0), Vector3(-6.5, 0, -7.6), Vector3(6.5, 0, -7.8), Vector3(-10.0, 0, -1.0)]:
		var r := FX.fr(0.9, 1.6)
		Chars3D.lsphere(self, r, rock if FX.f() < 0.5 else rock2, c.x, r * 0.5, c.z, 1.2, 0.85, 1.0, 8, 5)
	_waterfall()
	# virágok, bokrok
	for i in 30:
		var x := FX.fr(-12, 12)
		var z := FX.fr(-9, 7)
		if absf(x) < AX + 1.0 and z > Z0 - 1.0 and z < Z1 + 1.0:
			continue
		var col: String = FX.pick(["#ffd43b", "#ff8fab", "#ffffff", "#b197fc"])
		Chars3D.lsphere(self, 0.08, Chars3D.mat(col), x, 0.12, z, 1, 0.7, 1, 6, 3)


func _tree(pos: Vector3, s: float) -> void:
	var trunk := Chars3D.mat("#7a4f2c", {"rough": 0.9})
	var leaf := Chars3D.mat(FX.pick(["#2f9e44", "#37b24d", "#2b8a3e"]), {"rough": 0.85})
	Chars3D.lcyl(self, 0.25 * s, 0.32 * s, 2.0 * s, trunk, pos.x, s, pos.z, 7)
	for k in 3:
		var r := (1.5 - k * 0.35) * s
		Chars3D.lcone(self, r, 1.6 * s, leaf, pos.x, (2.0 + k * 0.95) * s, pos.z, 8)


func _waterfall() -> void:
	var cliff := Chars3D.mat("#6c7a89", {"rough": 0.95})
	for k in 5:
		Chars3D.lsphere(self, FX.fr(2.4, 3.2), cliff, -6.0 + k * 3.0, FX.fr(2.0, 4.0), -13.5, 1.2, 1.6, 0.9, 8, 5)
	var water := Chars3D.mat("#74c0fc", {"alpha": 0.85, "emit": "#a5d8ff", "emit_e": 0.5, "rough": 0.1})
	Chars3D.box(self, 2.4, 6.5, 0.4, water, Vector3(1.5, 3.25, -11.6))
	Chars3D.lsphere(self, 2.4, water, 1.5, 0.0, -10.4, 1.4, 0.15, 1.0, 10, 4)
	var foam := Chars3D.mat("#ffffff", {"rough": 0.6, "emit": "#ffffff", "emit_e": 0.3})
	for k in 10:
		var f := Chars3D.lsphere(self, FX.fr(0.2, 0.4), foam, 1.5 + FX.fr(-1.2, 1.2), 0.2, -10.6 + FX.fr(-0.5, 0.5), 1, 0.7, 1, 6, 3)
		falls.append({"n": f, "ph": FX.fr(0, TAU), "x": f.position.x, "z": f.position.z})


func _log_pile(pos: Vector3) -> void:
	var bark := Chars3D.mat("#8a5a32", {"rough": 0.9})
	var cap := Chars3D.mat("#e0b97a", {"rough": 0.8})
	for row in 3:
		for k in 3 - row:
			var x := pos.x + (k - (2 - row) / 2.0) * 0.5
			var y := 0.22 + row * 0.4
			Chars3D.lcyl(self, 0.22, 0.22, 1.4, bark, x, y, pos.z, 8, Vector3(PI / 2, 0, 0))
			Chars3D.lcyl(self, 0.18, 0.18, 1.42, cap, x, y, pos.z, 8, Vector3(PI / 2, 0, 0))


func _log_mesh() -> Node3D:
	var g := Node3D.new()
	add_child(g)
	Chars3D.lcyl(g, 0.26, 0.26, 1.5, Chars3D.mat("#8a5a32", {"rough": 0.9}), 0, 0, 0, 8, Vector3(0, 0, PI / 2))
	Chars3D.lcyl(g, 0.21, 0.21, 1.52, Chars3D.mat("#e0b97a", {"rough": 0.8}), 0, 0, 0, 8, Vector3(0, 0, PI / 2))
	return g


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
	var target: Dictionary = ss if p == solo else _r(p)
	if target.is_empty():
		return
	if msg.get("kb", false):
		target.kb_t = t
	match msg.get("t"):
		"stick":
			target.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)
			target.iy = clampf(float(msg.get("y", 0)), -1.0, 1.0)
		"btn":
			if p != solo:
				_throw(target)


func _throw(r: Dictionary) -> void:
	if float(r.cd) > 0.0 or over:
		return
	r.cd = THROW_CD
	r.throw_t = t
	var from := Vector3(float(r.x) + 0.3, 1.8, RIVAL_Z + 0.2)
	var to := Vector3(float(r.ax), 0.3, float(r.az))
	logs.append({"from": from, "to": to, "t0": t, "node": _log_mesh(), "landed": false, "done": false, "who": r.i, "spin": FX.fr(-0.6, 0.6)})
	Audio.play("jump")
	Net.vibrate(r.p.pid, 40)


## Csak a fejlesztői tesztbotoknak és a lecsatlakozott játékosok helyett.
func bot(p, dt: float) -> void:
	if over:
		return
	if p == solo:
		if ss.is_empty() or t - float(ss.kb_t) < 1.5:
			return
		ss.ai_t -= dt
		var here := Vector2(ss.x, ss.z)
		var flee := Vector2.ZERO
		for l in logs:
			if l.landed:
				continue
			var d := here - Vector2(l.to.x, l.to.z)
			if d.length() < 2.2:
				flee += d.normalized() * (2.2 - d.length()) if d.length() > 0.01 else Vector2(1, 0)
		if flee.length() > 0.05 and randf() < 0.9:
			var want := flee.normalized()
			ss.ix = want.x
			ss.iy = want.y
		else:
			if float(ss.ai_t) <= 0.0 or here.distance_to(Vector2(ss.tx, ss.tz)) < 0.5:
				ss.ai_t = randf_range(0.6, 1.5)
				ss.tx = randf_range(-AX + 0.6, AX - 0.6)
				ss.tz = randf_range(Z0 + 0.5, Z1 - 0.5)
			var w := (Vector2(ss.tx, ss.tz) - here)
			w = w.normalized() * 0.6 if w.length() > 0.2 else Vector2.ZERO
			ss.ix = w.x
			ss.iy = w.y
		return
	var r := _r(p)
	if r.is_empty() or t - float(r.kb_t) < 1.5 or ss.is_empty():
		return
	# a célkeresztet az egyedül játszó (kicsit előre becsült) helyére húzza, aztán dob
	var goal := Vector2(float(ss.x) + float(ss.vx) * 0.5 + randf_range(-0.6, 0.6), float(ss.z) + float(ss.vz) * 0.5 + randf_range(-0.4, 0.4))
	var d := goal - Vector2(r.ax, r.az)
	r.ix = clampf(d.x * 1.5, -1.0, 1.0)
	r.iy = clampf(d.y * 1.5, -1.0, 1.0)
	r.ai_t -= dt
	if d.length() < 0.8 and float(r.cd) <= 0.0 and float(r.ai_t) <= 0.0:
		r.ai_t = randf_range(0.2, 0.9)
		_throw(r)


func update(dt: float) -> void:
	if not over:
		_step(dt)
		if not ss.is_empty() and int(ss.hearts) <= 0:
			_end(false)
		elif t >= LIMIT:
			_end(true)
	elif t - end_t >= 3.2:
		finished = true
	_logs_step()
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _step(dt: float) -> void:
	for r in rs:
		r.cd = maxf(0.0, float(r.cd) - dt)
		r.ax = clampf(float(r.ax) + float(r.ix) * AIM_SPEED * dt, -AX, AX)
		r.az = clampf(float(r.az) + float(r.iy) * AIM_SPEED * dt, Z0, Z1)
	if ss.is_empty():
		return
	var hurt: bool = t - float(ss.hit_t) < 0.45
	var ix: float = 0.0 if hurt else float(ss.ix)
	var iy: float = 0.0 if hurt else float(ss.iy)
	ss.vx = lerpf(float(ss.vx), ix * SOLO_SPEED, minf(1.0, dt * 12.0))
	ss.vz = lerpf(float(ss.vz), iy * SOLO_SPEED, minf(1.0, dt * 12.0))
	ss.x = clampf(float(ss.x) + float(ss.vx) * dt, -AX + SOLO_R, AX - SOLO_R)
	ss.z = clampf(float(ss.z) + float(ss.vz) * dt, Z0 + SOLO_R, Z1 - SOLO_R)


## Rönkök: parabolán repülnek a célkereszthez; becsapódáskor eltalálják az ott álló egyedül játszót.
func _logs_step() -> void:
	for l in logs:
		var k: float = (t - float(l.t0)) / FLY
		if not l.landed and k >= 1.0:
			l.landed = true
			Audio.play("thud")
			var q := screen(l.to)
			Main.I.burst(q.x, q.y, {"n": 14, "colors": ["#b08a5a", "#8d6e46", "#d9c09a"], "speed": 200, "gravity": 400, "life": 0.5, "size": 5})
			if not over and not ss.is_empty() and t - float(ss.hit_t) >= SAFE:
				if Vector2(float(ss.x), float(ss.z)).distance_to(Vector2(l.to.x, l.to.z)) < HIT_R:
					ss.hearts = int(ss.hearts) - 1
					ss.hit_t = t
					var away := Vector2(float(ss.x) - l.to.x, float(ss.z) - l.to.z)
					away = away.normalized() if away.length() > 0.01 else Vector2(0, 1)
					ss.vx = away.x * 6.0
					ss.vz = away.y * 6.0
					Audio.play("hit")
					Audio.play("bad")
					Net.vibrate(solo.pid, [120, 50, 120])
					var sq := screen(Vector3(float(ss.x), 1.6, float(ss.z)))
					Main.I.float_text(sq.x, sq.y - 20, "AÚ! −1 ❤️", Color("#ff8787"), 34)
					print_verbose("[duel] rönkzápor: találat (%s), maradt %d szív (%.2f mp)" % [solo.name, ss.hearts, t])
		if k >= 1.7 and not l.done:
			l.done = true
			(l.node as Node3D).queue_free()
	logs = logs.filter(func(l): return not l.done)


func _end(solo_won: bool) -> void:
	over = true
	win_solo = solo_won
	end_t = t
	Audio.play("fanfare" if solo_won else "win")
	Main.I.confetti(70)
	print_verbose("[duel] rönkzápor vége: %s nyert" % ("az egyedül játszó" if solo_won else "a csapat"))


func ranking() -> Array:
	var out: Array = []
	for p in players:
		var is_solo: bool = p == solo
		var won: bool = win_solo if is_solo else not win_solo
		var lab := ("❤️ x%d – kibírta!" % int(ss.get("hearts", 0)) if won else "💔 elfogyott a szíve") if is_solo else ("🪵 eltalálták" if won else "😓 kibírta")
		out.append({"pid": p.pid, "score": 1.0 if won else 0.0, "label": lab})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


# ------------------------------------------------------------------ látvány
func _log_pos(l: Dictionary, k: float) -> Vector3:
	var from: Vector3 = l.from
	var to: Vector3 = l.to
	if k <= 1.0:
		return from.lerp(to, k) + Vector3(0, sin(k * PI) * 3.0, 0)
	# becsapódás után előregurul egy kicsit
	var u := k - 1.0
	return to + Vector3(0, absf(sin(u * 6.0)) * 0.25 * (1.0 - u), u * 1.6)


func _sync(dt: float) -> void:
	var tm: float = Main.I.time
	for f in falls:
		var n: Node3D = f.n
		n.position = Vector3(float(f.x) + sin(tm * 3.0 + f.ph) * 0.15, 0.2 + absf(sin(tm * 4.0 + f.ph)) * 0.25, float(f.z))
	for l in logs:
		var k: float = (t - float(l.t0)) / FLY
		var n: Node3D = l.node
		n.position = _log_pos(l, k)
		n.rotation = Vector3(k * 10.0, float(l.spin) * k, 0)
	for r in rs:
		_anim_rival(r, dt)
	if not ss.is_empty():
		_anim_solo(dt)


func _anim_rival(r: Dictionary, dt: float) -> void:
	var m: Chars3D.CharModel = r.m
	var a := m.animate(dt)
	var tt: float = m.t
	var k: float = t - float(r.throw_t)
	var arms_t: Array = [Vector3(-0.3, 0.75, 0.3), Vector3(0.3, 0.75, 0.3)]
	var lean := 0.0
	var face := Vector3(0.3, 1.0, 0.5)
	if k < 0.45:
		# két kézzel a feje fölül hajít
		var u := k / 0.45
		var up := 1.25 - u * 0.6
		arms_t = [Vector3(-0.25, up, -0.25 + u * 0.8), Vector3(0.25, up, -0.25 + u * 0.8)]
		lean = sin(u * PI) * 0.35
		face = Vector3(0.7, 1.1, 0.8)
	elif float(r.cd) > 0.0:
		# új rönköt emel fel
		arms_t = [Vector3(-0.3, 0.3, 0.3), Vector3(0.3, 0.3, 0.3)]
	if over:
		if not win_solo:
			arms_t = [Vector3(-0.4, 1.15 + sin(tt * 10.0) * 0.08, 0.1), Vector3(0.4, 1.15 + sin(tt * 10.0 + 1) * 0.08, 0.1)]
			face = Vector3(0.85, 1.1, 0.6)
		else:
			arms_t = [Vector3(-0.25, 0.0, 0.15), Vector3(0.25, 0.0, 0.15)]
			face = Vector3(0.1, 0.85, -0.9)
			lean = 0.3
	var aim := Vector3(float(r.ax), 0, float(r.az)) - Vector3(float(r.x), 0, RIVAL_Z)
	m.position = Vector3(float(r.x), a.y * 0.3 + (absf(sin(tt * 7.0)) * 0.3 if over and not win_solo else 0.0), RIVAL_Z)
	m.rotation = Vector3(lean, atan2(aim.x, aim.z) + a.spin, a.tilt)
	m.scale = Vector3.ONE
	for j in 2:
		K.arm_to(r.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, r.face, face.x, face.y, face.z)
	# célkereszt: pulzál, a dobás után a becsapódásig halványabb
	var ring: Node3D = r.ring
	ring.visible = not over
	ring.position = Vector3(float(r.ax), 0.06, float(r.az))
	ring.scale = Vector3.ONE * (1.0 + 0.1 * sin(Main.I.time * 7.0 + r.i)) * (0.7 if float(r.cd) > 0.0 else 1.0)


func _anim_solo(dt: float) -> void:
	var m: Chars3D.CharModel = ss.m
	var a := m.animate(dt)
	var tt: float = m.t
	var mv := Vector2(float(ss.vx), float(ss.vz))
	var spd := mv.length()
	if spd > 0.5:
		ss.yaw = lerp_angle(float(ss.yaw), atan2(mv.x, mv.y), minf(1.0, dt * 12.0))
	var run := clampf(spd / SOLO_SPEED, 0.0, 1.0)
	var ph := tt * 13.0
	var hop := absf(sin(ph)) * 0.12 * run
	var lean := 0.2 * run
	var roll := 0.0
	var sw := sin(ph) * 0.25 * run
	var arms_t: Array = [Vector3(-0.34, 0.32, 0.05 + sw), Vector3(0.34, 0.32, 0.05 - sw)]
	var lift := [maxf(0.0, sin(ph)) * 0.14 * run, maxf(0.0, -sin(ph)) * 0.14 * run]
	var face := Vector3(0.3, 1.1, 0.6)
	# veszélyben tágra nyílt szem
	for l in logs:
		if not l.landed and Vector2(float(ss.x), float(ss.z)).distance_to(Vector2(l.to.x, l.to.z)) < 1.8:
			face = Vector3(0.75, 1.3, 1.0)
	var hk: float = t - float(ss.hit_t)
	if hk < 0.6:
		roll = sin(hk * 30.0) * 0.3 * (1.0 - hk / 0.6)
		face = Vector3(0.6, 0.6, -0.8)
	if over:
		if win_solo:
			arms_t = [Vector3(-0.4, 1.15 + sin(tt * 10.0) * 0.08, 0.1), Vector3(0.4, 1.15 + sin(tt * 10.0 + 1) * 0.08, 0.1)]
			face = Vector3(0.85, 1.1, 0.6)
			hop = absf(sin(tt * 7.0)) * 0.35
			ss.yaw = lerp_angle(float(ss.yaw), 0.0, minf(1.0, dt * 5.0))
		else:
			arms_t = [Vector3(-0.25, 0.0, 0.15), Vector3(0.25, 0.0, 0.15)]
			face = Vector3(0.1, 0.85, -0.9)
			lean = 0.35
	m.position = Vector3(float(ss.x), hop + a.y * 0.3, float(ss.z))
	m.rotation = Vector3(lean, float(ss.yaw) + a.spin, roll + a.tilt)
	m.scale = Vector3.ONE
	# sérthetetlenség alatt villog
	m.visible = not (not over and hk < SAFE and fmod(t, 0.2) < 0.08)
	var feet: Array = ss.feet
	for j in 2:
		(feet[j] as Node3D).position = Vector3((-1 if j == 0 else 1) * 0.14, 0.04 + lift[j], 0.05 + lift[j] * 0.5)
	for j in 2:
		K.arm_to(ss.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, ss.face, face.x, face.y, face.z)


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	for r in rs:
		var q := screen((r.m as Node3D).position + Vector3(0, 1.55, 0))
		D.text(c, r.p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 5, "maxw": 140, "color": (r.p.color as Color).lightened(0.4)})
	if not ss.is_empty():
		var q := screen((ss.m as Node3D).position + Vector3(0, 1.55, 0))
		D.text(c, solo.name, q.x, q.y, {"size": 18, "stroke": Color.BLACK, "sw": 5, "maxw": 160, "color": Color("#ffd43b")})
	K.silver_timer(c, LIMIT - (end_t if over else t), 640, 46, 5.0, t)
	D.text(c, "🪵 Rönkzápor", 24, 34, {"size": 26, "align": "left", "stroke": D.DARK, "sw": 6})
	D.text(c, "1 a 3 ellen · 30 mp-ig kell kibírni", 24, 64, {"size": 16, "align": "left", "color": Color("#fff3bf"), "stroke": D.DARK, "sw": 5})
	# szívek jól láthatóan
	if not ss.is_empty():
		D.panel(c, 980, 18, 280, 60, {"r": 30, "fill": Color(0.2, 0.05, 0.08, 0.85), "stroke": Color("#ff6b6b"), "lw": 3})
		D.text(c, solo.name, 1000, 48, {"size": 18, "align": "left", "maxw": 100})
		var hk: float = t - float(ss.hit_t)
		for k in HEARTS:
			var full: bool = k < int(ss.hearts)
			var just: bool = k == int(ss.hearts) and hk < 0.6
			var sc := 1.0 + (0.4 * (1.0 - hk / 0.6) if just else 0.0)
			D.emoji(c, "❤️" if full or just else "🖤", 1130 + k * 42, 47, 34 * sc, 1.0 if full or just else 0.6)
	if over:
		var txt := ("%s KIBÍRTA!" % solo.name.to_upper()) if win_solo and solo != null else "A CSAPAT NYERT!"
		K.banner(c, txt, t - end_t, 3.2, 300, Color("#ffe066"), 72)
