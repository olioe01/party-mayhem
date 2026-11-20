class_name HighwayScene
extends GameScene
## Óceánsztráda: egy kör = minijáték, utána a helyezések sorrendjében mindenki annyi kockával dob,
## amennyit a helyezése ért, és a dobott összeggel előrefut a 351 mezős sztrádán. Különleges mezők,
## két ellenőrzőpont (felvonóhíd 100, jelzőlámpás kapu 200), a végén célkapu: 10 kockával 40 (utána 35) kell.
## Minden véletlen a játékmenet randi()-ja (online lockstep), a látvány a Highway3D-ben él.

const HL = preload("res://scripts/world/highway_layout.gd")

var intro := false
var h3: Highway3D
var current = null
var toast_obj = null
var runs := {}               # pid -> {from, to, t0, dur}
var carry = null             # {pid, kind, a, b, t0}
var dice = null              # {p, origin, vals, kind, t0s, gold, bonus_from}
var total_fx = null          # {p, total, t0, grade, gold, label}
var done := false
var step_t := 0.0
var walk = null              # {pid, left, dir}: a futó figura lépésszámlálója (left = a mostani futás elején hátralévő lépés)


func _init(is_intro := false) -> void:
	intro = is_intro


func enter() -> void:
	G.phase = "board"
	Audio.music("board")
	h3 = Highway3D.get_world()
	if h3.get_parent():
		h3.get_parent().remove_child(h3)
	add_child(h3)
	h3.activate()
	if intro:
		h3.reset_game()
	for p in G.players:
		Net.push_status(p.pid)
	_run()


func exit() -> void:
	if h3 and h3.get_parent() == self:
		remove_child(h3)


# ------------------------------------------------------------------ menet
func _run() -> void:
	for p in G.players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🛣️", "title": "Óceánsztráda", "text": "Figyeld a képernyőt!"})
	if intro:
		await _intro()
		Main.I.set_scene(MgFlow.SelectScene.new())
		return
	if G.hw_duel_now:
		# a párbaj után: előbb a bónuszkockák, aztán jön a kör rendes minijátéka
		G.hw_duel_now = false
		await _duel_bonus()
		if G.mtn_winner:
			await _win(G.mtn_winner)
			return
		await _to_minigame()
		return
	_cam_all()
	print_verbose("[hw] kör %d: %s" % [G.round, ", ".join(G.players.map(func(p): return "%s=%d 🎲%d" % [p.name, p.node, p.hw_dice]))])
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
	if Game.force_duel and G.hw_duel == "" and G.players.size() > 0:
		Game.force_duel = false
		G.hw_duel = G.players[0].pid
	if G.hw_duel != "" and G.players.size() > 1 and G.by_pid(G.hw_duel) != null:
		var solo = G.by_pid(G.hw_duel)
		_cam_all()
		for p in G.players:
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": "⚔️", "title": "Párbaj!", "text": "%s párbajozik – mindjárt kiderül, kik ellen!" % solo.name})
		var vs_txt := "3 véletlenül sorsolt ellenfél ellen" if G.players.size() >= 4 else "egy véletlenül sorsolt ellenféllel kettesben"
		await toast("⚔️ %s párbaja!" % solo.name, "%s %s játszik. Ha nyer, +%d kocka; ha az ellenfelek, fejenként +%d" % [solo.name, vs_txt, HL.DUEL_SOLO_DICE, HL.DUEL_TEAM_DICE], 3.0, solo)
		G.hw_duel_now = true
		Main.I.set_scene(MgFlow.SelectScene.new())
		return
	G.hw_duel = ""
	await _to_minigame()


func _to_minigame() -> void:
	_cam_all()
	for p in G.players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🎮", "title": "Minijáték jön!", "text": "A helyezésed dönti el, hány kockával dobsz!"})
	await toast("🎮 Minijáték!", "Harcolj a minél több kockáért!", 1.5)
	Main.I.set_scene(MgFlow.SelectScene.new())


func _intro() -> void:
	for i in G.players.size():
		G.players[i].hw_lane = i
	h3.cam_follow(HL.pos(0), "mid", 3.0, 0)
	h3.cam_snap()
	_render(0.0)
	Audio.jingle("start")
	h3.pose_all("intro", 3.4)
	await toast("🛣️ Óceánsztráda!", "%d mező az óceán fölött – aki elsőként átjut a célkapun, nyer!" % HL.GOAL, 3.4)
	var r := HL.rewards(G.players.size())
	var parts := PackedStringArray()
	for i in r.size():
		parts.append("%d.: %d" % [i + 1, r[i]])
	await toast("🎲 A kockákat a minijáték osztja", "Minden kör minijátékkal kezdődik. Kockák: " + " · ".join(parts), 4.0)
	await toast("✨ Egyforma kockák = +%d kocka" % HL.MATCH_BONUS, "Ha minden kockád ugyanazt mutatja, még %d kockával dobsz!" % HL.MATCH_BONUS, 3.2)
	h3.cam_follow(HL.pos(HL.CP_BRIDGE), "mid", 1.4, HL.CP_BRIDGE)
	await toast("🌉 100: Felvonóhíd", "Egy kockával páratlan kell (1, 3, 5) – ha nem sikerül, egyet visszalépsz. Ha valaki egyszer leengedi, mindenkinek nyitva marad.", 3.8)
	h3.cam_follow(HL.pos(HL.CP_LIGHTS), "mid", 1.4, HL.CP_LIGHTS)
	await toast("🚦 200: Jelzőlámpás kapu", "%d zöld-piros lámpakockával több zöld kell, mint piros! Ha valaki kinyitja, örökre nyitva marad mindenkinek, és onnantól az utolsó helyezett választ minijátékot." % HL.LIGHT_DICE, 4.0)
	h3.cam_follow(HL.pos(HL.GOAL), "mid", 1.4, HL.GOAL)
	await toast("🏁 %d: Célkapu" % HL.GOAL, "%d kockával legalább %d kell (ha elsőre nem megy, utána %d). Ha nem sikerül: %d mezőt vissza." % [HL.FINAL_DICE, HL.FINAL_NEED[0], HL.FINAL_NEED[1], HL.FINAL_FAIL_BACK], 4.0)
	h3.cam_follow(HL.pos(0), "mid", 1.6, 0)
	await toast("⏩ Különleges mezők", "Hátszél és szembeszél, kék és piros kockamező, UFO, rakéta, felzárkózó (aki rálép, dob: +10/+20/+30 az utolsónak) és „1 a többiek ellen”.", 3.4)
	await toast("🎮 Kezdjük egy minijátékkal!", "", 1.6)


