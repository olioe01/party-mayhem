extends Minigame
## Sínharc: várudvar, benne sínhálózat (külső kör, belső keresztutak). Mindenki egy kis, kerek dodzsemkocsin ül,
## ami a síneken halad; a kereszteződésekben a játékos választ irányt. Elöl ágyú, hátul céltábla:
## csak a céltáblát eltaláló lövés sebez. 3 életerő, 60 másodperc; az utolsó talpon maradó (vagy a több életerő) nyer.

const K = preload("res://scripts/minigames/mg_kit.gd")

const LIMIT := 60.0
const XS := [-8.4, -2.8, 2.8, 8.4]
const ZS := [-5.0, 0.0, 5.0]
const R := 0.9                    # kanyarsugár a csomópontokban
const LOOK := 1.6                 # ennyivel a kanyar előtt már látszik a választott irány
const SPEED := 3.4
const VEH_R := 0.64
const VEH_SCALE := 1.35
const HP := 3
const SHOT_CD := 0.8
const SHOT_SPEED := 10.5
const SHOT_LIFE := 2.2
const SHOT_Y := 0.72
const SHOT_R := 0.12
const REAR_DOT := -0.25           # ennél „hátulsóbb” becsapódás találja el a céltáblát
const INVULN := 0.6
const WALL_X := 9.95
const WALL_Z := 6.45
const VEH_COLS := ["#2f80ff", "#f03e3e", "#2fb344", "#fcc419", "#9b5de5", "#13b5c8", "#f0609e", "#ff8c1a"]
## kezdőhelyek (sín két végpontja); 4 főig a külső kör négy sarka, utána a belső keresztutak is
const START := [[0, 1], [3, 7], [11, 10], [8, 4], [5, 6], [6, 10], [9, 5], [2, 1]]
const AI_THINK := [0.5, 0.28, 0.12]
const AI_AIM := [0.34, 0.21, 0.11]
const AI_REV_CD := [3.5, 2.0, 1.2]
const AI_WRONG := [0.3, 0.12, 0.03]

var nodes: Array = []             # Vector3
var adj: Array = []               # szomszédlisták
var hedges: Array = []            # Rect2 az xz síkon (x, z)
var pl: Array = []
var shots: Array = []             # lövedék-készlet (újrahasznosítva)
var sparks: Array = []            # becsapódási szikra-készlet
var spark_i := 0
var out_order: Array = []
var over := false
var end_at := -1.0
var places := {}
var shake := 0.0
var cam_base := Vector3.ZERO
var msg_text := ""
var msg_col := Color.WHITE
var msg_t0 := -10.0
var msg_dur := 1.2


func meta() -> Dictionary:
	return {"id": "rails", "name": "Sínharc", "icon": "🚃", "color": "#2f80ff", "modes": ["ffa"],
		"tagline": "Lődd hátba a többieket!",
		"desc": "Kis ágyús kocsikkal száguldoztok a várudvar sínjein. Elölről páncél véd, de hátul mindenkinek céltábla van: azt kell eltalálni! Három találat és kiestél. 60 másodperc után a több életerő nyer.",
		"controls": "A joystickkal választod ki, merre fordulj a kereszteződésben (hátrahúzva megfordulsz), a TŰZ gombbal lősz. A hedge-sövény és a fal elnyeli a lövést."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "btn": "💥 TŰZ", "cd": int(SHOT_CD * 1000)}


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	make_env("#3b82f6", "#cfe8ff", 0.95)
	cam_base = Vector3(0, 17.0, 12.8)
	make_camera(cam_base, Vector3(0, 0, 0.9), 44)
	var sun := make_sun(Vector3(-58, -25, 0), 1.3, "#fff1d6")
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 45.0
	_build_graph()
	_build_courtyard()
	_build_rails()
	_build_pools()
	var all := players.duplicate()
	var ai_k := 0
	for i in all.size():
		var p = all[i]
		var cpu := not players.has(p)
		var lvl := 1
		if cpu or p.is_bot:
			lvl = K.ai_level(ai_k)
			ai_k += 1
		pl.append(_make_vehicle(p, i, cpu, lvl))
	_sync(0.0)


func _nid(xi: int, zi: int) -> int:
	return zi * XS.size() + xi


func _build_graph() -> void:
	for zi in ZS.size():
		for xi in XS.size():
			nodes.append(Vector3(XS[xi], 0, ZS[zi]))
			adj.append([])
	for zi in ZS.size():
		for xi in XS.size():
			var a := _nid(xi, zi)
			if xi + 1 < XS.size():
				_link(a, _nid(xi + 1, zi))
			if zi + 1 < ZS.size():
				_link(a, _nid(xi, zi + 1))


func _link(a: int, b: int) -> void:
	adj[a].append(b)
	adj[b].append(a)


func _dir(a: int, b: int) -> Vector3:
	return (nodes[b] - nodes[a]).normalized()


func _has_straight(node: int, d: Vector3) -> bool:
	for c in adj[node]:
		if _dir(node, c).dot(d) > 0.99:
			return true
	return false


static var _tile: ImageTexture


static func _tile_tex() -> ImageTexture:
	if _tile:
		return _tile
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rnd := BoardLayout.Seeded.new(31)
	for y in n:
		for x in n:
			var c := Color("#b9835a")
			if x % 16 == 0 or y % 16 == 0:
				c = Color("#8a5a3a")
			else:
				var q := (x / 16) + (y / 16) * 2
				c = c.darkened(0.06 * (q % 3)).lerp(Color("#c9956a"), rnd.next() * 0.25)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tile = ImageTexture.create_from_image(img)
	return _tile


