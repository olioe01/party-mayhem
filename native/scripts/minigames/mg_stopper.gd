extends Minigame
## Célzó – a mutató ide-oda leng, állítsd meg a célzónában!

const ROUNDS := 5
const BAR_X0 := 160.0
const BAR_X1 := 1120.0
const BAR_Y := 300.0
const LIMIT := 7.0
const REVEAL := 2.6

var round_i := 0
var pts := {}
var phase := "pre"
var phase_t := 0.0
var stops := {}
var got := {}
var target := 0.5
var speed := 2.2
var width := 0.1
var ph := 0.0
var bot_tol := {}
var bot_min := {}


func meta() -> Dictionary:
	return {"id": "stopper", "name": "Célzó", "icon": "🎯", "color": "#facc15", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Egy jól időzített koppintás",
		"desc": "Egy mutató ide-oda leng a sávon. Állítsd meg minél közelebb a sárga célzóna közepéhez! Minél pontosabb vagy, annál több pontot kapsz (max. 100). Körről körre gyorsul a mutató, és szűkül a zóna.",
		"controls": "Nyomd meg a STOP gombot, amikor a mutató a sárga zónában van. Körönként egyszer nyomhatsz. 5 kör."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "🎯", "title": "Célzó", "text": "Figyeld a mutatót!"}


func _ready() -> void:
	for p in players:
		pts[p.pid] = 0


func start() -> void:
	_next()


func _next() -> void:
	round_i += 1
	if round_i > ROUNDS:
		finished = true
		return
	phase = "run"
	phase_t = 0.0
	target = randf_range(0.15, 0.85)
	speed = 1.5 + round_i * 0.3
	width = max(0.05, 0.11 - round_i * 0.012)
	ph = randf() * TAU
	stops = {}
	got = {}
	for p in players:
		bot_tol[p.pid] = randf_range(0.03, 0.16)
		bot_min[p.pid] = randf_range(0.6, 2.5)
		Net.set_ctrl(p.pid, {"mode": "tap", "label": "🎯 STOP!", "hint": "Állítsd meg a mutatót a sárga zónában!"})


func _pos() -> float:
	return 0.5 + 0.5 * sin(phase_t * speed + ph)


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap" or phase != "run" or stops.has(p.pid):
		return
	var v := _pos()
	var d: float = abs(v - target)
	var g: int = 100 if d <= width / 2 * 0.35 else max(0, roundi(100 * (1 - d / 0.32)))
	stops[p.pid] = v
	got[p.pid] = g
	pts[p.pid] += g
	if g >= 100:
		Audio.play("crown")
		Net.vibrate(p.pid, [60, 40, 160])
	else:
		Audio.play("pop")
		Net.vibrate(p.pid, 40)
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🎯" if g >= 100 else ("👍" if g >= 75 else "😬"), "title": "%d pont" % g, "text": "TÖKÉLETES!" if g >= 100 else "Várj a többiekre…"})


func bot(p, _dt: float) -> void:
	if phase != "run" or stops.has(p.pid):
		return
	var late := phase_t > LIMIT - 1
	if (phase_t >= bot_min[p.pid] and abs(_pos() - target) < bot_tol[p.pid]) or late:
		input(p, {"t": "tap"})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	if phase == "run":
		var all_in := true
		for p in players:
			if not stops.has(p.pid):
				all_in = false
		if phase_t >= LIMIT or all_in:
			for p in players:
				if not stops.has(p.pid):
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⌛", "title": "Lejárt az idő!", "text": "0 pont ebben a körben"})
			phase = "reveal"
			phase_t = 0.0
			var best_pid := ""
			var best_g := 0
			for pid in got:
				if got[pid] > best_g:
					best_g = got[pid]
					best_pid = pid
			if best_pid != "":
				var bp = G.by_pid(best_pid)
				Main.I.burst(BAR_X0 + stops[best_pid] * (BAR_X1 - BAR_X0), BAR_Y, {"n": 40, "colors": [bp.color_hex, "#ffd43b", "#ffffff"], "speed": 420})
	elif phase == "reveal" and phase_t >= REVEAL:
		_next()


