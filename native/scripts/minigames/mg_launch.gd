extends Minigame
## Tűzijáték-pumpa: éjszakai városi tér, négy kézi pumpás rakétaállomás.
## 10 másodpercig mindenki pumpál (gyors koppintás), a töltés a mérőoszlopban látszik.
## Aztán a rakéták egyszerre kilőnek, a kamera követi őket az égbe; ki repül a legmagasabbra?

const K = preload("res://scripts/minigames/mg_kit.gd")
const W = preload("res://scripts/minigames/presents_world.gd")

const PUMP_TIME := 10.0
const PREP := 1.5
const PUMP_FULL := 80.0           # ennyi pumpálás tölti ki a mérőt (100%)
const LUCK := 0.025               # a magasság legfeljebb ±2,5%-ban véletlen
const ALT_MIN := 5.0
const ALT_K := 23.0
const GAP := 3.4
const BASE_SCALE := 1.6
const HANDLE_UP := 0.8
const HANDLE_TRAVEL := 0.3
const SEGS := 16
const METER_H := 2.4
const METER_Y := 0.35
const CAM_Y := 1.9
const FOV := 50.0
const TRAIL_COLS := ["#4dabf7", "#ffd43b", "#ff5c8a", "#51cf66"]
const BURST_COLS := [["#a5d8ff", "#3b82f6", "#e7f5ff"], ["#fff3bf", "#ffb300", "#ff6b00"], ["#ffc9de", "#ff2d6f", "#c084fc"], ["#d3f9d8", "#2fb344", "#a9e34b"]]
const METER_STYLE := [
	{"a": "#7c3aed", "b": "#c4a1ff", "glow": "#d0bfff", "rings": false},     # lila, világító vízszintes csíkok
	{"a": "#2fb344", "b": "#20c9b7", "glow": "#96f2d7", "rings": false},     # zöld-türkiz váltakozó csíkok
	{"a": "#1c6ee8", "b": "#3b8cff", "glow": "#a5d8ff", "rings": true},      # kék, körkörös díszek
	{"a": "#ff8c1a", "b": "#ffd43b", "glow": "#fff3bf", "rings": false},     # sárga-narancs, izzó csíkok
]
const AI_RATE := [[4.8, 6.0], [6.4, 7.6], [7.8, 9.0]]

var pl: Array = []
var stage := "pump"               # pump | prep | flight | react
var stage_t0 := 0.0
var h_track := 0.0
var h_target := 0.0
var react_t0 := -1.0
var last_boom := 0.0
var flashes: Array = []
var stars: MultiMeshInstance3D
var msg_text := ""
var msg_col := Color.WHITE
var msg_t0 := -10.0
var msg_dur := 1.2


func meta() -> Dictionary:
	return {"id": "launch", "name": "Tűzijáték-pumpa", "icon": "🎆", "color": "#7c3aed", "modes": ["ffa"],
		"tagline": "Pumpáld fel a rakétát!",
		"desc": "Éjszaka a városi téren mindenki a saját rakétáját pumpálja. Minél jobban feltöltöd a mérőt, annál magasabbra repül a rakétád – és annál nagyobb tűzijáték lesz belőle. A legmagasabbra jutó nyer!",
		"controls": "10 másodpercig koppints a nagy gombra olyan gyorsan, ahogy csak tudsz! Minden koppintás egy pumpálás."}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "🔥 PUMPÁLJ!", "hint": "Koppints gyorsan, ahogy csak bírsz!", "rapid": true}


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	make_env("#040818", "#17244f", 0.3)
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3f4f96")
	env.ambient_light_energy = 0.42
	make_camera(Vector3(0, CAM_Y + 0.7, 9.8), Vector3(0, 2.2, 0), FOV)
	cam.far = 600.0
	var moon := make_sun(Vector3(-38, 28, 0), 0.22, "#8fa6ff")
	moon.shadow_enabled = true
	_build_city()
	var all := players.duplicate()
	var n := all.size()
	var ai_k := 0
	for i in n:
		var p = all[i]
		var cpu := not players.has(p)
		var lvl := 1
		if cpu or p.is_bot:
			lvl = K.ai_level(ai_k)
			ai_k += 1
		pl.append(_make_station(p, i, (i - (n - 1) / 2.0) * GAP, cpu, lvl))
	_sync(0.0)


