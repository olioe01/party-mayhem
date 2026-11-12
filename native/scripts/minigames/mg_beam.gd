extends Minigame
## Forgó gerenda (3D) – egy körbeforgó, tüskés farönk söpör végig a platformon.
## Ugorj át rajta időben! Aki eltalálódik, lerepül. Az utolsó talpon maradó nyer.

const LIMIT := 50.0
const RADIUS := 3.6
const BEAM_H := 0.55
const GRAV := 26.0
const JUMP_V := 8.6

var st: Array = []
var beams: Array = []          # [{node, angle, dir}]
var speed := 1.1
var out_order: Array = []
var end_at := -1.0
var next_flip := 12.0


func meta() -> Dictionary:
	return {"id": "beam", "name": "Forgó gerenda", "icon": "🪵", "color": "#a0703c", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Ugrálj, amíg bírod!",
		"desc": "Egy tüskés farönk forog körbe a platformon, és egyre gyorsul. Ugorj át rajta, amikor odaér hozzád! Később egy második rönk is megjelenik, és néha irányt váltanak. Az utolsó talpon maradó nyer.",
		"controls": "Koppints az UGRÁS gombra, amikor a rönk odaér hozzád. Ne ugorj túl korán!"}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "⬆️ UGRÁS!", "hint": "Ugorj át a rönkön!", "rapid": true}


func _ready() -> void:
	make_env("#2563eb", "#bae6fd", 0.8)
	make_camera(Vector3(0, 8.0, 9.0), Vector3(0, 0.3, 0.4), 48)
	make_sun(Vector3(-60, -35, 0), 1.3)
	# platform: fű a sziklán, a felhők fölött
	Chars3D.cyl(self, RADIUS + 1.2, RADIUS + 1.0, 0.5, Chars3D.mat("#7cc552"), 0, -0.25, 0, 48)
	Chars3D.cyl(self, RADIUS + 1.0, 0.6, 4.0, Chars3D.mat("#7c6f64", {"rough": 1.0}), 0, -2.5, 0, 14)
	Chars3D.cyl(self, 0.45, 0.55, 1.0, Chars3D.mat("#8b5e34"), 0, 0.5, 0, 16)
	var cm := Chars3D.mat("#ffffff", {"rough": 1.0})
	var rnd := BoardLayout.Seeded.new(9)
	for i in 16:
		var a := rnd.next() * TAU
		var d := 9.0 + rnd.next() * 10.0
		var c := Chars3D.sphere(self, 1.5 + rnd.next() * 1.5, cm, cos(a) * d, -5 - rnd.next() * 3, sin(a) * d - 4, 1.6, 0.5, 1.0)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beams.append(_make_beam(0.0))
	var n := players.size()
	for i in n:
		var p = players[i]
		var a := PI / 2 + float(i) / n * TAU + 0.4
		var m := player_model(p, 1.3)
		var disc := color_disc(p, 0.35)
		add_child(disc)
		st.append({"p": p, "a": a, "h": 0.0, "vy": 0.0, "out": false, "fly": 0.0, "m": m, "disc": disc, "bot_err": randf_range(-0.12, 0.12), "bot_skill": randf_range(0.7, 0.97)})
	_sync(0.0)


func _make_beam(angle: float) -> Dictionary:
	var pivot := Node3D.new()
	add_child(pivot)
	var log_m := Chars3D.mat("#8b5e34", {"rough": 0.9})
	var lg := Chars3D.cyl(pivot, 0.3, 0.3, RADIUS + 1.3, log_m, 0, BEAM_H, 0, 14, Vector3(0, 0, PI / 2))
	lg.position.x = (RADIUS + 1.3) / 2.0 + 0.4
	for k in 7:
		var x := 1.0 + k * 0.62
		Chars3D.cone(pivot, 0.09, 0.32, Chars3D.mat("#e5e7eb", {"metal": 0.6, "rough": 0.3}), x, BEAM_H + 0.38, 0, 6)
	Chars3D.cyl(pivot, 0.34, 0.34, 0.08, Chars3D.mat("#f2d18b"), RADIUS + 1.75, BEAM_H, 0, 14, Vector3(0, 0, PI / 2))
	return {"node": pivot, "angle": angle}


