class_name Board3D
extends Node3D
## 3D tábla: lebegő szigetek, hidak, mezők, díszletek, korona, bábuk, kamera.
## A játéklogika a régi 2D koordinátákban (1280×720 px) dolgozik; 1 egység = 40 px.

const S := 40.0
const TYPES := {
	"B": {"color": "#3b82f6", "icon": "+", "emoji": false},
	"R": {"color": "#ef4444", "icon": "−", "emoji": false},
	"E": {"color": "#a855f7", "icon": "?", "emoji": false},
	"S": {"color": "#f59e0b", "icon": "🛒", "emoji": true},
	"T": {"color": "#10b981", "icon": "🏁", "emoji": true},
	"J": {"color": "#06b6d4", "icon": "🚀", "emoji": true},
	"A": {"color": "#f472b6", "icon": "🤝", "emoji": true},
	"V": {"color": "#16a34a", "icon": "❗", "emoji": true},
}
const ZOOMS := {
	"far": {"h": 26.5, "d": 22.0, "lead": 0.0},
	"mid": {"h": 13.5, "d": 11.5, "lead": 1.2},
	"near": {"h": 9.5, "d": 8.2, "lead": 0.6},
	"close": {"h": 6.2, "d": 5.6, "lead": 0.45},
}
const PAWN_SCALE := 0.95

static var instance: Board3D = null

var board: Dictionary
var camera: Camera3D
var sun: DirectionalLight3D
var pawns := {}          # pid -> {group, model, base, ring, yaw, target_yaw, last, still, prev_h, allies:[]}
var crown: Node3D
var crown_light: OmniLight3D
var crown_glow: MeshInstance3D
var marker: Node3D
var tiles := {}          # node id -> MeshInstance3D
var hidden_box: Node3D
var animated: Array = [] # Callable(t)
var t := 0.0
var cam_mode := "overview"
var cam_pid := ""
var cam_point := Vector3.ZERO
var cam_zoom := "far"
var cam_speed := 3.0
var cam_pos := Vector3(0, 26.5, 22)
var cam_look_pos := Vector3(0, 0, 1)
var shake := 0.0
var env: Environment
var dusk := 0.0          # 0..1 – az utolsó körökben naplementés fények
var _dusk_now := 0.0


static func get_for(b: Dictionary) -> Board3D:
	if instance and is_instance_valid(instance) and instance.board == b:
		return instance
	if instance and is_instance_valid(instance):
		instance.queue_free()
	instance = Board3D.new()
	instance.build(b)
	return instance


