class_name Highway3D
extends Node3D
## Óceánsztráda – a 3D világ: hosszú, egyenes sztráda az óceán fölött, nézőcsoportok, delfinek,
## felvonóhíd (100), jelzőlámpás kapu (200), célkapu (351), UFO, rakéta, dobókockák, kamera.
## Csak látvány: a játékállapotot a HighwayScene tartja, ide minden képkockán átadja (render()).

const HL = preload("res://scripts/world/highway_layout.gd")
const K = preload("res://scripts/minigames/mg_kit.gd")
const W = preload("res://scripts/minigames/presents_world.gd")

const OCEAN_Y := -14.0
const PAWN_SC := 0.95
const DIE := 0.42
const MAX_DICE := 16
const SLOT_COLORS := ["#2f80ff", "#f03e3e", "#2fb344", "#ffd43b", "#ff8c1a", "#9b5de5", "#13b5c8", "#f0609e"]

static var instance: Highway3D

var env: Environment
var camera: Camera3D
var sun: DirectionalLight3D
var t := 0.0
var pawns := {}              # pid -> {group, m, arms, face, disc, yaw, pose, pose_t0, pose_dur, last}
var crowds: Array = []       # [{node, s, figs, mood, mood_t0}]
var dolphins: Array = []     # [{node, t0, dur, a, b}]
var next_dolphin := 2.0
var dice_nodes: Array = []   # [{root, cube, labels, mat}]
var ufo: Node3D
var beam: MeshInstance3D
var rocket: Node3D
var flame: Node3D
var bridge_leaf: Node3D
var bridge_open := 0.0       # 0 = felhúzva (zárva), 1 = leengedve
var bridge_target := 0.0
var gate_boom: Node3D
var gate_open := 0.0
var gate_target := 0.0
var gate_lamps: Array = []   # [piros anyag, zöld anyag]
var gate_light := ""         # "", "red", "green", "blink"
var final_doors: Array = []
var final_open := 0.0
var final_target := 0.0
var marker: Node3D
var cam_look := Vector3.ZERO
var cam_off := Vector3(4.5, 5.5, 10.0)     # az út keretében (x jobbra, z hátra); cam_yaw forgatja
var cam_look_t := Vector3.ZERO
var cam_off_t := Vector3(4.5, 5.5, 10.0)
var cam_yaw := 0.0                          # a kamera iránya (az út iránya, lassan követi)
var cam_yaw_t := 0.0
var cam_s := 0.0                            # merre néz a kamera az út mentén (delfinekhez)
var cam_speed := 2.5
var shake := 0.0
var puffs: Array = []        # füstpamacsok: [{node, t0, dur, v}]


static func get_world() -> Highway3D:
	if instance and is_instance_valid(instance):
		return instance
	instance = Highway3D.new()
	instance.build()
	return instance


static func smat(hex: String, o := {}) -> StandardMaterial3D:
	var o2 := o.duplicate()
	if not o2.has("rough"):
		o2["rough"] = 0.7
	return Chars3D.mat(hex, o2)


func build() -> void:
	_env()
	_ocean()
	_islands()
	_clouds()
	_road()
	_bridge()
	_light_gate()
	_final_gate()
	_start_arch()
	_crowds()
	_dolphins()
	_vehicles()
	_dice()
	marker = Node3D.new()
	add_child(marker)
	Chars3D.cone(marker, 0.22, 0.4, Chars3D.mat("#ffd43b", {"emit": "#ffb000", "emit_e": 1.5}), 0, 0, 0, 4, Vector3(PI, 0, 0))
	camera = Camera3D.new()
	camera.fov = 48
	camera.far = 3000
	add_child(camera)
	cam_look = HL.pos(0) + Vector3(0, 1, -4)
	cam_look_t = cam_look
	camera.position = cam_look + cam_off


## új játék: a figurák újraépülnek (más figurát választhattak), a kapuk zárva
func reset_game() -> void:
	for pid in pawns:
		(pawns[pid].group as Node3D).queue_free()
	pawns.clear()
	bridge_target = 0.0
	bridge_open = 0.0
	gate_target = 0.0
	gate_open = 0.0
	gate_light = ""
	final_target = 0.0
	final_open = 0.0


func activate() -> void:
	Main.I.world_env.environment = env
	camera.make_current()


# ------------------------------------------------------------------ táj
func _env() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2a78e4")
	sm.sky_horizon_color = Color("#cdeeff")
	sm.ground_bottom_color = Color("#155aa8")
	sm.ground_horizon_color = Color("#cdeeff")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#bfe1f7")
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("#fff3dc")
	sun.shadow_enabled = true
	# a távolabbi figurák árnyéka fokozatosan halványul
	sun.directional_shadow_max_distance = 42.0
	sun.directional_shadow_fade_start = 0.45
	add_child(sun)


func _ocean() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	sea.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float w = sin(wp.x * 0.35 + TIME * 1.1) * sin(wp.z * 0.28 - TIME * 0.9) + 0.5 * sin((wp.x + wp.z) * 0.9 + TIME * 2.0);
	vec3 deep = vec3(0.04, 0.32, 0.72);
	vec3 light = vec3(0.16, 0.55, 0.92);
	ALBEDO = mix(deep, light, clamp(w * 0.35 + 0.4, 0.0, 1.0));
	float sp = smoothstep(1.05, 1.4, w);
	EMISSION = vec3(sp) * 0.35;
	ROUGHNESS = 0.18;
	METALLIC = 0.1;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	sea.material_override = m
	sea.position = Vector3(0, OCEAN_Y, -260)
	add_child(sea)


## Szigetek az út két oldalán: [mező, oldaltávolság (+ = jobbra), sugár]. Amelyik túl közel esne
## bármelyik útághoz (a kanyarok miatt), az kimarad.
const ISLES := [[-6, -48, 16], [20, 46, 14], [40, -72, 22], [70, 64, 24], [104, -60, 30], [128, 70, 18],
	[166, -64, 22], [196, 62, 26], [232, -66, 30], [262, 58, 20], [290, -70, 34], [316, 66, 24],
	[350, -60, 40], [372, 40, 30], [420, -10, 60], [-30, 70, 18], [180, 150, 44], [300, -160, 44]]
## Felhők: [mező, oldaltávolság, magasság, méret]
const CLOUDS := [[-4, 36, 18, 6.0], [30, -40, 24, 8.0], [70, 50, 30, 9.0], [110, -46, 20, 7.0], [150, 44, 26, 8.0],
	[200, -56, 34, 10.0], [250, 52, 40, 12.0], [300, -44, 50, 16.0], [180, 26, 9, 4.0], [330, -30, 8, 4.0], [20, 70, 14, 6.0],
	[380, 0, 46, 14.0]]


## Világpont az út keretében: s. mező, x oldalra (+ = jobbra), y fel, z hátra (helyi).
static func at(s: float, x := 0.0, y := 0.0, z := 0.0) -> Vector3:
	return HL.xf(s) * Vector3(x, y, z)


func _islands() -> void:
	var shallow := smat("#3fd6c6", {"rough": 0.4})
	var sand := smat("#f5dfa0", {"rough": 0.9})
	var g1 := smat("#3fa34d")
	var g2 := smat("#2f7d3a")
	var trunk := smat("#8a5a2b")
	for k in ISLES.size():
		var it: Array = ISLES[k]
		var r: float = it[2]
		var c := at(float(it[0]), float(it[1]))
		if HL.road_dist(c) < r * 1.6 + 8.0:
			continue
		var x := c.x
		var z := c.z
		Chars3D.cyl(self, r * 1.5, r * 1.6, 0.3, shallow, x, OCEAN_Y + 0.05, z, 22)
		Chars3D.cyl(self, r * 1.05, r * 1.15, 1.4, sand, x, OCEAN_Y + 0.6, z, 18)
		for j in 1 + k % 3:
			var off := Vector2(cos(k * 2.1 + j * 2.4), sin(k * 1.7 + j * 2.4)) * r * (0.0 if j == 0 else 0.45)
			var h: float = r * (0.9 - j * 0.22)
			Chars3D.lcone(self, r * (0.8 - j * 0.16), h, g1 if j % 2 == 0 else g2, x + off.x, OCEAN_Y + 1.2 + h / 2.0, z + off.y, 7)
		# pár pálma a parton
		for j in 3:
			var a := k * 1.3 + j * 2.1
			var px := x + cos(a) * r * 0.95
			var pz := z + sin(a) * r * 0.95
			Chars3D.cyl(self, 0.35, 0.5, 6.0, trunk, px, OCEAN_Y + 4.0, pz, 6)
			for q in 5:
				Chars3D.box(self, 3.2, 0.15, 0.9, g1, Vector3(px + cos(q * 1.26) * 1.4, OCEAN_Y + 7.0, pz + sin(q * 1.26) * 1.4), Vector3(0, -q * 1.26, -0.4))