func turn(p) -> void:
	current = p
	h3.bridge_target = 1.0 if G.hw_open >= 1 else 0.0
	h3.gate_target = 1.0 if G.hw_open >= 2 else 0.0
	h3.gate_light = "green" if G.hw_open >= 2 else ""
	h3.cam_follow(ground(p).pos, "near", 2.5, float(p.node))
	Audio.play("select")
	for q in G.players:
		if q != p:
			Net.set_ctrl(q.pid, {"mode": "wait", "char": p.char_id, "title": "%s következik" % p.name, "text": "Figyeld a képernyőt!"})
	await sleep(0.6)
	var n: int = maxi(1, p.hw_dice)
	var res := await roll_dice(p, n, "std", true, "Koppints a dobáshoz! (%d kocka)" % n)
	var total: int = res.total
	p.hw_total = total
	Net.push_status(p.pid)
	print_verbose("[hw] %s dob: %d kocka -> %s = %d%s" % [p.name, n, str(res.vals), total, " (EGYFORMA!)" if res.matched else ""])
	await sleep(0.3)
	await move(p, total)
	if G.mtn_winner == null:
		await land(p)
	Net.push_status(p.pid)
	await sleep(0.4)


## Dobás: n kocka (kind: "std" = hatoldalú, "light" = piros/zöld lámpakocka, "boost" = +10/+20/+30-as felzárkózó kocka). Igaz allow_match esetén
## egyforma kockáknál +HL.MATCH_BONUS kocka. Visszaad: {total, vals, matched, grade}.
func roll_dice(p, n: int, kind: String, allow_match: bool, hint: String, judge := true) -> Dictionary:
	var g := ground(p)
	dice = {"p": p, "origin": g.pos, "vals": [], "kind": kind, "t0s": [], "gold": false, "bonus_from": 99}
	total_fx = null
	h3.cam_follow(g.pos, "close" if n <= 3 else "near", 3.0, g.s)
	var label: String = {"std": "🎲 DOBJ!", "light": "🚦 DOBJ!", "boost": "🆙 DOBJ!"}.get(kind, "🎲 DOBJ!")
	await Net.ask(p.pid, {"mode": "tap", "label": label, "hint": hint, "botAuto": true}, ["tap"], 25)
	var vals: Array = []
	for i in n:
		if kind == "light":
			vals.append(1 if randi_range(1, 6) <= HL.LIGHT_GREEN_FACES else 0)
		elif kind == "boost":
			vals.append(HL.LAST_BOOST[randi() % HL.LAST_BOOST.size()])
		else:
			vals.append(randi_range(1, 6))
	dice.vals = vals.duplicate()
	for i in n:
		dice.t0s.append(t + i * 0.05)
	h3.pose(p.pid, "throw", 0.6)
	Audio.play("jump")
	Net.vibrate(p.pid, 60)
	after(0.75, func(): Audio.play("hit"))
	after(0.95, func(): Audio.play("land"))
	await sleep(1.05 + n * 0.05)
	var total := 0
	for v in vals:
		total += int(v)
	var matched := false
	if allow_match and kind == "std" and n >= 2 and vals.all(func(v): return v == vals[0]):
		matched = true
		dice.gold = true
		total_fx = {"p": p, "total": total, "t0": t, "grade": "good", "gold": true, "label": "EGYFORMA!"}
		Audio.play("fanfare")
		Audio.play("sparkle")
		h3.pose(p.pid, "cheer", 1.8)
		h3.crowd(float(p.node), true)
		Main.I.confetti(40)
		await toast("✨ MIND EGYFORMA!", "+%d bónuszkocka!" % HL.MATCH_BONUS, 1.6, p)
		var b0: int = dice.vals.size()
		dice.bonus_from = b0
		for i in HL.MATCH_BONUS:
			var v := randi_range(1, 6)
			dice.vals.append(v)
			dice.t0s.append(t + i * 0.06)
			total += v
		Audio.play("jump")
		after(0.8, func(): Audio.play("hit"))
		await sleep(1.2)
	if kind == "light":
		await sleep(0.3)
		var greens := 0
		for v in vals:
			greens += int(v)
		var r := {"total": greens, "vals": vals, "matched": false, "grade": "ok"}
		await sleep(0.4)
		dice = null
		return r
	var grade := HL.grade(total, n) if judge else "ok"
	if matched:
		grade = "good"
	total_fx = {"p": p, "total": total, "t0": t, "grade": grade, "gold": grade == "good", "label": total_fx.label if total_fx else ""}
	if judge:
		match grade:
			"good":
				Audio.play("coin")
				h3.pose(p.pid, "fist", 1.6)
				h3.crowd(float(p.node), true)
			"bad":
				Audio.play("fail")
				h3.pose(p.pid, "hips", 1.8)
				h3.crowd(float(p.node), false)
	await sleep(1.1)
	dice = null
	return {"total": total, "vals": vals, "matched": matched, "grade": grade}


