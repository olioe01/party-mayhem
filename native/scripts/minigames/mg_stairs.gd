extends Minigame
## Rönklépcső – farönkökből rakott lépcső egy virágos hegyoldalon, a tetején fa célkapu.
## Minden körben mindenki titokban választ, hány fokot lépne; a visszaszámlálás végéig módosíthat.
## Utána egyszerre fedik fel a táblájukat: akinek a számát más is választotta, egy helyben marad,
## a többiek annyi fokot futnak fel. Aki elsőként felér, nyer.
##
## A választható számok és a lépcső hossza a létszámtól függ (MOVE_OPTIONS, EXTRA_STAIRS);
## csak 3–8 játékossal kerül sorra (meta: min_players / max_players, szűrés: MgFlow.fits).

const K = preload("res://scripts/minigames/mg_kit.gd")

# ------------------------------------------------------------------ beállítások
const MIN_PLAYERS := 3
const MAX_PLAYERS := 8
const BASE_STAIRS := 16
const EXTRA_STAIRS := {3: 0, 4: 0, 5: 2, 6: 2, 7: 4, 8: 4}
const MOVE_OPTIONS := {
	3: [1, 3, 5], 4: [1, 3, 5],
	5: [1, 3, 5, 7], 6: [1, 3, 5, 7],
	7: [1, 2, 3, 5, 6, 7], 8: [1, 2, 3, 5, 6, 7],
}
const DECISION_TIME := 10.0        # egy döntési kör
const HURRY_TIME := 3.0            # ha mindenki választott, legfeljebb ennyi marad (addig még módosíthat)
const URGENT_AT := 3               # az utolsó ennyi másodpercben sürgető hang
const REVEAL_TIME := 2.9           # a táblák felmutatása
const CLASH_AT := 1.4              # ekkor derül ki, kinek ütközött a száma
const STEP_TIME := 0.32            # egy fok megmászása
const LEAN_IN := 0.18              # nekirugaszkodás a futás előtt
const MAX_ROUNDS := 20             # biztonsági korlát: utána a legmagasabban álló nyer
const FINISH_TIME := 7.4           # célba érés: kapu, hegytető, ünneplés
const CAM_SPAN := 8.0              # a kamera legfeljebb ennyi foknyi mezőnyt fog át (az élen állóktól lefelé)

# a lépcső méretei
const STEP_D := 0.95               # egy fok mélysége (-z irányba emelkedik)
const STEP_H := 0.4                # egy fok magassága
const STAIR_W := 8.2               # a lépcső szélessége (8 figurának is elég)
const LOG_R := 0.25
const MS := 1.0                    # a figurák mérete
const HILL_Z := 5.2                # a célkapu mögötti hegytető közepe (a felső foktól)

const LOG_COLS := ["#8b5a2b", "#7a5230", "#6e6252", "#94673d", "#7d6a55", "#86552c"]

var n := 0                         # résztvevők száma (a players listából)
var top := 0                       # a felső fok sorszáma (a lépcső hossza)
var opts: Array = []
var spacing := 1.0
var pl: Array = []
var phase := "intro"               # intro | pick | reveal | climb | finish | done
var phase_t0 := 0.0
var round_i := 0
var cut := DECISION_TIME           # a döntési kör tényleges hossza (siettetés után rövidebb)
var last_tick := -1
var clash_done := false
var climb_dur := 0.0
var fin_t0 := 0.0
var reached := false               # célba ért valaki (különben körkorlát miatt ért véget)
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var fov := 50.0


static func options_for(count: int) -> Array:
	return MOVE_OPTIONS[clampi(count, MIN_PLAYERS, MAX_PLAYERS)]


static func stairs_for(count: int) -> int:
	return BASE_STAIRS + int(EXTRA_STAIRS[clampi(count, MIN_PLAYERS, MAX_PLAYERS)])


func meta() -> Dictionary:
	return {"id": "stairs", "name": "Rönklépcső", "icon": "🪵", "color": "#5fae3c", "modes": ["ffa"],
		"min_players": MIN_PLAYERS, "max_players": MAX_PLAYERS, "keep_ties": true, "own_end": true,
		"tagline": "Lépj nagyot – de ne ugyanannyit, mint más!",
		"desc": "Minden körben mindenki titokban választ, hány fokot lép. Ha a számodat más is választotta, mindketten egy helyben maradtok, a többiek felfutnak. Az nyer, aki elsőként felér a célkapuig. 3–4 fő: 1, 3, 5 lépés, %d fok · 5–6 fő: 1, 3, 5, 7 lépés, %d fok · 7–8 fő: 1, 2, 3, 5, 6, 7 lépés, %d fok." % [stairs_for(3), stairs_for(5), stairs_for(7)],
		"controls": "Koppints egy számra a telefonodon (vagy A/D, ←/→). A visszaszámlálás végéig átválthatsz; ha nem választasz, a legkisebbet kapod."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "🪵", "title": "Rönklépcső", "text": "Mindjárt választhatsz!"}


func keyboard_lr() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	n = players.size()
	top = stairs_for(n)
	opts = options_for(n)
	spacing = 1.15 if n <= 4 else (1.0 if n <= 6 else 0.9)
	make_env("#2f7fe0", "#d4ecff", 0.9)
	env.fog_enabled = true
	env.fog_light_color = Color("#cfe6ff")
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	fov = 50.0 if n <= 4 else (54.0 if n <= 6 else 58.0)
	_cam_target()
	make_camera(cam_pos, cam_look, fov)
	var sun := make_sun(Vector3(-50, -35, 0), 1.3, "#fff4dc")
	sun.directional_shadow_max_distance = 45.0
	_build_hill()
	_build_stairs()
	_build_arch()
	_build_fences()
	_build_flowers()
	_build_hilltop()
	_build_backdrop()
	for i in n:
		_make_player(players[i], i)
	_sync(0.0)


func _hill_y(z: float) -> float:
	return clamp(-(z + STEP_D / 2.0) / STEP_D * STEP_H, 0.0, top * STEP_H)


func _stair_pt(k: float) -> Vector3:
	return Vector3(0, k * STEP_H, -k * STEP_D)


