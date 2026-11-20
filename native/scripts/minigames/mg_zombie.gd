extends Minigame
## Zombifogó – éjszakai temető kovácsoltvas kerítéssel. A sírkövek között kóbor zombik csoszognak;
## akit megérint egy zombi, maga is zombivá változik, és onnantól ő is a többieket kergeti
## (a játékos végig irányítja a figuráját). Az utolsó ember nyer; a helyezés: ki meddig maradt ember.
##
## A kezdő zombik a pálya veszélyei (mint a vakondok vagy a bárányok), nem résztvevők:
## a ranglistában csak a valódi játékosok szerepelnek.

const K = preload("res://scripts/minigames/mg_kit.gd")

# ------------------------------------------------------------------ beállítások
const LIMIT := 60.0
const AX := 9.0                    # a kerítésen belüli fél szélesség
const AZ := 6.0                    # a kerítésen belüli fél mélység
const BODY := 0.38                 # a figurák sugara
const TOUCH := 0.74                # ennél közelebb = megérintette (a két test összeér)
const H_ACC := 40.0
const H_MAXV := 4.6                # ember
const Z_ACC := 58.0                # zombi-játékos: kicsit lassabb, de fürgébben fordul
const Z_MAXV := 4.15
const N_ACC := 22.0                # kóbor zombi
const N_MAXV := 3.1
const N_DETECT := 6.5              # ennyiről veszi észre az embert
const TURN_TIME := 0.8             # az átváltozás ideje (közben se nem fertőz, se nem fertőzhető)
const RISE_TIME := 1.4             # a kezdő zombik ennyi idő alatt másznak elő a földből
const END_TIME := 3.4
const MS := 1.0

# sírkövek: [x, z, fajta, elforgatás] – kézzel, szabálytalanul; körülöttük mindenütt van kiút
const STONES := [
	[-5.8, -3.6, "round", 0.08], [-2.4, -4.2, "tall", -0.05], [1.9, -3.6, "cross", 0.1], [5.0, -4.1, "rect", -0.06],
	[7.0, -1.2, "round", 0.12], [-6.9, 0.5, "rect", 0.04], [-3.3, -0.5, "cracked", -0.1], [3.0, 0.5, "tall", 0.07],
	[5.8, 2.9, "cracked", -0.08], [-4.9, 3.5, "round", 0.05], [-0.6, 3.1, "rect", -0.03],
]
const STONE_SIZE := {"round": Vector2(0.9, 0.3), "tall": Vector2(0.72, 0.32), "rect": Vector2(1.15, 0.36), "cross": Vector2(0.62, 0.3), "cracked": Vector2(0.9, 0.3)}
const TREE := Vector3(0.2, -1.1, 0.5)      # a középső görbe fa: x, z, törzs-sugár
const NPC_SPAWN := [Vector2(-7.4, -4.7), Vector2(7.4, -4.6), Vector2(-7.6, 4.6), Vector2(7.5, 4.7), Vector2(0.0, -4.9)]

var st: Array = []                 # játékosok
var npcs: Array = []               # kóbor zombik
var obstacles: Array = []          # {x, z, hx, hz} téglalapok vagy {x, z, r} körök
var phase := "pre"                 # pre | play | end
var end_t := 0.0
var end_kind := ""                 # last | none | time | solo
var puffs: Array = []              # 3D füstpamacsok (csak látvány)
var fogs: Array = []
var clouds: Array = []
var moon_light: DirectionalLight3D
var flash_at := 4.0
var flash_t := -10.0
var thunder_at := -1.0
var owl_at := 6.0
var groan_at := 3.0
var zmats := {}                    # eredeti anyag -> zombi színű másolat


func meta() -> Dictionary:
	return {"id": "zombie", "name": "Zombifogó", "icon": "🧟", "color": "#6d9b3a", "modes": ["ffa"],
		"keep_ties": true, "own_end": true, "music": "spooky",
		"tagline": "Az utolsó ember nyer!",
		"desc": "Éjszaka a temetőben zombik csoszognak a sírkövek között. Akit megérint egy zombi, maga is zombivá változik – és onnantól ő is a többieket kergeti! Az nyer, aki utolsóként marad ember; ha az idő végén többen is emberek, holtversenyben nyernek. A helyezést az dönti el, ki meddig bírta.",
		"controls": "A joystickkal (gépen WASD/nyilak) futsz. Emberként menekülj és bújj a sírkövek mögé; zombiként kapd el a megmaradt embereket."}


func layout(p) -> Dictionary:
	var s := _get(p)
	if not s.is_empty() and s.state != "human":
		return {"mode": "stick", "noBtn": true, "title": "🧟 Zombi vagy! Kapd el őket!"}
	return {"mode": "stick", "noBtn": true, "title": "🏃 Menekülj a zombik elől!"}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	make_env("#070b24", "#25385f", 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7f93c9")
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color("#2b3d63")
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15
	env.glow_intensity = 0.9
	make_camera(Vector3(0, 14.5, 12.6), Vector3(0, 0, 0.4), 44)
	moon_light = make_sun(Vector3(-52, 28, 0), 0.95, "#b9c8ff")
	moon_light.shadow_blur = 2.0
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 6, 2)
	lamp.omni_range = 18.0
	lamp.light_energy = 0.45
	lamp.light_color = Color("#9fb4ff")
	add_child(lamp)
	_build_ground()
	_build_fence()
	_build_stones()
	_build_trees()
	_build_sky()
	var n := players.size()
	for i in n:
		_make_player(players[i], i, n)
	var nz := 2 if n <= 2 else (3 if n <= 4 else 4)
	for k in nz:
		_make_npc(NPC_SPAWN[k], k)
	_sync(0.0)


func _build_ground() -> void:
	Chars3D.box(self, 90, 1.0, 70, Chars3D.mat("#16302c", {"rough": 1.0}), Vector3(0, -0.52, 0))
	Chars3D.box(self, AX * 2 + 0.6, 0.2, AZ * 2 + 0.6, Chars3D.mat("#2f5d50", {"rough": 1.0}), Vector3(0, -0.1, 0))
	var patch := Chars3D.mat("#3b6f5f", {"rough": 1.0})
	var dirt := Chars3D.mat("#4a3a2e", {"rough": 1.0})
	var tuft := Chars3D.mat("#2a5446", {"rough": 1.0})
	for i in 14:
		var x := FX.fr(-AX + 1, AX - 1)
		var z := FX.fr(-AZ + 1, AZ - 1)
		Chars3D.lcyl(self, FX.fr(0.6, 1.4), FX.fr(0.6, 1.4), 0.02, patch, x, 0.005, z, 9, Vector3(0, FX.fr(0, TAU), 0)).scale = Vector3(1.0, 1.0, FX.fr(0.5, 0.9))
	# a sírok előtt kis földhantok
	for sd in STONES:
		var m := Chars3D.lcyl(self, 0.5, 0.55, 0.05, dirt, sd[0], 0.02, sd[1] + 0.55, 8)
		m.scale = Vector3(1.0, 1.0, 0.75)
	for i in 110:
		var x := FX.fr(-AX + 0.3, AX - 0.3)
		var z := FX.fr(-AZ + 0.3, AZ - 0.3)
		var c := Chars3D.lcone(self, 0.07, FX.fr(0.12, 0.22), tuft, x, 0.06, z, 4)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Kovácsoltvas kerítés: vékony rudak hegyes véggel, két vízszintes pánt, kőoszlopok, elöl zárt nagykapu.
