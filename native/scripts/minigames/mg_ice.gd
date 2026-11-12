extends Minigame
## Olvadó jégtábla (3D) – hatszögletű jégcsempéken álltok. Amelyikre ráléptek, megreped,
## és pár pillanat múlva leszakad. Folyamatosan mozogni kell; az utolsó talpon maradó nyer.

const LIMIT := 75.0
const S := 1.0               # a hatszög sugara
const BODY := 0.42
const ACC := 40.0
const MAXV := 4.5
const REFREEZE_UNTIL := 30.0   # eddig fagynak vissza a leszakadt csempék

var rad := 4
var tiles: Array = []        # {x, z, node, mesh, state(0 ép,1 reped,2 zuhan,3 nincs), tm, ph}
var st: Array = []
var elim: Array = []
var end_at := -1.0
var melt_t := 0.0
var ice_mats: Array = []
var crack_mat: StandardMaterial3D


func meta() -> Dictionary:
	return {"id": "ice", "name": "Olvadó jégtábla", "icon": "🧊", "color": "#74c0fc", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Ne állj meg egy pillanatra sem!",
		"desc": "Hatszögletű jégcsempéken álltok a jeges víz fölött. Amelyik csempére rálépsz, megreped, és pár pillanat múlva leszakad – úgyhogy folyamatosan mozogni kell! A leszakadt csempék eleinte visszafagynak, de fél perc után már nem, és a jég a szélekről is olvadni kezd. Az utolsó talpon maradó nyer.",
		"controls": "A joystickkal mozogsz. Mindig lépj tovább egy ép csempére, mielőtt alattad leszakad!"}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "noBtn": true, "title": "🧊 Mozogj folyamatosan!"}


func _ready() -> void:
	var n := players.size()
	rad = 4 if n <= 4 else 5
	make_env("#0b3d6b", "#a5d8ff", 0.9)
	var sc := rad / 5.0
	make_camera(Vector3(0, 19.5 * sc + 2.0, 12.0 * sc + 1.5), Vector3(0, 0, 0.9), 50)
	make_sun(Vector3(-58, -25, 0), 1.2)
	Chars3D.box(self, 120, 0.2, 120, Chars3D.mat("#1971c2", {"rough": 0.15, "metal": 0.3}), Vector3(0, -3.0, 0))
	var rnd := BoardLayout.Seeded.new(5)
	for i in 14:
		var a := rnd.next() * TAU
		var d := rad * 1.8 + 5.0 + rnd.next() * 9.0
		var r := 0.8 + rnd.next() * 1.6
		Chars3D.cone(self, r, r * 2.2, Chars3D.mat("#e7f5ff", {"rough": 0.3}), sin(a) * d, -3.0 + r * 1.1, cos(a) * d - 3.0, 6)
	ice_mats = [Chars3D.mat("#d0ebff", {"rough": 0.15, "metal": 0.1}), Chars3D.mat("#e7f5ff", {"rough": 0.15, "metal": 0.1}), Chars3D.mat("#c5f6fa", {"rough": 0.15, "metal": 0.1})]
	crack_mat = Chars3D.mat("#ffa8a8", {"rough": 0.3})
	var hex := CylinderMesh.new()
	hex.top_radius = S * 0.96
	hex.bottom_radius = S * 0.8
	hex.height = 0.6
	hex.radial_segments = 6
	hex.rings = 1
	for q in range(-rad, rad + 1):
		for r in range(-rad, rad + 1):
			if absi(q + r) > rad:
				continue
			var g := Node3D.new()
			add_child(g)
			var mi := MeshInstance3D.new()
			mi.mesh = hex
			mi.material_override = ice_mats[posmod(q - r, 3)]
			mi.position.y = -0.3
			g.add_child(mi)
			var x := S * sqrt(3.0) * (q + r / 2.0)
			var z := S * 1.5 * r
			g.position = Vector3(x, 0, z)
			tiles.append({"x": x, "z": z, "node": g, "mesh": mi, "state": 0, "tm": 0.0, "ph": randf() * 6.0, "base": posmod(q - r, 3), "rise": 0.0})
	var ext := rad * 1.5 * S * 0.62
	for i in n:
		var p = players[i]
		var a := float(i) / n * TAU
		var m := player_model(p, 1.2)
		st.append({"p": p, "x": sin(a) * ext, "z": cos(a) * ext, "vx": 0.0, "vz": 0.0, "ix": 0.0, "iy": 0.0, "yaw": a + PI, "m": m,
			"out": false, "fall_t": 0.0, "air": 0.0, "ai_t": 0.0, "tgt": -1, "nerve": 0.45})
	_sync(0.0)


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func _tile_at(x: float, z: float) -> int:
	var best := -1
	var bd := INF
	for i in tiles.size():
		var tl: Dictionary = tiles[i]
		var d: float = (tl.x - x) * (tl.x - x) + (tl.z - z) * (tl.z - z)
		if d < bd:
			bd = d
			best = i
	return best if bd <= S * S * 0.94 else -1