func _clouds() -> void:
	var cw := smat("#ffffff", {"rough": 1.0})
	var cw2 := smat("#eef6fc", {"rough": 1.0})
	for k in CLOUDS.size():
		var sp: Array = CLOUDS[k]
		var r: float = sp[3]
		var c := at(float(sp[0]), float(sp[1]), float(sp[2]))
		# alacsony felhő ne lógjon bele az útba
		if c.y < 16.0 and HL.road_dist(c) < r * 1.8 + 6.0:
			continue
		var g := Node3D.new()
		g.position = c
		add_child(g)
		for q in [[0, 0, 0, 1.0], [-0.9, -0.15, 0.2, 0.75], [0.95, -0.1, -0.1, 0.8], [0.35, 0.35, 0.25, 0.7], [-1.6, -0.3, -0.2, 0.5], [1.6, -0.3, 0.3, 0.5]]:
			Chars3D.lsphere(g, r * q[3], cw if k % 2 == 0 else cw2, q[0] * r, q[1] * r, q[2] * r, 1.0, 0.7, 0.9, 9, 6)


func _mm(mesh: Mesh, mat: Material, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)


## Rögzítőpont az út keretében (s. mező): a gyerekei helyi koordinátában épülnek (x jobbra, -z előre).
func _anchor(s: float, x := 0.0) -> Node3D:
	var n := Node3D.new()
	n.transform = HL.xf(s) * Transform3D(Basis(), Vector3(x, 0, 0))
	add_child(n)
	return n


# ------------------------------------------------------------------ út
const S_START := -7.0            # az úttest eleje (a rajtkapu mögött)
const S_END := HL.GOAL + 12.0    # vége (az ünnepi tér után)
const GAP_A := HL.CP_BRIDGE + 0.45            # a felvonóhíd rése az úttestben
const GAP_B := HL.CP_BRIDGE + 0.55 + 0.95 / HL.SP
const EXT_STEP := 0.25           # kihúzás felbontása (mező)
const CHUNK := 24.0              # ennyi mezőnként külön háló (a kamerán kívülieket a motor kihagyja)
const PIER_EVERY := 16           # pillérpár ennyi mezőnként


## Profil tükrözése a középvonalra (a körüljárás is megfordul, hogy a normális kifelé nézzen).
static func _mirror(prof: Array) -> Array:
	var out: Array = []
	for i in range(prof.size() - 1, -1, -1):
		var p: Vector2 = prof[i]
		out.append(Vector2(-p.x, p.y))
	return out


## Görbe menti kihúzás az s0..s1 szakaszon. A prof (x, y) pontsor az út keretében; a felület
## normálisa minden szakaszon a haladási irány bal keze felé néz (a felső lapot balról jobbra kell
## megadni, az oldalakat az óramutató járása szerint).
func _extrude(prof: Array, s0: float, s1: float, m: Material) -> void:
	var a := s0
	while a < s1 - 0.001:
		var b := minf(a + CHUNK, s1)
		_extrude_chunk(prof, a, b, m)
		a = b


