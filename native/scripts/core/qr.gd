class_name QR
## QR-kód készítő (bájt mód, M hibajavítás, 1–10. verzió) – külső könyvtár nélkül.
## encode(text) -> Array[Array[bool]] (true = sötét modul)

# [ecc kódszó/blokk, blokkok csoport1, adat/blokk cs1, blokkok cs2, adat/blokk cs2] – M szint
const EC_M := [
	[],
	[10, 1, 16, 0, 0], [16, 1, 28, 0, 0], [26, 1, 44, 0, 0], [18, 2, 32, 0, 0], [24, 2, 43, 0, 0],
	[16, 4, 27, 0, 0], [18, 4, 31, 0, 0], [22, 2, 38, 2, 39], [22, 3, 36, 2, 37], [26, 4, 43, 1, 44],
]
const ALIGN := [[], [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]]

static var _exp := PackedInt32Array()
static var _log := PackedInt32Array()


static func _init_gf() -> void:
	if _exp.size():
		return
	_exp.resize(512)
	_log.resize(256)
	var x := 1
	for i in 255:
		_exp[i] = x
		_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11d
	for i in range(255, 512):
		_exp[i] = _exp[i - 255]


static func _mul(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return _exp[_log[a] + _log[b]]


static func _rs(data: PackedInt32Array, n: int) -> PackedInt32Array:
	var gen := PackedInt32Array([1])
	for i in n:
		var ng := PackedInt32Array()
		ng.resize(gen.size() + 1)
		for j in gen.size():
			ng[j] ^= gen[j]
			ng[j + 1] ^= _mul(gen[j], _exp[i])
		gen = ng
	var res := PackedInt32Array()
	res.resize(n)
	for d in data:
		var f := d ^ res[0]
		for k in n - 1:
			res[k] = res[k + 1]
		res[n - 1] = 0
		for k in n:
			res[k] ^= _mul(gen[k + 1], f)
	return res


static func encode(text: String, force_mask := -1) -> Array:
	_init_gf()
	var bytes := text.to_utf8_buffer()
	var ver := 0
	for v in range(1, 11):
		var e: Array = EC_M[v]
		var cap: int = e[1] * e[2] + e[3] * e[4]
		var need := 4 + (8 if v < 10 else 16) + bytes.size() * 8
		if need <= cap * 8:
			ver = v
			break
	if ver == 0:
		push_error("QR: túl hosszú szöveg")
		return []
	var e: Array = EC_M[ver]
	var data_cw: int = e[1] * e[2] + e[3] * e[4]
	# bitfolyam
	var bits: Array[int] = []
	var put := func(val: int, n: int):
		for i in range(n - 1, -1, -1):
			bits.append((val >> i) & 1)
	put.call(4, 4)
	put.call(bytes.size(), 8 if ver < 10 else 16)
	for b in bytes:
		put.call(b, 8)
	for i in min(4, data_cw * 8 - bits.size()):
		bits.append(0)
	while bits.size() % 8:
		bits.append(0)
	var cw := PackedInt32Array()
	for i in range(0, bits.size(), 8):
		var v := 0
		for k in 8:
			v = (v << 1) | bits[i + k]
		cw.append(v)
	var pad := [0xEC, 0x11]
	var pi := 0
	while cw.size() < data_cw:
		cw.append(pad[pi % 2])
		pi += 1
	# blokkok + hibajavítás, összefésülés
	var blocks: Array = []
	var ecs: Array = []
	var off := 0
	for g in 2:
		var nb: int = e[1 + g * 2]
		var dl: int = e[2 + g * 2]
		for b in nb:
			var blk := cw.slice(off, off + dl)
			off += dl
			blocks.append(blk)
			ecs.append(_rs(blk, e[0]))
	var final := PackedInt32Array()
	var maxd := 0
	for b in blocks:
		maxd = max(maxd, b.size())
	for i in maxd:
		for b in blocks:
			if i < b.size():
				final.append(b[i])
	for i in e[0]:
		for ec in ecs:
			final.append(ec[i])

	var size := 17 + ver * 4
	var m: Array = []      # modulok (-1 = üres)
	var fn: Array = []     # funkcionális modul?
	for y in size:
		var row := []
		var frow := []
		row.resize(size)
		frow.resize(size)
		row.fill(0)
		frow.fill(false)
		m.append(row)
		fn.append(frow)
	var setf := func(x: int, y: int, dark: bool):
		m[y][x] = 1 if dark else 0
		fn[y][x] = true
	# keresőminták
	for c in [[0, 0], [size - 7, 0], [0, size - 7]]:
		for dy in range(-1, 8):
			for dx in range(-1, 8):
				var x: int = c[0] + dx
				var y: int = c[1] + dy
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				var dark := (dx >= 0 and dx <= 6 and (dy == 0 or dy == 6)) or (dy >= 0 and dy <= 6 and (dx == 0 or dx == 6)) \
					or (dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4)
				setf.call(x, y, dark)
	# igazítóminták
	var al: Array = ALIGN[ver]
	for ay in al:
		for ax in al:
			if fn[ay][ax]:
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					setf.call(ax + dx, ay + dy, max(abs(dx), abs(dy)) != 1)
	# időzítő sávok
	for i in range(8, size - 8):
		if not fn[6][i]: setf.call(i, 6, i % 2 == 0)
		if not fn[i][6]: setf.call(6, i, i % 2 == 0)
	# formátum-helyek lefoglalása + sötét modul
	for i in 9:
		if not fn[8][i]: setf.call(i, 8, false)
		if not fn[i][8]: setf.call(8, i, false)
	for i in 8:
		setf.call(size - 1 - i, 8, false)
		setf.call(8, size - 1 - i, false)
	setf.call(8, size - 8, true)
	# verzióinformáció (7+)
	if ver >= 7:
		var rem := ver
		for i in 12:
			rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
		var vb := (ver << 12) | rem
		for i in 18:
			var bit := ((vb >> i) & 1) == 1
			var a := size - 11 + i % 3
			var b := i / 3
			setf.call(a, b, bit)
			setf.call(b, a, bit)
	# adatbitek cikcakkban
	var dbits: Array[int] = []
	for v in final:
		for k in range(7, -1, -1):
			dbits.append((v >> k) & 1)
	var idx := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if fn[y][x]:
					continue
				m[y][x] = dbits[idx] if idx < dbits.size() else 0
				idx += 1
		right -= 2
	# maszk választás
	var best_mask := 0
	var best_score := 1 << 30
	var best: Array = []
	var masks := [force_mask] if force_mask >= 0 else range(8)
	for mask in masks:
		var mm: Array = []
		for y in size:
			mm.append(m[y].duplicate())
		for y in size:
			for x in size:
				if fn[y][x]:
					continue
				var inv := false
				match mask:
					0: inv = (x + y) % 2 == 0
					1: inv = y % 2 == 0
					2: inv = x % 3 == 0
					3: inv = (x + y) % 3 == 0
					4: inv = (y / 2 + x / 3) % 2 == 0
					5: inv = (x * y) % 2 + (x * y) % 3 == 0
					6: inv = ((x * y) % 2 + (x * y) % 3) % 2 == 0
					7: inv = ((x + y) % 2 + (x * y) % 3) % 2 == 0
				if inv:
					mm[y][x] ^= 1
		_format_bits(mm, size, mask)
		var sc := _penalty(mm, size)
		if sc < best_score:
			best_score = sc
			best_mask = mask
			best = mm
	var out: Array = []
	for y in size:
		var row: Array = []
		for x in size:
			row.append(best[y][x] == 1)
		out.append(row)
	return out


static func _format_bits(mm: Array, size: int, mask: int) -> void:
	var data := (0 << 3) | mask  # M szint = 00
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in 6:
		mm[i][8] = (bits >> i) & 1
	mm[7][8] = (bits >> 6) & 1
	mm[8][8] = (bits >> 7) & 1
	mm[8][7] = (bits >> 8) & 1
	for i in range(9, 15):
		mm[8][14 - i] = (bits >> i) & 1
	for i in 8:
		mm[8][size - 1 - i] = (bits >> i) & 1
	for i in range(8, 15):
		mm[size - 15 + i][8] = (bits >> i) & 1
	mm[size - 8][8] = 1


static func _penalty(mm: Array, size: int) -> int:
	var score := 0
	# 1. szabály: 5+ azonos egy sorban/oszlopban
	for pass_i in 2:
		for a in size:
			var run := 1
			var prev: int = mm[a][0] if pass_i == 0 else mm[0][a]
			for b in range(1, size):
				var v: int = mm[a][b] if pass_i == 0 else mm[b][a]
				if v == prev:
					run += 1
				else:
					if run >= 5: score += 3 + run - 5
					run = 1
					prev = v
			if run >= 5: score += 3 + run - 5
	# 2. szabály: 2x2 blokkok
	for y in size - 1:
		for x in size - 1:
			var v: int = mm[y][x]
			if v == mm[y][x + 1] and v == mm[y + 1][x] and v == mm[y + 1][x + 1]:
				score += 3
	# 3. szabály: keresőmintához hasonló sorozat
	var pat1 := [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0]
	var pat2 := [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1]
	for y in size:
		for x in size - 10:
			var h1 := true
			var h2 := true
			var v1 := true
			var v2 := true
			for k in 11:
				if mm[y][x + k] != pat1[k]: h1 = false
				if mm[y][x + k] != pat2[k]: h2 = false
				if mm[x + k][y] != pat1[k]: v1 = false
				if mm[x + k][y] != pat2[k]: v2 = false
			score += 40 * (int(h1) + int(h2) + int(v1) + int(v2))
	# 4. szabály: sötét arány
	var dark := 0
	for y in size:
		for x in size:
			dark += mm[y][x]
	var k := int(abs(dark * 20 - size * size * 10) / (size * size))
	score += k * 10
	return score