func _delay() -> float:
	return maxf(0.6, 1.15 - t * 0.012)


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
	var here := _tile_at(s.x, s.z)
	if here >= 0 and tiles[here].state == 1 and tiles[here].tm > s.nerve:
		# amíg bírja a jég, a csempe közepén vár
		var hc := Vector2(tiles[here].x - s.x, tiles[here].z - s.z)
		s.ix = clampf(hc.x * 2.0, -1.0, 1.0)
		s.iy = clampf(hc.y * 2.0, -1.0, 1.0)
		s.tgt = -1
		return
	var need: bool = s.ai_t <= 0
	if s.tgt >= 0:
		var tt: Dictionary = tiles[s.tgt]
		if tt.state >= 2 or Vector2(tt.x - s.x, tt.z - s.z).length() < 0.3:
			need = true
	else:
		need = true
	if need:
		s.ai_t = randf_range(0.25, 0.5)
		s.nerve = randf_range(0.3, 0.6)
		var cur := here
		var best := -1
		var bv := -INF
		for i in tiles.size():
			var tl: Dictionary = tiles[i]
			if tl.state >= 2 or i == cur:
				continue
			var d := Vector2(tl.x - s.x, tl.z - s.z).length()
			if d > 4.2:
				continue
			var v := -d * 1.6 + randf() * 1.2
			if tl.state == 0:
				v += 4.0
			else:
				v -= (1.0 - tl.tm) * 3.0
			# minél több ép szomszéd, annál biztonságosabb
			for o in tiles:
				if o.state == 0 and absf(o.x - tl.x) < 1.9 and absf(o.z - tl.z) < 1.9:
					v += 0.35
			if v > bv:
				bv = v
				best = i
		s.tgt = best
	if s.tgt < 0:
		s.ix = 0.0
		s.iy = 0.0
		return
	var g: Dictionary = tiles[s.tgt]
	var dir := Vector2(g.x - s.x, g.z - s.z)
	if dir.length() > 0.05:
		dir = dir.normalized()
	s.ix = dir.x
	s.iy = dir.y


func update(dt: float) -> void:
	for s in st:
		if s.out:
			s.fall_t += dt
			continue
		s.vx += s.ix * ACC * dt
		s.vz += s.iy * ACC * dt
		var fr := pow(0.04, dt)
		s.vx *= fr
		s.vz *= fr
		var sp := Vector2(s.vx, s.vz).length()
		if sp > MAXV:
			s.vx *= MAXV / sp
			s.vz *= MAXV / sp
		s.x += s.vx * dt
		s.z += s.vz * dt
	var alive: Array = st.filter(func(s): return not s.out)
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a: Dictionary = alive[i]
			var b: Dictionary = alive[j]
			var dv := Vector2(a.x - b.x, a.z - b.z)
			var d := dv.length()
			if d >= BODY * 2 or d == 0:
				continue
			var nrm := dv / d
			var ov := BODY * 2 - d
			a.x += nrm.x * ov / 2
			a.z += nrm.y * ov / 2
			b.x -= nrm.x * ov / 2
			b.z -= nrm.y * ov / 2
			a.vx += nrm.x * 2.5
			a.vz += nrm.y * 2.5
			b.vx -= nrm.x * 2.5
			b.vz -= nrm.y * 2.5
	# csempék
	for s in alive:
		var ti := _tile_at(s.x, s.z)
		var solid: bool = ti >= 0 and tiles[ti].state < 2
		if solid:
			s.air = 0.0
			if tiles[ti].state == 0:
				tiles[ti].state = 1
				tiles[ti].tm = _delay()
				Audio.play("tick", 0.7)
		else:
			s.air += dt
			if s.air > 0.13:
				_fall(s)
	# olvadás a szélekről, hogy biztosan vége legyen
	if t > REFREEZE_UNTIL:
		melt_t -= dt
		if melt_t <= 0:
			melt_t = maxf(0.2, 0.6 - (t - REFREEZE_UNTIL) * 0.02)
			var far := -1
			var fd := -1.0
			for i in tiles.size():
				var tl: Dictionary = tiles[i]
				if tl.state != 0:
					continue
				var d: float = Vector2(tl.x, tl.z).length() + randf() * 1.5
				if d > fd:
					fd = d
					far = i
			if far >= 0:
				tiles[far].state = 1
				tiles[far].tm = 1.3
	for tl in tiles:
		if tl.state == 1:
			tl.tm -= dt
			if tl.tm <= 0:
				tl.state = 2
				tl.tm = 0.0
				Audio.play("land", 0.8)
		elif tl.state == 2:
			tl.tm += dt
			if tl.tm > 1.2:
				tl.state = 3
				tl.tm = 0.0
				tl.node.visible = false
		elif tl.state == 3 and t < REFREEZE_UNTIL:
			tl.tm += dt
			if tl.tm > 3.5 + t * 0.2:
				# visszafagy
				tl.state = 0
				tl.rise = 1.0
				tl.node.visible = true
				tl.node.rotation = Vector3.ZERO
	var left: Array = st.filter(func(s): return not s.out)
	var team_alive := {}
	for o in left:
		team_alive[team_of(o.p)] = true
	var teams_over := teams.size() == 2 and team_alive.size() <= 1
	if end_at < 0 and ((st.size() > 1 and left.size() <= 1) or left.is_empty() or t >= LIMIT or teams_over):
		end_at = t + 1.1
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)