func _extrude_chunk(prof: Array, s0: float, s1: float, m: Material) -> void:
	var steps := maxi(1, ceili((s1 - s0) / EXT_STEP))
	var rings: Array = []
	for i in steps + 1:
		rings.append(HL.xf(lerpf(s0, s1, float(i) / steps)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in prof.size() - 1:
		var pa: Vector2 = prof[j]
		var pb: Vector2 = prof[j + 1]
		var d := pb - pa
		var nl := Vector3(-d.y, d.x, 0.0).normalized()
		var la := Vector3(pa.x, pa.y, 0.0)
		var lb := Vector3(pb.x, pb.y, 0.0)
		for i in steps:
			var t0: Transform3D = rings[i]
			var t1: Transform3D = rings[i + 1]
			var n0 := t0.basis * nl
			var n1 := t1.basis * nl
			# a Godot elülső lapja az óramutató járása szerinti
			st.set_normal(n0)
			st.add_vertex(t0 * la)
			st.set_normal(n1)
			st.add_vertex(t1 * la)
			st.set_normal(n1)
			st.add_vertex(t1 * lb)
			st.set_normal(n0)
			st.add_vertex(t0 * la)
			st.set_normal(n1)
			st.add_vertex(t1 * lb)
			st.set_normal(n0)
			st.add_vertex(t0 * lb)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


## A rés két oldalán (a felvonóhídnál megszakad az úttest).
func _extrude2(prof: Array, m: Material, s0 := S_START, s1 := S_END) -> void:
	_extrude(prof, s0, GAP_A, m)
	_extrude(prof, GAP_B, s1, m)


func _road() -> void:
	var hw := HL.ROAD_W / 2.0
	var asphalt := smat("#5a6070", {"rough": 0.85})
	var concrete := smat("#d9dde6", {"rough": 0.6})
	var under := smat("#b4bccb", {"rough": 0.7})
	var white := smat("#ffffff", {"rough": 0.5})
	var rail := smat("#f1f3f5", {"rough": 0.5})
	var red := smat("#e03131", {"rough": 0.5})
	# úttest (felső lap + oldalak), alatta a betonlemez és a két hosszanti tartógerenda
	_extrude2([Vector2(-hw, -0.5), Vector2(-hw, 0.0), Vector2(hw, 0.0), Vector2(hw, -0.5)], asphalt)
	var cw := hw + 0.3
	_extrude2([Vector2(-cw, -1.2), Vector2(-cw, -0.5), Vector2(cw, -0.5), Vector2(cw, -1.2), Vector2(-cw, -1.2)], concrete)
	for gx in [-2.4, 2.4]:
		# teteje a lemez alatt rejtve: jobb oldal le, alja, bal oldal fel
		_extrude2([Vector2(gx + 0.45, -1.2), Vector2(gx + 0.45, -2.2), Vector2(gx - 0.45, -2.2), Vector2(gx - 0.45, -1.2)], under)
	# szélső fehér vonal és folyamatos korlát mindkét oldalon (a kanyarokat hézag nélkül követi)
	var edge := [Vector2(hw - 0.37, 0.006), Vector2(hw - 0.23, 0.006)]
	var wall := [Vector2(hw - 0.04, 0.0), Vector2(hw - 0.04, 0.42), Vector2(hw + 0.14, 0.42), Vector2(hw + 0.14, -0.5)]
	var cap := [Vector2(hw - 0.06, 0.42), Vector2(hw - 0.06, 0.5), Vector2(hw + 0.16, 0.5), Vector2(hw + 0.16, 0.42)]
	for prof in [edge, _mirror(edge)]:
		_extrude2(prof, white)
	for prof in [wall, _mirror(wall)]:
		_extrude2(prof, rail)
	for prof in [cap, _mirror(cap)]:
		_extrude2(prof, red)
	# az úttest két vége
	for s in [S_START, S_END]:
		var e := _anchor(s)
		Chars3D.box(e, cw * 2.0, 1.2, 0.04, concrete, Vector3(0, -0.6, 0))
	# szaggatott felezővonalak
	var dash := BoxMesh.new()
	dash.size = Vector3(0.1, 0.02, 1.2)
	var xf: Array = []
	var s := S_START + 1.0
	while s < S_END - 1.0:
		if s < GAP_A - 0.5 or s > GAP_B + 0.5:
			for lx in [-hw / 2.0, 0.0, hw / 2.0]:
				xf.append(HL.xf(s) * Transform3D(Basis(), Vector3(lx, 0.01, 0)))
		s += 2.0
	_mm(dash, white, xf)
	# mezőhatárok: vékony keresztcsíkok, szélükön színes jelzőkockák
	var line := BoxMesh.new()
	line.size = Vector3(HL.ROAD_W - 0.8, 0.012, 0.05)
	var cube := BoxMesh.new()
	cube.size = Vector3(0.22, 0.22, 0.22)
	var lines: Array = []
	var cubes_a: Array = []
	var cubes_b: Array = []
	for i in range(0, HL.GOAL + 1):
		var t := HL.xf(i)
		if i != HL.CP_BRIDGE:
			lines.append(HL.xf(i + 0.5) * Transform3D(Basis(), Vector3(0, 0.006, 0)))
		var tf_l := t * Transform3D(Basis(), Vector3(-hw + 0.1, 0.12, 0))
		var tf_r := t * Transform3D(Basis(), Vector3(hw - 0.1, 0.12, 0))
		(cubes_a if i % 2 == 0 else cubes_b).append_array([tf_l, tf_r])
	_mm(line, smat("#ffffff", {"alpha": 0.35, "unshaded": true}), lines)
	_mm(cube, smat("#ffd43b", {"rough": 0.4}), cubes_a)
	_mm(cube, smat("#4dabf7", {"rough": 0.4}), cubes_b)
	_piers()
	_special_tiles()
	# minden 10. mező száma az út szélén
	for i in range(10, HL.GOAL, 10):
		if HL.specials().has(i):
			continue
		var lab := _flat_label(str(i), 80, 0.008)
		lab.modulate = Color(1, 1, 1, 0.85)
		lab.transform = HL.xf(i) * Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(-hw + 0.9, 0.02, 0))
		add_child(lab)


## Pillérpárok a hullámokba: fejgerenda a tartógerendák alatt, két oszlop, hab a víz színén.
## Az út irányába forgatva, így a kanyarokban is pontosan az úttest alatt állnak.
func _piers() -> void:
	var col_h := -2.7 - (OCEAN_Y - 0.5)
	var pil := CylinderMesh.new()
	pil.top_radius = 0.55
	pil.bottom_radius = 0.8
	pil.height = col_h
	pil.radial_segments = 10
	var head := BoxMesh.new()
	head.size = Vector3(HL.ROAD_W - 0.6, 0.5, 1.3)
	var brace := BoxMesh.new()
	brace.size = Vector3(0.35, 0.35, col_h * 0.55)
	var fm := CylinderMesh.new()
	fm.top_radius = 1.5
	fm.bottom_radius = 1.5
	fm.height = 0.1
	fm.radial_segments = 14
	var pils: Array = []
	var heads: Array = []
	var braces: Array = []
	var foam: Array = []
	var s := 0
	while s < S_END:
		if absf(s - HL.CP_BRIDGE) > 2.0:
			var t := HL.xf(s)
			heads.append(t * Transform3D(Basis(), Vector3(0, -2.45, 0)))
			for sx in [-1.0, 1.0]:
				var x: float = sx * 2.4
				pils.append(t * Transform3D(Basis(), Vector3(x, -2.7 - col_h / 2.0, 0)))
				foam.append(t * Transform3D(Basis(), Vector3(x, OCEAN_Y + 0.05, 0)))
			# keresztmerevítő a két oszlop között (X alakban)
			for k in [-1.0, 1.0]:
				braces.append(t * Transform3D(Basis(Vector3.FORWARD, k * 0.52) * Basis(Vector3.RIGHT, PI / 2), Vector3(0, -2.7 - col_h * 0.42, 0)))
		s += PIER_EVERY
	var conc := smat("#c9cfdb", {"rough": 0.6})
	_mm(pil, conc, pils)
	_mm(head, smat("#b4bccb", {"rough": 0.6}), heads)
	_mm(brace, conc, braces)
	_mm(fm, smat("#ffffff", {"alpha": 0.7, "unshaded": true}), foam)


func _flat_label(text: String, size: int, px: float) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font = D.font
	lab.font_size = size
	lab.pixel_size = px
	# távolról úgyis olvashatatlan: ott nem rajzoljuk
	lab.visibility_range_end = 130.0
	lab.visibility_range_end_margin = 20.0
	lab.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return lab


# ------------------------------------------------------------------ különleges mezők
## Színes lap felirattal, mellette mindkét oldalon a típus jele: nyíl (hátszél), figyelmeztető háromszög
## (szembeszél), dobókocka (kockamezők), arany keret és dupla nyíl (felzárkózó), világító gyűrű (UFO),
## rakéta, keresztbe tett kardok (párbaj). Egy típus minden darabja egy MultiMeshben.
func _special_tiles() -> void:
	var hw := HL.ROAD_W / 2.0
	var tile := BoxMesh.new()
	tile.size = Vector3(HL.ROAD_W - 0.7, 0.03, HL.SP * 0.86)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.14, 0.03, 0.62)
	var tri := _tri_mesh(0.42)
	var small_tri := _tri_mesh(0.2)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.08, 0.03, 0.26)
	var dot := BoxMesh.new()
	dot.size = Vector3(0.08, 0.03, 0.08)
	var face := BoxMesh.new()
	face.size = Vector3(0.66, 0.03, 0.66)
	var pip := CylinderMesh.new()
	pip.top_radius = 0.07
	pip.bottom_radius = 0.07
	pip.height = 0.02
	pip.radial_segments = 8
	pip.rings = 1
	var frame_l := BoxMesh.new()
	frame_l.size = Vector3(0.12, 0.05, HL.SP * 0.86)
	var frame_w := BoxMesh.new()
	frame_w.size = Vector3(HL.ROAD_W - 0.7, 0.05, 0.12)
	var body := BoxMesh.new()
	body.size = Vector3(0.24, 0.03, 0.46)
	var ring := Chars3D.torus(0.3, 0.06)
	var sword := BoxMesh.new()
	sword.size = Vector3(0.09, 0.03, 0.74)
	var glow_white := smat("#ffffff", {"emit": "#ffffff", "emit_e": 0.6, "rough": 0.4})
	var mats := {
		"white": glow_white,
		"dark": smat("#1d1f26", {"rough": 0.5}),
		"warn": smat("#ffd43b", {"emit": "#ffc61a", "emit_e": 0.5, "rough": 0.4}),
		"gold": smat("#ffe066", {"emit": "#ffc61a", "emit_e": 1.4, "rough": 0.3, "metal": 0.3}),
		"pip_b": smat("#1546a8", {"rough": 0.4}),
		"pip_r": smat("#a51111", {"rough": 0.4}),
		"ufo": smat("#7df9ff", {"emit": "#3bc9db", "emit_e": 2.2, "rough": 0.3}),
		"flame": smat("#ffd43b", {"emit": "#ff922b", "emit_e": 1.5, "rough": 0.4}),
	}
	var parts := {}   # kulcs -> [mesh, anyag, transzformok]
	var add := func(key: String, mesh: Mesh, mk: String, t: Transform3D) -> void:
		if not parts.has(key):
			parts[key] = [mesh, mats[mk], []]
		parts[key][2].append(t)
	var tiles := {}   # típus -> [transzformok]
	var sp_all := HL.specials()
	for s in sp_all:
		var sp: Array = sp_all[s]
		var kind: String = sp[0]
		var val: int = sp[1]
		var t := HL.xf(float(s))
		if not tiles.has(kind):
			tiles[kind] = []
		tiles[kind].append(t * Transform3D(Basis(), Vector3(0, 0.016, 0)))
		for sx in [-1.0, 1.0]:
			var ic := t * Transform3D(Basis(), Vector3(sx * (hw - 1.2), 0.04, 0))
			match kind:
				"F", "B", "LAST":
					# előre (hátszél, felzárkózó) vagy hátra (szembeszél) mutató nyílhegyek
					var dir := -1.0 if kind == "B" else 1.0
					var zs: Array = [-0.28, 0.14] if (val >= 20 or kind == "LAST") else [-0.07]
					if kind == "B":
						# figyelmeztető háromszög, benne felkiáltójel; −20-nál mögötte egy visszafelé nyíl
						var zt := -0.14 if val >= 20 else 0.05
						add.call("tri", tri, "warn", ic * Transform3D(Basis(), Vector3(0, -0.005, zt)))
						add.call("bar", bar, "dark", ic * Transform3D(Basis(), Vector3(0, 0.005, zt - 0.04)))
						add.call("dot", dot, "dark", ic * Transform3D(Basis(), Vector3(0, 0.005, zt + 0.15)))
						zs = [0.3] if val >= 20 else []
					var mk := "gold" if kind == "LAST" else "white"
					for zc in zs:
						for side in [-1.0, 1.0]:
							var off := Vector3(side * 0.212, 0.0, float(zc) - 0.088 * dir)
							add.call("chev_" + mk, arm, mk, ic * Transform3D(Basis(Vector3.UP, side * dir * PI / 4.0), off))
				"BD", "RD":
					add.call("face", face, "white", ic)
					var pk := "pip_b" if kind == "BD" else "pip_r"
					var pts := [Vector2(-0.18, -0.18), Vector2(0.18, 0.18), Vector2(-0.18, 0.18), Vector2(0.18, -0.18), Vector2.ZERO] if val <= 5 \
						else [Vector2(-0.18, -0.2), Vector2(-0.18, 0.0), Vector2(-0.18, 0.2), Vector2(0.18, -0.2), Vector2(0.18, 0.0), Vector2(0.18, 0.2)]
					for q in pts:
						add.call(pk, pip, pk, ic * Transform3D(Basis(), Vector3(q.x, 0.02, q.y)))
				"UFO":
					add.call("ring", ring, "ufo", ic)
					add.call("dot_u", dot, "ufo", ic * Transform3D(Basis().scaled(Vector3(1.6, 1, 1.6)), Vector3.ZERO))
				"ROCKET":
					add.call("nose", small_tri, "white", ic * Transform3D(Basis(), Vector3(0, 0, -0.33)))
					add.call("body", body, "white", ic * Transform3D(Basis(), Vector3(0, 0, 0.0)))
					add.call("fire", small_tri, "flame", ic * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.36)))
				"DUEL":
					for k in [-1.0, 1.0]:
						add.call("sword", sword, "white", ic * Transform3D(Basis(Vector3.UP, k * PI / 4.0), Vector3.ZERO))
		if kind == "LAST":
			for sx in [-1.0, 1.0]:
				add.call("frame_l", frame_l, "gold", t * Transform3D(Basis(), Vector3(sx * (hw - 0.41), 0.03, 0)))
				add.call("frame_w", frame_w, "gold", t * Transform3D(Basis(), Vector3(0, 0.03, sx * HL.SP * 0.43)))
		var lab := _flat_label(_space_text(sp), 150 if kind in ["F", "B"] else 96, 0.009)
		lab.outline_size = 22
		lab.outline_modulate = Color(0, 0, 0, 0.45)
		lab.transform = t * Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.05, 0))
		add_child(lab)
	for kind in tiles:
		var col: String = HL.INFO[kind].col
		var e := 0.55 if kind in ["LAST", "UFO"] else 0.3
		_mm(tile, smat(col, {"rough": 0.45, "emit": col, "emit_e": e}), tiles[kind])
	for key in parts:
		_mm(parts[key][0], parts[key][1], parts[key][2])
	_run_strips()


