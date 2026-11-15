extends Minigame
## Szoborjáték (3D) – fuss a cél felé gyors koppintással, amíg a Bagoly-őr háttal áll!
## Ha megfordul (vörösen izzik a szeme), dermedj meg: aki ilyenkor mozdul, visszakerül.

const LIMIT := 40.0
const GOAL := 16.0
const STEP := 0.32

var st: Array = []
var guard: Node3D
var guard_eyes: Array = []
var watching := false
var turn_k := 0.0          # 0 = háttal, 1 = szemben
var next_switch := 2.5
var warn_t := -1.0
var place := 0


func meta() -> Dictionary:
	return {"id": "statue", "name": "Szoborjáték", "icon": "🦉", "color": "#8b5cf6", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Fuss… és dermedj meg!",
		"desc": "Fuss a Bagoly-őr felé gyors koppintással! Amikor a bagoly megfordul és vörösen izzik a szeme, ne nyomj semmit – aki mozdul, visszakerül a rajtvonalhoz. Aki elsőként ér célba, nyer.",
		"controls": "Koppints gyorsan a FUTÁS gombra, de állj meg, amikor a bagoly feléd néz! Huhogás = mindjárt megfordul."}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "🏃 FUTÁS!", "hint": "Állj meg, ha a bagoly néz!", "rapid": true}


func _ready() -> void:
	make_env("#7c3aed", "#fbcfe8", 0.75)
	make_camera(Vector3(0, 6.5, 9.0), Vector3(0, 0.5, -6.0), 52)
	make_sun(Vector3(-50, 30, 0), 1.2, "#fff1d6")
	Chars3D.box(self, 18, 0.4, GOAL + 8, Chars3D.mat("#86c95a"), Vector3(0, -0.2, -GOAL / 2 + 1))
	for i in 9:
		Chars3D.box(self, 18, 0.02, 0.12, Chars3D.mat("#ffffff"), Vector3(0, 0.01, -i * 2.0))
	Chars3D.box(self, 18, 0.03, 0.4, Chars3D.mat("#ffd43b", {"emit": "#ffd43b", "emit_e": 0.8}), Vector3(0, 0.02, -GOAL))
	# fák a pálya szélén
	for side in [-1, 1]:
		for k in 6:
			var z := -k * 3.5
			var x: float = side * (7.5 + (k % 2) * 0.8)
			Chars3D.cyl(self, 0.18, 0.24, 1.2, Chars3D.mat("#8b5e34"), x, 0.6, z, 8)
			Chars3D.sphere(self, 1.0, Chars3D.mat("#3f9d45"), x, 1.8, z, 1, 1.1, 1)
	_decor()
	# Bagoly-őr (saját, kódból épített figura)
	guard = Node3D.new()
	guard.position = Vector3(0, 0, -GOAL - 2.5)
	add_child(guard)
	var brown := Chars3D.mat("#7a4a2a")
	var belly := Chars3D.mat("#f2d18b")
	Chars3D.sphere(guard, 1.5, brown, 0, 1.6, 0, 1, 1.25, 0.95)
	Chars3D.sphere(guard, 1.05, belly, 0, 1.3, 0.75, 1, 1.15, 0.5)
	for s in [-1, 1]:
		Chars3D.cone(guard, 0.35, 0.8, brown, s * 0.85, 3.4, 0, 6, Vector3(0, 0, -s * 0.3))
		Chars3D.sphere(guard, 0.62, Chars3D.mat("#ffffff"), s * 0.62, 2.55, 0.95)
		var eye := Chars3D.sphere(guard, 0.3, Chars3D.mat("#1f1b2e"), s * 0.62, 2.55, 1.42)
		guard_eyes.append(eye)
		Chars3D.sphere(guard, 0.55, brown, s * 1.45, 1.6, 0, 0.5, 1.2, 0.9)
		Chars3D.sphere(guard, 0.25, Chars3D.mat("#ff9f1c"), s * 0.4, 0.15, 0.7, 1.3, 0.5, 1.6)
	Chars3D.cone(guard, 0.22, 0.5, Chars3D.mat("#ff9f1c"), 0, 2.2, 1.35, 8, Vector3(PI / 2 + 0.4, 0, 0))
	# hát oldali minta
	Chars3D.sphere(guard, 0.9, Chars3D.mat("#5c3820"), 0, 1.8, -0.9, 1, 1.2, 0.4)
	var n := players.size()
	var lane: float = min(2.0, 14.0 / n)
	for i in n:
		var p = players[i]
		var m := player_model(p, 1.0)
		st.append({"p": p, "x": (i - (n - 1) / 2.0) * lane, "z": 0.0, "disp": 0.0, "fin": -1.0, "caught_t": -9.0, "bot_t": 0.0, "m": m,
			"bot_risk": randf_range(0.0, 0.35), "place": 0})
	_sync(0.0)


