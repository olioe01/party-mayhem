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
| `T` | minijáték teszt: a minijátékok tét nélkül kipróbálhatók (lobby) |
| `←` `→` | körök száma (lobby) |
| `ENTER` | indítás / tovább |
| `O` | online játék (szoba nyitása / csatlakozás) |
| `P` | FPS kijelzés |
| `F12` | képernyőkép (a Godot felhasználói mappájába) |
| `Esc` kétszer | kilépés |

Ha a QR-kód rossz címet mutat (például több hálózati kártya miatt), indítsd így: `set PUBLIC_HOST=192.168.1.23 && PartyMayhem.exe`, ahol az IP-cím a gép Wi-Fi címe (`ipconfig`). Alapból a 3000-es (telefonos oldal) és a 3001-es (WebSocket) portot használja; ha ezek foglaltak, a következő szabadra lép (3010/3011, …).

## 🌐 Online játék – mindenki a saját gépén

Ha a barátaidnak is megvan a `PartyMayhem.exe`, nem kell képernyőt megosztani: mindenki a saját gépén futtatja és látja a játékot, a gépek között csak a gombnyomások utaznak, ezért nincs videókésés.

1. **A szoba gazdája** a lobbyban megnyomja a **🌐 Online játék** gombot (vagy az `O` billentyűt), majd a **Szoba megnyitása az interneten** gombot. A játék kapcsolódik a közvetítő szerverhez, és kiír egy rövid **szobakódot** (pl. `KX7PM`). A routeren semmit nem kell állítani, és VPN sem kell.
2. **A többiek** ugyanitt beírják a kódot a jobb oldali mezőbe, és **Csatlakozás**. Pár másodperc múlva ugyanazt a lobbyt látják.
3. **A telefonját mindenki a saját képernyőjén lévő QR-kóddal** csatlakoztatja (a saját Wi-Fi-jén). A játékot bármelyik gépről el lehet indítani (ENTER vagy az INDÍTÁS gomb), illetve a ⭐ VIP telefonjáról.

Tudnivalók:
- Menet közben is be lehet szállni, illetve vissza lehet jönni: a játék pár másodperc alatt felzárkózik. Aki játék közben érkezik új telefonnal, az a következő játékban kap helyet.
- Ha megszakad a kapcsolat, a vendég gép magától újrapróbálkozik; ha nem sikerül, visszakerül a saját lobbyjába. A lecsatlakozott gép játékosai helyett addig a bot játszik.
- Mindenkinek **ugyanaz a játékverzió** kell (eltérő verziónál a csatlakozás hibaüzenettel elutasítja).
- **Az este első szobanyitása akár egy percig is tarthat:** az ingyenes közvetítő szerver használaton kívül elalszik, és ennyi idő, amíg felébred. Játék közben nem alszik el.
- A közvetítő szerver kódja a `../relay/` mappában van (Node, a Renderen fut); a játékba épített címe a `core/sync.gd` `RELAY_DEFAULT` állandója.
- **Egy hálózaton belül vagy VPN-nel** (Radmin VPN, Tailscale, Hamachi) szerver nélkül is megy: a kód helyett a gazda gépének IP-címét kell beírni. Ilyenkor a Windows tűzfal kérdésénél a gazdának engedélyeznie kell a játékot.
- Parancssorból: `PartyMayhem.exe -- --join=KX7PM` (vagy `--join=192.168.1.23`) azonnal csatlakozik, a `-- --room` indításkor megnyitja a szobát. Teszthez `--relay=ws://127.0.0.1:8787` (a `--room` / `--join` elé írva) másik közvetítő szervert ad meg.

## Három nagy játékmód

A lobbyban a gépen (a jobb felső gombokkal vagy a `J` billentyűvel) vagy a ⭐ VIP telefonján lehet választani.

**👑 Koronavadászat** – az eredeti mód: lebegő szigetek, érmék, bolt, koronák, a megadott számú kör végén a legtöbb korona nyer. A részletek lejjebb.

