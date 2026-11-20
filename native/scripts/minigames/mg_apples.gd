extends Minigame
## Almaszámláló (1 a 3 ellen) – színes vetélkedő-színpad aranyívekkel, függönnyel, reflektorokkal.
## A három ellenfél egy-egy almagurító szerkezetet kezel: a saját sínjükön (három különböző magasságban)
## almákat gurítanak át a színpadon, változó sebességgel. Az egyedül játszó számolja őket a telefonján
## (+ / −), a végén leadja a válaszát. Ha pontosan annyi, ahány almát ténylegesen elgurítottak, ő nyer.
##
## A helyes számot a ténylegesen létrehozott almák adják (mindegyik egyszer számít). Egy sínen
## a későbbi alma soha nem gyorsabb az előtte gurulónál, így nem érik utol és nem fedik egymást.

const K = preload("res://scripts/minigames/mg_kit.gd")

const LIMIT := 30.0
const SEND_END := 19.0             # eddig lehet almát gurítani
const PER_RIVAL := 8               # ellenfelenként legfeljebb ennyi alma
const SEND_CD := 0.75
const SPEEDS := [2.3, 3.3, 4.6]    # lassú, közepes, gyors (egység / mp)
const X_IN := 7.4                  # itt bukkannak elő (jobbra, a gurítóból)
const X_OUT := -5.6                # itt esnek a kosárba (balra)
const LANES := [[0.35, 1.6], [1.75, 0.2], [3.15, -1.2]]   # [magasság, mélység]
const APPLE_R := 0.3

var solo = null
var rivals: Array = []
var rs: Array = []
var apples: Array = []
var spawned := 0                   # a ténylegesen elgurított almák száma (ez a helyes válasz)
var answer := 0
var locked := false
var lock_t := 0.0
var over := false
var win_solo := false
var end_t := 0.0
var next_id := 0
var bulbs: Array = []
var spots: Array = []
var ss_m: Chars3D.CharModel
var ss_arms: Array = []
var ss_face: Dictionary = {}
var bot_seen := {}                 # a gépi számoló már „látott” almái
var bot_count := 0
var kb_t := -10.0
var press_t := -10.0
var done_ok := false               # a számoló már megkapta a KÉSZ gombot


func meta() -> Dictionary:
	return {"id": "apples", "name": "Almaszámláló", "icon": "🍎", "color": "#e03131", "modes": ["1v3"], "min_players": 4, "own_end": true,
		"tagline": "Hány alma gurult át? Pontosan!",
		"desc": "Vetélkedő-színpad! A három ellenfél egy-egy almagurítót kezel: a saját sínjükön almákat gurítanak át a színpadon, gyorsan vagy lassan, ahogy épp sikerül összezavarni a számolót. Az egyedül játszó a telefonján számolja őket (+ / −), és a végén leadja a válaszát. Ha pontosan annyi, ahány alma átgurult, ő nyer – ha téved, a csapat.",
		"controls": "Egyedül: + és − gombbal számolsz, a végén ✔ KÉSZ. Ellenfél: GURÍTS! gombbal indítasz egy almát a saját sínedre (mindenkinek %d alma jut)." % PER_RIVAL}


