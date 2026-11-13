class_name MountainScene
extends GameScene
## Hegymászás: egy kör = minijáték, majd a helyezések sorrendjében dobás a kiosztott kockákkal.
## Büntető-, hátszél- és jégmezők, három akadály (külön kockával 4-5-6 kell), cél a csúcs.

const ML = preload("res://scripts/world/mountain_layout.gd")
const DIE_COLORS := {6: ["#ffffff", "#5b3fb5"], 4: ["#a5d8ff", "#1c4f8a"], 2: ["#ffd8a8", "#a3470b"]}
const GATE_DIE := ["#2b2140", "#ffd43b"]
const GATE_INFO := {
	"wall": {"icon": "🧱", "name": "Téglafal", "how": "be kell ütni", "win": "beütötte a falat", "fail": "A fal meg se rezdült"},
	"cannon": {"icon": "💣", "name": "Bástya", "how": "az ágyúval kell szétlőni", "win": "szétlőtte a bástyát", "fail": "Az ágyú nem sült el"},
	"yeti": {"icon": "😴", "name": "Alvó jeti", "how": "hógolyóval kell felébreszteni", "win": "felébresztette a jetit", "fail": "A jeti horkol tovább"},
}
const CHASERS := ["bear", "rocks", "snow"]
const PENALTY_TEXT := [
	["🐻 Medve az úton!", "ijedtében visszafut"],
	["🪨 Kőomlás!", "visszasodorja a görgeteg"],
	["🌨️ Lavina!", "lecsúszik a havon"],
]

var intro := false
var m3: Mountain3D
var L: Dictionary
var hops := {}               # pid -> {from, to, t0, dur, height}
var jumps := {}              # pid -> {a, b, t0, dur, height}: szabad ugrás két világpont között
var perch := {}              # pid -> Vector3: a bábu az útról letérve itt áll (pl. az ágyún)
var chaser = null            # {node, s, follow, gap, anim}: medve / kőomlás / lavina a büntetőmezőn
var wind_p = null            # akit épp a hátszél tol
var gate_tried := false      # a mostani lépéssorozatban próbálkozott-e már akadállyal
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
		# a kocka mindig előtérben van: semmi nem takarhatja ki
		m.no_depth_test = true
		m.render_priority = 20
		cube.material_override = m
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			face.no_depth_test = true
			face.double_sided = false
			face.render_priority = 21
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
		await toast("🚧 3 akadály állja az utat", "Téglafal, ágyús bástya és egy alvó jeti. Mindegyiknél külön kockával dobsz: 4, 5 vagy 6 kell. Ha sikerül, a maradék lépéseiddel mehetsz is tovább, és az út mindenkinek szabad marad.", 6.0)
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
	# ha akadály előtt áll, előbb azt kell legyőznie a külön kockával
	var gate = closed_gate(p.node)
	if gate != null and not await try_gate(p, gate):
		Net.push_status(p.pid)
		await sleep(0.4)
		return
	var vals: Array = await roll(p, "Koppints a dobáshoz!")
	var total := 0
	for v in vals:
		total += v
	if vals.size() > 1:
		var parts := PackedStringArray()
		for v in vals: parts.append(str(v))
		await toast("%s = %d" % [" + ".join(parts), total], "lépés", 1.1)
	m3.cam_follow(p.pid, "near", 3.5)
	await move(p, total)
	if G.mtn_winner == null:
		await land(p)
	Net.push_status(p.pid)
	await sleep(0.5)


## Akadály: külön kockával dob, 4-5-6-ra legyőzi. Igaz, ha sikerült (ilyenkor mehet tovább).
func try_gate(p, g: Dictionary) -> bool:
	gate_tried = true
	var info: Dictionary = GATE_INFO[g.kind]
	m3.cam_side = -0.5     # hátulról, ferdén látszik az akadály és a bábu is
	m3.cam_node(g.node + 0.3, "close", 3)
	var sub := "%s külön kockával dob – %s: 4, 5 vagy 6 kell" % [p.name, info.how]
	if steps_left > 0:
		sub += ". Ha sikerül, mehet tovább a maradék %d lépéssel!" % steps_left
	await toast("%s %s" % [info.icon, info.name], sub, 2.3, p)
	var v: int = (await roll(p, "4, 5 vagy 6 kell!", [6], true))[0]
	print_verbose("[mtn] akadály-dobás: %s @%d (%s) -> %d" % [p.name, g.node, g.kind, v])
	if v >= ML.GATE_PASS:
		await open_gate(g, p)
		m3.cam_side = 0.16
		return true
	m3.gate_fail(g.node)
	m3.emote(p.pid, "sad")
	Audio.play("fail")
	Net.vibrate(p.pid, [60, 40, 60])
	await toast("%s %s" % [info.icon, info.fail], "%d lett, pedig 4, 5 vagy 6 kellett. A következő körben újra próbálhatja!" % v, 2.0, p)
	m3.cam_side = 0.16
	return false