**⛰️ Hegymászás** – egyetlen út csavarodik körbe-körbe egy hegyen, 80 mező a csúcsig. Aki először felér, az nyer; nincs körszám, érme vagy korona.
- Minden kör egy minijátékkal kezdődik, és a helyezés osztja ki a kockákat a következő dobáshoz: **1. hely** két szabályos kocka (1–6) · **2. hely** egy szabályos és egy 1–4-es · **3. hely** egy szabályos és egy 1–2-es · **utolsó hely** egyetlen szabályos kocka. (Az „utolsó csak egy kockát kap” szabály 4 vagy több játékosnál él; 5–8 játékosnál a 4. és az utolsó közöttiek a 3. hely kockáit kapják. Holtversenyben mindenki a jobb helyezés kockáit kapja.)
- 🎲 **Egyforma kockák:** ha legalább két kockával dobsz, és mind ugyanazt mutatja, még egy szabályos kockával dobhatsz.
- A dobás sorrendje is a minijáték helyezése: a győztes lép először.
- Ebben a módban nincsenek saját figurakockák, és a minijátékok mindig egyéniek (nincs csapat).
- 🟥 **Büntetőmezők:** vissza 2–6 mezőt (lent medve, középen kőomlás, fent lavina – a hegy felfelé egyre keményebb).
- ❄️ **Jégmező:** kimaradsz a következő dobásodból. 🟩 **Hátszél:** előre 2–3 mezőt.
- 🚧 **3 akadály**: téglafal (be kell ütni), bástya (az ágyúval kell szétlőni) és egy alvó jeti (hógolyóval kell felébreszteni). Mindegyiknél külön akadály-kockával dobsz, és 4, 5 vagy 6 kell. Aki lépés közben ér oda, azonnal dobhat, és ha sikerül, a maradék lépéseivel megy is tovább; aki nem dobja meg, a következő körében újra próbálkozhat. A legyőzött akadály mindenkinek szabad utat ad.
- A piros mezőkön tényleg megkerget a medve (feljebb kőomlás, majd lavina sodor vissza), a zöldeken a hátszél tol előre.
- A különleges mezők és az akadályok pontos helye játékonként kicsit más.

**🛣️ Óceánsztráda** – egy hosszú, kanyargós sztráda pilléreken az óceán fölött, 351 mező a célkapuig, 1–8 játékos. Nincs körszám: aki elsőként átjut a célkapun, az nyer.
- Az út balra-jobbra kígyózik: S-kanyarok, két széles U-forduló, köztük egyenesek; a kamera a kanyarokkal együtt fordul, és előre néz. A vonalvezetést a `world/highway_layout.gd` `CURVE_KEYS` listája adja (mező + irány); a híd, a lámpás kapu és a cél mindig egyenes szakaszra esik.
- A mezők kb. fele (181) különleges, a `SPECIAL_RUNS` listában állítható: hat egymást követő +10-es és hat −10-es mezőből álló csoportok (6–6 db, a csoport mentén a korlát is zölden/pirosan világít), sok ±20, kék és piros kockamező, 16 felzárkózó, 14 UFO, 5 rakéta. A pálya vége felé egyre sűrűbb és kaotikusabb.
- Egy lépésre legfeljebb egy mezőhatás jut: ha a hátszél, a kockamező vagy az UFO újabb különleges mezőre visz, az már nem lép működésbe (nincs végtelen lánc).
- Minden kör minijátékkal kezdődik; a helyezés adja a sorrendet és azt, hány hatoldalú kockával dobsz (holtversenyt kockadobás dönt el). 4 főnél 10 / 7 / 4 / 2 kocka, 8 főnél 10 / 9 / 8 / 7 / 6 / 5 / 4 / 2; a többi létszám táblája a `world/highway_layout.gd`-ben állítható.
- A dobott összeggel a figura végigfut a sztrádán. Ha minden kocka ugyanazt mutatja (bármennyi kockával dobsz): +5 bónuszkocka (aranyszínű összeg). A dobást a játék értékeli is (jó: arany szám, ökölrázás, ujjongó nézők; gyenge: billegő szám, csípőre tett kéz).
- Különleges mezők: ⏩ hátszél (+10/+20), ⏪ szembeszél (−10/−20), kék kockamező (5 vagy 10 kocka előre, itt is jár az egyforma-bónusz), piros kockamező (5 vagy 10 kocka vissza), 🆙 felzárkózó (csak a sereghajtónak: +10/+20/+30 vagy UFO a vezetőhöz), 🛸 UFO (elvisz egy véletlen másik játékos mellé), 🚀 rakéta (a 190. mezőig), ⚔️ 1 a többiek ellen (a kör végén csapatos párbaj-minijáték: ha az egyedül játszó nyer, 5 bónuszkocka, ha a többiek, fejenként 2; egy játékosnál helyette egyszemélyes kihívás).
- 🌉 **100: felvonóhíd** – egy kockával páratlan kell. 🚦 **200: jelzőlámpás kapu** – 5 lámpakockából legalább egy zöld kell; ezután minden kör előtt az utolsó helyezett választ minijátékot három közül. Ha nem sikerül: egy mezőt vissza, és a következő körben újra.
- 🏁 **351: célkapu** – 10 kockával legalább 40 kell (bukás után már 35 is elég); ha nem sikerül, 15 mezőt vissza.
- Nézőcsoportok szurkolnak vagy csóválják a fejüket, delfinek ugrálnak, az UFO és a rakéta saját animációval visz.

