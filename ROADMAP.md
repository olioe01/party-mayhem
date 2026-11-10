# Party Mayhem – 3D (2.5D) ütemterv

Cél: a tábla és a figurák 3D-ben, Mario Party-szerű hangulattal. A minijátékok egyelőre 2D-ben maradnak,
később egyenként kerülnek át 3D-be. A telefonos kontroller és a szerver változatlan.

Jelölés: ✅ kész · 🔨 folyamatban · ⬜ hátravan

## 1. 🔨 3D alapok és 3D tábla
- Three.js beépítése helyben (`/vendor/three`, internet nélkül is megy)
- Két réteg: alul a 3D (WebGL) vászon, felül a meglévő 2D-s felület (HUD, kártyák, feliratok)
- 3D sziget, víz, utak, mezők ikonokkal, low-poly díszletek (fák, kastély, vulkán, sziklák)
- Ferde rálátású kamera, napfény, árnyékok
- 3D korona (forog, lebeg, fénylik), átrepülés animáció új helyre
- A bábuk egyelőre „táblás” figurák (avatar-korong talapzaton), ugrálnak a mezők között
- A 2D-s effektek (kocka, lebegő szövegek, jelölők) a 3D pozíciókhoz igazodnak
- Tartalék: ha nincs WebGL, a régi 2D tábla jelenik meg

## 2. ⬜ Kódból épített 3D figurák
- Gömb/kapszula test a játékos színében, szemek, állatfül/kalap az állatfigura szerint
- Animációk: álló „lélegzés”, lépésnél ugrás + összenyomódás, öröm (érme/korona), szomorúság (piros mező)
- Az aktuális játékos fölött lebegő jelölő

## 3. ⬜ Kamerarendezés
- Kör elején áttekintő nézet, utána a soron lévő játékos követése
- Ráközelítés dobásnál és koronavásárlásnál
- Elágazásnál a két út felé forduló nézet
- Sima, rugós kameramozgás

## 4. ⬜ 3D kocka és effektek
- Valódi 3D dobókocka, amit a játékos „megüt”
- 3D érme-részecskék, felvillanó mezők, koronavásárlás-tűzijáték

## 5. ⬜ Hangulat
- Animált víz és felhők, apró élőlények
- Az utolsó 3 körben naplementés/vöröses fények

## 6. ⬜ Minőség és teljesítmény
- Grafikai minőség választó (alacsony/magas) a lobbyban
- FPS-mérés, automatikus visszaváltás gyenge gépen

## 7. ⬜ Első 3D minijáték: Lökdösődő aréna
- Valódi 3D platform, láva, ferde kamera, a figurák a 2. lépésből

## 8. ⬜ További minijátékok 3D-ben
- Érmeeső 3D-ben, majd egy-két új, eleve 3D-s minijáték

## 9. ⬜ Tesztelés valódi telefonokkal és finomhangolás
