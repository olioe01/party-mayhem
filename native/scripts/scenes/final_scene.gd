class_name FinalScene
extends GameScene
## Játék vége: 3 véletlen bónusz korona (a 7 lehetségesből), majd 3D dobogó a figurákkal.

const BONUSES := [
	{"icon": "🎮", "title": "Minijáték-mester", "desc": "Aki a legtöbb érmét nyerte minijátékokban", "stat": "mg_coins"},
	{"icon": "🚶", "title": "Vándor", "desc": "Aki a legtöbb mezőt lépte", "stat": "steps"},
	{"icon": "💰", "title": "Krőzus", "desc": "Akinél egyszerre a legtöbb érme volt", "stat": "max_coins"},
	{"icon": "🟥", "title": "Pechmadár", "desc": "Aki a legtöbbször lépett piros mezőre", "stat": "red"},
	{"icon": "❓", "title": "Kalandor", "desc": "Aki a legtöbb eseménybe keveredett", "stat": "events"},
	{"icon": "🛍️", "title": "Vásárkirály", "desc": "Aki a legtöbbet költött a boltban", "stat": "spent"},
	{"icon": "🤝", "title": "Barátságos", "desc": "Akihez a legtöbb barát csatlakozott", "stat": "allies"},
]

var stage := "intro"
var bonus = null
var podium_t := 0.0
var final_rank: Array = []
var root3d: Node3D
var cam: Camera3D
var models := {}
var env: Environment


func enter() -> void:
	G.phase = "final"
	Audio.music("final")
	for p in G.players:
		Net.set_ctrl(p.pid, {"mode": "wait", "icon": "🏆", "title": "Vége a játéknak!", "text": "Jönnek a bónuszok…"})
	_build_3d()
	_run()


func _build_3d() -> void:
	root3d = Node3D.new()
	add_child(root3d)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a0636")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6d4bb8")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	Main.I.world_env.environment = env
	cam = Camera3D.new()
	cam.fov = 40
	root3d.add_child(cam)
	cam.position = Vector3(0, 3.2, 9.5)
	cam.look_at(Vector3(0, 1.4, 0))
	cam.make_current()
	var key := SpotLight3D.new()
	key.position = Vector3(0, 9, 4)
	key.rotation_degrees = Vector3(-65, 0, 0)
	key.spot_angle = 32
	key.light_energy = 6.0
	key.spot_range = 20
	key.shadow_enabled = true
	key.light_color = Color("#fff3d6")
	root3d.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 40, 0)
	fill.light_energy = 0.5
	fill.light_color = Color("#b197fc")
	root3d.add_child(fill)
	# színpad
	var floor_m := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 7
	cy.bottom_radius = 7.2
	cy.height = 0.3
	cy.radial_segments = 48
	floor_m.mesh = cy
	floor_m.material_override = Chars3D.mat("#2b1055", {"rough": 0.35, "metal": 0.2})
	floor_m.position.y = -0.15
	root3d.add_child(floor_m)
	var ring := MeshInstance3D.new()
	ring.mesh = Chars3D.torus(7.05, 0.08)
	ring.material_override = Chars3D.mat("#ffd43b", {"emit": "#ffb000", "emit_e": 2.0})
	root3d.add_child(ring)
	# dobogó: 2 – 1 – 3
	var spots := [[0.0, 1.5, "#ffd43b"], [-2.1, 1.0, "#ced4da"], [2.1, 0.65, "#e8a87c"]]
	for i in 3:
		var sp: Array = spots[i]
		var b := Chars3D.box(root3d, 1.9, sp[1], 1.6, Chars3D.mat(sp[2], {"metal": 0.3, "rough": 0.35}), Vector3(sp[0], sp[1] / 2.0, 0))
		var lab := Label3D.new()
		lab.text = str(i + 1)
		lab.font = D.font
		lab.font_size = 160
		lab.pixel_size = 0.004
		lab.position = Vector3(sp[0], sp[1] * 0.55, 0.81)
		lab.outline_size = 20
		lab.outline_modulate = Color(0, 0, 0, 0.4)
		root3d.add_child(lab)
	# fényszórók animált csóvái
	for i in 4:
		var s := SpotLight3D.new()
		s.position = Vector3(-6 + i * 4, 6, -3)
		s.light_color = Color(["#ff4d6d", "#4dabf7", "#51cf66", "#b197fc"][i])
		s.light_energy = 3.0
		s.spot_angle = 18
		s.spot_range = 14
		root3d.add_child(s)
		var ph := i * 1.3
		s.set_meta("ph", ph)