## Lapos, előre (-z) mutató egyenlő oldalú háromszög (felülről látszik), r = a csúcsok távolsága a középtől.
static func _tri_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for v in [Vector3(0, 0, -r), Vector3(r * 0.866, 0, r * 0.5), Vector3(-r * 0.866, 0, r * 0.5)]:
		st.add_vertex(v)
	return st.commit()


## A legalább háromtagú hátszél-/szembeszél-csoportok mentén a korlát teteje zölden / pirosan világít,
## így a csoport már messziről látszik.
func _run_strips() -> void:
	var hw := HL.ROAD_W / 2.0
	var strip := [Vector2(hw - 0.07, 0.5), Vector2(hw - 0.07, 0.56), Vector2(hw + 0.17, 0.56), Vector2(hw + 0.17, 0.5)]
	var sp_all := HL.specials()
	var s := 1
	while s < HL.GOAL:
		var sp: Array = sp_all.get(s, [])
		if sp.is_empty() or not (sp[0] in ["F", "B"]):
			s += 1
			continue
		var e := s
		while sp_all.has(e + 1) and sp_all[e + 1][0] == sp[0]:
			e += 1
		if e - s + 1 >= 3:
			var col: String = HL.INFO[sp[0]].col
			var m := smat(col, {"emit": col, "emit_e": 1.6, "rough": 0.4})
			for prof in [strip, _mirror(strip)]:
				_extrude(prof, s - 0.5, e + 0.5, m)
		s = e + 1


static func _space_text(sp: Array) -> String:
	match sp[0]:
		"F": return "+%d" % sp[1]
		"B": return "−%d" % sp[1]
		"BD": return "+%d KOCKA" % sp[1]
		"RD": return "−%d KOCKA" % sp[1]
		"LAST": return "FELZÁRKÓZÓ"
		"UFO": return "UFO"
		"ROCKET": return "RAKÉTA"
		"DUEL": return "1 vs. MIND"
	return ""


func _tower(parent: Node3D, x: float, z: float, h: float) -> void:
	var stripe := smat("#ffc61a", {"rough": 0.45})
	var dark := smat("#2b2f3a", {"rough": 0.5, "metal": 0.4})
	Chars3D.box(parent, 0.8, h, 0.8, smat("#e8590c", {"rough": 0.5}), Vector3(x, h / 2.0 - 0.5, z))
	for k in int(h / 0.8):
		Chars3D.box(parent, 0.84, 0.18, 0.84, stripe if k % 2 == 0 else dark, Vector3(x, 0.1 + k * 0.8, z))
	Chars3D.sphere(parent, 0.28, smat("#ff3b30", {"emit": "#ff3b30", "emit_e": 1.5}), x, h - 0.3, z)


## Felvonóhíd a 100. mező után: a lap a túlsó végén forog, zárva függőleges fal.
func _bridge() -> void:
	var a := _anchor((GAP_A + GAP_B) / 2.0)
	var half := (GAP_B - GAP_A) * HL.SP / 2.0
	var z0 := half
	var z1 := -half
	for sx in [-1.0, 1.0]:
		_tower(a, sx * (HL.ROAD_W / 2.0 + 0.8), 0.0, 4.2)
	Chars3D.box(a, HL.ROAD_W + 2.4, 0.4, 0.5, smat("#e8590c"), Vector3(0, 3.9, 0))
	var lab := Label3D.new()
	lab.text = "FELVONÓHÍD"
	lab.font = D.font
	lab.font_size = 90
	lab.pixel_size = 0.01
	lab.outline_size = 16
	lab.position = Vector3(0, 4.5, 0)
	a.add_child(lab)
	bridge_leaf = Node3D.new()
	bridge_leaf.position = Vector3(0, 0, z1)
	a.add_child(bridge_leaf)
	var leaf_len := absf(z1 - z0)
	Chars3D.box(bridge_leaf, HL.ROAD_W, 0.3, leaf_len, smat("#7b8496", {"rough": 0.6, "metal": 0.3}), Vector3(0, -0.15, leaf_len / 2.0))
	for k in 6:
		Chars3D.box(bridge_leaf, 0.5, 0.04, leaf_len - 0.1, smat("#ffc61a"), Vector3(-HL.ROAD_W / 2.0 + 0.7 + k * 1.4, 0.01, leaf_len / 2.0))
	# láncok
	for sx in [-1.0, 1.0]:
		Chars3D.cyl(bridge_leaf, 0.05, 0.05, 0.6, smat("#2b2f3a"), sx * (HL.ROAD_W / 2.0 - 0.2), 0.3, leaf_len - 0.1, 6)


## Jelzőlámpás kapu a 200. mező után: kapukeret, piros és zöld lámpák, felcsapódó sorompó.
func _light_gate() -> void:
	var a := _anchor(HL.CP_LIGHTS + 0.5)
	var frame := smat("#343a46", {"rough": 0.4, "metal": 0.5})
	for sx in [-1.0, 1.0]:
		Chars3D.box(a, 0.7, 5.2, 0.7, frame, Vector3(sx * (HL.ROAD_W / 2.0 + 0.5), 2.1, 0))
	Chars3D.box(a, HL.ROAD_W + 1.8, 0.7, 0.8, frame, Vector3(0, 4.9, 0))
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#5c1010")
	red.emission_enabled = true
	red.emission = Color("#ff2b2b")
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("#0f3d18")
	green.emission_enabled = true
	green.emission = Color("#2bff5a")
	gate_lamps = [red, green]
	for k in 4:
		var x := -2.4 + k * 1.6
		Chars3D.box(a, 1.0, 1.9, 0.6, smat("#1d1f26"), Vector3(x, 4.1, 0.5))
		Chars3D.sphere(a, 0.34, red, x, 4.55, 0.82)
		Chars3D.sphere(a, 0.34, green, x, 3.7, 0.82)
	gate_boom = Node3D.new()
	gate_boom.position = Vector3(-HL.ROAD_W / 2.0 - 0.1, 1.0, 0.4)
	a.add_child(gate_boom)
	var stripe := smat("#ffffff", {"rough": 0.5})
	var stripe2 := smat("#e03131", {"rough": 0.5})
	for k in 8:
		Chars3D.box(gate_boom, HL.ROAD_W / 8.0, 0.32, 0.22, stripe if k % 2 == 0 else stripe2, Vector3((k + 0.5) * HL.ROAD_W / 8.0, 0, 0))


