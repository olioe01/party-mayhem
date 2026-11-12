class_name GameScene
extends Node
## Jelenet-alaposztály: saját időzítők (a jelenet halála után nem futnak tovább),
## frissítés, 2D rajzolás az átfedő rétegre, telefonos bemenet.

var t := 0.0
var dead := false
var _timers: Array = []
var buttons: Array = []   # egérrel kattintható gombok (minden rajzoláskor újra regisztrálva)


class Waiter:
	extends RefCounted
	signal fired
	var at := 0.0
	var fn: Callable


func after(sec: float, fn: Callable) -> Waiter:
	var w := Waiter.new()
	w.at = t + sec
	w.fn = fn
	_timers.append(w)
	return w


## await sleep(1.0) – ha közben jelenetváltás van, a folytatás egyszerűen elmarad.
func sleep(sec: float) -> Signal:
	var w := Waiter.new()
	w.at = t + sec
	_timers.append(w)
	return w.fired


func _tick(dt: float) -> void:
	t += dt
	if _timers.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for w in _timers:
		if w.at <= t: due.append(w)
		else: keep.append(w)
	if due.is_empty():
		return
	_timers = keep
	for w in due:
		if dead:
			return
		if w.fn.is_valid():
			w.fn.call()
		w.fired.emit()


func kill() -> void:
	dead = true
	_timers.clear()


## Kattintható gomb a 2D rétegen (a böngészős változat button() megfelelője).
func button(c: CanvasItem, x: float, y: float, w: float, h: float, label: String, fn: Callable, o := {}) -> void:
	var color: Color = o.get("color", Color("#ffd43b"))
	var text_color: Color = o.get("text_color", Color("#2b1055"))
	var m: Vector2 = c.get_local_mouse_position()
	var hover := m.x >= x and m.x <= x + w and m.y >= y and m.y <= y + h
	D.panel(c, x, y + 5, w, h, {"r": h / 2, "fill": D.shade(color, -0.35), "stroke": null, "shadow": false})
	D.panel(c, x, y + (2 if hover else 0), w, h, {"r": h / 2, "fill": D.shade(color, 0.15) if hover else color, "stroke": null, "shadow": false})
	D.text(c, label, x + w / 2, y + h / 2 + (2 if hover else 0), {"size": o.get("size", 24), "color": text_color})
	buttons.append({"rect": Rect2(x, y, w, h), "fn": fn})


func click(pos: Vector2) -> void:
	for b in buttons:
		if b.rect.has_point(pos):
			b.fn.call()
			return


# ---- felülírható
func enter() -> void: pass
func exit() -> void: pass
func update(_dt: float) -> void: pass
func draw(_c: CanvasItem) -> void: pass
func input(_pid: String, _msg: Dictionary) -> void: pass
func key(_e: InputEventKey) -> void: pass
func players_changed() -> void: pass
