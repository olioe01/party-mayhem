class_name HighwayLayout
extends RefCounted
## Óceánsztráda – a pálya és a szabályok számai egy helyen (minden itt állítható).
## Kanyargós, az óceán fölött húzódó sztráda, 0 = rajt, GOAL = célkapu. A haladást a mező
## sorszáma adja; a világbeli helyet a középvonal (CURVE_KEYS) és a sáv (oldalirányú eltolás, hogy
## a figurák ne takarják egymást) adja.

const GOAL := 351
const CP_BRIDGE := 100           # 1. ellenőrzőpont: felvonóhíd – egy kockával páratlan kell
const CP_LIGHTS := 200           # 2. ellenőrzőpont: jelzőlámpás kapu – 5 piros-zöld kockából legalább egy zöld
const LIGHT_DICE := 5
const LIGHT_GREEN_FACES := 2     # a lámpakocka 6 lapjából ennyi zöld
const ROCKET_TO := 190           # a rakéta idáig repít (visszafelé soha)
const FINAL_DICE := 10
const FINAL_NEED := [40, 35]     # első próbálkozás, utána minden további
const FINAL_FAIL_BACK := 15
const MATCH_BONUS := 5           # ha minden kocka ugyanazt mutatja: ennyi plusz kocka
const DUEL_SOLO_DICE := 5        # „1 a többiek ellen”: ha az egyedül játszó nyer
const DUEL_TEAM_DICE := 2        # … ha a többiek nyernek, fejenként
const LAST_BOOST := [10, 20, 30, -1]   # felzárkózó mező kimenetei (-1: UFO az élen állóhoz)
const SP := 1.5                  # két mező távolsága (világegység)
const LANE := 0.86               # két sáv távolsága
const LANES := 8
const ROAD_W := 8.4
const RUN_SPEED := 8.0           # mező / mp futás közben

## Kockajutalom a minijáték helyezése szerint, a résztvevők számától függően.
const REWARDS := {
	1: [10],
	2: [10, 2],
	3: [10, 6, 2],
	4: [10, 7, 4, 2],
	5: [10, 8, 6, 4, 2],
	6: [10, 9, 7, 6, 4, 2],
	7: [10, 9, 8, 7, 5, 4, 2],
	8: [10, 9, 8, 7, 6, 5, 4, 2],
}

## Dobás-értékelés a kockák számához igazítva: jó, ha összeg >= kocka × GOOD_K, gyenge, ha < kocka × BAD_K.
## (10 kockánál: 40 felett jó, 29 alatt gyenge; 2 kockánál: 8 felett jó, 5 alatt gyenge.)
const GOOD_K := 4.0
const BAD_K := 3.0

