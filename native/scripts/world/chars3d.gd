class_name Chars3D
## Kódból épített 3D figurák. Minden figura kb. 1 egység magas, a talpa az origóban, a +Z felé néz.
## build(id) -> CharModel (Node3D): rig (nyújtás/lapítás), eyes (pislogás), tick (saját mozgás).

static var _mats := {}


static func mat(hex: String, o := {}) -> StandardMaterial3D:
	var key := hex + str(o)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = o.get("rough", 0.55)
	m.metallic = o.get("metal", 0.0)
	if o.has("emit"):
		m.emission_enabled = true
		m.emission = Color(o.emit)
		m.emission_energy_multiplier = o.get("emit_e", 1.0)
	if o.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = o.alpha
	if o.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static var _mesh_cache := {}


static func _sphere_mesh(r: float, hemi := false) -> SphereMesh:
	var key := "s%.3f%s" % [r, hemi]
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * (1.0 if hemi else 2.0)
		m.is_hemisphere = hemi
		m.radial_segments = 24
		m.rings = 12
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func part(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.rotation_order = EULER_ORDER_XYZ
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, sx := 1.0, sy := 1.0, sz := 1.0) -> MeshInstance3D:
	return part(parent, _sphere_mesh(r), m, Vector3(x, y, z), Vector3(sx, sy, sz))


