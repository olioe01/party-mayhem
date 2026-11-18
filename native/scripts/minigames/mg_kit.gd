extends RefCounted
## Közös segédek a Kártyafogó, a Tűzijáték-pumpa és a Sínharc minijátékhoz:
## helyszínek színei, fényes óra, helyezéscímkék, karok és arckifejezés.

const W = preload("res://scripts/minigames/presents_world.gd")
const Presents = preload("res://scripts/minigames/mg_presents.gd")

## a négy hely saját színe (kék, piros, zöld, narancs)
const SLOT_COLORS := ["#2f80ff", "#f03e3e", "#2fb344", "#ff8c1a"]
const PLACE_COLORS := ["#ffd43b", "#dee2e6", "#f4a261", "#9aa5b1"]
const PLACE_DARK := ["#b35c00", "#495057", "#8a4b14", "#3d4752"]
const PLACE_TEXT := ["1.", "2.", "3.", "4."]
const ARM_L := 0.6


## Gépi kitöltő ellenfél nincs: minden minijátékban pontosan annyi résztvevő van, ahány valódi
## játékos a szobában (globális szabály). A gépi szintek csak a fejlesztői tesztbotokra (--bots)
## és a lecsatlakozott játékosok helyett játszó automatikára vonatkoznak.

## gépi nehézség: 0 = könnyű, 1 = közepes, 2 = nehéz; a gépek sorban más-más szintet kapnak
static func ai_level(k: int) -> int:
	return [1, 2, 0][k % 3]


const LEVEL_NAME := ["könnyű", "közepes", "nehéz"]


# ------------------------------------------------------------------ 2D felület
## Ezüstös, fényes, lekerekített óra stopperórával a képernyő tetején.
static func silver_timer(c: CanvasItem, remain: float, x := 640.0, y := 46.0, low_at := 5.0, t := 0.0) -> void:
	var r: float = max(0.0, remain)
	var low := r <= low_at and r > 0.0
	var pulse: float = 1.0 + (0.07 * abs(sin(t * 7.0)) if low else 0.0)
	c.draw_set_transform(Vector2(x, y), 0, Vector2(pulse, pulse))
	D.panel(c, -92, -33, 184, 66, {"r": 33, "fill": Color("#ffffff"), "stroke": null})
	D.panel(c, -86, -27, 172, 54, {"r": 27, "fill": Color("#d9363e") if low else Color("#8e9aab"), "stroke": null, "shadow": false})
	D.panel(c, -86, -2, 172, 29, {"r": 14, "fill": Color(0, 0, 0, 0.12), "stroke": null, "shadow": false})
	D.panel(c, -78, -23, 156, 22, {"r": 11, "fill": Color(1, 1, 1, 0.42), "stroke": null, "shadow": false})
	D.emoji(c, "⏱", -50, 1, 34)
	D.text(c, "%d" % ceili(r), 24, 2, {"size": 42, "stroke": Color("#7a1010") if low else Color("#2b3442"), "sw": 7})
	c.draw_set_transform(Vector2.ZERO)


## Nagy, színes, „3D” hatású helyezéscímke (1. 2. 3. 4.), k: 0..1 beúszás
static func place_label(c: CanvasItem, place: int, x: float, y: float, k := 1.0, size := 64) -> void:
	if k <= 0.0:
		return
	place = clampi(place, 0, 3)
	var s := D.ease_out_back(clamp(k, 0.0, 1.0))
	c.draw_set_transform(Vector2(x, y), sin(k * 9.0) * 0.06 * (1.0 - min(1.0, k)), Vector2(s, s))
	var col := Color(PLACE_COLORS[place])
	var dark := Color(PLACE_DARK[place])
	# kihúzott „mélység”: több eltolt, sötét réteg, rajta a világos lap
	for i in range(5, 0, -1):
		D.text(c, PLACE_TEXT[place], i * 1.4, i * 2.0, {"size": size, "color": dark, "stroke": D.DARK, "sw": 10})
	D.text(c, PLACE_TEXT[place], 0, 0, {"size": size, "color": col, "stroke": Color.WHITE, "sw": 6})
	c.draw_set_transform(Vector2.ZERO)


## Kék-fehér, nagy, beúszó felirat (pl. „Jegyezd meg!”)
static func banner(c: CanvasItem, text: String, k: float, dur: float, y := 196.0, col := Color("#ffffff"), size := 72) -> void:
	if k < 0.0 or k > dur:
		return
	var sc := D.ease_out_back(min(1.0, k * 4.5)) * (1.0 + sin(k * 9.0) * 0.025)
	var alpha: float = clamp((dur - k) / 0.3, 0.0, 1.0)
	c.draw_set_transform(Vector2(640, y), sin(k * 7.0) * 0.015, Vector2(sc, sc))
	D.text(c, text, 0, 0, {"size": size, "color": col, "stroke": Color("#1c4fd6"), "sw": 14, "alpha": alpha, "maxw": 1150})
	c.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ figurák: kar és arc
