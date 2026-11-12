extends Minigame
## Lufivadászat (3D) – kiskocsikkal kell kipukkasztani a lufikat egy nagy arénában.
## Sima lufi 1 pont, arany lufi 3 pont. Félidőben berobban egy bombagömb, ami összevissza
## pattog: akit eltalál, 1 másodpercre elkábul és 1 pontot veszít.

const LIMIT := 50.0
const HALF := LIMIT / 2.0
const AX := 13.0             # az aréna fél szélessége
const AZ := 8.0              # az aréna fél mélysége
const KART_R := 0.75
const BALLOON_R := 0.6
const BOMB_R := 0.95
const ACC := 42.0
const MAXV := 9.5
const BOMB_SPEED := 13.5

var karts: Array = []
var balloons: Array = []
var spawn_t := 0.4
var bomb = null              # {x, z, vx, vz, node, turn_t, light}
var bomb_warn := -1.0
var last_bump := 0.0


func meta() -> Dictionary:
	return {"id": "balloons", "name": "Lufivadászat", "icon": "🎈", "color": "#f06595", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Pukkaszd ki a legtöbb lufit!",
		"desc": "Kiskocsikkal száguldoztok egy nagy arénában. Hajts bele a lufikba: a sima lufi 1 pont, az arany lufi 3 pont. Félidőben berobban egy bombagömb, ami összevissza pattog – akit eltalál, 1 másodpercre elkábul, és 1 pontot veszít!",
		"controls": "A joystickkal irányítod a kiskocsidat. Csak bele kell hajtani a lufikba."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "noBtn": true, "title": "🎈 Hajts a lufikba!"}


func _ready() -> void:
	make_env("#2f7fd6", "#d6ecff", 0.9)
	make_camera(Vector3(0, 22.5, 14.5), Vector3(0, 0, 1.2), 50)
	make_sun(Vector3(-58, -25, 0), 1.25)
	# aréna: füves környezet, aszfalt pálya, színes gumifal
	Chars3D.box(self, 90, 1.0, 70, Chars3D.mat("#69b34c", {"rough": 0.95}), Vector3(0, -0.56, 0))
	Chars3D.box(self, AX * 2 + 1.6, 1.0, AZ * 2 + 1.6, Chars3D.mat("#495057", {"rough": 0.9}), Vector3(0, -0.5, 0))
	Chars3D.box(self, AX * 2, 0.02, AZ * 2, Chars3D.mat("#5c636b", {"rough": 0.85}), Vector3(0, 0.011, 0))
	var line := Chars3D.mat("#f1f3f5", {"rough": 0.7})
	Chars3D.cyl(self, 3.0, 3.0, 0.02, line, 0, 0.022, 0, 40)
	Chars3D.cyl(self, 2.8, 2.8, 0.022, Chars3D.mat("#5c636b", {"rough": 0.85}), 0, 0.024, 0, 40)
	Chars3D.box(self, 0.2, 0.02, AZ * 2, line, Vector3(0, 0.023, 0))
	var cols := ["#ff4d6d", "#ffffff"]
	var nx := 26
	for i in nx:
		var x := -AX + (i + 0.5) * (AX * 2 / nx)
		for sz in [-1.0, 1.0]:
			Chars3D.box(self, AX * 2 / nx, 0.7, 0.6, Chars3D.mat(cols[i % 2]), Vector3(x, 0.35, sz * (AZ + 0.3)))
	var nz := 16
	for i in nz:
		var z := -AZ + (i + 0.5) * (AZ * 2 / nz)
		for sx in [-1.0, 1.0]:
			Chars3D.box(self, 0.6, 0.7, AZ * 2 / nz, Chars3D.mat(cols[i % 2]), Vector3(sx * (AX + 0.3), 0.35, z))
	var rnd := BoardLayout.Seeded.new(13)
	for i in 18:
		var g := Node3D.new()
		var a := rnd.next() * TAU
		g.position = Vector3(sin(a) * (20 + rnd.next() * 10), 0, cos(a) * (15 + rnd.next() * 6) - 4)
		if abs(g.position.x) < AX + 2.5 and abs(g.position.z) < AZ + 2.5:
			g.position.x = sign(g.position.x + 0.01) * (AX + 4.0 + rnd.next() * 6.0)
		g.scale = Vector3.ONE * (1.4 + rnd.next())
		add_child(g)
		Chars3D.cyl(g, 0.08, 0.11, 0.6, Chars3D.mat("#8b5e34"), 0, 0.3, 0, 8)
		Chars3D.sphere(g, 0.42, Chars3D.mat("#3f9d45"), 0, 0.85, 0, 1, 0.9, 1)
	var n := players.size()
	for i in n:
		var p = players[i]
		var a := float(i) / n * TAU
		var k := _make_kart(p)
		karts.append({"p": p, "x": sin(a) * 5.0, "z": cos(a) * 3.6, "vx": 0.0, "vz": 0.0, "ix": 0.0, "iy": 0.0,
			"yaw": a + PI, "score": 0, "stun": 0.0, "safe": 0.0, "node": k.node, "m": k.model, "ai_t": 0.0, "tx": 0.0, "tz": 0.0})
	for i in _want():
		_spawn_balloon()
	_sync(0.0)