func _build_city() -> void:
	# kövezet
	var tile := StandardMaterial3D.new()
	tile.albedo_texture = _stone_tex()
	tile.uv1_scale = Vector3(40, 40, 1)
	tile.roughness = 0.35
	tile.metallic_specular = 0.7
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	ground.material_override = tile
	ground.position = Vector3(0, 0, 30)
	add_child(ground)
	# járdaszegély a házak előtt
	Chars3D.box(self, 80, 0.18, 1.2, Chars3D.mat("#3c4357", {"rough": 0.7}), Vector3(0, 0.09, -9.4))
	# házsor
	var walls := ["#f1d7a7", "#e9a17b", "#cfd9e6", "#f4c95d", "#d9a7c7", "#a9d1c3", "#f0b78a", "#e6d2b5", "#b9c8f0"]
	var roofs := ["#7a2f2f", "#3d4a6b", "#5b3a29", "#2f4f6f"]
	var x := -27.0
	var k := 0
	while x < 27.0:
		var w: float = [4.4, 5.2, 3.8, 6.0, 4.8][k % 5]
		var h: float = [8.0, 9.6, 7.2, 10.2, 8.8, 6.8][k % 6]
		_house(x + w / 2, -12.5 - (k % 2) * 0.8, w, h, walls[k % walls.size()], roofs[k % roofs.size()], k)
		x += w + 0.15
		k += 1
	# fák és lámpák
	for tx in [-11.5, -6.0, 6.0, 11.5]:
		W._tree(self, tx, -7.5, 1.15)
	for lx in [-8.5, 0.0, 8.5]:
		_lamp(lx, -6.8)
	for lx in [-13.0, 13.0]:
		_lamp(lx, 2.0)
	# égbolt: hold, csillagok, felhők
	var moon_m := Chars3D.mat("#fff8dc", {"emit": "#fff1b8", "emit_e": 1.6, "unshaded": true})
	Chars3D.sphere(self, 4.0, moon_m, 38, 95, -120)
	_build_stars()
	var cloud_m := Chars3D.mat("#4a5a86", {"alpha": 0.55, "unshaded": true})
	var cloud_m2 := Chars3D.mat("#36446e", {"alpha": 0.5, "unshaded": true})
	for i in 9:
		var cx := -60.0 + i * 15.0
		var cy := 28.0 + (i % 3) * 14.0
		var cz := -70.0 - (i % 2) * 20.0
		for j in 4:
			var mi := Chars3D.sphere(self, 4.5 + (j % 2) * 1.5, cloud_m if j % 2 == 0 else cloud_m2, cx + (j - 1.5) * 5.0, cy + sin(i + j) * 1.2, cz, 1.6, 0.45, 0.6)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _house(cx: float, z: float, w: float, h: float, wall_hex: String, roof_hex: String, k: int) -> void:
	var g := Chars3D.grp(self, Vector3(cx, 0, z))
	var wall := Chars3D.mat(Color(wall_hex).darkened(0.42).to_html(), {"rough": 0.8})
	var trim := Chars3D.mat("#8f8a7c", {"rough": 0.6})
	var d := 5.0
	Chars3D.box(g, w, h, d, wall, Vector3(0, h / 2, 0))
	Chars3D.box(g, w + 0.25, 0.25, d + 0.25, trim, Vector3(0, h, 0))
	Chars3D.box(g, w + 0.1, 0.18, d + 0.1, trim, Vector3(0, 3.1, 0))
	Chars3D.box(g, w, 0.9, 0.12, wall, Vector3(0, 0.45, d / 2 + 0.03))
	# tető: háromszög hasáb
	var roof := MeshInstance3D.new()
	roof.mesh = Chars3D.prism([[-w / 2 - 0.3, 0], [w / 2 + 0.3, 0], [0, 2.2 + (k % 3) * 0.5]], d + 0.4)
	roof.material_override = Chars3D.mat(roof_hex, {"rough": 0.6})
	roof.position = Vector3(0, h + 0.12, 0)
	g.add_child(roof)
	if k % 3 == 1:
		Chars3D.box(g, 0.5, 1.4, 0.5, Chars3D.mat("#8a4a3a"), Vector3(w * 0.25, h + 1.4, -0.6))
	# ablakok: meleg sárga fény (a legtöbb világít), a földszinten bolt és kapu
	var lit := Chars3D.mat("#ffcf6e", {"emit": "#ffb43c", "emit_e": 1.7})
	var dark := Chars3D.mat("#22305a", {"rough": 0.3, "metal": 0.3})
	var frame := Chars3D.mat("#3a2a20", {"rough": 0.7})
	var cols: int = max(2, int(w / 1.35))
	var floors: int = max(2, int((h - 3.4) / 2.2))
	for f in floors:
		for c in cols:
			var wx: float = (c - (cols - 1) / 2.0) * (w / cols)
			var wy: float = 4.3 + f * 2.2
			if wy > h - 0.8:
				continue
			var on := (k * 7 + f * 3 + c * 5) % 9 > 1
			Chars3D.box(g, 0.78, 1.18, 0.06, frame, Vector3(wx, wy, d / 2 + 0.02))
			var win := Chars3D.box(g, 0.62, 1.02, 0.06, lit if on else dark, Vector3(wx, wy, d / 2 + 0.05))
			win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# íves ablakfej
			Chars3D.cyl(g, 0.39, 0.39, 0.08, frame, wx, wy + 0.58, d / 2 + 0.02, 12, Vector3(PI / 2, 0, 0))
			Chars3D.box(g, 0.9, 0.08, 0.22, trim, Vector3(wx, wy - 0.64, d / 2 + 0.1))
	# földszint: kirakat és ajtó
	Chars3D.box(g, w * 0.55, 1.6, 0.06, lit, Vector3(-w * 0.12, 1.5, d / 2 + 0.05))
	Chars3D.box(g, 0.9, 2.0, 0.08, Chars3D.mat("#5b3a29"), Vector3(w * 0.33, 1.0, d / 2 + 0.05))
	Chars3D.box(g, w * 0.62, 0.12, 0.6, Chars3D.mat(["#e03131", "#2f9e44", "#1c7ed6", "#f08c00"][k % 4]), Vector3(-w * 0.12, 2.45, d / 2 + 0.3), Vector3(0.35, 0, 0))


func _lamp(x: float, z: float) -> void:
	var iron := Chars3D.mat("#1f2633", {"rough": 0.4, "metal": 0.6})
	Chars3D.cyl(self, 0.2, 0.26, 0.4, iron, x, 0.2, z, 10)
	Chars3D.cyl(self, 0.07, 0.09, 3.6, iron, x, 2.0, z, 8)
	Chars3D.cyl(self, 0.22, 0.12, 0.16, iron, x, 3.85, z, 8)
	Chars3D.sphere(self, 0.28, Chars3D.mat("#fff2c4", {"emit": "#ffc65a", "emit_e": 3.0, "unshaded": true}), x, 4.15, z)
	Chars3D.cone(self, 0.3, 0.3, iron, x, 4.5, z, 8)
	var l := OmniLight3D.new()
	l.position = Vector3(x, 4.1, z)
	l.light_color = Color("#ffc46b")
	l.light_energy = 2.6
	l.omni_range = 10.0
	l.omni_attenuation = 1.2
	add_child(l)