func _lane_x(i: int) -> float:
	return (i - (n - 1) / 2.0) * spacing


func _beam(a: Vector3, b: Vector3, th: float, m: Material) -> MeshInstance3D:
	var mi := Chars3D.box(self, th, th, a.distance_to(b), m, (a + b) / 2.0)
	mi.basis = Basis.looking_at(b - a, Vector3.UP)
	return mi


func _build_hill() -> void:
	var grass := Chars3D.mat("#6cc24a", {"rough": 0.95})
	var grass2 := Chars3D.mat("#5db33f", {"rough": 0.95})
	# lent a rét, ahonnan indulnak
	Chars3D.box(self, 120, 2, 50, grass, Vector3(0, -1, -STEP_D / 2.0 + 25))
	# a lejtő a lépcső mentén
	var rise := top * STEP_H
	var run := top * STEP_D
	var a := atan2(rise, run)
	var nrm := Vector3(0, cos(a), sin(a))
	var mid := Vector3(0, rise / 2.0, -STEP_D / 2.0 - run / 2.0)
	Chars3D.box(self, 120, 2, Vector2(run, rise).length() + 0.4, grass2, mid - nrm, Vector3(a, 0, 0))
	# fenn a hegytető
	Chars3D.box(self, 120, 2, 40, grass, Vector3(0, rise - 1, -run - STEP_D / 2.0 - 20))


func _build_stairs() -> void:
	var dirt := Chars3D.mat("#a27b4f", {"rough": 1.0})
	var cap := Chars3D.mat("#dcb47c", {"rough": 0.8})
	var ring := Chars3D.mat("#b88a55", {"rough": 0.8})
	for k in range(1, top + 1):
		# a fok tömött földje
		Chars3D.box(self, STAIR_W, STEP_H * 2.0, STEP_D, dirt, Vector3(0, k * STEP_H - STEP_H, -k * STEP_D))
		# elöl a vastag, kerek farönk – a teteje a fok szintjén
		var r := LOG_R * FX.fr(0.92, 1.08)
		var z := -k * STEP_D + STEP_D / 2.0 - r * 0.8
		var y := k * STEP_H - r * 0.9
		var col: String = FX.pick(LOG_COLS)
		Chars3D.lcyl(self, r, r * FX.fr(0.95, 1.05), STAIR_W + 0.35, Chars3D.mat(col, {"rough": 0.85}), 0, y, z, 9, Vector3(FX.fr(-0.03, 0.03), 0, PI / 2))
		# kéreg-csíkok: egy-két vékonyabb, sötétebb gyűrű a rönkön
		for j in 2:
			var bx := FX.fr(-STAIR_W / 2.0 + 0.6, STAIR_W / 2.0 - 0.6)
			Chars3D.lcyl(self, r * 1.04, r * 1.04, 0.08, Chars3D.mat(Color(col).darkened(0.25).to_html(), {"rough": 0.9}), bx, y, z, 9, Vector3(0, 0, PI / 2))
		# a rönkvégek: világos vágott lap, benne évgyűrű
		for side in [-1, 1]:
			var ex: float = side * (STAIR_W / 2.0 + 0.18)
			Chars3D.lcyl(self, r * 0.93, r * 0.93, 0.03, cap, ex, y, z, 9, Vector3(0, 0, PI / 2))
			Chars3D.lcyl(self, r * 0.55, r * 0.55, 0.035, ring, ex, y, z, 9, Vector3(0, 0, PI / 2))
			Chars3D.lcyl(self, r * 0.4, r * 0.4, 0.04, cap, ex, y, z, 9, Vector3(0, 0, PI / 2))


func _build_arch() -> void:
	var wood := Chars3D.mat("#8a5a32", {"rough": 0.85})
	var dark := Chars3D.mat("#6b4426", {"rough": 0.85})
	var base := _stair_pt(top)
	var hx := STAIR_W / 2.0 + 0.3
	for side in [-1, 1]:
		Chars3D.lcyl(self, 0.17, 0.2, 3.0, wood, side * hx, base.y + 1.5, base.z, 8)
		Chars3D.lcyl(self, 0.24, 0.26, 0.3, dark, side * hx, base.y + 0.15, base.z, 8)
	Chars3D.lcyl(self, 0.2, 0.2, hx * 2 + 1.0, wood, 0, base.y + 2.95, base.z, 8, Vector3(0, 0, PI / 2))
	# tábla a gerendán
	Chars3D.box(self, 1.9, 0.62, 0.1, Chars3D.mat("#f3d9a4", {"rough": 0.8}), Vector3(0, base.y + 2.5, base.z + 0.14))
	var lab := Label3D.new()
	lab.text = "CÉL"
	lab.font = D.font
	lab.font_size = 150
	lab.pixel_size = 0.003
	lab.modulate = Color("#6b3d1c")
	lab.outline_size = 0
	lab.position = Vector3(0, base.y + 2.5, base.z + 0.2)
	add_child(lab)
	# színes zászlófüzér a gerenda alatt
	var cols := ["#ff4d6d", "#ffd43b", "#4dabf7", "#51cf66", "#b197fc"]
	var cnt := int(hx * 2 / 0.55)
	for i in cnt:
		var x := -hx + 0.35 + i * (hx * 2 - 0.7) / maxi(1, cnt - 1)
		if abs(x) < 1.1:
			continue
		var sag := 0.18 * (1.0 - pow(x / hx, 2))
		var tri := Chars3D.part(self, Chars3D.prism([[-0.16, 0.0], [0.16, 0.0], [0.0, -0.32]], 0.02),
			Chars3D.mat(cols[i % cols.size()], {"rough": 0.6}), Vector3(x, base.y + 2.78 - sag, base.z + 0.05))
		tri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_fences() -> void:
	var post := Chars3D.mat("#9a6b3f", {"rough": 0.9})
	var rail := Chars3D.mat("#b07d4b", {"rough": 0.9})
	for side in [-1, 1]:
		var x: float = side * (STAIR_W / 2.0 + 1.0)
		var prev := Vector3.INF
		for k in range(-6, top + 1, 2):
			var z := -k * STEP_D
			var y := _hill_y(z) if k > 0 else 0.0
			Chars3D.lcyl(self, 0.07, 0.08, 1.05, post, x, y + 0.45, z, 6)
			var p := Vector3(x, y, z)
			if prev != Vector3.INF:
				_beam(prev + Vector3(0, 0.42, 0), p + Vector3(0, 0.42, 0), 0.07, rail)
				_beam(prev + Vector3(0, 0.78, 0), p + Vector3(0, 0.78, 0), 0.07, rail)
			prev = p


