extends Minigame
## Számold meg! – hány darab volt a mozgó tömegben?

const ROUNDS := 3
const SHOW := 6.5
const INPUT := 12.0
const REVEAL := 4.5
const THEMES := [
	{"target": "🐟", "decoys": ["🐠", "🐡"], "bg": ["#0b7285", "#0b3d5c"]},
	{"target": "🍎", "decoys": ["🍅", "🍒", "🍓"], "bg": ["#2b8a3e", "#0b3d1c"]},
	{"target": "🐑", "decoys": ["🐐", "🐄"], "bg": ["#5c940d", "#2b4005"]},
	{"target": "⭐", "decoys": ["🌟", "✨", "🌠"], "bg": ["#1c1652", "#05041a"]},
	{"target": "🎈", "decoys": ["🎀", "🎁"], "bg": ["#c2255c", "#4a0d26"]},
	{"target": "🐞", "decoys": ["🐝", "🦋", "🐛"], "bg": ["#66a80f", "#233d04"]},
]

var round_i := 0
var pts := {}
var themes: Array = []
var theme: Dictionary
var answer := 0
var objs: Array = []
var phase := "pre"
var phase_t := 0.0
var guess := {}
var reveal_n := 0
var targets: Array = []
var fastest = null
var bot_when := {}


func meta() -> Dictionary:
	return {"id": "count", "name": "Számold meg!", "icon": "🔢", "color": "#b197fc", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Sasszem kell hozzá",
		"desc": "A képernyőn rengeteg figura mozog össze-vissza. Számold meg, hány darab van a kért fajtából! Pontos tipp: 3 pont, 1-gyel mellé: 2, 2-vel: 1. A leggyorsabb pontos tipp +1 pontot ér.",
		"controls": "Figyeld a képernyőt, aztán írd be a számot a telefonod billentyűzetén, és nyomd meg a ✓-t. 3 kör."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "👀", "title": "Számolj!", "text": "Figyeld a képernyőt!"}


func _ready() -> void:
	for p in players:
		pts[p.pid] = 0
	themes = THEMES.duplicate()
	themes.shuffle()
	_setup_round()


func start() -> void:
	round_i = 0
	_next()


func _setup_round() -> void:
	theme = themes[round_i % themes.size()]
	answer = randi_range(7 + round_i * 3, 13 + round_i * 5)
	var decoys := randi_range(12 + round_i * 4, 18 + round_i * 6)
	var list: Array = []
	for i in answer:
		list.append(theme.target)
	for i in decoys:
		list.append(theme.decoys.pick_random())
	list.shuffle()
	objs = []
	for e in list:
		var a := randf() * TAU
		var sp := randf_range(50, 150) + round_i * 25
		objs.append({"e": e, "x": randf_range(120, 1160), "y": randf_range(150, 560), "vx": cos(a) * sp, "vy": sin(a) * sp, "s": randf_range(38, 50), "w": randf() * 6})


func _next() -> void:
	round_i += 1
	if round_i > ROUNDS:
		finished = true
		return
	_setup_round()
	phase = "show"
	phase_t = 0.0
	guess = {}
	reveal_n = 0
	fastest = null
	bot_when = {}
	for p in players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": theme.target, "title": "Számold: %s" % theme.target, "text": "Figyeld a képernyőt!"})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "num" or phase != "input" or guess.has(p.pid):
		return
	var v := clampi(roundi(float(msg.get("v", 0))), 0, 999)
	guess[p.pid] = {"v": v, "at": phase_t}
	Audio.play("pop")
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "📨", "title": "Tipped: %d" % v, "text": "Várjuk a többieket…"})


func bot(p, _dt: float) -> void:
	if phase != "input" or guess.has(p.pid):
		return
	if not bot_when.has(p.pid):
		bot_when[p.pid] = randf_range(2, 7)
	if phase_t >= bot_when[p.pid]:
		var err: int = [0, 0, 0, 1, -1, 1, -1, 2, -2, 3].pick_random()
		input(p, {"t": "num", "v": max(0, answer + err)})


func _score(g: int) -> int:
	var d: int = abs(g - answer)
	return 3 if d == 0 else (2 if d == 1 else (1 if d == 2 else 0))


func _move(dt: float) -> void:
	for o in objs:
		o.x += o.vx * dt
		o.y += o.vy * dt
		if o.x < 60 or o.x > 1220:
			o.vx *= -1
			o.x = clamp(o.x, 60, 1220)
		if o.y < 140 or o.y > 580:
			o.vy *= -1
			o.y = clamp(o.y, 140, 580)


func idle(dt: float) -> void:
	_move(dt)