func _build_courtyard() -> void:
	var tile := StandardMaterial3D.new()
	tile.albedo_texture = _tile_tex()
	tile.uv1_scale = Vector3(14, 10, 1)
	tile.roughness = 0.8
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(22, 15)
	ground.mesh = pm
	ground.material_override = tile
	add_child(ground)
	# a falon kívül fű
	var grass := Chars3D.mat("#5cb85c", {"rough": 0.95})
	Chars3D.box(self, 70, 0.1, 50, grass, Vector3(0, -0.06, 0))
	var stone := Chars3D.mat("#4f7fd9", {"rough": 0.7})
	var stone_d := Chars3D.mat("#3d66b8", {"rough": 0.7})
	var cream := Chars3D.mat("#fff1d0", {"rough": 0.6})
	var orange := Chars3D.mat("#ff922b", {"rough": 0.55})
	var roof := Chars3D.mat("#e8590c", {"rough": 0.5})
	var dark := Chars3D.mat("#1f2a44", {"rough": 0.6})
	# hátsó (északi) magas fal kapuval
	var nz := -7.0
	for sx in [-1, 1]:
		var cx: float = sx * 6.2
		Chars3D.box(self, 8.6, 3.4, 1.0, stone, Vector3(cx, 1.7, nz))
		Chars3D.box(self, 8.7, 0.25, 1.1, cream, Vector3(cx, 3.45, nz))
		Chars3D.box(self, 8.7, 0.18, 1.08, orange, Vector3(cx, 0.6, nz))
		for k in 9:
			Chars3D.box(self, 0.55, 0.55, 1.0, stone_d, Vector3(cx - 4.0 + k * 1.0, 3.85, nz))
		for k in 3:
			var wx: float = cx - 2.6 + k * 2.6
			Chars3D.box(self, 0.6, 0.9, 0.12, dark, Vector3(wx, 2.0, nz + 0.5))
			Chars3D.cyl(self, 0.3, 0.3, 0.12, dark, wx, 2.45, nz + 0.5, 14, Vector3(PI / 2, 0, 0))
			Chars3D.box(self, 0.85, 0.1, 0.24, cream, Vector3(wx, 1.52, nz + 0.55))
	# kapu
	Chars3D.box(self, 3.6, 4.6, 1.3, stone_d, Vector3(0, 2.3, nz - 0.1))
	Chars3D.box(self, 2.2, 2.4, 0.2, Chars3D.mat("#7a4a26", {"rough": 0.7}), Vector3(0, 1.2, nz + 0.52))
	Chars3D.cyl(self, 1.1, 1.1, 0.2, Chars3D.mat("#7a4a26", {"rough": 0.7}), 0, 2.4, nz + 0.52, 18, Vector3(PI / 2, 0, 0))
	Chars3D.cyl(self, 1.3, 1.3, 0.16, cream, 0, 2.4, nz + 0.45, 18, Vector3(PI / 2, 0, 0))
	for k in 5:
		Chars3D.box(self, 0.08, 2.3, 0.05, Chars3D.mat("#3d2614"), Vector3(-0.8 + k * 0.4, 1.3, nz + 0.64))
	for k in 4:
		Chars3D.box(self, 0.6, 0.6, 1.3, stone, Vector3(-1.35 + k * 0.9, 4.9, nz - 0.1))
	Chars3D.box(self, 3.8, 0.25, 1.4, orange, Vector3(0, 4.55, nz - 0.1))
	# zászlók a kapun
	for sx in [-1, 1]:
		Chars3D.cyl(self, 0.04, 0.04, 1.6, dark, sx * 1.35, 6.0, nz - 0.1, 6)
		Chars3D.box(self, 0.7, 0.45, 0.04, Chars3D.mat("#ffd43b"), Vector3(sx * 1.35 + 0.37, 6.5, nz - 0.1))
	# tornyok a sarkokban: kék kő, krémszínű és narancs díszítés, kúpos tető
	for tp in [Vector2(-10.6, nz), Vector2(10.6, nz), Vector2(-10.6, 7.0), Vector2(10.6, 7.0)]:
		var tall := 5.4 if tp.y < 0 else 2.6
		Chars3D.cyl(self, 1.1, 1.2, tall, stone, tp.x, tall / 2, tp.y, 14)
		Chars3D.cyl(self, 1.28, 1.28, 0.3, cream, tp.x, tall + 0.1, tp.y, 14)
		Chars3D.cyl(self, 1.22, 1.22, 0.16, orange, tp.x, tall * 0.35, tp.y, 14)
		if tp.y < 0:
			Chars3D.cone(self, 1.45, 2.2, roof, tp.x, tall + 1.35, tp.y, 14)
			Chars3D.cyl(self, 0.22, 0.22, 0.12, dark, tp.x, tall * 0.7, tp.y + 1.08, 12, Vector3(PI / 2, 0, 0))
		else:
			for k in 6:
				var a := TAU * k / 6.0
				Chars3D.box(self, 0.42, 0.45, 0.42, stone_d, Vector3(tp.x + cos(a) * 1.0, tall + 0.45, tp.y + sin(a) * 1.0))
	# oldalfalak (alacsonyabbak, hogy a sínek látsszanak)
	for sx in [-1, 1]:
		Chars3D.box(self, 0.9, 1.5, 13.4, stone, Vector3(sx * 10.6, 0.75, 0))
		Chars3D.box(self, 1.0, 0.18, 13.5, cream, Vector3(sx * 10.6, 1.55, 0))
		for k in 10:
			Chars3D.box(self, 0.9, 0.42, 0.6, stone_d, Vector3(sx * 10.6, 1.85, -5.6 + k * 1.25))
	# elöl csak mellvéd
	Chars3D.box(self, 21.2, 0.7, 0.8, stone, Vector3(0, 0.35, 7.1))
	Chars3D.box(self, 21.3, 0.14, 0.9, cream, Vector3(0, 0.74, 7.1))
	# díszbokrok a falak mentén
	var bush := [Chars3D.mat("#2f9e44"), Chars3D.mat("#40c057"), Chars3D.mat("#37b24d")]
	for k in 12:
		var bx := -9.2 + k * 1.67
		if abs(bx) < 2.2:
			continue
		Chars3D.lsphere(self, 0.42, bush[k % 3], bx, 0.3, -6.25, 1.1, 0.8, 0.8, 8, 6)
	for sx in [-1, 1]:
		for k in 4:
			Chars3D.lsphere(self, 0.36, bush[k % 3], sx * 9.75, 0.28, -2.5 + k * 1.7 if k < 2 else 1.0 + k * 0.9, 0.8, 0.8, 1.1, 8, 6)
	# sövénykertek a négy sarokcellában
	for cx in [-5.6, 5.6]:
		for cz in [-2.5, 2.5]:
			_hedge(cx, cz, 3.9, 3.3)
	# virágágyások a középső cellákban (alacsonyak: a lövés átrepül fölöttük)
	for cz in [-2.5, 2.5]:
		_flowerbed(0.0, cz, 3.6, 2.9)