func _build_fence() -> void:
	var iron := Chars3D.mat("#1d1f2b", {"rough": 0.35, "metal": 0.75})
	var stone := Chars3D.mat("#59606e", {"rough": 0.95})
	var cap := Chars3D.mat("#6f7684", {"rough": 0.9})
	var bars: Array = []                 # rudak Transform3D-i (MultiMesh)
	var spikes: Array = []
	var h := 1.25
	var ex := AX + 0.15
	var ez := AZ + 0.15
	var sides := [[Vector2(-ex, -ez), Vector2(ex, -ez)], [Vector2(ex, -ez), Vector2(ex, ez)], [Vector2(ex, ez), Vector2(-ex, ez)], [Vector2(-ex, ez), Vector2(-ex, -ez)]]
	for sd in sides:
		var a: Vector2 = sd[0]
		var b: Vector2 = sd[1]
		var cnt := int(a.distance_to(b) / 0.3)
		for k in cnt + 1:
			var q := a.lerp(b, float(k) / cnt)
			# a kapu helyén (elöl, középen) a kapu saját rúdjai állnak
			if absf(q.y - ez) < 0.01 and absf(q.x) < 1.3:
				continue
			bars.append(Transform3D(Basis(), Vector3(q.x, h / 2.0, q.y)))
			spikes.append(Transform3D(Basis(), Vector3(q.x, h + 0.08, q.y)))
		for y in [0.25, h - 0.15]:
			var m := Vector2((a.x + b.x) / 2.0, (a.y + b.y) / 2.0)
			var len := a.distance_to(b)
			var horiz := absf(a.y - b.y) < 0.01
			Chars3D.box(self, len if horiz else 0.05, 0.05, 0.05 if horiz else len, iron, Vector3(m.x, y, m.y))
	_multi(bars, _cyl_mesh(0.022, 0.022, h, 5), iron)
	_multi(spikes, _cyl_mesh(0.0, 0.05, 0.16, 4), iron)
	# kőoszlopok
	for x in [-ex, -ex / 2.0, 0.0, ex / 2.0, ex]:
		for z in [-ez, ez]:
			if z > 0 and absf(x) < 0.5:
				continue
			# elöl alacsonyabb oszlopok, hogy ne takarják a figurákat
			var ph := 1.55 if z < 0 else 1.15
			Chars3D.box(self, 0.42, ph, 0.42, stone, Vector3(x, ph / 2.0, z))
			Chars3D.box(self, 0.52, 0.12, 0.52, cap, Vector3(x, ph + 0.05, z))
	for z in [-ez / 2.0, 0.0, ez / 2.0]:
		for x in [-ex, ex]:
			Chars3D.box(self, 0.42, 1.55, 0.42, stone, Vector3(x, 0.77, z))
			Chars3D.box(self, 0.52, 0.12, 0.52, cap, Vector3(x, 1.6, z))
	# a nagykapu: két kőpillér, két zárt kapuszárny íves tetővel, középen lakat
	for side in [-1, 1]:
		Chars3D.box(self, 0.55, 1.5, 0.55, stone, Vector3(side * 1.45, 0.75, ez))
		Chars3D.lsphere(self, 0.26, cap, side * 1.45, 1.65, ez, 1, 1, 1, 8, 5)
		for k in 7:
			var x: float = side * (0.12 + k * 0.17)
			var top := 1.55 + 0.35 * sin((1.0 - (k / 6.0)) * PI / 2.0)
			Chars3D.lcyl(self, 0.024, 0.024, top, iron, x, top / 2.0, ez, 5)
			Chars3D.lcone(self, 0.05, 0.16, iron, x, top + 0.08, ez, 4)
		for y in [0.3, 0.9, 1.45]:
			Chars3D.box(self, 1.15, 0.05, 0.05, iron, Vector3(side * 0.6, y, ez))
		var ring := MeshInstance3D.new()
		ring.mesh = Chars3D.torus(0.2, 0.025)
		ring.material_override = iron
		ring.position = Vector3(side * 0.6, 1.0, ez + 0.02)
		add_child(ring)
	Chars3D.box(self, 0.18, 0.22, 0.1, Chars3D.mat("#a07a2c", {"metal": 0.6, "rough": 0.4}), Vector3(0, 0.95, ez + 0.05))


