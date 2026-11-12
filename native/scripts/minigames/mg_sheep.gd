extends Minigame
## Birkaterelő (3D) – egy közös úton kell a kamera felé sétálni a célig. Mindenki egyforma
## gyorsan megy, de az úton bárányok kószálnak, és elállják az utat: őket kerülgetni kell.

const LIMIT := 75.0
const FINISH := 88.0
const ROAD := 5.6            # az út fél szélessége
const SPEED := 4.7           # minden játékos ugyanilyen gyors
const PR := 0.45             # játékos sugara
const SR := 0.85             # bárány sugara
const AFTER_FIRST := 14.0    # az első célba érő után ennyi idő marad

var pl: Array = []
var sheep: Array = []
var finished_n := 0
var first_t := -1.0
var end_at := -1.0
var cam_focus := 0.0
var last_baa := 0.0


func meta() -> Dictionary:
	return {"id": "sheep", "name": "Birkaterelő", "icon": "🐑", "color": "#94d82d", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Kerülgesd a bárányokat a célig!",
		"desc": "Egy közös úton sétáltok a kamera felé, a célvonalig. Mindenki pontosan ugyanolyan gyors, úgyhogy nem a tempó dönt: az úton bárányok kószálnak, és elállják az utat. Aki a legügyesebben kerülgeti őket, az ér be elsőnek!",
		"controls": "A joystickkal sétálsz: húzd magad felé (lefelé), hogy a kamera felé menj, és jobbra-balra, hogy kikerüld a bárányokat."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "noBtn": true, "title": "🐑 Húzd lefelé: előre!"}