func _flower(pos: Vector3, kind: int, s := 1.0) -> void:
	var stem := Chars3D.mat("#3f9a32", {"rough": 0.9})
	Chars3D.lcyl(self, 0.012 * s, 0.015 * s, 0.22 * s, stem, pos.x, pos.y + 0.11 * s, pos.z, 4)
	var hy := pos.y + 0.23 * s
	match kind:
		0:     # margaréta: fehér szirmok, sárga közép
			var white := Chars3D.mat("#ffffff", {"rough": 0.7})
			for j in 5:
				var a := TAU * j / 5.0
				Chars3D.lsphere(self, 0.045 * s, white, pos.x + cos(a) * 0.05 * s, hy, pos.z + sin(a) * 0.05 * s, 1, 0.4, 1, 6, 3)
			Chars3D.lsphere(self, 0.035 * s, Chars3D.mat("#ffc61a"), pos.x, hy + 0.01, pos.z, 1, 0.7, 1, 6, 3)
		1:
			Chars3D.lsphere(self, 0.07 * s, Chars3D.mat("#ffd43b", {"rough": 0.6}), pos.x, hy, pos.z, 1, 0.75, 1, 6, 4)
		2:
			Chars3D.lsphere(self, 0.07 * s, Chars3D.mat("#ff7eb6", {"rough": 0.6}), pos.x, hy, pos.z, 1, 0.75, 1, 6, 4)
		_:
			Chars3D.lsphere(self, 0.065 * s, Chars3D.mat("#ff6b6b", {"rough": 0.6}), pos.x, hy, pos.z, 1, 0.75, 1, 6, 4)


func _build_flowers() -> void:
	var rock := Chars3D.mat("#9aa0a6", {"rough": 0.95})
	var rock2 := Chars3D.mat("#80868c", {"rough": 0.95})
	var bush := Chars3D.mat("#4f9e36", {"rough": 0.95})
	var z0 := 6.0
	var z1 := -top * STEP_D - 2.0
	for i in 150:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * FX.fr(STAIR_W / 2.0 + 0.4, 13.0)
		if abs(abs(x) - (STAIR_W / 2.0 + 1.0)) < 0.18:
			x += side * 0.3
		var z := FX.fr(z1, z0)
		_flower(Vector3(x, _hill_y(z), z), i % 4, FX.fr(0.9, 1.3))
	for i in 26:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * FX.fr(STAIR_W / 2.0 + 1.6, 16.0)
		var z := FX.fr(z1, z0 + 3)
		var r := FX.fr(0.18, 0.5)
		Chars3D.lsphere(self, r, rock if i % 3 else rock2, x, _hill_y(z) + r * 0.25, z, FX.fr(1.0, 1.5), 0.7, FX.fr(0.9, 1.3), 7, 4)
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * FX.fr(STAIR_W / 2.0 + 2.5, 18.0)
		var z := FX.fr(z1, z0)
		var r := FX.fr(0.45, 0.85)
		Chars3D.lsphere(self, r, bush, x, _hill_y(z) + r * 0.45, z, 1.2, 0.85, 1.1, 8, 5)


## A célkapu mögötti hegytető: virágágyások, kerítés, padka – ide fut be a győztes.
func _build_hilltop() -> void:
	var c := _stair_pt(top)
	var hz := c.z - HILL_Z
	var soil := Chars3D.mat("#7a5434", {"rough": 1.0})
	var edge := Chars3D.mat("#c9a26b", {"rough": 0.9})
	for side in [-1, 1]:
		for row in 2:
			var bx: float = side * (2.6 + row * 3.2)
			var bz := hz + 0.2 - row * 1.4
			Chars3D.box(self, 2.4, 0.18, 1.5, soil, Vector3(bx, c.y + 0.05, bz))
			Chars3D.box(self, 2.6, 0.12, 0.12, edge, Vector3(bx, c.y + 0.08, bz + 0.8))
			Chars3D.box(self, 2.6, 0.12, 0.12, edge, Vector3(bx, c.y + 0.08, bz - 0.8))
			for j in 18:
				_flower(Vector3(bx + FX.fr(-1.05, 1.05), c.y + 0.14, bz + FX.fr(-0.6, 0.6)), (j + row) % 4, FX.fr(1.1, 1.5))
	# kerítés körben a tető hátsó szélén
	var post := Chars3D.mat("#9a6b3f", {"rough": 0.9})
	var rail := Chars3D.mat("#b07d4b", {"rough": 0.9})
	var fz := hz - 3.6
	var prev := Vector3.INF
	for i in 17:
		var x := -12.0 + i * 1.5
		Chars3D.lcyl(self, 0.07, 0.08, 1.05, post, x, c.y + 0.45, fz, 6)
		var p := Vector3(x, c.y, fz)
		if prev != Vector3.INF:
			_beam(prev + Vector3(0, 0.42, 0), p + Vector3(0, 0.42, 0), 0.07, rail)
			_beam(prev + Vector3(0, 0.78, 0), p + Vector3(0, 0.78, 0), 0.07, rail)
		prev = p
	# egy kis fa a sarokban
	var trunk := Chars3D.mat("#7a4f2c", {"rough": 0.9})
	var leaf := Chars3D.mat("#3f9a32", {"rough": 0.9})
	for side in [-1, 1]:
		var tx: float = side * 9.5
		Chars3D.lcyl(self, 0.18, 0.24, 1.6, trunk, tx, c.y + 0.8, hz - 1.5, 7)
		Chars3D.lsphere(self, 1.1, leaf, tx, c.y + 2.2, hz - 1.5, 1, 0.9, 1, 8, 5)
		Chars3D.lsphere(self, 0.8, leaf, tx + side * 0.5, c.y + 2.9, hz - 1.3, 1, 0.9, 1, 8, 5)