func _make_kart(p) -> Dictionary:
	var g := Node3D.new()
	add_child(g)
	var body := Chars3D.mat(p.color_hex, {"rough": 0.35, "metal": 0.15})
	var dark := Chars3D.mat("#212529", {"rough": 0.6})
	Chars3D.box(g, 1.0, 0.28, 1.5, body, Vector3(0, 0.3, 0))
	Chars3D.box(g, 0.8, 0.2, 0.45, body, Vector3(0, 0.44, 0.62))
	Chars3D.box(g, 1.1, 0.1, 0.16, Chars3D.mat("#f1f3f5"), Vector3(0, 0.22, 0.8))
	Chars3D.box(g, 0.9, 0.36, 0.12, dark, Vector3(0, 0.6, -0.62))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Chars3D.cyl(g, 0.24, 0.24, 0.2, dark, sx * 0.58, 0.24, sz * 0.5, 14, Vector3(0, 0, PI / 2))
	var model := Chars3D.build(p.char_id)
	model.scale = Vector3.ONE * 0.95
	model.position = Vector3(0, 0.42, -0.1)
	g.add_child(model)
	return {"node": g, "model": model}


## ennyi lufi legyen egyszerre a pályán
func _want() -> int:
	return 4 + ceili(players.size() * 0.75)


func _kart(p) -> Dictionary:
	for k in karts:
		if k.p == p:
			return k
	return {}


func _spawn_balloon() -> void:
	var x := 0.0
	var z := 0.0
	for tries in 12:
		x = randf_range(-AX + 1.2, AX - 1.2)
		z = randf_range(-AZ + 1.2, AZ - 1.2)
		var ok := true
		for k in karts:
			if Vector2(k.x - x, k.z - z).length() < 2.6:
				ok = false
		if ok:
			break
	var gold := randf() < 0.16
	var g := Node3D.new()
	add_child(g)
	var col: String = "#ffd43b" if gold else ["#ff4d6d", "#4dabf7", "#51cf66", "#b197fc", "#ff922b", "#22d3ee"].pick_random()
	var m := Chars3D.mat(col, {"rough": 0.2, "metal": 0.75, "emit": "#ffb000", "emit_e": 0.9}) if gold else Chars3D.mat(col, {"rough": 0.25})
	var r := 0.72 if gold else 0.6
	Chars3D.sphere(g, r, m, 0, 1.4, 0, 1, 1.18, 1)
	Chars3D.cone(g, 0.1, 0.14, m, 0, 0.66, 0, 8)
	Chars3D.cyl(g, 0.015, 0.015, 0.6, Chars3D.mat("#f8f9fa"), 0, 0.3, 0, 4)
	balloons.append({"x": x, "z": z, "gold": gold, "node": g, "age": 0.0, "dead": false, "ph": randf() * 6.0, "col": col})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "stick":
		return
	var k := _kart(p)
	if k.is_empty():
		return
	k.ix = clamp(float(msg.get("x", 0)), -1.0, 1.0)
	k.iy = clamp(float(msg.get("y", 0)), -1.0, 1.0)


