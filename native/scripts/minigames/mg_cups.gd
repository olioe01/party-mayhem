extends Minigame
## Pohárkeverő (3D) – egy labda kerül az egyik pohár alá, aztán két kéz összekeveri a poharakat.
## A telefonon kell megnyomni, melyik pohár alatt van. 5 kör, egyre gyorsabban, egyre több pohárral.

const ROUNDS := 5
const CUPS := [3, 4, 4, 5, 6]
const SWAPS := [4, 6, 8, 10, 13]
const SWAP_DUR := [0.62, 0.5, 0.42, 0.34, 0.27]
const GAP := 2.15
const PICK_LIMIT := 8.0
const SHOW_T := 2.6
const REVEAL_T := 3.2

var round_i := -1
var phase := "pre"           # show | shuffle | pick | reveal
var phase_t := 0.0
var cups: Array = []         # {node, slot, x, z, lift}
var ball: Node3D
var ball_cup := 0            # melyik pohár alatt van (index a cups tömbben)
var swaps_left := 0
var swap = null              # {a, b, t, dur, ax, bx}
var hands: Array = []
var picks := {}              # pid -> {slot, time}
var score := {}              # pid -> jó válaszok száma
var total_time := {}
var bots := {}               # pid -> {at, slot}
var table: Node3D


func meta() -> Dictionary:
	return {"id": "cups", "name": "Pohárkeverő", "icon": "🥤", "color": "#e03131", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Hol a labda?",
		"desc": "Egy labda kerül az egyik pohár alá, aztán két kéz jól összekeveri a poharakat. Kövesd a szemeddel, és nyomd meg a telefonodon, melyik pohár alatt van! 5 kör, egyre gyorsabb keveréssel és egyre több pohárral.",
		"controls": "Keverés közben csak figyelj. Utána a telefonodon a poharak balról jobbra számozva jelennek meg: koppints arra, amelyik alatt a labda van."}


func layout(_p) -> Dictionary:
	return {"mode": "wait", "icon": "👀", "title": "Figyeld a labdát!", "text": "A keverés után kell választanod."}


func _ready() -> void:
	make_env("#2b1055", "#7048e8", 0.75)
	make_camera(Vector3(0, 8.2, 11.6), Vector3(0, 0.7, 0.2), 45)
	make_sun(Vector3(-55, -20, 0), 1.2)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 11, 3)
	spot.rotation_degrees = Vector3(-72, 0, 0)
	spot.spot_angle = 42
	spot.spot_range = 24
	spot.light_energy = 5.0
	spot.light_color = Color("#fff3d6")
	add_child(spot)
	var M := Chars3D
	M.box(self, 80, 1.0, 60, M.mat("#1f1147", {"rough": 0.9}), Vector3(0, -2.6, 0))
	M.cyl(self, 9.6, 9.6, 0.5, M.mat("#8a5a2b", {"rough": 0.6}), 0, -0.26, 0, 56)
	M.cyl(self, 9.0, 9.0, 0.5, M.mat("#2f9e44", {"rough": 0.95}), 0, -0.24, 0, 56)
	M.cyl(self, 1.4, 2.4, 2.2, M.mat("#6b4a2b"), 0, -1.6, 0, 16)
	for i in 6:
		cups.append({"node": _make_cup(), "slot": i, "x": 0.0, "z": 0.0, "lift": 0.0, "used": false})
	ball = Node3D.new()
	add_child(ball)
	M.sphere(ball, 0.36, M.mat("#ffd43b", {"rough": 0.3, "emit": "#ffb000", "emit_e": 0.5}))
	ball.visible = false
	for i in 2:
		hands.append({"node": _make_hand(i == 0), "pos": Vector3((-1 if i == 0 else 1) * 7.5, 3.2, 2.5), "target": Vector3.ZERO, "busy": false})
	for p in players:
		score[p.pid] = 0
		total_time[p.pid] = 0.0
	_layout_cups(3)
	_sync(0.0)


