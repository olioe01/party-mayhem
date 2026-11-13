extends Node
## A játék állapota és az alapadatok (figurák, saját kockák, tárgyak).

const COLORS := ["#ff4d6d", "#4dabf7", "#51cf66", "#ffd43b", "#b197fc", "#ff922b", "#22d3ee", "#f783ac"]

## Figurák. Mindegyiknek van saját kockája (6 lap). Egy lap: [lépés, érme].
## A sima kocka 1–10; a saját kocka kiszámíthatóbb vagy kockázatosabb, néha érmét is ad.
const CHARS := [
	{"id": "frog", "name": "Béka", "emoji": "🐸", "die": "Ugrókocka", "faces": [[2, 0], [2, 0], [5, 0], [5, 0], [8, 0], [8, 0]], "tip": "2 · 5 · 8 – nagyokat ugrik"},
	{"id": "cat", "name": "Cica", "emoji": "🐱", "die": "Kilenc élet", "faces": [[1, 3], [3, 0], [4, 0], [6, 0], [7, 0], [9, 0]], "tip": "vegyes, az 1-es mellé 3 🪙"},
	{"id": "fox", "name": "Róka", "emoji": "🦊", "die": "Ravasz kocka", "faces": [[0, 5], [0, 5], [6, 0], [7, 0], [8, 0], [9, 0]], "tip": "vagy 5 🪙, vagy 6–9 lépés"},
	{"id": "panda", "name": "Panda", "emoji": "🐼", "die": "Lusta kocka", "faces": [[1, 2], [1, 2], [1, 2], [10, 0], [10, 0], [10, 0]], "tip": "1 lépés + 2 🪙, vagy 10 lépés"},
	{"id": "pig", "name": "Malac", "emoji": "🐷", "die": "Persely", "faces": [[1, 3], [2, 3], [3, 3], [4, 0], [5, 0], [6, 0]], "tip": "kis lépések, sok érme"},
	{"id": "penguin", "name": "Pingvin", "emoji": "🐧", "die": "Csúszka", "faces": [[4, 0], [4, 0], [5, 0], [5, 0], [6, 0], [6, 0]], "tip": "mindig 4–6, biztos"},
	{"id": "duck", "name": "Gumikacsa", "emoji": "🦆", "die": "Hullámkocka", "faces": [[1, 0], [1, 0], [7, 0], [7, 0], [11, 0], [11, 0]], "tip": "1 · 7 · 11 – hullámzó"},
	{"id": "robot", "name": "Robot", "emoji": "🤖", "die": "Precíz kocka", "faces": [[3, 0], [3, 0], [4, 0], [4, 0], [5, 1], [5, 1]], "tip": "3–5, az 5-ös mellé 1 🪙"},
	{"id": "ghost", "name": "Szellem", "emoji": "👻", "die": "Kísértet", "faces": [[0, 0], [0, 0], [0, 0], [12, 0], [12, 0], [12, 0]], "tip": "semmi vagy 12 – 50/50"},
	{"id": "queen", "name": "Királynő", "emoji": "👸", "die": "Királyi kocka", "faces": [[0, -2], [3, 0], [4, 0], [5, 0], [6, 0], [0, 8]], "tip": "3–6, vagy 8 🪙 (vagy −2 🪙)"},
	{"id": "thimble", "name": "Gyűszű", "emoji": "🔘", "die": "Varrókocka", "faces": [[2, 0], [2, 0], [2, 0], [3, 0], [3, 0], [13, 0]], "tip": "2–3, ritkán 13!"},
	{"id": "donut", "name": "Fánk", "emoji": "🍩", "die": "Cukorkocka", "faces": [[1, 2], [2, 2], [5, 0], [5, 0], [5, 0], [8, 0]], "tip": "1–2 + 2 🪙, sok 5-ös"},
	{"id": "knight", "name": "Lovag", "emoji": "⚔️", "die": "Pajzskocka", "faces": [[3, 1], [4, 0], [5, 0], [6, 0], [6, 0], [7, 0]], "tip": "3–7, megbízható"},
	{"id": "king", "name": "Király", "emoji": "🤴", "die": "Kincstárkocka", "faces": [[1, 4], [2, 4], [3, 0], [5, 0], [7, 0], [9, 0]], "tip": "kis dobás mellé 4 🪙"},
	{"id": "tiger", "name": "Tigris", "emoji": "🐯", "die": "Vadászkocka", "faces": [[3, 0], [3, 0], [6, 0], [6, 0], [9, 0], [9, 0]], "tip": "3 · 6 · 9 – nagy ugrások"},
	{"id": "bear", "name": "Medve", "emoji": "🐻", "die": "Mézkocka", "faces": [[2, 2], [2, 2], [4, 1], [6, 0], [8, 0], [8, 0]], "tip": "lassan mézet (🪙) gyűjt, vagy 6–8"},
	{"id": "dwarf", "name": "Törpe", "emoji": "⛏️", "die": "Bányászkocka", "faces": [[1, 6], [2, 3], [3, 0], [4, 0], [5, 0], [6, 0]], "tip": "kis lépések, de aranyat ás"},
	{"id": "ship", "name": "Hajó", "emoji": "⛵", "die": "Vitorlakocka", "faces": [[0, 3], [2, 0], [4, 0], [6, 0], [8, 0], [10, 0]], "tip": "páros lépések, szélcsendben 3 🪙"},
]

