extends Minigame
## Vakondvadász (3D) – kerítéses, türkiz tér 3×3 lyukkal. Fuss oda a felbukkanó vakondhoz, és csapj le rá
## az óriási, felfújható játékkalapácsoddal! Barna vakond +1, arany vakond +3 pont, 30 másodpercig.
## A kalapács a többi játékost is eltalálhatja: akit fejbe kólintanak, rövid időre elkábul.
## Négynél kevesebb játékosnál gépi ellenfelek töltik fel a helyeket; négynél többel (max. 8) mindenki játszik.
##
## Felépítés: beállítások (konstansok) · felépítés · bemenet · szimuláció (mozgás, kalapács, vakondok,
## ütemezés) · gépi játékos · látvány (_sync) · felület (draw). A díszlet és a modellek a mole_world.gd-ben.

const K = preload("res://scripts/minigames/mg_kit.gd")
const MW = preload("res://scripts/minigames/mole_world.gd")

# ------------------------------------------------------------------ beállítások
const TIME := 30.0                 # a kör hossza (mp)
const SCORE_NORMAL := 1
const SCORE_GOLD := 3
const GOLD_CHANCE := 0.11          # egy új vakond ekkora eséllyel arany
const GOLD_MAX := 1                # egyszerre legfeljebb ennyi arany vakond
const GOLD_LIFE_K := 0.8           # az arany vakond ennyiszer rövidebb ideig marad kint
const GOLD_FROM := 2.5             # az első pár másodpercben nincs arany vakond
## nehézségi szakaszok: [kezdet (mp), min. aktív, max. aktív, köz min, köz max, élettartam min, élettartam max]
const WAVES := [
	[0.0, 1, 2, 0.9, 1.3, 1.5, 2.0],
	[5.0, 2, 3, 0.6, 0.95, 1.3, 1.8],
	[15.0, 3, 4, 0.4, 0.7, 1.0, 1.5],
	[23.0, 4, 5, 0.25, 0.42, 0.85, 1.3],
	[25.0, 4, 6, 0.14, 0.28, 0.8, 1.1],    # utolsó 5 mp: káosz
]
const SPAWN_GAP := 0.12            # két megjelenés között legalább ennyi idő
const URGENT_AT := 5.0             # ennyi mp-nél pirosodik az óra

const SPEED := 4.4                 # futási sebesség (egység/mp)
const ACCEL := 22.0                # mennyire gyorsan áll be a sebesség (1/mp)
const SWING_MOVE_K := 0.3          # lecsapás közben ennyiszeres a sebesség
const BODY_R := 0.4                # a figurák ütközési sugara
const SWING_CD := 0.5              # két lecsapás között legalább ennyi idő
const HIT_R := 0.6                 # a kalapácsfej ütési körének sugara vakondra
const HIT_R_PLAYER := 0.55         # … és játékosra
const STUN := 1.5                  # kábulás hossza
const STUN_SAFE := 1.2             # kábulás után ennyi ideig nem lehet újra elkábítani
const KNOCK := 5.0                 # hátralökés kezdősebessége

const AI_REACT := [0.55, 0.32, 0.16]    # gépi reakcióidő (könnyű, közepes, nehéz)
const AI_MISS := [0.22, 0.1, 0.03]      # mekkora eséllyel csap mellé
const AI_AIM := [0.35, 0.2, 0.08]       # a beállási pont szórása
const AI_BULLY := [0.0, 0.5, 0.9]       # mennyire szívesen kólint fejbe másokat (mp-enkénti esély, ha van kéznél)
const AI_SPEED := [0.82, 0.92, 1.0]     # a futási sebesség ennyiszerese

# tér
const HALF := 4.6                  # a padló fél oldalhossza
const HOLE_GAP := 2.7              # a lyukak távolsága
const SC := 1.05                   # a figurák mérete

# vakond idővonala
const OPEN_T := 0.18               # fedél nyílása
const RISE_T := 0.16               # kibújás
const DOWN_T := 0.2                # visszabújás
const CLOSE_T := 0.18              # fedél zárása
const SQUASH_T := 0.14             # ütés utáni lapulás
const SINK_T := 0.2                # ütés utáni elsüllyedés
const MOLE_DOWN_Y := -0.82         # a vakond magassága lent

# kalapácslendítés idővonala (mp a lendítés kezdetétől)
const SW_UP := 0.13                # felemelés vége
const SW_HIT := 0.2                # becsapódás
const SW_ACT0 := 0.17              # az ütőfelület ettől…
const SW_ACT1 := 0.25              # …eddig él
const SW_REB := 0.28               # visszapattanás vége
const SW_END := 0.46               # visszaáll alapállásba
const HL := 0.8                    # a fogástól a kalapácsfej közepéig (figura-egységben)
# testtartások: [nyél szöge (0 = felfelé, + = előre), fogás helye a figura terében, dőlés előre, összenyomás]
const P_READY := [0.32, Vector3(0, 0.5, 0.3), 0.0, 1.0]
const P_UP := [-0.8, Vector3(0, 0.84, 0.06), -0.24, 1.04]
const P_HIT := [1.8, Vector3(0, 0.62, 0.4), 0.3, 0.86]
const P_REB := [1.38, Vector3(0, 0.62, 0.38), 0.18, 0.95]

const SLOT_COLORS := ["#2f80ff", "#f03e3e", "#2fb344", "#ff8c1a", "#9b5de5", "#13b5c8", "#f0609e", "#d9a400"]

