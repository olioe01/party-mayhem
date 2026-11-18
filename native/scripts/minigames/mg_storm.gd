extends Minigame
## Viharpadló – piros vagy kék? Az óceán fölött magasan lebegő, kétfelé osztott platformon állsz.
## Öt másodperc alatt szabadon átfuthatsz bármelyik oldalra; amikor lejár az idő, az számít, hol állsz.
## Az egyik fele (fele-fele eséllyel) csapóajtóként lenyílik, és aki rajta állt, a mélybe zuhan:
## kap egy villám-büntetést. Három kör, a legkevesebb villám nyer; holtversenyben azonos a helyezés.
##
## Játékmenet-állapot (lockstep): pl[].x/z/vx/vz/ix/iz/side/pen, phase, phase_t, round_i, doomed.
## Minden más (csapóajtó szöge, zuhanó figurák, kamera, vihar) csak látvány, a _sync() számolja.

const K = preload("res://scripts/minigames/mg_kit.gd")
const W = preload("res://scripts/minigames/presents_world.gd")

const ROUNDS := 3
const PICK_TIME := 5.0
const PREP_TIME := 1.6
const HX := 5.6                    # a járható padló fél szélessége (x)
const HZ := 3.2                    # … és fél mélysége (z)
const DIV := 0.34                  # a sárga elválasztó fél szélessége (itt vannak a csuklópántok)
const RIM := 0.55                  # a csíkos keret szélessége
const SPEED := 5.0
const ACCEL := 18.0
const BODY_R := 0.46
const SC := 1.25
const GRAV := 17.0
const FALL_G := 9.0                # a zuhanó figurák (látvány) gravitációja: kicsit lebegősebb, rajzfilmes
const SUSPENSE := [1.3, 1.8, 2.5]  # körönként egyre hosszabb a feszült rész…
const SHAKE := [0.75, 0.95, 1.2]   # …a remegés…
const SHAKE_AMP := [1.0, 1.6, 2.2]
const SWING := [1.75, 1.95, 2.15]  # …és a csapóajtó egyre nagyobbat leng
const STORM := [0.0, 0.45, 0.85]   # a vihar erőssége körönként
const DROP_TIME := 1.0
const FALL_TIME := 2.4
const RESET_TIME := 1.4
const RETURN_TIME := 1.1
const FINISH_TIME := 4.4
const SLOT_COLORS := ["#2f80ff", "#f03e3e", "#2fb344", "#ff8c1a", "#9b5de5", "#13b5c8", "#f0609e", "#d9a400"]
const SIDE_HEX := ["#f5333f", "#2f7dff"]
const SIDE_DARK := ["#8f1019", "#123c99"]
const SIDE_NAME := ["PIROS", "KÉK"]
const OCEAN_Y := -300.0
const CAM_POS := Vector3(0, 8.6, 12.6)
const CAM_LOOK := Vector3(0, -0.6, 0.2)

var pl: Array = []
var round_i := 0
var phase := "pre"     # prep -> pick -> lock -> suspense -> shake -> drop -> fall -> reset -> return -> (prep | wipe -> finish)
var phase_t := 0.0
var doomed := -1       # a lezuhanó oldal: 0 = piros (bal), 1 = kék (jobb)
var post := 0.0
var swapped := false   # a célplatform már látszik
var last_tick := -1
var places := {}       # slot index -> helyezés (holtversenyben azonos)

# ---- csak látvány
var plat: Node3D
var fin: Node3D
var pivots: Array = []
var floor_mats: Array = []
var lamp_mats: Array = []
var locks: Array = [[], []]
var rotors: Array = []
var clouds: Array = []
var storm_clouds: Array = []
var bolt3d: Node3D
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var cam_pos := CAM_POS
var cam_look := CAM_LOOK
var storm_v := 0.0
var flash := 0.0
var next_bolt := 3.0
var next_gust := 2.0


func meta() -> Dictionary:
	return {"id": "storm", "name": "Viharpadló", "icon": "🌩️", "color": "#6366f1", "modes": ["ffa"],
		"keep_ties": true, "own_end": true,
		"tagline": "Piros vagy kék? Az egyik oldal lezuhan!",
		"desc": "Magasan az óceán fölött lebeg egy kétfelé osztott platform: bal oldalt PIROS, jobb oldalt KÉK. %d másodperced van, hogy átfuss arra az oldalra, amelyik szerinted megmarad – akárhányszor meggondolhatod magad. Amikor lejár az idő, az egyik fele csapóajtóként lenyílik, és aki rajta állt, a mélybe pottyan: kap egy ⚡ villámot. Hogy melyik oldal zuhan, az tiszta szerencse! %d kör, a legkevesebb villám nyer." % [int(PICK_TIME), ROUNDS],
		"controls": "Joystickkal futsz; az számít, melyik oldalon állsz, amikor lejár az idő. Gépen: WASD / nyilak."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "🌩️", "title": "Viharpadló", "text": "Mindjárt indul az első kör!"}


func _stick_layout() -> Dictionary:
	return {"mode": "stick", "noBtn": true, "title": "Fuss a biztonságos oldalra!"}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	make_env("#2e7fe0", "#cfeeff", 0.95)
	sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	env.ssao_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color("#b4dbf7")
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	make_camera(CAM_POS, CAM_LOOK, 44)
	sun = make_sun(Vector3(-58, -28, 0), 1.25, "#fff6e6")
	sun.shadow_blur = 1.5
	_build_world()
	plat = Node3D.new()
	add_child(plat)
	_build_platform()
	fin = Node3D.new()
	fin.visible = false
	add_child(fin)
	_build_finale()
	var n := players.size()
	for i in n:
		var p = players[i]
		var sp := _spawn_pos(i, n)
		var s := {"p": p, "i": i, "col": Color(SLOT_COLORS[i % SLOT_COLORS.size()]),
			"x": sp.x, "z": sp.y, "vx": 0.0, "vz": 0.0, "ix": 0.0, "iz": 0.0, "kb_t": -10.0,
			"yaw": 0.0, "side": -1, "pen": 0, "pen_t": -10.0, "fell": false,
			"ai_side": 0, "ai_x": 0.0, "ai_z": 0.0, "ai_at": 0.0, "ai_flip": -1.0,
			# látvány
			"run_ph": 0.0, "vis": "stand", "fpos": Vector3.ZERO, "fvel": Vector3.ZERO, "lx": 0.0, "slide": 0.0, "vs": 0.0,
			"spin": Vector3.ZERO, "rot": Vector3.ZERO, "from": Vector2.ZERO, "landed": false, "cheer_r": 0, "burst_t": -10.0}
		_build_player(s)
		pl.append(s)
	_sync(0.0)


func _spawn_pos(i: int, n: int) -> Vector2:
	# kiegyensúlyozott, igazságos kezdés: mindenki az elválasztón áll, egyenlő távol a két oldaltól
	var gap: float = minf(1.45, (HZ * 2.0 - 1.0) / maxf(1.0, n - 1.0))
	return Vector2(0.0, (i - (n - 1) / 2.0) * gap)


static func _mat_tex(img: Image, scale: float, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = rough
	return m


## sárga-fekete figyelmeztető csíkok
static func _stripe_mat() -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, Color("#ffc61a") if ((x + y) / 8) % 2 == 0 else Color("#1d1d24"))
	return _mat_tex(img, 1.1, 0.45)