func bot(p, dt: float) -> void:
	var k := _kart(p)
	k.ai_t -= dt
	if k.ai_t > 0:
		return
	k.ai_t = randf_range(0.1, 0.22)
	var best = null
	var best_v := -INF
	for b in balloons:
		if b.dead or b.age < 0.3:
			continue
		var d := Vector2(b.x - k.x, b.z - k.z).length()
		var crowd := 0.0
		for o in karts:
			if o != k and Vector2(b.x - o.x, b.z - o.z).length() < d:
				crowd += 1.0
		var v: float = (3.0 if b.gold else 1.0) / (1.5 + d) - crowd * 0.08 + randf_range(-0.03, 0.03)
		if v > best_v:
			best_v = v
			best = b
	var dir := Vector2.ZERO
	if best != null:
		dir = Vector2(best.x - k.x, best.z - k.z).normalized()
	if bomb != null:
		var away := Vector2(k.x - bomb.x, k.z - bomb.z)
		if away.length() < 4.5:
			dir = (dir + away.normalized() * 1.6).normalized()
	k.ix = dir.x
	k.iy = dir.y


func update(dt: float) -> void:
	# lufik utánpótlása
	spawn_t -= dt
	if spawn_t <= 0 and balloons.size() < _want():
		spawn_t = 0.38
		_spawn_balloon()
	for b in balloons:
		b.age += dt
	# kocsik
	for k in karts:
		k.stun = max(0.0, k.stun - dt)
		k.safe = max(0.0, k.safe - dt)
		if k.stun <= 0:
			k.vx += k.ix * ACC * dt
			k.vz += k.iy * ACC * dt
		var fr := pow(0.08, dt)
		k.vx *= fr
		k.vz *= fr
		var sp := Vector2(k.vx, k.vz).length()
		if sp > MAXV:
			k.vx *= MAXV / sp
			k.vz *= MAXV / sp
		k.x += k.vx * dt
		k.z += k.vz * dt
		if abs(k.x) > AX - KART_R:
			k.x = sign(k.x) * (AX - KART_R)
			k.vx *= -0.45
		if abs(k.z) > AZ - KART_R:
			k.z = sign(k.z) * (AZ - KART_R)
			k.vz *= -0.45
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a: Dictionary = karts[i]
			var c: Dictionary = karts[j]
			var dv := Vector2(a.x - c.x, a.z - c.z)
			var d := dv.length()
			if d >= KART_R * 2 or d == 0:
				continue
			var nrm := dv / d
			var ov := KART_R * 2 - d
			a.x += nrm.x * ov / 2
			a.z += nrm.y * ov / 2
			c.x -= nrm.x * ov / 2
			c.z -= nrm.y * ov / 2
			var rel: float = (a.vx - c.vx) * nrm.x + (a.vz - c.vz) * nrm.y
			if rel < 0:
				var imp := -1.6 * rel / 2 + 1.5
				a.vx += nrm.x * imp
				a.vz += nrm.y * imp
				c.vx -= nrm.x * imp
				c.vz -= nrm.y * imp
				if t - last_bump > 0.1:
					last_bump = t
					Audio.play("hit")
	# pukkasztás
	for b in balloons:
		if b.dead or b.age < 0.25:
			continue
		var best = null
		var best_d := KART_R + BALLOON_R
		for k in karts:
			var d := Vector2(k.x - b.x, k.z - b.z).length()
			if d < best_d:
				best_d = d
				best = k
		if best != null:
			b.dead = true
			_pop(best, b)
	for b in balloons:
		if b.dead and is_instance_valid(b.node):
			b.node.queue_free()
	balloons = balloons.filter(func(b): return not b.dead)
	# bombagömb félidőtől
	if bomb == null and bomb_warn < 0 and t >= HALF - 2.0:
		bomb_warn = t
		Audio.play("fail")
	if bomb == null and t >= HALF:
		_spawn_bomb()
	if bomb != null:
		_update_bomb(dt)
	if t >= LIMIT:
		finished = true
	_sync(dt)


