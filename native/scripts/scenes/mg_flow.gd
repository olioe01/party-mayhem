class_name MgFlow
## Minijáték körítés: csapatbeosztás + sorsolás -> leírás + "kész" -> visszaszámlálás -> játék -> eredmény

const AWARDS := [10, 6, 3, 1]
const MEDALS := ["🥇", "🥈", "🥉"]
const TEAM_COLORS := [Color("#3b82f6"), Color("#ef4444")]
const TEAM_NAMES := ["KÉK", "PIROS"]

const GAMES := [
	preload("res://scripts/minigames/mg_rocket.gd"),
	preload("res://scripts/minigames/mg_reaction.gd"),
	preload("res://scripts/minigames/mg_arena.gd"),
	preload("res://scripts/minigames/mg_coinrain.gd"),
	preload("res://scripts/minigames/mg_memory.gd"),
	preload("res://scripts/minigames/mg_count.gd"),
	preload("res://scripts/minigames/mg_blindtimer.gd"),
	preload("res://scripts/minigames/mg_quickmath.gd"),
	preload("res://scripts/minigames/mg_stopper.gd"),
	preload("res://scripts/minigames/mg_beam.gd"),
	preload("res://scripts/minigames/mg_statue.gd"),
	preload("res://scripts/minigames/mg_tug.gd"),
	preload("res://scripts/minigames/mg_balloons.gd"),
	preload("res://scripts/minigames/mg_hoops.gd"),
	preload("res://scripts/minigames/mg_sheep.gd"),
	preload("res://scripts/minigames/mg_cups.gd"),
	preload("res://scripts/minigames/mg_bomb.gd"),
	preload("res://scripts/minigames/mg_paint.gd"),
	preload("res://scripts/minigames/mg_ice.gd"),
	preload("res://scripts/minigames/mg_tower.gd"),
	preload("res://scripts/minigames/mg_fishing.gd"),
	preload("res://scripts/minigames/mg_flash.gd"),
	preload("res://scripts/minigames/mg_rhythm.gd"),
]

static var _metas := {}


static func meta_of(script: Script) -> Dictionary:
	if not _metas.has(script):
		var inst: Minigame = script.new()
		_metas[script] = inst.meta()
		inst.free()
	return _metas[script]


static func all_metas() -> Array:
	var out: Array = []
	for s in GAMES:
		var m := meta_of(s).duplicate()
		m["script"] = s
		out.append(m)
	return out


static func find(id: String):
	for m in all_metas():
		if m.id == id:
			return m
	return null


## Csapatbeosztás az utolsó mező színe alapján (csak 4 játékosnál):
## piros mező = piros csapat, kék/bolt/rajt/barát = kék, a többi (esemény, ugrópad) véletlen.
static func split_teams() -> Dictionary:
	var colors := {}
	for p in G.players:
		var c := 0
		if p.last_space == "R": c = 1
		elif p.last_space in ["E", "V", "J", ""]: c = randi() % 2
		colors[p.pid] = c
	# hegymászásnál nincs csapat: a helyezés osztja a kockákat
	if G.players.size() != 4 or G.is_mountain():
		return {"mode": "ffa", "colors": colors, "teams": []}
	var blue: Array = G.players.filter(func(p): return colors[p.pid] == 0)
	var red: Array = G.players.filter(func(p): return colors[p.pid] == 1)
	if blue.size() == 2:
		return {"mode": "2v2", "colors": colors, "teams": [blue, red]}
	if blue.size() == 1 or red.size() == 1:
		var solo: Array = blue if blue.size() == 1 else red
		var trio: Array = red if blue.size() == 1 else blue
		return {"mode": "1v3", "colors": colors, "teams": [trio, solo] if blue.size() == 3 else [solo, trio]}
	return {"mode": "ffa", "colors": colors, "teams": []}


static func bg(c: CanvasItem, hue := 265.0) -> void:
	var top := Color.from_hsv(hue / 360.0, 0.6, 0.32)
	var bot := Color.from_hsv(fmod(hue + 30.0, 360.0) / 360.0, 0.7, 0.09)
	D.vgrad(c, top, bot)
	for i in 14:
		var x := fmod(i * 137.0 + Main.I.time * 30.0, 1480.0) - 100.0
		c.draw_circle(Vector2(x, fmod(i * 211.0, 720.0)), 40.0 + (i % 4) * 30.0, Color(1, 1, 1, 0.07))