## lapos sokszög (pl. a sötét háromszögek a padlón)
static func _flat_poly(pts: Array, y: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(1, pts.size() - 1):
		for q in [pts[0], pts[k], pts[k + 1]]:
			st.add_vertex(Vector3(q.x, y, q.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mm := m.duplicate() as StandardMaterial3D
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	return mi


func _build_world() -> void:
	# óceán mélyen lent, szigetekkel
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	sea.mesh = pm
	sea.material_override = Chars3D.mat("#1769c9", {"rough": 0.22, "metal": 0.1})
	sea.position.y = OCEAN_Y
	add_child(sea)
	var isles := [[-70, -120, 22], [90, -180, 30], [-170, -260, 40], [30, -330, 55], [210, -90, 26],
		[-230, -40, 30], [150, -430, 70], [-80, -500, 62], [40, 60, 30], [-130, 110, 24], [180, 140, 34]]
	var shallow := Chars3D.mat("#3fd6c6", {"rough": 0.4})
	var sand := Chars3D.mat("#f5dfa0", {"rough": 0.9})
	var green := Chars3D.mat("#3fa34d", {"rough": 0.85})
	var green2 := Chars3D.mat("#2f7d3a", {"rough": 0.85})
	for k in isles.size():
		var it: Array = isles[k]
		var x: float = it[0]
		var z: float = it[1]
		var r: float = it[2]
		Chars3D.cyl(self, r * 1.5, r * 1.6, 0.4, shallow, x, OCEAN_Y + 0.1, z, 24)
		Chars3D.cyl(self, r * 1.05, r * 1.15, 1.2, sand, x, OCEAN_Y + 0.5, z, 20)
		for j in 1 + k % 3:
			var off := Vector2(cos(k * 2.1 + j * 2.4), sin(k * 1.7 + j * 2.4)) * r * (0.0 if j == 0 else 0.45)
			var h: float = r * (0.6 - j * 0.15)
			Chars3D.lcone(self, r * (0.85 - j * 0.18), h, green if j % 2 == 0 else green2, x + off.x, OCEAN_Y + 1.0 + h / 2.0, z + off.y, 7)
	# bárányfelhők a platform alatt és körül
	var cw := Chars3D.mat("#ffffff", {"rough": 1.0})
	var cw2 := Chars3D.mat("#e9f3fb", {"rough": 1.0})
	var spots := [[-26, -24, -40, 5.0], [24, -32, -55, 6.0], [-8, -55, -90, 8.0], [40, -18, -30, 4.0], [-46, -14, -20, 4.5],
		[12, -70, -20, 7.0], [-30, -80, -140, 10.0], [55, -60, -120, 9.0], [-60, -40, 10, 6.0], [30, -45, 20, 5.0],
		[0, -100, -200, 14.0], [-90, -20, -80, 7.0], [90, -26, -60, 7.0]]
	for k in spots.size():
		var sp: Array = spots[k]
		var g := _cloud(Vector3(sp[0], sp[1], sp[2]), sp[3], cw if k % 2 == 0 else cw2)
		clouds.append({"n": g, "x0": float(sp[0]), "sp": 0.6 + (k % 4) * 0.25})
	# közeledő viharfelhők (a későbbi körökben)
	var dark := Chars3D.mat("#4a5568", {"rough": 1.0})
	var dark2 := Chars3D.mat("#38404f", {"rough": 1.0})
	var st_spots := [[-30, -8, 0, 9.0], [0, -4, 6, 11.0], [28, -10, 2, 9.0], [-55, -14, 10, 8.0], [55, -14, 8, 8.0], [14, 2, -6, 8.0]]
	for k in st_spots.size():
		var sp: Array = st_spots[k]
		var g := _cloud(Vector3(sp[0], sp[1], -260), sp[3], dark if k % 2 == 0 else dark2)
		g.visible = false
		storm_clouds.append({"n": g, "dz": float(sp[2])})
	# villám (újrahasznosított cikcakk)
	bolt3d = Node3D.new()
	bolt3d.visible = false
	add_child(bolt3d)
	var bm := Chars3D.mat("#fff8c4", {"emit": "#fff3a0", "emit_e": 4.0, "unshaded": true})
	var pts := [Vector3(0, 24, 0), Vector3(-3, 16, 0), Vector3(2, 9, 0), Vector3(-2, 1, 0), Vector3(3, -7, 0), Vector3(-1, -16, 0), Vector3(2, -26, 0)]
	for k in pts.size() - 1:
		W.seg(bolt3d, 0.35, bm, pts[k], pts[k + 1])


func _cloud(pos: Vector3, r: float, m: Material) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	var puffs := [[0, 0, 0, 1.0], [-0.9, -0.15, 0.2, 0.75], [0.95, -0.1, -0.1, 0.8], [0.35, 0.35, 0.25, 0.7], [-0.4, 0.3, -0.3, 0.65], [1.6, -0.3, 0.3, 0.5], [-1.6, -0.3, -0.2, 0.5]]
	for q in puffs:
		Chars3D.lsphere(g, r * q[3], m, q[0] * r, q[1] * r, q[2] * r, 1.0, 0.72, 0.9, 9, 6)
	return g


func _build_platform() -> void:
	var stripe := _stripe_mat()
	var steel := Chars3D.mat("#5b6474", {"rough": 0.45, "metal": 0.5})
	var steel_d := Chars3D.mat("#3a404c", {"rough": 0.5, "metal": 0.5})
	var yellow := Chars3D.mat("#ffcc1f", {"rough": 0.4})
	var red := Chars3D.mat("#e5303a", {"rough": 0.35})
	var ox := HX + RIM / 2.0
	var oz := HZ + RIM / 2.0
	# csíkos keret
	Chars3D.box(plat, (HX + RIM) * 2.0, 0.42, RIM, stripe, Vector3(0, -0.13, oz))
	Chars3D.box(plat, (HX + RIM) * 2.0, 0.42, RIM, stripe, Vector3(0, -0.13, -oz))
	Chars3D.box(plat, RIM, 0.42, HZ * 2.0, stripe, Vector3(ox, -0.13, 0))
	Chars3D.box(plat, RIM, 0.42, HZ * 2.0, stripe, Vector3(-ox, -0.13, 0))
	# alatta acél szoknya csavarokkal, szellőzőkkel
	Chars3D.box(plat, (HX + RIM) * 2.0 - 0.1, 0.5, 0.3, steel, Vector3(0, -0.6, oz + 0.05))
	Chars3D.box(plat, (HX + RIM) * 2.0 - 0.1, 0.5, 0.3, steel, Vector3(0, -0.6, -oz - 0.05))
	Chars3D.box(plat, 0.3, 0.5, HZ * 2.0 + RIM * 2.0, steel, Vector3(ox + 0.05, -0.6, 0))
	Chars3D.box(plat, 0.3, 0.5, HZ * 2.0 + RIM * 2.0, steel, Vector3(-ox - 0.05, -0.6, 0))
	for k in 12:
		var bx := -HX + 0.5 + k * (HX * 2.0 - 1.0) / 11.0
		Chars3D.cyl(plat, 0.06, 0.06, 0.06, steel_d, bx, -0.6, oz + 0.22, 8, Vector3(PI / 2, 0, 0))
		if k % 3 == 1:
			Chars3D.box(plat, 0.5, 0.08, 0.04, steel_d, Vector3(bx + 0.4, -0.52, oz + 0.21))
			Chars3D.box(plat, 0.5, 0.08, 0.04, steel_d, Vector3(bx + 0.4, -0.68, oz + 0.21))
	# sárga elválasztó, alatta a csuklópántok tartógerendája
	Chars3D.box(plat, DIV * 2.0, 0.36, HZ * 2.0, yellow, Vector3(0, -0.14, 0))
	Chars3D.box(plat, DIV * 2.0 - 0.04, 0.04, HZ * 2.0, Chars3D.mat("#ffe066", {"rough": 0.3}), Vector3(0, 0.05, 0))
	Chars3D.box(plat, 0.5, 1.0, HZ * 2.0 + RIM * 2.0, steel_d, Vector3(0, -0.8, 0))
	Chars3D.cone(plat, 0.55, 1.2, steel, 0, -1.9, 0, 10, Vector3(PI, 0, 0))
	for sgn in [-1.0, 1.0]:
		for k in 5:
			Chars3D.cyl(plat, 0.09, 0.09, 0.9, steel_d, sgn * DIV, -0.12, -HZ + 0.6 + k * (HZ * 2.0 - 1.2) / 4.0, 10, Vector3(PI / 2, 0, 0))
	# a két csapóajtó: forgáspontjuk az elválasztó mentén van
	for s in 2:
		var sgn := -1.0 if s == 0 else 1.0
		var pv := Node3D.new()
		pv.position = Vector3(sgn * DIV, 0, 0)
		plat.add_child(pv)
		pivots.append(pv)
		var w := HX - DIV
		var fm := Chars3D.mat(SIDE_HEX[s], {"rough": 0.38}).duplicate() as StandardMaterial3D
		fm.emission_enabled = true
		fm.emission = Color(SIDE_HEX[s]).lightened(0.35)
		fm.emission_energy_multiplier = 0.0
		floor_mats.append(fm)
		Chars3D.box(pv, w, 0.3, HZ * 2.0, fm, Vector3(sgn * w / 2.0, -0.15, 0))
		# világosabb belső szegély
		var edge := Chars3D.mat(Color(SIDE_HEX[s]).lightened(0.25).to_html(false), {"rough": 0.35})
		Chars3D.box(pv, w - 0.1, 0.02, 0.1, edge, Vector3(sgn * w / 2.0, 0.005, HZ - 0.2))
		Chars3D.box(pv, w - 0.1, 0.02, 0.1, edge, Vector3(sgn * w / 2.0, 0.005, -HZ + 0.2))
		# nagy sötét háromszög, kifelé mutat
		var tri := [Vector2(sgn * 0.75, -2.15), Vector2(sgn * 0.75, 2.15), Vector2(sgn * 4.55, 0.0)]
		pv.add_child(_flat_poly(tri, 0.012, Chars3D.mat(SIDE_DARK[s], {"rough": 0.5})))
		# alul acélbordák (csapóajtó-hatás, amikor lenyílik)
		for k in 4:
			Chars3D.box(pv, w - 0.2, 0.22, 0.16, steel_d, Vector3(sgn * w / 2.0, -0.38, -HZ + 0.5 + k * (HZ * 2.0 - 1.0) / 3.0))
		Chars3D.box(pv, 0.16, 0.22, HZ * 2.0 - 0.4, steel_d, Vector3(sgn * (w - 0.3), -0.38, 0))
		# reteszek a külső peremen: lezuhanás előtt kicsúsznak
		for k in 3:
			var z := -HZ + 1.0 + k * (HZ - 1.0)
			var lk := Node3D.new()
			lk.position = Vector3(sgn * (HX + 0.02), 0.04, z)
			plat.add_child(lk)
			Chars3D.box(lk, 0.5, 0.14, 0.34, yellow, Vector3(-sgn * 0.08, 0, 0))
			Chars3D.box(lk, 0.14, 0.18, 0.4, Chars3D.mat("#1d1d24", {"rough": 0.5}), Vector3(sgn * 0.2, 0, 0))
			locks[s].append(lk)
		# figyelmeztető lámpák a sarkokon
		var lm := Chars3D.mat("#ff5a36", {"emit": "#ff3b1f", "emit_e": 0.0, "rough": 0.3}).duplicate() as StandardMaterial3D
		lamp_mats.append(lm)
		for zz in [-1.0, 1.0]:
			Chars3D.cyl(plat, 0.13, 0.15, 0.12, steel_d, sgn * ox, 0.14, zz * (oz - 0.6), 10)
			Chars3D.sphere(plat, 0.16, lm, sgn * ox, 0.26, zz * (oz - 0.6))
	# sarokgépek: piros, lekerekített házak sárga részekkel, forgó légcsavarral
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_pod(plat, Vector3(cx * (ox + 0.55), -0.2, cz * (oz + 0.45)), red, yellow, steel_d, 1.0)


## Lebegtető sarokgép: kerek piros ház, sárga gyűrű és árboc, forgó légcsavar fent és lent.
func _pod(parent: Node3D, pos: Vector3, red: Material, yellow: Material, dark: Material, sc: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.scale = Vector3.ONE * sc
	parent.add_child(g)
	var body := MeshInstance3D.new()
	body.mesh = Chars3D.llathe([[0.0, -0.75], [0.42, -0.7], [0.68, -0.45], [0.78, -0.05], [0.72, 0.3], [0.5, 0.5], [0.0, 0.55]], 14)
	body.material_override = red
	g.add_child(body)
	var ring := MeshInstance3D.new()
	ring.mesh = Chars3D.torus(0.79, 0.08)
	ring.material_override = yellow
	ring.position.y = -0.05
	g.add_child(ring)
	Chars3D.sphere(g, 0.16, Chars3D.mat("#bfe9ff", {"rough": 0.1, "metal": 0.2}), 0, 0.12, 0.66, 1.0, 1.0, 0.5)
	Chars3D.cyl(g, 0.08, 0.1, 0.9, yellow, 0, 0.95, 0, 10)
	Chars3D.cyl(g, 0.16, 0.16, 0.16, dark, 0, 1.42, 0, 10)
	for dir in [1.0, -1.0]:
		var rot := Node3D.new()
		rot.position = Vector3(0, 1.52 if dir > 0 else -0.86, 0)
		g.add_child(rot)
		for k in 3:
			var b := Node3D.new()
			b.rotation.y = TAU * k / 3.0
			rot.add_child(b)
			if dir > 0:
				Chars3D.box(b, 0.95, 0.03, 0.2, yellow, Vector3(0.5, 0, 0), Vector3(0.25, 0, 0))
			else:
				Chars3D.box(b, 0.5, 0.03, 0.14, dark, Vector3(0.27, 0, 0), Vector3(0.25, 0, 0))
		Chars3D.sphere(rot, 0.1, dark)
		rotors.append({"n": rot, "sp": (13.0 if dir > 0 else -9.0) + pos.x * 0.3})
	# tartókar a platform felé
	var to := Vector3(-signf(pos.x) * 0.7, 0.1, -signf(pos.z) * 0.6)
	W.seg(g, 0.07, yellow, Vector3(0, -0.2, 0), to)


func _build_finale() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color("#c8f2b4"))
	img.set_pixel(1, 1, Color("#c8f2b4"))
	img.set_pixel(1, 0, Color("#ffffff"))
	img.set_pixel(0, 1, Color("#ffffff"))
	var checker := _mat_tex(img, 0.6, 0.5)
	var red := Chars3D.mat("#e5303a", {"rough": 0.35})
	var yellow := Chars3D.mat("#ffcc1f", {"rough": 0.4})
	var steel_d := Chars3D.mat("#3a404c", {"rough": 0.5, "metal": 0.5})
	Chars3D.cyl(fin, 4.7, 4.7, 0.4, checker, 0, -0.2, 0, 48)
	Chars3D.cyl(fin, 5.3, 5.0, 0.7, red, 0, -0.42, 0, 48)
	var ring := MeshInstance3D.new()
	ring.mesh = Chars3D.torus(5.0, 0.3)
	ring.material_override = red
	ring.position.y = -0.02
	fin.add_child(ring)
	var ring2 := MeshInstance3D.new()
	ring2.mesh = Chars3D.torus(4.72, 0.06)
	ring2.material_override = Chars3D.mat("#ffffff", {"rough": 0.4})
	ring2.position.y = 0.02
	fin.add_child(ring2)
	Chars3D.cone(fin, 2.2, 2.4, steel_d, 0, -1.9, 0, 12, Vector3(PI, 0, 0))
	for a in [PI, 0.0, -PI * 0.72, -PI * 0.28]:
		_pod(fin, Vector3(cos(a) * 5.75, -0.25, sin(a) * 5.75), red, yellow, steel_d, 1.1)


func _build_player(s: Dictionary) -> void:
	var m := player_model(s.p, SC)
	var col: Color = s.col
	s.m = m
	s.arms = K.build_arms(m, col.darkened(0.1).to_html(false), 0.5)
	s.face = K.build_face(m)
	# rúgkapáló lábak: csak zuhanás közben bújnak elő
	var leg_m := Chars3D.mat(col.darkened(0.25).to_html(false), {"rough": 0.5})
	var shoe := Chars3D.mat("#ffffff", {"rough": 0.4})
	var legs: Array = []
	for side in [-1, 1]:
		var lg := W.seg(m, 0.05, leg_m)
		var ft := Chars3D.sphere(m, 0.085, shoe, 0, 0, 0, 1.0, 0.8, 1.4)
		lg.visible = false
		ft.visible = false
		legs.append({"side": side, "seg": lg, "foot": ft})
	s.legs = legs
	var disc := MeshInstance3D.new()
	disc.mesh = Chars3D.torus(0.44, 0.05)
	disc.material_override = Chars3D.mat(col.to_html(false), {"rough": 0.4, "emit": col.to_html(false), "emit_e": 0.5})
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	s.disc = disc


func _slot(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


# ------------------------------------------------------------------ bemenet
func input(p, msg: Dictionary) -> void:
	var s := _slot(p)
	if s.is_empty() or finished:
		return
	if msg.get("kb", false):
		s.kb_t = t
	if msg.get("t") == "stick":
		s.ix = clamp(float(msg.get("x", 0)), -1.0, 1.0)
		s.iz = clamp(float(msg.get("y", 0)), -1.0, 1.0)


## Csak a fejlesztői tesztbotoknak (--bots) és a lecsatlakozott játékosoknak: választ egy oldalt,
## néha meggondolja magát. Valódi meccsbe a játék soha nem tesz gépi ellenfelet.
func bot(p, _dt: float) -> void:
	var s := _slot(p)
	if s.is_empty() or t - float(s.kb_t) < 3.0:
		return
	if phase != "pick":
		s.ix = 0.0
		s.iz = 0.0
		return
	if phase_t >= float(s.ai_at):
		s.ai_side = randi() % 2
		s.ai_x = (-1.0 if s.ai_side == 0 else 1.0) * randf_range(1.3, HX - 1.0)
		s.ai_z = randf_range(-HZ + 0.8, HZ - 0.8)
		s.ai_at = phase_t + (randf_range(1.6, 3.2) if randf() < 0.45 else 99.0)
	var d := Vector2(float(s.ai_x) - float(s.x), float(s.ai_z) - float(s.z))
	if d.length() < 0.25:
		s.ix = 0.0
		s.iz = 0.0
	else:
		var v := d.normalized() * minf(1.0, d.length() / 0.6 + 0.2)
		s.ix = v.x
		s.iz = v.y


# ------------------------------------------------------------------ szimuláció (lockstep)
func start() -> void:
	_next_round()


func _set_phase(ph: String) -> void:
	phase = ph
	phase_t = 0.0


func _next_round() -> void:
	round_i += 1
	doomed = -1
	last_tick = -1
	for s in pl:
		s.fell = false
		s.side = -1
		s.ai_at = randf_range(0.2, 1.0)
	_set_phase("prep")
	for s in pl:
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🌩️", "title": "%d. kör" % round_i if round_i < ROUNDS else "Utolsó kör!", "text": "Készülj: mindjárt futhatsz!"})


func update(dt: float) -> void:
	if finished:
		return
	phase_t += dt
	var r: int = clampi(round_i - 1, 0, ROUNDS - 1)
	match phase:
		"prep":
			if phase_t >= PREP_TIME:
				_set_phase("pick")
				Audio.play("go")
				for s in pl:
					s.ix = 0.0
					s.iz = 0.0
					Net.set_ctrl(s.p.pid, _stick_layout())
		"pick":
			for s in pl:
				_move(s, dt)
			_collide()
			var rem := ceili(PICK_TIME - phase_t)
			if rem != last_tick and rem > 0:
				last_tick = rem
				if rem <= 3:
					Audio.play("tick", 1.4 + (3 - rem) * 0.12)
			if phase_t >= PICK_TIME:
				_lock()
		"lock":
			if phase_t >= 0.7:
				_set_phase("suspense")
				Audio.play("roll")
		"suspense":
			if phase_t >= float(SUSPENSE[r]):
				_set_phase("shake")
				Audio.play("tremble")
				Audio.play("bell")
		"shake":
			if phase_t >= float(SHAKE[r]):
				_set_phase("drop")
				Audio.play("clank")
				Audio.play("crash", 0.8)
		"drop":
			if phase_t >= DROP_TIME:
				_set_phase("fall")
				_penalties()
		"fall":
			if phase_t >= FALL_TIME:
				_set_phase("reset")
				Audio.play("strain")
		"reset":
			if phase_t >= RESET_TIME:
				Audio.play("clank")
				_set_phase("return")
				var n := pl.size()
				for s in pl:
					s.from = Vector2(s.x, s.z)
					var sp := _spawn_pos(s.i, n)
					s.x = sp.x
					s.z = sp.y
					s.vx = 0.0
					s.vz = 0.0
					s.ix = 0.0
					s.iz = 0.0
					s.landed = false
		"return":
			if phase_t >= RETURN_TIME:
				if round_i >= ROUNDS:
					_set_phase("wipe")
					Audio.play("whoosh")
				else:
					_next_round()
		"wipe":
			if phase_t >= 0.45 and not swapped:
				_finale()
			if phase_t >= 0.9:
				_set_phase("finish")
				Audio.play("fanfare")
				Audio.jingle("victory")
		"finish":
			if phase_t >= FINISH_TIME:
				finished = true
	_sync(dt)


func idle(dt: float) -> void:
	if finished:
		post += dt
	_sync(dt)


func _move(s: Dictionary, dt: float) -> void:
	var want := Vector2(s.ix, s.iz).limit_length(1.0)
	if want.length() < 0.12:
		want = Vector2.ZERO
	var k: float = minf(1.0, ACCEL * dt)
	s.vx = lerpf(s.vx, want.x * SPEED, k)
	s.vz = lerpf(s.vz, want.y * SPEED, k)
	s.x = clampf(float(s.x) + float(s.vx) * dt, -HX + BODY_R, HX - BODY_R)
	s.z = clampf(float(s.z) + float(s.vz) * dt, -HZ + BODY_R, HZ - BODY_R)
	if want.length() > 0.2:
		s.yaw = lerp_angle(float(s.yaw), atan2(want.x, want.y), minf(1.0, dt * 14.0))


func _collide() -> void:
	var n := pl.size()
	for a in n:
		for b in range(a + 1, n):
			var sa: Dictionary = pl[a]
			var sb: Dictionary = pl[b]
			var d := Vector2(float(sb.x) - float(sa.x), float(sb.z) - float(sa.z))
			var l := d.length()
			if l >= BODY_R * 2.0:
				continue
			var dir := d / l if l > 0.0001 else Vector2(0, 1)
			var push := (BODY_R * 2.0 - l) / 2.0
			sa.x = clampf(float(sa.x) - dir.x * push, -HX + BODY_R, HX - BODY_R)
			sa.z = clampf(float(sa.z) - dir.y * push, -HZ + BODY_R, HZ - BODY_R)
			sb.x = clampf(float(sb.x) + dir.x * push, -HX + BODY_R, HX - BODY_R)
			sb.z = clampf(float(sb.z) + dir.y * push, -HZ + BODY_R, HZ - BODY_R)


## Lejárt az idő: a helyzet dönt. Az elválasztón álló figurát az az oldal kapja, ahová a teste
## nagyobb része (a középpontja) esik; pontosan középen a piros (bal) oldal – így determinisztikus.
## Ezután fele-fele eséllyel eldől, melyik oldal zuhan le (független attól, ki hol áll).
func _lock() -> void:
	for s in pl:
		s.side = 0 if float(s.x) <= 0.0 else 1
		s.vx = 0.0
		s.vz = 0.0
		s.ix = 0.0
		s.iz = 0.0
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🔴" if s.side == 0 else "🔵", "title": "A %s oldalon állsz" % SIDE_NAME[s.side], "text": "Melyik oldal zuhan le?!"})
	doomed = randi() % 2
	_set_phase("lock")
	Audio.play("horn")
	print_verbose("[storm] %d. kör: %s zuhan; %s" % [round_i, SIDE_NAME[doomed], ", ".join(pl.map(func(s): return "%s=%s" % [s.p.name, SIDE_NAME[s.side]]))])


func _penalties() -> void:
	var any := false
	for s in pl:
		if int(s.side) == doomed:
			any = true
			s.fell = true
			s.pen = int(s.pen) + 1
			s.pen_t = t
			Net.vibrate(s.p.pid, [200, 80, 200])
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "⚡", "title": "Lezuhantál!", "text": "Kaptál egy villámot (%d ⚡)." % int(s.pen)})
		else:
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "😅", "title": "Megúsztad!", "text": "A másik oldal zuhant le."})
	Audio.play("wind")
	if any:
		Audio.play("fail")
		Audio.play("bad")
	else:
		Audio.play("coin")


