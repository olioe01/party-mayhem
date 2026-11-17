extends RefCounted
## A Vakondvadász díszlete és modelljei (csak látvány, játékmeneti állapot nincs benne):
## türkiz, rombuszmintás tér fehér kerítéssel és sarokdíszekkel, a 3×3 lyuk zöld, kétszárnyú fedéllel,
## a barna és az arany vakond, valamint a felfújható játékkalapács.

const W = preload("res://scripts/minigames/presents_world.gd")

const HOLE_R := 0.47          # a lyuk belső sugara
const LID_OPEN := 1.95        # ennyit nyílik a fedél egy-egy szárnya (radián)


# ------------------------------------------------------------------ aréna
static func _floor_mat(tiles: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 base_col;
uniform vec3 line_col;
uniform vec3 dot_col;
uniform float tiles;
void fragment() {
	vec2 uv = UV * tiles;
	vec2 r = vec2(uv.x + uv.y, uv.x - uv.y);
	vec2 f = abs(fract(r) - 0.5);
	float dia = smoothstep(0.455, 0.49, max(f.x, f.y));
	vec2 g = abs(fract(uv) - 0.5);
	float dots = 1.0 - smoothstep(0.05, 0.075, length(g));
	vec3 c = mix(base_col, line_col, dia * 0.85);
	c = mix(c, dot_col, dots * 0.6);
	vec2 e = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.82, 1.0, max(e.x, e.y));
	c = mix(c, base_col * 0.78, edge * 0.55);
	ALBEDO = c;
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base_col", Color("#2ec4c0"))
	m.set_shader_parameter("line_col", Color("#8ff0e6"))
	m.set_shader_parameter("dot_col", Color("#ffffff"))
	m.set_shader_parameter("tiles", tiles)
	return m


static func _grass_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 a;
uniform vec3 b;
void fragment() {
	vec2 uv = UV * 26.0;
	float stripe = step(0.5, fract((uv.x + uv.y) * 0.25));
	ALBEDO = mix(a, b, stripe * 0.6);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("a", Color("#79c95b"))
	m.set_shader_parameter("b", Color("#93d86c"))
	return m


## A teljes tér: padló, szegély, kerítés, sarokdíszek, háttér. half: a padló fél oldalhossza.
static func build_arena(root: Node3D, half: float) -> void:
	# fű és dombok a háttérben
	var grass := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(90, 90)
	grass.mesh = gp
	grass.material_override = _grass_mat()
	grass.position.y = -0.42
	root.add_child(grass)
	var hill := Chars3D.mat("#5fb54c", {"rough": 0.95})
	var hill2 := Chars3D.mat("#4ea33f", {"rough": 0.95})
	for k in 7:
		var x := -21.0 + k * 7.0
		Chars3D.lsphere(root, 5.5 + (k % 3) * 1.2, hill if k % 2 == 0 else hill2, x, -2.6, -19.0 - (k % 2) * 3.0, 1.0, 0.75, 0.7, 12, 7)
	for x in [-12.5, -9.0, 9.0, 12.5]:
		W._tree(root, x, -8.5 + absf(x) * 0.1, 1.15).get_parent().position.y = -0.42
	for x in [-11.5, 11.5]:
		W._tree(root, x, -2.0, 1.0).get_parent().position.y = -0.42
		W._tree(root, x, 4.5, 0.95).get_parent().position.y = -0.42
	# talapzat (a padló alatt, kék oldallal és fehér-narancs szegéllyel)
	var blue := Chars3D.mat("#2f6fd6", {"rough": 0.4})
	var white := Chars3D.mat("#ffffff", {"rough": 0.35})
	var orange := Chars3D.mat("#ff8a1f", {"rough": 0.4})
	var s := half * 2.0
	Chars3D.box(root, s + 1.0, 0.42, s + 1.0, blue, Vector3(0, -0.22, 0))
	for sgn in [-1, 1]:
		Chars3D.box(root, s + 1.06, 0.07, 0.08, orange, Vector3(0, -0.36, sgn * (half + 0.51)))
		Chars3D.box(root, 0.08, 0.07, s + 1.06, orange, Vector3(sgn * (half + 0.51), -0.36, 0))
	# padló: rombuszmintás türkiz lap, körben fehér keret
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(s, s)
	fl.mesh = pm
	fl.material_override = _floor_mat(half * 0.9)
	fl.position.y = 0.0
	root.add_child(fl)
	for sgn in [-1, 1]:
		Chars3D.box(root, s + 1.0, 0.06, 0.5, white, Vector3(0, -0.02, sgn * (half + 0.25)))
		Chars3D.box(root, 0.5, 0.06, s, white, Vector3(sgn * (half + 0.25), -0.02, 0))
	_fence(root, half + 0.3)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_corner(root, Vector3(sx * (half + 0.55), 0, sz * (half + 0.55)), sx, sz)


## Fehér, rombuszhálós korlát a tér körül.
static func _fence(root: Node3D, e: float) -> void:
	var white := Chars3D.mat("#ffffff", {"rough": 0.3})
	var cream := Chars3D.mat("#eef4ff", {"rough": 0.35})
	var lo := 0.1
	var hi := 0.62
	var n := int(round(e * 2.0 / 0.82))
	var step := e * 2.0 / n
	for side in 4:
		# az oldal két végpontja (az óramutató járásával körbe)
		var a: Vector3
		var b: Vector3
		match side:
			0: a = Vector3(-e, 0, -e); b = Vector3(e, 0, -e)
			1: a = Vector3(e, 0, -e); b = Vector3(e, 0, e)
			2: a = Vector3(e, 0, e); b = Vector3(-e, 0, e)
			_: a = Vector3(-e, 0, e); b = Vector3(-e, 0, -e)
		var dir := (b - a) / (e * 2.0)
		W.seg(root, 0.035, white, a + Vector3(0, hi, 0), b + Vector3(0, hi, 0))
		W.seg(root, 0.025, white, a + Vector3(0, lo, 0), b + Vector3(0, lo, 0))
		for k in n:
			var p0 := a + dir * (k * step)
			var p1 := a + dir * ((k + 1) * step)
			# X alakú rácsszemek: egymás mellett rombuszhálót adnak
			W.seg(root, 0.014, cream, p0 + Vector3(0, lo, 0), p1 + Vector3(0, hi, 0))
			W.seg(root, 0.014, cream, p0 + Vector3(0, hi, 0), p1 + Vector3(0, lo, 0))
			if k > 0:
				Chars3D.cyl(root, 0.04, 0.045, hi + 0.08, white, p0.x, (hi + 0.08) / 2.0, p0.z, 8)
				Chars3D.sphere(root, 0.06, white, p0.x, hi + 0.1, p0.z)


## Sarokdísz: kék talapzat, fehér váz, narancs tető, színes ív, zöld bokrok.
static func _corner(root: Node3D, pos: Vector3, sx: int, sz: int) -> void:
	var g := Chars3D.grp(root, pos, Vector3(0, atan2(float(sx), float(sz)), 0))
	var blue := Chars3D.mat("#2a63d4", {"rough": 0.35})
	var blue2 := Chars3D.mat("#4f8df0", {"rough": 0.35})
	var white := Chars3D.mat("#ffffff", {"rough": 0.3})
	var orange := Chars3D.mat("#ff8a1f", {"rough": 0.35})
	var yellow := Chars3D.mat("#ffd43b", {"rough": 0.35})
	var red := Chars3D.mat("#ff4d6d", {"rough": 0.35})
	var green := Chars3D.mat("#3fae4a", {"rough": 0.8})
	var green2 := Chars3D.mat("#5cc95a", {"rough": 0.8})
	# talapzat
	Chars3D.lcyl(g, 0.62, 0.7, 0.5, blue, 0, 0.25, 0, 8)
	Chars3D.lcyl(g, 0.66, 0.66, 0.08, orange, 0, 0.52, 0, 8)
	# fehér oszlopváz
	for k in 4:
		var an := TAU * k / 4.0 + PI / 4.0
		Chars3D.cyl(g, 0.05, 0.05, 1.05, white, sin(an) * 0.42, 1.06, cos(an) * 0.42, 8)
	Chars3D.lcyl(g, 0.6, 0.6, 0.1, white, 0, 1.6, 0, 8)
	Chars3D.lcone(g, 0.66, 0.55, orange, 0, 1.93, 0, 8)
	Chars3D.sphere(g, 0.1, yellow, 0, 2.27, 0)
	Chars3D.lsphere(g, 0.3, blue2, 0, 0.95, 0, 1, 1, 1, 8, 6)
	# színes ív a talapzat fölött, a tér felé fordulva
	var arc_cols := [red, orange, yellow, blue2]
	for k in arc_cols.size():
		var r := 0.95 - k * 0.09
		Chars3D.part(g, Chars3D.arc_tube(r, 0.045, PI, 20, 6), arc_cols[k], Vector3(0, 0.55, -0.15), Vector3.ONE, Vector3(0, PI / 2, 0))
	# bokrok
	for b in [[0.75, -0.55, 0.36], [-0.55, 0.8, 0.32], [0.95, 0.35, 0.26], [0.2, 0.95, 0.24]]:
		Chars3D.lsphere(g, b[2], green if int(b[2] * 100) % 2 == 0 else green2, b[0], b[2] * 0.7, b[1], 1, 0.85, 1, 8, 6)


# ------------------------------------------------------------------ lyuk
static func _half_disc(r: float, d: float, seg := 12) -> ArrayMesh:
	# a +x felé eső félkorong, az egyenes éle a z tengelyen; vastagsága y irányú
	var v := PackedVector3Array()
	var h := d / 2.0
	for i in seg:
		var a0 := -PI / 2 + PI * i / seg
		var a1 := -PI / 2 + PI * (i + 1) / seg
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		v.append_array(PackedVector3Array([
			Vector3(0, h, 0), p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0),
			Vector3(0, -h, 0), p0 - Vector3(0, h, 0), p1 - Vector3(0, h, 0),
			p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), p1 - Vector3(0, h, 0),
			p0 + Vector3(0, h, 0), p1 - Vector3(0, h, 0), p0 - Vector3(0, h, 0)]))
	v.append_array(PackedVector3Array([
		Vector3(0, h, -r), Vector3(0, h, r), Vector3(0, -h, r),
		Vector3(0, h, -r), Vector3(0, -h, r), Vector3(0, -h, -r)]))
	return Chars3D.flat_mesh(v, Vector3(r * 0.4, 0, 0))