func layout(p) -> Dictionary:
	if p == solo:
		return {"mode": "counter", "title": "🍎 Számold az almákat!", "text": "Minden átguruló almánál nyomj +-t!", "value": answer, "doneOk": false}
	var r := _r(p)
	var left: int = PER_RIVAL - int(r.get("sent", 0))
	return {"mode": "tap", "label": "🍎 GURÍTS!", "rapid": true, "hint": "Még %d almád van – zavard össze a számolót!" % left}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	_split()
	make_env("#2b1055", "#5f3dc4", 0.8)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a0b3b")
	make_camera(Vector3(0, 3.2, 12.4), Vector3(0.4, 1.6, 0), 44)
	var sun := make_sun(Vector3(-50, -20, 0), 0.9, "#fff1d6")
	sun.shadow_blur = 2.0
	_build_stage()
	for i in rivals.size():
		var p = rivals[i]
		var lane: Array = LANES[i % LANES.size()]
		var y: float = lane[0]
		var z: float = lane[1]
		var m := player_model(p, 0.8)
		rs.append({"p": p, "i": i, "m": m, "y": y, "z": z, "sent": 0, "cd": 0.0, "push_t": -10.0, "kb_t": -10.0, "ai_t": randf_range(0.4, 2.0),
			"arms": K.build_arms(m, (p.color as Color).to_html(), 0.42), "face": K.build_face(m), "crank": _chute(i, y, z, p.color)})
	if solo != null:
		ss_m = player_model(solo, 1.05)
		ss_arms = K.build_arms(ss_m, (solo.color as Color).to_html(), 0.45)
		ss_face = K.build_face(ss_m)
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


func _build_stage() -> void:
	var floor_m := Chars3D.mat("#3b2a6b", {"rough": 0.25, "metal": 0.3})
	var edge := Chars3D.mat("#ffd43b", {"rough": 0.3, "metal": 0.6, "emit": "#b8860b", "emit_e": 0.3})
	Chars3D.box(self, 26, 0.6, 9, floor_m, Vector3(0, -0.3, 0))
	Chars3D.box(self, 26, 0.12, 0.2, edge, Vector3(0, 0.0, 4.5))
	# függöny hátul: piros redők
	var curtain := Chars3D.mat("#c92a2a", {"rough": 0.7})
	var curtain2 := Chars3D.mat("#a61e1e", {"rough": 0.7})
	for k in 34:
		Chars3D.lcyl(self, 0.42, 0.42, 9.0, curtain if k % 2 else curtain2, -13.0 + k * 0.8, 4.4, -3.6, 6)
	Chars3D.box(self, 27, 1.0, 0.6, Chars3D.mat("#ffd43b", {"rough": 0.4, "metal": 0.5}), Vector3(0, 8.6, -3.2))
	# aranyívek
	for x in [-8.5, 0.0, 8.5]:
		var arc := MeshInstance3D.new()
		arc.mesh = Chars3D.arc_tube(3.2, 0.16, PI, 24, 8)
		arc.material_override = edge
		arc.position = Vector3(x, 3.8, -2.6)
		add_child(arc)
		for side in [-1, 1]:
			Chars3D.lcyl(self, 0.18, 0.2, 3.8, edge, x + side * 3.2, 1.9, -2.6, 8)
	# villanykörték az íveken
	for x in [-8.5, 0.0, 8.5]:
		for k in 9:
			var a := k * PI / 8.0
			var b := Chars3D.sphere(self, 0.09, Chars3D.mat("#fff3bf", {"emit": "#ffe066", "emit_e": 2.0, "unshaded": true}), x + cos(a) * 3.2, 3.8 + sin(a) * 3.2, -2.4)
			bulbs.append({"n": b, "k": k})
	# reflektorfény-kúpok
	for k in 4:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 2.0
		cm.height = 9.0
		cm.radial_segments = 16
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.95, 0.7, 0.07)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(-7.5 + k * 5.0, 4.5, 0.5)
		add_child(mi)
		spots.append({"n": mi, "ph": k * 1.3})
	# a sínek: polcok három magasságban (fával), bal végén kosár
	var shelf := Chars3D.mat("#c08a52", {"rough": 0.7})
	var rail := Chars3D.mat("#dee2e6", {"rough": 0.3, "metal": 0.6})
	for lane in LANES:
		var y: float = lane[0]
		var z: float = lane[1]
		var len := X_IN - X_OUT + 1.6
		var cx := (X_IN + X_OUT) / 2.0
		Chars3D.box(self, len, 0.12, 0.7, shelf, Vector3(cx, y - APPLE_R - 0.06, z))
		for side in [-1, 1]:
			Chars3D.box(self, len, 0.06, 0.06, rail, Vector3(cx, y - APPLE_R + 0.08, z + side * 0.3))
		if y > 1.0:
			for x in [X_OUT - 0.4, cx, X_IN + 0.6]:
				Chars3D.lcyl(self, 0.06, 0.06, y - APPLE_R, rail, x, (y - APPLE_R) / 2.0, z - 0.3, 6)
		# kosár a sín végén
		Chars3D.lcyl(self, 0.5, 0.38, 0.5, Chars3D.mat("#a0703c", {"rough": 0.8}), X_OUT - 0.9, y - APPLE_R + 0.1, z, 10)
	# az egyedül játszó dobogója balra elöl, nagy kijelzővel
	Chars3D.box(self, 2.0, 0.5, 1.6, Chars3D.mat("#7048e8", {"rough": 0.4}), Vector3(-7.6, 0.25, 3.0))
	Chars3D.box(self, 2.1, 0.08, 1.7, edge, Vector3(-7.6, 0.52, 3.0))


