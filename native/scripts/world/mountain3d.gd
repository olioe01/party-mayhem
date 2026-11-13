class_name Mountain3D
extends Node3D
## 3D hegy a hegymászós játékmódhoz: kúp alakú hegy, körbefutó párkány-út, mezők, akadályok,
## díszletek, bábuk és a hegy körül keringő kamera.

const ML = preload("res://scripts/world/mountain_layout.gd")
const TYPES := {
	"N": {"color": "#e2e8f0", "icon": "", "emoji": false},
	"T": {"color": "#10b981", "icon": "🏁", "emoji": true},
	"P": {"color": "#ef4444", "icon": "−", "emoji": false},
	"F": {"color": "#22c55e", "icon": "+", "emoji": false},
	"X": {"color": "#38bdf8", "icon": "❄️", "emoji": true},
	"G": {"color": "#f59e0b", "icon": "🚧", "emoji": true},
	"W": {"color": "#ffd43b", "icon": "🏆", "emoji": true},
}
const ZOOMS := {
	"mid": {"d": 15.0, "h": 7.5},
	"near": {"d": 10.5, "h": 5.0},
	"close": {"d": 7.2, "h": 3.4},
}
const PAWN_SCALE := 0.95

static var instance: Mountain3D = null

var layout: Dictionary
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var pawns := {}          # pid -> {group, model, ring, char_id, yaw, target_yaw, last, still, prev_h}
var tiles := {}          # mező -> Node3D
var gates := {}          # mező -> {root, kind, bricks, extra, label, open, ...}
var debris: Array = []   # szétrepülő faldarabok: {n, v, w, age}
var wind: Node3D = null
var wind_power := 0.0
var marker: Node3D
var animated: Array = []
var t := 0.0
var shake := 0.0

var cam_mode := "overview"   # overview | follow | point | manual
var cam_pid := ""
var cam_point := Vector3.ZERO
var cam_zoom := "near"
var cam_speed := 3.0
var cam_ang := 0.0           # a kamera szöge a hegy körül
var cam_rad := 38.0
var cam_y := 15.0
var cam_look_pos := Vector3(0, 7.5, 0)
var orbit := 0.0
var cam_side := 0.16      # ennyivel néz előre a menetirányba (negatív: hátulról mutatja a jelenetet)


static func get_for(l: Dictionary) -> Mountain3D:
	if instance and is_instance_valid(instance) and instance.layout.get("seed") == l.get("seed"):
		instance.layout = l      # jelenetváltáskor az állapot új szótárba töltődik vissza
		return instance
	if instance and is_instance_valid(instance):
		instance.queue_free()
	instance = Mountain3D.new()
	instance.build(l)
	return instance


static func smat(hex: String, o := {}) -> StandardMaterial3D:
	var o2 := o.duplicate()
	if not o2.has("rough"):
		o2["rough"] = 0.85
	return Chars3D.mat(hex, o2)


func build(l: Dictionary) -> void:
	layout = l
	name = "Mountain3D"
	_env()
	camera = Camera3D.new()
	camera.fov = 40
	camera.near = 0.5
	camera.far = 300
	add_child(camera)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 90.0
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)
	_cloud_sea()
	_ground()
	_body()
	_path()
	_tiles()
	_gates()
	_summit()
	_deco()
	_cloud_ring()
	_marker()
	_birds()


func _env() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2f7fd6")
	sm.sky_horizon_color = Color("#d6ecff")
	sm.ground_bottom_color = Color("#9ccdf5")
	sm.ground_horizon_color = Color("#d6ecff")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color("#d6ecff")
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.06


func activate() -> void:
	Main.I.world_env.environment = env
	camera.make_current()