## Díszlet: erdei tisztás futósávokkal, kerítéssel, lámpásokkal, célkapuval és a bagoly kőtalapzatával.
func _decor() -> void:
	var rnd := BoardLayout.Seeded.new(31)
	var wood := Chars3D.mat("#8b5e34", {"rough": 0.9})
	var dark_wood := Chars3D.mat("#5c3d1e", {"rough": 0.9})
	var stone := Chars3D.mat("#8d8a94", {"rough": 1.0})
	var stone2 := Chars3D.mat("#6f6b78", {"rough": 1.0})
	# váltakozó fűcsíkok és egy döngölt földút középen
	for i in 8:
		Chars3D.box(self, 15.6, 0.012, 1.0, Chars3D.mat("#79bb4f"), Vector3(0, 0.004, -i * 2.0 - 1.0))
	Chars3D.box(self, 15.6, 0.01, 2.2, Chars3D.mat("#c9a86a", {"rough": 1.0}), Vector3(0, 0.006, 1.6))
	# rajtvonal kockás csíkkal
	for k in 26:
		Chars3D.box(self, 0.6, 0.02, 0.3, Chars3D.mat("#ffffff" if k % 2 == 0 else "#2b2140"), Vector3(-7.5 + k * 0.6, 0.015, 0.45))
	# kerítés a két oldalon
	for side in [-1, 1]:
		var fx: float = side * 8.2
		for k in 13:
			var z := 2.0 - k * 1.6
			Chars3D.lcyl(self, 0.09, 0.11, 0.9, wood, fx, 0.45, z, 6)
			Chars3D.lcone(self, 0.12, 0.16, dark_wood, fx, 0.98, z, 6)
		Chars3D.box(self, 0.07, 0.1, 19.6, wood, Vector3(fx, 0.62, -7.6))
		Chars3D.box(self, 0.07, 0.1, 19.6, wood, Vector3(fx, 0.3, -7.6))
		# lámpások oszlopon
		for k in 4:
			var z := -1.0 - k * 5.0
			var lx: float = side * 8.9
			Chars3D.lcyl(self, 0.07, 0.09, 2.2, dark_wood, lx, 1.1, z, 6)
			Chars3D.box(self, 0.34, 0.4, 0.34, Chars3D.mat("#ffe066", {"emit": "#ffd43b", "emit_e": 1.6}), Vector3(lx, 2.35, z))
			Chars3D.lcone(self, 0.3, 0.22, dark_wood, lx, 2.66, z, 4)
		# bokrok, sziklák, gombák, virágok a pálya szélén
		for k in 9:
			var z := 2.5 - k * 2.4 + rnd.next() * 0.8
			var bx: float = side * (9.6 + rnd.next() * 2.2)
			var r := 0.45 + rnd.next() * 0.4
			Chars3D.lsphere(self, r, Chars3D.mat("#2f8f3a" if k % 2 == 0 else "#4caf50"), bx, r * 0.6, z, 1.2, 0.8, 1.0)
			if k % 3 == 0:
				Chars3D.lsphere(self, 0.4 + rnd.next() * 0.3, stone if k % 2 == 0 else stone2, bx - side * 1.1, 0.2, z + 0.9, 1.2, 0.7, 1.0, 6, 4)
			if k % 3 == 1:
				var mx: float = bx - side * 0.9
				Chars3D.lcyl(self, 0.07, 0.09, 0.3, Chars3D.mat("#f5efe0"), mx, 0.15, z + 0.6, 6)
				Chars3D.lsphere(self, 0.2, Chars3D.mat("#e03131"), mx, 0.32, z + 0.6, 1.0, 0.6, 1.0, 8, 4)
		for k in 14:
			var fz := 2.0 - rnd.next() * 18.0
			var flx: float = side * (8.5 + rnd.next() * 0.5)
			Chars3D.lsphere(self, 0.09, Chars3D.mat(["#ff8fa3", "#ffd43b", "#ffffff", "#b197fc"][k % 4]), flx, 0.12, fz, 1.0, 0.6, 1.0, 6, 3)
	# hátsó fenyves és dombok
	for k in 11:
		var x := -15.0 + k * 3.0 + rnd.next() * 1.2
		var z := -GOAL - 6.5 - rnd.next() * 3.0
		var h := 2.6 + rnd.next() * 1.8
		Chars3D.lcyl(self, 0.16, 0.22, 0.9, dark_wood, x, 0.45, z, 6)
		for j in 3:
			Chars3D.lcone(self, 1.25 - j * 0.3, h * 0.5, Chars3D.mat("#1f6b3a" if j % 2 == 0 else "#2b8a4a"), x, 0.9 + j * h * 0.27 + h * 0.25, z, 7)
	for k in 4:
		Chars3D.lsphere(self, 7.0, Chars3D.mat("#5aa84a", {"rough": 1.0}), -16.0 + k * 11.0, -3.6, -GOAL - 13.0, 1.4, 0.8, 1.0, 10, 5)
	# célkapu: két oszlop, gerenda, zászlók
	for side in [-1, 1]:
		Chars3D.lcyl(self, 0.18, 0.22, 3.2, wood, side * 7.6, 1.6, -GOAL, 8)
		Chars3D.lsphere(self, 0.26, Chars3D.mat("#ffd43b", {"metal": 0.5, "rough": 0.3}), side * 7.6, 3.3, -GOAL)
	Chars3D.box(self, 15.4, 0.22, 0.22, dark_wood, Vector3(0, 3.0, -GOAL))
	for k in 15:
		Chars3D.lcone(self, 0.22, 0.42, Chars3D.mat(["#ff4d6d", "#ffd43b", "#4dabf7", "#51cf66"][k % 4]), -7.0 + k * 1.0, 2.66, -GOAL, 3, Vector3(PI, 0, 0))
	# a bagoly kőtalapzata lépcsővel és két fáklyával
	Chars3D.lcyl(self, 2.5, 2.8, 0.3, stone2, 0, 0.0, -GOAL - 2.5, 10)
	Chars3D.lcyl(self, 2.0, 2.3, 0.26, stone, 0, 0.02, -GOAL - 2.5, 10)
	for side in [-1, 1]:
		var tx: float = side * 3.3
		Chars3D.lcyl(self, 0.22, 0.3, 1.5, stone, tx, 0.75, -GOAL - 1.4, 6)
		Chars3D.lcyl(self, 0.32, 0.2, 0.2, stone2, tx, 1.58, -GOAL - 1.4, 6)
		Chars3D.lcone(self, 0.2, 0.55, Chars3D.mat("#ff922b", {"emit": "#ff922b", "emit_e": 2.5}), tx, 1.95, -GOAL - 1.4, 5)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffb347")
		lamp.light_energy = 1.2
		lamp.omni_range = 5.0
		lamp.position = Vector3(tx, 2.1, -GOAL - 1.4)
		add_child(lamp)


