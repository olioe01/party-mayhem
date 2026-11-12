extends Minigame
## Festékcsata (3D) – mindenki a saját színével festi a padlót, amerre jár, és átfestheti a
## másét. Az nyer, akié a legnagyobb terület az idő végén. Néha festékesvödör esik a pályára:
## aki felveszi, nagy foltot fröccsent maga köré.

const LIMIT := 40.0
const GW := 52
const GH := 32
const CELL := 0.5
const AX := GW * CELL / 2.0
const AZ := GH * CELL / 2.0
const BODY := 0.55
const BRUSH := 1.05
const ACC := 46.0
const MAXV := 7.2

var owner_of := PackedInt32Array()
var counts: Array = []
var img: Image
var tex: ImageTexture
var dirty := false
var st: Array = []
var buckets: Array = []
var bucket_t := 5.0
var blank := Color("#e9ecef")
var blank2 := Color("#dee2e6")


func meta() -> Dictionary:
	return {"id": "paint", "name": "Festékcsata", "icon": "🎨", "color": "#22d3ee", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Fesd be az egész arénát!",
		"desc": "Amerre jársz, a padló a te színedre vált – a többiekét is átfestheted! Az nyer, akié a legnagyobb terület, amikor lejár az idő. Figyeld a lehulló festékesvödröket: aki felveszi, hatalmas foltot fröccsent maga köré.",
		"controls": "A joystickkal futkározol. A festés magától megy, csak járd be a pályát!"}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "noBtn": true, "title": "🎨 Fess be mindent!"}


func _ready() -> void:
	make_env("#3b5bdb", "#dbe4ff", 0.95)
	make_camera(Vector3(0, 22.5, 14.5), Vector3(0, 0, 1.2), 50)
	make_sun(Vector3(-58, -25, 0), 1.15)
	Chars3D.box(self, 90, 1.0, 70, Chars3D.mat("#364fc7", {"rough": 0.95}), Vector3(0, -0.56, 0))
	Chars3D.box(self, AX * 2 + 1.2, 1.0, AZ * 2 + 1.2, Chars3D.mat("#343a40", {"rough": 0.8}), Vector3(0, -0.5, 0))
	for sz in [-1.0, 1.0]:
		Chars3D.box(self, AX * 2 + 1.2, 0.5, 0.5, Chars3D.mat("#f8f9fa", {"rough": 0.5}), Vector3(0, 0.25, sz * (AZ + 0.3)))
		Chars3D.box(self, 0.5, 0.5, AZ * 2 + 0.2, Chars3D.mat("#f8f9fa", {"rough": 0.5}), Vector3(sz * (AX + 0.3), 0.25, 0))
	owner_of.resize(GW * GH)
	owner_of.fill(-1)
	img = Image.create(GW, GH, false, Image.FORMAT_RGBA8)
	for y in GH:
		for x in GW:
			img.set_pixel(x, y, _blank(x, y))
	tex = ImageTexture.create_from_image(img)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(AX * 2, AZ * 2)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = tex
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.roughness = 0.45
	floor_mi.material_override = fm
	floor_mi.position.y = 0.01
	add_child(floor_mi)
	var n := players.size()
	for i in n:
		var p = players[i]
		var a := float(i) / n * TAU
		var m := player_model(p, 1.35)
		counts.append(0)
		st.append({"p": p, "i": i, "x": sin(a) * AX * 0.6, "z": cos(a) * AZ * 0.6, "vx": 0.0, "vz": 0.0, "ix": 0.0, "iy": 0.0,
			"yaw": a + PI, "m": m, "ai_t": 0.0, "tx": 0.0, "tz": 0.0})
	_sync(0.0)


func _blank(x: int, y: int) -> Color:
	return blank if (x / 2 + y / 2) % 2 == 0 else blank2


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "stick":
		return
	var s := _get(p)
	if s.is_empty():
		return
	s.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)
	s.iy = clampf(float(msg.get("y", 0)), -1.0, 1.0)


func bot(p, dt: float) -> void:
	var s := _get(p)
	s.ai_t -= dt
	var here := Vector2(s.x, s.z)
	if s.ai_t <= 0 or here.distance_to(Vector2(s.tx, s.tz)) < 0.8:
		s.ai_t = randf_range(0.5, 1.1)
		var best := INF
		for b in buckets:
			var bd := here.distance_to(Vector2(b.x, b.z))
			if bd < 9.0 and b.fall <= 0.0:
				best = bd * 0.4
				s.tx = b.x
				s.tz = b.z
		for i in 10:
			var cx := randi() % GW
			var cy := randi() % GH
			if owner_of[cy * GW + cx] == s.i:
				continue
			var w := Vector2((cx + 0.5) * CELL - AX, (cy + 0.5) * CELL - AZ)
			var d := here.distance_to(w) + randf() * 2.0
			if d < best:
				best = d
				s.tx = w.x
				s.tz = w.y
	var dir := Vector2(s.tx - s.x, s.tz - s.z)
	if dir.length() > 0.1:
		dir = dir.normalized()
	s.ix = dir.x
	s.iy = dir.y