## Almagurító szerkezet a sín jobb végén: tölcsér, cső, forgó kar.
func _chute(i: int, y: float, z: float, col: Color) -> Node3D:
	var body := Chars3D.mat(col.to_html(), {"rough": 0.4})
	var metal := Chars3D.mat("#ced4da", {"rough": 0.3, "metal": 0.6})
	Chars3D.box(self, 1.2, 1.0, 0.9, body, Vector3(X_IN + 0.9, y + 0.15, z))
	Chars3D.lcone(self, 0.7, 0.7, metal, X_IN + 0.9, y + 0.95, z, 8, Vector3(PI, 0, 0))
	Chars3D.lcyl(self, 0.34, 0.34, 0.6, metal, X_IN + 0.2, y, z, 10, Vector3(0, 0, PI / 2))
	# almák a tölcsérben
	for k in 3:
		Chars3D.lsphere(self, 0.16, Chars3D.mat("#e03131"), X_IN + 0.75 + k * 0.15, y + 1.2, z + (k - 1) * 0.15, 1, 1, 1, 6, 4)
	var crank := Node3D.new()
	crank.position = Vector3(X_IN + 1.55, y + 0.15, z + 0.2)
	add_child(crank)
	Chars3D.box(crank, 0.08, 0.6, 0.08, metal, Vector3(0, 0.3, 0))
	Chars3D.lsphere(crank, 0.12, Chars3D.mat("#ffd43b"), 0, 0.6, 0, 1, 1, 1, 6, 4)
	return crank


func _apple_mesh(speed_k: int) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	var col: String = ["#e03131", "#f03e3e", "#c92a2a"][speed_k % 3]
	Chars3D.lsphere(g, APPLE_R, Chars3D.mat(col, {"rough": 0.3}), 0, 0, 0, 1.0, 0.92, 1.0, 10, 7)
	Chars3D.lcyl(g, 0.025, 0.03, 0.16, Chars3D.mat("#6b4226"), 0, APPLE_R, 0, 5)
	Chars3D.lsphere(g, 0.09, Chars3D.mat("#51cf66"), 0.07, APPLE_R + 0.05, 0, 1.4, 0.4, 0.8, 6, 3)
	Chars3D.lsphere(g, 0.07, Chars3D.mat("#ffffff", {"alpha": 0.6, "unshaded": true}), -0.12, 0.12, APPLE_R * 0.85, 1, 1, 0.4, 6, 3)
	return g


# ------------------------------------------------------------------ menet
func start() -> void:
	Audio.play("bell")


func _r(p) -> Dictionary:
	for r in rs:
		if r.p == p:
			return r
	return {}


