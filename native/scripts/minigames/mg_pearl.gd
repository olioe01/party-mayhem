extends Minigame
## Gyöngyhalászat – víz alatti aréna sziklákkal, korallokkal, hínárral. A különböző magasságú
## sziklapárkányokon óriáskagylók ülnek: időnként kinyílnak, és egy izzó rózsaszín gyöngy látszik
## bennük. Aki elsőként megérinti, +1 pont; a kagyló utána egy időre bezárul. A lassan lebegő
## medúzák megbénítanak (1,5 mp), utána rövid védettség jár. 30 mp, a legtöbb gyöngy nyer.
##
## Oldalnézetes (2,5D) úszás: a joystick vízszintes tengelye jobbra-balra, a függőleges fel-le visz.

const K = preload("res://scripts/minigames/mg_kit.gd")

# ------------------------------------------------------------------ beállítások
const LIMIT := 30.0
const XL := 11.2                   # az úszható tér fél szélessége
const Y0 := 0.55                   # a homokos fenék fölött
const Y1 := 11.3                   # a vízfelszín alatt
const BODY := 0.42
const ACC := 30.0
const MAXV := 5.4
const DRAG := 0.06                 # víz-ellenállás (ennyi marad 1 mp alatt a sebességből)
const PICK_R := 0.78               # ennyire kell megközelíteni a gyöngyöt
const OPEN_DUR := 0.45             # nyílás / zárás ideje
const OPEN_MAX := 6.0              # ha senki nem veszi el, ennyi után bezárul
const CLOSED_MIN := 2.4            # bezárva legalább / legfeljebb ennyi ideig
const CLOSED_MAX := 4.6
const STUN := 1.5
const SAFE := 1.4                  # a bénulás után ennyi ideig nem bénítható újra
const JELLY_R := 0.5               # a medúza harangja
const MS := 0.95
const START_SAFE := 2.0           # az elején ennyi ideig senkit nem bénít meg medúza

# a kagylók helye: [x, y] – a párkány teteje a kagyló alja
const CLAMS := [[-8.6, 1.15], [-3.4, 3.3], [2.6, 1.0], [7.9, 3.0], [-9.0, 6.6], [-1.1, 7.2], [5.1, 6.1], [-5.4, 9.6], [8.7, 9.2], [1.9, 10.0]]
# medúzák pályája: [középpont x, y, vízszintes kilengés, függőleges kilengés, sebesség]
const JELLIES := [[-6.0, 4.6, 2.4, 0.9, 0.24], [0.2, 2.7, 2.6, 0.7, 0.2], [5.6, 8.2, 2.2, 0.9, 0.26], [-3.2, 8.6, 2.6, 0.8, 0.22], [6.2, 1.9, 1.8, 0.6, 0.28]]

var st: Array = []
var clams: Array = []
var jellies: Array = []
var ledges: Array = []             # {x, y, hx, hy} a sziklapárkányok (ütközés)
var bubbles: Array = []            # buborék-nyomvonal (csak látvány)
var amb: Array = []                # felszálló háttérbuborékok
var rays: Array = []
var weeds: Array = []
var bubble_mesh: SphereMesh
var bubble_mat: StandardMaterial3D


func meta() -> Dictionary:
	return {"id": "pearl", "name": "Gyöngyhalászat", "icon": "🦪", "color": "#2fa8d8", "modes": ["ffa"], "keep_ties": true,
		"tagline": "Kapd el a gyöngyöt, mielőtt a kagyló bezárul!",
		"desc": "A tenger mélyén óriáskagylók ülnek a sziklapárkányokon. Időnként kinyílnak, és egy izzó rózsaszín gyöngy látszik bennük: aki elsőként megérinti, +1 pont, a kagyló pedig egy időre bezárul. Vigyázz a lassan lebegő medúzákkal: ha hozzájuk érsz, másfél másodpercre megbénulsz! 30 másodperc, a legtöbb gyöngy nyer.",
		"controls": "A joystickkal úszol (gépen WASD/nyilak): jobbra-balra és fel-le, bármerre."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "noBtn": true, "title": "🦪 Úszás a gyöngyökért!"}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	make_env("#0a5a8f", "#1e88b8", 0.9)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b4f7e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8fd6ff")
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("#13689a")
	env.fog_density = 0.028
	env.glow_intensity = 0.9
	make_camera(Vector3(0, 6.0, 20.5), Vector3(0, 5.7, 0), 46)
	var sun := make_sun(Vector3(-70, -15, 0), 1.0, "#bff0ff")
	sun.shadow_blur = 2.5
	bubble_mesh = SphereMesh.new()
	bubble_mesh.radius = 0.08
	bubble_mesh.height = 0.16
	bubble_mesh.radial_segments = 8
	bubble_mesh.rings = 4
	bubble_mat = Chars3D.mat("#e6fbff", {"alpha": 0.55, "rough": 0.1, "emit": "#bdf3ff", "emit_e": 0.4})
	_build_seabed()
	_build_rocks()
	_build_light()
	for i in CLAMS.size():
		_make_clam(i)
	var nj := 3 if players.size() <= 3 else (4 if players.size() <= 6 else 5)
	for k in nj:
		_make_jelly(k)
	var n := players.size()
	for i in n:
		_make_player(players[i], i, n)
	_sync(0.0)


