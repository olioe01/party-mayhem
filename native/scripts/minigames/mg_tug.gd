extends Minigame
## Kötélhúzás (3D, csak csapatban: 2 a 2 ellen vagy 1 a 3 ellen) – gyors koppintással húzzátok
## a kötelet! Akinek a csapata átrántja a szalagot a saját oldalára, nyer. 1 a 3 ellen a magányos
## játékos háromszoros erővel húz.

const LIMIT := 22.0
const WIN_X := 3.0

var rope_x := 0.0
var rope_v := 0.0
var taps := {}
var recent := {}           # pid -> koppintások az utolsó fél másodpercben (animációhoz)
var models := {}
var rope: Node3D
var flag: Node3D
var winner_team := -1
var decided := false
var end_t := 0.0
var bot_t := {}


func meta() -> Dictionary:
	return {"id": "tug", "name": "Kötélhúzás", "icon": "🪢", "color": "#e8590c", "modes": ["2v2", "1v3"],
		"tagline": "Húzd meg, ereszd meg!",
		"desc": "Két csapat, egy kötél, alatta sárgödör! Koppintsatok, amilyen gyorsan csak tudtok: minden koppintás a saját oldalatok felé húzza a kötelet. 1 a 3 ellen a magányos játékos háromszoros erővel húz.",
		"controls": "Koppints gyorsan a HÚZÁS gombra! A csapatod koppintásai összeadódnak."}


func layout(_p) -> Dictionary:
	return {"mode": "tap", "label": "💪 HÚZÁS!", "hint": "Koppints gyorsan!", "rapid": true}


func _ready() -> void:
	make_env("#f59f00", "#ffe8cc", 0.8)
	make_camera(Vector3(0, 5.5, 11.5), Vector3(0, 0.6, 0), 45)
	make_sun(Vector3(-55, -20, 0), 1.3)
	for side in [-1, 1]:
		Chars3D.box(self, 9, 1.0, 5, Chars3D.mat("#7cc552" if side < 0 else "#e9c46a"), Vector3(side * 6.5, -0.5, 0))
		Chars3D.box(self, 0.2, 0.06, 5, Chars3D.mat(MgFlow.TEAM_COLORS[0 if side < 0 else 1].to_html()), Vector3(side * WIN_X, 0.02, 0))
	var mud := Chars3D.box(self, 4.0, 0.6, 5, Chars3D.mat("#5c3d2e", {"rough": 0.3}), Vector3(0, -0.6, 0))
	mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		Chars3D.sphere(self, 0.25, Chars3D.mat("#7a5240", {"rough": 0.2}), randf_range(-1.5, 1.5), -0.3, randf_range(-2, 2), 1, 0.4, 1)
	rope = Node3D.new()
	add_child(rope)
	Chars3D.cyl(rope, 0.06, 0.06, 15.0, Chars3D.mat("#d6b37a", {"rough": 0.9}), 0, 0.62, 0, 8, Vector3(0, 0, PI / 2))
	flag = Node3D.new()
	rope.add_child(flag)
	Chars3D.box(flag, 0.08, 0.7, 0.4, Chars3D.mat("#ff4d6d", {"emit": "#ff4d6d", "emit_e": 0.6}), Vector3(0, 0.25, 0))
	for ti in 2:
		var side := -1.0 if ti == 0 else 1.0
		var list: Array = teams[ti] if teams.size() == 2 else []
		for k in list.size():
			var p = list[k]
			var m := player_model(p, 1.1)
			models[p.pid] = {"m": m, "side": side, "k": k}
			taps[p.pid] = 0
			recent[p.pid] = 0.0
	_sync(0.0)


func _power(p) -> float:
	var ti := team_of(p)
	if ti < 0 or teams.size() != 2:
		return 1.0
	var my: int = teams[ti].size()
	var other: int = teams[1 - ti].size()
	return float(other) / float(my) if my < other else 1.0


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "tap" or decided:
		return
	var ti := team_of(p)
	if ti < 0:
		return
	taps[p.pid] = taps.get(p.pid, 0) + 1
	recent[p.pid] = recent.get(p.pid, 0.0) + 1.0
	var dir := -1.0 if ti == 0 else 1.0
	rope_v += dir * 0.085 * _power(p)
	if taps[p.pid] % 10 == 0:
		Audio.play("tick")


