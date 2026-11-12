extends Minigame
## Lökdösődő aréna (3D) – lökd le a többieket a láva fölötti, zsugorodó platformról.
## A fizika a régi 2D (px) térben fut, a 3D csak megjelenítés (1 egység = 40 px).

const LIMIT := 45.0
const BALL := 27.0
const ACC := 1300.0
const MAXV := 430.0
const DASH := 720.0

var R := 300.0
var elim: Array = []
var last_hit := 0.0
var b: Array = []
var end_at := -1.0
var platform: MeshInstance3D
var rim: MeshInstance3D
var lava_mat: ShaderMaterial


func meta() -> Dictionary:
	return {"id": "arena", "name": "Lökdösődő aréna", "icon": "💥", "color": "#ff4d6d", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Az utolsó talpon maradó nyer",
		"desc": "Egy láva fölötti, folyamatosan zsugorodó platformon álltok. Lökd le a többieket, de vigyázz, nehogy te ess le!",
		"controls": "Bal oldalon a joystickkal mozogsz, jobb oldalon a LÖKÉS gombbal gyorsan előrevetődsz."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "btn": "💥 LÖKÉS"}


func _ready() -> void:
	make_env("#3b0a0a", "#ff7b29", 0.5)
	make_camera(Vector3(0, 11.5, 9.8), Vector3(0, 0, 0.9), 50)
	make_sun(Vector3(-60, -20, 0), 1.1, "#ffe8cc")
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff6a00")
	glow.light_energy = 3.0
	glow.omni_range = 30
	glow.position = Vector3(0, -2, 0)
	add_child(glow)
	# láva
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform float time_s;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void fragment() {
	vec2 uv = UV * 18.0;
	float n = noise(uv + vec2(time_s * 0.3, time_s * 0.2)) * 0.6 + noise(uv * 2.3 - vec2(time_s * 0.4, 0.0)) * 0.4;
	vec3 dark = vec3(0.45, 0.05, 0.0);
	vec3 hot = vec3(1.0, 0.55, 0.05);
	vec3 white = vec3(1.0, 0.9, 0.4);
	vec3 col = mix(dark, hot, smoothstep(0.35, 0.7, n));
	col = mix(col, white, smoothstep(0.78, 0.92, n));
	ALBEDO = col * 0.95;
}
"""
	lava_mat = ShaderMaterial.new()
	lava_mat.shader = sh
	var lava := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	lava.mesh = pm
	lava.material_override = lava_mat
	lava.position.y = -1.6
	add_child(lava)
	# platform
	platform = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 1.0
	cy.bottom_radius = 0.85
	cy.height = 1.0
	cy.radial_segments = 48
	platform.mesh = cy
	platform.material_override = Chars3D.mat("#6b7a90", {"rough": 0.55, "metal": 0.1})
	add_child(platform)
	rim = MeshInstance3D.new()
	rim.mesh = Chars3D.torus(1.0, 0.025)
	rim.material_override = Chars3D.mat("#facc15", {"emit": "#facc15", "emit_e": 1.5})
	add_child(rim)
	var pillar := Chars3D.cyl(self, 1.5, 2.2, 3.0, Chars3D.mat("#334155", {"rough": 0.9}), 0, -2.5, 0, 16)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := players.size()
	for i in n:
		var p = players[i]
		var a := float(i) / n * TAU - PI / 2
		var m := player_model(p, 1.5)
		var disc := color_disc(p, 0.5)
		add_child(disc)
		b.append({"p": p, "x": 640 + cos(a) * 180, "y": 370 + sin(a) * 180, "vx": 0.0, "vy": 0.0, "ix": 0.0, "iy": 0.0,
			"cd": 0.0, "dash_t": 0.0, "out": false, "fall_t": 0.0, "ai_t": 0.0, "m": m, "disc": disc, "yaw": 0.0})
	_sync(0.0)


func _ball(p) -> Dictionary:
	for x in b:
		if x.p == p:
			return x
	return {}


func input(p, msg: Dictionary) -> void:
	var o := _ball(p)
	if o.is_empty() or o.out:
		return
	if msg.get("t") == "stick":
		o.ix = clamp(float(msg.get("x", 0)), -1.0, 1.0)
		o.iy = clamp(float(msg.get("y", 0)), -1.0, 1.0)
	elif msg.get("t") == "btn" and o.cd <= 0:
		var dx: float = o.ix
		var dy: float = o.iy
		if Vector2(dx, dy).length() < 0.2:
			dx = o.vx
			dy = o.vy
		var l: float = max(0.001, Vector2(dx, dy).length())
		o.vx += dx / l * DASH
		o.vy += dy / l * DASH
		o.cd = 1.3
		o.dash_t = 0.25
		Audio.play("whoosh")
		(o.m as Chars3D.CharModel).emote("happy")


func bot(p, dt: float) -> void:
	var o := _ball(p)
	if o.out:
		return
	o.ai_t -= dt
	if o.ai_t > 0:
		return
	o.ai_t = 0.12
	var others: Array = b.filter(func(x): return x != o and not x.out and (teams.is_empty() or team_of(x.p) != team_of(p)))
	var d0 := Vector2(o.x - 640, o.y - 370).length()
	var tx := 640.0
	var ty := 370.0
	if others.size() and d0 < R * 0.55:
		others.sort_custom(func(a, c): return Vector2(a.x - o.x, a.y - o.y).length() < Vector2(c.x - o.x, c.y - o.y).length())
		var tgt: Dictionary = others[0]
		tx = tgt.x + (tgt.x - 640) * 0.2
		ty = tgt.y + (tgt.y - 370) * 0.2
		if Vector2(tgt.x - o.x, tgt.y - o.y).length() < 150 and o.cd <= 0 and randf() < 0.35:
			var v := Vector2(tgt.x - o.x, tgt.y - o.y).normalized()
			o.ix = v.x
			o.iy = v.y
			input(p, {"t": "btn"})
			return
	var dv := Vector2(tx - o.x, ty - o.y)
	var l: float = max(0.001, dv.length())
	var k: float = min(1.0, l / 60.0)
	o.ix = dv.x / l * k + randf_range(-0.15, 0.15)
	o.iy = dv.y / l * k + randf_range(-0.15, 0.15)


func update(dt: float) -> void:
	if t > 5:
		R = max(125.0, 300.0 - (t - 5) * 5.2)
	for o in b:
		if o.out:
			o.fall_t += dt
			continue
		o.cd = max(0.0, o.cd - dt)
		o.dash_t = max(0.0, o.dash_t - dt)
		o.vx += o.ix * ACC * dt
		o.vy += o.iy * ACC * dt
		var fr := pow(0.12, dt)
		o.vx *= fr
		o.vy *= fr
		var sp := Vector2(o.vx, o.vy).length()
		var cap: float = 1000.0 if o.dash_t > 0 else max(MAXV, sp * 0.97)
		if sp > cap:
			o.vx *= cap / sp
			o.vy *= cap / sp
		o.x += o.vx * dt
		o.y += o.vy * dt
	var alive: Array = b.filter(func(x): return not x.out)
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a: Dictionary = alive[i]
			var c: Dictionary = alive[j]
			var dx: float = a.x - c.x
			var dy: float = a.y - c.y
			var d := Vector2(dx, dy).length()
			if d >= BALL * 2 or d == 0:
				continue
			var nx := dx / d
			var ny := dy / d
			var ov := BALL * 2 - d
			a.x += nx * ov / 2
			a.y += ny * ov / 2
			c.x -= nx * ov / 2
			c.y -= ny * ov / 2
			var rel: float = (a.vx - c.vx) * nx + (a.vy - c.vy) * ny
			if rel < 0:
				var j2 := -(1.9) * rel / 2 + 90
				a.vx += nx * j2
				a.vy += ny * j2
				c.vx -= nx * j2
				c.vy -= ny * j2
				if t - last_hit > 0.08:
					last_hit = t
					Audio.play("hit")
					var q := screen(_w((a.x + c.x) / 2, (a.y + c.y) / 2, 0.6))
					Main.I.burst(q.x, q.y, {"n": 8, "colors": ["#ffffff", "#ffe066"], "speed": 220, "gravity": 0, "life": 0.4})
	for o in alive:
		if Vector2(o.x - 640, o.y - 370).length() > R + BALL * 0.3:
			o.out = true
			elim.append(o)
			Audio.play("splash")
			Net.vibrate(o.p.pid, [200, 80, 200])
			var q := screen(_w(o.x, o.y, 0))
			Main.I.burst(q.x, q.y, {"n": 30, "colors": ["#ff922b", "#ffd43b", "#ff4d6d"], "speed": 300})
			Net.set_ctrl(o.p.pid, {"mode": "wait", "icon": "🔥", "title": "Leestél!", "text": "%d. kiesett" % elim.size()})
	var left := b.filter(func(x): return not x.out).size()
	var team_alive := {}
	for o in b:
		if not o.out:
			team_alive[team_of(o.p)] = true
	var teams_over := teams.size() == 2 and team_alive.size() <= 1
	if end_at < 0 and ((b.size() > 1 and left <= 1) or left == 0 or t >= LIMIT or teams_over):
		end_at = t + 1.0
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _w(x: float, y: float, h: float) -> Vector3:
	return Vector3((x - 640) / 40.0, h, (y - 370) / 40.0)


func _sync(dt: float) -> void:
	lava_mat.set_shader_parameter("time_s", Main.I.time)
	var rr := R / 40.0
	platform.scale = Vector3(rr, 1, rr)
	platform.position.y = -0.5
	rim.scale = Vector3(rr, 1, rr)
	rim.position.y = 0.0
	(rim.material_override as StandardMaterial3D).albedo_color = Color("#ff4d6d") if R < 180 else Color("#facc15")
	for o in b:
		var m: Chars3D.CharModel = o.m
		var a := m.animate(dt)
		var pos := _w(o.x, o.y, 0)
		if o.out:
			var k: float = min(1.0, o.fall_t / 0.9)
			pos.y = -k * k * 3.0
			m.rotation.x = k * 1.5
		var mv := Vector2(o.vx, o.vy)
		if mv.length() > 30:
			o.yaw = lerp_angle(o.yaw, atan2(mv.x, mv.y), min(1.0, dt * 10.0))
		m.position = pos + Vector3(0, a.y, 0)
		m.rotation.y = o.yaw + a.spin
		var disc: MeshInstance3D = o.disc
		disc.visible = not o.out
		disc.position = pos + Vector3(0, 0.03, 0)
		disc.scale = Vector3.ONE * (1.25 if o.cd <= 0 else 1.0)


func ranking() -> Array:
	var out: Array = []
	for o in b:
		var d := Vector2(o.x - 640, o.y - 370).length()
		var ei := elim.find(o)
		out.append({"pid": o.p.pid, "score": float(ei) if o.out else 1000.0 + roundi(R - d), "label": "%d. kiesett" % (ei + 1) if o.out else "Túlélte! 💪"})
	out.sort_custom(func(a, c): return a.score > c.score)
	return out


func draw(c: CanvasItem) -> void:
	for o in b:
		if o.out:
			continue
		var q := screen(_w(o.x, o.y, 1.6))
		var col := Color.WHITE
		var tix := team_of(o.p)
		if tix >= 0:
			col = MgFlow.TEAM_COLORS[tix].lightened(0.4)
		D.text(c, o.p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 4, "maxw": 120, "color": col})
		if o.cd <= 0:
			D.text(c, "💥", q.x, q.y - 22, {"size": 16})
	var alive := b.filter(func(x): return not x.out).size()
	D.text(c, "🔥 Talpon: %d/%d" % [alive, b.size()], 30, 36, {"size": 26, "align": "left", "stroke": Color.BLACK, "sw": 5})
	D.text(c, "💥 a név fölött = kész a lökés", 30, 70, {"size": 16, "align": "left", "color": Color("#fecaca")})
	D.timer_hud(c, LIMIT - t, 1180, 40)
