// A pálya felépítése: lebegő szigetek, hidak, elágazások, ugrópadok.
// Tiszta adat + számolás (nincs rajzolás), a koordináták a 2D tábla pixelei (1280x720).

// determinisztikus véletlen, hogy a díszletek mindig ugyanott legyenek
export function seeded(seed) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Szigetek: ellipszisek. A "big" díszletek fix helyen állnak, a többi automatikusan kerül az utak mellé.
export const ISLANDS = [
  { id: 'meadow', name: 'Rét', x: 250, y: 455, rx: 200, ry: 150, top: '#7cc552', side: '#8b5e34', rock: '#7c6f64',
    big: [['fountain', 290, 440, 1.2]], deco: ['tree', 'tree', 'flowers', 'mushroom', 'flowers', 'tree'] },
  { id: 'forest', name: 'Erdő', x: 245, y: 170, rx: 165, ry: 120, top: '#4f9a45', side: '#6b4a2b', rock: '#6b6461',
    big: [], deco: ['pine', 'pine', 'pine', 'mushroom', 'pine', 'rock', 'pine'] },
  { id: 'castle', name: 'Kastély', x: 640, y: 125, rx: 205, ry: 98, top: '#8fd16a', side: '#8b5e34', rock: '#857a72',
    big: [['castle', 530, 158, 1.0]], deco: ['flowers', 'tree', 'flowers'] },
  { id: 'volcano', name: 'Vulkán', x: 1035, y: 180, rx: 170, ry: 125, top: '#6e5446', side: '#4a342a', rock: '#3f3631',
    big: [['volcano', 1040, 185, 1.05]], deco: ['rock', 'rock', 'rock'] },
  { id: 'desert', name: 'Sivatag', x: 1040, y: 470, rx: 175, ry: 135, top: '#e9c46a', side: '#b07a3c', rock: '#9c7b5b',
    big: [['tent', 1050, 470, 1.1]], deco: ['cactus', 'cactus', 'palm', 'rock', 'cactus', 'palm'] },
  { id: 'crystal', name: 'Kristály', x: 640, y: 355, rx: 150, ry: 105, top: '#a99cf2', side: '#5b4a9e', rock: '#4c4475',
    big: [['crystal', 560, 345, 1.1], ['crystal', 715, 440, 0.9]], deco: ['crystal', 'rock'] },
  { id: 'beach', name: 'Öböl', x: 640, y: 585, rx: 160, ry: 62, top: '#f2d18b', side: '#b07a3c', rock: '#9c8b7b',
    big: [], deco: ['palm', 'palm'] },
];

// Fő kör (az óramutató járásával megegyezően a képernyőn)
const MAIN_WP = [
  [330, 565], [205, 548], [120, 470], [130, 375],
  [170, 280], [150, 180], [210, 95], [335, 82],
  [470, 108], [560, 68], [720, 68], [820, 108],
  [905, 98], [1010, 72], [1125, 100], [1175, 195], [1110, 285],
  [1140, 375], [1180, 470], [1125, 562], [995, 590],
  [865, 602], [745, 588], [640, 610], [535, 590], [430, 578],
];
// fő kör mezői, 0 = a fenti első pont; 'T' = rajt
const MAIN_TYPES = 'TBEBRBSBEJBRBEBBRBSEBBRBEJBBRBSBEBBRB';

// elágazások: honnan (legközelebbi fő mező), merre, hova csatlakozik vissza
const BRANCHES = [
  { id: 'crystal', from: [640, 68], to: [640, 610], via: [[625, 190], [655, 285], [625, 380], [650, 480]], types: 'REBRER',
    route: { label: '⬇️ Kristály-rövidítés', sub: 'Rövid, de veszélyes – sok a piros mező!' } },
  { id: 'lava', from: [1110, 285], to: 'crystal:3', via: [[1000, 330], [880, 355], [780, 360]], types: 'RBRE',
    route: { label: '⬅️ Lávahíd', sub: 'Átvág a közepére, de forró a talaj' } },
];
const MAIN_ROUTE = { label: '➡️ Körút', sub: 'Hosszabb, de biztonságosabb' };

// Catmull–Rom görbe a pontokon át
function curve(pts, closed, per = 30) {
  const n = pts.length, out = [];
  const get = (i) => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))]);
  const segs = closed ? n : n - 1;
  for (let i = 0; i < segs; i++) {
    const p0 = get(i - 1), p1 = get(i), p2 = get(i + 1), p3 = get(i + 2);
    for (let k = 0; k < per; k++) {
      const t = k / per, t2 = t * t, t3 = t2 * t;
      out.push([0, 1].map((j) => 0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
        + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)));
    }
  }
  out.push(closed ? [...pts[0]] : [...pts[n - 1]]);
  return out;
}