func bot(p, dt: float) -> void:
	bot_t[p.pid] = bot_t.get(p.pid, 0.0) - dt
	if bot_t[p.pid] <= 0:
		input(p, {"t": "tap"})
		bot_t[p.pid] = 1.0 / randf_range(5.0, 7.5)


func update(dt: float) -> void:
	if not decided:
		rope_x += rope_v
		rope_v = 0.0
		if rope_x <= -WIN_X:
			winner_team = 0
		elif rope_x >= WIN_X:
			winner_team = 1
		elif t >= LIMIT:
			winner_team = 0 if rope_x < 0 else (1 if rope_x > 0 else -1)
			decided = true
		if winner_team >= 0:
			decided = true
		if decided:
			end_t = t
			Audio.play("win")
			Main.I.confetti(60)
			for p in players:
				var won := team_of(p) == winner_team
				(models[p.pid].m as Chars3D.CharModel).emote("cheer" if won else "sad")
	elif t - end_t > 1.8:
		finished = true
	_sync(dt)


func idle(dt: float) -> void:
	_sync(dt)


func _sync(dt: float) -> void:
	rope.position.x = rope_x
	flag.position.x = 0
	for pid in models:
		var o: Dictionary = models[pid]
		var m: Chars3D.CharModel = o.m
		recent[pid] = max(0.0, recent[pid] - dt * 4.0)
		var a := m.animate(dt)
		var x: float = rope_x + o.side * (2.2 + o.k * 1.1)
		var lean: float = 0.12 + min(0.18, recent[pid] * 0.05)
		m.position = Vector3(x, a.y, 0.0 + (o.k % 2) * 0.12)
		m.rotation.y = -o.side * PI / 2 + a.spin
		m.rotation.z = 0.0
		m.rotation.x = lean + a.tilt


func ranking() -> Array:
	var out: Array = []
	for p in players:
		var ti := team_of(p)
		var sc := 0.5
		if winner_team >= 0:
			sc = 1.0 if ti == winner_team else 0.0
		out.append({"pid": p.pid, "score": sc, "label": "%d húzás" % taps.get(p.pid, 0)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func draw(c: CanvasItem) -> void:
	for pid in models:
		var o: Dictionary = models[pid]
		var p = G.by_pid(pid)
		var q := screen((o.m as Node3D).position + Vector3(0, 1.6, 0))
		D.text(c, p.name, q.x, q.y, {"size": 16, "stroke": Color.BLACK, "sw": 4, "maxw": 110})
		if _power(p) > 1.0:
			D.text(c, "×%d 💪" % roundi(_power(p)), q.x, q.y - 22, {"size": 16, "color": Color("#ffd43b"), "stroke": Color.BLACK, "sw": 4})
	D.text(c, "KÉK", 120, 60, {"size": 40, "color": MgFlow.TEAM_COLORS[0].lightened(0.3), "stroke": D.DARK, "sw": 7})
	D.text(c, "PIROS", 1160, 60, {"size": 40, "color": MgFlow.TEAM_COLORS[1].lightened(0.3), "stroke": D.DARK, "sw": 7})
	var k := rope_x / WIN_X
	D.panel(c, 340, 96, 600, 22, {"r": 11, "fill": Color(0, 0, 0, 0.45), "stroke": null})
	c.draw_rect(Rect2(640, 100, -300 * max(0.0, -k), 14), MgFlow.TEAM_COLORS[0])
	c.draw_rect(Rect2(640, 100, 300 * max(0.0, k), 14), MgFlow.TEAM_COLORS[1])
	c.draw_rect(Rect2(638, 92, 4, 30), Color.WHITE)
	if winner_team >= 0:
		D.text(c, "%s CSAPAT NYERT!" % MgFlow.TEAM_NAMES[winner_team], 640, 200, {"size": 56, "color": MgFlow.TEAM_COLORS[winner_team].lightened(0.3), "stroke": D.DARK, "sw": 9})
	D.timer_hud(c, LIMIT - t, 640, 46)