func _fall(s: Dictionary) -> void:
	s.out = true
	elim.append(s)
	Audio.play("splash")
	Net.vibrate(s.p.pid, [200, 80, 200])
	var q := screen(Vector3(s.x, 0, s.z))
	Main.I.burst(q.x, q.y, {"n": 30, "colors": ["#a5d8ff", "#ffffff", "#4dabf7"], "speed": 300})
	Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🥶", "title": "Vízbe estél!", "text": "%d. kiesett" % elim.size()})


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for tl in tiles:
		if tl.state == 3:
			continue
		var g: Node3D = tl.node
		var mi: MeshInstance3D = tl.mesh
		if tl.state == 0:
			tl.rise = maxf(0.0, tl.rise - dt * 2.5)
			g.position = Vector3(tl.x, sin(Main.I.time * 1.6 + tl.ph) * 0.03 - tl.rise * tl.rise * 1.5, tl.z)
			mi.material_override = ice_mats[tl.base]
		elif tl.state == 1:
			var k: float = tl.tm
			g.position = Vector3(tl.x + sin(Main.I.time * 48.0 + tl.ph) * 0.035, -0.08, tl.z + cos(Main.I.time * 41.0 + tl.ph) * 0.035)
			mi.material_override = crack_mat if fmod(k * 7.0, 1.0) < 0.5 or k < 0.3 else ice_mats[tl.base]
		else:
			var k2: float = tl.tm
			g.position = Vector3(tl.x, -0.08 - k2 * k2 * 9.0, tl.z)
			g.rotation.x = k2 * 1.6
			g.rotation.z = k2 * 1.1
			mi.material_override = crack_mat
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var pos := Vector3(s.x, 0, s.z)
		if s.out:
			var k: float = minf(1.0, s.fall_t / 0.8)
			pos.y = -k * k * 3.4
			m.rotation.x = k * 1.4
			m.visible = s.fall_t < 1.2
		var mv := Vector2(s.vx, s.vz)
		if mv.length() > 0.6:
			s.yaw = lerp_angle(s.yaw, atan2(mv.x, mv.y), minf(1.0, dt * 10.0))
		var hop: float = absf(sin(Main.I.time * 12.0 + s.x)) * 0.14 * minf(1.0, mv.length() / 3.0)
		m.position = pos + Vector3(0, a.y + (0.0 if s.out else hop), 0)
		m.rotation.y = s.yaw + a.spin


func ranking() -> Array:
	var out: Array = []
	for s in st:
		var ei := elim.find(s)
		out.append({"pid": s.p.pid, "score": float(ei) if s.out else 1000.0, "label": "%d. kiesett" % (ei + 1) if s.out else "Túlélte! 💪"})
	out.sort_custom(func(a, c): return a.score > c.score)
	return out


func draw(c: CanvasItem) -> void:
	for s in st:
		if s.out:
			continue
		var q := screen(Vector3(s.x, 1.9, s.z))
		var col := Color.WHITE
		var tix := team_of(s.p)
		if tix >= 0:
			col = MgFlow.TEAM_COLORS[tix].lightened(0.4)
		D.text(c, s.p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 5, "maxw": 130, "color": col})
	var alive := st.filter(func(s): return not s.out).size()
	D.text(c, "🧊 Talpon: %d / %d" % [alive, st.size()], 30, 36, {"size": 26, "align": "left", "stroke": Color.BLACK, "sw": 6})
	if t > REFREEZE_UNTIL - 1.0 and t < REFREEZE_UNTIL + 4.0:
		D.text(c, "☀️ Már nem fagy vissza – olvad a jég!", 640, 110, {"size": 36, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 9})
	D.timer_hud(c, LIMIT - t, 1180, 40)
