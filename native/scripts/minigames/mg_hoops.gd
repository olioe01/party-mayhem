extends Minigame
## Kosárdobás (3D) – mindenki egyszerre dobál a saját kosarára. Minden játékos mellett egy
## csúszka van: ha a jelölő a zöld zónában áll meg, a labda bemegy. A zóna helye dobásról
## dobásra véletlenül változik. Néha arany labda jön (3 pont) – mindenkinél ugyanannyi és ugyanakkor.

const SHOTS := 12
const LIMIT := 55.0
const FLY := 0.85
const HOOP_Y := 3.3
const HOOP_Z := -3.4
const PLAYER_Z := 3.0

var lane := 3.0
var shots: Array = []        # dobásonként közös: {zone, width, speed, val}
var st: Array = []           # játékosonként
var end_at := -1.0


func meta() -> Dictionary:
	return {"id": "hoops", "name": "Kosárdobás", "icon": "🏀", "color": "#ff922b", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Időzíts jól, és bent van!",
		"desc": "Mindenki egyszerre dobál a saját kosarára, %d labdával. Melletted egy csúszkán fel-le jár a jelölő: ha a zöld zónában állítod meg, a labda bemegy. A zóna minden dobásnál máshol van, és a jelölő egyre gyorsul. Az arany labda 3 pontot ér – ebből mindenki ugyanannyit kap." % SHOTS,
		"controls": "Koppints a DOBÁS gombra, amikor a jelölő a zöld zónában van. Nem kell kapkodni: mindenkinek %d dobása van." % SHOTS}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "🏀 DOBÁS!", "hint": "Akkor koppints, amikor a jelölő a zöld zónában van!", "rapid": true}


func _ready() -> void:
	# a dobások paraméterei mindenkinél azonosak, hogy igazságos legyen
	var gold := {}
	var cand: Array = range(2, SHOTS)
	cand.shuffle()
	for i in 3:
		gold[cand[i]] = true
	for i in SHOTS:
		shots.append({"zone": randf_range(0.2, 0.8), "width": max(0.15, 0.27 - i * 0.009), "speed": 2.3 + i * 0.22, "val": 3 if gold.has(i) else 1})
	make_env("#1e3a8a", "#93c5fd", 0.85)
	var n := players.size()
	lane = min(3.2, 17.5 / max(1, n))
	make_camera(Vector3(0, 8.2, 14.2), Vector3(0, 2.3, -0.6), 46)
	make_sun(Vector3(-50, 25, 0), 1.2)
	# pálya
	Chars3D.box(self, 60, 1.0, 40, Chars3D.mat("#2b3a67", {"rough": 0.9}), Vector3(0, -0.56, 0))
	Chars3D.box(self, max(12.0, n * lane + 2.0), 1.0, 11.0, Chars3D.mat("#d9a066", {"rough": 0.5}), Vector3(0, -0.5, 0))
	Chars3D.box(self, max(12.0, n * lane + 2.0), 0.02, 0.12, Chars3D.mat("#ffffff"), Vector3(0, 0.012, PLAYER_Z - 0.9))
	Chars3D.box(self, 60, 9.0, 0.6, Chars3D.mat("#3b4f8f", {"rough": 0.9}), Vector3(0, 4.0, -6.2))
	for i in 9:
		Chars3D.box(self, 0.25, 9.0, 0.7, Chars3D.mat("#4c63b0"), Vector3(-24 + i * 6, 4.0, -6.1))
	var steel := Chars3D.mat("#ced4da", {"metal": 0.6, "rough": 0.35})
	var rim_m := Chars3D.mat("#ff6b00", {"rough": 0.4, "emit": "#ff6b00", "emit_e": 0.25})
	for i in n:
		var p = players[i]
		var x := (i - (n - 1) / 2.0) * lane
		# kosár: oszlop, palánk, gyűrű, háló
		Chars3D.cyl(self, 0.09, 0.11, HOOP_Y + 0.6, steel, x, (HOOP_Y + 0.6) / 2.0, HOOP_Z - 0.75, 10)
		Chars3D.box(self, min(1.9, lane * 0.8), 1.25, 0.08, Chars3D.mat("#f8f9fa", {"rough": 0.3}), Vector3(x, HOOP_Y + 0.55, HOOP_Z - 0.55))
		Chars3D.box(self, min(1.9, lane * 0.8) + 0.1, 0.12, 0.1, Chars3D.mat(p.color_hex), Vector3(x, HOOP_Y + 1.2, HOOP_Z - 0.55))
		Chars3D.box(self, 0.6, 0.45, 0.02, Chars3D.mat(p.color_hex), Vector3(x, HOOP_Y + 0.35, HOOP_Z - 0.5))
		var rim := MeshInstance3D.new()
		rim.mesh = Chars3D.torus(0.42, 0.035)
		rim.material_override = rim_m
		rim.position = Vector3(x, HOOP_Y, HOOP_Z)
		add_child(rim)
		var net := Chars3D.cyl(self, 0.42, 0.26, 0.55, Chars3D.mat("#ffffff", {"alpha": 0.45, "rough": 0.9}), x, HOOP_Y - 0.28, HOOP_Z, 12)
		net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var disc := color_disc(p, 0.55)
		disc.position = Vector3(x, 0.03, PLAYER_Z)
		add_child(disc)
		var m := player_model(p, 1.25)
		m.position = Vector3(x, 0, PLAYER_Z)
		m.rotation.y = PI
		var ball := Node3D.new()
		add_child(ball)
		var bm := MeshInstance3D.new()
		bm.mesh = Chars3D._sphere_mesh(0.3)
		ball.add_child(bm)
		st.append({"p": p, "x": x, "m": m, "ball": ball, "ball_mesh": bm, "rim": rim, "idx": 0, "state": "wait", "ph": randf() * TAU, "st_t": 0.0,
			"score": 0, "acc": 0.0, "made": 0, "hit": false, "err": 0.0, "stop_v": 0.0, "last": "", "last_t": -9.0,
			"bot_delay": 0.0, "bot_hit": false, "done_t": 0.0, "side": 1.0, "bx": 1.0})
	for s in st:
		_set_ball_look(s)
	_sync(0.0)


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func start() -> void:
	for s in st:
		_begin_aim(s)


