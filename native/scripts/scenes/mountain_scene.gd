class_name MountainScene
extends GameScene
## Hegymászás: egy kör = minijáték, majd a helyezések sorrendjében dobás a kiosztott kockákkal.
## Büntető-, hátszél- és jégmezők, közös kapuk (csak adott dobással nyílnak), cél a csúcs.

const ML = preload("res://scripts/world/mountain_layout.gd")
const DIE_COLORS := {6: ["#ffffff", "#5b3fb5"], 4: ["#a5d8ff", "#1c4f8a"], 2: ["#ffd8a8", "#a3470b"]}
const PENALTY_TEXT := [
	["🐻 Medve az úton!", "ijedtében visszafut"],
	["🪨 Kőomlás!", "visszasodorja a görgeteg"],
	["🌨️ Lavina!", "lecsúszik a havon"],
]

var intro := false
var m3: Mountain3D
var L: Dictionary
var hops := {}               # pid -> {from, to, t0, dur, height}
var current = null
var toast_obj = null
var dice = null              # {p, sides, vals, rolling, next, hit_t}
var dice_blocks: Array = []  # [{root, cube, labels}]
var steps_left := 0
var done := false


func _init(is_intro := false) -> void:
	intro = is_intro


func enter() -> void:
	G.phase = "board"
	Audio.music("board")
	L = G.mountain
	m3 = Mountain3D.get_for(L)
	if m3.get_parent():
		m3.get_parent().remove_child(m3)
	add_child(m3)
	m3.activate()
	_make_dice_blocks()
	for p in G.players:
		Net.push_status(p.pid)
	_run()


func exit() -> void:
	if m3 and m3.get_parent() == self:
		remove_child(m3)


func _make_dice_blocks() -> void:
	for k in 2:
		var root := Node3D.new()
		m3.add_child(root)
		var cube := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.72, 0.72, 0.72)
		cube.mesh = bx
		var m := StandardMaterial3D.new()
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color("#b197fc")
		m.emission_energy_multiplier = 0.2
		cube.material_override = m
		root.add_child(cube)
		var labels: Array = []
		var dirs := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
		for dv in dirs:
			var face := Label3D.new()
			face.text = "?"
			face.font = D.font
			face.font_size = 120
			face.pixel_size = 0.0036
			face.outline_size = 0
			face.position = dv * 0.37
			if dv.z < 0: face.rotation.y = PI
			elif dv.x > 0: face.rotation.y = PI / 2
			elif dv.x < 0: face.rotation.y = -PI / 2
			elif dv.y > 0: face.rotation.x = -PI / 2
			elif dv.y < 0: face.rotation.x = PI / 2
			cube.add_child(face)
			labels.append(face)
		root.visible = false
		dice_blocks.append({"root": root, "cube": cube, "labels": labels, "mat": m})


# ------------------------------------------------------------------ menet
func _run() -> void:
	for p in G.players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⛰️", "title": "Hegymászás", "text": "Figyeld a képernyőt!"})
	if intro:
		m3.cam_node(ML.GOAL, "mid")
		m3.cam_snap()
		Audio.jingle("start")
		after(1.4, func(): m3.cam_overview(0.7))
		await toast("⛰️ Hegymászás!", "%d mező vezet a csúcsra – aki először felér, az nyer!" % L.goal, 3.2)
		await toast("🎲 A kockákat a minijáték osztja", "1. hely: 2 kocka · 2.: kocka + 1–4 · 3.: kocka + 1–2 · utolsó: 1 kocka", 4.2)
		var g0: Dictionary = L.gates[0]
		m3.cam_node(g0.node, "mid", 1.6)
		await toast("🚧 %d kapu állja az utat" % L.gates.size(), "Meg kell állnod előtte. Akkor nyílik ki, ha valaki a kapu mezőjén állva legalább annyit dob, amennyi rá van írva – utána mindenkinek nyitva marad.", 5.2)
		m3.cam_overview(1.2)
		await toast("⬇️ Vigyázz a piros mezőkkel!", "Piros: vissza · zöld: előre · ❄️: kimaradsz egy dobásból", 3.4)
		await toast("🎮 Kezdjük egy minijátékkal!", "A helyezés dönti el, ki milyen kockákkal dob", 2.2)
		Main.I.set_scene(MgFlow.SelectScene.new())
		return
	m3.cam_overview()
	print_verbose("[mtn] kör %d: %s" % [G.round, ", ".join(G.players.map(func(p): return "%s=%d %s" % [p.name, p.node, str(p.dice)]))])
	await toast("%d. kör" % G.round, "A minijáték helyezései szerint dobtok", 1.8)
	var order: Array = G.mtn_order.filter(func(p): return G.players.has(p))
	for p in G.players:
		if not order.has(p):
			order.append(p)
	for p in order:
		await turn(p)
		if G.mtn_winner:
			break
	current = null
	if G.mtn_winner:
		await _win(G.mtn_winner)
		return
	G.round += 1
	m3.cam_overview()
	for p in G.players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🎮", "title": "Minijáték jön!", "text": "A helyezésed dönti el a kockáidat!"})
	await toast("🎮 Minijáték!", "Harcolj a jobb kockákért!", 1.5)
	Main.I.set_scene(MgFlow.SelectScene.new())


