extends Minigame
## Vak időzítő – az óra eltűnik, neked kell érezni, mikor telt el pontosan X másodperc.

const ROUNDS := 3
const T_MIN := 5
const T_MAX := 15
const VISIBLE := 3.0
const INTRO := 2.6
const REVEAL := 5.0
const PLACE_PTS := [3, 2, 1]

var round_i := 0
var pts := {}
var err := {}
var phase := "pre"
var phase_t := 0.0
var stops := {}
var target := 10
var gained := {}
var bot_at := {}
var best = null
var targets: Array = []      # a 3 kör célideje: 5 és 15 mp közötti, egymástól különböző egész számok


func meta() -> Dictionary:
	return {"id": "blindtimer", "name": "Vak időzítő", "icon": "⏱️", "color": "#f59e0b", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Mennyi az a pár másodperc?",
		"desc": "Elindul egy óra, de 3 másodperc múlva eltűnik! Magadban számolva nyomd meg a gombot pontosan a megadott időnél. Három kör van, a célidő minden körben más: véletlenszerűen 5 és 15 másodperc közötti. A legpontosabb 3 pontot kap, a második 2-t, a harmadik 1-et. Ha 0,1 mp-en belül vagy, +1 bónusz jár.",
		"controls": "Figyeld az órát, aztán számolj magadban, és nyomd meg a STOP gombot, amikor szerinted letelt az idő. Körönként egyszer nyomhatsz."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "⏱️", "title": "Vak időzítő", "text": "Figyeld az órát!"}


func _ready() -> void:
	for p in players:
		pts[p.pid] = 0
		err[p.pid] = 0.0
	var pool: Array = range(T_MIN, T_MAX + 1)
	pool.shuffle()
	targets = pool.slice(0, ROUNDS)


func _gauss() -> float:
	return (randf() + randf() + randf() - 1.5) * 1.15


func start() -> void:
	_next()


func _next() -> void:
	round_i += 1
	if round_i > ROUNDS:
		finished = true
		return
	target = targets[round_i - 1]
	phase = "intro"
	phase_t = 0.0
	stops = {}
	gained = {}
	best = null
	for p in players:
		bot_at[p.pid] = target + _gauss() * (0.35 + target * 0.05)
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⏱️", "title": "Cél: %d mp" % target, "text": "Mindjárt indul az óra…"})


func _go() -> void:
	phase = "run"
	phase_t = 0.0
	Audio.play("go")
	for p in players:
		Net.set_ctrl(p.pid, {"mode": "tap", "label": "⏱️ STOP!", "hint": "Nyomd meg, ha szerinted eltelt %d másodperc!" % target})
		Net.vibrate(p.pid, 80)


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap" or phase != "run" or stops.has(p.pid):
		return
	stops[p.pid] = phase_t
	Audio.play("pop")
	Net.vibrate(p.pid, 40)
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🤞", "title": "Megállítva!", "text": "Lássuk, mennyire voltál pontos…"})


func bot(p, _dt: float) -> void:
	if phase == "run" and not stops.has(p.pid) and phase_t >= bot_at[p.pid]:
		input(p, {"t": "tap"})


func _score_round() -> void:
	var rows: Array = []
	for p in players:
		if stops.has(p.pid):
			rows.append({"p": p, "d": abs(stops[p.pid] - target)})
	rows.sort_custom(func(a, b): return a.d < b.d)
	var place := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		if i > 0 and abs(r.d - rows[i - 1].d) > 0.0005:
			place = i
		var g: int = (PLACE_PTS[place] if place < PLACE_PTS.size() else 0) + (1 if r.d < 0.1 else 0)
		gained[r.p.pid] = g
		pts[r.p.pid] += g
	for p in players:
		err[p.pid] += abs(stops[p.pid] - target) if stops.has(p.pid) else 5.0
	best = rows[0].p if rows.size() else null
	if best:
		Main.I.burst(640, 232, {"n": 50, "colors": [best.color_hex, "#ffd43b", "#ffffff"], "speed": 480})
	Audio.play("coin")


