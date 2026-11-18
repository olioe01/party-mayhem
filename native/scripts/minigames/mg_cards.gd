extends Minigame
## Kártyafogó: 12 lefordított lap (3 sor × 4 oszlop); minden sorban mindenkinek pontosan egy lapja van.
## Körbe haladva mindenki a saját három lapját keresi egy menetben: előbb az 1. sorban fordít fel egyet,
## ha az övé, jöhet a 2. sor, aztán a 3. Ha bármelyik sorban mellényúl, a menetben felfordított összes lapja
## visszafordul, és legközelebb újra az 1. sortól kezd. Csak annak a lapjai maradnak végleg fent, aki mindhárom
## sorban megtalálta a sajátját – ő végzett (aki elsőként, az nyer). A játék addig tart, amíg egy játékos marad.
## A végül be nem fejezők sorrendje: a legjobb menetük (hány sorig jutottak), aztán a kevesebb gondolkodási idő.

const K = preload("res://scripts/minigames/mg_kit.gd")

const ROWS := 3
const CARD_W := 1.2
const CARD_L := 1.6
const CARD_T := 0.035
const COL_GAP := 1.6
const ROW_Z := [-2.15, 0.0, 2.15]
const TURN_TIME := 10.0
const FLIP_DUR := 0.5
const FIRST_TURN := 1.0
const AI_MEMORY := [0.45, 0.7, 0.92]    # mekkora eséllyel jegyez meg egy felfedett lapot a gép (könnyű, közepes, nehéz)
const AI_THINK := [[2.2, 4.5], [1.4, 3.0], [0.8, 1.9]]
const TURN_CAP := 12               # legfeljebb ennyi menete lehet mindenkinek (utána vége)
const TEX_W := 150
const TEX_H := 200

static var _tex_cache := {}

var pl: Array = []              # helyek (valódi és gépi játékosok)
var cards: Array = []
var stage := "intro"            # intro | turn | reveal | result | fail | flipback | won | done
var row_i := 0                  # a soron lévő játékos aktuális sora
var turns := 0                  # eddigi menetek száma
var fin_count := 0              # hányan végeztek már
var active := -1
var turn_t0 := 0.0
var pick := -1
var pick_t := 0.0
var next_at := 0.0
var done_t := -1.0
var places := {}                # pl index -> helyezés (a végén)

var cursor := Vector2(640, 360)
var cursor_card := -1
var hover_card := -1
var hover_next := 0.0
var glow: MeshInstance3D
var glow_mat: StandardMaterial3D
var msg_text := ""
var msg_col := Color.WHITE
var msg_t0 := -10.0
var msg_dur := 1.2
var row_labels: Array = []


func meta() -> Dictionary:
	return {"id": "cards", "name": "Kártyafogó", "icon": "🃏", "color": "#c2255c", "modes": ["ffa"],
		"tagline": "Találd meg mind a három lapodat!",
		"desc": "Tizenkét lefordított lap fekszik az asztalon: minden sorban mindenkinek pontosan egy lapja van. Ha rád kerül a sor, előbb az 1. sorban keresed a sajátodat – ha megvan, jöhet a 2., aztán a 3. sor. Ha bármelyiknél mellényúlsz, minden lapod visszafordul, és legközelebb elölről kezded. Aki elsőként találja meg mind a hármat, nyer – figyeld, mit fordítanak fel a többiek!",
		"controls": "Amikor rád kerül a sor, lapponként 10 másodperced van: nyomd meg az aktuális sorod 1–4. lapjának gombját."}


func layout(p) -> Dictionary:
	return _ctrl_for(p)


var cols := 4                     # soronként ennyi lap: a játékosok száma, de legalább 4


## a c. oszlop x helye (a lapok középre rendezve)
func _col_x(c: int) -> float:
	return (c - (cols - 1) / 2.0) * _gap()


func _gap() -> float:
	return COL_GAP if cols <= 4 else 1.45