func _cyl_mesh(r1: float, r2: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _multi(tfs: Array, mesh: Mesh, m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	add_child(mi)


func _build_stones() -> void:
	var g1 := Chars3D.mat("#7d8592", {"rough": 0.95})
	var g2 := Chars3D.mat("#6a717d", {"rough": 0.95})
	var dark := Chars3D.mat("#3a3f49", {"rough": 1.0})
	var moss := Chars3D.mat("#4f7a4a", {"rough": 1.0})
	for i in STONES.size():
		var sd: Array = STONES[i]
		var kind: String = sd[2]
		var sz: Vector2 = STONE_SIZE[kind]
		obstacles.append({"x": sd[0], "z": sd[1], "hx": sz.x / 2.0, "hz": sz.y / 2.0})
		var g := Node3D.new()
		g.position = Vector3(sd[0], 0, sd[1])
		g.rotation = Vector3(sd[3] * 0.6, sd[3], sd[3] * 0.8)
		add_child(g)
		var mat := g1 if i % 2 == 0 else g2
		match kind:
			"round", "cracked":
				Chars3D.box(g, sz.x, 0.62, sz.y, mat, Vector3(0, 0.31, 0))
				var top := Chars3D.lcyl(g, sz.x / 2.0, sz.x / 2.0, sz.y, mat, 0, 0.62, 0, 10, Vector3(PI / 2, 0, 0))
				top.scale = Vector3(1, 1, 1)
				if kind == "cracked":
					Chars3D.box(g, 0.05, 0.42, sz.y + 0.02, dark, Vector3(0.1, 0.55, 0), Vector3(0, 0, 0.5))
					Chars3D.box(g, 0.04, 0.25, sz.y + 0.02, dark, Vector3(-0.04, 0.32, 0), Vector3(0, 0, -0.4))
					Chars3D.box(g, 0.22, 0.14, 0.12, mat, Vector3(0.35, 0.05, 0.32), Vector3(0.3, 0.6, 0.2))
			"tall":
				Chars3D.box(g, sz.x, 1.25, sz.y, mat, Vector3(0, 0.62, 0))
				Chars3D.part(g, Chars3D.prism([[-sz.x / 2.0, 0.0], [sz.x / 2.0, 0.0], [0.0, 0.32]], sz.y), mat, Vector3(0, 1.25, 0))
			"rect":
				Chars3D.box(g, sz.x, 0.78, sz.y, mat, Vector3(0, 0.39, 0))
				Chars3D.box(g, sz.x + 0.12, 0.1, sz.y + 0.1, dark, Vector3(0, 0.82, 0))
			"cross":
				Chars3D.box(g, sz.x, 0.3, sz.y, mat, Vector3(0, 0.15, 0))
				Chars3D.box(g, 0.22, 1.35, 0.2, mat, Vector3(0, 0.95, 0))
				Chars3D.box(g, 0.8, 0.2, 0.2, mat, Vector3(0, 1.25, 0))
		# felirat-bevágás és moha
		if kind != "cross":
			Chars3D.box(g, sz.x * 0.5, 0.05, 0.02, dark, Vector3(0, 0.45, sz.y / 2.0 + 0.005))
			Chars3D.box(g, sz.x * 0.35, 0.05, 0.02, dark, Vector3(0, 0.33, sz.y / 2.0 + 0.005))
		Chars3D.lsphere(g, 0.14, moss, -sz.x * 0.3, 0.05, sz.y / 2.0, 1.4, 0.5, 0.8, 6, 3)


func _twisted_tree(x: float, z: float, s: float, inside: bool) -> void:
	var bark := Chars3D.mat("#3b2a35" if inside else "#1c1826", {"rough": 0.95})
	var g := Node3D.new()
	g.position = Vector3(x, 0, z)
	g.rotation.y = FX.fr(0, TAU)
	g.scale = Vector3.ONE * s
	add_child(g)
	# görbe törzs: egymásra dőlő, vékonyodó szakaszok
	var p := Vector3.ZERO
	var r := 0.5
	var lean := Vector3(0.18, 1.0, 0.05)
	for k in 5:
		var seg_h := 0.75
		var dir := (lean + Vector3(sin(k * 1.7) * 0.35, 0, cos(k * 1.3) * 0.25)).normalized()
		var q := p + dir * seg_h
		var mi := Chars3D.lcyl(g, r * 0.82, r, seg_h + 0.12, bark, 0, 0, 0, 7)
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), (p + q) / 2.0)
		p = q
		r *= 0.82
	# kacskaringós ágak
	for k in 6:
		var a := k * TAU / 6.0 + 0.4
		var base := Vector3(0, 1.9 + (k % 3) * 0.55, 0) + Vector3(sin(k * 1.7) * 0.35, 0, 0)
		var dir := Vector3(cos(a), 0.55 + (k % 2) * 0.35, sin(a)).normalized()
		var len := 0.9 + (k % 3) * 0.35
		var mi := Chars3D.lcyl(g, 0.04, 0.12, len, bark, 0, 0, 0, 5)
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), base + dir * len / 2.0)
		var tip := base + dir * len
		var d2 := (dir + Vector3(-dir.z, 0.5, dir.x) * 0.8).normalized()
		var tw := Chars3D.lcyl(g, 0.015, 0.05, 0.5, bark, 0, 0, 0, 4)
		tw.transform = Transform3D(Basis(Quaternion(Vector3.UP, d2)), tip + d2 * 0.25)


func _build_trees() -> void:
	obstacles.append({"x": TREE.x, "z": TREE.y, "r": TREE.z})
	_twisted_tree(TREE.x, TREE.y, 1.0, true)
	for c in [Vector2(-11.0, -7.2), Vector2(11.2, -7.0), Vector2(-11.8, 3.5), Vector2(12.0, 4.2), Vector2(-3.2, -8.4), Vector2(5.5, -8.6)]:
		_twisted_tree(c.x, c.y, FX.fr(1.2, 1.6), false)
	var pine := Chars3D.mat("#0f1a26", {"rough": 1.0})
	for side in [-1, 1]:
		for i in 9:
			var h := FX.fr(4.0, 7.5)
			Chars3D.lcone(self, h * 0.28, h, pine, side * FX.fr(15.0, 22.0), h / 2.0 - 0.3, -12.0 + i * 2.6, 6)


func _build_sky() -> void:
	# A rögzített, felülről néző kamerából csak a temető mögötti keskeny sáv látszik az égből:
	# oda egy kamera felé forduló „festett” háttérfal kerül (színátmenetes ég, csillagok),
	# előtte a telihold, a vándorló felhők és a távoli erdő sziluettje.
	var bz := -10.6
	var tilt := -0.5                       # a fal teteje hátradől, így szemből látszik
	var sky := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(80, 12)
	sky.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = _sky_tex()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.set("disable_fog", true)
	sky.material_override = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = Vector3(0, 4.6, bz - 2.9)
	sky.rotation = Vector3(tilt, 0, 0)
	add_child(sky)
	var moon := Chars3D.mat("#fff4cf", {"emit": "#fff1c2", "emit_e": 2.4, "unshaded": true})
	moon.set("disable_fog", true)
	Chars3D.sphere(self, 1.05, moon, -6.5, 1.55, bz - 0.6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var crater := Chars3D.mat("#e9dcae", {"unshaded": true})
	crater.set("disable_fog", true)
	for cr in [Vector3(-0.35, 0.3, 1.1), Vector3(0.4, -0.25, 1.12), Vector3(0.1, 0.55, 1.05)]:
		Chars3D.sphere(self, 0.19, crater, -6.5 + cr.x * 0.85, 1.55 + cr.y * 0.85, bz - 0.6 + cr.z * 0.9, 1, 1, 0.3)
	var halo := Chars3D.mat("#bcd0ff", {"alpha": 0.14, "unshaded": true})
	halo.set("disable_fog", true)
	Chars3D.sphere(self, 1.7, halo, -6.5, 1.55, bz - 0.9, 1, 1, 0.2).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# vándorló felhők a hold előtt
	var cloud := Chars3D.mat("#41507f", {"alpha": 0.82, "rough": 1.0, "unshaded": true})
	cloud.set("disable_fog", true)
	for i in 6:
		var g := Node3D.new()
		add_child(g)
		for j in 4:
			var cs := Chars3D.lsphere(g, FX.fr(0.45, 0.75), cloud, (j - 1.5) * 0.7, FX.fr(-0.1, 0.2), FX.fr(-0.1, 0.1), 1.6, 0.55, 0.6, 8, 4)
			cs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds.append({"g": g, "x": -24.0 + i * 8.5, "y": FX.fr(1.5, 2.6), "z": bz + 0.1, "v": FX.fr(0.35, 0.7)})
	# távoli erdő sziluettje a hold előtt
	var pine := Chars3D.mat("#0d1622", {"rough": 1.0})
	for i in 30:
		var x := -30.0 + i * 2.05 + FX.fr(-0.5, 0.5)
		var h := FX.fr(0.9, 1.7) if absf(x + 6.5) > 2.0 else FX.fr(0.5, 0.9)
		Chars3D.lcone(self, h * 0.35, h, pine, x, h / 2.0 - 0.1, bz + 0.4 + FX.fr(-0.3, 0.3), 6)
	# talaj menti köd: puha szélű, áttetsző lapok
	var tex := _soft_tex()
	for i in 7:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(FX.fr(7, 11), FX.fr(4, 6))
		mi.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = tex
		fm.albedo_color = Color(0.75, 0.82, 1.0, 0.16)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = fm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		fogs.append({"mi": mi, "x": FX.fr(-AX, AX), "z": FX.fr(-AZ, AZ), "v": FX.fr(0.25, 0.5) * (1 if i % 2 else -1), "y": 0.12 + i * 0.03})


## Éjszakai ég: fent mélykék, a láthatár felé lilás derengés, apró csillagok.
static func _sky_tex() -> ImageTexture:
	var w := 256
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var k := float(y) / (h - 1)
		var c := Color("#0a0f2e").lerp(Color("#2c2f6b"), k).lerp(Color("#5a4a86"), maxf(0.0, k - 0.7) / 0.3 * 0.6)
		for x in w:
			img.set_pixel(x, y, c)
	for i in 70:
		var x := int(FX.fr(0, w - 1))
		var y := int(FX.fr(0, h * 0.75))
		img.set_pixel(x, y, Color(1, 1, 0.9, FX.fr(0.5, 1.0)))
	return ImageTexture.create_from_image(img)


static func _soft_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)


