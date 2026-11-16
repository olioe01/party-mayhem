extends Minigame
## Ajándéktorony (3D) – mindenki egy billegő ajándéktornyot egyensúlyoz a feje fölött.
## A torony fordított inga: a gombok csak nyomatékot adnak, a lendület megmarad. A dobozok
## rugós láncként, késleltetve követik egymást. Szél, remegés, félidőben plusz doboz,
## és néha egy teherautó vagy biciklis hajt el a kamera előtt.
##
## Felépítés: egyensúly-fizika (_balance_step) · szél (_wind_step) · forgalom (_traffic_step) ·
## plusz ajándék (_extra_step) · figura- és arcanimáció (_animate_char) · leesett dobozok (_loose_step) · HUD (draw).

const W = preload("res://scripts/minigames/presents_world.gd")

const LIMIT := 60.0
const EXTRA_AT := 30.0           # ekkor ér le a negyedik doboz
const MAX_TILT := 0.5236         # 30 fok: ennél jobban megdőlve leborul
const BASE_SCALE := 1.4
const HOLD_Y := 1.95             # ilyen magasan tartják a kezek a tornyot
const BOX_H := 0.72
const TRUCK_D := 4.2             # ilyen messze megy el a teherautó a kamera előtt
const BIKE_D := 4.0
const ARM_L := 0.6               # felkar és alkar hossza a figura saját terében
const WIND_MAG := [0.0, 0.2, 0.42, 0.72, 0.98]      # szélcsend, szellő, szél, erős széllökés, hirtelen vihar
const WIND_NAME := ["Szélcsend", "Szellő", "Szél", "Erős szél", "Viharos lökés"]
const BOT_LAPSE := [0.002, 0.02, 3.0]     # a botok figyelmetlensége: alap, ügyetlenség szerinti, idővel növekvő
const FACES := ["😊", "😟", "😨", "😱"]
# a figurák szája (a rig terében) – ide kerül a rémülten kitátott száj
const MOUTHS := {
	"frog": [0.45, 0.4, 0.075], "panda": [0.63, 0.315, 0.04], "thimble": [0.3, 0.305, 0.06], "cat": [0.652, 0.32, 0.036],
	"tiger": [0.662, 0.332, 0.038], "bear": [0.705, 0.345, 0.04], "knight": [0.725, 0.225, 0.032], "queen": [0.75, 0.22, 0.032],
}

var pl: Array = []
var out_order: Array = []
var over := false
var end_at := -1.0
var dist := 10.5                 # a kamera távolsága a játékosok sorától
var cam_base := Vector3.ZERO
var shake := 0.0

# szél (közös minden játékosnak)
var wind := 0.0                  # pillanatnyi szél: szöggyorsulás, + = jobbra fúj
var wind_type := 0
var wind_dir := 1.0
var wind_t := 2.0                # ennyi van hátra a mostani szakaszból
var wind_warn := 0.0             # előjelzés: a nagy lökés ennyi idő múlva csap le
var wind_snd := 0.0

# forgalom
var veh := {}                    # az éppen áthaladó jármű: {truck, dir, x, v, warn, end, run}
var next_traffic := 20.0
var last_truck := false
var truck: Dictionary
var bike: Dictionary

# plusz ajándék
var extra_state := 0             # 0 = még nem jött, 1 = zuhan, 2 = megérkezett
var drops: Array = []

# üzenet a képernyő közepén
var msg_text := ""
var msg_col := Color.WHITE
var msg_t0 := -10.0
var msg_dur := 1.5

# díszlet
var town := {}
var leaves: Array = []
var streaks: Array = []
var loose: Array = []            # elszabadult dobozok (csak látvány)
var vis_t := 0.0


func meta() -> Dictionary:
	return {"id": "presents", "name": "Ajándéktorony", "icon": "🎁", "color": "#ff6b6b", "modes": ["ffa"],
		"tagline": "Ne borítsd fel a tornyot!",
		"desc": "Mindenki egy billegő ajándéktornyot egyensúlyoz. Fúj a szél, remeg a kezed, félidőben jön még egy doboz, és néha egy teherautó takarja ki a képet. Aki a legtovább bírja, az nyer.",
		"controls": "Tartsd nyomva a ◀ vagy ▶ gombot, hogy arra told a tornyot. Finoman: a torony lendülete megmarad! (A gépen az A/D vagy a ←/→ az első botot irányítja.)"}


func layout(_p) -> Dictionary:
	return {"mode": "lr"}


func keyboard_lr() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	var n: int = max(1, players.size())
	var gap: float = clamp(14.0 / n, 2.3, 3.5)
	dist = max(10.5, ((n - 1) / 2.0 * gap + 2.2) / 0.7545)
	make_env("#2a7be4", "#bfe4ff", 1.0)
	cam_base = Vector3(0, 1.7, dist)
	make_camera(cam_base, Vector3(0, 3.0, 0), 46)
	var sun := make_sun(Vector3(-46, -32, 0), 1.3, "#fff0d0")
	sun.shadow_blur = 2.0
	town = W.build_town(self, dist - TRUCK_D - 0.3)
	truck = W.build_truck(self)
	bike = W.build_cyclist(self)
	(bike.node as Node3D).scale = Vector3.ONE * 1.3
	_build_wind_fx()
	for i in players.size():
		pl.append(_make_player(players[i], i, (i - (n - 1) / 2.0) * gap))
	next_traffic = randf_range(18.5, 22.0)
	wind_dir = 1.0 if randf() < 0.5 else -1.0
	_sync(0.0)
	print_verbose("[mg] ajándéktorony indul (%s, %d játékos)" % ["próbakör" if preview else "éles", n])