func _build_backdrop() -> void:
	var rock := Chars3D.mat("#7b8fa6", {"rough": 0.95})
	var rock2 := Chars3D.mat("#8fa3b8", {"rough": 0.95})
	var snow := Chars3D.mat("#f8fbff", {"rough": 0.6})
	var far_hill := Chars3D.mat("#7fc65a", {"rough": 0.95})
	var zb := -top * STEP_D
	# hátul távoli zöld dombok, mögöttük havas csúcsok
	for i in 7:
		var x := -48.0 + i * 16.0 + FX.fr(-3, 3)
		Chars3D.lsphere(self, 1.0, far_hill, x, top * STEP_H - 2.0, zb - 26 - FX.fr(0, 6), 11.0, 5.0, 8.0, 9, 5)
	for i in 9:
		var x := -64.0 + i * 16.0 + FX.fr(-4, 4)
		var h := FX.fr(26.0, 40.0)
		var r := h * FX.fr(0.55, 0.75)
		var z := zb - 55.0 - FX.fr(0, 18)
		Chars3D.lcone(self, r, h, rock if i % 2 else rock2, x, h / 2.0 - 2.0, z, 7, Vector3(0, FX.fr(0, TAU), 0))
		Chars3D.lcone(self, r * 0.36, h * 0.36, snow, x, h - 2.0 - h * 0.18 + 0.05, z, 7, Vector3(0, FX.fr(0, TAU), 0))
	# bárányfelhők
	var cloud := Chars3D.mat("#ffffff", {"rough": 1.0, "emit": "#ffffff", "emit_e": 0.25})
	for i in 9:
		var cx := -50.0 + i * 12.5 + FX.fr(-4, 4)
		var cy := top * STEP_H + FX.fr(14, 24)
		var cz := zb - FX.fr(25, 60)
		for j in 5:
			var r := FX.fr(1.6, 3.0)
			var s := Chars3D.lsphere(self, r, cloud, cx + (j - 2) * 2.2 + FX.fr(-0.5, 0.5), cy + FX.fr(-0.4, 1.0), cz + FX.fr(-1, 1), 1.2, 0.8, 1.0, 9, 5)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_player(p, i: int) -> void:
	var m := player_model(p, MS)
	var col: Color = p.color
	var shoe := Chars3D.mat(D.shade(col, -0.45).to_html(), {"rough": 0.6})
	var feet: Array = []
	for side in [-1, 1]:
		feet.append(Chars3D.lsphere(m, 0.09, shoe, side * 0.14, 0.04, 0.05, 1.0, 0.55, 1.4, 8, 4))
	# a felmutatható számtábla: nyél + kerek tábla a játékos színével, rajta a szám
	var sign := Node3D.new()
	m.add_child(sign)
	Chars3D.lcyl(sign, 0.025, 0.025, 0.75, Chars3D.mat("#9a6b3f", {"rough": 0.8}), 0, 0.3, 0, 6)
	Chars3D.cyl(sign, 0.34, 0.34, 0.05, Chars3D.mat(col.to_html(), {"rough": 0.45}), 0, 0.85, 0, 24, Vector3(PI / 2, 0, 0))
	Chars3D.cyl(sign, 0.28, 0.28, 0.06, Chars3D.mat("#ffffff", {"rough": 0.5}), 0, 0.85, 0.005, 24, Vector3(PI / 2, 0, 0))
	var num := Label3D.new()
	num.font = D.font
	num.font_size = 180
	num.pixel_size = 0.0024
	num.modulate = D.shade(col, -0.5)
	num.outline_size = 0
	num.position = Vector3(0, 0.85, 0.04)
	sign.add_child(num)
	sign.visible = false
	var s := {"p": p, "i": i, "col": col, "m": m, "feet": feet, "sign": sign, "num": num,
		"arms": K.build_arms(m, col.to_html(), 0.42), "face": K.build_face(m),
		"pos": 0, "from": 0, "go": 0, "pick": 0, "final": 0, "ok": false, "auto": false,
		"score": 0.0, "fin": false, "win": false, "yaw": 0.0, "bot_at": 0.0, "bot_re": -1.0,
		"vis": 0.0, "stop_t": -10.0}
	pl.append(s)


# ------------------------------------------------------------------ menet
func start() -> void:
	_round()


func _round() -> void:
	round_i += 1
	phase = "pick"
	phase_t0 = t
	cut = DECISION_TIME
	last_tick = -1
	clash_done = false
	for s in pl:
		s.pick = 0
		s.final = 0
		s.ok = false
		s.auto = false
		s.go = 0
		s.bot_at = randf_range(1.0, 6.0)
		s.bot_re = randf_range(6.5, 8.5) if randf() < 0.3 else -1.0
		_push_pick(s)
	Audio.play("bell")


func _push_pick(s: Dictionary) -> void:
	var p = s.p
	Net.set_ctrl(p.pid, {"mode": "steps", "title": "Hány fokot lépsz?", "options": opts, "sel": s.pick if s.pick > 0 else null,
		"color": p.color_hex, "text": "Ha más is ugyanezt választja, egyikőtök sem lép! Most a %d. fokon állsz, a cél a %d." % [s.pos, top]})


func _choose(s: Dictionary, v: int) -> void:
	if phase != "pick" or not opts.has(v):
		return
	if s.pick != v:
		s.pick = v
		Audio.play("pop")      # mindig ugyanaz a hang: a hangmagasság se árulja el a számot


func input(p, msg: Dictionary) -> void:
	var s := _get(p)
	if s.is_empty() or phase != "pick":
		return
	var tt := str(msg.get("t", ""))
	if tt == "step":
		_choose(s, int(msg.get("v", 0)))
	elif tt == "lr" and int(msg.get("v", 0)) != 0:
		# billentyűzet: A/D vagy ←/→ lépteti a választást
		var i := opts.find(s.pick)
		var d := int(msg.v)
		i = clampi((0 if d > 0 else opts.size() - 1) if i < 0 else i + d, 0, opts.size() - 1)
		_choose(s, int(opts[i]))
		if msg.get("kb", false):
			_push_pick(s)