## Célkapu a 351. mezőnél: arany boltív, CÉL felirat, kétszárnyú kapu.
func _final_gate() -> void:
	var a := _anchor(HL.GOAL + 0.6)
	var gold := smat("#ffc61a", {"rough": 0.3, "metal": 0.4})
	var red := smat("#e03131", {"rough": 0.4})
	for sx in [-1.0, 1.0]:
		Chars3D.cyl(a, 0.7, 0.8, 8.0, gold, sx * (HL.ROAD_W / 2.0 + 0.7), 3.5, 0, 12)
		Chars3D.sphere(a, 0.9, red, sx * (HL.ROAD_W / 2.0 + 0.7), 7.8, 0)
	var arch := MeshInstance3D.new()
	arch.mesh = Chars3D.arc_tube(HL.ROAD_W / 2.0 + 0.7, 0.45, PI, 28, 8)
	arch.material_override = gold
	arch.position = Vector3(0, 7.5, 0)
	a.add_child(arch)
	Chars3D.box(a, 5.0, 1.3, 0.3, red, Vector3(0, 9.4, 0))
	var lab := Label3D.new()
	lab.text = "CÉL"
	lab.font = D.font
	lab.font_size = 150
	lab.pixel_size = 0.012
	lab.outline_size = 22
	lab.position = Vector3(0, 9.4, 0.2)
	a.add_child(lab)
	for sx in [-1.0, 1.0]:
		var d := Node3D.new()
		d.position = Vector3(sx * HL.ROAD_W / 2.0, 0, 0)
		a.add_child(d)
		var w := HL.ROAD_W / 2.0
		Chars3D.box(d, w, 3.2, 0.25, smat("#ffffff", {"rough": 0.4}), Vector3(-sx * w / 2.0, 1.6, 0))
		for k in 4:
			Chars3D.box(d, w / 4.0, 0.5, 0.27, red, Vector3(-sx * (k + 0.5) * w / 4.0, 0.4 + (k % 2) * 2.2, 0))
		final_doors.append({"n": d, "sx": sx})
	# a kapu mögött egy kis ünnepi tér
	Chars3D.cyl(a, 7.5, 7.5, 0.5, smat("#ffe8a3", {"rough": 0.6}), 0, -0.25, -9.0, 32)


func _start_arch() -> void:
	var a := _anchor(0.0)
	var blue := smat("#1c7ed6", {"rough": 0.4})
	for sx in [-1.0, 1.0]:
		Chars3D.box(a, 0.6, 10.0, 0.6, blue, Vector3(sx * (HL.ROAD_W / 2.0 + 0.4), 4.5, 3.0))
	Chars3D.box(a, HL.ROAD_W + 1.4, 1.1, 0.5, blue, Vector3(0, 9.6, 3.0))
	var lab := Label3D.new()
	lab.text = "RAJT · ÓCEÁNSZTRÁDA"
	lab.font = D.font
	lab.font_size = 90
	lab.pixel_size = 0.009
	lab.outline_size = 14
	lab.position = Vector3(0, 9.6, 3.3)
	a.add_child(lab)
	# kockás rajtvonal
	for k in 16:
		Chars3D.box(a, HL.ROAD_W / 16.0, 0.02, 0.5, smat("#ffffff" if k % 2 == 0 else "#1d1f26"), Vector3(-HL.ROAD_W / 2.0 + (k + 0.5) * HL.ROAD_W / 16.0, 0.012, 0.6))


## Nézőcsoportok kis kiugró teraszokon, zászlókkal. Csak díszlet: soha nem versenyzők.
func _crowds() -> void:
	var skins := ["#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#ffdbac"]
	var shirts := ["#ff6b6b", "#4dabf7", "#69db7c", "#ffd43b", "#b197fc", "#ff922b", "#22b8cf", "#f783ac"]
	var k := 0
	for s in range(12, HL.GOAL, 26):
		var side := -1.0 if k % 2 == 0 else 1.0
		var g := _anchor(float(s), side * (HL.ROAD_W / 2.0 + 2.1))
		Chars3D.box(g, 3.2, 0.4, 4.2, smat("#d9dde6"), Vector3(0, -0.2, 0))
		Chars3D.box(g, 0.12, 3.2, 0.12, smat("#adb5bd"), Vector3(side * 1.4, 1.4, -1.9))
		var flag := Chars3D.box(g, 0.04, 0.9, 1.4, smat(shirts[k % shirts.size()], {"rough": 0.6}), Vector3(side * 1.4, 2.6, -1.2))
		var figs: Array = []
		for i in 5:
			var f := Node3D.new()
			f.position = Vector3(FX.fr(-0.9, 0.9) * 0.0 + (i % 2) * 0.7 * side - 0.3 * side, 0, -1.6 + i * 0.8)
			g.add_child(f)
			var shirt := smat(shirts[(k * 3 + i) % shirts.size()])
			Chars3D.lcyl(f, 0.22, 0.26, 0.7, shirt, 0, 0.35, 0, 7)
			Chars3D.lsphere(f, 0.22, smat(skins[(k + i) % skins.size()]), 0, 0.92, 0, 1, 1, 1, 8, 5)
			var arms: Array = []
			for sd in [-1.0, 1.0]:
				var a := Node3D.new()
				a.position = Vector3(sd * 0.27, 0.62, 0)
				f.add_child(a)
				Chars3D.box(a, 0.1, 0.45, 0.1, shirt, Vector3(0, -0.2, 0))
				arms.append(a)
			f.rotation.y = -side * PI / 2.0
			figs.append({"n": f, "arms": arms, "ph": float(i) * 1.7 + k})
		crowds.append({"node": g, "s": float(s), "figs": figs, "mood": "", "mood_t0": -10.0, "flag": flag})
		k += 1


## Csoportok reakciója a közelben (good: ujjongás, bad: csalódott fejcsóválás)
func crowd(s: float, good: bool) -> void:
	for c in crowds:
		if absf(float(c.s) - s) < 34.0:
			c.mood = "good" if good else "bad"
			c.mood_t0 = t


func _dolphins() -> void:
	var body := smat("#6c8fb3", {"rough": 0.35})
	var belly := smat("#dfe9f3", {"rough": 0.4})
	for i in 3:
		var d := Node3D.new()
		d.visible = false
		add_child(d)
		Chars3D.lsphere(d, 0.55, body, 0, 0, 0, 0.8, 0.75, 2.4, 10, 6)
		Chars3D.lsphere(d, 0.4, belly, 0, -0.18, 0.1, 0.8, 0.5, 2.0, 8, 5)
		Chars3D.lcone(d, 0.3, 0.6, body, 0, 0.45, 0.1, 4, Vector3(-0.4, 0, 0))
		Chars3D.box(d, 1.0, 0.08, 0.35, body, Vector3(0, 0, -1.35))
		Chars3D.lcone(d, 0.16, 0.5, body, 0, 0.0, 1.5, 6, Vector3(PI / 2, 0, 0))
		dolphins.append({"node": d, "t0": -10.0, "dur": 1.6, "a": Vector3.ZERO, "b": Vector3.ZERO})


func _vehicles() -> void:
	# UFO
	ufo = Node3D.new()
	ufo.visible = false
	add_child(ufo)
	var disc := MeshInstance3D.new()
	disc.mesh = Chars3D.lathe([[0.0, -0.35], [1.2, -0.25], [2.2, 0.0], [1.3, 0.3], [0.0, 0.35]], 28)
	disc.material_override = smat("#ced4da", {"rough": 0.25, "metal": 0.6})
	ufo.add_child(disc)
	Chars3D.sphere(ufo, 0.9, smat("#a5f3fc", {"rough": 0.05, "alpha": 0.7}), 0, 0.35, 0, 1, 0.75, 1)
	for k in 10:
		var a := TAU * k / 10.0
		Chars3D.sphere(ufo, 0.13, smat("#ffe066", {"emit": "#ffd43b", "emit_e": 2.5}), cos(a) * 1.75, 0.02, sin(a) * 1.75)
	beam = MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.5
	bc.bottom_radius = 1.6
	bc.height = 1.0
	beam.mesh = bc
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.97, 0.6, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ufo.add_child(beam)
	# rakéta
	rocket = Node3D.new()
	rocket.visible = false
	add_child(rocket)
	var hull := MeshInstance3D.new()
	hull.mesh = Chars3D.lathe([[0.0, 0.0], [0.55, 0.1], [0.62, 1.2], [0.55, 2.3], [0.3, 2.9], [0.0, 3.2]], 18)
	hull.material_override = smat("#f8f9fa", {"rough": 0.35})
	rocket.add_child(hull)
	Chars3D.cone(rocket, 0.33, 0.5, smat("#e03131"), 0, 3.0, 0, 16)
	Chars3D.cyl(rocket, 0.63, 0.63, 0.25, smat("#e03131"), 0, 1.6, 0, 18)
	Chars3D.sphere(rocket, 0.22, smat("#4dabf7", {"rough": 0.1}), 0, 2.15, 0.52, 1, 1, 0.5)
	for k in 3:
		var fin := Node3D.new()
		fin.rotation.y = TAU * k / 3.0
		rocket.add_child(fin)
		Chars3D.box(fin, 0.08, 0.9, 0.6, smat("#e03131"), Vector3(0, 0.4, 0.75), Vector3(0.3, 0, 0))
	flame = Node3D.new()
	rocket.add_child(flame)
	Chars3D.cone(flame, 0.42, 1.4, smat("#ffa94d", {"emit": "#ff922b", "emit_e": 3.0, "unshaded": true}), 0, -0.7, 0, 10, Vector3(PI, 0, 0))
	Chars3D.cone(flame, 0.22, 0.9, smat("#fff3bf", {"emit": "#fff3bf", "emit_e": 3.0, "unshaded": true}), 0, -0.45, 0, 8, Vector3(PI, 0, 0))