func _make_player(p, i: int, x: float) -> Dictionary:
	var m := player_model(p, BASE_SCALE)
	m.position = Vector3(x, 0, 0)
	var disc := color_disc(p, 0.75)
	disc.position = Vector3(x, 0.03, 0)
	add_child(disc)
	# kinek milyen dobozok jutnak: játékosonként más sorrend
	var rnd := BoardLayout.Seeded.new(17 + i * 7)
	var types: Array = [0, 1, 2, 3, 4, 5]
	for k in range(5, 0, -1):
		var j := int(rnd.next() * (k + 1))
		var tmp = types[k]
		types[k] = types[j]
		types[j] = tmp
	var s := {"p": p, "m": m, "x": x, "i": i, "types": types,
		"th": 0.0, "om": 0.0, "om_prev": 0.0, "dir": 0, "in_f": 0.0, "nbox": 3, "alive": true, "kb": false,
		"phi": [0.0, 0.0, 0.0, 0.0], "phv": [0.0, 0.0, 0.0, 0.0],
		"ph0": randf() * TAU, "ph1": randf() * TAU, "ph2": randf() * TAU,
		"tr_t": 0.0, "tr_amp": 0.0, "tr_kick": 0.0, "tr_next": 0.0, "tr_at": randf_range(10.0, 15.0),
		"fear": 0.0, "squash": 0.0, "surprise": 0.0, "hx": 0.0, "out_t": 0.0, "out_time": 0.0, "won": false, "strain_t": 0.0,
		"skill": randf_range(0.5, 0.95), "ai_t": randf_range(0.1, 0.4),
		"gifts": [], "joints": [], "arms": [], "brows": [], "sweat": [], "mouth": null, "eye_r": 0.06}
	# a torony: forgáspont a kezeknél, fölötte láncba fűzött dobozok
	var pivot := Chars3D.grp(self, Vector3(x, HOLD_Y, 0.12))
	s["pivot"] = pivot
	var parent: Node3D = pivot
	var y := 0.0
	for k in 4:
		var j := Chars3D.grp(parent, Vector3(0, y, 0))
		s.joints.append(j)
		parent = j
		y = BOX_H
		if k < 3:
			_attach_gift(s, k)
	_build_arms(s)
	_build_face(s)
	return s


func _gift_w(k: int) -> float:
	return 1.06 - k * 0.07


func _attach_gift(s: Dictionary, k: int, g := {}) -> void:
	if g.is_empty():
		g = W.gift(s.types[k], _gift_w(k), BOX_H)
	var node: Node3D = g.node
	if node.get_parent():
		node.get_parent().remove_child(node)
	(s.joints[k] as Node3D).add_child(node)
	node.transform = Transform3D(Basis(), Vector3(0, BOX_H / 2, 0))
	s.gifts.append(g)
	for q in s.gifts.size():
		(s.gifts[q].bow as Node3D).visible = q == s.gifts.size() - 1


func _build_arms(s: Dictionary) -> void:
	var m: Chars3D.CharModel = s.m
	var sleeve := Chars3D.mat(s.p.color_hex, {"rough": 0.5})
	var glove := Chars3D.mat("#ffffff", {"rough": 0.4})
	for side in [-1, 1]:
		var sh := Vector3(side * 0.3, 0.56, 0.02)
		Chars3D.sphere(m, 0.075, sleeve, sh.x, sh.y, sh.z)
		s.arms.append({"side": side, "sh": sh,
			"up": W.seg(m, 0.055, sleeve), "fore": W.seg(m, 0.048, sleeve),
			"elbow": Chars3D.sphere(m, 0.058, sleeve), "hand": Chars3D.sphere(m, 0.09, glove)})


## Arckellékek a figura meglévő szemeihez igazítva: szemöldök, kitátott száj, izzadságcseppek.
func _build_face(s: Dictionary) -> void:
	var m: Chars3D.CharModel = s.m
	var dark := Chars3D.mat("#1f1b2e", {"rough": 0.4})
	if m.eyes.size() >= 2:
		var e0: Node3D = m.eyes[0]
		if e0.get_child_count() > 0 and e0.get_child(0) is MeshInstance3D and (e0.get_child(0) as MeshInstance3D).mesh is SphereMesh:
			s.eye_r = ((e0.get_child(0) as MeshInstance3D).mesh as SphereMesh).radius
		var r: float = max(0.04, s.eye_r)
		for k in 2:
			var b := Chars3D.box(m.eyes[k], r * 1.7, r * 0.34, r * 0.4, dark, Vector3(0, r * 1.45, r * 0.55))
			b.visible = false
			s.brows.append(b)
	if MOUTHS.has(m.char_id):
		var md: Array = MOUTHS[m.char_id]
		var mo := Chars3D.sphere(m.rig, md[2], Chars3D.mat("#3b1220", {"rough": 0.6}), 0, md[0], md[1], 1.0, 1.25, 0.55)
		Chars3D.sphere(mo, md[2] * 0.55, Chars3D.mat("#ff6b81"), 0, -md[2] * 0.45, md[2] * 0.25, 1, 0.6, 0.6)
		mo.visible = false
		s.mouth = mo
	var drop := Chars3D.mat("#8fd3ff", {"rough": 0.15})
	for k in 4:
		var d := Chars3D.sphere(m, 0.04, drop)
		d.visible = false
		s.sweat.append(d)


func _build_wind_fx() -> void:
	var cols := ["#69b34c", "#f59f00", "#e8590c", "#a9e34b", "#fcc419"]
	for i in 18:
		var mi := Chars3D.box(self, 0.2, 0.012, 0.11, Chars3D.mat(cols[i % cols.size()], {"rough": 0.8}), Vector3.ZERO)
		leaves.append({"n": mi, "x": FX.fr(-12, 12), "z": FX.fr(-4.0, 2.5), "h": FX.fr(0.5, 4.5), "ph": FX.f() * TAU, "sp": FX.fr(0.6, 1.3)})
	var white := Chars3D.mat("#ffffff", {"alpha": 0.5, "unshaded": true})
	var dust := Chars3D.mat("#e6d6ad", {"alpha": 0.3, "unshaded": true})
	for i in 14:
		var is_dust := i >= 9
		var mi: MeshInstance3D
		if is_dust:
			mi = Chars3D.sphere(self, 0.22, dust)
		else:
			mi = Chars3D.box(self, 1.0, 0.018, 0.018, white, Vector3.ZERO)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streaks.append({"n": mi, "dust": is_dust, "x": FX.fr(-12, 12), "y": FX.fr(0.1, 0.5) if is_dust else FX.fr(0.8, 5.5), "z": FX.fr(-2.0, 3.0), "sp": FX.fr(0.8, 1.4)})


