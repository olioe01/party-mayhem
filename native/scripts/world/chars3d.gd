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


class CharModel:
	extends Node3D
	var rig: Node3D
	var eyes: Array = []
	var tick_fn: Callable = func(_t): pass
	var char_id := ""
	var phase := randf() * 10.0
	var blink_at := 1.0 + randf() * 3.0
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
				blink_at = t + 2.0 + randf() * 3.0
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


static func _cat(rig: Node3D) -> Dictionary:
	var fur := mat("#f2a541")
	var cream := mat("#fff1d6")
	var black := mat("#1f1b2e", {"rough": 0.3})
	sphere(rig, 0.28, fur, 0, 0.3, 0, 1, 1.05, 0.95)
	sphere(rig, 0.2, cream, 0, 0.27, 0.12, 1, 1, 0.6)
	sphere(rig, 0.3, fur, 0, 0.72, 0.02)
	for s in [-1, 1]:
		cone(rig, 0.11, 0.22, fur, s * 0.17, 0.98, 0, 4, Vector3(0, 0, -s * 0.35))
		cone(rig, 0.06, 0.13, mat("#ff9fb5"), s * 0.165, 0.96, 0.04, 4, Vector3(0, 0, -s * 0.35))
		for k in [-1, 1]:
			box(rig, 0.2, 0.01, 0.01, black, Vector3(s * 0.2, 0.66 + k * 0.03, 0.27), Vector3(0, 0, s * k * 0.15))
	var e := eyes(rig, 0.76, 0.27, 0.11, 0.075)
	sphere(rig, 0.035, mat("#ff9fb5"), 0, 0.68, 0.3)
	smile(rig, 0.64, 0.28, 0.035)
	var tail := part(rig, arc_tube(0.2, 0.05, PI * 1.2), fur, Vector3(0.12, 0.35, -0.24), Vector3.ONE, Vector3(0, PI / 2, 0))
	return {"eyes": e, "tick": func(t): tail.rotation.x = sin(t * 3.0) * 0.3}


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


static func _queen(rig: Node3D) -> Dictionary:
	var dress := mat("#8b5cf6")
	var trim := mat("#fde68a", {"metal": 0.5, "rough": 0.3})
	var skin := mat("#ffd7b0")
	var hair := mat("#7a3e1d")
	part(rig, lathe([[0, 0], [0.36, 0], [0.34, 0.08], [0.26, 0.3], [0.16, 0.48], [0.13, 0.58], [0, 0.6]]), dress)
	part(rig, torus(0.35, 0.03), trim, Vector3(0, 0.04, 0))
	part(rig, torus(0.11, 0.022), trim, Vector3(0, 0.6, 0))
	for s in [-1, 1]:
		var arm := sphere(rig, 0.06, dress, s * 0.2, 0.42, 0.04, 0.8, 1.8, 0.8)
		arm.rotation.z = s * 0.5
	sphere(rig, 0.21, hair, 0, 0.82, -0.04, 1.05, 1.05, 1)
	sphere(rig, 0.19, skin, 0, 0.8, 0.03)
	sphere(rig, 0.1, hair, 0, 0.9, -0.2)
	var e := eyes(rig, 0.82, 0.19, 0.07, 0.045)
	cheeks(rig, 0.75, 0.18, 0.12, 0.035)
	smile(rig, 0.74, 0.205, 0.03, mat("#c0392b"))
	cyl(rig, 0.12, 0.12, 0.04, trim, 0, 1.0, 0, 20)
	for i in [-1, 0, 1]:
		cone(rig, 0.03, 0.12 if i == 0 else 0.08, trim, i * 0.07, 1.06 + (0.02 if i == 0 else 0.0), 0.08, 6)
	sphere(rig, 0.025, mat("#e11d48", {"rough": 0.2}), 0, 1.12, 0.09)
	return {"eyes": e}


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
