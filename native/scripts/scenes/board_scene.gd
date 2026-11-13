class_name BoardScene
extends GameScene
## A játéktábla: dobás (sima vagy saját kocka), lépés, korona, bolt, események,
## szövetségesek, sziget-események, rejtett dobozok, utolsó körös fordulat.

const NODE_R := 21.0

var intro := false
var b3: Board3D
var anim := {}               # pid -> {from, to, t0, dur, height}
var current = null
var toast_obj = null
var dice = null              # {p, val, coins, rolling, next, hit_t, label, faces}
var dice_block: Node3D
var dice_label: Label3D
var card = null
var shop_for = null
var fork_for = null
var steps_left := 0
var crown_anim = null
var wheel = null             # {opts, idx, spinning, t0, result}
var block_pop = null         # {node, kind, t0}
var order_rolls = null       # {pid: {val, done, t}} – kezdő sorrend-dobás


func _init(is_intro := false) -> void:
	intro = is_intro


func enter() -> void:
	G.phase = "board"
	Audio.music("board_final" if G.is_last_rounds() else "board")
	b3 = Board3D.get_for(G.board)
	if b3.get_parent():
		b3.get_parent().remove_child(b3)
	add_child(b3)
	b3.activate()
	b3.set_dusk(G.is_last_rounds())
	b3._dusk_now = b3.dusk
	for p in G.players:
		p.disp_coins = p.coins
	_make_dice_block()
	_run()


func exit() -> void:
	if b3 and b3.get_parent() == self:
		remove_child(b3)


func _make_dice_block() -> void:
	dice_block = Node3D.new()
	b3.add_child(dice_block)
	var cube := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.8, 0.8, 0.8)
	cube.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ffffff")
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color("#b197fc")
	m.emission_energy_multiplier = 0.25
	# a kocka mindig előtérben van: semmi nem takarhatja ki
	m.no_depth_test = true
	m.render_priority = 20
	cube.material_override = m
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dice_block.add_child(cube)
	for i in 6:
		var face := Label3D.new()
		face.text = "?"
		face.font = D.font
		face.font_size = 120
		face.pixel_size = 0.004
		face.modulate = Color("#5b3fb5")
		face.outline_size = 0
		face.no_depth_test = true
		face.double_sided = false
		face.render_priority = 21
		var dirs := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
		var dv: Vector3 = dirs[i]
		face.position = dv * 0.41
		if dv.z < 0: face.rotation.y = PI
		elif dv.x > 0: face.rotation.y = PI / 2
		elif dv.x < 0: face.rotation.y = -PI / 2
		elif dv.y > 0: face.rotation.x = -PI / 2
		elif dv.y < 0: face.rotation.x = PI / 2
		cube.add_child(face)
	dice_label = Label3D.new()
	dice_label.font = D.font
	dice_label.font_size = 150
	dice_label.pixel_size = 0.006
	dice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dice_label.no_depth_test = true
	dice_label.render_priority = 22
	dice_label.outline_render_priority = 21
	dice_label.outline_size = 28
	dice_label.outline_modulate = D.DARK
	dice_label.modulate = Color("#ffd43b")
	dice_label.visible = false
	b3.add_child(dice_label)
	dice_block.visible = false


# ------------------------------------------------------------------ menet
func _run() -> void:
	if intro:
		var st: Dictionary = G.board.nodes[G.board.start]
		b3.cam_look(st.x, st.y, "close")
		b3.cam_snap()
		after(0.6, func(): b3.cam_overview(0.9))
		Audio.jingle("start")
		await toast("Kezdődik a játék!", "%d kör · a legtöbb 👑 koronát gyűjtő nyer" % G.max_rounds, 2.6)
		await _order_roll()
		var names := ""
		for p in G.players:
			names += ("  →  " if names != "" else "") + p.name
		await toast("Sorrend", names, 2.6)
		await toast("🎲 Saját kocka!", "Minden figurának van egy saját kockája – a telefonon választhatsz", 2.4)
		await place_crown()
	b3.cam_overview()
	await toast("%d. kör" % G.round, "Ez az utolsó kör!" if G.round == G.max_rounds else "még %d kör van hátra" % (G.max_rounds - G.round + 1), 1.6)
	if G.is_last_rounds() and G.round == G.max_rounds - 2:
		await _last_rounds_event()
	for p in G.players:
		await turn(p)
	current = null
	b3.cam_overview()
	for p in G.players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🎮", "title": "Minijáték jön!", "text": "Készülj!"})
	await toast("🎮 Minijáték!", "Lássuk a csapatokat…", 1.4)
	Main.I.set_scene(MgFlow.SelectScene.new())


## Kezdő sorrend: mindenki egyszerre dob, a legnagyobb kezd.
func _order_roll() -> void:
	b3.cam_look(G.board.nodes[G.board.start].x, G.board.nodes[G.board.start].y, "near", 2.5)
	toast_obj = {"title": "🎲 Ki kezd?", "sub": "Mindenki dob egyet – a legnagyobb szám kezd!", "t0": t, "dur": 60.0, "p": null}
	order_rolls = {}
	var used := {}
	for p in G.players:
		var v := randi_range(1, 10)
		while used.has(v) and used.size() < 10:
			v = randi_range(1, 10)
		used[v] = true
		order_rolls[p.pid] = {"val": v, "shown": 1, "done": false, "t": 0.0}
		_order_one(p)
	while true:
		await sleep(0.2)
		var all_done := true
		for pid in order_rolls:
			if not order_rolls[pid].done:
				all_done = false
		if all_done:
			break
	await sleep(1.2)
	G.players.sort_custom(func(a, b): return order_rolls[a.pid].val > order_rolls[b.pid].val)
	toast_obj = null
	order_rolls = null


func _order_one(p) -> void:
	await Net.ask(p.pid, {"mode": "tap", "label": "🎲 DOBJ!", "hint": "A legnagyobb szám kezd!", "botAuto": true}, ["tap"], 20)
	if order_rolls == null:
		return
	var o: Dictionary = order_rolls[p.pid]
	o.done = true
	o.t = t
	Audio.play("hit")
	Net.vibrate(p.pid, 60)
	b3.emote(p.pid, "happy")
	var q := pawn_xy(p)
	Main.I.burst(q.x, q.y - 70, {"n": 16, "colors": ["#ffffff", p.color_hex, "#ffd43b"], "speed": 260})
	Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🎲", "title": "%d-et dobtál!" % o.val, "text": "Várjuk a többieket…"})


