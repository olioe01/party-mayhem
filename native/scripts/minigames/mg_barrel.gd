extends Minigame
## Hordó – mindenki feje fölé leereszkedik egy hordó. Állítsd meg minél később, de még mielőtt fejbe vág!
## Egyetlen kör: az nyer, aki a legkésőbb állította meg úgy, hogy a hordó még nem találta el.
## Az ereszkedés tempója menet közben változik, hogy ne lehessen kiszámolni.

const ROUNDS := 1
const TOP_Y := 70.0          # innen indul a hordó alja
const HEAD_Y := 470.0        # itt éri el a fejeket
const WARN := 1.4
const REVEAL := 3.0

var round_i := 0
var phase := "pre"
var phase_t := 0.0
var fall := 0.0              # 0 = fent, 1 = fejbe vágott
var speeds: Array = []       # a négy negyed tempója
var stop := {}               # pid -> hol állította meg (0..1)
var hit := {}
var got := {}
var pts := {}
var bot_target := {}


func meta() -> Dictionary:
	return {"id": "barrel", "name": "Hordó", "icon": "🛢️", "color": "#b45309", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Ki meri a legtovább húzni?",
		"desc": "Mindenki feje fölé leereszkedik egy hordó. Állítsd meg a sajátodat! Az nyer, aki a legkésőbb nyomja meg – de akit a hordó fejbe vág, az kiesett. A hordó hol lassul, hol gyorsul, és csak egyetlen kör van!",
		"controls": "Nyomd meg a STOP gombot, amikor már épp a fejed fölött jár a hordó. Csak egyszer nyomhatsz."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "🛢️", "title": "Hordó", "text": "Figyeld a hordódat!"}


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
	phase = "warn"
	phase_t = 0.0
	fall = 0.0
	stop = {}
	hit = {}
	got = {}
	speeds = []
	for i in 4:
		speeds.append(randf_range(0.17, 0.5) * (1.0 + 0.12 * round_i))
	for p in players:
		bot_target[p.pid] = 2.0 if randf() < 0.08 else randf_range(0.55, 0.985)
		Net.set_ctrl(p.pid, {"mode": "tap", "label": "🛑 STOP!", "hint": "Állítsd meg a hordót minél később – de mielőtt fejbe vág!"})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap" or phase != "fall" or stop.has(p.pid) or hit.has(p.pid):
		return
	stop[p.pid] = fall
	Audio.play("pop")
	Net.vibrate(p.pid, 40)
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🛑", "title": "Megállítottad!", "text": "Lássuk, ki merte tovább húzni…"})


func bot(p, _dt: float) -> void:
	if phase == "fall" and not stop.has(p.pid) and fall >= float(bot_target[p.pid]):
		input(p, {"t": "tap"})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	if phase == "warn":
		if phase_t >= WARN:
			phase = "fall"
			phase_t = 0.0
			Audio.play("whoosh")
	elif phase == "fall":
		fall = min(1.0, fall + float(speeds[min(3, int(fall * 4.0))]) * dt)
		if fall >= 1.0:
			for p in players:
				if not stop.has(p.pid):
					hit[p.pid] = true
					Net.vibrate(p.pid, [200, 80, 200])
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "💥", "title": "Fejbe vágott!", "text": "Túl sokáig vártál…"})
			Audio.play("boom")
			_reveal()
		elif stop.size() >= players.size():
			_reveal()
	elif phase == "reveal" and phase_t >= REVEAL:
		_next()


func _reveal() -> void:
	phase = "reveal"
	phase_t = 0.0
	var best := -1
	for p in players:
		var g: int = 0 if hit.has(p.pid) else min(99, roundi(float(stop[p.pid]) * 100.0))
		got[p.pid] = g
		pts[p.pid] += g
		best = max(best, g)
	if best > 0:
		Audio.play("coin")