func input(p, msg: Dictionary) -> void:
	if over:
		return
	var tt := str(msg.get("t", ""))
	if p == solo:
		if msg.get("kb", false):
			kb_t = t
		if locked:
			return
		if tt == "cnt":
			answer = clampi(int(msg.get("v", 0)), 0, 99)
			press_t = t
		elif tt == "done" and t >= SEND_END and apples.is_empty():
			answer = clampi(int(msg.get("v", answer)), 0, 99)
			_lock()
		elif tt == "btn":
			answer = mini(99, answer + 1)
			press_t = t
		elif tt == "stick" and float(msg.get("x", 0)) < -0.6:
			answer = maxi(0, answer - 1)
			press_t = t
		return
	var r := _r(p)
	if r.is_empty():
		return
	if msg.get("kb", false):
		r.kb_t = t
	if tt == "tap" or tt == "btn":
		_send(r)


## Egy alma indul az ellenfél sínjén. A sebesség véletlen, de nem lehet gyorsabb a sínen előtte
## guruló almánál (különben utolérné és takarná).
func _send(r: Dictionary) -> void:
	if t >= SEND_END or int(r.sent) >= PER_RIVAL or float(r.cd) > 0.0 or over:
		return
	var sk := randi() % SPEEDS.size()
	var sp: float = SPEEDS[sk]
	for a in apples:
		if a.lane == r.i:
			sp = minf(sp, float(a.v))
			# a sín elején legyen hely: az előző alma már arrébb gurult
			if float(a.x) > X_IN - APPLE_R * 3.0:
				return
	r.sent = int(r.sent) + 1
	r.cd = SEND_CD
	r.push_t = t
	spawned += 1
	next_id += 1
	apples.append({"id": next_id, "lane": r.i, "x": X_IN, "v": sp, "y": r.y, "z": r.z, "node": _apple_mesh(sk), "rot": 0.0})
	Audio.play("pop", 0.9 + sk * 0.12)
	Net.vibrate(r.p.pid, 30)
	Net.set_ctrl(r.p.pid, layout(r.p))
	print_verbose("[duel] almaszámláló: %s gurít (#%d, seb. %.1f) – eddig %d" % [r.p.name, next_id, sp, spawned])


## Csak a fejlesztői tesztbotoknak és a lecsatlakozott játékosok helyett.
func bot(p, dt: float) -> void:
	if over:
		return
	if p == solo:
		if t - kb_t < 1.5 or locked:
			return
		# a gépi számoló a színpad közepén áthaladó almákat számolja, néha téved
		for a in apples:
			if float(a.x) < 1.0 and not bot_seen.has(a.id):
				bot_seen[a.id] = true
				bot_count += 1 if randf() < 0.93 else (0 if randf() < 0.5 else 2)
		if answer != bot_count:
			answer = bot_count
			press_t = t
		if t >= SEND_END and apples.is_empty() and t > SEND_END + 2.0:
			_lock()
		return
	var r := _r(p)
	if r.is_empty() or t - float(r.kb_t) < 1.5:
		return
	r.ai_t -= dt
	if float(r.ai_t) <= 0.0:
		# néha sorozatban gurít, néha kivár
		r.ai_t = randf_range(0.2, 0.5) if randf() < 0.4 else randf_range(1.0, 2.6)
		_send(r)


func update(dt: float) -> void:
	if not over:
		for r in rs:
			r.cd = maxf(0.0, float(r.cd) - dt)
		for a in apples:
			a.x = float(a.x) - float(a.v) * dt
			a.rot = float(a.rot) + float(a.v) * dt / APPLE_R
		var gone: Array = apples.filter(func(a): return float(a.x) <= X_OUT)
		for a in gone:
			(a.node as Node3D).queue_free()
			Audio.play("land", 1.3)
		apples = apples.filter(func(a): return float(a.x) > X_OUT)
		if t >= SEND_END and apples.is_empty() and not locked:
			# a gurítás véget ért: a számolónak már leadhatja a válaszát
			if solo and not done_ok:
				done_ok = true
				Net.set_ctrl(solo.pid, {"mode": "counter", "title": "🍎 Mennyi volt?", "text": "Minden alma átgurult. Állítsd be a végső számot, és nyomd meg a KÉSZ gombot!", "value": answer, "doneOk": true})
		if not locked and t >= LIMIT:
			_lock()
		if locked and t - lock_t >= 3.4:
			_end(answer == spawned)
	elif t - end_t >= 3.4:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _lock() -> void:
	if locked:
		return
	locked = true
	lock_t = t
	Audio.play("bell")
	if solo:
		Net.set_ctrl(solo.pid, {"mode": "wait", "icon": "🍎", "title": "A válaszod: %d" % answer, "text": "Lássuk, stimmel-e…"})
	for r in rs:
		Net.set_ctrl(r.p.pid, {"mode": "wait", "icon": "🍎", "title": "Gurítás vége", "text": "Lássuk, eltalálta-e…"})
	print_verbose("[duel] almaszámláló: válasz %d, valójában %d" % [answer, spawned])