func ranking() -> Array:
	return rank_by(func(p): return float(pts[p.pid]), func(p): return "%d pont" % pts[p.pid])


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#3d1d0f"), Color("#140803"))
	D.text(c, "%d. / %d kör" % [clampi(round_i, 1, ROUNDS), ROUNDS], 100, 36, {"size": 22, "color": Color("#dddddd")})
	D.panel(c, 400, 14, 480, 70, {"r": 35, "fill": Color(0, 0, 0, 0.45)})
	D.text(c, "🎯 Állítsd meg a sárgában!", 640, 50, {"size": 32})
	var w0 := BAR_X1 - BAR_X0
	D.panel(c, BAR_X0 - 10, BAR_Y - 38, w0 + 20, 76, {"r": 38, "fill": Color("#2a140a"), "stroke": null})
	# színátmenetes sáv a cél felé
	var steps := 64
	for i in steps:
		var v0 := float(i) / steps
		var v1 := float(i + 1) / steps
		var d: float = abs((v0 + v1) / 2 - target)
		var col := Color("#facc15").lerp(Color("#ea580c"), clamp(d / 0.25, 0, 1))
		if d > 0.25:
			col = Color("#ea580c").lerp(Color("#7f1d1d"), clamp((d - 0.25) / 0.4, 0, 1))
		c.draw_rect(Rect2(BAR_X0 + v0 * w0, BAR_Y - 26, w0 / steps + 1, 52), col)
	var zx := BAR_X0 + (target - width / 2) * w0
	D.panel(c, zx, BAR_Y - 34, width * w0, 68, {"r": 12, "fill": Color(1, 1, 1, 0.35), "stroke": Color.WHITE, "lw": 4, "shadow": false})
	var k := 0
	for p in players:
		if not stops.has(p.pid):
			continue
		var x: float = BAR_X0 + stops[p.pid] * w0
		var up := 1 if k % 2 else -1
		k += 1
		c.draw_line(Vector2(x, BAR_Y + up * 26), Vector2(x, BAR_Y + up * 62), p.color, 4)
		D.avatar(c, p, x, BAR_Y + up * 82, 17, {"shadow": false})
		if phase == "reveal":
			D.text(c, str(got[p.pid]), x, BAR_Y + up * 118, {"size": 20, "color": Color("#ffd43b"), "stroke": Color.BLACK, "sw": 4})
	if phase == "run":
		var x := BAR_X0 + _pos() * w0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, BAR_Y - 30), Vector2(x - 16, BAR_Y - 58), Vector2(x + 16, BAR_Y - 58)]), Color.WHITE)
		c.draw_rect(Rect2(x - 3, BAR_Y - 32, 6, 64), Color.WHITE)
		var pulse := 0.5 + sin(Main.I.time * 10.0) * 0.5
		D.text(c, "MOST?", 640, 470, {"size": 40, "color": D.shade(Color("#facc15"), pulse * 0.4), "stroke": Color.BLACK, "sw": 6})
	var n := players.size()
	var gap: float = min(150.0, 1180.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var done: bool = stops.has(p.pid)
		var tix := team_of(p)
		D.panel(c, x - gap / 2 + 6, 560, gap - 12, 120, {"r": 18, "fill": Color(0, 0, 0, 0.45), "stroke": MgFlow.TEAM_COLORS[tix] if tix >= 0 else p.color, "shadow": false})
		D.avatar(c, p, x, 598, 24, {"shadow": false, "alpha": 1.0 if (done or phase != "run") else 0.6})
		D.text(c, p.name, x, 636, {"size": 16, "maxw": gap - 18})
		D.text(c, str(pts[p.pid]), x, 662, {"size": 20, "color": Color("#ffd43b")})