# ------------------------------------------------------------------ sorsolás
class SelectScene:
	extends GameScene
	var force := ""
	var choice: Dictionary
	var strip: Array = []
	var target := 26
	var dur := 3.4
	var last_idx := -1
	var landed := false
	var split: Dictionary
	var stage := "teams"
	var roll_t0 := 0.0

	func _init(f := "") -> void:
		force = f

	func enter() -> void:
		G.phase = "mg"
		Audio.music("mg_select")
		split = MgFlow.split_teams()
		G.team_split = split.teams
		var metas := MgFlow.all_metas()
		var mode: String = split.mode
		var pool: Array = metas.filter(func(m): return m.modes.has(mode) and not G.recent_mg.has(m.id))
		if pool.is_empty():
			pool = metas.filter(func(m): return m.modes.has(mode))
		if pool.is_empty():
			mode = "ffa"
			split.mode = "ffa"
			G.team_split = []
			pool = metas.filter(func(m): return m.modes.has("ffa"))
		choice = pool.pick_random()
		if force != "":
			var f = MgFlow.find(force)
			if f:
				choice = f
				if not f.modes.has(split.mode):
					split.mode = "ffa" if f.modes.has("ffa") else f.modes[0]
					if split.mode == "ffa":
						G.team_split = []
					else:
						var sh: Array = G.players.duplicate()
						sh.shuffle()
						var cut := 1 if split.mode == "1v3" else sh.size() / 2
						split.teams = [sh.slice(cut), sh.slice(0, cut)]
						for i in sh.size():
							split.colors[sh[i].pid] = 1 if i < cut else 0
						G.team_split = split.teams
		G.recent_mg.append(choice.id)
		while G.recent_mg.size() > min(6, metas.size() - 1):
			G.recent_mg.pop_front()
		var ffa_list: Array = metas.filter(func(m): return m.modes.has(split.mode))
		if ffa_list.is_empty(): ffa_list = metas
		for i in 26:
			strip.append(ffa_list[i % ffa_list.size()])
		strip.append(choice)
		for i in 3:
			strip.append(ffa_list[(i + 2) % ffa_list.size()])
		for p in G.players:
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🎰", "title": "Minijáték sorsolás…", "text": "Nézd a nagy képernyőt!"})
		Main.I.world_env.environment = null
		if G.players.size() == 4 and not G.is_mountain():
			stage = "teams"
			Audio.play("whoosh")
			after(2.6, func():
				stage = "roll"
				roll_t0 = t)
		else:
			stage = "roll"
			roll_t0 = t
		after((2.6 if stage == "teams" else 0.0) + dur + 1.6, func(): Main.I.set_scene(MgFlow.IntroScene.new(choice, G.team_split)))

	func pos() -> float:
		return D.ease_out_cubic(min(1.0, (t - roll_t0) / dur)) * target

	func update(_dt: float) -> void:
		if stage != "roll":
			return
		var i := roundi(pos())
		if i != last_idx:
			last_idx = i
			Audio.play("tick")
		if not landed and t - roll_t0 >= dur:
			landed = true
			Audio.play("fanfare")
			Main.I.burst(640, 360, {"n": 70, "speed": 520})

	func draw(c: CanvasItem) -> void:
		MgFlow.bg(c)
		if stage == "teams":
			_draw_teams(c)
			return
		var mode_txt: String = {"ffa": "🎰 MINIJÁTÉK SORSOLÁS 🎰", "2v2": "🎰 2 A 2 ELLEN 🎰", "1v3": "🎰 1 A 3 ELLEN 🎰"}.get(split.mode, "🎰")
		D.text(c, mode_txt, 640, 110, {"size": 48, "stroke": D.DARK, "sw": 10, "color": Color("#ffd43b")})
		var ps := pos()
		var spacing := 300.0
		for i in strip.size():
			var dx := (i - ps) * spacing
			if abs(dx) > 800:
				continue
			var m: Dictionary = strip[i]
			var center: float = max(0.0, 1.0 - abs(dx) / spacing)
			var pulse := 1.0 + sin(Main.I.time * 8.0) * 0.04 if (landed and i == target) else 1.0
			var s := (0.75 + center * 0.3) * pulse
			c.draw_set_transform(Vector2(640 + dx, 380), 0, Vector2(s, s))
			var col := Color(m.color)
			D.panel(c, -125, -150, 250, 300, {"fill": Color(D.shade(col, -0.45), 0.45 + center * 0.55), "stroke": Color("#ffd43b") if center > 0.5 else col, "lw": 6, "r": 28})
			D.emoji(c, m.icon, 0, -50, 100, 0.45 + center * 0.55)
			D.text(c, m.name, 0, 70, {"size": 28, "maxw": 225, "alpha": 0.45 + center * 0.55})
			c.draw_set_transform(Vector2.ZERO)
		D.text(c, "▼", 640, 205, {"size": 40, "color": Color("#ffd43b")})
		if landed:
			D.text(c, choice.name.to_upper(), 640, 610, {"size": 54, "stroke": D.DARK, "sw": 10})

	func _draw_teams(c: CanvasItem) -> void:
		D.text(c, "CSAPATOK", 640, 90, {"size": 56, "stroke": D.DARK, "sw": 10, "color": Color("#ffd43b")})
		var sub: String = {"ffa": "Mindenki mindenki ellen!", "2v2": "2 a 2 ellen!", "1v3": "1 a 3 ellen!"}.get(split.mode, "")
		D.text(c, "Az utolsó mező színe dönt: kék vagy piros", 640, 140, {"size": 22, "color": Color("#cfc6f5")})
		for side in 2:
			var cx := 350.0 + side * 580
			D.panel(c, cx - 230, 190, 460, 330, {"fill": Color(MgFlow.TEAM_COLORS[side], 0.25), "stroke": MgFlow.TEAM_COLORS[side], "lw": 5, "r": 30})
			D.text(c, MgFlow.TEAM_NAMES[side], cx, 225, {"size": 30, "color": MgFlow.TEAM_COLORS[side].lightened(0.3)})
		var k: float = min(1.0, t / 1.2)
		var idx := [0, 0]
		for p in G.players:
			var side: int = split.colors[p.pid]
			var tx = 350.0 + side * 580 + (idx[side] - 0.5) * 120
			idx[side] += 1
			var ty := 350.0
			var sx := 640.0
			var x := lerpf(sx, tx, D.ease_out_back(k))
			D.avatar(c, p, x, ty - abs(sin(Main.I.time * 4.0 + x)) * 8, 46)
			D.text(c, p.name, x, ty + 70, {"size": 20, "maxw": 120})
		D.text(c, sub, 640, 580, {"size": 46, "stroke": D.DARK, "sw": 8})