## befest egy kört; visszaadja, hány mező változott
func _paint(x: float, z: float, r: float, who: int) -> int:
	var changed := 0
	var x0: int = clampi(int(floor((x - r + AX) / CELL)), 0, GW - 1)
	var x1: int = clampi(int(floor((x + r + AX) / CELL)), 0, GW - 1)
	var y0: int = clampi(int(floor((z - r + AZ) / CELL)), 0, GH - 1)
	var y1: int = clampi(int(floor((z + r + AZ) / CELL)), 0, GH - 1)
	var col: Color = players[who].color
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var wx := (cx + 0.5) * CELL - AX
			var wz := (cy + 0.5) * CELL - AZ
			if (wx - x) * (wx - x) + (wz - z) * (wz - z) > r * r:
				continue
			var k := cy * GW + cx
			var old := owner_of[k]
			if old == who:
				continue
			if old >= 0:
				counts[old] -= 1
			owner_of[k] = who
			counts[who] += 1
			img.set_pixel(cx, cy, col.darkened(0.06) if (cx + cy) % 2 == 0 else col)
			changed += 1
	if changed > 0:
		dirty = true
	return changed


func update(dt: float) -> void:
	for s in st:
		s.vx += s.ix * ACC * dt
		s.vz += s.iy * ACC * dt
		var fr := pow(0.03, dt)
		s.vx *= fr
		s.vz *= fr
		var sp := Vector2(s.vx, s.vz).length()
		if sp > MAXV:
			s.vx *= MAXV / sp
			s.vz *= MAXV / sp
		s.x = clampf(s.x + s.vx * dt, -AX + BODY, AX - BODY)
		s.z = clampf(s.z + s.vz * dt, -AZ + BODY, AZ - BODY)
	for i in st.size():
		for j in range(i + 1, st.size()):
			var a: Dictionary = st[i]
			var b: Dictionary = st[j]
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
			a.vx += nrm.x * 3.0
			a.vz += nrm.y * 3.0
			b.vx -= nrm.x * 3.0
			b.vz -= nrm.y * 3.0
	for s in st:
		_paint(s.x, s.z, BRUSH, s.i)
	# festékesvödrök
	bucket_t -= dt
	if bucket_t <= 0 and t < LIMIT - 3.0:
		bucket_t = randf_range(4.0, 6.5)
		_spawn_bucket()
	for b in buckets:
		b.fall = maxf(0.0, b.fall - dt * 1.6)
		if b.fall > 0:
			continue
		for s in st:
			if Vector2(s.x - b.x, s.z - b.z).length() < BODY + 0.6:
				b.dead = true
				_paint(b.x, b.z, 3.6, s.i)
				Audio.play("splash")
				Audio.play("coin")
				Net.vibrate(s.p.pid, [50, 30, 90])
				var q := screen(Vector3(b.x, 0.8, b.z))
				Main.I.burst(q.x, q.y, {"n": 46, "colors": [s.p.color_hex, "#ffffff"], "speed": 460, "life": 0.7})
				Main.I.float_text(q.x, q.y - 20, "PLACCS!", s.p.color.lightened(0.4), 36)
				(s.m as Chars3D.CharModel).emote("happy")
				break
	for b in buckets:
		if b.dead:
			b.node.queue_free()
	buckets = buckets.filter(func(b): return not b.dead)
	if dirty:
		dirty = false
		tex.update(img)
	if t >= LIMIT:
		finished = true
	_sync(dt)


func _spawn_bucket() -> void:
	var g := Node3D.new()
	add_child(g)
	Chars3D.cyl(g, 0.5, 0.38, 0.7, Chars3D.mat("#ced4da", {"metal": 0.7, "rough": 0.3}), 0, 0.35, 0, 16)
	Chars3D.cyl(g, 0.44, 0.44, 0.06, Chars3D.mat("#ffd43b", {"emit": "#ffd43b", "emit_e": 1.2}), 0, 0.7, 0, 16)
	var h := MeshInstance3D.new()
	h.mesh = Chars3D.torus(0.42, 0.03)
	h.material_override = Chars3D.mat("#868e96", {"metal": 0.6})
	h.rotation.x = PI / 2
	h.position.y = 0.72
	g.add_child(h)
	buckets.append({"x": randf_range(-AX + 2.0, AX - 2.0), "z": randf_range(-AZ + 2.0, AZ - 2.0), "node": g, "fall": 1.0, "dead": false})
	Audio.play("sparkle")


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var mv := Vector2(s.vx, s.vz)
		if mv.length() > 0.8:
			s.yaw = lerp_angle(s.yaw, atan2(mv.x, mv.y), minf(1.0, dt * 10.0))
		var hop: float = absf(sin(Main.I.time * 11.0 + s.i)) * 0.16 * minf(1.0, mv.length() / 3.0)
		m.position = Vector3(s.x, a.y + hop, s.z)
		m.rotation.y = s.yaw + a.spin
	for b in buckets:
		var g: Node3D = b.node
		g.position = Vector3(b.x, b.fall * b.fall * 14.0 + absf(sin(Main.I.time * 4.0)) * 0.12, b.z)
		g.rotation.y = Main.I.time * 1.5


func _pct(p) -> int:
	return roundi(100.0 * counts[_get(p).i] / float(GW * GH))


func ranking() -> Array:
	return rank_by(func(p): return float(counts[_get(p).i]), func(p): return "%d%%" % _pct(p))


func draw(c: CanvasItem) -> void:
	for s in st:
		var q := screen(Vector3(s.x, 2.2, s.z))
		var col := Color.WHITE
		var tix := team_of(s.p)
		if tix >= 0:
			col = MgFlow.TEAM_COLORS[tix].lightened(0.4)
		D.text(c, s.p.name, q.x, q.y, {"size": 17, "stroke": Color.BLACK, "sw": 5, "maxw": 150, "color": col})
	D.timer_hud(c, LIMIT - t)
	D.text(c, "🎨 A legnagyobb terület nyer   🪣 vödör = nagy folt", 30, 36, {"size": 20, "align": "left", "stroke": Color.BLACK, "sw": 5})
	D.score_bar(c, st.map(func(s): return s.p), func(p): return "%d%%" % _pct(p), 680)