func _get(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


# ------------------------------------------------------------------ bemenet és botok
func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "lr":
		return
	var s := _get(p)
	if s.is_empty():
		return
	if msg.get("kb", false):
		s.kb = true        # billentyűzetről vezérelt bot: innentől nem a gép játszik helyette
	s.dir = clampi(roundi(float(msg.get("v", 0))), -1, 1)


func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.is_empty() or not s.alive or s.kb:
		return
	s.ai_t -= dt
	if s.ai_t > 0:
		return
	var k: float = clamp(t / LIMIT, 0.0, 1.0)
	var lazy: float = 1.0 - s.skill
	s.ai_t = randf_range(0.07, 0.15) + lazy * 0.14
	# néha elbambul (teherautó mögött és négy dobozzal gyakrabban): elengedi a gombot, ritkán rajta felejti az ujját
	var blind: bool = not veh.is_empty() and veh.truck and veh.run
	var lapse: float = (BOT_LAPSE[0] + BOT_LAPSE[1] * lazy) * (1.0 + BOT_LAPSE[2] * k) * (2.5 if blind else 1.0) * (1.5 if s.nbox >= 4 else 1.0)
	if randf() < lapse:
		if randf() < 0.7:
			s.dir = 0
			s.ai_t = randf_range(0.3, 0.6) + lazy * 0.4
		else:
			s.ai_t = randf_range(0.2, 0.4) + lazy * 0.2
		return
	# az előre jelzett széllökésre az ügyesebb bot már előre ráfeszül
	var wnd: float = wind_dir * WIND_MAG[wind_type] * s.skill if wind_warn > 0 else wind
	var u: float = -(s.th * 3.4 + s.om * 1.3 + wnd * 0.3) + randf_range(-0.1, 0.1) * (0.5 + lazy)
	s.dir = 0 if abs(u) < 0.06 + lazy * 0.05 else int(sign(u))


# ------------------------------------------------------------------ játékmenet
func update(dt: float) -> void:
	_wind_step(dt)
	_traffic_step(dt)
	_extra_step(dt)
	if not over:
		for s in pl:
			if s.alive:
				_balance_step(s, dt)
	_check_end()
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


## A torony fordított inga. Minden hatás szöggyorsulás: a gravitáció a dőlés irányába húz,
## a játékos csak nyomatékot ad, a szél és a remegés pedig kibillenti.
func _balance_step(s: Dictionary, dt: float) -> void:
	var k: float = clamp(t / LIMIT, 0.0, 1.0)
	var four: bool = s.nbox >= 4
	var ease_in: float = clamp(t / 1.5, 0.0, 1.0)
	s.in_f = move_toward(s.in_f, float(s.dir), dt * 9.0)
	# a gravitáció eleinte szelídebb, a négydobozos torony pedig nehezebben fogható meg
	var grav: float = lerp(1.7, 3.0, clamp(t / 20.0, 0.0, 1.0)) * (1.12 if four else 1.0)
	var ctrl: float = 2.25 if four else 2.7           # nagyobb tehetetlenség: ugyanaz a tolás kevesebbet gyorsít
	var sens: float = 1.3 if four else 1.0            # a magasabb torony jobban belekap a szélbe
	# folyamatos apró billegés, ami az idővel erősödik
	var noise: float = (sin(t * 1.7 + s.ph0) + sin(t * 2.9 + s.ph1) * 0.7 + sin(t * 4.3 + s.ph2) * 0.4) * (0.08 + 0.3 * k) * (1.25 if four else 1.0) * ease_in
	# remegés: néha megremeg a figura keze, és 1–2 másodpercig rángatja a tornyot
	var tremble := 0.0
	if s.tr_t > 0:
		s.tr_t -= dt
		s.tr_next -= dt
		if s.tr_next <= 0:
			s.tr_next = 0.09
			s.tr_kick = randf_range(-1.0, 1.0) * s.tr_amp * 1.9
		tremble = s.tr_kick + sin(t * 31.0 + s.ph0) * s.tr_amp * 0.6
	elif t >= s.tr_at:
		s.tr_t = randf_range(1.0, 2.0)
		s.tr_amp = [0.45, 0.8, 1.15][mini(2, randi() % 3 + (1 if k > 0.75 and randf() < 0.5 else 0))]
		s.tr_at = t + s.tr_t + randf_range(7.0, 13.0) - 4.0 * k
		if not preview:
			Audio.play("tremble")
	# a kilengő felső dobozok súlya is húzza a tornyot
	var sag := 0.0
	for i in range(1, s.nbox):
		sag += s.phi[i]
	var acc: float = grav * sin(s.th) + ctrl * s.in_f + wind * sens * cos(s.th) * (1.0 + 0.15 * sin(t * 6.1 + s.ph1)) + noise + tremble + 0.9 * sag
	s.om += acc * dt
	s.om *= exp(-0.4 * dt)
	s.th += s.om * dt
	_wobble_step(s, dt)
	# erőlködés hangja, ha nagyon dől
	s.strain_t -= dt
	if abs(s.th) > MAX_TILT * 0.72 and s.strain_t <= 0:
		s.strain_t = 1.4
		Audio.play("strain", randf_range(0.9, 1.2))
	if abs(s.th) >= MAX_TILT:
		_drop(s)


## Másodlagos mozgás: a dobozok rugós-csillapított láncként, késve követik az alattuk lévőt.
## Az alsó doboz a kézzel együtt mozog; fölfelé egyre nagyobb a kilengés.
func _wobble_step(s: Dictionary, dt: float) -> void:
	var four: bool = s.nbox >= 4
	var lag: float = 0.95 if four else 0.85
	var below_acc: float = clamp((s.om - s.om_prev) / dt, -9.0, 9.0)
	s.om_prev = s.om
	for i in range(1, s.nbox):
		var stiff := 62.0 - 7.0 * i
		var rest: float = s.th * (0.15 if four else 0.12)      # megdőlve a felső dobozok még jobban kihajolnak
		var flutter: float = wind * 0.9 * sin(t * 7.0 + i * 1.3 + s.ph2) * i / 3.0
		var a: float = -stiff * (s.phi[i] - rest) - 4.0 * s.phv[i] - lag * below_acc + flutter
		s.phv[i] += a * dt
		s.phi[i] += s.phv[i] * dt
		if abs(s.phi[i]) > 0.24:
			s.phi[i] = clamp(s.phi[i], -0.24, 0.24)
			s.phv[i] *= -0.3
		below_acc = clamp(below_acc + a, -9.0, 9.0)


func _wind_step(dt: float) -> void:
	wind_t -= dt
	if wind_t <= 0 and not over:
		# szakaszonként más az esélye az egyes szélfajtáknak
		var wts: Array = [3, 5, 0, 0, 0]
		if t > 45: wts = [0, 1, 3, 4, 3]
		elif t > 30: wts = [0, 2, 4, 3, 1]
		elif t > 20: wts = [1, 2, 4, 2, 0]
		elif t > 10: wts = [1, 4, 4, 0, 0]
		# a plusz doboz érkezésekor nincs nagy lökés
		if t > EXTRA_AT - 3.0 and t < EXTRA_AT + 2.0:
			wts = [1, 3, 1, 0, 0]
		var sum := 0
		for w in wts:
			sum += w
		var r := randi() % sum
		wind_type = 0
		for i in wts.size():
			r -= wts[i]
			if r < 0:
				wind_type = i
				break
		if randf() < 0.55:
			wind_dir = -wind_dir
		wind_warn = 0.0
		if wind_type >= 3:
			# a nagy lökést előre jelezzük: van idő rákészülni
			wind_warn = 0.9
			wind_t = wind_warn + (randf_range(1.5, 2.3) if wind_type == 3 else randf_range(0.9, 1.3))
			_say("ERŐS SZÉL!", Color("#a5d8ff"), 1.3)
			Audio.play("gust")
		else:
			wind_t = randf_range(2.5, 4.5)
			if wind_type == 2:
				Audio.play("wind")
	var target: float = wind_dir * WIND_MAG[wind_type]
	var rate := 0.7
	if wind_warn > 0:
		wind_warn -= dt
		target = wind_dir * 0.18
	elif wind_type == 3:
		rate = 2.2
	elif wind_type == 4:
		rate = 5.0
	if over:
		target = 0.0
	wind = move_toward(wind, target, rate * dt)
	if abs(wind) > 0.6:
		shake = max(shake, 0.012)


## Teherautó vagy biciklis hajt el közvetlenül a kamera előtt. Csak a kilátást takarja:
## a tornyokhoz nem ér hozzá, és az egyensúlyozás közben sem áll meg.
func _traffic_step(dt: float) -> void:
	if veh.is_empty():
		if over or t < next_traffic or t > LIMIT - 2.5:
			return
		if t > EXTRA_AT - 3.5 and t < EXTRA_AT + 1.5:
			next_traffic = EXTRA_AT + randf_range(1.5, 3.0)
			return
		var is_truck: bool = randf() < (0.3 if last_truck else 0.7)
		last_truck = is_truck
		var d := 1.0 if randf() < 0.5 else -1.0
		if is_truck:
			var x0 := TRUCK_D * 0.7545 + 5.3
			veh = {"truck": true, "dir": d, "x": -d * x0, "end": x0, "v": randf_range(8.5, 10.0), "warn": 0.7, "run": false, "trav": 0.0}
			_say("VIGYÁZZ!", Color("#ffd43b"), 1.1)
			if randf() < 0.65:
				Audio.play("horn")
		else:
			var x0 := BIKE_D * 0.7545 + 1.6
			veh = {"truck": false, "dir": d, "x": -d * x0, "end": x0, "v": randf_range(4.2, 5.2) if randf() < 0.5 else randf_range(7.0, 8.5), "warn": 0.35, "run": false, "trav": 0.0}
			Audio.play("bikebell")
		return
	if veh.warn > 0:
		veh.warn -= dt
		if veh.warn <= 0:
			veh.run = true
			if veh.truck:
				Audio.play("truck")
		return
	veh.x += veh.dir * veh.v * dt
	veh.trav += veh.v * dt
	if veh.truck:
		shake = max(shake, 0.03)
	if veh.x * veh.dir > veh.end:
		veh = {}
		next_traffic = t + randf_range(5.5, 9.0) - 1.5 * clamp(t / LIMIT, 0.0, 1.0)


## Félidőben minden talpon lévő játékos kap egy negyedik dobozt: fentről esik a toronyra.
func _extra_step(_dt: float) -> void:
	if extra_state == 0 and t >= EXTRA_AT - 1.0 and not over:
		extra_state = 1
		_say("PLUSZ AJÁNDÉK!", Color("#ff8fab"), 2.6)
		Audio.play("whoosh")
		for s in pl:
			if not s.alive:
				continue
			var g: Dictionary = W.gift(s.types[3], _gift_w(3), BOX_H)
			add_child(g.node)
			# kis árnyék a torony tetején, ami nő, ahogy közeledik a doboz
			var sh := Chars3D.cyl(s.joints[3], 0.5, 0.5, 0.012, Chars3D.mat("#000000", {"alpha": 0.35, "unshaded": true}), 0, 0.012, 0, 20)
			drops.append({"s": s, "g": g, "shadow": sh})
	if extra_state != 1:
		return
	var k: float = clamp(t - (EXTRA_AT - 1.0), 0.0, 1.0)
	for d in drops:
		var s: Dictionary = d.s
		var node: Node3D = d.g.node
		if not s.alive:
			# közben leborult a torony: a doboz egyszerűen lepottyan
			if d.shadow:
				(d.shadow as Node3D).queue_free()
				d.shadow = null
			if not d.has("lost"):
				d["lost"] = true
				_add_loose(node, Vector3(FX.fr(-1, 1), -3.0, FX.fr(0.3, 1.5)), FX.fr(-4, 4), _gift_w(3))
			continue
		var top: Transform3D = (s.joints[3] as Node3D).global_transform
		node.global_transform = Transform3D(top.basis, top.origin + top.basis.y * (BOX_H / 2) + Vector3(0, 4.6 * (1.0 - k * k), 0))
		(d.shadow as Node3D).scale = Vector3.ONE * (0.25 + 0.75 * k)
	if t >= EXTRA_AT:
		extra_state = 2
		var any := false
		for d in drops:
			var s: Dictionary = d.s
			if not s.alive:
				continue
			any = true
			(d.shadow as Node3D).queue_free()
			_attach_gift(s, 3, d.g)
			s.nbox = 4
			# becsapódás: a torony összenyomódik, megbillen, a dobozok megremegnek
			s.squash = 1.0
			s.surprise = 1.0
			s.om += (1.0 if randf() < 0.5 else -1.0) * randf_range(0.22, 0.36)
			for i in range(1, 4):
				s.phv[i] += randf_range(-1.2, 1.2)
			(s.m as Chars3D.CharModel).land = 1.0
			var q := screen((s.joints[3] as Node3D).global_position)
			Main.I.burst(q.x, q.y, {"n": 16, "colors": ["#ffffff", "#ffd43b", "#ff8fab"], "speed": 260})
			Net.vibrate(s.p.pid, 120)
		drops.clear()
		if any:
			Audio.play("thud")
			shake = max(shake, 0.09)


func _drop(s: Dictionary) -> void:
	s.alive = false
	s.dir = 0
	s.out_time = t
	out_order.append(s)
	var side: float = sign(s.th)
	_release_stack(s, Vector3(side * 1.2, 0.6, 0.0), 1.0)
	Audio.play("crash")
	Audio.play("fail")
	shake = max(shake, 0.12)
	Net.vibrate(s.p.pid, [220, 70, 220])
	var q := screen(Vector3(s.x, HOLD_Y + 0.6, 0))
	Main.I.burst(q.x, q.y, {"n": 26, "colors": ["#ffd43b", "#ffffff", s.p.color_hex], "speed": 340})
	Main.I.float_text(q.x, q.y - 30, "LEEJTETTED!", Color("#ff8787"), 34)
	Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "💥", "title": "Leejtetted!", "text": "%d. kiesett – %.1f mp-ig bírtad. Figyeld a többieket!" % [out_order.size(), t]})
	print_verbose("[mg] ajándéktorony: %s leejtette %.1f mp-nél (%d doboz)" % [s.p.name, t, s.nbox])