func closed_gate(id: int):
	var g = ML.gate_at(L, id)
	if g != null and not g.open:
		return g
	return null


func turn(p) -> void:
	current = p
	m3.cam_follow(p.pid, "near", 2.5)
	Audio.play("select")
	for q in G.players:
		if q != p:
			Net.set_ctrl(q.pid, {"mode": "wait", "char": p.char_id, "title": "%s következik" % p.name, "text": "Figyeld a képernyőt!"})
	await sleep(0.6)
	if p.frozen:
		p.frozen = false
		m3.emote(p.pid, "sad")
		Audio.play("bad")
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "❄️", "title": "Megfagytál!", "text": "Ebből a dobásból kimaradsz."})
		await toast("❄️ %s kimarad" % p.name, "Még kiolvad a jégből…", 1.8, p)
		return
	var gate = closed_gate(p.node)
	var hint := "Koppints a dobáshoz!"
	if gate != null:
		hint = "A kapuhoz legalább %d kell!" % gate.need
		await toast("🚧 Zárt kapu", "%s csak akkor megy tovább, ha legalább %d-%s dob" % [p.name, gate.need, _rag(gate.need)], 1.6, p)
	var vals: Array = await roll(p, hint)
	var total := 0
	for v in vals:
		total += v
	if vals.size() > 1:
		var parts := PackedStringArray()
		for v in vals: parts.append(str(v))
		await toast("%s = %d" % [" + ".join(parts), total], "lépés", 1.1)
	if gate != null:
		if total >= gate.need:
			await open_gate(gate, p)
		else:
			m3.emote(p.pid, "sad")
			Audio.play("fail")
			Net.vibrate(p.pid, [60, 40, 60])
			await toast("🔒 Zárva maradt", "%d kellett volna, de csak %d lett" % [gate.need, total], 1.8, p)
			return
	m3.cam_follow(p.pid, "near", 3.5)
	await move(p, total)
	if G.mtn_winner == null:
		await land(p)
	Net.push_status(p.pid)
	await sleep(0.5)


## magyar tárgyrag számokhoz: 5-öt, 6-ot, 8-at
func _rag(n: int) -> String:
	return {1: "et", 2: "t", 3: "at", 4: "et", 5: "öt", 6: "ot", 7: "et", 8: "at", 9: "et", 10: "et", 11: "et", 12: "t"}.get(n, "t")