var pl: Array = []                 # játékosok (gépiekkel együtt), lásd _ready
var holes: Array = []              # látvány: MW.build_hole eredménye
var moles: Array = []              # [{h, gold, t0, life, state ("up"/"hit"), ts, by}]
var next_spawn := 0.35
var last_spawn := -10.0
var last_hole := -1
var near_cnt: Array = []           # hányszor jelent meg vakond az egyes játékosok közelében
var frame := 0
var last_beep := 99
var pops: Array = []               # lebegő pontfeliratok [{x, z, text, col, gold, t0}]
var places := {}                   # slot index -> helyezés (a kör végén)
var post := 0.0                    # a kör vége óta eltelt idő (csak látvány)
var stats := {"spawn": 0, "gold": 0, "hits": 0, "stuns": 0, "max_active": 0, "late_spawn": 0}


func meta() -> Dictionary:
	return {"id": "mole", "name": "Vakondvadász", "icon": "🔨", "color": "#a16207", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Kalapácsot fel, vakondot le!",
		"desc": "Kilenc lyuk, egy csomó szemtelen vakond és egy óriási felfújható kalapács. Fuss oda, ahol kibújt egy vakond, és csapj le rá, mielőtt visszabújik! Barna vakond +1, arany vakond +3 pont. Vigyázz: a kalapács a többieket is eltalálja – akit fejbe kólintanak, egy pillanatra elkábul. A végén egyre több vakond bújik elő!",
		"controls": "Bal oldalon a joystickkal futsz, a 🔨 ÜTÉS gombbal lecsapsz maga elé. Gépen: WASD / nyilak és a szóköz."}


func layout(_p) -> Dictionary:
	return {"mode": "stick", "btn": "🔨 ÜTÉS"}


func keyboard_stick() -> bool:
	return true


# ------------------------------------------------------------------ felépítés
func _ready() -> void:
	make_env("#3f8fe6", "#d6f1ff", 0.95)
	env.ssao_enabled = false
	make_camera(Vector3(0, 12.6, 8.7), Vector3(0, 0, 0.55), 43)
	var sun := make_sun(Vector3(-62, -24, 0), 1.3, "#fff6e6")
	sun.shadow_blur = 2.0
	MW.build_arena(self, HALF)
	for h in 9:
		holes.append(MW.build_hole(self, _hole_pos(h)))
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
		var col := Color(SLOT_COLORS[i % SLOT_COLORS.size()])
		var st := _start_pos(i, n)
		var s := {"p": p, "cpu": cpu, "i": i, "col": col, "lvl": lvl, "kb_t": -10.0,
			"x": st.x, "z": st.y, "vx": 0.0, "vz": 0.0, "kx": 0.0, "kz": 0.0, "ix": 0.0, "iz": 0.0,
			"yaw": atan2(-st.x, -st.y), "sw_t0": -10.0, "sw_dir": Vector2.ZERO, "sw_hit": false, "sw_ground": false,
			"stun_until": -10.0, "safe_until": -10.0, "stun_t0": -10.0, "stun_shown": false,
			"score": 0, "golds": 0, "bonks": 0, "pop_t": -10.0,
			"tgt": -1, "react_at": 0.0, "aim": Vector2.ZERO, "miss_until": -10.0,
			"home": st, "run_ph": 0.0}
		_build_player(s)
		pl.append(s)
		near_cnt.append(0)
	_sync(0.0)


func _hole_pos(h: int) -> Vector3:
	return Vector3((h % 3 - 1) * HOLE_GAP, 0, (h / 3 - 1) * HOLE_GAP)


func _start_pos(i: int, n: int) -> Vector2:
	if n <= 4:
		var c := [Vector2(-1.35, -1.35), Vector2(1.35, -1.35), Vector2(-1.35, 1.35), Vector2(1.35, 1.35)]
		return c[i]
	var a := -PI * 0.75 + TAU * i / n
	return Vector2(cos(a), sin(a)) * 3.4


func _build_player(s: Dictionary) -> void:
	var m := player_model(s.p, SC)
	var col: Color = s.col
	s.m = m
	s.hammer = MW.build_hammer(m, col.to_html(false), HL)
	s.arms = K.build_arms(m, col.darkened(0.1).to_html(false), 0.5)
	s.face = K.build_face(m)
	var stars: Array = []
	for k in 3:
		var st := Chars3D.sphere(m, 0.075, Chars3D.mat("#ffe066", {"emit": "#ffd43b", "emit_e": 1.6}))
		st.visible = false
		stars.append(st)
	s.stars = stars
	# színes korong a figura alatt (csapatjátékban a csapat színe)
	var disc := MeshInstance3D.new()
	disc.mesh = Chars3D.torus(0.44, 0.05)
	var tix := team_of(s.p)
	var dc: Color = MgFlow.TEAM_COLORS[tix] if tix >= 0 else col
	disc.material_override = Chars3D.mat(dc.to_html(false), {"rough": 0.4, "emit": dc.to_html(false), "emit_e": 0.5})
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	s.disc = disc


func _slot(p) -> Dictionary:
	for s in pl:
		if s.p == p:
			return s
	return {}


func _ally(a: Dictionary, b: Dictionary) -> bool:
	if teams.is_empty():
		return false
	var ta := team_of(a.p)
	return ta >= 0 and ta == team_of(b.p)


# ------------------------------------------------------------------ bemenet
func input(p, msg: Dictionary) -> void:
	var s := _slot(p)
	if s.is_empty() or finished:
		return
	if msg.get("kb", false):
		s.kb_t = t
	match msg.get("t"):
		"stick":
			s.ix = clamp(float(msg.get("x", 0)), -1.0, 1.0)
			s.iz = clamp(float(msg.get("y", 0)), -1.0, 1.0)
		"btn":
			_swing(s)


func bot(p, dt: float) -> void:
	var s := _slot(p)
	# akit épp a billentyűzetről irányítanak, azt a gép nem veszi át
	if s.is_empty() or t - float(s.kb_t) < 3.0:
		return
	_ai(s, dt)