static func cone(parent: Node3D, r: float, h: float, m: Material, x: float, y: float, z: float, seg := 16, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return part(parent, c, m, Vector3(x, y, z), Vector3.ONE, rot)


static func cyl(parent: Node3D, r1: float, r2: float, h: float, m: Material, x: float, y: float, z: float, seg := 20, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return part(parent, c, m, Vector3(x, y, z), Vector3.ONE, rot)


static func box(parent: Node3D, sx: float, sy: float, sz: float, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return part(parent, b, m, pos, Vector3.ONE, rot)


## Cső egy körív mentén (a Three.js TorusGeometry arc paraméterének megfelelője), az XY síkban.
static func arc_tube(radius: float, tube: float, arc: float, seg := 24, tseg := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		for j in tseg:
			var quad := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var u := arc * float(i + d[0]) / seg
				var v := TAU * float(j + d[1]) / tseg
				var c := Vector3(cos(u) * radius, sin(u) * radius, 0)
				var nrm := Vector3(cos(u) * cos(v), sin(u) * cos(v), sin(v))
				quad.append([c + nrm * tube, nrm])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(quad[k][1])
				st.add_vertex(quad[k][0])
	return st.commit()


static func torus(r: float, tube: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = 32
	t.ring_segments = 10
	return t


## Forgástest (Three.js LatheGeometry) – pts: [[sugár, magasság], ...]
static func lathe(pts: Array, seg := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for k in pts.size() - 1:
			var p0: Array = pts[k]
			var p1: Array = pts[k + 1]
			var v := [
				Vector3(sin(a0) * p0[0], p0[1], cos(a0) * p0[0]), Vector3(sin(a1) * p0[0], p0[1], cos(a1) * p0[0]),
				Vector3(sin(a1) * p1[0], p1[1], cos(a1) * p1[0]), Vector3(sin(a0) * p1[0], p1[1], cos(a0) * p1[0]),
			]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.add_vertex(v[idx])
	st.generate_normals()
	return st.commit()


static func eyes(parent: Node3D, y: float, z: float, dx: float, r := 0.085, pupil := 0.55, white := true) -> Array:
	var out := []
	var W := mat("#ffffff", {"rough": 0.35})
	var B := mat("#1f1b2e", {"rough": 0.3})
	for s in [-1, 1]:
		var g := Node3D.new()
		g.position = Vector3(s * dx, y, z)
		parent.add_child(g)
		if white:
			sphere(g, r, W)
		var p := sphere(g, r * pupil, B, 0, 0, r * 0.62 if white else 0.0)
		if not white:
			p.scale = Vector3(1, 1.35, 0.6)
		sphere(g, r * 0.18, W, r * 0.22, r * 0.25, r * 0.95 if white else r * 0.45)
		out.append(g)
	return out


static func cheeks(parent: Node3D, y: float, z: float, dx: float, r := 0.05) -> void:
	for s in [-1, 1]:
		sphere(parent, r, mat("#ff9fb5"), s * dx, y, z, 1, 0.6, 0.4)


static func smile(parent: Node3D, y: float, z: float, r := 0.07, m: Material = null) -> void:
	part(parent, arc_tube(r, r * 0.22, PI, 16, 6), m if m else mat("#1f1b2e", {"rough": 0.3}), Vector3(0, y, z), Vector3.ONE, Vector3(0, 0, PI))


# ------------------------------------------------------------------ low-poly segédek
## Lapos árnyékolású (szögletes) háló háromszöglistából.
## orient = true: a lapok a `center` ponttól kifelé néznek (domború formákhoz).
static func flat_mesh(v: PackedVector3Array, center := Vector3.ZERO, orient := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, v.size() - 2, 3):
		var a := v[i]
		var b := v[i + 1]
		var c := v[i + 2]
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-14:
			continue
		n = n.normalized()
		if orient and n.dot((a + b + c) / 3.0 - center) < 0.0:
			n = -n
			var tmp := b
			b = c
			c = tmp
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()


static func _lsphere_mesh(seg: int, rings: int) -> ArrayMesh:
	var key := "ls%d_%d" % [seg, rings]
	if not _mesh_cache.has(key):
		var v := PackedVector3Array()
		var pt := func(ph: float, a: float) -> Vector3:
			return Vector3(sin(ph) * sin(a), cos(ph), sin(ph) * cos(a))
		for j in rings:
			var p0 := PI * j / rings
			var p1 := PI * (j + 1) / rings
			for i in seg:
				var a0 := TAU * i / seg
				var a1 := TAU * (i + 1) / seg
				var q := [pt.call(p0, a0), pt.call(p0, a1), pt.call(p1, a1), pt.call(p1, a0)]
				v.append_array(PackedVector3Array([q[0], q[1], q[2], q[0], q[2], q[3]]))
		_mesh_cache[key] = flat_mesh(v)
	return _mesh_cache[key]


## Szögletes gömb (ellipszoid): r sugár, sx/sy/sz nyújtás.
static func lsphere(parent: Node3D, r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, sx := 1.0, sy := 1.0, sz := 1.0, seg := 10, rings := 6) -> MeshInstance3D:
	return part(parent, _lsphere_mesh(seg, rings), m, Vector3(x, y, z), Vector3(sx, sy, sz) * r)


## Szögletes henger / csonkakúp (r1 fent, r2 lent), a közepe az (x, y, z) pont.
static func lcyl(parent: Node3D, r1: float, r2: float, h: float, m: Material, x: float, y: float, z: float, seg := 8, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "lc%.3f_%.3f_%.3f_%d" % [r1, r2, h, seg]
	if not _mesh_cache.has(key):
		var v := PackedVector3Array()
		var top := Vector3(0, h / 2, 0)
		var bot := Vector3(0, -h / 2, 0)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var t0 := top + Vector3(sin(a0), 0, cos(a0)) * r1
			var t1 := top + Vector3(sin(a1), 0, cos(a1)) * r1
			var b0 := bot + Vector3(sin(a0), 0, cos(a0)) * r2
			var b1 := bot + Vector3(sin(a1), 0, cos(a1)) * r2
			v.append_array(PackedVector3Array([t0, t1, b1, t0, b1, b0, top, t0, t1, bot, b0, b1]))
		_mesh_cache[key] = flat_mesh(v)
	return part(parent, _mesh_cache[key], m, Vector3(x, y, z), Vector3.ONE, rot)


static func lcone(parent: Node3D, r: float, h: float, m: Material, x: float, y: float, z: float, seg := 6, rot := Vector3.ZERO) -> MeshInstance3D:
	return lcyl(parent, 0.0, r, h, m, x, y, z, seg, rot)


## Szögletes forgástest – pts: [[sugár, magasság], ...] alulról felfelé.
static func llathe(pts: Array, seg := 10) -> ArrayMesh:
	var v := PackedVector3Array()
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for k in pts.size() - 1:
			var p0: Array = pts[k]
			var p1: Array = pts[k + 1]
			var q := [
				Vector3(sin(a0) * p0[0], p0[1], cos(a0) * p0[0]), Vector3(sin(a1) * p0[0], p0[1], cos(a1) * p0[0]),
				Vector3(sin(a1) * p1[0], p1[1], cos(a1) * p1[0]), Vector3(sin(a0) * p1[0], p1[1], cos(a0) * p1[0]),
			]
			for idx in [0, 2, 1, 0, 3, 2]:
				v.append(q[idx])
	return flat_mesh(v, Vector3.ZERO, false)


## Domború sokszög (XY síkban, [[x, y], ...]) kihúzva d vastagságra a Z tengely mentén.
static func prism(pts: Array, d: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var c := Vector2.ZERO
	for p in pts:
		c += Vector2(p[0], p[1]) / pts.size()
	var n := pts.size()
	for i in n:
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[(i + 1) % n][0], pts[(i + 1) % n][1])
		var h := d / 2
		v.append_array(PackedVector3Array([
			Vector3(c.x, c.y, h), Vector3(a.x, a.y, h), Vector3(b.x, b.y, h),
			Vector3(c.x, c.y, -h), Vector3(a.x, a.y, -h), Vector3(b.x, b.y, -h),
			Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h),
			Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]))
	return flat_mesh(v, Vector3(c.x, c.y, 0))


## Zárt keresztmetszetek ([Vector3, ...], mind ugyanannyi pont) összekötve, a két vége lezárva.
static func loft(sections: Array, center: Vector3) -> ArrayMesh:
	var v := PackedVector3Array()
	var n: int = sections[0].size()
	for s in sections.size() - 1:
		var a: Array = sections[s]
		var b: Array = sections[s + 1]
		for i in n:
			var j := (i + 1) % n
			v.append_array(PackedVector3Array([a[i], a[j], b[j], a[i], b[j], b[i]]))
	for e in [sections[0], sections[sections.size() - 1]]:
		var mid := Vector3.ZERO
		for p in e:
			mid += p / n
		for i in n:
			v.append_array(PackedVector3Array([mid, e[i], e[(i + 1) % n]]))
	return flat_mesh(v, center)


## Vízszintes csík (körív) egy gömbölyű testen: y magasságban, R sugárral, `mid` szög körül
## (0 = +X, PI/2 = elöl, -PI/2 = hátul), a (cx, cz) tengely körül.
static func band(parent: Node3D, m: Material, y: float, R: float, arc: float, mid: float, tube := 0.016, cx := 0.0, cz := 0.0) -> MeshInstance3D:
	var key := "bd%.3f_%.3f_%.3f" % [R, arc, tube]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = arc_tube(R, tube, arc, 7, 4)
	return part(parent, _mesh_cache[key], m, Vector3(cx, y, cz), Vector3.ONE, Vector3(PI / 2, 0, mid - arc / 2))


static func grp(parent: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_order = EULER_ORDER_XYZ
	g.rotation = rot
	parent.add_child(g)
	return g


class CharModel:
	extends Node3D
	var rig: Node3D
	var eyes: Array = []
	var tick_fn: Callable = func(_t): pass
	var char_id := ""
	var phase := FX.f() * 10.0
	var blink_at := 1.0 + FX.f() * 3.0
	var emote_type := ""
	var emote_t0 := 0.0
	var t := 0.0
	var land := 0.0
	var airborne := 0.0          # 0..1, ugrás közben nyúlik
	var base_scale := 1.0

	func emote(type: String) -> void:
		emote_type = type
		emote_t0 = t

	## Animáció léptetése. Visszaadja az extra magasságot (öröm-ugrás), forgást és dőlést a gyökérhez.
	func animate(dt: float) -> Dictionary:
		t += dt
		land = max(0.0, land - dt * 5.0)
		var sy := 1.0 + sin(t * 3.0 + phase) * 0.025
		var sx := 1.0
		var extra_y := 0.0
		var spin := 0.0
		var tilt := 0.0
		if airborne > 0.0:
			sy *= 1.0 + 0.12 * airborne
			sx = 1.0 - 0.08 * airborne
		sy *= 1.0 - land * 0.28
		sx *= 1.0 + land * 0.22
		if emote_type != "":
			var k := t - emote_t0
			if emote_type == "happy" and k < 0.8:
				extra_y = sin(k / 0.8 * PI) * 0.55
				spin = k / 0.8 * TAU
			elif emote_type == "cheer" and k < 1.8:
				extra_y = sin(fmod(k, 0.6) / 0.6 * PI) * 0.7
				spin = k / 1.8 * TAU * 2.0
			elif emote_type == "sad" and k < 1.4:
				var a = sin(min(1.0, k / 0.3) * PI / 2) * (1.0 - max(0.0, (k - 1.0) / 0.4))
				sy *= 1.0 - 0.18 * a
				sx *= 1.0 + 0.08 * a
				tilt = 0.35 * a
			elif emote_type == "dizzy" and k < 1.6:
				spin = sin(k * 12.0) * 0.6
				tilt = sin(k * 9.0) * 0.2
			else:
				emote_type = ""
		rig.scale = Vector3(sx, sy, sx)
		if t > blink_at:
			var b := t - blink_at
			var sc := 0.1 if b < 0.12 else 1.0
			for e in eyes:
				e.scale.y = sc
			if b > 0.12:
				blink_at = t + 2.0 + FX.f() * 3.0
		tick_fn.call(t + phase)
		return {"y": extra_y, "spin": spin, "tilt": tilt}


static func build(id: String) -> CharModel:
	var root := CharModel.new()
	root.char_id = id
	var rig := Node3D.new()
	root.add_child(rig)
	root.rig = rig
	var res: Dictionary = {}
	match id:
		"frog": res = _frog(rig)
		"cat": res = _cat(rig)
		"fox": res = _fox(rig)
		"panda": res = _panda(rig)
		"pig": res = _pig(rig)
		"penguin": res = _penguin(rig)
		"duck": res = _duck(rig)
		"robot": res = _robot(rig)
		"ghost": res = _ghost(rig)
		"queen": res = _queen(rig)
		"thimble": res = _thimble(rig)
		"donut": res = _donut(rig)
		"knight": res = _knight(rig)
		"king": res = _king(rig)
		"tiger": res = _tiger(rig)
		"bear": res = _bear(rig)
		"dwarf": res = _dwarf(rig)
		"ship": res = _ship(rig)
		_: res = _frog(rig)
	root.eyes = res.get("eyes", [])
	if res.has("tick"):
		root.tick_fn = res.tick
	return root


# ------------------------------------------------------------------ figurák
static func _frog(rig: Node3D) -> Dictionary:
	var g := mat("#4cbb57")
	var light := mat("#c9ef9f")
	sphere(rig, 0.42, g, 0, 0.36, 0, 1.15, 0.82, 1)
	sphere(rig, 0.3, light, 0, 0.3, 0.17, 1, 0.8, 0.6)
	sphere(rig, 0.15, g, -0.21, 0.66, 0.08)
	sphere(rig, 0.15, g, 0.21, 0.66, 0.08)
	var e := eyes(rig, 0.69, 0.17, 0.21, 0.1)
	part(rig, arc_tube(0.15, 0.018, PI * 0.8), mat("#1d6b2a"), Vector3(0, 0.47, 0.36), Vector3.ONE, Vector3(-0.35, 0, PI + PI * 0.1))
	cheeks(rig, 0.48, 0.35, 0.27)
	for s in [-1, 1]:
		sphere(rig, 0.12, g, s * 0.25, 0.05, 0.2, 1.3, 0.45, 1.5)
	return {"eyes": e}




static func _fox(rig: Node3D) -> Dictionary:
	var fur := mat("#f2711c")
	var white := mat("#fff8ee")
	var dark := mat("#3a2418")
	sphere(rig, 0.28, fur, 0, 0.3, 0, 1, 1.05, 0.95)
	sphere(rig, 0.19, white, 0, 0.27, 0.13, 1, 1, 0.6)
	sphere(rig, 0.29, fur, 0, 0.72, 0.02)
	cone(rig, 0.11, 0.28, white, 0, 0.62, 0.3, 16, Vector3(PI / 2, 0, 0))
	sphere(rig, 0.04, mat("#1f1b2e", {"rough": 0.3}), 0, 0.62, 0.45)
	for s in [-1, 1]:
		cone(rig, 0.1, 0.28, fur, s * 0.16, 1.02, -0.02, 4, Vector3(0, 0, -s * 0.25))
		cone(rig, 0.05, 0.1, dark, s * 0.19, 1.13, -0.02, 4, Vector3(0, 0, -s * 0.25))
	var e := eyes(rig, 0.81, 0.25, 0.13, 0.07)
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.25, -0.22)
	tail.rotation.x = -0.6
	rig.add_child(tail)
	sphere(tail, 0.17, fur, 0, 0.12, -0.12, 1, 1, 1.9)
	sphere(tail, 0.1, white, 0, 0.2, -0.38, 1, 1, 1.2)
	return {"eyes": e, "tick": func(t): tail.rotation.y = sin(t * 2.5) * 0.35}


static func _panda(rig: Node3D) -> Dictionary:
	var w := mat("#fafafa")
	var b := mat("#2b2b33")
	sphere(rig, 0.32, w, 0, 0.32, 0, 1, 1, 0.95)
	for s in [-1, 1]:
		sphere(rig, 0.1, b, s * 0.3, 0.38, 0.06, 1, 1.4, 1)
		sphere(rig, 0.11, b, s * 0.16, 0.06, 0.08, 1, 0.7, 1.2)
		sphere(rig, 0.09, b, s * 0.21, 0.98, -0.02)
		var patch := sphere(rig, 0.075, b, s * 0.11, 0.76, 0.25, 1, 1.35, 0.5)
		patch.rotation.z = s * 0.5
	sphere(rig, 0.3, w, 0, 0.74, 0.02)
	var e := eyes(rig, 0.77, 0.28, 0.11, 0.045)
	sphere(rig, 0.04, b, 0, 0.68, 0.31, 1.3, 0.9, 1)
	smile(rig, 0.63, 0.3, 0.03, b)
	return {"eyes": e}


static func _pig(rig: Node3D) -> Dictionary:
	var p := mat("#f9a8c4")
	var d := mat("#e77fa4")
	sphere(rig, 0.4, p, 0, 0.42, 0, 1.08, 0.98, 1)
	cyl(rig, 0.12, 0.13, 0.1, d, 0, 0.42, 0.39, 20, Vector3(PI / 2, 0, 0))
	for s in [-1, 1]:
		sphere(rig, 0.025, mat("#8a3b5c"), s * 0.045, 0.42, 0.45)
		cone(rig, 0.1, 0.18, d, s * 0.22, 0.78, 0.06, 3, Vector3(0.6, 0, -s * 0.4))
		for k in [-1, 1]:
			cyl(rig, 0.06, 0.06, 0.12, d, s * 0.2, 0.05, k * 0.16)
	var e := eyes(rig, 0.6, 0.33, 0.14, 0.065)
	cheeks(rig, 0.48, 0.36, 0.24)
	var tail := part(rig, arc_tube(0.07, 0.02, PI * 1.7, 14, 6), d, Vector3(0, 0.45, -0.41))
	return {"eyes": e, "tick": func(t): tail.rotation.z = t * 4.0}


static func _penguin(rig: Node3D) -> Dictionary:
	var b := mat("#24304a")
	var o := mat("#ff9f1c")
	sphere(rig, 0.34, b, 0, 0.48, 0, 1, 1.38, 0.95)
	sphere(rig, 0.27, mat("#ffffff", {"rough": 0.35}), 0, 0.42, 0.13, 0.85, 1.25, 0.6)
	cone(rig, 0.07, 0.18, o, 0, 0.7, 0.36, 16, Vector3(PI / 2, 0, 0))
	var e := eyes(rig, 0.8, 0.27, 0.11, 0.065)
	var flippers: Array = []
	for s in [-1, 1]:
		var f := sphere(rig, 0.1, b, s * 0.34, 0.45, 0, 0.45, 1.6, 0.9)
		f.rotation.z = s * 0.35
		flippers.append(f)
		sphere(rig, 0.09, o, s * 0.13, 0.03, 0.12, 1, 0.4, 1.5)
	cheeks(rig, 0.68, 0.28, 0.17, 0.04)
	return {"eyes": e, "tick": func(t):
		flippers[0].rotation.z = -(0.35 + sin(t * 5.0) * 0.15)
		flippers[1].rotation.z = 0.35 + sin(t * 5.0) * 0.15}


static func _duck(rig: Node3D) -> Dictionary:
	var y := mat("#ffd43b", {"rough": 0.25})
	var o := mat("#ff8c1a", {"rough": 0.3})
	sphere(rig, 0.36, y, 0, 0.3, -0.03, 1.15, 0.85, 1.1)
	cone(rig, 0.12, 0.22, y, 0, 0.42, -0.4, 16, Vector3(-1.1, 0, 0))
	sphere(rig, 0.25, y, 0, 0.74, 0.08)
	sphere(rig, 0.12, o, 0, 0.67, 0.31, 1.15, 0.38, 1.1)
	for s in [-1, 1]:
		sphere(rig, 0.14, y, s * 0.34, 0.36, -0.02, 0.4, 0.75, 1.1)
	var e := eyes(rig, 0.8, 0.27, 0.1, 0.06)
	return {"eyes": e, "tick": func(t): rig.rotation.z = sin(t * 2.2) * 0.07}


static func _robot(rig: Node3D) -> Dictionary:
	var steel := mat("#9fb3c8", {"metal": 0.55, "rough": 0.35})
	var dark := mat("#475569", {"metal": 0.4, "rough": 0.4})
	var glow := mat("#5eead4", {"emit": "#2dd4bf", "emit_e": 1.6})
	var red_on := mat("#ff4d6d", {"emit": "#ff1744", "emit_e": 2.0})
	var red_off := mat("#ff4d6d", {"emit": "#ff1744", "emit_e": 0.2})
	box(rig, 0.46, 0.4, 0.34, steel, Vector3(0, 0.38, 0))
	for i in 3:
		box(rig, 0.06, 0.06, 0.02, red_on if i == 1 else glow, Vector3(-0.1 + i * 0.1, 0.4, 0.18))
	box(rig, 0.44, 0.32, 0.36, steel, Vector3(0, 0.8, 0))
	box(rig, 0.36, 0.14, 0.02, dark, Vector3(0, 0.82, 0.185))
	var e: Array = []
	for s in [-1, 1]:
		var g := Node3D.new()
		g.position = Vector3(s * 0.09, 0.82, 0.2)
		rig.add_child(g)
		cyl(g, 0.035, 0.035, 0.02, glow, 0, 0, 0, 12, Vector3(PI / 2, 0, 0))
		e.append(g)
		cyl(rig, 0.045, 0.045, 0.24, dark, s * 0.29, 0.38, 0)
		sphere(rig, 0.06, steel, s * 0.29, 0.23, 0)
		box(rig, 0.12, 0.18, 0.14, dark, Vector3(s * 0.12, 0.09, 0))
	cyl(rig, 0.012, 0.012, 0.2, dark, 0, 1.05, 0)
	var bulb := sphere(rig, 0.05, red_on, 0, 1.16, 0)
	return {"eyes": e, "tick": func(t): bulb.material_override = red_on if sin(t * 6.0) > 0 else red_off}


static func _ghost(rig: Node3D) -> Dictionary:
	var m := mat("#f8f9ff", {"alpha": 0.9, "emit": "#c7d2fe", "emit_e": 0.25})
	var fl := Node3D.new()
	rig.add_child(fl)
	part(fl, _sphere_mesh(0.34, true), m, Vector3(0, 0.62, 0))
	cyl(fl, 0.34, 0.36, 0.34, m, 0, 0.45, 0, 24)
	for i in 8:
		var a := TAU * i / 8
		cone(fl, 0.1, 0.16, m, sin(a) * 0.28, 0.22, cos(a) * 0.28, 8, Vector3(PI, 0, 0))
	for s in [-1, 1]:
		sphere(fl, 0.08, m, s * 0.36, 0.48, 0.05, 0.8, 1, 0.8)
	var e := eyes(fl, 0.66, 0.31, 0.12, 0.075, 0.55, false)
	sphere(fl, 0.045, mat("#1f1b2e", {"rough": 0.3}), 0, 0.53, 0.33, 1, 1.3, 0.5)
	return {"eyes": e, "tick": func(t):
		fl.position.y = 0.12 + sin(t * 2.0) * 0.06
		fl.rotation.z = sin(t * 1.3) * 0.08}




static func _thimble(rig: Node3D) -> Dictionary:
	var metal := StandardMaterial3D.new()
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("#d7dee6"))
	for y in range(0, 128, 12):
		var off := 6 if (y / 12) % 2 else 0
		for x in range(off, 128, 12):
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx * dx + dy * dy <= 10:
						img.set_pixel(posmod(x + dx, 128), posmod(y + dy, 128), Color("#8f9bab"))
	img.generate_mipmaps()
	metal.albedo_texture = ImageTexture.create_from_image(img)
	metal.uv1_scale = Vector3(4, 2, 1)
	metal.metallic = 0.75
	metal.roughness = 0.3
	var lm := lathe([[0, 0.02], [0.31, 0.02], [0.3, 0.1], [0.27, 0.55], [0.24, 0.65], [0.17, 0.72], [0, 0.75]], 32)
	part(rig, lm, metal)
	part(rig, torus(0.31, 0.035), mat("#b8c2cf", {"metal": 0.8, "rough": 0.25}), Vector3(0, 0.05, 0))
	var e := eyes(rig, 0.44, 0.27, 0.1, 0.085)
	smile(rig, 0.3, 0.29, 0.06)
	cheeks(rig, 0.32, 0.28, 0.18, 0.04)
	for s in [-1, 1]:
		sphere(rig, 0.07, mat("#ef4444"), s * 0.14, 0.02, 0.18, 1.2, 0.5, 1.5)
	return {"eyes": e}


static func _donut(rig: Node3D) -> Dictionary:
	var dough := mat("#d99a5b")
	var icing := mat("#ff8fb8", {"rough": 0.35})
	var ring := Node3D.new()
	ring.position.y = 0.48
	rig.add_child(ring)
	part(ring, torus(0.29, 0.17), dough, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	part(ring, torus(0.29, 0.155), icing, Vector3(0, 0, 0.06), Vector3(1.04, 0.75, 1.04), Vector3(PI / 2, 0, 0))
	var cols := ["#fde047", "#60a5fa", "#34d399", "#ffffff", "#c084fc"]
	for i in 26:
		var a := TAU * i / 26 + (i % 3) * 0.2
		var rr := 0.29 + (((i * 37) % 10) - 5) * 0.018
		box(ring, 0.06, 0.018, 0.018, mat(cols[i % cols.size()]), Vector3(cos(a) * rr, sin(a) * rr, 0.19), Vector3(0, 0, a * 3))
	var e := eyes(ring, 0.29, 0.2, 0.12, 0.07)
	for s in [-1, 1]:
		sphere(rig, 0.07, mat("#7c4a24"), s * 0.15, 0.03, 0.05, 1.2, 0.5, 1.4)
	return {"eyes": e}


# ------------------------------------------------------------------ low-poly figurák
## Lengő, szelvényekből álló farok. Visszaadja a szelvények csuklóit (animációhoz).
static func _tail(parent: Node3D, pos: Vector3, n: int, r0: float, r1: float, mats: Array, curl := -0.32, lean := -0.9) -> Array:
	var joints: Array = []
	var cur := grp(parent, pos, Vector3(lean, 0, 0))
	for i in n:
		var k: float = float(i) / max(1, n - 1)
		var r := lerpf(r0, r1, k)
		lsphere(cur, r, mats[i % mats.size()] if i < n - 1 else mats[mats.size() - 1], 0, r * 0.7, 0, 1, 1.25, 1, 6, 4)
		joints.append(cur)
		cur = grp(cur, Vector3(0, r * 1.5, 0), Vector3(-curl, 0, 0))
	return joints


static func _cat(rig: Node3D) -> Dictionary:
	var fur := mat("#f2a541")
	var dark := mat("#c96f1c")
	var cream := mat("#fff1d6")
	var pink := mat("#ff9fb5")
	var black := mat("#1f1b2e", {"rough": 0.3})
	var gold := mat("#ffd43b", {"metal": 0.6, "rough": 0.3})
	# törzs, mellény, hátcsíkok
	lsphere(rig, 0.27, fur, 0, 0.29, -0.01, 1.0, 1.08, 0.95, 10, 7)
	lsphere(rig, 0.19, cream, 0, 0.27, 0.115, 0.95, 1.05, 0.62, 8, 6)
	for i in 3:
		var y := 0.2 + i * 0.1
		band(rig, dark, y, 0.265 * sqrt(1.0 - pow((y - 0.29) / 0.292, 2)) + 0.004, 1.9, -PI / 2, 0.02, 0, -0.01)
	# lábak
	for s in [-1, 1]:
		lsphere(rig, 0.095, fur, s * 0.2, 0.06, 0.04, 1, 0.62, 1.45, 8, 5)
		lsphere(rig, 0.05, cream, s * 0.2, 0.045, 0.15, 1.1, 0.7, 1, 6, 4)
		lsphere(rig, 0.065, fur, s * 0.1, 0.2, 0.2, 1, 1.9, 1, 6, 5)
		lsphere(rig, 0.07, cream, s * 0.1, 0.055, 0.24, 1.05, 0.7, 1.2, 6, 4)
		for k in [-1, 1]:
			box(rig, 0.006, 0.03, 0.03, dark, Vector3(s * 0.1 + k * 0.022, 0.06, 0.31))
	# nyakörv csengővel
	lcyl(rig, 0.165, 0.185, 0.045, mat("#e11d48"), 0, 0.5, 0.0, 10)
	lsphere(rig, 0.05, gold, 0, 0.455, 0.185, 1, 1, 1, 8, 5)
	box(rig, 0.012, 0.035, 0.02, black, Vector3(0, 0.44, 0.228))
	# fej
	lsphere(rig, 0.295, fur, 0, 0.73, 0.02, 1.06, 0.97, 0.98, 10, 7)
	for s in [-1, 1]:
		lcone(rig, 0.12, 0.25, fur, s * 0.175, 0.99, 0.0, 4, Vector3(0, PI / 4, -s * 0.32))
		lcone(rig, 0.07, 0.16, pink, s * 0.17, 0.975, 0.045, 4, Vector3(0, PI / 4, -s * 0.32))
		# pofaszőr
		for k in 2:
			lcone(rig, 0.05, 0.14, fur, s * 0.29, 0.66 - k * 0.06, 0.06, 4, Vector3(0, 0, -s * (PI / 2 + 0.15 + k * 0.35)))
		lsphere(rig, 0.078, cream, s * 0.052, 0.655, 0.265, 1.05, 0.85, 0.7, 7, 5)
		for k in [-1, 0, 1]:
			box(rig, 0.2, 0.009, 0.009, black, Vector3(s * 0.2, 0.655 + k * 0.03, 0.27), Vector3(0, -s * 0.25, s * k * 0.16))
	lsphere(rig, 0.05, cream, 0, 0.6, 0.255, 1.1, 0.7, 0.8, 6, 4)
	lsphere(rig, 0.034, pink, 0, 0.695, 0.318, 1.25, 0.8, 0.8, 6, 4)
	box(rig, 0.01, 0.04, 0.01, black, Vector3(0, 0.662, 0.322))
	smile(rig, 0.652, 0.305, 0.03)
	# homlokcsíkok
	for i in [-1, 0, 1]:
		box(rig, 0.032, 0.02, 0.13 if i == 0 else 0.09, dark, Vector3(i * 0.075, 0.992 - abs(i) * 0.012, 0.105), Vector3(0.42, 0, -i * 0.25))
	var e := eyes(rig, 0.775, 0.275, 0.115, 0.078)
	var tail := _tail(rig, Vector3(0.04, 0.14, -0.24), 7, 0.062, 0.045, [fur, dark, fur, dark, fur, fur, cream])
	return {"eyes": e, "tick": func(t):
		for i in tail.size():
			tail[i].rotation.z = sin(t * 3.0 - i * 0.55) * 0.16}


static func _tiger(rig: Node3D) -> Dictionary:
	var fur := mat("#f58a1f")
	var white := mat("#fff7ea")
	var black := mat("#231a14", {"rough": 0.45})
	var pink := mat("#f48aa0")
	# törzs
	lsphere(rig, 0.3, fur, 0, 0.31, -0.01, 1.08, 1.05, 0.98, 10, 7)
	lsphere(rig, 0.22, white, 0, 0.28, 0.12, 0.95, 1.05, 0.62, 8, 6)
	for i in 3:
		var y := 0.2 + i * 0.11
		var R := 0.3 * sqrt(1.0 - pow((y - 0.31) / 0.315, 2))
		for s in [0.0, PI]:
			band(rig, black, y, R * 1.06 + 0.004, 1.15, s + (0.12 if i == 1 else -0.1) * (1 if s == 0.0 else -1), 0.022, 0, -0.01)
		band(rig, black, y + 0.05, R * 0.99, 0.7, -PI / 2, 0.02, 0, -0.01)
	# mancsok
	for s in [-1, 1]:
		lsphere(rig, 0.11, fur, s * 0.2, 0.065, 0.06, 1, 0.6, 1.4, 8, 5)
		lsphere(rig, 0.06, white, s * 0.2, 0.05, 0.17, 1.2, 0.7, 1, 6, 4)
		var arm := grp(rig, Vector3(s * 0.31, 0.47, 0.04), Vector3(0, 0, s * 0.28))
		lsphere(arm, 0.085, fur, 0, -0.1, 0, 1, 1.75, 1, 7, 5)
		lsphere(arm, 0.075, white, 0, -0.23, 0.03, 1.05, 0.8, 1.1, 6, 4)
		for k in 2:
			lcyl(arm, 0.089, 0.089, 0.03, black, 0, -0.04 - k * 0.085, 0, 7)
	# fej
	lsphere(rig, 0.3, fur, 0, 0.75, 0.02, 1.12, 0.95, 0.98, 10, 7)
	for s in [-1, 1]:
		lsphere(rig, 0.095, fur, s * 0.22, 0.99, -0.01, 1, 1, 0.6, 8, 5)
		lsphere(rig, 0.06, white, s * 0.22, 0.985, 0.035, 1, 1, 0.5, 6, 4)
		lsphere(rig, 0.07, black, s * 0.22, 0.995, -0.045, 1, 1, 0.5, 6, 4)
		# pofa: fehér pofaszőr és csíkok
		lsphere(rig, 0.11, white, s * 0.21, 0.66, 0.13, 1, 0.8, 0.8, 7, 5)
		for k in 2:
			box(rig, 0.13, 0.026, 0.05, black, Vector3(s * 0.285, 0.73 + k * 0.075, 0.1), Vector3(0, -s * 0.9, s * (0.2 + k * 0.15)))
		lsphere(rig, 0.095, white, s * 0.06, 0.66, 0.27, 1.05, 0.85, 0.7, 7, 5)
		lcone(rig, 0.022, 0.07, white, s * 0.045, 0.585, 0.3, 4, Vector3(PI, 0, 0))
		for k in 3:
			lsphere(rig, 0.008, black, s * (0.05 + k * 0.03), 0.665 + (k % 2) * 0.02, 0.335 - k * 0.01)
	lsphere(rig, 0.06, white, 0, 0.6, 0.25, 1.2, 0.6, 0.8, 6, 4)
	lsphere(rig, 0.042, pink, 0, 0.71, 0.335, 1.35, 0.8, 0.8, 6, 4)
	box(rig, 0.012, 0.04, 0.012, black, Vector3(0, 0.672, 0.338))
	smile(rig, 0.662, 0.318, 0.032)
	for i in [-1, 0, 1]:
		box(rig, 0.036, 0.022, 0.15 if i == 0 else 0.11, black, Vector3(i * 0.085, 1.005 - abs(i) * 0.014, 0.1), Vector3(0.42, 0, -i * 0.25))
	box(rig, 0.11, 0.022, 0.03, black, Vector3(0, 0.925, 0.24), Vector3(0.75, 0, 0))
	var e := eyes(rig, 0.8, 0.275, 0.12, 0.075)
	var tail := _tail(rig, Vector3(0.04, 0.14, -0.27), 8, 0.07, 0.055, [fur, black], -0.28)
	return {"eyes": e, "tick": func(t):
		for i in tail.size():
			tail[i].rotation.z = sin(t * 2.4 - i * 0.5) * 0.14}


static func _bear(rig: Node3D) -> Dictionary:
	var fur := mat("#8a5a2e")
	var tanc := mat("#dcb886")
	var dark := mat("#3d2614", {"rough": 0.4})
	var red := mat("#e03131")
	# törzs és pocak
	lsphere(rig, 0.33, fur, 0, 0.33, -0.01, 1.06, 1.04, 0.98, 10, 7)
	lsphere(rig, 0.24, tanc, 0, 0.3, 0.12, 0.95, 1.05, 0.62, 8, 6)
	lsphere(rig, 0.07, fur, 0, 0.22, -0.32, 1, 1, 1, 6, 4)
	# talpak karmokkal
	for s in [-1, 1]:
		lsphere(rig, 0.125, fur, s * 0.19, 0.07, 0.08, 1, 0.6, 1.4, 8, 5)
		lsphere(rig, 0.07, tanc, s * 0.19, 0.075, 0.215, 1, 0.9, 0.5, 6, 4)
		for k in [-1, 0, 1]:
			lcone(rig, 0.018, 0.05, mat("#f5efe0"), s * 0.19 + k * 0.05, 0.03, 0.255, 4, Vector3(PI / 2, 0, 0))
	# sál
	lcyl(rig, 0.19, 0.22, 0.07, red, 0, 0.6, 0.0, 10)
	box(rig, 0.085, 0.2, 0.035, red, Vector3(0.1, 0.49, 0.25), Vector3(-0.2, 0, -0.12))
	box(rig, 0.085, 0.03, 0.037, mat("#ffffff"), Vector3(0.107, 0.43, 0.262), Vector3(-0.2, 0, -0.12))
	# fej
	lsphere(rig, 0.29, fur, 0, 0.8, 0.02, 1.08, 0.95, 0.98, 10, 7)
	for s in [-1, 1]:
		lsphere(rig, 0.105, fur, s * 0.215, 1.035, -0.01, 1, 1, 0.65, 8, 5)
		lsphere(rig, 0.06, tanc, s * 0.215, 1.03, 0.04, 1, 1, 0.5, 6, 4)
		box(rig, 0.085, 0.022, 0.03, dark, Vector3(s * 0.12, 0.905, 0.265), Vector3(0.3, 0, -s * 0.12))
	lsphere(rig, 0.13, tanc, 0, 0.73, 0.25, 1.1, 0.85, 0.75, 8, 5)
	lsphere(rig, 0.048, dark, 0, 0.775, 0.345, 1.35, 0.85, 0.8, 6, 4)
	box(rig, 0.012, 0.045, 0.012, dark, Vector3(0, 0.73, 0.345))
	smile(rig, 0.715, 0.33, 0.035, dark)
	cheeks(rig, 0.74, 0.26, 0.19, 0.04)
	var e := eyes(rig, 0.845, 0.275, 0.115, 0.06, 0.68)
	# mancsok: a jobb integet, a bal mézescsuprot tart
	var arm_r := grp(rig, Vector3(0.33, 0.52, 0.03), Vector3(0, 0, 0.5))
	lsphere(arm_r, 0.09, fur, 0, -0.1, 0, 1, 1.8, 1, 7, 5)
	lsphere(arm_r, 0.05, tanc, 0, -0.24, 0.05, 1, 1, 0.5, 6, 4)
	var arm_l := grp(rig, Vector3(-0.31, 0.5, 0.06), Vector3(-0.75, 0, -0.25))
	lsphere(arm_l, 0.09, fur, 0, -0.1, 0, 1, 1.8, 1, 7, 5)
	var pot := grp(rig, Vector3(-0.25, 0.3, 0.3))
	part(pot, llathe([[0, 0], [0.075, 0], [0.1, 0.06], [0.095, 0.13], [0.07, 0.16], [0.08, 0.18], [0.0, 0.18]], 8), mat("#c97b2a"))
	lcyl(pot, 0.068, 0.068, 0.02, mat("#ffc21a", {"rough": 0.2}), 0, 0.185, 0, 8)
	lsphere(pot, 0.03, mat("#ffc21a", {"rough": 0.2}), 0.06, 0.15, 0.06, 0.8, 1.6, 0.8, 6, 4)
	box(pot, 0.09, 0.055, 0.01, mat("#fff1c9"), Vector3(0, 0.085, 0.099))
	return {"eyes": e, "tick": func(t): arm_r.rotation.z = 0.5 + max(0.0, sin(t * 1.3)) * (1.3 + sin(t * 9.0) * 0.25)}


## Ember-figurák közös arca: szem, pirospozsga, mosoly.
static func _face(rig: Node3D, y: float, z: float, dx := 0.072, r := 0.045, mouth: Material = null) -> Array:
	var e := eyes(rig, y, z, dx, r)
	cheeks(rig, y - 0.07, z - 0.012, dx + 0.05, 0.032)
	smile(rig, y - 0.075, z + 0.012, 0.028, mouth)
	return e


static func _knight(rig: Node3D) -> Dictionary:
	var steel := mat("#c3ccd8", {"metal": 0.65, "rough": 0.32})
	var iron := mat("#6f7c8f", {"metal": 0.6, "rough": 0.4})
	var gold := mat("#ffd43b", {"metal": 0.7, "rough": 0.28})
	var red := mat("#e11d48", {"rough": 0.6})
	var blue := mat("#2f6fd6")
	var skin := mat("#ffd7b0")
	var leather := mat("#6b4a2b")
	# csizma, láb
	for s in [-1, 1]:
		lcyl(rig, 0.08, 0.095, 0.12, iron, s * 0.1, 0.06, 0.01, 8)
		box(rig, 0.15, 0.07, 0.14, iron, Vector3(s * 0.1, 0.035, 0.09))
		lcyl(rig, 0.075, 0.07, 0.12, steel, s * 0.1, 0.18, 0.0, 8)
		lsphere(rig, 0.05, gold, s * 0.1, 0.16, 0.07, 1, 1, 0.5, 6, 4)
	# páncél: szoknyalemezek, mellvért, öv
	for i in 8:
		var a := TAU * i / 8
		box(rig, 0.17, 0.15, 0.03, iron if i % 2 else steel, Vector3(sin(a) * 0.215, 0.275, cos(a) * 0.2), Vector3(-0.28, a, 0))
	part(rig, llathe([[0, 0.3], [0.21, 0.3], [0.25, 0.4], [0.255, 0.5], [0.2, 0.6], [0.11, 0.64], [0, 0.64]], 8), steel)
	lcyl(rig, 0.225, 0.22, 0.045, leather, 0, 0.335, 0, 8)
	box(rig, 0.07, 0.06, 0.03, gold, Vector3(0, 0.335, 0.215))
	box(rig, 0.035, 0.15, 0.02, gold, Vector3(0, 0.49, 0.245), Vector3(-0.05, 0, 0))
	box(rig, 0.11, 0.035, 0.02, gold, Vector3(0, 0.515, 0.245), Vector3(-0.05, 0, 0))
	lcyl(rig, 0.115, 0.14, 0.05, iron, 0, 0.65, 0, 8)
	# köpeny
	var cape := grp(rig, Vector3(0, 0.63, -0.15))
	part(cape, prism([[-0.17, 0], [0.17, 0], [0.24, -0.5], [-0.24, -0.5]], 0.03), red, Vector3.ZERO, Vector3.ONE, Vector3(0.22, 0, 0))
	# vállvért, kar, kesztyű
	for s in [-1, 1]:
		lsphere(rig, 0.11, steel, s * 0.275, 0.58, 0, 1, 0.8, 1, 8, 5)
		lcyl(rig, 0.112, 0.118, 0.025, gold, s * 0.275, 0.545, 0, 8)
		lcyl(rig, 0.055, 0.06, 0.16, iron, s * 0.3, 0.45, 0.03, 6)
		lsphere(rig, 0.068, steel, s * 0.305, 0.34, 0.06, 1, 1, 1, 6, 4)
	# fej és sisak
	lsphere(rig, 0.19, skin, 0, 0.82, 0.03, 1, 1, 1, 10, 7)
	lsphere(rig, 0.225, steel, 0, 0.855, -0.035, 1, 1, 1, 10, 7)
	lcyl(rig, 0.212, 0.215, 0.035, gold, 0, 0.935, -0.03, 10)
	for s in [-1, 1]:
		box(rig, 0.045, 0.2, 0.15, steel, Vector3(s * 0.165, 0.76, 0.1), Vector3(0, s * 0.25, 0))
		lsphere(rig, 0.025, gold, s * 0.195, 0.83, 0.1)
	box(rig, 0.034, 0.17, 0.035, steel, Vector3(0, 0.875, 0.215), Vector3(-0.1, 0, 0))
	lcyl(rig, 0.035, 0.045, 0.07, gold, 0, 1.09, -0.035, 6)
	var plume := grp(rig, Vector3(0, 1.1, -0.035))
	var pl := [[0.0, 0.05, 0.075], [-0.085, 0.07, 0.085], [-0.18, 0.03, 0.078], [-0.24, -0.06, 0.062], [-0.26, -0.15, 0.045]]
	for d in pl:
		lsphere(plume, d[2], red, 0, d[1], d[0], 0.8, 1, 1, 6, 4)
	var e := _face(rig, 0.8, 0.205, 0.068, 0.043)
	# pajzs a bal karon
	var sh := grp(rig, Vector3(-0.33, 0.42, 0.17), Vector3(0, -0.55, 0))
	part(sh, prism([[-0.15, 0.18], [0.15, 0.18], [0.15, -0.02], [0, -0.22], [-0.15, -0.02]], 0.04), gold)
	part(sh, prism([[-0.12, 0.15], [0.12, 0.15], [0.12, -0.01], [0, -0.18], [-0.12, -0.01]], 0.05), blue)
	box(sh, 0.045, 0.3, 0.06, mat("#f8f9fa"), Vector3(0, -0.005, 0))
	box(sh, 0.24, 0.045, 0.06, mat("#f8f9fa"), Vector3(0, 0.06, 0))
	lsphere(sh, 0.03, gold, 0, 0.06, 0.035)
	# kard a jobb kézben
	var sw := grp(rig, Vector3(0.32, 0.34, 0.1), Vector3(0.55, 0, -0.12))
	lcyl(sw, 0.02, 0.02, 0.1, leather, 0, 0, 0, 6)
	lsphere(sw, 0.032, gold, 0, -0.065, 0, 1, 1, 1, 6, 4)
	box(sw, 0.17, 0.03, 0.045, gold, Vector3(0, 0.062, 0))
	part(sw, prism([[-0.032, 0], [0.032, 0], [0.032, 0.36], [0, 0.44], [-0.032, 0.36]], 0.014), mat("#eef2f7", {"metal": 0.8, "rough": 0.18}), Vector3(0, 0.075, 0))
	box(sw, 0.008, 0.34, 0.018, steel, Vector3(0, 0.25, 0))
	return {"eyes": e, "tick": func(t):
		cape.rotation.x = sin(t * 2.2) * 0.06
		plume.rotation.x = sin(t * 3.0) * 0.08}


## Hermelinprém: fehér gyűrű fekete pöttyökkel.
static func _ermine(parent: Node3D, r: float, h: float, y: float, n: int, z := 0.0) -> void:
	lcyl(parent, r * 0.97, r, h, mat("#fbfbf8", {"rough": 0.9}), 0, y, z, 12)
	for i in n:
		var a := TAU * (i + 0.5) / n
		box(parent, 0.022, h * 0.5, 0.014, mat("#1f1b2e"), Vector3(sin(a) * r * 0.975, y, z + cos(a) * r * 0.975), Vector3(0, a, 0))


## Korona: abroncs, csúcsok ékkövekkel. tall: a csúcsok magassága.
static func _crown(parent: Node3D, r: float, y: float, n: int, tall: float, gems: Array, z := 0.0) -> void:
	var gold := mat("#ffd43b", {"metal": 0.75, "rough": 0.25})
	lcyl(parent, r * 1.04, r, tall * 0.55, gold, 0, y, z, 10)
	lcyl(parent, r * 1.08, r * 1.08, tall * 0.12, gold, 0, y - tall * 0.26, z, 10)
	for i in n:
		var a := TAU * i / n
		var p := Vector3(sin(a) * r * 1.0, y + tall * 0.6, z + cos(a) * r * 1.0)
		lcone(parent, r * 0.3, tall * 0.75, gold, p.x, p.y, p.z, 4, Vector3(0, a, 0))
		var gm := mat(gems[i % gems.size()], {"rough": 0.15, "emit": gems[i % gems.size()], "emit_e": 0.35})
		lsphere(parent, r * 0.16, gm, p.x, p.y + tall * 0.42, p.z, 1, 1, 1, 6, 4)
		lsphere(parent, r * 0.14, gm, sin(a + PI / n) * r * 1.06, y, z + cos(a + PI / n) * r * 1.06, 1, 1.3, 0.6, 4, 2)


static func _king(rig: Node3D) -> Dictionary:
	var robe := mat("#c81e3a", {"rough": 0.6})
	var robe_d := mat("#8f1230", {"rough": 0.6})
	var gold := mat("#ffd43b", {"metal": 0.75, "rough": 0.25})
	var skin := mat("#ffd0a6")
	var white := mat("#f8f8f4", {"rough": 0.9})
	# palást és ruha
	part(rig, llathe([[0, 0], [0.33, 0], [0.32, 0.1], [0.27, 0.3], [0.21, 0.47], [0.16, 0.58], [0, 0.6]], 12), robe)
	_ermine(rig, 0.345, 0.1, 0.05, 10)
	box(rig, 0.1, 0.5, 0.03, white, Vector3(0, 0.33, 0.262), Vector3(-0.3, 0, 0))
	for i in 4:
		box(rig, 0.03, 0.04, 0.012, mat("#1f1b2e"), Vector3(0.012 * (1 if i % 2 else -1), 0.17 + i * 0.1, 0.33 - i * 0.031), Vector3(-0.3, 0, 0))
	lcyl(rig, 0.228, 0.245, 0.05, gold, 0, 0.4, 0, 12)
	lsphere(rig, 0.045, mat("#2f9e44", {"rough": 0.15, "emit": "#2f9e44", "emit_e": 0.3}), 0, 0.4, 0.25, 1, 1, 0.6, 4, 2)
	var cape := grp(rig, Vector3(0, 0.6, -0.12))
	part(cape, prism([[-0.2, 0], [0.2, 0], [0.33, -0.58], [-0.33, -0.58]], 0.035), robe_d, Vector3.ZERO, Vector3.ONE, Vector3(0.3, 0, 0))
	part(cape, prism([[-0.335, -0.5], [0.335, -0.5], [0.345, -0.58], [-0.345, -0.58]], 0.05), white, Vector3.ZERO, Vector3.ONE, Vector3(0.3, 0, 0))
	_ermine(rig, 0.235, 0.09, 0.6, 9)
	# karok
	for s in [-1, 1]:
		var arm := grp(rig, Vector3(s * 0.215, 0.56, 0.02), Vector3(-0.5, 0, s * 0.5))
		lsphere(arm, 0.08, robe, 0, -0.1, 0, 1, 1.7, 1, 7, 5)
		lcyl(arm, 0.07, 0.075, 0.045, white, 0, -0.215, 0, 8)
		lsphere(arm, 0.055, skin, 0, -0.265, 0, 1, 1, 1, 6, 4)
	# fej, szakáll, bajusz
	lsphere(rig, 0.2, skin, 0, 0.84, 0.02, 1, 1, 1, 10, 7)
	for s in [-1, 1]:
		lsphere(rig, 0.1, white, s * 0.165, 0.83, -0.05, 0.8, 1.2, 1, 7, 5)
		lsphere(rig, 0.06, white, s * 0.065, 0.785, 0.21, 1.5, 0.75, 0.8, 6, 4).rotation.z = -s * 0.35
		lsphere(rig, 0.105, white, s * 0.1, 0.72, 0.12, 1, 1, 0.85, 7, 5)
		box(rig, 0.085, 0.026, 0.03, white, Vector3(s * 0.075, 0.925, 0.185), Vector3(0, 0, s * 0.18))
	lsphere(rig, 0.19, white, 0, 0.78, -0.07, 1, 1, 0.9, 8, 6)
	lsphere(rig, 0.14, white, 0, 0.68, 0.14, 1.15, 0.9, 0.75, 8, 6)
	lcone(rig, 0.12, 0.2, white, 0, 0.56, 0.17, 5, Vector3(PI + 0.25, 0, 0))
	lsphere(rig, 0.045, mat("#f3b58c"), 0, 0.82, 0.225, 1, 1, 1, 6, 4)
	var e := eyes(rig, 0.87, 0.2, 0.075, 0.043)
	cheeks(rig, 0.8, 0.185, 0.13, 0.03)
	# korona bársonysapkával
	lsphere(rig, 0.135, robe, 0, 1.07, 0.01, 1, 0.9, 1, 8, 5)
	_crown(rig, 0.15, 1.04, 6, 0.14, ["#e11d48", "#3b82f6", "#22c55e"], 0.01)
	lsphere(rig, 0.035, gold, 0, 1.21, 0.01, 1, 1, 1, 6, 4)
	box(rig, 0.02, 0.07, 0.02, gold, Vector3(0, 1.27, 0.01))
	box(rig, 0.055, 0.02, 0.02, gold, Vector3(0, 1.275, 0.01))
	# jogar és országalma
	var sc := grp(rig, Vector3(0.37, 0.36, 0.2), Vector3(0.12, 0, -0.1))
	lcyl(sc, 0.016, 0.02, 0.62, gold, 0, 0.16, 0, 6)
	lsphere(sc, 0.03, gold, 0, -0.16, 0, 1, 1, 1, 6, 4)
	lcyl(sc, 0.045, 0.03, 0.04, gold, 0, 0.47, 0, 6)
	var orb := lsphere(sc, 0.062, mat("#a855f7", {"rough": 0.15, "emit": "#a855f7", "emit_e": 0.5}), 0, 0.545, 0, 1, 1, 1, 6, 3)
	lcone(sc, 0.03, 0.06, gold, 0, 0.63, 0, 4)
	var apple := grp(rig, Vector3(-0.37, 0.39, 0.2))
	lsphere(apple, 0.07, mat("#3b82f6", {"rough": 0.2, "metal": 0.3}), 0, 0, 0, 1, 1, 1, 8, 5)
	lcyl(apple, 0.073, 0.073, 0.02, gold, 0, 0, 0, 8)
	box(apple, 0.02, 0.08, 0.02, gold, Vector3(0, 0.1, 0))
	box(apple, 0.06, 0.02, 0.02, gold, Vector3(0, 0.11, 0))
	return {"eyes": e, "tick": func(t):
		orb.rotation.y = t * 1.5
		cape.rotation.x = sin(t * 2.0) * 0.04}


static func _queen(rig: Node3D) -> Dictionary:
	var dress := mat("#8b5cf6", {"rough": 0.55})
	var dress_d := mat("#6d3fe0", {"rough": 0.55})
	var lilac := mat("#d9ccff", {"rough": 0.6})
	var gold := mat("#ffd43b", {"metal": 0.75, "rough": 0.25})
	var skin := mat("#ffd7b0")
	var hair := mat("#7a3e1d", {"rough": 0.7})
	var white := mat("#ffffff", {"rough": 0.8})
	# szoknya: fodros alj, elöl világos betét, arany szegély
	part(rig, llathe([[0, 0], [0.38, 0], [0.37, 0.05], [0.3, 0.22], [0.2, 0.4], [0.115, 0.5], [0.15, 0.6], [0, 0.62]], 12), dress)
	lcyl(rig, 0.385, 0.39, 0.035, gold, 0, 0.025, 0, 12)
	for i in 12:
		var a := TAU * (i + 0.5) / 12
		lsphere(rig, 0.05, white, sin(a) * 0.365, 0.075, cos(a) * 0.365, 1, 0.9, 0.7, 6, 4).rotation.y = a
		if i % 2 == 0:
			box(rig, 0.03, 0.24, 0.02, dress_d, Vector3(sin(a) * 0.3, 0.2, cos(a) * 0.3), Vector3(-0.42, a, 0))
	part(rig, prism([[-0.035, 0.24], [0.035, 0.24], [0.13, -0.22], [-0.13, -0.22]], 0.02), lilac, Vector3(0, 0.26, 0.262), Vector3.ONE, Vector3(-0.43, 0, 0))
	for i in 3:
		lsphere(rig, 0.018, gold, 0, 0.14 + i * 0.1, 0.33 - i * 0.045)
	lcyl(rig, 0.122, 0.128, 0.04, gold, 0, 0.5, 0, 12)
	# masni hátul
	for s in [-1, 1]:
		lcone(rig, 0.07, 0.15, lilac, s * 0.08, 0.5, -0.14, 4, Vector3(0, 0, s * PI / 2))
		box(rig, 0.045, 0.2, 0.02, lilac, Vector3(s * 0.04, 0.38, -0.17), Vector3(0.35, 0, s * 0.2))
	lsphere(rig, 0.035, gold, 0, 0.5, -0.14, 1, 1, 1, 6, 4)
	# nyaklánc, gallér
	lcyl(rig, 0.1, 0.155, 0.03, white, 0, 0.615, 0, 10)
	lsphere(rig, 0.03, mat("#e11d48", {"rough": 0.15, "emit": "#e11d48", "emit_e": 0.4}), 0, 0.59, 0.15, 1, 1.2, 0.6, 4, 2)
	# puffos ujj, kar, kesztyű
	var arms: Array = []
	for s in [-1, 1]:
		lsphere(rig, 0.085, lilac, s * 0.19, 0.57, 0, 1, 0.95, 1, 7, 5)
		var arm := grp(rig, Vector3(s * 0.22, 0.54, 0.02), Vector3(-0.55, 0, s * 0.35))
		lsphere(arm, 0.042, skin, 0, -0.1, 0, 1, 2.2, 1, 6, 4)
		lcyl(arm, 0.045, 0.05, 0.09, white, 0, -0.16, 0, 6)
		lsphere(arm, 0.045, white, 0, -0.22, 0, 1, 1, 1, 6, 4)
		arms.append(arm)
	# fej, haj
	lsphere(rig, 0.19, skin, 0, 0.83, 0.03, 1, 1, 1, 10, 7)
	lsphere(rig, 0.215, hair, 0, 0.86, -0.04, 1.02, 1, 1, 10, 7)
	lsphere(rig, 0.11, hair, 0, 1.06, -0.12, 1, 0.95, 1, 8, 5)
	lcyl(rig, 0.07, 0.085, 0.03, gold, 0, 1.0, -0.09, 8, Vector3(-0.5, 0, 0))
	for s in [-1, 1]:
		lsphere(rig, 0.065, hair, s * 0.19, 0.72, 0.03, 1, 2.3, 1.1, 6, 5)
		lsphere(rig, 0.05, hair, s * 0.2, 0.56, 0.05, 1, 1.2, 1, 6, 4)
		lsphere(rig, 0.075, hair, s * 0.1, 0.975, 0.13, 1.3, 0.7, 0.8, 6, 4).rotation.z = -s * 0.5
		lsphere(rig, 0.024, gold, s * 0.195, 0.74, 0.1, 1, 1.5, 1, 4, 2)
		box(rig, 0.04, 0.012, 0.012, mat("#1f1b2e"), Vector3(s * 0.125, 0.845, 0.19), Vector3(0, -s * 0.5, s * 0.5))
	lsphere(rig, 0.06, hair, 0, 0.995, 0.15, 1.2, 0.6, 0.8, 6, 4)
	var e := _face(rig, 0.825, 0.2, 0.07, 0.046, mat("#c0392b"))
	# korona
	_crown(rig, 0.105, 1.04, 5, 0.12, ["#ff5fa2", "#38bdf8"], 0.03)
	# pálca csillaggal
	var wand := grp(arms[1], Vector3(0, -0.23, 0.02), Vector3(0.75, 0, -0.45))
	lcyl(wand, 0.012, 0.014, 0.34, gold, 0, 0.13, 0, 6)
	var star := grp(wand, Vector3(0, 0.33, 0))
	var sm := mat("#ffe066", {"emit": "#ffd43b", "emit_e": 1.2, "rough": 0.3})
	for i in 5:
		part(star, prism([[-0.022, 0.02], [0.022, 0.02], [0, 0.085]], 0.025), sm, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, TAU * i / 5))
	lsphere(star, 0.036, sm, 0, 0, 0, 1, 1, 0.5, 5, 2)
	return {"eyes": e, "tick": func(t):
		star.rotation.z = t * 1.6
		arms[1].rotation.x = -0.55 + sin(t * 2.0) * 0.12}


static func _dwarf(rig: Node3D) -> Dictionary:
	var tunic := mat("#2f8f4e", {"rough": 0.7})
	var leather := mat("#5c3d1e", {"rough": 0.7})
	var steel := mat("#aeb9c6", {"metal": 0.65, "rough": 0.35})
	var gold := mat("#ffd43b", {"metal": 0.75, "rough": 0.25})
	var skin := mat("#f6c79c")
	var beard := mat("#c2501c", {"rough": 0.8})
	var beard_d := mat("#9a3c12", {"rough": 0.8})
	# bakancs
	for s in [-1, 1]:
		lsphere(rig, 0.115, leather, s * 0.14, 0.075, 0.06, 1, 0.68, 1.45, 8, 5)
		box(rig, 0.2, 0.035, 0.3, mat("#2b1c0f"), Vector3(s * 0.14, 0.018, 0.06))
		lcyl(rig, 0.1, 0.1, 0.035, steel, s * 0.14, 0.13, -0.01, 8)
	# törzs, öv
	part(rig, llathe([[0, 0.1], [0.27, 0.1], [0.305, 0.22], [0.295, 0.36], [0.23, 0.47], [0, 0.5]], 8), tunic)
	lcyl(rig, 0.31, 0.31, 0.065, leather, 0, 0.23, 0, 8)
	box(rig, 0.1, 0.09, 0.03, gold, Vector3(0, 0.23, 0.3))
	box(rig, 0.05, 0.04, 0.035, leather, Vector3(0, 0.23, 0.3))
	# vállak, karok, alkarvédő, ököl
	var arms: Array = []
	for s in [-1, 1]:
		lsphere(rig, 0.1, leather, s * 0.27, 0.43, 0, 1.1, 0.7, 1.1, 7, 4)
		var arm := grp(rig, Vector3(s * 0.3, 0.42, 0.02), Vector3(-0.35, 0, s * 0.3))
		lsphere(arm, 0.085, tunic, 0, -0.08, 0, 1, 1.5, 1, 7, 5)
		lcyl(arm, 0.075, 0.08, 0.07, leather, 0, -0.17, 0, 7)
		lsphere(arm, 0.078, skin, 0, -0.24, 0, 1, 1, 1, 6, 4)
		arms.append(arm)
	# fej
	lsphere(rig, 0.215, skin, 0, 0.64, 0.03, 1.06, 1, 1, 10, 7)
	for s in [-1, 1]:
		lsphere(rig, 0.05, skin, s * 0.225, 0.63, 0.02, 0.6, 1.2, 1, 6, 4)
	# szakáll: nagy, két fonattal
	lsphere(rig, 0.21, beard, 0, 0.5, 0.13, 1.2, 0.95, 0.72, 9, 6)
	lcone(rig, 0.16, 0.24, beard, 0, 0.33, 0.2, 5, Vector3(PI + 0.2, 0, 0))
	for s in [-1, 1]:
		lsphere(rig, 0.1, beard, s * 0.19, 0.56, 0.08, 0.8, 1.3, 1, 7, 5)
		for k in 3:
			lsphere(rig, 0.052 - k * 0.006, beard_d if k % 2 else beard, s * 0.115, 0.36 - k * 0.075, 0.27 - k * 0.01, 1, 1.1, 1, 6, 4)
		lcyl(rig, 0.04, 0.04, 0.035, gold, s * 0.115, 0.155, 0.245, 6)
		lsphere(rig, 0.03, beard, s * 0.115, 0.12, 0.245, 1, 1.3, 1, 5, 3)
		# bajusz, szemöldök
		lsphere(rig, 0.062, beard_d, s * 0.085, 0.575, 0.245, 1.7, 0.75, 0.8, 6, 4).rotation.z = -s * 0.4
		box(rig, 0.11, 0.04, 0.045, beard_d, Vector3(s * 0.09, 0.755, 0.205), Vector3(0.2, 0, -s * 0.28))
	lsphere(rig, 0.07, mat("#eda77c"), 0, 0.635, 0.255, 1.05, 1, 1, 7, 5)
	var e := eyes(rig, 0.695, 0.215, 0.088, 0.046)
	# szarvas sisak
	lsphere(rig, 0.225, steel, 0, 0.77, -0.04, 1.03, 0.95, 1, 10, 7)
	lcyl(rig, 0.228, 0.232, 0.045, gold, 0, 0.8, -0.035, 10)
	box(rig, 0.045, 0.2, 0.03, gold, Vector3(0, 0.9, 0.17), Vector3(-0.72, 0, 0))
	for s in [-1, 1]:
		lcyl(rig, 0.055, 0.06, 0.045, gold, s * 0.215, 0.86, -0.04, 6, Vector3(0, 0, -s * 1.0))
		lcyl(rig, 0.035, 0.052, 0.11, mat("#f5ecd7"), s * 0.275, 0.9, -0.04, 6, Vector3(0, 0, -s * 0.8))
		lcone(rig, 0.035, 0.12, mat("#f5ecd7"), s * 0.335, 0.99, -0.04, 6, Vector3(0, 0, -s * 0.25))
	# csákány a vállon
	var pick := grp(arms[1], Vector3(0, -0.24, 0.02), Vector3(-0.75, 0, -0.5))
	lcyl(pick, 0.024, 0.026, 0.66, mat("#8a5a2b"), 0, 0.2, 0, 6)
	part(pick, prism([[-0.24, -0.06], [-0.07, 0.045], [0.07, 0.045], [0.24, -0.06], [0.06, -0.035], [-0.06, -0.035]], 0.045), steel, Vector3(0, 0.5, 0))
	lcyl(pick, 0.035, 0.035, 0.07, steel, 0, 0.495, 0, 6)
	# kincs a másik kézben
	var gem := lsphere(arms[0], 0.07, mat("#22d3ee", {"rough": 0.1, "emit": "#22d3ee", "emit_e": 0.7}), 0, -0.34, 0.03, 0.8, 1.2, 0.8, 5, 2)
	return {"eyes": e, "tick": func(t): gem.rotation.y = t * 2.0}


static func _ship(rig: Node3D) -> Dictionary:
	var wood := mat("#8b5a2b", {"rough": 0.8})
	var wood_d := mat("#5c3d1e", {"rough": 0.8})
	var cream := mat("#f6e7c8", {"rough": 0.8})
	var sail := mat("#fffaf0", {"rough": 0.9})
	var red := mat("#e11d48", {"rough": 0.6})
	var gold := mat("#ffd43b", {"metal": 0.7, "rough": 0.28})
	var iron := mat("#2f3640", {"metal": 0.5, "rough": 0.45})
	# víz és tajték
	lcyl(rig, 0.43, 0.45, 0.06, mat("#3b9cf0", {"rough": 0.25}), 0, 0.03, 0.02, 12)
	lcyl(rig, 0.33, 0.36, 0.02, mat("#7cc4ff", {"rough": 0.25}), 0, 0.065, 0.02, 12)
	var foam := mat("#ffffff", {"rough": 0.9})
	var foams: Array = []
	for d in [[0.1, 0.4, 0.05], [-0.1, 0.4, 0.05], [0.2, 0.25, 0.04], [-0.2, 0.25, 0.04], [0.23, -0.2, 0.035], [-0.23, -0.2, 0.035], [0, -0.4, 0.045]]:
		foams.append(lsphere(rig, d[2], foam, d[0], 0.075, d[1], 1.3, 0.6, 1.3, 6, 4))
	var ship := grp(rig, Vector3(0, 0.02, 0))
	# hajótest: fa felső rész, világos fenék
	var st := [[-0.38, 0.17, 0.44, 0.24], [-0.24, 0.23, 0.38, 0.13], [0.0, 0.25, 0.33, 0.09], [0.2, 0.21, 0.34, 0.11], [0.36, 0.11, 0.38, 0.18], [0.47, 0.012, 0.43, 0.3]]
	var up: Array = []
	var low: Array = []
	for s in st:
		var z: float = s[0]
		var w: float = s[1]
		var mid := lerpf(s[3], s[2], 0.45)
		up.append([Vector3(-w, s[2], z), Vector3(-w * 0.9, mid, z), Vector3(w * 0.9, mid, z), Vector3(w, s[2], z)])
		low.append([Vector3(-w * 0.9, mid, z), Vector3(0, s[3], z), Vector3(w * 0.9, mid, z)])
	part(ship, loft(up, Vector3(0, 0.3, 0)), wood)
	part(ship, loft(low, Vector3(0, 0.2, 0)), cream)
	# korlát, palánk-csík, ágyúk
	for i in st.size() - 1:
		for s in [-1, 1]:
			var a := Vector3(s * st[i][1], st[i][2] + 0.015, st[i][0])
			var b := Vector3(s * st[i + 1][1], st[i + 1][2] + 0.015, st[i + 1][0])
			var rail := box(ship, 0.035, 0.035, a.distance_to(b) + 0.02, gold, (a + b) / 2)
			rail.basis = Basis.looking_at(b - a, Vector3.UP)
	for s in [-1, 1]:
		for z in [-0.12, 0.1]:
			lcyl(ship, 0.028, 0.034, 0.1, iron, s * 0.25, 0.27, z, 6, Vector3(0, 0, s * PI / 2))
			box(ship, 0.02, 0.085, 0.085, wood_d, Vector3(s * 0.225, 0.27, z))
	# tatfelépítmény ablakokkal, kormánylapát
	box(ship, 0.32, 0.12, 0.17, wood_d, Vector3(0, 0.455, -0.3))
	box(ship, 0.36, 0.025, 0.2, gold, Vector3(0, 0.525, -0.3))
	var win := mat("#ffe066", {"emit": "#ffd43b", "emit_e": 1.0})
	for i in [-1, 0, 1]:
		box(ship, 0.06, 0.06, 0.02, win, Vector3(i * 0.09, 0.455, -0.388))
	for s in [-1, 1]:
		box(ship, 0.02, 0.05, 0.05, win, Vector3(s * 0.162, 0.46, -0.3))
	box(ship, 0.025, 0.2, 0.09, wood_d, Vector3(0, 0.22, -0.41))
	# orrdísz és orrárboc
	lsphere(ship, 0.04, gold, 0, 0.44, 0.475, 1, 1, 1, 6, 4)
	lcyl(ship, 0.012, 0.018, 0.26, wood_d, 0, 0.5, 0.55, 6, Vector3(1.15, 0, 0))
	# árboc, vitorlarudak, árbockosár
	lcyl(ship, 0.02, 0.028, 0.72, wood_d, 0, 0.68, 0.02, 6)
	box(ship, 0.56, 0.026, 0.026, wood_d, Vector3(0, 0.8, 0.045))
	box(ship, 0.5, 0.024, 0.024, wood_d, Vector3(0, 0.43, 0.045))
	box(ship, 0.36, 0.024, 0.024, wood_d, Vector3(0, 0.99, 0.045))
	lcyl(ship, 0.055, 0.04, 0.05, wood, 0, 0.87, 0.02, 8)
	# vitorlák: a nagyvitorlán az arc
	var main := grp(ship, Vector3(0, 0.615, 0.075))
	part(main, prism([[-0.27, 0.18], [0.27, 0.18], [0.24, -0.18], [-0.24, -0.18]], 0.03), sail)
	part(main, prism([[-0.25, 0.14], [0.25, 0.14], [0.225, -0.14], [-0.225, -0.14]], 0.03), sail, Vector3(0, 0, 0.022))
	for yy in [-0.155, 0.155]:
		box(main, 0.5, 0.03, 0.034, red, Vector3(0, yy, 0.004))
	var e := eyes(main, 0.03, 0.05, 0.1, 0.062)
	smile(main, -0.055, 0.043, 0.04)
	cheeks(main, -0.04, 0.04, 0.17, 0.035)
	part(ship, prism([[-0.17, 0.07], [0.17, 0.07], [0.15, -0.07], [-0.15, -0.07]], 0.028), sail, Vector3(0, 0.905, 0.07))
	box(ship, 0.31, 0.03, 0.032, red, Vector3(0, 0.905, 0.073))
	# orrvitorla
	part(ship, prism([[0.06, 0.93], [0.06, 0.5], [0.6, 0.47]], 0.014), cream, Vector3(0, 0, 0.02), Vector3.ONE, Vector3(0, -PI / 2, 0))
	# zászló
	var flag := grp(ship, Vector3(0, 1.06, 0.02))
	part(flag, prism([[0, 0.045], [0.16, 0.0], [0, -0.045]], 0.012), red)
	lsphere(ship, 0.025, gold, 0, 1.05, 0.02, 1, 1, 1, 6, 4)
	return {"eyes": e, "tick": func(t):
		ship.rotation.z = sin(t * 2.0) * 0.07
		ship.rotation.x = sin(t * 1.5) * 0.045
		ship.position.y = 0.02 + sin(t * 2.0 + 1.0) * 0.012
		flag.rotation.y = sin(t * 5.0) * 0.5
		for i in foams.size():
			foams[i].position.y = 0.075 + sin(t * 3.0 + i * 1.3) * 0.012}
