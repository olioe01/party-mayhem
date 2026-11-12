class_name D
## 2D rajzoló segédfüggvények (a böngészős változat canvas-segédeinek megfelelői).
## Koordináták: 1280×720-as virtuális képernyő.

const W := 1280.0
const H := 720.0
const DARK := Color("#1b1036")

static var font: Font = preload("res://fonts/bold_font.tres")
static var font_mid: Font = preload("res://fonts/ui_font.tres")
static var _sb_cache := {}


static func rgba(hex: String, a := 1.0) -> Color:
	var c := Color(hex)
	c.a = a
	return c


static func shade(c: Color, amt: float) -> Color:
	if amt >= 0.0:
		return c.lerp(Color(1, 1, 1, c.a), amt)
	return Color(c.r * (1.0 + amt), c.g * (1.0 + amt), c.b * (1.0 + amt), c.a)


static func ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)


static func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)


static func ease_in_out(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0


static func text_width(s: String, size: int, bold := true) -> float:
	return (font if bold else font_mid).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Szöveg: függőlegesen középre igazítva y-ra. o: size, color, stroke(Color), sw, align("center"/"left"/"right"), maxw, bold, alpha
static func text(c: CanvasItem, s: String, x: float, y: float, o := {}) -> void:
	var size: int = int(o.get("size", 32))
	if size <= 0 or s == "":
		return
	var f: Font = font if o.get("bold", true) else font_mid
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var maxw: float = o.get("maxw", 0.0)
	if maxw > 0.0 and w > maxw:
		size = max(8, int(size * maxw / w))
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var align: String = o.get("align", "center")
	var px := x - w / 2.0
	if align == "left": px = x
	elif align == "right": px = x - w
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var py := y + (asc - desc) / 2.0
	var a: float = o.get("alpha", 1.0)
	var col: Color = o.get("color", Color.WHITE)
	col.a *= a
	if o.has("stroke") and o.stroke != null:
		var sc: Color = o.stroke
		sc.a *= a
		c.draw_string_outline(f, Vector2(px, py), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(o.get("sw", 6)), sc)
	c.draw_string(f, Vector2(px, py), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Több soros szöveg tördeléssel (balra igazítva).
static func wrap(c: CanvasItem, s: String, x: float, y: float, maxw: float, lh: float, o := {}) -> float:
	var size: int = int(o.get("size", 24))
	var words := s.split(" ")
	var line := ""
	var yy := y
	var oo := o.duplicate()
	oo["align"] = o.get("align", "left")
	for w in words:
		var test := w if line == "" else line + " " + w
		if text_width(test, size, o.get("bold", true)) > maxw and line != "":
			text(c, line, x, yy, oo)
			line = w
			yy += lh
		else:
			line = test
	if line != "":
		text(c, line, x, yy, oo)
	return yy


static func _stylebox(fill: Color, stroke, r: float, lw: float) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [fill.to_html(), str(stroke), int(r), int(lw)]
	if _sb_cache.has(key):
		return _sb_cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(r))
	sb.corner_detail = 10
	sb.anti_aliasing = true
	if stroke != null:
		sb.border_color = stroke
		sb.set_border_width_all(int(lw))
	if _sb_cache.size() > 400:
		_sb_cache.clear()
	_sb_cache[key] = sb
	return sb


## Lekerekített panel. o: fill, stroke (Color vagy null), r, lw, shadow
static func panel(c: CanvasItem, x: float, y: float, w: float, h: float, o := {}) -> void:
	var r: float = min(o.get("r", 20.0), min(w, h) / 2.0)
	if o.get("shadow", true):
		_stylebox(Color(0, 0, 0, 0.28), null, r, 0).draw(c.get_canvas_item(), Rect2(x + 2, y + 7, w, h))
	var fill: Color = o.get("fill", Color(0.094, 0.055, 0.22, 0.88))
	var stroke = o.get("stroke", Color(1, 1, 1, 0.18))
	_stylebox(fill, stroke, r, o.get("lw", 3.0)).draw(c.get_canvas_item(), Rect2(x, y, w, h))


static func emoji(c: CanvasItem, e: String, x: float, y: float, size: float, alpha := 1.0) -> void:
	text(c, e, x, y + size * 0.04, {"size": int(size), "alpha": alpha})


static func vgrad(c: CanvasItem, top: Color, bottom: Color, y0 := 0.0, y1 := H) -> void:
	var pts := PackedVector2Array([Vector2(0, y0), Vector2(W, y0), Vector2(W, y1), Vector2(0, y1)])
	c.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


static func ellipse(c: CanvasItem, x: float, y: float, rx: float, ry: float, col: Color, seg := 32) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
	c.draw_colored_polygon(pts, col)


static func ring(c: CanvasItem, x: float, y: float, r: float, col: Color, lw: float) -> void:
	c.draw_arc(Vector2(x, y), r, 0, TAU, 48, col, lw, true)


## Játékos-avatar: színes korong + portré. o: alpha, ring(Color), shadow, squash, gray
static func avatar(c: CanvasItem, p, x: float, y: float, r: float, o := {}) -> void:
	var alpha: float = o.get("alpha", 1.0)
	var col: Color = Color("#6b7280") if o.get("gray", false) else p.color
	if o.get("shadow", true):
		ellipse(c, x, y + r * 0.95, r * 0.85, r * 0.26, Color(0, 0, 0, 0.28 * alpha))
	var sq: float = o.get("squash", 0.0)
	c.draw_set_transform(Vector2(x, y), 0, Vector2(1 + sq, 1 - sq))
	var light := shade(col, 0.45)
	light.a = alpha
	var dark := shade(col, -0.4)
	dark.a = alpha
	var base := col
	base.a = alpha
	c.draw_circle(Vector2.ZERO, r, base)
	c.draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.55, Color(light, 0.35 * alpha))
	c.draw_arc(Vector2.ZERO, r, 0, TAU, 40, dark, max(2.0, r * 0.12), true)
	if o.has("ring") and o.ring != null:
		c.draw_arc(Vector2.ZERO, r * 1.22, 0, TAU, 40, o.ring, max(3.0, r * 0.16), true)
	var tex: Texture2D = G.portrait(p.char_id)
	if tex:
		var m := Color(1, 1, 1, alpha * (0.55 if o.get("gray", false) else 1.0))
		c.draw_texture_rect(tex, Rect2(-r * 1.12, -r * 1.06, r * 2.24, r * 2.24), false, m)
	c.draw_set_transform(Vector2.ZERO)