## Előre fut steps mezőt; ellenőrzőpontnál megáll és próbálkozik (siker esetén megy tovább a maradékkal).
func move(p, steps: int) -> void:
	var left := steps
	while left > 0 and G.mtn_winner == null:
		var cp := HL.next_cp(cp_done(p))
		var target: int = mini(p.node + left, cp)
		if target > p.node:
			walk = {"pid": p.pid, "left": left, "dir": 1}
			left -= target - p.node
			await run(p, target)
			walk = null
		if p.node == cp:
			if not await arrive_cp(p):
				return
	total_fx = null


## Hány ellenőrzőpont van már nyitva előtte: a sajátjai, vagy amit bárki más már kinyitott.
func cp_done(p) -> int:
	return maxi(p.hw_cp, G.hw_open)


## Ellenőrzőpontra érkezett (vagy UFO/rakéta oda tette): próbálkozás. Igaz, ha továbbmehet.
func arrive_cp(p) -> bool:
	var cp := HL.next_cp(cp_done(p))
	if p.node != cp:
		return true
	total_fx = null
	if cp == HL.GOAL:
		await final_gate(p)
		return false
	if cp == HL.CP_BRIDGE:
		return await bridge(p)
	return await lights(p)


func run(p, to: int) -> void:
	var from: int = p.node
	if to == from:
		return
	var dur := clampf(absf(to - from) / HL.RUN_SPEED, 0.35, 5.5)
	runs[p.pid] = {"from": float(from), "to": float(to), "t0": t, "dur": dur}
	await sleep(dur)
	runs.erase(p.pid)
	p.node = to
	p.stats.steps += maxi(0, to - from)
	Audio.play("land")
	Net.push_status(p.pid)


func back(p, n: int) -> void:
	var to := maxi(0, p.node - n)
	walk = {"pid": p.pid, "left": p.node - to, "dir": -1}
	await run(p, to)
	walk = null


# ------------------------------------------------------------------ ellenőrzőpontok
func bridge(p) -> bool:
	h3.bridge_target = 0.0
	h3.cam_at(HL.pos(HL.CP_BRIDGE) + HL.rot(HL.CP_BRIDGE, Vector3(0, 1.2, -1.0)), Vector3(5.0, 4.0, 7.5), 2.5, HL.heading(HL.CP_BRIDGE))
	await toast("🌉 Felvonóhíd", "%s egy kockával dob: páratlan kell (1, 3 vagy 5)!" % p.name, 2.0, p)
	var r := await roll_dice(p, 1, "std", false, "Páratlan kell: 1, 3 vagy 5!", false)
	var v: int = r.total
	print_verbose("[hw] híd: %s -> %d" % [p.name, v])
	if v % 2 == 1:
		p.hw_cp = 1
		G.hw_open = maxi(G.hw_open, 1)
		h3.bridge_target = 1.0
		Audio.play("clank")
		Audio.play("fanfare")
		h3.pose(p.pid, "cheer", 1.8)
		h3.crowd(float(p.node), true)
		await toast("🌉 Leereszkedett a híd!", "%d – páratlan! %s mehet tovább, és a híd mostantól mindenkinek nyitva marad." % [v, p.name], 2.4, p)
		return true
	Audio.play("fail")
	h3.pose(p.pid, "hips", 1.8)
	h3.crowd(float(p.node), false)
	await toast("🌉 A híd fent maradt", "%d – páros. %s egyet visszalép, és legközelebb újra próbálja." % [v, p.name], 2.2, p)
	await back(p, 1)
	return false