func roll(p, hint: String) -> Array:
	m3.cam_follow(p.pid, "close", 3)
	var sides: Array = p.dice.duplicate()
	if sides.is_empty():
		sides = [6]
	dice = {"p": p, "sides": sides, "vals": [], "rolling": true, "next": 0.0, "hit_t": 0.0}
	for i in sides.size():
		dice.vals.append(1)
	_dice_randomize()
	for i in dice_blocks.size():
		var b: Dictionary = dice_blocks[i]
		b.root.visible = i < sides.size()
		if i < sides.size():
			var cols: Array = DIE_COLORS.get(int(sides[i]), DIE_COLORS[6])
			(b.mat as StandardMaterial3D).albedo_color = Color(cols[0])
			for l in b.labels:
				(l as Label3D).modulate = Color(cols[1])
	var label := "🎲 DOBJ!" if sides.size() == 1 else "🎲🎲 DOBJ!"
	await Net.ask(p.pid, {"mode": "tap", "label": label, "hint": hint, "botAuto": true}, ["tap"], 25)
	m3.emote(p.pid, "happy")
	Audio.play("jump")
	await sleep(0.18)
	dice.rolling = false
	dice.hit_t = t
	Audio.play("hit")
	Net.vibrate(p.pid, 80)
	m3.shake = 0.5
	var q := pawn_xy(p)
	Main.I.burst(q.x, q.y - 80, {"n": 22, "colors": ["#ffffff", p.color_hex, "#ffd43b"], "speed": 320})
	await sleep(1.1)
	for b in dice_blocks:
		b.root.visible = false
	var res: Array = dice.vals.duplicate()
	dice = null
	return res


func _dice_randomize() -> void:
	for i in dice.sides.size():
		var s := int(dice.sides[i])
		var v := randi_range(1, s)
		if s > 2:
			while v == dice.vals[i]:
				v = randi_range(1, s)
		dice.vals[i] = v


func move(p, steps: int) -> void:
	steps_left = steps
	while steps_left > 0 and p.node < L.goal:
		if closed_gate(p.node) != null:
			break
		await hop(p, p.node + 1)
		p.stats.steps += 1
		steps_left -= 1
	steps_left = 0
	Net.push_status(p.pid)
	if p.node >= L.goal:
		G.mtn_winner = p


func hop(p, to_id: int, dur := 0.28, height := 0.65) -> void:
	hops[p.pid] = {"from": float(p.node), "to": float(to_id), "t0": t, "dur": dur, "height": height}
	Audio.play("step", randf_range(0.95, 1.08))
	await sleep(dur)
	hops.erase(p.pid)
	p.node = to_id
	Audio.play("land")
	m3.flash_tile(to_id)


func slide_back(p, n: int) -> void:
	var to: int = max(0, p.node - n)
	if to == p.node:
		return
	m3.emote(p.pid, "dizzy")
	Audio.play("whoosh")
	Net.vibrate(p.pid, [60, 40, 60, 40, 120])
	await hop(p, to, 0.35 + 0.14 * (p.node - to), 0.2)
	Net.push_status(p.pid)


func land(p) -> void:
	m3.cam_follow(p.pid, "close", 2.5)
	var node: Dictionary = L.nodes[p.node]
	p.last_space = node.type
	match node.type:
		"P":
			p.stats.red += 1
			var txt: Array = PENALTY_TEXT[ML.zone(p.node)]
			Audio.play("bad")
			var q := pawn_xy(p)
			Main.I.float_text(q.x, q.y - 40, "−%d" % node.val, Color("#ff8787"), 40)
			await toast(txt[0], "%s %s: vissza %d mezőt!" % [p.name, txt[1], node.val], 1.9, p)
			m3.cam_follow(p.pid, "near", 3)
			await slide_back(p, node.val)
			await sleep(0.4)
		"F":
			p.stats.events += 1
			Audio.play("sparkle")
			var q := pawn_xy(p)
			Main.I.float_text(q.x, q.y - 40, "+%d" % node.val, Color("#8ce99a"), 40)
			Main.I.burst(q.x, q.y, {"n": 20, "colors": ["#8ce99a", "#ffffff", p.color_hex], "speed": 300})
			await toast("💨 Hátszél!", "%s előreszalad még %d mezőt!" % [p.name, node.val], 1.5, p)
			m3.cam_follow(p.pid, "near", 3.5)
			await move(p, node.val)
			if G.mtn_winner == null and closed_gate(p.node) != null:
				await _gate_notice(p)
		"X":
			p.stats.events += 1
			p.frozen = true
			m3.emote(p.pid, "sad")
			Audio.play("bell")
			Net.vibrate(p.pid, [200, 80, 200])
			var q := pawn_xy(p)
			Main.I.burst(q.x, q.y, {"n": 30, "colors": ["#a5d8ff", "#ffffff", "#74c0fc"], "speed": 260})
			await toast("❄️ Jégmező!", "%s megfagyott: kimarad a következő dobásából" % p.name, 2.0, p)
		"G":
			if closed_gate(p.node) != null:
				await _gate_notice(p)