## Helyezés a villámok száma szerint: a kevesebb jobb, egyenlő számnál azonos a helyezés.
func _compute_places() -> void:
	places = {}
	for s in pl:
		var better := 0
		for o in pl:
			if int(o.pen) < int(s.pen):
				better += 1
		places[s.i] = better


func _finale() -> void:
	swapped = true
	_compute_places()
	plat.visible = false
	fin.visible = true
	var order: Array = pl.duplicate()
	order.sort_custom(func(a, b): return int(places[a.i]) < int(places[b.i]) if places[a.i] != places[b.i] else int(a.i) < int(b.i))
	var n := order.size()
	var gap: float = minf(1.6, 8.0 / maxf(1.0, n))
	for k in n:
		var s: Dictionary = order[k]
		s.x = (k - (n - 1) / 2.0) * gap
		s.z = 0.6
		s.yaw = 0.0
		s.vis = "stand"
		var place: int = places[s.i]
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏁", "title": "FINISH!", "text": "%d. hely – %d ⚡" % [place + 1, int(s.pen)]})
	cam_pos = Vector3(0, 4.6, 10.4)
	cam_look = Vector3(0, 0.9, 0)


func ranking() -> Array:
	return rank_by(_score, _label)


func _score(p) -> float:
	return -float(_slot(p).get("pen", 0))