func lights(p) -> bool:
	h3.gate_target = 0.0
	h3.gate_light = "blink"
	h3.cam_at(HL.pos(HL.CP_LIGHTS) + HL.rot(HL.CP_LIGHTS, Vector3(0, 1.6, -1.0)), Vector3(5.0, 4.2, 8.0), 2.5, HL.heading(HL.CP_LIGHTS))
	await toast("🚦 Jelzőlámpás kapu", "%s %d lámpakockával dob: több ZÖLD kell, mint piros!" % [p.name, HL.LIGHT_DICE], 2.0, p)
	var r := await roll_dice(p, HL.LIGHT_DICE, "light", false, "Több zöld kell, mint piros!", false)
	var greens: int = r.total
	var reds: int = HL.LIGHT_DICE - greens
	print_verbose("[hw] lámpa: %s -> %d zöld, %d piros" % [p.name, greens, reds])
	if greens > reds:
		p.hw_cp = 2
		G.hw_open = maxi(G.hw_open, 2)
		h3.gate_light = "green"
		h3.gate_target = 1.0
		Audio.play("bell")
		Audio.play("fanfare")
		h3.pose(p.pid, "cheer", 1.8)
		h3.crowd(float(p.node), true)
		await toast("🚦 ZÖLD! Nyílik a kapu!", "%d zöld, %d piros – %s mehet tovább, és a kapu örökre nyitva marad mindenkinek." % [greens, reds, p.name], 2.4, p)
		if not G.hw_choose:
			G.hw_choose = true
			await toast("🎮 Mostantól az utolsó választ", "Minden kör előtt a sereghajtó választ minijátékot három közül.", 2.6)
		return true
	h3.gate_light = "red"
	Audio.play("fail")
	h3.pose(p.pid, "hips", 1.8)
	h3.crowd(float(p.node), false)
	await toast("🚦 Több a piros!", "%d zöld, %d piros – %s egyet visszalép, és legközelebb újra próbálja." % [greens, reds, p.name], 2.2, p)
	await back(p, 1)
	return false


func final_gate(p) -> void:
	var need: int = HL.FINAL_NEED[mini(p.hw_final, HL.FINAL_NEED.size() - 1)]
	h3.cam_at(HL.pos(HL.GOAL) + HL.rot(HL.GOAL, Vector3(0, 2.0, -1.0)), Vector3(5.5, 4.0, 9.0), 2.5, HL.heading(HL.GOAL))
	await toast("🏁 CÉLKAPU!", "%s %d kockával dob: legalább %d kell!" % [p.name, HL.FINAL_DICE, need], 2.4, p)
	var r := await roll_dice(p, HL.FINAL_DICE, "std", false, "Legalább %d kell!" % need, false)
	var total: int = r.total
	print_verbose("[hw] célkapu: %s -> %d (kell %d)" % [p.name, total, need])
	if total >= need:
		G.mtn_winner = p
		return
	p.hw_final += 1
	Audio.play("fail")
	h3.pose(p.pid, "sad", 1.8)
	h3.crowd(float(p.node), false)
	await toast("🏁 Nem nyílt ki…", "%d, pedig %d kellett. %s %d mezőt visszafut; legközelebb %d is elég." % [total, need, p.name, HL.FINAL_FAIL_BACK, HL.FINAL_NEED[mini(p.hw_final, HL.FINAL_NEED.size() - 1)]], 2.6, p)
	await back(p, HL.FINAL_FAIL_BACK)


# ------------------------------------------------------------------ különleges mezők
## Egy lépésre legfeljebb EGY mezőhatás: a land() csak a rendes dobás utáni lépés végén fut (turn),
## a hatások mozgatása (move/back/transport) soha nem hív újra land()-et. Így a sok szomszédos
## különleges mező (pl. hatos +10-es csoport) sem okozhat végtelen láncot.
func land(p) -> void:
	var sp := HL.special(p.node)
	if sp.is_empty():
		return
	var kind: String = sp[0]
	var val: int = sp[1]
	var info: Dictionary = HL.INFO[kind]
	p.stats.events += 1
	print_verbose("[hw] mező: %s @%d -> %s %d" % [p.name, p.node, kind, val])
	match kind:
		"F":
			Audio.play("sparkle")
			h3.pose(p.pid, "cheer", 1.4)
			h3.crowd(float(p.node), true)
			await toast("%s Hátszél! +%d" % [info.icon, val], "%s előrefut %d mezőt" % [p.name, val], 1.6, p)
			await move(p, val)
		"B":
			Audio.play("bad")
			h3.pose(p.pid, "sad", 1.6)
			h3.crowd(float(p.node), false)
			await toast("%s Szembeszél! −%d" % [info.icon, val], "%s visszafut %d mezőt" % [p.name, val], 1.6, p)
			await back(p, val)
		"BD":
			Audio.play("coin")
			h3.crowd(float(p.node), true)
			await toast("🎲 Kék kockamező!", "%s még %d kockával dob, és annyit fut előre" % [p.name, val], 1.8, p)
			var r := await roll_dice(p, val, "std", true, "Előre! %d kocka" % val)
			await move(p, r.total)
		"RD":
			Audio.play("bad")
			h3.crowd(float(p.node), false)
			await toast("🎲 Piros kockamező!", "%s %d kockával dob, és annyit fut VISSZA" % [p.name, val], 1.8, p)
			var r := await roll_dice(p, val, "std", false, "Vissza… %d kocka" % val, false)
			h3.pose(p.pid, "sad", 1.6)
			await back(p, r.total)
		"LAST":
			await _last_boost(p)
		"UFO":
			var others: Array = G.players.filter(func(q): return q != p)
			if others.is_empty():
				await toast("🛸 UFO!", "Nincs kihez vinni – 10 mezővel előrébb teszi le", 1.8, p)
				await transport(p, "ufo", p.node + 10)
			else:
				var q = others[randi() % others.size()]
				await toast("🛸 UFO!", "Elrabolja %s-t, és %s mellé viszi" % [p.name, q.name], 1.8, p)
				await transport(p, "ufo", q.node)
		"ROCKET":
			# soha nem visz hátra, és le nem győzött ellenőrzőponton sem repül át
			var dest: int = mini(maxi(p.node, HL.ROCKET_TO), HL.next_cp(cp_done(p)))
			if dest <= p.node:
				await toast("🚀 Rakéta", "%s már túl van a rakéta célján – most nem száll fel." % p.name, 1.6, p)
				return
			await toast("🚀 Rakéta!", "%s a %d. mezőig repül!" % [p.name, dest], 1.6, p)
			await transport(p, "rocket", dest)
		"DUEL":
			await _duel_space(p)


