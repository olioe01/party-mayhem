extends Minigame
## Forró bomba (3D) – egy ketyegő bomba jár kézről kézre. A joystickkal célzol, a gombbal
## dobod tovább. Akinél felrobban, kiesik; az utolsó túlélő nyer. A kanóc körönként rövidebb.

const LIMIT := 150.0
const FLY := 0.42
const HOLD_MIN := 0.3

var ring := 4.6
var st: Array = []
var elim: Array = []
var holder = null            # akinél a bomba van (vagy akihez éppen repül)
var flying := false
var fly_t := 0.0
var from_pos := Vector3.ZERO
var fuse := 0.0
var fuse_total := 1.0
var round_i := 0
var phase := "pause"         # pause | live | boom
var phase_t := 0.0
var bomb: Node3D
var light: OmniLight3D
var end_at := -1.0
var tick_t := 0.0


func meta() -> Dictionary:
	return {"id": "bomb", "name": "Forró bomba", "icon": "💣", "color": "#ff6b6b", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Csak ne nálad robbanjon!",
		"desc": "Egy ketyegő bomba jár kézről kézre. Ha nálad van, célozz a joystickkal valakire, és dobd tovább! Akinél felrobban, kiesik. A kanóc minden körben rövidebb, és senki sem tudja pontosan, mikor robban. Az utolsó túlélő nyer.",
		"controls": "A joystickkal célzol (a nyíl mutatja, kire), a DOBÁS gombbal továbbdobod a bombát."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "btn": "💣 DOBÁS", "cd": 250, "title": "Célozz, és dobd tovább!"}


func _ready() -> void:
	make_env("#1a1033", "#7048e8", 0.75)
	var n := players.size()
	ring = 3.4 + n * 0.3
	make_camera(Vector3(0, 12.5 + n * 0.35, 10.5 + n * 0.3), Vector3(0, 0, 0.7), 50)
	make_sun(Vector3(-58, -25, 0), 1.15)
	Chars3D.cyl(self, 40.0, 40.0, 1.0, Chars3D.mat("#2b2150", {"rough": 0.95}), 0, -0.62, 0, 40)
	Chars3D.cyl(self, ring + 1.9, ring + 2.2, 1.0, Chars3D.mat("#5f3dc4", {"rough": 0.7}), 0, -0.5, 0, 48)
	Chars3D.cyl(self, ring - 1.3, ring - 1.3, 0.02, Chars3D.mat("#7950f2", {"rough": 0.6}), 0, 0.012, 0, 48)
	Chars3D.cyl(self, 1.1, 1.1, 0.02, Chars3D.mat("#ffd43b", {"rough": 0.5}), 0, 0.024, 0, 32)
	for i in n:
		var p = players[i]
		var a := float(i) / n * TAU
		var pos := Vector3(sin(a) * ring, 0, cos(a) * ring)
		var m := player_model(p, 1.45)
		var disc := color_disc(p, 0.75)
		disc.position = pos + Vector3(0, 0.03, 0)
		add_child(disc)
		st.append({"p": p, "pos": pos, "yaw": a + PI, "m": m, "disc": disc, "out": false, "out_t": 0.0, "ix": 0.0, "iy": 0.0,
			"aim": null, "hold_t": 0.0, "bot_t": 0.0})
	bomb = Node3D.new()
	add_child(bomb)
	Chars3D.sphere(bomb, 0.46, Chars3D.mat("#212529", {"rough": 0.25, "metal": 0.4}))
	Chars3D.cyl(bomb, 0.13, 0.13, 0.2, Chars3D.mat("#495057"), 0, 0.46, 0, 10)
	Chars3D.cyl(bomb, 0.03, 0.03, 0.3, Chars3D.mat("#d9a066"), 0.05, 0.68, 0, 6, Vector3(0, 0, -0.3))
	Chars3D.sphere(bomb, 0.12, Chars3D.mat("#ffd43b", {"emit": "#ff6b00", "emit_e": 6.0}), 0.1, 0.84, 0)
	light = OmniLight3D.new()
	light.light_color = Color("#ff5a36")
	light.omni_range = 5.0
	light.position.y = 0.6
	bomb.add_child(light)
	bomb.visible = false
	_sync(0.0)


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func _alive() -> Array:
	return st.filter(func(s): return not s.out)


func start() -> void:
	_new_round()