## az asztal fél szélessége (a lapok + szegély)
func _half_w() -> float:
	return maxf(5.3, (cols - 1) / 2.0 * _gap() + CARD_W / 2.0 + 1.6)


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	cols = maxi(4, players.size())
	make_env("#0c1f16", "#1d3b2a", 0.55)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0d1a14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9d8c4")
	env.ambient_light_energy = 0.55
	var cam_k := maxf(1.0, _half_w() / 5.3)
	make_camera(Vector3(0.0, 10.6 * cam_k, 3.6 * cam_k), Vector3(0.0, 0.0, 0.25), 42)
	var sun := make_sun(Vector3(-62, -18, 0), 1.25, "#fff4e0")
	sun.shadow_blur = 3.0
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 6.5, 0.5)
	lamp.omni_range = 14.0
	lamp.light_energy = 0.7
	lamp.light_color = Color("#ffe7b8")
	add_child(lamp)
	_build_table()
	var all := players.duplicate()
	var ai_k := 0
	for i in all.size():
		var p = all[i]
		var cpu := not players.has(p)
		var lvl := 1
		if cpu or p.is_bot:
			lvl = K.ai_level(ai_k)
			ai_k += 1
		pl.append({"p": p, "cpu": cpu, "i": i, "col": Color(K.SLOT_COLORS[i % K.SLOT_COLORS.size()]), "row": 0, "best": 0, "fin": -1, "turn_cards": [], "miss": 0, "time": 0.0,
			"lvl": lvl, "mem": {}, "think": 0.0, "react_t": -10.0, "react_ok": false})
	_deal()
	_sync(0.0)


func _build_table() -> void:
	var floor_m := Chars3D.mat("#22160f", {"rough": 0.9})
	Chars3D.box(self, 40, 0.2, 30, floor_m, Vector3(0, -1.2, 0))
	var felt := Chars3D.mat("#1f6b3e", {"rough": 1.0})
	var wood := Chars3D.mat("#7a4a26", {"rough": 0.55})
	var wood_l := Chars3D.mat("#a0663a", {"rough": 0.5})
	var hw := _half_w()
	Chars3D.box(self, hw * 2.0, 0.5, 7.9, wood, Vector3(0, -0.27, 0.15))
	Chars3D.box(self, hw * 2.0 - 0.6, 0.06, 7.3, felt, Vector3(0, 0.0, 0.15))
	# a filc finom mintája: sötétebb csíkok, hogy ne legyen egyszínű
	var felt_d := Chars3D.mat("#1a5e36", {"rough": 1.0})
	for i in 9:
		Chars3D.box(self, hw * 2.0 - 0.6, 0.005, 0.32, felt_d, Vector3(0, 0.032, -3.3 + i * 0.86))
	for s in [-1, 1]:
		Chars3D.box(self, hw * 2.0 + 0.1, 0.18, 0.32, wood_l, Vector3(0, 0.06, 0.15 + s * 3.8))
		Chars3D.box(self, 0.32, 0.18, 7.9, wood_l, Vector3(s * (hw - 0.1), 0.06, 0.15))
	# sorszámok mindkét oldalon
	for r in ROWS:
		for s in [-1, 1]:
			var lb := Label3D.new()
			lb.text = str(r + 1)
			lb.font_size = 150
			lb.pixel_size = 0.008
			lb.outline_size = 28
			lb.modulate = Color("#ffe066")
			lb.outline_modulate = Color("#3b1a00")
			lb.rotation = Vector3(-PI / 2, 0, 0)
			lb.position = Vector3(s * (_col_x(cols - 1) + CARD_W / 2.0 + 0.95), 0.05, ROW_Z[r])
			add_child(lb)
			row_labels.append({"n": lb, "r": r})
	# kiemelő keret a kurzor alatti lapnak
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_texture = _glow_tex()
	glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CARD_W + 0.42, CARD_L + 0.42)
	glow.mesh = q
	glow.material_override = glow_mat
	glow.rotation = Vector3(-PI / 2, 0, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visible = false
	add_child(glow)


## Lapok kiosztása: minden sorban mindenkinek egy lapja van (4-nél kevesebb játékosnál több is), soronként külön keverve.
func _deal() -> void:
	var owners: Array = []
	for r in ROWS:
		var row: Array = []
		for k in cols:
			row.append(k % pl.size())
		for k in range(row.size() - 1, 0, -1):
			var j := randi() % (k + 1)
			var tmp = row[k]
			row[k] = row[j]
			row[j] = tmp
		owners.append_array(row)
	var body_mesh := _card_body()
	var edge := Chars3D.mat("#f8f4ea", {"rough": 0.35})
	var shadow_m := Chars3D.mat("#000000", {"alpha": 0.32, "unshaded": true})
	for k in owners.size():
		var r := k / cols
		var c := k % cols
		var base := Vector3(_col_x(c), 0.05, ROW_Z[r])
		var sh := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(CARD_W * 1.04, CARD_L * 1.04)
		sh.mesh = sq
		sh.material_override = shadow_m
		sh.rotation = Vector3(-PI / 2, 0, 0)
		sh.position = base + Vector3(0.07, -0.015, 0.09)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sh)
		var piv := Chars3D.grp(self, base)
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = edge
		body.rotation = Vector3(PI / 2, 0, 0)
		piv.add_child(body)
		var back_m := StandardMaterial3D.new()
		back_m.albedo_texture = _back_tex()
		back_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		back_m.roughness = 0.45
		var front_m := StandardMaterial3D.new()
		front_m.albedo_texture = _front_tex(pl[owners[k]])
		front_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		front_m.roughness = 0.4
		var qm := QuadMesh.new()
		qm.size = Vector2(CARD_W, CARD_L)
		var back := MeshInstance3D.new()
		back.mesh = qm
		back.material_override = back_m
		back.rotation = Vector3(-PI / 2, 0, 0)
		back.position = Vector3(0, CARD_T / 2 + 0.003, 0)
		piv.add_child(back)
		var front := MeshInstance3D.new()
		front.mesh = qm
		front.material_override = front_m
		front.rotation = Vector3(PI / 2, 0, PI)
		front.position = Vector3(0, -CARD_T / 2 - 0.003, 0)
		piv.add_child(front)
		cards.append({"owner": owners[k], "r": r, "c": c, "base": base, "piv": piv, "sh": sh, "back_m": back_m, "front_m": front_m,
			"up": false, "perm": false, "flip_t0": -10.0, "from": 0.0, "to": 0.0, "ok": false})