## magyar tárgyrag számokhoz: 5-öt, 6-ot, 8-at
func _rag(n: int) -> String:
	return {1: "et", 2: "t", 3: "at", 4: "et", 5: "öt", 6: "ot", 7: "et", 8: "at", 9: "et", 10: "et", 11: "et", 12: "t"}.get(n, "t")


func roll(p, hint: String, sides_in = null, gate := false) -> Array:
	m3.cam_follow(p.pid, "close", 3)
	var sides: Array = sides_in if sides_in != null else p.dice.duplicate()
	if sides.is_empty():
		sides = [6]
	dice = {"p": p, "sides": sides, "vals": [], "rolling": true, "next": 0.0, "hit_t": 0.0, "gate": gate}
	for i in sides.size():
		dice.vals.append(1)
	_dice_randomize()
	for i in dice_blocks.size():
		var b: Dictionary = dice_blocks[i]
		b.root.visible = i < sides.size()
		if i < sides.size():
			var cols: Array = GATE_DIE if gate else DIE_COLORS.get(int(sides[i]), DIE_COLORS[6])
			_die_color(b, cols[0])
			for l in b.labels:
				(l as Label3D).modulate = Color(cols[1])
	var label := "🚧 AKADÁLY-KOCKA!" if gate else ("🎲 DOBJ!" if sides.size() == 1 else "🎲🎲 DOBJ!")
	await Net.ask(p.pid, {"mode": "tap", "label": label, "hint": hint, "botAuto": true}, ["tap"], 25)
	if not gate:
		m3.emote(p.pid, "happy")
	Audio.play("jump")
	await sleep(0.18)
	dice.rolling = false
	dice.hit_t = t
	if gate:
		# zöld, ha sikerült, piros, ha nem
		var ok: bool = dice.vals[0] >= ML.GATE_PASS
		_die_color(dice_blocks[0], "#2f9e44" if ok else "#e03131")
		for l in dice_blocks[0].labels:
			(l as Label3D).modulate = Color.WHITE
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


## A kocka színe: saját fénye is van, hogy árnyékban is ugyanolyan jól látsszon.
func _die_color(b: Dictionary, hex: String) -> void:
	var m: StandardMaterial3D = b.mat
	m.albedo_color = Color(hex)
	m.emission = Color(hex)
	m.emission_energy_multiplier = 0.5


func _dice_randomize() -> void:
	for i in dice.sides.size():
		var s := int(dice.sides[i])
		var v := randi_range(1, s)
		if s > 2:
			while v == dice.vals[i]:
				v = randi_range(1, s)
		dice.vals[i] = v


func move(p, steps: int, windy := false) -> void:
	steps_left = steps
	gate_tried = false
	while steps_left > 0 and p.node < L.goal:
		var g = closed_gate(p.node)
		if g != null:
			# akadályhoz ért, de lépne még: dobhat az akadály-kockával, és ha sikerül, megy tovább
			wind_p = null
			if not await try_gate(p, g):
				break
			m3.cam_follow(p.pid, "near", 3.5)
			if windy:
				wind_p = p
		if windy:
			await hop(p, p.node + 1, 0.2, 0.12)
		else:
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


## Szabad ugrás az útról egy tetszőleges pontra (stay: ott is marad, amíg vissza nem ugrik).
func jump_to(p, b: Vector3, dur: float, height: float, stay := true) -> void:
	var a: Vector3 = ground(p).pos
	jumps[p.pid] = {"a": a, "b": b, "t0": t, "dur": dur, "height": height}
	await sleep(dur)
	jumps.erase(p.pid)
	if stay:
		perch[p.pid] = b
	else:
		perch.erase(p.pid)