static func w(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3((x - 640.0) / S, h / S, (y - 330.0) / S)


static func smat(hex: String, o := {}) -> StandardMaterial3D:
	var o2 := o.duplicate()
	if not o2.has("rough"):
		o2["rough"] = 0.8
	return Chars3D.mat(hex, o2)


func build(b: Dictionary) -> void:
	board = b
	name = "Board3D"
	_env()
	camera = Camera3D.new()
	camera.fov = 36
	camera.near = 0.5
	camera.far = 200
	add_child(camera)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 70.0
	sun.rotation_degrees = Vector3(-58, -32, 0)
	add_child(sun)
	_cloud_sea()
	for s in BoardLayout.ISLANDS:
		_island(s)
	_paths()
	_tiles()
	for d in board.deco:
		_deco(d[0], d[1], d[2], d[3])
	_crown()
	_marker()
	_far_rocks()
	_birds()


func _env() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#3b8fe0")
	sm.sky_horizon_color = Color("#cfe9ff")
	sm.ground_bottom_color = Color("#9ccdf5")
	sm.ground_horizon_color = Color("#cfe9ff")
	sm.sun_angle_max = 30
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("#cfe9ff")
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.08


func activate() -> void:
	Main.I.world_env.environment = env
	camera.make_current()


func set_dusk(on: bool) -> void:
	dusk = 1.0 if on else 0.0


func _cloud_sea() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float time_s = 0.0;
uniform vec3 deep : source_color = vec3(0.55, 0.76, 0.98);
uniform vec3 puff : source_color = vec3(1.0, 1.0, 1.0);
void fragment() {
	vec2 uv = UV * 6.0;
	float n1 = texture(noise_tex, uv * 0.6 + vec2(time_s * 0.004, time_s * 0.002)).r;
	float n2 = texture(noise_tex, uv * 1.3 - vec2(time_s * 0.006, 0.0)).r;
	float c = smoothstep(0.38, 0.75, n1 * 0.7 + n2 * 0.45);
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = mix(deep, puff, c * 0.9);
	ALPHA = 1.0;
	ALBEDO = mix(ALBEDO, vec3(0.81, 0.91, 1.0), smoothstep(0.35, 1.0, d));
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
	pm.size = Vector2(260, 260)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(0, -16, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	animated.append(func(tt): m.set_shader_parameter("time_s", tt))
	# puha felhőpamacsok a szigetek alatt
	var cm := smat("#ffffff", {"rough": 1.0})
	var rnd := BoardLayout.Seeded.new(11)
	for i in 34:
		var g := Node3D.new()
		g.position = Vector3(-38 + rnd.next() * 76, -9 - rnd.next() * 6, -20 + rnd.next() * 34)
		var sc := 1.5 + rnd.next() * 2.5
		for k in 4:
			var s := MeshInstance3D.new()
			s.mesh = Chars3D._sphere_mesh(1.0)
			s.material_override = cm
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s.position = Vector3((k - 1.5) * sc * 0.8, rnd.next() * 0.4 * sc, (rnd.next() - 0.5) * sc)
			s.scale = Vector3(sc, sc * 0.45, sc * 0.8) * (0.7 + rnd.next() * 0.5)
			g.add_child(s)
		add_child(g)
		var spd := 0.15 + rnd.next() * 0.25
		var x0 := g.position.x
		animated.append(func(tt): g.position.x = fposmod(x0 + tt * spd + 40.0, 80.0) - 40.0)


func _island(s: Dictionary) -> void:
	var c := w(s.x, s.y)
	var rx: float = s.rx / S
	var rz: float = s.ry / S
	var g := Node3D.new()
	g.position = Vector3(c.x, 0, c.z)
	add_child(g)
	# fű teteje
	var top := CylinderMesh.new()
	top.top_radius = 1.0
	top.bottom_radius = 1.0
	top.height = 0.3
	top.radial_segments = 48
	var tm := MeshInstance3D.new()
	tm.mesh = top
	tm.material_override = smat(s.top)
	tm.position.y = -0.15
	tm.scale = Vector3(rx, 1, rz)
	g.add_child(tm)
	# föld perem
	var rim := CylinderMesh.new()
	rim.top_radius = 1.0
	rim.bottom_radius = 0.93
	rim.height = 0.6
	rim.radial_segments = 48
	var rm := MeshInstance3D.new()
	rm.mesh = rim
	rm.material_override = smat(s.side)
	rm.position.y = -0.6
	rm.scale = Vector3(rx * 1.005, 1, rz * 1.005)
	g.add_child(rm)
	# sziklás alj (lefelé keskenyedő kúp + kiálló kövek)
	var depth: float = 2.2 + (rx + rz) * 0.35
	var rock := CylinderMesh.new()
	rock.top_radius = 0.93
	rock.bottom_radius = 0.08
	rock.height = depth
	rock.radial_segments = 14
	rock.rings = 3
	var km := MeshInstance3D.new()
	km.mesh = rock
	km.material_override = smat(s.rock, {"rough": 0.95})
	km.position.y = -0.9 - depth / 2
	km.scale = Vector3(rx, 1, rz)
	g.add_child(km)
	var rnd := BoardLayout.Seeded.new(int(s.x * 7 + s.y))
	for i in 10:
		var a := rnd.next() * TAU
		var r := 0.55 + rnd.next() * 0.35
		var bm := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3.ONE * (0.4 + rnd.next() * 0.6)
		bm.mesh = bx
		bm.material_override = km.material_override
		bm.position = Vector3(cos(a) * rx * r, -1.2 - rnd.next() * depth * 0.5, sin(a) * rz * r)
		bm.rotation = Vector3(rnd.next() * 3, rnd.next() * 3, rnd.next() * 3)
		g.add_child(bm)
	# fű-csomók a peremen
	var tuft := smat(s.top)
	for i in 18:
		var a := TAU * i / 18 + rnd.next() * 0.2
		var sm := MeshInstance3D.new()
		sm.mesh = Chars3D._sphere_mesh(0.22)
		sm.material_override = tuft
		sm.position = Vector3(cos(a) * rx * 0.99, -0.05, sin(a) * rz * 0.99)
		sm.scale = Vector3(1.4, 0.5, 1.0)
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(sm)
	# lassú lebegés
	var ph := rnd.next() * 6.0
	animated.append(func(tt): g.position.y = sin(tt * 0.5 + ph) * 0.06)


func _paths() -> void:
	var nodes: Array = board.nodes
	var dirt := smat("#d9b77e")
	var dirt_inner := smat("#e8b4a0")
	var plank_a := smat("#a0703c")
	var plank_b := smat("#8a5a2b")
	var rope := smat("#e9d8a6")
	for nd in nodes:
		for nid in nd.next:
			var to: Dictionary = nodes[nid]
			var a := w(nd.x, nd.y)
			var b := w(to.x, to.y)
			var mid := (a + b) / 2
			var len := a.distance_to(b)
			var ang := atan2(b.x - a.x, b.z - a.z)
			var on_land = BoardLayout.island_at((nd.x + to.x) / 2.0, (nd.y + to.y) / 2.0, -4)
			var g := Node3D.new()
			g.position = mid
			g.rotation.y = ang
			add_child(g)
			if on_land:
				var pm := MeshInstance3D.new()
				var bx := BoxMesh.new()
				bx.size = Vector3(0.55, 0.04, len)
				pm.mesh = bx
				pm.material_override = dirt_inner if (nd.inner != "" or to.inner != "") else dirt
				pm.position.y = 0.01
				g.add_child(pm)
			else:
				var n_pl := maxi(3, int(len / 0.32))
				for i in n_pl:
					var pl := MeshInstance3D.new()
					var bx := BoxMesh.new()
					bx.size = Vector3(0.7, 0.07, len / n_pl * 0.82)
					pl.mesh = bx
					pl.material_override = plank_a if i % 2 else plank_b
					pl.position = Vector3(0, -0.02 - (i % 2) * 0.012, -len / 2 + (i + 0.5) * (len / n_pl))
					pl.rotation.z = (i % 3 - 1) * 0.03
					g.add_child(pl)
				for sx in [-0.38, 0.38]:
					var r := MeshInstance3D.new()
					var cy := CylinderMesh.new()
					cy.top_radius = 0.02
					cy.bottom_radius = 0.02
					cy.height = len
					r.mesh = cy
					r.material_override = rope
					r.rotation.x = PI / 2
					r.position = Vector3(sx, 0.32, 0)
					g.add_child(r)
					for zz in [-len / 2, len / 2]:
						var post := MeshInstance3D.new()
						var pc := CylinderMesh.new()
						pc.top_radius = 0.04
						pc.bottom_radius = 0.05
						pc.height = 0.4
						post.mesh = pc
						post.material_override = plank_b
						post.position = Vector3(sx, 0.14, zz)
						g.add_child(post)


func _tiles() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.48
	disc.bottom_radius = 0.52
	disc.height = 0.16
	disc.radial_segments = 32
	var rim := Chars3D.torus(0.5, 0.045)
	var white := smat("#ffffff", {"rough": 0.4})
	for nd in board.nodes:
		var ty: Dictionary = TYPES.get(nd.type, TYPES.B)
		var p := w(nd.x, nd.y)
		var g := Node3D.new()
		g.position = Vector3(p.x, 0.08, p.z)
		add_child(g)
		var m := MeshInstance3D.new()
		m.mesh = disc
		m.material_override = smat(ty.color, {"rough": 0.45})
		g.add_child(m)
		var r := MeshInstance3D.new()
		r.mesh = rim
		r.material_override = white
		r.position.y = 0.075
		g.add_child(r)
		var lab := Label3D.new()
		lab.text = ty.icon
		lab.font = D.font
		lab.font_size = 128 if not ty.emoji else 96
		lab.pixel_size = 0.0068 if not ty.emoji else 0.0068
		lab.outline_size = 0 if ty.emoji else 18
		lab.outline_modulate = Chars3D.mat(ty.color).albedo_color.darkened(0.45)
		lab.rotation.x = -PI / 2
		lab.position.y = 0.085
		lab.double_sided = false
		lab.shaded = false
		g.add_child(lab)
		tiles[nd.id] = g


func flash_tile(id: int) -> void:
	var g: Node3D = tiles.get(id)
	if g == null:
		return
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3(1.35, 1.6, 1.35), 0.12)
	tw.tween_property(g, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ díszletek
func _add_static(kind: String, x: float, y: float, sc: float) -> Node3D:
	var g := Node3D.new()
	var p := w(x, y)
	g.position = Vector3(p.x, 0, p.z)
	g.scale = Vector3.ONE * sc
	g.rotation.y = fmod(x * 0.37 + y * 0.11, TAU)
	add_child(g)
	return g


func _deco(kind: String, x: float, y: float, sc: float) -> void:
	var g := _add_static(kind, x, y, sc)
	var M := Chars3D
	match kind:
		"tree":
			M.cyl(g, 0.08, 0.11, 0.6, smat("#8b5e34"), 0, 0.3, 0, 8)
			M.sphere(g, 0.42, smat("#3f9d45"), 0, 0.85, 0, 1, 0.9, 1)
			M.sphere(g, 0.3, smat("#56b85a"), 0.18, 1.05, 0.1)
			M.sphere(g, 0.26, smat("#4aa94f"), -0.2, 1.0, -0.08)
		"pine":
			M.cyl(g, 0.07, 0.09, 0.4, smat("#6b4a2b"), 0, 0.2, 0, 8)
			for i in 3:
				M.cone(g, 0.5 - i * 0.12, 0.6, smat("#2f7d3b" if i % 2 == 0 else "#38904a"), 0, 0.55 + i * 0.35, 0, 9)
		"flowers":
			var cols := ["#ff6b9a", "#ffd43b", "#ffffff", "#b197fc", "#ff922b"]
			for i in 7:
				var a := i * 2.4
				var r := 0.3 * (i / 7.0 + 0.3)
				M.cyl(g, 0.012, 0.012, 0.2, smat("#3f9d45"), cos(a) * r, 0.1, sin(a) * r, 5)
				M.sphere(g, 0.06, smat(cols[i % cols.size()]), cos(a) * r, 0.22, sin(a) * r)
		"mushroom":
			M.cyl(g, 0.09, 0.11, 0.3, smat("#fff1d6"), 0, 0.15, 0, 10)
			var cap := M.part(g, Chars3D._sphere_mesh(0.28, true), smat("#e03131", {"rough": 0.5}), Vector3(0, 0.28, 0), Vector3(1, 0.8, 1))
			for i in 5:
				var a := i * 1.3
				M.sphere(g, 0.045, smat("#ffffff"), cos(a) * 0.17, 0.42 - (i % 2) * 0.05, sin(a) * 0.17)
		"rock":
			M.sphere(g, 0.3, smat("#8a8580", {"rough": 1.0}), 0, 0.12, 0, 1.2, 0.7, 1)
			M.sphere(g, 0.18, smat("#9b968f", {"rough": 1.0}), 0.25, 0.08, 0.1, 1, 0.7, 1)
		"cactus":
			var cm := smat("#3f9d5a")
			M.cyl(g, 0.12, 0.13, 0.8, cm, 0, 0.4, 0, 10)
			M.sphere(g, 0.12, cm, 0, 0.8, 0)
			M.cyl(g, 0.07, 0.07, 0.3, cm, 0.2, 0.45, 0, 8, Vector3(0, 0, PI / 2))
			M.cyl(g, 0.07, 0.07, 0.25, cm, 0.32, 0.6, 0, 8)
			M.sphere(g, 0.07, cm, 0.32, 0.73, 0)
			M.sphere(g, 0.05, smat("#ff6b9a"), 0, 0.93, 0)
		"palm":
			for i in 6:
				M.cyl(g, 0.07, 0.08, 0.32, smat("#a0703c" if i % 2 else "#8b5e34"), i * 0.04, 0.16 + i * 0.3, 0, 8, Vector3(0, 0, -0.08))
			for i in 6:
				var a := TAU * i / 6
				M.part(g, Chars3D._sphere_mesh(0.3), smat("#3fae4a"), Vector3(0.2 + cos(a) * 0.32, 1.85, sin(a) * 0.32), Vector3(1.4, 0.15, 0.5), Vector3(0, -a, -0.35))
			M.sphere(g, 0.08, smat("#6b4a2b"), 0.22, 1.75, 0.08)
			M.sphere(g, 0.08, smat("#6b4a2b"), 0.14, 1.75, -0.06)
		"crystal":
			for i in 4:
				var h := 0.6 + (i % 2) * 0.5
				M.cone(g, 0.16, h, smat("#c4b5fd", {"rough": 0.15, "metal": 0.2, "emit": "#8b5cf6", "emit_e": 0.6}), cos(i * 1.7) * 0.2, h / 2, sin(i * 1.7) * 0.2, 6, Vector3(cos(i) * 0.25, 0, sin(i) * 0.25))
		"fountain":
			var stone := smat("#cbd5e1", {"rough": 0.6})
			var water := smat("#74c0fc", {"rough": 0.1, "emit": "#4dabf7", "emit_e": 0.3})
			M.cyl(g, 0.7, 0.75, 0.25, stone, 0, 0.12, 0, 24)
			M.cyl(g, 0.6, 0.6, 0.05, water, 0, 0.24, 0, 24)
			M.cyl(g, 0.1, 0.14, 0.7, stone, 0, 0.5, 0, 12)
			M.cyl(g, 0.32, 0.25, 0.1, stone, 0, 0.85, 0, 16)
			var jet := M.cyl(g, 0.05, 0.09, 0.5, water, 0, 1.1, 0, 10)
			animated.append(func(tt): jet.scale.y = 1.0 + sin(tt * 6.0) * 0.15)
		"castle":
			var wall := smat("#e9ecef", {"rough": 0.7})
			var roof := smat("#e64980")
			M.box(g, 1.6, 1.0, 1.0, wall, Vector3(0, 0.5, 0))
			for sx in [-0.85, 0.85]:
				M.cyl(g, 0.3, 0.32, 1.5, wall, sx, 0.75, 0, 16)
				M.cone(g, 0.38, 0.6, roof, sx, 1.8, 0, 16)
			M.cyl(g, 0.35, 0.38, 2.0, wall, 0, 1.0, -0.15, 16)
			M.cone(g, 0.45, 0.8, roof, 0, 2.4, -0.15, 16)
			M.box(g, 0.4, 0.55, 0.05, smat("#7a4a2a"), Vector3(0, 0.27, 0.51))
			for i in 4:
				M.box(g, 0.18, 0.15, 0.18, wall, Vector3(-0.6 + i * 0.4, 1.07, 0.4))
			M.cyl(g, 0.015, 0.015, 0.5, smat("#555555"), 0, 3.0, -0.15, 6)
			var flag := M.box(g, 0.32, 0.18, 0.02, smat("#ffd43b"), Vector3(0.16, 3.15, -0.15))
			animated.append(func(tt): flag.rotation.y = sin(tt * 3.0) * 0.3)
		"volcano":
			var rockm := smat("#5b4636", {"rough": 1.0})
			M.cyl(g, 0.45, 1.25, 1.4, rockm, 0, 0.7, 0, 14)
			var lava := smat("#ff6b00", {"emit": "#ff4500", "emit_e": 2.2, "rough": 0.4})
			M.cyl(g, 0.4, 0.4, 0.06, lava, 0, 1.4, 0, 14)
			for i in 5:
				var a := TAU * i / 5 + 0.3
				M.part(g, Chars3D._sphere_mesh(0.08), lava, Vector3(cos(a) * 0.62, 1.15 - (i % 2) * 0.25, sin(a) * 0.62), Vector3(1, 2.5, 1))
			var smoke: Array = []
			for i in 4:
				var s := M.sphere(g, 0.25, smat("#9ca3af", {"rough": 1.0}), 0, 1.8 + i * 0.6, 0)
				smoke.append(s)
			var light := OmniLight3D.new()
			light.light_color = Color("#ff7b29")
			light.light_energy = 2.0
			light.omni_range = 3.5
			light.position = Vector3(0, 1.8, 0)
			g.add_child(light)
			animated.append(func(tt):
				for i in smoke.size():
					var k := fmod(tt * 0.35 + i * 0.25, 1.0)
					smoke[i].position = Vector3(sin(k * 6.0 + i) * 0.2, 1.6 + k * 2.2, 0)
					smoke[i].scale = Vector3.ONE * (0.6 + k * 1.6) * (1.0 - k * 0.5)
				light.light_energy = 1.6 + sin(tt * 7.0) * 0.4)
		"tent":
			M.cone(g, 0.9, 1.2, smat("#ff922b"), 0, 0.6, 0, 6)
			M.cone(g, 0.92, 0.3, smat("#fff3bf"), 0, 0.15, 0, 6)
			M.box(g, 0.3, 0.5, 0.05, smat("#7a4a2a"), Vector3(0, 0.25, 0.72))
			M.cyl(g, 0.02, 0.02, 0.5, smat("#555555"), 0, 1.4, 0, 6)
		"chest":
			M.box(g, 0.7, 0.4, 0.45, smat("#a0703c"), Vector3(0, 0.2, 0))
			M.part(g, Chars3D._sphere_mesh(0.36, true), smat("#8a5a2b"), Vector3(0, 0.4, 0), Vector3(1.0, 0.5, 0.65))
			M.box(g, 0.72, 0.06, 0.47, smat("#ffd43b", {"metal": 0.6, "rough": 0.3}), Vector3(0, 0.38, 0))
			M.box(g, 0.08, 0.12, 0.05, smat("#ffd43b", {"metal": 0.6, "rough": 0.3}), Vector3(0, 0.33, 0.24))


func _far_rocks() -> void:
	var rnd := BoardLayout.Seeded.new(23)
	var rm := smat("#7c6f64", {"rough": 1.0})
	var gm := smat("#7cc552")
	for i in 14:
		var g := Node3D.new()
		var a := rnd.next() * TAU
		var d := 26.0 + rnd.next() * 14.0
		g.position = Vector3(cos(a) * d, -2.0 - rnd.next() * 5.0, -6 + sin(a) * d * 0.6)
		var sc := 0.6 + rnd.next() * 1.4
		g.scale = Vector3.ONE * sc
		Chars3D.cyl(g, 1.0, 0.1, 2.2, rm, 0, -1.1, 0, 7)
		Chars3D.cyl(g, 1.02, 1.02, 0.2, gm, 0, 0.05, 0, 14)
		add_child(g)
		var ph := rnd.next() * 6.0
		var y0 := g.position.y
		animated.append(func(tt): g.position.y = y0 + sin(tt * 0.4 + ph) * 0.3)


func _birds() -> void:
	var bm := smat("#ffffff", {"rough": 0.6})
	for i in 5:
		var g := Node3D.new()
		add_child(g)
		var wl := Chars3D.box(g, 0.5, 0.02, 0.14, bm, Vector3(-0.25, 0, 0))
		var wr := Chars3D.box(g, 0.5, 0.02, 0.14, bm, Vector3(0.25, 0, 0))
		var r := 12.0 + i * 3.0
		var spd := 0.12 + i * 0.03
		var ph := i * 1.7
		animated.append(func(tt):
			var a = tt * spd + ph
			g.position = Vector3(cos(a) * r, 6.0 + sin(tt * 0.7 + i) * 0.8, sin(a) * r * 0.55)
			g.rotation.y = -a
			var f := sin(tt * 9.0 + i) * 0.5
			wl.rotation.z = f
			wr.rotation.z = -f)


func _crown() -> void:
	crown = Node3D.new()
	add_child(crown)
	var gold := smat("#ffd43b", {"metal": 0.85, "rough": 0.25, "emit": "#ffb000", "emit_e": 0.35})
	var band := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.42
	cy.bottom_radius = 0.38
	cy.height = 0.3
	cy.radial_segments = 24
	band.mesh = cy
	band.material_override = gold
	crown.add_child(band)
	var gem_cols := ["#e11d48", "#22d3ee", "#51cf66", "#b197fc", "#ff922b"]
	for i in 5:
		var a := TAU * i / 5
		Chars3D.cone(crown, 0.13, 0.42, gold, cos(a) * 0.36, 0.34, sin(a) * 0.36, 8)
		Chars3D.sphere(crown, 0.06, gold, cos(a) * 0.36, 0.58, sin(a) * 0.36)
		Chars3D.sphere(crown, 0.07, smat(gem_cols[i], {"rough": 0.1, "emit": gem_cols[i], "emit_e": 0.8}), cos(a + 0.63) * 0.41, 0.0, sin(a + 0.63) * 0.41)
	crown.scale = Vector3.ONE * 1.15
	crown_light = OmniLight3D.new()
	crown_light.light_color = Color("#ffe066")
	crown_light.light_energy = 0.0
	crown_light.omni_range = 4.0
	add_child(crown_light)
	crown_glow = MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.9
	gm.bottom_radius = 0.9
	gm.height = 0.02
	crown_glow.mesh = gm
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(1, 0.88, 0.4, 0.45)
	crown_glow.material_override = glow_mat
	crown_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crown_glow)


func _marker() -> void:
	marker = Node3D.new()
	add_child(marker)
	Chars3D.cone(marker, 0.22, 0.4, smat("#ffd43b", {"emit": "#ffb000", "emit_e": 1.2}), 0, 0, 0, 4, Vector3(PI, 0, 0))


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
		"last": null, "still": 0.0, "prev_h": 0.0, "allies": [], "ally_ids": []}
	pawns[p.pid] = o
	return o


func emote(pid: String, type: String) -> void:
	if pawns.has(pid):
		pawns[pid].model.emote(type)


func _sync_allies(o: Dictionary, p) -> void:
	if o.ally_ids == p.allies:
		return
	for a in o.allies:
		a.queue_free()
	o.allies = []
	for id in p.allies:
		var m := Chars3D.build(id)
		m.scale = Vector3.ONE * 0.42
		add_child(m)
		o.allies.append(m)
	o.ally_ids = p.allies.duplicate()


## st = {pawns: [{p, x, y, h, current}], crown: {x, y, h} | null}
func render(st: Dictionary, dt: float) -> void:
	t += dt
	var seen := {}
	var cur_pos = null
	for d in st.pawns:
		var o := pawn_for(d.p)
		seen[d.p.pid] = true
		_animate_pawn(o, d, dt)
		_sync_allies(o, d.p)
		if d.current:
			cur_pos = o.group.position
	for pid in pawns.keys():
		if not seen.has(pid):
			pawns[pid].group.queue_free()
			for a in pawns[pid].allies:
				a.queue_free()
			pawns.erase(pid)
	_update_camera(dt)
	marker.visible = cur_pos != null
	if cur_pos != null:
		marker.position = cur_pos + Vector3(0, 1.9 + sin(t * 5.0) * 0.1, 0)
		marker.rotation.y = t * 2.5
	var cr = st.get("crown")
	if cr:
		var p := w(cr.x, cr.y, cr.h)
		crown.visible = true
		crown_light.light_energy = 2.5
		crown.position = p + Vector3(0, 0.9 + sin(t * 3.0) * 0.12, 0)
		crown.rotation.y = t * 1.4
		crown_light.position = p + Vector3(0, 1.2, 0)
		crown_glow.visible = cr.h < 5
		crown_glow.position = Vector3(p.x, 0.18, p.z)
		(crown_glow.material_override as StandardMaterial3D).albedo_color.a = 0.35 + sin(t * 4.0) * 0.2
		crown_glow.scale = Vector3.ONE * (1.0 + sin(t * 4.0) * 0.08)
	else:
		crown.visible = false
		crown_glow.visible = false
		crown_light.light_energy = 0.0
	for f in animated:
		f.call(t)
	# naplemente az utolsó körökben
	_dusk_now = move_toward(_dusk_now, dusk, dt * 0.4)
	sun.light_color = Color("#fff1d6").lerp(Color("#ff9a5a"), _dusk_now)
	sun.rotation_degrees.x = lerp(-58.0, -28.0, _dusk_now)
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	sm.sky_top_color = Color("#3b8fe0").lerp(Color("#5b3a8f"), _dusk_now)
	sm.sky_horizon_color = Color("#cfe9ff").lerp(Color("#ffb37a"), _dusk_now)
	sm.ground_horizon_color = sm.sky_horizon_color
	env.fog_light_color = sm.sky_horizon_color


func _animate_pawn(o: Dictionary, d: Dictionary, dt: float) -> void:
	var p := w(d.x, d.y, d.h)
	if o.last != null:
		var dv: Vector3 = p - o.last
		if Vector2(dv.x, dv.z).length() > 0.004:
			o.target_yaw = atan2(dv.x, dv.z)
			o.still = 0.0
		else:
			o.still += dt
			if o.still > 0.5:
				o.target_yaw = 0.0
	o.last = p
	o.yaw += angle_difference(o.yaw, o.target_yaw) * min(1.0, dt * 10.0)
	var model: Chars3D.CharModel = o.model
	if o.prev_h > 0.5 and d.h <= 0.5:
		model.land = 1.0
	o.prev_h = d.h
	model.airborne = 1.0 if d.h > 0.5 else 0.0
	var a := model.animate(dt)
	o.group.position = p + Vector3(0, a.y, 0)
	model.rotation.y = o.yaw + a.spin
	model.rotation.x = a.tilt
	var cur: bool = d.current
	model.scale = Vector3.ONE * PAWN_SCALE * (1.12 if cur else 1.0)
	o.ring.visible = cur
	if cur:
		o.ring.scale = Vector3.ONE * (1.0 + sin(t * 6.0) * 0.08)
	# szövetségesek: libasorban követik
	var back := Vector3(-sin(o.yaw), 0, -cos(o.yaw))
	for i in o.allies.size():
		var am: Chars3D.CharModel = o.allies[i]
		var target: Vector3 = o.group.position + back * (0.55 + i * 0.38) + Vector3((i % 2) * 0.3 - 0.15, 0, 0)
		am.position = am.position.lerp(target, min(1.0, dt * 6.0)) if am.position != Vector3.ZERO else target
		am.position.y = max(0.0, o.group.position.y - 0.0) + abs(sin(t * 6.0 + i)) * 0.06
		am.rotation.y = o.yaw
		am.animate(dt)


# ------------------------------------------------------------------ kamera
func cam_overview(speed := 2.2) -> void:
	cam_mode = "overview"
	cam_speed = speed


func cam_follow(pid: String, zoom := "near", speed := 3.0) -> void:
	cam_mode = "follow"
	cam_pid = pid
	cam_zoom = zoom
	cam_speed = speed


func cam_look(x: float, y: float, zoom := "mid", speed := 3.0) -> void:
	cam_mode = "point"
	cam_point = w(x, y)
	cam_zoom = zoom
	cam_speed = speed


func cam_snap() -> void:
	var d := _cam_target()
	cam_pos = d[0]
	cam_look_pos = d[1]


func _cam_target() -> Array:
	var p = null
	if cam_mode == "follow" and pawns.has(cam_pid):
		p = pawns[cam_pid].group.position
	elif cam_mode == "point":
		p = cam_point
	if p == null:
		return [Vector3(0, ZOOMS.far.h, ZOOMS.far.d), Vector3(0, 0, 1)]
	var z: Dictionary = ZOOMS.get(cam_zoom, ZOOMS.near)
	var look := Vector3(clamp(p.x, -13.0, 13.0), 0.4, clamp(p.z - z.lead, -7.0, 6.5))
	return [look + Vector3(0, z.h, z.d), look]


func _update_camera(dt: float) -> void:
	if cam_mode != "manual":
		var d := _cam_target()
		var k := 1.0 - exp(-dt * cam_speed)
		cam_pos = cam_pos.lerp(d[0], k)
		cam_look_pos = cam_look_pos.lerp(d[1], k)
	shake = max(0.0, shake - dt * 2.5)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.25
	camera.position = cam_pos + off
	camera.look_at(cam_look_pos + off, Vector3.UP)


func project(x: float, y: float, h := 0.0) -> Vector2:
	var p := w(x, y, h)
	if camera.is_position_behind(p):
		return Vector2(-999, -999)
	return camera.unproject_position(p)
