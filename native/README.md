# 🎉 Party Mayhem – natív (Windows .exe) változat

Ez a Party Mayhem önálló, telepítés nélkül futtatható változata, Godot 4.4 motorra átírva. **Nem kell hozzá se Node.js, se böngésző**: elindítod a `PartyMayhem.exe`-t, és a telefonok ugyanúgy QR-kóddal csatlakoznak, mint eddig. A játék beépített webszervert futtat a telefonos kontrollerhez.

## Indítás

1. Indítsd el a `PartyMayhem.exe`-t. Az első indításkor a Windows tűzfal megkérdezi, hogy engedélyezed-e a hálózati hozzáférést: pipáld be a **Magánhálózatok** opciót, és kattints az **Engedélyezés** gombra.
2. A lobbyban olvassák be a telefonok a QR-kódot. A telefonoknak és a gépnek **ugyanazon a Wi-Fi hálózaton** kell lenniük.
3. Az első csatlakozó játékos a ⭐ VIP: ő választja ki a körök számát, és ő indítja a játékot. A gépen az `ENTER` is indít.

| Billentyű | Funkció |
|---|---|
| `F` / `F11` | teljes képernyő |
| `M` | hang ki/be |
| `B` | bot hozzáadása (lobby) |
| `J` | játékmód váltása (lobby) |
| `←` `→` | körök száma (lobby) |
| `ENTER` | indítás / tovább |
| `P` | FPS kijelzés |
| `F12` | képernyőkép (a Godot felhasználói mappájába) |
| `Esc` kétszer | kilépés |

Ha a QR-kód rossz címet mutat (például több hálózati kártya miatt), indítsd így: `set PUBLIC_HOST=192.168.1.23 && PartyMayhem.exe`, ahol az IP-cím a gép Wi-Fi címe (`ipconfig`). Alapból a 3000-es (telefonos oldal) és a 3001-es (WebSocket) portot használja; ha ezek foglaltak, a következő szabadra lép (3010/3011, …).

## Két nagy játékmód

A lobbyban a gépen (a jobb felső gombokkal vagy a `J` billentyűvel) vagy a ⭐ VIP telefonján lehet választani.

**👑 Koronavadászat** – az eredeti mód: lebegő szigetek, érmék, bolt, koronák, a megadott számú kör végén a legtöbb korona nyer. A részletek lejjebb.

**⛰️ Hegymászás** – egyetlen út csavarodik körbe-körbe egy hegyen, 80 mező a csúcsig. Aki először felér, az nyer; nincs körszám, érme vagy korona.
- Minden kör egy minijátékkal kezdődik, és a helyezés osztja ki a kockákat a következő dobáshoz: **1. hely** két szabályos kocka (1–6) · **2. hely** egy szabályos és egy 1–4-es · **3. hely** egy szabályos és egy 1–2-es · **utolsó hely** egyetlen szabályos kocka. (Az „utolsó csak egy kockát kap” szabály 4 vagy több játékosnál él; 5–8 játékosnál a 4. és az utolsó közöttiek a 3. hely kockáit kapják. Holtversenyben mindenki a jobb helyezés kockáit kapja.)
- A dobás sorrendje is a minijáték helyezése: a győztes lép először.
- Ebben a módban nincsenek saját figurakockák, és a minijátékok mindig egyéniek (nincs csapat).
- 🟥 **Büntetőmezők:** vissza 2–6 mezőt (lent medve, középen kőomlás, fent lavina – a hegy felfelé egyre keményebb).
- ❄️ **Jégmező:** kimaradsz a következő dobásodból. 🟩 **Hátszél:** előre 2–3 mezőt.
- 🚧 **3 kapu** (5+, 6+, 8+): a kapu mezőjén mindenkinek meg kell állnia, és addig senki nem mehet tovább, amíg valaki a kapu mezőjén állva legalább a ráírt számot nem dobja. Utána a kapu mindenkinek nyitva marad.
- A különleges mezők és a kapuk pontos helye játékonként kicsit más.