func _last_rounds_event() -> void:
	Audio.play("fanfare")
	Audio.music("board_final")
	b3.set_dusk(true)
	await toast("🔥 UTOLSÓ 3 KÖR! 🔥", "A kék és piros mezők mostantól duplán számítanak!", 2.8)
	# a lemaradó segítséget kap: szerencsekerék
	var s := G.standings()
	var last = s[s.size() - 1]
	if G.players.size() < 2:
		return
	b3.cam_follow(last.pid, "near", 2.5)
	await toast("🎡 Szerencsekerék", "%s áll az utolsó helyen – pörgetheti a szerencsekereket!" % last.name, 2.4, last)
	var opts := [
		{"label": "+10 🪙", "run": func(): give(last, 10)},
		{"label": "+20 🪙", "run": func(): give(last, 20)},
		{"label": "🌟 Aranycső", "run": func(): _gift_item(last, "golden")},
		{"label": "🤝 Barát", "run": func(): await _gain_ally(last)},
		{"label": "🎰 Tripla kocka", "run": func(): _gift_item(last, "triple")},
		{"label": "+5 🪙", "run": func(): give(last, 5)},
	]
	wheel = {"opts": opts, "pos": 0.0, "speed": 14.0, "spinning": true, "result": -1, "t0": t}
	await Net.ask(last.pid, {"mode": "tap", "label": "🎡 STOP!", "hint": "Állítsd meg a kereket!", "botAuto": true}, ["tap"], 20)
	wheel.spinning = false
	Audio.play("hit")
	while wheel.speed > 0.05:
		await sleep(0.05)
	var idx: int = posmod(int(round(wheel.pos)), opts.size())
	wheel.result = idx
	Audio.play("win")
	await sleep(1.2)
	await opts[idx].run.call()
	await sleep(1.0)
	wheel = null


func turn(p) -> void:
	current = p
	b3.cam_follow(p.pid, "near", 2.5)
	Audio.play("select")
	for q in G.players:
		if q != p:
			Net.set_ctrl(q.pid, {"mode": "wait", "char": p.char_id, "title": "%s következik" % p.name, "text": "Figyeld a képernyőt!"})
	await sleep(0.5)
	var ch: Dictionary = G.char_by_id(p.char_id)
	var options := [
		{"label": "🎲 Sima kocka", "sub": "1–10"},
		{"label": "%s %s" % [ch.emoji, ch.die], "sub": ch.tip},
	]
	for k in p.items:
		options.append({"label": "%s %s" % [G.ITEMS[k].icon, G.ITEMS[k].name], "sub": G.ITEMS[k].desc})
	var ally_txt := " · %d barát segít" % p.allies.size() if p.allies.size() else ""
	var r := await Net.ask(p.pid, {"mode": "choice", "title": "Te jössz!", "text": "Melyik kockával dobsz?" + ally_txt, "options": options,
		"botPick": _bot_dice_pick(p)})
	var v := int(r.get("v", 0))
	var n_dice := 1
	var own := v == 1
	if v >= 2 and v - 2 < p.items.size():
		var key: String = p.items[v - 2]
		p.items.remove_at(v - 2)
		Net.push_status(p.pid)
		var res: Dictionary = await use_item(p, key)
		n_dice = res.dice
		if res.get("skip_roll", false):
			await land(p)
			await sleep(0.6)
			return
	var total := 0
	var rolls: Array = []
	for i in n_dice:
		var dv: Array = await roll_die(p, i, n_dice, own and n_dice == 1)
		rolls.append(dv[0])
		total += dv[0]
		if dv[1] != 0:
			give(p, dv[1])
			await sleep(0.7)
	# szövetségesek: mindegyik +1 vagy +2 lépést dob hozzá
	for i in p.allies.size():
		var bonus := randi_range(1, 2)
		rolls.append(bonus)
		total += bonus
		var q := pawn_xy(p)
		Main.I.float_text(q.x + (i - p.allies.size() / 2.0) * 50, q.y - 90, "🤝 +%d" % bonus, Color("#f472b6"), 30)
		Audio.play("ally")
		await sleep(0.45)
	if rolls.size() > 1:
		var parts := PackedStringArray()
		for x in rolls: parts.append(str(x))
		await toast("%s = %d" % [" + ".join(parts), total], "lépés", 1.2)
	if total == 0:
		await toast("😶 0 lépés", "%s most egy helyben marad" % p.name, 1.2)
	else:
		b3.cam_follow(p.pid, "near", 3.5)
		await move(p, total)
		await land(p)
	await sleep(0.6)


func _bot_dice_pick(p) -> int:
	if p.items.size() and randf() < 0.6:
		return 2 + randi() % p.items.size()
	return 1 if randf() < 0.5 else 0


func use_item(p, key: String) -> Dictionary:
	var it: Dictionary = G.ITEMS[key]
	var q := pawn_xy(p)
	Main.I.float_text(q.x, q.y - 50, "%s %s!" % [it.icon, it.name], Color.WHITE, 32)
	Audio.play("whoosh")
	if key == "double": return {"dice": 2}
	if key == "triple": return {"dice": 3}
	if key == "golden":
		if G.crown_node >= 0:
			await toast("🌟 Aranycső!", "Irány a korona!", 1.2)
			var before := _node_before_crown()
			if before >= 0 and before != p.node:
				b3.cam_overview(2.4)
				await hop(p, before, 1.2, 320)
				b3.cam_follow(p.pid, "near", 3)
			return {"dice": 1}
		return {"dice": 1}
	var others: Array = G.players.filter(func(o): return o != p)
	if others.is_empty():
		return {"dice": 1}
	if key == "warp":
		await swap_with(p, others.pick_random())
		return {"dice": 1}
	if key == "thief":
		var options: Array = []
		var any := false
		var rich := 0
		for i in others.size():
			options.append({"label": others[i].name, "sub": "%d 🪙" % others[i].coins, "char": others[i].char_id, "disabled": others[i].coins == 0})
			if others[i].coins > 0: any = true
			if others[i].coins > others[rich].coins: rich = i
		if not any:
			await toast("🧤 Zsebtolvaj", "Senkinek nincs érméje… 😅", 1.5)
			return {"dice": 1}
		var r := await Net.ask(p.pid, {"mode": "choice", "title": "🧤 Kitől lopsz?", "options": options, "botPick": rich})
		var victim = others[clampi(int(r.get("v", rich)), 0, others.size() - 1)]
		var amt := -G.add_coins(victim, -randi_range(5, 15))
		coin_fx(victim, -amt)
		await sleep(0.6)
		give(p, amt)
		await toast("🧤 Zsebtolvaj", "%s ellopott %d érmét %s zsebéből!" % [p.name, amt, victim.name], 1.8)
	return {"dice": 1}