func _get(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


func bot(p, _dt: float) -> void:
	var s := _get(p)
	if s.is_empty() or phase != "pick":
		return
	var e := t - phase_t0
	if s.pick == 0 and e >= s.bot_at:
		_choose(s, int(opts.pick_random()))
	elif s.bot_re > 0 and e >= s.bot_re and s.pick != 0:
		s.bot_re = -1.0
		_choose(s, int(opts.pick_random()))


func _remain() -> float:
	return cut - (t - phase_t0)


func update(dt: float) -> void:
	match phase:
		"pick":
			var all := true
			for s in pl:
				if s.pick == 0:
					all = false
			if all and _remain() > HURRY_TIME:
				cut = (t - phase_t0) + HURRY_TIME
			var r := ceili(_remain())
			if r <= URGENT_AT and r > 0 and r != last_tick:
				last_tick = r
				Audio.play("tick", 1.0 + (URGENT_AT - r) * 0.18)
			if _remain() <= 0.0:
				_lock()
		"reveal":
			if not clash_done and t - phase_t0 >= CLASH_AT:
				clash_done = true
				_show_clash()
			if t - phase_t0 >= REVEAL_TIME:
				_climb_start()
		"climb":
			if t - phase_t0 >= climb_dur:
				_climb_end()
		"finish":
			if t - fin_t0 >= FINISH_TIME:
				phase = "done"
				finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


## A visszaszámlálás vége: a választások rögzülnek, a nem választók a legkisebbet kapják.
func _lock() -> void:
	var count := {}
	for s in pl:
		if s.pick == 0:
			s.pick = int(opts[0])
			s.auto = true
		s.final = s.pick
		count[s.final] = int(count.get(s.final, 0)) + 1
		(s.num as Label3D).text = str(s.final)
	for s in pl:
		s.ok = int(count[s.final]) == 1
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🪧", "title": "A számod: %d" % s.final,
			"text": "Nem választottál, ezért a legkisebbet kaptad." if s.auto else "Lássuk, más is ezt választotta-e…"})
	phase = "reveal"
	phase_t0 = t
	Audio.play("whoosh")
	Audio.play("sparkle")


func _show_clash() -> void:
	var any_bad := false
	for s in pl:
		if not s.ok:
			any_bad = true
			Net.vibrate(s.p.pid, [120, 60, 120])
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "💥", "title": "Ütközés!", "text": "Más is a %d-t választotta: most maradsz." % s.final})
		else:
			Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏃", "title": "+%d fok!" % s.final, "text": "Senki más nem választotta – futás!"})
	Audio.play("bad" if any_bad else "ally")


func _climb_start() -> void:
	phase = "climb"
	phase_t0 = t
	var longest := 0
	for s in pl:
		s.from = s.pos
		s.go = 0
		s.last_step = -1
		if s.ok:
			s.go = mini(int(s.final), top - int(s.pos))
			s.pos = int(s.pos) + int(s.go)
			if s.go > 0:
				Net.vibrate(s.p.pid, 60)
		longest = maxi(longest, int(s.go))
	climb_dur = LEAN_IN + longest * STEP_TIME + 0.7 if longest > 0 else 1.3
	if longest > 0:
		Audio.play("whoosh")


func _climb_end() -> void:
	# a vizuális és a logikai hely itt biztosan egyezik
	var done: Array = []
	for s in pl:
		s.vis = float(s.pos)
		if s.pos >= top:
			done.append(s)
	print_verbose("[stairs] %s%d. kör (%d fő, %d fok, %s): %s" % ["(próba) " if preview else "", round_i, n, top, str(opts),
		", ".join(pl.map(func(q): return "%s %d%s→%d" % [q.p.name, q.final, "" if q.ok else "✖", q.pos]))])
	if done.is_empty() and round_i < MAX_ROUNDS:
		_round()
		return
	# helyezés: aki felért, kevesebb lépésből (= korábban) ért fel; a többiek a magasságuk szerint
	for s in pl:
		if s.pos >= top:
			s.fin = true
			s.score = 1000.0 + 100.0 - float(s.go)
		else:
			s.score = float(s.pos)
	var best := -1.0
	for s in pl:
		best = maxf(best, float(s.score))
	for s in pl:
		s.win = float(s.score) == best
	reached = not done.is_empty()
	phase = "finish"
	fin_t0 = t
	Audio.play("fanfare")
	Main.I.confetti(110)
	for s in pl:
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏁" if s.win else "🪵", "title": "Célba értél!" if s.fin and s.win else ("Felértél!" if s.fin else "Vége!"),
			"text": "Nézd a nagy képernyőt!"})


func ranking() -> Array:
	return rank_by(func(p): return float(_get(p).score),
		func(p):
			var s := _get(p)
			return "🏁 célba ért" if s.fin else "%d. fok" % int(s.pos))


# ------------------------------------------------------------------ látvány
func _cam_target() -> void:
	if phase == "finish" and reached:
		var f := t - fin_t0
		var c := _stair_pt(top)
		if f < 0.9:
			pass
		elif f < 3.0:
			cam_pos = c + Vector3(0, 2.0, 4.6)
			cam_look = c + Vector3(0, 1.0, -0.5)
			return
		else:
			cam_pos = c + Vector3(0, 1.9, 0.6 - HILL_Z + 5.2)
			cam_look = c + Vector3(0, 1.4, -HILL_Z - 1.0)
			return
	var lead := 0.0
	var trail := float(top)
	for q in pl:
		lead = maxf(lead, float(q.vis))
		trail = minf(trail, float(q.vis))
	if pl.is_empty():
		trail = 0.0
	# az élboly mindig látsszon; a nagyon lemaradók kedvéért nem hátrálunk végtelenül (a jobb oldali térképen ők is látszanak)
	trail = maxf(trail, lead - CAM_SPAN)
	# a nézőpont kicsit a mezőny elé néz (a célkapu felé), aztán annyira hátrál,
	# hogy a leghátsó figura lába és a legelső feje is a képen maradjon (a felső/alsó feliratok alatt)
	var base_k := (trail + lead) / 2.0
	cam_look = _stair_pt(minf(base_k + 4.0, top + 1.0)) + Vector3(0, 0.4, 0)
	var dir := Vector3(0, 0.3 + clampf((lead - trail) / 10.0, 0.0, 1.0) * 0.12, 1).normalized()
	var pts := [_stair_pt(trail) + Vector3(0, -0.1, 0.4), _stair_pt(lead) + Vector3(0, 1.9, 0)]
	var half := fov / 2.0
	var d := 6.5
	while d < 60.0:
		if _fits_view(cam_look + dir * d, cam_look, pts, half - 7.0, half - 9.0):
			break
		d += 0.25
	cam_pos = cam_look + dir * d


