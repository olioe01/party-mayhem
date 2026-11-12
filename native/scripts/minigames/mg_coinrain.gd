extends Minigame
## Érmeeső (3D) – kapd el az érméket, kerüld a bombákat. A logika px-ben fut, 1 egység = 40 px.

const LIMIT := 30.0
const GROUND := 590.0
const SPEED := 560.0
const PR := 30.0

var pl: Array = []
var items: Array = []
var spawn_t := 0.0
var coin_mesh: CylinderMesh
var gold_mesh: CylinderMesh


func meta() -> Dictionary:
	return {"id": "coinrain", "name": "Érmeeső", "icon": "🪙", "color": "#fab005", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Gyűjts, amennyit csak tudsz!",
		"desc": "Érmék potyognak az égből! A sima érme 1 pont, a nagy arany 3. A bombák viszont 3 pontot visznek, és egy pillanatra elkábítanak.",
		"controls": "Tartsd nyomva a ◀ vagy ▶ gombot a mozgáshoz."}


func layout(_p) -> Dictionary:
	return {"mode": "lr"}


func _w(x: float, y: float, z := 0.0) -> Vector3:
	return Vector3((x - 640) / 40.0, (GROUND - y) / 40.0, z)


func _ready() -> void:
	make_env("#3b8fe0", "#d0ebff", 1.0)
	make_camera(Vector3(0, 6.0, 17.5), Vector3(0, 5.2, 0), 46)
	make_sun(Vector3(-50, -20, 0), 1.25)
	Chars3D.box(self, 60, 1.0, 8, Chars3D.mat("#82c91e"), Vector3(0, -0.5, 0))
	Chars3D.box(self, 60, 3.0, 8, Chars3D.mat("#5c940d"), Vector3(0, -2.5, 0))
	# háttér: dombok, fák, felhők
	var rnd := BoardLayout.Seeded.new(3)
	for i in 9:
		var h := MeshInstance3D.new()
		h.mesh = Chars3D._sphere_mesh(1.0)
		h.material_override = Chars3D.mat("#69b34c" if i % 2 else "#4f9a45")
		var s := 4.0 + rnd.next() * 5.0
		h.scale = Vector3(s * 1.4, s * 0.7, s)
		h.position = Vector3(-30 + i * 7.5, -1.0, -14 - rnd.next() * 6)
		add_child(h)
	for i in 7:
		var g := Node3D.new()
		g.position = Vector3(-24 + rnd.next() * 48, 11 + rnd.next() * 5, -12 - rnd.next() * 4)
		for k in 3:
			Chars3D.sphere(g, 1.2 + rnd.next(), Chars3D.mat("#ffffff", {"rough": 1.0}), (k - 1) * 1.6, rnd.next() * 0.6, 0, 1, 0.6, 0.8)
		add_child(g)
	coin_mesh = CylinderMesh.new()
	coin_mesh.top_radius = 0.38
	coin_mesh.bottom_radius = 0.38
	coin_mesh.height = 0.08
	coin_mesh.radial_segments = 24
	gold_mesh = CylinderMesh.new()
	gold_mesh.top_radius = 0.6
	gold_mesh.bottom_radius = 0.6
	gold_mesh.height = 0.12
	gold_mesh.radial_segments = 28
	var n := players.size()
	for i in n:
		var p = players[i]
		var m := player_model(p, 1.35)
		pl.append({"p": p, "x": 640 + (i - (n - 1) / 2.0) * min(140.0, 1100.0 / n), "dir": 0, "score": 0, "stun": 0.0,
			"face": 1, "ai_t": 0.0, "greed": randf_range(0.6, 1.4), "m": m})
	_sync(0.0)


