class_name HighwayLayout
extends RefCounted
## Óceánsztráda – a pálya és a szabályok számai egy helyen (minden itt állítható).
## Egyenes, az óceán fölött húzódó sztráda, 0 = rajt, GOAL = célkapu. A haladást a mező
## sorszáma adja; a sávok (oldalirányú eltolás) csak arra valók, hogy a figurák ne takarják egymást.

const GOAL := 351
const CP_BRIDGE := 100           # 1. ellenőrzőpont: felvonóhíd – egy kockával páratlan kell
const CP_LIGHTS := 200           # 2. ellenőrzőpont: jelzőlámpás kapu – 5 piros-zöld kockából legalább egy zöld
const LIGHT_DICE := 5
const LIGHT_GREEN_FACES := 2     # a lámpakocka 6 lapjából ennyi zöld
const ROCKET_TO := 190           # a rakéta idáig repít (visszafelé soha)
const FINAL_DICE := 10
const FINAL_NEED := [40, 35]     # első próbálkozás, utána minden további
const FINAL_FAIL_BACK := 15
const MATCH_BONUS := 5           # ha minden kocka ugyanazt mutatja: ennyi plusz kocka
const DUEL_SOLO_DICE := 5        # „1 a többiek ellen”: ha az egyedül játszó nyer
const DUEL_TEAM_DICE := 2        # … ha a többiek nyernek, fejenként
const LAST_BOOST := [10, 20, 30, -1]   # felzárkózó mező kimenetei (-1: UFO az élen állóhoz)
const SP := 1.5                  # két mező távolsága (világegység)
const LANE := 0.86               # két sáv távolsága
const LANES := 8
const ROAD_W := 8.4
const RUN_SPEED := 8.0           # mező / mp futás közben

## Kockajutalom a minijáték helyezése szerint, a résztvevők számától függően.
const REWARDS := {
	1: [10],
	2: [10, 2],
	3: [10, 6, 2],
	4: [10, 7, 4, 2],
	5: [10, 8, 6, 4, 2],
	6: [10, 9, 7, 6, 4, 2],
	7: [10, 9, 8, 7, 5, 4, 2],
	8: [10, 9, 8, 7, 6, 5, 4, 2],
}

## Dobás-értékelés a kockák számához igazítva: jó, ha összeg >= kocka × GOOD_K, gyenge, ha < kocka × BAD_K.
## (10 kockánál: 40 felett jó, 29 alatt gyenge; 2 kockánál: 8 felett jó, 5 alatt gyenge.)
const GOOD_K := 4.0
const BAD_K := 3.0

## Különleges mezők. Típusok: F (előre), B (hátra), BD (kék kockamező: előre a dobott összeggel),
## RD (piros kockamező: hátra), LAST (felzárkózó), UFO, ROCKET, DUEL (1 a többiek ellen).
const SPECIALS := {
	6: ["BD", 5], 11: ["F", 10], 17: ["RD", 5], 23: ["DUEL", 0], 29: ["B", 10], 34: ["LAST", 0],
	41: ["BD", 10], 47: ["UFO", 0], 53: ["F", 20], 58: ["RD", 10], 64: ["B", 10], 70: ["BD", 5],
	76: ["LAST", 0], 82: ["DUEL", 0], 88: ["F", 10], 93: ["B", 20],
	106: ["BD", 5], 112: ["UFO", 0], 118: ["F", 10], 124: ["RD", 5], 130: ["LAST", 0], 136: ["DUEL", 0],
	141: ["ROCKET", 0], 147: ["B", 10], 153: ["BD", 10], 159: ["F", 20], 165: ["RD", 10], 171: ["UFO", 0],
	177: ["B", 20], 183: ["LAST", 0], 188: ["BD", 5], 194: ["F", 10],
	207: ["RD", 5], 213: ["DUEL", 0], 219: ["F", 20], 225: ["B", 10], 231: ["BD", 10], 237: ["UFO", 0],
	243: ["LAST", 0], 249: ["RD", 10], 255: ["F", 10], 262: ["B", 20], 268: ["BD", 5], 274: ["DUEL", 0],
	280: ["UFO", 0], 286: ["F", 20], 292: ["RD", 5], 298: ["LAST", 0], 305: ["BD", 10], 311: ["B", 10],
	317: ["F", 10], 323: ["RD", 10], 329: ["UFO", 0], 335: ["B", 20], 341: ["BD", 5], 346: ["B", 10],
}

const INFO := {
	"F": {"col": "#2fb344", "icon": "⏩", "name": "Hátszél"},
	"B": {"col": "#e8590c", "icon": "⏪", "name": "Szembeszél"},
	"BD": {"col": "#1c7ed6", "icon": "🎲", "name": "Kék kockamező"},
	"RD": {"col": "#e03131", "icon": "🎲", "name": "Piros kockamező"},
	"LAST": {"col": "#f08c00", "icon": "🆙", "name": "Felzárkózó"},
	"UFO": {"col": "#7048e8", "icon": "🛸", "name": "UFO"},
	"ROCKET": {"col": "#c2255c", "icon": "🚀", "name": "Rakéta"},
	"DUEL": {"col": "#0ca678", "icon": "⚔️", "name": "1 a többiek ellen"},
}


static func special(s: int) -> Array:
	return SPECIALS.get(s, [])


static func rewards(n: int) -> Array:
	return REWARDS.get(clampi(n, 1, 8), REWARDS[8])


## Ennyi kocka jár a place. helyért (0 = első) n résztvevő mellett.
static func dice_for(place: int, n: int) -> int:
	var r := rewards(n)
	return int(r[clampi(place, 0, r.size() - 1)])


## "good" / "ok" / "bad"
static func grade(total: int, count: int) -> String:
	if total >= ceili(count * GOOD_K):
		return "good"
	if total < floori(count * BAD_K):
		return "bad"
	return "ok"


## A mező világbeli helye (a sáv közepén); s lehet tört is (futás közben).
static func pos(s: float, lane := -1.0) -> Vector3:
	var x := 0.0 if lane < 0.0 else (lane - (LANES - 1) / 2.0) * LANE
	return Vector3(x, 0.0, -s * SP)


## Az út menti „s” egy világpontból (csak z alapján).
static func s_of(p: Vector3) -> float:
	return -p.z / SP


## A következő még le nem győzött ellenőrzőpont a from után (cp = hány pontot győzött le eddig).
static func next_cp(cp: int) -> int:
	if cp <= 0:
		return CP_BRIDGE
	if cp == 1:
		return CP_LIGHTS
	return GOAL