func _dice() -> void:
	for k in MAX_DICE:
		var root := Node3D.new()
		add_child(root)
		var cube := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(DIE, DIE, DIE)
		cube.mesh = bx
		var m := StandardMaterial3D.new()
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission_energy_multiplier = 0.25
		cube.material_override = m
		root.add_child(cube)
		var labels: Array = []
		var dirs := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
		for dv in dirs:
			var face := Label3D.new()
			face.text = "1"
			face.font = D.font
			face.font_size = 110
			face.pixel_size = 0.0026
			face.double_sided = false
			face.position = dv * (DIE / 2.0 + 0.004)
			if dv.z < 0: face.rotation.y = PI
			elif dv.x > 0: face.rotation.y = PI / 2
			elif dv.x < 0: face.rotation.y = -PI / 2
			elif dv.y > 0: face.rotation.x = -PI / 2
			elif dv.y < 0: face.rotation.x = PI / 2
			cube.add_child(face)
			labels.append(face)
		root.visible = false
		dice_nodes.append({"root": root, "cube": cube, "labels": labels, "mat": m})


# ------------------------------------------------------------------ szállítás (UFO, rakéta)
## UFO-út: tt = eltelt idő; visszaadja az UFO, a figura helyét és a fénysugár erősségét.
static func ufo_frame(a: Vector3, b: Vector3, tt: float) -> Dictionary:
	var hover := 4.6
	var u := a + Vector3(0, 14, 0)
	var pawn := a
	var bm := 0.0
	if tt < 1.0:
		u = a + Vector3(0, lerpf(16.0, hover, D.ease_out_cubic(tt / 1.0)), 0)
	elif tt < 1.9:
		var k := (tt - 1.0) / 0.9
		u = a + Vector3(0, hover, 0)
		bm = 1.0
		pawn = a + Vector3(0, D.ease_in_out(k) * (hover - 1.4), 0)
	elif tt < 3.6:
		var k := D.ease_in_out((tt - 1.9) / 1.7)
		var mid := sin(k * PI) * 6.0
		u = a.lerp(b, k) + Vector3(0, hover + mid, 0)
		pawn = u - Vector3(0, 1.4, 0)
		bm = 0.6
	elif tt < 4.3:
		var k := (tt - 3.6) / 0.7
		u = b + Vector3(0, hover, 0)
		pawn = b + Vector3(0, (1.0 - D.ease_in_out(k)) * (hover - 1.4), 0)
		bm = 1.0
	else:
		var k := clampf((tt - 4.3) / 0.6, 0.0, 1.0)
		u = b + Vector3(0, hover + k * k * 30.0, 0)
		pawn = b
	return {"ufo": u, "pawn": pawn, "beam": bm}


## Vízszintes, a-ból b felé nézve jobbra mutató egységvektor (ha egy helyben: az út jobbja).
static func _flat_right(a: Vector3, b: Vector3) -> Vector3:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if d.length() < 0.01:
		return HL.right(HL.s_of(a))
	d = d.normalized()
	return Vector3(-d.z, 0.0, d.x)


const UFO_DUR := 4.9
const ROCKET_DUR := 4.6


static func rocket_frame(a: Vector3, b: Vector3, tt: float) -> Dictionary:
	var side := -1.4 * _flat_right(a, b)
	var r := a + side
	var pawn := a
	var fire := 0.0
	var tilt := 0.0
	var vis := true
	if tt < 0.6:
		r = a + side + Vector3(0, -6.0 * (1.0 - D.ease_out_back(tt / 0.6)), 0)
	elif tt < 1.1:
		var k := (tt - 0.6) / 0.5
		pawn = a.lerp(r + Vector3(0, 3.25, 0), D.ease_in_out(k)) + Vector3(0, sin(k * PI) * 1.2, 0)
	elif tt < 1.5:
		pawn = r + Vector3(0, 3.25, 0)
		fire = 0.5
	elif tt < 3.7:
		var k := (tt - 1.5) / 2.2
		var e := D.ease_in_out(k)
		var p := (a + side).lerp(b + side, e) + Vector3(0, sin(k * PI) * 22.0, 0)
		r = p
		pawn = r + Vector3(0, 3.25, 0)
		fire = 1.0
		tilt = cos(k * PI) * 0.9
	elif tt < 4.1:
		var k := (tt - 3.7) / 0.4
		r = b + side
		pawn = (r + Vector3(0, 3.25, 0)).lerp(b, D.ease_in_out(k)) + Vector3(0, sin(k * PI) * 1.2, 0)
		fire = 0.3
	else:
		r = b + side + Vector3(0, -((tt - 4.1) / 0.5) * 8.0, 0)
		pawn = b
		vis = tt < 4.6
	return {"rocket": r, "pawn": pawn, "fire": fire, "tilt": tilt, "vis": vis}


# ------------------------------------------------------------------ figurák
func pawn_for(p) -> Dictionary:
	if pawns.has(p.pid):
		return pawns[p.pid]
	var g := Node3D.new()
	add_child(g)
	var m := Chars3D.build(p.char_id)
	m.scale = Vector3.ONE * PAWN_SC
	g.add_child(m)
	var col := Color(SLOT_COLORS[p.hw_lane % SLOT_COLORS.size()])
	var disc := MeshInstance3D.new()
	disc.mesh = Chars3D.torus(0.42, 0.05)
	disc.material_override = Chars3D.mat(col.to_html(false), {"rough": 0.4, "emit": col.to_html(false), "emit_e": 0.6})
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(disc)
	var o := {"group": g, "m": m, "arms": K.build_arms(m, col.darkened(0.1).to_html(false), 0.5), "face": K.build_face(m),
		"disc": disc, "yaw": PI, "pose": "", "pose_t0": -10.0, "pose_dur": 0.0, "last": null, "run_ph": 0.0}
	pawns[p.pid] = o
	return o


## Testtartás-jelenet egy figurának: cheer, happy, sad, fist, hips, throw, wave, intro, scared
func pose(pid: String, kind: String, dur := 1.6) -> void:
	if not pawns.has(pid):
		return
	var o: Dictionary = pawns[pid]
	o.pose = kind
	o.pose_t0 = t
	o.pose_dur = dur
	var m: Chars3D.CharModel = o.m
	if kind == "cheer" or kind == "happy":
		m.emote(kind)
	elif kind == "sad":
		m.emote("sad")


func pose_all(kind: String, dur := 1.6) -> void:
	for pid in pawns:
		pose(pid, kind, dur)