func _get(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "lr":
		return
	var s := _get(p)
	if not s.is_empty():
		s.dir = clampi(roundi(float(msg.get("v", 0))), -1, 1)


func bot(p, dt: float) -> void:
	var s := _get(p)
	s.ai_t -= dt
	if s.ai_t > 0:
		return
	s.ai_t = randf_range(0.12, 0.3)
	var best = null
	var best_v := -INF
	for it in items:
		if it.dead:
			continue
		var tt: float = (GROUND - it.y) / it.vy
		if tt < 0:
			continue
		var dx: float = it.x - s.x
		if it.type == "bomb":
			if abs(dx) < 70 and tt < 0.6:
				s.dir = -1 if dx > 0 else 1
				return
			continue
		if abs(dx) > SPEED * tt + 20:
			continue
		var crowd := 0
		for o in pl:
			if o != s and abs(o.x - it.x) < abs(dx):
				crowd += 1
		var v: float = (3.0 if it.type == "gold" else 1.0) * s.greed / (0.3 + tt) - abs(dx) / 1500.0 - crowd * 0.6 + randf_range(-0.3, 0.3)
		if v > best_v:
			best_v = v
			best = it
	if best == null:
		s.dir = 0
		return
	var ddx: float = best.x - s.x
	s.dir = 0 if abs(ddx) < 12 else int(sign(ddx))


func update(dt: float) -> void:
	spawn_t -= dt
	if spawn_t <= 0:
		var k := t / LIMIT
		spawn_t = (0.42 - k * 0.22) / max(1.0, sqrt(pl.size() / 2.0))
		var r := randf()
		var type := "gold" if r < 0.1 else ("bomb" if r < 0.32 + k * 0.1 else "coin")
		var node := _make_item(type)
		items.append({"x": randf_range(60, 1220), "y": -60.0, "vy": randf_range(220, 340) + k * 160, "type": type, "rot": randf() * 6.0, "dead": false, "node": node})
	for s in pl:
		s.stun = max(0.0, s.stun - dt)
		if s.stun <= 0 and s.dir != 0:
			s.x = clamp(s.x + s.dir * SPEED * dt, PR + 40, 1240 - PR)
			s.face = s.dir
	var sorted := pl.duplicate()
	sorted.sort_custom(func(a, c): return a.x < c.x)
	for k in 3:
		for i in range(1, sorted.size()):
			var a: Dictionary = sorted[i - 1]
			var c: Dictionary = sorted[i]
			var ov: float = PR * 1.9 - (c.x - a.x)
			if ov > 0:
				a.x = clamp(a.x - ov / 2, PR + 40, 1240 - PR)
				c.x = clamp(c.x + ov / 2, PR + 40, 1240 - PR)
	for it in items:
		if it.dead:
			continue
		it.y += it.vy * dt
		it.rot += dt * 4
		if abs(it.y - (GROUND - PR * 2)) < PR + 22:
			var best = null
			for s in pl:
				var d: float = abs(it.x - s.x)
				if d < PR + 22 and (best == null or d < abs(it.x - best.x)):
					best = s
			if best:
				it.dead = true
				_catch(best, it)
		if not it.dead and it.y > GROUND + 10:
			it.dead = true
			if it.type == "bomb":
				var q := screen(_w(it.x, GROUND))
				Main.I.burst(q.x, q.y, {"n": 14, "colors": ["#ff922b", "#555555"], "speed": 200})
				Audio.play("hit")
	for it in items:
		if it.dead and is_instance_valid(it.node):
			it.node.queue_free()
	items = items.filter(func(it): return not it.dead)
	if t >= LIMIT:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _make_item(type: String) -> Node3D:
	var g := Node3D.new()
	if type == "bomb":
		Chars3D.sphere(g, 0.5, Chars3D.mat("#212529", {"rough": 0.3, "metal": 0.3}))
		Chars3D.cyl(g, 0.12, 0.12, 0.2, Chars3D.mat("#495057"), 0, 0.52, 0, 8)
		Chars3D.sphere(g, 0.1, Chars3D.mat("#ffd43b", {"emit": "#ff922b", "emit_e": 4.0}), 0.05, 0.7, 0)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = gold_mesh if type == "gold" else coin_mesh
		mi.material_override = Chars3D.mat("#f59f00" if type == "gold" else "#fcc419", {"metal": 0.8, "rough": 0.25, "emit": "#fab005", "emit_e": 0.35 if type == "gold" else 0.15})
		mi.rotation.x = PI / 2
		g.add_child(mi)
	add_child(g)
	return g


func _catch(s: Dictionary, it: Dictionary) -> void:
	var q := screen(_w(s.x, GROUND - PR * 3))
	if it.type == "bomb":
		s.score = max(0, s.score - 3)
		s.stun = 1.1
		Audio.play("boom")
		Net.vibrate(s.p.pid, [200, 60, 200])
		Main.I.burst(q.x, q.y, {"n": 40, "colors": ["#ff922b", "#ffd43b", "#495057"], "speed": 420})
		Main.I.float_text(q.x, q.y - 20, "−3", Color("#ff8787"), 34)
		(s.m as Chars3D.CharModel).emote("dizzy")
	else:
		var v := 3 if it.type == "gold" else 1
		s.score += v
		Audio.play("coin")
		Net.vibrate(s.p.pid, 25)
		Main.I.burst(q.x, q.y, {"n": 18 if v == 3 else 6, "colors": ["#ffd43b", "#fff3bf"], "speed": 220})
		Main.I.float_text(q.x, q.y - 20, "+%d" % v, Color("#ffe066") if v == 3 else Color.WHITE, 34 if v == 3 else 26)
		(s.m as Chars3D.CharModel).land = 0.6


func _sync(dt: float) -> void:
	for s in pl:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var running: bool = s.dir != 0 and s.stun <= 0
		var bob: float = abs(sin(t * 14.0)) * 0.18 if running else 0.0
		m.position = _w(s.x, GROUND) + Vector3(0, a.y + bob, 0)
		var target = (PI / 2 * s.face) if running else 0.0
		m.rotation.y = lerp_angle(m.rotation.y, target, min(1.0, dt * 12.0)) + a.spin * 0.0
		m.rotation.z = -s.face * 0.12 if running else 0.0
	for it in items:
		var g: Node3D = it.node
		g.position = _w(it.x, it.y)
		g.rotation.y = it.rot


func ranking() -> Array:
	return rank_by(func(p): return float(_get(p).score), func(p): return "%d pont" % _get(p).score)


func draw(c: CanvasItem) -> void:
	for s in pl:
		var q := screen(_w(s.x, GROUND + 22))
		D.text(c, str(s.score), q.x, q.y, {"size": 24, "stroke": Color("#2b8a3e"), "sw": 6})
		if s.stun > 0:
			var h := screen(_w(s.x, GROUND - PR * 3.8))
			D.emoji(c, "💫", h.x, h.y, 30)
	D.timer_hud(c, LIMIT - t)
	D.score_bar(c, pl.map(func(s): return s.p), func(p): return _get(p).score, 680)