func _new_round() -> void:
	round_i += 1
	phase = "live"
	phase_t = 0.0
	fuse_total = maxf(4.5, 12.5 - round_i * 1.6) + randf_range(0.0, 3.0)
	fuse = fuse_total
	holder = _alive().pick_random()
	holder.hold_t = -0.6
	holder.bot_t = randf_range(0.6, 1.6)
	flying = false
	bomb.visible = true
	Audio.play("go")
	Net.vibrate(holder.p.pid, [80, 40, 80])


## kire dobna most a játékos
func _aim_of(s: Dictionary):
	var others: Array = _alive().filter(func(o): return o != s)
	if others.is_empty():
		return null
	var dir := Vector2(s.ix, s.iy)
	if dir.length() < 0.3:
		if s.aim != null and others.has(s.aim):
			return s.aim
		# alapból a legtávolabbi (nagyjából szemközti) játékos
		var far = others[0]
		for o in others:
			if (o.pos - s.pos).length() > (far.pos - s.pos).length():
				far = o
		return far
	dir = dir.normalized()
	var best = null
	var best_d := -9.0
	for o in others:
		var v := Vector2(o.pos.x - s.pos.x, o.pos.z - s.pos.z).normalized()
		var d := v.dot(dir)
		if d > best_d:
			best_d = d
			best = o
	return best


func input(p, msg: Dictionary) -> void:
	var s := _get(p)
	if s.is_empty() or s.out:
		return
	if msg.get("t") == "stick":
		s.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)
		s.iy = clampf(float(msg.get("y", 0)), -1.0, 1.0)
	elif msg.get("t") == "btn":
		if phase != "live" or flying or not is_same(holder, s) or s.hold_t < HOLD_MIN:
			return
		var tgt = _aim_of(s)
		if tgt == null:
			return
		from_pos = _hold_pos(s)
		holder = tgt
		flying = true
		fly_t = 0.0
		tgt.hold_t = 0.0
		tgt.bot_t = randf_range(0.35, 1.5)
		Audio.play("whoosh")
		(s.m as Chars3D.CharModel).land = 0.6
		Net.vibrate(tgt.p.pid, [60, 30, 60])


func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.out or phase != "live" or flying or not is_same(holder, s):
		return
	s.bot_t -= dt
	if s.bot_t > 0 and fuse > 0.5:
		return
	var others: Array = _alive().filter(func(o): return o != s and (teams.is_empty() or team_of(o.p) != team_of(p)))
	if others.is_empty():
		others = _alive().filter(func(o): return o != s)
	if others.is_empty():
		return
	var tgt: Dictionary = others.pick_random()
	var v := Vector2(tgt.pos.x - s.pos.x, tgt.pos.z - s.pos.z).normalized()
	s.ix = v.x
	s.iy = v.y
	input(p, {"t": "btn"})
	s.ix = 0.0
	s.iy = 0.0
	s.aim = null


func _hold_pos(s: Dictionary) -> Vector3:
	return s.pos + Vector3(0, 2.25, 0)


func update(dt: float) -> void:
	phase_t += dt
	if phase == "live":
		fuse -= dt
		for s in st:
			s.hold_t += dt
			if not s.out:
				s.aim = _aim_of(s)
		if flying:
			fly_t += dt
			if fly_t >= FLY:
				flying = false
				Audio.play("land")
				(holder.m as Chars3D.CharModel).land = 0.8
		tick_t -= dt
		if tick_t <= 0:
			tick_t = lerpf(0.11, 0.6, clampf(fuse / fuse_total, 0.0, 1.0))
			Audio.play("tick", lerpf(1.7, 1.0, clampf(fuse / fuse_total, 0.0, 1.0)))
		if fuse <= 0 and not flying:
			_explode()
	elif phase == "boom" and phase_t >= 1.7 and end_at < 0:
		_new_round()
	if end_at < 0 and t >= LIMIT:
		end_at = t
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)


