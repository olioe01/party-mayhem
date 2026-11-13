class_name FX
## Díszítő (nem játékmenetbeli) véletlen: részecskék, pislogás, kamerarázás.
## Külön generátor, hogy a látvány soha ne léptesse a játék közös véletlenszám-sorozatát –
## online játékban a kockadobásoknak minden gépen ugyanannak kell lenniük.

static var r := RandomNumberGenerator.new()


static func f() -> float:
	return r.randf()


static func fr(a: float, b: float) -> float:
	return r.randf_range(a, b)


static func pick(a: Array):
	return a[r.randi() % a.size()]
