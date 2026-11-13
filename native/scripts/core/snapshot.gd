class_name Snapshot
## Állapotmentés jelenetváltáskor (online játékhoz).
## Minden jelenetváltásnál a hoszt bájtokba menti a játék teljes állapotát és az új jelenet
## induló adatait; MINDEN gép (a hoszt is) ebből a mentésből folytatja. Így a később
## csatlakozó gép pontosan ugyanonnan indul, és az esetleges apró eltérések sem öröklődnek.
##
## Csak adat megy át: a szkript-objektumok közül kizárólag az itt felsorolt osztályok
## példányosíthatók, szkriptet pedig csak a res://scripts/ alól tölt be.

const VERSION := 1
const K_OBJ := "\u0001o"
const K_SCRIPT := "\u0001s"

## ezekben a fájlokban vannak a menthető osztályok (a belső osztályokat is felveszi)
const CLASS_FILES := [
	"res://scripts/core/state.gd",
	"res://scripts/scenes/lobby_scene.gd",
	"res://scripts/scenes/board_scene.gd",
	"res://scripts/scenes/mountain_scene.gd",
	"res://scripts/scenes/final_scene.gd",
	"res://scripts/scenes/mg_flow.gd",
]
const G_SKIP := ["portraits"]
const SCENE_SKIP := ["_timers", "buttons"]
const NET_KEYS := ["bots", "away", "layouts", "_seq"]
const GAME_KEYS := ["force_mg", "test_start_node", "test_tiles"]

static var _name_of := {}      # Script -> név
static var _script_of := {}    # név -> Script
static var _warned := {}


static func _registry() -> void:
	if not _script_of.is_empty():
		return
	for path in CLASS_FILES:
		var s: Script = load(path)
		_add(path, s)
		_add_inner(path, s)


static func _add(n: String, s: Script) -> void:
	_name_of[s] = n
	_script_of[n] = s


static func _add_inner(prefix: String, s: Script) -> void:
	var consts: Dictionary = s.get_script_constant_map()
	for k in consts:
		var v = consts[k]
		if v is GDScript and (v as GDScript).resource_path == "" and not _name_of.has(v):
			_add("%s::%s" % [prefix, k], v)
			_add_inner("%s::%s" % [prefix, k], v)


static func _warn(what: String) -> void:
	if not _warned.has(what):
		_warned[what] = true
		push_warning("Snapshot: nem menthető – %s" % what)


