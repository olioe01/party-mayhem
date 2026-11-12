extends Minigame
## Színmemória – ismételd meg a felvillanó sorozatot. Legfeljebb 10 színig: aki odáig eljut, holtversenyben nyer.

const PADS := [
	{"color": "#ff4d6d", "shape": "▲"},
	{"color": "#4dabf7", "shape": "●"},
	{"color": "#51cf66", "shape": "■"},
	{"color": "#ffd43b", "shape": "★"},
]
const STEP := 0.6
const LIT := 0.42
const MAXLEN := 10

var seq: Array = []
var alive := {}
var st := {}
var phase := "pre"
var phase_t := 0.0
var lit := -1
var last_shown := -1
var limit := 0.0
var flash := {}


func meta() -> Dictionary:
	return {"id": "memory", "name": "Színmemória", "icon": "🧠", "color": "#4dabf7", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Ki bírja a legtovább?",
		"desc": "A nagy képernyőn felvillan egy színsorozat. Ismételd meg pontosan a telefonodon! A sorozat minden körben eggyel hosszabb, és aki hibázik, kiesik. Aki eljut 10 színig, holtversenyben nyer.",
		"controls": "Figyeld a képernyőt, aztán nyomd meg a színes gombokat ugyanabban a sorrendben."}


func layout(_p) -> Dictionary:
	return {"mode": "pads", "enabled": false, "pads": PADS, "title": "Figyeld a képernyőt! 👀"}


func _ready() -> void:
	seq = [randi() % 4, randi() % 4, randi() % 4]
	for p in players:
		alive[p.pid] = true
		st[p.pid] = {"idx": 0, "done": false, "failed": false, "best": 0, "total": 0.0, "bot_t": 0.0}


func start() -> void:
	_show_seq()


func _show_seq() -> void:
	phase = "show"
	phase_t = 0.0
	last_shown = -1
	for p in players:
		if alive.has(p.pid):
			Net.set_ctrl(p.pid, {"mode": "pads", "enabled": false, "pads": PADS, "title": "Figyeld a képernyőt! 👀"})
		st[p.pid].idx = 0
		st[p.pid].done = false


func _start_input() -> void:
	phase = "input"
	phase_t = 0.0
	limit = 3.0 + seq.size() * 0.75
	for p in players:
		if alive.has(p.pid):
			Net.set_ctrl(p.pid, {"mode": "pads", "enabled": true, "pads": PADS, "title": "Ismételd! (%d szín)" % seq.size()})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "pad" or phase != "input" or not alive.has(p.pid):
		return
	var s: Dictionary = st[p.pid]
	if s.done:
		return
	var v := int(msg.get("v", -1))
	if v == seq[s.idx]:
		s.idx += 1
		Audio.pad_soft(v)
		flash[p.pid] = {"v": v, "t": t}
		if s.idx == seq.size():
			s.done = true
			s.best = seq.size()
			s.total += phase_t
			Net.vibrate(p.pid, 60)
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": "✅", "title": "Helyes!", "text": "Várj a következő sorozatra…"})
	else:
		_fail(p)


func _fail(p) -> void:
	var s: Dictionary = st[p.pid]
	if s.failed:
		return
	s.failed = true
	alive.erase(p.pid)
	Audio.play("bad")
	Net.vibrate(p.pid, [200, 80, 200])
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "❌", "title": "Hibáztál!", "text": "Elért szint: %d szín" % s.best})


func bot(p, dt: float) -> void:
	if phase != "input" or not alive.has(p.pid):
		return
	var s: Dictionary = st[p.pid]
	if s.done:
		return
	s.bot_t -= dt
	if s.bot_t > 0:
		return
	s.bot_t = randf_range(0.3, 0.6)
	var err = 0.03 + max(0, seq.size() - 4) * 0.035
	var right: int = seq[s.idx]
	input(p, {"t": "pad", "v": (right + randi_range(1, 3)) % 4 if randf() < err else right})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	if phase == "show":
		var i := floori((phase_t - 0.6) / STEP)
		var in_lit := i >= 0 and i < seq.size() and (phase_t - 0.6) - i * STEP < LIT
		lit = seq[i] if in_lit else -1
		if in_lit and i != last_shown:
			last_shown = i
			Audio.pad(seq[i])
		if phase_t > 0.6 + seq.size() * STEP + 0.2:
			lit = -1
			_start_input()
	elif phase == "input":
		var all_done := true
		for p in players:
			if alive.has(p.pid) and not st[p.pid].done:
				all_done = false
		if all_done or phase_t >= limit:
			for p in players:
				if alive.has(p.pid) and not st[p.pid].done:
					_fail(p)
			phase = "check"
			phase_t = 0.0
			if alive.size():
				Audio.play("coin")
	elif phase == "check" and phase_t > 1.6:
		if alive.size() == 0 or seq.size() >= MAXLEN or (players.size() > 1 and alive.size() == 1 and teams.is_empty()):
			finished = true
			return
		seq.append(randi() % 4)
		_show_seq()