func _build_seabed() -> void:
	var sand := Chars3D.mat("#e7cf94", {"rough": 1.0})
	var sand2 := Chars3D.mat("#d6bb7c", {"rough": 1.0})
	Chars3D.box(self, 80, 2, 40, sand, Vector3(0, -1.0, -8))
	for i in 18:
		var r := FX.fr(1.0, 2.6)
		Chars3D.lsphere(self, r, sand2, FX.fr(-16, 16), -r * 0.75, FX.fr(-8, 2), 1.4, 0.5, 1.0, 8, 4)
	# kagylóhéjak, tengeri csillagok, kavicsok a homokon
	var shell_cols := ["#ffb3c7", "#ffd8a8", "#f8f0e3", "#c5a3ff"]
	for i in 16:
		var x := FX.fr(-12, 12)
		var z := FX.fr(-2.5, 2.5)
		var sc: String = FX.pick(shell_cols)
		var sh := Chars3D.lsphere(self, 0.16, Chars3D.mat(sc, {"rough": 0.6}), x, 0.04, z, 1, 0.35, 1.1, 7, 3)
		sh.rotation.y = FX.fr(0, TAU)
	for i in 6:
		_starfish(Vector3(FX.fr(-11, 11), 0.05, FX.fr(-1.5, 2.5)), Color(FX.pick(["#ff7a59", "#ffb347", "#ff5c8a"])))
	# korallok
	for i in 14:
		var x := FX.fr(-12.5, 12.5)
		var z := FX.fr(-3.5, -0.8)
		_coral(Vector3(x, 0.0, z), i)
	# hínár és tengeri fű (lassan hajladozik)
	for i in 26:
		var x := FX.fr(-13, 13)
		var z := FX.fr(-3.2, 1.6)
		_seaweed(Vector3(x, 0, z), FX.fr(1.2, 3.2), i)


func _starfish(pos: Vector3, col: Color) -> void:
	var m := Chars3D.mat(col.to_html(), {"rough": 0.7})
	for k in 5:
		var a := k * TAU / 5.0
		Chars3D.lcone(self, 0.07, 0.3, m, pos.x + sin(a) * 0.13, pos.y, pos.z + cos(a) * 0.13, 4, Vector3(PI / 2, a, 0))
	Chars3D.lsphere(self, 0.09, m, pos.x, pos.y, pos.z, 1, 0.4, 1, 6, 3)


func _coral(pos: Vector3, k: int) -> void:
	var cols := ["#ff6f91", "#ff9671", "#ffc75f", "#c34a9d", "#f9f871", "#ff8fab"]
	var m := Chars3D.mat(cols[k % cols.size()], {"rough": 0.7})
	match k % 3:
		0:     # ágas korall
			for j in 5:
				var a := j * TAU / 5.0 + 0.3
				var h := 0.6 + (j % 3) * 0.25
				var dir := Vector3(sin(a) * 0.35, 1.0, cos(a) * 0.35).normalized()
				var mi := Chars3D.lcyl(self, 0.05, 0.08, h, m, 0, 0, 0, 5)
				mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), pos + dir * h / 2.0)
				Chars3D.lsphere(self, 0.08, m, pos.x + dir.x * h, pos.y + dir.y * h, pos.z + dir.z * h, 1, 1, 1, 6, 3)
		1:     # agykorall
			Chars3D.lsphere(self, 0.55, m, pos.x, 0.15, pos.z, 1.2, 0.7, 1.0, 9, 5)
			Chars3D.lsphere(self, 0.3, Chars3D.mat(Color(cols[k % cols.size()]).darkened(0.2).to_html()), pos.x + 0.5, 0.1, pos.z + 0.2, 1, 0.7, 1, 7, 4)
		_:     # csöves korall
			for j in 4:
				var off := Vector3(cos(j * 1.9) * 0.22, 0, sin(j * 1.9) * 0.22)
				var h := 0.5 + j * 0.18
				Chars3D.lcyl(self, 0.09, 0.07, h, m, pos.x + off.x, h / 2.0, pos.z + off.z, 7)
				Chars3D.lcyl(self, 0.06, 0.06, 0.02, Chars3D.mat("#5c2a4a"), pos.x + off.x, h + 0.01, pos.z + off.z, 7)


func _seaweed(pos: Vector3, h: float, k: int) -> void:
	var m := Chars3D.mat(["#2f9e6e", "#3cb371", "#5fae3c", "#2a8a7a"][k % 4], {"rough": 0.8})
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var segs: Array = []
	var parent: Node3D = root
	var n := int(h / 0.4) + 2
	for j in n:
		var pv := Node3D.new()
		pv.position = Vector3(0, 0.0 if j == 0 else 0.4, 0)
		parent.add_child(pv)
		var w := 0.12 * (1.0 - float(j) / n) + 0.04
		Chars3D.box(pv, w, 0.44, 0.03, m, Vector3(0, 0.2, 0))
		segs.append(pv)
		parent = pv
	weeds.append({"segs": segs, "ph": k * 0.9})