## Különleges mezők. Típusok: F (hátszél: előre), B (szembeszél: hátra), BD (kék kockamező: előre a dobott
## összeggel), RD (piros kockamező: hátra), LAST (felzárkózó), UFO, ROCKET, DUEL (1 a többiek ellen).
## Futamokban megadva: [első mező, típus, érték, hány egymást követő mező]. A mennyiséget ez a lista adja
## (most 181 mező, a pálya ~52%-a); a 0., 100., 200. és 351. mezőre a builder nem enged különlegest.
const SPECIAL_RUNS := [
	# 1. szakasz (1–70): mérsékelt sűrűség
	[5, "BD", 5, 1], [12, "F", 10, 6], [21, "LAST", 0, 1], [24, "RD", 5, 1], [27, "B", 10, 1], [30, "UFO", 0, 1],
	[33, "DUEL", 0, 1], [36, "F", 20, 1], [39, "B", 20, 1], [47, "B", 10, 6], [55, "ROCKET", 0, 1], [58, "F", 20, 2],
	[62, "BD", 10, 1], [65, "LAST", 0, 1], [68, "RD", 10, 1],
	# 2. szakasz (71–140): több pozitív és negatív csoport
	[74, "F", 10, 6], [82, "B", 20, 1], [84, "LAST", 0, 1], [86, "B", 10, 6], [93, "UFO", 0, 1], [95, "F", 20, 3],
	[103, "BD", 5, 1], [105, "RD", 5, 1], [107, "F", 10, 6], [114, "DUEL", 0, 1], [116, "B", 20, 2], [119, "LAST", 0, 1],
	[121, "ROCKET", 0, 1], [123, "B", 10, 6], [130, "BD", 10, 1], [132, "F", 20, 1], [134, "UFO", 0, 1], [140, "LAST", 0, 1],
	# 3. szakasz (141–210): sok kockamező, UFO és rakéta
	[142, "BD", 5, 1], [145, "ROCKET", 0, 1], [147, "RD", 5, 1], [149, "UFO", 0, 1], [151, "BD", 10, 1], [153, "F", 20, 1],
	[155, "RD", 10, 1], [157, "LAST", 0, 1], [159, "ROCKET", 0, 1], [161, "BD", 5, 1], [163, "UFO", 0, 1], [165, "RD", 5, 2],
	[168, "B", 20, 1], [170, "BD", 10, 1], [172, "ROCKET", 0, 1], [174, "F", 10, 1], [176, "RD", 10, 1], [178, "UFO", 0, 1],
	[180, "LAST", 0, 1], [182, "BD", 5, 1], [184, "DUEL", 0, 1], [186, "RD", 5, 1], [188, "BD", 10, 1], [192, "UFO", 0, 1],
	[196, "BD", 5, 1], [198, "RD", 5, 1], [202, "F", 10, 1], [204, "BD", 10, 1], [206, "UFO", 0, 1], [208, "RD", 10, 1],
	[210, "LAST", 0, 1],
	# 4. szakasz (211–280): nagy sűrűség
	[211, "F", 20, 1], [213, "F", 10, 6], [222, "LAST", 0, 1], [224, "UFO", 0, 1], [226, "B", 10, 6], [233, "BD", 10, 1],
	[235, "F", 20, 2], [238, "RD", 5, 1], [240, "DUEL", 0, 1], [242, "BD", 5, 1], [244, "B", 20, 2], [247, "LAST", 0, 1],
	[249, "UFO", 0, 1], [251, "F", 10, 6], [258, "RD", 10, 1], [262, "B", 20, 1], [264, "F", 20, 1], [266, "LAST", 0, 1],
	[268, "B", 10, 6], [275, "BD", 10, 1], [277, "UFO", 0, 1],
	# 5. szakasz (281–350): kaotikus hajrá
	[281, "LAST", 0, 1], [283, "BD", 10, 1], [285, "F", 20, 3], [289, "RD", 10, 1], [291, "UFO", 0, 1], [293, "F", 10, 6],
	[300, "B", 20, 1], [302, "LAST", 0, 1], [304, "BD", 5, 1], [305, "BD", 10, 1], [309, "B", 10, 6], [316, "UFO", 0, 1],
	[318, "F", 20, 1], [320, "LAST", 0, 1], [322, "BD", 10, 1], [324, "B", 20, 2], [327, "RD", 10, 1], [329, "DUEL", 0, 1],
	[333, "F", 20, 1], [338, "LAST", 0, 1], [340, "UFO", 0, 1], [342, "B", 20, 3], [346, "RD", 5, 1], [349, "LAST", 0, 1],
]

const INFO := {
	"F": {"col": "#20b84a", "icon": "⏩", "name": "Hátszél"},
	"B": {"col": "#e8282b", "icon": "⏪", "name": "Szembeszél"},
	"BD": {"col": "#1c7ed6", "icon": "🎲", "name": "Kék kockamező"},
	"RD": {"col": "#c2182b", "icon": "🎲", "name": "Piros kockamező"},
	"LAST": {"col": "#f5b301", "icon": "🆙", "name": "Felzárkózó"},
	"UFO": {"col": "#7048e8", "icon": "🛸", "name": "UFO"},
	"ROCKET": {"col": "#fd7e14", "icon": "🚀", "name": "Rakéta"},
	"DUEL": {"col": "#0ca678", "icon": "⚔️", "name": "1 a többiek ellen"},
}