func _build_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 4
	sm.rings = 2
	mm.mesh = sm
	mm.instance_count = 260
	var rnd := BoardLayout.Seeded.new(4242)
	for i in mm.instance_count:
		var az: float = rnd.next() * PI - PI
		var el: float = 0.12 + rnd.next() * 1.35
		var r := 260.0
		var pos := Vector3(cos(el) * sin(az) * r, sin(el) * r, -abs(cos(el) * cos(az)) * r - 40.0)
		var s: float = 0.5 + rnd.next() * 1.2
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
	stars = MultiMeshInstance3D.new()
	stars.multimesh = mm
	stars.material_override = Chars3D.mat("#ffffff", {"emit": "#dfe8ff", "emit_e": 2.0, "unshaded": true})
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)


static var _stone: ImageTexture


static func _stone_tex() -> ImageTexture:
	if _stone:
		return _stone
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rnd := BoardLayout.Seeded.new(77)
	for y in n:
		for x in n:
			var c := Color("#4c5368")
			var off := 16 if y >= 16 else 0
			if y % 16 == 0 or (x + off) % 32 == 0 or (x + off) % 32 == 31:
				c = Color("#2c3040")
			else:
				c = c.darkened(rnd.next() * 0.12)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_stone = ImageTexture.create_from_image(img)
	return _stone


func _make_station(p, i: int, x: float, cpu: bool, lvl: int) -> Dictionary:
	var st: Dictionary = METER_STYLE[i % 4]
	var col := Color(K.SLOT_COLORS[i % K.SLOT_COLORS.size()])
	var g := Chars3D.grp(self, Vector3(x, 0, 0))
	var metal := Chars3D.mat("#c9d1dc", {"rough": 0.25, "metal": 0.75})
	var dark_m := Chars3D.mat("#2b3140", {"rough": 0.4, "metal": 0.4})
	# talapzat lánggal az elején
	var px := -0.62
	Chars3D.box(g, 0.62, 0.3, 0.5, Chars3D.mat(col.darkened(0.25).to_html(), {"rough": 0.45}), Vector3(px, 0.15, 0.6))
	Chars3D.box(g, 0.68, 0.05, 0.56, metal, Vector3(px, 0.32, 0.6))
	var flame := MeshInstance3D.new()
	flame.mesh = Chars3D.prism([[0, 0.17], [0.07, 0.02], [0.11, -0.08], [0.06, -0.15], [0, -0.17], [-0.06, -0.15], [-0.11, -0.08], [-0.07, 0.02]], 0.03)
	flame.material_override = Chars3D.mat("#ff922b", {"emit": "#ff6b00", "emit_e": 2.2})
	flame.position = Vector3(px, 0.15, 0.86)
	flame.scale = Vector3.ONE * 0.75
	g.add_child(flame)
	Chars3D.sphere(flame, 0.05, Chars3D.mat("#ffe066", {"emit": "#ffd43b", "emit_e": 2.5}), 0, -0.07, 0.02)
	# pumpatest, rúd, T-fogantyú
	Chars3D.cyl(g, 0.11, 0.13, 0.22, Chars3D.mat("#e03131", {"rough": 0.35}), px, 0.44, 0.6, 12)
	Chars3D.cyl(g, 0.13, 0.13, 0.04, metal, px, 0.56, 0.6, 12)
	var handle := Chars3D.grp(g, Vector3(px, HANDLE_UP, 0.6))
	Chars3D.cyl(handle, 0.03, 0.03, 0.5, metal, 0, -0.25, 0, 8)
	Chars3D.cyl(handle, 0.05, 0.05, 0.55, Chars3D.mat("#ffd43b", {"rough": 0.4}), 0, 0, 0, 10, Vector3(0, 0, PI / 2))
	for sx in [-1, 1]:
		Chars3D.sphere(handle, 0.065, dark_m, sx * 0.29, 0, 0)
	# tömlő a pumpától a mérőig
	var hose := W.seg(g, 0.045, Chars3D.mat("#343a40", {"rough": 0.8}), Vector3(px + 0.12, 0.4, 0.6), Vector3(0.38, 0.3, 0.2))
	hose.name = "hose"
	# mérőoszlop: üvegcső, benne szegmensekben feltöltődő színes csíkok
	var mx := 0.42
	Chars3D.cyl(g, 0.42, 0.48, 0.35, dark_m, mx, 0.175, 0.1, 14)
	Chars3D.cyl(g, 0.36, 0.36, 0.05, metal, mx, 0.36, 0.1, 14)
	var segs: Array = []
	var seg_h := METER_H / SEGS
	for k in SEGS:
		var hex: String = st.a if k % 2 == 0 else st.b
		var m := Chars3D.mat(hex, {"emit": hex, "emit_e": 0.9})
		var sg := Chars3D.cyl(g, 0.26, 0.26, seg_h * 0.86, m, mx, METER_Y + seg_h * (k + 0.5), 0.1, 14)
		sg.visible = false
		var ring: MeshInstance3D = null
		if st.rings and k % 2 == 1:
			ring = Chars3D.part(sg, Chars3D.torus(0.27, 0.025), Chars3D.mat(st.glow, {"emit": st.glow, "emit_e": 2.0}))
		elif k % 2 == 0:
			ring = Chars3D.cyl(sg, 0.265, 0.265, seg_h * 0.18, Chars3D.mat(st.glow, {"emit": st.glow, "emit_e": 2.4}), 0, 0, 0, 14)
		segs.append({"n": sg, "ring": ring, "on_t": -10.0})
	var glass := Chars3D.cyl(g, 0.32, 0.32, METER_H + 0.06, Chars3D.mat("#cfe8ff", {"alpha": 0.22, "rough": 0.05, "metal": 0.2}), mx, METER_Y + METER_H / 2, 0.1, 16)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 5:
		Chars3D.cyl(g, 0.335, 0.335, 0.03, metal, mx, METER_Y + METER_H * k / 4.0, 0.1, 16)
	Chars3D.cyl(g, 0.38, 0.33, 0.12, metal, mx, METER_Y + METER_H + 0.06, 0.1, 16)
	# rakéta a mérő tetején
	var rocket := _build_rocket(i)
	var r_base := Vector3(x + mx, METER_Y + METER_H + 0.12, 0.1)
	rocket.position = r_base
	add_child(rocket)
	var trail := _trail(Color(TRAIL_COLS[i % 4]))
	add_child(trail)
	var burst := _burst_set(i)
	# figura a pumpa mögött
	var m := player_model(p, BASE_SCALE)
	m.position = Vector3(x + px, 0, 0.02)
	var disc := color_disc(p, 0.6)
	disc.position = Vector3(x + px, 0.02, 0.02)
	add_child(disc)
	var s := {"p": p, "cpu": cpu, "lvl": lvl, "i": i, "x": x, "px": px, "col": col, "g": g, "m": m, "handle": handle,
		"segs": segs, "rocket": rocket, "r_base": r_base, "trail": trail, "burst": burst,
		"pumps": 0, "stroke_t0": -10.0, "amp": 1.0, "lean": 0.0, "next_tap": randf_range(0.15, 0.4),
		"alt": 0.0, "launch_at": 0.0, "dur": 1.0, "y": 0.0, "boom_t": -1.0, "flying": false, "place": -1,
		"look": 0.0, "arms": K.build_arms(m, col.to_html(), 0.42), "face": K.build_face(m), "rain": null}
	return s