# ------------------------------------------------------------------ leírás
class IntroScene:
	extends GameScene
	var mg: Dictionary
	var teams: Array
	var ready_set := {}
	var limit := 30.0
	var started := false

	func _init(m: Dictionary, tm: Array) -> void:
		mg = m
		teams = tm

	func enter() -> void:
		for p in G.players:
			Net.set_ctrl(p.pid, {"mode": "ready", "icon": mg.icon, "title": mg.name, "text": _controls_for(p)})
		after(limit, go)

	func _controls_for(p) -> String:
		var s: String = mg.controls
		if teams.size() == 2:
			var tix := 0 if teams[0].has(p) else 1
			s = "Te a %s csapatban vagy! %s" % [MgFlow.TEAM_NAMES[tix], s]
		return s

	func input(pid: String, msg: Dictionary) -> void:
		if str(msg.get("t", "")) != "ready" or ready_set.has(pid) or G.by_pid(pid) == null:
			return
		ready_set[pid] = true
		Audio.play("pop")
		Net.set_ctrl(pid, {"mode": "wait", "icon": "✅", "title": "Kész vagy!", "text": "Várakozás a többiekre…"})
		_check()

	func players_changed() -> void:
		_check()

	func _check() -> void:
		for p in G.players:
			if not ready_set.has(p.pid) and (p.connected or p.is_bot):
				return
		after(0.7, go)

	func key(e: InputEventKey) -> void:
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			go()

	func go() -> void:
		if started:
			return
		started = true
		Main.I.set_scene(MgFlow.PlayScene.new(mg, teams))

	func draw(c: CanvasItem) -> void:
		MgFlow.bg(c)
		var s := D.ease_out_back(min(1.0, t * 2.5))
		var col := Color(mg.color)
		c.draw_set_transform(Vector2(640, 300), 0, Vector2(s, s))
		D.panel(c, -470, -250, 940, 470, {"fill": Color(0.08, 0.05, 0.19, 0.92), "stroke": col, "lw": 6, "r": 32})
		D.emoji(c, mg.icon, -340, -150, 110)
		D.text(c, mg.name, -250, -170, {"size": 58, "align": "left", "color": col, "stroke": D.DARK, "sw": 8, "maxw": 680})
		D.text(c, mg.tagline, -250, -115, {"size": 24, "align": "left", "color": Color("#cfc6f5")})
		D.wrap(c, mg.desc, -420, -45, 840, 30, {"size": 25})
		D.panel(c, -420, 80, 840, 110, {"fill": Color(1, 1, 1, 0.08), "stroke": null, "r": 20, "shadow": false})
		D.text(c, "📱 Irányítás", -395, 108, {"size": 22, "align": "left", "color": Color("#ffd43b")})
		D.wrap(c, mg.controls, -395, 145, 790, 28, {"size": 22})
		c.draw_set_transform(Vector2.ZERO)
		var n := G.players.size()
		var gap: float = min(130.0, 1150.0 / n)
		for i in n:
			var p = G.players[i]
			var x := 640 + (i - (n - 1) / 2.0) * gap
			var r: bool = ready_set.has(p.pid)
			if teams.size() == 2:
				var tix := 0 if teams[0].has(p) else 1
				D.ring(c, x, 600, 38, MgFlow.TEAM_COLORS[tix], 6)
			D.avatar(c, p, x, 600 - (abs(sin(Main.I.time * 5.0 + i)) * 8 if r else 0.0), 30, {"alpha": 1.0 if r else 0.5})
			D.text(c, "✔" if r else "…", x + 26, 578, {"size": 26, "color": Color("#69db7c") if r else Color("#aaaaaa"), "stroke": D.DARK, "sw": 5})
			D.text(c, p.name, x, 652, {"size": 17, "maxw": gap - 8})
		var left: int = max(0, ceili(limit - t))
		D.text(c, "Nyomd meg a telefonodon a „Kész” gombot!  (automatikus indulás: %d mp)" % left, 640, 695, {"size": 18, "color": Color("#b8acec")})


