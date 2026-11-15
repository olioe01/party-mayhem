extends Minigame
## Vakondvadász – 3×3-as rét (a közepén nincs lyuk): csapj le a felbukkanó vakondokra a telefonodon lévő rácson!
## Néha arany kalapács bukkan fel: aki elsőként csap rá, az pár másodpercre elkábítja a többieket.

const TIME := 40.0
const CELLS := [0, 1, 2, 3, 5, 6, 7, 8]      # a 4-es (közép) helyén nincs lyuk
const STUN := 2.4
const MISS_CD := 0.45
const CELL := 150.0
const GX := 640.0 - CELL * 1.5
const GY := 96.0

var score := {}
var moles: Array = []          # [{cell, born, life, gold, bots}]
var next_spawn := 0.5
var next_gold := 7.0
var stun_until := {}
var cd_until := {}
var stun_shown := {}
var hits: Array = []           # [{cell, pid, t, ok, gold}]: a legutóbbi csapások, csak a rajzhoz


func meta() -> Dictionary:
	return {"id": "mole", "name": "Vakondvadász", "icon": "🔨", "color": "#a16207", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Csapj le, mielőtt elbújik!",
		"desc": "A réten nyolc lyuk van (a közepén nincs). A vakondok hol itt, hol ott dugják ki a fejüket: aki elsőként csap le rájuk, azé a pont. Ha üres lyukra csapsz, egy pillanatig nem tudsz ütni. Néha arany kalapács bukkan fel: aki megszerzi, az elkábítja a többieket!",
		"controls": "A telefonodon ugyanaz a 3×3-as rács van, mint a képernyőn: koppints arra a lyukra, ahol a vakond kibújt."}


func layout(_p) -> Dictionary:
	var cells: Array = []
	for i in 9:
		cells.append("" if i == 4 else "🕳️")
	return {"mode": "grid", "cols": 3, "cells": cells, "title": "Csapj le a vakondra! 🔨"}


func _ready() -> void:
	for p in players:
		score[p.pid] = 0


func _mole_at(cell: int):
	for m in moles:
		if m.cell == cell:
			return m
	return null


func _blocked(p) -> bool:
	return t < float(stun_until.get(p.pid, 0.0)) or t < float(cd_until.get(p.pid, 0.0))


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "cell" or finished or _blocked(p):
		return
	var cell := int(msg.get("v", -1))
	if not CELLS.has(cell):
		return
	var m = _mole_at(cell)
	if m == null:
		cd_until[p.pid] = t + MISS_CD
		hits.append({"cell": cell, "pid": p.pid, "t": t, "ok": false, "gold": false})
		Audio.play("tick")
		return
	moles.erase(m)
	score[p.pid] += 1
	hits.append({"cell": cell, "pid": p.pid, "t": t, "ok": true, "gold": m.gold})
	Net.vibrate(p.pid, 40)
	var q := _cell_pos(cell)
	if m.gold:
		# nagy kalapács: a többiek (csapatjátékban az ellenfelek) elkábulnak
		Audio.play("boom")
		Audio.play("crown")
		Main.I.burst(q.x, q.y, {"n": 50, "colors": ["#ffd43b", "#ffffff", p.color_hex], "speed": 460})
		var mine := team_of(p)
		for o in players:
			if o == p or (mine >= 0 and team_of(o) == mine):
				continue
			stun_until[o.pid] = t + STUN
			stun_shown[o.pid] = true
			Net.vibrate(o.pid, [120, 60, 120])
			Net.set_ctrl(o.pid, {"mode": "wait", "icon": "💫", "title": "Elkábultál!", "text": "%s megszerezte a nagy kalapácsot…" % p.name})
	else:
		Audio.play("hit")
		Main.I.burst(q.x, q.y, {"n": 14, "colors": ["#8b5a2b", "#d9a066", p.color_hex], "speed": 260})


func bot(p, _dt: float) -> void:
	if _blocked(p):
		return
	for m in moles:
		var plan: Dictionary = m.bots
		if not plan.has(p.pid):
			plan[p.pid] = (t + randf_range(0.45, 1.25)) if randf() < 0.8 else 1e9
		if t >= float(plan[p.pid]):
			input(p, {"t": "cell", "v": m.cell})
			return


func update(_dt: float) -> void:
	if t >= TIME:
		finished = true
		return
	var alive: Array = []
	for m in moles:
		if t < m.born + m.life:
			alive.append(m)
	moles = alive
	if t >= next_spawn:
		var free: Array = []
		for cell in CELLS:
			if _mole_at(cell) == null:
				free.append(cell)
		if not free.is_empty() and moles.size() < 3:
			var gold := t >= next_gold
			if gold:
				next_gold = t + randf_range(8.0, 11.0)
				Audio.play("sparkle")
			moles.append({"cell": free.pick_random(), "born": t, "life": 1.8 if gold else randf_range(1.0, 1.6), "gold": gold, "bots": {}})
		next_spawn = t + randf_range(0.5, 0.95) * (1.0 - 0.4 * t / TIME)
	for p in players:
		if stun_shown.get(p.pid, false) and t >= float(stun_until.get(p.pid, 0.0)):
			stun_shown[p.pid] = false
			Net.set_ctrl(p.pid, layout(p))
	var keep: Array = []
	for h in hits:
		if t - h.t < 0.6:
			keep.append(h)
	hits = keep