func _label(p) -> String:
	var n := int(_slot(p).get("pen", 0))
	return "hibátlan! 0 ⚡" if n == 0 else "%d ⚡" % n


# ------------------------------------------------------------------ látvány
## A lezuhanó csapóajtó szöge (radián, 0 = vízszintes).
func _door_angle(side: int) -> float:
	if side != doomed:
		return 0.0
	var r: int = clampi(round_i - 1, 0, ROUNDS - 1)
	var sw: float = SWING[r]
	match phase:
		"drop":
			var tk := 0.62
			if phase_t < tk:
				var a := 2.0 * sw / (tk * tk)
				return 0.5 * a * phase_t * phase_t
			var q := phase_t - tk
			return sw - sin(q * 13.0) * (0.16 + 0.05 * r) * exp(-q * 4.5)
		"fall":
			return sw + sin(phase_t * 2.4) * 0.025
		"reset":
			var k: float = clamp(phase_t / (RESET_TIME - 0.15), 0.0, 1.0)
			return sw * (1.0 - D.ease_in_out(k))
	return 0.0


## A „rulett”: melyik oldal világít épp (a feszült rész végén mindig a lezuhanó).
func _roulette() -> int:
	if doomed < 0:
		return -1
	var r: int = clampi(round_i - 1, 0, ROUNDS - 1)
	var dur: float = SUSPENSE[r]
	var steps := 7 + r * 3
	# egyre lassuló váltások; a hátralévő váltások paritása adja az oldalt
	var tt := 0.0
	var gaps: Array = []
	for k in steps:
		gaps.append(0.6 + k * 0.35)
		tt += gaps[k]
	var sc := dur / tt
	var acc := 0.0
	var done := 0
	for k in steps:
		acc += float(gaps[k]) * sc
		if phase_t >= acc:
			done += 1
	var remain := steps - done
	return doomed if remain % 2 == 0 else 1 - doomed