## Mi van benne (Koronavadászat)

**Tábla:** 7 lebegő sziget (Rét, Erdő, Kastély, Vulkán, Sivatag, Kristály, Öböl), hidak, két elágazás és ugrópadok, 3D-ben, animált felhőtengerrel. Az utolsó 3 körben naplementébe vált a fény, és duplán számítanak a mezők.

**A műfaj klasszikus elemei, saját kivitelben:**
- 🎲 **Saját kocka minden figurának.** Dobás előtt választhatsz a sima 1–10-es kocka és a figurád saját, 6 lapos kockája között. A Pingvin mindig 4–6-ot dob, a Szellem vagy semmit, vagy 12-t, a Malac kicsiket lép, de érmét is kap, és így tovább.
- ✨ **Egyforma kockák:** ha több kockával dobsz (dupla/tripla kocka), és mind ugyanazt mutatja, még egy sima kockával dobhatsz.
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

**33 minijáték** (válogatás):

Minden minijátékban pontosan annyian vesznek részt, ahány játékos a játékban van (1–8 fő, minden minijáték 8 főig játszható); a minijátékok soha nem töltik fel magukat gépi ellenféllel. Ha egy minijátékhoz kevesen vagytok (a Rönklépcsőhöz legalább 3 fő kell), az egyszerűen nem kerül sorra. A lobbiban a játék elején a „+ Bot” gombbal (vagy a `B` billentyűvel) lehet botot adni – ő rendes játékosként vesz részt. A közös eredményképernyőn bal oldalt a lista, jobb oldalt 3D-s talapzatokon a figurák: a győztes ugrál és a magasba emeli a karját, az utolsó lehajtott fejjel szomorkodik.

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
| 🎁 | Ajándéktorony *(új)* | ◀ ▶ – billegő ajándéktornyot egyensúlyozol: szél, remegés, félidőben plusz doboz, teherautó takarja a képet; a gépen A/D vagy ←/→ az első játékost irányítja | 3D |
| 🃏 | Kártyafogó *(új, 8 főig: soronként annyi lap, ahány játékos)* | 1–4 gomb – minden sorban mindenkinek egy lapja van; a menetedben előbb az 1. sorban keresed a sajátodat, ha megvan, jöhet a 2., aztán a 3.; ha mellényúlsz, minden lapod visszafordul és legközelebb elölről kezded; aki elsőként megtalálja mind a hármat, nyer (figyeld, mit fordítanak a többiek!) | 3D |
| 🎆 | Tűzijáték-pumpa *(új, 8 főig)* | gyors koppintás 10 mp-ig – a töltés dönti el, milyen magasra száll a rakéta (±2,5% szerencse); a kamera követi az égbe | 3D, éjszakai tér |
| 🚃 | Sínharc *(új, 8 főig)* | joystick – irány a kereszteződésben, hátrahúzva fordulás; TŰZ – lövés; csak a hátsó céltábla sebez, 3 életerő, 60 mp | 3D, várudvar |
| 🌩️ | Viharpadló *(megújult)* | joystick (gépen WASD/nyilak) – a magasban lebegő platform bal fele PIROS, jobb fele KÉK; 5 mp alatt állj arra, amelyik szerinted megmarad; az egyik fele (fele-fele eséllyel) csapóajtóként lenyílik, aki rajta áll, lezuhan és ⚡ villámot kap; 3 kör, a legkevesebb villám nyer, holtversenyben azonos helyezés | 3D, óceán fölött, erősödő vihar |
| 🔨 | Vakondvadász *(megújult, max. 8 fő)* | joystick + ÜTÉS (gépen WASD/nyilak + szóköz) – fuss a 3×3 lyukból kibújó vakondhoz és csapj le az óriási játékkalapáccsal: barna +1, arany +3; a kalapács a többieket is elkábítja; 30 mp, a végére egyre több vakond | 3D |
| 🪵 | Rönklépcső *(új, csak 3–8 fő)* | kerek számgombok (gépen A/D, ←/→) – mindenki titokban választ, hány fokot lép; a 10 mp-es visszaszámlálás végéig átválthat, aki nem választ, a legkisebbet kapja; ha más is ugyanazt választotta, mind helyben maradnak; az nyer, aki elsőként felér a célkapuig. 3–4 fő: 1/3/5 lépés, 16 fok · 5–6 fő: 1/3/5/7, 18 fok · 7–8 fő: 1/2/3/5/6/7, 20 fok | 3D |
| 🧟 | Zombifogó *(új)* | joystick (gépen WASD/nyilak) – éjszakai temető kovácsoltvas kerítéssel; akit megérint egy zombi, zombivá változik és onnantól ő is üldöz (végig irányítod); a sírkövek mögé nem lát és nem nyúl át a zombi; az utolsó ember nyer, a helyezés a túlélési idő (az időkorlát végén ember maradtak holtversenyben) | 3D |
| 🦪 | Gyöngyhalászat *(új)* | joystick (gépen WASD/nyilak) – oldalnézetes víz alatti aréna, szabad úszás jobbra-balra és fel-le; a különböző magasságú párkányokon ülő óriáskagylók időnként kinyílnak: aki elsőként megérinti a gyöngyöt, +1 pont, a kagyló egy időre bezárul; a lassan lebegő medúza 1,5 mp-re megbénít (utána rövid védettség); 30 mp | 3D |
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