## A torony dobozai önálló, szabadon eső tárgyakká válnak.
func _release_stack(s: Dictionary, push: Vector3, tumble: float) -> void:
	var piv: Vector3 = (s.pivot as Node3D).global_position
	for k in s.gifts.size():
		var node: Node3D = s.gifts[k].node
		(s.gifts[k].bow as Node3D).visible = true
		var r := node.global_position - piv
		# a forgó torony pontjainak kerületi sebessége + egy kis szórás
		var v: Vector3 = Vector3(s.om * r.y, -s.om * r.x, 0) + push * (0.5 + k * 0.35) + Vector3(FX.fr(-0.6, 0.6), FX.fr(0.0, 1.2), FX.fr(-0.8, 1.8))
		_add_loose(node, v, -s.om * 1.5 - sign(push.x) * FX.fr(1.0, 4.0) * tumble + FX.fr(-1.5, 1.5), s.gifts[k].w)
	s.gifts.clear()


func _add_loose(node: Node3D, vel: Vector3, angv: float, w: float) -> void:
	var gt := node.global_transform
	if node.get_parent() != self:
		node.get_parent().remove_child(node)
		add_child(node)
	loose.append({"n": node, "pos": gt.origin, "vel": vel, "ang": gt.basis.get_euler().z, "angv": angv,
		"yaw": 0.0, "yawv": FX.fr(-2.5, 2.5), "hw": w / 2, "hh": BOX_H / 2, "rest": false, "hits": 0})


