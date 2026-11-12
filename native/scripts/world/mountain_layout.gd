class_name MountainLayout
## A hegymászós játékmód pályája: egyetlen, a hegy körül felfelé csavarodó út.
## Tiszta adat + geometria (a 3D megjelenítés a Mountain3D-ben van).
##
## Mezők: T rajt · N sima · P büntető (vissza N mezőt) · F hátszél (előre N mezőt)
##        X jég (kimaradsz egy dobásból) · G kapu (csak adott dobással nyílik) · W csúcs (cél)

const GOAL := 80             # a csúcs mező sorszáma (a rajt a 0.), vagyis 80 lépés az út
const SPIRAL_N := 80         # a 0..79. mező van a spirálon, a 80. a csúcs közepe
const RB := 11.5             # az út sugara lent
const RT := 2.6              # az út sugara fent
const H := 15.0              # az út teteje
const SPACING := 1.6         # két mező távolsága az út mentén
const PATH_W := 0.95         # az út félszélessége
const WALL_IN := 0.75        # a hegy fala ennyivel van beljebb az út közepénél
const SUMMIT_Y := H + 0.45

const GATE_NODES := [20, 42, 62]
const GATE_NEEDS := [5, 6, 8]

static var _theta: PackedFloat32Array = PackedFloat32Array()


static func _thetas() -> PackedFloat32Array:
	if _theta.is_empty():
		var a := 0.0
		for i in SPIRAL_N:
			_theta.append(a)
			a += SPACING / lerpf(RB, RT, float(i) / (SPIRAL_N - 1))
	return _theta


## Az út sugara, szöge és magassága az s (tört mezősorszám) helyen, s <= 79.
static func polar(s: float) -> Vector3:
	var th := _thetas()
	var c: float = clamp(s, 0.0, float(SPIRAL_N - 1))
	var i := int(floor(c))
	var j: int = min(i + 1, SPIRAL_N - 1)
	var k := c - i
	var k01 := c / (SPIRAL_N - 1)
	return Vector3(lerpf(RB, RT, k01), lerpf(th[i], th[j], k), H * k01)


## Világkoordináta az út s pontján (79 fölött a csúcs közepe felé megy).
static func pos(s: float) -> Vector3:
	var last := float(SPIRAL_N - 1)
	if s > last:
		var a := pos(last)
		return a.lerp(Vector3(0, SUMMIT_Y, 0), clamp(s - last, 0.0, 1.0))
	var p := polar(s)
	return Vector3(sin(p.y) * p.x, p.z, cos(p.y) * p.x)


## A hegy tengelyétől kifelé mutató egységvektor az s pontban.
static func radial(s: float) -> Vector3:
	var a := angle(s)
	return Vector3(sin(a), 0, cos(a))


## Az út haladási iránya (felfelé) az s pontban.
static func tangent(s: float) -> Vector3:
	var a := angle(s)
	return Vector3(cos(a), 0, -sin(a))


static func angle(s: float) -> float:
	return polar(min(s, float(SPIRAL_N - 1))).y


## A hegy falának sugara y magasságban.
static func wall_r(y: float) -> float:
	return lerpf(RB, RT, clamp(y / H, -0.2, 1.0)) - WALL_IN


static func zone(i: int) -> int:
	return 0 if i < 27 else (1 if i < 54 else 2)


static func build() -> Dictionary:
	var nodes: Array = []
	for i in GOAL + 1:
		nodes.append({"id": i, "type": "N", "val": 0})
	nodes[0].type = "T"
	nodes[GOAL].type = "W"
	var gates: Array = []
	for k in GATE_NODES.size():
		var id: int = GATE_NODES[k] + randi_range(-2, 2)
		nodes[id].type = "G"
		nodes[id].val = GATE_NEEDS[k]
		gates.append({"node": id, "need": GATE_NEEDS[k], "open": false, "idx": k})
	# különleges mezők: zónánként elosztva, hogy lent szelídebb, fent keményebb legyen a hegy
	var plan := [
		{"from": 3, "to": 26, "P": 4, "X": 1, "F": 2, "vals": [2, 2, 3, 3]},
		{"from": 27, "to": 53, "P": 5, "X": 1, "F": 2, "vals": [2, 3, 3, 4, 4]},
		{"from": 54, "to": 78, "P": 6, "X": 2, "F": 2, "vals": [3, 4, 4, 5, 6, 4]},
	]
	var special := func(i: int) -> bool:
		return i >= 0 and i <= GOAL and nodes[i].type != "N"
	for z in plan:
		var kinds: Array = []
		for k in z.P: kinds.append("P")
		for k in z.X: kinds.append("X")
		for k in z.F: kinds.append("F")
		var vals: Array = z.vals.duplicate()
		vals.shuffle()
		var cand: Array = range(z.from, z.to + 1)
		cand.shuffle()
		for kind in kinds:
			for id in cand:
				if nodes[id].type != "N":
					continue
				# kapu mellé nem kerül, és legfeljebb két különleges mező lehet egymás mellett
				if nodes[id - 1].type == "G" or nodes[id + 1].type == "G":
					continue
				var left: bool = special.call(id - 1)
				var right: bool = special.call(id + 1)
				if (left and right) or (left and special.call(id - 2)) or (right and special.call(id + 2)):
					continue
				nodes[id].type = kind
				if kind == "P":
					nodes[id].val = vals.pop_back() if vals.size() else 3
				elif kind == "F":
					nodes[id].val = randi_range(2, 3)
				break
	return {"nodes": nodes, "gates": gates, "goal": GOAL, "seed": randi()}


static func gate_at(layout: Dictionary, id: int):
	for g in layout.gates:
		if g.node == id:
			return g
	return null