static var _specials := {}


## mező -> [típus, érték]; a SPECIAL_RUNS-ból épül egyszer.
static func specials() -> Dictionary:
	if _specials.is_empty():
		for r in SPECIAL_RUNS:
			for k in int(r[3]):
				var s: int = int(r[0]) + k
				if s <= 0 or s >= GOAL or s == CP_BRIDGE or s == CP_LIGHTS or _specials.has(s):
					push_warning("Óceánsztráda: a %d. mezőre nem tehető különleges mező" % s)
					continue
				_specials[s] = [r[1], r[2]]
	return _specials


static func special(s: int) -> Array:
	return specials().get(s, [])


static func rewards(n: int) -> Array:
	return REWARDS.get(clampi(n, 1, 8), REWARDS[8])


## Ennyi kocka jár a place. helyért (0 = első) n résztvevő mellett.
static func dice_for(place: int, n: int) -> int:
	var r := rewards(n)
	return int(r[clampi(place, 0, r.size() - 1)])


## "good" / "ok" / "bad"
static func grade(total: int, count: int) -> String:
	if total >= ceili(count * GOOD_K):
		return "good"
	if total < floori(count * BAD_K):
		return "bad"
	return "ok"


# ------------------------------------------------------------------ kanyargós út
## Az út középvonala irány-kulcspontokból: [mező, irány fokban (0 = előre, + = jobbra)]. A kulcspontok
## között egyenletesen fordul, a töréseket CURVE_SMOOTH mezőnyi mozgóátlag simítja (átmeneti ív).
## Két azonos irányú kulcspont között egyenes szakasz van: a rajt, a híd (100), a lámpás kapu (200)
## és a cél (351) ilyenre esik. Legszűkebb ív kb. 20 egység sugarú, két útág legalább 40 egységre van.
const CURVE_KEYS := [
	[0, 0], [10, 0], [36, -50], [46, -50], [76, 30], [84, 30], [92, 0], [112, 0],
	[136, 90], [146, 90], [188, -90], [212, -90], [254, 90], [264, 90],
	[284, 30], [292, 30], [316, -35], [324, -35], [340, 0], [384, 0],
]
const CURVE_SMOOTH := 10.0
const CURVE_RES := 8             # minta / mező
const CURVE_S0 := -16.0
const CURVE_S1 := 384.0

static var _hd := PackedFloat32Array()   # irány (radián) mintánként
static var _cx := PackedFloat32Array()   # középvonal x
static var _cz := PackedFloat32Array()   # középvonal z


static func _key_heading(s: float) -> float:
	if s <= CURVE_KEYS[0][0]:
		return CURVE_KEYS[0][1]
	for i in CURVE_KEYS.size() - 1:
		var a: Array = CURVE_KEYS[i]
		var b: Array = CURVE_KEYS[i + 1]
		if s <= b[0]:
			return lerpf(a[1], b[1], (s - a[0]) / float(b[0] - a[0]))
	return CURVE_KEYS[CURVE_KEYS.size() - 1][1]


static func _build_curve() -> void:
	var n := int((CURVE_S1 - CURVE_S0) * CURVE_RES) + 1
	var pre := PackedFloat64Array()
	pre.resize(n + 1)
	pre[0] = 0.0
	for i in n:
		pre[i + 1] = pre[i] + deg_to_rad(_key_heading(CURVE_S0 + float(i) / CURVE_RES))
	var w := int(CURVE_SMOOTH * CURVE_RES / 2.0)
	_hd.resize(n)
	for i in n:
		var a := maxi(0, i - w)
		var b := mini(n - 1, i + w)
		_hd[i] = (pre[b + 1] - pre[a]) / float(b - a + 1)
	_cx.resize(n)
	_cz.resize(n)
	var i0 := int(-CURVE_S0 * CURVE_RES)
	var ds := SP / CURVE_RES
	_cx[i0] = 0.0
	_cz[i0] = 0.0
	for i in range(i0 + 1, n):
		var h := (_hd[i] + _hd[i - 1]) / 2.0
		_cx[i] = _cx[i - 1] + sin(h) * ds
		_cz[i] = _cz[i - 1] - cos(h) * ds
	for i in range(i0 - 1, -1, -1):
		var h := (_hd[i] + _hd[i + 1]) / 2.0
		_cx[i] = _cx[i + 1] - sin(h) * ds
		_cz[i] = _cz[i + 1] + cos(h) * ds