func _run() -> void:
	Audio.play("fanfare")
	await sleep(2.5)
	var pool := BONUSES.duplicate()
	pool.shuffle()
	var chosen: Array = [BONUSES[0]]
	for b in pool:
		if chosen.size() >= 3:
			break
		if b != BONUSES[0]:
			chosen.append(b)
	if G.is_mountain():
		chosen = []   # hegymászásnál nincs bónusz korona: aki felért, az nyert
	for b in chosen:
		var best := 0
		for p in G.players:
			best = max(best, int(p.stats.get(b.stat, 0)))
		var winners: Array = G.players.filter(func(p): return best > 0 and int(p.stats.get(b.stat, 0)) == best)
		bonus = b.duplicate()
		bonus["winners"] = winners
		bonus["value"] = best
		bonus["t0"] = t
		stage = "bonus"
		Audio.play("select")
		await sleep(1.2)
		for p in winners:
			p.crowns += 1
			Net.push_status(p.pid)
			Net.vibrate(p.pid, [80, 60, 200])
		if winners.size():
			Audio.play("crown")
			Main.I.burst(640, 380, {"n": 60, "colors": ["#ffd43b", "#ffffff"], "speed": 500})
		await sleep(2.6)
	stage = "podium"
	podium_t = t
	final_rank = G.standings()
	Audio.jingle("victory")
	Audio.play("win")
	Main.I.confetti(160)
	_place_models()
	for p in G.players:
		var pl := G.place_of(p)
		Net.set_ctrl(p.pid, {"mode": "result", "icon": "🏆" if pl == 1 else ("🥈" if pl == 2 else ("🥉" if pl == 3 else "🎉")),
			"title": "GYŐZTÉL!" if pl == 1 else "%d. hely" % pl, "text": _score_text(p), "again": p.pid == G.vip})
	_loop_confetti()


func _score_text(p) -> String:
	if G.is_mountain():
		return "🏔️ Felért a csúcsra!" if p == G.mtn_winner else "⛰️ %d / %d mező" % [p.node, G.mountain.goal]
	return "%d 👑 · %d 🪙" % [p.crowns, p.coins]


func _place_models() -> void:
	var xs := [0.0, -2.1, 2.1]
	var hs := [1.5, 1.0, 0.65]
	for i in min(3, final_rank.size()):
		var p = final_rank[i]
		var m := Chars3D.build(p.char_id)
		m.scale = Vector3.ONE * (1.5 if i == 0 else 1.25)
		m.position = Vector3(xs[i], hs[i] + 4.0, 0)
		root3d.add_child(m)
		models[p.pid] = {"m": m, "y": hs[i], "x": xs[i], "i": i, "drop_t": t + (2 - i) * 0.5}
	# a többiek a színpad szélén
	for i in range(3, final_rank.size()):
		var p = final_rank[i]
		var m := Chars3D.build(p.char_id)
		var x := -4.2 + (i - 3) * 0.9 if i % 2 else 4.2 - (i - 4) * 0.9
		m.position = Vector3(x, 0, 1.2)
		m.scale = Vector3.ONE * 0.9
		root3d.add_child(m)
		models[p.pid] = {"m": m, "y": 0.0, "x": x, "i": i, "drop_t": -1.0}


func _loop_confetti() -> void:
	Main.I.confetti(40)
	after(2.5, _loop_confetti)


func input(pid: String, msg: Dictionary) -> void:
	if str(msg.get("t", "")) == "again" and pid == G.vip and stage == "podium":
		Game.go_lobby()