func _animate_pawn(o: Dictionary, d: Dictionary, dt: float) -> void:
	var g: Node3D = o.group
	var m: Chars3D.CharModel = o.m
	var pos: Vector3 = d.pos
	var running := false
	if o.last != null:
		var dv: Vector3 = pos - (o.last as Vector3)
		if Vector2(dv.x, dv.z).length() > 0.01 and d.h < 0.05 and not d.get("carried", false):
			running = true
			o.yaw = lerp_angle(float(o.yaw), atan2(dv.x, dv.z), minf(1.0, dt * 12.0))
	o.last = pos
	if not running:
		# állva a kamera felé fordul
		var to_cam := camera.position - pos
		o.yaw = lerp_angle(float(o.yaw), atan2(to_cam.x, to_cam.z), minf(1.0, dt * 4.0))
	o.run_ph = float(o.run_ph) + dt * (13.0 if running else 0.0)
	var ph: float = o.run_ph
	var a := m.animate(dt)
	var k: float = t - float(o.pose_t0)
	var kind: String = o.pose if k < float(o.pose_dur) else ""
	var arm_t: Array = []
	var arms: Array = o.arms
	for arm in arms:
		var sd: float = arm.side
		arm_t.append(Vector3(sd * 0.36, 0.12 + sin(t * 2.0 + sd) * 0.02, 0.06))
	var y := 0.0
	var sy := 1.0
	var lean := 0.0
	var roll := 0.0
	var face := [0.0, 1.0, 0.0]
	if running:
		y = absf(sin(ph)) * 0.16
		lean = 0.2
		for i in arms.size():
			var sd: float = arms[i].side
			arm_t[i] = Vector3(sd * 0.3, 0.22, sin(ph + (0.0 if sd > 0 else PI)) * 0.32 + 0.05)
		face = [0.2, 1.0, 0.2]
	match kind:
		"cheer", "happy":
			for i in arms.size():
				var sd: float = arms[i].side
				arm_t[i] = Vector3(sd * (0.32 + sin(t * 11.0 + sd) * 0.06), 1.05, 0.1)
			face = [0.85, 1.1, 0.6]
		"fist":
			for i in arms.size():
				var sd: float = arms[i].side
				if sd > 0:
					arm_t[i] = Vector3(0.3, 1.0 + sin(minf(k * 6.0, PI / 2.0)) * 0.1, 0.12)
			y = absf(sin(minf(k * 5.0, PI))) * 0.25
			face = [0.6, 1.05, 0.5]
		"hips", "sad":
			for i in arms.size():
				var sd: float = arms[i].side
				arm_t[i] = Vector3(sd * 0.42, 0.28, -0.02) if kind == "hips" else Vector3(sd * 0.22, 0.02, 0.2)
			lean = 0.25
			roll = sin(t * 5.0) * 0.05
			face = [0.1, 0.85, -0.85]
		"throw":
			var u := clampf(k / 0.35, 0.0, 1.0)
			for i in arms.size():
				var sd: float = arms[i].side
				arm_t[i] = Vector3(sd * 0.2, lerpf(0.35, 1.1, u), lerpf(0.35, 0.25, u))
			y = sin(u * PI) * 0.2
			face = [0.5, 1.1, 0.4]
		"wave":
			for i in arms.size():
				var sd: float = arms[i].side
				arm_t[i] = Vector3(sd * (0.45 + sin(t * 12.0 + sd) * 0.12), 0.95, 0.1)
			face = [0.6, 1.05, 0.4]
		"scared":
			for i in arms.size():
				var sd: float = arms[i].side
				arm_t[i] = Vector3(sd * 0.5, 0.8 + sin(t * 18.0 + sd) * 0.12, 0.1)
			roll = sin(t * 30.0) * 0.04
			face = [0.9, 1.35, 0.9]
		"intro":
			# guggolás -> kéz a csípőn, lábdobolás -> két kézzel integet -> két ugrás
			if k < 0.5:
				sy = 1.0 - 0.22 * sin(k / 0.5 * PI)
			elif k < 1.5:
				for i in arms.size():
					var sd: float = arms[i].side
					arm_t[i] = Vector3(0.42, 0.3, -0.02) if sd > 0 else Vector3(-0.36, 0.12, 0.06)
				roll = sin(k * 22.0) * 0.06
				y = maxf(0.0, sin(k * 22.0)) * 0.04
			elif k < 2.3:
				for i in arms.size():
					var sd: float = arms[i].side
					arm_t[i] = Vector3(sd * (0.45 + sin(t * 12.0 + sd) * 0.12), 0.95, 0.1)
				face = [0.7, 1.05, 0.5]
			else:
				var u := clampf((k - 2.3) / 1.0, 0.0, 1.0)
				y = absf(sin(u * TAU)) * 0.55
				for i in arms.size():
					var sd: float = arms[i].side
					arm_t[i] = Vector3(sd * 0.4, 0.95, 0.1)
				face = [0.8, 1.1, 0.6]
	if d.get("carried", false):
		for i in arms.size():
			var sd: float = arms[i].side
			arm_t[i] = Vector3(sd * 0.5, 0.75 + sin(t * 14.0 + sd) * 0.15, 0.0)
		face = [0.8, 1.3, 0.8]
	K.set_face(m, o.face, face[0], face[1], face[2])
	g.position = pos + Vector3(0, float(d.h) + y + a.y * 0.6, 0)
	g.rotation_order = EULER_ORDER_YXZ
	g.rotation = Vector3(lean + a.tilt, float(o.yaw) + a.spin, roll)
	m.scale = Vector3(PAWN_SC / sqrt(sy), PAWN_SC * sy, PAWN_SC / sqrt(sy))
	for i in arms.size():
		K.arm_to(arms[i], arm_t[i], Vector3(0.8, -0.4, -0.3))
	var disc: MeshInstance3D = o.disc
	disc.visible = float(d.h) < 0.3 and not d.get("carried", false)
	disc.position = Vector3(0, 0.03 - float(d.h) - y, 0)


# ------------------------------------------------------------------ képkocka
## st: {pawns: [{p, pos, h, current, carried}], carry: {kind, a, b, t0}|null, dice: {...}|null, now: jelenetidő}
func render(st: Dictionary, dt: float) -> void:
	t += dt
	var seen := {}
	var cur_pos = null
	for d in st.pawns:
		var o := pawn_for(d.p)
		seen[d.p.pid] = true
		_animate_pawn(o, d, dt)
		if d.current:
			cur_pos = (o.group as Node3D).position
	for pid in pawns.keys():
		if not seen.has(pid):
			(pawns[pid].group as Node3D).queue_free()
			pawns.erase(pid)
	marker.visible = cur_pos != null
	if cur_pos != null:
		marker.position = cur_pos + Vector3(0, 1.85 + sin(t * 5.0) * 0.1, 0)
		marker.rotation.y = t * 2.5
	_render_carry(st.get("carry"), float(st.get("now", 0.0)))
	_render_dice(st.get("dice"), float(st.get("now", 0.0)))
	_render_gates(dt)
	_render_crowds()
	_render_dolphins(dt)
	_render_puffs()
	_update_camera(dt)


func _render_carry(c, now: float) -> void:
	ufo.visible = false
	rocket.visible = false
	if c == null:
		return
	var tt: float = now - float(c.t0)
	if c.kind == "ufo":
		var f := ufo_frame(c.a, c.b, tt)
		ufo.visible = tt < UFO_DUR
		ufo.position = f.ufo
		ufo.rotation.y = t * 3.0
		beam.visible = f.beam > 0.0
		var hgt := maxf(0.5, (f.ufo as Vector3).y - (c.a as Vector3).y + 0.2)
		beam.scale = Vector3(1, hgt, 1)
		beam.position = Vector3(0, -hgt / 2.0, 0)
		(beam.material_override as StandardMaterial3D).albedo_color.a = 0.35 * float(f.beam) * (0.8 + 0.2 * sin(t * 20.0))
	elif c.kind == "rocket":
		var f := rocket_frame(c.a, c.b, tt)
		rocket.visible = f.vis
		rocket.position = f.rocket
		var r := _flat_right(c.a, c.b)
		rocket.rotation = Vector3(-float(f.tilt), atan2(r.z, -r.x) + PI, 0)
		flame.visible = f.fire > 0.0
		flame.scale = Vector3.ONE * (0.6 + 0.6 * float(f.fire)) * (0.85 + 0.15 * sin(t * 40.0))
		if f.fire > 0.5 and fmod(t, 0.06) < 0.02:
			_puff((f.rocket as Vector3) + Vector3(FX.fr(-0.3, 0.3), -1.0, FX.fr(-0.3, 0.3)), 0.9)


func _puff(at: Vector3, size: float) -> void:
	var s := Chars3D.lsphere(self, 0.5 * size, smat("#f1f3f5", {"rough": 1.0, "alpha": 0.8}), at.x, at.y, at.z, 1, 1, 1, 7, 4)
	puffs.append({"node": s, "t0": t, "dur": 1.2, "v": Vector3(FX.fr(-0.5, 0.5), FX.fr(-0.2, 0.6), FX.fr(-0.5, 0.5))})


func _render_puffs() -> void:
	var keep: Array = []
	for pf in puffs:
		var k: float = (t - float(pf.t0)) / float(pf.dur)
		var n: Node3D = pf.node
		if k >= 1.0:
			n.queue_free()
			continue
		n.position += (pf.v as Vector3) * 0.016
		n.scale = Vector3.ONE * (1.0 + k * 1.6) * (1.0 - k * 0.4)
		keep.append(pf)
	puffs = keep