const MAX_PLAYERS := 8
const CROWN_PRICE := 20
const MAX_ITEMS := 3
const MAX_ALLIES := 3

const ITEMS := {
	"double": {"icon": "🎲", "name": "Dupla kocka", "price": 5, "desc": "Két kockával dobsz"},
	"triple": {"icon": "🎰", "name": "Tripla kocka", "price": 10, "desc": "Három kockával dobsz"},
	"thief": {"icon": "🧤", "name": "Zsebtolvaj", "price": 12, "desc": "Lopj 5–15 érmét valakitől"},
	"warp": {"icon": "🌀", "name": "Teleport", "price": 8, "desc": "Helyet cserélsz valakivel"},
	"golden": {"icon": "🌟", "name": "Aranycső", "price": 25, "desc": "Egyenesen a korona elé repít"},
}
const SHOP_ITEMS := ["double", "triple", "thief", "warp", "golden"]

const MODES := [
	{"id": "crown", "icon": "👑", "name": "Koronavadászat", "desc": "Gyűjts érmét, vegyél koronát – a legtöbb korona nyer"},
	{"id": "mountain", "icon": "⛰️", "name": "Hegymászás", "desc": "Körbe-körbe fel a hegyre – aki először ér a csúcsra, nyer"},
]

var phase := "lobby"
var mode := "crown"              # "crown" (szigetek, koronák) | "mountain" (hegymászás)
var mountain = null              # MountainLayout szótár (csak hegymászásnál)
var mtn_order: Array = []        # a körön belüli sorrend (az utolsó minijáték helyezései szerint)
var mtn_winner = null
var players: Array = []          # PlayerData
var max_rounds := 10
var round := 1
var vip := ""
var crown_node := -1
var recent_mg: Array = []
var board = null                 # BoardLayout.Board
var hidden_blocks := {}          # node id -> "coins"|"crown"|"item"
var team_split: Array = []       # [[pid..],[pid..]] csapatos minijátékhoz, ha van
var portraits := {}              # char id -> Texture2D


class PlayerData:
	extends RefCounted
	var pid := ""
	var name := ""
	var is_bot := false
	var connected := true
	var ready := false
	var color := Color.WHITE
	var color_hex := "#ffffff"
	var char_id := "frog"
	var coins := 10
	var crowns := 0
	var node := 0
	var items: Array = []
	var allies: Array = []        # char id-k
	var disp_coins := 10.0
	var last_space := ""          # "B" / "R" / ... az utolsó mező, amire lépett (csapatbeosztáshoz)
	var stats := {}
	var dice: Array = [6]         # hegymászás: a következő dobás kockái (oldalszámok), pl. [6, 4]
	var frozen := false           # hegymászás: kimarad a következő dobásból
	var mg_place := 0             # hegymászás: az utolsó minijáték helyezése (0 = első)

	func reset() -> void:
		dice = [6]
		frozen = false
		mg_place = 0
		coins = 10
		crowns = 0
		items = []
		allies = []
		disp_coins = 10.0
		last_space = ""
		stats = {"mg_coins": 0, "steps": 0, "max_coins": 10, "mg_wins": 0, "red": 0, "events": 0, "spent": 0, "allies": 0, "blue": 0}