func _gate_notice(p) -> void:
	var g = closed_gate(p.node)
	m3.cam_node(g.node + 0.5, "close", 2.5)
	Audio.play("hit")
	await toast("🚧 Zárt kapu!", "Itt mindenkinek meg kell állnia. A kapu mezőjén állva dobj legalább %d-%s, és kinyílik!" % [g.need, _rag(g.need)], 2.6, p)


func open_gate(g: Dictionary, p) -> void:
	g.open = true
	print_verbose("[mtn] kapu nyitva: %d (%s)" % [g.node, p.name])
	m3.cam_node(g.node + 0.5, "close", 3)
	await sleep(0.5)
	m3.open_gate(g.node)
	Audio.play("boom")
	Audio.play("fanfare")
	Net.vibrate(p.pid, [80, 60, 80, 60, 200])
	m3.emote(p.pid, "cheer")
	p.stats.events += 1
	var q := m3.project(ML.pos(g.node + 0.5) + Vector3(0, 1.4, 0))
	Main.I.burst(q.x, q.y, {"n": 60, "colors": ["#ffd43b", "#ffffff", "#f59e0b", p.color_hex], "speed": 480})
	await toast("🔓 %s kinyitotta a kaput!" % p.name, "Mostantól mindenki szabadon átmehet rajta", 2.4, p)


func _win(p) -> void:
	done = true
	print_verbose("[mtn] győztes: %s, %d. kör" % [p.name, G.round])
	current = p
	m3.cam_follow(p.pid, "close", 2.0)
	m3.emote(p.pid, "cheer")
	Audio.play("crown")
	Audio.jingle("crown")
	Main.I.confetti(140)
	Net.vibrate(p.pid, [100, 50, 100, 50, 300])
	for q in G.players:
		Net.set_ctrl(q.pid, {"mode": "wait", "icon": "🏔️", "title": "%s felért!" % p.name, "text": "Vége a játéknak!"})
	var q2 := pawn_xy(p)
	Main.I.burst(q2.x, q2.y, {"n": 80, "colors": ["#ffd43b", "#fff3bf", "#ffffff", p.color_hex], "speed": 520})
	after(1.3, func(): m3.emote(p.pid, "cheer"))
	await toast("🏔️ %s FELÉRT A CSÚCSRA!" % p.name, "%d kör alatt hódította meg a hegyet" % G.round, 3.6, p)
	G.phase = "final"
	Main.I.set_scene(FinalScene.new())


func toast(title: String, sub := "", dur := 1.6, p = null) -> void:
	toast_obj = {"title": title, "sub": sub, "t0": t, "dur": dur, "p": p}
	await sleep(dur)
	if toast_obj and toast_obj.title == title:
		toast_obj = null


# ------------------------------------------------------------------ pozíciók
## A bábu talppontja és ugrásmagassága.
func ground(p) -> Dictionary:
	if hops.has(p.pid):
		var a: Dictionary = hops[p.pid]
		var k: float = min(1.0, (t - a.t0) / a.dur)
		var e := D.ease_in_out(k)
		return {"pos": ML.pos(lerpf(a.from, a.to, e)), "h": sin(k * PI) * a.height}
	var here: Array = G.players.filter(func(q): return q.node == p.node and not hops.has(q.pid))
	var base := ML.pos(p.node)
	if here.size() <= 1:
		return {"pos": base, "h": 0.0}
	var i := here.find(p)
	var ang := float(i) / here.size() * TAU + PI / 2
	var spread := 0.36 + here.size() * 0.035
	var s: float = min(float(p.node), float(ML.SPIRAL_N - 1))
	return {"pos": base + ML.tangent(s) * cos(ang) * spread + ML.radial(s) * sin(ang) * spread * 0.8, "h": 0.0}