func _sync(dt: float) -> void:
	var tv := t + post
	var r: int = clampi(round_i - 1, 0, ROUNDS - 1)
	# --- vihar
	var target_storm: float = STORM[r] if round_i > 0 and not swapped else 0.0
	storm_v = lerpf(storm_v, target_storm, minf(1.0, dt * 0.8))
	flash = maxf(0.0, flash - dt * 4.0)
	if sky_mat:
		sky_mat.sky_top_color = Color("#2e7fe0").lerp(Color("#3b4766"), storm_v)
		sky_mat.sky_horizon_color = Color("#cfeeff").lerp(Color("#93a0b4"), storm_v)
	env.fog_light_color = Color("#b4dbf7").lerp(Color("#8f9bb0"), storm_v)
	sun.light_energy = lerpf(1.25, 0.8, storm_v) + flash * 1.4
	for k in storm_clouds.size():
		var sc: Dictionary = storm_clouds[k]
		var g: Node3D = sc.n
		g.visible = storm_v > 0.03
		g.position.z = lerpf(-230.0, -70.0, storm_v) + float(sc.dz) + sin(tv * 0.2 + k) * 2.0
	if storm_v > 0.3 and dt > 0.0:
		next_bolt -= dt
		if next_bolt <= 0.0:
			next_bolt = FX.fr(2.0, 4.5) / storm_v
			flash = 1.0
			bolt3d.position = Vector3(FX.fr(-60, 60), FX.fr(-12, 0), lerpf(-230.0, -70.0, storm_v) + FX.fr(-8, 8))
			bolt3d.rotation.y = FX.fr(-0.5, 0.5)
			Audio.play("boom", FX.fr(0.5, 0.7))
		next_gust -= dt
		if next_gust <= 0.0:
			next_gust = FX.fr(3.0, 6.0)
			Audio.play("gust", FX.fr(0.8, 1.1))
	bolt3d.visible = flash > 0.6
	for k in clouds.size():
		var cl: Dictionary = clouds[k]
		var g: Node3D = cl.n
		g.position.x = float(cl.x0) + sin(tv * 0.04 * float(cl.sp) + k) * (6.0 + 6.0 * storm_v)
	for ro in rotors:
		(ro.n as Node3D).rotation.y += dt * float(ro.sp) * (1.0 + storm_v * 0.4)
	# --- csapóajtók, reteszek, lámpák, padló-kiemelés
	var hl := _roulette() if phase == "suspense" else -1
	for side in 2:
		var sgn := -1.0 if side == 0 else 1.0
		var pv: Node3D = pivots[side]
		var ang := _door_angle(side)
		var jit := Vector3.ZERO
		var jr := 0.0
		if phase == "shake" and side == doomed:
			var amp: float = SHAKE_AMP[r] * minf(1.0, phase_t * 3.0)
			jit = Vector3(FX.fr(-1, 1) * 0.02, sin(tv * 70.0) * 0.025, FX.fr(-1, 1) * 0.015) * amp
			jr = sin(tv * 55.0) * 0.012 * amp
		pv.position = Vector3(sgn * DIV, 0, 0) + jit
		pv.rotation.z = -sgn * ang + jr
		var lock_out := 0.0
		if side == doomed:
			match phase:
				"shake": lock_out = clamp((phase_t - float(SHAKE[r]) + 0.25) / 0.2, 0.0, 1.0)
				"drop", "fall": lock_out = 1.0
				"reset": lock_out = 1.0 - clamp((phase_t - RESET_TIME + 0.3) / 0.25, 0.0, 1.0)
		for k in locks[side].size():
			var lk: Node3D = locks[side][k]
			lk.position.x = sgn * (HX + 0.02 + 0.42 * lock_out)
		var fm: StandardMaterial3D = floor_mats[side]
		var e := 0.0
		if phase == "suspense":
			e = 1.0 if hl == side else 0.0
		elif phase == "shake" and side == doomed:
			e = 0.3 + 0.3 * absf(sin(tv * 14.0))
		elif phase == "pick":
			e = 0.06 + 0.04 * sin(tv * 3.0 + side * PI)
		fm.emission_energy_multiplier = lerpf(fm.emission_energy_multiplier, e, minf(1.0, dt * 18.0)) if dt > 0.0 else e
		var lm: StandardMaterial3D = lamp_mats[side]
		var blink := (phase == "shake" or phase == "drop") and side == doomed and fmod(tv, 0.24) < 0.12
		lm.emission_energy_multiplier = 4.0 if blink else (1.2 if phase == "suspense" and hl == side else 0.0)
	# --- figurák
	for s in pl:
		_sync_player(s, tv, dt)
	# --- kamera
	_sync_camera(dt, tv)