func _swing(s: Dictionary) -> void:
	if finished or t < float(s.stun_until) or t - float(s.sw_t0) < SWING_CD:
		return
	var want := Vector2(s.ix, s.iz)
	if want.length() > 0.3:
		s.yaw = atan2(want.x, want.y)
	s.sw_t0 = t
	s.sw_dir = Vector2(sin(s.yaw), cos(s.yaw))
	s.sw_hit = false
	s.sw_ground = false
	Audio.play("whoosh", 1.25)


# ------------------------------------------------------------------ szimuláció
func update(dt: float) -> void:
	if finished:
		return
	if t >= TIME:
		_finish()
		return
	frame += 1
	for s in pl:
		if s.cpu:
			_ai(s, dt)
	_spawn_step()
	for s in pl:
		_move(s, dt)
	_collide()
	# az ütéseket minden képkockán más játékostól kezdve bíráljuk el, így az egyidejű csapásoknál senki sem előnyös
	var n := pl.size()
	for k in n:
		_swing_step(pl[(k + frame) % n])
	_mole_step()
	for s in pl:
		if s.stun_shown and t >= float(s.stun_until):
			s.stun_shown = false
			Net.set_ctrl(s.p.pid, layout(s.p))
	var rem := ceili(TIME - t)
	if rem <= int(URGENT_AT) and rem != last_beep:
		last_beep = rem
		Audio.play("tick", 1.5 + (5 - rem) * 0.08)
		if rem == int(URGENT_AT):
			Audio.play("bell")
	var keep: Array = []
	for q in pops:
		if t - float(q.t0) < 1.1:
			keep.append(q)
	pops = keep
	_sync(dt)


func idle(dt: float) -> void:
	if finished:
		post += dt
	_sync(dt)


func _swinging(s: Dictionary) -> bool:
	var k: float = t - float(s.sw_t0)
	return k >= 0.0 and k < SW_END


func _move(s: Dictionary, dt: float) -> void:
	var stunned: bool = t < float(s.stun_until)
	var want := Vector2.ZERO
	if not stunned:
		want = Vector2(s.ix, s.iz).limit_length(1.0)
		if want.length() < 0.12:
			want = Vector2.ZERO
	var sp := SPEED * (SWING_MOVE_K if _swinging(s) else 1.0)
	if s.cpu or s.p.is_bot:
		sp *= AI_SPEED[s.lvl]
	var k: float = min(1.0, ACCEL * dt)
	s.vx = lerpf(s.vx, want.x * sp, k)
	s.vz = lerpf(s.vz, want.y * sp, k)
	s.x += (s.vx + s.kx) * dt
	s.z += (s.vz + s.kz) * dt
	var fr := pow(0.015, dt)
	s.kx *= fr
	s.kz *= fr
	if not stunned and not _swinging(s) and want.length() > 0.2:
		s.yaw = lerp_angle(s.yaw, atan2(want.x, want.y), min(1.0, dt * 16.0))
	var lim := HALF - BODY_R
	s.x = clamp(s.x, -lim, lim)
	s.z = clamp(s.z, -lim, lim)


## A figurák szétnyomják egymást (nem ragadnak össze).
func _collide() -> void:
	for i in pl.size():
		for j in range(i + 1, pl.size()):
			var a: Dictionary = pl[i]
			var b: Dictionary = pl[j]
			var d := Vector2(a.x - b.x, a.z - b.z)
			var l := d.length()
			if l >= BODY_R * 2.0:
				continue
			var nv := d / l if l > 0.0001 else Vector2(1, 0).rotated(float(i + j))
			var ov := (BODY_R * 2.0 - l) * 0.5
			a.x += nv.x * ov
			a.z += nv.y * ov
			b.x -= nv.x * ov
			b.z -= nv.y * ov
	var lim := HALF - BODY_R
	for s in pl:
		s.x = clamp(s.x, -lim, lim)
		s.z = clamp(s.z, -lim, lim)


## Testtartás a lendítés k-adik másodpercében: [nyélszög, fogás helye, dőlés, összenyomás]
static func _pose(k: float) -> Array:
	if k < 0.0 or k >= SW_END:
		return P_READY
	if k < SW_UP:
		return _mix(P_READY, P_UP, D.ease_out_cubic(k / SW_UP))
	if k < SW_HIT:
		var u := (k - SW_UP) / (SW_HIT - SW_UP)
		return _mix(P_UP, P_HIT, u * u)
	if k < SW_REB:
		return _mix(P_HIT, P_REB, D.ease_out_cubic((k - SW_HIT) / (SW_REB - SW_HIT)))
	return _mix(P_REB, P_READY, D.ease_in_out((k - SW_REB) / (SW_END - SW_REB)))


static func _mix(a: Array, b: Array, u: float) -> Array:
	return [lerpf(a[0], b[0], u), (a[1] as Vector3).lerp(b[1], u), lerpf(a[2], b[2], u), lerpf(a[3], b[3], u)]


## A kalapácsfej közepe a világban a lendítés k-adik másodpercében (a figura helyéhez és irányához képest).
func _head_world(s: Dictionary, k: float) -> Vector3:
	var ps := _pose(k)
	var a: float = ps[0]
	var piv: Vector3 = ps[1]
	var loc := piv + Vector3(0, cos(a), sin(a)) * HL
	var dir: Vector2 = s.sw_dir
	return Vector3(s.x + dir.x * loc.z * SC, loc.y * SC, s.z + dir.y * loc.z * SC)