func _card_body() -> ArrayMesh:
	var pts: Array = []
	var rr := 0.11
	var hw := CARD_W / 2 - 0.004
	var hl := CARD_L / 2 - 0.004
	var corners := [[hw - rr, hl - rr, 0.0], [-hw + rr, hl - rr, PI / 2], [-hw + rr, -hl + rr, PI], [hw - rr, -hl + rr, PI * 1.5]]
	for cc in corners:
		for i in 4:
			var a: float = cc[2] + PI / 2 * i / 3.0
			pts.append([cc[0] + cos(a) * rr, cc[1] + sin(a) * rr])
	return Chars3D.prism(pts, CARD_T)


# ------------------------------------------------------------------ textúrák (egyszer készülnek el)
static func _rounded_alpha(x: int, y: int, w: int, h: int, r: int) -> bool:
	var cx: int = clampi(x, r, w - 1 - r)
	var cy: int = clampi(y, r, h - 1 - r)
	return Vector2(x - cx, y - cy).length() <= r


static func _back_tex() -> ImageTexture:
	if _tex_cache.has("back"):
		return _tex_cache["back"]
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var base := Color("#9c1d7a")
	var deep := Color("#6d0f57")
	var light := Color("#e64fb6")
	var cx := TEX_W / 2.0
	var cy := TEX_H / 2.0
	for y in TEX_H:
		for x in TEX_W:
			if not _rounded_alpha(x, y, TEX_W, TEX_H, 14):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := base
			var inset: int = min(min(x, TEX_W - 1 - x), min(y, TEX_H - 1 - y))
			if inset < 5:
				col = Color("#fdf2fa")
			elif inset < 9:
				col = deep
			elif inset == 11 or inset == 12:
				col = Color(1, 1, 1, 1)
			else:
				# szimmetrikus virágminta: rózsagörbe sziromlevelek + koncentrikus körök
				var dx := (x - cx) / (TEX_W * 0.42)
				var dy := (y - cy) / (TEX_H * 0.42)
				var rad := sqrt(dx * dx + dy * dy)
				var ang := atan2(dy, dx)
				var petal: float = abs(cos(ang * 4.0)) * 0.62 + 0.12
				var petal2: float = abs(cos(ang * 4.0 + PI / 4)) * 0.42 + 0.1
				if rad < 0.1:
					col = Color("#ffe066")
				elif rad < petal and rad > 0.13:
					col = light if rad > petal - 0.07 else Color("#c93c9a")
				elif rad < petal2 + 0.05 and rad > petal2 - 0.02:
					col = Color("#f7c8e8")
				elif abs(rad - 0.86) < 0.025:
					col = Color(1, 1, 1, 1)
				else:
					var diag := int(floor((x + y) / 9.0) + floor((x - y + 400) / 9.0))
					col = base if diag % 2 == 0 else base.darkened(0.08)
				# sarokdíszek: kis virágok a négy sarokban
				for cc in [[22, 22], [TEX_W - 23, 22], [22, TEX_H - 23], [TEX_W - 23, TEX_H - 23]]:
					var d := Vector2(x - cc[0], y - cc[1])
					var a2 := atan2(d.y, d.x)
					var lr := d.length()
					if lr < 3.5:
						col = Color("#ffe066")
					elif lr < 5.0 + abs(cos(a2 * 2.0)) * 5.0:
						col = Color("#ffffff")
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache["back"] = tex
	return tex