func _check_end() -> void:
	if over:
		if t >= end_at:
			finished = true
		return
	var alive := pl.filter(func(x): return x.alive)
	if (pl.size() > 1 and alive.size() <= 1) or alive.is_empty() or t >= LIMIT:
		over = true
		end_at = t + (2.6 if not alive.is_empty() else 1.7)
		for s in alive:
			# a győztes örömében a magasba dobja a csomagokat
			s.won = true
			s.dir = 0
			_release_stack(s, Vector3(0, 7.5, 0), 0.6)
			(s.m as Chars3D.CharModel).emote("cheer")
		print_verbose("[mg] ajándéktorony vége %.1f mp-nél, talpon: %d" % [t, alive.size()])
		if not alive.is_empty():
			Audio.play("fanfare")
			if not preview:
				Main.I.confetti(140)
			if alive.size() == 1:
				_say("🏆 %s nyert!" % alive[0].p.name, Color("#ffd43b"), 4.0)
			else:
				_say("🎁 Megtartották!", Color("#ffd43b"), 4.0)


func _say(text: String, col: Color, dur: float) -> void:
	msg_text = text
	msg_col = col
	msg_t0 = t
	msg_dur = dur


func ranking() -> Array:
	var out: Array = []
	for s in pl:
		var ei := out_order.find(s)
		out.append({"pid": s.p.pid, "score": 100.0 if s.alive else float(ei),
			"label": "Megtartotta! 🎁" if s.alive else "%.1f mp-ig bírta" % s.out_time})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


# ------------------------------------------------------------------ látvány
func _sync(dt: float) -> void:
	vis_t += dt
	for s in pl:
		_animate_char(s, dt)
	_loose_step(dt)
	_sync_traffic()
	_sync_town(dt)
	# finom kamerarázás (szél, becsapódás, teherautó, leboruló torony)
	shake = max(0.0, shake - dt * 0.22)
	if cam:
		cam.position = cam_base + Vector3(FX.fr(-1, 1), FX.fr(-1, 1), 0) * shake


func _animate_char(s: Dictionary, dt: float) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var pivot: Node3D = s.pivot
	var holding: bool = s.alive and not s.won
	var trem: float = s.tr_amp if (s.tr_t > 0 and holding) else 0.0
	s.fear = lerp(s.fear, clamp(abs(s.th) / MAX_TILT, 0.0, 1.0) if holding else (1.0 if not s.alive else 0.0), min(1.0, dt * 7.0))
	s.squash = max(0.0, s.squash - dt * 2.6)
	s.surprise = max(0.0, s.surprise - dt * 0.9)
	var fear: float = s.fear
	var worried: float = smoothstep(0.28, 0.6, fear)
	var panic: float = smoothstep(0.78, 0.98, fear)
	var busy: float = 0.012 + 0.03 * worried + 0.05 * panic + 0.035 * trem
	var tt: float = m.t
	var jx: float = sin(tt * 37.0 + s.ph0) * busy * 0.6
	var bounce: float = s.squash * cos((1.0 - s.squash) * 11.0)
	if holding:
		# a figura a torony alá lép, a teste a dőlés felé hajlik, a térde megroggyan
		s.hx = lerp(s.hx, clamp(s.th * 0.55, -0.32, 0.32), min(1.0, dt * 8.0))
		var knee: float = 1.0 - 0.05 * fear - 0.035 * abs(sin(tt * 27.0)) * (panic + trem * 0.8) - 0.1 * bounce - 0.02 * sin(tt * 2.3 + s.ph1)
		m.position = Vector3(s.x + s.hx * 0.7 + jx, a.y, 0)
		m.rotation = Vector3(0.0, s.th * 0.5 + sin(tt * 19.0 + s.ph1) * 0.12 * panic, -s.th * 0.4 - s.in_f * 0.07 + sin(tt * 33.0) * 0.03 * (trem + panic))
		m.scale = Vector3(1.0 / sqrt(knee), knee, 1.0 / sqrt(knee)) * BASE_SCALE
		pivot.position = Vector3(s.x + s.hx + jx * 1.6, HOLD_Y - (1.0 - knee) * 1.1 + a.y, 0.12)
		pivot.rotation.z = -s.th
		pivot.scale = Vector3(1.0 + 0.06 * bounce, 1.0 - 0.1 * bounce, 1.0 + 0.06 * bounce)
		for i in range(1, 4):
			var j: Node3D = s.joints[i]
			j.rotation.z = -s.phi[i]
			j.position.x = s.phi[i] * 0.55
	elif s.won:
		m.position = Vector3(s.x, a.y, 0)
		m.rotation = Vector3(0, a.spin, 0)
		m.scale = Vector3.ONE * BASE_SCALE
	else:
		# kiesés: kalimpál, hátratántorodik, majd hanyatt esik
		s.out_t += dt
		var o: float = s.out_t
		var fall: float = clamp((o - 0.5) / 0.4, 0.0, 1.0)
		var hop: float = abs(sin(max(0.0, o - 0.9) * 9.0)) * 0.25 * exp(-max(0.0, o - 0.9) * 4.0)
		m.position = Vector3(s.x + s.hx * 0.7 - sign(s.th) * min(o, 0.5) * 0.5, 0.42 * fall * fall + hop, -min(o, 0.9) * 1.1)
		m.rotation = Vector3(-PI / 2 * fall * fall, sin(o * 21.0) * 0.3 * (1.0 - fall), sin(o * 24.0) * 0.28 * (1.0 - fall))
		m.scale = Vector3.ONE * BASE_SCALE
	_animate_arms(s, holding, busy)
	_animate_face(s, worried, panic, trem)