## Mi van benne (Koronavadászat)

**Tábla:** 7 lebegő sziget (Rét, Erdő, Kastély, Vulkán, Sivatag, Kristály, Öböl), hidak, két elágazás és ugrópadok, 3D-ben, animált felhőtengerrel. Az utolsó 3 körben naplementébe vált a fény, és duplán számítanak a mezők.

**A műfaj klasszikus elemei, saját kivitelben:**
- 🎲 **Saját kocka minden figurának.** Dobás előtt választhatsz a sima 1–10-es kocka és a figurád saját, 6 lapos kockája között. A Pingvin mindig 4–6-ot dob, a Szellem vagy semmit, vagy 12-t, a Malac kicsiket lép, de érmét is kap, és így tovább.
- 🙋 **Kockaütés:** a figurád felugrik, és megüti a feje fölött pörgő 3D kockát.
- 🏁 **Kezdő sorrend-dobás:** mindenki egyszerre dob, és a legnagyobb szám kezd.
- 🤝 **Barátok (szövetségesek):** a rózsaszín 🤝 mezőn egy szabad figura csatlakozik hozzád, és libasorban követ. Minden barát minden dobásodhoz +1–2 lépést ad (legfeljebb 3 barátod lehet).
- ❗ **Sziget-események (zöld mezők):** szigetenként más történik. A Réten a kút megajándékoz, az Erdőben a szél elfújja a koronát, a Kastély ágyúja elröpít, a Vulkán kitör, a Sivatagban homokvihar keveri a játékosokat, a Kristály újradobást ad, az Öbölben kincsesláda vár.
- ❓ **Rejtett dobozok:** láthatatlan dobozok néhány mező fölött. Ha pont ott állsz meg, érme, tárgy vagy ritkán egy egész korona esik ki belőlük.
- 🎡 **Utolsó 3 kör:** a lemaradó játékos szerencsekereket pörget (érmék, Aranycső, barát, tripla kocka).
- 👑 **Korona:** 20 érméért veheted meg, ha rálépsz vagy átmész rajta.
- 🛒 **Bolt:** dupla és tripla kocka, zsebtolvaj, teleport, és az új 🌟 **Aranycső**, amely egyenesen a korona elé visz.
- 🔵🔴 **Csapatos minijátékok:** 4 játékosnál az utolsó mező színe dönti el a csapatokat. Kék mező esetén a kék csapatba, piros mező esetén a piros csapatba kerülsz, az eseménymezők véletlenszerűen osztanak. Így 2 a 2 vagy 1 a 3 ellen is lehet játék.
- 🏆 **Végén 3 bónusz korona** 7 lehetséges közül (minijáték-mester, vándor, krőzus, pechmadár, kalandor, vásárkirály, barátságos), majd 3D dobogó.

**23 minijáték:**