## Nagy sziklaformációk körben + a kagylókat tartó párkányok (ezek szilárdak).
func _build_rocks() -> void:
	var rock := Chars3D.mat("#6b7385", {"rough": 0.95})
	var rock2 := Chars3D.mat("#555c70", {"rough": 0.95})
	var rock3 := Chars3D.mat("#7f8798", {"rough": 0.95})
	var moss := Chars3D.mat("#3f8f6a", {"rough": 1.0})
	# hátul alacsony sziklagerinc, mögötte a nyílt víz (a ködben elhalványuló távoli sziklák)
	for i in 10:
		var x := -17.0 + i * 3.8 + FX.fr(-0.8, 0.8)
		var r := FX.fr(1.8, 2.8)
		Chars3D.lsphere(self, r, rock2 if i % 2 else rock, x, FX.fr(0.2, 1.4), -7.5 - FX.fr(0, 1.5), 1.2, 0.9, 0.8, 8, 5)
	for i in 5:
		var x := -20.0 + i * 10.0 + FX.fr(-2, 2)
		Chars3D.lcone(self, FX.fr(2.0, 3.0), FX.fr(7.0, 11.0), rock2, x, 3.5, -16.0 - FX.fr(0, 4), 7)
	# oldalsó sziklafalak: a kerület szélén, nem lógnak be az úszható térbe
	for side in [-1, 1]:
		for j in 5:
			var r := FX.fr(1.4, 2.0)
			Chars3D.lsphere(self, r, rock if j % 2 else rock3, side * (XL + 2.2 + FX.fr(0, 0.8)), 0.4 + j * 2.6, FX.fr(-2.5, -0.5), 0.9, 1.1, 1.0, 8, 5)
	# párkányok a kagylók alatt
	for i in CLAMS.size():
		var c: Array = CLAMS[i]
		var x: float = c[0]
		var y: float = c[1]
		ledges.append({"x": x, "y": y - 0.38, "hx": 0.95, "hy": 0.33})
		var g := Node3D.new()
		g.position = Vector3(x, y - 0.38, 0)
		add_child(g)
		Chars3D.lsphere(g, 1.0, rock3 if i % 2 else rock, 0, 0, -0.3, 1.05, 0.38, 1.0, 9, 5)
		Chars3D.lsphere(g, 0.7, rock2, 0.4, -0.25, -0.5, 1.0, 0.6, 1.0, 8, 4)
		if y > 1.6:
			# lelógó sziklatő, hogy ne lebegjen a semmiben: a hátsó falhoz kötődik
			Chars3D.lcone(g, 0.55, 1.2, rock2, 0, -0.75, -0.6, 6, Vector3(PI, 0, 0))
			Chars3D.lcyl(g, 0.45, 0.6, 3.0, rock2, 0, 0.0, -2.0, 7, Vector3(PI / 2, 0, 0))
		Chars3D.lsphere(g, 0.35, moss, -0.5, 0.25, 0.1, 1.2, 0.35, 0.8, 6, 3)
		_coral(Vector3(x + 0.75, y - 0.1, -0.3), i + 1)