func _hedge(cx: float, cz: float, w: float, d: float) -> void:
	var g1 := Chars3D.mat("#2b8a3e", {"rough": 0.95})
	var g2 := Chars3D.mat("#37b24d", {"rough": 0.95})
	var soil := Chars3D.mat("#6b4a2b", {"rough": 1.0})
	Chars3D.box(self, w + 0.2, 0.12, d + 0.2, soil, Vector3(cx, 0.06, cz))
	Chars3D.box(self, w, 0.85, d, g1, Vector3(cx, 0.5, cz))
	Chars3D.box(self, w - 0.16, 0.14, d - 0.16, g2, Vector3(cx, 0.98, cz))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Chars3D.lsphere(self, 0.34, g2, cx + sx * (w / 2 - 0.25), 1.18, cz + sz * (d / 2 - 0.25), 1, 1, 1, 8, 6)
	# a sövény közepén kis kút / szobor helyett virágos kőváza
	Chars3D.cyl(self, 0.28, 0.2, 0.3, Chars3D.mat("#fff1d0"), cx, 1.2, cz, 10)
	Chars3D.lsphere(self, 0.26, Chars3D.mat("#ff6b9a"), cx, 1.45, cz, 1, 0.7, 1, 8, 5)
	hedges.append(Rect2(cx - w / 2, cz - d / 2, w, d))


func _flowerbed(cx: float, cz: float, w: float, d: float) -> void:
	var border := Chars3D.mat("#fff1d0", {"rough": 0.7})
	var soil := Chars3D.mat("#5a3d2b", {"rough": 1.0})
	Chars3D.box(self, w, 0.22, d, border, Vector3(cx, 0.11, cz))
	Chars3D.box(self, w - 0.24, 0.24, d - 0.24, soil, Vector3(cx, 0.13, cz))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.2
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	var cols := [Color("#ff6b6b"), Color("#ffd43b"), Color("#f783ac"), Color("#ffffff"), Color("#b197fc"), Color("#ff922b")]
	var nx := 9
	var nz := 7
	mm.instance_count = nx * nz
	for i in nx:
		for j in nz:
			var px := cx - w / 2 + 0.3 + i * (w - 0.6) / (nx - 1)
			var pz := cz - d / 2 + 0.3 + j * (d - 0.6) / (nz - 1) + (0.08 if i % 2 == 0 else -0.08)
			mm.set_instance_transform(i * nz + j, Transform3D(Basis(), Vector3(px, 0.32, pz)))
			mm.set_instance_color(i * nz + j, cols[(i * 3 + j * 2) % cols.size()])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.6
	mi.material_override = fm
	add_child(mi)
	# levelek a virágok alatt
	Chars3D.box(self, w - 0.4, 0.06, d - 0.4, Chars3D.mat("#40c057"), Vector3(cx, 0.26, cz))


## Sínek: egyenesek a csomópontok között, a kanyarokban íves szakaszok; mind két MultiMesh-ben (sín és talpfa).
func _build_rails() -> void:
	var rail_tf: Array = []
	var tie_tf: Array = []
	var gauge := 0.19
	for a in nodes.size():
		for b in adj[a]:
			if b < a:
				continue
			var d := _dir(a, b)
			var p0: Vector3 = nodes[a]
			var p1: Vector3 = nodes[b]
			# ahol a csomóponton nincs egyenes továbbhaladás, ott az egyenes a kanyar elején véget ér
			if not _has_straight(a, -d):
				p0 += d * R
			if not _has_straight(b, d):
				p1 -= d * R
			var ln := p0.distance_to(p1)
			var side := Vector3(-d.z, 0, d.x)
			var basis := Basis.looking_at(d, Vector3.UP)
			for sgn in [-1, 1]:
				rail_tf.append(Transform3D(basis * Basis.from_scale(Vector3(0.07, 0.07, ln)), (p0 + p1) / 2 + side * gauge * sgn + Vector3(0, 0.07, 0)))
			var n := int(ln / 0.42)
			for k in n:
				var pp := p0 + d * ((k + 0.5) * ln / n)
				tie_tf.append(Transform3D(basis * Basis.from_scale(Vector3(0.62, 0.05, 0.15)), pp + Vector3(0, 0.025, 0)))
	# kanyarok: minden csomóponton minden merőleges ágpárhoz egy negyedív
	for a in nodes.size():
		var nb: Array = adj[a]
		for i in nb.size():
			for j in range(i + 1, nb.size()):
				var d1 := _dir(a, nb[i])
				var d2 := _dir(a, nb[j])
				if abs(d1.dot(d2)) > 0.1:
					continue
				var c: Vector3 = nodes[a] + (d1 + d2) * R
				var steps := 7
				for k in steps:
					var u0 := float(k) / steps
					var u1 := float(k + 1) / steps
					var q0 := _arc_pt(c, d1, d2, u0)
					var q1 := _arc_pt(c, d1, d2, u1)
					var dd := (q1 - q0).normalized()
					var basis := Basis.looking_at(dd, Vector3.UP)
					var mid := (q0 + q1) / 2
					var rad := (mid - c).normalized()
					for sgn in [-1, 1]:
						var rr: float = R + gauge * sgn
						var ln: float = (q1 - q0).length() * rr / R + 0.02
						rail_tf.append(Transform3D(basis * Basis.from_scale(Vector3(0.07, 0.07, ln)), c + rad * rr + Vector3(0, 0.07, 0)))
					if k % 2 == 1:
						tie_tf.append(Transform3D(basis * Basis.from_scale(Vector3(0.62, 0.05, 0.15)), mid + Vector3(0, 0.024, 0)))
	_mm(rail_tf, Chars3D.mat("#c8d0db", {"rough": 0.22, "metal": 0.85}))
	_mm(tie_tf, Chars3D.mat("#f3e3c3", {"rough": 0.75}))


## pont a negyedíven: a d1 irányú ág R távolságú pontjától a d2 irányú ág pontjáig (c: az ív középpontja)
func _arc_pt(c: Vector3, d1: Vector3, d2: Vector3, u: float) -> Vector3:
	var a := u * PI / 2
	return c - d2 * R * cos(a) - d1 * R * sin(a)


