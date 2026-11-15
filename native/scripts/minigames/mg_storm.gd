extends Minigame
## Villámfelhő – bal vagy jobb pódium? Mindenki titokban választ, aztán a viharfelhő belecsap az egyikbe,
## az leszakad, és aki rajta állt, életet veszít. Mindenkinek 2 élete van, legfeljebb 5 kör.

const MAX_ROUNDS := 5
const LIVES := 2
const PICK_TIME := 7.0
const PX := [330.0, 950.0]   # a két pódium közepe
const PY := 470.0

var lives := {}
var out_round := {}
var side := {}               # pid -> 0 (bal) / 1 (jobb)
var bot_at := {}
var round_i := 0
var phase := "pre"           # pick -> walk -> suspense -> strike -> (következő kör)
var phase_t := 0.0
var doomed := 0
var lost := {}               # akik ebben a körben életet vesztettek


func meta() -> Dictionary:
	return {"id": "storm", "name": "Villámfelhő", "icon": "🌩️", "color": "#6366f1", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Bal vagy jobb? A felhő dönt.",
		"desc": "Két pódium közül választhatsz: bal vagy jobb. Amikor mindenki beállt, a viharfelhő belecsap az egyikbe, az leszakad, és aki rajta állt, elveszít egy életet. Hogy melyikbe, az csak a végén derül ki! Mindenkinek %d élete van, legfeljebb %d kör – akinek több élete marad, az nyer." % [LIVES, MAX_ROUNDS],
		"controls": "Koppints a BAL vagy a JOBB gombra, mielőtt lejár az idő."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "🌩️", "title": "Villámfelhő", "text": "Mindjárt választhatsz!"}


func _ready() -> void:
	for p in players:
		lives[p.pid] = LIVES


func start() -> void:
	_next()


func _alive() -> Array:
	return players.filter(func(p): return int(lives[p.pid]) > 0)


func _next() -> void:
	var alive := _alive()
	if round_i >= MAX_ROUNDS or alive.is_empty() or (teams.is_empty() and players.size() > 1 and alive.size() <= 1):
		finished = true
		return
	round_i += 1
	phase = "pick"
	phase_t = 0.0
	side = {}
	lost = {}
	doomed = randi() % 2
	for p in players:
		if int(lives[p.pid]) > 0:
			bot_at[p.pid] = randf_range(0.8, 4.0)
			Net.set_ctrl(p.pid, {"mode": "choice", "title": "Melyik pódiumra állsz?", "text": "A felhő az egyikbe belecsap…", "options": [{"label": "⬅️ BAL"}, {"label": "JOBB ➡️"}]})
		else:
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": "💔", "title": "Kiestél", "text": "Szurkolj a többieknek!"})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "choice" or phase != "pick" or side.has(p.pid) or int(lives[p.pid]) <= 0:
		return
	side[p.pid] = clampi(int(msg.get("v", 0)), 0, 1)
	Audio.play("pop")
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🤞", "title": "BAL" if side[p.pid] == 0 else "JOBB", "text": "Reméljük, nem ide csap a villám…"})


func bot(p, _dt: float) -> void:
	if phase == "pick" and not side.has(p.pid) and int(lives[p.pid]) > 0 and phase_t >= float(bot_at[p.pid]):
		input(p, {"t": "choice", "v": randi() % 2})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	match phase:
		"pick":
			var alive := _alive()
			var all_in := true
			for p in alive:
				if not side.has(p.pid):
					all_in = false
			if all_in or phase_t >= PICK_TIME:
				for p in alive:
					if not side.has(p.pid):
						side[p.pid] = randi() % 2
						Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⌛", "title": "Lejárt az idő!", "text": "A játék választott helyetted."})
				phase = "walk"
				phase_t = 0.0
				Audio.play("step")
		"walk":
			if phase_t >= 1.1:
				phase = "suspense"
				phase_t = 0.0
				Audio.play("roll")
		"suspense":
			if phase_t >= 2.4:
				phase = "strike"
				phase_t = 0.0
				Audio.play("boom")
				Audio.play("hit")
				Main.I.burst(PX[doomed], PY, {"n": 60, "colors": ["#fff3bf", "#ffd43b", "#ffffff"], "speed": 520})
				var any := false
				for p in _alive():
					if side[p.pid] != doomed:
						Net.set_ctrl(p.pid, {"mode": "wait", "icon": "😅", "title": "Megúsztad!", "text": "A villám a másik pódiumba csapott."})
						continue
					any = true
					lost[p.pid] = true
					lives[p.pid] = int(lives[p.pid]) - 1
					Net.vibrate(p.pid, [200, 80, 200])
					if int(lives[p.pid]) <= 0:
						out_round[p.pid] = round_i
						Net.set_ctrl(p.pid, {"mode": "wait", "icon": "💔", "title": "Kiestél!", "text": "Elfogyott az életed."})
					else:
						Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⚡", "title": "Eltalált a villám!", "text": "Még %d életed maradt." % int(lives[p.pid])})
				if not any:
					Audio.play("coin")
		"strike":
			if phase_t >= 3.0:
				_next()