func _sync_camera(dt: float, tv: float) -> void:
	var tp := CAM_POS
	var tl := CAM_LOOK
	var fov := 44.0
	var sg := -1.0 if doomed == 0 else 1.0
	if swapped:
		tp = Vector3(sin(tv * 0.25) * 1.6, 4.6, 10.4)
		tl = Vector3(0, 0.9, 0)
		fov = 42.0
	else:
		match phase:
			"shake":
				tp = Vector3(sg * 1.2, 8.2, 12.0)
				tl = Vector3(sg * 1.5, -0.6, 0.2)
			"drop":
				tp = Vector3(sg * 2.6, 7.4, 11.4)
				tl = Vector3(sg * 3.0, -1.6, 0.0)
			"fall":
				var ys := 0.0
				var cnt := 0
				for s in pl:
					if s.vis == "air":
						ys += (s.fpos as Vector3).y
						cnt += 1
				var fy := ys / cnt if cnt > 0 else -6.0
				tp = Vector3(sg * 2.4, 7.6, 12.8)
				tl = Vector3(sg * 4.0, maxf(fy, -11.0) * 0.75, -0.5)
				fov = 50.0
	var k: float = 1.0 - exp(-dt * 3.0)
	cam_pos = cam_pos.lerp(tp, k)
	cam_look = cam_look.lerp(tl, k)
	cam.fov = lerpf(cam.fov, fov, k)
	var shake := Vector3.ZERO
	if not swapped and (phase == "drop" and phase_t < 0.5):
		shake = Vector3(FX.fr(-1, 1), FX.fr(-1, 1), 0) * 0.06 * (1.0 - phase_t / 0.5)
	cam.position = cam_pos + shake
	cam.look_at(cam_look, Vector3.UP)