func _build_rocket(i: int) -> Node3D:
	var r := Node3D.new()
	var tc := Color(TRAIL_COLS[i % 4])
	var white := Chars3D.mat("#f8f9fa", {"rough": 0.35})
	var colm := Chars3D.mat(tc.to_html(), {"rough": 0.35})
	Chars3D.cyl(r, 0.17, 0.17, 0.85, white, 0, 0.5, 0, 14)
	Chars3D.cyl(r, 0.175, 0.175, 0.16, colm, 0, 0.3, 0, 14)
	Chars3D.cyl(r, 0.175, 0.175, 0.08, colm, 0, 0.72, 0, 14)
	Chars3D.cone(r, 0.17, 0.42, colm, 0, 1.13, 0, 14)
	Chars3D.sphere(r, 0.07, Chars3D.mat("#ffffff", {"emit": tc.lightened(0.4).to_html(), "emit_e": 4.0, "unshaded": true}), 0, 1.36, 0)
	for k in 3:
		var a := TAU * k / 3.0
		var fin := MeshInstance3D.new()
		fin.mesh = Chars3D.prism([[0, 0], [0.22, -0.12], [0.22, 0.12], [0, 0.32]], 0.04)
		fin.material_override = colm
		fin.position = Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15)
		fin.rotation = Vector3(0, -a, 0)
		r.add_child(fin)
	Chars3D.cyl(r, 0.11, 0.14, 0.08, Chars3D.mat("#495057", {"metal": 0.6, "rough": 0.3}), 0, 0.04, 0, 10)
	# kanóc: szikrázik az indulás előtt
	var fuse := CPUParticles3D.new()
	fuse.emitting = false
	fuse.amount = 24
	fuse.lifetime = 0.35
	fuse.mesh = _spark_mesh(0.05)
	fuse.direction = Vector3(0, -1, 0)
	fuse.spread = 70.0
	fuse.initial_velocity_min = 1.0
	fuse.initial_velocity_max = 2.5
	fuse.gravity = Vector3(0, -4, 0)
	fuse.color_ramp = _ramp([Color(3, 2.6, 1.2), Color(2.5, 1.0, 0.2), Color(1, 0.3, 0, 0)])
	fuse.name = "fuse"
	r.add_child(fuse)
	return r


func _spark_mesh(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _dot_tex()
	q.material = m
	return q


static var _dot: ImageTexture


static func _dot_tex() -> ImageTexture:
	if _dot:
		return _dot
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot = ImageTexture.create_from_image(img)
	return _dot


func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cc := PackedColorArray()
	for k in cols.size():
		offs.append(float(k) / (cols.size() - 1))
		cc.append(cols[k])
	g.offsets = offs
	g.colors = cc
	return g


func _trail(col: Color) -> CPUParticles3D:
	var tr := CPUParticles3D.new()
	tr.emitting = false
	tr.amount = 140
	tr.lifetime = 1.1
	tr.local_coords = false
	tr.mesh = _spark_mesh(0.42)
	tr.direction = Vector3(0, -1, 0)
	tr.spread = 12.0
	tr.initial_velocity_min = 1.5
	tr.initial_velocity_max = 3.0
	tr.gravity = Vector3(0, -1.0, 0)
	tr.damping_min = 1.0
	tr.damping_max = 2.0
	tr.scale_amount_min = 0.7
	tr.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0.2))
	tr.scale_amount_curve = sc
	var hot := Color(col.r * 1.6, col.g * 1.6, col.b * 1.6)
	tr.color_ramp = _ramp([Color(2.0, 2.0, 1.8), hot, Color(col.r, col.g, col.b, 0.5), Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, 0)])
	return tr