## Kétcsontos IK: a kezek mindig a legalsó doboz két oldalát fogják, a könyök kifelé hajlik.
func _animate_arms(s: Dictionary, holding: bool, busy: float) -> void:
	var m: Chars3D.CharModel = s.m
	var tt: float = m.t
	var inv := m.global_transform.affine_inverse()
	var piv := (s.pivot as Node3D).global_transform
	var w0 := _gift_w(0)
	for arm in s.arms:
		var side: float = arm.side
		var sh: Vector3 = arm.sh
		var target: Vector3
		if holding:
			var jit := Vector3(sin(tt * 43.0 + side), cos(tt * 39.0 + side * 2.0), 0) * busy * 0.5
			target = inv * (piv * Vector3(side * (w0 / 2 + 0.04), 0.15, 0.0) + jit)
		elif s.won:
			target = sh + Vector3(side * 0.32 + sin(tt * 9.0) * 0.08, 0.72 + sin(tt * 11.0 + side) * 0.1, 0.1)
		else:
			var calm: float = clamp(s.out_t - 1.2, 0.0, 1.0)
			target = sh + Vector3(side * (0.5 + 0.2 * sin(tt * 17.0 + side)), (0.55 + 0.35 * sin(tt * 23.0 + side * 1.7)) * (1.0 - calm) + 0.05 * calm, 0.25)
		var d := target - sh
		var dl: float = clamp(d.length(), 0.08, ARM_L * 2 - 0.004)
		var dir := d.normalized()
		var aa := dl / 2.0
		var hh: float = sqrt(max(0.0, ARM_L * ARM_L - aa * aa))
		var bend := Vector3(side, -0.35, -0.45)
		bend = (bend - dir * bend.dot(dir)).normalized()
		var elbow := sh + dir * aa + bend * hh
		var hand := sh + dir * dl
		W.place_seg(arm.up, sh, elbow)
		W.place_seg(arm.fore, elbow, hand)
		(arm.elbow as Node3D).position = elbow
		(arm.hand as Node3D).position = hand


## Arckifejezés a veszély szerint: nyugodt -> aggódó -> ijedt -> pánik, folyamatos átmenettel.
func _animate_face(s: Dictionary, worried: float, panic: float, trem: float) -> void:
	var m: Chars3D.CharModel = s.m
	var scared: float = smoothstep(0.6, 0.86, s.fear)
	var wide: float = 1.0 + 0.22 * worried + 0.25 * scared + 0.2 * panic + 0.4 * s.surprise
	if not s.alive:
		wide = 1.0 + 0.5 * max(0.0, 1.0 - s.out_t * 0.6)
	for k in m.eyes.size():
		var e: Node3D = m.eyes[k]
		var blinking := e.scale.y < 0.5
		e.scale = Vector3(wide, 0.1 if blinking else wide, wide)
	for k in s.brows.size():
		var b: MeshInstance3D = s.brows[k]
		var side := -1.0 if k == 0 else 1.0
		b.visible = worried > 0.05 or s.surprise > 0.05
		b.position.y = s.eye_r * (1.35 + 0.35 * worried + 0.3 * panic + 0.3 * s.surprise)
		b.rotation.z = -side * (0.42 * worried + 0.2 * panic)
	if s.mouth:
		var mo: MeshInstance3D = s.mouth
		var open: float = max(0.35 * worried + 0.45 * scared + 0.5 * panic, s.surprise)
		if not s.alive:
			open = 1.0
		mo.visible = open > 0.08
		mo.scale = Vector3(0.6 + 0.5 * open, (0.35 + 1.1 * open) * (1.0 + 0.12 * sin(m.t * 30.0) * panic), 0.55)
	# izzadságcseppek pattognak le a fejéről, ha baj van
	var wet: float = max(panic, max(trem * 0.8, scared * 0.6)) if s.alive and not s.won else 0.0
	for k in s.sweat.size():
		var d: MeshInstance3D = s.sweat[k]
		d.visible = wet > 0.25
		if d.visible:
			var f := fposmod(m.t * 1.7 + k * 0.27, 1.0)
			var side := -1.0 if k % 2 == 0 else 1.0
			d.position = Vector3(side * (0.28 + f * 0.3), 0.92 + f * 0.25 - f * f * 0.55 + (k / 2) * 0.08, 0.2)
			d.scale = Vector3.ONE * (1.0 - f) * (0.7 + 0.6 * wet)