## Belefér-e minden pont a nézet függőleges szögébe (lent és fent külön tartalékkal) – csak látvány.
func _fits_view(from: Vector3, look: Vector3, pts: Array, down: float, up: float) -> bool:
	var f := look - from
	var fp := rad_to_deg(atan2(f.y, -f.z))
	for p3 in pts:
		var v: Vector3 = p3 - from
		var pp := rad_to_deg(atan2(v.y, -v.z))
		if pp < fp - down or pp > fp + up:
			return false
	return true


func _sync(dt: float) -> void:
	for s in pl:
		_anim(s, dt)
	var prev_pos := cam_pos
	var prev_look := cam_look
	_cam_target()
	if cam and dt > 0.0:
		var k := minf(1.0, dt * (1.8 if phase == "finish" else 1.4))
		cam_pos = prev_pos.lerp(cam_pos, k)
		cam_look = prev_look.lerp(cam_look, k)
		cam.position = cam_pos
		cam.look_at(cam_look, Vector3.UP)


func _smooth(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)


func _anim(s: Dictionary, dt: float) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var tt: float = m.t
	var i: int = s.i
	var x := _lane_x(i)
	var k := float(s.pos)
	var hop := 0.0
	var moving := false
	var step_ph := 0.0
	var e := t - phase_t0
	if phase == "climb":
		k = float(s.from)
		if s.go > 0:
			var c: float = clamp((e - LEAN_IN) / STEP_TIME, 0.0, float(s.go))
			moving = e < LEAN_IN + s.go * STEP_TIME
			var ki := floorf(c)
			var f := c - ki
			if c >= s.go:
				ki = float(s.go)
				f = 0.0
				if s.stop_t < phase_t0:
					s.stop_t = t
					Audio.play("land", 0.9 + FX.f() * 0.2)
			elif f > 0.0 and int(ki) != int(s.get("last_step", -1)):
				s.last_step = int(ki)
				Audio.play("step", 0.9 + FX.f() * 0.3)
			k = float(s.from) + ki + _smooth(f)
			hop = sin(f * PI) * 0.3
			step_ph = c
	s.vis = k
	var pos := Vector3(x, k * STEP_H + hop, -k * STEP_D)
	var yaw := 0.0                    # 0 = a kamera felé néz
	var lean := 0.0
	var roll := sin(tt * 1.6 + i) * 0.03
	var bounce := 0.0
	var face := Vector3(0.0, 1.0, 0.0)  # száj, szem, szemöldök
	var arms_t: Array = [Vector3(-0.36, 0.12, 0.1), Vector3(0.36, 0.12, 0.1)]
	var sign_up := 0.0
	var lift := [0.0, 0.0]
	var fin_f := t - fin_t0
	match phase:
		"intro", "pick":
			# gondolkodás: kéz az állon, apró idegeskedés
			var nerv: float = 0.5 + 0.5 * sin(tt * 0.9 + i * 1.7)
			roll += sin(tt * 3.1 + i) * 0.04 * nerv
			yaw = sin(tt * 0.7 + i * 2.0) * 0.25
			arms_t[1] = Vector3(0.12, 0.66 + sin(tt * 2.0 + i) * 0.03, 0.34)
			arms_t[0] = Vector3(-0.3, 0.3, 0.26)
			face = Vector3(0.05 + 0.1 * nerv, 1.0, 0.35 * sin(tt * 1.3 + i))
			if phase == "pick" and _remain() < URGENT_AT:
				roll += sin(tt * 14.0) * 0.03
				face = Vector3(0.3, 1.15, 0.6)
		"reveal":
			var rk: float = clamp(e / 0.35, 0.0, 1.0)
			sign_up = D.ease_out_back(rk)
			arms_t[1] = Vector3(0.36, 0.62 + 0.1 * sign_up, 0.22)
			if e >= CLASH_AT and not s.ok:
				face = Vector3(0.15, 0.85, -0.9)
				arms_t[0] = Vector3(-0.3, 0.05, 0.12)
				lean = 0.18
				roll += sin((e - CLASH_AT) * 26.0) * 0.08 * maxf(0.0, 1.0 - (e - CLASH_AT) * 1.5)
			else:
				face = Vector3(0.6, 1.1, 0.5)
				arms_t[0] = Vector3(-0.45, 1.05 + sin(tt * 9.0) * 0.08, 0.15)
				bounce = abs(sin(e * 6.0)) * 0.06
		"climb":
			if s.go > 0 and (moving or e < LEAN_IN):
				yaw = PI
				lean = 0.28 if moving else 0.28 * clamp(e / LEAN_IN, 0.0, 1.0)
				var sw := sin(step_ph * PI)
				arms_t = [Vector3(-0.32, 0.32, 0.05 + sw * 0.22), Vector3(0.32, 0.32, 0.05 - sw * 0.22)]
				lift = [maxf(0.0, sin(step_ph * PI)) * 0.13, maxf(0.0, -sin(step_ph * PI)) * 0.13]
				face = Vector3(0.35, 1.0, -0.3)
			elif s.go > 0:
				# megállás: kis egyensúlyozás, aztán visszafordul
				var st: float = t - s.stop_t
				yaw = PI if st < 0.25 else 0.0
				roll += sin(st * 18.0) * 0.12 * maxf(0.0, 1.0 - st * 2.2)
				arms_t = [Vector3(-0.5, 0.45, 0.05), Vector3(0.5, 0.45, 0.05)]
				face = Vector3(0.4, 1.05, 0.3)
			else:
				face = Vector3(0.12, 0.9, -0.8)
				lean = 0.22
				arms_t = [Vector3(-0.28, 0.02, 0.12), Vector3(0.28, 0.02, 0.12)]
		"finish", "done":
			if s.win:
				var walk_from := 3.0
				var walk_to := 4.3
				if reached and fin_f >= walk_from:
					var wf: float = clamp((fin_f - walk_from) / (walk_to - walk_from), 0.0, 1.0)
					pos.z -= _smooth(wf) * HILL_Z
					if wf < 1.0:
						yaw = PI
						lean = 0.2
						var ph := fin_f * 9.0
						hop = abs(sin(ph)) * 0.08
						pos.y += hop
						lift = [maxf(0.0, sin(ph)) * 0.12, maxf(0.0, -sin(ph)) * 0.12]
						arms_t = [Vector3(-0.32, 0.3, sin(ph) * 0.2), Vector3(0.32, 0.3, -sin(ph) * 0.2)]
					else:
						_celebrate(tt, arms_t)
						bounce = abs(sin(tt * 6.5)) * 0.35
						face = Vector3(0.85, 1.1, 0.6)
				else:
					_celebrate(tt, arms_t)
					bounce = abs(sin(tt * 6.5)) * 0.3
					face = Vector3(0.85, 1.1, 0.6)
			else:
				face = Vector3(0.12, 0.85, -0.9)
				lean = 0.35
				roll += sin(tt * 1.8 + i) * 0.06
				arms_t = [Vector3(-0.26, -0.02, 0.14), Vector3(0.26, -0.02, 0.14)]
	# a figura
	s.yaw = lerp_angle(float(s.yaw), yaw, minf(1.0, dt * 9.0)) if dt > 0.0 else yaw
	m.position = pos + Vector3(0, a.y * 0.3 + bounce, 0)
	m.rotation = Vector3(lean, float(s.yaw), roll + a.tilt)
	m.scale = Vector3.ONE * MS
	var feet: Array = s.feet
	for j in 2:
		var ft: MeshInstance3D = feet[j]
		ft.position = Vector3((-1 if j == 0 else 1) * 0.14, 0.04 + lift[j], 0.05 + lift[j] * 0.6)
	for j in 2:
		K.arm_to(s.arms[j], arms_t[j], Vector3(0.6, -0.8, -0.2))
	K.set_face(m, s.face, face.x, face.y, face.z)
	# a számtábla a jobb kézben
	var sign: Node3D = s.sign
	sign.visible = sign_up > 0.01
	if sign.visible:
		sign.position = Vector3(0.44, 0.2 + 0.32 * sign_up, 0.22)
		sign.scale = Vector3.ONE * maxf(0.05, sign_up)
		sign.rotation.z = -0.08 + (sin((e - CLASH_AT) * 30.0) * 0.18 * maxf(0.0, 1.0 - (e - CLASH_AT) * 2.0) if (e >= CLASH_AT and not s.ok) else 0.0)


