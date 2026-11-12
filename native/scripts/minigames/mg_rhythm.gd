extends Minigame
## Ritmusdob – a képernyőn 4 sávban érkeznek a jelek, és a telefon 4 színes gombját kell
## ütemre megnyomni, amikor a jel a célvonalra ér. A pontosság ad pontot, a tempó egyre gyorsul.
## Mindenki ugyanazt a kottát kapja.

const PADS := [
	{"color": "#ff4d6d", "shape": "▲"},
	{"color": "#4dabf7", "shape": "●"},
	{"color": "#51cf66", "shape": "■"},
	{"color": "#ffd43b", "shape": "★"},
]
const LIMIT := 44.0
const TRAVEL := 1.7
const WIN := 0.2
const LANE_W := 96.0
const TOP_Y := 70.0
const HIT_Y := 545.0

var notes: Array = []        # {time, lane}
var st: Array = []
var sound_ptr := 0
var lane_flash := [-9.0, -9.0, -9.0, -9.0]
var beat_pulse := -9.0


func meta() -> Dictionary:
	return {"id": "rhythm", "name": "Ritmusdob", "icon": "🥁", "color": "#b197fc", "modes": ["ffa", "2v2", "1v3"],
		"tagline": "Üsd ütemre!",
		"desc": "A képernyőn négy színes sávban érkeznek a jelek. Amikor egy jel a célvonalra ér, nyomd meg a telefonodon az ugyanolyan színű gombot! Minél pontosabb vagy, annál több pontot kapsz, a sorozatos találat pedig bónuszt ér. A tempó egyre gyorsul – a vaktában nyomkodás pontlevonással jár.",
		"controls": "A 4 színes gombot nyomd ütemre: mindig azt, amelyik színű jel éppen a célvonalra ér."}


func layout(_p) -> Dictionary:
	return {"mode": "pads", "enabled": true, "pads": PADS, "title": "🥁 Üsd ütemre!"}


func _ready() -> void:
	Audio.music("")
	var tt := 2.2
	var last := -1
	var rep := 0
	while tt < LIMIT - 2.0:
		var step := lerpf(0.62, 0.36, tt / LIMIT)
		if randf() > 0.1:
			var lane := randi() % 4
			if lane == last:
				rep += 1
				if rep >= 2:
					lane = (lane + 1 + randi() % 3) % 4
					rep = 0
			else:
				rep = 0
			last = lane
			notes.append({"time": tt, "lane": lane})
			if tt > LIMIT * 0.5 and randf() < 0.16:
				notes.append({"time": tt, "lane": (lane + 1 + randi() % 3) % 4})
			if tt > LIMIT * 0.3 and randf() < 0.2:
				notes.append({"time": tt + step / 2.0, "lane": randi() % 4})
		tt += step
	notes.sort_custom(func(a, b): return a.time < b.time)
	for p in players:
		st.append({"p": p, "score": 0, "combo": 0, "best": 0, "hits": 0, "judged": {}, "ptr": 0, "last": "", "last_t": -9.0, "last_col": Color.WHITE,
			"bot_ptr": 0, "bot_err": 0.0, "bot_skip": false, "skill": randf_range(0.03, 0.09), "bump": 0.0})


func _get(p) -> Dictionary:
	for s in st:
		if s.p == p:
			return s
	return {}


func _say(s: Dictionary, txt: String, col: Color) -> void:
	s.last = txt
	s.last_t = t
	s.last_col = col


func input(p, msg: Dictionary) -> void:
	if msg.get("t") != "pad":
		return
	var s := _get(p)
	if s.is_empty():
		return
	var lane := int(msg.get("v", -1))
	if lane < 0 or lane > 3:
		return
	lane_flash[lane] = t
	var best := -1
	var bd := WIN
	for i in range(s.ptr, notes.size()):
		var nt: Dictionary = notes[i]
		if nt.time > t + WIN:
			break
		if nt.lane != lane or s.judged.has(i):
			continue
		var d := absf(nt.time - t)
		if d <= bd:
			bd = d
			best = i
	if best < 0:
		s.combo = 0
		s.score = maxi(0, s.score - 1)
		_say(s, "Mellé −1", Color("#ff8787"))
		return
	s.judged[best] = true
	s.combo += 1
	s.best = maxi(s.best, s.combo)
	s.hits += 1
	s.bump = 1.0
	var pts := 1
	if bd <= 0.065:
		pts = 3
		_say(s, "TÖKÉLETES", Color("#ffe066"))
	elif bd <= 0.13:
		pts = 2
		_say(s, "Jó!", Color("#8ce99a"))
	else:
		_say(s, "Oké", Color("#a5d8ff"))
	if s.combo >= 10:
		pts += 1
	s.score += pts
	if s.combo > 0 and s.combo % 10 == 0:
		Net.vibrate(p.pid, [30, 20, 60])


func bot(p, _dt: float) -> void:
	var s := _get(p)
	while s.bot_ptr < notes.size():
		var nt: Dictionary = notes[s.bot_ptr]
		if t < nt.time + s.bot_err:
			return
		if not s.bot_skip:
			input(p, {"t": "pad", "v": nt.lane})
		s.bot_ptr += 1
		s.bot_err = clampf(randfn(0.0, s.skill), -0.18, 0.18)
		s.bot_skip = randf() < 0.1