| | Név | Irányítás | Megjelenés |
|---|---|---|---|
| 🚀 | Rakétaverseny | gyors koppintás | 3D |
| 💥 | Lökdösődő aréna | joystick + lökés | 3D, láva |
| 🪙 | Érmeeső | ◀ ▶ | 3D |
| 🪵 | Forgó gerenda *(új)* | ugrás időzítve | 3D |
| 🦉 | Szoborjáték *(új)* | koppintás, megállás, ha a bagoly néz | 3D |
| 🪢 | Kötélhúzás *(új, csak csapatban)* | gyors koppintás | 3D |
| 🎈 | Lufivadászat *(új)* | joystick – kiskocsival a lufikba; arany lufi 3 pont, félidőtől bombagömb | 3D |
| 🏀 | Kosárdobás *(új)* | koppintás, amikor a csúszka jelölője a zöld zónában van | 3D |
| 🐑 | Birkaterelő *(új)* | joystick – séta a kamera felé, a bárányokat kerülgetve | 3D |
| 🥤 | Pohárkeverő *(új)* | kövesd a labdát, aztán válaszd ki a poharat | 3D |
| 💣 | Forró bomba *(új)* | joystick – célzás, gomb – dobás; akinél felrobban, kiesik | 3D |
| 🎨 | Festékcsata *(új)* | joystick – amerre jársz, a te színedre vált a padló; vödör = nagy folt | 3D |
| 🧊 | Olvadó jégtábla *(új)* | joystick – a csempe leszakad alattad, eleinte visszafagy | 3D |
| 🏗️ | Toronyépítő *(új)* | koppintás – ejtsd a lengő blokkot pontosan a toronyra | 3D |
| 🎣 | Horgászverseny *(új)* | koppintás, amikor lemerül az úszó; kis hal 1, nagy hal 3, bakancs −1 | 3D |
| 🔦 | Zseblámpás bújócska *(új, 1 a 3 ellen vagy sorsolt keresővel)* | joystick – a kereső fénykúpja elől a ládák mögé kell bújni | 3D, sötét |
| 🥁 | Ritmusdob *(új)* | 4 színes gomb ütemre, gyorsuló tempó | 2D |
| ⚡ | Villámreflex | egy gomb | 2D |
| 🧠 | Színmemória | 4 színes gomb | 2D |
| 🔢 | Számold meg! | számbillentyűzet | 2D |
| ⏱️ | Vak időzítő | egy gomb | 2D |
| 🧮 | Fejszámolás | számbillentyűzet | 2D |
| 🎯 | Célzó | egy gomb | 2D |

**Zene:** 6 saját szerzemény (lobby, tábla, feszült utolsó körök, minijáték, sorsolás, díjátadó) és 4 rövid betét (kezdés, korona, barát, győzelem). A `tools/make_music.mjs` saját szintetizátora rendereli őket, külső hangminta nélkül.

## Fejlesztés

Szükséges: Godot 4.4.1, Node.js (csak a zene rendereléséhez), Python 3.

```bash
cd native
node tools/make_music.mjs        # music/*.wav (egyszer kell, ~20 mp)
python3 tools/pack_web.py        # web/ -> web.zip (a telefonos kontroller az exe-be)
godot --path .                   # futtatás a szerkesztőből / parancssorból
godot --headless --path . --export-release "Windows Desktop" build/PartyMayhem.exe
```

Az exe-exporthoz kell a Windows export sablon (`~/.local/share/godot/export_templates/4.4.1.stable/windows_release_x86_64.exe`). A szerkesztőben: *Editor → Manage Export Templates*.

Tesztelési kapcsolók (a `--` után): `--bots=4`, `--autostart`, `--rounds=2`, `--mode=mountain` (hegymászás), `--mg=beam` (adott minijáték), `--speed=2`, `--small` (kis ablak), `--shots=mappa` (automatikus képernyőképek), `--quit-at=60`.

```
native/
  main.tscn, scripts/main.gd     jelenetváltás, 2D réteg, részecskék, billentyűk
  scripts/core/                  net (web- és WebSocket-szerver, botok), state, game, audio, qr, draw
  scripts/world/                 board_layout (pálya), board3d (3D tábla, kamera), chars3d (12 figura),
                                 mountain_layout + mountain3d (a hegymászás pályája és 3D hegye)
  scripts/scenes/                lobby, board (táblamenet), mountain (hegymászás), mg_flow (minijáték-keret), final
  scripts/minigames/             a 23 minijáték
  web/                           telefonos kontroller (HTML/JS/CSS + portrék), becsomagolva: web.zip
  music/, tools/                 zenék és a generátoruk
```

A fontok (Fredoka, Noto Color Emoji) SIL Open Font License alatt állnak, a licencek a `fonts/` mappában vannak. A figurák, a pálya, a minijátékok és a zene saját munka.