func update(dt: float) -> void:
	if phase == "pre":
		return
	var prev := phase_t
	phase_t += dt
	if phase == "intro":
		if phase_t >= INTRO:
			_go()
	elif phase == "run":
		if prev < VISIBLE and phase_t >= VISIBLE:
			Audio.play("whoosh")
		elif phase_t < VISIBLE and floori(prev) != floori(phase_t):
			Audio.play("tick")
		var all_in := true
		for p in players:
			if not stops.has(p.pid):
				all_in = false
		if all_in or phase_t > target + 5:
			for p in players:
				if not stops.has(p.pid):
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⌛", "title": "Lejárt az idő!", "text": "Ebben a körben nem nyomtál."})
			phase = "reveal"
			phase_t = 0.0
			_score_round()
	elif phase == "reveal" and phase_t >= REVEAL:
		_next()


func ranking() -> Array:
	return rank_by(func(p): return pts[p.pid] * 1000.0 - roundi(err[p.pid] * 10), func(p): return "%d pont" % pts[p.pid])


func _draw_clock(c: CanvasItem, x: float, y: float, r: float) -> void:
	var run := phase == "run"
	var shown := phase == "intro" or (run and phase_t < VISIBLE)
	var fade: float = clamp((phase_t - VISIBLE + 0.5) / 0.5, 0.0, 1.0) if run else 0.0
	c.draw_circle(Vector2(x, y), r + 14, Color("#2b1a5c"))
	c.draw_circle(Vector2(x, y), r, Color("#fdfaff"))
	for i in 60:
		var a := float(i) / 60 * TAU - PI / 2
		var l := 18.0 if i % 5 == 0 else 8.0
		c.draw_line(Vector2(x + cos(a) * (r - 6), y + sin(a) * (r - 6)), Vector2(x + cos(a) * (r - 6 - l), y + sin(a) * (r - 6 - l)),
			Color("#2b1a5c") if i % 5 == 0 else Color("#b8acec"), 5.0 if i % 5 == 0 else 2.0, true)
	var ta := float(target) / 60 * TAU - PI / 2
	c.draw_circle(Vector2(x + cos(ta) * (r - 40), y + sin(ta) * (r - 40)), 12, Color("#ffd43b"))
	var tt := phase_t if run else (float(target) if phase == "reveal" else 0.0)
	if shown or phase == "reveal":
		var a := tt / 60 * TAU - PI / 2
		c.draw_line(Vector2(x, y), Vector2(x + cos(a) * (r - 24), y + sin(a) * (r - 24)), Color("#e11d48"), 7, true)
	c.draw_circle(Vector2(x, y), 10, Color("#2b1a5c"))
	if run and fade > 0:
		c.draw_circle(Vector2(x, y), r + 2, Color(Color("#3b1f7a"), fade))
		D.text(c, "?", x, y + 6, {"size": 130, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 10, "alpha": fade})
	if shown:
		D.text(c, "%.1f" % tt, x + r + 70, y, {"size": 44, "stroke": D.DARK, "sw": 7})


func draw(c: CanvasItem) -> void:
	_draw_studio(c)
	D.text(c, "%d. / %d kör" % [clampi(round_i, 1, ROUNDS), ROUNDS], 100, 36, {"size": 22, "color": Color("#dddddd")})
	D.panel(c, 390, 14, 500, 70, {"r": 35, "fill": Color(0, 0, 0, 0.55), "stroke": Color("#ffd43b"), "lw": 3})
	D.text(c, "🎯 Állítsd meg pontosan %d mp-nél!" % target, 640, 50, {"size": 30, "maxw": 470})
	_draw_clock(c, 640, 232, 118)
	if phase == "run" and phase_t >= VISIBLE:
		D.text(c, "Számolj magadban… 🤫", 640, 408, {"size": 28, "color": Color("#e5dbff"), "stroke": D.DARK, "sw": 6})
	elif phase == "intro":
		D.text(c, "Az óra 3 mp után eltűnik!", 640, 408, {"size": 26, "color": Color("#e5dbff"), "stroke": D.DARK, "sw": 6})
	elif phase == "reveal" and best and phase_t > 0.4 + players.size() * 0.22:
		var pulse := 1.0 + sin(Main.I.time * 6.0) * 0.04
		c.draw_set_transform(Vector2(640, 408), 0, Vector2(pulse, pulse))
		D.text(c, "🏅 %s a legpontosabb!" % best.name, 0, 0, {"size": 32, "stroke": D.shade(best.color, -0.6), "sw": 7})
		c.draw_set_transform(Vector2.ZERO)
	_draw_desks(c)