func _ready() -> void:
	Net.status_provider = status_of


func char_by_id(id: String) -> Dictionary:
	for c in CHARS:
		if c.id == id:
			return c
	return CHARS[0]


func portrait(id: String) -> Texture2D:
	if portraits.has(id):
		return portraits[id]
	var img := Image.new()
	var data := Net.read_web_file("img/chars/%s.png" % id)
	var tex: Texture2D = null
	if data.size() and img.load_png_from_buffer(data) == OK:
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	portraits[id] = tex
	return tex


func by_pid(pid: String) -> PlayerData:
	for p in players:
		if p.pid == pid:
			return p
	return null


func humans() -> Array:
	return players.filter(func(p): return not p.is_bot)


func new_player(pid: String, pname: String, bot: bool) -> PlayerData:
	var used_c := {}
	var used_ch := {}
	for q in players:
		used_c[q.color_hex] = true
		used_ch[q.char_id] = true
	var p := PlayerData.new()
	p.pid = pid
	p.name = pname
	p.is_bot = bot
	p.ready = bot
	p.color_hex = COLORS[0]
	for c in COLORS:
		if not used_c.has(c):
			p.color_hex = c
			break
	p.color = Color(p.color_hex)
	var free_chars := CHARS.filter(func(c): return not used_ch.has(c.id))
	p.char_id = (free_chars.pick_random() if bot and free_chars.size() else (free_chars[0] if free_chars.size() else CHARS[0])).id
	p.reset()
	return p


func status_of(pid: String):
	var p := by_pid(pid)
	if p == null:
		return null
	var icons: Array = []
	for k in p.items:
		icons.append(ITEMS[k].icon)
	for a in p.allies:
		icons.append(char_by_id(a).emoji)
	var d := {"name": p.name, "color": p.color_hex, "char": p.char_id, "coins": p.coins, "crowns": p.crowns,
		"items": icons, "playing": phase != "lobby"}
	if mode == "mountain" and mountain != null:
		d["stats"] = "⛰️ %d/%d   %s" % [p.node, mountain.goal, dice_text(p.dice)]
	return d


func is_mountain() -> bool:
	return mode == "mountain"


func mode_info() -> Dictionary:
	for m in MODES:
		if m.id == mode:
			return m
	return MODES[0]


## pl. [6, 4] -> "🎲6 + 🎲4"
func dice_text(dice: Array) -> String:
	var parts := PackedStringArray()
	for s in dice:
		parts.append("🎲%d" % int(s))
	return " + ".join(parts)


## Hegymászás: a minijáték helyezése alapján járó kockák.
## 1.: két szabályos · 2.: szabályos + 1–4 · 3.: szabályos + 1–2 · utolsó (4+ játékosnál): egy szabályos.
func dice_for_place(place: int, last_place: int, n_players: int) -> Array:
	if place <= 0: return [6, 6]
	if place == 1: return [6, 4]
	if place == 2: return [6, 2]
	if n_players >= 4 and place >= last_place: return [6]
	return [6, 2]


func add_coins(p: PlayerData, n: int) -> int:
	var before := p.coins
	p.coins = max(0, p.coins + n)
	p.stats.max_coins = max(p.stats.max_coins, p.coins)
	Net.push_status(p.pid)
	return p.coins - before


func standings() -> Array:
	var s := players.duplicate()
	if is_mountain():
		s.sort_custom(func(a, b): return a.node > b.node or (a.node == b.node and a.stats.mg_wins > b.stats.mg_wins))
		if mtn_winner and s.has(mtn_winner):
			s.erase(mtn_winner)
			s.push_front(mtn_winner)
		return s
	s.sort_custom(func(a, b): return a.crowns > b.crowns or (a.crowns == b.crowns and a.coins > b.coins))
	return s


func place_of(p: PlayerData) -> int:
	var s := standings()
	if is_mountain():
		if p == mtn_winner:
			return 1
		for i in s.size():
			if s[i].node == p.node and s[i] != mtn_winner:
				return i + 1
		return s.size()
	for i in s.size():
		if s[i].crowns == p.crowns and s[i].coins == p.coins:
			return i + 1
	return s.size()


func is_last_rounds() -> bool:
	return max_rounds >= 5 and round > max_rounds - 3