func _ready() -> void:
	make_env("#3b8fe0", "#d0ebff", 1.0)
	make_camera(Vector3(0, 9.5, 18), Vector3(0, 0, 4), 50)
	var sun := make_sun(Vector3(-52, 150, 0), 1.3)
	sun.directional_shadow_max_distance = 90.0
	var M := Chars3D
	# rét, földút, kerítés
	M.box(self, 160, 1.0, FINISH + 120, M.mat("#74b85a", {"rough": 0.95}), Vector3(0, -0.52, FINISH / 2.0))
	M.box(self, ROAD * 2 + 0.6, 1.0, FINISH + 60, M.mat("#d9b77e", {"rough": 0.95}), Vector3(0, -0.5, FINISH / 2.0))
	var wood := M.mat("#8a5a2b", {"rough": 0.9})
	for sx in [-1.0, 1.0]:
		for yy in [0.45, 0.85]:
			M.box(self, 0.08, 0.1, FINISH + 40, wood, Vector3(sx * (ROAD + 0.45), yy, FINISH / 2.0))
		var fz := -18.0
		while fz < FINISH + 22.0:
			M.box(self, 0.16, 1.1, 0.16, wood, Vector3(sx * (ROAD + 0.45), 0.55, fz))
			fz += 3.0
	var rnd := BoardLayout.Seeded.new(29)
	for i in 60:
		var g := Node3D.new()
		var side := 1.0 if i % 2 else -1.0
		g.position = Vector3(side * (ROAD + 2.5 + rnd.next() * 16.0), 0, -16 + rnd.next() * (FINISH + 34))
		g.scale = Vector3.ONE * (1.2 + rnd.next() * 1.4)
		add_child(g)
		if i % 4 == 0:
			M.sphere(g, 0.3, M.mat("#8a8580", {"rough": 1.0}), 0, 0.12, 0, 1.2, 0.7, 1)
		elif i % 4 == 1:
			M.cyl(g, 0.07, 0.09, 0.4, M.mat("#6b4a2b"), 0, 0.2, 0, 8)
			for j in 3:
				M.cone(g, 0.5 - j * 0.12, 0.6, M.mat("#2f7d3b" if j % 2 == 0 else "#38904a"), 0, 0.55 + j * 0.35, 0, 9)
		else:
			M.cyl(g, 0.08, 0.11, 0.6, M.mat("#8b5e34"), 0, 0.3, 0, 8)
			M.sphere(g, 0.42, M.mat("#3f9d45"), 0, 0.85, 0, 1, 0.9, 1)
			M.sphere(g, 0.3, M.mat("#56b85a"), 0.18, 1.05, 0.1)
	# rajt- és célvonal
	M.box(self, ROAD * 2, 0.02, 0.3, M.mat("#ffffff"), Vector3(0, 0.012, 1.2))
	for i in 14:
		for j in 2:
			M.box(self, ROAD * 2 / 14.0, 0.02, 0.5, M.mat("#ffffff" if (i + j) % 2 else "#212529"), Vector3(-ROAD + (i + 0.5) * ROAD * 2 / 14.0, 0.013, FINISH + 0.25 + j * 0.5))
	for sx in [-1.0, 1.0]:
		M.cyl(self, 0.16, 0.2, 4.6, M.mat("#e03131"), sx * (ROAD + 0.3), 2.3, FINISH + 0.5, 12)
	M.box(self, ROAD * 2 + 1.0, 0.9, 0.12, M.mat("#ffd43b"), Vector3(0, 4.3, FINISH + 0.5))
	for face in [1.0, -1.0]:
		var lab := Label3D.new()
		lab.text = "🏁 CÉL 🏁"
		lab.font = D.font
		lab.font_size = 150
		lab.pixel_size = 0.0048
		lab.modulate = Color("#2b1055")
		lab.outline_size = 0
		lab.position = Vector3(0, 4.3, FINISH + 0.5 + face * 0.07)
		lab.rotation.y = 0.0 if face > 0 else PI
		add_child(lab)
	# bárányok: soronként egy-két bárány, a cél felé egyre sűrűbben és gyorsabban
	var z := 6.5
	var row := 0
	while z < FINISH - 3.0:
		var k := z / FINISH
		var count := 1 if randf() > 0.25 + k * 0.5 else 2
		var xs: Array = [randf_range(-ROAD + SR, ROAD - SR)]
		if count == 2:
			xs = [randf_range(-ROAD + SR, -0.6), randf_range(0.6, ROAD - SR)]
		for x in xs:
			var r := randf()
			var v := 0.0
			if r > 0.2:
				v = randf_range(1.0, 2.2 + k * 1.6) * (1.0 if randf() < 0.5 else -1.0)
			if r > 0.92:
				v = randf_range(3.6, 4.6) * (1.0 if randf() < 0.5 else -1.0)
			var node := _make_sheep(randf() < 0.12)
			sheep.append({"x": x, "z": z + randf_range(-0.25, 0.25), "vx": v, "row": row, "node": node, "ph": randf() * 6.0, "bump": 0.0,
				"pause": 0.0, "face": 1.0 if v >= 0 else -1.0})
		z += randf_range(1.9, 2.9) - k * 0.5
		row += 1
	var n := players.size()
	for i in n:
		var p = players[i]
		var m := player_model(p, 1.15)
		var disc := color_disc(p, 0.5)
		add_child(disc)
		pl.append({"p": p, "x": (i - (n - 1) / 2.0) * min(1.3, ROAD * 1.7 / n), "z": 0.0 - (i % 2) * 0.9, "ix": 0.0, "iy": 0.0, "yaw": 0.0, "m": m, "disc": disc,
			"done": false, "time": 0.0, "place": 0, "moving": false, "ai_t": 0.0, "ai_x": 0.0, "stuck": 0.0, "last_z": 0.0, "side_t": 0.0, "side_dir": 1.0})
	_sync(0.0)
	cam_focus = 0.0
	_cam(1.0)