## Tűzijáték-készlet egy rakétához (előre elkészítve, újrahasznosítva): fő gömb, csíkok, füst, villanófény.
func _burst_set(i: int) -> Dictionary:
	var cols: Array = BURST_COLS[i % 4]
	var main := CPUParticles3D.new()
	main.one_shot = true
	main.emitting = false
	main.explosiveness = 0.95
	main.amount = 160
	main.lifetime = 2.0
	main.local_coords = false
	main.mesh = _spark_mesh(0.85)
	main.direction = Vector3(0, 1, 0)
	main.spread = 180.0
	main.gravity = Vector3(0, -2.6, 0)
	main.damping_min = 2.2
	main.damping_max = 3.0
	var c0 := Color(cols[0])
	var c1 := Color(cols[1])
	var c2 := Color(cols[2])
	main.color_ramp = _ramp([Color(2.2, 2.2, 2.2), Color(c0.r * 1.5, c0.g * 1.5, c0.b * 1.5), Color(c1.r * 1.35, c1.g * 1.35, c1.b * 1.35), Color(c1.r, c1.g, c1.b, 0.6), Color(c1.r, c1.g, c1.b, 0)])
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.2))
	sc.add_point(Vector2(0.7, 0.8))
	sc.add_point(Vector2(1, 0.1))
	main.scale_amount_curve = sc
	match i % 4:
		1:    # gyűrű
			main.flatness = 1.0
			main.direction = Vector3(0, 0, 1)
		2:    # szomorúfűz: lassabb, hosszan lehulló arany szikrák
			main.gravity = Vector3(0, -5.5, 0)
			main.lifetime = 2.8
			main.damping_min = 1.2
			main.damping_max = 1.6
	add_child(main)
	var streak := CPUParticles3D.new()
	streak.one_shot = true
	streak.emitting = false
	streak.explosiveness = 1.0
	streak.amount = 60
	streak.lifetime = 1.3
	streak.local_coords = false
	streak.mesh = _spark_mesh(0.55)
	streak.direction = Vector3(0, 1, 0)
	streak.spread = 180.0
	streak.gravity = Vector3(0, -1.5, 0)
	streak.damping_min = 1.0
	streak.damping_max = 1.4
	streak.color_ramp = _ramp([Color(2.0, 2.0, 2.0), Color(c2.r * 1.5, c2.g * 1.5, c2.b * 1.5), Color(c2.r, c2.g, c2.b, 0)])
	add_child(streak)
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.emitting = false
	smoke.explosiveness = 0.9
	smoke.amount = 14
	smoke.lifetime = 2.2
	smoke.local_coords = false
	var sq := QuadMesh.new()
	sq.size = Vector2(2.2, 2.2)
	var smm := StandardMaterial3D.new()
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smm.vertex_color_use_as_albedo = true
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smm.albedo_texture = _dot_tex()
	sq.material = smm
	smoke.mesh = sq
	smoke.spread = 180.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.5
	smoke.gravity = Vector3(0, 0.3, 0)
	smoke.color_ramp = _ramp([Color(0.6, 0.6, 0.7, 0.0), Color(0.55, 0.55, 0.65, 0.35), Color(0.4, 0.4, 0.5, 0)])
	add_child(smoke)
	var light := OmniLight3D.new()
	light.light_color = c1.lightened(0.3)
	light.light_energy = 0.0
	light.omni_range = 30.0
	add_child(light)
	# indításkori füst a kilövőnél
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.explosiveness = 0.85
	puff.amount = 22
	puff.lifetime = 1.6
	puff.local_coords = false
	var pq := QuadMesh.new()
	pq.size = Vector2(1.1, 1.1)
	pq.material = smm
	puff.mesh = pq
	puff.direction = Vector3(0, 0.2, 0)
	puff.spread = 90.0
	puff.flatness = 0.6
	puff.initial_velocity_min = 1.2
	puff.initial_velocity_max = 2.6
	puff.damping_min = 1.5
	puff.damping_max = 2.5
	puff.gravity = Vector3(0, 0.6, 0)
	puff.color_ramp = _ramp([Color(1.0, 0.85, 0.6, 0.7), Color(0.75, 0.75, 0.8, 0.5), Color(0.5, 0.5, 0.6, 0)])
	add_child(puff)
	return {"main": main, "streak": streak, "smoke": smoke, "light": light, "puff": puff}