func _celebrate(tt: float, arms_t: Array) -> void:
	arms_t[0] = Vector3(-0.4, 1.15 + sin(tt * 10.0) * 0.08, 0.1)
	arms_t[1] = Vector3(0.4, 1.15 + sin(tt * 10.0 + 1.0) * 0.08, 0.1)


# ------------------------------------------------------------------ 2D felület
func draw(c: CanvasItem) -> void:
	_draw_heads(c)
	if not (phase in ["finish", "done"] and reached and t - fin_t0 > 3.0):
		_draw_ladder(c)
	D.text(c, "🪵 Rönklépcső", 24, 34, {"size": 26, "align": "left", "stroke": D.DARK, "sw": 6})
	D.text(c, "%d. kör · cél: %d. fok" % [maxi(1, round_i), top], 24, 66, {"size": 17, "align": "left", "color": Color("#ffffff"), "stroke": D.DARK, "sw": 5})
	match phase:
		"intro":
			K.silver_timer(c, DECISION_TIME, 640, 46, URGENT_AT, t)
		"pick":
			K.silver_timer(c, _remain(), 640, 46, URGENT_AT, t)
			D.text(c, "Válassz titokban a telefonodon!", 640, 104, {"size": 26, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 7})
			_draw_options(c)
		"reveal":
			_draw_panels(c)
		"finish", "done":
			var f := t - fin_t0
			var txt := "CÉLBA ÉRT!" if reached else "VÉGE!"
			K.banner(c, txt, f, 2.6, 150, Color("#ffe066"), 84)
			if f > 2.6:
				var names: Array = []
				for s in pl:
					if s.win:
						names.append(s.p.name)
				var k: float = clamp((f - 2.6) * 3.0, 0.0, 1.0)
				D.text(c, "🏆 " + ", ".join(names), 640, 90, {"size": 40 * D.ease_out_back(k), "color": Color("#ffffff"), "stroke": D.DARK, "sw": 9, "maxw": 1000})


## A választható számok (a telefonon ugyanezek a gombok): kör alakú, színes jelvények alul.
func _draw_options(c: CanvasItem) -> void:
	var r := 27.0
	var gap := 66.0
	var x0 := 52.0
	D.text(c, "Lépések:", x0 - 26, 618, {"size": 17, "align": "left", "color": Color.WHITE, "stroke": D.DARK, "sw": 5})
	for j in opts.size():
		var x := x0 + j * gap
		var y := 668.0 + sin(t * 3.0 + j * 0.8) * 3.0
		c.draw_circle(Vector2(x + 3, y + 5), r, Color(0, 0, 0, 0.3))
		c.draw_circle(Vector2(x, y), r, Color("#ffffff"))
		D.ring(c, x, y, r - 3, Color("#5fae3c"), 6)
		D.text(c, str(opts[j]), x, y + 2, {"size": 30, "color": Color("#2b1055")})