func pawn_xy(p) -> Vector2:
	var g := ground(p)
	return m3.project(g.pos + Vector3(0, g.h + 1.25, 0))


# ------------------------------------------------------------------ frissítés + rajz
func update(dt: float) -> void:
	var pawns: Array = []
	for p in G.players:
		var g := ground(p)
		pawns.append({"p": p, "pos": g.pos, "h": g.h, "current": p == current})
	m3.render({"pawns": pawns}, dt)
	if dice:
		if dice.rolling and t >= dice.next:
			_dice_randomize()
			dice.next = t + 0.07
			Audio.play("roll")
		var g := ground(dice.p)
		var n: int = dice.sides.size()
		var right := Vector3(cos(m3.cam_ang), 0, -sin(m3.cam_ang))
		var pop: float = 1.0 + 0.45 * max(0.0, 1.0 - (t - dice.hit_t) * 3.0) if not dice.rolling else 1.0
		for i in n:
			var b: Dictionary = dice_blocks[i]
			var root: Node3D = b.root
			var cube: MeshInstance3D = b.cube
			root.position = g.pos + Vector3(0, 2.25 + sin(t * 4.0 + i) * 0.07, 0) + right * (i - (n - 1) / 2.0) * 1.0
			if dice.rolling:
				cube.rotation = Vector3(t * 2.3 + i, t * 3.1 + i * 2.0, t * 1.7)
			else:
				cube.rotation = Vector3(-0.35, m3.cam_ang, 0)
			cube.scale = Vector3.ONE * pop
			for l in b.labels:
				(l as Label3D).text = str(dice.vals[i])


func draw(c: CanvasItem) -> void:
	if current and steps_left > 0 and dice == null:
		var q := pawn_xy(current)
		c.draw_circle(Vector2(q.x + 34, q.y - 6), 17, Color.WHITE)
		D.text(c, str(steps_left), q.x + 34, q.y - 5, {"size": 22, "color": Color("#2b1055")})
	if dice and dice.rolling:
		var q := pawn_xy(dice.p)
		var parts := PackedStringArray()
		for s in dice.sides:
			parts.append("🎲 1–%d" % int(s))
		var txt := "   +   ".join(parts)
		var w: float = max(150.0, D.text_width(txt, 22) + 36)
		D.panel(c, q.x - w / 2, q.y - 196, w, 40, {"r": 20, "fill": Color(0.08, 0.05, 0.19, 0.88), "shadow": false})
		D.text(c, txt, q.x, q.y - 176, {"size": 22, "color": Color("#ffe066")})
	for p in G.players:
		if p.frozen:
			var q := pawn_xy(p)
			D.emoji(c, "❄️", q.x, q.y - 14, 26)
	_draw_hud(c)
	_draw_progress(c)
	if toast_obj: _draw_toast(c)


func _draw_hud(c: CanvasItem) -> void:
	D.panel(c, 14, 8, 230, 44, {"r": 14, "fill": Color(0.094, 0.055, 0.22, 0.85)})
	D.text(c, "⛰️ %d. kör" % G.round, 129, 31, {"size": 23})
	if current and not done:
		var p = current
		D.panel(c, 490, 6, 300, 48, {"r": 24, "fill": D.shade(p.color, -0.45), "stroke": p.color})
		D.avatar(c, p, 516, 30, 17, {"shadow": false})
		D.text(c, "%s köre" % p.name, 652, 31, {"size": 24, "maxw": 250})
	var n := G.players.size()
	var cw: float = min(232.0, (1180.0 - (n - 1) * 8) / n)
	var x0 := 600.0 - (n * cw + (n - 1) * 8) / 2.0
	for i in n:
		var p = G.players[i]
		var cur: bool = p == current
		var x := x0 + i * (cw + 8)
		var y := 606.0 if cur else 616.0
		D.panel(c, x, y, cw, 98, {"r": 16, "fill": D.shade(p.color, -0.55), "stroke": Color("#ffd43b") if cur else p.color, "lw": 5 if cur else 3})
		D.avatar(c, p, x + 32, y + 36, 21, {"alpha": 1.0 if (p.connected or p.is_bot) else 0.4, "shadow": false})
		D.text(c, "%d." % G.place_of(p), x + 32, y + 78, {"size": 18, "color": Color("#ffd43b")})
		D.text(c, p.name, x + 60, y + 24, {"size": 19, "align": "left", "maxw": cw - 68})
		D.text(c, "⛰️ %d / %d" % [p.node, L.goal], x + 60, y + 53, {"size": 21, "align": "left", "color": Color("#ffe066"), "maxw": cw - 68})
		D.text(c, ("❄️ " if p.frozen else "") + G.dice_text(p.dice), x + 60, y + 80, {"size": 18, "align": "left", "maxw": cw - 68})
		if not p.connected and not p.is_bot:
			D.text(c, "📵", x + cw - 14, y + 22, {"size": 18})


