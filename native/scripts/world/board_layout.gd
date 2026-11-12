class_name BoardLayout
## A pálya felépítése: lebegő szigetek, hidak, elágazások, ugrópadok.
## Tiszta adat + számolás. A koordináták a régi 2D tábla pixelei (1280×720); a 3D-ben 1 egység = 40 px.
##
## Mezők: T rajt · B kék (+3) · R piros (−3) · E esemény (?) · S bolt · J ugrópad
##        A barát (szövetséges csatlakozik) · V sziget-esemény (minden szigeten más történik)

const ISLANDS := [
	{"id": "meadow", "name": "Rét", "x": 250, "y": 455, "rx": 200, "ry": 150, "top": "#7cc552", "side": "#8b5e34", "rock": "#7c6f64",
		"big": [["fountain", 290, 440, 1.2]], "deco": ["tree", "tree", "flowers", "mushroom", "flowers", "tree"]},
	{"id": "forest", "name": "Erdő", "x": 245, "y": 170, "rx": 165, "ry": 120, "top": "#4f9a45", "side": "#6b4a2b", "rock": "#6b6461",
		"big": [], "deco": ["pine", "pine", "pine", "mushroom", "pine", "rock", "pine"]},
	{"id": "castle", "name": "Kastély", "x": 640, "y": 125, "rx": 205, "ry": 98, "top": "#8fd16a", "side": "#8b5e34", "rock": "#857a72",
		"big": [["castle", 530, 158, 1.0]], "deco": ["flowers", "tree", "flowers"]},
	{"id": "volcano", "name": "Vulkán", "x": 1035, "y": 180, "rx": 170, "ry": 125, "top": "#6e5446", "side": "#4a342a", "rock": "#3f3631",
		"big": [["volcano", 1040, 185, 1.05]], "deco": ["rock", "rock", "rock"]},
	{"id": "desert", "name": "Sivatag", "x": 1040, "y": 470, "rx": 175, "ry": 135, "top": "#e9c46a", "side": "#b07a3c", "rock": "#9c7b5b",
		"big": [["tent", 1050, 470, 1.1]], "deco": ["cactus", "cactus", "palm", "rock", "cactus", "palm"]},
	{"id": "crystal", "name": "Kristály", "x": 640, "y": 355, "rx": 150, "ry": 105, "top": "#a99cf2", "side": "#5b4a9e", "rock": "#4c4475",
		"big": [["crystal", 560, 345, 1.1], ["crystal", 715, 440, 0.9]], "deco": ["crystal", "rock"]},
	{"id": "beach", "name": "Öböl", "x": 640, "y": 585, "rx": 160, "ry": 62, "top": "#f2d18b", "side": "#b07a3c", "rock": "#9c8b7b",
		"big": [["chest", 700, 580, 0.9]], "deco": ["palm", "palm"]},
]

const MAIN_WP := [
	[330, 565], [205, 548], [120, 470], [130, 375],
	[170, 280], [150, 180], [210, 95], [335, 82],
	[470, 108], [560, 68], [720, 68], [820, 108],
	[905, 98], [1010, 72], [1125, 100], [1175, 195], [1110, 285],
	[1140, 375], [1180, 470], [1125, 562], [995, 590],
	[865, 602], [745, 588], [640, 610], [535, 590], [430, 578],
]
# fő kör mezői, 0 = rajt
const MAIN_TYPES := "TBEARBSBEJBRBEBVRBSEBARBEJBBVRBSBEBRB"

const BRANCHES := [
	{"id": "crystal", "from": [640, 68], "to": [640, 610], "via": [[625, 190], [655, 285], [625, 380], [650, 480]], "types": "RVBRAR",
		"route": {"label": "⬇️ Kristály-rövidítés", "sub": "Rövid, de veszélyes – sok a piros mező!"}},
	{"id": "lava", "from": [1110, 285], "to": "crystal:3", "via": [[1000, 330], [880, 355], [780, 360]], "types": "RVRE",
		"route": {"label": "⬅️ Lávahíd", "sub": "Átvág a közepére, de forró a talaj"}},
]
const MAIN_ROUTE := {"label": "➡️ Körút", "sub": "Hosszabb, de biztonságosabb"}


## determinisztikus véletlen, hogy a díszletek mindig ugyanott legyenek
class Seeded:
	var s := 0
	func _init(seed_v: int) -> void:
		s = seed_v
	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := _imul(s ^ (s >> 15), 1 | s)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xffffffff) ^ t
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
	static func _imul(a: int, b: int) -> int:
		return (a * b) & 0xffffffff


static func _curve(pts: Array, closed: bool, per := 30) -> Array:
	var n := pts.size()
	var out: Array = []
	var get_p := func(i: int) -> Vector2:
		var k := posmod(i, n) if closed else clampi(i, 0, n - 1)
		return Vector2(pts[k][0], pts[k][1])
	var segs := n if closed else n - 1
	for i in segs:
		var p0: Vector2 = get_p.call(i - 1)
		var p1: Vector2 = get_p.call(i)
		var p2: Vector2 = get_p.call(i + 1)
		var p3: Vector2 = get_p.call(i + 2)
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(Vector2(pts[0][0], pts[0][1]) if closed else Vector2(pts[n - 1][0], pts[n - 1][1]))
	return out


