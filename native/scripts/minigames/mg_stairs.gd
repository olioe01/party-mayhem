extends Minigame
## Lépcsőverseny – mindenki titokban választ egy számot. Akinek a számát más nem választotta,
## annyi lépcsőt léphet fel. Legfeljebb 4 játékossal kerül sorra (a meta "max_players" kulcsa miatt).

const GOAL := 12
const MAX_ROUNDS := 8
const NUMS := [1, 2, 3, 4, 5]
const PICK_TIME := 8.0
const SX := 150.0            # a lépcső bal széle
const SW := 76.0             # egy fok szélessége
const SY := 590.0            # a legalsó fok teteje
const SH := 34.0             # egy fok magassága

var height := {}
var shown := {}              # a kirajzolt (animált) magasság
var pick := {}
var unique := {}
var bot_at := {}
var round_i := 0
var phase := "pre"
var phase_t := 0.0
var applied := false


func meta() -> Dictionary:
	return {"id": "stairs", "name": "Lépcsőverseny", "icon": "📶", "color": "#f472b6", "modes": ["ffa"], "max_players": 4,
		"tagline": "Gondolj másra, mint a többiek!",
		"desc": "Minden körben mindenki titokban választ egy számot 1 és 5 között. Ha a számodat senki más nem választotta, annyi lépcsőfokot léphetsz fel. Ha más is ugyanazt választotta, mindketten a helyeteken maradtok! Az nyer, aki először ér fel a %d. fokra, vagy %d kör után a legmagasabban áll." % [GOAL, MAX_ROUNDS],
		"controls": "Koppints egy számra. A nagy szám többet ér, de arra mások is vágynak…"}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "📶", "title": "Lépcsőverseny", "text": "Mindjárt választhatsz!"}


func _ready() -> void:
	for p in players:
		height[p.pid] = 0
		shown[p.pid] = 0.0


func start() -> void:
	_next()


func _next() -> void:
	round_i += 1
	phase = "pick"
	phase_t = 0.0
	applied = false
	pick = {}
	unique = {}
	var opts: Array = []
	for v in NUMS:
		opts.append({"label": "📶 %d" % v})
	for p in players:
		bot_at[p.pid] = randf_range(1.0, 4.0)
		Net.set_ctrl(p.pid, {"mode": "choice", "title": "Hány fokot lépnél?", "text": "Csak akkor léphetsz, ha más nem választja ugyanezt!", "options": opts})


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "choice" or phase != "pick" or pick.has(p.pid):
		return
	var v: int = NUMS[clampi(int(msg.get("v", 0)), 0, NUMS.size() - 1)]
	pick[p.pid] = v
	Audio.play("pop")
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🤫", "title": "A számod: %d" % v, "text": "Reméljük, más nem ezt választotta…"})


func bot(p, _dt: float) -> void:
	if phase == "pick" and not pick.has(p.pid) and phase_t >= float(bot_at[p.pid]):
		var v: int = [1, 2, 3, 3, 4, 4, 5, 5].pick_random()
		input(p, {"t": "choice", "v": v - 1})


func update(dt: float) -> void:
	for p in players:
		shown[p.pid] = move_toward(float(shown[p.pid]), float(height[p.pid]), dt * 5.0)
	if phase == "pre":
		return
	phase_t += dt
	if phase == "pick":
		if pick.size() >= players.size() or phase_t >= PICK_TIME:
			var count := {}
			for p in players:
				if not pick.has(p.pid):
					pick[p.pid] = 0
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⌛", "title": "Lekésted!", "text": "Ebben a körben nem lépsz."})
				count[pick[p.pid]] = int(count.get(pick[p.pid], 0)) + 1
			for p in players:
				unique[p.pid] = int(pick[p.pid]) > 0 and int(count[pick[p.pid]]) == 1
			phase = "reveal"
			phase_t = 0.0
			Audio.play("bell")
	elif phase == "reveal":
		if not applied and phase_t >= 1.5:
			applied = true
			var any := false
			for p in players:
				if unique[p.pid]:
					any = true
					height[p.pid] = min(GOAL, int(height[p.pid]) + int(pick[p.pid]))
					Net.vibrate(p.pid, 60)
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "📶", "title": "+%d fok!" % int(pick[p.pid]), "text": "Most a %d. fokon állsz." % int(height[p.pid])})
				elif int(pick[p.pid]) > 0:
					Net.vibrate(p.pid, [120, 60, 120])
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "💥", "title": "Ütközés!", "text": "Más is a %d-t választotta, maradsz." % int(pick[p.pid])})
			Audio.play("jump" if any else "bad")
		if phase_t >= 3.8:
			var top := 0
			for p in players:
				top = max(top, int(height[p.pid]))
			if top >= GOAL or round_i >= MAX_ROUNDS:
				finished = true
			else:
				_next()