func _begin_aim(s: Dictionary) -> void:
	if s.idx >= SHOTS:
		s.state = "done"
		s.done_t = t
		s.ball.visible = false
		Net.set_ctrl(s.p.pid, {"mode": "wait", "icon": "🏀", "title": "%d pont" % s.score, "text": "Elfogytak a labdáid – várj a többiekre!"})
		return
	s.state = "aim"
	s.st_t = 0.0
	s.ph = randf() * TAU
	s.bot_delay = randf_range(0.5, 1.7)
	s.bot_hit = randf() < 0.72 - s.idx * 0.012
	s.ball.visible = true
	_set_ball_look(s)


func _set_ball_look(s: Dictionary) -> void:
	var sh: Dictionary = shots[min(s.idx, SHOTS - 1)]
	var gold: bool = sh.val > 1
	(s.ball_mesh as MeshInstance3D).material_override = Chars3D.mat("#ffd43b", {"metal": 0.7, "rough": 0.25, "emit": "#ffb000", "emit_e": 0.8}) if gold \
		else Chars3D.mat("#e8590c", {"rough": 0.7})


## a jelölő helye a csúszkán (0 = lent, 1 = fent)
func _marker(s: Dictionary) -> float:
	var sh: Dictionary = shots[min(s.idx, SHOTS - 1)]
	return 0.5 + 0.5 * sin(s.st_t * sh.speed + s.ph)


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	var s := _get(p)
	if s.is_empty() or s.state != "aim" or s.st_t < 0.15:
		return
	var sh: Dictionary = shots[s.idx]
	var v := _marker(s)
	var err: float = v - sh.zone
	s.stop_v = v
	s.err = err
	s.hit = abs(err) <= sh.width / 2.0
	s.side = 1.0 if err >= 0 else -1.0
	s.bx = 1.0 if randf() < 0.5 else -1.0
	s.state = "fly"
	s.st_t = 0.0
	Audio.play("jump")
	(s.m as Chars3D.CharModel).land = 0.7