## Egy lyuk: fém perem, sötét nyílás, kétszárnyú zöld fedél, benne egy barna és egy arany vakond.
static func build_hole(root: Node3D, pos: Vector3) -> Dictionary:
	var g := Chars3D.grp(root, pos)
	var metal := Chars3D.mat("#c3ccd6", {"rough": 0.22, "metal": 0.75})
	var metal_d := Chars3D.mat("#7d8894", {"rough": 0.3, "metal": 0.7})
	Chars3D.part(g, Chars3D.torus(HOLE_R + 0.06, 0.07), metal, Vector3(0, 0.035, 0))
	Chars3D.cyl(g, HOLE_R + 0.13, HOLE_R + 0.15, 0.03, metal_d, 0, 0.012, 0, 32)
	for k in 8:
		var an := TAU * k / 8.0
		Chars3D.sphere(g, 0.028, metal_d, sin(an) * (HOLE_R + 0.06), 0.1, cos(an) * (HOLE_R + 0.06))
	var dark := Chars3D.cyl(g, HOLE_R, HOLE_R, 0.02, Chars3D.mat("#070b07", {"unshaded": true}), 0, 0.03, 0, 32)
	# vakondok (a sötét korong alatt rejtőznek)
	var mole := build_mole(g, false)
	var gold := build_mole(g, true)
	# fedél: két félkorong, a külső szélükön csuklóval
	var lid_m := Chars3D.mat("#3cc24a", {"rough": 0.35})
	var lid_l := Chars3D.mat("#7ee07a", {"rough": 0.35})
	var lid_d := Chars3D.mat("#2a9a38", {"rough": 0.4})
	var lids: Array = []
	for side in [-1, 1]:
		var hinge := Chars3D.grp(g, Vector3(side * HOLE_R, 0.062, 0))
		var leaf := Chars3D.grp(hinge, Vector3(-side * HOLE_R, 0, 0))
		var hd := Chars3D.part(leaf, _half_disc(HOLE_R - 0.005, 0.04), lid_m, Vector3.ZERO, Vector3.ONE, Vector3(0, 0 if side > 0 else PI, 0))
		hd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# sugárirányú díszcsíkok és perem a félkorongon
		for k in 3:
			var an := -PI / 3.0 + PI / 3.0 * k
			var dx: float = cos(an) * side
			var dz: float = sin(an)
			W.seg(leaf, 0.018, lid_l, Vector3(dx * 0.1, 0.022, dz * 0.1), Vector3(dx * 0.4, 0.022, dz * 0.4))
		var rim := Chars3D.grp(leaf, Vector3(0, 0.022, 0), Vector3(0, side * PI / 2, 0))
		Chars3D.part(rim, Chars3D.arc_tube(HOLE_R - 0.06, 0.016, PI, 12, 4), lid_d, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
		Chars3D.sphere(leaf, 0.05, lid_l, side * 0.02, 0.02, 0, 1, 0.5, 1)
		lids.append({"hinge": hinge, "side": side})
	return {"g": g, "lids": lids, "mole": mole, "gold": gold, "dark": dark}


## A fedél nyitottsága (0 = zárt, 1 = nyitott).
static func set_lid(hole: Dictionary, open: float) -> void:
	for l in hole.lids:
		(l.hinge as Node3D).rotation.z = -float(l.side) * LID_OPEN * open


# ------------------------------------------------------------------ vakond
## Kerek, játékfigura-szerű vakond. A test közepe a lyuk szintjén van, ha teljesen kibújt.
static func build_mole(parent: Node3D, gold: bool) -> Dictionary:
	var g := Chars3D.grp(parent)
	var root := Chars3D.grp(g)
	var fur := Chars3D.mat("#ffc21a", {"rough": 0.18, "metal": 0.55, "emit": "#ff9d00", "emit_e": 0.45}) if gold else Chars3D.mat("#8a5a34", {"rough": 0.6})
	var light := Chars3D.mat("#ffe680", {"rough": 0.2, "metal": 0.4, "emit": "#ffcc33", "emit_e": 0.35}) if gold else Chars3D.mat("#d8a777", {"rough": 0.6})
	var pink := Chars3D.mat("#ff7f9b", {"rough": 0.35})
	var black := Chars3D.mat("#14101a", {"rough": 0.2})
	var white := Chars3D.mat("#ffffff", {"rough": 0.2, "emit": "#ffffff", "emit_e": 0.6 if gold else 0.0})
	var body := Chars3D.part(root, Chars3D.lathe([[0.0, -0.75], [0.29, -0.74], [0.31, -0.2], [0.31, 0.18], [0.285, 0.36], [0.22, 0.5], [0.12, 0.57], [0.0, 0.59]], 22), fur)
	Chars3D.sphere(root, 0.2, light, 0, 0.0, 0.17, 1.0, 1.25, 0.6)
	# pofa
	Chars3D.sphere(root, 0.13, light, 0, 0.2, 0.24, 1.25, 0.85, 0.85)
	Chars3D.sphere(root, 0.065, pink, 0, 0.255, 0.35, 1.25, 0.85, 1.0)
	Chars3D.sphere(root, 0.02, white, -0.02, 0.275, 0.4)
	Chars3D.smile(root, 0.15, 0.335, 0.05, black)
	Chars3D.box(root, 0.035, 0.045, 0.02, white, Vector3(-0.02, 0.125, 0.335))
	Chars3D.box(root, 0.035, 0.045, 0.02, white, Vector3(0.02, 0.125, 0.335))
	# nagy, egyszerű fekete szemek fénypöttyel
	var eyes: Array = []
	for sx in [-1, 1]:
		var e := Chars3D.grp(root, Vector3(sx * 0.105, 0.36, 0.25))
		Chars3D.sphere(e, 0.06, black, 0, 0, 0, 0.85, 1.15, 0.6)
		Chars3D.sphere(e, 0.02, white, 0.018, 0.025, 0.03)
		eyes.append(e)
		# fülek
		Chars3D.sphere(root, 0.065, fur, sx * 0.25, 0.43, -0.02, 1.0, 0.8, 0.5)
		Chars3D.sphere(root, 0.035, pink, sx * 0.25, 0.43, 0.01, 1.0, 0.8, 0.4)
		# bajusz
		W.seg(root, 0.006, black, Vector3(sx * 0.1, 0.22, 0.33), Vector3(sx * 0.24, 0.25, 0.3))
		W.seg(root, 0.006, black, Vector3(sx * 0.1, 0.2, 0.33), Vector3(sx * 0.24, 0.18, 0.31))
	# kis kezek a peremen, karmokkal
	var hands: Array = []
	for sx in [-1, 1]:
		var h := Chars3D.grp(root, Vector3(sx * 0.24, -0.02, 0.22))
		Chars3D.sphere(h, 0.075, pink if not gold else light, 0, 0, 0, 1.1, 0.7, 1.0)
		for c in 3:
			Chars3D.sphere(h, 0.018, white, (c - 1) * 0.035, -0.01, 0.07)
		hands.append(h)
	# arany vakond: körülötte keringő szikrák
	var sparks: Array = []
	if gold:
		var sp := Chars3D.mat("#fff3b0", {"emit": "#ffe066", "emit_e": 2.2, "unshaded": true})
		for k in 4:
			var s := Chars3D.lsphere(root, 0.045, sp, 0, 0, 0, 1, 1, 1, 6, 4)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sparks.append(s)
	for n in g.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visible = false
	return {"g": g, "root": root, "body": body, "eyes": eyes, "hands": hands, "sparks": sparks}


# ------------------------------------------------------------------ kalapács
## Óriási, felfújható játékkalapács. A „hn” csomópont a fogás helye; a nyél a helyi +Y felé áll,
## a fej (henger) tengelye a helyi Z – így lecsapáskor a fej lapja ér a földre.
## hl: a fogástól a fej közepéig mért távolság.
static func build_hammer(parent: Node3D, hex: String, hl: float) -> Dictionary:
	var col := Color(hex)
	var main := Chars3D.mat(hex, {"rough": 0.28})
	var light := Chars3D.mat(col.lightened(0.35).to_html(false), {"rough": 0.28})
	var dark := Chars3D.mat(col.darkened(0.25).to_html(false), {"rough": 0.35})
	var white := Chars3D.mat("#ffffff", {"rough": 0.3})
	var hn := Chars3D.grp(parent)
	# nyél: színes cső, fehér markolatcsíkokkal, gömb a végén
	Chars3D.cyl(hn, 0.05, 0.05, hl + 0.26, dark, 0, (hl - 0.26) / 2.0, 0, 10)
	for k in 3:
		Chars3D.cyl(hn, 0.058, 0.058, 0.045, white, 0, -0.16 + k * 0.1, 0, 10)
	Chars3D.sphere(hn, 0.085, light, 0, -0.27, 0)
	Chars3D.cyl(hn, 0.075, 0.09, 0.08, light, 0, hl - 0.33, 0, 12)
	# fej
	var head := Chars3D.grp(hn, Vector3(0, hl, 0))
	var hr := 0.36
	var hlen := 0.88
	var rx := Vector3(PI / 2, 0, 0)
	Chars3D.cyl(head, hr, hr, hlen - 0.12, main, 0, 0, 0, 28, rx)
	for sgn in [-1.0, 1.0]:
		# párnázott, lekerekített végek
		Chars3D.part(head, Chars3D.torus(hr - 0.05, 0.06), main, Vector3(0, 0, sgn * (hlen / 2 - 0.06)), Vector3.ONE, rx)
		Chars3D.sphere(head, hr - 0.05, light, 0, 0, sgn * (hlen / 2 - 0.05), 1.0, 1.0, 0.22)
		Chars3D.part(head, Chars3D.torus(hr - 0.17, 0.025), white, Vector3(0, 0, sgn * (hlen / 2 + 0.005)), Vector3.ONE, rx)
		# vízszintes díszcsíkok
		Chars3D.cyl(head, hr + 0.012, hr + 0.012, 0.065, white, 0, 0, sgn * 0.2, 28, rx)
	Chars3D.cyl(head, hr + 0.02, hr + 0.02, 0.11, light, 0, 0, 0, 28, rx)
	return {"hn": hn, "head": head}