## Felzárkózó mező: BÁRKI lép rá, ő dob a felzárkózó kockával (+10 / +20 / +30), és annyit lép előre
## az, aki abban a pillanatban az utolsó (holtversenynél mindegyik utolsó). Ellenőrzőponton nem fut át:
## ott megáll, és a saját körében próbálkozik.
func _last_boost(p) -> void:
	Audio.play("coin")
	h3.crowd(float(p.node), true)
	await toast("🆙 Felzárkózó mező!", "%s dob a felzárkózó kockával: amennyit dob (+10, +20 vagy +30), annyit lép előre az utolsó!" % p.name, 2.2, p)
	var r := await roll_dice(p, 1, "boost", false, "+10 / +20 / +30 az utolsónak!", false)
	var amount: int = r.total
	var low := 999999
	for q in G.players:
		low = mini(low, q.node)
	var lasts: Array = G.players.filter(func(q): return q.node == low)
	var names := ", ".join(lasts.map(func(q): return q.name))
	print_verbose("[hw] felzárkózó: %s dobott +%d -> %s" % [p.name, amount, names])
	Audio.play("fanfare")
	for q in lasts:
		h3.pose(q.pid, "cheer", 1.6)
	await toast("🆙 +%d az utolsónak!" % amount, "%s előrefut %d mezőt" % [names, amount], 1.9, lasts[0])
	for q in lasts:
		await _boost_run(q, amount)


func _boost_run(q, n: int) -> void:
	var cp := HL.next_cp(cp_done(q))
	var to: int = mini(q.node + n, cp)
	if to <= q.node:
		return
	var g := ground(q)
	h3.cam_follow(g.pos, "near", 2.5, g.s)
	walk = {"pid": q.pid, "left": to - q.node, "dir": 1}
	await run(q, to)
	walk = null
	if q.node == cp:
		await toast("⛔ Ellenőrzőpont", "%s itt megáll – a saját körében próbálkozik." % q.name, 1.6, q)


func _duel_space(p) -> void:
	if G.players.size() <= 1:
		# egyedül nincs ellenfél: helyette bónuszkihívás – egy kockával 4+ kell
		await toast("⚔️ Egyszemélyes kihívás", "Egy kockával 4, 5 vagy 6 kell – ha sikerül, %d bónuszkocka!" % HL.DUEL_SOLO_DICE, 2.2, p)
		var r := await roll_dice(p, 1, "std", false, "4, 5 vagy 6 kell!", false)
		if int(r.total) >= 4:
			Audio.play("fanfare")
			h3.pose(p.pid, "cheer", 1.6)
			await toast("⚔️ Sikerült!", "%d bónuszkocka jár!" % HL.DUEL_SOLO_DICE, 1.6, p)
			var b := await roll_dice(p, HL.DUEL_SOLO_DICE, "std", true, "Bónusz: %d kocka" % HL.DUEL_SOLO_DICE)
			await move(p, b.total)
		else:
			Audio.play("fail")
			h3.pose(p.pid, "hips", 1.4)
			await toast("⚔️ Most nem jött össze", "", 1.4, p)
		return
	if G.hw_duel != "":
		await toast("⚔️ 1 a többiek ellen", "Ebben a körben már van párbaj.", 1.6, p)
		return
	G.hw_duel = p.pid
	Audio.play("horn")
	h3.pose(p.pid, "fist", 1.6)
	var vs_txt := "1 a 3 ellen: 3 véletlenül sorsolt ellenféllel" if G.players.size() >= 4 else "kettesben egy véletlen ellenféllel"
	await toast("⚔️ Párbaj-mező: %s!" % p.name, "A kör végén párbaj-minijáték (%s). Ha %s nyer, +%d kocka; ha az ellenfelek, fejenként +%d." % [vs_txt, p.name, HL.DUEL_SOLO_DICE, HL.DUEL_TEAM_DICE], 3.0, p)


## A párbaj eredménye után (G.hw_bonus): a nyertesek bónuszkockákkal dobnak és előrefutnak.
func _duel_bonus() -> void:
	var list: Array = G.hw_bonus.duplicate()
	G.hw_bonus = []
	G.hw_duel = ""
	_cam_all()
	if list.is_empty():
		await toast("⚔️ Döntetlen párbaj", "Most senki sem kap bónuszkockát.", 1.8)
		return
	for e in list:
		var p = G.by_pid(str(e.pid))
		if p == null:
			continue
		current = p
		h3.cam_follow(ground(p).pos, "near", 2.5, float(p.node))
		await toast("⚔️ %s: +%d bónuszkocka" % [p.name, int(e.n)], "", 1.4, p)
		var r := await roll_dice(p, int(e.n), "std", true, "Bónusz: %d kocka" % int(e.n))
		await move(p, r.total)
		if G.mtn_winner:
			return
		Net.push_status(p.pid)
	current = null