static func char_image(c: CanvasItem, char_id: String, x: float, y: float, size: float, alpha := 1.0) -> void:
	var tex: Texture2D = G.portrait(char_id)
	if tex:
		c.draw_texture_rect(tex, Rect2(x - size / 2, y - size / 2, size, size), false, Color(1, 1, 1, alpha))


static func timer_hud(c: CanvasItem, remain: float, x := 640.0, y := 36.0) -> void:
	var r: float = max(0.0, remain)
	var low := r <= 5.0
	panel(c, x - 75, y - 25, 150, 50, {"r": 25, "fill": Color(0.86, 0.15, 0.15, 0.92) if low else Color(0.08, 0.05, 0.19, 0.85)})
	text(c, "⏱ %d" % ceili(r), x, y + 1, {"size": 28})


## alsó sáv: játékosok pontszámmal
static func score_bar(c: CanvasItem, players: Array, value_of: Callable, y := 680.0, h := 56.0) -> void:
	var n := players.size()
	var w: float = min(200.0, (1240.0 - (n - 1) * 8) / n)
	var x0 := 640.0 - (n * w + (n - 1) * 8) / 2.0
	for i in n:
		var p = players[i]
		var x := x0 + i * (w + 8)
		panel(c, x, y - h / 2, w, h, {"r": 16, "fill": Color(0.08, 0.05, 0.19, 0.8), "stroke": p.color, "shadow": false})
		avatar(c, p, x + 28, y, 18, {"shadow": false})
		text(c, str(value_of.call(p)), x + w - 14, y + 1, {"size": 26, "align": "right", "color": Color("#ffd43b")})
		text(c, p.name, x + 52, y - 13, {"size": 13, "align": "left", "color": Color("#dddddd"), "maxw": w - 90})