func _explode() -> void:
	var s: Dictionary = holder
	s.out = true
	s.out_t = 0.0
	elim.append(s)
	phase = "boom"
	phase_t = 0.0
	bomb.visible = false
	Audio.play("boom")
	Net.vibrate(s.p.pid, [300, 80, 300])
	var q := screen(_hold_pos(s))
	Main.I.burst(q.x, q.y, {"n": 70, "colors": ["#ff922b", "#ffd43b", "#ff4d6d", "#495057"], "speed": 520})
	Main.I.float_text(q.x, q.y - 30, "BUMM!", Color("#ffd43b"), 54)
	Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "💥", "title": "Felrobbantál!", "text": "%d. kiesett" % elim.size()})
	for o in _alive():
		(o.m as Chars3D.CharModel).emote("happy")
	var left := _alive()
	var team_alive := {}
	for o in left:
		team_alive[team_of(o.p)] = true
	if left.size() <= 1 or (teams.size() == 2 and team_alive.size() <= 1):
		end_at = t + 1.4


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var pos: Vector3 = s.pos
		var yaw: float = s.yaw
		if s.out:
			s.out_t += dt
			var k: float = s.out_t
			pos += Vector3(sin(s.yaw + PI) * k * 9.0, k * 9.0 - k * k * 7.0, cos(s.yaw + PI) * k * 9.0)
			yaw += k * 12.0
			m.rotation.x = k * 7.0
			m.visible = k < 2.5
		elif s.aim != null and is_same(holder, s) and not flying:
			var tp: Vector3 = s.aim.pos
			yaw = atan2(tp.x - pos.x, tp.z - pos.z)
		m.position = pos + Vector3(0, a.y, 0)
		m.rotation.y = yaw + a.spin
		(s.disc as MeshInstance3D).visible = not s.out
	if bomb.visible and holder != null:
		var k: float = clampf(1.0 - fuse / fuse_total, 0.0, 1.0)
		var hp := _hold_pos(holder)
		if flying:
			var f: float = clampf(fly_t / FLY, 0.0, 1.0)
			hp = from_pos.lerp(hp, f) + Vector3(0, sin(f * PI) * 2.2, 0)
			bomb.rotation.x += dt * 14.0
		else:
			bomb.rotation.x = 0.0
		var pulse := 1.0 + sin(Main.I.time * lerpf(6.0, 34.0, k)) * lerpf(0.04, 0.16, k)
		bomb.position = hp
		bomb.scale = Vector3.ONE * pulse
		light.light_energy = 1.5 + k * 5.0 + sin(Main.I.time * 30.0) * k * 2.0


func ranking() -> Array:
	var out: Array = []
	for s in st:
		var ei := elim.find(s)
		out.append({"pid": s.p.pid, "score": float(ei) if s.out else 1000.0, "label": "%d. kiesett" % (ei + 1) if s.out else "Túlélte! 💪"})
	out.sort_custom(func(a, c): return a.score > c.score)
	return out


func draw(c: CanvasItem) -> void:
	# célzónyíl a bomba gazdájától
	if phase == "live" and holder != null and not flying and holder.aim != null:
		var a := screen(holder.pos + Vector3(0, 0.3, 0))
		var b := screen(holder.aim.pos + Vector3(0, 0.3, 0))
		var d := b - a
		if d.length() > 60:
			var n := d.normalized()
			var a2 := a + n * 36
			var b2 := b - n * 44
			var col: Color = holder.p.color.lightened(0.3)
			col.a = 0.85
			c.draw_line(a2, b2, Color(0, 0, 0, 0.5), 12, true)
			c.draw_line(a2, b2, col, 6, true)
			var side := Vector2(-n.y, n.x)
			c.draw_colored_polygon(PackedVector2Array([b2 + n * 22, b2 + side * 15, b2 - side * 15]), col)
	for s in st:
		if s.out:
			continue
		var q := screen(s.pos + Vector3(0, -0.15, 0))
		var col := Color.WHITE
		var tix := team_of(s.p)
		if tix >= 0:
			col = MgFlow.TEAM_COLORS[tix].lightened(0.4)
		D.text(c, s.p.name, q.x, q.y + 26, {"size": 18, "stroke": Color.BLACK, "sw": 5, "maxw": 140, "color": col})
	D.text(c, "💣 %d. kör" % max(1, round_i), 30, 36, {"size": 28, "align": "left", "stroke": Color.BLACK, "sw": 6})
	D.text(c, "Talpon: %d / %d" % [_alive().size(), st.size()], 30, 72, {"size": 20, "align": "left", "stroke": Color.BLACK, "sw": 5, "color": Color("#ffe3e3")})
	if phase == "live" and holder != null and not flying:
		D.text(c, "%s kezében a bomba!" % holder.p.name, 640, 44, {"size": 30, "color": holder.p.color.lightened(0.45), "stroke": D.DARK, "sw": 8, "maxw": 700})
	elif phase == "boom" and not elim.is_empty():
		D.text(c, "💥 %s kiesett!" % elim[-1].p.name, 640, 44, {"size": 34, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 8, "maxw": 700})