func _pop(k: Dictionary, b: Dictionary) -> void:
	var v := 3 if b.gold else 1
	k.score += v
	Audio.play("pop", 1.3 if b.gold else randf_range(0.9, 1.15))
	if b.gold:
		Audio.play("coin")
	Net.vibrate(k.p.pid, [40, 30, 80] if b.gold else 25)
	var q := screen(Vector3(b.x, 1.3, b.z))
	Main.I.burst(q.x, q.y, {"n": 26 if b.gold else 12, "colors": [b.col, "#ffffff"], "speed": 300 if b.gold else 220, "life": 0.6})
	Main.I.float_text(q.x, q.y - 16, "+%d" % v, Color("#ffe066") if b.gold else Color.WHITE, 36 if b.gold else 26)
	(k.m as Chars3D.CharModel).land = 0.5


func _spawn_bomb() -> void:
	var g := Node3D.new()
	add_child(g)
	Chars3D.sphere(g, BOMB_R, Chars3D.mat("#212529", {"rough": 0.25, "metal": 0.4}))
	Chars3D.cyl(g, 0.2, 0.2, 0.3, Chars3D.mat("#495057"), 0, BOMB_R, 0, 10)
	Chars3D.sphere(g, 0.18, Chars3D.mat("#ffd43b", {"emit": "#ff6b00", "emit_e": 5.0}), 0.08, BOMB_R + 0.25, 0)
	for i in 6:
		var a := TAU * i / 6
		Chars3D.cone(g, 0.2, 0.4, Chars3D.mat("#e03131", {"emit": "#e03131", "emit_e": 0.8}), cos(a) * BOMB_R, 0, sin(a) * BOMB_R, 6, Vector3(0, -a, -PI / 2))
	var light := OmniLight3D.new()
	light.light_color = Color("#ff4d4d")
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.position.y = 1.2
	g.add_child(light)
	var a0 := randf() * TAU
	bomb = {"x": 0.0, "z": -AZ + 1.5, "vx": cos(a0) * BOMB_SPEED, "vz": abs(sin(a0)) * BOMB_SPEED, "node": g, "turn_t": 0.8, "light": light, "drop": 1.0}
	Audio.play("boom")
	var q := screen(Vector3(0, 1, -AZ + 1.5))
	Main.I.burst(q.x, q.y, {"n": 40, "colors": ["#ff922b", "#ffd43b", "#495057"], "speed": 420})