func _make_player(p, i: int, n: int) -> void:
	var m := player_model(p, MS)
	var col: Color = p.color
	var feet: Array = []
	var shoe := Chars3D.mat(D.shade(col, -0.45).to_html(), {"rough": 0.6})
	for side in [-1, 1]:
		feet.append(Chars3D.lsphere(m, 0.09, shoe, side * 0.14, 0.04, 0.05, 1.0, 0.55, 1.4, 8, 4))
	var disc := color_disc(p, 0.46)
	add_child(disc)
	# kezdőhelyek: a temető közepén, egymástól távol, a sírköveken kívül
	var a := float(i) / maxi(1, n) * TAU + 0.3
	var rr := 2.2 if n > 1 else 0.0
	var x := sin(a) * rr * 1.6
	var z := 1.4 + cos(a) * rr * 0.75
	var s := {"p": p, "i": i, "m": m, "col": col, "feet": feet, "disc": disc,
		"arms": K.build_arms(m, col.to_html(), 0.42), "face": K.build_face(m),
		"x": x, "z": z, "vx": 0.0, "vz": 0.0, "ix": 0.0, "iy": 0.0, "yaw": PI, "state": "human", "turn_t": -10.0,
		"out_t": -1.0, "zlook": false, "fear": 0.0, "kb_t": -10.0, "ai_t": 0.0, "tx": 0.0, "tz": 0.0, "dust": 0.0, "look_back": 0.0}
	_push_out(s)
	st.append(s)


## Kóbor zombi: saját, rajzfilmes figura – zöldes bőr, karikás szem, előrenyújtott kar.
func _make_npc(pos: Vector2, k: int) -> void:
	var g := Node3D.new()
	add_child(g)
	var skin := Chars3D.mat(["#8fbf6a", "#9fb98a", "#86b38f"][k % 3], {"rough": 0.75})
	var shirt := Chars3D.mat(["#6b4f8c", "#8c5a3c", "#4f6b8c", "#7a3f5c", "#5c7a3f"][k % 5], {"rough": 0.9})
	var pants := Chars3D.mat("#3d3550", {"rough": 0.9})
	var white := Chars3D.mat("#f3f7d9", {"rough": 0.5})
	var dark := Chars3D.mat("#1f1a2b", {"rough": 0.5})
	var ring := Chars3D.mat("#5b3f6e", {"rough": 0.8})
	var body := Node3D.new()
	g.add_child(body)
	var legs: Array = []
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.13, 0.45, 0)
		body.add_child(leg)
		Chars3D.lcyl(leg, 0.09, 0.1, 0.45, pants, 0, -0.22, 0, 6)
		Chars3D.lsphere(leg, 0.1, dark, 0, -0.43, 0.05, 1, 0.6, 1.4, 6, 3)
		legs.append(leg)
	Chars3D.lcyl(body, 0.27, 0.31, 0.55, shirt, 0, 0.72, 0, 7)
	# szakadt ingalj: pár lelógó háromszög
	for j in 5:
		var a := j * TAU / 5.0
		Chars3D.lcone(body, 0.08, 0.14, shirt, sin(a) * 0.28, 0.42, cos(a) * 0.28, 4, Vector3(PI, 0, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 1.22, 0.02)
	body.add_child(head)
	Chars3D.lsphere(head, 0.3, skin, 0, 0, 0, 1.0, 0.95, 0.95, 9, 6)
	for side in [-1, 1]:
		Chars3D.lsphere(head, 0.1, ring, side * 0.11, 0.05, 0.22, 1, 1, 0.5, 7, 4)
		Chars3D.lsphere(head, 0.075, white, side * 0.11, 0.05, 0.25, 1, 0.8, 0.6, 7, 4)
		Chars3D.lsphere(head, 0.03, dark, side * 0.11 + side * 0.01, 0.04, 0.3, 1, 1, 0.6, 5, 3)
	Chars3D.lsphere(head, 0.08, dark, 0.02, -0.13, 0.24, 1.3, 0.7, 0.5, 6, 3)
	Chars3D.box(head, 0.05, 0.05, 0.02, white, Vector3(-0.03, -0.1, 0.28))
	for j in 3:
		Chars3D.lcone(head, 0.06, 0.16, dark, -0.1 + j * 0.1, 0.3, -0.02, 4, Vector3(FX.fr(-0.4, 0.4), 0, FX.fr(-0.4, 0.4)))
	var arms: Array = []
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.32, 0.92, 0.02)
		body.add_child(arm)
		Chars3D.lcyl(arm, 0.075, 0.085, 0.5, shirt, 0, 0, 0.12, 6, Vector3(PI / 2, 0, 0))
		Chars3D.lcyl(arm, 0.06, 0.065, 0.2, skin, 0, 0, 0.45, 6, Vector3(PI / 2, 0, 0))
		Chars3D.lsphere(arm, 0.08, skin, 0, 0, 0.58, 1, 0.8, 1.1, 6, 3)
		arms.append(arm)
	var x := pos.x
	var z := pos.y
	npcs.append({"g": g, "body": body, "head": head, "legs": legs, "arms": arms, "k": k, "x": x, "z": z, "vx": 0.0, "vz": 0.0,
		"yaw": atan2(-x, -z), "target": -1, "wx": 0.0, "wz": 0.0, "think": 0.0, "stuck_t": 0.0, "last": Vector2(x, z), "wander_until": 0.0})


# ------------------------------------------------------------------ ütközés
func _push_out(s: Dictionary) -> void:
	for o in obstacles:
		if o.has("r"):
			var d := Vector2(s.x - o.x, s.z - o.z)
			var mind: float = o.r + BODY
			if d.length() < mind:
				var nrm := d.normalized() if d.length() > 0.001 else Vector2(1, 0)
				s.x = o.x + nrm.x * mind
				s.z = o.z + nrm.y * mind
				var vn: float = s.vx * nrm.x + s.vz * nrm.y
				if vn < 0:
					s.vx -= vn * nrm.x
					s.vz -= vn * nrm.y
		else:
			var cx: float = clampf(s.x, o.x - o.hx, o.x + o.hx)
			var cz: float = clampf(s.z, o.z - o.hz, o.z + o.hz)
			var d := Vector2(s.x - cx, s.z - cz)
			var dl := d.length()
			if dl < BODY:
				var nrm: Vector2
				if dl > 0.0001:
					nrm = d / dl
				else:
					# a középpont a kőben van: a legközelebbi oldalon toljuk ki
					var px: float = o.hx - absf(s.x - o.x)
					var pz: float = o.hz - absf(s.z - o.z)
					nrm = Vector2(signf(s.x - o.x) if s.x != o.x else 1.0, 0) if px < pz else Vector2(0, signf(s.z - o.z) if s.z != o.z else 1.0)
					cx = o.x + nrm.x * o.hx if nrm.x != 0 else s.x
					cz = o.z + nrm.y * o.hz if nrm.y != 0 else s.z
				s.x = cx + nrm.x * BODY
				s.z = cz + nrm.y * BODY
				var vn: float = s.vx * nrm.x + s.vz * nrm.y
				if vn < 0:
					s.vx -= vn * nrm.x
					s.vz -= vn * nrm.y
	# kerítés
	s.x = clampf(s.x, -AX + BODY, AX - BODY)
	s.z = clampf(s.z, -AZ + BODY, AZ - BODY)