func _make_cup() -> Node3D:
	var g := Node3D.new()
	add_child(g)
	var M := Chars3D
	M.cyl(g, 0.52, 0.76, 1.36, M.mat("#e03131", {"rough": 0.35}), 0, 0.68, 0, 28)
	var rim := MeshInstance3D.new()
	rim.mesh = M.torus(0.76, 0.05)
	rim.material_override = M.mat("#ffffff", {"rough": 0.4})
	rim.position.y = 0.05
	g.add_child(rim)
	M.cyl(g, 0.6, 0.63, 0.12, M.mat("#ffffff", {"rough": 0.4}), 0, 1.0, 0, 28)
	g.visible = false
	return g


func _make_hand(left: bool) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	var M := Chars3D
	var glove := M.mat("#ffffff", {"rough": 0.6})
	M.sphere(g, 0.5, glove, 0, 0, 0, 1.0, 0.55, 1.1)
	for i in 4:
		M.sphere(g, 0.17, glove, -0.33 + i * 0.22, -0.12, 0.5, 1.0, 1.0, 1.9)
	M.sphere(g, 0.18, glove, (0.5 if left else -0.5), -0.05, 0.1, 1.7, 1.0, 1.0)
	M.cyl(g, 0.34, 0.3, 0.5, M.mat("#4dabf7"), 0, 0.05, -0.75, 14, Vector3(PI / 2, 0, 0))
	M.cyl(g, 0.3, 0.3, 3.0, M.mat("#343a40"), 0, 0.05, -2.4, 12, Vector3(PI / 2, 0, 0))
	return g


func _slot_x(slot: int, n: int) -> float:
	return (slot - (n - 1) / 2.0) * GAP


func _n() -> int:
	return CUPS[clampi(round_i, 0, ROUNDS - 1)]


func _layout_cups(n: int) -> void:
	for i in cups.size():
		var c: Dictionary = cups[i]
		c.used = i < n
		c.slot = i
		c.x = _slot_x(i, n)
		c.z = 0.0
		c.lift = 0.0
		c.node.visible = c.used


func start() -> void:
	_next_round()


func _next_round() -> void:
	round_i += 1
	if round_i >= ROUNDS:
		finished = true
		return
	var n := _n()
	_layout_cups(n)
	ball_cup = randi() % n
	swaps_left = SWAPS[round_i]
	swap = null
	picks = {}
	bots = {}
	phase = "show"
	phase_t = 0.0
	ball.visible = true
	Audio.play("whoosh")
	for p in players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "👀", "title": "%d. kör – figyelj!" % (round_i + 1), "text": "%d pohár, kövesd a labdát a szemeddel!" % n})


func _start_swap() -> void:
	var n := _n()
	var a := randi() % n
	var b := (a + 1 + randi() % (n - 1)) % n
	# a távoli cseréket ritkítjuk, hogy követhető maradjon
	if abs(a - b) > 2 and randf() < 0.6:
		b = a + (1 if a + 1 < n else -1)
	var ca = null
	var cb = null
	for c in cups:
		if c.used and c.slot == a: ca = c
		if c.used and c.slot == b: cb = c
	var dur: float = SWAP_DUR[round_i] * (1.0 + abs(a - b) * 0.12)
	swap = {"a": ca, "b": cb, "t": 0.0, "dur": dur, "ax": _slot_x(a, n), "bx": _slot_x(b, n), "sa": a, "sb": b}
	swaps_left -= 1
	Audio.play("step", randf_range(0.8, 1.2))


func _start_pick() -> void:
	phase = "pick"
	phase_t = 0.0
	var n := _n()
	Audio.play("count_go")
	for p in players:
		Net.set_ctrl(p.pid, {"mode": "cups", "n": n, "title": "Melyik pohár alatt van?"})
		bots[p.pid] = {"at": randf_range(0.9, 3.2), "ok": randf() < 0.86 - round_i * 0.11}


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "cup" or phase != "pick" or picks.has(p.pid):
		return
	var v := clampi(int(msg.get("v", 0)), 0, _n() - 1)
	picks[p.pid] = {"slot": v, "time": phase_t}
	Audio.play("pop")
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🤞", "title": "%d. pohár" % (v + 1), "text": "Mindjárt kiderül…"})