## A leesett dobozok saját, olcsó fizikája: zuhannak, pattannak, egymásnak ütköznek, majd a lapjukra billennek.
func _loose_step(dt: float) -> void:
	if dt <= 0.0:
		return
	for b in loose:
		if b.rest:
			continue
		b.vel.y -= 21.0 * dt
		b.pos += b.vel * dt
		b.ang += b.angv * dt
		b.yaw += b.yawv * dt
		var ext: float = abs(sin(b.ang)) * b.hw + abs(cos(b.ang)) * b.hh
		if b.pos.y < ext:
			b.pos.y = ext
			var flat: float = round(b.ang / (PI / 2)) * (PI / 2)
			if b.vel.y < -1.6:
				# pattanás: a sarkára érkező doboz megpördül
				b.vel.y = -b.vel.y * 0.36
				b.vel.x = b.vel.x * 0.72 + (b.ang - flat) * 2.5
				b.vel.z *= 0.72
				b.angv = b.angv * 0.55 + FX.fr(-2.5, 2.5) - b.vel.x * 0.5
				b.yawv *= 0.6
				if b.hits == 0:
					Audio.play("thud", FX.fr(0.9, 1.4))
					var q := screen(b.pos)
					Main.I.burst(q.x, q.y, {"n": 5, "colors": ["#e6d6ad", "#ffffff"], "speed": 120})
				b.hits += 1
			else:
				b.vel.y = 0.0
				b.angv = lerp(b.angv, (flat - b.ang) * 12.0, min(1.0, dt * 10.0))
				b.vel.x = move_toward(b.vel.x, 0.0, dt * 7.0)
				b.vel.z = move_toward(b.vel.z, 0.0, dt * 7.0)
				b.yawv = move_toward(b.yawv, 0.0, dt * 5.0)
				if abs(flat - b.ang) < 0.012 and abs(b.vel.x) < 0.05 and abs(b.angv) < 0.3:
					b.ang = flat
					b.rest = true
	# dobozok egymás között: gömbként tolják szét egymást
	for i in loose.size():
		for j in range(i + 1, loose.size()):
			var a: Dictionary = loose[i]
			var c: Dictionary = loose[j]
			if a.rest and c.rest:
				continue
			var d: Vector3 = c.pos - a.pos
			var need: float = (a.hw + a.hh + c.hw + c.hh) * 0.5 * 0.92
			var dl := d.length()
			if dl >= need or dl < 0.001:
				continue
			var nrm := d / dl
			var push := need - dl
			var rel: float = (c.vel - a.vel).dot(nrm)
			if a.rest:
				c.pos += nrm * push
			elif c.rest:
				a.pos -= nrm * push
			else:
				a.pos -= nrm * push * 0.5
				c.pos += nrm * push * 0.5
			if rel < 0:
				var imp := nrm * rel * 0.7
				if not a.rest: a.vel += imp
				if not c.rest: c.vel -= imp
				a.angv += FX.fr(-1.5, 1.5)
				c.angv += FX.fr(-1.5, 1.5)
	for b in loose:
		var n: Node3D = b.n
		n.position = b.pos
		n.rotation = Vector3(0, b.yaw, b.ang)


func _sync_traffic() -> void:
	var tn: Node3D = truck.node
	var bn: Node3D = bike.node
	var active: bool = not veh.is_empty() and veh.run
	tn.visible = active and veh.truck
	bn.visible = active and not veh.truck
	if not active:
		return
	if veh.truck:
		tn.position = Vector3(veh.x, 0, dist - TRUCK_D)
		tn.rotation.y = 0.0 if veh.dir > 0 else PI
		for w in truck.wheels:
			(w as Node3D).rotation.z = -veh.trav / truck.r
		# a rakomány kicsit rázkódik
		tn.position.y = abs(sin(veh.trav * 2.2)) * 0.03
	else:
		bn.position = Vector3(veh.x, 0, dist - BIKE_D)
		bn.rotation.y = 0.0 if veh.dir > 0 else PI
		W.animate_cyclist(bike, veh.trav / 1.3)


func _sync_town(dt: float) -> void:
	var wv: float = wind
	var str_k: float = clamp(abs(wv) / 0.9, 0.0, 1.0)
	for i in town.flags.size():
		var f: Node3D = town.flags[i]
		f.rotation.z = wv * 0.9 + sin(vis_t * (3.0 + str_k * 9.0) + i * 0.9) * (0.08 + 0.3 * str_k)
		f.rotation.x = sin(vis_t * 2.1 + i) * 0.1
	for i in town.banners.size():
		var b: Node3D = town.banners[i]
		b.rotation.z = wv * 0.45 + sin(vis_t * (1.6 + str_k * 5.0) + i * 1.7) * (0.03 + 0.12 * str_k)
	for i in town.trees.size():
		var tr: Node3D = town.trees[i]
		tr.rotation.z = -wv * 0.16 + sin(vis_t * (1.3 + str_k * 4.0) + i * 2.1) * (0.015 + 0.05 * str_k)
	for c in town.clouds:
		var cn: Node3D = c
		cn.position.x = wrapf(cn.position.x + (0.25 + wv * 1.2) * dt, -55.0, 55.0)
	# falevelek: szélcsendben a földön hevernek, a széllel felkapnak és átrepülnek a téren
	var span := 15.0
	for l in leaves:
		var n: Node3D = l.n
		l.x = wrapf(l.x + wv * 11.0 * l.sp * dt, -span, span)
		var lift: float = clamp(abs(wv) * 2.4, 0.0, 1.0)
		n.position = Vector3(l.x, 0.03 + lift * (l.h + sin(vis_t * 2.6 * l.sp + l.ph) * 0.5), l.z)
		n.rotation = Vector3(vis_t * 5.0 * lift * l.sp + l.ph, l.ph + vis_t * 3.0 * lift, sin(vis_t * 4.0 + l.ph) * lift)
	# szélcsíkok és porfelhők: csak erősebb szélben látszanak
	for st in streaks:
		var n: Node3D = st.n
		var need: float = 0.25 if st.dust else 0.4
		n.visible = abs(wv) > need
		if not n.visible:
			continue
		st.x = wrapf(st.x + wv * (16.0 if st.dust else 34.0) * st.sp * dt, -span, span)
		n.position = Vector3(st.x, st.y, st.z)
		if st.dust:
			n.scale = Vector3(1.6, 0.6, 1.0) * (0.6 + str_k)
		else:
			n.scale = Vector3(0.8 + str_k * 2.2, 1, 1)


# ------------------------------------------------------------------ HUD
func draw(c: CanvasItem) -> void:
	for s in pl:
		_draw_gauge(c, s)
	_draw_timer(c)
	_draw_wind(c)
	# nagy, beúszó üzenet
	var mk := t - msg_t0
	if msg_text != "" and mk >= 0 and mk < msg_dur:
		var sc := D.ease_out_back(min(1.0, mk * 4.5)) * (1.0 + sin(mk * 9.0) * 0.03)
		var alpha: float = clamp((msg_dur - mk) / 0.3, 0.0, 1.0)
		c.draw_set_transform(Vector2(640, 196), sin(mk * 7.0) * 0.02, Vector2(sc, sc))
		D.text(c, msg_text, 0, 0, {"size": 76, "color": msg_col, "stroke": D.DARK, "sw": 14, "alpha": alpha, "maxw": 1100})
		c.draw_set_transform(Vector2.ZERO)


## Kék-fehér, fényes óra a képernyő tetején.
func _draw_timer(c: CanvasItem) -> void:
	var r: float = max(0.0, LIMIT - t)
	var low := r <= 10.0 and not over
	var pulse: float = 1.0 + (0.06 * abs(sin(t * 6.0)) if low else 0.0)
	c.draw_set_transform(Vector2(640, 46), 0, Vector2(pulse, pulse))
	D.panel(c, -96, -32, 192, 64, {"r": 32, "fill": Color("#ffffff"), "stroke": null})
	D.panel(c, -90, -26, 180, 52, {"r": 26, "fill": Color("#e03131") if low else Color("#1c6ee8"), "stroke": null, "shadow": false})
	D.panel(c, -82, -22, 164, 20, {"r": 10, "fill": Color(1, 1, 1, 0.26), "stroke": null, "shadow": false})
	D.emoji(c, "⏱", -52, 0, 34)
	D.text(c, "%d" % ceili(r), 26, 1, {"size": 40, "stroke": Color("#7a1010") if low else Color("#0b2f7a"), "sw": 7})
	c.draw_set_transform(Vector2.ZERO)