func update(dt: float) -> void:
	# a jel hangja, amikor a célvonalra ér – ez adja a ritmust
	while sound_ptr < notes.size() and notes[sound_ptr].time <= t:
		Audio.pad_soft(notes[sound_ptr].lane)
		Audio.play("tick")
		beat_pulse = t
		sound_ptr += 1
	for s in st:
		s.bump = maxf(0.0, s.bump - dt * 5.0)
		while s.ptr < notes.size() and notes[s.ptr].time < t - WIN:
			if not s.judged.has(s.ptr):
				if s.combo >= 3:
					_say(s, "Kimaradt", Color("#adb5bd"))
				s.combo = 0
			s.ptr += 1
	if t >= LIMIT:
		finished = true


func ranking() -> Array:
	return rank_by(_rank_score, _rank_label)


func _rank_score(p) -> float:
	var s := _get(p)
	return float(s.score) + float(s.best) * 0.001


func _rank_label(p) -> String:
	var s := _get(p)
	return "%d pont (sorozat: %d)" % [s.score, s.best]


func draw(c: CanvasItem) -> void:
	bg(c, 275.0)
	var x0 := 640.0 - LANE_W * 2
	var pulse: float = clampf(1.0 - (t - beat_pulse) * 5.0, 0.0, 1.0)
	D.panel(c, x0 - 14, TOP_Y - 30, LANE_W * 4 + 28, HIT_Y - TOP_Y + 110, {"r": 26, "fill": Color(0.05, 0.03, 0.14, 0.92), "stroke": Color(1, 1, 1, 0.15 + pulse * 0.25), "lw": 4})
	for i in 4:
		var col := Color(PADS[i].color)
		var lx := x0 + i * LANE_W
		var fl: float = clampf(1.0 - (t - lane_flash[i]) * 5.0, 0.0, 1.0)
		c.draw_rect(Rect2(lx + 3, TOP_Y - 20, LANE_W - 6, HIT_Y - TOP_Y + 90), Color(col, 0.07 + fl * 0.22))
		# célkör
		var cx := lx + LANE_W / 2
		c.draw_circle(Vector2(cx, HIT_Y), 36, Color(col, 0.18 + fl * 0.4))
		c.draw_arc(Vector2(cx, HIT_Y), 36 + fl * 6, 0, TAU, 40, col, 5, true)
		D.text(c, PADS[i].shape, cx, HIT_Y, {"size": 30, "color": Color(1, 1, 1, 0.45 + fl * 0.5)})
	c.draw_rect(Rect2(x0, HIT_Y - 2, LANE_W * 4, 4), Color(1, 1, 1, 0.35))
	for nt in notes:
		var dtm: float = nt.time - t
		if dtm > TRAVEL:
			break
		if dtm < -0.22:
			continue
		var y := HIT_Y - dtm / TRAVEL * (HIT_Y - TOP_Y)
		var col := Color(PADS[nt.lane].color)
		var cx: float = x0 + nt.lane * LANE_W + LANE_W / 2
		var al := 1.0 if dtm >= 0 else clampf(1.0 + dtm / 0.22, 0.0, 1.0)
		c.draw_circle(Vector2(cx, y + 4), 30, Color(0, 0, 0, 0.35 * al))
		c.draw_circle(Vector2(cx, y), 30, Color(col, al))
		c.draw_arc(Vector2(cx, y), 30, 0, TAU, 32, Color(1, 1, 1, 0.85 * al), 3, true)
		D.text(c, PADS[nt.lane].shape, cx, y, {"size": 26, "alpha": al})
	# játékosok két oszlopban
	var n := st.size()
	var per := int(ceil(n / 2.0))
	var ph: float = minf(130.0, 560.0 / maxi(1, per))
	for i in n:
		var s: Dictionary = st[i]
		var left := i % 2 == 0
		var row := i / 2
		var px := 36.0 if left else 1280.0 - 36.0 - 370.0
		var py := 90.0 + row * ph
		var tix := team_of(s.p)
		var stroke: Color = MgFlow.TEAM_COLORS[tix] if tix >= 0 else s.p.color
		D.panel(c, px, py, 370, ph - 12, {"r": 20, "fill": Color(0.08, 0.05, 0.19, 0.85), "stroke": stroke, "lw": 4})
		var ay := py + (ph - 12) / 2
		D.avatar(c, s.p, px + 48, ay - s.bump * 8.0, minf(34.0, ph * 0.3), {"shadow": false})
		D.text(c, s.p.name, px + 96, ay - 22, {"size": 20, "align": "left", "maxw": 160})
		D.text(c, "%d" % s.score, px + 350, ay - 14, {"size": 38, "align": "right", "color": Color("#ffd43b")})
		if s.combo >= 3:
			D.text(c, "🔥 %d" % s.combo, px + 350, ay + 24, {"size": 18, "align": "right", "color": Color("#ffa94d")})
		if t - s.last_t < 0.7:
			D.text(c, s.last, px + 96, ay + 14, {"size": 20, "align": "left", "color": s.last_col, "alpha": clampf((0.7 - (t - s.last_t)) * 4.0, 0.0, 1.0)})
	D.timer_hud(c, LIMIT - t, 640, 30)
	D.text(c, "Nyomd a színes gombot, amikor a jel a körbe ér!", 640, 690, {"size": 20, "color": Color("#e5dbff"), "stroke": Color.BLACK, "sw": 5})