## A kalapácsfej ütőfelülete csak a becsapódás körüli rövid ablakban él.
func _swing_step(s: Dictionary) -> void:
	var k: float = t - float(s.sw_t0)
	if k < SW_ACT0 or k > SW_ACT1 or t < float(s.stun_until):
		return
	var hd := _head_world(s, k)
	if hd.y < 0.85:
		var hp := Vector2(hd.x, hd.z)
		if not s.sw_hit:
			for m in moles:
				if not _hittable(m):
					continue
				var hv := _hole_pos(m.h)
				if hp.distance_to(Vector2(hv.x, hv.z)) < HIT_R:
					_hit_mole(s, m)
					s.sw_hit = true
					break
		for o in pl:
			if o == s or _ally(s, o) or t < float(o.stun_until) or t < float(o.safe_until):
				continue
			if hp.distance_to(Vector2(o.x, o.z)) < HIT_R_PLAYER:
				_stun(o, s)
	if k >= SW_HIT and not s.sw_ground:
		s.sw_ground = true
		if not s.sw_hit:
			Audio.play("thud", 1.3)
			var q := screen(Vector3(hd.x, 0.05, hd.z))
			Main.I.burst(q.x, q.y, {"n": 10, "colors": ["#ffffff", "#c9fff6", "#8ff0e6"], "speed": 170, "gravity": 300, "life": 0.4, "size": 6})


func _hittable(m: Dictionary) -> bool:
	if m.state != "up":
		return false
	var e: float = t - float(m.t0)
	return e >= OPEN_T + RISE_T * 0.35 and e < OPEN_T + RISE_T + float(m.life)


func _hit_mole(s: Dictionary, m: Dictionary) -> void:
	assert(m.state == "up")
	m.state = "hit"
	stats.hits += 1
	m.ts = t
	m.by = s.i
	var gold: bool = m.gold
	var pts := SCORE_GOLD if gold else SCORE_NORMAL
	s.score += pts
	s.golds += 1 if gold else 0
	s.pop_t = t
	var hv := _hole_pos(m.h)
	pops.append({"x": hv.x, "z": hv.z, "text": "+%d" % pts, "col": s.col, "gold": gold, "t0": t})
	if not s.cpu:
		if gold:
			Net.vibrate(s.p.pid, [60, 40, 90])
		else:
			Net.vibrate(s.p.pid, 60)
	var q := screen(hv + Vector3(0, 0.4, 0))
	Audio.play("hit")
	if gold:
		Audio.play("coin")
		Audio.play("sparkle")
		Main.I.burst(q.x, q.y, {"n": 46, "colors": ["#ffd43b", "#fff3b0", "#ffffff", (s.col as Color).to_html(false)], "speed": 430, "life": 0.9})
	else:
		Audio.play("pop", 1.5)
		Main.I.burst(q.x, q.y, {"n": 20, "colors": ["#8a5a34", "#d8a777", "#ffffff", (s.col as Color).to_html(false)], "speed": 300, "life": 0.6})


func _stun(o: Dictionary, by: Dictionary) -> void:
	o.stun_until = t + STUN
	o.safe_until = t + STUN + STUN_SAFE
	o.stun_t0 = t
	o.sw_t0 = -10.0
	o.tgt = -1
	var d := Vector2(o.x - by.x, o.z - by.z)
	if d.length() < 0.01:
		d = by.sw_dir
	d = d.normalized() * KNOCK
	o.kx = d.x
	o.kz = d.y
	by.bonks += 1
	stats.stuns += 1
	Audio.play("clank")
	Audio.play("boom", 1.4)
	var q := screen(Vector3(o.x, 1.0, o.z))
	Main.I.burst(q.x, q.y, {"n": 18, "colors": ["#ffe066", "#ffffff", (by.col as Color).to_html(false)], "speed": 280, "gravity": 0, "life": 0.5, "shape": "rect"})
	(o.m as Chars3D.CharModel).emote("dizzy")
	if not o.cpu:
		o.stun_shown = true
		Net.vibrate(o.p.pid, [120, 60, 120])
		Net.set_ctrl(o.p.pid, {"mode": "wait", "icon": "💫", "title": "Elkábultál!", "text": "%s fejbe kólintott…" % by.p.name})


# ------------------------------------------------------------------ vakondok
func _mole_step() -> void:
	var keep: Array = []
	for m in moles:
		var done: float
		if m.state == "hit":
			done = float(m.ts) + SQUASH_T + SINK_T + CLOSE_T
		else:
			done = float(m.t0) + OPEN_T + RISE_T + float(m.life) + DOWN_T + CLOSE_T
		if t < done:
			keep.append(m)
	moles = keep


func _wave() -> Array:
	var w: Array = WAVES[0]
	for x in WAVES:
		if t >= float(x[0]):
			w = x
	return w


func _spawn_step() -> void:
	var w := _wave()
	if t - last_spawn < SPAWN_GAP:
		return
	var cnt := moles.size()
	if cnt >= int(w[2]):
		return
	if t < next_spawn and cnt >= int(w[1]):
		return
	if _spawn(w):
		last_spawn = t
		next_spawn = t + randf_range(w[3], w[4])


## Új vakond egy szabad lyukba. Igazságos véletlen: a nemrég használt lyuk és azok a lyukak, amelyekhez
## közel álló játékos már sok vakondot „kapott”, kisebb eséllyel jönnek.
func _spawn(w: Array) -> bool:
	var used := {}
	var golds := 0
	for m in moles:
		used[m.h] = true
		if m.gold:
			golds += 1
	var free: Array = []
	var weights: Array = []
	var min_cnt := 1 << 30
	for c in near_cnt:
		min_cnt = mini(min_cnt, c)
	var total := 0.0
	for h in 9:
		if used.has(h):
			continue
		var wt: float = 1.0 / (1.0 + 0.6 * float(int(near_cnt[_nearest(h)]) - min_cnt))
		if h == last_hole:
			wt *= 0.25
		free.append(h)
		weights.append(wt)
		total += wt
	if free.is_empty():
		return false
	var r := randf() * total
	var pick: int = free[free.size() - 1]
	for i in free.size():
		r -= weights[i]
		if r <= 0.0:
			pick = free[i]
			break
	var gold := t >= GOLD_FROM and golds < GOLD_MAX and randf() < GOLD_CHANCE
	var life := randf_range(w[5], w[6]) * (GOLD_LIFE_K if gold else 1.0)
	moles.append({"h": pick, "gold": gold, "t0": t, "life": life, "state": "up", "ts": 0.0, "by": -1})
	last_hole = pick
	stats.spawn += 1
	stats.gold += 1 if gold else 0
	stats.max_active = maxi(stats.max_active, moles.size())
	if t >= 25.0:
		stats.late_spawn += 1
	near_cnt[_nearest(pick)] += 1
	if gold:
		Audio.play("sparkle", 1.2)
	else:
		Audio.play("pop", 0.8)
	return true