func _end(solo_won: bool) -> void:
	over = true
	win_solo = solo_won
	end_t = t
	Audio.play("fanfare" if solo_won else "fail")
	if solo_won:
		Main.I.confetti(90)
	print_verbose("[duel] almaszámláló vége: %s nyert" % ("az egyedül játszó" if solo_won else "a csapat"))


func ranking() -> Array:
	var out: Array = []
	for p in players:
		var is_solo: bool = p == solo
		var won: bool = win_solo if is_solo else not win_solo
		var lab := ("🍎 %d – pontos!" % answer if won else "🍎 %d (%d volt)" % [answer, spawned]) if is_solo else ("🍎 %d almát gurított" % int(_r(p).get("sent", 0)))
		out.append({"pid": p.pid, "score": 1.0 if won else 0.0, "label": lab})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


# ------------------------------------------------------------------ látvány
func _sync(dt: float) -> void:
	var tm: float = Main.I.time
	for b in bulbs:
		var on := int(tm * 4.0 + b.k) % 3 != 0
		(b.n as Node3D).scale = Vector3.ONE * (1.2 if on else 0.8)
	for sp in spots:
		(sp.n as Node3D).rotation.z = sin(tm * 0.6 + sp.ph) * 0.35
	for a in apples:
		var n: Node3D = a.node
		n.position = Vector3(float(a.x), float(a.y) + absf(sin(float(a.rot) * 0.5)) * 0.03, float(a.z))
		n.rotation = Vector3(0, 0, float(a.rot))
	for r in rs:
		var m: Chars3D.CharModel = r.m
		var an := m.animate(dt)
		var k: float = t - float(r.push_t)
		var push := sin(clampf(k / 0.3, 0.0, 1.0) * PI)
		var crank: Node3D = r.crank
		crank.rotation.z = -push * 1.4
		var arms_t: Array = [Vector3(-0.3, 0.45, 0.3), Vector3(0.3 + 0.1 * push, 0.55 + 0.3 * push, 0.35)]
		var face := Vector3(0.3 + push * 0.4, 1.0, 0.5)
		if over:
			if not win_solo:
				arms_t = [Vector3(-0.4, 1.15, 0.1), Vector3(0.4, 1.15, 0.1)]
				face = Vector3(0.85, 1.1, 0.6)
			else:
				face = Vector3(0.1, 0.85, -0.9)
		m.position = Vector3(X_IN + 2.4, float(r.y) - APPLE_R - 0.0 + an.y * 0.3, float(r.z) + 0.1)
		m.rotation = Vector3(0, -PI / 2 + 0.5, an.tilt)
		m.scale = Vector3.ONE * 0.8
		for j in 2:
			K.arm_to(r.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
		K.set_face(m, r.face, face.x, face.y, face.z)
	if ss_m:
		var an := ss_m.animate(dt)
		var tt: float = ss_m.t
		var pk: float = t - press_t
		var nod := sin(clampf(pk / 0.25, 0.0, 1.0) * PI) * 0.15
		var arms_t: Array = [Vector3(-0.3, 0.5, 0.35), Vector3(0.25, 0.75 + nod, 0.4)]
		var face := Vector3(0.2, 1.15, 0.6)
		var hop := 0.0
		if over:
			if win_solo:
				arms_t = [Vector3(-0.4, 1.15 + sin(tt * 10.0) * 0.08, 0.1), Vector3(0.4, 1.15 + sin(tt * 10.0 + 1) * 0.08, 0.1)]
				face = Vector3(0.85, 1.1, 0.6)
				hop = absf(sin(tt * 7.0)) * 0.35
			else:
				arms_t = [Vector3(-0.25, 0.0, 0.15), Vector3(0.25, 0.0, 0.15)]
				face = Vector3(0.1, 0.85, -0.9)
		ss_m.position = Vector3(-7.6, 0.56 + hop + an.y * 0.3, 3.0)
		ss_m.rotation = Vector3(nod, 0.55, an.tilt)
		for j in 2:
			K.arm_to(ss_arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
		K.set_face(ss_m, ss_face, face.x, face.y, face.z)


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	K.silver_timer(c, LIMIT - (lock_t if locked else t), 640, 46, 5.0, t)
	D.text(c, "🍎 Almaszámláló", 24, 34, {"size": 26, "align": "left", "stroke": D.DARK, "sw": 6})
	D.text(c, "1 a 3 ellen · pontosan kell számolni", 24, 64, {"size": 16, "align": "left", "color": Color("#ffe3e3"), "stroke": D.DARK, "sw": 5})
	# az egyedül játszó kijelzője
	if solo != null and ss_m:
		var q := screen(ss_m.position + Vector3(0, 2.1, 0))
		var pk := t - press_t
		var sc := 1.0 + (0.18 * (1.0 - pk / 0.2) if pk < 0.2 else 0.0)
		D.panel(c, q.x - 80, q.y - 50, 160, 100, {"r": 22, "fill": Color(0.06, 0.04, 0.16, 0.9), "stroke": Color("#ffd43b"), "lw": 5})
		c.draw_set_transform(Vector2(q.x, q.y + 6), 0, Vector2(sc, sc))
		D.text(c, str(answer), 0, 0, {"size": 56, "color": Color("#ffd43b")})
		c.draw_set_transform(Vector2.ZERO)
		D.text(c, solo.name, q.x, q.y - 66, {"size": 18, "stroke": Color.BLACK, "sw": 5, "maxw": 180})
	# ellenfelek: hány almájuk maradt
	for r in rs:
		var q := screen((r.m as Node3D).position + Vector3(0, 1.4, 0))
		D.text(c, r.p.name, q.x, q.y - 18, {"size": 15, "stroke": Color.BLACK, "sw": 5, "maxw": 130, "color": (r.p.color as Color).lightened(0.4)})
		D.text(c, "🍎×%d" % (PER_RIVAL - int(r.sent)), q.x, q.y + 4, {"size": 16, "stroke": Color.BLACK, "sw": 5})
	if t >= SEND_END and not locked and not over and apples.is_empty():
		D.text(c, "Minden alma átgurult – %s, mennyi volt?" % (solo.name if solo else ""), 640, 110, {"size": 26, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 7})
	if locked:
		# leleplezés: a válasz és a valódi szám
		var k := t - lock_t
		var shown := mini(spawned, int(k * 12.0)) if not over else spawned
		D.panel(c, 380, 230, 520, 220, {"r": 30, "fill": Color(0.08, 0.04, 0.2, 0.92), "stroke": Color("#ffd43b"), "lw": 6})
		D.text(c, "Válasz: %d" % answer, 640, 290, {"size": 44, "color": Color("#ffffff")})
		D.text(c, "Almák: %d" % shown, 640, 360, {"size": 52, "color": Color("#ff8787")})
		if over:
			D.text(c, "✔ PONTOS!" if win_solo else "✖ NEM ANNYI!", 640, 420, {"size": 36, "color": Color("#69db7c") if win_solo else Color("#ff6b6b")})
	if over:
		var txt := ("%s NYERT!" % solo.name.to_upper()) if win_solo and solo != null else "A CSAPAT NYERT!"
		K.banner(c, txt, t - end_t, 3.4, 170, Color("#ffe066"), 64)
