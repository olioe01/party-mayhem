class_name Mountain3D
extends Node3D
## 3D hegy a hegymászós játékmódhoz: kúp alakú hegy, körbefutó párkány-út, mezők, kapuk,
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
var gates := {}          # mező -> {root, door, label}
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


static func get_for(l: Dictionary) -> Mountain3D:
	if instance and is_instance_valid(instance) and is_same(instance.layout, l):
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


# ------------------------------------------------------------------ kapuk
func _gates() -> void:
	var stone := smat("#9aa3ad", {"rough": 0.9})
	var dark := smat("#6b7280", {"rough": 0.9})
	var wood := smat("#8a5a2b")
	var iron := smat("#3f3f46", {"rough": 0.4, "metal": 0.6})
	for g in layout.gates:
		var s: float = g.node + 0.5
		var root := Node3D.new()
		root.position = ML.pos(s)
		root.rotation.y = ML.angle(s)   # helyi +x = menetirány, helyi +z = kifelé
		add_child(root)
		for sz in [-1.0, 1.0]:
			Chars3D.box(root, 0.5, 2.3, 0.42, stone, Vector3(0, 1.15, sz * (ML.PATH_W + 0.05)))
			Chars3D.box(root, 0.6, 0.22, 0.52, dark, Vector3(0, 2.36, sz * (ML.PATH_W + 0.05)))
		Chars3D.box(root, 0.52, 0.42, ML.PATH_W * 2 + 0.6, stone, Vector3(0, 2.6, 0))
		Chars3D.box(root, 0.6, 0.16, ML.PATH_W * 2 + 0.9, dark, Vector3(0, 2.88, 0))
		var door := Node3D.new()
		root.add_child(door)
		for k in 6:
			Chars3D.box(door, 0.12, 2.2, 0.2, wood, Vector3(0, 1.1, -ML.PATH_W + 0.3 + k * (ML.PATH_W * 2 - 0.6) / 5.0))
		for yy in [0.55, 1.65]:
			Chars3D.box(door, 0.16, 0.14, ML.PATH_W * 2 - 0.3, iron, Vector3(0, yy, 0))
		Chars3D.cyl(door, 0.2, 0.2, 0.2, smat("#ffd43b", {"metal": 0.7, "rough": 0.3, "emit": "#ffb000", "emit_e": 0.4}), -0.12, 1.1, 0, 12, Vector3(0, 0, PI / 2))
		var lab := Label3D.new()
		lab.text = "🔒 %d+" % g.need
		lab.font = D.font
		lab.font_size = 110
		lab.pixel_size = 0.0085
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.outline_size = 26
		lab.outline_modulate = D.DARK
		lab.modulate = Color("#ffd43b")
		lab.position = Vector3(0, 3.7, 0)
		root.add_child(lab)
		gates[g.node] = {"root": root, "door": door, "label": lab}
		if g.open:
			_set_gate_open(g.node)


func _set_gate_open(id: int) -> void:
	var o: Dictionary = gates[id]
	o.door.visible = false
	o.label.text = "🔓"
	o.label.modulate = Color("#8ce99a")
	o.label.font_size = 80


func open_gate(id: int) -> void:
	if not gates.has(id):
		return
	var o: Dictionary = gates[id]
	var door: Node3D = o.door
	var tw := create_tween()
	tw.tween_property(door, "position:y", 0.25, 0.12)
	tw.tween_property(door, "position:y", 2.6, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(door, "scale", Vector3(1, 0.05, 1), 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _set_gate_open(id))
	shake = 0.9


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
	return [ang + 0.16, pr + z.d, p.y + z.h, Vector3(p.x, p.y + 0.6, p.z)]


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
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.25
	camera.position = Vector3(sin(cam_ang) * cam_rad, cam_y, cos(cam_ang) * cam_rad) + off
	camera.look_at(cam_look_pos + off, Vector3.UP)


func project(p: Vector3) -> Vector2:
	if camera.is_position_behind(p):
		return Vector2(-999, -999)
	return camera.unproject_position(p)