# ------------------------------------------------------------------ játék
class PlayScene:
	extends GameScene
	var mg: Dictionary
	var teams: Array
	var inst: Minigame
	var phase := "count"
	var count_t := 3.0
	var last_count := 4
	var go_t := 0.0
	var end_t := 0.0

	func _init(m: Dictionary, tm: Array) -> void:
		mg = m
		teams = tm

	func enter() -> void:
		Audio.music("minigame")
		inst = mg.script.new()
		inst.setup(G.players.duplicate(), teams)
		add_child(inst)
		for p in G.players:
			Net.set_ctrl(p.pid, {"mode": "wait", "icon": mg.icon, "title": "Készülj…", "text": "Mindjárt indul!"})

	func update(dt: float) -> void:
		if phase == "count":
			count_t -= dt
			var n := ceili(count_t)
			if n != last_count and n > 0:
				last_count = n
				Audio.play("count")
			if count_t <= 0:
				phase = "play"
				go_t = t
				Audio.play("count_go")
				for p in inst.players:
					Net.set_ctrl(p.pid, inst.layout(p))
				inst.start()
			inst.idle(dt)
		elif phase == "play":
			for p in inst.players:
				if Net.is_auto(p.pid):
					inst.bot(p, dt)
			inst.t += dt
			inst.update(dt)
			if inst.finished:
				phase = "end"
				end_t = t
				Audio.play("win")
				for p in inst.players:
					Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🏁", "title": "VÉGE!", "text": "Mindjárt jönnek az eredmények…"})
				after(2.0, func(): Main.I.set_scene(MgFlow.ResultScene.new(mg, inst.ranking(), teams)))
		else:
			inst.idle(dt)

	func input(pid: String, msg: Dictionary) -> void:
		if phase != "play":
			return
		var p = G.by_pid(pid)
		if p and inst.players.has(p):
			inst.input(p, msg)

	func draw(c: CanvasItem) -> void:
		inst.draw(c)
		if phase == "count":
			c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.12, 0.55))
			var n: int = max(1, ceili(count_t))
			var k = 1.0 - (count_t - floor(count_t))
			var s := 1.6 - D.ease_out_cubic(min(1.0, k * 1.5)) * 0.6
			D.text(c, mg.name, 640, 180, {"size": 44, "color": Color(mg.color), "stroke": D.DARK, "sw": 8})
			if teams.size() == 2:
				var a := ""
				var b := ""
				for p in teams[0]: a += ("  " if a != "" else "") + p.name
				for p in teams[1]: b += ("  " if b != "" else "") + p.name
				D.text(c, a, 320, 600, {"size": 26, "color": MgFlow.TEAM_COLORS[0].lightened(0.3), "stroke": D.DARK, "sw": 6, "maxw": 560})
				D.text(c, "VS", 640, 600, {"size": 40, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 8})
				D.text(c, b, 960, 600, {"size": 26, "color": MgFlow.TEAM_COLORS[1].lightened(0.3), "stroke": D.DARK, "sw": 6, "maxw": 560})
			c.draw_set_transform(Vector2(640, 380), 0, Vector2(s, s))
			D.text(c, str(n), 0, 0, {"size": 200, "stroke": D.DARK, "sw": 14})
			c.draw_set_transform(Vector2.ZERO)
		elif phase == "play" and t - go_t < 0.9:
			var k := (t - go_t) / 0.9
			c.draw_set_transform(Vector2(640, 360), 0, Vector2(1 + k, 1 + k))
			D.text(c, "RAJT!", 0, 0, {"size": 150, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 14, "alpha": 1.0 - k})
			c.draw_set_transform(Vector2.ZERO)
		elif phase == "end":
			c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.12, 0.35))
			var s := D.ease_out_back(min(1.0, (t - end_t) * 3.0))
			c.draw_set_transform(Vector2(640, 360), 0, Vector2(s, s))
			D.text(c, "VÉGE!", 0, 0, {"size": 150, "stroke": Color("#e11d48"), "sw": 16})
			c.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ eredmény