## Az út mentén hol tart épp a bábu (tört mezősorszám).
func cur_s(p) -> float:
	if hops.has(p.pid):
		var a: Dictionary = hops[p.pid]
		return lerpf(a.from, a.to, D.ease_in_out(min(1.0, (t - a.t0) / a.dur)))
	return float(p.node)


## Büntetőmező: megjelenik az üldöző (medve / kőomlás / lavina), és tényleg visszakergeti a bábut.
func chase_back(p, n: int, kind: String) -> void:
	var to: int = max(0, p.node - n)
	if to == p.node:
		return
	print_verbose("[mtn] büntető: %s @%d -> %d (%s)" % [p.name, p.node, to, kind])
	var c: Node3D = m3.make_chaser(kind)
	chaser = {"node": c, "s": p.node + 1.45, "follow": null, "gap": 1.2, "anim": null}
	m3.cam_follow(p.pid, "near", 3)
	Net.vibrate(p.pid, [60, 40, 60, 40, 120])
	if kind == "bear":
		# a medve előbukkan és ráijeszt, a bábu ijedtében nagyot ugrik, aztán futás!
		c.scale = Vector3.ONE * 0.01
		m3.place_chaser(c, chaser.s, 0.0)
		m3.chaser_scale(c, 1.0, 0.35)
		Audio.play("boom", 0.7)
		m3.shake = 0.5
		await sleep(0.3)
		await jump_to(p, ground(p).pos, 0.32, 0.7, false)
		await sleep(0.25)
		chaser.follow = p
		while p.node > to:
			await hop(p, p.node - 1, 0.16, 0.24)
		chaser.follow = null
		m3.emote(p.pid, "dizzy")
		await sleep(0.45)
		m3.chaser_scale(c, 0.01, 0.3)
		await sleep(0.32)
	else:
		# a görgeteg fentről robog le az úton, és magával sodorja a bábut
		chaser.s = p.node + 5.0
		chaser.anim = {"from": chaser.s, "to": p.node + 0.7, "t0": t, "dur": 0.75}
		Audio.play("whoosh", 0.7)
		await sleep(0.75)
		chaser.anim = null
		chaser.gap = 0.7
		chaser.follow = p
		m3.shake = 0.8
		Audio.play("hit")
		Audio.play("boom", 1.2)
		m3.emote(p.pid, "dizzy")
		var q := pawn_xy(p)
		Main.I.burst(q.x, q.y, {"n": 26, "colors": ["#ffffff", "#dfeaf5", "#a5d8ff"] if kind == "snow" else ["#8a8580", "#d9cfc1", "#6f6a66"], "speed": 340})
		await hop(p, to, 0.3 + 0.13 * (p.node - to), 0.25)
		chaser.follow = null
		chaser.anim = {"from": chaser.s, "to": chaser.s - 3.0, "t0": t, "dur": 0.55}
		m3.chaser_scale(c, 0.01, 0.55)
		await sleep(0.55)
	chaser = null
	c.queue_free()
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
			toast(txt[0], "%s %s: vissza %d mezőt!" % [p.name, txt[1], node.val], 2.6, p)
			await chase_back(p, node.val, CHASERS[ML.zone(p.node)])
			await sleep(0.4)
		"F":
			p.stats.events += 1
			Audio.play("sparkle")
			Audio.play("whoosh")
			var q := pawn_xy(p)
			Main.I.float_text(q.x, q.y - 40, "+%d" % node.val, Color("#8ce99a"), 40)
			toast("💨 Hátszél!", "A szél előrefújja: %s még %d mezőt repül!" % [p.name, node.val], 2.4, p)
			print_verbose("[mtn] hátszél: %s @%d +%d" % [p.name, p.node, node.val])
			# feltámad a szél, aztán tényleg előretolja a bábut
			wind_p = p
			m3.cam_follow(p.pid, "close", 3.5)
			await sleep(0.75)
			await move(p, node.val, true)
			await sleep(0.25)
			wind_p = null
			if G.mtn_winner == null and closed_gate(p.node) != null and not gate_tried:
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
			if closed_gate(p.node) != null and not gate_tried:
				await _gate_notice(p)


func _gate_notice(p) -> void:
	var g = closed_gate(p.node)
	var info: Dictionary = GATE_INFO[g.kind]
	m3.cam_node(g.node + 0.5, "close", 2.5)
	Audio.play("hit")
	await toast("%s %s állja az utat!" % [info.icon, info.name], "%s a következő körében külön kockával dob: 4, 5 vagy 6 kell, hogy továbbmehessen." % p.name, 2.6, p)