func _node_before_crown() -> int:
	for n in G.board.nodes:
		if n.inner == "" and n.next.has(G.crown_node):
			return n.id
	for n in G.board.nodes:
		if n.next.has(G.crown_node):
			return n.id
	return -1


## [lépés, érme]
func roll_die(p, i: int, n: int, own: bool) -> Array:
	b3.cam_follow(p.pid, "close", 3)
	var ch: Dictionary = G.char_by_id(p.char_id)
	var faces: Array = ch.faces if own else []
	dice = {"p": p, "val": 1, "coins": 0, "rolling": true, "next": 0.0, "hit_t": 0.0, "faces": faces, "own": own, "fi": 0}
	_dice_randomize()
	dice_block.visible = true
	dice_label.visible = false
	var label := ("🎲 DOBJ! (%d/%d)" % [i + 1, n]) if n > 1 else ("%s DOBJ!" % ch.emoji if own else "🎲 DOBJ!")
	await Net.ask(p.pid, {"mode": "tap", "label": label, "hint": "Koppints a dobáshoz!", "botAuto": true}, ["tap"], 25)
	# a figura felugrik és megüti a kockát
	b3.emote(p.pid, "happy")
	Audio.play("jump")
	await sleep(0.18)
	dice.rolling = false
	dice.hit_t = t
	Audio.play("hit")
	Net.vibrate(p.pid, 80)
	b3.shake = 0.5
	var dq := dice_pos()
	Main.I.burst(dq.x, dq.y, {"n": 22, "colors": ["#ffffff", p.color_hex, "#ffd43b"], "speed": 320})
	dice_block.visible = false
	dice_label.visible = true
	dice_label.text = str(dice.val) if dice.coins == 0 else ("%d\n%+d🪙" % [dice.val, dice.coins])
	dice_label.modulate = Color("#ffd43b") if dice.val > 0 else Color("#ff8787")
	await sleep(1.0)
	dice_label.visible = false
	var res := [dice.val, dice.coins]
	dice = null
	return res


func _dice_randomize() -> void:
	if dice.faces.size():
		var fi: int = (dice.fi + 1 + randi() % (dice.faces.size() - 1)) % dice.faces.size()
		dice.fi = fi
		dice.val = dice.faces[fi][0]
		dice.coins = dice.faces[fi][1]
	else:
		var v := randi_range(1, 10)
		while v == dice.val:
			v = randi_range(1, 10)
		dice.val = v
		dice.coins = 0


func move(p, steps: int) -> void:
	steps_left = steps
	while steps_left > 0:
		var node: Dictionary = G.board.nodes[p.node]
		var next_id: int = node.next[0]
		if node.next.size() > 1:
			fork_for = node
			var mx: float = node.x
			var my: float = node.y
			for id in node.next:
				mx += G.board.nodes[id].x
				my += G.board.nodes[id].y
			mx /= node.next.size() + 1
			my /= node.next.size() + 1
			b3.cam_look(mx, my + 60, "mid")
			var options: Array = node.routes if node.routes.size() else [{"label": "1. út"}, {"label": "2. út"}]
			var r := await Net.ask(p.pid, {"mode": "choice", "title": "Merre mész?", "text": "Még %d lépés" % steps_left, "options": options})
			fork_for = null
			b3.cam_follow(p.pid, "near", 3.5)
			var ri := clampi(int(r.get("v", 0)), 0, node.next.size() - 1)
			next_id = node.next[ri]
		await hop(p, next_id)
		p.node = next_id
		p.stats.steps += 1
		steps_left -= 1
		if next_id == G.crown_node:
			await crown_stop(p)


func hop(p, to_id: int, dur := 0.28, height := 26.0) -> void:
	var from := ground_xy(p)
	var to: Dictionary = G.board.nodes[to_id]
	anim[p.pid] = {"from": Vector2(from.x, from.y), "to": Vector2(to.x, to.y), "t0": t, "dur": dur, "height": height}
	Audio.play("step", randf_range(0.95, 1.08))
	await sleep(dur)
	anim.erase(p.pid)
	p.node = to_id
	Audio.play("land")
	b3.flash_tile(to_id)


func swap_with(p, q) -> void:
	var a: int = p.node
	var b: int = q.node
	Audio.play("whoosh")
	hop(q, a, 0.8, 140)
	await hop(p, b, 0.8, 140)
	p.node = b
	q.node = a


func crown_stop(p) -> void:
	b3.cam_follow(p.pid, "close", 3)
	if p.coins >= G.CROWN_PRICE:
		var r := await Net.ask(p.pid, {"mode": "choice", "title": "👑 Korona!", "text": "Megveszed %d érméért? (%d 🪙 van)" % [G.CROWN_PRICE, p.coins],
			"options": [{"label": "👑 Igen, kérem!"}, {"label": "Nem most"}], "botPick": 0})
		if int(r.get("v", 1)) == 0:
			G.add_coins(p, -G.CROWN_PRICE)
			await _award_crown(p)
	else:
		await toast("👑 A korona itt van!", "Ehhez %d érme kell – %s zsebében csak %d van." % [G.CROWN_PRICE, p.name, p.coins], 1.8)
	if current:
		b3.cam_follow(current.pid, "near", 3.5)