## Az út iránya az s. mezőnél (radián; 0 = -z felé, + = jobbra kanyarodva).
static func heading(s: float) -> float:
	if _hd.is_empty():
		_build_curve()
	var f := clampf((s - CURVE_S0) * CURVE_RES, 0.0, _hd.size() - 1.001)
	var i := int(f)
	return lerpf(_hd[i], _hd[i + 1], f - i)


## Előre (menetirány) és jobbra mutató egységvektor.
static func fwd(s: float) -> Vector3:
	var h := heading(s)
	return Vector3(sin(h), 0.0, -cos(h))


static func right(s: float) -> Vector3:
	var h := heading(s)
	return Vector3(cos(h), 0.0, sin(h))


## Az út középvonala (a pálya végein túl egyenesen folytatódik).
static func center(s: float) -> Vector3:
	if _hd.is_empty():
		_build_curve()
	var f := (s - CURVE_S0) * CURVE_RES
	var last := _hd.size() - 1
	if f <= 0.0:
		return Vector3(_cx[0], 0.0, _cz[0]) + fwd(CURVE_S0) * (s - CURVE_S0) * SP
	if f >= last:
		return Vector3(_cx[last], 0.0, _cz[last]) + fwd(CURVE_S1) * (s - CURVE_S1) * SP
	var i := int(f)
	var k := f - i
	return Vector3(lerpf(_cx[i], _cx[i + 1], k), 0.0, lerpf(_cz[i], _cz[i + 1], k))


## Az út helyi kerete: x = jobbra, y = fel, -z = előre.
static func basis(s: float) -> Basis:
	return Basis(Vector3.UP, -heading(s))


static func xf(s: float) -> Transform3D:
	return Transform3D(basis(s), center(s))


## Helyi (út-keretbeli) vektor elforgatása az s. mező irányába.
static func rot(s: float, v: Vector3) -> Vector3:
	return basis(s) * v


## A mező világbeli helye (a sáv közepén); s lehet tört is (futás közben).
static func pos(s: float, lane := -1.0) -> Vector3:
	var x := 0.0 if lane < 0.0 else (lane - (LANES - 1) / 2.0) * LANE
	return center(s) + right(s) * x


## Az út menti „s” egy világponthoz: a legközelebbi középvonal-minta (durván, aztán finomítva).
static func s_of(p: Vector3) -> float:
	if _hd.is_empty():
		_build_curve()
	var best := 0
	var bd := INF
	var n := _hd.size()
	for i in range(0, n, 4):
		var d := Vector2(_cx[i] - p.x, _cz[i] - p.z).length_squared()
		if d < bd:
			bd = d
			best = i
	for i in range(maxi(0, best - 4), mini(n, best + 5)):
		var d := Vector2(_cx[i] - p.x, _cz[i] - p.z).length_squared()
		if d < bd:
			bd = d
			best = i
	return CURVE_S0 + float(best) / CURVE_RES


## Vízszintes távolság a középvonaltól (díszletek elhelyezéséhez).
static func road_dist(p: Vector3) -> float:
	var c := center(s_of(p))
	return Vector2(c.x - p.x, c.z - p.z).length()


## A következő még le nem győzött ellenőrzőpont a from után (cp = hány pontot győzött le eddig).
static func next_cp(cp: int) -> int:
	if cp <= 0:
		return CP_BRIDGE
	if cp == 1:
		return CP_LIGHTS
	return GOAL