static func _props(o: Object) -> PackedStringArray:
	var out := PackedStringArray()
	for pr in o.get_property_list():
		if int(pr.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(pr.name)
	return out


# ------------------------------------------------------------------ kódolás
static func _enc(v, objs: Array, ids: Dictionary):
	match typeof(v):
		TYPE_ARRAY:
			var out: Array = []
			out.resize(v.size())
			for i in v.size():
				out[i] = _enc(v[i], objs, ids)
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[_enc(k, objs, ids)] = _enc(v[k], objs, ids)
			return d
		TYPE_OBJECT:
			if not is_instance_valid(v):
				return null
			if v is Script:
				if _name_of.has(v):
					return {K_SCRIPT: _name_of[v]}
				var path: String = v.resource_path
				if path.begins_with("res://scripts/"):
					return {K_SCRIPT: path}
				_warn("szkript: %s" % path)
				return null
			var sc = v.get_script()
			if sc == null or not _name_of.has(sc):
				return null    # csomópontok, erőforrások: a jelenet maga építi újra
			var iid: int = v.get_instance_id()
			if ids.has(iid):
				return {K_OBJ: ids[iid]}
			var idx := objs.size()
			ids[iid] = idx
			var rec := {"c": _name_of[sc], "p": {}}
			objs.append(rec)
			var skip: Array = SCENE_SKIP if v is GameScene else []
			for n in _props(v):
				if not skip.has(n):
					rec.p[n] = _enc(v.get(n), objs, ids)
			return {K_OBJ: idx}
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
	return v


static func _dec(v, objs: Array, made: Array):
	match typeof(v):
		TYPE_ARRAY:
			var out: Array = []
			out.resize(v.size())
			for i in v.size():
				out[i] = _dec(v[i], objs, made)
			return out
		TYPE_DICTIONARY:
			if v.size() == 1:
				if v.has(K_OBJ):
					return _obj(int(v[K_OBJ]), objs, made)
				if v.has(K_SCRIPT):
					return _load_script(str(v[K_SCRIPT]))
			var d := {}
			for k in v:
				d[_dec(k, objs, made)] = _dec(v[k], objs, made)
			return d
	return v


static func _load_script(n: String):
	if _script_of.has(n):
		return _script_of[n]
	if n.begins_with("res://scripts/") and n.ends_with(".gd") and not n.contains("..") and ResourceLoader.exists(n):
		return load(n)
	return null


static func _obj(idx: int, objs: Array, made: Array):
	if idx < 0 or idx >= objs.size():
		return null
	if made[idx] != null:
		return made[idx]
	var rec: Dictionary = objs[idx]
	var sc = _script_of.get(str(rec.get("c", "")))
	if sc == null:
		return null
	var o: Object = sc.new()
	made[idx] = o
	var p: Dictionary = rec.get("p", {})
	var known := _props(o)
	for n in p:
		if known.has(n):
			o.set(n, _dec(p[n], objs, made))
	return o


# ------------------------------------------------------------------ mentés / visszatöltés
## A teljes játékállapot + a most induló jelenet, bájtokban.
static func capture(scene: GameScene) -> PackedByteArray:
	_registry()
	var objs: Array = []
	var ids := {}
	var g := {}
	for n in _props(G):
		if not G_SKIP.has(n):
			g[n] = _enc(G.get(n), objs, ids)
	var net := {}
	for n in NET_KEYS:
		net[n] = _enc(Net.get(n), objs, ids)
	var game := {}
	for n in GAME_KEYS:
		game[n] = Game.get(n)
	if scene and not scene._timers.is_empty():
		_warn("a jelenetnek már az indulás előtt van időzítője")
	var snap := {"v": VERSION, "seed": randi(), "time": Main.I.time, "g": g, "net": net, "game": game,
		"scene": _enc(scene, objs, ids), "objs": objs}
	return var_to_bytes(snap)


## Visszatölti az állapotot, és visszaadja az új (még el nem indított) jelenetet.
static func restore(bytes: PackedByteArray) -> GameScene:
	_registry()
	var snap = bytes_to_var(bytes)
	if typeof(snap) != TYPE_DICTIONARY or int(snap.get("v", 0)) != VERSION:
		push_error("Snapshot: ismeretlen formátum")
		return null
	var objs: Array = snap.get("objs", [])
	var made: Array = []
	made.resize(objs.size())
	var g: Dictionary = snap.get("g", {})
	var g_known := _props(G)
	for n in g:
		if g_known.has(n) and not G_SKIP.has(n):
			G.set(n, _dec(g[n], objs, made))
	var net: Dictionary = snap.get("net", {})
	for n in NET_KEYS:
		if net.has(n):
			Net.set(n, _dec(net[n], objs, made))
	var game: Dictionary = snap.get("game", {})
	for n in GAME_KEYS:
		if game.has(n):
			Game.set(n, game[n])
	Main.I.time = float(snap.get("time", 0.0))
	seed(int(snap.get("seed", 0)))
	var sc = _dec(snap.get("scene"), objs, made)
	return sc as GameScene


static func scene_name(scene: GameScene) -> String:
	_registry()
	return str(_name_of.get(scene.get_script(), "?")).get_file() if scene else "-"


## Hibakereséshez: olvasható szöveg a mentésből (két gép állapotának összevetésére).
static func describe(bytes: PackedByteArray) -> String:
	return var_to_str(bytes_to_var(bytes))