func _award_crown(p) -> void:
	p.crowns += 1
	Net.push_status(p.pid)
	Net.vibrate(p.pid, [80, 60, 80, 60, 200])
	b3.emote(p.pid, "cheer")
	Audio.play("crown")
	Audio.jingle("crown")
	var q := pawn_xy(p)
	Main.I.burst(q.x, q.y, {"n": 60, "colors": ["#ffd43b", "#fff3bf", "#fab005", p.color_hex], "speed": 500})
	Main.I.confetti(80)
	Main.I.float_text(q.x, q.y - 50, "+1 👑", Color("#ffd43b"), 44)
	await toast("👑 %s koronát szerzett!" % p.name, "Már %d koronája van" % p.crowns, 2.2, p)
	await place_crown()


func place_crown() -> void:
	var occupied := {}
	for p in G.players:
		occupied[p.node] = true
	var cand: Array = G.board.nodes.filter(func(n): return n.type == "B" and n.inner == "" and n.id != G.crown_node and not occupied.has(n.id) and not G.hidden_blocks.has(n.id))
	if cand.is_empty():
		cand = G.board.nodes.filter(func(n): return n.type == "B")
	var target: Dictionary = cand.pick_random()
	var from := Vector2(640, -60)
	if G.crown_node >= 0:
		from = Vector2(G.board.nodes[G.crown_node].x, G.board.nodes[G.crown_node].y)
	G.crown_node = -1
	b3.cam_look(target.x, target.y, "mid", 2.2)
	crown_anim = {"from": from, "to": Vector2(target.x, target.y), "t0": t, "dur": 1.3}
	Audio.play("whoosh")
	await sleep(1.3)
	G.crown_node = target.id
	crown_anim = null
	Audio.play("crown")
	var tq := b3.project(target.x, target.y, 40)
	Main.I.burst(tq.x, tq.y, {"n": 30, "colors": ["#ffd43b", "#ffffff"], "speed": 260})
	await toast("👑 A korona új helye", "Lépj rá vagy haladj át rajta, és vedd meg %d érméért!" % G.CROWN_PRICE, 1.8)


func land(p) -> void:
	b3.cam_follow(p.pid, "close", 2.5)
	var node: Dictionary = G.board.nodes[p.node]
	var mult := 2 if G.is_last_rounds() else 1
	p.last_space = node.type
	match node.type:
		"B", "T":
			p.stats.blue += 1
			give(p, 3 * mult)
			await sleep(1.0)
		"R":
			p.stats.red += 1
			give(p, -3 * mult)
			await sleep(1.0)
		"E":
			p.stats.events += 1
			await event(p)
		"S":
			await shop(p)
		"J":
			await jump_pad(p, node)
		"A":
			await _gain_ally(p)
		"V":
			p.stats.events += 1
			await island_event(p, node)
	if G.hidden_blocks.has(p.node):
		await _hidden_block(p)


func _hidden_block(p) -> void:
	var kind: String = G.hidden_blocks[p.node]
	G.hidden_blocks.erase(p.node)
	b3.emote(p.pid, "happy")
	Audio.play("jump")
	await sleep(0.25)
	Audio.play("sparkle")
	block_pop = {"node": p.node, "kind": kind, "t0": t}
	var q := pawn_xy(p)
	Main.I.burst(q.x, q.y - 80, {"n": 30, "colors": ["#ffd43b", "#ffffff", "#b197fc"], "speed": 320})
	await toast("❓ Rejtett doboz!", "Egy láthatatlan doboz volt a mező fölött!", 1.5)
	match kind:
		"crown":
			Main.I.float_text(q.x, q.y - 60, "👑 !!!", Color("#ffd43b"), 48)
			p.crowns += 1
			Net.push_status(p.pid)
			Audio.play("crown")
			Audio.jingle("crown")
			Main.I.confetti(90)
			await toast("👑 INGYEN KORONA!", "%s egy koronát talált a dobozban!" % p.name, 2.4, p)
		"item":
			_gift_item(p, ["double", "triple", "warp", "thief", "golden"].pick_random())
			await sleep(1.2)
		_:
			give(p, randi_range(10, 20))
			await sleep(1.2)
	block_pop = null
	# új rejtett doboz kerül valahová
	var cand: Array = G.board.nodes.filter(func(n): return n.type in ["B", "R"] and not G.hidden_blocks.has(n.id) and n.id != G.crown_node)
	if cand.size():
		G.hidden_blocks[cand.pick_random().id] = BoardLayout._hidden_kind()


func _gift_item(p, key: String) -> void:
	if p.items.size() >= G.MAX_ITEMS:
		give(p, 5)
		return
	p.items.append(key)
	Net.push_status(p.pid)
	var q := pawn_xy(p)
	Main.I.float_text(q.x, q.y - 40, "%s %s" % [G.ITEMS[key].icon, G.ITEMS[key].name], Color.WHITE, 30)
	Audio.play("pop")


func _gain_ally(p) -> void:
	var used := {}
	for q in G.players:
		used[q.char_id] = true
		for a in q.allies:
			used[a] = true
	var free: Array = G.CHARS.filter(func(c): return not used.has(c.id))
	if free.is_empty() or p.allies.size() >= G.MAX_ALLIES:
		await toast("🤝 Barátság", "Most nincs szabad barát – kapsz helyette 5 érmét.", 1.6)
		give(p, 5)
		return
	var c: Dictionary = free.pick_random()
	p.allies.append(c.id)
	p.stats.allies += 1
	Net.push_status(p.pid)
	Audio.play("ally")
	Audio.jingle("ally")
	b3.emote(p.pid, "cheer")
	var q := pawn_xy(p)
	Main.I.burst(q.x, q.y, {"n": 30, "colors": ["#f472b6", "#ffffff", p.color_hex], "speed": 300})
	await toast("🤝 %s csatlakozott!" % c.name, "%s barátja lett: minden dobáshoz +1–2 lépést ad" % p.name, 2.2, p)


func jump_pad(p, node: Dictionary) -> void:
	if node.pair < 0:
		return
	var to: Dictionary = G.board.nodes[node.pair]
	Audio.play("whoosh")
	Net.vibrate(p.pid, [40, 30, 120])
	await toast("🚀 Ugrópad!", "Irány egy másik sziget!", 1.1)
	b3.cam_overview(2.4)
	b3.emote(p.pid, "happy")
	await hop(p, to.id, 1.3, 320)
	p.node = to.id
	b3.cam_follow(p.pid, "near", 3)
	var q := pawn_xy(p)
	Main.I.burst(q.x, q.y, {"n": 24, "colors": ["#22d3ee", "#ffffff", p.color_hex], "speed": 340})
	if to.id == G.crown_node:
		await crown_stop(p)


