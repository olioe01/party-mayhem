extends Minigame
## Rakétaverseny (3D) – gyors koppintás: minden koppintás tolóerő, aki elsőként éri el a Holdat, nyer.

const GOAL := 65
const LIMIT := 22.0
const TOP := 12.5

var r: Array = []
var place := 0
var smoke: Array = []


func meta() -> Dictionary:
	return {"id": "rocket", "name": "Rakétaverseny", "icon": "🚀", "color": "#ff922b", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Gyors ujjak versenye",
		"desc": "Mindenki a saját rakétáján ül. Minden koppintás egy kis tolóerő – aki elsőként éri el a Holdat, nyer!",
		"controls": "Koppints a nagy gombra olyan gyorsan, ahogy csak tudsz! (Több ujjal is lehet.)"}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "🔥 TOLÁS!", "hint": "Koppints gyorsan!", "rapid": true}


func _ready() -> void:
	make_env("#05061a", "#3b1f6b", 0.5)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070720")
	make_camera(Vector3(0, 6.5, 21), Vector3(0, 6.2, 0), 46)
	make_sun(Vector3(-35, -25, 0), 1.3)
	# csillagok
	var star_m := Chars3D.mat("#ffffff", {"unshaded": true})
	var rnd := BoardLayout.Seeded.new(5)
	for i in 160:
		var s := MeshInstance3D.new()
		s.mesh = Chars3D._sphere_mesh(0.04 + rnd.next() * 0.05)
		s.material_override = star_m
		s.position = Vector3(-30 + rnd.next() * 60, -4 + rnd.next() * 30, -18 - rnd.next() * 10)
		add_child(s)
	# Hold
	var moon := MeshInstance3D.new()
	moon.mesh = Chars3D._sphere_mesh(7.0)
	moon.material_override = Chars3D.mat("#fff3c4", {"rough": 0.9, "emit": "#ffe8a3", "emit_e": 0.35})
	moon.position = Vector3(0, TOP + 8.6, -6)
	add_child(moon)
	for c in [[-2.5, 1.0, 1.0], [2.0, 2.2, 0.7], [0.5, -0.8, 0.5], [-4.0, -1.5, 0.6]]:
		var cr := MeshInstance3D.new()
		cr.mesh = Chars3D._sphere_mesh(c[2])
		cr.material_override = Chars3D.mat("#d9c27a", {"rough": 1.0})
		cr.position = moon.position + Vector3(c[0], c[1] - 4.0, 6.6)
		cr.scale = Vector3(1, 1, 0.3)
		add_child(cr)
	# célvonal
	var line := Chars3D.box(self, 40, 0.15, 0.1, Chars3D.mat("#ffd43b", {"emit": "#ffd43b", "emit_e": 1.5}), Vector3(0, TOP + 1.6, 0))
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# talaj
	Chars3D.box(self, 60, 1, 10, Chars3D.mat("#1e293b"), Vector3(0, -0.5, 0))
	var n := players.size()
	var lane: float = min(3.6, 26.0 / n)
	for i in n:
		var p = players[i]
		var x := (i - (n - 1) / 2.0) * lane
		Chars3D.box(self, 1.6, 0.25, 1.6, Chars3D.mat("#475569"), Vector3(x, 0.12, 0))
		var g := _rocket(p)
		g.position = Vector3(x, 0.25, 0)
		add_child(g)
		r.append({"p": p, "x": x, "prog": 0, "disp": 0.0, "fin": -1.0, "flame": 0.0, "bot_t": 0.0, "g": g, "place": 0})


func _rocket(p) -> Node3D:
	var g := Node3D.new()
	var white := Chars3D.mat("#f1f5f9", {"rough": 0.3, "metal": 0.3})
	var col := Chars3D.mat(p.color_hex, {"rough": 0.35})
	Chars3D.cyl(g, 0.55, 0.6, 2.0, white, 0, 1.3, 0, 20)
	Chars3D.cone(g, 0.55, 1.0, col, 0, 2.8, 0, 20)
	Chars3D.cyl(g, 0.62, 0.62, 0.2, col, 0, 0.35, 0, 20)
	for i in 3:
		var a := TAU * i / 3
		var fin := Chars3D.box(g, 0.08, 0.8, 0.6, col, Vector3(cos(a) * 0.6, 0.6, sin(a) * 0.6), Vector3(0, -a, 0))
		fin.rotation_order = EULER_ORDER_YXZ
	Chars3D.cyl(g, 0.3, 0.3, 0.05, Chars3D.mat("#bfe3ff", {"rough": 0.1, "metal": 0.4}), 0, 1.6, 0.56, 16, Vector3(PI / 2, 0, 0))
	var flame := Node3D.new()
	flame.name = "flame"
	g.add_child(flame)
	Chars3D.cone(flame, 0.45, 1.4, Chars3D.mat("#ff922b", {"emit": "#ff6a00", "emit_e": 3.0, "unshaded": true}), 0, -0.55, 0, 12, Vector3(PI, 0, 0))
	Chars3D.cone(flame, 0.25, 0.9, Chars3D.mat("#ffe066", {"emit": "#ffd43b", "emit_e": 4.0, "unshaded": true}), 0, -0.35, 0, 12, Vector3(PI, 0, 0))
	var m := Chars3D.build(p.char_id)
	m.scale = Vector3.ONE * 0.75
	m.position = Vector3(0, 3.05, 0)
	m.name = "rider"
	g.add_child(m)
	return g