func _nearest(h: int) -> int:
	var hv := _hole_pos(h)
	var best := 0
	var bd := 1e9
	for s in pl:
		var d := Vector2(s.x - hv.x, s.z - hv.z).length_squared()
		if d < bd:
			bd = d
			best = s.i
	return best


func _mole_at(h: int) -> Dictionary:
	for m in moles:
		if m.h == h:
			return m
	return {}


func _finish() -> void:
	finished = true
	for s in pl:
		s.ix = 0.0
		s.iz = 0.0
		s.vx = 0.0
		s.vz = 0.0
	# a kint lévő vakondok visszabújnak (az idejüket a mostani pillanatra vágjuk)
	for m in moles:
		if m.state == "up":
			m.life = min(float(m.life), max(0.0, t - float(m.t0) - OPEN_T - RISE_T))
	var order := pl.duplicate()
	order.sort_custom(func(a, b): return a.score > b.score)
	for k in order.size():
		var s: Dictionary = order[k]
		# holtversenyben azonos helyezés (a végső sorrendet a minijáték-keret holtverseny-dobása dönti el)
		if k > 0 and s.score == order[k - 1].score:
			places[s.i] = places[order[k - 1].i]
		else:
			places[s.i] = k
	var sc := []
	for s in pl:
		sc.append("%s=%d(%dg,p%d)" % [s.p.name, s.score, s.golds, places[s.i] + 1])
	print_verbose("[mole] vége t=%.1f %s stat=%s" % [t, " ".join(sc), str(stats)])
	for s in pl:
		var cm: Chars3D.CharModel = s.m
		cm.emote("cheer" if places[s.i] == 0 else ("sad" if places[s.i] == pl.size() - 1 or s.score == 0 else ""))


func ranking() -> Array:
	var out: Array = []
	for s in pl:
		if s.cpu:
			continue
		var lab := "%d pont" % s.score
		if s.golds > 0:
			lab += " · %d arany" % s.golds
		out.append({"pid": s.p.pid, "score": float(s.score), "label": lab})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


# ------------------------------------------------------------------ gépi játékos
## Ugyanazzal a mozgással és ütéssel dolgozik, mint az ember: odafut, beáll, lecsap.
func _ai(s: Dictionary, dt: float) -> void:
	if t < float(s.stun_until):
		s.ix = 0.0
		s.iz = 0.0
		return
	var lvl: int = s.lvl
	var me := Vector2(s.x, s.z)
	var reach := _reach()
	# a cél elveszett (leütötték, visszabújt, vagy már nem érünk oda)
	if s.tgt >= 0:
		var m := _mole_at(s.tgt)
		if m.is_empty() or m.state != "up" or _remain(m) < 0.05:
			s.tgt = -1
			s.react_at = t + AI_REACT[lvl] * randf_range(0.7, 1.3)
	if s.tgt < 0 and t >= float(s.react_at):
		s.tgt = _choose(s)
		s.aim = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * AI_AIM[lvl]
		if s.tgt < 0:
			s.react_at = t + 0.12
	if s.tgt < 0:
		# nincs cél: visszaballag a saját környékére (így nem tömörül mindenki egy helyre),
		# és ha valaki kéznél van, megkólintja
		var home: Vector2 = s.home
		var c := home - me
		var v := c.limit_length(1.0) * (0.5 if c.length() > 0.7 else 0.0)
		s.ix = v.x
		s.iz = v.y
		_ai_bully(s, dt)
		return
	var hv := _hole_pos(s.tgt)
	var hole := Vector2(hv.x, hv.z)
	var from := me - hole
	if from.length() < 0.05:
		from = Vector2(0, 1)
	var aim: Vector2 = s.aim
	var stand := hole + from.normalized() * reach + aim
	var go := stand - me
	var to_hole := hole - me
	if go.length() > 0.14:
		var v := go.normalized() * minf(1.0, go.length() / 0.4 + 0.25)
		s.ix = v.x
		s.iz = v.y
	else:
		# beállt: a lyuk felé fordul (kis lépés előre)
		var v := to_hole.normalized() * 0.25
		s.ix = v.x
		s.iz = v.y
	var facing := Vector2(sin(s.yaw), cos(s.yaw))
	var aligned := facing.dot(to_hole.normalized()) > 0.93
	var dist_ok := absf(to_hole.length() - reach) < HIT_R * 0.8
	var m2 := _mole_at(s.tgt)
	var e: float = t - float(m2.t0)
	var up_soon: bool = e >= OPEN_T + RISE_T * 0.35 - SW_ACT0
	if t - float(s.sw_t0) >= SWING_CD and up_soon:
		if dist_ok and aligned:
			_swing(s)
		elif t >= float(s.miss_until) and to_hole.length() < reach + 0.9:
			# néha türelmetlenül, rossz helyről csap le
			s.miss_until = t + 0.4
			if randf() < AI_MISS[lvl] * 2.0:
				_swing(s)


func _ai_bully(s: Dictionary, dt: float) -> void:
	var lvl: int = s.lvl
	if t - float(s.sw_t0) < SWING_CD or randf() > AI_BULLY[lvl] * dt:
		return
	var facing := Vector2(sin(s.yaw), cos(s.yaw))
	var reach := _reach()
	for o in pl:
		if o == s or _ally(s, o) or t < float(o.safe_until):
			continue
		var d := Vector2(o.x - s.x, o.z - s.z)
		if absf(d.length() - reach) < HIT_R_PLAYER and facing.dot(d.normalized()) > 0.85:
			_swing(s)
			return