func _entry(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var s := _entry(p)
	if s.is_empty() or s.out or s.h > 0.01:
		return
	s.vy = JUMP_V
	s.h = 0.01
	Audio.play("jump")
	(s.m as Chars3D.CharModel).airborne = 1.0


func bot(p, _dt: float) -> void:
	var s := _entry(p)
	if s.out or s.h > 0.01:
		return
	for b in beams:
		var da := angle_difference(b.angle, s.a) * (1.0 if speed >= 0 else -1.0)
		var time_to: float = da / abs(speed) if da > 0 else INF
		if time_to < 0.2 + s.bot_err and time_to > 0.05:
			if randf() < s.bot_skill:
				input(p, {"t": "tap"})
			else:
				s.bot_err = randf_range(-0.15, 0.2)
			return


func update(dt: float) -> void:
	speed = sign(speed) * min(3.6, 1.1 + t * 0.055)
	if t > 18 and beams.size() == 1:
		beams.append(_make_beam(beams[0].angle + PI))
		Audio.play("whoosh")
	if t > next_flip:
		next_flip = t + randf_range(7, 12)
		speed = -speed
		Audio.play("select")
	for b in beams:
		b.angle = wrapf(b.angle + speed * dt, -PI, PI)
	for s in st:
		if s.out:
			s.fly += dt
			continue
		if s.h > 0:
			s.vy -= GRAV * dt
			s.h += s.vy * dt
			if s.h <= 0:
				s.h = 0.0
				s.vy = 0.0
				(s.m as Chars3D.CharModel).land = 1.0
				(s.m as Chars3D.CharModel).airborne = 0.0
		for b in beams:
			if abs(angle_difference(b.angle, s.a)) < 0.16 and s.h < BEAM_H + 0.25:
				s.out = true
				s.fly_dir = sign(speed)
				out_order.append(s)
				Audio.play("boom")
				Net.vibrate(s.p.pid, [200, 80, 200])
				var q := screen(_pos(s) + Vector3(0, 1, 0))
				Main.I.burst(q.x, q.y, {"n": 30, "colors": ["#ffd43b", "#ffffff", s.p.color_hex], "speed": 360})
				Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🪵", "title": "Eltalált a rönk!", "text": "%d. kiesett" % out_order.size()})
				break
	var alive := st.filter(func(x): return not x.out)
	var teams_left := {}
	for s in alive:
		teams_left[team_of(s.p)] = true
	var over := (st.size() > 1 and alive.size() <= 1) or alive.is_empty() or t >= LIMIT or (teams.size() == 2 and teams_left.size() <= 1)
	if end_at < 0 and over:
		end_at = t + 1.2
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _pos(s: Dictionary) -> Vector3:
	return Vector3(cos(s.a) * RADIUS, s.h, sin(s.a) * RADIUS)


func _sync(dt: float) -> void:
	for b in beams:
		(b.node as Node3D).rotation.y = -b.angle
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		var pos := _pos(s)
		if s.out:
			var k: float = s.fly
			var out_dir := Vector3(cos(s.a), 0, sin(s.a))
			pos += out_dir * k * 7.0 + Vector3(0, k * 6.0 - k * k * 9.0, 0)
			m.rotation.z += dt * 12.0
		m.position = pos + Vector3(0, a.y, 0)
		if not s.out:
			m.rotation.y = a.spin
		var disc: MeshInstance3D = s.disc
		disc.visible = not s.out
		disc.position = Vector3(cos(s.a) * RADIUS, 0.03, sin(s.a) * RADIUS)


func ranking() -> Array:
	var out: Array = []
	for s in st:
		var ei := out_order.find(s)
		out.append({"pid": s.p.pid, "score": float(ei) if s.out else 100.0, "label": ("%d. kiesett" % (ei + 1)) if s.out else "Túlélte! 💪"})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func draw(c: CanvasItem) -> void:
	for s in st:
		if s.out:
			continue
		var q := screen(_pos(s) + Vector3(0, 1.45, 0))
		var tix := team_of(s.p)
		D.text(c, s.p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 4, "maxw": 120, "color": MgFlow.TEAM_COLORS[tix].lightened(0.45) if tix >= 0 else Color.WHITE})
	var alive := st.filter(func(x): return not x.out).size()
	D.text(c, "🪵 Talpon: %d/%d" % [alive, st.size()], 30, 36, {"size": 26, "align": "left", "stroke": Color.BLACK, "sw": 5})
	D.text(c, "Sebesség: %d%%" % roundi(abs(speed) / 1.1 * 100), 30, 70, {"size": 18, "align": "left", "color": Color("#fde68a"), "stroke": Color.BLACK, "sw": 4})
	D.timer_hud(c, LIMIT - t, 1180, 40)