## Egy figura látványa: futás, ijedtség, csapóajtón csúszás, zuhanás, visszatérés, győzelmi tánc.
func _sync_player(s: Dictionary, tv: float, dt: float) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var sgn := -1.0 if int(s.side) == 0 else 1.0
	var falls: bool = int(s.side) == doomed and doomed >= 0 and not swapped
	var face: Dictionary = s.face
	var disc: MeshInstance3D = s.disc
	var arms: Array = s.arms
	var show_legs := false
	# --- zuhanás állapotgépe (csak látvány)
	if not swapped and falls and (phase == "drop" or phase == "fall") and s.vis == "stand":
		s.vis = "door"
		s.lx = float(s.x) - sgn * DIV
		if absf(float(s.lx)) < 0.3:
			s.lx = sgn * 0.3   # az elválasztóról is lecsúszik a saját oldalára
		s.slide = 0.0
		s.vs = 0.0
		s.fpos = Vector3(s.x, 0, s.z)
	if s.vis == "door":
		var ang := _door_angle(int(s.side))
		var aa := -sgn * ang
		s.vs = float(s.vs) + GRAV * sin(ang) * dt * 0.9
		s.slide = float(s.slide) + float(s.vs) * dt
		var u: float = float(s.lx) + sgn * float(s.slide)
		var np := Vector3(sgn * DIV + u * cos(aa), u * sin(aa), float(s.z))
		var prev: Vector3 = s.fpos
		s.fpos = np
		if absf(u) > HX - DIV - 0.15 or ang > 1.0:
			s.vis = "air"
			var v: Vector3 = (np - prev) / maxf(dt, 0.001)
			s.fvel = v * 0.5 + Vector3(sgn * 1.6, 3.2, FX.fr(-0.6, 0.6))
			s.spin = Vector3(FX.fr(-3.0, 3.0), FX.fr(-4.0, 4.0), sgn * FX.fr(-4.0, -1.5))
			s.rot = Vector3(0, float(s.yaw), aa)
			Audio.play("whoosh", FX.fr(0.8, 1.1))
	elif s.vis == "air":
		var v: Vector3 = s.fvel
		v.y -= FALL_G * dt
		v.x *= pow(0.6, dt)
		s.fvel = v
		s.fpos = (s.fpos as Vector3) + v * dt
		s.rot = (s.rot as Vector3) + (s.spin as Vector3) * dt
	if phase == "reset" and s.vis != "stand":
		s.vis = "gone"
	if phase == "return" or phase == "prep" or phase == "pick" or swapped:
		if s.vis != "stand" and phase != "return":
			s.vis = "stand"
	m.visible = s.vis != "gone"
	# --- helyzet és testtartás
	var pos := Vector3(s.x, 0, s.z)
	var basis := Basis(Vector3.UP, float(s.yaw))
	var sp := Vector2(s.vx, s.vz).length()
	var runk: float = clamp(sp / SPEED, 0.0, 1.0)
	s.run_ph = float(s.run_ph) + dt * (7.0 + sp * 2.4) * (1.0 if runk > 0.05 else 0.0)
	var ph: float = s.run_ph
	var sy := 1.0
	var lean := 0.0
	var arm_t: Array = []
	for arm in arms:
		var sd: float = arm.side
		arm_t.append(Vector3(sd * 0.36, 0.12 + sin(tv * 2.0 + sd) * 0.02, 0.06))
	var fear := 0.0
	if not swapped:
		match phase:
			"lock", "suspense":
				fear = 0.5
			"shake":
				fear = 1.0 if falls else 0.4
			"drop":
				fear = 1.0 if falls else 0.2
	if s.vis == "door" or s.vis == "air":
		pos = s.fpos
		show_legs = true
		if s.vis == "door":
			basis = Basis(Vector3.BACK, -sgn * _door_angle(int(s.side)) * 0.85 + sin(tv * 18.0) * 0.15) * Basis(Vector3.UP, float(s.yaw))
		else:
			var rt: Vector3 = s.rot
			basis = Basis(Vector3.BACK, rt.z) * Basis(Vector3.RIGHT, rt.x) * Basis(Vector3.UP, rt.y)
		for k in arms.size():
			var sd: float = arms[k].side
			arm_t[k] = Vector3(sd * 0.55, 0.62 + sin(tv * 15.0 + sd * 2.0) * 0.2, cos(tv * 13.0 + sd) * 0.18)
		K.set_face(m, face, 0.95, 1.35, 1.0)
	elif phase == "return" and not swapped:
		var n := pl.size()
		var to := _spawn_pos(int(s.i), n)
		if s.vis == "gone" or s.vis == "drop_in":
			# a lezuhantak felülről pottyannak vissza
			s.vis = "drop_in"
			var k: float = clamp((phase_t - 0.1) / 0.6, 0.0, 1.0)
			pos = Vector3(to.x, (1.0 - k) * (1.0 - k) * 9.0, to.y)
			if k >= 1.0 and not s.landed:
				s.landed = true
				m.land = 1.0
				Audio.play("land", FX.fr(0.9, 1.1))
			if k >= 1.0:
				s.vis = "stand"
			for k2 in arms.size():
				var sd: float = arms[k2].side
				arm_t[k2] = Vector3(sd * 0.5, 0.75, 0.0)
			K.set_face(m, face, 0.5, 1.15, 0.6)
		else:
			# a többiek visszaszökdécselnek a kezdőhelyükre
			var k: float = clamp(phase_t / 0.8, 0.0, 1.0)
			var fr: Vector2 = s.from
			var xz := fr.lerp(to, D.ease_in_out(k))
			pos = Vector3(xz.x, sin(k * PI) * 0.6, xz.y)
			if (to - fr).length() > 0.1 and k < 1.0:
				basis = Basis(Vector3.UP, atan2(to.x - fr.x, to.y - fr.y))
			K.set_face(m, face, 0.0, 1.0, 0.0)
	elif swapped:
		var place: int = places.get(s.i, 0)
		var maxp := 0
		for v in places.values():
			maxp = maxi(maxp, int(v))
		var shown := phase == "finish" or finished
		if shown and place == 0:
			# győztes: ugrál, karok a magasban
			pos.y = absf(sin(tv * 5.0 + s.i)) * 0.45
			for k in arms.size():
				var sd: float = arms[k].side
				arm_t[k] = Vector3(sd * (0.3 + sin(tv * 10.0 + sd) * 0.08), 1.05, 0.1)
			K.set_face(m, face, 0.8, 1.1, 0.6)
		elif shown and place == maxp and maxp > 0:
			# utolsó: lehajtott fej, lógó karok, időnként nagy sóhaj
			lean = 0.38
			sy = 0.9 + sin(tv * 1.6) * 0.03
			for k in arms.size():
				var sd: float = arms[k].side
				arm_t[k] = Vector3(sd * 0.22, 0.05, 0.22)
			K.set_face(m, face, 0.12, 0.85, -0.85)
		elif shown:
			# középmezőny: egyik kezével int
			for k in arms.size():
				var sd: float = arms[k].side
				if sd > 0:
					arm_t[k] = Vector3(0.45, 0.95 + sin(tv * 7.0 + s.i) * 0.1, 0.15)
			K.set_face(m, face, 0.25, 1.0, 0.1)
		else:
			K.set_face(m, face, 0.0, 1.0, 0.0)
	else:
		# áll vagy fut a platformon
		pos.y = absf(sin(ph)) * 0.1 * runk
		lean = 0.18 * runk
		if runk > 0.05:
			for k in arms.size():
				var sd: float = arms[k].side
				arm_t[k] = Vector3(sd * 0.3, 0.2, sin(ph + (0.0 if sd > 0 else PI)) * 0.3 * runk + 0.05)
		if fear > 0.0:
			var tr := sin(tv * 40.0) * 0.02 * fear
			pos.x += tr
			for k in arms.size():
				var sd: float = arms[k].side
				arm_t[k] = Vector3(sd * 0.14, 0.5, 0.32) if fear < 0.8 else Vector3(sd * 0.42, 0.95 + sin(tv * 16.0 + sd) * 0.1, 0.1)
			K.set_face(m, face, 0.35 + 0.55 * fear, 1.0 + 0.3 * fear, 0.4 + 0.5 * fear)
		elif phase == "fall" and not falls:
			K.set_face(m, face, 0.6, 1.05, 0.5)   # megkönnyebbülés
			if int(s.cheer_r) != round_i and phase_t > 0.3:
				s.cheer_r = round_i
				m.emote("happy")
		else:
			K.set_face(m, face, 0.0, 1.0, 0.0)
	# a figura gyökere
	var b := basis * Basis(Vector3.RIGHT, lean + a.tilt * 0.3)
	b = b * Basis(Vector3.UP, a.spin)
	m.transform = Transform3D(b.scaled(Vector3(SC / sqrt(sy), SC * sy, SC / sqrt(sy))), pos + Vector3(0, a.y, 0))
	for k in arms.size():
		K.arm_to(arms[k], arm_t[k], Vector3(0.8, -0.4, -0.3))
	# lábak (zuhanáskor kapálóznak)
	for lg in s.legs:
		var sd: float = lg.side
		var seg: Node3D = lg.seg
		var ft: Node3D = lg.foot
		seg.visible = show_legs
		ft.visible = show_legs
		if show_legs:
			var hip := Vector3(sd * 0.13, 0.1, 0)
			var foot := Vector3(sd * 0.2, -0.28 + sin(tv * 17.0 + sd * 1.7) * 0.12, sin(tv * 15.0 + sd) * 0.2)
			W.place_seg(seg, hip, foot)
			ft.position = foot + Vector3(0, -0.03, 0.05)
	# színes gyűrű a talpa alatt
	disc.visible = m.visible and s.vis == "stand"
	disc.position = Vector3(pos.x, 0.03, pos.z)
	# a villám beugrásakor szikrák a panelen
	var pk: float = tv - float(s.pen_t)
	if pk >= 0.12 and float(s.burst_t) != float(s.pen_t):
		s.burst_t = s.pen_t
		var pp := _panel_pos(s.i)
		Main.I.burst(pp.x + 20, pp.y + 12, {"n": 14, "colors": ["#ffd21f", "#fff3bf", "#ffffff"], "speed": 220, "life": 0.5, "size": 6})
		Audio.play("sparkle")


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	var tv := t + post
	var r: int = clampi(round_i - 1, 0, ROUNDS - 1)
	# szél: a viharral erősödő csíkok
	var nw := int(6 + 34 * storm_v)
	for k in nw:
		var sp := 900.0 + (k % 5) * 160.0
		var x := 1380.0 - fmod(k * 197.0 + tv * sp, 1500.0)
		var y := fmod(k * 83.0 + sin(tv + k) * 20.0, 720.0)
		var ln := 40.0 + (k % 4) * 22.0
		c.draw_line(Vector2(x, y), Vector2(x + ln, y - ln * 0.12), Color(1, 1, 1, 0.12 + 0.18 * storm_v), 2.0)
	# a zuhanók mögötti sebességcsíkok
	for s in pl:
		if s.vis != "air":
			continue
		var q := screen(s.fpos)
		if q.x < -100:
			continue
		for k in 3:
			var ox := (k - 1) * 14.0
			c.draw_line(Vector2(q.x + ox, q.y - 30 - k * 6), Vector2(q.x + ox, q.y - 80 - k * 14), Color(1, 1, 1, 0.45), 3.0)
	# feszültség a 3. körben: lüktető sötét keret
	if not swapped and r == 2 and (phase == "suspense" or phase == "shake"):
		var pulse := 0.5 + 0.5 * sin(tv * 9.0)
		for i in 5:
			var w := 34.0 - i * 6.0
			var col := Color(0.25, 0.0, 0.05, 0.08 + 0.1 * pulse)
			c.draw_rect(Rect2(0, 0, 1280, w), col)
			c.draw_rect(Rect2(0, 720 - w, 1280, w), col)
			c.draw_rect(Rect2(0, 0, w, 720), col)
			c.draw_rect(Rect2(1280 - w, 0, w, 720), col)
	# nevek a fejek fölött
	if phase != "wipe" and phase != "finish" and not finished:
		for s in pl:
			if s.vis != "stand":
				continue
			var q := screen(Vector3(s.x, 2.05, s.z))
			var col: Color = s.col
			D.panel(c, q.x - 24, q.y - 13, 48, 24, {"r": 12, "fill": col, "stroke": Color.WHITE, "lw": 2.5, "shadow": false})
			D.text(c, "%dP" % (int(s.i) + 1), q.x, q.y - 1, {"size": 14, "stroke": col.darkened(0.5), "sw": 3})
			c.draw_colored_polygon(PackedVector2Array([Vector2(q.x - 6, q.y + 11), Vector2(q.x + 6, q.y + 11), Vector2(q.x, q.y + 18)]), Color.WHITE)
	# óra és kör
	if not swapped and (phase == "prep" or phase == "pick"):
		var rem := PICK_TIME if phase == "prep" else PICK_TIME - phase_t
		K.silver_timer(c, rem, 640, 46, 3.0, tv)
	if round_i > 0 and not swapped:
		D.text(c, "%d. KÖR / %d" % [round_i, ROUNDS], 640, 98, {"size": 20, "color": Color("#ffffff"), "stroke": Color("#1c2b4a"), "sw": 5})
	# feliratok
	match phase:
		"prep":
			K.banner(c, "%d. KÖR" % round_i if round_i < ROUNDS else "UTOLSÓ KÖR!", phase_t, PREP_TIME - 0.1, 250.0, Color("#ffffff"), 84)
		"pick":
			K.banner(c, "Fuss a jó oldalra!", phase_t, 1.0, 170.0, Color("#ffe066"), 54)
		"lock":
			K.banner(c, "ÁLLJ!", phase_t, 0.7, 250.0, Color("#ff6b6b"), 110)
		"suspense":
			D.text(c, "Melyik oldal zuhan?!", 640, 160, {"size": 38, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 8})
		"drop", "fall":
			var k := phase_t + (DROP_TIME if phase == "fall" else 0.0)
			K.banner(c, "A %s OLDAL ZUHAN!" % SIDE_NAME[doomed], k, 2.4, 160.0, Color(SIDE_HEX[doomed]).lightened(0.35), 60)
	# villám-felvillanás
	if flash > 0.0:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, flash * 0.28))
	# átúszás a célplatformra
	if phase == "wipe":
		var al: float = 1.0 - absf(phase_t - 0.45) / 0.45
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, clamp(al, 0.0, 1.0)))
	# FINISH! és helyezések
	if swapped and (phase == "finish" or finished):
		var k := phase_t if not finished else FINISH_TIME + post
		_draw_finish(c, k)
		for s in pl:
			var place: int = places.get(s.i, 0)
			var lk: float = (k - 0.9 - (pl.size() - place) * 0.12) * 2.5
			var q := screen(Vector3(s.x, 2.45, s.z))
			if place <= 3:
				K.place_label(c, place, q.x, q.y, lk, 44)
			elif lk > 0.0:
				D.text(c, "%d." % (place + 1), q.x, q.y, {"size": 38, "color": Color("#9aa5b1"), "stroke": D.DARK, "sw": 8})
	for s in pl:
		_draw_panel(c, s, tv)


