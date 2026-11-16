extends RefCounted
## Az Ajándéktorony minijáték díszlete és kellékei: városi tér, ajándékdobozok, teherautó, biciklis.
## Csak építő és mozgató függvények; a játéklogika az mg_presents.gd-ben van.
## Minden itt épített dolog díszlet: nincs ütközése, a játékmenetre nem hat.

# ------------------------------------------------------------------ minták (kódból festett textúrák)
static var _tex := {}
static var _tmats := {}


static func _texel(kind: String, x: int, y: int) -> Color:
	match kind:
		"tri":      # piros papír, világosabb háromszögekkel
			var row := y / 32
			var u := (x + row * 16) % 32
			var v := y % 32
			if v > 6 and v < 27 and abs(u - 16) < (v - 6) * 0.55:
				return Color("#ff8787")
			return Color("#e32636")
		"dots":     # korallrózsaszín, fehér pöttyökkel
			var row := y / 16
			var u := (x + (row % 2) * 8) % 16
			var v := y % 16
			if Vector2(u - 8, v - 8).length() < 3.6:
				return Color("#ffffff")
			return Color("#ff7a85")
		"rings":    # sötétkék, körmintával
			var d := Vector2(x % 32 - 16, y % 32 - 16).length()
			if d > 8.0 and d < 11.5:
				return Color("#4dabf7")
			if d < 3.5:
				return Color("#a5d8ff")
			return Color("#1b3a9c")
		"rainbow":  # szivárványcsíkos szalag
			return Color(["#ff4d4d", "#ff922b", "#ffd43b", "#51cf66", "#339af0", "#b05cf0"][(y * 6 / 64) % 6])
		"multi":    # ferde, sokszínű csíkok
			return Color(["#ffd43b", "#4dabf7", "#ff6b9d", "#51cf66"][((x + y) / 8) % 4])
		"diamond":  # rózsaszín-zöld rombuszok
			if abs(x % 16 - 8) + abs(y % 16 - 8) < 7:
				return Color("#ff6b9d")
			return Color("#40c057")
		"candy":    # fehér szalag rózsaszín csíkokkal
			return Color("#ffffff") if ((x + y) / 8) % 2 == 0 else Color("#ff8fab")
	return Color.WHITE


static func texture(kind: String) -> ImageTexture:
	if not _tex.has(kind):
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				img.set_pixel(x, y, _texel(kind, x, y))
		img.generate_mipmaps()
		_tex[kind] = ImageTexture.create_from_image(img)
	return _tex[kind]


## Mintás anyag: a minta a doboz saját terében ismétlődik (triplanar), így minden lapon ép.
static func tmat(kind: String, rep := 2.0, rough := 0.45) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [kind, rep, rough]
	if not _tmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture(kind)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * rep
		m.roughness = rough
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_tmats[key] = m
	return _tmats[key]


## Henger/doboz kifeszítése két pont közé (a háló 1 egység magas, az Y tengelye mentén áll).
static func place_seg(mi: Node3D, a: Vector3, b: Vector3, thick := 1.0) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.0001:
		return
	var y := d / ln
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x * thick, y * ln, z * thick), (a + b) * 0.5)