// egyenletes pontok a vonal mentén: a hossz i/den részeinél, i = from..to
function along(line, fracs) {
  const cum = [0];
  for (let i = 1; i < line.length; i++) cum.push(cum[i - 1] + Math.hypot(line[i][0] - line[i - 1][0], line[i][1] - line[i - 1][1]));
  const L = cum[cum.length - 1];
  let j = 0;
  return fracs.map((f) => {
    const target = L * f;
    while (j < cum.length - 1 && cum[j + 1] < target) j++;
    const k = cum[j + 1] > cum[j] ? (target - cum[j]) / (cum[j + 1] - cum[j]) : 0;
    const a = line[j], b = line[Math.min(j + 1, line.length - 1)];
    return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
  });
}

export const islandAt = (x, y, pad = 0) => ISLANDS.find((s) => ((x - s.x) / (s.rx + pad)) ** 2 + ((y - s.y) / (s.ry + pad)) ** 2 <= 1) || null;

export function buildBoard() {
  const nodes = [];
  const add = (x, y, type, extra = {}) => {
    const n = { id: nodes.length, x: Math.round(x), y: Math.round(y), type, next: [], ...extra };
    nodes.push(n);
    return n;
  };
  const N = MAIN_TYPES.length;
  const main = along(curve(MAIN_WP, true), Array.from({ length: N }, (_, i) => i / N))
    .map(([x, y], i) => add(x, y, MAIN_TYPES[i]));
  main.forEach((n, i) => { n.next.push(main[(i + 1) % N].id); });
  const nearest = (p) => main.reduce((b, n) => (Math.hypot(n.x - p[0], n.y - p[1]) < Math.hypot(b.x - p[0], b.y - p[1]) ? n : b));

  const branchNodes = {};
  for (const br of BRANCHES) {
    const a = nearest(br.from);
    const b = typeof br.to === 'string' ? branchNodes[br.to.split(':')[0]][Number(br.to.split(':')[1])] : nearest(br.to);
    const line = curve([[a.x, a.y], ...br.via, [b.x, b.y]], false);
    const k = br.types.length;
    const pts = along(line, Array.from({ length: k }, (_, i) => (i + 1) / (k + 1)));
    const list = pts.map(([x, y], i) => add(x, y, br.types[i], { inner: br.id }));
    branchNodes[br.id] = list;
    a.routes = a.routes || [MAIN_ROUTE];
    a.next.push(list[0].id);
    a.routes.push(br.route);
    list.forEach((n, i) => { n.next.push(i + 1 < k ? list[i + 1].id : b.id); });
  }

  // ugrópadok: párban, egymásba lőnek
  const pads = nodes.filter((n) => n.type === 'J');
  for (let i = 0; i + 1 < pads.length; i += 2) { pads[i].pair = pads[i + 1].id; pads[i + 1].pair = pads[i].id; }
  for (const n of nodes) n.island = islandAt(n.x, n.y, 6)?.id ?? null;

  return { nodes, start: 0, islands: ISLANDS, deco: placeDeco(nodes) };
}

// távolság pont és szakasz között
function segDist(px, py, a, b) {
  const dx = b.x - a.x, dy = b.y - a.y;
  const t = Math.max(0, Math.min(1, ((px - a.x) * dx + (py - a.y) * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(px - a.x - dx * t, py - a.y - dy * t);
}

function placeDeco(nodes) {
  const rnd = seeded(7);
  const segs = [];
  for (const n of nodes) for (const id of n.next) segs.push([n, nodes[id]]);
  const out = [];
  const free = (x, y, r) => segs.every(([a, b]) => segDist(x, y, a, b) > r + 26)
    && out.every(([, ox, oy, os]) => Math.hypot(ox - x, oy - y) > r + 22 * os);
  for (const s of ISLANDS) {
    for (const d of s.big) out.push(d);
    for (const kind of s.deco) {
      for (let tries = 0; tries < 60; tries++) {
        const a = rnd() * Math.PI * 2, rr = Math.sqrt(rnd()) * 0.82;
        const x = s.x + Math.cos(a) * s.rx * rr, y = s.y + Math.sin(a) * s.ry * rr;
        const sc = 0.8 + rnd() * 0.45;
        if (free(x, y, 22 * sc)) { out.push([kind, Math.round(x), Math.round(y), +sc.toFixed(2)]); break; }
      }
    }
  }
  return out;
}