func _draw_finish(c: CanvasItem, k: float) -> void:
	var s := D.ease_out_back(clamp(k * 2.2, 0.0, 1.0)) * (1.0 + sin(k * 6.0) * 0.03)
	c.draw_set_transform(Vector2(640, 150), sin(k * 3.0) * 0.03, Vector2(s, s))
	for i in range(6, 0, -1):
		D.text(c, "FINISH!", i * 1.5, i * 2.2, {"size": 104, "color": Color("#b84a00"), "stroke": Color("#5a1d00"), "sw": 14})
	D.text(c, "FINISH!", 0, 0, {"size": 104, "color": Color("#ffb21a"), "stroke": Color("#ffffff"), "sw": 8})
	D.text(c, "FINISH!", 0, -6, {"size": 104, "color": Color(1, 0.93, 0.35, 0.55)})
	c.draw_set_transform(Vector2.ZERO)


## Állapotpanelek a sarkokban (1P bal fent, 2P jobb fent, 3P bal lent, 4P jobb lent);
## csak annyi, ahány valódi játékos van.
func _panel_pos(i: int) -> Vector2:
	var pos := [Vector2(122, 56), Vector2(1158, 56), Vector2(122, 664), Vector2(1158, 664),
		Vector2(352, 56), Vector2(928, 56), Vector2(352, 664), Vector2(928, 664)]
	return pos[i % pos.size()]


const BOLT := [Vector2(0.08, -0.5), Vector2(-0.26, 0.06), Vector2(-0.03, 0.06), Vector2(-0.14, 0.5), Vector2(0.26, -0.08), Vector2(0.03, -0.08), Vector2(0.17, -0.5)]


static func _bolt(c: CanvasItem, at: Vector2, size: float, lit: bool) -> void:
	var pts := PackedVector2Array()
	for q in BOLT:
		pts.append(at + q * size)
	c.draw_colored_polygon(pts, Color("#ffd21f") if lit else Color("#9aa3b2"))
	var hi := PackedVector2Array()
	for k in 3:
		hi.append(at + (BOLT[k] as Vector2) * size * 0.7 + Vector2(size * 0.03, -size * 0.04))
	if lit:
		c.draw_colored_polygon(hi, Color(1, 1, 0.8, 0.6))
	var ol := pts.duplicate()
	ol.append(pts[0])
	c.draw_polyline(ol, Color("#7a4b00") if lit else Color("#4a5160"), 3.0, true)


func _draw_panel(c: CanvasItem, s: Dictionary, tv: float) -> void:
	var p := _panel_pos(s.i)
	var col: Color = s.col
	var pk: float = tv - float(s.pen_t)
	var sc := 1.0
	if pk >= 0.0 and pk < 0.4:
		sc += sin(pk / 0.4 * PI) * 0.1
	c.draw_set_transform(p, 0, Vector2(sc, sc))
	var w := 210.0
	var h := 76.0
	D.panel(c, -w / 2, -h / 2, w, h, {"r": 24, "fill": col, "stroke": Color.WHITE, "lw": 4.0})
	D.panel(c, -w / 2 + 6, -h / 2 + 5, w - 12, h * 0.4, {"r": 18, "fill": Color(1, 1, 1, 0.22), "stroke": null, "shadow": false})
	D.panel(c, -w / 2 + 8, -29, 58, 58, {"r": 29, "fill": Color.WHITE, "stroke": col.darkened(0.3), "lw": 3.0, "shadow": false})
	D.char_image(c, s.p.char_id, -w / 2 + 37, 0, 54, 0.55 if s.vis == "air" or s.vis == "gone" else 1.0)
	D.text(c, s.p.name, -w / 2 + 74, -20, {"size": 14, "align": "left", "maxw": 128, "stroke": col.darkened(0.5), "sw": 3})
	var pen: int = s.pen
	var nb: int = maxi(2, pen)
	for k in nb:
		var lit := k < pen
		var bs := 32.0
		# a legújabb villám beugrik
		if lit and k == pen - 1 and pk >= 0.0 and pk < 0.6:
			bs *= 1.0 + sin(clamp(pk / 0.35, 0.0, 1.0) * PI) * 0.6
			lit = pk > 0.12
		_bolt(c, Vector2(-w / 2 + 92 + k * (96.0 / nb + 4.0), 12), bs, lit)
	c.draw_set_transform(Vector2.ZERO)