func _mm(tfs: Array, m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	add_child(mi)


func _build_pools() -> void:
	for i in 24:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var body := Chars3D.sphere(root, SHOT_R * 1.15, Chars3D.mat("#ffffff"))
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ghosts: Array = []
		for k in 4:
			var gh := Chars3D.sphere(self, SHOT_R * (0.9 - k * 0.17), Chars3D.mat("#ffffff"))
			gh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gh.visible = false
			ghosts.append(gh)
		shots.append({"on": false, "n": root, "body": body, "ghosts": ghosts, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "owner": -1, "life": 0.0})
	var dot := QuadMesh.new()
	dot.size = Vector2(0.16, 0.16)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = dm
	for i in 8:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 1.0
		p.amount = 26
		p.lifetime = 0.55
		p.local_coords = false
		p.mesh = dot
		p.spread = 180.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -7, 0)
		p.damping_min = 2.0
		p.damping_max = 3.0
		add_child(p)
		sparks.append(p)


func _spark(pos: Vector3, cols: Array, n := 26, speed := 1.0) -> void:
	var p: CPUParticles3D = sparks[spark_i]
	spark_i = (spark_i + 1) % sparks.size()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(cols[0]) * 2.0, Color(cols[1]), Color(Color(cols[1]), 0.0)])
	p.color_ramp = g
	p.amount = n
	p.initial_velocity_min = 2.0 * speed
	p.initial_velocity_max = 5.0 * speed
	p.global_position = pos
	p.restart()


func _make_vehicle(p, i: int, cpu: bool, lvl: int) -> Dictionary:
	var col := Color(VEH_COLS[i % VEH_COLS.size()])
	var root := Chars3D.grp(self)
	root.scale = Vector3.ONE * VEH_SCALE
	var body := Chars3D.grp(root)
	var paint: StandardMaterial3D = Chars3D.mat(col.to_html(), {"rough": 0.3}).duplicate()
	var paint_l := Chars3D.mat(col.lightened(0.35).to_html(), {"rough": 0.3})
	var rubber := Chars3D.mat("#2b2d36", {"rough": 0.6})
	var metal := Chars3D.mat("#adb5bd", {"rough": 0.25, "metal": 0.8})
	# alváz és kerekek
	Chars3D.box(body, 0.5, 0.12, 0.74, Chars3D.mat("#495057", {"metal": 0.5, "rough": 0.4}), Vector3(0, 0.13, 0))
	var wheels: Array = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var w := Chars3D.grp(body, Vector3(sx * 0.19, 0.11, sz * 0.27))
			Chars3D.cyl(w, 0.1, 0.1, 0.07, rubber, 0, 0, 0, 10, Vector3(0, 0, PI / 2))
			Chars3D.box(w, 0.075, 0.13, 0.03, metal, Vector3.ZERO)
			wheels.append(w)
	# kerek kád: henger, gumi lökhárító, peremen világos csík
	var tub := Chars3D.grp(body, Vector3(0, 0.38, 0))
	Chars3D.cyl(tub, 0.46, 0.4, 0.42, paint, 0, 0, 0, 18)
	Chars3D.part(tub, Chars3D.torus(0.46, 0.08), rubber, Vector3(0, -0.12, 0))
	Chars3D.part(tub, Chars3D.torus(0.44, 0.045), paint_l, Vector3(0, 0.21, 0))
	Chars3D.cyl(tub, 0.36, 0.36, 0.05, Chars3D.mat("#212529"), 0, 0.2, 0, 16)
	# ágyú elöl
	var gun := Chars3D.grp(tub, Vector3(0, 0.12, 0.42))
	Chars3D.sphere(gun, 0.13, metal)
	Chars3D.cyl(gun, 0.075, 0.09, 0.42, Chars3D.mat("#343a40", {"metal": 0.6, "rough": 0.3}), 0, 0, 0.2, 10, Vector3(PI / 2, 0, 0))
	Chars3D.cyl(gun, 0.1, 0.1, 0.06, paint_l, 0, 0, 0.4, 10, Vector3(PI / 2, 0, 0))
	# céltábla hátul: piros-fehér koncentrikus körök
	var tgt := Chars3D.grp(tub, Vector3(0, 0.36, -0.44))
	Chars3D.box(tgt, 0.06, 0.32, 0.06, metal, Vector3(0, -0.2, 0.02))
	var rings := ["#ffffff", "#e03131", "#ffffff", "#e03131", "#ffffff", "#e03131"]
	for k in rings.size():
		var rr := 0.34 - k * 0.055
		Chars3D.cyl(tgt, rr, rr, 0.04 + k * 0.006, Chars3D.mat(rings[k], {"rough": 0.4}), 0, 0, -0.01 - k * 0.003, 20, Vector3(PI / 2, 0, 0))
	# kormány
	var wheel_g := Chars3D.grp(tub, Vector3(0, 0.36, 0.22))
	Chars3D.cyl(wheel_g, 0.025, 0.025, 0.25, metal, 0, -0.12, -0.02, 6, Vector3(0.4, 0, 0))
	Chars3D.part(wheel_g, Chars3D.torus(0.11, 0.022), rubber, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2 - 0.5, 0, 0))
	# figura derékig a kádban
	var m := player_model(p, 0.78)
	remove_child(m)
	tub.add_child(m)
	m.position = Vector3(0, 0.02, -0.05)
	var arms := K.build_arms(m, col.to_html(), 0.34)
	var face := K.build_face(m)
	# szédülés-csillagok (kiesés után)
	var stars: Array = []
	for k in 3:
		var st := Chars3D.sphere(m, 0.07, Chars3D.mat("#ffe066", {"emit": "#ffd43b", "emit_e": 1.5}))
		st.visible = false
		stars.append(st)
	var st0: Array = START[i % START.size()]
	var s := {"p": p, "cpu": cpu, "lvl": lvl, "i": i, "col": col, "root": root, "body": body, "tub": tub, "m": m, "wheels": wheels,
		"tgt": tgt, "arms": arms, "face": face, "stars": stars, "paint": paint,
		"a": st0[0], "b": st0[1], "s": 1.2, "prev": -1, "next": -1, "pending": -1,
		"pos": Vector3.ZERO, "hd": Vector3.FORWARD, "vis_yaw": 0.0, "stick": Vector2.ZERO,
		"hp": HP, "hits": 0, "shots": 0, "dmg": 0, "alive": true, "out_t": -1.0, "cd": 0.0, "inv": 0.0,
		"hit_t": -10.0, "bump_t": -10.0, "rev_t": -10.0, "fire_t": -10.0, "spin": 0.0,
		"ai_t": randf_range(0.0, 0.3), "ai_rev": 0.0, "target": -1}
	_place(s)
	s.vis_yaw = atan2(s.hd.x, s.hd.z)
	return s