func ranking() -> Array:
	return rank_by(_score, _label)


func _score(p) -> float:
	var l := int(lives[p.pid])
	return l * 100.0 + 50.0 if l > 0 else float(out_round.get(p.pid, 0))


func _label(p) -> String:
	var l := int(lives[p.pid])
	return "❤️".repeat(l) if l > 0 else "kiesett (%d. kör)" % int(out_round.get(p.pid, 0))


## A felhő vízszintes helye: választás alatt középen lebeg, a feszült részben ide-oda cikázik, végül a kiszemelt pódium fölé áll.
func _cloud_x() -> float:
	match phase:
		"suspense":
			var k: float = clamp((phase_t - 1.7) / 0.7, 0.0, 1.0)
			return lerpf(640.0 + sin(phase_t * 5.5) * 300.0, PX[doomed], D.ease_in_out(k))
		"strike":
			return PX[doomed]
	return 640.0 + sin(Main.I.time * 1.3) * 40.0


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#1e293b"), Color("#020617"))
	for i in 40:
		var rx := fmod(i * 97.0 + Main.I.time * 260.0, 1380.0) - 50.0
		var ry := fmod(i * 61.0 + Main.I.time * 700.0, 720.0)
		c.draw_line(Vector2(rx, ry), Vector2(rx - 8, ry + 22), Color(0.7, 0.8, 1, 0.22), 2)
	D.text(c, "🌩️ Villámfelhő", 170, 40, {"size": 28, "stroke": D.DARK, "sw": 6})
	D.text(c, "%d. / %d kör" % [clampi(round_i, 1, MAX_ROUNDS), MAX_ROUNDS], 1160, 40, {"size": 22, "color": Color("#dddddd")})
	var head := ""
	match phase:
		"pick": head = "Bal vagy jobb? Válassz a telefonodon!"
		"walk": head = "Mindenki beállt…"
		"suspense": head = "Hová csap a villám?! ⚡"
		"strike": head = "A %s pódium leszakadt!" % ("BAL" if doomed == 0 else "JOBB")
	D.text(c, head, 640, 40, {"size": 28, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 6})
	if phase == "pick":
		var k: float = max(0.0, 1.0 - phase_t / PICK_TIME)
		D.panel(c, 440, 66, 400, 10, {"r": 5, "fill": Color(1, 1, 1, 0.15), "stroke": null, "shadow": false})
		if k > 0.02:
			D.panel(c, 440, 66, 400 * k, 10, {"r": 5, "fill": Color("#ff6b6b") if k < 0.3 else Color("#69db7c"), "stroke": null, "shadow": false})
	# a leszakadó pódium és a rajta állók ennyit zuhannak
	var drop := 0.0
	if phase == "strike":
		drop = min(360.0, pow(max(0.0, phase_t - 0.25), 2.0) * 900.0)
	for s in 2:
		var dy := drop if (phase == "strike" and s == doomed) else 0.0
		var x: float = PX[s]
		c.draw_rect(Rect2(x - 26, PY + 34 + dy, 52, 130), Color("#44403c"))
		D.panel(c, x - 210, PY + dy, 420, 44, {"r": 14, "fill": Color("#a16207"), "stroke": Color("#451a03"), "lw": 4})
		for k in 5:
			c.draw_line(Vector2(x - 210 + (k + 1) * 70, PY + 6 + dy), Vector2(x - 210 + (k + 1) * 70, PY + 38 + dy), Color("#78350f"), 3)
		D.text(c, "BAL" if s == 0 else "JOBB", x, PY + 22 + dy, {"size": 22, "color": Color("#fff3bf"), "stroke": D.DARK, "sw": 5})
	# játékosok: választás alatt középen várnak, aztán a pódiumukra sétálnak
	var n := players.size()
	var idx := [0, 0]
	var tot := [0, 0]
	for p in players:
		if side.has(p.pid) and phase != "pick":
			tot[side[p.pid]] += 1
	for i in n:
		var p = players[i]
		var dead: bool = int(lives[p.pid]) <= 0 and not lost.has(p.pid)
		var wx := 640 + (i - (n - 1) / 2.0) * 62.0
		var wy := 330.0
		var x := wx
		var y := wy
		if dead:
			continue
		if phase != "pick" and side.has(p.pid):
			var s: int = side[p.pid]
			var tx: float = PX[s] + (idx[s] - (tot[s] - 1) / 2.0) * min(74.0, 380.0 / max(1, tot[s]))
			idx[s] += 1
			var k: float = D.ease_in_out(clamp(phase_t / 1.0, 0.0, 1.0)) if phase == "walk" else 1.0
			x = lerpf(wx, tx, k)
			y = lerpf(wy, PY - 34, k) - (abs(sin(k * PI * 3.0)) * 14.0 if phase == "walk" else 0.0)
			if phase == "strike" and s == doomed:
				y += drop
		D.avatar(c, p, x, y, 32, {"shadow": phase != "strike" or side.get(p.pid, -1) != doomed})
		if phase == "pick" and side.has(p.pid):
			D.text(c, "✔", x + 24, y - 28, {"size": 22, "color": Color("#69db7c"), "stroke": D.DARK, "sw": 5})
		if phase == "strike" and lost.has(p.pid) and phase_t < 1.2:
			D.text(c, "−1 ❤️", x, y - 54, {"size": 26, "color": Color("#ff8787"), "stroke": D.DARK, "sw": 6})
	# felhő + villám
	var cx := _cloud_x()
	var cy := 150.0 + sin(Main.I.time * 2.0) * 6.0
	var dark := Color("#475569") if phase == "pick" else Color("#334155")
	for b in [[-70, 10, 46], [-30, -18, 58], [26, -12, 62], [74, 12, 44], [0, 18, 60]]:
		c.draw_circle(Vector2(cx + b[0], cy + b[1]), b[2], dark)
	D.emoji(c, "😠" if phase != "pick" else "😴", cx, cy + 4, 46)
	if phase == "suspense" and fmod(phase_t, 0.5) < 0.08:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.12))
	if phase == "strike" and phase_t < 0.45:
		var pts := PackedVector2Array()
		var zig := [0.0, -34.0, 26.0, -22.0, 30.0, -12.0, 0.0]
		for k in zig.size():
			pts.append(Vector2(cx + zig[k], lerpf(cy + 50, PY, float(k) / (zig.size() - 1))))
		c.draw_polyline(pts, Color("#fff3bf"), 14, true)
		c.draw_polyline(pts, Color.WHITE, 6, true)
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.55 * (1.0 - phase_t / 0.45)))
	# alul: életek
	var gap: float = min(200.0, 1220.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		var l := int(lives[p.pid])
		var tix := team_of(p)
		D.panel(c, x - gap / 2 + 6, 640, gap - 12, 70, {"r": 16, "fill": Color(0.03, 0.04, 0.1, 0.85), "stroke": MgFlow.TEAM_COLORS[tix] if tix >= 0 else p.color, "shadow": false})
		D.avatar(c, p, x - gap / 2 + 38, 675, 20, {"shadow": false, "gray": l <= 0})
		D.text(c, p.name, x + 14, 660, {"size": 14, "color": Color("#dddddd"), "maxw": gap - 80})
		D.text(c, "❤️".repeat(l) + "🖤".repeat(LIVES - l), x + 14, 688, {"size": 20})
