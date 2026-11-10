# 🎉 Party Mayhem

Helyi hálózaton futó, böngészős táblás partijáték 1–8 főre. A játék a laptopon vagy a TV-n fut, **a telefonok a kontrollerek**. Telepíteni semmit nem kell rájuk, elég beolvasni a QR-kódot.

## Indítás

```bash
npm install
npm start
```

- **Játékképernyő (laptop/TV):** `http://localhost:3000/host`. Kattints a kezdéshez, `F` = teljes képernyő, `M` = hang ki/be.
- **Telefonok:** olvassák be a QR-kódot a lobbyban (ugyanazon a Wi-Fi-n kell lenniük).

## A játék

- A tábla egy szigeten körbefutó út, középen egy veszélyes **rövidítéssel**.
- Mindenki dob egy 1–10-es kockával (a telefonján koppintva), és lép.
  - 🔵 kék mező: +3 érme
  - 🔴 piros mező: −3 érme
  - 🟣 **?** mező: véletlen esemény (szerencse, helycsere, szülinap, sas…)
  - 🟠 🛒 bolt: tárgyak (dupla/tripla kocka, zsebtolvaj, teleport)
- Egy 👑 **korona** áll valahol a táblán. Aki rálép vagy átmegy rajta, 20 érméért megveheti, utána a korona máshová kerül.
- Minden kör végén **minijáték** jön, és a helyezés érmét ér (10 / 6 / 3 / 1).
- Az utolsó 3 körben a mezők duplán számítanak. A végén 3 bónusz korona jár (minijáték-mester, vándor, krőzus).
- **A legtöbb koronát gyűjtő nyer**, holtversenynél a több érme dönt.

### Minijátékok

| | Név | Irányítás |
|---|---|---|
| 🚀 | Rakétaverseny | gyors koppintás |
| ⚡ | Villámreflex | egy gomb, csak ha zöld a lámpa |
| 💥 | Lökdösődő aréna | joystick + lökés gomb |
| 🪙 | Érmeeső | ◀ ▶ gombok |
| 🧠 | Színmemória | 4 színes gomb |
| 🔢 | Számold meg! | számbillentyűzet |

### Hasznos

- Az **első csatlakozó játékos a ⭐ VIP**: ő állítja a körök számát, és ő indítja a játékot a telefonjáról.
- A lobbyban a `+ Bot` gombbal (vagy a `B` billentyűvel) gépi játékosokat adhatsz hozzá.
- Ha egy telefon lecsatlakozik, a játék nem áll meg: amíg vissza nem jön, egy bot játszik helyette. Újratöltés után ugyanaz a játékos marad.
- Tesztelési URL-paraméterek: `/host?bots=3&rounds=2`, vagy egy adott minijáték: `/host?bots=3&mg=arena`.

## WSL esetén: hogyan érik el a telefonok?

WSL2 alatt a szerver alapból egy belső (172.x.x.x) címen fut, ezt a telefonok nem látják. Három megoldás közül választhatsz:

1. **Legegyszerűbb:** telepíts Node.js-t Windowsra, és ott futtasd az `npm start`-ot.
2. **Mirrored hálózat (Windows 11):** a `%UserProfile%\.wslconfig` fájlba írd be:
   ```ini
   [wsl2]
   networkingMode=mirrored
   ```
   Utána futtasd a `wsl --shutdown` parancsot, és engedélyezd a 3000-es portot a tűzfalon (rendszergazdai PowerShellben):
   ```powershell
   New-NetFirewallRule -DisplayName "Party Mayhem" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
   ```
3. **Porttovábbítás** (rendszergazdai PowerShellben, a `<WSL-IP>` a `hostname -I` első címe WSL-ben):
   ```powershell
   netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=<WSL-IP>
   New-NetFirewallRule -DisplayName "Party Mayhem" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
   ```
   Ilyenkor indítsd így, hogy a QR-kód a Windows gép címére mutasson:
   ```bash
   PUBLIC_HOST=192.168.1.23 npm start   # a Windows gép Wi-Fi IP-címe (ipconfig)
   ```

Tipp: ha a játékképernyőt eleve a gép LAN-címén nyitod meg (pl. `http://192.168.1.23:3000/host`), a QR-kód automatikusan azt a címet használja.

## Felépítés

```
server.js                 Express + Socket.IO: üzenettovábbítás a host és a telefonok között, QR-kód
public/host.html          játékképernyő (canvas)
public/js/host/           játéklogika: engine (rajz, jelenetek), board (tábla), mgflow (minijáték keret),
                          minigames/ (a 6 minijáték), lobby, final, net (kontrollerek + botok), audio
public/index.html         telefonos kontroller (play.js, play.css)
```

Minden grafika canvas-rajz és emoji, minden hang WebAudio-szintézis, külső asset nincs.