func ranking() -> Array:
	return rank_by(_score, _label)


func _score(p) -> float:
	var s: Dictionary = st[p.pid]
	if s.best >= MAXLEN:
		return MAXLEN * 1000.0
	return s.best * 1000.0 - roundi(s.total * 10)


func _label(p) -> String:
	var s: Dictionary = st[p.pid]
	return ("%d szín 🏆" % MAXLEN) if s.best >= MAXLEN else "%d szín" % s.best


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#1e1b4b"), Color("#0b0920"))
	var label := ""
	match phase:
		"pre": label = "Készülj!"
		"show": label = "Figyeld a sorrendet! 👀"
		"input": label = "Most te jössz – a telefonodon!"
		"check":
			if alive.is_empty(): label = "Mindenki kiesett!"
			elif seq.size() >= MAXLEN: label = ("🏆 %d szín – döntetlen!" % MAXLEN) if alive.size() > 1 else ("🏆 Megvan mind a %d szín!" % MAXLEN)
			else: label = "Szuper! Jön a következő…"
	D.text(c, label, 640, 50, {"size": 34, "stroke": Color.BLACK, "sw": 6})
	D.text(c, "Sorozat hossza: %d / %d" % [seq.size(), MAXLEN], 640, 92, {"size": 22, "color": Color("#c5bdf2")})
	if phase == "input":
		var k: float = max(0.0, 1.0 - phase_t / limit)
		D.panel(c, 440, 112, 400, 10, {"r": 5, "fill": Color(1, 1, 1, 0.15), "stroke": null, "shadow": false})
		if k > 0.02:
			D.panel(c, 440, 112, 400 * k, 10, {"r": 5, "fill": Color("#ff6b6b") if k < 0.3 else Color("#69db7c"), "stroke": null, "shadow": false})
	var S := 150.0
	var Gp := 18.0
	var x0 := 640 - S - Gp / 2
	var y0 := 140.0
	for i in 4:
		var pd: Dictionary = PADS[i]
		var x := x0 + (i % 2) * (S + Gp)
		var y := y0 + (i / 2) * (S + Gp)
		var on := lit == i
		var col := Color(pd.color)
		if on:
			for k in 6:
				D.panel(c, x - 30 + k * 5, y - 30 + k * 5, S + 60 - k * 10, S + 60 - k * 10, {"r": 40, "fill": Color(col, 0.08), "stroke": null, "shadow": false})
		D.panel(c, x, y, S, S, {"r": 30, "fill": D.shade(col, 0.35) if on else D.shade(col, -0.55), "stroke": Color.WHITE if on else D.shade(col, -0.2), "lw": 5})
		D.text(c, pd.shape, x + S / 2, y + S / 2 + 4, {"size": 64, "color": Color.WHITE if on else D.shade(col, -0.25)})
	var n := players.size()
	var gap: float = min(155.0, 1200.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var s: Dictionary = st[p.pid]
		var out := not alive.has(p.pid)
		var f = flash.get(p.pid)
		var bounce := 6.0 if (f and t - f.t < 0.2) else 0.0
		var tix := team_of(p)
		if tix >= 0:
			D.ring(c, x, 540 - bounce, 38, MgFlow.TEAM_COLORS[tix], 5)
		D.avatar(c, p, x, 540 - bounce, 30, {"gray": out})
		D.text(c, p.name, x, 588, {"size": 16, "maxw": gap - 6})
		if out:
			D.text(c, "❌ %d" % s.best, x, 618, {"size": 20, "color": Color("#ff8787")})
		elif phase == "input" or s.done:
			var len := seq.size()
			var w: float = min(gap - 16, len * 12.0)
			for k in len:
				var col := Color(PADS[seq[k]].color) if k < s.idx else Color(1, 1, 1, 0.2)
				c.draw_circle(Vector2(x - w / 2 + (k + 0.5) * (w / len), 618), min(5.0, w / len / 2 - 0.5), col)
			if s.done:
				D.text(c, "✔", x + 26, 518, {"size": 24, "color": Color("#69db7c"), "stroke": Color.BLACK, "sw": 4})
		else:
			D.text(c, "🧠 %d" % s.best, x, 618, {"size": 18, "color": Color("#ffd43b")})