func _make_sheep(black := false) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	var M := Chars3D
	var wool := M.mat("#3f3a3a" if black else "#fffdf5", {"rough": 1.0})
	var skin := M.mat("#2f2a2a" if not black else "#d9cfc4", {"rough": 0.8})
	M.sphere(g, 0.62, wool, 0, 0.78, 0, 1.0, 0.85, 1.25)
	for i in 7:
		var a := TAU * i / 7
		M.sphere(g, 0.3, wool, cos(a) * 0.42, 0.95 + sin(i * 2.0) * 0.12, sin(a) * 0.6)
	M.sphere(g, 0.24, wool, 0, 1.22, 0.62)
	M.sphere(g, 0.27, skin, 0, 0.98, 0.84, 0.85, 1.0, 1.1)
	for sx in [-1.0, 1.0]:
		M.sphere(g, 0.1, skin, sx * 0.27, 1.05, 0.72, 1.5, 0.6, 0.8)
		M.sphere(g, 0.055, M.mat("#ffffff"), sx * 0.12, 1.05, 1.06)
		M.sphere(g, 0.03, M.mat("#111111"), sx * 0.12, 1.05, 1.1)
		for sz in [-1.0, 1.0]:
			M.cyl(g, 0.07, 0.06, 0.5, skin, sx * 0.3, 0.25, sz * 0.42, 8)
	return g


