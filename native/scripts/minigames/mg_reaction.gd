extends Minigame
## Villámreflex – aki leggyorsabban reagál a zöld jelre. A kék villanás csapda!

const ROUNDS := 5

var pts := {}
var times := {}
var round_i := 0
var last := {}
var phase := "pre"
var phase_t := 0.0
var fouled := {}
var tapped := {}
var delay := 0.0
var fake := -1.0
var fake_shown := false
var winner = null
var bot_rt := {}
var bot_foul := {}
var after_t := 0.0


func meta() -> Dictionary:
	return {"id": "reaction", "name": "Villámreflex", "icon": "⚡", "color": "#51cf66", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Csak semmi kapkodás!",
		"desc": "A lámpa egyszer csak ZÖLD lesz. Aki elsőként nyom, 2 pontot kap, a második 1-et. Vigyázz: a kék villanás csapda, és a korai nyomás pontlevonással jár!",
		"controls": "Nyomd meg a gombot, amikor a nagy képernyőn ZÖLD lesz a lámpa. 5 kör."}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "⚡ MOST!", "hint": "Csak ha zöld!", "rapid": true}


func _ready() -> void:
	for p in players:
		pts[p.pid] = 0
		times[p.pid] = []


func start() -> void:
	_next()


func _next() -> void:
	round_i += 1
	if round_i > ROUNDS:
		finished = true
		return
	phase = "wait"
	phase_t = 0.0
	delay = randf_range(1.8, 4.2)
	fake = randf_range(0.8, delay - 0.6) if (round_i >= 2 and randf() < 0.55) else -1.0
	fake_shown = false
	fouled = {}
	tapped = {}
	winner = null
	last = {}
	for p in players:
		bot_rt[p.pid] = randf_range(0.27, 0.6)
		bot_foul[p.pid] = randf() < 0.12


func _is_fake() -> bool:
	return fake >= 0 and phase_t >= fake and phase_t < fake + 0.55


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap":
		return
	if phase == "wait":
		if fouled.has(p.pid):
			return
		fouled[p.pid] = true
		pts[p.pid] -= 1
		last[p.pid] = "KORAI!"
		Audio.play("bad")
		Net.vibrate(p.pid, [150, 50, 150])
	elif phase == "go":
		if fouled.has(p.pid) or tapped.has(p.pid):
			return
		var rt := phase_t - delay
		tapped[p.pid] = rt
		times[p.pid].append(rt)
		last[p.pid] = "%d ms" % roundi(rt * 1000)
		if winner == null:
			winner = p
			pts[p.pid] += 2
			Audio.play("coin")
			Net.vibrate(p.pid, 120)
		elif tapped.size() == 2:
			pts[p.pid] += 1


func bot(p, _dt: float) -> void:
	if phase == "wait" and _is_fake() and bot_foul.get(p.pid, false):
		bot_foul[p.pid] = false
		input(p, {"t": "tap"})
	if phase == "go" and phase_t - delay >= bot_rt.get(p.pid, 0.4):
		input(p, {"t": "tap"})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	if phase == "wait":
		if _is_fake() and not fake_shown:
			fake_shown = true
			Audio.play("select")
		if phase_t >= delay:
			phase = "go"
			Audio.play("go")
			Main.I.burst(640, 300, {"n": 40, "colors": ["#69db7c", "#ffffff", "#b2f2bb"], "speed": 500})
	elif phase == "go":
		var all_in := true
		for p in players:
			if not fouled.has(p.pid) and not tapped.has(p.pid):
				all_in = false
		if all_in or phase_t > delay + 2.5:
			phase = "after"
			after_t = phase_t
			if winner:
				Main.I.burst(640, 300, {"n": 50, "colors": [winner.color_hex, "#ffd43b", "#ffffff"], "speed": 520})
				Audio.play("win")
	elif phase == "after" and phase_t - after_t > 2.4:
		_next()


func ranking() -> Array:
	return rank_by(_score, func(p): return "%d pont" % pts[p.pid])


func _score(p) -> float:
	var a: Array = times[p.pid]
	var avg := 9.0
	if a.size():
		avg = 0.0
		for x in a:
			avg += x
		avg /= a.size()
	return pts[p.pid] * 100.0 - avg


func draw(c: CanvasItem) -> void:
	var is_fake := phase == "wait" and _is_fake()
	var top := Color("#3b0a1a")
	var bot_c := Color("#14050c")
	var lamp := Color("#ff4d6d")
	var msg := "VÁRJ…"
	if phase == "pre":
		top = Color("#1f1147"); bot_c = Color("#0a0520"); lamp = Color("#6b7280"); msg = "Készülj!"
	if is_fake:
		top = Color("#0b2a5b"); bot_c = Color("#03102a"); lamp = Color("#4dabf7"); msg = "NEM MOST!"
	if phase == "go":
		top = Color("#0d4f2a"); bot_c = Color("#032612"); lamp = Color("#51cf66"); msg = "MOST!!!"
	if phase == "after":
		top = Color("#1f1147"); bot_c = Color("#0a0520"); lamp = winner.color if winner else Color("#6b7280"); msg = ""
	D.vgrad(c, top, bot_c)
	D.text(c, "%d. / %d kör" % [min(round_i, ROUNDS), ROUNDS], 640, 44, {"size": 28, "color": Color("#dddddd")})
	var pulse := 1.0 + sin(Main.I.time * 30.0) * 0.03 if phase == "go" else 1.0
	for k in 12:
		var rr := 230.0 * pulse * (1.0 - k / 12.0)
		c.draw_circle(Vector2(640, 290), rr, Color(lamp, 0.05 + k * 0.012))
	c.draw_circle(Vector2(640, 290), 120, lamp)
	c.draw_circle(Vector2(610, 255), 50, Color(1, 1, 1, 0.25))
	D.ring(c, 640, 290, 120, Color(1, 1, 1, 0.7), 10)
	if msg != "":
		D.text(c, msg, 640, 290, {"size": 46 if msg.length() > 6 else 60, "stroke": Color(0, 0, 0, 0.6), "sw": 8})
	if phase == "after":
		if winner:
			D.avatar(c, winner, 640, 275, 70)
			D.text(c, "%s volt a leggyorsabb!" % winner.name, 640, 450, {"size": 36, "stroke": D.DARK, "sw": 7})
		else:
			D.text(c, "Senki nem nyomta meg…", 640, 290, {"size": 36})
	if phase == "wait" or phase == "pre":
		D.text(c, "Csak akkor nyomd, ha ZÖLD! A korai nyomás −1 pont.", 640, 460, {"size": 22, "color": Color("#ffc9c9")})
	var n := players.size()
	var gap: float = min(150.0, 1180.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var foul: bool = fouled.has(p.pid)
		var jump := 0.0
		if tapped.has(p.pid):
			jump = max(0.0, 1.0 - (phase_t - delay - tapped[p.pid]) * 3.0) * 18.0
		var tix := team_of(p)
		if tix >= 0:
			D.ring(c, x, 575 - jump, 38, MgFlow.TEAM_COLORS[tix], 5)
		D.avatar(c, p, x, 575 - jump, 30, {"gray": foul})
		D.text(c, p.name, x, 620, {"size": 16, "maxw": gap - 6})
		D.text(c, "%d pont" % pts[p.pid], x, 645, {"size": 18, "color": Color("#ffd43b")})
		if last.has(p.pid):
			var l: String = last[p.pid]
			D.text(c, l, x, 528, {"size": 18, "color": Color("#ff8787") if l == "KORAI!" else Color("#b2f2bb"), "stroke": Color.BLACK, "sw": 4})