# ------------------------------------------------------------------ pályakövetés
func _edge_len(s: Dictionary) -> float:
	return (nodes[s.b] as Vector3).distance_to(nodes[s.a])


func _is_turn(x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0:
		return false
	return abs(_dir(x, y).dot(_dir(y, z))) < 0.5


## Helyzet és irány a sínen: egyenesen lineáris, a kanyarok R sugarú környékén másodfokú Bézier-ív.
func _place(s: Dictionary) -> void:
	var a: int = s.a
	var b: int = s.b
	var L := _edge_len(s)
	var d := _dir(a, b)
	var sv: float = s.s
	var pa: Vector3 = nodes[a]
	var pb: Vector3 = nodes[b]
	if sv > L - R and _is_turn(a, b, s.next):
		var u: float = (sv - (L - R)) / (2.0 * R)
		var dn := _dir(b, s.next)
		_bez(s, pb - d * R, pb, pb + dn * R, u)
	elif sv < R and _is_turn(s.prev, a, b):
		var u: float = 0.5 + sv / (2.0 * R)
		var dp := _dir(s.prev, a)
		_bez(s, pa - dp * R, pa, pa + d * R, u)
	else:
		s.pos = pa + d * sv
		s.hd = d


func _bez(s: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3, u: float) -> void:
	var iu := 1.0 - u
	s.pos = p0 * iu * iu + p1 * 2.0 * u * iu + p2 * u * u
	var tg := (p1 - p0) * 2.0 * iu + (p2 - p1) * 2.0 * u
	s.hd = tg.normalized() if tg.length() > 0.0001 else _dir(s.a, s.b)


## Melyik ágra menjen tovább a b csomópontból: a kar (stick) iránya szerint; ha nincs kitérítve, egyenesen.
func _pick_branch(s: Dictionary) -> int:
	var cands: Array = []
	for c in adj[s.b]:
		if c != s.a:
			cands.append(c)
	if cands.is_empty():
		return s.a
	var din := _dir(s.a, s.b)
	var st: Vector2 = s.stick
	if st.length() > 0.35:
		var want := Vector3(st.x, 0, st.y).normalized()
		var best: int = cands[0]
		var bd := -9.0
		for c in cands:
			var dd := _dir(s.b, c).dot(want)
			if dd > bd:
				bd = dd
				best = c
		return best
	for c in cands:
		if _dir(s.b, c).dot(din) > 0.99:
			return c
	return cands[0]


func _reverse(s: Dictionary) -> void:
	var L := _edge_len(s)
	var old_s: float = s.s
	var na: int = s.b
	var nb: int = s.a
	var nprev: int = s.next if old_s > L - R else -1
	var nnext: int = s.prev if old_s < R else -1
	s.a = na
	s.b = nb
	s.s = L - old_s
	s.prev = nprev
	s.next = nnext
	s.pending = -1
	s.rev_t = t


func _move(s: Dictionary, dt: float) -> void:
	var L := _edge_len(s)
	s.s += SPEED * dt
	if s.next < 0:
		if s.s >= L - R:
			s.next = _pick_branch(s)
			s.pending = -1
		elif s.s >= L - R - LOOK:
			s.pending = _pick_branch(s)
	while s.s >= L:
		s.s -= L
		var nb: int = s.next if s.next >= 0 else _pick_branch(s)
		s.prev = s.a
		s.a = s.b
		s.b = nb
		s.next = -1
		s.pending = -1
		L = _edge_len(s)
	_place(s)


# ------------------------------------------------------------------ bemenet és gépek
func _get(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	var s := _get(p)
	if s.is_empty() or not s.alive or over:
		return
	match msg.get("t"):
		"stick":
			s.stick = Vector2(float(msg.get("x", 0)), float(msg.get("y", 0))).limit_length(1.0)
			_stick_reverse(s)
		"btn":
			_fire(s)


## erősen hátrahúzott kar: megfordul (kis várakozással, hogy ne pörögjön)
func _stick_reverse(s: Dictionary) -> void:
	var st: Vector2 = s.stick
	if st.length() < 0.6 or t - s.rev_t < 0.5:
		return
	var w := Vector3(st.x, 0, st.y).normalized()
	if w.dot(s.hd) < -0.75:
		_reverse(s)
		_place(s)


func bot(p, dt: float) -> void:
	var s := _get(p)
	if not s.is_empty():
		_ai(s, dt)


func _ai(s: Dictionary, dt: float) -> void:
	if not s.alive or over:
		return
	s.ai_t -= dt
	if s.ai_t > 0.0:
		return
	var lvl: int = s.lvl
	s.ai_t = AI_THINK[lvl] * randf_range(0.8, 1.25)
	# célpont: a legközelebbi élő ellenfél (a nehéz gép a sebzettebbet is szívesen üldözi)
	var best := -1
	var bd := 1e9
	for o in pl:
		if o == s or not o.alive:
			continue
		var dd: float = (o.pos as Vector3).distance_to(s.pos)
		if lvl == 2:
			dd -= (HP - int(o.hp)) * 1.5
		if dd < bd:
			bd = dd
			best = o.i
	s.target = best
	if best < 0:
		s.stick = Vector2.ZERO
		return
	var o: Dictionary = pl[best]
	# a cél mögé igyekszik: oda, ahol a céltáblája felé lehet lőni
	var goal: Vector3 = o.pos - (o.hd as Vector3) * 2.4
	var to_goal: Vector3 = goal - s.pos
	var want := Vector2(to_goal.x, to_goal.z).normalized()
	if randf() < AI_WRONG[lvl]:
		want = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	s.stick = want
	# megfordulás, ha a cél egyértelműen mögötte van
	s.ai_rev -= AI_THINK[lvl]
	var tv := Vector3(to_goal.x, 0, to_goal.z)
	if s.ai_rev <= 0.0 and tv.length() > 2.0 and tv.normalized().dot(s.hd) < -0.6:
		_reverse(s)
		_place(s)
		s.ai_rev = AI_REV_CD[lvl] * randf_range(0.8, 1.3)
	# lövés: ha a (sebességgel előre számolt) célpont az ágyú vonalában van
	if s.cd > 0.0:
		return
	var muzzle: Vector3 = s.pos + (s.hd as Vector3) * 0.9
	for oo in pl:
		if oo == s or not oo.alive:
			continue
		var rel: Vector3 = oo.pos - muzzle
		var dist := rel.length()
		if dist > 12.0 or dist < 0.3:
			continue
		var lead: Vector3 = oo.pos + (oo.hd as Vector3) * SPEED * (dist / SHOT_SPEED)
		var aim: Vector3 = (lead - muzzle).normalized()
		var ang: float = acos(clamp(aim.dot(s.hd), -1.0, 1.0))
		if ang > AI_AIM[lvl] * randf_range(0.7, 1.4):
			continue
		# a közepes és a nehéz gép csak akkor lő, ha a céltábla felé néz és nincs sövény útban
		# a könnyű gép gyakran elszalasztja a lehetőséget, a közepes és a nehéz csak akkor lő,
		# ha a céltábla felé néz és nincs sövény útban (a nehéz a félig oldalról jövő lövést is megkockáztatja)
		if lvl == 0 and randf() < 0.55:
			continue
		if lvl >= 1:
			var allow: float = REAR_DOT + (0.1 if lvl == 1 else 0.3)
			if (muzzle - lead).normalized().dot(oo.hd) > allow:
				continue
			if _blocked(muzzle, lead):
				continue
		_fire(s)
		break


func _blocked(a: Vector3, b: Vector3) -> bool:
	for h in hedges:
		var rr: Rect2 = (h as Rect2).grow(SHOT_R)
		var steps := 12
		for k in steps + 1:
			var q := a.lerp(b, float(k) / steps)
			if rr.has_point(Vector2(q.x, q.z)):
				return true
	return false


# ------------------------------------------------------------------ lövés, találat
func _fire(s: Dictionary) -> void:
	if s.cd > 0.0 or not s.alive or over:
		return
	var free := -1
	for k in shots.size():
		if not shots[k].on:
			free = k
			break
	if free < 0:
		return
	s.cd = SHOT_CD
	s.fire_t = t
	s.shots += 1
	var sh: Dictionary = shots[free]
	sh.on = true
	sh.owner = s.i
	sh.pos = s.pos + (s.hd as Vector3) * 0.9 + Vector3(0, SHOT_Y, 0)
	sh.vel = (s.hd as Vector3) * SHOT_SPEED
	sh.life = SHOT_LIFE
	var col: Color = s.col
	(sh.body as MeshInstance3D).material_override = Chars3D.mat(col.lightened(0.45).to_html(), {"emit": col.to_html(), "emit_e": 2.2})
	for k in sh.ghosts.size():
		(sh.ghosts[k] as MeshInstance3D).material_override = Chars3D.mat(col.lightened(0.3).to_html(), {"alpha": 0.55 - k * 0.12, "unshaded": true})
	Audio.play("cannon", FX.fr(0.92, 1.1))
	_spark(sh.pos, ["#fff3bf", "#ff922b"], 10, 0.6)


func _shots_step(dt: float) -> void:
	for sh in shots:
		if not sh.on:
			continue
		sh.life -= dt
		if sh.life <= 0.0:
			_kill_shot(sh, "")
			continue
		# két részlépés, hogy gyors lövedék se ugorja át a kocsit
		for k in 2:
			sh.pos += sh.vel * (dt / 2.0)
			var p2 := Vector2(sh.pos.x, sh.pos.z)
			if abs(sh.pos.x) > WALL_X or sh.pos.z < -WALL_Z or sh.pos.z > WALL_Z:
				_kill_shot(sh, "wall")
				break
			var hit_hedge := false
			for h in hedges:
				if (h as Rect2).grow(SHOT_R).has_point(p2):
					hit_hedge = true
					break
			if hit_hedge:
				_kill_shot(sh, "hedge")
				break
			var done := false
			for v in pl:
				if v.i == sh.owner or not v.alive:
					continue
				var rel: Vector3 = sh.pos - (v.pos as Vector3)
				rel.y = 0
				if rel.length() < VEH_R + SHOT_R:
					_impact(sh, v, rel)
					done = true
					break
			if done:
				break


func _kill_shot(sh: Dictionary, why: String) -> void:
	sh.on = false
	if why == "hedge":
		_spark(sh.pos, ["#b2f2bb", "#2f9e44"], 18, 0.7)
		Audio.play("thud", 1.3)
	elif why == "wall":
		_spark(sh.pos, ["#e9ecef", "#868e96"], 16, 0.7)
		Audio.play("thud", 1.1)


func _impact(sh: Dictionary, v: Dictionary, rel: Vector3) -> void:
	var shooter: Dictionary = pl[sh.owner]
	sh.on = false
	var rear: bool = rel.normalized().dot(v.hd) < REAR_DOT
	if rear and v.inv <= 0.0:
		v.hp -= 1
		v.inv = INVULN
		v.hit_t = t
		shooter.hits += 1
		shooter.dmg += 1
		shake = max(shake, 0.12)
		_spark(sh.pos, ["#ffffff", "#ff6b00"], 34, 1.2)
		Audio.play("hit")
		Audio.play("pop", 0.8)
		var sp := screen(v.pos + Vector3(0, 1.0, 0))
		Main.I.burst(sp.x, sp.y, {"n": 22, "colors": ["#ffd43b", "#ff6b00", "#ffffff", (v.col as Color).to_html()], "speed": 260, "size": 7})
		Main.I.float_text(sp.x, sp.y - 30, "TALÁLAT!", Color("#ffd43b"), 30)
		(v.m as Chars3D.CharModel).emote("dizzy")
		if v.hp <= 0:
			_eliminate(v)
	else:
		# a páncélról lepattan
		v.bump_t = t
		_spark(sh.pos, ["#ffffff", "#adb5bd"], 14, 0.8)
		Audio.play("clank", FX.fr(0.9, 1.15))


func _eliminate(v: Dictionary) -> void:
	v.alive = false
	v.hp = 0
	v.out_t = t
	out_order.append(v.i)
	shake = max(shake, 0.3)
	Audio.play("boom")
	_spark(v.pos + Vector3(0, 0.6, 0), ["#ffe066", "#ff4d00"], 40, 1.8)
	var sp := screen(v.pos + Vector3(0, 0.8, 0))
	Main.I.burst(sp.x, sp.y, {"n": 46, "colors": ["#ffd43b", "#ff6b00", "#495057", "#ffffff"], "speed": 420, "size": 10})
	_say("💥 %s kiesett!" % v.p.name, Color("#ff8787"), 1.4)
	if not v.cpu:
		Net.set_ctrl(v.p.pid, {"mode": "wait", "icon": "💥", "title": "Kiestél!", "text": "Nézd, ki bírja tovább!"})
	print_verbose("[mg] sínharc: %s kiesett %.1f mp-nél" % [v.p.name, t])


func _bumps() -> void:
	for v in pl:
		if not v.alive:
			continue
		for o in pl:
			if o == v or not o.alive:
				continue
			var rel: Vector3 = o.pos - (v.pos as Vector3)
			if rel.length() < VEH_R * 1.9 and rel.normalized().dot(v.hd) > 0.2 and t - v.rev_t > 0.35:
				_reverse(v)
				_place(v)
				v.bump_t = t
				Audio.play("thud")
				shake = max(shake, 0.05)


# ------------------------------------------------------------------ játékmenet
func update(dt: float) -> void:
	for s in pl:
		if s.cpu:
			_ai(s, dt)
	if not over:
		for s in pl:
			s.cd = max(0.0, s.cd - dt)
			s.inv = max(0.0, s.inv - dt)
			if s.alive:
				_move(s, dt)
		_bumps()
		_shots_step(dt)
		if LIMIT - t <= 5.0 and ceili(LIMIT - t) != ceili(LIMIT - t + dt):
			Audio.play("tick")
	_check_end()
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _check_end() -> void:
	if over:
		if t >= end_at:
			finished = true
		return
	var alive := pl.filter(func(x): return x.alive)
	if (pl.size() > 1 and alive.size() <= 1) or t >= LIMIT:
		over = true
		end_at = t + 4.2
		for sh in shots:
			sh.on = false
		var idx: Array = range(pl.size())
		idx.sort_custom(func(a, b): return _score(pl[a]) > _score(pl[b]))
		for k in idx.size():
			places[idx[k]] = k
		var w: Dictionary = pl[idx[0]]
		_say("🏆 %s nyert!" % w.p.name, Color("#ffd43b"), 3.6)
		Audio.play("fanfare")
		(w.m as Chars3D.CharModel).emote("cheer")
		if not preview:
			Main.I.confetti(130)
		for s in pl:
			if not s.cpu:
				Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏁", "title": "Vége!", "text": "%d. hely" % (places[s.i] + 1)})
		print_verbose("[mg] sínharc vége %.1f mp-nél, talpon: %d | %s" % [t, alive.size(),
			", ".join(pl.map(func(x): return "%s(%s) %d❤ %d találat %d lövés" % [x.p.name, K.LEVEL_NAME[x.lvl], x.hp, x.hits, x.shots]))])


func _score(s: Dictionary) -> float:
	if s.alive:
		return 100000.0 + s.hp * 1000.0 + s.hits * 10.0 + s.dmg
	return s.out_t * 100.0 + s.hits


func ranking() -> Array:
	var out: Array = []
	for s in pl:
		if s.cpu:
			continue
		var lab := "%d ❤ · %d találat" % [s.hp, s.hits] if s.alive else "kiesett (%.0f mp) · %d találat" % [s.out_t, s.hits]
		out.append({"pid": s.p.pid, "score": _score(s), "label": lab})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func _say(text: String, col: Color, dur: float) -> void:
	msg_text = text
	msg_col = col
	msg_t0 = t
	msg_dur = dur


# ------------------------------------------------------------------ látvány
func _sync(dt: float) -> void:
	for s in pl:
		_animate_vehicle(s, dt)
	for sh in shots:
		var n: Node3D = sh.n
		n.visible = sh.on
		for k in sh.ghosts.size():
			var gh: Node3D = sh.ghosts[k]
			gh.visible = sh.on
			if sh.on:
				gh.position = sh.pos - sh.vel * (0.022 * (k + 1))
		if sh.on:
			n.position = sh.pos
			var pulse := 1.0 + 0.15 * sin(t * 40.0)
			n.scale = Vector3.ONE * pulse
	shake = max(0.0, shake - dt * 0.6)
	if cam:
		cam.position = cam_base + Vector3(FX.fr(-1, 1), FX.fr(-1, 1), 0) * shake


func _animate_vehicle(s: Dictionary, dt: float) -> void:
	var root: Node3D = s.root
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var tt: float = m.t
	var yaw := atan2((s.hd as Vector3).x, (s.hd as Vector3).z)
	s.vis_yaw = lerp_angle(float(s.vis_yaw), yaw, 1.0 - exp(-14.0 * dt))
	var hk: float = t - s.hit_t
	var bk: float = t - s.bump_t
	var jitter := Vector3.ZERO
	if hk >= 0.0 and hk < 0.45:
		jitter = Vector3(sin(hk * 70.0), 0, cos(hk * 63.0)) * 0.08 * (1.0 - hk / 0.45)
	elif bk >= 0.0 and bk < 0.3:
		jitter = Vector3(sin(bk * 60.0), 0, 0) * 0.04 * (1.0 - bk / 0.3)
	var moving: bool = s.alive and not over
	root.position = s.pos + jitter
	root.rotation = Vector3(0, s.vis_yaw, 0)
	var body: Node3D = s.body
	var bounce: float = 0.025 * abs(sin(tt * 13.0 + s.i)) if moving else 0.0
	body.position = Vector3(0, bounce, 0)
	body.rotation = Vector3(0.04 * sin(tt * 9.0) if moving else 0.0, 0, 0.03 * sin(tt * 7.0 + 1.0) if moving else 0.0)
	for w in s.wheels:
		if moving:
			(w as Node3D).rotation.x += SPEED * dt / 0.1
	# villogás találatkor; a kiesett kocsi kormos
	var paint: StandardMaterial3D = s.paint
	if s.alive and s.inv > 0.0 and fmod(t, 0.12) < 0.06:
		paint.emission_enabled = true
		paint.emission = Color.WHITE
		paint.emission_energy_multiplier = 1.2
	else:
		paint.emission_enabled = false
	if not s.alive:
		paint.albedo_color = (s.col as Color).darkened(0.55)
	# figura: kiesésnél felrepül, pörög, visszahuppan, szédül
	var tub: Node3D = s.tub
	if not s.alive:
		var ok: float = t - s.out_t
		var up: float = max(0.0, 2.6 * ok - 6.0 * ok * ok) if ok < 0.45 else 0.0
		m.position = Vector3(0, 0.02 + up, -0.05)
		m.rotation = Vector3(0, ok * 14.0 if ok < 0.45 else sin(tt * 3.0) * 0.4, sin(tt * 5.0) * 0.2)
		for k in s.stars.size():
			var st: Node3D = s.stars[k]
			st.visible = ok > 0.45
			var ang: float = tt * 4.0 + TAU * k / 3.0
			st.position = Vector3(cos(ang) * 0.35, 1.05, sin(ang) * 0.35)
	else:
		var win: bool = over and places.get(s.i, 9) == 0
		m.position = Vector3(0, 0.02 + (a.y * 0.35 if win else 0.0), -0.05)
		m.rotation = Vector3(-0.06 if moving else 0.0, a.spin if win else 0.0, a.tilt)
	tub.rotation = Vector3.ZERO
	# kezek a kormányon; lövéskor az egyik előrelendül, győzelemkor a magasba
	var place: int = places.get(s.i, -1)
	for arm in s.arms:
		var side: float = arm.side
		var target: Vector3
		if over and place == 0:
			target = Vector3(side * 0.42, 1.2 + sin(tt * 10.0 + side) * 0.08, 0.1)
		elif not s.alive:
			target = Vector3(side * (0.55 + 0.1 * sin(tt * 9.0 + side)), 0.8 + 0.2 * sin(tt * 7.0 + side * 2.0), 0.15)
		elif over and place == pl.size() - 1:
			target = Vector3(side * 0.3, 0.2, 0.25)
		else:
			var fk: float = t - s.fire_t
			var punch: float = (1.0 - fk / 0.2) * 0.12 if fk >= 0.0 and fk < 0.2 and side > 0 else 0.0
			target = Vector3(side * 0.13, 0.42, 0.33 + punch)
		K.arm_to(arm, target, Vector3(0.45, -0.8, -0.1))
	var face: Dictionary = s.face
	if not s.alive:
		K.set_face(m, face, 0.7, 1.25, 0.8)
	elif hk >= 0.0 and hk < 0.8:
		K.set_face(m, face, 0.9, 1.3, 1.0)
	elif over:
		if place == 0:
			K.set_face(m, face, 0.8, 1.1, 0.6)
		else:
			K.set_face(m, face, 0.15, 0.9, -0.7)
	else:
		var fk2: float = t - s.fire_t
		K.set_face(m, face, 0.35 if fk2 < 0.3 else 0.0, 1.0, -0.5 if fk2 < 0.3 else -0.2)


func draw(c: CanvasItem) -> void:
	# a választott irány nyila a következő kereszteződésnél
	for s in pl:
		if not s.alive or over:
			continue
		var nx: int = s.next if s.next >= 0 else s.pending
		if nx < 0:
			continue
		var node: Vector3 = nodes[s.b]
		var d := _dir(s.b, nx)
		var p0 := screen(node + d * 0.45 + Vector3(0, 0.15, 0))
		var p1 := screen(node + d * 1.35 + Vector3(0, 0.15, 0))
		var col: Color = s.col
		var dv := (p1 - p0)
		if dv.length() < 2.0:
			continue
		var n := dv.normalized()
		var perp := Vector2(-n.y, n.x)
		c.draw_line(p0, p1 - n * 8, Color(D.DARK, 0.7), 9.0)
		c.draw_line(p0, p1 - n * 8, col, 5.0)
		c.draw_colored_polygon(PackedVector2Array([p1 + n * 6, p1 - n * 12 + perp * 11, p1 - n * 12 - perp * 11]), col)
	# életerő a kocsik fölött
	for s in pl:
		var sp := screen(s.pos + Vector3(0, 1.95, 0))
		if s.alive:
			for k in HP:
				var on: bool = k < s.hp
				D.text(c, "❤" if on else "♡", sp.x + (k - 1) * 20, sp.y, {"size": 20, "color": Color("#ff4d6d") if on else Color(1, 1, 1, 0.5), "stroke": D.DARK, "sw": 4})
		if over and places.has(s.i):
			var k: float = (t - (end_at - 4.2) - 0.5 - (pl.size() - 1 - places[s.i]) * 0.22) * 2.5
			K.place_label(c, places[s.i], sp.x, sp.y - 40, k, 54)
	K.silver_timer(c, LIMIT - t if not over else max(0.0, LIMIT - (end_at - 4.2)), 640, 42, 10.0, t)
	_draw_hud(c)
	var mk := t - msg_t0
	K.banner(c, msg_text, mk, msg_dur, 150, msg_col, 60)


func _draw_hud(c: CanvasItem) -> void:
	var n := pl.size()
	var gap := 12.0
	var w: float = minf(236.0, (1250.0 - (n - 1) * gap) / n)
	var x0 := 640.0 - (n * w + (n - 1) * gap) / 2.0
	for s in pl:
		var x: float = x0 + s.i * (w + gap)
		var col: Color = s.col
		var hk: float = t - s.hit_t
		var dy: float = sin(hk * 40.0) * 4.0 * (1.0 - hk / 0.4) if hk >= 0.0 and hk < 0.4 else 0.0
		D.panel(c, x, 652 + dy, w, 58, {"r": 18, "fill": Color(0.05, 0.06, 0.15, 0.85) if s.alive else Color(0.2, 0.05, 0.05, 0.85), "stroke": col, "lw": 4.0})
		D.panel(c, x + 6, 657 + dy, w - 12, 18, {"r": 9, "fill": Color(1, 1, 1, 0.1), "stroke": null, "shadow": false})
		D.char_image(c, s.p.char_id, x + 30, 681 + dy, 44)
		var name: String = s.p.name
		if s.cpu or s.p.is_bot:
			name += " · " + K.LEVEL_NAME[s.lvl]
		D.text(c, name, x + 58, 668 + dy, {"size": 15, "align": "left", "maxw": w - 66})
		if s.alive:
			for k in HP:
				D.text(c, "❤" if k < s.hp else "♡", x + 66 + k * 22, 693 + dy, {"size": 19, "color": Color("#ff4d6d") if k < s.hp else Color(1, 1, 1, 0.35)})
		else:
			D.text(c, "💥 kiesett", x + 100, 693 + dy, {"size": 17, "color": Color("#ffa8a8")})
		D.text(c, "🎯 %d" % s.hits, x + w - 14, 693 + dy, {"size": 18, "align": "right", "color": Color("#ffe066")})