## Szélirány-jelző: minél erősebb a szél, annál több és annál pirosabb a nyíl.
func _draw_wind(c: CanvasItem) -> void:
	var lvl := 0
	var aw: float = abs(wind)
	if aw > 0.85: lvl = 4
	elif aw > 0.55: lvl = 3
	elif aw > 0.3: lvl = 2
	elif aw > 0.08: lvl = 1
	var warn := wind_warn > 0
	var dir: float = wind_dir if warn else sign(wind)
	var col: Color = [Color("#adb5bd"), Color("#ffffff"), Color("#ffe066"), Color("#ff922b"), Color("#ff4d4d")][lvl]
	var blink := warn and fmod(t, 0.24) < 0.12
	D.panel(c, 520, 88, 240, 40, {"r": 20, "fill": Color(0.75, 0.1, 0.1, 0.9) if blink else Color(0.05, 0.12, 0.3, 0.82), "stroke": Color(1, 1, 1, 0.5), "lw": 2.0})
	D.emoji(c, "💨", 546, 108, 22)
	D.text(c, "Jön a lökés!" if warn else WIND_NAME[lvl], 566, 108, {"size": 16, "align": "left", "color": col, "maxw": 96})
	var n: int = 4 if warn else lvl
	for i in n:
		var cx := 712.0 + (i - (n - 1) / 2.0) * 17.0 * dir
		var slide := fmod(t * 2.0, 1.0) * 5.0 * dir
		var x := cx + slide
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6 * dir, 98), Vector2(x + 7 * dir, 108), Vector2(x - 6 * dir, 118)]), Color("#ff4d4d") if warn else col)
	if n == 0:
		D.text(c, "–", 712, 108, {"size": 20, "color": col})


## Egyensúlyjelző a figura alatt: zöld biztos sáv, sárga figyelmeztető, piros veszélyzóna, mozgó mutatóval.
func _draw_gauge(c: CanvasItem, s: Dictionary) -> void:
	var n := pl.size()
	var w: float = clamp(1180.0 / n - 10.0, 120.0, 190.0)
	var gx: float = clamp(screen(Vector3(s.x, 0, 0)).x, w / 2 + 6, 1274 - w / 2)
	var p = s.p
	var deg: float = abs(rad_to_deg(s.th))
	var stage := 0
	if deg >= 25: stage = 3
	elif deg >= 20: stage = 2
	elif deg >= 10: stage = 1
	var danger: bool = s.alive and not s.won and stage == 3
	var flash := danger and fmod(t, 0.3) < 0.15
	D.panel(c, gx - w / 2, 634, w, 78, {"r": 16, "fill": Color(0.45, 0.05, 0.08, 0.92) if flash else Color(0.07, 0.05, 0.18, 0.85), "stroke": Color("#ff4d4d") if danger else p.color})
	D.avatar(c, p, gx - w / 2 + 22, 655, 14, {"shadow": false, "gray": not s.alive})
	D.text(c, ("[A/D] " if s.kb else "") + p.name, gx - w / 2 + 42, 654, {"size": 15, "align": "left", "maxw": w - 82})
	if not s.alive:
		D.emoji(c, "😵", gx + w / 2 - 20, 655, 22)
		D.text(c, "💥 %d. kiesett" % (out_order.find(s) + 1), gx, 688, {"size": 17, "color": Color("#ffa8a8"), "maxw": w - 16})
		return
	if s.won:
		D.emoji(c, "🥳", gx + w / 2 - 20, 655, 22)
		D.text(c, "Megtartotta!", gx, 688, {"size": 17, "color": Color("#ffe066"), "maxw": w - 16})
		return
	# a teherautó a jelzőt is kitakarja: amíg előtted halad, vakon kell egyensúlyozni
	if not veh.is_empty() and veh.truck and veh.run:
		var tz := dist - TRUCK_D
		var xa := screen(Vector3(veh.x - 5.0, 1.5, tz)).x
		var xb := screen(Vector3(veh.x + 5.0, 1.5, tz)).x
		if gx > min(xa, xb) and gx < max(xa, xb):
			D.emoji(c, "🚚", gx + w / 2 - 20, 655, 22)
			D.text(c, "? ? ?", gx, 688, {"size": 20, "color": Color("#adb5bd")})
			return
	D.emoji(c, FACES[stage], gx + w / 2 - 20, 655, 22)
	var half := w / 2 - 12
	var by := 679.0
	c.draw_rect(Rect2(gx - half - 2, by - 2, half * 2 + 4, 20), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(gx - half, by, half * 2, 16), Color("#e03131"))
	c.draw_rect(Rect2(gx - half * 5 / 6, by, half * 10 / 6, 16), Color("#ff922b"))
	c.draw_rect(Rect2(gx - half * 2 / 3, by, half * 4 / 3, 16), Color("#ffd43b"))
	c.draw_rect(Rect2(gx - half / 3, by, half * 2 / 3, 16), Color("#40c057"))
	c.draw_rect(Rect2(gx - 1, by, 2, 16), Color(1, 1, 1, 0.6))
	var px: float = gx + clamp(s.th / MAX_TILT, -1.0, 1.0) * half
	c.draw_colored_polygon(PackedVector2Array([Vector2(px - 9, by - 8), Vector2(px + 9, by - 8), Vector2(px, by + 6)]), D.DARK)
	c.draw_colored_polygon(PackedVector2Array([Vector2(px - 6, by - 7), Vector2(px + 6, by - 7), Vector2(px, by + 3)]), Color.WHITE)
	c.draw_rect(Rect2(px - 1.5, by + 2, 3, 16), Color.WHITE)
	if s.nbox >= 4:
		D.text(c, "×4", gx + w / 2 - 44, 655, {"size": 13, "color": Color("#ff8fab")})
	if danger and fmod(t, 0.3) < 0.2:
		D.text(c, "VESZÉLY!", gx, 618, {"size": 24, "color": Color("#ff4d4d"), "stroke": Color.WHITE, "sw": 6})
	elif s.tr_t > 0:
		var h := screen(Vector3(s.x, 1.2, 0.5))
		D.emoji(c, "💦", h.x + 56, h.y, 30)