## UFO / rakéta: elviszi a figurát a dest mezőre (nem lép át le nem győzött ellenőrzőponton).
func transport(p, kind: String, dest: int) -> void:
	dest = clampi(dest, 0, HL.GOAL)
	var cp := HL.next_cp(cp_done(p))
	dest = mini(dest, cp)
	var a: Vector3 = ground(p).pos
	var b := HL.pos(dest, p.hw_lane)
	carry = {"pid": p.pid, "kind": kind, "a": a, "b": b, "t0": t}
	# a repülés irányából nézve, oldalról-hátulról; minél messzebbre visz, annál hátrébb
	var fly := Vector3(b.x - a.x, 0, b.z - a.z)
	var yaw := HL.heading(float(p.node)) if fly.length() < 0.5 else atan2(fly.x, -fly.z)
	var dist := a.distance_to(b)
	h3.cam_at((a + b) / 2.0 + Vector3(0, 3.0, 0), Vector3(9.0, 9.0 + dist * 0.25, 16.0 + dist * 0.35), 1.8, yaw)
	if kind == "ufo":
		Audio.play("whoosh", 0.6)
		after(1.0, func(): Audio.play("sparkle", 0.7))
		after(1.9, func(): Audio.play("whoosh", 0.8))
		after(1.0, func(): h3.pose(p.pid, "scared", 3.0))
		await sleep(Highway3D.UFO_DUR)
	else:
		after(0.6, func(): Audio.play("jump"))
		after(1.1, func(): Audio.play("tremble"))
		after(1.5, func(): Audio.play("launch"))
		after(3.9, func(): Audio.play("land"))
		after(1.5, func(): h3.pose(p.pid, "cheer", 2.5))
		await sleep(Highway3D.ROCKET_DUR)
	carry = null
	p.node = dest
	h3.shake = 0.6
	Net.push_status(p.pid)
	h3.cam_follow(ground(p).pos, "near", 3.0, float(p.node))
	await sleep(0.4)
	if p.node == HL.next_cp(cp_done(p)):
		await arrive_cp(p)


func _win(p) -> void:
	done = true
	print_verbose("[hw] győztes: %s, %d. kör" % [p.name, G.round])
	current = p
	h3.final_target = 1.0
	h3.cam_at(HL.pos(HL.GOAL) + HL.rot(HL.GOAL, Vector3(0, 2.0, -2.0)), Vector3(4.5, 3.6, 9.0), 2.0, HL.heading(HL.GOAL))
	Audio.play("crown")
	Audio.jingle("victory")
	for q in G.players:
		Net.set_ctrl(q.pid, {"mode": "wait", "icon": "🏁", "title": "%s célba ért!" % p.name, "text": "Vége a játéknak!"})
	Net.vibrate(p.pid, [100, 50, 100, 50, 300])
	await sleep(1.0)
	# átfut a kinyílt kapun
	runs[p.pid] = {"from": float(HL.GOAL), "to": float(HL.GOAL) + 5.0, "t0": t, "dur": 1.2}
	await sleep(1.2)
	h3.pose(p.pid, "cheer", 6.0)
	for c in 4:
		after(c * 0.7, func():
			Main.I.confetti(60)
			Audio.play("firework")
			var q := pawn_xy(p)
			Main.I.burst(q.x + (c - 1.5) * 160, q.y - 120, {"n": 50, "colors": ["#ffd43b", "#ff6b6b", "#4dabf7", "#69db7c", "#ffffff"], "speed": 520}))
	h3.crowd(float(HL.GOAL), true)
	await toast("🏁 %s ÁTJUTOTT A CÉLKAPUN!" % p.name, "%d kör alatt tette meg az Óceánsztrádát" % G.round, 4.0, p)
	G.phase = "final"
	Main.I.set_scene(FinalScene.new())


func toast(title: String, sub := "", dur := 1.6, p = null) -> void:
	toast_obj = {"title": title, "sub": sub, "t0": t, "dur": dur, "p": p}
	await sleep(dur)
	if toast_obj and toast_obj.title == title:
		toast_obj = null


# ------------------------------------------------------------------ pozíciók
func ground(p) -> Dictionary:
	if carry != null and carry.pid == p.pid:
		var tt: float = t - float(carry.t0)
		var f: Dictionary = Highway3D.ufo_frame(carry.a, carry.b, tt) if carry.kind == "ufo" else Highway3D.rocket_frame(carry.a, carry.b, tt)
		return {"pos": f.pawn, "h": 0.0, "carried": true, "s": NAN}
	if runs.has(p.pid):
		var r: Dictionary = runs[p.pid]
		var k: float = clampf((t - float(r.t0)) / float(r.dur), 0.0, 1.0)
		var e := D.ease_in_out(k) if float(r.dur) < 1.0 else _run_ease(k)
		var s := lerpf(r.from, r.to, e)
		return {"pos": HL.pos(s, p.hw_lane), "h": 0.0, "s": s}
	return {"pos": HL.pos(p.node, p.hw_lane), "h": 0.0, "s": float(p.node)}


## hosszú futásnál egyenletes tempó, csak az elején-végén gyorsul/lassul
static func _run_ease(k: float) -> float:
	var a := 0.12
	if k < a:
		return k * k / (2.0 * a * (1.0 - a))
	if k > 1.0 - a:
		var q := 1.0 - k
		return 1.0 - q * q / (2.0 * a * (1.0 - a))
	return (k - a / 2.0) / (1.0 - a)


func pawn_xy(p) -> Vector2:
	var g := ground(p)
	return h3.project((g.pos as Vector3) + Vector3(0, 1.3, 0))