**Hogyan marad szinkronban a több gép?** A játék fix 60 lépés/mp ütemben fut (`Main.step`). A hoszt minden bemenetet lépésszámmal megjelölve szétküld, a vendég gépek ugyanazokat a lépéseket játsszák le. Minden jelenetváltásnál a hoszt a teljes állapotot is átküldi (`Snapshot`), és minden gép – a hoszt is – ebből folytatja. Amire új kódnál figyelni kell:
- a játékmenetre ható időzítés a jelenet `after()` / `sleep()` időzítőivel vagy a `Sync.after()`-rel menjen, ne `create_timer`-rel és ne valós idővel;
- a csak látványt szolgáló véletlen (részecske, pislogás, rázkódás) az `FX.f()` / `FX.fr()` legyen, ne a közös `randf()`;
- a `draw()` ne változtasson állapotot és ne húzzon véletlent;
- egy jelenet konstruktorának minden paramétere legyen elhagyható, a tagváltozói pedig sima adatok (a `Snapshot` ezeket viszi át).

Ellenőrzés két példánnyal egy gépen: az egyik `-- --bots=4 --autostart --speed=10 --sync-log`, a másik `-- --join=127.0.0.1:3001 --sync-log`; a vendég minden jelenetváltásnál kiírja, hogy a saját állapota bájtra egyezik-e a hosztéval (`EGYEZIK` / `ELTÉR`).

Tesztelési kapcsolók (a `--` után): `--bots=4`, `--autostart`, `--rounds=2`, `--mode=mountain` (hegymászás), `--mode=highway` (Óceánsztráda; `--start-node=N` innen indul mindenki), `--mg=beam` (adott minijáték), `--speed=2`, `--small` (kis ablak), `--shots=mappa` (automatikus képernyőképek), `--quit-at=60`.

```
native/
  main.tscn, scripts/main.gd     jelenetváltás, 2D réteg, részecskék, billentyűk
  scripts/core/                  net (web- és WebSocket-szerver, botok), state, game, audio, qr, draw
                                 sync (online játék: lépésütem, eseményfolyam, szobakód, szoba a közvetítő szerveren),
                                 snapshot (állapotmentés jelenetváltáskor), online_ui (a lobby online panelje)
  scripts/world/                 board_layout (pálya), board3d (3D tábla, kamera), chars3d (18 figura),
                                 mountain_layout + mountain3d (a hegymászás pályája és 3D hegye)
                                 highway_layout + highway3d (az Óceánsztráda számai és 3D világa)
  scripts/scenes/                lobby, board (táblamenet), mountain (hegymászás), highway (Óceánsztráda), mg_flow (minijáték-keret), final
  scripts/minigames/             a minijátékok (a díszletet külön fájl is adhatja, pl. presents_world.gd;
                                 mg_kit.gd: ezüst óra, helyezéscímkék, kar és arc)
  web/                           telefonos kontroller (HTML/JS/CSS + portrék), becsomagolva: web.zip
  music/, tools/                 zenék és a generátoruk
```

A fontok (Fredoka, Noto Color Emoji) SIL Open Font License alatt állnak, a licencek a `fonts/` mappában vannak. A figurák, a pálya, a minijátékok és a zene saját munka.