func _entry(p) -> Dictionary:
	for e in r:
		if e.p == p:
			return e
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var e := _entry(p)
	if e.is_empty() or e.fin >= 0:
		return
	e.prog += 1
	e.flame = 1.0
	if e.prog % 8 == 0:
		Audio.play("tick")
	if e.prog >= GOAL:
		e.fin = t
		place += 1
		e.place = place
		Audio.play("win")
		Net.vibrate(p.pid, [100, 50, 200])
		var q := screen(e.g.position + Vector3(0, 3, 0))
		Main.I.burst(q.x, q.y, {"n": 50, "colors": [p.color_hex, "#ffffff", "#ffd43b"], "speed": 450})
		(e.g.get_node("rider") as Chars3D.CharModel).emote("cheer")
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🌕", "title": "Célba értél! (%d.)" % place, "text": "%.2f másodperc" % e.fin})


func bot(p, dt: float) -> void:
	var e := _entry(p)
	e.bot_t -= dt
	if e.bot_t <= 0:
		input(p, {"t": "tap"})
		e.bot_t = 1.0 / randf_range(4.5, 7.5)


func update(dt: float) -> void:
	var all_done := true
	for e in r:
		if e.fin < 0:
			all_done = false
	if all_done or t >= LIMIT:
		finished = true
	idle(dt)


func idle(dt: float) -> void:
	for e in r:
		e.disp += (e.prog - e.disp) * min(1.0, dt * 10.0)
		e.flame = max(0.0, e.flame - dt * 3.0)
		var y: float = 0.25 + min(e.disp, GOAL) / float(GOAL) * TOP
		var g: Node3D = e.g
		var shake := sin(t * 50.0) * 0.04 if (e.flame > 0.3 and e.fin < 0) else 0.0
		g.position = Vector3(e.x + shake, y, 0)
		g.rotation.z = sin(t * 3.0 + e.x) * 0.03
		var f: float = 0.6 if e.fin >= 0 else e.flame
		var fl: Node3D = g.get_node("flame")
		fl.visible = f > 0.05
		fl.scale = Vector3(1, 0.4 + f * 1.1 + sin(t * 40.0) * 0.08, 1)
		(g.get_node("rider") as Chars3D.CharModel).animate(dt)
		if e.flame > 0.5 and randf() < 0.35:
			_puff(g.position + Vector3(randf_range(-0.3, 0.3), -0.6, 0))
	for s in smoke.duplicate():
		s.life -= dt
		if s.life <= 0:
			s.node.queue_free()
			smoke.erase(s)
			continue
		s.node.position.y -= dt * 0.6
		s.node.scale = Vector3.ONE * (1.6 - s.life) * 0.9
	# a kamera finoman követi a vezetőt
	var lead := 0.0
	for e in r:
		lead = max(lead, e.disp / GOAL)
	if cam:
		cam.position.y = lerpf(cam.position.y, 6.5 + lead * 1.5, dt * 2.0)


func _puff(pos: Vector3) -> void:
	var s := MeshInstance3D.new()
	s.mesh = Chars3D._sphere_mesh(0.35)
	s.material_override = Chars3D.mat("#cbd5e1", {"alpha": 0.6, "rough": 1.0})
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = pos
	add_child(s)
	smoke.append({"node": s, "life": 1.0})


func ranking() -> Array:
	var out: Array = []
	for e in r:
		out.append({"pid": e.p.pid, "score": (1000.0 - e.fin) if e.fin >= 0 else float(e.prog),
			"label": ("%.2f mp" % e.fin) if e.fin >= 0 else "%d%%" % roundi(float(e.prog) / GOAL * 100)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func draw(c: CanvasItem) -> void:
	D.timer_hud(c, LIMIT - t, 1180, 40)
	D.text(c, "🌕 CÉL", 80, 46, {"size": 26, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 6})
	for e in r:
		var q := screen(Vector3(e.x, -0.2, 0.8))
		D.text(c, e.p.name, q.x, q.y + 6, {"size": 18, "maxw": 130, "stroke": D.DARK, "sw": 5})
		var lab: String = ("🏁 %d." % e.place) if e.fin >= 0 else "%d%%" % roundi(min(e.prog, GOAL) / float(GOAL) * 100)
		D.text(c, lab, q.x, q.y + 30, {"size": 18, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 5})
		var tix := team_of(e.p)
		if tix >= 0:
			D.ring(c, q.x, q.y + 6, 14, MgFlow.TEAM_COLORS[tix], 3)