## Az akadály legyőzése – mindegyiknek saját jelenete van.
func open_gate(g: Dictionary, p) -> void:
	g.open = true
	print_verbose("[mtn] akadály legyőzve: %d %s (%s)" % [g.node, g.kind, p.name])
	p.stats.events += 1
	var info: Dictionary = GATE_INFO[g.kind]
	var tile: Vector3 = ML.pos(g.node)
	m3.cam_node(g.node + 0.4, "close", 3)
	match g.kind:
		"wall":
			# nekifutás hátralépéssel, aztán egy nagy ütés: a fal tégláira hullik
			await jump_to(p, m3.gate_point(g.node, Vector3(-1.5, 0, 0)), 0.25, 0.2)
			await sleep(0.2)
			jump_to(p, m3.gate_point(g.node, Vector3(-0.45, 0, 0)), 0.13, 0.3)
			Audio.play("whoosh", 1.3)
			await sleep(0.12)
			m3.break_wall(g.node, 1.0)
			Audio.play("boom")
			Audio.play("hit")
			await sleep(0.45)
			await jump_to(p, tile, 0.3, 0.35, false)
		"cannon":
			# felugrik az ágyúra, ég a kanóc… BUMM, és a bástyának vége
			await jump_to(p, m3.cannon_perch(g.node), 0.45, 1.2)
			Audio.play("land")
			m3.cannon_light(g.node)
			for i in 4:
				Audio.play("step", 1.5 + i * 0.15)
				await sleep(0.2)
			m3.cannon_fire(g.node)
			Audio.play("boom", 0.8)
			jump_to(p, m3.cannon_perch(g.node), 0.4, 0.8)
			await sleep(0.18)
			Audio.play("boom")
			await sleep(0.7)
			await jump_to(p, tile, 0.42, 0.9, false)
		_:
			# hógolyó az orrára: a jeti felriad, és kiül a párkányra
			var a: Vector3 = ground(p).pos + Vector3(0, 0.9, 0)
			jump_to(p, ground(p).pos, 0.3, 0.45, false)
			m3.throw_ball(a, m3.yeti_head(g.node), 0.45, 0.9)
			Audio.play("whoosh")
			await sleep(0.45)
			Audio.play("hit")
			m3.yeti_wake(g.node)
			await sleep(0.45)
			Audio.play("boom", 0.8)
			await sleep(1.2)
			Audio.play("land")
	Audio.play("fanfare")
	Net.vibrate(p.pid, [80, 60, 80, 60, 200])
	m3.emote(p.pid, "cheer")
	var q := m3.project(ML.pos(g.node + 0.5) + Vector3(0, 1.4, 0))
	Main.I.burst(q.x, q.y, {"n": 60, "colors": ["#ffd43b", "#ffffff", "#f59e0b", p.color_hex], "speed": 480})
	await toast("🎉 %s %s!" % [p.name, info.win], "Az út mostantól mindenkinek szabad", 2.2, p)


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
	if jumps.has(p.pid):
		var j: Dictionary = jumps[p.pid]
		var jk: float = min(1.0, (t - j.t0) / j.dur)
		return {"pos": (j.a as Vector3).lerp(j.b, D.ease_in_out(jk)), "h": sin(jk * PI) * j.height}
	if perch.has(p.pid):
		return {"pos": perch[p.pid], "h": 0.0}
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
	if chaser:
		var c: Dictionary = chaser
		var prev: float = c.s
		if c.follow != null:
			c.s = min(c.s, cur_s(c.follow) + c.gap)
		elif c.anim != null:
			c.s = lerpf(c.anim.from, c.anim.to, clamp((t - c.anim.t0) / c.anim.dur, 0.0, 1.0))
		m3.place_chaser(c.node, c.s, prev - c.s)
	if wind_p != null:
		m3.wind_at(ground(wind_p).pos, min(cur_s(wind_p), float(ML.SPIRAL_N - 1)))
	else:
		m3.wind_at(Vector3.ZERO, 0.0, false)
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
		if dice.gate:
			txt = "🚧 akadály-kocka: 4 · 5 · 6 kell"
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
			D.emoji(c, GATE_INFO[g.kind].icon, x - 40, gy, 17)
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