func bot(p, dt: float) -> void:
	var s := _get(p)
	if s.state != "aim":
		return
	s.bot_delay -= dt
	if s.bot_delay > 0:
		return
	var sh: Dictionary = shots[s.idx]
	var d: float = abs(_marker(s) - sh.zone)
	if s.bot_hit:
		if d < sh.width * 0.32:
			input(p, {"t": "tap"})
	elif d > sh.width * 0.55 and d < sh.width * 1.3:
		input(p, {"t": "tap"})


func update(dt: float) -> void:
	var all_done := true
	for s in st:
		s.st_t += dt
		if s.state == "fly" and s.st_t >= FLY:
			_resolve(s)
		elif s.state == "after" and s.st_t >= 0.45:
			_begin_aim(s)
		if s.state != "done":
			all_done = false
	if end_at < 0 and (all_done or t >= LIMIT):
		end_at = t + 1.2
	if end_at >= 0 and t >= end_at:
		finished = true
	_sync(dt)


func _resolve(s: Dictionary) -> void:
	var sh: Dictionary = shots[s.idx]
	var q := screen(Vector3(s.x, HOOP_Y + 0.2, HOOP_Z))
	if s.hit:
		var perfect: bool = abs(s.err) <= sh.width * 0.12
		s.score += sh.val
		s.made += 1
		s.acc += 1.0 - abs(s.err) / (sh.width / 2.0)
		s.last = ("TÖKÉLETES! +%d" if perfect else "+%d") % sh.val
		Audio.play("crown" if sh.val > 1 else "coin")
		Net.vibrate(s.p.pid, [40, 30, 90] if sh.val > 1 else 35)
		Main.I.burst(q.x, q.y, {"n": 30 if sh.val > 1 else 14, "colors": ["#ffd43b", "#ffffff", s.p.color_hex], "speed": 300})
		Main.I.float_text(q.x, q.y - 30, "+%d" % sh.val, Color("#ffe066") if sh.val > 1 else Color.WHITE, 40 if sh.val > 1 else 30)
		(s.m as Chars3D.CharModel).emote("happy")
	else:
		s.last = "Mellé!"
		Audio.play("land")
	s.last_t = t
	s.idx += 1
	s.state = "after"
	s.st_t = 0.0


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	for s in st:
		var m: Chars3D.CharModel = s.m
		var a := m.animate(dt)
		m.position = Vector3(s.x, a.y, PLAYER_Z)
		m.rotation.y = PI + a.spin
		var ball: Node3D = s.ball
		var hold := Vector3(s.x + 0.0, 1.75 + sin(Main.I.time * 5.0 + s.x) * 0.06, PLAYER_Z - 0.55)
		var hoop := Vector3(s.x, HOOP_Y, HOOP_Z)
		if s.state == "fly" or s.state == "after":
			var k: float = clamp(s.st_t / FLY, 0.0, 1.0) if s.state == "fly" else 1.0
			var target := hoop + Vector3(0, 0.1, 0)
			if not s.hit:
				# rövid vagy hosszú dobás: a gyűrű elé esik, vagy a palánkról oldalra pattan
				target = hoop + (Vector3(0.0, 0.05, 0.75) if s.side < 0 else Vector3(0.5 * s.bx, 0.6, -0.35))
			var pos := hold.lerp(target, k) + Vector3(0, sin(k * PI) * 2.6, 0)
			if s.state == "after":
				var k2: float = s.st_t / 0.45
				if s.hit:
					pos = hoop + Vector3(0, 0.1 - k2 * 2.2, 0)
				elif s.side < 0:
					pos = target + Vector3(0, -k2 * k2 * 3.0, k2 * 0.8)
				else:
					pos = target + Vector3(sign(target.x - hoop.x) * k2 * 1.6, sin(k2 * PI) * 0.5 - k2 * 2.0, k2 * 1.2)
			ball.position = pos
			ball.rotation.x = -s.st_t * 9.0
		else:
			ball.position = hold
			ball.rotation.x = 0.0


