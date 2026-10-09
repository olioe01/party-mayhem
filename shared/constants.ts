import { AvatarId, AvatarInfo, ChaosEvent, PartyMode } from './types';

export const AVATARS: Record<AvatarId, AvatarInfo> = {
  fox: {
    id: 'fox',
    name: 'Róka',
    emoji: '🦊',
    color: '#f97316',
    badge: 'Ravasz',
    description: 'Gyors és kiszámíthatatlan!'
  },
  shark: {
    id: 'shark',
    name: 'Cápa',
    emoji: '🦈',
    color: '#06b6d4',
    badge: 'Ragadozó',
    description: 'Nem kegyelmez senkinek!'
  },
  frog: {
    id: 'frog',
    name: 'Béka',
    emoji: '🐸',
    color: '#84cc16',
    badge: 'Ugrifüles',
    description: 'Magasra ugrik, mélyre taszít!'
  },
  panda: {
    id: 'panda',
    name: 'Panda',
    emoji: '🐼',
    color: '#f1f5f9',
    badge: 'Nyugis',
    description: 'Lassú víz partot mos!'
  },
  octopus: {
    id: 'octopus',
    name: 'Polip',
    emoji: '🐙',
    color: '#a855f7',
    badge: 'Kaotikus',
    description: 'Minden csápjával kavarja a vizet!'
  },
  cat: {
    id: 'cat',
    name: 'Macska',
    emoji: '🐱',
    color: '#ec4899',
    badge: 'Csínytevő',
    description: 'Mindig a talpára érkezik!'
  },
  robot: {
    id: 'robot',
    name: 'Robot',
    emoji: '🤖',
    color: '#3b82f6',
    badge: 'Precíz',
    description: 'Hideg kalkuláció, nulla érzelem!'
  },
  ghost: {
    id: 'ghost',
    name: 'Szellem',
    emoji: '👻',
    color: '#818cf8',
    badge: 'Kísérteties',
    description: 'Átsiklik a csapdákon!'
  },
  chicken: {
    id: 'chicken',
    name: 'Csirke',
    emoji: '🐔',
    color: '#eab308',
    badge: 'Pánikoló',
    description: 'Fejvesztve rohan a győzelemért!'
  },
  dino: {
    id: 'dino',
    name: 'Dínó',
    emoji: '🦖',
    color: '#22c55e',
    badge: 'Zúzó',
    description: 'Mindent legázol a pályán!'
  }
};

export const CROWN_COST_COINS = 25;

export const PARTY_MODE_ROUNDS: Record<PartyMode, number> = {
  quick: 8,
  normal: 12,
  chaos: 16
};

export const MINIGAME_COIN_REWARDS = [10, 7, 5, 3, 1, 1, 1, 1];