func ranking() -> Array:
	return rank_by(func(p): return float(pts[p.pid]), func(p): return "fejbe vágta 💥" if hit.has(p.pid) else "%d%%-nál állt meg" % pts[p.pid])


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#57534e"), Color("#1c1917"))
	# pince: gerenda fent, téglasorok
	for i in 9:
		c.draw_line(Vector2(0, 110 + i * 60), Vector2(1280, 110 + i * 60), Color(0, 0, 0, 0.12), 2)
	c.draw_rect(Rect2(0, 0, 1280, 46), Color("#44260f"))
	c.draw_rect(Rect2(0, 40, 1280, 8), Color("#2b1708"))
	c.draw_rect(Rect2(0, 548, 1280, 172), Color("#292524"))
	c.draw_rect(Rect2(0, 548, 1280, 8), Color("#44403c"))
	D.text(c, "🛢️ Hordó", 130, 84, {"size": 28, "stroke": D.DARK, "sw": 6})
	var head := ""
	match phase:
		"warn": head = "Készülj… mindjárt jön!"
		"fall": head = "Állítsd meg minél később! 🛑"
		"reveal": head = "Ki merte a legtovább húzni?"
	D.text(c, head, 640, 84, {"size": 30, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 6})
	var n := players.size()
	var gap: float = min(230.0, 1180.0 / n)
	var bw: float = min(120.0, gap - 34)
	var bh := bw * 1.05
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var was_hit: bool = hit.has(p.pid)
		var f: float = stop.get(p.pid, fall)
		var shake: float = sin(Main.I.time * 40.0 + i) * 3.0 if phase == "warn" else 0.0
		var by: float = lerpf(TOP_Y, HEAD_Y, f)                    # a hordó alja
		# kötél
		c.draw_line(Vector2(x, 46), Vector2(x + shake, by - bh), Color("#d6b98a"), 4, true)
		# játékos
		var ay: float = 508.0 + (16.0 if was_hit else 0.0)
		D.avatar(c, p, x, ay, 34, {"squash": 0.25 if was_hit else 0.0})
		# hordó: dongák + abroncsok
		var bx: float = x + shake - bw / 2
		D.panel(c, bx, by - bh, bw, bh, {"r": 22, "fill": Color("#92400e"), "stroke": Color("#451a03"), "lw": 4, "shadow": false})
		for k in 3:
			c.draw_line(Vector2(bx + bw * (k + 1) / 4.0, by - bh + 8), Vector2(bx + bw * (k + 1) / 4.0, by - 8), Color("#78350f"), 3)
		c.draw_rect(Rect2(bx + 2, by - bh * 0.8, bw - 4, 9), Color("#a8a29e"))
		c.draw_rect(Rect2(bx + 2, by - bh * 0.28, bw - 4, 9), Color("#a8a29e"))
		if stop.has(p.pid):
			c.draw_arc(Vector2(x, by - bh / 2), bw * 0.62, 0, TAU, 40, Color("#69db7c"), 5, true)
			D.text(c, "🛑", x, by - bh / 2, {"size": 34})
		if was_hit:
			D.text(c, "💥", x, HEAD_Y, {"size": 60})
			D.emoji(c, "💫", x + 30, ay - 40 + sin(Main.I.time * 9.0) * 4, 26)
		if phase == "reveal":
			var g: int = got.get(p.pid, 0)
			D.text(c, "+%d" % g, x, by - bh - 26, {"size": 30, "color": Color("#ffd43b") if g > 0 else Color("#ff8787"), "stroke": D.DARK, "sw": 6})
		D.panel(c, x - gap / 2 + 8, 600, gap - 16, 100, {"r": 18, "fill": Color(0, 0, 0, 0.45), "stroke": p.color, "shadow": false})
		D.text(c, p.name, x, 630, {"size": 18, "maxw": gap - 26})
		D.text(c, str(pts[p.pid]), x, 668, {"size": 28, "color": Color("#ffd43b")})