func _get(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "stick":
		return
	var s := _get(p)
	if s.is_empty():
		return
	s.ix = clamp(float(msg.get("x", 0)), -1.0, 1.0)
	s.iy = clamp(float(msg.get("y", 0)), -1.0, 1.0)


func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.done:
		return
	# ha elakadt, egy darabig oldalra tér ki
	s.stuck = s.stuck + dt if s.z - s.last_z < SPEED * dt * 0.35 else 0.0
	s.last_z = s.z
	if s.stuck > 0.35 and s.side_t <= 0:
		s.side_t = randf_range(0.4, 0.8)
		s.side_dir = (1.0 if randf() < 0.5 else -1.0) if abs(s.x) < ROAD - 1.5 else -sign(s.x)
		s.stuck = 0.0
	s.side_t -= dt
	s.ai_t -= dt
	if s.ai_t <= 0:
		s.ai_t = randf_range(0.12, 0.26)
		var steer := 0.0
		var near := 99.0
		for sh in sheep:
			var dz: float = sh.z - s.z
			if dz < -0.3 or dz > 3.4:
				continue
			# hol lesz a bárány, mire odaérek
			var fx: float = sh.x + sh.vx * (dz / SPEED) * 0.7
			var dx: float = s.x - fx
			if abs(dx) < SR + PR + 0.55 and dz < near:
				near = dz
				steer = sign(dx) if abs(dx) > 0.08 else (1.0 if randf() < 0.5 else -1.0)
				if abs(s.x + steer * 1.5) > ROAD - PR:
					steer = -steer
		s.ai_x = steer
	if s.side_t > 0:
		s.ix = s.side_dir
		s.iy = 0.25
	else:
		s.ix = s.ai_x
		s.iy = 1.0 if s.ai_x == 0.0 else 0.75


func update(dt: float) -> void:
	# bárányok
	for sh in sheep:
		sh.bump = max(0.0, sh.bump - dt)
		if sh.pause > 0:
			sh.pause -= dt
			continue
		sh.x += sh.vx * dt
		if abs(sh.x) > ROAD - SR:
			sh.x = sign(sh.x) * (ROAD - SR)
			sh.vx = -sh.vx
			if randf() < 0.3:
				sh.pause = randf_range(0.3, 1.2)
		if sh.vx != 0.0:
			sh.face = 1.0 if sh.vx > 0 else -1.0
	for i in sheep.size():
		for j in range(i + 1, sheep.size()):
			var a: Dictionary = sheep[i]
			var b: Dictionary = sheep[j]
			if b.row - a.row > 1:
				break
			var dv := Vector2(a.x - b.x, a.z - b.z)
			if dv.length() < SR * 2 and dv.length() > 0.001:
				var push := (SR * 2 - dv.length()) / 2.0
				var sx: float = sign(dv.x) if dv.x != 0.0 else 1.0
				a.x = clamp(a.x + sx * push, -ROAD + SR, ROAD - SR)
				b.x = clamp(b.x - sx * push, -ROAD + SR, ROAD - SR)
				if (a.vx - b.vx) * sx < 0:
					var tmp: float = a.vx
					a.vx = b.vx
					b.vx = tmp
	# játékosok: mindenki ugyanolyan gyors
	for s in pl:
		s.moving = false
		if s.done:
			s.z += SPEED * 0.6 * dt if s.z < FINISH + 4.0 + s.place * 0.0 else 0.0
			continue
		var dir := Vector2(s.ix, s.iy)
		if dir.length() > 0.25:
			dir = dir.normalized()
			s.x += dir.x * SPEED * dt
			s.z += dir.y * SPEED * dt
			s.moving = true
			s.yaw = lerp_angle(s.yaw, atan2(dir.x, dir.y), min(1.0, dt * 10.0))
	for it in 2:
		for i in pl.size():
			for j in range(i + 1, pl.size()):
				var a: Dictionary = pl[i]
				var b: Dictionary = pl[j]
				if a.done or b.done:
					continue
				var dv := Vector2(a.x - b.x, a.z - b.z)
				var d := dv.length()
				if d < PR * 2 and d > 0.001:
					var nrm := dv / d
					var ov := (PR * 2 - d) / 2.0
					a.x += nrm.x * ov
					a.z += nrm.y * ov
					b.x -= nrm.x * ov
					b.z -= nrm.y * ov
		for s in pl:
			if s.done:
				continue
			for sh in sheep:
				if abs(sh.z - s.z) > SR + PR:
					continue
				var dv := Vector2(s.x - sh.x, s.z - sh.z)
				var d := dv.length()
				if d < SR + PR:
					var nrm := dv / d if d > 0.001 else Vector2(0, -1)
					s.x = sh.x + nrm.x * (SR + PR)
					s.z = sh.z + nrm.y * (SR + PR)
					if sh.bump <= 0 and s.moving:
						sh.bump = 0.5
						if t - last_baa > 0.25:
							last_baa = t
							Audio.play("pop", randf_range(0.45, 0.6))
			# az út széle: ha a bárány a kerítéshez szorít, hátrébb kell lépni
			if abs(s.x) > ROAD - PR:
				s.x = sign(s.x) * (ROAD - PR)
				for sh in sheep:
					var dv := Vector2(s.x - sh.x, s.z - sh.z)
					if dv.length() < SR + PR:
						var need := sqrt(max(0.0, pow(SR + PR, 2) - dv.x * dv.x))
						s.z = sh.z - need if s.z <= sh.z else sh.z + need
			s.z = max(s.z, -3.0)
	for s in pl:
		if not s.done and s.z >= FINISH:
			s.done = true
			s.time = t
			finished_n += 1
			s.place = finished_n
			if first_t < 0:
				first_t = t
				Audio.play("fanfare")
			else:
				Audio.play("win")
			(s.m as Chars3D.CharModel).emote("cheer")
			Net.vibrate(s.p.pid, [80, 60, 200])
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏁", "title": "%d. helyen értél be!" % s.place, "text": "Várj a többiekre…"})
			var q := screen(Vector3(s.x, 1.2, s.z))
			Main.I.burst(q.x, q.y, {"n": 40, "colors": ["#ffd43b", "#ffffff", s.p.color_hex], "speed": 420})
	if end_at < 0:
		if finished_n >= pl.size():
			end_at = t + 1.5
		elif (first_t >= 0 and t - first_t >= AFTER_FIRST) or t >= LIMIT:
			end_at = t + 0.2
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)
	_cam(dt)


func idle(dt: float) -> void:
	_sync(dt)
	_cam(dt)