// 27 Unique Chaos Events
export const CHAOS_EVENTS: ChaosEvent[] = [
  {
    id: 'coin_storm',
    name: 'COIN STORM',
    description: 'Hatalmas érmezápor! Minden játékos kap +5 érmét!',
    icon: '🌧️',
    affectType: 'all'
  },
  {
    id: 'tax_time',
    name: 'TAX TIME',
    description: 'Adóellenőrzés! A jelenlegi első helyezett veszít 10 érmét!',
    icon: '🧾',
    affectType: 'leader'
  },
  {
    id: 'robin_hood',
    name: 'ROBIN HOOD',
    description: 'Az élen állótól 6 érme átvándorol az utolsó helyezetthez!',
    icon: '🏹',
    affectType: 'all'
  },
  {
    id: 'swap',
    name: 'SWAP!',
    description: 'Két random játékos azonnal helyet cserél a pályán!',
    icon: '🔄',
    affectType: 'random'
  },
  {
    id: 'double_trouble',
    name: 'DOUBLE TROUBLE',
    description: 'A következő minijáték minden jutalma DUPLÁZÓDIK!',
    icon: '🔥',
    affectType: 'all'
  },
  {
    id: 'revenge',
    name: 'REVENGE',
    description: 'Az utolsó helyezett ellophat 5 érmét az általa választott ellenféltől!',
    icon: '🗡️',
    affectType: 'last'
  },
  {
    id: 'bank_error',
    name: 'BANK ERROR',
    description: 'Banki tévedés a javadra! Egy szerencsés játékos kap +15 érmét!',
    icon: '🏦',
    affectType: 'random'
  },
  {
    id: 'bad_luck',
    name: 'BAD LUCK',
    description: 'Balszerencse! Egy véletlenszerű játékos veszít 8 érmét!',
    icon: '💥',
    affectType: 'random'
  },
  {
    id: 'teleport',
    name: 'TELEPORT',
    description: 'Térugrás! Egy véletlenszerű játékos egy másik mezőre repül!',
    icon: '🌀',
    affectType: 'random'
  },
  {
    id: 'crown_panic',
    name: 'CROWN PANIC',
    description: 'A Crown Shop azonnal új helyre költözik a pályán!',
    icon: '👑',
    affectType: 'shop'
  },
  {
    id: 'chaos_round',
    name: 'CHAOS ROUND',
    description: 'A következő minijáték pontozása MEGVIZSGÁLÓDIK: az utolsó kapja a legtöbb érmét!',
    icon: '🙃',
    affectType: 'all'
  },
  {
    id: 'mystery_box',
    name: 'MYSTERY BOX',
    description: 'Egy játékos választhat 3 titkos doboz közül (+10 coin, -5 coin vagy KORONA)!',
    icon: '🎁',
    affectType: 'random'
  },
  {
    id: 'lucky_day',
    name: 'LUCKY DAY',
    description: 'Egy szerencsés játékos következő dobása garantáltan legalább 4 lesz!',
    icon: '🍀',
    affectType: 'random'
  },
  {
    id: 'slow_mode',
    name: 'SLOW MODE',
    description: 'Egy játékos lassítva halad: következő dobása maximum 3 lehet!',
    icon: '🐢',
    affectType: 'random'
  },
  {
    id: 'coin_duel',
    name: 'COIN DUEL',
    description: 'Két véletlenszerű játékos azonnali párbajt vív 6 érméért!',
    icon: '⚔️',
    affectType: 'random'
  },
  {
    id: 'bounty',
    name: 'BOUNTY',
    description: 'Vérdíj! Aki a következő minijátékban megelőzi a vezetőt, extra +8 érmét kap!',
    icon: '🎯',
    affectType: 'leader'
  },
  {
    id: 'meteor_shower',
    name: 'METEOR SHOWER',
    description: 'Meteorzápor a páratlan sorszámú mezőkön! Az ott állók veszítenek 3 érmét!',
    icon: '☄️',
    affectType: 'board'
  },
  {
    id: 'gold_rush',
    name: 'GOLD RUSH',
    description: 'Aranyláz! Minden kék mező 1 kör erejéig duplán fizet (+6 érme)!',
    icon: '💰',
    affectType: 'board'
  },
  {
    id: 'equalizer',
    name: 'EQUALIZER',
    description: 'Egyenlőségi hullám: a legtöbb érmével rendelkező játékos lead 4-et a legkevesebbel bíróknak!',
    icon: '⚖️',
    affectType: 'all'
  },
  {
    id: 'speed_run',
    name: 'SPEED RUN',
    description: 'Turbó sebesség! Minden játékos azonnal 2 mezővel előrébb lép!',
    icon: '⚡',
    affectType: 'all'
  },
  {
    id: 'freeze',
    name: 'FREEZE',
    description: 'A vezető játékos megfagy: a következő körben nem dobhat kockát!',
    icon: '❄️',
    affectType: 'leader'
  },
  {
    id: 'shop_sale',
    name: 'SHOP SALE',
    description: 'Kiárusítás! A Crown Shop ára 1 körre lecsökken 15 érmére!',
    icon: '🏷️',
    affectType: 'shop'
  },
  {
    id: 'crown_gift',
    name: 'CROWN GIFT',
    description: 'Karitatív adomány! Az utolsó helyezett azonnal kap 12 segítő érmét!',
    icon: '💝',
    affectType: 'last'
  },
  {
    id: 'lucky_wheel',
    name: 'LUCKY WHEEL',
    description: 'Kaotikus szerencsekerék pörög a nagy képernyőn!',
    icon: '🎡',
    affectType: 'random'
  },
  {
    id: 'anarchy',
    name: 'ANARCHY',
    description: 'Anarchia a pénzügyekben! Mindenki érméje véletlenszerűen módosul (+- 5)!',
    icon: '🏴‍☠️',
    affectType: 'all'
  },
  {
    id: 'shield_blessing',
    name: 'SHIELD BLESSING',
    description: 'Egy játékos védőpajzsot kap a következő negatív esemény vagy csapda ellen!',
    icon: '🛡️',
    affectType: 'random'
  },
  {
    id: 'ghost_visit',
    name: 'GHOST VISIT',
    description: 'A szellem meglátogatja a 2. helyezettet és átad 4 érmét a 4. helyezettnek!',
    icon: '👻',
    affectType: 'all'
  }
];