## Vetélkedő-stúdió: függöny, reflektorok, fényes padló.
func _draw_studio(c: CanvasItem) -> void:
	D.vgrad(c, Color("#3b1470"), Color("#12072e"))
	for i in 17:
		var x := i * 80.0
		c.draw_rect(Rect2(x, 0, 40, 560), Color(0, 0, 0, 0.10))
		c.draw_rect(Rect2(x + 40, 0, 6, 560), Color(1, 1, 1, 0.03))
	# reflektorfények fentről
	for k in 4:
		var sx := 160.0 + k * 320.0
		var sway := sin(Main.I.time * 0.7 + k * 1.7) * 60.0
		var cone := PackedVector2Array([Vector2(sx - 14, 0), Vector2(sx + 14, 0), Vector2(sx + sway + 150, 560), Vector2(sx + sway - 150, 560)])
		c.draw_colored_polygon(cone, Color(1, 0.95, 0.7, 0.05))
		c.draw_circle(Vector2(sx, 4), 16, Color("#ffe066"))
	# égősor a színpad peremén
	for i in 33:
		var on := (i + int(Main.I.time * 3.0)) % 3 == 0
		c.draw_circle(Vector2(i * 40.0, 556), 5, Color("#ffd43b") if on else Color("#7a5b12"))
	D.vgrad(c, Color("#2a1458"), Color("#090416"), 562, 720)
	c.draw_rect(Rect2(0, 560, 1280, 4), Color("#ffd43b"))


## Minden játékos egy pult mögött áll; a pult kijelzője a kör végén megmutatja, mennyinél állította meg.
func _draw_desks(c: CanvasItem) -> void:
	var n := players.size()
	var gap: float = min(190.0, 1220.0 / n)
	var w: float = gap - 14
	var reveal := phase == "reveal"
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var done: bool = stops.has(p.pid)
		var shown: bool = reveal and phase_t > 0.3 + i * 0.22
		var is_best: bool = shown and best == p
		var tix := team_of(p)
		var trim: Color = MgFlow.TEAM_COLORS[tix] if tix >= 0 else p.color
		# a figura a pult mögött (a pult eltakarja az alját)
		var bob: float = abs(sin(Main.I.time * 6.0 + i)) * 8.0 if is_best else 0.0
		D.avatar(c, p, x, 462 - bob, min(44.0, w * 0.36), {"shadow": false})
		if done and not reveal:
			D.text(c, "✋", x + min(40.0, w * 0.3), 438, {"size": 26})
		# pult
		if is_best:
			D.panel(c, x - w / 2 - 6, 484, w + 12, 172, {"r": 20, "fill": Color(1, 0.83, 0.23, 0.35), "stroke": null, "shadow": false})
		D.panel(c, x - w / 2, 490, w, 160, {"r": 16, "fill": D.shade(trim, -0.55), "stroke": trim, "lw": 4})
		c.draw_rect(Rect2(x - w / 2 + 4, 490, w - 8, 10), D.shade(trim, 0.2))
		D.text(c, p.name, x, 518, {"size": 17, "maxw": w - 14})
		# kijelző
		D.panel(c, x - w / 2 + 10, 536, w - 20, 70, {"r": 10, "fill": Color("#0a0618"), "stroke": Color(1, 1, 1, 0.25), "lw": 2, "shadow": false})
		if shown:
			if done:
				var sv: float = stops[p.pid]
				var d := sv - target
				var col := Color("#69db7c") if abs(d) < 0.3 else (Color("#ffd43b") if abs(d) < 1 else Color("#ff8787"))
				D.text(c, "%.2f" % sv, x, 560, {"size": min(30, int(w * 0.24)), "color": col})
				D.text(c, "%s%.2f mp" % ["+" if d >= 0 else "−", abs(d)], x, 590, {"size": 15, "color": Color("#cfc6f5")})
			else:
				D.text(c, "nem nyomott", x, 571, {"size": 15, "color": Color("#ff8787"), "maxw": w - 26})
		elif reveal:
			D.text(c, "?", x, 571, {"size": 34, "color": Color("#ffd43b")})
		elif done:
			D.text(c, "STOP", x, 571, {"size": 26, "color": Color("#69db7c")})
		else:
			D.text(c, "– –", x, 571, {"size": 26, "color": Color(1, 1, 1, 0.35)})
		# a pult alja: pontok
		if shown and gained.get(p.pid, 0) > 0:
			D.text(c, "+%d p" % gained[p.pid], x, 628, {"size": 20, "color": Color("#ffd43b")})
		else:
			D.text(c, "%d pont" % pts[p.pid], x, 628, {"size": 17, "color": Color("#e5dbff")})