func _cam(dt: float) -> void:
	# a kamera a mezőny eleje előtt hátrál, szemből nézi a játékosokat
	var lead := 0.0
	var sum := 0.0
	var cnt := 0
	for s in pl:
		if s.done:
			continue
		lead = max(lead, s.z)
		sum += s.z
		cnt += 1
	var target: float = lead * 0.7 + (sum / cnt) * 0.3 if cnt > 0 else FINISH
	target = min(target, FINISH - 2.0)
	cam_focus = lerpf(cam_focus, target, min(1.0, dt * 2.5))
	cam.position = Vector3(0, 9.6, cam_focus + 16.5)
	cam.look_at(Vector3(0, 0.4, cam_focus + 2.6), Vector3.UP)


func _sync(dt: float) -> void:
	for s in pl:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var bob: float = abs(sin(t * 13.0 + s.x)) * 0.16 if s.moving else 0.0
		m.position = Vector3(s.x, a.y + bob, s.z)
		m.rotation.y = (0.0 if s.done else s.yaw) + a.spin
		var disc: MeshInstance3D = s.disc
		disc.position = Vector3(s.x, 0.03, s.z)
	for sh in sheep:
		var g: Node3D = sh.node
		var walking: bool = sh.vx != 0.0 and sh.pause <= 0
		var hop: float = abs(sin(Main.I.time * (5.0 + abs(sh.vx) * 2.0) + sh.ph)) * 0.1 if walking else 0.0
		g.position = Vector3(sh.x, hop + sh.bump * 0.25 * abs(sin(sh.bump * 20.0)), sh.z)
		var target_yaw: float = PI / 2 * sh.face if walking else sin(Main.I.time * 0.5 + sh.ph) * 0.5
		g.rotation.y = lerp_angle(g.rotation.y, target_yaw, min(1.0, dt * 6.0))
		g.rotation.z = sin(sh.bump * 30.0) * 0.12 if sh.bump > 0 else 0.0


func ranking() -> Array:
	var out: Array = []
	for s in pl:
		if s.done:
			out.append({"pid": s.p.pid, "score": 1000.0 - s.time, "label": "%.1f mp" % s.time})
		else:
			out.append({"pid": s.p.pid, "score": snappedf(s.z, 0.1), "label": "%d%%-nál tartott" % int(clamp(s.z / FINISH, 0.0, 0.99) * 100)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func draw(c: CanvasItem) -> void:
	for s in pl:
		var q := screen(Vector3(s.x, 1.75, s.z))
		var col := Color.WHITE
		var tix := team_of(s.p)
		if tix >= 0:
			col = MgFlow.TEAM_COLORS[tix].lightened(0.4)
		D.text(c, ("%d. " % s.place if s.done else "") + s.p.name, q.x, q.y, {"size": 17, "stroke": Color.BLACK, "sw": 5, "maxw": 140, "color": col})
	# haladásjelző
	var x0 := 240.0
	var x1 := 1040.0
	D.panel(c, x0 - 30, 68, x1 - x0 + 60, 34, {"r": 17, "fill": Color(0.08, 0.05, 0.19, 0.8), "shadow": false})
	c.draw_line(Vector2(x0, 85), Vector2(x1, 85), Color(1, 1, 1, 0.35), 5, true)
	D.emoji(c, "🏁", x1 + 14, 84, 22)
	for s in pl:
		var k: float = clamp(s.z / FINISH, 0.0, 1.0)
		D.avatar(c, s.p, lerpf(x0, x1, k), 85, 13, {"shadow": false})
	D.timer_hud(c, (AFTER_FIRST - (t - first_t)) if first_t >= 0 else (LIMIT - t), 640, 30)
	if first_t >= 0 and finished_n < pl.size():
		D.text(c, "Valaki beért – siess!", 640, 126, {"size": 22, "color": Color("#ffd43b"), "stroke": Color.BLACK, "sw": 5})