func ranking() -> Array:
	return rank_by(func(p): return float(score[p.pid]), func(p): return "%d találat" % score[p.pid])


func _cell_pos(cell: int) -> Vector2:
	return Vector2(GX + (cell % 3 + 0.5) * CELL, GY + (cell / 3 + 0.5) * CELL)


func draw(c: CanvasItem) -> void:
	D.vgrad(c, Color("#3f9142"), Color("#1d5a2a"))
	for i in 18:
		var fx := fmod(i * 173.0, 1280.0)
		var fy := 90.0 + fmod(i * 97.0, 480.0)
		c.draw_circle(Vector2(fx, fy), 5, Color(1, 1, 1, 0.16))
	D.panel(c, GX - 18, GY - 18, CELL * 3 + 36, CELL * 3 + 36, {"r": 34, "fill": Color("#2f7a36"), "stroke": Color("#8ce99a"), "lw": 5})
	for cell in 9:
		var q := _cell_pos(cell)
		if cell == 4:
			D.emoji(c, "🌼", q.x, q.y, 54)
			continue
		D.ellipse(c, q.x, q.y + 34, 58, 22, Color("#3b2412"))
		var m = _mole_at(cell)
		if m != null:
			var age: float = t - m.born
			var up: float = clamp(age / 0.12, 0.0, 1.0) * clamp((m.life - age) / 0.15, 0.0, 1.0)
			var y := q.y + 34 - up * 52
			if m.gold:
				var glow := 0.5 + 0.5 * sin(Main.I.time * 12.0)
				c.draw_circle(Vector2(q.x, y - 6), 50 + glow * 6, Color(1, 0.83, 0.23, 0.35))
				c.draw_circle(Vector2(q.x, y - 6), 40, Color("#ffd43b"))
				c.draw_arc(Vector2(q.x, y - 6), 40, 0, TAU, 40, Color("#a16207"), 5, true)
				D.emoji(c, "🔨", q.x, y - 6, 46)
			else:
				# vakond: test, pofa, szemek, orr, fogak
				D.ellipse(c, q.x, y, 42, 46, Color("#6b4423"))
				D.ellipse(c, q.x, y + 12, 28, 22, Color("#c99a6b"))
				c.draw_circle(Vector2(q.x - 15, y - 12), 6, Color.WHITE)
				c.draw_circle(Vector2(q.x + 15, y - 12), 6, Color.WHITE)
				c.draw_circle(Vector2(q.x - 14, y - 11), 3, Color.BLACK)
				c.draw_circle(Vector2(q.x + 16, y - 11), 3, Color.BLACK)
				D.ellipse(c, q.x, y + 4, 9, 6, Color("#ff8fa3"))
				c.draw_rect(Rect2(q.x - 7, y + 18, 6, 9), Color.WHITE)
				c.draw_rect(Rect2(q.x + 1, y + 18, 6, 9), Color.WHITE)
			# a lyuk pereme eltakarja a vakond alját
			c.draw_rect(Rect2(q.x - 62, q.y + 40, 124, 34), Color("#2f7a36"))
		c.draw_arc(Vector2(q.x, q.y + 34), 58, 0.0, PI, 24, Color("#5a3a1e"), 7, true)
	for h in hits:
		var q := _cell_pos(h.cell)
		var k: float = clamp((t - h.t) / 0.25, 0.0, 1.0)
		var hp = G.by_pid(h.pid)
		c.draw_set_transform(Vector2(q.x + 30, q.y - 30), lerpf(-1.1, 0.35, k), Vector2(1.5, 1.5) if h.gold else Vector2.ONE)
		D.emoji(c, "🔨", 0, 0, 56)
		c.draw_set_transform(Vector2.ZERO)
		if h.ok:
			D.text(c, "💥", q.x, q.y + 6, {"size": 54, "alpha": 1.0 - k * 0.6})
		if hp:
			D.avatar(c, hp, q.x - 46, q.y - 46, 17, {"shadow": false, "alpha": 1.0 if h.ok else 0.6})
	D.timer_hud(c, TIME - t)
	D.text(c, "🔨 Vakondvadász", 180, 40, {"size": 28, "stroke": D.DARK, "sw": 6})
	D.text(c, "Arany kalapács = a többiek elkábulnak!", 1050, 40, {"size": 18, "color": Color("#ffe066"), "stroke": D.DARK, "sw": 5})
	D.score_bar(c, players, func(p): return score[p.pid])
	var n := players.size()
	var w: float = min(200.0, (1240.0 - (n - 1) * 8) / n)
	var x0 := 640.0 - (n * w + (n - 1) * 8) / 2.0
	for i in n:
		var p = players[i]
		if t < float(stun_until.get(p.pid, 0.0)):
			D.emoji(c, "💫", x0 + i * (w + 8) + 28, 664 + sin(Main.I.time * 10.0) * 3, 30)