## A figurák feje fölött: hányadik fokon állnak; döntés közben, hogy választottak-e már (a számot nem!).
func _draw_heads(c: CanvasItem) -> void:
	for s in pl:
		var m: Node3D = s.m
		var sp := screen(m.position + Vector3(0, 1.35 * MS + 0.25, 0))
		if sp.x < -500:
			continue
		var col: Color = s.col
		if phase == "pick" or phase == "intro":
			D.panel(c, sp.x - 26, sp.y - 15, 52, 30, {"r": 15, "fill": Color(col, 0.9), "stroke": Color.WHITE, "lw": 2.5, "shadow": false})
			D.text(c, str(s.pos), sp.x, sp.y + 1, {"size": 18})
			if phase == "pick":
				var mark := "✔" if s.pick != 0 else "🤔"
				D.text(c, mark, sp.x + 30, sp.y - 14, {"size": 22, "color": Color("#69db7c"), "stroke": D.DARK, "sw": 5})
		elif phase == "climb":
			var e := t - phase_t0
			var k: float = clamp(e * 3.0, 0.0, 1.0)
			if s.ok and s.go > 0:
				D.text(c, "+%d" % s.go, sp.x, sp.y - 6 - e * 12.0, {"size": 30 * D.ease_out_back(k), "color": Color("#69db7c"), "stroke": D.DARK, "sw": 6})
			elif not s.ok:
				D.text(c, "✖ %d" % s.final, sp.x, sp.y - 6, {"size": 26 * D.ease_out_back(k), "color": Color("#ff8787"), "stroke": D.DARK, "sw": 6})
			if e >= climb_dur - 0.6:
				D.panel(c, sp.x - 26, sp.y + 14, 52, 30, {"r": 15, "fill": Color(col, 0.9), "stroke": Color.WHITE, "lw": 2.5, "shadow": false})
				D.text(c, str(s.pos), sp.x, sp.y + 30, {"size": 18})


## Jobb oldalt függőleges „lépcső-térkép”: ki hol tart, fent a cél.
func _draw_ladder(c: CanvasItem) -> void:
	var x := 1236.0
	var y0 := 600.0
	var y1 := 170.0
	D.panel(c, x - 24, y1 - 46, 48, y0 - y1 + 80, {"r": 22, "fill": Color(0.1, 0.18, 0.08, 0.55), "stroke": Color(1, 1, 1, 0.5), "lw": 2, "shadow": false})
	for k in range(0, top + 1, 2):
		var y := lerpf(y0, y1, float(k) / top)
		c.draw_line(Vector2(x - 12, y), Vector2(x + 12, y), Color(0.85, 0.65, 0.4, 0.7), 3.0)
	D.emoji(c, "🏁", x, y1 - 24, 30)
	var order: Array = pl.duplicate()
	order.sort_custom(func(a, b): return float(a.vis) < float(b.vis))
	var seen := {}
	for s in order:
		var key := int(round(float(s.vis)))
		var off: int = seen.get(key, 0)
		seen[key] = off + 1
		var y := lerpf(y0, y1, float(s.vis) / top)
		D.avatar(c, s.p, x - 34 - off * 22, y, 13, {"shadow": false})


## A felfedés: minden játékos saját színű portrélapja, rajta a felmutatott szám.
func _draw_panels(c: CanvasItem) -> void:
	var e := t - phase_t0
	# bal és jobb oldali oszlop, hogy a lépcső és a figurák középen szabadon maradjanak
	var per := int(ceil(n / 2.0))
	var w := 262.0 if n <= 4 else (240.0 if n <= 6 else 222.0)
	var h := minf(150.0, (600.0 - (per - 1) * 10.0) / per)
	var y0 := 400.0 - (per * (h + 10.0) - 10.0) / 2.0
	for j in n:
		var s: Dictionary = pl[j]
		var right := j % 2 == 1
		var ci := j / 2
		var x := 1280.0 - 84.0 - w if right else 16.0
		var y := y0 + ci * (h + 10.0)
		var k: float = clamp((e - j * 0.05) / 0.35, 0.0, 1.0)
		if k <= 0.0:
			continue
		var sc := D.ease_out_back(k)
		var col: Color = s.col
		var bad: bool = e >= CLASH_AT and not s.ok
		var shake := sin(e * 40.0) * 6.0 * maxf(0.0, 1.0 - (e - CLASH_AT) * 2.5) if bad else 0.0
		c.draw_set_transform(Vector2(x + w / 2 + shake, y + h / 2), 0, Vector2(sc, sc))
		D.panel(c, -w / 2, -h / 2, w, h, {"r": 18, "fill": D.shade(col, -0.5), "stroke": col, "lw": 5})
		D.panel(c, -w / 2 + 6, -h / 2 + 6, w - 12, h * 0.32, {"r": 12, "fill": Color(1, 1, 1, 0.12), "stroke": null, "shadow": false})
		var ps := h - 34.0
		D.char_image(c, s.p.char_id, -w / 2 + ps / 2 + 10, 6, ps)
		D.text(c, s.p.name, -w / 2 + 12, -h / 2 + 16, {"size": 15, "align": "left", "maxw": w * 0.55})
		# a nagy kerek számtábla
		var r := h * 0.33
		var cx := w / 2 - r - 12
		var cy := 8.0 + sin(e * 5.0 + j) * 2.0
		c.draw_circle(Vector2(cx + 3, cy + 5), r, Color(0, 0, 0, 0.35))
		c.draw_circle(Vector2(cx, cy), r, col)
		c.draw_circle(Vector2(cx, cy), r - 6, Color.WHITE)
		D.text(c, str(s.final), cx, cy + 2, {"size": int(r * 1.25), "color": D.shade(col, -0.5)})
		if e >= CLASH_AT:
			var kk: float = clamp((e - CLASH_AT) / 0.25, 0.0, 1.0)
			if bad:
				D.text(c, "✖", cx + r * 0.75, cy - r * 0.7, {"size": int(36 * D.ease_out_back(kk)), "color": Color("#ff6b6b"), "stroke": Color.WHITE, "sw": 5})
			else:
				D.text(c, "+%d" % s.final, cx + r * 0.7, cy - r * 0.75, {"size": int(28 * D.ease_out_back(kk)), "color": Color("#69db7c"), "stroke": D.DARK, "sw": 5})
		if s.auto:
			D.text(c, "⌛", -w / 2 + 18, h / 2 - 18, {"size": 20})
		c.draw_set_transform(Vector2.ZERO)