func bot(p, _dt: float) -> void:
	if phase != "pick" or picks.has(p.pid) or not bots.has(p.pid):
		return
	var b: Dictionary = bots[p.pid]
	if phase_t < b.at:
		return
	var right: int = cups[ball_cup].slot
	var v := right
	if not b.ok:
		v = (right + 1 + randi() % (_n() - 1)) % _n()
	input(p, {"t": "cup", "v": v})


func update(dt: float) -> void:
	if phase == "pre":
		return
	phase_t += dt
	match phase:
		"show":
			if phase_t >= SHOW_T:
				phase = "shuffle"
				phase_t = 0.0
		"shuffle":
			if swap == null:
				if swaps_left > 0:
					_start_swap()
				elif phase_t > 0.0:
					_start_pick()
			else:
				swap.t += dt
				var k: float = min(1.0, swap.t / swap.dur)
				var e := D.ease_in_out(k)
				var cx: float = (swap.ax + swap.bx) / 2.0
				var rad: float = abs(swap.bx - swap.ax) / 2.0
				var dir: float = sign(swap.bx - swap.ax)
				# az egyik pohár elöl, a másik hátul kerüli meg a közös középpontot
				swap.a.x = cx - dir * cos(e * PI) * rad
				swap.a.z = sin(e * PI) * min(1.25, rad * 0.9)
				swap.b.x = cx + dir * cos(e * PI) * rad
				swap.b.z = -sin(e * PI) * min(1.25, rad * 0.9)
				if k >= 1.0:
					swap.a.slot = swap.sb
					swap.b.slot = swap.sa
					swap.a.x = swap.bx
					swap.b.x = swap.ax
					swap.a.z = 0.0
					swap.b.z = 0.0
					swap = null
					phase_t = 0.0
		"pick":
			var all_in := true
			for p in players:
				if not picks.has(p.pid):
					all_in = false
			if all_in or phase_t >= PICK_LIMIT:
				_reveal()
		"reveal":
			if phase_t >= REVEAL_T:
				_next_round()
	_sync(dt)


func _reveal() -> void:
	phase = "reveal"
	phase_t = 0.0
	var right: int = cups[ball_cup].slot
	Audio.play("fanfare")
	var any := false
	for p in players:
		if picks.has(p.pid) and picks[p.pid].slot == right:
			score[p.pid] += 1
			total_time[p.pid] += picks[p.pid].time
			any = true
			Net.vibrate(p.pid, [60, 40, 160])
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": "✅", "title": "Eltaláltad!", "text": "%d jó válasz eddig" % score[p.pid]})
		else:
			total_time[p.pid] += PICK_LIMIT
			Net.vibrate(p.pid, 60)
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": "❌", "title": "Nem ott volt!" if picks.has(p.pid) else "Lejárt az idő!", "text": "A %d. pohár alatt volt." % (right + 1)})
	var q := screen(Vector3(cups[ball_cup].x, 0.5, 0))
	Main.I.burst(q.x, q.y, {"n": 40 if any else 16, "colors": ["#ffd43b", "#ffffff", "#e03131"], "speed": 380})


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	var bc: Dictionary = cups[ball_cup]
	for i in cups.size():
		var c: Dictionary = cups[i]
		if not c.used:
			continue
		var want := 0.0
		if phase == "show" and i == ball_cup:
			# a pohár felemelve várja a labdát, aztán ráborul
			want = 2.0 if phase_t < SHOW_T - 0.9 else 0.0
		elif phase == "reveal":
			want = 2.0 if (i == ball_cup or phase_t > 0.9) else 0.0
		c.lift = lerpf(c.lift, want, min(1.0, dt * 9.0))
		var node: Node3D = c.node
		node.position = Vector3(c.x, c.lift, c.z)
		node.rotation.z = -c.lift * 0.12
	ball.position = Vector3(bc.x, 0.36, bc.z)
	if phase == "show" and phase_t < 0.7:
		# a labda bepottyan a helyére
		var k := phase_t / 0.7
		ball.position.y = 0.36 + (1.0 - k) * 4.0 + abs(sin(k * PI * 2.0)) * 0.3 * (1.0 - k)
	# kezek: keverés közben a mozgó poharakon, egyébként oldalt pihennek
	for i in hands.size():
		var h: Dictionary = hands[i]
		var rest := Vector3((-1 if i == 0 else 1) * 7.6, 3.0 + sin(Main.I.time * 2.0 + i) * 0.15, 2.6)
		var target := rest
		if swap != null:
			var c: Dictionary = swap.a if i == 0 else swap.b
			target = Vector3(c.x, 1.75, c.z + 0.1)
		elif phase == "shuffle":
			target = Vector3((-1 if i == 0 else 1) * 2.0, 2.6, 1.4)
		h.pos = (h.pos as Vector3).lerp(target, min(1.0, dt * (22.0 if swap != null else 6.0)))
		var node: Node3D = h.node
		node.position = h.pos
		node.rotation.y = (0.35 if i == 0 else -0.35) * (0.0 if swap != null else 1.0)