## dice: {origin, vals: [], kind: "std"|"light", t0s: [], hl: -1}
func _render_dice(dc, now: float) -> void:
	if dc == null:
		for b in dice_nodes:
			(b.root as Node3D).visible = false
		return
	var vals: Array = dc.vals
	var n: int = mini(vals.size(), MAX_DICE)
	var right := camera.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var fwd := (camera.position - (dc.origin as Vector3))
	fwd.y = 0
	fwd = fwd.normalized()
	var cols: int = mini(n, 8)
	for i in MAX_DICE:
		var b: Dictionary = dice_nodes[i]
		var root: Node3D = b.root
		root.visible = i < n
		if i >= n:
			continue
		var t0: float = dc.t0s[i]
		var k: float = now - t0
		if k < 0.0:
			root.visible = false
			continue
		var row := i / 8
		var col := i % 8
		var rc: int = cols if row == 0 else n - 8
		var target: Vector3 = (dc.origin as Vector3) + Vector3(0, 2.2 + row * 0.55, 0) + right * (col - (rc - 1) / 2.0) * 0.54 + fwd * 0.25
		var start: Vector3 = (dc.origin as Vector3) + Vector3(0, 1.0, 0)
		var cube: MeshInstance3D = b.cube
		var settled := k >= 0.95
		if k < 0.7:
			var u := k / 0.7
			root.position = start.lerp(target, u) + Vector3(0, sin(u * PI) * 1.8, 0)
			cube.rotation = Vector3(k * 13.0 + i, k * 9.0 + i * 2.0, k * 11.0)
		elif k < 0.95:
			var u := (k - 0.7) / 0.25
			root.position = target + Vector3(0, absf(sin(u * PI)) * 0.35 * (1.0 - u), 0)
			cube.rotation = cube.rotation.lerp(Vector3(-0.3, atan2(fwd.x, fwd.z), 0), u)
		else:
			root.position = target
			cube.rotation = Vector3(-0.3, atan2(fwd.x, fwd.z), 0)
		var pop := 1.0 + (0.3 * maxf(0.0, 1.0 - (k - 0.95) * 4.0) if settled else 0.0)
		cube.scale = Vector3.ONE * pop
		var m: StandardMaterial3D = b.mat
		var v: int = vals[i]
		var light: bool = dc.kind == "light"
		if light:
			var green: bool = v == 1 if settled else fmod(t * 8.0 + i, 2.0) < 1.0
			m.albedo_color = Color("#2fb344") if green else Color("#e03131")
			m.emission = m.albedo_color
			for l in b.labels:
				(l as Label3D).text = "OK" if green else "X"
				(l as Label3D).modulate = Color.WHITE
		else:
			var gold: bool = dc.get("gold", false) and settled
			var bonus: bool = i >= int(dc.get("bonus_from", 99))
			var bg := Color("#ffd43b") if gold else (Color("#ffe8cc") if bonus else Color("#ffffff"))
			m.albedo_color = bg
			m.emission = bg
			for l in b.labels:
				(l as Label3D).text = str(v if settled else (int(t * 14.0 + i * 3) % 6 + 1))
				(l as Label3D).modulate = Color("#2b1055") if not bonus else Color("#c2255c")


func _render_gates(dt: float) -> void:
	bridge_open = move_toward(bridge_open, bridge_target, dt * 0.9)
	bridge_leaf.rotation.x = -(1.0 - D.ease_in_out(bridge_open)) * PI / 2.0 * 0.95
	gate_open = move_toward(gate_open, gate_target, dt * 1.2)
	gate_boom.rotation.z = D.ease_in_out(gate_open) * 1.35
	var r: StandardMaterial3D = gate_lamps[0]
	var g: StandardMaterial3D = gate_lamps[1]
	var red_on := gate_light == "red" or (gate_light == "blink" and fmod(t, 0.3) < 0.15) or gate_light == ""
	var green_on := gate_light == "green" or (gate_light == "blink" and fmod(t, 0.3) >= 0.15)
	r.emission_energy_multiplier = 3.0 if red_on else 0.1
	g.emission_energy_multiplier = 3.0 if green_on else 0.1
	final_open = move_toward(final_open, final_target, dt * 0.6)
	for d in final_doors:
		var n: Node3D = d.n
		n.rotation.y = -float(d.sx) * D.ease_in_out(final_open) * 1.6


func _render_crowds() -> void:
	for c in crowds:
		var k: float = t - float(c.mood_t0)
		var mood: String = c.mood if k < 2.6 else ""
		var flag: Node3D = c.flag
		flag.rotation.x = sin(t * 3.0 + float(c.s)) * 0.12
		for f in c.figs:
			var n: Node3D = f.n
			var ph: float = f.ph
			var arms: Array = f.arms
			match mood:
				"good":
					n.position.y = absf(sin(t * 9.0 + ph)) * 0.35
					n.rotation.z = 0.0
					for i in 2:
						(arms[i] as Node3D).rotation.z = (PI * 0.85 + sin(t * 14.0 + ph) * 0.3) * (-1.0 if i == 0 else 1.0)
				"bad":
					n.position.y = 0.0
					n.rotation.z = sin(t * 7.0 + ph) * 0.15
					for i in 2:
						(arms[i] as Node3D).rotation.z = 0.05 * (-1.0 if i == 0 else 1.0)
				_:
					n.position.y = absf(sin(t * 2.0 + ph)) * 0.04
					n.rotation.z = 0.0
					for i in 2:
						(arms[i] as Node3D).rotation.z = (0.25 + sin(t * 2.2 + ph) * 0.15) * (-1.0 if i == 0 else 1.0)


func _render_dolphins(dt: float) -> void:
	next_dolphin -= dt
	if next_dolphin <= 0.0:
		next_dolphin = FX.fr(3.5, 7.0)
		for d in dolphins:
			if t - float(d.t0) > float(d.dur):
				var side := -1.0 if FX.f() < 0.5 else 1.0
				var s := cam_s + FX.fr(3.0, 17.0)
				var x := side * FX.fr(9.0, 18.0)
				d.a = at(s - 2.7, x, OCEAN_Y - 0.5)
				d.b = at(s + 2.7, x + side * FX.fr(-2.0, 2.0), OCEAN_Y - 0.5)
				d.t0 = t
				d.dur = FX.fr(1.4, 1.9)
				break
	for d in dolphins:
		var n: Node3D = d.node
		var k: float = (t - float(d.t0)) / float(d.dur)
		n.visible = k >= 0.0 and k <= 1.0
		if not n.visible:
			continue
		var a: Vector3 = d.a
		var b: Vector3 = d.b
		var p := a.lerp(b, k) + Vector3(0, sin(k * PI) * 4.0, 0)
		var dir := (b - a).normalized()
		n.position = p
		n.look_at(p + dir + Vector3(0, cos(k * PI) * 1.4, 0), Vector3.UP)
		n.rotate_object_local(Vector3.UP, PI)


# ------------------------------------------------------------------ kamera
## A kamera a figura mögött, kicsit jobbra-fölötte áll, és az út irányával együtt fordul (lassan,
## hogy a kanyarokban se ugorjon); kicsit előre néz, hogy a következő kanyar is látsszon.
## s: hol jár a figura az út mentén (ha nincs megadva, a legközelebbi útpontból számolja).
func cam_follow(pos: Vector3, zoom := "near", speed := 2.5, s := NAN) -> void:
	if is_nan(s):
		s = HL.s_of(pos)
	cam_speed = speed
	var z := {"close": Vector3(3.2, 3.4, 6.4), "near": Vector3(4.5, 5.2, 9.6), "mid": Vector3(6.0, 8.5, 15.0)}
	var ahead := 2.0 if zoom == "close" else 3.0
	cam_look_t = pos + Vector3(0, 1.0, 0) + HL.fwd(s + ahead) * ahead
	cam_yaw_t = HL.heading(s + ahead * 1.5)
	cam_off_t = z.get(zoom, z.near)
	cam_s = s


## Mindenki látszik: a leghátsó és a legelső közötti útszakasz köré, annak átlagos irányából.
func cam_span(a: float, b: float, speed := 1.6) -> void:
	cam_speed = speed
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var box := AABB(HL.pos(lo), Vector3.ZERO)
	var k := lo
	while k < hi:
		box = box.expand(HL.pos(k))
		k += 4.0
	box = box.expand(HL.pos(hi))
	var mid := (lo + hi) / 2.0
	cam_look_t = box.get_center() + Vector3(0, 0.8, 0) + HL.fwd(mid) * 2.0
	var d := clampf(box.size.length() * 0.62 + 9.0, 10.0, 80.0)
	cam_yaw_t = HL.heading(mid)
	cam_off_t = Vector3(d * 0.42, d * 0.55, d * 0.85)
	cam_s = mid


## look: világpont; off: eltolás az út keretében (x jobbra, y fel, z hátra), yaw: a keret iránya.
func cam_at(look: Vector3, off: Vector3, speed := 2.0, yaw := NAN) -> void:
	cam_speed = speed
	cam_look_t = look
	cam_off_t = off
	cam_yaw_t = HL.heading(HL.s_of(look)) if is_nan(yaw) else yaw
	cam_s = HL.s_of(look)


func cam_snap() -> void:
	cam_look = cam_look_t
	cam_off = cam_off_t
	cam_yaw = cam_yaw_t


func _update_camera(dt: float) -> void:
	var k := 1.0 - exp(-dt * cam_speed)
	cam_look = cam_look.lerp(cam_look_t, k)
	cam_off = cam_off.lerp(cam_off_t, k)
	# a forgás lassabb, mint a követés: a kanyarban fokozatosan fordul be
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_t, 1.0 - exp(-dt * minf(cam_speed, 2.2)))
	shake = maxf(0.0, shake - dt * 2.0)
	var sh := Vector3(FX.fr(-1, 1), FX.fr(-1, 1), 0) * shake * 0.15
	camera.position = cam_look + Basis(Vector3.UP, -cam_yaw) * cam_off + sh
	camera.look_at(cam_look + sh * 0.5, Vector3.UP)


func project(p: Vector3) -> Vector2:
	if camera.is_position_behind(p):
		return Vector2(-999, -999)
	return camera.unproject_position(p)
