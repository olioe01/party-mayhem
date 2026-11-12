extends Minigame
## Fejszámolás – ki oldja meg leggyorsabban a feladatot?

const LIMIT := 12.0
const REVEAL := 3.2
const ORDER_PTS := [3, 2]
const ROUNDS := 5

var round_i := 0
var pts := {}
var phase := "pre"
var phase_t := 0.0
var ans := {}
var correct_order: Array = []
var task := {"q": "", "a": 0}
var bot_plan := {}
var gained := {}


func meta() -> Dictionary:
	return {"id": "quickmath", "name": "Fejszámolás", "icon": "🧮", "color": "#20c997", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Gyorsabb vagy a számológépnél?",
		"desc": "Megjelenik egy feladat a képernyőn, és egyre nehezebb lesz. Az első helyes válasz 3 pontot ér, a második 2-t, a többi helyes 1-et. Egy feladatra csak egyszer válaszolhatsz!",
		"controls": "Írd be az eredményt a telefonod számbillentyűzetén, és nyomd meg a ✓-t. 5 feladat."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "🧮", "title": "Fejszámolás", "text": "Figyeld a képernyőt!"}


func _ready() -> void:
	for p in players:
		pts[p.pid] = 0


func _make(i: int) -> Dictionary:
	match i:
		0:
			var a := randi_range(12, 49)
			var b := randi_range(11, 49)
			return {"q": "%d + %d" % [a, b], "a": a + b}
		1:
			var a := randi_range(40, 99)
			var b := randi_range(12, a - 5)
			return {"q": "%d − %d" % [a, b], "a": a - b}
		2:
			var a := randi_range(3, 9)
			var b := randi_range(4, 12)
			return {"q": "%d × %d" % [a, b], "a": a * b}
		3:
			var a := randi_range(20, 60)
			var b := randi_range(10, 40)
			var c := randi_range(5, 25)
			return {"q": "%d + %d − %d" % [a, b, c], "a": a + b - c}
		_:
			var a := randi_range(3, 9)
			var b := randi_range(3, 9)
			var c := randi_range(5, 30)
			return {"q": "%d × %d + %d" % [a, b, c], "a": a * b + c}


func start() -> void:
	_next()


func _next() -> void:
	round_i += 1
	if round_i > ROUNDS:
		finished = true
		return
	task = _make(round_i - 1)
	phase = "ask"
	phase_t = 0.0
	ans = {}
	correct_order = []
	gained = {}
	for p in players:
		var right := randf() < 0.82
		bot_plan[p.pid] = {"at": randf_range(2.2, 4) + round_i * randf_range(0.4, 1.0),
			"v": task.a if right else max(0, task.a + (-1 if randf() < 0.5 else 1) * randi_range(1, 10))}
	Audio.play("select")
	for p in players:
		Net.set_ctrl(p.pid, {"mode": "number", "title": "%s = ?" % task.q})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "num" or phase != "ask" or ans.has(p.pid):
		return
	var v := clampi(roundi(float(msg.get("v", 0))), 0, 999)
	var ok: bool = v == task.a
	ans[p.pid] = {"v": v, "ok": ok, "at": phase_t}
	if ok:
		correct_order.append(p.pid)
		Audio.play("coin")
		Net.vibrate(p.pid, 60)
	else:
		Audio.play("bad")
		Net.vibrate(p.pid, [120, 50, 120])
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "✅" if ok else "❌", "title": "Helyes!" if ok else "Nem talált…", "text": "A tipped: %d" % v})


func bot(p, _dt: float) -> void:
	var plan = bot_plan.get(p.pid)
	if phase == "ask" and plan and not ans.has(p.pid) and phase_t >= plan.at:
		input(p, {"t": "num", "v": plan.v})