// Harmless Social Party Challenges (Alcohol-free)
export const PARTY_CHALLENGES = [
  'A legkevesebb pontot szerző játékosnak utánoznia kell az avatárja állathangját!',
  'A forduló nyertese kiválaszthatja a következő háttérzenét vagy ritmust!',
  'A két utolsó helyezettnek le kell pacsiznia és helyet kell cserélnie a kanapén!',
  'A következő minijátékban mindenki csak a nem domináns kezét használhatja!',
  'Az élen álló játékosnak tiszteletteljesen meg kell hajolnia a többiek előtt!',
  'Aki hibázik a következő körben, annak 10 másodpercig szoborrá kell merevednie!'
];

// Secret Missions (Displayed ONLY on phone)
export const SECRET_MISSION_TEMPLATES = [
  {
    title: 'Szorongasd meg a bajnokot!',
    description: 'A következő minijátékban végezz az aktuális első helyezett előtt!',
    rewardCoins: 6,
    conditionType: 'beat_player' as const
  },
  {
    title: 'Dobogós cél!',
    description: 'A következő minijátékban kerülj be az első 2 helyezett közé!',
    rewardCoins: 5,
    conditionType: 'top_two' as const
  },
  {
    title: 'Páros dobás!',
    description: 'A következő körödben dobj páros számot (2, 4 vagy 6)!',
    rewardCoins: 4,
    conditionType: 'roll_even' as const
  },
  {
    title: 'Különleges célpont!',
    description: 'Lépj egy arany, boost vagy chaos mezőre a következő mozgásodkor!',
    rewardCoins: 5,
    conditionType: 'land_special' as const
  },
  {
    title: 'Trónfosztás!',
    description: 'Ha a jelenlegi éllovas NEM nyeri meg a következő minijátékot, zsebeld be a jutalmat!',
    rewardCoins: 5,
    conditionType: 'leader_loses' as const
  }
];

export interface MinigameMeta {
  id: string;
  name: string;
  description: string;
  instructions: string;
}