func _cam_all() -> void:
	var lo := 99999.0
	var hi := -1.0
	for p in G.players:
		lo = minf(lo, p.node)
		hi = maxf(hi, p.node)
	if hi < 0.0:
		lo = 0.0
		hi = 0.0
	h3.cam_span(lo, hi)


# ------------------------------------------------------------------ frissítés + rajz
func update(dt: float) -> void:
	if current and runs.has(current.pid):
		var r: Dictionary = runs[current.pid]
		var g := ground(current)
		h3.cam_follow(g.pos, "near" if absf(float(r.to) - float(r.from)) < 25 else "mid", 4.0, g.s)
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.17
			Audio.play("step", 1.0 + fmod(t * 7.0, 0.1))
	_render(dt)


func _render(dt: float) -> void:
	var pawns: Array = []
	for p in G.players:
		var g := ground(p)
		pawns.append({"p": p, "pos": g.pos, "h": g.h, "current": p == current, "carried": g.get("carried", false)})
	var dc = null
	if dice:
		dc = {"origin": dice.origin, "vals": dice.vals, "kind": dice.kind, "t0s": dice.t0s, "gold": dice.gold, "bonus_from": dice.bonus_from}
	h3.render({"pawns": pawns, "carry": carry, "dice": dc, "now": t}, dt)


func draw(c: CanvasItem) -> void:
	if total_fx and total_fx.p:
		_draw_total(c)
	if walk != null and not (total_fx and total_fx.p and total_fx.p.pid == walk.pid):
		_draw_walk(c)
	_draw_hud(c)
	_draw_progress(c)
	if toast_obj:
		_draw_toast(c)


func _draw_total(c: CanvasItem) -> void:
	var o: Dictionary = total_fx
	var p = o.p
	var k: float = t - float(o.t0)
	var q := pawn_xy(p)
	if q.x < -500:
		return
	var shown: int = int(round(float(o.total) * clampf(k / 0.5, 0.0, 1.0)))
	# futás közben a dobott szám mezőről mezőre fogy: látszik, hol áll meg
	var left := _walk_left(p.pid)
	if left >= 0:
		shown = left
	var gold: bool = o.gold
	var bad: bool = o.grade == "bad"
	var s := D.ease_out_back(clampf(k * 3.0, 0.0, 1.0))
	var rot := sin(k * 18.0) * 0.12 * maxf(0.0, 1.0 - k) if bad else 0.0
	var y := clampf(q.y - 250.0, 110.0, 600.0)
	c.draw_set_transform(Vector2(q.x, y), rot, Vector2(s, s))
	var col := Color("#ffd43b") if gold else (Color("#c9d2df") if bad else Color.WHITE)
	var stroke := Color("#a34a00") if gold else D.DARK
	for i in range(4, 0, -1):
		D.text(c, str(shown), i * 1.2, i * 2.0, {"size": 96, "color": stroke.darkened(0.3), "stroke": stroke.darkened(0.5), "sw": 12})
	D.text(c, str(shown), 0, 0, {"size": 96, "color": col, "stroke": stroke, "sw": 12})
	var lab: String = o.label
	if lab == "":
		lab = {"good": "SZUPER DOBÁS!", "bad": "Hát ez kevés…", "ok": ""}.get(o.grade, "")
	if lab != "":
		D.text(c, lab, 0, 70, {"size": 28, "color": Color("#ffe066") if gold else Color("#e5dbff"), "stroke": D.DARK, "sw": 6})
	c.draw_set_transform(Vector2.ZERO)


## Hány lépés van még hátra a pid figura mostani futásából (-1, ha nem fut).
func _walk_left(pid: String) -> int:
	if walk == null or walk.pid != pid or not runs.has(pid):
		return -1
	var r: Dictionary = runs[pid]
	var k: float = clampf((t - float(r.t0)) / float(r.dur), 0.0, 1.0)
	var e := D.ease_in_out(k) if float(r.dur) < 1.0 else _run_ease(k)
	var done_steps := int(floor(absf(float(r.to) - float(r.from)) * e + 0.001))
	return maxi(0, int(walk.left) - done_steps)


## Lépésszámláló buborék a futó figura fölött (hátszél, felzárkózó, visszalépés: ahol nincs dobott szám).
func _draw_walk(c: CanvasItem) -> void:
	var p = G.by_pid(str(walk.pid))
	var left := _walk_left(str(walk.pid))
	if p == null or left < 0:
		return
	var q := pawn_xy(p)
	if q.x < -500:
		return
	var back_run: bool = int(walk.dir) < 0
	var y := clampf(q.y - 150.0, 90.0, 600.0)
	var fill := Color("#c92a2a") if back_run else Color("#2b1055")
	c.draw_circle(Vector2(q.x, y), 34, Color.WHITE)
	c.draw_circle(Vector2(q.x, y), 29, fill)
	D.text(c, ("−%d" if back_run else "%d") % left, q.x, y + 1, {"size": 34, "color": Color.WHITE, "stroke": D.DARK, "sw": 4})
	D.text(c, "👣 vissza" if back_run else "👣 lépés", q.x, y + 50, {"size": 18, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 5})