func give(p, n: int) -> int:
	var d := G.add_coins(p, n)
	coin_fx(p, d)
	return d


func coin_fx(p, d: int) -> void:
	if d != 0:
		b3.emote(p.pid, "happy" if d > 0 else "sad")
	var q := pawn_xy(p)
	Main.I.float_text(q.x, q.y - 36, "%s%d 🪙" % ["+" if d >= 0 else "", d], Color("#ffd43b") if d >= 0 else Color("#ff8787"), 32)
	if d > 0:
		Main.I.burst(q.x, q.y, {"n": 14, "colors": ["#ffd43b", "#fab005", "#fff3bf"]})
		Audio.play("coin")
	elif d < 0:
		Audio.play("bad")
	Net.vibrate(p.pid, 40 if d >= 0 else [60, 40, 60])


# ------------------------------------------------------------------ események
func _events() -> Array:
	var others_ok := G.players.size() > 1
	return [
		{"w": 3, "icon": "🍀", "title": "Szerencse!", "desc": "Kapsz 10 érmét.", "run": func(p): give(p, 10)},
		{"w": 3, "icon": "🕳️", "title": "Lyukas zseb", "desc": "Elhagysz 6 érmét.", "run": func(p): give(p, -6)},
		{"w": 2 if others_ok else 0, "icon": "🎂", "title": "Szülinap!", "desc": "Mindenki ad neked 3 érmét.", "run": func(p):
			var sum := 0
			for q in G.players:
				if q != p:
					var dd := -G.add_coins(q, -3)
					sum += dd
					coin_fx(q, -dd)
			give(p, sum)},
		{"w": 2, "icon": "🌧️", "title": "Érmeeső", "desc": "Mindenki kap 5 érmét.", "run": func(_p):
			for q in G.players:
				give(q, 5)},
		{"w": 2 if others_ok else 0, "icon": "🔄", "title": "Helycsere", "desc": "Helyet cserélsz egy véletlen játékossal!", "run": func(p):
			await swap_with(p, G.players.filter(func(q): return q != p).pick_random())},
		{"w": 2, "icon": "🎁", "title": "Ajándék", "desc": "Kapsz egy véletlen tárgyat.", "run": func(p):
			_gift_item(p, G.SHOP_ITEMS.pick_random())},
		{"w": 1 if G.crown_node >= 0 else 0, "icon": "🦅", "title": "Koronaexpressz", "desc": "Egy sas a korona elé repít!", "run": func(p):
			var before := _node_before_crown()
			if before >= 0 and before != p.node:
				await hop(p, before, 0.9, 160)},
		{"w": 2 if others_ok else 0, "icon": "⚖️", "title": "Igazságos osztozás", "desc": "Összeadod az érméidet a leggazdagabbéval, és elfelezitek!", "run": func(p):
			var rich = G.players.filter(func(q): return q != p)
			rich.sort_custom(func(a, b): return a.coins > b.coins)
			var r = rich[0]
			var half: int = (p.coins + r.coins) / 2
			var dp = half - p.coins
			var dr = half - r.coins
			give(p, dp)
			give(r, dr)},
		{"w": 1, "icon": "🤝", "title": "Új barát", "desc": "Valaki csatlakozik hozzád!", "run": func(p): await _gain_ally(p)},
	]


func event(p) -> void:
	var pool: Array = _events().filter(func(e): return e.w > 0)
	var total := 0
	for e in pool: total += e.w
	var r := randf() * total
	var ev: Dictionary = pool[0]
	for e in pool:
		r -= e.w
		if r < 0:
			ev = e
			break
	card = {"ev": ev, "t0": t}
	Audio.play("whoosh")
	await sleep(2.2)
	await ev.run.call(p)
	await sleep(1.0)
	card = null


func island_event(p, node: Dictionary) -> void:
	var isl: String = node.island
	var info := {
		"meadow": ["⛲", "Kívánságkút", "A kút megáldja a Rét összes vándorát: +6 érme mindenkinek a szigeten!"],
		"forest": ["🍃", "Erdei szél", "Feltámad a szél, és a korona új helyre repül!"],
		"castle": ["💣", "Ágyúlövés", "A kastély ágyúja kilő egy véletlen mezőre!"],
		"volcano": ["🌋", "Kitörés!", "Lávabombák! Aki a vulkánon vagy a Lávahídon áll, 8 érmét veszít."],
		"lava": ["🌋", "Kitörés!", "Lávabombák! Aki a vulkánon vagy a Lávahídon áll, 8 érmét veszít."],
		"desert": ["🌪️", "Homokvihar", "A vihar összekeveri a játékosokat: két véletlen játékos helyet cserél!"],
		"crystal": ["💎", "Kristálytükör", "A kristály megsokszorozza a szerencsét: dobj még egyet!"],
		"beach": ["🏴‍☠️", "Kincses láda", "Egy partra sodort láda: 8–15 érme!"],
	}
	var d: Array = info.get(isl, ["❗", "Meglepetés", "Kapsz 5 érmét."])
	card = {"ev": {"icon": d[0], "title": d[1], "desc": d[2], "green": true}, "t0": t}
	Audio.play("whoosh")
	await sleep(2.2)
	card = null
	match isl:
		"meadow":
			b3.cam_look(250, 455, "mid")
			Audio.play("bell")
			for q in G.players:
				if G.board.nodes[q.node].island == "meadow":
					give(q, 6)
			await sleep(1.4)
		"forest":
			await place_crown()
		"castle":
			b3.shake = 1.0
			Audio.play("boom")
			var cand: Array = G.board.nodes.filter(func(n): return n.id != p.node and n.type in ["B", "R", "E"])
			var target: Dictionary = cand.pick_random()
			b3.cam_overview(2.0)
			await hop(p, target.id, 1.5, 420)
			b3.cam_follow(p.pid, "near", 3)
			if target.id == G.crown_node:
				await crown_stop(p)
		"volcano", "lava":
			b3.cam_look(1035, 200, "mid", 2.5)
			await sleep(0.4)
			Audio.play("boom")
			b3.shake = 1.4
			Main.I.burst(860, 200, {"n": 80, "colors": ["#ff6b00", "#ffd43b", "#ff4500", "#333333"], "speed": 600, "life": 1.4})
			await sleep(0.8)
			var hit := false
			for q in G.players:
				var nd: Dictionary = G.board.nodes[q.node]
				if nd.island == "volcano" or nd.inner == "lava":
					give(q, -8)
					hit = true
			if not hit:
				await toast("😅 Szerencse", "Most senki sem állt a lávában!", 1.4)
			await sleep(1.0)
		"desert":
			if G.players.size() >= 2:
				var two: Array = G.players.duplicate()
				two.shuffle()
				Audio.play("whoosh")
				b3.cam_overview(2.0)
				await swap_with(two[0], two[1])
				await toast("🌪️ Homokvihar", "%s és %s helyet cserélt!" % [two[0].name, two[1].name], 1.6)
			else:
				give(p, 5)
		"crystal":
			Audio.play("sparkle")
			var dv: Array = await roll_die(p, 0, 1, false)
			b3.cam_follow(p.pid, "near", 3.5)
			await move(p, dv[0])
			if G.board.nodes[p.node].type in ["B", "R"]:
				give(p, 3 if G.board.nodes[p.node].type == "B" else -3)
				await sleep(0.8)
		"beach":
			give(p, randi_range(8, 15))
			await sleep(1.2)
		_:
			give(p, 5)
			await sleep(1.0)