export const MINIGAME_META_LIST: MinigameMeta[] = [
  { id: 'fruit-frenzy', name: 'Fruit Frenzy (3D Arena)', description: 'Kapd el a hulló gyümölcsöket kosárral a D-paddal!', instructions: 'D-PAD = MOZGÁS! Kerüld a bombákat (-3), kapd el az aranyalmát (+3)!' },
  { id: 'bomb-dodge', name: 'Bomb Dodge (3D Arena)', description: 'Térj ki a lehulló bombák és robbanások elől a D-paddal!', instructions: 'D-PAD = MOZGÁS! Fuss ki a piros veszélyzónákból a robbanás előtt!' },
  { id: 'push-arena', name: 'Push Arena (3D Arena)', description: 'Lökd le az ellenfeleket a lebegő arénáról!', instructions: 'D-PAD = MOZGÁS • [A] = LÖKÉS • [B] = DASH!' },
  { id: 'crown-chase', name: 'Crown Chase (3D Arena)', description: 'Tartsd meg a koronát a legtovább!', instructions: 'D-PAD = MOZGÁS! Érj a koronáshoz a lopáshoz, majd menekülj!' },
  { id: 'paint-panic', name: 'Paint Panic (3D Arena)', description: 'Fesd le a padlót a saját színeddel a D-paddal!', instructions: 'D-PAD = MOZGÁS! Ahol jársz, felveszi a színedet!' },
  { id: 'controller-test', name: 'Controller Test Arena', description: 'Szabad teszt aréna a telefonos kontroller teszteléséhez!', instructions: 'D-PAD = MOZGÁS • [A] = UGRÁS • [B] = AKCIÓ' },
  { id: 'reaction-rush', name: 'Reaction Rush', description: 'Reagálj a leggyorsabban a GO-ra!', instructions: 'VÁRJ A GO-RA!' },
  { id: 'shake-it', name: 'Shake It', description: 'Rázd a telefont, lődd ki a rakétát!', instructions: 'RÁZD VAGY TAPELD GŐZERŐVEL!' },
  { id: 'bomb-pass', name: 'Bomb Pass', description: 'Passzold el a bombát, mielőtt felrobban!', instructions: 'ADD ÁT MÁSNAK IDŐBEN!' },
  { id: 'dont-touch', name: "Don't Touch", description: 'Ne érj hozzá a hamis feliratoknál!', instructions: 'CSAK A "NOW!" UTÁN NYOMD MEG!' },
  { id: 'perfect-stop', name: 'Perfect Stop', description: 'Állítsd meg a mutatót a célvonalon!', instructions: 'ÁLLÍTSD MEG KÖZÉPEN!' },
  { id: 'tap-war', name: 'Tap War', description: 'Nyomd gyorsan, de állj meg a STOP-nál!', instructions: '10 MÁSODPERC! VÉGÉN STOP!' },
  { id: 'balance', name: 'Balance', description: 'Tartsd a golyót a kör közepén!', instructions: 'DÖNTSD A TELEFONT!' },
  { id: 'choose-your-enemy', name: 'Choose Your Enemy', description: 'Titkos szavazás az ellenfelekről!', instructions: 'SZAVAZZ VALAKIRE TITKOBAN!' },
  { id: 'button-chicken', name: 'Button Chicken', description: 'Minden nyomás +1 érme, de bármikor robbanhat!', instructions: 'NYOMD A COINÉRT ÉS BANKOLJ!' },
  { id: 'hold-your-nerve', name: 'Hold Your Nerve', description: 'Tartsd lenyomva a szorzóért a CRASH előtt!', instructions: 'TARTSD LENYOMVA!' },
  { id: 'safe-tile', name: 'Safe Tile', description: 'Válassz biztonságos színt!', instructions: 'VÁLASSZ SZÍNT!' },
  { id: 'copycat', name: 'Copycat', description: 'Ismételd meg a színsort!', instructions: 'ISMÉTELT A MINTÁT PONTOSAN!' },
  { id: 'phone-hot-potato', name: 'Phone Hot Potato', description: 'Gyors továbbadás a kért játékosnak!', instructions: 'KÖVESD A TV UTASÍTÁSAIT!' },
  { id: 'fake-buttons', name: 'Fake Buttons', description: 'Találd meg a kért szimbólumot a 9 gomb közül!', instructions: 'KERESD MEG A KÉRT IKONT!' },
  { id: 'last-second', name: 'Last Second', description: 'Nyomd meg pontosan 10.00 másodpercnél!', instructions: 'SZÁMOLJ FEJBEN 10-IG!' },
  { id: 'tug-of-war', name: 'Tug of War (2v2v1)', description: 'Csapatos kötélhúzás, solo bónusszal!', instructions: 'TAPELJ A CSAPATODÉRT!' },
  { id: 'boss-battle', name: 'Boss Battle', description: 'Mindenki a jelenlegi első ellen!', instructions: 'A BOSS VÉDEKEZIK, A CSAPAT TÁMAD!' },
  { id: 'target-lock', name: 'Target Lock', description: 'Célozz és lőj az ellenfelek avatarjaira!', instructions: 'CÉLOZZ ÉS LŐJ!' },
  { id: 'secret-number', name: 'Secret Number', description: 'Válassz egyedi számot 1 és 10 között!', instructions: 'VÁLASSZ SZÁMOT 1 ÉS 10 KÖZÖTT!' }
];

import { CosmeticHat, HatId } from './types';

export const COSMETIC_HATS: Record<HatId, CosmeticHat> = {
  none: {
    id: 'none',
    name: 'Nincs kalap',
    emoji: '🧢',
    description: 'Természetes frizura'
  },
  'top-hat': {
    id: 'top-hat',
    name: 'Cilinder',
    emoji: '🎩',
    description: 'Elegáns úriember stílus'
  },
  cap: {
    id: 'cap',
    name: 'Baseball sapka',
    emoji: '🧢',
    description: 'Utcai laza viselet'
  },
  crown: {
    id: 'crown',
    name: 'Kis korona',
    emoji: '👑',
    description: 'A királyi fenség'
  },
  cowboy: {
    id: 'cowboy',
    name: 'Cowboy kalap',
    emoji: '🤠',
    description: 'Vadnyugati seriff'
  },
  'grad-cap': {
    id: 'grad-cap',
    name: 'Diplomás sapka',
    emoji: '🎓',
    description: 'A buli professzora'
  },
  'party-hat': {
    id: 'party-hat',
    name: 'Party csákó',
    emoji: '🎉',
    description: 'Szülinapi buli hangulat'
  },
  'frog-hat': {
    id: 'frog-hat',
    name: 'Béka sapka',
    emoji: '🐸',
    description: 'Aranyos zöld békafej'
  },
  'sun-hat': {
    id: 'sun-hat',
    name: 'Nyári szalmakalap',
    emoji: '👒',
    description: 'Tengerparti pihenés'
  }
};