func _entry(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var s := _entry(p)
	if s.is_empty() or s.fin >= 0 or t - s.caught_t < 1.2:
		return
	if watching and turn_k > 0.7:
		s.z = max(0.0, s.z - GOAL * 0.4)
		s.caught_t = t
		Audio.play("fail")
		Net.vibrate(p.pid, [250, 80, 250])
		(s.m as Chars3D.CharModel).emote("dizzy")
		var q := screen(Vector3(s.x, 1.5, -s.disp))
		Main.I.float_text(q.x, q.y, "LEBUKTÁL!", Color("#ff8787"), 30)
		return
	s.z += STEP
	if s.z >= GOAL:
		s.z = GOAL
		s.fin = t
		place += 1
		s.place = place
		Audio.play("win")
		(s.m as Chars3D.CharModel).emote("cheer")
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🏁", "title": "Célba értél! (%d.)" % place, "text": "%.1f másodperc" % t})


func bot(p, dt: float) -> void:
	var s := _entry(p)
	if s.fin >= 0:
		return
	s.bot_t -= dt
	if s.bot_t > 0:
		return
	s.bot_t = 1.0 / randf_range(5.0, 7.5)
	# a bot óvatos: figyelmeztetéskor (huhogás) többnyire megáll
	var danger := watching or (warn_t >= 0 and t - warn_t > 0.15)
	if danger and randf() > s.bot_risk * 0.15:
		return
	input(p, {"t": "tap"})


func update(dt: float) -> void:
	if t >= next_switch - 0.7 and not watching and warn_t < 0:
		warn_t = t
		Audio.play("bell")
	if t >= next_switch:
		watching = not watching
		warn_t = -1.0
		next_switch = t + (randf_range(1.6, 3.0) if watching else randf_range(2.0, 4.5))
		Audio.play("whoosh")
	var all_done := true
	for s in st:
		if s.fin < 0:
			all_done = false
	if all_done or t >= LIMIT:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	turn_k = move_toward(turn_k, 1.0 if watching else 0.0, dt * 5.0)
	guard.rotation.y = lerpf(PI, 0.0, turn_k)
	var warn := warn_t >= 0 and sin(Main.I.time * 30.0) > 0
	guard.position.y = 0.15 if warn else 0.0
	for e in guard_eyes:
		(e as MeshInstance3D).material_override = Chars3D.mat("#ff1744", {"emit": "#ff1744", "emit_e": 3.0}) if turn_k > 0.7 else Chars3D.mat("#1f1b2e")
	for s in st:
		s.disp = lerpf(s.disp, s.z, min(1.0, dt * 10.0))
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var moving: bool = abs(s.disp - s.z) > 0.05
		m.position = Vector3(s.x, a.y + (abs(sin(t * 16.0)) * 0.15 if moving else 0.0), -s.disp)
		m.rotation.y = PI + a.spin
		m.rotation.x = a.tilt


func ranking() -> Array:
	var out: Array = []
	for s in st:
		out.append({"pid": s.p.pid, "score": (1000.0 - s.fin) if s.fin >= 0 else s.z, "label": ("%.1f mp" % s.fin) if s.fin >= 0 else "%d%%" % roundi(s.z / GOAL * 100)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func draw(c: CanvasItem) -> void:
	for s in st:
		var q := screen(Vector3(s.x, 1.5, -s.disp))
		var tix := team_of(s.p)
		D.text(c, s.p.name, q.x, q.y, {"size": 15, "stroke": Color.BLACK, "sw": 4, "maxw": 110, "color": MgFlow.TEAM_COLORS[tix].lightened(0.45) if tix >= 0 else Color.WHITE})
		if s.fin >= 0:
			D.text(c, "🏁 %d." % s.place, q.x, q.y - 22, {"size": 16, "color": Color("#ffd43b"), "stroke": Color.BLACK, "sw": 4})
	var msg := "👀 NE MOZDULJ!" if turn_k > 0.5 else ("🦉 Huhú…" if warn_t >= 0 else "🏃 FUSS!")
	var col := Color("#ff6b6b") if turn_k > 0.5 else (Color("#ffd43b") if warn_t >= 0 else Color("#69db7c"))
	D.panel(c, 440, 14, 400, 64, {"r": 32, "fill": Color(0, 0, 0, 0.55)})
	D.text(c, msg, 640, 46, {"size": 34, "color": col})
	D.timer_hud(c, LIMIT - t, 1180, 40)