## Fénysugarak a felszínről, a vízfelszín alulról, háttérbuborékok.
func _build_light() -> void:
	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 30)
	surf.mesh = pm
	var sm := Chars3D.mat("#9be7ff", {"alpha": 0.45, "unshaded": true})
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	surf.material_override = sm
	surf.position = Vector3(0, Y1 + 1.6, -6)
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surf)
	var tex := _ray_tex()
	for i in 7:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(FX.fr(1.2, 2.6), 16)
		mi.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(0.8, 0.97, 1.0, 0.22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var x := -12.0 + i * 4.0 + FX.fr(-1, 1)
		mi.position = Vector3(x, 6.0, -3.0 + FX.fr(-1, 1.5))
		mi.rotation = Vector3(0, 0, 0.32)
		add_child(mi)
		rays.append({"mi": mi, "ph": FX.fr(0, TAU), "a": FX.fr(0.14, 0.26)})
	for i in 40:
		var mi := MeshInstance3D.new()
		mi.mesh = bubble_mesh
		mi.material_override = bubble_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		amb.append({"mi": mi, "x": FX.fr(-13, 13), "z": FX.fr(-3, 1.5), "y0": FX.fr(0, 12), "v": FX.fr(0.5, 1.1), "s": FX.fr(0.6, 1.6), "ph": FX.fr(0, TAU)})


static func _ray_tex() -> ImageTexture:
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var edge := 1.0 - absf(x - 15.5) / 16.0
			var fade := float(64 - y) / 64.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(edge * edge * (0.3 + 0.7 * fade), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Óriáskagyló: bordázott alsó és felső héj (a felső hátul csuklós), bent rózsaszínes „hús” és a gyöngy.
func _make_clam(i: int) -> void:
	var c: Array = CLAMS[i]
	var g := Node3D.new()
	g.position = Vector3(c[0], c[1], 0.05)
	g.rotation.y = FX.fr(-0.25, 0.25)
	g.scale = Vector3.ONE * 1.25
	add_child(g)
	var shell := Chars3D.mat(["#8a7fd6", "#7d6fc4", "#9b8ce0"][i % 3], {"rough": 0.45})
	var rim := Chars3D.mat("#c9bfff", {"rough": 0.4})
	var inner := Chars3D.mat("#f1e8ff", {"rough": 0.25, "metal": 0.15})
	var hemi := SphereMesh.new()
	hemi.radius = 0.62
	hemi.height = 0.62
	hemi.is_hemisphere = true
	hemi.radial_segments = 12
	hemi.rings = 4
	# alsó héj (fejjel lefelé fordított félgömb) + belseje
	Chars3D.part(g, hemi, shell, Vector3(0, 0.22, 0), Vector3(1.0, 0.36, 0.82), Vector3(PI, 0, 0))
	Chars3D.cyl(g, 0.55, 0.55, 0.04, inner, 0, 0.22, 0, 16).scale = Vector3(1, 1, 0.8)
	# bordák az alsó héjon (a kamera felőli oldalon)
	for k in 5:
		var a := (k - 2) * 0.32
		Chars3D.box(g, 0.05, 0.2, 0.05, rim, Vector3(sin(a) * 0.5, 0.12, cos(a) * 0.42), Vector3(0.6, a, 0))
	# felső héj: a csukló a kagyló hátulján
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0.24, -0.48)
	g.add_child(hinge)
	var top := Node3D.new()
	top.position = Vector3(0, 0, 0.48)
	hinge.add_child(top)
	Chars3D.part(top, hemi, shell, Vector3.ZERO, Vector3(1.0, 0.4, 0.82))
	for k in 5:
		var a := (k - 2) * 0.32
		Chars3D.box(top, 0.05, 0.05, 0.36, rim, Vector3(sin(a) * 0.42, 0.18, 0.12), Vector3(-0.35, a, 0))
	Chars3D.cyl(top, 0.55, 0.55, 0.03, inner, 0, 0.0, 0, 16).scale = Vector3(1, 1, 0.8)
	# a gyöngy
	var pearl := Chars3D.lsphere(g, 0.2, Chars3D.mat("#ff5cc8", {"emit": "#ff3fb8", "emit_e": 2.4, "rough": 0.1, "metal": 0.25}), 0, 0.42, 0.18, 1, 1, 1, 12, 8)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff8ad8")
	glow.light_energy = 0.0
	glow.omni_range = 2.2
	glow.position = Vector3(0, 0.6, 0.3)
	g.add_child(glow)
	clams.append({"g": g, "hinge": hinge, "pearl": pearl, "glow": glow, "x": c[0], "y": c[1],
		"state": "closed", "t0": 0.0, "open_at": 99.0, "has": false, "k": 0.0})


func _make_jelly(k: int) -> void:
	var g := Node3D.new()
	add_child(g)
	var col: String = ["#ff7ad9", "#c084fc", "#f472b6", "#a78bfa", "#ff9ae6"][k % 5]
	var bell := Chars3D.mat(col, {"alpha": 0.72, "emit": col, "emit_e": 0.9, "rough": 0.2})
	var dome := SphereMesh.new()
	dome.radius = JELLY_R
	dome.height = JELLY_R
	dome.is_hemisphere = true
	dome.radial_segments = 14
	dome.rings = 5
	var body := Chars3D.part(g, dome, bell, Vector3.ZERO, Vector3(1, 1.15, 1))
	var core := Chars3D.lsphere(g, 0.22, Chars3D.mat("#ffe3f6", {"emit": "#ffc2ec", "emit_e": 1.4}), 0, 0.18, 0, 1, 0.8, 1, 8, 4)
	var rim := Chars3D.cyl(g, JELLY_R * 1.02, JELLY_R * 1.02, 0.06, Chars3D.mat(col, {"alpha": 0.85, "emit": col, "emit_e": 1.2}), 0, 0.0, 0, 16)
	var tents: Array = []
	for j in 6:
		var a := j * TAU / 6.0
		var t := Node3D.new()
		t.position = Vector3(cos(a) * 0.28, -0.02, sin(a) * 0.28)
		g.add_child(t)
		var parent: Node3D = t
		for q in 4:
			var pv := Node3D.new()
			pv.position = Vector3(0, 0.0 if q == 0 else -0.22, 0)
			parent.add_child(pv)
			Chars3D.lcyl(pv, 0.025, 0.02, 0.24, bell, 0, -0.11, 0, 4)
			tents.append({"n": pv, "q": q, "j": j})
			parent = pv
	var light := OmniLight3D.new()
	light.light_color = Color(col)
	light.light_energy = 0.7
	light.omni_range = 2.4
	g.add_child(light)
	var jd: Array = JELLIES[k]
	jellies.append({"g": g, "body": body, "core": core, "rim": rim, "tents": tents, "k": k,
		"cx": jd[0], "cy": jd[1], "ax": jd[2], "ay": jd[3], "w": jd[4], "x": jd[0], "y": jd[1]})


func _make_player(p, i: int, n: int) -> void:
	var m := player_model(p, MS)
	var col: Color = p.color
	var feet: Array = []
	var shoe := Chars3D.mat(D.shade(col, -0.45).to_html(), {"rough": 0.6})
	for side in [-1, 1]:
		feet.append(Chars3D.lsphere(m, 0.09, shoe, side * 0.14, 0.04, 0.05, 1.0, 0.55, 1.4, 8, 4))
	# kezdőhely: középmagasságban, egy sorban
	var x := (i - (n - 1) / 2.0) * minf(1.6, 15.0 / maxi(1, n))
	var s := {"p": p, "i": i, "m": m, "col": col, "feet": feet, "arms": K.build_arms(m, col.to_html(), 0.42), "face": K.build_face(m),
		"x": x, "y": 5.0, "vx": 0.0, "vy": 0.0, "ix": 0.0, "iy": 0.0, "score": 0, "stun_t": -10.0, "safe_until": START_SAFE,
		"yaw": 0.0, "lean": 0.0, "kb_t": -10.0, "ai_t": 0.0, "bub": 0.0, "hit_t": -10.0, "got_t": -10.0}
	_push_out(s)
	st.append(s)


# ------------------------------------------------------------------ ütközés
func _push_out(s: Dictionary) -> void:
	for o in ledges:
		var cx: float = clampf(s.x, o.x - o.hx, o.x + o.hx)
		var cy: float = clampf(s.y, o.y - o.hy, o.y + o.hy)
		var d := Vector2(s.x - cx, s.y - cy)
		var dl := d.length()
		if dl < BODY:
			var nrm: Vector2
			if dl > 0.0001:
				nrm = d / dl
			else:
				var px: float = o.hx - absf(s.x - o.x)
				var py: float = o.hy - absf(s.y - o.y)
				nrm = Vector2(signf(s.x - o.x) if s.x != o.x else 1.0, 0) if px < py else Vector2(0, signf(s.y - o.y) if s.y != o.y else 1.0)
				cx = o.x + nrm.x * o.hx if nrm.x != 0 else s.x
				cy = o.y + nrm.y * o.hy if nrm.y != 0 else s.y
			s.x = cx + nrm.x * BODY
			s.y = cy + nrm.y * BODY
			var vn: float = s.vx * nrm.x + s.vy * nrm.y
			if vn < 0:
				s.vx -= vn * nrm.x
				s.vy -= vn * nrm.y
	s.x = clampf(s.x, -XL + BODY, XL - BODY)
	s.y = clampf(s.y, Y0, Y1)


# ------------------------------------------------------------------ menet
func start() -> void:
	# a kagylók eltérő időben nyílnak; az elején néhány már hamar
	for i in clams.size():
		var c: Dictionary = clams[i]
		c.open_at = randf_range(0.2, 1.2) if i % 3 == 0 else randf_range(1.5, 5.0)
	Audio.play("bubble")


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
	# a telefon joystickja lefelé ad pozitív y-t: a képernyőn fel = fel
	s.iy = -clampf(float(msg.get("y", 0)), -1.0, 1.0)


## Csak a fejlesztői tesztbotoknak és a lecsatlakozott játékosok helyett: a legközelebbi nyitott
## (vagy hamarosan nyíló) kagylóhoz úszik, a medúzákat kerüli.
func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.is_empty() or t - float(s.kb_t) < 1.5:
		return
	s.ai_t -= dt
	if s.ai_t > 0.0:
		return
	s.ai_t = randf_range(0.15, 0.3)
	var here := Vector2(s.x, s.y)
	var best := INF
	var goal := here
	for c in clams:
		var cp := Vector2(c.x, c.y + 0.45)
		var d := here.distance_to(cp)
		var cost := d
		if not c.has:
			cost += maxf(0.0, float(c.open_at) - t) * 3.0 + 6.0
		cost += randf_range(0.0, 2.0)
		if cost < best:
			best = cost
			goal = cp
	var want := (goal - here)
	want = want.normalized() if want.length() > 0.2 else Vector2.ZERO
	for j in jellies:
		var d := here - Vector2(j.x, j.y)
		var l := d.length()
		if l < 2.4 and l > 0.01:
			want += d / l * (2.4 - l) * 1.2
	if want.length() > 1.0:
		want = want.normalized()
	s.ix = want.x
	s.iy = want.y


func update(dt: float) -> void:
	if t >= LIMIT:
		finished = true
		_sync(dt)
		return
	_clams_step()
	_jellies_step()
	for s in st:
		_move(s, dt)
	_separate()
	_stings()
	_collect()
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _move(s: Dictionary, dt: float) -> void:
	var stunned: bool = t - float(s.stun_t) < STUN
	var ix: float = 0.0 if stunned else s.ix
	var iy: float = 0.0 if stunned else s.iy
	s.vx += ix * ACC * dt
	s.vy += iy * ACC * dt
	var fr := pow(DRAG if not stunned else 0.2, dt)
	s.vx *= fr
	s.vy *= fr
	var sp := Vector2(s.vx, s.vy).length()
	if sp > MAXV:
		s.vx *= MAXV / sp
		s.vy *= MAXV / sp
	s.x += s.vx * dt
	s.y += s.vy * dt
	_push_out(s)


func _separate() -> void:
	for i in st.size():
		for j in range(i + 1, st.size()):
			var a: Dictionary = st[i]
			var b: Dictionary = st[j]
			var dv := Vector2(a.x - b.x, a.y - b.y)
			var d := dv.length()
			if d >= BODY * 2 or d < 0.0001:
				continue
			var nrm := dv / d
			var ov := BODY * 2 - d
			a.x += nrm.x * ov / 2
			a.y += nrm.y * ov / 2
			b.x -= nrm.x * ov / 2
			b.y -= nrm.y * ov / 2
	for s in st:
		_push_out(s)


## Kagylók: zárva vár -> nyílik (gyöngy) -> nyitva, amíg valaki el nem viszi, vagy le nem jár -> zárul.
func _clams_step() -> void:
	for c in clams:
		match c.state:
			"closed":
				if t >= float(c.open_at):
					c.state = "opening"
					c.t0 = t
					c.has = true
			"opening":
				if t - float(c.t0) >= OPEN_DUR:
					c.state = "open"
					c.t0 = t
			"open":
				if t - float(c.t0) >= OPEN_MAX:
					_close(c)
			"closing":
				if t - float(c.t0) >= OPEN_DUR:
					c.state = "closed"


func _close(c: Dictionary) -> void:
	c.state = "closing"
	c.t0 = t
	c.has = false
	c.open_at = t + OPEN_DUR + randf_range(CLOSED_MIN, CLOSED_MAX)


## Medúzák: lassú, sima lebegés (a játékidőből számolva, így minden gépen ugyanott vannak).
func _jellies_step() -> void:
	for j in jellies:
		var w: float = j.w
		var ph: float = j.k * 1.7
		j.x = j.cx + j.ax * sin(t * w + ph)
		j.y = j.cy + j.ay * sin(t * w * 1.6 + ph * 0.7) + 0.15 * sin(t * 1.3 + ph)


func _stings() -> void:
	for s in st:
		if t - float(s.stun_t) < STUN or t < float(s.safe_until):
			continue
		for j in jellies:
			var me := Vector2(s.x, s.y)
			var bell := Vector2(j.x, j.y + 0.15)
			var tent := Vector2(j.x, j.y - 0.55)
			if me.distance_to(bell) < BODY + JELLY_R * 0.9 or me.distance_to(tent) < BODY + 0.25:
				s.stun_t = t
				s.safe_until = t + STUN + SAFE
				print_verbose("[pearl] %.2f mp: %s megbénult" % [t, s.p.name])
				var away := (me - Vector2(j.x, j.y)).normalized()
				s.vx = away.x * 3.0
				s.vy = away.y * 3.0
				Audio.play("zap")
				Net.vibrate(s.p.pid, [60, 40, 60, 40, 120])
				var q := screen(Vector3(s.x, s.y + 0.6, 0))
				Main.I.burst(q.x, q.y, {"n": 18, "colors": ["#fff3bf", "#ffe066", "#e599f7"], "speed": 260, "life": 0.5, "size": 5})
				break


## Gyöngyszedés: ha egy lépésben többen is elérik ugyanazt a gyöngyöt, a legközelebbi kapja
## (egyforma távolságnál a kisebb sorszámú) – egy gyöngyöt csak egyvalaki vihet el.
func _collect() -> void:
	for c in clams:
		if not c.has or c.state != "open" and not (c.state == "opening" and t - float(c.t0) >= OPEN_DUR * 0.6):
			continue
		var pp := Vector2(c.x, c.y + 0.42)
		var who: Dictionary = {}
		var best := PICK_R
		for s in st:
			if t - float(s.stun_t) < STUN:
				continue
			var d := Vector2(s.x, s.y).distance_to(pp)
			if d < best:
				best = d
				who = s
		if who.is_empty():
			continue
		who.score = int(who.score) + 1
		who.got_t = t
		print_verbose("[pearl] %.2f mp: %s gyöngyöt szerzett (%d)" % [t, who.p.name, who.score])
		_close(c)
		Audio.play("pearl")
		Audio.play("bubble", 1.3)
		Net.vibrate(who.p.pid, 40)
		var q := screen(Vector3(c.x, c.y + 0.5, 0.1))
		Main.I.burst(q.x, q.y, {"n": 26, "colors": ["#ff9ad5", "#ffffff", "#ffd6f0", (who.col as Color).to_html()], "speed": 300, "gravity": -40, "life": 0.7, "size": 6})
		Main.I.float_text(q.x, q.y - 30, "+1", (who.col as Color).lightened(0.35), 40)


func ranking() -> Array:
	return rank_by(func(p): return float(_get(p).score), func(p): return "%d 🦪" % int(_get(p).score))


# ------------------------------------------------------------------ látvány
func _sync(dt: float) -> void:
	var tm: float = Main.I.time
	for s in st:
		_anim_player(s, dt)
	for c in clams:
		var k := 0.0
		match c.state:
			"opening": k = clampf((t - float(c.t0)) / OPEN_DUR, 0.0, 1.0)
			"open": k = 1.0
			"closing": k = 1.0 - clampf((t - float(c.t0)) / OPEN_DUR, 0.0, 1.0)
		c.k = k
		var e := D.ease_out_back(k) if c.state == "opening" else D.ease_in_out(k)
		(c.hinge as Node3D).rotation.x = -1.05 * e + (sin(tm * 3.0 + float(c.x)) * 0.03 if c.state == "open" else 0.0)
		var pearl: Node3D = c.pearl
		pearl.visible = c.has and k > 0.05
		pearl.scale = Vector3.ONE * 0.2 * (0.9 + 0.1 * sin(tm * 5.0 + float(c.y))) * minf(1.0, k * 1.6)
		pearl.position.y = 0.36 + 0.04 * sin(tm * 3.0 + float(c.x))
		(c.glow as OmniLight3D).light_energy = (0.7 + 0.25 * sin(tm * 6.0)) * k if c.has else 0.0
	for j in jellies:
		var g: Node3D = j.g
		var pulse := sin(tm * 2.4 + j.k)
		g.position = Vector3(j.x, j.y, 0.1)
		var body: Node3D = j.body
		body.scale = Vector3(1.0 + 0.12 * pulse, 1.15 - 0.14 * pulse, 1.0 + 0.12 * pulse)
		(j.rim as Node3D).scale = Vector3(1.0 + 0.12 * pulse, 1.0, 1.0 + 0.12 * pulse)
		g.rotation = Vector3(sin(tm * 0.7 + j.k) * 0.12, tm * 0.2, sin(tm * 0.9 + j.k) * 0.1)
		for tn in j.tents:
			(tn.n as Node3D).rotation = Vector3(sin(tm * 2.0 - tn.q * 0.6 + tn.j) * 0.25, 0, cos(tm * 1.7 - tn.q * 0.5 + tn.j) * 0.2)
	for w in weeds:
		var segs: Array = w.segs
		for q in segs.size():
			(segs[q] as Node3D).rotation.z = sin(tm * 1.1 + w.ph - q * 0.5) * 0.12 * (0.5 + q * 0.2)
	for r in rays:
		var m: StandardMaterial3D = (r.mi as MeshInstance3D).material_override
		m.albedo_color.a = r.a * (0.6 + 0.4 * sin(tm * 0.8 + r.ph))
	for b in amb:
		var y := fposmod(float(b.y0) + tm * float(b.v), 13.0)
		(b.mi as Node3D).position = Vector3(b.x + sin(tm * 1.5 + b.ph) * 0.15, y, b.z)
		(b.mi as Node3D).scale = Vector3.ONE * float(b.s)
	for b in bubbles:
		b.life += dt
		b.p += Vector3(sin(tm * 6.0 + b.ph) * 0.3, 1.2, 0) * dt
		var mi: Node3D = b.mi
		mi.position = b.p
		mi.scale = Vector3.ONE * float(b.s) * (1.0 + b.life * 0.5)
		if b.life >= 1.1:
			mi.queue_free()
	bubbles = bubbles.filter(func(b): return b.life < 1.1)


func _bubble(pos: Vector3, s := 1.0) -> void:
	if bubbles.size() > 140:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = bubble_mesh
	mi.material_override = bubble_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	bubbles.append({"mi": mi, "p": pos, "life": 0.0, "s": s * FX.fr(0.6, 1.2), "ph": FX.fr(0, TAU)})


func _anim_player(s: Dictionary, dt: float) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var tt: float = m.t
	var v := Vector2(s.vx, s.vy)
	var spd := v.length()
	var run := clampf(spd / MAXV, 0.0, 1.0)
	var stunned: bool = t - float(s.stun_t) < STUN and phase_started()
	# irány: oldalra úszva oldalt néz, lassan a kamera felé fordul
	var yaw_t := 0.0
	if absf(s.vx) > 0.6:
		yaw_t = PI / 2.0 * signf(s.vx)
	elif spd < 0.6:
		yaw_t = 0.0
	else:
		yaw_t = float(s.yaw)
	s.yaw = lerp_angle(float(s.yaw), yaw_t, minf(1.0, dt * 7.0)) if dt > 0.0 else yaw_t
	# testtartás: vízszintes úszásnál előredől, felfelé úszva felegyenesedik, lefelé fejest ugrik
	var h := absf(s.vx) / maxf(0.01, spd)
	var up: float = s.vy / maxf(0.01, spd)
	var lean_t := run * (0.35 + 0.85 * h) + (0.55 * run * maxf(0.0, -up))
	s.lean = lerpf(float(s.lean), lean_t, minf(1.0, dt * 6.0))
	var ph := tt * (6.0 + run * 5.0)
	var c := cos(ph)
	var arms_t: Array = []
	var lift := [0.0, 0.0]
	var face := Vector3(0.15, 1.0, 0.2)
	var roll := sin(tt * 1.6 + s.i) * 0.05
	var spin := 0.0
	var bob := sin(tt * 2.2 + s.i) * 0.08
	if stunned:
		# bénulás: forog, ráz, kába arc
		var sk: float = t - float(s.stun_t)
		spin = sk * 7.0 * maxf(0.2, 1.0 - sk / STUN)
		roll = sin(tt * 40.0) * 0.15
		arms_t = [Vector3(-0.5, 0.75 + sin(tt * 30.0) * 0.1, 0.1), Vector3(0.5, 0.75 - sin(tt * 30.0) * 0.1, 0.1)]
		face = Vector3(0.55, 1.25, 0.9)
		s.lean = lerpf(float(s.lean), 0.0, minf(1.0, dt * 6.0))
	elif spd > 0.8:
		# mellúszás: a kezek előrenyúlnak, aztán oldalra húznak; a lábak tempóznak
		var open := (1.0 - c) / 2.0
		arms_t = [Vector3(-(0.15 + 0.4 * open), 0.62 + 0.25 * (1.0 - open), 0.45 - 0.35 * open), Vector3(0.15 + 0.4 * open, 0.62 + 0.25 * (1.0 - open), 0.45 - 0.35 * open)]
		lift = [maxf(0.0, sin(ph * 2.0)) * 0.16, maxf(0.0, -sin(ph * 2.0)) * 0.16]
		face = Vector3(0.25, 1.05, 0.3)
		bob = 0.0
	else:
		# helyben tempózás
		arms_t = [Vector3(-0.42, 0.42 + sin(tt * 4.0) * 0.12, 0.12), Vector3(0.42, 0.42 - sin(tt * 4.0) * 0.12, 0.12)]
		lift = [maxf(0.0, sin(tt * 4.0)) * 0.08, maxf(0.0, -sin(tt * 4.0)) * 0.08]
	if t - float(s.got_t) < 0.8:
		face = Vector3(0.8, 1.1, 0.6)
	m.position = Vector3(s.x, s.y - 0.45 + bob + a.y * 0.3, 0)
	m.rotation = Vector3(float(s.lean), float(s.yaw) + spin + a.spin, roll + a.tilt)
	m.scale = Vector3.ONE * MS
	# védettség alatt villog
	m.visible = not (t < float(s.safe_until) and not stunned and fmod(t, 0.2) < 0.08)
	var feet: Array = s.feet
	for j in 2:
		(feet[j] as Node3D).position = Vector3((-1 if j == 0 else 1) * 0.14, 0.04 + lift[j], 0.05 - lift[j] * 0.8)
	for j in 2:
		K.arm_to(s.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, s.face, face.x, face.y, face.z)
	# buboréknyom
	s.bub = float(s.bub) - dt
	if s.bub <= 0.0 and dt > 0.0:
		s.bub = 0.1 if spd > 2.0 else 0.6
		_bubble(m.position + Vector3(FX.fr(-0.15, 0.15), 0.9, 0.1), 0.8 if spd > 2.0 else 0.6)


func phase_started() -> bool:
	return t > 0.0


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	for s in st:
		var q := screen(Vector3(s.x, s.y + 1.05, 0))
		D.text(c, s.p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 5, "maxw": 140, "color": (s.col as Color).lightened(0.45)})
		if t - float(s.stun_t) < STUN and t > 0.0:
			var a := t * 6.0
			for k in 3:
				var aa := a + k * TAU / 3.0
				D.emoji(c, "⭐", q.x + cos(aa) * 26, q.y - 16 + sin(aa) * 8, 18)
	# a nyitott kagylók gyöngyén csillanás
	for cl in clams:
		if cl.has and float(cl.k) > 0.5:
			var q := screen(Vector3(cl.x, cl.y + 0.45, 0.3))
			var tw := 0.5 + 0.5 * sin(Main.I.time * 7.0 + float(cl.x))
			D.text(c, "✦", q.x + 14, q.y - 16, {"size": int(14 + 10 * tw), "color": Color(1, 0.9, 1, 0.5 + 0.5 * tw)})
	K.silver_timer(c, LIMIT - t, 640, 46, 5.0, t)
	D.text(c, "🦪 Gyöngyhalászat", 24, 34, {"size": 26, "align": "left", "stroke": D.DARK, "sw": 6})
	D.text(c, "Gyöngy = +1 · a medúza megbénít!", 24, 64, {"size": 17, "align": "left", "color": Color("#c5f6fa"), "stroke": D.DARK, "sw": 5})
	D.score_bar(c, st.map(func(s): return s.p), func(p): return "%d 🦪" % int(_get(p).score), 684)