static func seg_mesh(r: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 1.0
	c.radial_segments = seg
	c.rings = 1
	return c


static func seg(parent: Node3D, r: float, m: Material, a := Vector3.ZERO, b := Vector3.UP) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = seg_mesh(r)
	mi.material_override = m
	parent.add_child(mi)
	place_seg(mi, a, b)
	return mi


# ------------------------------------------------------------------ ajándékdobozok
const GIFTS := [
	{"id": "red", "body": "tri", "ribbon": "gold", "cross": true, "bow": 1.5},
	{"id": "orange", "hex": "#ff8a1f", "ribbon": "multi", "cross": false, "bow": 1.0},
	{"id": "green", "hex": "#35c94a", "ribbon": "rainbow", "cross": true, "bow": 1.0},
	{"id": "purple", "hex": "#8b3fd9", "ribbon": "rainbow", "cross": false, "bow": 1.0},
	{"id": "blue", "body": "rings", "ribbon": "diamond", "cross": true, "bow": 1.0},
	{"id": "pink", "body": "dots", "ribbon": "candy", "cross": false, "bow": 1.0},
]


## Egy ajándék: a csomópont közepe a doboz közepe. Vissza: {node, bow, w, h}
static func gift(type: int, w: float, h: float) -> Dictionary:
	var def: Dictionary = GIFTS[type % GIFTS.size()]
	var g := Node3D.new()
	var body: Material = tmat(def.body, 2.0 / w * 0.9) if def.has("body") else Chars3D.mat(def.hex, {"rough": 0.42})
	var rib: Material
	if def.ribbon == "gold":
		rib = Chars3D.mat("#f7c531", {"rough": 0.25, "metal": 0.75})
	else:
		rib = tmat(def.ribbon, 3.0, 0.35)
	Chars3D.box(g, w, h, w, body, Vector3.ZERO)
	# fedél: kicsit kilóg, ettől lágyabb a doboz sziluettje
	var lid_h := h * 0.2
	Chars3D.box(g, w + 0.06, lid_h, w + 0.06, body, Vector3(0, h / 2 - lid_h / 2 + 0.012, 0))
	Chars3D.box(g, w + 0.075, 0.025, w + 0.075, Chars3D.mat("#ffffff", {"alpha": 0.22, "rough": 0.2}), Vector3(0, h / 2 + 0.012, 0))
	# szalag: függőleges pánt, a keresztszalagos dobozokon egy öv is
	var rw := w * 0.17
	Chars3D.box(g, rw, h + 0.035, w + 0.085, rib, Vector3(0, 0.006, 0))
	Chars3D.box(g, w + 0.085, h + 0.035, rw, rib, Vector3(0, 0.006, 0))
	if def.cross:
		Chars3D.box(g, w + 0.03, rw * 0.8, w + 0.03, rib, Vector3(0, -h * 0.12, 0))
	# masni (csak a legfelső dobozon látszik)
	var bow := Chars3D.grp(g, Vector3(0, h / 2 + 0.03, 0))
	var bs: float = def.bow * w
	for s in [-1, 1]:
		Chars3D.sphere(bow, 0.2, rib, s * 0.19 * bs, 0.09 * bs, 0, 1.0 * bs, 0.62 * bs, 0.55 * bs).rotation.z = s * 0.45
		Chars3D.box(bow, 0.26 * bs, 0.02, 0.1 * bs, rib, Vector3(s * 0.2 * bs, 0.005, 0.16 * bs), Vector3(0, s * 0.5, 0))
	Chars3D.sphere(bow, 0.085 * bs, rib, 0, 0.08 * bs, 0)
	return {"node": g, "bow": bow, "w": w, "h": h}


# ------------------------------------------------------------------ városi tér
static func _building(root: Node3D, x: float, z: float, w: float, h: float, d: float, wall_hex: String, o := {}) -> Node3D:
	var g := Chars3D.grp(root, Vector3(x, 0, z), Vector3(0, o.get("rot", 0.0), 0))
	var wall := Chars3D.mat(wall_hex, {"rough": 0.85})
	var stone := Chars3D.mat("#cdc7ba", {"rough": 0.9})
	var roof := Chars3D.mat("#c9563a", {"rough": 0.8})
	var roof_d := Chars3D.mat("#a8432c", {"rough": 0.8})
	var frame := Chars3D.mat("#b57c28", {"rough": 0.5})
	var glass := Chars3D.mat("#6fa9d8", {"rough": 0.15, "metal": 0.25})
	var dark := Chars3D.mat("#4b3a33", {"rough": 0.95})
	var fz := d / 2
	Chars3D.box(g, w, h, d, wall, Vector3(0, h / 2, 0))
	Chars3D.box(g, w + 0.3, 0.5, d + 0.3, stone, Vector3(0, 0.25, 0))
	Chars3D.box(g, w + 0.45, 0.28, d + 0.45, stone, Vector3(0, h, 0))
	# tető: oromzat a tér felé, vagy a homlokzattal párhuzamos gerinc
	var rh: float = o.get("roof", 2.0)
	if o.get("gable", false):
		Chars3D.part(g, Chars3D.prism([[-w / 2 - 0.45, 0], [w / 2 + 0.45, 0], [0, rh]], d + 0.6), roof, Vector3(0, h + 0.14, 0))
		Chars3D.box(g, 0.25, 0.16, d + 0.7, roof_d, Vector3(0, h + 0.14 + rh, 0))
		# kerek dísz az oromzatban
		var oy := h + 0.14 + rh * 0.38
		Chars3D.cyl(g, 0.62, 0.62, 0.1, frame, 0, oy, fz + 0.3, 28, Vector3(PI / 2, 0, 0))
		Chars3D.cyl(g, 0.48, 0.48, 0.12, Chars3D.mat("#fbf8f0"), 0, oy, fz + 0.3, 28, Vector3(PI / 2, 0, 0))
		Chars3D.cyl(g, 0.18, 0.18, 0.14, roof, 0, oy, fz + 0.3, 16, Vector3(PI / 2, 0, 0))
	else:
		Chars3D.part(g, Chars3D.prism([[-d / 2 - 0.45, 0], [d / 2 + 0.45, 0], [0, rh]], w + 0.6), roof, Vector3(0, h + 0.14, 0), Vector3.ONE, Vector3(0, PI / 2, 0))
		Chars3D.box(g, w + 0.7, 0.16, 0.25, roof_d, Vector3(0, h + 0.14 + rh, 0))
	# árkádsor: boltívek oszlopokkal
	var n: int = o.get("arches", 3)
	var aw := w / n
	var ah: float = o.get("arch_h", 2.3)
	var ar := aw * 0.3
	for i in n:
		var cx := -w / 2 + aw * (i + 0.5)
		Chars3D.box(g, ar * 2, ah, 0.1, dark, Vector3(cx, ah / 2, fz + 0.01))
		Chars3D.cyl(g, ar, ar, 0.1, dark, cx, ah, fz + 0.01, 24, Vector3(PI / 2, 0, 0))
		Chars3D.part(g, Chars3D.arc_tube(ar + 0.07, 0.085, PI, 16, 6), stone, Vector3(cx, ah, fz + 0.07))
		Chars3D.box(g, 0.24, 0.3, 0.2, stone, Vector3(cx, ah + ar + 0.1, fz + 0.1))
	for i in n + 1:
		var px := -w / 2 + aw * i
		Chars3D.cyl(g, 0.15, 0.18, ah + 0.3, stone, px, (ah + 0.3) / 2, fz + 0.26, 12)
		Chars3D.box(g, 0.48, 0.16, 0.48, stone, Vector3(px, ah + 0.38, fz + 0.26))
		Chars3D.box(g, 0.48, 0.2, 0.48, stone, Vector3(px, 0.1, fz + 0.26))
	Chars3D.box(g, w + 0.2, 0.22, 0.5, stone, Vector3(0, ah + ar + 0.55, fz + 0.12))
	# emeleti ablakok aranybarna kerettel, köztük kerek díszek
	var y0 := ah + ar + 1.55
	var rows := int((h - y0 + 0.3) / 1.9) + 1
	for r in rows:
		var wy := y0 + r * 1.9
		if wy + 0.75 > h:
			break
		for i in n:
			var cx := -w / 2 + aw * (i + 0.5)
			Chars3D.box(g, 1.0, 1.3, 0.12, frame, Vector3(cx, wy, fz + 0.02))
			Chars3D.box(g, 0.78, 1.08, 0.14, glass, Vector3(cx, wy, fz + 0.03))
			Chars3D.box(g, 0.06, 1.08, 0.16, frame, Vector3(cx, wy, fz + 0.03))
			Chars3D.box(g, 0.78, 0.06, 0.16, frame, Vector3(cx, wy + 0.12, fz + 0.03))
			Chars3D.box(g, 1.2, 0.12, 0.3, stone, Vector3(cx, wy - 0.72, fz + 0.1))
		if r == 0:
			for i in n - 1:
				var ox := -w / 2 + aw * (i + 1)
				Chars3D.cyl(g, 0.24, 0.24, 0.08, frame, ox, wy + 0.1, fz + 0.03, 20, Vector3(PI / 2, 0, 0))
				Chars3D.cyl(g, 0.15, 0.15, 0.1, Chars3D.mat("#fbf8f0"), ox, wy + 0.1, fz + 0.03, 20, Vector3(PI / 2, 0, 0))
	return g


static func _tree(root: Node3D, x: float, z: float, s := 1.0) -> Node3D:
	var g := Chars3D.grp(root, Vector3(x, 0, z))
	g.scale = Vector3.ONE * s
	var pot := Chars3D.mat("#b9603f", {"rough": 0.85})
	Chars3D.box(g, 1.1, 0.7, 1.1, pot, Vector3(0, 0.35, 0))
	Chars3D.box(g, 1.25, 0.14, 1.25, Chars3D.mat("#9c4c30", {"rough": 0.85}), Vector3(0, 0.7, 0))
	Chars3D.box(g, 0.95, 0.06, 0.95, Chars3D.mat("#5a3d2b"), Vector3(0, 0.76, 0))
	Chars3D.cyl(g, 0.09, 0.13, 1.3, Chars3D.mat("#7a5230"), 0, 1.4, 0, 8)
	var crown := Chars3D.grp(g, Vector3(0, 2.0, 0))
	Chars3D.lsphere(crown, 0.75, Chars3D.mat("#3fa54a"), 0, 0.45, 0, 1, 1, 1, 10, 7)
	Chars3D.lsphere(crown, 0.52, Chars3D.mat("#57bd5c"), 0.42, 0.75, 0.15, 1, 1, 1, 8, 6)
	Chars3D.lsphere(crown, 0.5, Chars3D.mat("#2f8f3e"), -0.42, 0.3, -0.1, 1, 1, 1, 8, 6)
	Chars3D.lsphere(crown, 0.42, Chars3D.mat("#6fce6a"), -0.1, 1.05, 0.05, 1, 1, 1, 8, 6)
	return crown


## A tér felépítése. Vissza a széllel mozgó részek: {flags, banners, trees, clouds}
static func build_town(root: Node3D, road_z: float) -> Dictionary:
	var out := {"flags": [], "banners": [], "trees": [], "clouds": []}
	# burkolat: krémszínű kőlapok halvány fugákkal
	Chars3D.box(root, 110, 1.0, 70, Chars3D.mat("#efe3c6", {"rough": 0.9}), Vector3(0, -0.5, -8))
	var line := Chars3D.mat("#dccdaa", {"rough": 0.95})
	for i in 9:
		Chars3D.box(root, 110, 0.012, 0.07, line, Vector3(0, 0.004, -7.5 + i * 2.5))
	for i in 23:
		Chars3D.box(root, 0.07, 0.012, 28, line, Vector3(-27.5 + i * 2.5, 0.004, 1))
	# a tér előtt futó út (itt jár a teherautó és a biciklis)
	Chars3D.box(root, 110, 0.02, 4.6, Chars3D.mat("#c9c2b3", {"rough": 0.95}), Vector3(0, 0.006, road_z))
	Chars3D.box(root, 110, 0.03, 0.18, Chars3D.mat("#fbf8f0"), Vector3(0, 0.012, road_z - 2.4))
	# házak
	_building(root, 0, -11.5, 12.0, 6.6, 6.0, "#f7f4ea", {"gable": true, "arches": 4, "roof": 2.4})
	_building(root, -12.6, -11.0, 10.0, 5.6, 6.0, "#e6e4dd", {"arches": 3, "roof": 1.9})
	_building(root, 12.9, -11.0, 10.4, 6.0, 6.0, "#f2eee2", {"arches": 3, "roof": 2.0})
	_building(root, -24.0, -6.0, 10.0, 6.4, 6.0, "#ecebe5", {"gable": true, "arches": 3, "rot": 0.55, "roof": 2.2})
	_building(root, 24.4, -6.0, 10.0, 6.2, 6.0, "#f7f4ea", {"gable": true, "arches": 3, "rot": -0.55, "roof": 2.2})
	# két torony a háztetők mögött
	for td in [[-6.6, -19.0, 10.5, "#e6e4dd"], [7.2, -20.0, 9.4, "#f2eee2"]]:
		var tw := Chars3D.grp(root, Vector3(td[0], 0, td[1]))
		Chars3D.box(tw, 3.4, td[2], 3.4, Chars3D.mat(td[3], {"rough": 0.85}), Vector3(0, td[2] / 2.0, 0))
		Chars3D.box(tw, 3.8, 0.3, 3.8, Chars3D.mat("#cdc7ba"), Vector3(0, td[2], 0))
		Chars3D.cone(tw, 2.7, 2.6, Chars3D.mat("#c9563a", {"rough": 0.8}), 0, td[2] + 1.4, 0, 4, Vector3(0, PI / 4, 0))
		Chars3D.box(tw, 0.9, 1.4, 0.1, Chars3D.mat("#4b3a33"), Vector3(0, td[2] - 1.5, 1.71))
		Chars3D.cyl(tw, 0.45, 0.45, 0.1, Chars3D.mat("#4b3a33"), 0, td[2] - 0.8, 1.71, 20, Vector3(PI / 2, 0, 0))
	# szökőkút a tér közepén
	var f := Chars3D.grp(root, Vector3(0, 0, -5.2))
	var st := Chars3D.mat("#d6d0c3", {"rough": 0.8})
	Chars3D.cyl(f, 2.1, 2.25, 0.55, st, 0, 0.275, 0, 28)
	Chars3D.cyl(f, 1.85, 1.85, 0.57, Chars3D.mat("#5cc0ee", {"rough": 0.1, "metal": 0.2}), 0, 0.28, 0, 28)
	Chars3D.cyl(f, 0.22, 0.3, 1.5, st, 0, 1.0, 0, 12)
	Chars3D.cyl(f, 0.95, 0.3, 0.3, st, 0, 1.85, 0, 20)
	Chars3D.cyl(f, 0.85, 0.85, 0.06, Chars3D.mat("#5cc0ee", {"rough": 0.1}), 0, 1.99, 0, 20)
	Chars3D.sphere(f, 0.28, st, 0, 2.3, 0)
	# cserepes fák
	for td in [[-7.4, -3.6, 1.0], [7.4, -3.6, 1.0], [-13.5, -1.6, 1.15], [13.5, -1.6, 1.15], [-18.5, -6.5, 1.0], [18.5, -6.5, 1.0]]:
		out.trees.append(_tree(root, td[0], td[1], td[2]))
	# zászlófüzérek a házak között
	var cols := ["#ff4d6d", "#ffd43b", "#4dabf7", "#51cf66", "#ff922b", "#b05cf0"]
	var rope := Chars3D.mat("#6b5a4a")
	for sd in [[Vector3(-10.5, 5.2, -7.6), Vector3(10.5, 5.5, -7.6), 1.0, 15], [Vector3(-17.5, 4.6, -4.5), Vector3(-5.5, 5.9, -8.4), 0.7, 9], [Vector3(17.5, 4.6, -4.5), Vector3(5.5, 5.9, -8.4), 0.7, 9]]:
		var a: Vector3 = sd[0]
		var b: Vector3 = sd[1]
		var cnt: int = sd[3]
		var prev := a
		for i in range(1, cnt + 2):
			var k := float(i) / (cnt + 1)
			var p := a.lerp(b, k) - Vector3(0, sin(k * PI) * sd[2], 0)
			seg(root, 0.018, rope, prev, p)
			prev = p
			if i <= cnt:
				var fl := Chars3D.grp(root, p)
				fl.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
				Chars3D.part(fl, Chars3D.prism([[-0.24, 0], [0.24, 0], [0, -0.6]], 0.02), Chars3D.mat(cols[i % cols.size()], {"rough": 0.7}))
				out.flags.append(fl)
	# hosszú, lelógó zászlók a középső ház homlokzatán
	for bd in [[-4.5, "#e03131"], [-1.5, "#1c7ed6"], [1.5, "#f59f00"], [4.5, "#2f9e44"]]:
		var bn := Chars3D.grp(root, Vector3(bd[0], 6.1, -8.28))
		Chars3D.box(root, 1.0, 0.07, 0.07, Chars3D.mat("#6b5a4a"), Vector3(bd[0], 6.12, -8.28))
		Chars3D.box(bn, 0.72, 2.1, 0.03, Chars3D.mat(bd[1], {"rough": 0.7}), Vector3(0, -1.05, 0))
		Chars3D.box(bn, 0.72, 0.16, 0.035, Chars3D.mat("#ffd43b", {"rough": 0.4}), Vector3(0, -1.9, 0))
		Chars3D.part(bn, Chars3D.prism([[-0.36, 0], [0.36, 0], [0, -0.4]], 0.03), Chars3D.mat(bd[1], {"rough": 0.7}), Vector3(0, -2.1, 0))
		out.banners.append(bn)
	# nagy fehér felhők
	var white := Chars3D.mat("#ffffff", {"rough": 1.0})
	var rnd := BoardLayout.Seeded.new(11)
	for i in 8:
		var cg := Chars3D.grp(root, Vector3(-42 + i * 12.0 + rnd.next() * 5.0, 15.5 + rnd.next() * 8.0, -42 - rnd.next() * 8.0))
		for k in 4:
			Chars3D.sphere(cg, 2.2 + rnd.next() * 1.4, white, (k - 1.5) * 2.6, rnd.next() * 1.0, rnd.next(), 1, 0.62, 0.8)
		out.clouds.append(cg)
	return out


# ------------------------------------------------------------------ teherautó
## Színes, kerekded áruszállító. Az orra a +X felé néz; hossza kb. 9,6 egység. Vissza: {node, wheels}
static func build_truck(root: Node3D) -> Dictionary:
	var g := Node3D.new()
	root.add_child(g)
	var teal := Chars3D.mat("#12b5a5", {"rough": 0.35})
	var teal_d := Chars3D.mat("#0c8f83", {"rough": 0.4})
	var cream := Chars3D.mat("#fff3d6", {"rough": 0.4})
	var yellow := Chars3D.mat("#ffc93c", {"rough": 0.3})
	var dark := Chars3D.mat("#2b2d42", {"rough": 0.6})
	var glass := Chars3D.mat("#9bd5f5", {"rough": 0.1, "metal": 0.3})
	var red := Chars3D.mat("#ff5d5d", {"rough": 0.35})
	Chars3D.box(g, 9.0, 0.32, 2.0, dark, Vector3(0.3, 0.8, 0))
	# rakodótér lekerekített tetővel
	Chars3D.box(g, 6.3, 2.25, 2.3, teal, Vector3(-1.25, 2.05, 0))
	Chars3D.cyl(g, 1.15, 1.15, 6.3, teal_d, -1.25, 3.17, 0, 20, Vector3(0, 0, PI / 2)).scale = Vector3(0.36, 1, 1)
	Chars3D.box(g, 6.32, 0.4, 2.32, cream, Vector3(-1.25, 1.5, 0))
	Chars3D.box(g, 6.32, 0.12, 2.32, yellow, Vector3(-1.25, 1.2, 0))
	for sz in [-1, 1]:
		# embléma: masnis csomag egy fehér korongon
		Chars3D.cyl(g, 0.72, 0.72, 0.04, cream, -1.25, 2.4, sz * 1.16, 28, Vector3(PI / 2, 0, 0))
		Chars3D.box(g, 0.66, 0.56, 0.05, red, Vector3(-1.25, 2.32, sz * 1.17))
		Chars3D.box(g, 0.14, 0.58, 0.06, yellow, Vector3(-1.25, 2.32, sz * 1.175))
		Chars3D.box(g, 0.68, 0.12, 0.06, yellow, Vector3(-1.25, 2.4, sz * 1.175))
		Chars3D.sphere(g, 0.14, yellow, -1.39, 2.68, sz * 1.17, 1, 0.7, 0.3)
		Chars3D.sphere(g, 0.14, yellow, -1.11, 2.68, sz * 1.17, 1, 0.7, 0.3)
	# vezetőfülke és motorház, gömbölyített sarkokkal
	Chars3D.box(g, 2.0, 1.75, 2.2, yellow, Vector3(3.1, 1.8, 0))
	Chars3D.sphere(g, 1.0, yellow, 3.1, 2.62, 0, 1.0, 0.42, 1.1)
	Chars3D.box(g, 1.0, 0.95, 2.2, yellow, Vector3(4.4, 1.42, 0))
	Chars3D.sphere(g, 0.6, yellow, 4.6, 1.5, 0, 0.75, 0.75, 1.82)
	Chars3D.box(g, 0.1, 0.75, 1.8, glass, Vector3(4.07, 2.25, 0))
	for sz in [-1, 1]:
		Chars3D.box(g, 1.15, 0.72, 0.06, glass, Vector3(3.2, 2.2, sz * 1.1))
		Chars3D.box(g, 1.5, 0.1, 0.07, cream, Vector3(3.2, 1.7, sz * 1.1))
		Chars3D.sphere(g, 0.17, Chars3D.mat("#fff7c2", {"emit": "#fff3a0", "emit_e": 1.5}), 4.95, 1.42, sz * 0.75, 0.5, 1, 1)
		Chars3D.box(g, 0.25, 0.3, 0.08, red, Vector3(2.4, 2.6, sz * 1.22))
	Chars3D.box(g, 0.28, 0.3, 2.4, Chars3D.mat("#adb5bd", {"rough": 0.3, "metal": 0.6}), Vector3(5.0, 0.85, 0))
	Chars3D.box(g, 0.16, 0.42, 1.2, dark, Vector3(4.98, 1.42, 0))
	# túlméretezett kerekek
	var wheels: Array = []
	for wx in [3.75, -1.9, -3.55]:
		for sz in [-1, 1]:
			var w := Chars3D.grp(g, Vector3(wx, 0.72, sz * 0.98))
			Chars3D.cyl(w, 0.72, 0.72, 0.5, dark, 0, 0, 0, 24, Vector3(PI / 2, 0, 0))
			Chars3D.cyl(w, 0.4, 0.4, 0.54, cream, 0, 0, 0, 20, Vector3(PI / 2, 0, 0))
			Chars3D.cyl(w, 0.14, 0.14, 0.6, yellow, 0, 0, 0, 12, Vector3(PI / 2, 0, 0))
			for k in 5:
				var a := TAU * k / 5.0
				Chars3D.sphere(w, 0.07, red, cos(a) * 0.27, sin(a) * 0.27, sz * 0.27)
			wheels.append(w)
		Chars3D.box(g, 1.9, 0.14, 2.36, teal_d if wx < 0 else yellow, Vector3(wx, 1.52, 0))
	g.visible = false
	return {"node": g, "wheels": wheels, "r": 0.72}


# ------------------------------------------------------------------ biciklis
const BB := Vector3(-0.04, 0.42, 0)      # középcsapágy
const CRANK := 0.17

## Saját rajzfilmfigura színes biciklin, a +X felé halad. A lábait az animate_cyclist() hajtja.
static func build_cyclist(root: Node3D) -> Dictionary:
	var g := Node3D.new()
	root.add_child(g)
	var paint := Chars3D.mat("#ff4d8d", {"rough": 0.3, "metal": 0.3})
	var steel := Chars3D.mat("#ced4da", {"rough": 0.3, "metal": 0.7})
	var tire := Chars3D.mat("#2b2d42", {"rough": 0.7})
	var jersey := Chars3D.mat("#ffd43b", {"rough": 0.6})
	var shorts := Chars3D.mat("#364fc7", {"rough": 0.6})
	var skin := Chars3D.mat("#f2c29b", {"rough": 0.6})
	var r := 0.42
	var rear := Vector3(-0.64, r, 0)
	var front := Vector3(0.66, r, 0)
	var seat := Vector3(-0.3, 1.0, 0)
	var head_t := Vector3(0.46, 0.98, 0)
	var bar := Vector3(0.52, 1.16, 0)
	for pr in [[BB, seat], [BB, head_t - Vector3(0.03, 0.12, 0)], [seat - Vector3(0, 0.1, 0), head_t], [rear, BB], [rear, seat - Vector3(0, 0.08, 0)]]:
		seg(g, 0.03, paint, pr[0], pr[1])
	seg(g, 0.026, steel, head_t - Vector3(0.03, 0.14, 0), front)
	seg(g, 0.026, steel, head_t, bar)
	seg(g, 0.024, steel, bar + Vector3(0, 0, -0.24), bar + Vector3(0, 0, 0.24))
	Chars3D.sphere(g, 0.1, tire, seat.x, seat.y + 0.05, 0, 1.5, 0.45, 0.9)
	Chars3D.sphere(g, 0.05, Chars3D.mat("#ffd43b", {"metal": 0.8, "rough": 0.2}), bar.x - 0.02, bar.y + 0.05, 0.14)   # csengő
	var wheels: Array = []
	for c in [rear, front]:
		var w := Chars3D.grp(g, c)
		var tm := MeshInstance3D.new()
		tm.mesh = Chars3D.torus(r - 0.04, 0.04)
		tm.material_override = tire
		tm.rotation.x = PI / 2
		w.add_child(tm)
		for k in 4:
			Chars3D.box(w, (r - 0.06) * 2, 0.012, 0.012, steel, Vector3.ZERO, Vector3(0, 0, PI * k / 4.0))
		Chars3D.sphere(w, 0.045, paint)
		wheels.append(w)
	# hajtómű
	var crank := Chars3D.grp(g, BB)
	Chars3D.cyl(crank, 0.1, 0.1, 0.02, steel, 0, 0, 0.05, 16, Vector3(PI / 2, 0, 0))
	for s in [-1, 1]:
		Chars3D.box(crank, CRANK, 0.025, 0.02, steel, Vector3(s * CRANK / 2, 0, s * 0.08))
		Chars3D.box(crank, 0.1, 0.03, 0.08, tire, Vector3(s * CRANK, 0, s * 0.13))
	# bringás: előredőlő törzs, fej bukósisakkal, kéz a kormányon
	var body := Chars3D.grp(g)
	var hip := Vector3(-0.3, 1.12, 0)
	var neck := Vector3(0.1, 1.62, 0)
	seg(body, 0.17, jersey, hip, neck)
	Chars3D.sphere(body, 0.17, jersey, neck.x, neck.y, 0)
	Chars3D.sphere(body, 0.19, shorts, hip.x, hip.y, 0, 1, 0.85, 1)
	var hd := Chars3D.grp(body, Vector3(0.2, 1.86, 0))
	Chars3D.sphere(hd, 0.19, skin)
	var helm := Chars3D.part(hd, Chars3D._sphere_mesh(0.21, true), Chars3D.mat("#4dabf7", {"rough": 0.3}), Vector3(-0.01, 0.03, 0))
	helm.scale = Vector3(1.12, 1.0, 1.0)
	Chars3D.box(hd, 0.14, 0.03, 0.26, Chars3D.mat("#1c7ed6"), Vector3(0.2, 0.05, 0))
	for sz in [-1, 1]:
		Chars3D.sphere(hd, 0.035, Chars3D.mat("#1f1b2e"), 0.16, 0.0, sz * 0.085)
		seg(body, 0.05, jersey, neck + Vector3(0, -0.04, sz * 0.17), Vector3(0.32, 1.36, sz * 0.2))
		seg(body, 0.045, skin, Vector3(0.32, 1.36, sz * 0.2), bar + Vector3(0, 0.03, sz * 0.2))
		Chars3D.sphere(body, 0.06, skin, bar.x, bar.y + 0.03, sz * 0.2)
	Chars3D.sphere(hd, 0.03, skin, 0.19, -0.04, 0)
	Chars3D.part(hd, Chars3D.arc_tube(0.05, 0.012, PI, 10, 5), Chars3D.mat("#1f1b2e"), Vector3(0.17, -0.07, 0), Vector3.ONE, Vector3(0, PI / 2, PI))
	# sál, ami lobog a menetszélben
	var scarf := Chars3D.grp(body, neck + Vector3(-0.08, 0.06, 0))
	Chars3D.box(scarf, 0.5, 0.09, 0.03, Chars3D.mat("#e03131"), Vector3(-0.25, 0, 0))
	Chars3D.sphere(body, 0.13, Chars3D.mat("#e03131"), neck.x + 0.02, neck.y + 0.07, 0, 1.1, 0.5, 1.1)
	# lábak: comb + lábszár oldalanként, a pedálhoz igazítva
	var legs: Array = []
	for sz in [-1, 1]:
		legs.append({"thigh": seg(g, 0.075, shorts), "shin": seg(g, 0.06, skin), "foot": Chars3D.sphere(g, 0.07, Chars3D.mat("#f8f9fa"), 0, 0, 0, 1.6, 0.7, 1.0), "z": sz * 0.11, "hip": hip + Vector3(0.02, -0.04, sz * 0.11)})
	g.visible = false
	return {"node": g, "wheels": wheels, "crank": crank, "legs": legs, "body": body, "scarf": scarf, "r": r}


## dist: a megtett út (egységben); ebből forog a kerék és a hajtómű, ehhez igazodik a láb.
static func animate_cyclist(cy: Dictionary, dist: float) -> void:
	var r: float = cy.r
	for w in cy.wheels:
		(w as Node3D).rotation.z = -dist / r
	var ca := -dist / r * 0.45
	(cy.crank as Node3D).rotation.z = ca
	(cy.body as Node3D).position.y = sin(ca * 2.0) * 0.012
	(cy.body as Node3D).rotation.x = sin(ca) * 0.04
	(cy.scarf as Node3D).rotation.z = sin(dist * 5.0) * 0.25
	(cy.scarf as Node3D).rotation.y = sin(dist * 3.3) * 0.3
	var L1 := 0.42
	var L2 := 0.44
	for i in 2:
		var lg: Dictionary = cy.legs[i]
		var s := -1.0 if i == 0 else 1.0
		var ped := BB + Vector3(cos(ca) * CRANK * s, sin(ca) * CRANK * s + 0.04, lg.z)
		var hip: Vector3 = lg.hip
		var d := ped - hip
		var dl: float = clamp(d.length(), 0.05, L1 + L2 - 0.005)
		var dir := d.normalized()
		var a := (L1 * L1 - L2 * L2 + dl * dl) / (2.0 * dl)
		var hh: float = sqrt(max(0.0, L1 * L1 - a * a))
		var bend := Vector3(1, 0.25, 0)
		bend = (bend - dir * bend.dot(dir)).normalized()
		var knee := hip + dir * a + bend * hh
		place_seg(lg.thigh, hip, knee)
		place_seg(lg.shin, knee, hip + dir * dl)
		(lg.foot as Node3D).position = hip + dir * dl + Vector3(0.04, -0.03, 0)
