extends Minigame
## Vak időzítő – az óra eltűnik, neked kell érezni, mikor telt el pontosan X másodperc.

const TARGETS := [10, 7, 13]
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


func meta() -> Dictionary:
	return {"id": "blindtimer", "name": "Vak időzítő", "icon": "⏱️", "color": "#f59e0b", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Mennyi az a 10 másodperc?",
		"desc": "Elindul egy óra, de 3 másodperc múlva eltűnik! Magadban számolva nyomd meg a gombot pontosan a megadott időnél (10, 7, majd 13 mp). A legpontosabb 3 pontot kap, a második 2-t, a harmadik 1-et. Ha 0,1 mp-en belül vagy, +1 bónusz jár.",
		"controls": "Figyeld az órát, aztán számolj magadban, és nyomd meg a STOP gombot, amikor szerinted letelt az idő. Körönként egyszer nyomhatsz."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "⏱️", "title": "Vak időzítő", "text": "Figyeld az órát!"}


func _ready() -> void:
	for p in players:
		pts[p.pid] = 0
		err[p.pid] = 0.0


func _gauss() -> float:
	return (randf() + randf() + randf() - 1.5) * 1.15


func start() -> void:
	_next()


func _next() -> void:
	round_i += 1
	if round_i > TARGETS.size():
		finished = true
		return
	target = TARGETS[round_i - 1]
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
		Main.I.burst(640, 300, {"n": 50, "colors": [best.color_hex, "#ffd43b", "#ffffff"], "speed": 480})
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
		D.text(c, "?", x, y + 8, {"size": 170, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 10, "alpha": fade})
	if shown:
		D.text(c, "%.1f" % tt, x, y + r + 50, {"size": 44, "stroke": D.DARK, "sw": 7})


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#2a1660"), Color("#0b0622"))
	D.text(c, "%d. / %d kör" % [clampi(round_i, 1, TARGETS.size()), TARGETS.size()], 100, 36, {"size": 22, "color": Color("#dddddd")})
	D.panel(c, 390, 14, 500, 70, {"r": 35, "fill": Color(0, 0, 0, 0.45)})
	D.text(c, "🎯 Állítsd meg pontosan %d mp-nél!" % target, 640, 50, {"size": 30, "maxw": 470})
	if phase == "reveal":
		_draw_reveal(c)
		return
	_draw_clock(c, 640, 290, 165)
	if phase == "run" and phase_t >= VISIBLE:
		D.text(c, "Számolj magadban… 🤫", 640, 515, {"size": 30, "color": Color("#e5dbff")})
	elif phase == "intro":
		D.text(c, "Az óra 3 mp után eltűnik!", 640, 515, {"size": 28, "color": Color("#e5dbff")})
	var n := players.size()
	var gap: float = min(150.0, 1180.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var done: bool = stops.has(p.pid)
		var tix := team_of(p)
		if tix >= 0:
			D.ring(c, x, 600 - (6.0 if done else 0.0), 36, MgFlow.TEAM_COLORS[tix], 5)
		D.avatar(c, p, x, 600 - (6.0 if done else 0.0), 28, {"alpha": 1.0 if done else 0.7})
		D.text(c, p.name, x, 644, {"size": 16, "maxw": gap - 6})
		D.text(c, "✋ STOP" if done else "%d p" % pts[p.pid], x, 672, {"size": 18, "color": Color("#69db7c") if done else Color("#ffd43b")})


func _draw_reveal(c: CanvasItem) -> void:
	var x0 := 140.0
	var x1 := 1140.0
	var y := 230.0
	var span := 3.0
	for p in players:
		span = max(span, abs(stops.get(p.pid, float(target)) - target) + 0.5)
	var k: float = min(1.0, phase_t / 1.2)
	D.panel(c, x0, y - 8, x1 - x0, 16, {"r": 8, "fill": Color(1, 1, 1, 0.15), "stroke": null, "shadow": false})
	c.draw_rect(Rect2(638, y - 40, 4, 80), Color("#ffd43b"))
	D.text(c, "%d.00 mp" % target, 640, y - 58, {"size": 26, "color": Color("#ffd43b")})
	D.text(c, "◀ korán", x0 + 50, y - 28, {"size": 18, "color": Color("#b8acec")})
	D.text(c, "későn ▶", x1 - 50, y - 28, {"size": 18, "color": Color("#b8acec")})
	var rows := players.duplicate()
	rows.sort_custom(func(a, b): return gained.get(a.pid, -1) > gained.get(b.pid, -1))
	var n := rows.size()
	for i in n:
		var p = rows[i]
		var has: bool = stops.has(p.pid)
		if has:
			var s: float = stops[p.pid]
			var px := 640 + ((s - target) / span * ((x1 - x0) / 2)) * k
			c.draw_line(Vector2(px, y), Vector2(px, y + 22 + (i % 3) * 12), p.color, 3)
			D.avatar(c, p, px, y + 34 + (i % 3) * 12, 13, {"shadow": false})
		var ry = 330 + i * min(46.0, 340.0 / n)
		D.panel(c, 300, ry - 20, 680, 40, {"r": 14, "fill": Color(1, 1, 1, 0.07), "stroke": p.color, "shadow": false, "lw": 2})
		D.avatar(c, p, 326, ry, 15, {"shadow": false})
		D.text(c, p.name, 352, ry, {"size": 20, "align": "left", "maxw": 220})
		if not has:
			D.text(c, "nem nyomott", 700, ry, {"size": 20, "color": Color("#ff8787")})
		else:
			var s: float = stops[p.pid]
			var d := s - target
			D.text(c, "%.2f mp" % s, 640, ry, {"size": 22})
			D.text(c, "%s%.2f" % ["+" if d >= 0 else "−", abs(d)], 790, ry, {"size": 20, "color": Color("#69db7c") if abs(d) < 0.3 else (Color("#ffd43b") if abs(d) < 1 else Color("#ff8787"))})
		if gained.get(p.pid, 0) > 0:
			D.text(c, "+%d p" % gained[p.pid], 950, ry, {"size": 22, "color": Color("#ffd43b"), "align": "right"})
	if best:
		var pulse := 1.0 + sin(Main.I.time * 6.0) * 0.04
		c.draw_set_transform(Vector2(640, 125), 0, Vector2(pulse, pulse))
		D.text(c, "🏅 %s a legpontosabb!" % best.name, 0, 0, {"size": 34, "stroke": D.shade(best.color, -0.6), "sw": 7})
		c.draw_set_transform(Vector2.ZERO)