static func _along(line: Array, fracs: Array) -> Array:
	var cum := [0.0]
	for i in range(1, line.size()):
		cum.append(cum[i - 1] + line[i].distance_to(line[i - 1]))
	var L: float = cum[cum.size() - 1]
	var j := 0
	var out: Array = []
	for f in fracs:
		var target: float = L * f
		while j < cum.size() - 1 and cum[j + 1] < target:
			j += 1
		var k: float = (target - cum[j]) / (cum[j + 1] - cum[j]) if cum[j + 1] > cum[j] else 0.0
		var a: Vector2 = line[j]
		var b: Vector2 = line[min(j + 1, line.size() - 1)]
		out.append(a.lerp(b, k))
	return out


static func island_at(x: float, y: float, pad := 0.0):
	for s in ISLANDS:
		if pow((x - s.x) / (s.rx + pad), 2) + pow((y - s.y) / (s.ry + pad), 2) <= 1.0:
			return s
	return null


static func island_by_id(id: String):
	for s in ISLANDS:
		if s.id == id:
			return s
	return null


static func build() -> Dictionary:
	var nodes: Array = []
	var add := func(p: Vector2, type: String, inner: String) -> Dictionary:
		var n := {"id": nodes.size(), "x": roundi(p.x), "y": roundi(p.y), "type": type, "next": [], "inner": inner, "routes": [], "pair": -1, "island": ""}
		nodes.append(n)
		return n
	var N := MAIN_TYPES.length()
	var fr: Array = []
	for i in N:
		fr.append(float(i) / N)
	var main: Array = []
	var pts := _along(_curve(MAIN_WP, true), fr)
	for i in N:
		main.append(add.call(pts[i], MAIN_TYPES[i], ""))
	for i in N:
		main[i].next.append(main[(i + 1) % N].id)
	var nearest := func(p: Array) -> Dictionary:
		var best: Dictionary = main[0]
		for n in main:
			if Vector2(n.x - p[0], n.y - p[1]).length() < Vector2(best.x - p[0], best.y - p[1]).length():
				best = n
		return best
	var branch_nodes := {}
	for br in BRANCHES:
		var a: Dictionary = nearest.call(br.from)
		var b: Dictionary
		if typeof(br.to) == TYPE_STRING:
			b = branch_nodes[br.to.get_slice(":", 0)][int(br.to.get_slice(":", 1))]
		else:
			b = nearest.call(br.to)
		var wp: Array = [[a.x, a.y]]
		wp.append_array(br.via)
		wp.append([b.x, b.y])
		var line := _curve(wp, false)
		var k: int = br.types.length()
		var fr2: Array = []
		for i in k:
			fr2.append(float(i + 1) / (k + 1))
		var bp := _along(line, fr2)
		var list: Array = []
		for i in k:
			list.append(add.call(bp[i], br.types[i], br.id))
		branch_nodes[br.id] = list
		if a.routes.is_empty():
			a.routes.append(MAIN_ROUTE)
		a.next.append(list[0].id)
		a.routes.append(br.route)
		for i in k:
			list[i].next.append(list[i + 1].id if i + 1 < k else b.id)
	# ugrópadok párban
	var pads := nodes.filter(func(n): return n.type == "J")
	var i := 0
	while i + 1 < pads.size():
		pads[i].pair = pads[i + 1].id
		pads[i + 1].pair = pads[i].id
		i += 2
	for n in nodes:
		var s = island_at(n.x, n.y, 6)
		n.island = s.id if s else (n.inner if n.inner == "lava" else "")
	return {"nodes": nodes, "start": 0, "deco": _place_deco(nodes)}


static func place_hidden_blocks(board: Dictionary, count := 4) -> Dictionary:
	var cand: Array = board.nodes.filter(func(n): return n.type in ["B", "R"])
	cand.shuffle()
	var out := {}
	for k in min(count, cand.size()):
		out[cand[k].id] = _hidden_kind()
	return out


static func _hidden_kind() -> String:
	var r := randf()
	if r < 0.08: return "crown"
	if r < 0.3: return "item"
	return "coins"


static func _seg_dist(p: Vector2, a: Dictionary, b: Dictionary) -> float:
	var av := Vector2(a.x, a.y)
	var d := Vector2(b.x, b.y) - av
	var l2 := d.length_squared()
	var t: float = clamp((p - av).dot(d) / (l2 if l2 > 0 else 1.0), 0.0, 1.0)
	return p.distance_to(av + d * t)


static func _place_deco(nodes: Array) -> Array:
	var rnd := Seeded.new(7)
	var segs: Array = []
	for n in nodes:
		for id in n.next:
			segs.append([n, nodes[id]])
	var out: Array = []
	var free := func(p: Vector2, r: float) -> bool:
		for sg in segs:
			if _seg_dist(p, sg[0], sg[1]) <= r + 26:
				return false
		for o in out:
			if Vector2(o[1], o[2]).distance_to(p) <= r + 22 * o[3]:
				return false
		return true
	for s in ISLANDS:
		for d in s.big:
			out.append(d)
		for kind in s.deco:
			for tries in 60:
				var a := rnd.next() * TAU
				var rr := sqrt(rnd.next()) * 0.82
				var p := Vector2(s.x + cos(a) * s.rx * rr, s.y + sin(a) * s.ry * rr)
				var sc := 0.8 + rnd.next() * 0.45
				if free.call(p, 22 * sc):
					out.append([kind, roundi(p.x), roundi(p.y), snappedf(sc, 0.01)])
					break
	return out