func ranking() -> Array:
	return rank_by(_rank_score, _rank_label)


## holtversenynél a gyorsabb válaszadó áll előrébb
func _rank_score(p) -> float:
	return float(score[p.pid]) + max(0.0, 1.0 - float(total_time[p.pid]) / (ROUNDS * PICK_LIMIT)) * 0.01


func _rank_label(p) -> String:
	return "%d / %d jó" % [score[p.pid], ROUNDS]


func draw(c: CanvasItem) -> void:
	var n := _n()
	D.panel(c, 440, 14, 400, 60, {"r": 30, "fill": Color(0, 0, 0, 0.5)})
	var title := "Figyeld a labdát! 👀"
	if phase == "shuffle": title = "Keverés… 🌀"
	elif phase == "pick": title = "Melyik alatt van? 📱"
	elif phase == "reveal": title = "Itt volt! 🎉"
	D.text(c, title, 640, 45, {"size": 30})
	D.text(c, "%d. / %d kör · %d pohár" % [clampi(round_i + 1, 1, ROUNDS), ROUNDS, n], 110, 36, {"size": 20, "color": Color("#dddddd"), "align": "left", "maxw": 300})
	if phase == "pick":
		D.timer_hud(c, PICK_LIMIT - phase_t, 1180, 40)
	if phase == "pick" or phase == "reveal":
		var right: int = cups[ball_cup].slot
		for s in n:
			var q := screen(Vector3(_slot_x(s, n), 0.0, 1.35))
			var good: bool = phase == "reveal" and s == right
			D.panel(c, q.x - 24, q.y - 24, 48, 48, {"r": 24, "fill": Color("#2f9e44") if good else Color(0.08, 0.05, 0.19, 0.9), "stroke": Color("#ffd43b"), "lw": 3, "shadow": false})
			D.text(c, str(s + 1), q.x, q.y, {"size": 26})
			# ki mit választott
			var k := 0
			for p in players:
				if not picks.has(p.pid) or picks[p.pid].slot != s:
					continue
				var ax: float = q.x + ((k % 3) - 1) * 34
				var ay: float = q.y + 52 + (k / 3) * 36
				k += 1
				if phase == "reveal":
					D.avatar(c, p, ax, ay, 15, {"shadow": false, "ring": Color("#8ce99a") if s == right else Color("#ff8787"), "gray": s != right})
	# pontok
	var m := players.size()
	var gap: float = min(150.0, 1180.0 / m)
	for i in m:
		var p = players[i]
		var x := 640 + (i - (m - 1) / 2.0) * gap
		var tix := team_of(p)
		var picked: bool = picks.has(p.pid)
		D.panel(c, x - gap / 2 + 6, 600, gap - 12, 108, {"r": 18, "fill": Color(0, 0, 0, 0.5), "stroke": MgFlow.TEAM_COLORS[tix] if tix >= 0 else p.color, "shadow": false})
		D.avatar(c, p, x, 632, 22, {"shadow": false, "alpha": 1.0 if (picked or phase != "pick") else 0.55})
		if phase == "pick" and picked:
			D.text(c, "✔", x + 24, 616, {"size": 22, "color": Color("#8ce99a"), "stroke": Color.BLACK, "sw": 4})
		D.text(c, p.name, x, 668, {"size": 15, "maxw": gap - 18})
		D.text(c, "%d ✓" % score[p.pid], x, 690, {"size": 19, "color": Color("#ffd43b")})