# ------------------------------------------------------------------ bemenet és gépek
func _get(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var s := _get(p)
	if not s.is_empty():
		_pump(s)


func bot(p, dt: float) -> void:
	var s := _get(p)
	if not s.is_empty():
		_ai(s, dt)


func _ai(s: Dictionary, dt: float) -> void:
	if stage != "pump":
		return
	s.next_tap -= dt
	if s.next_tap <= 0.0:
		_pump(s)
		var r: Array = AI_RATE[s.lvl]
		# a végére kicsit elfárad
		var tired: float = 1.0 - 0.12 * clamp(t / PUMP_TIME, 0.0, 1.0)
		s.next_tap += 1.0 / (randf_range(r[0], r[1]) * tired)


func _pump(s: Dictionary) -> void:
	if stage != "pump" or t >= PUMP_TIME:
		return
	var before := _filled(s)
	s.pumps += 1
	s.stroke_t0 = t
	s.amp = FX.fr(0.82, 1.0)
	Audio.play("pump", FX.fr(0.92, 1.08) + 0.15 * min(1.0, s.pumps / PUMP_FULL))
	var after := _filled(s)
	if after > before and after <= SEGS:
		(s.segs[after - 1] as Dictionary).on_t = t


func _charge(s: Dictionary) -> float:
	return s.pumps / PUMP_FULL


func _filled(s: Dictionary) -> int:
	return clampi(int(floor(_charge(s) * SEGS)), 0, SEGS)


# ------------------------------------------------------------------ játékmenet
func start() -> void:
	stage = "pump"
	stage_t0 = 0.0


func update(dt: float) -> void:
	for s in pl:
		if s.cpu:
			_ai(s, dt)
	match stage:
		"pump":
			if t >= PUMP_TIME:
				stage = "prep"
				stage_t0 = t
				_compute_flights()
				Audio.play("count_go")
				_say("Gyújtás!", Color("#ffd43b"), 1.2)
				for s in pl:
					if not s.cpu:
						Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🎆", "title": "Kilövés!", "text": "Nézd a rakétádat!"})
					((s.rocket as Node3D).get_node("fuse") as CPUParticles3D).emitting = true
			elif PUMP_TIME - t <= 3.0 and ceili(PUMP_TIME - t) != ceili(PUMP_TIME - t + dt):
				Audio.play("tick")
		"prep":
			for s in pl:
				if not s.flying and s.boom_t < 0 and t >= s.launch_at:
					_launch(s)
			if t - stage_t0 >= PREP:
				stage = "flight"
				stage_t0 = t
		"flight":
			var all_done := true
			for s in pl:
				if not s.flying and s.boom_t < 0 and t >= s.launch_at:
					_launch(s)
				if s.flying:
					var k: float = clamp((t - s.launch_at) / s.dur, 0.0, 1.0)
					s.y = s.alt * (1.0 - (1.0 - k) * (1.0 - k))
					if k >= 1.0:
						_explode(s)
				if s.boom_t < 0 or t - s.boom_t < 1.2:
					all_done = false
			if all_done:
				stage = "react"
				stage_t0 = t
				react_t0 = t
				_react()
		"react":
			if t - stage_t0 >= 5.0:
				finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


## Repülési magasság: fő tényező a töltés, a véletlen legfeljebb ±2,5%.
func _compute_flights() -> void:
	for s in pl:
		var c := _charge(s)
		s.alt = ALT_MIN + ALT_K * c * (1.0 + randf_range(-LUCK, LUCK))
		s.launch_at = PUMP_TIME + PREP * 0.75 + randf_range(0.0, 0.18)
		s.dur = 1.1 + s.alt * 0.06
		print_verbose("[mg] tűzijáték: %s %d pumpálás -> %.1f m" % [s.p.name, s.pumps, s.alt])


func _launch(s: Dictionary) -> void:
	s.flying = true
	s.y = 0.0
	((s.rocket as Node3D).get_node("fuse") as CPUParticles3D).emitting = false
	(s.trail as CPUParticles3D).emitting = true
	var puff: CPUParticles3D = s.burst.puff
	puff.global_position = s.r_base
	puff.restart()
	Audio.play("launch", FX.fr(0.92, 1.08))


func _explode(s: Dictionary) -> void:
	s.flying = false
	s.boom_t = t
	(s.trail as CPUParticles3D).emitting = false
	(s.rocket as Node3D).visible = false
	var pos: Vector3 = s.r_base + Vector3(0, s.alt, 0)
	var power: float = clamp((s.alt - ALT_MIN) / ALT_K, 0.0, 1.2)
	var b: Dictionary = s.burst
	var main: CPUParticles3D = b.main
	main.amount = int(70 + 170 * power)
	main.initial_velocity_min = 6.0 + 8.0 * power
	main.initial_velocity_max = 8.0 + 11.0 * power
	main.global_position = pos
	main.restart()
	var streak: CPUParticles3D = b.streak
	streak.amount = int(24 + 60 * power)
	streak.initial_velocity_min = 8.0 + 8.0 * power
	streak.initial_velocity_max = 11.0 + 12.0 * power
	streak.global_position = pos
	streak.restart()
	var smoke: CPUParticles3D = b.smoke
	smoke.global_position = pos
	smoke.restart()
	var light: OmniLight3D = b.light
	light.global_position = pos
	light.omni_range = 22.0 + 20.0 * power
	flashes.append({"l": light, "t0": t, "e": 4.0 + 6.0 * power})
	Audio.play("firework", FX.fr(0.85, 1.05) + (0.2 - 0.25 * power))
	if power > 0.75:
		Audio.play("boom", 0.9)
	last_boom = t


func _react() -> void:
	var idx: Array = range(pl.size())
	idx.sort_custom(func(a, b): return pl[a].alt > pl[b].alt)
	for k in idx.size():
		var s: Dictionary = pl[idx[k]]
		s.place = k
		var m: Chars3D.CharModel = s.m
		if k == 0:
			m.emote("cheer")
		elif k == 1:
			m.emote("happy")
		elif k == pl.size() - 1 and pl.size() > 2:
			m.emote("sad")
			_add_rain(s)
	var best: Dictionary = pl[idx[0]]
	_say("🏆 %s rakétája repült a legmagasabbra!" % best.p.name, Color("#ffd43b"), 3.4)
	Audio.play("fanfare")
	if not preview:
		Main.I.confetti(110)


## a vesztes feje fölé kis esőfelhő kerül (vicces vereség)
func _add_rain(s: Dictionary) -> void:
	var m: Chars3D.CharModel = s.m
	var cloud := Chars3D.grp(m, Vector3(0, 1.35, 0))
	var cm := Chars3D.mat("#5c677d", {"rough": 0.9})
	for k in 4:
		Chars3D.sphere(cloud, 0.16 + (k % 2) * 0.05, cm, (k - 1.5) * 0.14, sin(k * 2.0) * 0.04, 0)
	var drops: Array = []
	var dm := Chars3D.mat("#74c0fc", {"emit": "#4dabf7", "emit_e": 0.6})
	for k in 5:
		drops.append(Chars3D.sphere(cloud, 0.03, dm, (k - 2) * 0.09, -0.2, 0, 0.7, 1.5, 0.7))
	s.rain = {"n": cloud, "drops": drops}


func ranking() -> Array:
	var out: Array = []
	for s in pl:
		if s.cpu:
			continue
		out.append({"pid": s.p.pid, "score": snappedf(s.alt, 0.01), "label": "%.1f m · %d pumpálás" % [s.alt, s.pumps]})
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
		_animate_station(s, dt)
	for f in flashes:
		var k: float = (t - f.t0) / 1.1
		(f.l as OmniLight3D).light_energy = 0.0 if k >= 1.0 else f.e * (1.0 - k) * (1.0 - k)
	flashes = flashes.filter(func(f): return t - f.t0 < 1.2)
	_camera(dt)


func _animate_station(s: Dictionary, dt: float) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var tt: float = m.t
	# pumpaütés: gyors le, lassabb vissza
	var k: float = t - s.stroke_t0
	var d := 0.0
	if k >= 0.0 and k < 0.07:
		d = k / 0.07
	elif k >= 0.07 and k < 0.22:
		d = 1.0 - (k - 0.07) / 0.15
	d *= s.amp
	var handle: Node3D = s.handle
	handle.position.y = HANDLE_UP - HANDLE_TRAVEL * d
	var busy: float = clamp(1.0 - (t - s.stroke_t0) / 0.6, 0.0, 1.0) if stage == "pump" else 0.0
	s.lean = lerp(float(s.lean), busy, min(1.0, dt * 6.0))
	# fejjel a rakéták felé néz
	var look_tgt := 0.0
	if stage == "flight" or (stage == "prep" and t - stage_t0 > 0.4):
		var ry: float = s.y if s.flying else (s.alt if s.boom_t >= 0 else 1.5)
		look_tgt = clamp(atan2(ry, 6.0) * 0.8, 0.15, 0.55)
	elif stage == "react" and s.place == 0:
		look_tgt = 0.12
	s.look = lerp(float(s.look), look_tgt, min(1.0, dt * 4.0))
	var base_pos := Vector3(s.x + s.px, 0, 0.02)
	var sq := 1.0 - 0.1 * d
	var rot := Vector3(0.1 * s.lean + 0.14 * d - s.look, 0, sin(tt * 1.3 + s.i) * 0.02)
	var react: bool = stage == "react"
	var place: int = s.place
	if react:
		var rk: float = t - react_t0
		if place == 0:
			rot = Vector3(-0.05, a.spin, 0)
		elif place == pl.size() - 1 and pl.size() > 2:
			# lógatott fej, ide-oda dülöngélés
			rot = Vector3(0.42, 0, sin(rk * 2.2) * 0.12)
			sq = 0.86 + 0.03 * sin(rk * 2.2)
		elif place == 1:
			rot = Vector3(-0.05, a.spin, 0)
		else:
			rot = Vector3(0.08, 0, sin(rk * 1.5) * 0.04)
	elif stage != "pump":
		base_pos.z -= 0.25 * clamp((t - stage_t0) / 0.4, 0.0, 1.0) if stage == "prep" else 0.25
	m.position = base_pos + Vector3(0, a.y, 0)
	m.rotation = rot + Vector3(0, 0, a.tilt)
	m.scale = Vector3(BASE_SCALE / sqrt(sq), BASE_SCALE * sq, BASE_SCALE / sqrt(sq))
	# kezek: pumpálás közben a fogantyún, utána mutatnak / ünnepelnek / lógnak
	var inv := m.global_transform.affine_inverse()
	for arm in s.arms:
		var side: float = arm.side
		var target: Vector3
		if stage == "pump" or (stage == "prep" and t - stage_t0 < 0.3):
			target = inv * (handle.global_position + Vector3(side * 0.2, 0.02, 0))
		elif react and place == 0:
			target = Vector3(side * 0.42, 1.22 + sin(tt * 10.0 + side) * 0.08, 0.1)
		elif react and place == 1:
			target = Vector3(side * 0.5, 0.95 + sin(tt * 7.0) * 0.05 * side, 0.15)
		elif react and place == pl.size() - 1 and pl.size() > 2:
			target = Vector3(side * 0.28, 0.0, 0.12)
		elif stage == "flight" or stage == "prep":
			# izgatottan összekulcsolt kéz / mutogatás
			if side > 0:
				target = Vector3(0.35, 0.7 + s.look * 0.9, 0.42)
			else:
				target = Vector3(-0.1, 0.42, 0.3)
		else:
			target = Vector3(side * 0.38, 0.12, 0.12)
		K.arm_to(arm, target, Vector3(0.3, -1.0, 0.2))
	# arc: erőlködés, izgalom, meglepetés, öröm vagy bánat
	var face: Dictionary = s.face
	if stage == "pump":
		K.set_face(m, face, 0.2 + 0.5 * d, 1.0, -0.7 * s.lean)
	elif stage == "prep" or stage == "flight":
		var wow: float = 0.4 + 0.5 * s.look
		if s.boom_t >= 0 and t - s.boom_t < 1.0:
			wow = 1.0
		K.set_face(m, face, wow, 1.15 + 0.25 * s.look, 0.9)
	elif react:
		if place == 0:
			K.set_face(m, face, 0.8, 1.1, 0.6)
		elif place == 1:
			K.set_face(m, face, 0.45, 1.0, 0.3)
		elif place == pl.size() - 1 and pl.size() > 2:
			K.set_face(m, face, 0.15, 0.85, -0.9)
		else:
			K.set_face(m, face, 0.1, 1.0, -0.25)
	else:
		K.set_face(m, face, 0.0, 1.0, 0.0)
	if s.rain:
		var rn: Dictionary = s.rain
		for j in rn.drops.size():
			var f := fposmod(tt * 1.6 + j * 0.37, 1.0)
			(rn.drops[j] as Node3D).position.y = -0.18 - f * 0.7
			(rn.drops[j] as Node3D).visible = f < 0.9
	# mérő: a szegmensek a töltéssel gyulladnak ki, villanással
	var filled := _filled(s)
	for j in SEGS:
		var sg: Dictionary = s.segs[j]
		var n: MeshInstance3D = sg.n
		n.visible = j < filled
		if n.visible:
			var pk: float = clamp((t - sg.on_t) / 0.25, 0.0, 1.0)
			var pop: float = (1.0 - pk) * 0.35
			var shimmer: float = 0.04 * sin(t * 6.0 - j * 0.7) if filled >= SEGS else 0.0
			n.scale = Vector3(1.0 + pop + shimmer, 1.0, 1.0 + pop + shimmer)
	# rakéta: a töltéstől remeg, kilövés után emelkedik, enyhén imbolyog
	var rocket: Node3D = s.rocket
	if s.boom_t < 0:
		var shake: float = 0.0
		if stage == "prep":
			shake = 0.03
		elif stage == "pump":
			shake = 0.012 * min(1.0, _charge(s)) * busy
		var wob := Vector3(FX.fr(-1, 1), 0, FX.fr(-1, 1)) * shake
		rocket.position = s.r_base + Vector3(0, s.y, 0) + wob
		rocket.rotation = Vector3(sin(t * 9.0 + s.i) * 0.04, t * 3.0 if s.flying else 0.0, sin(t * 7.0 + s.i) * 0.04) if s.flying else Vector3.ZERO
		var tr: CPUParticles3D = s.trail
		tr.position = rocket.position
	if s.flying:
		(s.trail as CPUParticles3D).emitting = true


## Nagy totál, majd a kilövéskor a kamera felfelé billen és hátrébb húzódik, hogy minden rakéta látsszon.
func _camera(dt: float) -> void:
	if cam == null:
		return
	var target := 0.0
	if stage == "flight" or stage == "prep":
		for s in pl:
			if s.flying:
				target = max(target, float(s.y) + 4.0)
			elif s.boom_t >= 0:
				target = max(target, float(s.alt) + 6.0)
	elif stage == "react":
		var rk := t - stage_t0
		var top := 0.0
		for s in pl:
			top = max(top, float(s.alt) + 6.0)
		target = top * (1.0 - smoothstep(0.6, 2.4, rk))
	h_target = target
	# kritikusan csillapított követés: nincs ugrás
	var rate := 2.2 if h_target > h_track else 1.6
	h_track = lerp(h_track, h_target, 1.0 - exp(-rate * dt))
	var H: float = max(h_track, 5.0)
	var span: float = deg_to_rad(FOV) * 0.82
	var cz: float = max(9.8, (H - CAM_Y + 1.0) / tan(span) + 1.5)
	# 4-nél több állomásnál a kamera hátrébb húzódik, hogy mindenki beférjen
	var half_w: float = (pl.size() - 1) / 2.0 * GAP + 2.2
	cz = max(cz, half_w / (tan(deg_to_rad(FOV) / 2.0) * 1.7))
	var a_top := atan2(H - CAM_Y, cz)
	var a_bot := atan2(-CAM_Y, cz)
	var pitch := (a_top + a_bot) / 2.0
	var push := 0.0
	if stage == "pump":
		push = 1.4 * clamp(t / PUMP_TIME, 0.0, 1.0)
	var cy: float = CAM_Y + 0.7 * (1.0 - clamp(h_track / 6.0, 0.0, 1.0))
	var shake := 0.0
	if last_boom > 0.0 and t - last_boom < 0.4:
		shake = 0.06 * (1.0 - (t - last_boom) / 0.4)
	cam.position = Vector3(FX.fr(-1, 1) * shake, cy + FX.fr(-1, 1) * shake, cz - push)
	cam.look_at(Vector3(0, CAM_Y + tan(pitch) * cz - 0.1 + 0.3 * (1.0 - clamp(h_track / 6.0, 0.0, 1.0)), 0), Vector3.UP)


func draw(c: CanvasItem) -> void:
	if stage == "pump":
		K.silver_timer(c, PUMP_TIME - t, 640, 46, 3.0, t)
	for s in pl:
		_draw_station_hud(c, s)
	var mk := t - msg_t0
	K.banner(c, msg_text, mk, msg_dur, 140, msg_col, 60)


func _draw_station_hud(c: CanvasItem, s: Dictionary) -> void:
	var col: Color = s.col
	if stage == "pump" or stage == "prep":
		var sp := screen(Vector3(s.x, 0, 0.9))
		var w: float = minf(176.0, 1250.0 / pl.size() - 8.0)
		var x: float = clamp(sp.x, w / 2 + 6, 1274 - w / 2)
		D.panel(c, x - w / 2, 640, w, 66, {"r": 18, "fill": Color(0.05, 0.06, 0.16, 0.86), "stroke": col, "lw": 4.0})
		D.char_image(c, s.p.char_id, x - w / 2 + 26, 660, 38)
		var name: String = s.p.name
		if s.cpu or s.p.is_bot:
			name += " · " + K.LEVEL_NAME[s.lvl]
		D.text(c, name, x - w / 2 + 50, 657, {"size": 15, "align": "left", "maxw": w - 60})
		var ch: float = min(1.0, _charge(s))
		var bw := w - 24
		c.draw_rect(Rect2(x - bw / 2 - 2, 677, bw + 4, 18), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(x - bw / 2, 679, bw * ch, 14), col.lightened(0.2))
		c.draw_rect(Rect2(x - bw / 2, 679, bw * ch, 5), Color(1, 1, 1, 0.35))
		D.text(c, "%d%%" % roundi(_charge(s) * 100.0), x, 686, {"size": 14, "stroke": D.DARK, "sw": 4})
		if _charge(s) >= 1.0 and fmod(t, 0.4) < 0.25:
			D.text(c, "MAX!", x + w / 2 - 22, 657, {"size": 15, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 4})
	elif stage == "flight":
		var y: float = s.y if s.flying else s.alt
		var p3: Vector3 = s.r_base + Vector3(0, y + 1.6, 0)
		var sp := screen(p3)
		if sp.x > -500:
			D.text(c, "%d m" % roundi(y * 10.0), sp.x, sp.y - 6, {"size": 22, "color": Color(TRAIL_COLS[s.i % 4]).lightened(0.3), "stroke": D.DARK, "sw": 5})
	elif stage == "react":
		var sp := screen(Vector3(s.x + s.px, 2.6, -0.2))
		var rk: float = (t - react_t0 - 1.6 - (pl.size() - 1 - s.place) * 0.2) * 2.5
		K.place_label(c, s.place, sp.x, sp.y - 30, rk, 66)
		if rk > 0.5:
			D.text(c, "%d m" % roundi(s.alt * 10.0), sp.x, sp.y + 22, {"size": 22, "stroke": D.DARK, "sw": 5, "color": Color(TRAIL_COLS[s.i % 4]).lightened(0.4)})