func _award() -> void:
	for i in correct_order.size():
		var g: int = ORDER_PTS[i] if i < ORDER_PTS.size() else 1
		gained[correct_order[i]] = g
		pts[correct_order[i]] += g
	if correct_order.size():
		Main.I.burst(640, 260, {"n": 40, "speed": 450})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	if phase == "ask":
		var all_in := true
		for p in players:
			if not ans.has(p.pid):
				all_in = false
		if phase_t >= LIMIT or all_in:
			phase = "reveal"
			phase_t = 0.0
			_award()
			for p in players:
				if not ans.has(p.pid):
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⌛", "title": "Lejárt az idő!", "text": "A megoldás: %d" % task.a})
	elif phase == "reveal" and phase_t >= REVEAL:
		_next()


func ranking() -> Array:
	return rank_by(func(p): return float(pts[p.pid]), func(p): return "%d pont" % pts[p.pid])


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#0f3d3e"), Color("#03161a"))
	D.text(c, "%d. / %d feladat" % [clampi(round_i, 1, ROUNDS), ROUNDS], 110, 36, {"size": 22, "color": Color("#dddddd")})
	if phase == "ask":
		D.timer_hud(c, LIMIT - phase_t, 1180, 40)
	var s := D.ease_out_back(min(1.0, phase_t * 3.0)) if phase == "ask" else 1.0
	c.draw_set_transform(Vector2(640, 250), 0, Vector2(s, s))
	D.panel(c, -380, -110, 760, 220, {"r": 40, "fill": Color(1, 1, 1, 0.95), "stroke": Color("#20c997"), "lw": 8})
	var eq: String = ("%s = %d" % [task.q, task.a]) if phase == "reveal" else ("%s = ?" % task.q)
	D.text(c, eq, 0, 6, {"size": 76 if eq.length() > 14 else 96, "color": Color("#0b3d3e"), "maxw": 720})
	c.draw_set_transform(Vector2.ZERO)
	var msg := ("Szép munka!" if correct_order.size() else "Senki nem találta el…") if phase == "reveal" else "Írd be a választ a telefonodon!"
	D.text(c, msg, 640, 410, {"size": 28, "color": Color("#c3fae8")})
	var n := players.size()
	var gap: float = min(150.0, 1180.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var a = ans.get(p.pid)
		var rank := correct_order.find(p.pid)
		var hop := 8.0 if (a and phase_t - a.at < 0.3 and phase == "ask") else 0.0
		var tix := team_of(p)
		D.panel(c, x - gap / 2 + 6, 480, gap - 12, 200, {"r": 18, "fill": Color(0, 0, 0, 0.4), "stroke": MgFlow.TEAM_COLORS[tix] if tix >= 0 else p.color, "shadow": false})
		D.avatar(c, p, x, 530 - hop, 28, {"shadow": false})
		D.text(c, p.name, x, 575, {"size": 16, "maxw": gap - 18})
		if phase == "reveal":
			if a:
				D.text(c, str(a.v), x, 610, {"size": 26, "color": Color("#69db7c") if a.ok else Color("#ff8787")})
			else:
				D.text(c, "—", x, 610, {"size": 26, "color": Color("#aaaaaa")})
			if gained.has(p.pid):
				D.text(c, "+%d%s" % [gained[p.pid], " ⚡" if rank == 0 else ""], x, 642, {"size": 20, "color": Color("#ffd43b")})
		elif a:
			D.text(c, ("%d. ✔" % (rank + 1)) if rank >= 0 else "✔", x, 610, {"size": 24, "color": Color("#e9fac8")})
		else:
			D.text(c, "…", x, 610, {"size": 26, "color": Color("#999999")})
		D.text(c, "%d pont" % pts[p.pid], x, 668, {"size": 17, "color": Color("#ffd43b")})
	if phase == "ask":
		var pulse := 0.5 + sin(Main.I.time * 4.0) * 0.5
		D.text(c, "🧮", 1040, 250, {"size": 70, "alpha": 0.4 + pulse * 0.3})