func _reach() -> float:
	var a: float = P_HIT[0]
	var piv: Vector3 = P_HIT[1]
	return (piv.z + sin(a) * HL) * SC


func _remain(m: Dictionary) -> float:
	return float(m.t0) + OPEN_T + RISE_T + float(m.life) - t


func _choose(s: Dictionary) -> int:
	var lvl: int = s.lvl
	var me := Vector2(s.x, s.z)
	var best := -1
	var bv := -1.0
	for m in moles:
		if m.state != "up":
			continue
		var hv := _hole_pos(m.h)
		var d := maxf(0.0, me.distance_to(Vector2(hv.x, hv.z)) - _reach())
		var eta: float = d / (SPEED * float(AI_SPEED[lvl])) + SW_HIT + 0.1
		var rem := _remain(m)
		if lvl > 0 and eta > rem + 0.15:
			continue
		var v: float = (3.0 if m.gold else 1.0) / (eta + 0.4)
		if lvl == 2:
			# a nehéz gép nem fut versenyt azzal, aki sokkal közelebb van
			for o in pl:
				if o != s and t >= float(o.stun_until) and Vector2(o.x, o.z).distance_to(Vector2(hv.x, hv.z)) + 0.6 < d + _reach():
					v *= 0.45
					break
		# ha már más is arra tart, inkább másikat választ
		if lvl > 0:
			for o in pl:
				if o != s and int(o.tgt) == int(m.h):
					v *= 0.4
		if lvl == 0:
			v *= randf_range(0.5, 1.5)
		if v > bv:
			bv = v
			best = m.h
	return best


# ------------------------------------------------------------------ látvány
func _sync(dt: float) -> void:
	var tv := t + post
	for h in 9:
		_sync_hole(h, tv, dt)
	for s in pl:
		_sync_player(s, tv, dt)


## A vakond magassága és a fedél nyitottsága a vakond idővonala alapján.
func _mole_state(m: Dictionary, tv: float) -> Dictionary:
	var e: float = tv - float(m.t0)
	var open: float = clamp(e / OPEN_T, 0.0, 1.0)
	var r: float = clamp((e - OPEN_T) / RISE_T, 0.0, 1.0)
	var y: float = lerpf(MOLE_DOWN_Y, 0.0, D.ease_out_back(r)) if r > 0.0 else MOLE_DOWN_Y
	var ds: float = OPEN_T + RISE_T + float(m.life)
	var sx := 1.0
	var sy := 1.0
	var squint := 1.0
	if m.state == "hit":
		var y0: float = _mole_state({"t0": m.t0, "life": m.life, "state": "up"}, float(m.ts)).y
		var k: float = tv - float(m.ts)
		var sq: float = clamp(k / SQUASH_T, 0.0, 1.0)
		sy = 1.0 - 0.42 * sin(min(1.0, sq * 1.6) * PI / 2)
		sx = 1.0 + 0.28 * sin(min(1.0, sq * 1.6) * PI / 2)
		squint = 0.15
		var sk: float = clamp((k - SQUASH_T) / SINK_T, 0.0, 1.0)
		y = lerpf(y0, MOLE_DOWN_Y, sk * sk)
		var ck: float = clamp((k - SQUASH_T - SINK_T) / CLOSE_T, 0.0, 1.0)
		open = 1.0 - ck
	else:
		var dk: float = clamp((e - ds) / DOWN_T, 0.0, 1.0)
		if dk > 0.0:
			y = lerpf(0.0, MOLE_DOWN_Y, dk * dk)
			sy = 1.0 + 0.1 * sin(dk * PI)
		var ck: float = clamp((e - ds - DOWN_T) / CLOSE_T, 0.0, 1.0)
		if ck > 0.0:
			open = 1.0 - ck
	return {"y": y, "open": open, "sx": sx, "sy": sy, "squint": squint}


func _sync_hole(h: int, tv: float, dt: float) -> void:
	var hole: Dictionary = holes[h]
	var m := _mole_at(h)
	var mn: Dictionary = hole.mole
	var mg: Dictionary = hole.gold
	(mn.g as Node3D).visible = false
	(mg.g as Node3D).visible = false
	if m.is_empty():
		MW.set_lid(hole, 0.0)
		return
	var st := _mole_state(m, tv)
	var open: float = st.open
	MW.set_lid(hole, D.ease_out_back(open) if open < 1.0 else 1.0)
	var md: Dictionary = mg if m.gold else mn
	var g: Node3D = md.g
	g.visible = st.y > MOLE_DOWN_Y + 0.02
	g.position.y = st.y
	var root: Node3D = md.root
	root.scale = Vector3(st.sx, st.sy, st.sx)
	# kint: kíváncsian tekinget, a kezével a peremen dobol
	var e: float = tv - float(m.t0)
	root.rotation.y = sin(e * 5.0 + h) * 0.35 if m.state == "up" else 0.0
	root.rotation.z = sin(e * 9.0) * 0.06 if m.state == "up" else 0.0
	for k in md.hands.size():
		var hn: Node3D = md.hands[k]
		hn.position.y = -0.02 + absf(sin(e * 14.0 + k * 1.6)) * 0.035
	for ey in md.eyes:
		(ey as Node3D).scale = Vector3(1.0, st.squint, 1.0)
	if m.gold:
		for k in md.sparks.size():
			var sp: Node3D = md.sparks[k]
			var an: float = tv * 3.2 + TAU * k / md.sparks.size()
			sp.position = Vector3(cos(an) * 0.45, 0.25 + sin(tv * 5.0 + k) * 0.2, sin(an) * 0.45)
			sp.scale = Vector3.ONE * 0.045 * (0.6 + 0.6 * absf(sin(tv * 8.0 + k)))
		if m.state == "up" and st.y > -0.3 and FX.f() < dt * 7.0:
			var q := screen(_hole_pos(h) + Vector3(FX.fr(-0.35, 0.35), 0.4 + FX.f() * 0.5, FX.fr(-0.2, 0.3)))
			Main.I.burst(q.x, q.y, {"n": 3, "colors": ["#fff3b0", "#ffd43b", "#ffffff"], "speed": 60, "gravity": -40, "life": 0.6, "size": 5})