class ResultScene:
	extends GameScene
	var mg: Dictionary
	var ranking: Array
	var teams: Array
	var rows: Array = []
	var done := false
	var team_win := -2     # -2: nem csapatos, -1: döntetlen

	func _init(m: Dictionary, r: Array, tm: Array) -> void:
		mg = m
		ranking = r
		teams = tm

	func enter() -> void:
		Main.I.world_env.environment = null
		if teams.size() == 2:
			_team_result()
		else:
			_ffa_result()
		after(0.3, func():
			Audio.play("fanfare")
			Audio.jingle("victory")
			Main.I.confetti(90))
		after(3.5 + rows.size() * 0.35, next)

	func _ffa_result() -> void:
		var place := 0
		for i in ranking.size():
			var r: Dictionary = ranking[i]
			if i == 0 or r.score != ranking[i - 1].score:
				place = i
			var p = G.by_pid(r.pid)
			if p == null:
				continue
			var award: int = MgFlow.AWARDS[place] if place < MgFlow.AWARDS.size() else 0
			rows.append({"p": p, "place": place, "award": award, "label": r.label})
		if G.is_mountain():
			_mountain_dice()
			return
		for row in rows:
			_give(row)

	## Hegymászás: érme helyett a következő dobás kockáit osztja a helyezés.
	func _mountain_dice() -> void:
		var last_place := 0
		for row in rows:
			last_place = max(last_place, row.place)
		var order: Array = []
		for row in rows:
			var p = row.p
			p.dice = G.dice_for_place(row.place, last_place, rows.size())
			p.mg_place = row.place
			row["dice"] = p.dice
			order.append(p)
			if row.place == 0:
				p.stats.mg_wins += 1
			Net.set_ctrl(p.pid, {"mode": "result", "icon": MgFlow.MEDALS[row.place] if row.place < 3 else "🎮",
				"title": "%d. hely" % (row.place + 1), "text": "Kockáid: %s" % G.dice_text(p.dice)})
			Net.vibrate(p.pid, [100, 50, 100, 50, 300] if row.place == 0 else 80)
		G.mtn_order = order

	func _team_result() -> void:
		var score := [0.0, 0.0]
		var byp := {}
		for r in ranking:
			byp[r.pid] = r
		for ti in 2:
			var sum := 0.0
			for p in teams[ti]:
				sum += float(byp.get(p.pid, {"score": 0}).score)
			score[ti] = sum / max(1, teams[ti].size())
		if is_equal_approx(score[0], score[1]):
			team_win = -1
		else:
			team_win = 0 if score[0] > score[1] else 1
		var solo_mode: bool = teams[0].size() != teams[1].size()
		for ti in 2:
			for p in teams[ti]:
				var award := 3
				if team_win >= 0:
					if ti == team_win:
						award = 10
						if solo_mode:
							award = 15 if teams[ti].size() == 1 else 6
					else:
						award = 0
				var place := 0 if (team_win == ti or team_win == -1) else 1
				rows.append({"p": p, "place": place, "award": award, "label": byp.get(p.pid, {"label": ""}).label, "team": ti})
		rows.sort_custom(func(a, b): return a.place < b.place)
		for row in rows:
			_give(row)

	func _give(r: Dictionary) -> void:
		G.add_coins(r.p, r.award)
		r.p.stats.mg_coins += r.award
		if r.place == 0:
			r.p.stats.mg_wins += 1
		Net.set_ctrl(r.p.pid, {"mode": "result", "icon": MgFlow.MEDALS[r.place] if r.place < 3 else "🎮",
			"title": "%d. hely" % (r.place + 1) if team_win == -2 else ("GYŐZELEM!" if r.place == 0 else "Vesztettetek"),
			"text": "+%d 🪙" % r.award if r.award > 0 else "Most nem jött össze – legközelebb!"})
		Net.vibrate(r.p.pid, [100, 50, 100, 50, 300] if r.place == 0 else 80)

	func key(e: InputEventKey) -> void:
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			next()

	func next() -> void:
		if done:
			return
		done = true
		Game.after_minigame()

	func draw(c: CanvasItem) -> void:
		MgFlow.bg(c, 200)
		D.text(c, "%s %s" % [mg.icon, mg.name], 640, 70, {"size": 46, "color": Color(mg.color), "stroke": D.DARK, "sw": 8})
		if team_win >= 0:
			D.text(c, "%s CSAPAT NYERT!" % MgFlow.TEAM_NAMES[team_win], 640, 122, {"size": 32, "color": MgFlow.TEAM_COLORS[team_win].lightened(0.35), "stroke": D.DARK, "sw": 6})
		elif team_win == -1:
			D.text(c, "DÖNTETLEN!", 640, 122, {"size": 32, "color": Color("#ffd43b")})
		elif G.is_mountain():
			D.text(c, "A helyezés osztja a következő dobás kockáit", 640, 118, {"size": 24, "color": Color("#cfc6f5")})
		else:
			D.text(c, "Eredmények", 640, 118, {"size": 26, "color": Color("#cfc6f5")})
		var n := rows.size()
		var row_h: float = min(70.0, 520.0 / max(1, n))
		for i in n:
			var r: Dictionary = rows[i]
			var appear: float = clamp((t - 0.3 - i * 0.3) * 3.0, 0.0, 1.0)
			if appear <= 0:
				continue
			var y := 160.0 + i * (row_h + 6)
			var x := lerpf(-700.0, 0.0, D.ease_out_back(appear))
			var first: bool = r.place == 0
			var stroke: Color = r.p.color
			if r.has("team"):
				stroke = MgFlow.TEAM_COLORS[r.team]
			D.panel(c, 250 + x, y, 780, row_h, {"fill": Color(1, 0.83, 0.23, 0.22) if first else Color(1, 1, 1, 0.08), "stroke": Color("#ffd43b") if first else stroke, "r": 18})
			var cy := y + row_h / 2
			if r.place < 3:
				D.emoji(c, MgFlow.MEDALS[r.place], 295 + x, cy, row_h * 0.6)
			else:
				D.text(c, "%d." % (r.place + 1), 295 + x, cy, {"size": 28})
			D.avatar(c, r.p, 355 + x, cy, row_h * 0.36, {"shadow": false})
			D.text(c, r.p.name, 395 + x, cy, {"size": 28, "align": "left", "maxw": 260})
			D.text(c, str(r.label), (720 if r.has("dice") else 760) + x, cy, {"size": 24, "color": Color("#d0c8f0"), "maxw": 170 if r.has("dice") else 200})
			if r.has("dice"):
				D.text(c, G.dice_text(r.dice), 1010 + x, cy, {"size": 26, "color": Color("#ffd43b"), "align": "right", "maxw": 190})
			else:
				D.text(c, "+%d 🪙" % r.award if r.award > 0 else "–", 990 + x, cy, {"size": 30, "color": Color("#ffd43b"), "align": "right"})
		D.text(c, "ENTER = tovább", 1250, 700, {"size": 15, "color": Color("#8f84c4"), "align": "right", "bold": false})