func _front_tex(s: Dictionary) -> ImageTexture:
	var key := "front_%s_%d" % [s.p.char_id, s.i]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var col: Color = s.col
	var por := Image.new()
	var data := Net.read_web_file("img/chars/%s.png" % s.p.char_id)
	var has_por := data.size() > 0 and por.load_png_from_buffer(data) == OK
	var ps := 118
	if has_por:
		por.convert(Image.FORMAT_RGBA8)
		por.resize(ps, ps, Image.INTERPOLATE_BILINEAR)
	var px0 := (TEX_W - ps) / 2
	var py0 := 30
	for y in TEX_H:
		for x in TEX_W:
			if not _rounded_alpha(x, y, TEX_W, TEX_H, 14):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var inset: int = min(min(x, TEX_W - 1 - x), min(y, TEX_H - 1 - y))
			var c := Color("#fffaf0")
			if inset < 4:
				c = Color("#ffffff")
			elif inset < 12:
				c = col
			elif inset < 14:
				c = col.lightened(0.5)
			else:
				# világos sugaras háttér a portré mögött
				var a := atan2(y - 90.0, x - 75.0)
				c = Color("#fff6d6") if int(floor((a + PI) / TAU * 16.0)) % 2 == 0 else Color("#ffefc0")
				if y > TEX_H - 40:
					c = col.lightened(0.25)
			if has_por and x >= px0 and x < px0 + ps and y >= py0 and y < py0 + ps:
				var pc := por.get_pixel(x - px0, y - py0)
				c = c.lerp(Color(pc.r, pc.g, pc.b, 1.0), pc.a)
			img.set_pixel(x, y, c)
	if not has_por:
		# portré nélkül (pl. hiányzó kép) nagy, színes kör a játékos színével
		for y in range(50, 140):
			for x in range(30, 120):
				if Vector2(x - 75, y - 95).length() < 40:
					img.set_pixel(x, y, s.p.color)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func _glow_tex() -> ImageTexture:
	if _tex_cache.has("glow"):
		return _tex_cache["glow"]
	var w := 96
	var h := 124
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			# távolság a belső lekerekített téglalaptól
			var qx: float = max(abs(x - w / 2.0) - (w / 2.0 - 14), 0.0)
			var qy: float = max(abs(y - h / 2.0) - (h / 2.0 - 14), 0.0)
			var d := Vector2(qx, qy).length()
			var a: float = clamp(1.0 - abs(d - 8.0) / 7.0, 0.0, 1.0)
			a = max(a, 1.0 - abs(d - 5.0) / 1.8) if d > 2.0 else a
			img.set_pixel(x, y, Color(1, 1, 1, clamp(a, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache["glow"] = tex
	return tex


# ------------------------------------------------------------------ vezérlő
func _ctrl_for(p) -> Dictionary:
	var si := _slot_of(p)
	if stage == "turn" and si == active:
		var cells: Array = []
		for c in cols:
			var cd: Dictionary = cards[row_i * cols + c]
			cells.append("" if cd.up else "🃏 %d" % (c + 1))
		return {"mode": "grid", "cols": 4, "title": "%d. sor – melyik a te lapod?" % (row_i + 1), "cells": cells}
	if si >= 0 and pl[si].fin >= 0:
		return {"mode": "wait", "icon": "✅", "title": "Megtaláltad mind a hármat!", "text": "%d. lettél – nézd, hogy boldogulnak a többiek." % (pl[si].fin + 1)}
	if stage == "intro":
		return {"mode": "wait", "icon": "👀", "title": "Figyelj!", "text": "Jegyezd meg, mit fordítanak fel a többiek!"}
	if active >= 0 and active < pl.size():
		return {"mode": "wait", "icon": "🃏", "title": "%s keres…" % pl[active].p.name, "text": "%d. sor" % (row_i + 1)}
	return {"mode": "wait", "icon": "🃏", "title": "Figyeld az asztalt!"}


func _push_ctrl() -> void:
	for s in pl:
		if not s.cpu:
			Net.set_ctrl(s.p.pid, _ctrl_for(s.p))


func _slot_of(p) -> int:
	for s in pl:
		if s.p == p:
			return s.i
	return -1


# ------------------------------------------------------------------ játékmenet
func start() -> void:
	stage = "intro"
	_push_ctrl()


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "cell" or stage != "turn":
		return
	var si := _slot_of(p)
	if si != active:
		return
	var c := int(msg.get("v", -1))
	if c < 0 or c >= cols:
		return
	_choose(row_i * cols + c)


func bot(p, dt: float) -> void:
	var si := _slot_of(p)
	if si >= 0:
		_ai(pl[si], dt)


## gépi döntés: emlékezetből a saját lapját keresi, különben a még ismeretlenek közül tippel
func _ai(s: Dictionary, _dt: float) -> void:
	if stage != "turn" or s.i != active:
		return
	if t - turn_t0 < s.think:
		return
	var free: Array = []
	for c in cols:
		var k: int = row_i * cols + c
		if not cards[k].up:
			free.append(k)
	if free.is_empty():
		return
	var mine: Array = free.filter(func(k): return s.mem.get(k, -1) == s.i)
	var unknown: Array = free.filter(func(k): return not s.mem.has(k))
	var choice: int = free[randi() % free.size()]
	if not mine.is_empty():
		choice = mine[randi() % mine.size()]
	elif not unknown.is_empty():
		choice = unknown[randi() % unknown.size()]
	_choose(choice)


func _choose(k: int) -> void:
	var cd: Dictionary = cards[k]
	if cd.up or cd.r != row_i:
		return
	var s: Dictionary = pl[active]
	stage = "reveal"
	print_verbose("[mg] kártya: %s %.2f mp (gondolkodás %.2f)" % [s.p.name, t - turn_t0, s.think])
	pick = k
	pick_t = t
	s.time += t - turn_t0
	_flip(cd, true)
	Audio.play("flip", FX.fr(0.95, 1.1))
	next_at = t + FLIP_DUR + 0.15
	_push_ctrl()


func _flip(cd: Dictionary, up: bool) -> void:
	cd.up = up
	cd.flip_t0 = t
	cd.from = cd.to
	cd.to = PI if up else 0.0


func update(dt: float) -> void:
	for s in pl:
		if s.cpu:
			_ai(s, dt)
	match stage:
		"intro":
			if t >= FIRST_TURN:
				_give_turn(0)
		"turn":
			if t - turn_t0 >= TURN_TIME:
				var s: Dictionary = pl[active]
				s.miss += 1
				s.time += TURN_TIME
				s.react_t = t
				s.react_ok = false
				Audio.play("bad")
				_say("Lejárt az idő!", Color("#ff8787"), 1.0)
				stage = "fail"
				next_at = t + 0.8
				_push_ctrl()
		"reveal":
			if t >= next_at:
				_evaluate()
		"result":
			if t >= next_at:
				_begin_turn()
		"fail":
			if t >= next_at:
				_flip_back()
		"flipback", "won":
			if t >= next_at:
				_pass_turn()
		"done":
			if t >= done_t + 4.2:
				finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


## Egy felfedett lapot a gépek a szintjüktől függő eséllyel jegyeznek meg (a saját lapjukra jobban figyelnek).
## Mindenkinek kiszámoljuk (az emberekét nem használjuk), így a véletlen-sorozat minden gépen azonos.
func _remember(k: int) -> void:
	for s in pl:
		var bonus: float = 0.08 if cards[k].owner == s.i else 0.0
		if randf() < AI_MEMORY[s.lvl] + bonus:
			s.mem[k] = cards[k].owner


## Új menet: a játékos az 1. sortól kezdi.
func _give_turn(i: int) -> void:
	active = i
	turns += 1
	var s: Dictionary = pl[i]
	s.row = 0
	s.turn_cards = []
	_say("%s keres" % s.p.name, s.col.lightened(0.35), 1.0)
	Audio.play("go")
	_begin_turn()


## Egy tipp a soron lévő játékos aktuális sorában (egy menetben több is lehet).
func _begin_turn() -> void:
	var s: Dictionary = pl[active]
	row_i = s.row
	turn_t0 = t
	stage = "turn"
	pick = -1
	var th: Array = AI_THINK[s.lvl]
	s.think = randf_range(th[0], th[1])
	hover_next = 0.0
	Audio.play("select")
	_push_ctrl()


func _evaluate() -> void:
	var cd: Dictionary = cards[pick]
	var s: Dictionary = pl[active]
	var ok: bool = cd.owner == active
	cd.ok = ok
	s.react_t = t
	s.react_ok = ok
	var sp := screen(cd.base)
	# aki figyelt, megjegyzi, mi volt a lapon
	_remember(pick)
	if not ok:
		Audio.play("bad")
		Main.I.float_text(sp.x, sp.y - 40, "✖", Color("#ff6b6b"), 42)
		if not s.turn_cards.is_empty():
			_say("Minden visszafordul!", Color("#ff8787"), 1.1)
		stage = "fail"
		next_at = t + 1.1
		return
	s.turn_cards.append(pick)
	s.row += 1
	s.best = maxi(s.best, s.row)
	Audio.play("sparkle")
	Main.I.burst(sp.x, sp.y, {"n": 28, "colors": ["#ffe066", "#ffffff", "#fff3bf", (s.col as Color).to_html()], "speed": 300, "gravity": 220, "size": 7})
	if s.row < ROWS:
		Audio.play("coin")
		Main.I.float_text(sp.x, sp.y - 40, "✔ %d/%d" % [s.row, ROWS], Color("#ffe066"), 38)
		stage = "result"
		next_at = t + 0.9
		return
	# mindhárom megvan: a lapjai végleg fent maradnak
	s.fin = fin_count
	fin_count += 1
	for k in s.turn_cards:
		cards[k].perm = true
	Audio.play("fanfare" if s.fin == 0 else "win")
	Main.I.float_text(sp.x, sp.y - 40, "✔ %d/%d" % [s.row, ROWS], Color("#ffe066"), 38)
	_say(("🏆 %s nyert!" if s.fin == 0 else "✅ %s végzett!") % s.p.name, Color("#ffd43b"), 1.8)
	if s.fin == 0 and not preview:
		Main.I.confetti(60)
	stage = "won"
	next_at = t + 2.0
	_push_ctrl()


## Mellényúlt (vagy lejárt az idő): a menetben felfordított összes lapja visszafordul.
func _flip_back() -> void:
	var s: Dictionary = pl[active]
	var back: Array = s.turn_cards.duplicate()
	if pick >= 0:
		back.append(pick)
	for k in back:
		var cd: Dictionary = cards[k]
		if cd.up and not cd.perm:
			_flip(cd, false)
			cd.ok = false
	if not back.is_empty():
		Audio.play("flip", FX.fr(0.85, 0.95))
	s.turn_cards = []
	s.row = 0
	pick = -1
	stage = "flipback"
	next_at = t + FLIP_DUR + 0.25
	_push_ctrl()


## A következő, még nem végzett játékos jön; ha csak egy maradt (vagy elfogytak a menetek), vége.
func _pass_turn() -> void:
	pick = -1
	var left: Array = []
	for s in pl:
		if s.fin < 0:
			left.append(s.i)
	if left.size() <= (1 if pl.size() > 1 else 0) or turns >= TURN_CAP * pl.size():
		_finish()
		return
	var n := pl.size()
	for k in range(1, n + 1):
		var j := (active + k) % n
		if pl[j].fin < 0:
			_give_turn(j)
			return


func _finish() -> void:
	stage = "done"
	done_t = t
	active = -1
	var idx: Array = range(pl.size())
	idx.sort_custom(func(a, b): return _score(pl[a]) > _score(pl[b]))
	for k in idx.size():
		places[idx[k]] = k
	var best: Dictionary = pl[idx[0]]
	print_verbose("[mg] kártyafogó vége (%d menet): %s" % [turns, ", ".join(idx.map(func(k): return "%s(%s) %s %.1f mp" % [pl[k].p.name, K.LEVEL_NAME[pl[k].lvl], _label(pl[k]), pl[k].time]))])
	_say("🏆 %s nyert!" % best.p.name, Color("#ffd43b"), 3.0)
	Audio.play("fanfare")
	if not preview:
		Main.I.confetti(120)
	_push_ctrl()


## a végzettek a befejezés sorrendjében; a többiek a legjobb menetük, aztán a kevesebb gondolkodási idő szerint
func _score(s: Dictionary) -> float:
	if s.fin >= 0:
		return 1000000.0 - s.fin * 10000.0
	return s.best * 1000.0 - s.time


func _label(s: Dictionary) -> String:
	if s.fin >= 0:
		return "✅ %d. kész · %.1f mp" % [s.fin + 1, s.time]
	return "%d/%d sor · %.1f mp" % [s.best, ROWS, s.time]


func ranking() -> Array:
	var out: Array = []
	for s in pl:
		if s.cpu:
			continue
		out.append({"pid": s.p.pid, "score": _score(s), "label": _label(s)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func _say(text: String, col: Color, dur: float) -> void:
	msg_text = text
	msg_col = col
	msg_t0 = t
	msg_dur = dur


# ------------------------------------------------------------------ látvány
func _sync(_dt: float) -> void:
	for k in cards.size():
		var cd: Dictionary = cards[k]
		var piv: Node3D = cd.piv
		var f: float = clamp((t - cd.flip_t0) / FLIP_DUR, 0.0, 1.0)
		var e := D.ease_in_out(f)
		var lift := sin(f * PI) * 0.55
		var bounce := 0.0
		var after: float = t - cd.flip_t0 - FLIP_DUR
		if after > 0.0 and after < 0.3:
			bounce = sin(after / 0.3 * PI) * 0.07 * (1.0 - after / 0.3)
		piv.position = cd.base + Vector3(0, lift + bounce, 0)
		piv.rotation = Vector3(0, 0, lerp(float(cd.from), float(cd.to), e))
		var sq := 1.0 - bounce * 0.8
		piv.scale = Vector3(1.0 + bounce * 0.6, 1.0, sq)
		(cd.sh as Node3D).scale = Vector3.ONE * (1.0 + lift * 0.25)
		(cd.sh as Node3D).position = cd.base + Vector3(0.07 + lift * 0.25, -0.015, 0.09 + lift * 0.3)
		# az inaktív sorok elsötétülnek
		var lit := 1.0
		if stage in ["turn", "reveal", "result", "fail"]:
			lit = 1.0 if cd.r == row_i else 0.42
		var bm: StandardMaterial3D = cd.back_m
		var fm: StandardMaterial3D = cd.front_m
		var target := Color(lit, lit, lit)
		bm.albedo_color = bm.albedo_color.lerp(target, 0.15)
		var fl: float = lit if not cd.up else max(lit, 0.85)
		fm.albedo_color = fm.albedo_color.lerp(Color(fl, fl, fl), 0.15)
	for rl in row_labels:
		var on: bool = stage in ["intro", "done"] or rl.r == row_i
		var lb: Label3D = rl.n
		lb.modulate = lb.modulate.lerp(Color("#ffe066") if on else Color(0.45, 0.42, 0.3), 0.15)
		lb.scale = Vector3.ONE * (1.0 + (0.08 * sin(t * 5.0) if on and stage != "intro" and stage != "done" else 0.0))
	_cursor_step()


## A kéz alakú kurzor simán úszik a lapok között; a gép „gondolkodik”, a kurzor ide-oda vándorol.
func _cursor_step() -> void:
	var tgt_card := -1
	if stage == "turn":
		if t >= hover_next:
			var free: Array = []
			for c in cols:
				if not cards[row_i * cols + c].up:
					free.append(row_i * cols + c)
			if not free.is_empty():
				hover_card = free[int(FX.f() * free.size()) % free.size()]
			hover_next = t + FX.fr(0.45, 0.9)
		tgt_card = hover_card
	elif stage in ["reveal", "result"]:
		tgt_card = pick
	cursor_card = tgt_card
	if tgt_card >= 0:
		var sp := screen(cards[tgt_card].base + Vector3(0.25, 0.1, 0.45))
		cursor = cursor.lerp(sp, 0.18)
		var cp: Node3D = cards[tgt_card].piv
		var gp := Vector3(cp.position.x, 0.04, cp.position.z)
		glow.position = gp if not glow.visible else glow.position.lerp(gp, 0.2)
		glow.visible = true
		var col: Color = pl[active].col if active >= 0 else Color.WHITE
		var pulse := 0.75 + 0.25 * sin(t * 8.0)
		glow_mat.albedo_color = Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, pulse)
	else:
		glow.visible = false


func draw(c: CanvasItem) -> void:
	_draw_players(c)
	if stage == "turn":
		K.silver_timer(c, TURN_TIME - (t - turn_t0), 640, 46, 3.0, t)
	else:
		K.silver_timer(c, TURN_TIME if stage != "done" else 0.0, 640, 46, 3.0, t)
	# kéz kurzor
	if cursor_card >= 0 and active >= 0:
		var press: float = 1.0 - clamp((t - pick_t) / 0.25, 0.0, 1.0) if stage == "reveal" else 0.0
		var bob := sin(t * 6.0) * 4.0 if stage == "turn" else 0.0
		var col: Color = pl[active].col
		D.ellipse(c, cursor.x + 6, cursor.y + 30, 18, 6, Color(0, 0, 0, 0.3))
		c.draw_circle(cursor + Vector2(-6, -18 + bob + press * 8), 15, Color(col, 0.85))
		D.emoji(c, "👆", cursor.x, cursor.y + bob + press * 8, 44)
	var mk := t - msg_t0
	K.banner(c, msg_text, mk, msg_dur, 360, msg_col, 84)


## Bal oldali játékoslista: színes keret, portré, pontok; a soron lévő kiemelve, ugrálva.
func _draw_players(c: CanvasItem) -> void:
	var n := pl.size()
	var h := 112.0
	var hs: float = minf(1.0, 690.0 / (n * (h + 10) - 10))    # 5–8 játékosnál kisebb kártyák
	var y0 := 360.0 - (n * (h + 10) - 10) * hs / 2.0
	for s in pl:
		var y: float = y0 + s.i * (h + 10) * hs + h * hs / 2
		var on: bool = s.i == active
		var rk: float = t - s.react_t
		var x := 22.0
		var sc := 1.0
		if on:
			sc = 1.08 + 0.03 * sin(t * 6.0)
			x += 10.0
		if rk >= 0 and rk < 0.6:
			if s.react_ok:
				sc += sin(rk / 0.6 * PI) * 0.12
			else:
				x += sin(rk * 40.0) * 8.0 * (1.0 - rk / 0.6)
		c.draw_set_transform(Vector2(x + 95 * hs, y), 0, Vector2(sc * hs, sc * hs))
		var col: Color = s.col
		if on:
			D.panel(c, -101, -h / 2 - 6, 202, h + 12, {"r": 22, "fill": Color(col, 0.35 + 0.25 * abs(sin(t * 5.0))), "stroke": null, "shadow": false})
		D.panel(c, -95, -h / 2, 190, h, {"r": 18, "fill": Color(0.06, 0.05, 0.12, 0.88), "stroke": col, "lw": 5.0})
		D.panel(c, -89, -h / 2 + 6, 178, 22, {"r": 11, "fill": Color(1, 1, 1, 0.1), "stroke": null, "shadow": false})
		# portré keretben
		D.panel(c, -86, -36, 72, 72, {"r": 14, "fill": col, "stroke": Color.WHITE, "lw": 3.0, "shadow": false})
		D.char_image(c, s.p.char_id, -50, 0, 66)
		var name: String = s.p.name
		if s.cpu or s.p.is_bot:
			name += " · " + K.LEVEL_NAME[s.lvl]
		D.text(c, name, -6, -28, {"size": 16, "align": "left", "maxw": 96})
		for k in ROWS:
			var got: bool = s.fin >= 0 or (on and k < s.row)
			var star := "⭐" if got else "☆"
			D.text(c, star, 6 + k * 28, 6, {"size": 22, "color": Color("#ffe066") if got else Color(1, 1, 1, 0.3)})
		var sub: String = "✅ %d. kész" % (s.fin + 1) if s.fin >= 0 else "legjobb: %d/%d" % [s.best, ROWS]
		D.text(c, sub, 30, 36, {"size": 14, "color": Color("#8ce99a") if s.fin >= 0 else Color(1, 1, 1, 0.6)})
		if rk >= 0 and rk < 1.2:
			D.emoji(c, "😄" if s.react_ok else "😣", 82, -h / 2 + 4, 30)
		c.draw_set_transform(Vector2.ZERO)
		if on and stage == "turn":
			var ax := 22.0 + 206.0 * hs + sin(t * 8.0) * 5.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(ax, y), Vector2(ax + 20, y - 14), Vector2(ax + 20, y + 14)]), Color.WHITE)
		if stage == "done" and places.has(s.i):
			var k: float = (t - done_t - 0.4 - (pl.size() - 1 - places[s.i]) * 0.25) * 2.5
			K.place_label(c, places[s.i], x + 168 * hs, y + 4, k, int(50 * maxf(hs, 0.7)))
