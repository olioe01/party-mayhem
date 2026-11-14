# Party Mayhem

Telefonnal irányított partijáték. Az élő kód a `native/` (Godot 4.4.1, GDScript, Windows exe).
A `public/` + `server.js` a régi böngészős változat: csak kifejezett kérésre nyúlj hozzá, és ne olvasd tájékozódásként.

A felhasználóval magyarul beszélj. Tartalom: csak saját figurák, pályák, zene (műfaji mechanikák igen, más játék másolása nem).

## Takarékos munka (fontos)

- Nagy fájlból ne olvass egészet. Előbb `native/tools/outline.sh <fájl>` (függvények sorszámmal), aztán csak a kellő sortartomány. Nagyok: `world/mountain3d.gd`, `world/chars3d.gd`, `scenes/board_scene.gd` (1000+ sor), `world/board3d.gd`, `scenes/mountain_scene.gd`, `core/sync.gd`.
- Tesztelni a `native/tools/check.sh`-val kell, nem nyers `godot --headless`-szel: a nyers kimenet 1300+ sor ártalmatlan kilépési zaj.
- Ne olvasd: `node_modules/`, `.godot/`, `web.zip`, `package-lock.json`, `*.uid`, `*.import`, `music/*.wav`, `tools/make_music.mjs` (hacsak nem a zene a feladat).
- A játékszabályok és a billentyűk a `native/README.md`-ben vannak; csak akkor olvasd, ha a feladathoz kell.

## Parancsok (a `native/` mappából)

```bash
tools/check.sh                       # 30 mp botos játék, csak hibák + összegzés; kilépési kód 1, ha szkripthiba van
tools/check.sh 60 --mode=mountain --verbose   # hegymászás, [mtn] haladási sorokkal
tools/check.sh 40 --mg=beam          # egy minijáték (id: a mg_<id>.gd meta()-jából)
tools/outline.sh [-v] <fájl...>      # vázlat sorszámokkal (-v: változók is)
tools/build.sh                       # zene -> web.zip -> build/PartyMayhem.exe (+ build_id.txt)
godot --headless --path . --import   # új class_name-es szkript után egyszer kell
```

Kapcsolók a `--` után (`core/game.gd` `apply_args`): `--bots=N --autostart --rounds=N --mode=mountain --mg=<id> --speed=N --small --shots=<mappa> --shot-every= --quit-at=<mp> --start-node=N --tiles=F|P|X --portraits=id,id|all --join=<cím|kód> --room[=KÓD] --relay=<ws-cím> --online-ui --sync-log`.
Ablakos futás (képernyőképhez) WSLg + llvmpipe alatt lassú: `--small --speed=3`, az első táblakörig 150–200 mp.
Egyszerre csak egy godot példány fusson (különben a portok 3000/3001-ről 3010/3011-re lépnek), kivéve a szinkrontesztet.

## Szerkezet (`native/scripts/`)

- `main.gd` – `Main`: jelenetváltás, fix 60 Hz `step`, 2D réteg, részecskék, billentyűk.
- `core/` – autoloadok: `G` (state.gd: játékosok, figurák listája, mód), `Net` (HTTP 3000 + WebSocket 3001, botok), `Audio`, `Game` (kapcsolók, indítás), `Sync` (online lockstep). Továbbá `game_scene.gd` (`GameScene` ősosztály: `after`/`sleep`/`button`), `snapshot.gd`, `online_ui.gd`, `fx.gd`, `draw.gd`, `qr.gd`.
- `scenes/` – `lobby_scene`, `board_scene` (koronavadászat), `mountain_scene` (hegymászás), `mg_flow` (minijáték-keret + a minijátékok preload-listája), `final_scene`.
- `world/` – `board_layout` + `board3d` (szigetek), `mountain_layout` + `mountain3d` (hegy), `chars3d` (figurák, `Chars3D.build(id)`).
- `minigames/` – `minigame.gd` (`Minigame` ős) + 23 db `mg_<id>.gd`.
- `../relay/` – közvetítő szerver az online szobákhoz (Node + `ws`, a Renderen fut). Helyi próba: `PORT=8787 node relay/server.js`, hoszt `--relay=ws://127.0.0.1:8787 --room=TESTA`, vendég `--relay=ws://127.0.0.1:8787 --join=TESTA`.
- `../web/` – a telefonos kontroller (`js/play.js`, `play.css`); a build `web.zip`-be csomagolja.

Új minijáték: `mg_<id>.gd` a `Minigame`-ből + felvétel a `scenes/mg_flow.gd` preload-listájába; ha új vezérlőelrendezés kell, `web/js/play.js`.
Új figura: adat a `core/state.gd` listájába + `_<id>()` építő és `match` ág a `chars3d.gd`-ben + portré (`--portraits=<id>`, ablakkal).
Új jelenetfájl: fel kell venni a `Snapshot.CLASS_FILES`-ba.

## Kötelező szabályok új kódnál

Az online mód determinisztikus lockstep; ezek megszegése szétcsúsztatja a gépeket:

- Játékmenetre ható időzítés csak a jelenet `after()`/`sleep()`-jével vagy `Sync.after()`-rel. Tilos: `create_timer`, valós idő.
- Csak látványt szolgáló véletlen: `FX.f()` / `FX.fr()` / `FX.pick()`. A globális `randf()` a játékmeneté.
- A `draw()` nem módosít állapotot és nem húz véletlent.
- Jelenet konstruktorának minden paramétere alapértékes, tagváltozói sima adatok.
- Ellenőrzés: hoszt `godot --headless --path . -- --bots=4 --autostart --speed=10 --sync-log`, vendég `-- --join=127.0.0.1:3001 --sync-log`; a vendég `EGYEZIK`/`ELTÉR` sort ír jelenetváltásonként.

GDScript-buktatók ebben a projektben:

- `const X := ValamiGlobálisOsztály` nem fordul; helyette `const X = preload("res://...gd")`.
- Típuskövetkeztetési (`:=`) hibák csak futáskor látszanak: módosítás után mindig `tools/check.sh`.
- A `[mtn]` sorok `print_verbose`-ok: a `--verbose` motorkapcsoló kell hozzájuk (a `check.sh` kezeli).

Az új figurák stílusa lapolt low-poly (`lsphere`, `lcyl`, `lcone`, `llathe`, `prism`, `loft`, `band` a `chars3d.gd`-ben): „low poly, de részletes”.

## Git

Ág: `floating-islands-minigames`, origin: GitHub, push SSH-n. Nincs gitben: exe, `.godot`, `web.zip`, `music/*.wav`, `build_id.txt` (a `build.sh` újragyártja). Commit és push csak kérésre.