func _update_bomb(dt: float) -> void:
	bomb.drop = max(0.0, bomb.drop - dt * 2.5)
	bomb.turn_t -= dt
	if bomb.turn_t <= 0:
		# összevissza cikázik: új véletlen irány, néha egy kocsi felé
		bomb.turn_t = randf_range(0.35, 1.2)
		var a := randf() * TAU
		if randf() < 0.35 and karts.size():
			var k: Dictionary = karts.pick_random()
			a = atan2(k.z - bomb.z, k.x - bomb.x) + randf_range(-0.35, 0.35)
		bomb.vx = cos(a) * BOMB_SPEED
		bomb.vz = sin(a) * BOMB_SPEED
	bomb.x += bomb.vx * dt
	bomb.z += bomb.vz * dt
	if abs(bomb.x) > AX - BOMB_R:
		bomb.x = sign(bomb.x) * (AX - BOMB_R)
		bomb.vx *= -1
		Audio.play("land")
	if abs(bomb.z) > AZ - BOMB_R:
		bomb.z = sign(bomb.z) * (AZ - BOMB_R)
		bomb.vz *= -1
		Audio.play("land")
	for k in karts:
		if k.safe > 0:
			continue
		var dv := Vector2(k.x - bomb.x, k.z - bomb.z)
		if dv.length() < BOMB_R + KART_R:
			k.stun = 1.0
			k.safe = 1.8
			var lost: int = min(1, k.score)
			k.score -= lost
			var nrm := dv.normalized() if dv.length() > 0.01 else Vector2(1, 0)
			k.vx = nrm.x * 11.0
			k.vz = nrm.y * 11.0
			Audio.play("boom")
			Net.vibrate(k.p.pid, [200, 60, 200])
			(k.m as Chars3D.CharModel).emote("dizzy")
			var q := screen(Vector3(k.x, 1.2, k.z))
			Main.I.burst(q.x, q.y, {"n": 34, "colors": ["#ff922b", "#ffd43b", "#495057"], "speed": 400})
			Main.I.float_text(q.x, q.y - 20, "−%d" % lost if lost > 0 else "💫", Color("#ff8787"), 36)


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for k in karts:
		var m: Chars3D.CharModel = k.m
		var a := m.animate(dt)
		var mv := Vector2(k.vx, k.vz)
		if k.stun > 0:
			k.yaw += dt * 14.0
		elif mv.length() > 0.8:
			k.yaw = lerp_angle(k.yaw, atan2(mv.x, mv.y), min(1.0, dt * 9.0))
		var node: Node3D = k.node
		node.position = Vector3(k.x, 0, k.z)
		node.rotation.y = k.yaw
		m.position.y = 0.42 + a.y * 0.4
		m.rotation.y = a.spin
		node.visible = k.safe <= 0 or k.stun > 0 or fmod(t * 10.0, 1.0) < 0.6
	for b in balloons:
		var g: Node3D = b.node
		var grow: float = min(1.0, b.age * 4.0)
		g.position = Vector3(b.x, sin(t * 2.2 + b.ph) * 0.12, b.z)
		g.rotation.z = sin(t * 1.7 + b.ph) * 0.12
		g.scale = Vector3.ONE * D.ease_out_back(grow)
	if bomb != null:
		var g: Node3D = bomb.node
		g.position = Vector3(bomb.x, BOMB_R + bomb.drop * 9.0, bomb.z)
		g.rotation = Vector3(t * 7.0, t * 5.0, 0)
		(bomb.light as OmniLight3D).light_energy = 2.5 + sin(t * 18.0) * 1.5


func ranking() -> Array:
	return rank_by(func(p): return float(_kart(p).score), func(p): return "%d pont" % _kart(p).score)


func draw(c: CanvasItem) -> void:
	for k in karts:
		var q := screen(Vector3(k.x, 2.3, k.z))
		var col := Color.WHITE
		var tix := team_of(k.p)
		if tix >= 0:
			col = MgFlow.TEAM_COLORS[tix].lightened(0.4)
		D.text(c, "%s  %d" % [k.p.name, k.score], q.x, q.y, {"size": 17, "stroke": Color.BLACK, "sw": 5, "maxw": 150, "color": col})
		if k.stun > 0:
			D.emoji(c, "💫", q.x, q.y - 26, 28)
	D.timer_hud(c, LIMIT - t)
	if bomb == null and bomb_warn >= 0:
		var pulse := 0.5 + sin(t * 14.0) * 0.5
		D.text(c, "💣 JÖN A BOMBA!", 640, 120, {"size": 46, "color": Color("#ff6b6b").lerp(Color.WHITE, pulse * 0.5), "stroke": D.DARK, "sw": 10})
	elif bomb != null and t - HALF < 2.0:
		D.text(c, "💣 Kerüld a bombát! −1 pont", 640, 120, {"size": 38, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 9, "alpha": clamp((HALF + 2.0 - t) * 2.0, 0.0, 1.0)})
	D.text(c, "🎈 1 pont   ⭐ arany lufi 3 pont", 30, 36, {"size": 20, "align": "left", "stroke": Color.BLACK, "sw": 5})
	D.score_bar(c, karts.map(func(k): return k.p), func(p): return _kart(p).score, 680)