func _draw_hud(c: CanvasItem) -> void:
	D.panel(c, 14, 8, 200, 44, {"r": 14, "fill": Color(0.06, 0.12, 0.3, 0.85)})
	D.text(c, "🛣️ %d. kör" % G.round, 114, 31, {"size": 23})
	var n := G.players.size()
	var gap := 6.0
	var cw: float = minf(232.0, (1252.0 - (n - 1) * gap) / n)
	var x0 := 640.0 - (n * cw + (n - 1) * gap) / 2.0
	var narrow := cw < 180.0
	for i in n:
		var p = G.players[i]
		var cur: bool = p == current
		var x := x0 + i * (cw + gap)
		var y := 614.0 if cur else 622.0
		var col := Color(Highway3D.SLOT_COLORS[p.hw_lane % 8])
		D.panel(c, x, y, cw, 92, {"r": 16, "fill": D.shade(col, -0.55), "stroke": Color("#ffd43b") if cur else col, "lw": 5 if cur else 3})
		D.panel(c, x + 6, y + 6, 46, 46, {"r": 23, "fill": Color.WHITE, "stroke": col, "lw": 3, "shadow": false})
		D.char_image(c, p.char_id, x + 29, y + 29, 42, 1.0 if (p.connected or p.is_bot) else 0.45)
		D.text(c, "%d." % G.place_of(p), x + 29, y + 70, {"size": 18, "color": Color("#ffd43b")})
		D.text(c, p.name, x + 58, y + 17, {"size": 15 if narrow else 18, "align": "left", "maxw": cw - 64})
		D.text(c, "📍%d" % p.node, x + 58, y + 41, {"size": 16 if narrow else 19, "align": "left", "color": Color("#ffe066"), "maxw": cw - 64})
		D.text(c, "🎲×%d  Σ%d" % [p.hw_dice, p.hw_total], x + 58, y + 66, {"size": 14 if narrow else 17, "align": "left", "maxw": cw - 64})
		if not p.connected and not p.is_bot:
			D.text(c, "📵", x + cw - 14, y + 18, {"size": 16})


## Felül vízszintes pálya-mérő: ki hol tart, hol vannak az ellenőrzőpontok.
func _draw_progress(c: CanvasItem) -> void:
	var x0 := 250.0
	var x1 := 1240.0
	var y := 30.0
	D.panel(c, x0 - 20, y - 22, x1 - x0 + 40, 44, {"r": 20, "fill": Color(0.06, 0.12, 0.3, 0.8)})
	c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.35), 6, true)
	for cp in [HL.CP_BRIDGE, HL.CP_LIGHTS, HL.GOAL]:
		var cx := lerpf(x0, x1, float(cp) / HL.GOAL)
		c.draw_line(Vector2(cx, y - 14), Vector2(cx, y + 14), Color("#ffd43b"), 4, true)
		D.emoji(c, {HL.CP_BRIDGE: "🌉", HL.CP_LIGHTS: "🚦", HL.GOAL: "🏁"}[cp], cx, y - 2, 18)
		# végleg kinyitva (valaki már átjutott): zöld pipa
		if (cp == HL.CP_BRIDGE and G.hw_open >= 1) or (cp == HL.CP_LIGHTS and G.hw_open >= 2):
			c.draw_circle(Vector2(cx + 13, y + 11), 8, Color("#2fb344"))
			D.text(c, "✓", cx + 13, y + 11, {"size": 13, "color": Color.WHITE})
	var by := {}
	for p in G.players:
		var s: float = float(p.node)
		if runs.has(p.pid):
			var r: Dictionary = runs[p.pid]
			s = lerpf(r.from, r.to, clampf((t - float(r.t0)) / float(r.dur), 0.0, 1.0))
		var key := int(s / 6.0)
		var k: int = by.get(key, 0)
		by[key] = k + 1
		var px := lerpf(x0, x1, s / HL.GOAL)
		D.avatar(c, p, px, y + 2 + k * 9 - (4 if k > 0 else 0), 11, {"shadow": false, "ring": Color("#ffd43b") if p == current else null})


func _draw_toast(c: CanvasItem) -> void:
	var o: Dictionary = toast_obj
	var age: float = t - o.t0
	var s := D.ease_out_back(min(1.0, age * 4.0))
	var a: float = clamp((o.dur - age) * 5.0, 0.0, 1.0)
	var p = o.p
	c.draw_set_transform(Vector2(640, 160), 0, Vector2(s, s))
	var has_sub: bool = o.sub != ""
	var long_sub: bool = D.text_width(o.sub, 24) > 760
	var fill := Color(D.shade(p.color, -0.5), 0.94 * a) if p else Color(0.06, 0.12, 0.3, 0.94 * a)
	var stroke := Color(p.color, a) if p else Color(1, 0.83, 0.23, a)
	D.panel(c, -420, -78, 840, (190 if long_sub else 156) if has_sub else 110, {"fill": fill, "stroke": stroke, "lw": 5, "r": 28, "shadow": false})
	D.text(c, o.title, 0, -30 if has_sub else -23, {"size": 46, "stroke": D.DARK, "sw": 8, "maxw": 800, "alpha": a})
	if has_sub:
		if long_sub:
			D.wrap(c, o.sub, 0, 28, 790, 30, {"size": 23, "color": Color("#e5dbff"), "alpha": a, "align": "center"})
		else:
			D.text(c, o.sub, 0, 34, {"size": 24, "color": Color("#e5dbff"), "maxw": 800, "alpha": a})
	c.draw_set_transform(Vector2.ZERO)