func ranking() -> Array:
	return rank_by(_rank_score, _rank_label)


## holtversenynél a pontosabb dobó áll előrébb
func _rank_score(p) -> float:
	var s := _get(p)
	return float(s.score) + float(s.acc) * 0.001


func _rank_label(p) -> String:
	return "%d pont" % _get(p).score


func draw(c: CanvasItem) -> void:
	var bar_h := 150.0
	var bar_w := 24.0
	for s in st:
		var foot := screen(Vector3(s.x, 0.0, PLAYER_Z))
		var head := screen(Vector3(s.x, 1.9, PLAYER_Z))
		var bx: float = foot.x + min(56.0, (head.y - foot.y) * -0.42)
		var by: float = foot.y - 6
		var idx: int = min(s.idx, SHOTS - 1)
		var sh: Dictionary = shots[idx]
		if s.state != "done":
			# csúszka
			D.panel(c, bx - bar_w / 2 - 4, by - bar_h - 4, bar_w + 8, bar_h + 8, {"r": 10, "fill": Color(0.06, 0.04, 0.16, 0.9), "stroke": s.p.color, "lw": 3, "shadow": false})
			c.draw_rect(Rect2(bx - bar_w / 2, by - bar_h, bar_w, bar_h), Color("#7f1d1d"))
			var gold: bool = sh.val > 1
			var zy: float = by - (sh.zone + sh.width / 2.0) * bar_h
			c.draw_rect(Rect2(bx - bar_w / 2, zy, bar_w, sh.width * bar_h), Color("#ffd43b") if gold else Color("#40c057"))
			c.draw_rect(Rect2(bx - bar_w / 2, by - (sh.zone + sh.width * 0.12) * bar_h, bar_w, sh.width * 0.24 * bar_h), Color("#fff3bf") if gold else Color("#b2f2bb"))
			var mv: float = _marker(s) if s.state == "aim" else s.stop_v
			var my: float = by - mv * bar_h
			var mcol := Color.WHITE
			if s.state != "aim":
				mcol = Color("#8ce99a") if s.hit else Color("#ff8787")
			c.draw_rect(Rect2(bx - bar_w / 2 - 7, my - 3, bar_w + 14, 6), mcol)
			c.draw_colored_polygon(PackedVector2Array([Vector2(bx - bar_w / 2 - 6, my), Vector2(bx - bar_w / 2 - 20, my - 10), Vector2(bx - bar_w / 2 - 20, my + 10)]), mcol)
			if gold:
				D.text(c, "⭐×3", bx, by - bar_h - 20, {"size": 18, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 5})
		# név, pont, hátralévő labdák
		var tix := team_of(s.p)
		var ncol: Color = MgFlow.TEAM_COLORS[tix].lightened(0.4) if tix >= 0 else Color.WHITE
		D.text(c, s.p.name, foot.x, foot.y + 20, {"size": 17, "stroke": Color.BLACK, "sw": 5, "maxw": 130, "color": ncol})
		D.text(c, "%d pont" % s.score, foot.x, foot.y + 44, {"size": 22, "color": Color("#ffd43b"), "stroke": Color.BLACK, "sw": 5})
		D.text(c, "🏀 %d / %d" % [min(s.idx + (0 if s.state == "done" else 1), SHOTS), SHOTS], foot.x, foot.y + 68, {"size": 15, "color": Color("#dbe4ff"), "stroke": Color.BLACK, "sw": 4})
		if t - s.last_t < 0.9 and s.last != "":
			var hq := screen(Vector3(s.x, HOOP_Y + 1.9, HOOP_Z))
			D.text(c, s.last, hq.x, hq.y - (t - s.last_t) * 20, {"size": 22, "color": Color("#8ce99a") if s.last != "Mellé!" else Color("#ff8787"), "stroke": Color.BLACK, "sw": 5, "maxw": 150})
	D.timer_hud(c, LIMIT - t)
	D.text(c, "Állítsd meg a jelölőt a zöld zónában!  ⭐ arany labda = 3 pont", 640, 86, {"size": 20, "stroke": Color.BLACK, "sw": 5, "color": Color("#fff3bf")})