func shop(p) -> void:
	var full: bool = p.items.size() >= G.MAX_ITEMS
	var options: Array = []
	for k in G.SHOP_ITEMS:
		var it: Dictionary = G.ITEMS[k]
		options.append({"label": "%s %s  ·  %d 🪙" % [it.icon, it.name, it.price], "sub": it.desc, "disabled": full or p.coins < it.price})
	options.append({"label": "Köszi, semmit"})
	shop_for = p
	var bot_pick := -1
	for i in range(G.SHOP_ITEMS.size() - 1, -1, -1):
		if not options[i].disabled and randf() < 0.6:
			bot_pick = i
			break
	var r := await Net.ask(p.pid, {"mode": "choice", "title": "🛒 Bolt", "text": "Tele a zsebed (max. 3 tárgy)" if full else "%d érméd van. Mit veszel?" % p.coins,
		"options": options, "botPick": bot_pick if bot_pick >= 0 else options.size() - 1})
	var v := int(r.get("v", options.size() - 1))
	if v < G.SHOP_ITEMS.size() and not options[v].disabled:
		var k: String = G.SHOP_ITEMS[v]
		G.add_coins(p, -G.ITEMS[k].price)
		p.stats.spent += G.ITEMS[k].price
		p.items.append(k)
		Net.push_status(p.pid)
		Audio.play("coin")
		var q := pawn_xy(p)
		Main.I.float_text(q.x, q.y - 40, "%s %s" % [G.ITEMS[k].icon, G.ITEMS[k].name], Color.WHITE, 30)
		await sleep(1.2)
	shop_for = null


func toast(title: String, sub := "", dur := 1.6, p = null) -> void:
	toast_obj = {"title": title, "sub": sub, "t0": t, "dur": dur, "p": p}
	await sleep(dur)
	if toast_obj and toast_obj.title == title:
		toast_obj = null


# ------------------------------------------------------------------ pozíciók
func node_slot(p) -> Vector2:
	var here: Array = G.players.filter(func(q): return q.node == p.node and not anim.has(q.pid))
	var n: Dictionary = G.board.nodes[p.node]
	if here.size() <= 1:
		return Vector2(n.x, n.y)
	var i := here.find(p)
	var a := float(i) / here.size() * TAU - PI / 2
	return Vector2(n.x + cos(a) * (19 + here.size() * 3), n.y + sin(a) * (13 + here.size() * 2))


func ground_xy(p) -> Dictionary:
	if anim.has(p.pid):
		var a: Dictionary = anim[p.pid]
		var k: float = min(1.0, (t - a.t0) / a.dur)
		var e := D.ease_in_out(k)
		var pos: Vector2 = a.from.lerp(a.to, e)
		return {"x": pos.x, "y": pos.y, "h": sin(k * PI) * a.height}
	var s := node_slot(p)
	return {"x": s.x, "y": s.y, "h": 0.0}


func pawn_xy(p) -> Vector2:
	var g := ground_xy(p)
	return b3.project(g.x, g.y, g.h + 50)


func crown_pos():
	if crown_anim:
		var a: Dictionary = crown_anim
		var k: float = min(1.0, (t - a.t0) / a.dur)
		var e := D.ease_in_out(k)
		var pos: Vector2 = a.from.lerp(a.to, e)
		return {"x": pos.x, "y": pos.y, "h": sin(k * PI) * 200}
	if G.crown_node < 0:
		return null
	var n: Dictionary = G.board.nodes[G.crown_node]
	return {"x": n.x, "y": n.y, "h": 0.0}


func dice_pos() -> Vector2:
	var q := pawn_xy(dice.p)
	return Vector2(q.x, q.y - 70)


# ------------------------------------------------------------------ frissítés + rajz
func update(dt: float) -> void:
	for p in G.players:
		p.disp_coins += (p.coins - p.disp_coins) * min(1.0, dt * 8.0)
	var pawns: Array = []
	for p in G.players:
		var g := ground_xy(p)
		pawns.append({"p": p, "x": g.x, "y": g.y, "h": g.h, "current": p == current})
	b3.render({"pawns": pawns, "crown": crown_pos()}, dt)
	if dice:
		if dice.rolling and t >= dice.next:
			_dice_randomize()
			dice.next = t + 0.07
			Audio.play("roll")
		var g := ground_xy(dice.p)
		var base := Board3D.w(g.x, g.y, 0) + Vector3(0, 2.3, 0)
		dice_block.position = base + Vector3(0, sin(t * 4.0) * 0.08, 0)
		dice_block.rotation = Vector3(t * 2.3, t * 3.1, t * 1.7) if dice.rolling else dice_block.rotation
		for f in dice_block.get_child(0).get_children():
			(f as Label3D).text = str(dice.val)
		var pop: float = 1.0 + 0.5 * max(0.0, 1.0 - (t - dice.hit_t) * 3.0) if not dice.rolling else 1.0
		dice_label.position = base + Vector3(0, 0.2, 0)
		dice_label.scale = Vector3.ONE * pop
	if order_rolls:
		for pid in order_rolls:
			var o: Dictionary = order_rolls[pid]
			if not o.done and fmod(t, 0.08) < dt:
				o.shown = randi_range(1, 10)
	if wheel:
		if wheel.spinning:
			wheel.pos += wheel.speed * dt
		else:
			wheel.speed *= pow(0.25, dt)
			wheel.pos += wheel.speed * dt
		var idx := int(floor(wheel.pos))
		if idx != wheel.get("last_i", -1):
			wheel["last_i"] = idx
			Audio.play("tick")