func update(dt: float) -> void:
	if phase == "show" or phase == "pre":
		_move(dt)
	if phase == "pre":
		return
	phase_t += dt
	if phase == "show" and phase_t >= SHOW:
		phase = "input"
		phase_t = 0.0
		Audio.play("select")
		for p in players:
			Net.set_ctrl(p.pid, {"mode": "number", "title": "Hány %s volt?" % theme.target})
	elif phase == "input":
		var all_in := true
		for p in players:
			if not guess.has(p.pid):
				all_in = false
		if phase_t >= INPUT or all_in:
			phase = "reveal"
			phase_t = 0.0
			targets = objs.filter(func(o): return o.e == theme.target)
			for p in players:
				Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🔍", "title": "Lássuk…", "text": "Nézd a nagy képernyőt!"})
	elif phase == "reveal":
		var n: int = min(answer, floori(phase_t / (1.8 / answer)))
		if n > reveal_n:
			reveal_n = n
			Audio.play("tick")
			if n == answer:
				_award()
		if phase_t >= 1.8 + REVEAL:
			_next()


func _award() -> void:
	Audio.play("coin")
	var best_at := INF
	fastest = null
	for p in players:
		if not guess.has(p.pid):
			continue
		var g: Dictionary = guess[p.pid]
		var s := _score(g.v)
		pts[p.pid] += s
		if s == 3 and g.at < best_at:
			best_at = g.at
			fastest = p
	if fastest:
		pts[fastest.pid] += 1
	Main.I.burst(640, 360, {"n": 50, "speed": 500})


func ranking() -> Array:
	return rank_by(func(p): return float(pts[p.pid]), func(p): return "%d pont" % pts[p.pid])


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color(theme.bg[0]), Color(theme.bg[1]))
	var show_objs := phase == "show" or phase == "reveal" or phase == "pre"
	if show_objs:
		for o in objs:
			var dim: bool = phase == "reveal" and o.e != theme.target
			D.emoji(c, o.e, o.x, o.y + sin(Main.I.time * 3.0 + o.w) * 4, o.s, 0.25 if dim else 1.0)
		if phase == "reveal":
			for i in min(reveal_n, targets.size()):
				var o: Dictionary = targets[i]
				D.ring(c, o.x, o.y, o.s * 0.62, Color("#ffd43b"), 4)
				D.text(c, str(i + 1), o.x + o.s * 0.5, o.y - o.s * 0.5, {"size": 18, "stroke": Color.BLACK, "sw": 4})
	else:
		D.text(c, "❓", 640, 330, {"size": 180})
		D.text(c, "Írd be a tipped a telefonodon!", 640, 470, {"size": 38, "stroke": Color.BLACK, "sw": 6})
	D.panel(c, 330, 14, 620, 70, {"r": 35, "fill": Color(0, 0, 0, 0.55)})
	var head := ("Pontosan %d %s volt!" % [reveal_n, theme.target]) if phase == "reveal" else ("Számold meg: %s" % theme.target)
	D.text(c, head, 640, 50, {"size": 38})
	D.text(c, "%d. / %d kör" % [clampi(round_i, 1, ROUNDS), ROUNDS], 90, 36, {"size": 22, "color": Color("#eeeeee")})
	if phase == "show":
		D.timer_hud(c, SHOW - phase_t, 1180, 40)
	if phase == "input":
		D.timer_hud(c, INPUT - phase_t, 1180, 40)
	var n := players.size()
	var gap: float = min(150.0, 1200.0 / n)
	var done: bool = phase == "reveal" and reveal_n == answer
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var tix := team_of(p)
		D.panel(c, x - gap / 2 + 6, 612, gap - 12, 100, {"r": 18, "fill": Color(0, 0, 0, 0.5), "stroke": MgFlow.TEAM_COLORS[tix] if tix >= 0 else p.color, "shadow": false})
		D.avatar(c, p, x, 646, 22, {"shadow": false})
		var g = guess.get(p.pid)
		if phase == "reveal" and g:
			var sc := _score(g.v)
			D.text(c, str(g.v), x - 18, 690, {"size": 24})
			if done:
				D.text(c, ("+%d%s" % [sc, "+1⚡" if fastest == p else ""]) if sc else "✗", x + 26, 690, {"size": 20, "color": Color("#69db7c") if sc else Color("#ff8787")})
		elif phase == "input":
			D.text(c, "✔" if g else "…", x, 690, {"size": 24, "color": Color("#69db7c") if g else Color("#bbbbbb")})
		else:
			D.text(c, "%d p" % pts[p.pid], x, 690, {"size": 20, "color": Color("#ffd43b")})