## Van-e akadály (sírkő, fa) a két pont között – a fertőzés és az észlelés ezen nem hatol át.
func _blocked(a: Vector2, b: Vector2) -> bool:
	for o in obstacles:
		if o.has("r"):
			var ab := b - a
			var l2 := ab.length_squared()
			var u: float = clampf((Vector2(o.x, o.z) - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
			if (a + ab * u).distance_to(Vector2(o.x, o.z)) < o.r:
				return true
		else:
			var t0 := 0.0
			var t1 := 1.0
			var d := b - a
			var ok := true
			for ax in 2:
				var lo: float = (o.x - o.hx) if ax == 0 else (o.z - o.hz)
				var hi: float = (o.x + o.hx) if ax == 0 else (o.z + o.hz)
				var p0: float = a.x if ax == 0 else a.y
				var dd: float = d.x if ax == 0 else d.y
				if absf(dd) < 0.00001:
					if p0 < lo or p0 > hi:
						ok = false
						break
				else:
					var ta := (lo - p0) / dd
					var tb := (hi - p0) / dd
					t0 = maxf(t0, minf(ta, tb))
					t1 = minf(t1, maxf(ta, tb))
					if t0 > t1:
						ok = false
						break
			if ok:
				return true
	return false


## Kerülő irány: az akadályok és a kerítés eltaszít, a megkerülés felé is terel.
func _steer(x: float, z: float, want: Vector2) -> Vector2:
	var out := want
	for o in obstacles:
		var d: Vector2
		var dist: float
		if o.has("r"):
			d = Vector2(x - o.x, z - o.z)
			dist = d.length() - o.r
		else:
			var c := Vector2(clampf(x, o.x - o.hx, o.x + o.hx), clampf(z, o.z - o.hz, o.z + o.hz))
			d = Vector2(x, z) - c
			dist = d.length()
		if dist > 1.4 or d.length() < 0.0001:
			continue
		var nrm := d.normalized()
		var k := (1.4 - dist) / 1.4
		out += nrm * k * 1.6
		# megkerülés: a haladási iránnyal egyező érintő felé
		var tan := Vector2(-nrm.y, nrm.x)
		if tan.dot(want) < 0:
			tan = -tan
		out += tan * k * 1.4
	var m := 1.2
	if x < -AX + m: out.x += (-AX + m - x) * 1.5
	if x > AX - m: out.x -= (x - AX + m) * 1.5
	if z < -AZ + m: out.y += (-AZ + m - z) * 1.5
	if z > AZ - m: out.y -= (z - AZ + m) * 1.5
	return out.normalized() if out.length() > 0.001 else Vector2.ZERO


# ------------------------------------------------------------------ menet
func start() -> void:
	phase = "play"
	Audio.play("groan")


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
	if msg.get("kb", false):
		s.kb_t = t
	s.ix = clampf(float(msg.get("x", 0)), -1.0, 1.0)
	s.iy = clampf(float(msg.get("y", 0)), -1.0, 1.0)


## Csak a fejlesztői tesztbotoknak (--bots) és a lecsatlakozott játékosok helyett: emberként
## menekül, zombiként üldöz. Valódi meccsbe a játék nem tesz gépi résztvevőt.
func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.is_empty() or phase != "play" or t - float(s.kb_t) < 1.5:
		return
	s.ai_t -= dt
	if s.ai_t > 0.0:
		return
	s.ai_t = randf_range(0.12, 0.25)
	var here := Vector2(s.x, s.z)
	var want := Vector2.ZERO
	if s.state == "human":
		for z in _zombie_points():
			var d: Vector2 = here - z
			var l := d.length()
			if l < 6.0 and l > 0.01:
				want += d / (l * l)
		if want.length() < 0.02:
			# nincs közeli veszély: lassan kóborol
			if here.distance_to(Vector2(s.tx, s.tz)) < 0.8 or randf() < 0.05:
				s.tx = randf_range(-AX + 2, AX - 2)
				s.tz = randf_range(-AZ + 2, AZ - 2)
			want = (Vector2(s.tx, s.tz) - here).normalized() * 0.5
		else:
			want = want.normalized() + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	elif s.state == "zombie":
		var best := INF
		var tgt := here
		for q in st:
			if q.state != "human":
				continue
			var qp := Vector2(q.x, q.z) + Vector2(q.vx, q.vz) * 0.3
			var d := here.distance_to(qp)
			if d < best:
				best = d
				tgt = qp
		want = (tgt - here).normalized()
	var dir := _steer(s.x, s.z, want)
	s.ix = dir.x
	s.iy = dir.y


func _zombie_points() -> Array:
	var out: Array = []
	for z in npcs:
		out.append(Vector2(z.x, z.z))
	for q in st:
		if q.state == "zombie":
			out.append(Vector2(q.x, q.z))
	return out


func _humans() -> Array:
	return st.filter(func(q): return q.state == "human")


func update(dt: float) -> void:
	if phase == "play":
		for s in st:
			_move_player(s, dt)
		_npc_ai(dt)
		_separate()
		_infect()
		_check_end()
	elif phase == "end":
		for s in st:
			s.vx *= pow(0.02, dt)
			s.vz *= pow(0.02, dt)
		if t - end_t >= END_TIME:
			finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _move_player(s: Dictionary, dt: float) -> void:
	if s.state == "turning":
		s.vx = 0.0
		s.vz = 0.0
		if t - float(s.turn_t) >= TURN_TIME:
			s.state = "zombie"
			Net.set_ctrl(s.p.pid, layout(s.p))
		return
	var zed: bool = s.state == "zombie"
	var acc := Z_ACC if zed else H_ACC
	var maxv := Z_MAXV if zed else H_MAXV
	s.vx += s.ix * acc * dt
	s.vz += s.iy * acc * dt
	var fr := pow(0.004 if zed else 0.02, dt)
	s.vx *= fr
	s.vz *= fr
	var sp := Vector2(s.vx, s.vz).length()
	if sp > maxv:
		s.vx *= maxv / sp
		s.vz *= maxv / sp
	s.x += s.vx * dt
	s.z += s.vz * dt
	_push_out(s)


func _npc_ai(dt: float) -> void:
	var rise := t < RISE_TIME
	var humans := _humans()
	for z in npcs:
		if rise:
			continue
		var here := Vector2(z.x, z.z)
		z.think -= dt
		if z.think <= 0.0:
			z.think = randf_range(0.35, 0.55)
			# a legközelebbi, látható embert üldözi; ha nincs ilyen, kóborol
			z.target = -1
			if t >= float(z.wander_until):
				var best := N_DETECT
				for q in humans:
					var d := here.distance_to(Vector2(q.x, q.z))
					if d < best and not _blocked(here, Vector2(q.x, q.z)):
						best = d
						z.target = st.find(q)
				if z.target < 0:
					for q in humans:
						var d := here.distance_to(Vector2(q.x, q.z))
						if d < 2.6 and d < best:
							best = d
							z.target = st.find(q)
			if z.target < 0 and (here.distance_to(Vector2(z.wx, z.wz)) < 0.8 or randf() < 0.12):
				z.wx = randf_range(-AX + 1.5, AX - 1.5)
				z.wz = randf_range(-AZ + 1.5, AZ - 1.5)
			# beragadás: ha alig mozdult, egy ideig máshová indul
			if here.distance_to(z.last) < 0.25:
				z.stuck_t += 0.45
				if z.stuck_t > 1.2:
					z.stuck_t = 0.0
					z.wander_until = t + 1.6
					z.target = -1
					z.wx = randf_range(-AX + 1.5, AX - 1.5)
					z.wz = randf_range(-AZ + 1.5, AZ - 1.5)
			else:
				z.stuck_t = 0.0
			z.last = here
		var goal := Vector2(z.wx, z.wz)
		if z.target >= 0 and z.target < st.size() and st[z.target].state == "human":
			goal = Vector2(st[z.target].x, st[z.target].z)
		var dir := _steer(z.x, z.z, (goal - here).normalized())
		z.vx += dir.x * N_ACC * dt
		z.vz += dir.y * N_ACC * dt
		var fr := pow(0.03, dt)
		z.vx *= fr
		z.vz *= fr
		var sp := Vector2(z.vx, z.vz).length()
		var maxv := N_MAXV if z.target >= 0 else N_MAXV * 0.6
		if sp > maxv:
			z.vx *= maxv / sp
			z.vz *= maxv / sp
		z.x += z.vx * dt
		z.z += z.vz * dt
		_push_out(z)


## A testek nem hatolnak egymásba (ember-ember, zombi-zombi); ember és zombi összeérése fertőzés.
func _separate() -> void:
	var all: Array = []
	for s in st:
		all.append(s)
	for z in npcs:
		if t >= RISE_TIME:
			all.append(z)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Dictionary = all[i]
			var b: Dictionary = all[j]
			var dv := Vector2(a.x - b.x, a.z - b.z)
			var d := dv.length()
			if d >= BODY * 2 or d < 0.0001:
				continue
			var nrm := dv / d
			var ov := BODY * 2 - d
			a.x += nrm.x * ov / 2
			a.z += nrm.y * ov / 2
			b.x -= nrm.x * ov / 2
			b.z -= nrm.y * ov / 2
	for s in all:
		_push_out(s)


## Fertőzés: ugyanabban a lépésben észlelt minden érintés egyszerre érvényes (azonos időpont = holtverseny).
func _infect() -> void:
	var srcs: Array = []
	if t >= RISE_TIME:
		for z in npcs:
			srcs.append(Vector2(z.x, z.z))
	for q in st:
		if q.state == "zombie":
			srcs.append(Vector2(q.x, q.z))
	var hit: Array = []
	for s in st:
		if s.state != "human":
			continue
		var me := Vector2(s.x, s.z)
		for z in srcs:
			if me.distance_to(z) <= TOUCH and not _blocked(me, z):
				hit.append(s)
				break
	for s in hit:
		s.state = "turning"
		s.turn_t = t
		s.out_t = t
		s.vx = 0.0
		s.vz = 0.0
		Audio.play("zombify")
		Net.vibrate(s.p.pid, [80, 40, 160])
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🧟", "title": "Megfertőztek!", "text": "Zombivá változol… mindjárt te kergetsz!"})
		_smoke(Vector3(s.x, 0.6, s.z))
		var q := screen(Vector3(s.x, 1.8, s.z))
		Main.I.float_text(q.x, q.y - 10, "FERTŐZÉS!", Color("#b6f36a"), 30)
		print_verbose("[zombie] %.2f mp: %s zombi lett" % [t, s.p.name])


func _check_end() -> void:
	var alive := _humans().size()
	var n := st.size()
	if n >= 2 and alive <= 1:
		end_kind = "last" if alive == 1 else "none"
	elif n == 1 and alive == 0:
		end_kind = "solo"
	elif t >= LIMIT:
		end_kind = "time"
	else:
		return
	phase = "end"
	end_t = t
	if alive > 0:
		Audio.play("win")
		Main.I.confetti(90)
	else:
		Audio.play("groan")
	for s in st:
		if s.state == "human":
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏆", "title": "Túlélted!", "text": "Ember maradtál a végéig!"})
		else:
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🧟", "title": "Vége!", "text": "Nézd a nagy képernyőt!"})
	print_verbose("[zombie] vége (%s): %s" % [end_kind, ", ".join(st.map(func(q): return "%s %s" % [q.p.name, "ember" if q.state == "human" else "%.2f" % q.out_t]))])


## Helyezés: aki tovább maradt ember, előrébb; az időben (vagy utolsóként) ember maradtak holtversenyben elöl.
func ranking() -> Array:
	return rank_by(func(p):
			var s := _get(p)
			return 1000.0 if s.state == "human" else float(s.out_t),
		func(p):
			var s := _get(p)
			return "🧍 túlélte!" if s.state == "human" else "%.1f mp" % float(s.out_t))


# ------------------------------------------------------------------ látvány
func _smoke(pos: Vector3) -> void:
	var cols := ["#9b5de5", "#7cd65a", "#b388ff", "#a3e635"]
	for i in 10:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cols[i % cols.size()])
		m.albedo_color.a = 0.75
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var a := i * TAU / 10.0 + FX.f()
		puffs.append({"mi": mi, "p": pos + Vector3(cos(a) * 0.2, FX.fr(-0.2, 0.5), sin(a) * 0.2),
			"v": Vector3(cos(a) * FX.fr(0.6, 1.4), FX.fr(0.8, 1.8), sin(a) * FX.fr(0.6, 1.4)), "life": 0.0, "max": FX.fr(0.7, 1.1)})
	var q := screen(pos)
	Main.I.burst(q.x, q.y, {"n": 36, "colors": ["#9b5de5", "#7cd65a", "#d0bfff", "#c0eb75"], "speed": 320, "gravity": -60, "life": 0.9, "size": 7})


## Zombi kinézet: a figura minden anyagát zöldes-szürkés árnyalatra színezi (a formája, haja, kiegészítői
## megmaradnak, így felismerhető), a szemek köré sötét karikát tesz.
func _zombify_look(s: Dictionary) -> void:
	var m: Chars3D.CharModel = s.m
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mat = (mi as MeshInstance3D).material_override
		if not (mat is StandardMaterial3D):
			continue
		if not zmats.has(mat):
			var c: Color = mat.albedo_color
			var lum := c.get_luminance()
			var dup: StandardMaterial3D = mat.duplicate()
			if lum < 0.16:
				dup = mat
			elif lum > 0.86:
				dup.albedo_color = c.lerp(Color("#dfe8b0"), 0.35)
			else:
				dup.albedo_color = c.lerp(Color("#8fbf6a"), 0.55).darkened(0.08)
				dup.emission_enabled = false
			zmats[mat] = dup
		(mi as MeshInstance3D).material_override = zmats[mat]
	var ring := Chars3D.mat("#4b2f5e", {"rough": 0.8})
	for e in m.eyes:
		var r := 0.06
		var e3: Node3D = e
		if e3.get_child_count() > 0 and e3.get_child(0) is MeshInstance3D and (e3.get_child(0) as MeshInstance3D).mesh is SphereMesh:
			r = ((e3.get_child(0) as MeshInstance3D).mesh as SphereMesh).radius
		Chars3D.sphere(e3, r * 1.55, ring, 0, 0, -r * 0.45, 1.0, 1.0, 0.4)
	(s.disc as MeshInstance3D).material_override = Chars3D.mat("#7cd65a", {"rough": 0.4, "emit": "#4c8a2c", "emit_e": 0.6})
	s.zlook = true


func _sync(dt: float) -> void:
	var zpts := _zombie_points()
	for s in st:
		_anim_player(s, dt, zpts)
	for z in npcs:
		_anim_npc(z, dt)
	for pf in puffs:
		pf.life += dt
		var k: float = pf.life / pf.max
		var mi: MeshInstance3D = pf.mi
		pf.p += pf.v * dt
		pf.v *= pow(0.2, dt)
		mi.position = pf.p
		mi.scale = Vector3.ONE * (0.6 + k * 1.6)
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.75 * (1.0 - k)
		if k >= 1.0:
			mi.queue_free()
	puffs = puffs.filter(func(pf): return pf.life < pf.max)
	var tm: float = Main.I.time
	for cl in clouds:
		var g: Node3D = cl.g
		g.position = Vector3(fposmod(cl.x + tm * cl.v + 40.0, 80.0) - 40.0, cl.y, cl.z)
	for f in fogs:
		var mi: MeshInstance3D = f.mi
		mi.position = Vector3(fposmod(f.x + tm * f.v + AX + 4.0, AX * 2 + 8.0) - AX - 4.0, f.y, f.z + sin(tm * 0.3 + f.x) * 0.6)
	_ambience(dt)


## Villámlás, bagoly, nyögések – csak hangulat (a látványhoz tartozó véletlenből)
func _ambience(_dt: float) -> void:
	if moon_light == null or preview:
		return
	var tm: float = Main.I.time
	if tm >= flash_at:
		flash_at = tm + FX.fr(9.0, 16.0)
		flash_t = tm
		thunder_at = tm + FX.fr(0.5, 1.1)
	if thunder_at > 0.0 and tm >= thunder_at:
		thunder_at = -1.0
		Audio.play("thunder")
	var fk := tm - flash_t
	var fl := 0.0
	if fk >= 0.0 and fk < 0.5:
		fl = maxf(0.0, 1.0 - fk / 0.12) + (maxf(0.0, 1.0 - absf(fk - 0.25) / 0.08) * 0.7)
	moon_light.light_energy = 0.95 + fl * 2.2
	env.ambient_light_energy = 0.75 + fl * 1.2
	if tm >= owl_at:
		owl_at = tm + FX.fr(10.0, 18.0)
		if phase != "pre":
			Audio.play("owl")
	if tm >= groan_at:
		groan_at = tm + FX.fr(3.5, 6.5)
		if phase == "play":
			Audio.play("groan", FX.fr(0.85, 1.15))


func _anim_player(s: Dictionary, dt: float, zpts: Array) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var tt: float = m.t
	var mv := Vector2(s.vx, s.vz)
	var spd := mv.length()
	var zed: bool = s.state == "zombie"
	var turning: bool = s.state == "turning"
	if (zed or turning) and not s.zlook and t - float(s.turn_t) >= TURN_TIME * 0.45:
		_zombify_look(s)
		Audio.play("groan", 1.2)
	if spd > 0.5:
		s.yaw = lerp_angle(float(s.yaw), atan2(mv.x, mv.y), minf(1.0, dt * (14.0 if zed else 11.0)))
	# a legközelebbi zombi: félelem, hátranézés
	var near := INF
	var near_p := Vector2.ZERO
	for z in zpts:
		var d := Vector2(s.x, s.z).distance_to(z)
		if d < near and d > 0.01:
			near = d
			near_p = z
	var fear_t := clampf((3.2 - near) / 2.4, 0.0, 1.0) if s.state == "human" else 0.0
	s.fear = lerpf(float(s.fear), fear_t, minf(1.0, dt * 6.0))
	var fear: float = s.fear
	var run := clampf(spd / H_MAXV, 0.0, 1.0)
	var ph := tt * (13.0 + fear * 5.0)
	var hop := absf(sin(ph)) * 0.12 * run
	var lean := 0.22 * run
	var roll := sin(ph) * 0.06 * run
	var yaw_off := 0.0
	var arms_t: Array = []
	var lift := [maxf(0.0, sin(ph)) * 0.14 * run, maxf(0.0, -sin(ph)) * 0.14 * run]
	var face := Vector3(0.1 + fear * 0.6, 1.0 + fear * 0.35, fear * 0.9)
	if s.state == "human":
		# menekülés: lendülő karok (félelemben hevesebben), néha hátrapillant
		var sw := sin(ph) * (0.22 + fear * 0.15) * run
		arms_t = [Vector3(-0.34, 0.3 + fear * 0.25, 0.05 + sw), Vector3(0.34, 0.3 + fear * 0.25, 0.05 - sw)]
		if fear > 0.35:
			var to_z := near_p - Vector2(s.x, s.z)
			var back := absf(angle_difference(float(s.yaw), atan2(to_z.x, to_z.y))) > 2.0
			s.look_back = lerpf(float(s.look_back), 0.55 if back and sin(tt * 2.3 + s.i) > 0.2 else 0.0, minf(1.0, dt * 8.0))
			if spd < 0.5:
				arms_t = [Vector3(-0.3, 0.75, 0.3), Vector3(0.3, 0.75, 0.3)]
				roll += sin(tt * 30.0) * 0.03
		else:
			s.look_back = lerpf(float(s.look_back), 0.0, minf(1.0, dt * 8.0))
		yaw_off = s.look_back * (1.0 if sin(tt * 0.7 + s.i) > 0 else -1.0)
		# por a futó lábak alatt
		s.dust -= dt
		if spd > 3.2 and s.dust <= 0.0 and not preview:
			s.dust = 0.22
			var q := screen(Vector3(s.x, 0.05, s.z))
			Main.I.burst(q.x, q.y, {"n": 3, "colors": ["#8a9bb0", "#6f7f94"], "speed": 50, "gravity": -20, "life": 0.4, "size": 4})
	elif turning:
		# átváltozás: megdermed, ráz, a karok előremerevednek
		var k: float = clampf((t - float(s.turn_t)) / TURN_TIME, 0.0, 1.0)
		roll = sin(tt * 45.0) * 0.12 * (1.0 - k * 0.5)
		hop = absf(sin(tt * 30.0)) * 0.05
		lean = 0.0
		lift = [0.0, 0.0]
		arms_t = [Vector3(-0.3, 0.3 + k * 0.4, 0.1 + k * 0.5), Vector3(0.3, 0.3 + k * 0.4, 0.1 + k * 0.5)]
		face = Vector3(0.9 - k * 0.5, 1.3 - k * 0.5, 1.0 - k * 1.3)
	else:
		# zombi: görnyedt tartás, előrenyújtott karok, egyenetlen lépés, dülöngélés
		var zph := tt * 7.5
		lean = 0.3
		hop = absf(sin(zph)) * 0.07 * run + absf(sin(zph * 0.5)) * 0.03 * run
		roll = sin(zph * 0.5) * 0.14 * maxf(0.3, run) + sin(tt * 1.3) * 0.04
		yaw_off = sin(tt * 1.7 + s.i) * 0.12
		lift = [maxf(0.0, sin(zph)) * 0.08 * run, maxf(0.0, -sin(zph)) * 0.05 * run]
		var reach := sin(tt * 4.0) * 0.05
		arms_t = [Vector3(-0.2, 0.62 + reach, 0.6), Vector3(0.2, 0.62 - reach, 0.6)]
		face = Vector3(0.35 + absf(sin(tt * 1.6)) * 0.2, 0.75, -0.35)
	if phase == "end":
		if s.state == "human":
			# győztes: két kar fel, ugrálás, mosoly
			var et := t - end_t
			hop = absf(sin(et * 7.0)) * 0.4
			arms_t = [Vector3(-0.4, 1.15 + sin(et * 10.0) * 0.08, 0.1), Vector3(0.4, 1.15 + sin(et * 10.0 + 1.0) * 0.08, 0.1)]
			face = Vector3(0.85, 1.1, 0.6)
			lean = 0.0
			roll = 0.0
			s.yaw = lerp_angle(float(s.yaw), 0.0, minf(1.0, dt * 5.0))
			yaw_off = 0.0
		elif s.state == "zombie":
			# a zombik bután táncikálnak
			var et: float = t - end_t + s.i
			roll = sin(et * 4.0) * 0.25
			hop = absf(sin(et * 4.0)) * 0.12
			arms_t = [Vector3(-0.35, 0.9 + sin(et * 8.0) * 0.2, 0.4), Vector3(0.35, 0.9 - sin(et * 8.0) * 0.2, 0.4)]
	m.position = Vector3(s.x, a.y + hop, s.z)
	m.rotation = Vector3(lean, float(s.yaw) + yaw_off + a.spin, roll + a.tilt)
	m.scale = Vector3.ONE * MS
	var feet: Array = s.feet
	for j in 2:
		(feet[j] as Node3D).position = Vector3((-1 if j == 0 else 1) * 0.14, 0.04 + lift[j], 0.05 + lift[j] * 0.5)
	for j in 2:
		K.arm_to(s.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, s.face, face.x, face.y, face.z)
	(s.disc as Node3D).position = Vector3(s.x, 0.02, s.z)


func _anim_npc(z: Dictionary, dt: float) -> void:
	var g: Node3D = z.g
	var tm: float = Main.I.time + z.k * 1.3
	var mv := Vector2(z.vx, z.vz)
	var spd := mv.length()
	if spd > 0.3:
		z.yaw = lerp_angle(float(z.yaw), atan2(mv.x, mv.y), minf(1.0, dt * 6.0))
	var rise: float = clampf((t if phase != "pre" else 0.0) / RISE_TIME, 0.0, 1.0)
	var y := -1.3 * (1.0 - D.ease_out_cubic(rise))
	var run := clampf(spd / N_MAXV, 0.0, 1.0)
	var ph := tm * 6.0
	g.position = Vector3(z.x, y + absf(sin(ph)) * 0.06 * run, z.z)
	g.rotation = Vector3(0, float(z.yaw), 0)
	var body: Node3D = z.body
	body.rotation = Vector3(0.28, 0, sin(ph * 0.5) * 0.12 + sin(tm * 1.1) * 0.05)
	var legs: Array = z.legs
	(legs[0] as Node3D).rotation.x = sin(ph) * 0.45 * run
	(legs[1] as Node3D).rotation.x = -sin(ph) * 0.3 * run
	var arms: Array = z.arms
	for j in 2:
		(arms[j] as Node3D).rotation = Vector3(-0.15 + sin(tm * 3.0 + j) * 0.1, 0, (0.1 if j == 0 else -0.1))
	(z.head as Node3D).rotation = Vector3(sin(tm * 1.4) * 0.12, sin(tm * 0.9) * 0.25, sin(tm * 1.9) * 0.15)
	# előmászás közben föld-por
	if phase == "play" and t < RISE_TIME and FX.f() < 0.25 and not preview:
		var q := screen(Vector3(z.x, 0.05, z.z))
		Main.I.burst(q.x, q.y, {"n": 2, "colors": ["#4a3a2e", "#6b5844"], "speed": 90, "life": 0.5, "size": 5})


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	for s in st:
		var q := screen(Vector3(s.x, 1.75, s.z))
		var zed: bool = s.state != "human"
		D.text(c, ("🧟 " if zed else "") + s.p.name, q.x, q.y, {"size": 17, "stroke": Color.BLACK, "sw": 5, "maxw": 150,
			"color": Color("#b6f36a") if zed else Color.WHITE})
	K.silver_timer(c, LIMIT - (t if phase != "pre" else 0.0) if phase != "end" else LIMIT - end_t, 640, 46, 10.0, t)
	D.text(c, "🧟 Zombifogó", 24, 34, {"size": 26, "align": "left", "stroke": D.DARK, "sw": 6})
	D.text(c, "Az utolsó ember nyer!", 24, 64, {"size": 17, "align": "left", "color": Color("#d0bfff"), "stroke": D.DARK, "sw": 5})
	var alive := _humans().size()
	D.panel(c, 1050, 20, 210, 54, {"r": 27, "fill": Color(0.08, 0.06, 0.18, 0.85), "stroke": Color("#7cd65a"), "lw": 3})
	D.text(c, "🧍 Emberek: %d" % alive, 1155, 47, {"size": 22, "color": Color.WHITE})
	if phase == "play" and t < 1.6:
		K.banner(c, "Futás!", t, 1.6, 360, Color("#c0eb75"), 80)
	if phase == "end":
		var k := t - end_t
		var txt := "UTOLSÓ TÚLÉLŐ!"
		match end_kind:
			"none": txt = "MINDENKI ZOMBI LETT!"
			"solo": txt = "ELKAPTAK!"
			"time":
				txt = "LEJÁRT AZ IDŐ!" if alive != 1 else "UTOLSÓ TÚLÉLŐ!"
				if alive == st.size() and alive > 1:
					txt = "MINDENKI TÚLÉLTE!"
		K.banner(c, txt, k, END_TIME, 200, Color("#ffe066") if alive > 0 else Color("#b6f36a"), 76)
		if alive > 0 and k > 0.6:
			var names: Array = []
			for s in st:
				if s.state == "human":
					names.append(s.p.name)
			D.text(c, "🏆 " + ", ".join(names), 640, 280, {"size": 36, "stroke": D.DARK, "sw": 8, "maxw": 1000})