func key(e: InputEventKey) -> void:
	if (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and stage == "podium":
		Game.go_lobby()


func update(dt: float) -> void:
	var tt = Main.I.time
	for s in root3d.get_children():
		if s is SpotLight3D and s.has_meta("ph"):
			var ph: float = s.get_meta("ph")
			s.rotation = Vector3(-1.2 + sin(tt * 0.8 + ph) * 0.3, sin(tt * 0.6 + ph) * 0.6, 0)
	cam.position = Vector3(sin(tt * 0.15) * 1.2, 3.4, 10.5)
	cam.look_at(Vector3(0, 1.75, 0))
	for pid in models:
		var o: Dictionary = models[pid]
		var m: Chars3D.CharModel = o.m
		var a := m.animate(dt)
		var target_y: float = o.y
		if o.drop_t >= 0.0:
			var k: float = clamp((t - o.drop_t) * 2.0, 0.0, 1.0)
			target_y = lerpf(o.y + 4.0, o.y, D.ease_out_back(k))
			if k >= 1.0 and o.i == 0 and m.emote_type == "":
				m.emote("cheer")
		m.position.y = target_y + a.y
		m.rotation.y = a.spin
		m.rotation.x = a.tilt


func draw(c: CanvasItem) -> void:
	if stage == "intro":
		D.vgrad(c, Color("#3b0764"), Color("#0c0420"))
		var s := D.ease_out_back(min(1.0, t * 2.0))
		c.draw_set_transform(Vector2(640, 330), 0, Vector2(s, s))
		D.text(c, "🏁 VÉGE A JÁTÉKNAK! 🏁", 0, 0, {"size": 72, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 12})
		D.text(c, "Lássuk, ki meddig jutott a hegyen…" if G.is_mountain() else "De még jönnek a bónusz koronák…", 0, 80, {"size": 30, "color": Color("#e5dbff")})
		c.draw_set_transform(Vector2.ZERO)
	elif stage == "bonus":
		D.vgrad(c, Color("#3b0764"), Color("#0c0420"))
		var b: Dictionary = bonus
		var age: float = t - b.t0
		var s := D.ease_out_back(min(1.0, age * 3.0))
		c.draw_set_transform(Vector2(640, 300), 0, Vector2(s, s))
		D.panel(c, -430, -220, 860, 440, {"fill": Color(0.08, 0.05, 0.19, 0.92), "stroke": Color("#ffd43b"), "lw": 6, "r": 32})
		D.text(c, "BÓNUSZ KORONA", 0, -180, {"size": 26, "color": Color("#ffd43b")})
		D.emoji(c, b.icon, 0, -110, 80)
		D.text(c, b.title, 0, -30, {"size": 52})
		D.text(c, b.desc, 0, 18, {"size": 24, "color": Color("#cfc6f5"), "maxw": 800})
		if age > 1.2:
			if b.winners.is_empty():
				D.text(c, "Senki nem kapja meg.", 0, 110, {"size": 30})
			for i in b.winners.size():
				var p = b.winners[i]
				var x = (i - (b.winners.size() - 1) / 2.0) * 170
				D.avatar(c, p, x, 100, 42)
				D.text(c, p.name, x, 165, {"size": 22, "maxw": 160})
				D.emoji(c, "👑", x, 44 - abs(sin(Main.I.time * 5.0)) * 8, 34)
		c.draw_set_transform(Vector2.ZERO)
	else:
		_draw_podium(c)


func _draw_podium(c: CanvasItem) -> void:
	var age := t - podium_t
	D.text(c, "🏆 VÉGEREDMÉNY 🏆", 640, 44, {"size": 50, "color": Color("#ffd43b"), "stroke": D.DARK, "sw": 10})
	for i in min(3, final_rank.size()):
		var p = final_rank[i]
		var o: Dictionary = models[p.pid]
		var m: Node3D = o.m
		var q := cam.unproject_position(Vector3(o.x, 0.05, 1.05))
		if age > (2 - i) * 0.5 + 0.4:
			D.panel(c, q.x - 100, q.y + 4, 200, 62, {"r": 16, "fill": Color(0.08, 0.05, 0.19, 0.8), "stroke": p.color, "shadow": false})
			D.text(c, p.name, q.x, q.y + 22, {"size": 24, "maxw": 190})
			D.text(c, _score_text(p) if G.is_mountain() else "%d 👑  %d 🪙" % [p.crowns, p.coins], q.x, q.y + 50, {"size": 20, "color": Color("#ffe066"), "maxw": 190})
			if i == 0:
				var hq := cam.unproject_position(m.global_position + Vector3(0, 1.55 + abs(sin(Main.I.time * 4.0)) * 0.12, 0))
				D.emoji(c, "👑", hq.x, hq.y, 56)
	for i in range(3, final_rank.size()):
		var p = final_rank[i]
		var x := 1050.0
		var y := 180.0 + (i - 3) * 62
		D.panel(c, x, y, 210, 52, {"r": 16, "fill": Color(1, 1, 1, 0.08), "stroke": p.color, "shadow": false})
		D.text(c, "%d." % G.place_of(p), x + 22, y + 26, {"size": 22})
		D.avatar(c, p, x + 62, y + 26, 18, {"shadow": false})
		D.text(c, p.name, x + 88, y + 18, {"size": 17, "align": "left", "maxw": 115})
		D.text(c, ("⛰️ %d/%d" % [p.node, G.mountain.goal]) if G.is_mountain() else "%d👑 %d🪙" % [p.crowns, p.coins], x + 88, y + 38, {"size": 15, "align": "left", "color": Color("#ffe066")})
	if age > 2.5:
		button(c, 520, 640, 240, 56, "ÚJ JÁTÉK", Game.go_lobby, {"color": Color("#51cf66"), "size": 26})
		D.text(c, "vagy a ⭐ VIP a telefonjáról · ENTER", 640, 710, {"size": 15, "color": Color("#a99fd6"), "bold": false})