## Jobb oldali magasságmérő: ki hol tart, és hol vannak a kapuk.
func _draw_progress(c: CanvasItem) -> void:
	var x := 1236.0
	var y0 := 590.0
	var y1 := 96.0
	D.panel(c, x - 30, y1 - 34, 60, y0 - y1 + 62, {"r": 22, "fill": Color(0.094, 0.055, 0.22, 0.8)})
	c.draw_line(Vector2(x, y0), Vector2(x, y1), Color(1, 1, 1, 0.35), 6, true)
	D.emoji(c, "🏆", x, y1 - 14, 22)
	for g in L.gates:
		var gy := lerpf(y0, y1, float(g.node) / L.goal)
		c.draw_line(Vector2(x - 16, gy), Vector2(x + 16, gy), Color("#8ce99a") if g.open else Color("#f59e0b"), 5, true)
		if not g.open:
			D.text(c, "%d+" % g.need, x - 36, gy, {"size": 15, "align": "right", "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 5})
	var by_node := {}
	for p in G.players:
		var s: float = float(p.node)
		if hops.has(p.pid):
			var a: Dictionary = hops[p.pid]
			s = lerpf(a.from, a.to, D.ease_in_out(min(1.0, (t - a.t0) / a.dur)))
		var k: int = by_node.get(p.node, 0)
		by_node[p.node] = k + 1
		var py := lerpf(y0, y1, s / L.goal)
		D.avatar(c, p, x + (k % 2) * 12 - (6 if k > 0 else 0) - (k / 2) * 14, py, 13, {"shadow": false, "ring": Color("#ffd43b") if p == current else null})


func _draw_toast(c: CanvasItem) -> void:
	var o: Dictionary = toast_obj
	var age: float = t - o.t0
	var s := D.ease_out_back(min(1.0, age * 4.0))
	var a: float = clamp((o.dur - age) * 5.0, 0.0, 1.0)
	var p = o.p
	c.draw_set_transform(Vector2(600, 150), 0, Vector2(s, s))
	var has_sub: bool = o.sub != ""
	var long_sub: bool = D.text_width(o.sub, 24) > 760
	var fill := Color(D.shade(p.color, -0.5), 0.94 * a) if p else Color(0.094, 0.055, 0.22, 0.94 * a)
	var stroke := Color(p.color, a) if p else Color(1, 0.83, 0.23, a)
	D.panel(c, -410, -78, 820, (190 if long_sub else 156) if has_sub else 110, {"fill": fill, "stroke": stroke, "lw": 5, "r": 28, "shadow": false})
	D.text(c, o.title, 0, -30 if has_sub else -23, {"size": 48, "stroke": D.DARK, "sw": 8, "maxw": 780, "alpha": a})
	if has_sub:
		if long_sub:
			D.wrap(c, o.sub, 0, 28, 770, 30, {"size": 23, "color": Color("#e5dbff"), "alpha": a, "align": "center"})
		else:
			D.text(c, o.sub, 0, 34, {"size": 24, "color": Color("#e5dbff"), "maxw": 780, "alpha": a})
	c.draw_set_transform(Vector2.ZERO)