func ranking() -> Array:
	return rank_by(func(p): return float(height[p.pid]), func(p): return "%d. fok" % int(height[p.pid]))


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#4c1d95"), Color("#1e1035"))
	D.text(c, "📶 Lépcsőverseny", 190, 40, {"size": 28, "stroke": D.DARK, "sw": 6})
	D.text(c, "%d. / %d kör" % [clampi(round_i, 1, MAX_ROUNDS), MAX_ROUNDS], 1160, 40, {"size": 22, "color": Color("#dddddd")})
	var head := ""
	match phase:
		"pick": head = "Válassz egy számot a telefonodon! 🤫"
		"reveal": head = "Akinek egyedi a száma, az léphet!"
	D.text(c, head, 640, 40, {"size": 28, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 6})
	if phase == "pick":
		var k: float = max(0.0, 1.0 - phase_t / PICK_TIME)
		D.panel(c, 440, 66, 400, 10, {"r": 5, "fill": Color(1, 1, 1, 0.15), "stroke": null, "shadow": false})
		if k > 0.02:
			D.panel(c, 440, 66, 400 * k, 10, {"r": 5, "fill": Color("#ff6b6b") if k < 0.3 else Color("#69db7c"), "stroke": null, "shadow": false})
	# a lépcső: balról jobbra emelkedik, a tetején a cél
	for i in GOAL + 1:
		var x := SX + i * SW
		var y := SY - i * SH
		var col := Color("#f472b6").lerp(Color("#ffd43b"), float(i) / GOAL)
		c.draw_rect(Rect2(x, y, SW + 1, 720 - y), D.shade(col, -0.35))
		c.draw_rect(Rect2(x, y, SW + 1, 9), col)
		D.text(c, str(i), x + SW / 2, y + 26, {"size": 16, "color": Color(1, 1, 1, 0.55)})
	D.emoji(c, "🏁", SX + GOAL * SW + SW / 2, SY - GOAL * SH - 96, 44)
	var n := players.size()
	for i in n:
		var p = players[i]
		var s: float = shown[p.pid]
		var moving: bool = abs(s - float(height[p.pid])) > 0.01
		var hop: float = abs(sin(s * PI)) * 22.0 if moving else 0.0
		var x := SX + s * SW + SW / 2 + (i - (n - 1) / 2.0) * 15.0
		var y: float = SY - s * SH - 30 - hop - i * 3
		D.avatar(c, p, x, y, 26, {"shadow": false})
		if phase == "pick" and pick.has(p.pid):
			D.text(c, "✔", x + 20, y - 26, {"size": 22, "color": Color("#69db7c"), "stroke": D.DARK, "sw": 5})
		elif phase == "reveal":
			var v := int(pick[p.pid])
			var ok: bool = unique[p.pid]
			var by: float = y - 58 - (i % 2) * 34
			D.panel(c, x - 24, by - 20, 48, 40, {"r": 14, "fill": Color("#2f9e44") if ok else Color("#c92a2a"), "stroke": Color.WHITE, "lw": 3, "shadow": false})
			D.text(c, ("+%d" % v) if ok else (str(v) if v > 0 else "–"), x, by, {"size": 22})
	# alul: ki mit választott
	var gap: float = min(240.0, 1180.0 / n)
	for i in n:
		var p = players[i]
		var x := 640 + (i - (n - 1) / 2.0) * gap
		D.panel(c, x - gap / 2 + 6, 650, gap - 12, 60, {"r": 16, "fill": Color(0.08, 0.05, 0.19, 0.85), "stroke": p.color, "shadow": false})
		D.avatar(c, p, x - gap / 2 + 38, 680, 18, {"shadow": false})
		D.text(c, p.name, x - gap / 2 + 64, 668, {"size": 14, "align": "left", "color": Color("#dddddd"), "maxw": gap - 130})
		var st := "…"
		if phase == "reveal":
			st = ("✔ +%d" % int(pick[p.pid])) if unique[p.pid] else ("✖ %d" % int(pick[p.pid]) if int(pick[p.pid]) > 0 else "⌛")
		elif pick.has(p.pid):
			st = "🤫"
		D.text(c, st, x - gap / 2 + 64, 690, {"size": 18, "align": "left", "color": Color("#ffd43b")})
		D.text(c, "%d." % int(height[p.pid]), x + gap / 2 - 20, 680, {"size": 26, "align": "right", "color": Color("#ffd43b")})