func draw(c: CanvasItem) -> void:
	var nodes: Array = G.board.nodes
	if fork_for:
		for i in fork_for.next.size():
			var n: Dictionary = nodes[fork_for.next[i]]
			var q := b3.project(n.x, n.y)
			var s := 1.0 + sin(Main.I.time * 6.0) * 0.15
			c.draw_set_transform(q, 0, Vector2(1.0, 0.7))
			c.draw_arc(Vector2.ZERO, NODE_R * 1.6 * s, 0, TAU, 40, Color.WHITE, 4, true)
			c.draw_set_transform(Vector2.ZERO)
			var lab: String = fork_for.routes[i].label if i < fork_for.routes.size() else "%d." % (i + 1)
			D.text(c, lab, q.x, q.y - 40, {"size": 20, "stroke": D.DARK, "sw": 6})
	if current and steps_left > 0 and dice == null:
		var q := pawn_xy(current)
		var top := q.y - 34
		c.draw_circle(Vector2(q.x + 30, top + 8), 17, Color.WHITE)
		D.text(c, str(steps_left), q.x + 30, top + 9, {"size": 22, "color": Color("#2b1055")})
	if dice and dice.own and dice.rolling and dice.faces.size():
		var q := dice_pos()
		var parts := PackedStringArray()
		for f in dice.faces:
			parts.append(("%d" % f[0]) + (("%+d🪙" % f[1]) if f[1] != 0 else ""))
		D.panel(c, q.x - 150, q.y - 120, 300, 36, {"r": 18, "fill": Color(0.08, 0.05, 0.19, 0.85), "shadow": false})
		D.text(c, " · ".join(parts), q.x, q.y - 102, {"size": 18, "color": Color("#ffe066"), "maxw": 280})
	if block_pop:
		var n: Dictionary = nodes[block_pop.node]
		var k: float = min(1.0, (t - block_pop.t0) * 2.5)
		var q := b3.project(n.x, n.y, 110 + k * 30)
		var icon: String = {"crown": "👑", "item": "🎁", "coins": "🪙"}.get(block_pop.kind, "❓")
		D.panel(c, q.x - 34, q.y - 34, 68, 68, {"r": 14, "fill": Color("#ffd43b"), "stroke": Color("#b45309"), "lw": 4})
		D.emoji(c, icon, q.x, q.y, 40 * D.ease_out_back(k))
	if order_rolls:
		for p in G.players:
			var o: Dictionary = order_rolls[p.pid]
			var q := pawn_xy(p)
			var pop: float = 1.0 + 0.4 * max(0.0, 1.0 - (t - o.t) * 3.0) if o.done else 1.0
			var s := 46.0 * pop
			D.panel(c, q.x - s / 2, q.y - 95 - s / 2, s, s, {"r": 10, "fill": Color.WHITE, "stroke": p.color, "lw": 4})
			D.text(c, str(o.val if o.done else o.shown), q.x, q.y - 95, {"size": int(28 * pop), "color": Color("#e11d48") if o.done else Color("#5b3fb5")})
	_draw_hud(c)
	if card: _draw_card(c)
	if shop_for: _draw_shop(c)
	if wheel: _draw_wheel(c)
	if toast_obj: _draw_toast(c)


func _draw_hud(c: CanvasItem) -> void:
	D.panel(c, 14, 8, 250, 44, {"r": 14, "fill": Color(0.094, 0.055, 0.22, 0.85)})
	D.text(c, "🎲 %d. kör / %d" % [G.round, G.max_rounds], 139, 31, {"size": 23})
	if G.is_last_rounds():
		D.panel(c, 274, 8, 190, 44, {"r": 14, "fill": Color(0.86, 0.15, 0.15, 0.9)})
		D.text(c, "🔥 Dupla mezők", 369, 31, {"size": 20})
	D.panel(c, 1046, 8, 220, 44, {"r": 14, "fill": Color(0.094, 0.055, 0.22, 0.85)})
	D.text(c, "👑 ára: %d 🪙" % G.CROWN_PRICE, 1156, 31, {"size": 21})
	if current:
		var p = current
		D.panel(c, 490, 6, 300, 48, {"r": 24, "fill": D.shade(p.color, -0.45), "stroke": p.color})
		D.avatar(c, p, 516, 30, 17, {"shadow": false})
		D.text(c, "%s köre" % p.name, 652, 31, {"size": 24, "maxw": 250})
	var n := G.players.size()
	var cw: float = min(232.0, (1250.0 - (n - 1) * 8) / n)
	var x0 := 640.0 - (n * cw + (n - 1) * 8) / 2.0
	for i in n:
		var p = G.players[i]
		var cur: bool = p == current
		var x := x0 + i * (cw + 8)
		var y := 606.0 if cur else 616.0
		D.panel(c, x, y, cw, 98, {"r": 16, "fill": D.shade(p.color, -0.55), "stroke": Color("#ffd43b") if cur else p.color, "lw": 5 if cur else 3})
		D.avatar(c, p, x + 32, y + 36, 21, {"alpha": 1.0 if (p.connected or p.is_bot) else 0.4, "shadow": false})
		D.text(c, "%d." % G.place_of(p), x + 32, y + 78, {"size": 18, "color": Color("#ffd43b")})
		D.text(c, p.name, x + 60, y + 24, {"size": 19, "align": "left", "maxw": cw - 68})
		D.text(c, "🪙 %d" % roundi(p.disp_coins), x + 60, y + 53, {"size": 21, "align": "left", "color": Color("#ffe066")})
		D.text(c, "👑 %d" % p.crowns, x + 60, y + 80, {"size": 21, "align": "left"})
		var icons := ""
		for k in p.items: icons += G.ITEMS[k].icon
		for a in p.allies: icons += G.char_by_id(a).emoji
		if icons != "":
			D.text(c, icons, x + cw - 8, y + 80, {"size": 16, "align": "right", "maxw": cw - 110})
		if not p.connected and not p.is_bot:
			D.text(c, "📵", x + cw - 14, y + 22, {"size": 18})