func _sync_player(s: Dictionary, tv: float, dt: float) -> void:
	var m: Chars3D.CharModel = s.m
	var a := m.animate(dt)
	var stunned: bool = t < float(s.stun_until)
	var sp := Vector2(s.vx, s.vz).length()
	var runk: float = clamp(sp / SPEED, 0.0, 1.0)
	s.run_ph = float(s.run_ph) + dt * (7.0 + sp * 2.6) * (1.0 if runk > 0.05 else 0.0)
	var ph: float = s.run_ph
	var place: int = places.get(s.i, -1)
	# testtartás: alap, lendítés, kábulás, győzelem, vereség
	var ps: Array = P_READY.duplicate()
	var k: float = tv - float(s.sw_t0)
	var swinging := k >= 0.0 and k < SW_END and not stunned
	if swinging:
		ps = _pose(k)
	else:
		ps[0] = float(ps[0]) + sin(ph * 2.0) * 0.12 * runk + sin(tv * 2.2 + s.i) * 0.04
	var hand_a: float = ps[0]
	var piv: Vector3 = ps[1]
	var lean: float = ps[2] + 0.18 * runk * (0.0 if swinging else 1.0)
	var squash: float = ps[3]
	var roll := 0.0
	var stun_k: float = tv - float(s.stun_t0)
	if stunned:
		# a kalapács kicsúszik a kézből, a figura szédeleg
		var dk: float = clamp(stun_k / 0.25, 0.0, 1.0)
		hand_a = lerpf(hand_a, 1.75, D.ease_out_cubic(dk))
		piv = piv.lerp(Vector3(0, 0.36, 0.34), dk)
		roll = sin(tv * 9.0) * 0.18
		lean = -0.1
		squash = 1.0 - 0.25 * max(0.0, 1.0 - stun_k / 0.2)
	elif place == 0:
		hand_a = -0.35 + sin(tv * 9.0) * 0.45
		piv = Vector3(0, 0.95, 0.12)
	elif place >= 0 and (place == pl.size() - 1 or s.score == 0):
		hand_a = 1.7
		piv = Vector3(0, 0.34, 0.32)
		lean = 0.2
	var bob: float = absf(sin(ph)) * 0.1 * runk
	var pos := Vector3(s.x, bob + a.y, s.z)
	m.position = pos
	m.rotation_order = EULER_ORDER_YXZ
	m.rotation = Vector3(lean + a.tilt * 0.3, s.yaw + a.spin, roll + (a.tilt if stunned else 0.0))
	var sy: float = squash * (1.0 - 0.06 * absf(cos(ph)) * runk)
	m.scale = Vector3(SC / sqrt(sy), SC * sy, SC / sqrt(sy))
	# villog, amíg nem lehet újra elkábítani
	var safe: bool = not stunned and t < float(s.safe_until)
	m.visible = not (safe and fmod(tv, 0.16) < 0.06)
	# kalapács a kézben
	var hm: Dictionary = s.hammer
	var hn: Node3D = hm.hn
	hn.position = piv
	hn.rotation = Vector3(hand_a, 0, 0)
	var head: Node3D = hm.head
	var ik: float = k - SW_HIT
	if swinging and ik >= 0.0 and ik < 0.12:
		var q: float = sin(ik / 0.12 * PI)
		head.scale = Vector3(1.0 + 0.16 * q, 1.0 + 0.16 * q, 1.0 - 0.26 * q)
	else:
		head.scale = Vector3.ONE
	# két kézzel fogja a nyelet
	var top := hn.transform * Vector3(0, 0.04, 0)
	var low := hn.transform * Vector3(0, -0.13, 0)
	for arm in s.arms:
		K.arm_to(arm, low if arm.side > 0 else top, Vector3(0.7, -0.5, -0.25))
	# arc
	var face: Dictionary = s.face
	if stunned:
		K.set_face(m, face, 0.7, 1.25, 0.8)
	elif place == 0:
		K.set_face(m, face, 0.85, 1.1, 0.6)
	elif place >= 0 and (place == pl.size() - 1 or s.score == 0):
		K.set_face(m, face, 0.15, 0.9, -0.7)
	elif tv - float(s.pop_t) < 0.5:
		K.set_face(m, face, 0.55, 1.15, 0.5)
	elif swinging and k < SW_HIT:
		K.set_face(m, face, 0.2, 0.95, -0.6)
	elif swinging:
		K.set_face(m, face, 0.6, 1.1, -0.2)
	else:
		K.set_face(m, face, 0.0, 1.0, 0.0)
	# szédülés-csillagok
	for j in s.stars.size():
		var st: Node3D = s.stars[j]
		st.visible = stunned
		var an: float = tv * 6.0 + TAU * j / 3.0
		st.position = Vector3(cos(an) * 0.38, 1.12, sin(an) * 0.38)
	var disc: MeshInstance3D = s.disc
	disc.position = Vector3(s.x, 0.03, s.z)
	var ready: bool = t - float(s.sw_t0) >= SWING_CD and not stunned
	disc.scale = Vector3.ONE * (1.0 if ready else 0.82)