# ------------------------------------------------------------------ táj
func _cloud_sea() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float time_s = 0.0;
void fragment() {
	vec2 uv = UV * 6.0;
	float n1 = texture(noise_tex, uv * 0.6 + vec2(time_s * 0.004, time_s * 0.002)).r;
	float n2 = texture(noise_tex, uv * 1.3 - vec2(time_s * 0.006, 0.0)).r;
	float c = smoothstep(0.38, 0.75, n1 * 0.7 + n2 * 0.45);
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = mix(vec3(0.55, 0.76, 0.98), vec3(1.0), c * 0.9);
	ALBEDO = mix(ALBEDO, vec3(0.84, 0.93, 1.0), smoothstep(0.35, 1.0, d));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 512
	nt.height = 512
	var fn := FastNoiseLite.new()
	fn.frequency = 0.008
	fn.fractal_octaves = 4
	nt.noise = fn
	m.set_shader_parameter("noise_tex", nt)
	var pm := PlaneMesh.new()
	pm.size = Vector2(360, 360)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(0, -18, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	animated.append(func(tt): m.set_shader_parameter("time_s", tt))


func _ground() -> void:
	var r := ML.RB + 6.0
	Chars3D.cyl(self, r, r, 0.4, smat("#7cc552"), 0, -0.2, 0, 64)
	Chars3D.cyl(self, r * 1.005, r * 0.94, 0.9, smat("#8b5e34"), 0, -0.85, 0, 64)
	var rock := Chars3D.cyl(self, r * 0.94, 1.2, 11.0, smat("#7c6f64", {"rough": 0.95}), 0, -6.8, 0, 18)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rnd := BoardLayout.Seeded.new(41)
	var tuft := smat("#7cc552")
	for i in 40:
		var a := TAU * i / 40 + rnd.next() * 0.1
		var s := Chars3D.sphere(self, 0.4, tuft, sin(a) * r * 0.995, -0.05, cos(a) * r * 0.995, 1.5, 0.5, 1.1)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 14:
		var a := rnd.next() * TAU
		var rr := r * (0.5 + rnd.next() * 0.4)
		var bm := Chars3D.box(self, 1.0, 1.0, 1.0, smat("#7c6f64", {"rough": 0.95}), Vector3(sin(a) * rr, -2.0 - rnd.next() * 5.0, cos(a) * rr),
			Vector3(rnd.next() * 3, rnd.next() * 3, rnd.next() * 3))
		bm.scale = Vector3.ONE * (0.8 + rnd.next() * 1.4)


## A hegy teste: három színzóna (fű, szikla, hó), mindegyik csonkakúp.
func _body() -> void:
	var zones := [[-0.6, 4.6, "#5f9f4c"], [4.6, 7.4, "#7f8a6a"], [7.4, 10.6, "#8f857b"], [10.6, 12.2, "#b9b7b6"], [12.2, ML.H, "#f4f7fb"]]
	for z in zones:
		var cy := CylinderMesh.new()
		cy.bottom_radius = ML.wall_r(z[0])
		cy.top_radius = ML.wall_r(z[1])
		cy.height = z[1] - z[0]
		cy.radial_segments = 56
		cy.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cy
		mi.material_override = smat(z[2], {"rough": 0.95})
		mi.position.y = (z[0] + z[1]) / 2.0
		add_child(mi)
	# kiálló sziklák és hófoltok a falon, az út két menete között
	var rnd := BoardLayout.Seeded.new(layout.get("seed", 5) & 0xffff)
	for i in 70:
		var s := 2.0 + rnd.next() * 74.0
		var p := ML.polar(s)
		var gap := _loop_rise(s)
		var y := p.z + gap * (0.3 + rnd.next() * 0.45)
		if y > ML.H - 0.6:
			continue
		var rr := ML.wall_r(y) + 0.05
		var snowy := y > 11.0
		var col := "#f4f7fb" if snowy else ("#857b72" if y > 4.4 else "#6f7f5a")
		var sc := 0.5 + rnd.next() * 0.9
		var bm := Chars3D.box(self, sc, sc * (0.6 + rnd.next() * 0.6), sc, smat(col, {"rough": 1.0}),
			Vector3(sin(p.y) * rr, y, cos(p.y) * rr), Vector3(rnd.next() * 3, rnd.next() * 3, rnd.next() * 3))
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mennyit emelkedik az út egy teljes kör alatt az s pont környékén.
func _loop_rise(s: float) -> float:
	var p := ML.polar(s)
	return (TAU * p.x / ML.SPACING) / (ML.SPIRAL_N - 1) * ML.H


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	# a Godotban az óramutató szerinti körüljárás az előlap
	var n := (c - a).cross(b - a)
	var nn := want.normalized()
	if n.dot(want) < 0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(nn)
		st.add_vertex(v)


func _path() -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var per := 5
	var total := (ML.SPIRAL_N - 1) * per
	var prev := []
	for i in range(-per, total + 1):
		var s := float(i) / per
		var pp := ML.polar(max(s, 0.0))
		# a rajt előtt egy rövid ráfutó szakasz a földön
		var ang: float = pp.y + (min(s, 0.0) * ML.SPACING / ML.RB)
		var rad := Vector3(sin(ang), 0, cos(ang))
		var c := rad * pp.x + Vector3(0, pp.z + 0.02, 0)
		var a_in := c - rad * (ML.PATH_W + 0.25)
		var a_out := c + rad * ML.PATH_W
		var lip := a_out + Vector3(0, -0.18, 0)
		var foot := c + rad * 0.12 + Vector3(0, -1.75, 0)
		var cur := [a_in, a_out, lip, foot, rad]
		if prev.size():
			_tri(top, prev[0], prev[1], cur[1], Vector3.UP)
			_tri(top, prev[0], cur[1], cur[0], Vector3.UP)
			_tri(edge, prev[1], prev[2], cur[2], rad)
			_tri(edge, prev[1], cur[2], cur[1], rad)
			var sn: Vector3 = rad * 0.9 + Vector3(0, -0.45, 0)
			_tri(skirt, prev[2], prev[3], cur[3], sn)
			_tri(skirt, prev[2], cur[3], cur[2], sn)
		prev = cur
	for d in [[top, "#dcc08a"], [edge, "#b9965c"], [skirt, "#7a6f66"]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (d[0] as SurfaceTool).commit()
		var m := smat(d[1], {"rough": 0.95}).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		add_child(mi)
	# korlát-cölöpök az út külső szélén
	var post_m := smat("#8a5a2b")
	var rope_m := smat("#e9d8a6")
	var i2 := 0
	while i2 < ML.SPIRAL_N - 1:
		for half in 2:
			var s := i2 + 0.5 * half
			var p := ML.pos(s) + ML.radial(s) * (ML.PATH_W - 0.08)
			Chars3D.cyl(self, 0.045, 0.055, 0.42, post_m, p.x, p.y + 0.21, p.z, 6)
			var q := ML.pos(s + 0.5) + ML.radial(s + 0.5) * (ML.PATH_W - 0.08)
			var mid := (p + q) / 2 + Vector3(0, 0.34, 0)
			var rope := Chars3D.cyl(self, 0.018, 0.018, p.distance_to(q), rope_m, mid.x, mid.y, mid.z, 5)
			rope.basis = Basis.looking_at(q - p, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)
			rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		i2 += 1


func _tiles() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.54
	disc.height = 0.14
	disc.radial_segments = 28
	var rim := Chars3D.torus(0.52, 0.04)
	var white := smat("#ffffff", {"rough": 0.4})
	for nd in layout.nodes:
		var ty: Dictionary = TYPES.get(nd.type, TYPES.N)
		var p := ML.pos(nd.id)
		var g := Node3D.new()
		g.position = p + Vector3(0, 0.09, 0)
		g.rotation.y = ML.angle(nd.id)
		add_child(g)
		var m := MeshInstance3D.new()
		m.mesh = disc
		m.material_override = smat(ty.color, {"rough": 0.45})
		g.add_child(m)
		var r := MeshInstance3D.new()
		r.mesh = rim
		r.material_override = white
		r.position.y = 0.065
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(r)
		var txt: String = ty.icon
		if nd.type == "P": txt = "−%d" % nd.val
		elif nd.type == "F": txt = "+%d" % nd.val
		if txt != "":
			var lab := Label3D.new()
			lab.text = txt
			lab.font = D.font
			lab.font_size = 96 if ty.emoji else 100
			lab.pixel_size = 0.0066
			lab.outline_size = 0 if ty.emoji else 18
			lab.outline_modulate = Color(ty.color).darkened(0.5)
			lab.rotation.x = -PI / 2
			lab.position.y = 0.078
			lab.double_sided = false
			lab.shaded = false
			g.add_child(lab)
		tiles[nd.id] = g
		# tízesével mérföldkő-tábla az út belső oldalán
		if nd.id > 0 and nd.id % 10 == 0 and nd.id < ML.GOAL:
			var sp := p - ML.radial(nd.id) * 0.62
			Chars3D.cyl(self, 0.04, 0.05, 0.9, smat("#8a5a2b"), sp.x, sp.y + 0.45, sp.z, 6)
			var board := Chars3D.box(self, 0.62, 0.36, 0.06, smat("#f3e3b5"), sp + Vector3(0, 0.95, 0), Vector3(0, ML.angle(nd.id), 0))
			var sl := Label3D.new()
			sl.text = str(nd.id)
			sl.font = D.font
			sl.font_size = 64
			sl.pixel_size = 0.0042
			sl.modulate = Color("#5c3d1e")
			sl.outline_size = 0
			sl.position = Vector3(0, 0, 0.04)
			board.add_child(sl)


func flash_tile(id: int) -> void:
	var g: Node3D = tiles.get(id)
	if g == null:
		return
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3(1.35, 1.6, 1.35), 0.12)
	tw.tween_property(g, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ akadályok
## Három akadály zárja el az utat: téglafal (be kell ütni), bástya (ágyúval kell szétlőni)
## és egy alvó jeti (hógolyóval kell felébreszteni). A helyi +x a menetirány, a +z kifelé mutat.
func _gates() -> void:
	for g in layout.gates:
		var s: float = g.node + 0.5
		var root := Node3D.new()
		root.position = ML.pos(s)
		root.rotation.y = ML.angle(s)
		add_child(root)
		var o := {"root": root, "kind": g.kind, "bricks": [], "extra": [], "open": false, "lit": false, "awake": false}
		match g.kind:
			"cannon": _build_bastion(root, o)
			"yeti": _build_yeti(root, o)
			_: _build_wall(root, o)
		var lab := Label3D.new()
		lab.text = "🎲 4 · 5 · 6"
		lab.font = D.font
		lab.font_size = 96
		lab.pixel_size = 0.0045
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.outline_size = 24
		lab.outline_modulate = D.DARK
		lab.modulate = Color("#ffd43b")
		lab.position = Vector3(0, 2.75 if g.kind == "cannon" else 2.4, 0)
		root.add_child(lab)
		o["label"] = lab
		gates[g.node] = o
		if g.open:
			_set_gate_open(g.node)


func _wall_blocks(root: Node3D, o: Dictionary, rows: int, bh: float, thick: float, unit: float, cols: Array) -> void:
	var z0 := -1.0
	var z1 := 1.0
	for r in rows:
		var edges: Array = [z0]
		var z := z0 + (unit / 2 if r % 2 else unit)
		while z < z1 - 0.05:
			edges.append(z)
			z += unit
		edges.append(z1)
		for i in edges.size() - 1:
			var w: float = edges[i + 1] - edges[i]
			var b := Chars3D.box(root, thick, bh * 0.93, w - 0.025, smat(cols[(r * 3 + i) % cols.size()], {"rough": 0.9}),
				Vector3(0, bh * (r + 0.5), (edges[i] + edges[i + 1]) / 2))
			o.bricks.append(b)
	o.extra.append(Chars3D.box(root, thick - 0.1, rows * bh - 0.03, z1 - z0 - 0.05, smat("#d8cbb8"), Vector3(0, rows * bh / 2, 0)))


func _build_wall(root: Node3D, o: Dictionary) -> void:
	_wall_blocks(root, o, 6, 0.3, 0.36, 0.5, ["#c2553d", "#b34a36", "#cf6a4a", "#a8432f"])
	for i in 4:
		o.bricks.append(Chars3D.box(root, 0.46, 0.1, 0.5, smat("#9aa3ad", {"rough": 0.9}), Vector3(0, 1.85, -0.75 + i * 0.5)))
	# repedés és célpont a falon, a mászók felé néző oldalon
	var crack := smat("#3b1f17")
	for d in [[1.05, 0.1, 0.5, 0.5], [0.75, -0.12, 0.34, -0.7], [1.3, -0.1, 0.3, 0.9], [0.95, 0.38, 0.26, -0.3]]:
		o.extra.append(Chars3D.box(root, 0.02, d[2], 0.035, crack, Vector3(-0.19, d[0], d[1]), Vector3(d[3], 0, 0)))
	var fist := Label3D.new()
	fist.text = "👊"
	fist.font = D.font
	fist.font_size = 110
	fist.pixel_size = 0.006
	fist.rotation.y = -PI / 2
	fist.position = Vector3(-0.21, 1.25, 0.45)
	root.add_child(fist)
	o.extra.append(fist)


func _build_bastion(root: Node3D, o: Dictionary) -> void:
	_wall_blocks(root, o, 3, 0.64, 0.56, 0.68, ["#8d96a3", "#7b8492", "#9aa3ad", "#6f7885"])
	for i in 4:
		o.bricks.append(Chars3D.box(root, 0.62, 0.3, 0.34, smat("#6f7885", {"rough": 0.9}), Vector3(0, 2.07, -0.83 + i * 0.553)))
	# céltábla
	var rings := [[0.46, "#e03131"], [0.32, "#ffffff"], [0.18, "#e03131"]]
	for i in rings.size():
		o.extra.append(Chars3D.cyl(root, rings[i][0], rings[i][0], 0.03, smat(rings[i][1], {"rough": 0.6}), -0.29 - i * 0.012, 1.0, 0.1, 20, Vector3(0, 0, PI / 2)))
	# ágyú egy kiugró fa-állványon, az út külső oldalán
	var wood := smat("#8a5a2b")
	var wood_d := smat("#5c3d1e")
	var iron := smat("#2f3640", {"metal": 0.6, "rough": 0.4})
	var cpos := Vector3(-0.95, 0.0, 1.5)
	Chars3D.box(root, 1.2, 0.1, 1.15, wood, cpos + Vector3(0, -0.02, -0.05))
	for i in 4:
		Chars3D.box(root, 0.03, 0.105, 1.15, wood_d, cpos + Vector3(-0.45 + i * 0.3, -0.02, -0.05))
	for sx in [-0.45, 0.45]:
		Chars3D.box(root, 0.09, 1.25, 0.09, wood_d, cpos + Vector3(sx, -0.5, 0.0), Vector3(0.85, 0, 0))
		Chars3D.cyl(root, 0.05, 0.06, 0.5, wood_d, cpos.x + sx, 0.22, cpos.z + 0.45, 6)
	var aim := Vector3(0, 0.95, 0.1) - (cpos + Vector3(0, 0.45, 0))
	var cn := Chars3D.grp(root, cpos + Vector3(0, 0.03, 0), Vector3(0, atan2(-aim.z, aim.x), 0))
	Chars3D.box(cn, 0.62, 0.14, 0.36, wood_d, Vector3(-0.02, 0.22, 0))
	for sz in [-1.0, 1.0]:
		Chars3D.lcyl(cn, 0.22, 0.22, 0.07, wood, -0.02, 0.22, sz * 0.22, 10, Vector3(PI / 2, 0, 0))
		Chars3D.lcyl(cn, 0.07, 0.07, 0.09, iron, -0.02, 0.22, sz * 0.23, 6, Vector3(PI / 2, 0, 0))
	var barrel := Chars3D.grp(cn, Vector3(0, 0.42, 0), Vector3(0, 0, 0.3))
	Chars3D.lcyl(barrel, 0.14, 0.19, 0.9, iron, 0.2, 0, 0, 10, Vector3(0, 0, -PI / 2))
	Chars3D.lcyl(barrel, 0.175, 0.175, 0.07, smat("#ffd43b", {"metal": 0.7, "rough": 0.3}), 0.63, 0, 0, 10, Vector3(0, 0, -PI / 2))
	Chars3D.lcyl(barrel, 0.2, 0.2, 0.06, smat("#ffd43b", {"metal": 0.7, "rough": 0.3}), -0.05, 0, 0, 10, Vector3(0, 0, -PI / 2))
	Chars3D.lsphere(barrel, 0.19, iron, -0.25, 0, 0, 1, 1, 1, 8, 5)
	Chars3D.cyl(barrel, 0.012, 0.012, 0.16, smat("#e9d8a6"), -0.22, 0.24, 0, 5)
	var spark := Chars3D.lsphere(barrel, 0.06, smat("#ffe066", {"emit": "#ff9500", "emit_e": 3.0}), -0.22, 0.34, 0, 1, 1, 1, 5, 3)
	spark.visible = false
	var flash := Chars3D.lsphere(barrel, 0.3, smat("#fff3bf", {"emit": "#ffb000", "emit_e": 4.0, "unshaded": true}), 0.8, 0, 0, 1, 1, 1, 7, 4)
	flash.visible = false
	o["cannon"] = cn
	o["barrel"] = barrel
	o["spark"] = spark
	o["flash"] = flash
	animated.append(func(tt):
		if o.lit and is_instance_valid(spark):
			spark.scale = Vector3.ONE * 0.06 * (1.0 + sin(tt * 40.0) * 0.5)
			spark.position.y = 0.34 - fmod(tt * 0.2, 0.1))


func _build_yeti(root: Node3D, o: Dictionary) -> void:
	var C := Chars3D
	var fur := smat("#f4f7fb", {"rough": 0.95})
	var fur_d := smat("#d5e3f0", {"rough": 0.95})
	var blue := smat("#8fd0f5", {"rough": 0.6})
	var dark := smat("#274060", {"rough": 0.5})
	var ivory := smat("#f5ecd7")
	# jégpárkány az út külső szélén: ide ül ki, ha felébredt
	var ice := smat("#cfeaff", {"rough": 0.15, "metal": 0.2, "emit": "#74c0fc", "emit_e": 0.25})
	C.box(root, 1.9, 0.24, 1.55, ice, Vector3(0.2, -0.1, 1.72))
	C.box(root, 1.96, 0.08, 1.6, smat("#ffffff", {"rough": 0.9}), Vector3(0.2, 0.04, 1.72))
	for i in 5:
		C.lcone(root, 0.16, 0.5 + (i % 2) * 0.3, ice, -0.55 + i * 0.38, -0.45 - (i % 2) * 0.15, 1.5 + (i % 3) * 0.3, 5, Vector3(PI, 0, 0))
	var y := C.grp(root, Vector3(0, 0, 0.1), Vector3(0, -PI / 2, 0))
	# test, has, lábak
	C.lsphere(y, 0.72, fur, 0, 0.66, 0, 1.1, 1.0, 0.95, 10, 7)
	C.lsphere(y, 0.46, fur_d, 0, 0.58, 0.42, 1, 1, 0.5, 8, 6)
	for i in 7:
		var a := TAU * i / 7
		C.lcone(y, 0.2, 0.34, fur, sin(a) * 0.66, 0.2, cos(a) * 0.6, 4, Vector3(PI, a, 0))
	for s in [-1, 1]:
		C.lsphere(y, 0.24, fur, s * 0.4, 0.18, 0.5, 1, 0.8, 1.5, 7, 5)
		C.lsphere(y, 0.23, blue, s * 0.42, 0.2, 0.86, 1, 1.1, 0.5, 7, 5)
		for k in [-1, 0, 1]:
			C.lsphere(y, 0.05, dark, s * 0.42 + k * 0.11, 0.36, 0.95, 1, 1, 0.6, 5, 3)
	# fej, arc
	var head := C.grp(y, Vector3(0, 1.38, 0.1))
	C.lsphere(head, 0.47, fur, 0, 0, 0, 1.08, 0.95, 1, 10, 7)
	C.lsphere(head, 0.31, blue, 0, -0.05, 0.3, 1.15, 0.9, 0.55, 8, 6)
	for s in [-1, 1]:
		C.lcone(head, 0.085, 0.3, ivory, s * 0.36, 0.38, 0.0, 6, Vector3(0, 0, -s * 0.55))
		C.lcone(head, 0.12, 0.25, fur, s * 0.5, -0.1, 0.05, 4, Vector3(0, 0, -s * 1.9))
		C.lcone(head, 0.04, 0.11, ivory, s * 0.1, -0.2, 0.44, 4)
	for i in 3:
		C.lcone(head, 0.1, 0.26, fur, (i - 1) * 0.13, 0.48, 0.05, 4, Vector3(0.2, 0, -(i - 1) * 0.35))
	C.lsphere(head, 0.06, dark, 0, -0.03, 0.48, 1.3, 0.8, 0.8, 6, 4)
	C.box(head, 0.2, 0.03, 0.03, dark, Vector3(0, -0.21, 0.44))
	var eyes: Array = C.eyes(head, 0.08, 0.42, 0.15, 0.085)
	for e in eyes:
		e.scale.y = 0.12
	# karok
	var arms: Array = []
	for s in [-1, 1]:
		var arm := C.grp(y, Vector3(s * 0.74, 1.02, 0.08), Vector3(0, 0, s * 0.22))
		C.lsphere(arm, 0.21, fur, 0, -0.32, 0, 1, 1.9, 1, 7, 5)
		C.lsphere(arm, 0.19, blue, 0, -0.72, 0.03, 1, 0.9, 1, 7, 5)
		arms.append(arm)
	var zzz := Label3D.new()
	zzz.text = "💤"
	zzz.font = D.font
	zzz.font_size = 120
	zzz.pixel_size = 0.007
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zzz.no_depth_test = true
	zzz.position = Vector3(0.45, 2.35, 0.1)
	root.add_child(zzz)
	o["yeti"] = y
	o["yeti_eyes"] = eyes
	o["yeti_arm"] = arms[1]
	o["yeti_head"] = head
	o["zzz"] = zzz
	o["snore"] = 0.0
	animated.append(func(tt):
		if not o.awake:
			var br := sin(tt * 1.6)
			var k: float = 1.0 + o.snore
			y.scale = Vector3(1.0 - br * 0.015 * k, 1.0 + br * 0.035 * k, 1.0 + br * 0.02 * k)
			head.rotation.z = 0.12 + br * 0.04
			zzz.position.y = 2.35 + fmod(tt * 0.35, 0.5)
			zzz.modulate.a = 1.0 - fmod(tt * 0.35, 0.5) * 1.6
			o.snore = max(0.0, o.snore - 0.02)
		else:
			arms[1].rotation.z = 2.5 + sin(tt * 7.0) * 0.35
			head.rotation.z = sin(tt * 3.5) * 0.08)


## Az akadály helyi koordinátája (x: menetirány, z: kifelé) világkoordinátában.
func gate_point(id: int, local: Vector3) -> Vector3:
	return (gates[id].root as Node3D).transform * local


func cannon_perch(id: int) -> Vector3:
	var o: Dictionary = gates[id]
	return (o.root as Node3D).transform * ((o.cannon as Node3D).transform * Vector3(0.08, 0.6, 0))


func yeti_head(id: int) -> Vector3:
	return gate_point(id, Vector3(-0.3, 1.45, 0.1))


func _set_gate_open(id: int) -> void:
	var o: Dictionary = gates[id]
	o.open = true
	o.label.visible = false
	for b in o.bricks:
		if is_instance_valid(b):
			b.queue_free()
	o.bricks = []
	for e in o.extra:
		if is_instance_valid(e):
			e.queue_free()
	o.extra = []
	if o.kind == "yeti":
		o.awake = true
		o.zzz.visible = false
		for e in o.yeti_eyes:
			e.scale.y = 1.0
		var y: Node3D = o.yeti
		y.scale = Vector3.ONE * 0.8
		y.position = Vector3(0.2, 0.08, 1.85)
		y.rotation.y = -0.64


## Sikertelen próbálkozás: az akadály megrezzen, de áll tovább.
func gate_fail(id: int) -> void:
	if not gates.has(id):
		return
	var o: Dictionary = gates[id]
	var root: Node3D = o.root
	if o.kind == "yeti":
		o.snore = 2.5
		var z: Label3D = o.zzz
		var tw := create_tween()
		tw.tween_property(z, "scale", Vector3.ONE * 1.8, 0.15)
		tw.tween_property(z, "scale", Vector3.ONE, 0.5)
		return
	var tw := create_tween()
	for a in [0.05, -0.04, 0.025, -0.012, 0.0]:
		tw.tween_property(root, "rotation:z", a, 0.07)
	shake = 0.35


## A fal darabjaira hullik: a téglák a menetirányba és a szakadék felé repülnek.
func break_wall(id: int, power := 1.0) -> void:
	if not gates.has(id):
		return
	var o: Dictionary = gates[id]
	for b in o.bricks:
		debris.append({"n": b, "age": FX.f() * 0.3,
			"v": Vector3(FX.fr(1.5, 5.5) * power, FX.fr(1.0, 5.5) * power, FX.fr(-1.0, 3.2)),
			"w": Vector3(FX.fr(-9, 9), FX.fr(-9, 9), FX.fr(-9, 9))})
	o.bricks = []
	_set_gate_open(id)
	# porfelhő
	for i in 7:
		_puff(gate_point(id, Vector3(FX.fr(-0.2, 0.5), FX.fr(0.3, 1.6), FX.fr(-0.7, 0.8))), "#d9cfc1", 0.5 + FX.f() * 0.4, 0.7)
	shake = 0.9 * power


func _puff(at: Vector3, col: String, size: float, dur: float) -> void:
	var m := smat(col, {"rough": 1.0}).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var s := Chars3D.lsphere(self, 1.0, m, at.x, at.y, at.z, 1, 1, 1, 6, 4)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.scale = Vector3.ONE * size * 0.2
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * size, dur * 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "position:y", at.y + 0.5, dur)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)


func cannon_light(id: int) -> void:
	var o: Dictionary = gates[id]
	o.lit = true
	o.spark.visible = true
	var cn: Node3D = o.cannon
	var tw := create_tween()
	tw.tween_property(cn, "scale", Vector3(1.12, 0.8, 1.12), 0.08)
	tw.tween_property(cn, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Elsül az ágyú: a golyó a bástyába csapódik, ami darabokra hullik.
func cannon_fire(id: int) -> void:
	var o: Dictionary = gates[id]
	o.lit = false
	o.spark.visible = false
	var barrel: Node3D = o.barrel
	var flash: MeshInstance3D = o.flash
	var tw := create_tween()
	tw.tween_property(barrel, "position:x", -0.3, 0.06)
	tw.tween_property(barrel, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash.visible = true
	flash.scale = Vector3.ONE * 0.1
	var tf := create_tween()
	tf.tween_property(flash, "scale", Vector3.ONE * 0.42, 0.07)
	tf.tween_property(flash, "scale", Vector3.ONE * 0.01, 0.12)
	tf.tween_callback(func(): flash.visible = false)
	var from: Vector3 = (o.root as Node3D).transform * ((o.cannon as Node3D).transform * (barrel.transform * Vector3(0.75, 0, 0)))
	var to := gate_point(id, Vector3(-0.2, 1.0, 0.1))
	for i in 5:
		_puff(from + Vector3(FX.fr(-0.25, 0.25), FX.fr(-0.1, 0.3), FX.fr(-0.25, 0.25)), "#6b7280", 0.45 + FX.f() * 0.35, 0.9)
	var ball := Chars3D.lsphere(self, 0.17, smat("#1f2329", {"metal": 0.5, "rough": 0.4}), from.x, from.y, from.z, 1, 1, 1, 7, 4)
	var tb := create_tween()
	tb.tween_property(ball, "position", to, 0.16)
	tb.tween_callback(func():
		ball.queue_free()
		break_wall(id, 1.5))
	shake = 0.7


## Ívben repülő golyó (hógolyó) a és b között.
func throw_ball(a: Vector3, b: Vector3, dur: float, height: float, col := "#ffffff", r := 0.16) -> void:
	var ball := Chars3D.lsphere(self, r, smat(col, {"rough": 0.9}), a.x, a.y, a.z, 1, 1, 1, 6, 4)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		ball.position = a.lerp(b, k) + Vector3(0, sin(k * PI) * height, 0)
		ball.rotation.x = k * 9.0, 0.0, 1.0, dur)
	tw.tween_callback(func():
		for i in 6:
			_puff(b + Vector3(FX.fr(-0.3, 0.3), FX.fr(-0.2, 0.3), FX.fr(-0.3, 0.3)), "#ffffff", 0.3 + FX.f() * 0.25, 0.6)
		ball.queue_free())


## A jeti felriad, nagyot ugrik, és kiül a jégpárkányra integetni.
func yeti_wake(id: int) -> void:
	var o: Dictionary = gates[id]
	var y: Node3D = o.yeti
	o.label.visible = false
	o.zzz.text = "❗"
	o.zzz.modulate.a = 1.0
	for e in o.yeti_eyes:
		e.scale.y = 1.25
	o.awake = true
	o.open = true
	y.scale = Vector3.ONE
	var from := y.position
	var to := Vector3(0.2, 0.08, 1.85)
	var tw := create_tween()
	tw.tween_property(y, "scale", Vector3(1.12, 0.8, 1.12), 0.1)
	tw.tween_property(y, "scale", Vector3(0.9, 1.15, 0.9), 0.1)
	tw.parallel().tween_property(y, "position:y", 0.9, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(y, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): shake = 0.8)
	tw.tween_property(y, "scale", Vector3(1.15, 0.8, 1.15), 0.08)
	tw.tween_property(y, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(0.15)
	tw.tween_method(func(k: float):
		y.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 1.6, 0)
		y.rotation.y = lerpf(-PI / 2, -0.64, k)
		y.scale = Vector3.ONE * lerpf(1.0, 0.8, k), 0.0, 1.0, 0.6)
	tw.tween_callback(func():
		shake = 0.6
		o.zzz.visible = false
		for e in o.yeti_eyes:
			e.scale.y = 1.0)


func _update_debris(dt: float) -> void:
	if debris.is_empty():
		return
	var keep: Array = []
	for d in debris:
		var n: Node3D = d.n
		if not is_instance_valid(n):
			continue
		d.age += dt
		d.v.y -= 16.0 * dt
		n.position += d.v * dt
		n.rotation += d.w * dt
		if d.age > 1.9:
			n.scale = Vector3.ONE * max(0.01, 1.0 - (d.age - 1.9) * 3.0)
		if d.age > 2.2:
			n.queue_free()
		else:
			keep.append(d)
	debris = keep


# ------------------------------------------------------------------ mezők látványa: üldözők és szél
## kind: "bear" (medve), "rocks" (kőomlás), "snow" (lavina). A csomópont +z iránya a haladás (lefelé az úton).
func make_chaser(kind: String) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	g.set_meta("kind", kind)
	if kind == "bear":
		var m := Chars3D.build("bear")
		m.scale = Vector3.ONE * 1.75
		for s in [-1, 1]:
			Chars3D.box(m.rig, 0.13, 0.04, 0.05, Chars3D.mat("#2a170b"), Vector3(s * 0.12, 0.925, 0.275), Vector3(0.3, 0, s * 0.55))
		for s in [-1, 1]:
			Chars3D.lcone(m.rig, 0.025, 0.07, Chars3D.mat("#ffffff"), s * 0.05, 0.69, 0.33, 4, Vector3(PI, 0, 0))
		g.add_child(m)
		g.set_meta("model", m)
		return g
	var snow := kind == "snow"
	var cols := ["#f4f7fb", "#ffffff", "#dfeaf5"] if snow else ["#8a8580", "#6f6a66", "#9b968f"]
	var defs := [[0.0, 0.52, 0.0], [-0.42, 0.36, -0.5], [0.4, 0.4, -0.75], [0.05, 0.3, -1.25], [-0.3, 0.26, 0.6]]
	if snow:
		defs.append_array([[0.45, 0.34, 0.35], [-0.5, 0.3, -1.3], [0.2, 0.45, -1.9]])
	for i in defs.size():
		var d: Array = defs[i]
		var hold := Chars3D.grp(g, Vector3(d[0], d[1] * (0.85 if snow else 1.0), d[2]))
		var b := Chars3D.lsphere(hold, d[1], smat(cols[i % 3], {"rough": 1.0}), 0, 0, 0, 1, 0.9 if snow else 0.85, 1, 6 + (i % 2), 4)
		b.set_meta("r", d[1])
	return g


## Az üldöző elhelyezése az út s pontjára; moved: mennyit haladt (mezőben) az előző képkocka óta.
func place_chaser(g: Node3D, s: float, moved: float) -> void:
	g.position = ML.pos(clamp(s, 0.0, float(ML.GOAL)))
	g.rotation.y = ML.angle(s) - PI / 2
	if g.get_meta("kind") == "bear":
		var m: Node3D = g.get_meta("model")
		var run: float = clamp(abs(moved) * 60.0, 0.0, 1.0)
		m.position.y = abs(sin(t * 13.0)) * 0.22 * run
		m.rotation.x = 0.22 * run + sin(t * 13.0) * 0.06 * run
		m.rotation.z = sin(t * 6.5) * 0.12 * run
		return
	for hold in g.get_children():
		var b: Node3D = hold.get_child(0)
		b.rotation.x += moved * ML.SPACING / float(b.get_meta("r"))
		hold.position.y = float(b.get_meta("r")) * 0.9 + abs(sin(t * 9.0 + hold.position.z * 3.0)) * 0.12


func chaser_scale(g: Node3D, to: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3.ONE * to, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT if to > 0.5 else Tween.EASE_IN)


func _build_wind() -> void:
	wind = Node3D.new()
	wind.visible = false
	add_child(wind)
	var wm := smat("#ffffff", {"unshaded": true, "alpha": 0.9})
	var leaf := [smat("#8ce99a", {"unshaded": true}), smat("#ffd43b", {"unshaded": true}), smat("#ffffff", {"unshaded": true})]
	var items: Array = []
	for i in 18:
		var b := Chars3D.box(wind, 1.0 + (i % 3) * 0.45, 0.1, 0.1, wm, Vector3.ZERO)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		items.append({"n": b, "ph": i * 0.377, "y": 0.25 + (i * 0.37) - floor(i * 0.37 / 1.5) * 1.5, "z": -0.7 + fmod(i * 0.53, 1.5), "leaf": false, "sp": 1.5 + (i % 4) * 0.25})
	for i in 9:
		var b := Chars3D.box(wind, 0.2, 0.02, 0.13, leaf[i % 3], Vector3.ZERO)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		items.append({"n": b, "ph": i * 0.291, "y": 0.3 + fmod(i * 0.41, 1.3), "z": -0.65 + fmod(i * 0.67, 1.4), "leaf": true, "sp": 1.2 + (i % 3) * 0.2})
	animated.append(func(tt):
		if not wind.visible:
			return
		for it in items:
			var k := fmod(tt * it.sp + it.ph, 1.0)
			var n: Node3D = it.n
			var grow := sin(k * PI)
			if it.leaf:
				n.position = Vector3(lerpf(-2.4, 2.2, k), it.y + sin(k * 9.0 + it.ph * 20.0) * 0.25, it.z + cos(k * 7.0 + it.ph * 9.0) * 0.2)
				n.rotation = Vector3(tt * 9.0 + it.ph, tt * 7.0, tt * 5.0)
				n.scale = Vector3.ONE * grow * wind_power
			else:
				n.position = Vector3(lerpf(-2.6, 2.0, k), it.y + sin(k * PI) * 0.12, it.z)
				n.scale = Vector3(grow, 1, 1) * max(0.01, wind_power))


## A szél-effekt a megadott talppontra (s: útmenti hely) kerül; on = false kikapcsolja.
func wind_at(pos: Vector3, s: float, on := true) -> void:
	if wind == null:
		_build_wind()
	wind.visible = on
	if on:
		wind.position = pos
		wind.rotation.y = ML.angle(s)
		wind_power = min(1.0, wind_power + 0.06)
	else:
		wind_power = 0.0


func _summit() -> void:
	var r := ML.wall_r(ML.H)
	Chars3D.cyl(self, r, r, ML.SUMMIT_Y - ML.H + 0.3, smat("#ffffff", {"rough": 0.9}), 0, (ML.SUMMIT_Y + ML.H - 0.3) / 2.0, 0, 40)
	# rámpa az utolsó útmezőtől a csúcsig
	var a := ML.pos(ML.SPIRAL_N - 1)
	var b := Vector3(0, ML.SUMMIT_Y, 0)
	var mid := (a + b) / 2
	var ramp := Chars3D.box(self, 1.5, 0.12, a.distance_to(b), smat("#dcc08a"), mid + Vector3(0, -0.02, 0))
	ramp.basis = Basis.looking_at(b - a, Vector3.UP)
	# zászló
	var g := Node3D.new()
	g.position = Vector3(0, ML.SUMMIT_Y, -0.75)
	add_child(g)
	Chars3D.cyl(g, 0.045, 0.06, 3.2, smat("#e5e7eb", {"metal": 0.5, "rough": 0.4}), 0, 1.6, 0, 8)
	Chars3D.sphere(g, 0.1, smat("#ffd43b", {"metal": 0.8, "rough": 0.25, "emit": "#ffb000", "emit_e": 0.6}), 0, 3.25, 0)
	var flag := Node3D.new()
	flag.position = Vector3(0, 2.75, 0)
	g.add_child(flag)
	Chars3D.box(flag, 1.1, 0.7, 0.03, smat("#e11d48", {"rough": 0.6}), Vector3(0.58, 0, 0))
	animated.append(func(tt):
		flag.rotation.y = cam_ang + sin(tt * 3.0) * 0.25)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffe066")
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.position = Vector3(0, ML.SUMMIT_Y + 1.6, 0)
	add_child(light)
	animated.append(func(tt): light.light_energy = 1.4 + sin(tt * 3.0) * 0.5)


func _deco() -> void:
	var rnd := BoardLayout.Seeded.new(97)
	var M := Chars3D
	# a hegy lábánál: fenyők, sziklák, virágok
	for i in 46:
		var a := rnd.next() * TAU
		var rr := ML.RB + 1.7 + rnd.next() * 3.6
		var g := Node3D.new()
		g.position = Vector3(sin(a) * rr, 0, cos(a) * rr)
		g.rotation.y = rnd.next() * TAU
		g.scale = Vector3.ONE * (0.9 + rnd.next() * 0.8)
		add_child(g)
		var k := i % 5
		if k <= 2:
			M.cyl(g, 0.07, 0.09, 0.4, smat("#6b4a2b"), 0, 0.2, 0, 8)
			for j in 3:
				M.cone(g, 0.5 - j * 0.12, 0.6, smat("#2f7d3b" if j % 2 == 0 else "#38904a"), 0, 0.55 + j * 0.35, 0, 9)
		elif k == 3:
			M.sphere(g, 0.3, smat("#8a8580", {"rough": 1.0}), 0, 0.12, 0, 1.2, 0.7, 1)
			M.sphere(g, 0.18, smat("#9b968f", {"rough": 1.0}), 0.25, 0.08, 0.1, 1, 0.7, 1)
		else:
			var cols := ["#ff6b9a", "#ffd43b", "#ffffff", "#b197fc", "#ff922b"]
			for j in 6:
				var fa := j * 2.4
				var fr := 0.3 * (j / 6.0 + 0.3)
				M.cyl(g, 0.012, 0.012, 0.2, smat("#3f9d45"), cos(fa) * fr, 0.1, sin(fa) * fr, 5)
				M.sphere(g, 0.06, smat(cols[j % cols.size()]), cos(fa) * fr, 0.22, sin(fa) * fr)
	# alaptábor a rajt mellett
	var camp := Node3D.new()
	var sp := ML.pos(0) + ML.radial(0) * 3.2 - ML.tangent(0) * 2.2
	camp.position = Vector3(sp.x, 0, sp.z)
	camp.rotation.y = 0.5
	add_child(camp)
	M.cone(camp, 1.0, 1.3, smat("#ff922b"), 0, 0.65, 0, 6)
	M.cone(camp, 1.03, 0.32, smat("#fff3bf"), 0, 0.16, 0, 6)
	M.box(camp, 0.34, 0.55, 0.05, smat("#7a4a2a"), Vector3(0, 0.27, 0.8))
	var fire := Node3D.new()
	fire.position = Vector3(1.7, 0, 0.6)
	camp.add_child(fire)
	for j in 5:
		var la := TAU * j / 5
		M.cyl(fire, 0.05, 0.05, 0.5, smat("#6b4a2b"), cos(la) * 0.12, 0.08, sin(la) * 0.12, 6, Vector3(PI / 2.4, la, 0))
	var flame := M.cone(fire, 0.16, 0.45, smat("#ff922b", {"emit": "#ff6b00", "emit_e": 2.5}), 0, 0.3, 0, 7)
	animated.append(func(tt): flame.scale = Vector3(1.0 + sin(tt * 11.0) * 0.15, 1.0 + sin(tt * 13.0) * 0.25, 1.0 + cos(tt * 9.0) * 0.15))
	# fenyők és bokrok a párkány belső oldalán, a hegy alsó harmadán
	for i in 30:
		var s := 1.5 + rnd.next() * 34.0
		if MountainLayout.gate_at(layout, int(round(s))) != null or MountainLayout.gate_at(layout, int(floor(s))) != null:
			continue
		var p := ML.pos(s) - ML.radial(s) * (ML.PATH_W + 0.05)
		var g := Node3D.new()
		g.position = p + Vector3(0, 0.3, 0)
		g.scale = Vector3.ONE * (0.55 + rnd.next() * 0.45)
		add_child(g)
		if i % 3 == 0:
			M.sphere(g, 0.3, smat("#8a8580", {"rough": 1.0}), 0, 0.05, 0, 1.2, 0.7, 1)
		else:
			M.cyl(g, 0.07, 0.09, 0.4, smat("#6b4a2b"), 0, 0.2, 0, 8)
			for j in 3:
				M.cone(g, 0.5 - j * 0.12, 0.6, smat("#2f7d3b" if j % 2 == 0 else "#38904a"), 0, 0.55 + j * 0.35, 0, 9)
	# hóemberek és jégcsúcsok fent
	for i in 9:
		var s := 56.0 + rnd.next() * 21.0
		if MountainLayout.gate_at(layout, int(round(s))) != null or MountainLayout.gate_at(layout, int(floor(s))) != null:
			continue
		var p := ML.pos(s) - ML.radial(s) * (ML.PATH_W + 0.02)
		var g := Node3D.new()
		g.position = p + Vector3(0, 0.25, 0)
		g.rotation.y = ML.angle(s)
		g.scale = Vector3.ONE * 0.6
		add_child(g)
		if i % 3 == 0:
			var snow := smat("#ffffff", {"rough": 0.9})
			M.sphere(g, 0.34, snow, 0, 0.3, 0)
			M.sphere(g, 0.25, snow, 0, 0.75, 0)
			M.sphere(g, 0.18, snow, 0, 1.08, 0)
			M.cone(g, 0.05, 0.22, smat("#ff922b"), 0, 1.08, 0.24, 6, Vector3(PI / 2, 0, 0))
			M.sphere(g, 0.03, smat("#1f1b2e"), -0.07, 1.14, 0.15)
			M.sphere(g, 0.03, smat("#1f1b2e"), 0.07, 1.14, 0.15)
		else:
			for j in 3:
				var hh := 0.5 + (j % 2) * 0.45
				M.cone(g, 0.15, hh, smat("#cfeaff", {"rough": 0.15, "metal": 0.2, "emit": "#74c0fc", "emit_e": 0.35}), cos(j * 2.1) * 0.2, hh / 2, sin(j * 2.1) * 0.2, 6)


func _cloud_ring() -> void:
	var cm := smat("#ffffff", {"rough": 1.0})
	var rnd := BoardLayout.Seeded.new(19)
	for i in 16:
		var g := Node3D.new()
		var sc := 1.2 + rnd.next() * 1.6
		for k in 4:
			var s := Chars3D.sphere(g, 1.0, cm, (k - 1.5) * sc * 0.8, rnd.next() * 0.4 * sc, (rnd.next() - 0.5) * sc)
			s.scale = Vector3(sc, sc * 0.45, sc * 0.8) * (0.7 + rnd.next() * 0.5)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		var rad := 24.0 + rnd.next() * 22.0
		var y0 := -6.0 + rnd.next() * 22.0
		var a0 := rnd.next() * TAU
		var spd := (0.012 + rnd.next() * 0.02) * (1 if i % 2 else -1)
		animated.append(func(tt):
			var a = a0 + tt * spd
			g.position = Vector3(sin(a) * rad, y0, cos(a) * rad)
			g.rotation.y = a + PI / 2)


func _marker() -> void:
	marker = Node3D.new()
	add_child(marker)
	Chars3D.cone(marker, 0.22, 0.4, smat("#ffd43b", {"emit": "#ffb000", "emit_e": 1.2}), 0, 0, 0, 4, Vector3(PI, 0, 0))


func _birds() -> void:
	var bm := smat("#ffffff", {"rough": 0.6})
	for i in 5:
		var g := Node3D.new()
		add_child(g)
		var wl := Chars3D.box(g, 0.5, 0.02, 0.14, bm, Vector3(-0.25, 0, 0))
		var wr := Chars3D.box(g, 0.5, 0.02, 0.14, bm, Vector3(0.25, 0, 0))
		var r := 16.0 + i * 2.5
		var spd := 0.12 + i * 0.03
		var ph := i * 1.7
		animated.append(func(tt):
			var a = tt * spd + ph
			g.position = Vector3(cos(a) * r, 9.0 + i * 1.5 + sin(tt * 0.7 + i) * 0.8, sin(a) * r)
			g.rotation.y = -a
			var f := sin(tt * 9.0 + i) * 0.5
			wl.rotation.z = f
			wr.rotation.z = -f)


# ------------------------------------------------------------------ bábuk
func pawn_for(p) -> Dictionary:
	if pawns.has(p.pid) and pawns[p.pid].char_id == p.char_id:
		return pawns[p.pid]
	if pawns.has(p.pid):
		pawns[p.pid].group.queue_free()
	var g := Node3D.new()
	add_child(g)
	var model := Chars3D.build(p.char_id)
	model.scale = Vector3.ONE * PAWN_SCALE
	g.add_child(model)
	var base := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.36
	cy.bottom_radius = 0.38
	cy.height = 0.05
	base.mesh = cy
	base.material_override = Chars3D.mat(p.color_hex, {"rough": 0.4})
	base.position.y = 0.025
	g.add_child(base)
	var ring := MeshInstance3D.new()
	ring.mesh = Chars3D.torus(0.46, 0.04)
	ring.material_override = Chars3D.mat("#ffffff", {"unshaded": true})
	ring.position.y = 0.04
	g.add_child(ring)
	var o := {"group": g, "model": model, "ring": ring, "char_id": p.char_id, "yaw": 0.0, "target_yaw": 0.0,
		"last": null, "still": 0.0, "prev_h": 0.0}
	pawns[p.pid] = o
	return o


func emote(pid: String, type: String) -> void:
	if pawns.has(pid):
		pawns[pid].model.emote(type)


## st = {pawns: [{p, pos: Vector3 (talppont), h: ugrásmagasság, current, frozen}]}
func render(st: Dictionary, dt: float) -> void:
	t += dt
	var seen := {}
	var cur_pos = null
	for d in st.pawns:
		var o := pawn_for(d.p)
		seen[d.p.pid] = true
		_animate_pawn(o, d, dt)
		if d.current:
			cur_pos = o.group.position
	for pid in pawns.keys():
		if not seen.has(pid):
			pawns[pid].group.queue_free()
			pawns.erase(pid)
	_update_camera(dt)
	_update_debris(dt)
	marker.visible = cur_pos != null
	if cur_pos != null:
		marker.position = cur_pos + Vector3(0, 1.9 + sin(t * 5.0) * 0.1, 0)
		marker.rotation.y = t * 2.5
	for f in animated:
		f.call(t)


func _animate_pawn(o: Dictionary, d: Dictionary, dt: float) -> void:
	var p: Vector3 = d.pos
	var out_yaw := atan2(p.x, p.z)
	if Vector2(p.x, p.z).length() < 0.5:
		out_yaw = cam_ang
	if o.last != null:
		var dv: Vector3 = p - o.last
		if Vector2(dv.x, dv.z).length() > 0.004:
			o.target_yaw = atan2(dv.x, dv.z)
			o.still = 0.0
		else:
			o.still += dt
			if o.still > 0.45:
				o.target_yaw = out_yaw
	else:
		o.yaw = out_yaw
		o.target_yaw = out_yaw
	o.last = p
	o.yaw += angle_difference(o.yaw, o.target_yaw) * min(1.0, dt * 10.0)
	var model: Chars3D.CharModel = o.model
	if o.prev_h > 0.12 and d.h <= 0.12:
		model.land = 1.0
	o.prev_h = d.h
	model.airborne = 1.0 if d.h > 0.12 else 0.0
	var a := model.animate(dt)
	o.group.position = p + Vector3(0, d.h + a.y, 0)
	model.rotation.y = o.yaw + a.spin
	model.rotation.x = a.tilt
	var cur: bool = d.current
	model.scale = Vector3.ONE * PAWN_SCALE * (1.12 if cur else 1.0)
	o.ring.visible = cur
	if cur:
		o.ring.scale = Vector3.ONE * (1.0 + sin(t * 6.0) * 0.08)


# ------------------------------------------------------------------ kamera
func cam_overview(speed := 1.8) -> void:
	cam_mode = "overview"
	cam_speed = speed


func cam_follow(pid: String, zoom := "near", speed := 3.0) -> void:
	cam_mode = "follow"
	cam_pid = pid
	cam_zoom = zoom
	cam_speed = speed


func cam_node(s: float, zoom := "mid", speed := 2.5) -> void:
	cam_mode = "point"
	cam_point = ML.pos(s)
	cam_zoom = zoom
	cam_speed = speed


## [szög, sugár, magasság, nézett pont]
func _cam_target() -> Array:
	var p = null
	if cam_mode == "follow" and pawns.has(cam_pid):
		p = pawns[cam_pid].group.position
	elif cam_mode == "point":
		p = cam_point
	if p == null:
		return [cam_ang + 0.0, 45.0, 19.0, Vector3(0, 9.6, 0)]
	var z: Dictionary = ZOOMS.get(cam_zoom, ZOOMS.near)
	var pr := Vector2(p.x, p.z).length()
	var ang: float = atan2(p.x, p.z) if pr > 0.6 else cam_ang
	# kicsit előre néz a menetirányba, hogy látszódjon, mi jön
	return [ang + cam_side, pr + z.d, p.y + z.h, Vector3(p.x, p.y + 0.6, p.z)]


func cam_snap() -> void:
	var d := _cam_target()
	cam_ang = d[0]
	cam_rad = d[1]
	cam_y = d[2]
	cam_look_pos = d[3]


func _update_camera(dt: float) -> void:
	if cam_mode == "overview":
		cam_ang += dt * 0.12
	if cam_mode != "manual":
		var d := _cam_target()
		var k := 1.0 - exp(-dt * cam_speed)
		cam_ang += angle_difference(cam_ang, d[0]) * k
		cam_rad = lerpf(cam_rad, d[1], k)
		cam_y = lerpf(cam_y, d[2], k)
		cam_look_pos = cam_look_pos.lerp(d[3], k)
	shake = max(0.0, shake - dt * 2.5)
	var off := Vector3(FX.fr(-1, 1), FX.fr(-1, 1), 0) * shake * 0.25
	camera.position = Vector3(sin(cam_ang) * cam_rad, cam_y, cos(cam_ang) * cam_rad) + off
	camera.look_at(cam_look_pos + off, Vector3.UP)


func project(p: Vector3) -> Vector2:
	if camera.is_position_behind(p):
		return Vector2(-999, -999)
	return camera.unproject_position(p)