func _draw_card(c: CanvasItem) -> void:
	var ev: Dictionary = card.ev
	var k: float = min(1.0, (t - card.t0) / 0.6)
	var flip: float = abs(cos(k * PI))
	var front := k >= 0.5
	var s := D.ease_out_back(min(1.0, (t - card.t0) * 3.0))
	var green: bool = ev.get("green", false)
	var col := Color("#16a34a") if green else Color("#a855f7")
	c.draw_set_transform(Vector2(640, 320), 0, Vector2(max(0.02, flip) * s, s))
	D.panel(c, -190, -140, 380, 280, {"fill": Color("#f0fdf4") if (front and green) else (Color("#faf5ff") if front else D.shade(col, -0.2)), "stroke": col, "lw": 6, "r": 26})
	if front:
		D.emoji(c, ev.icon, 0, -60, 80)
		D.text(c, ev.title, 0, 25, {"size": 38, "color": Color("#14532d") if green else Color("#4c1d95")})
		D.wrap(c, ev.desc, 0, 72, 340, 26, {"size": 21, "color": Color("#166534") if green else Color("#6b21a8"), "align": "center", "bold": false})
	else:
		D.text(c, "❗" if green else "?", 0, 5, {"size": 120})
	c.draw_set_transform(Vector2.ZERO)


func _draw_shop(c: CanvasItem) -> void:
	var p = shop_for
	D.panel(c, 830, 100, 400, 380, {"fill": Color(1, 0.97, 0.9, 0.97), "stroke": Color("#f59e0b"), "lw": 5})
	D.text(c, "🛒 Bolt", 1030, 138, {"size": 34, "color": Color("#92400e")})
	for i in G.SHOP_ITEMS.size():
		var it: Dictionary = G.ITEMS[G.SHOP_ITEMS[i]]
		var y := 185.0 + i * 56
		var ok: bool = p.coins >= it.price and p.items.size() < G.MAX_ITEMS
		D.emoji(c, it.icon, 870, y + 4, 34, 1.0 if ok else 0.4)
		D.text(c, it.name, 900, y - 6, {"size": 22, "color": Color("#78350f") if ok else Color("#b8a48a"), "align": "left"})
		D.text(c, it.desc, 900, y + 17, {"size": 15, "color": Color("#a16207"), "align": "left", "bold": false})
		D.text(c, "%d 🪙" % it.price, 1205, y + 4, {"size": 22, "color": Color("#b45309") if ok else Color("#d6c4a8"), "align": "right"})
	D.text(c, "%s: %d 🪙" % [p.name, p.coins], 1030, 458, {"size": 20, "color": Color("#92400e")})


func _draw_wheel(c: CanvasItem) -> void:
	var opts: Array = wheel.opts
	var n := opts.size()
	var cx := 640.0
	var cy := 360.0
	var R := 190.0
	D.ellipse(c, cx + 4, cy + 10, R + 14, R + 14, Color(0, 0, 0, 0.3))
	c.draw_circle(Vector2(cx, cy), R + 12, Color("#ffd43b"))
	var cols := ["#ff4d6d", "#4dabf7", "#51cf66", "#b197fc", "#ff922b", "#22d3ee"]
	var rot: float = -wheel.pos / n * TAU
	for i in n:
		var a0 := rot + (i - 0.5) / n * TAU - PI / 2
		var a1 := rot + (i + 0.5) / n * TAU - PI / 2
		var pts := PackedVector2Array([Vector2(cx, cy)])
		for k in 13:
			var a := lerpf(a0, a1, k / 12.0)
			pts.append(Vector2(cx + cos(a) * R, cy + sin(a) * R))
		var col := Color(cols[i % cols.size()])
		if wheel.result == i:
			col = col.lightened(0.35 + sin(t * 10.0) * 0.2)
		c.draw_colored_polygon(pts, col)
		var am := (a0 + a1) / 2
		c.draw_set_transform(Vector2(cx + cos(am) * R * 0.62, cy + sin(am) * R * 0.62), am + PI / 2, Vector2.ONE)
		D.text(c, opts[i].label, 0, 0, {"size": 22, "stroke": D.DARK, "sw": 5, "maxw": 120})
		c.draw_set_transform(Vector2.ZERO)
	c.draw_circle(Vector2(cx, cy), 28, Color.WHITE)
	D.text(c, "🎡", cx, cy, {"size": 34})
	var tip := PackedVector2Array([Vector2(cx - 20, cy - R - 34), Vector2(cx + 20, cy - R - 34), Vector2(cx, cy - R + 6)])
	c.draw_colored_polygon(tip, Color.WHITE)
	c.draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[0]]), D.DARK, 4, true)


func _draw_toast(c: CanvasItem) -> void:
	var o: Dictionary = toast_obj
	var age: float = t - o.t0
	var s := D.ease_out_back(min(1.0, age * 4.0))
	var a: float = clamp((o.dur - age) * 5.0, 0.0, 1.0)
	var p = o.p
	var y := 190.0 if wheel == null else 95.0
	c.draw_set_transform(Vector2(640, y), 0, Vector2(s, s))
	var has_sub: bool = o.sub != ""
	var fill := Color(D.shade(p.color, -0.5), 0.94 * a) if p else Color(0.094, 0.055, 0.22, 0.94 * a)
	var stroke := Color(p.color, a) if p else Color(1, 0.83, 0.23, a)
	D.panel(c, -400, -78, 800, 156 if has_sub else 110, {"fill": fill, "stroke": stroke, "lw": 5, "r": 28, "shadow": false})
	D.text(c, o.title, 0, -30 if has_sub else -23, {"size": 50, "stroke": D.DARK, "sw": 8, "maxw": 760, "alpha": a})
	if has_sub:
		D.text(c, o.sub, 0, 34, {"size": 24, "color": Color("#e5dbff"), "maxw": 760, "alpha": a})
	c.draw_set_transform(Vector2.ZERO)