# ------------------------------------------------------------------ felület
func draw(c: CanvasItem) -> void:
	var tv := t + post
	var rem := TIME - t
	# utolsó másodpercek: lüktető piros keret
	if rem <= URGENT_AT and not finished:
		var pulse := 0.5 + 0.5 * sin(tv * 10.0)
		var col := Color(1.0, 0.15, 0.15, 0.12 + 0.16 * pulse)
		for i in 4:
			var w := 26.0 - i * 6.0
			c.draw_rect(Rect2(0, 0, 1280, w), col)
			c.draw_rect(Rect2(0, 720 - w, 1280, w), col)
			c.draw_rect(Rect2(0, 0, w, 720), col)
			c.draw_rect(Rect2(1280 - w, 0, w, 720), col)
	# nevek a fejek fölött
	for s in pl:
		var q := screen(Vector3(s.x, 1.75, s.z))
		var col: Color = s.col
		D.panel(c, q.x - 24, q.y - 13, 48, 24, {"r": 12, "fill": col, "stroke": Color.WHITE, "lw": 2.5, "shadow": false})
		D.text(c, "%dP" % (s.i + 1) if not s.cpu else "GÉP", q.x, q.y - 1, {"size": 14, "stroke": col.darkened(0.5), "sw": 3})
		c.draw_colored_polygon(PackedVector2Array([Vector2(q.x - 6, q.y + 11), Vector2(q.x + 6, q.y + 11), Vector2(q.x, q.y + 18)]), Color.WHITE)
		if t < float(s.stun_until):
			D.emoji(c, "💫", q.x + 30, q.y - 6 + sin(tv * 10.0) * 3, 22)
	# lebegő pontfeliratok
	for p in pops:
		var k: float = (tv - float(p.t0)) / 1.0
		if k < 0.0 or k > 1.0:
			continue
		var q := screen(Vector3(p.x, 1.15 + k * 0.9, p.z))
		var gold: bool = p.gold
		var sc: float = (1.5 if gold else 1.0) * (0.55 + 0.45 * D.ease_out_back(min(1.0, k * 5.0)) + k * 0.15)
		var alpha: float = 1.0 - clamp((k - 0.6) / 0.4, 0.0, 1.0)
		var pc: Color = p.col
		c.draw_set_transform(q, sin(k * 12.0) * 0.08 if gold else 0.0, Vector2(sc, sc))
		if gold:
			D.text(c, p.text, 0, 0, {"size": 52, "color": Color("#ffd43b"), "stroke": pc.darkened(0.3), "sw": 9, "alpha": alpha})
			D.emoji(c, "✨", 44, -22, 28, alpha)
		else:
			D.text(c, p.text, 0, 0, {"size": 44, "color": pc.lightened(0.15), "stroke": Color.WHITE, "sw": 7, "alpha": alpha})
		c.draw_set_transform(Vector2.ZERO)
	K.silver_timer(c, rem if not finished else 0.0, 640, 46, URGENT_AT, tv)
	for s in pl:
		_draw_panel(c, s, tv)


## Pontpanelek a sarkokban (1P bal fent, 2P jobb fent, 3P bal lent, 4P jobb lent); 4 fölött a felső és alsó sorban középen.
func _panel_pos(i: int) -> Vector2:
	var pos := [Vector2(122, 56), Vector2(1158, 56), Vector2(122, 664), Vector2(1158, 664),
		Vector2(352, 56), Vector2(928, 56), Vector2(352, 664), Vector2(928, 664)]
	return pos[i % pos.size()]


func _draw_panel(c: CanvasItem, s: Dictionary, tv: float) -> void:
	var p := _panel_pos(s.i)
	var col: Color = s.col
	var pk: float = tv - float(s.pop_t)
	var sc := 1.0
	if pk >= 0.0 and pk < 0.35:
		sc += sin(pk / 0.35 * PI) * 0.08
	c.draw_set_transform(p, 0, Vector2(sc, sc))
	var w := 210.0
	var h := 76.0
	D.panel(c, -w / 2, -h / 2, w, h, {"r": 22, "fill": col, "stroke": Color.WHITE, "lw": 4.0})
	D.panel(c, -w / 2 + 6, -h / 2 + 5, w - 12, h * 0.4, {"r": 16, "fill": Color(1, 1, 1, 0.22), "stroke": null, "shadow": false})
	# portré
	D.panel(c, -w / 2 + 8, -29, 58, 58, {"r": 29, "fill": Color.WHITE, "stroke": col.darkened(0.3), "lw": 3.0, "shadow": false})
	D.char_image(c, s.p.char_id, -w / 2 + 37, 0, 54, 0.5 if t < float(s.stun_until) else 1.0)
	var name: String = s.p.name
	if s.cpu or s.p.is_bot:
		name += " · " + K.LEVEL_NAME[s.lvl]
	D.text(c, name, -w / 2 + 74, -20, {"size": 14, "align": "left", "maxw": 128, "stroke": col.darkened(0.5), "sw": 3})
	# pontszám ugró számmal
	var nk: float = 1.0 + (sin(pk / 0.3 * PI) * 0.45 if pk >= 0.0 and pk < 0.3 else 0.0)
	c.draw_set_transform(p + Vector2(40 * sc, 10 * sc), 0, Vector2(sc * nk, sc * nk))
	D.text(c, str(s.score), 0, 0, {"size": 40, "stroke": col.darkened(0.55), "sw": 7})
	c.draw_set_transform(Vector2.ZERO)
	if t < float(s.stun_until):
		D.emoji(c, "💫", p.x + w / 2 - 18, p.y - h / 2 + 6, 24)
	if finished and places.has(s.i):
		var place: int = places[s.i]
		var lk: float = (post - 0.25 - (pl.size() - place) * 0.12) * 2.5
		var ly: float = p.y + (62.0 if p.y < 360 else -62.0)
		if place <= 3:
			K.place_label(c, place, p.x, ly, lk, 46)
		elif lk > 0.0:
			D.text(c, "%d." % (place + 1), p.x, ly, {"size": 40, "color": Color("#9aa5b1"), "stroke": D.DARK, "sw": 8})