## Két kar (felkar, alkar, könyök, kesztyűs kéz) a figura saját terében.
static func build_arms(m: Chars3D.CharModel, sleeve_hex: String, arm_len := ARM_L) -> Array:
	var sleeve := Chars3D.mat(sleeve_hex, {"rough": 0.5})
	var glove := Chars3D.mat("#ffffff", {"rough": 0.4})
	var arms: Array = []
	for side in [-1, 1]:
		var sh := Vector3(side * 0.3, 0.56, 0.02)
		Chars3D.sphere(m, 0.075, sleeve, sh.x, sh.y, sh.z)
		arms.append({"side": side, "sh": sh, "len": arm_len,
			"up": W.seg(m, 0.055, sleeve), "fore": W.seg(m, 0.048, sleeve),
			"elbow": Chars3D.sphere(m, 0.058, sleeve), "hand": Chars3D.sphere(m, 0.09, glove)})
	return arms


## Kétcsontos IK: a kéz a célpontba (a figura saját terében) nyúl, a könyök a bend irányába hajlik.
## bend.x: mennyire álljon ki oldalra a könyök (a kar oldalával szorozva)
static func arm_to(arm: Dictionary, target: Vector3, bend := Vector3(1, -0.35, -0.45)) -> void:
	var sh: Vector3 = arm.sh
	var side: float = arm.side
	var d := target - sh
	var al: float = arm.get("len", ARM_L)
	var dl: float = clamp(d.length(), 0.08, al * 2 - 0.004)
	var dir := d.normalized()
	var aa := dl / 2.0
	var hh: float = sqrt(max(0.0, al * al - aa * aa))
	var b := Vector3(side * bend.x, bend.y, bend.z)
	b = b - dir * b.dot(dir)
	if b.length() < 0.001:
		b = Vector3(side, 0, 0)
	b = b.normalized()
	var elbow := sh + dir * aa + b * hh
	var hand := sh + dir * dl
	W.place_seg(arm.up, sh, elbow)
	W.place_seg(arm.fore, elbow, hand)
	(arm.elbow as Node3D).position = elbow
	(arm.hand as Node3D).position = hand


## Szemöldök és kitátható száj a figura meglévő szemeihez igazítva.
static func build_face(m: Chars3D.CharModel) -> Dictionary:
	var f := {"brows": [], "mouth": null, "eye_r": 0.06}
	var dark := Chars3D.mat("#1f1b2e", {"rough": 0.4})
	if m.eyes.size() >= 2:
		var e0: Node3D = m.eyes[0]
		if e0.get_child_count() > 0 and e0.get_child(0) is MeshInstance3D and (e0.get_child(0) as MeshInstance3D).mesh is SphereMesh:
			f.eye_r = ((e0.get_child(0) as MeshInstance3D).mesh as SphereMesh).radius
		var r: float = max(0.04, f.eye_r)
		for k in 2:
			var b := Chars3D.box(m.eyes[k], r * 1.7, r * 0.34, r * 0.4, dark, Vector3(0, r * 1.45, r * 0.55))
			b.visible = false
			f.brows.append(b)
	var md: Array = Presents.MOUTHS.get(m.char_id, [])
	if not md.is_empty():
		var mo := Chars3D.sphere(m.rig, md[2], Chars3D.mat("#3b1220", {"rough": 0.6}), 0, md[0], md[1], 1.0, 1.25, 0.55)
		Chars3D.sphere(mo, md[2] * 0.55, Chars3D.mat("#ff6b81"), 0, -md[2] * 0.45, md[2] * 0.25, 1, 0.6, 0.6)
		mo.visible = false
		f.mouth = mo
	return f


## Arckifejezés: open = tátott száj (0..1), wide = tágra nyílt szem, brow > 0 felhúzott (meglepett),
## brow < 0 összehúzott (szomorú/erőlködő) szemöldök.
static func set_face(m: Chars3D.CharModel, f: Dictionary, open: float, wide: float, brow: float) -> void:
	for e in m.eyes:
		var blinking: bool = (e as Node3D).scale.y < 0.5
		(e as Node3D).scale = Vector3(wide, 0.1 if blinking else wide, wide)
	var r: float = f.eye_r
	for k in f.brows.size():
		var b: MeshInstance3D = f.brows[k]
		var side := -1.0 if k == 0 else 1.0
		b.visible = abs(brow) > 0.05
		b.position.y = r * (1.4 + 0.45 * max(0.0, brow))
		b.rotation.z = side * 0.45 * brow if brow < 0 else -side * 0.15 * brow
	if f.mouth:
		var mo: MeshInstance3D = f.mouth
		mo.visible = open > 0.08
		mo.scale = Vector3(0.6 + 0.5 * open, 0.35 + 1.1 * open, 0.55)
