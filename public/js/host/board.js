// A játéktábla: mezők, dobás, lépés, korona, bolt, események

import {
  Scene, W, H, text, panel, avatar, emoji, rr, vgrad, burst, floatText, confetti, shade, ease,
  rand, randi, pick, time, lerp, setScene,
} from './engine.js';
import { G, ITEMS, CROWN_PRICE, MAX_ITEMS, addCoins, placeOf, isLastRounds } from './state.js';
import * as net from './net.js';
import { sfx, music } from './audio.js';
import { MgSelectScene } from './mgflow.js';
import * as b3 from './board3d.js';

const TYPES = {
  B: { color: '#3b82f6', icon: '+' },
  R: { color: '#ef4444', icon: '−' },
  E: { color: '#a855f7', icon: '?' },
  S: { color: '#f59e0b', icon: '🛒' },
  T: { color: '#10b981', icon: '🏁' },
};
const OUTER = 'BBEBRBBSBEBBRBEBBEBBRBEB' + 'T' + 'BBRSBEB'; // 32 mező, 24-es a start
const INNER = 'REBER'; // a rövidítés mezői
const NODE_R = 21;

export function buildBoard() {
  const cx = 640, cy = 330, a = 500, b = 228, n = 4;
  const pts = [];
  const M = 4000;
  for (let i = 0; i <= M; i++) {
    const th = -Math.PI / 2 + (2 * Math.PI * i) / M;
    const c = Math.cos(th), s = Math.sin(th);
    pts.push([cx + a * Math.sign(c) * Math.pow(Math.abs(c), 2 / n), cy + b * Math.sign(s) * Math.pow(Math.abs(s), 2 / n)]);
  }
  const cum = [0];
  for (let i = 1; i <= M; i++) cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  const N = OUTER.length;
  const nodes = [];
  let j = 0;
  for (let k = 0; k < N; k++) {
    const target = (cum[M] * k) / N;
    while (cum[j] < target) j++;
    nodes.push({ id: k, x: pts[j][0], y: pts[j][1], type: OUTER[k], next: [(k + 1) % N] });
  }
  // rövidítés a tetejéről (0) az aljára (16), középen keresztül
  const top = nodes[0], bottom = nodes[N / 2];
  let prev = top;
  for (let k = 1; k <= INNER.length; k++) {
    const node = {
      id: nodes.length, x: cx, y: lerp(top.y, bottom.y, k / (INNER.length + 1)), type: INNER[k - 1], next: [], inner: true,
    };
    nodes.push(node);
    prev.next.push(node.id);
    prev = node;
  }
  prev.next = [bottom.id];
  return { nodes, start: 24, fork: 0 };
}

// 3D díszletek: [típus, x, y (2D px), méret]
const DECO3D = [
  ['castle', 380, 300, 1.15], ['volcano', 905, 290, 1.1], ['tree', 250, 205, 1], ['tree', 300, 455, 1.1],
  ['pine', 520, 190, 1], ['pine', 470, 220, 0.8], ['tree', 520, 465, 0.9], ['palm', 760, 200, 1], ['palm', 1035, 440, 1],
  ['cactus', 775, 455, 1], ['mushroom', 450, 410, 1.3], ['mushroom', 470, 430, 0.9], ['flowers', 250, 330, 1.4],
  ['flowers', 1040, 215, 1.4], ['rock', 820, 375, 1.5], ['rock', 845, 390, 0.8], ['fountain', 255, 400, 1],
  ['tent', 1000, 330, 1], ['flowers', 560, 330, 1.2], ['flowers', 720, 330, 1.2], ['tree', 1060, 290, 0.8],
  ['pine', 220, 260, 0.8], ['tree', 700, 470, 0.8], ['rock', 580, 200, 0.9],
];

let staticCache = null;
function renderStatic(board) {
  const cv = document.createElement('canvas');
  cv.width = W * 2;
  cv.height = H * 2;
  const c = cv.getContext('2d');
  c.scale(2, 2);
  // víz
  vgrad(c, '#4cc9f0', '#1d4e89');
  c.strokeStyle = 'rgba(255,255,255,.18)';
  c.lineWidth = 3;
  for (let i = 0; i < 40; i++) {
    const x = rand(0, W), y = rand(0, H);
    c.beginPath();
    c.arc(x, y, 14, Math.PI * 1.1, Math.PI * 1.9);
    c.stroke();
  }
  // sziget
  rr(c, 78, 52, 1124, 556, 150);
  c.fillStyle = '#f4d58d';
  c.fill();
  rr(c, 96, 68, 1088, 524, 135);
  const g = c.createRadialGradient(640, 330, 100, 640, 330, 650);
  g.addColorStop(0, '#9be15d');
  g.addColorStop(1, '#3fa34d');
  c.fillStyle = g;
  c.fill();
  for (let i = 0; i < 260; i++) {
    c.fillStyle = `rgba(30,90,30,${rand(0.08, 0.2)})`;
    const x = rand(130, 1150), y = rand(90, 570);
    c.fillRect(x, y, 2, 6);
  }
  // díszletek (a belső területeken, az utaktól távol)
  const deco = [
    ['🏰', 380, 300, 92], ['🌋', 905, 285, 92], ['🌳', 250, 200, 46], ['🌳', 300, 450, 50], ['🌲', 520, 190, 44],
    ['🌳', 515, 460, 44], ['🌴', 760, 200, 46], ['🌴', 1040, 430, 48], ['🌵', 770, 455, 40], ['🍄', 450, 410, 30],
    ['🌻', 250, 330, 30], ['🌷', 1040, 210, 30], ['🪨', 820, 370, 34], ['⛲', 255, 395, 36], ['🏕️', 1000, 330, 40],
    ['🌼', 560, 330, 26], ['🌸', 720, 330, 26], ['⛵', 40, 640, 44], ['🐳', 1235, 90, 44], ['🦀', 1225, 640, 32],
    ['🐠', 40, 110, 30], ['🏝️', 1240, 360, 40],
  ];
  for (const [e, x, y, s] of deco) emoji(c, e, x, y, s);
  // utak
  const nodes = board.nodes;
  for (const pass of [0, 1, 2]) {
    for (const nd of nodes) {
      for (const nid of nd.next) {
        const to = nodes[nid];
        c.beginPath();
        c.moveTo(nd.x, nd.y);
        c.lineTo(to.x, to.y);
        c.lineCap = 'round';
        if (pass === 0) { c.strokeStyle = '#6b4f2a'; c.lineWidth = 30; }
        else if (pass === 1) { c.strokeStyle = (nd.inner || to.inner) ? '#e8b4a0' : '#e7c98f'; c.lineWidth = 20; }
        else { c.strokeStyle = 'rgba(255,255,255,.55)'; c.lineWidth = 3; c.setLineDash([6, 10]); }
        c.stroke();
        c.setLineDash([]);
      }
    }
  }
  // mezők
  for (const nd of nodes) {
    const t = TYPES[nd.type];
    c.fillStyle = 'rgba(0,0,0,.3)';
    c.beginPath();
    c.ellipse(nd.x, nd.y + 6, NODE_R, NODE_R * 0.55, 0, 0, Math.PI * 2);
    c.fill();
    const gg = c.createRadialGradient(nd.x - 6, nd.y - 7, 2, nd.x, nd.y, NODE_R);
    gg.addColorStop(0, shade(t.color, 0.45));
    gg.addColorStop(1, t.color);
    c.fillStyle = gg;
    c.beginPath();
    c.arc(nd.x, nd.y, NODE_R, 0, Math.PI * 2);
    c.fill();
    c.lineWidth = 4;
    c.strokeStyle = '#fff';
    c.stroke();
    if (nd.type === 'S' || nd.type === 'T') emoji(c, t.icon, nd.x, nd.y, 22);
    else text(c, t.icon, nd.x, nd.y + 1, { size: 26, color: '#fff', stroke: shade(t.color, -0.4), sw: 4 });
  }
  return cv;
}

const EVENTS = [
  { w: 3, icon: '🍀', title: 'Szerencse!', desc: 'Kapsz 10 érmét.', run: (s, p) => s.give(p, 10) },
  { w: 3, icon: '🕳️', title: 'Lyukas zseb', desc: 'Elhagysz 6 érmét.', run: (s, p) => s.give(p, -6) },
  {
    w: 2, icon: '🎂', title: 'Szülinap!', desc: 'Mindenki ad neked 3 érmét.', ok: () => G.players.length > 1,
    run: (s, p) => { let sum = 0; for (const q of G.players) if (q !== p) { const d = -addCoins(q, -3); sum += d; s.coinFx(q, -d); } s.give(p, sum); },
  },
  {
    w: 2, icon: '🌧️', title: 'Érmeeső', desc: 'Mindenki kap 5 érmét.',
    run: (s) => { for (const q of G.players) s.give(q, 5); },
  },
  { w: 2, icon: '🔄', title: 'Helycsere', desc: 'Helyet cserélsz egy véletlen játékossal!', ok: () => G.players.length > 1, run: (s, p) => s.swapWith(p, pick(G.players.filter((q) => q !== p))) },
  {
    w: 2, icon: '🎁', title: 'Ajándék', desc: 'Kapsz egy véletlen tárgyat.',
    run: (s, p) => {
      if (p.items.length >= MAX_ITEMS) { s.give(p, 5); return; }
      const k = pick(Object.keys(ITEMS));
      p.items.push(k);
      net.pushStatus(p.pid);
      const { x, y } = s.pawnXY(p);
      floatText(x, y - 40, `${ITEMS[k].icon} ${ITEMS[k].name}`, '#fff', 30);
    },
  },
  {
    w: 1, icon: '🦅', title: 'Koronaexpressz', desc: 'Egy sas a korona elé repít!',
    ok: () => G.crownNode != null,
    run: async (s, p) => {
      const before = G.board.nodes.find((n) => !n.inner && n.next.includes(G.crownNode)) || G.board.nodes.find((n) => n.next.includes(G.crownNode));
      if (before && before.id !== p.node) { await s.hop(p, before.id, 0.9, 160); p.node = before.id; }
    },
  },
];

export class BoardScene extends Scene {
  constructor(intro) { super(); this.intro = intro; }

  enter() {
    G.phase = 'board';
    music('board');
    this.use3d = b3.available();
    if (this.use3d) {
      b3.build(G.board, TYPES, DECO3D);
      b3.setVisible(true);
    } else if (!staticCache || staticCache.board !== G.board) {
      staticCache = { board: G.board, img: renderStatic(G.board) };
    }
    this.anim = new Map();
    this.current = null;
    this.toastObj = null;
    this.dice = null;
    this.card = null;
    this.shopFor = null;
    this.forkFor = null;
    this.stepsLeft = 0;
    this.crownAnim = null;
    for (const p of G.players) p.dispCoins = p.coins;
    this.run();
  }

  exit() { b3.setVisible(false); }

  // ---------------------------------------------------------------- menet
  async run() {
    if (this.intro) {
      await this.toast('Kezdődik a játék!', `${G.maxRounds} kör · a legtöbb 👑 koronát gyűjtő nyer`, 2.4);
      await this.toast('Sorrend', G.players.map((p) => p.name).join('  →  '), 2.6);
      await this.placeCrown();
    }
    if (this.dead) return;
    await this.toast(`${G.round}. kör`, G.round === G.maxRounds ? 'Ez az utolsó kör!' : `még ${G.maxRounds - G.round + 1} kör van hátra`, 1.6);
    if (isLastRounds() && G.round === G.maxRounds - 2) {
      sfx.fanfare();
      await this.toast('🔥 UTOLSÓ 3 KÖR! 🔥', 'A kék és piros mezők mostantól duplán számítanak!', 2.8);
    }
    for (const p of G.players) {
      if (this.dead) return;
      await this.turn(p);
    }
    if (this.dead) return;
    this.current = null;
    for (const p of G.players) net.setCtrl(p.pid, { mode: 'wait', icon: '🎮', title: 'Minijáték jön!', text: 'Készülj!' });
    await this.toast('🎮 Minijáték!', 'Mindenki játszik mindenki ellen', 1.6);
    setScene(new MgSelectScene());
  }

  async turn(p) {
    this.current = p;
    sfx.select();
    for (const q of G.players) {
      if (q !== p) net.setCtrl(q.pid, { mode: 'wait', char: p.char, title: `${p.name} következik`, text: 'Figyeld a képernyőt!' });
    }
    await this.sleep(0.5);
    let dice = 1;
    if (p.items.length) {
      const options = [{ label: '🎲 Dobás', sub: 'Sima kockadobás' },
        ...p.items.map((k) => ({ label: `${ITEMS[k].icon} ${ITEMS[k].name}`, sub: ITEMS[k].desc }))];
      const r = await net.ask(p.pid, { mode: 'choice', title: 'Te jössz!', text: 'Dobsz, vagy használsz egy tárgyat?', options });
      if (this.dead) return;
      if (r.v > 0 && r.v <= p.items.length) {
        const key = p.items.splice(r.v - 1, 1)[0];
        net.pushStatus(p.pid);
        dice = await this.useItem(p, key);
        if (this.dead) return;
      }
    }
    let total = 0;
    const rolls = [];
    for (let i = 0; i < dice; i++) {
      const v = await this.rollDie(p, i, dice);
      if (this.dead) return;
      rolls.push(v);
      total += v;
    }
    if (dice > 1) await this.toast(`${rolls.join(' + ')} = ${total}`, 'lépés', 1.2);
    await this.move(p, total);
    if (this.dead) return;
    await this.land(p);
    await this.sleep(0.6);
  }

  async useItem(p, key) {
    const it = ITEMS[key];
    const { x, y } = this.pawnXY(p);
    floatText(x, y - 50, `${it.icon} ${it.name}!`, '#fff', 32);
    sfx.whoosh();
    if (key === 'double') return 2;
    if (key === 'triple') return 3;
    const others = G.players.filter((q) => q !== p);
    if (!others.length) return 1;
    if (key === 'warp') {
      await this.swapWith(p, pick(others));
      return 1;
    }
    if (key === 'thief') {
      const options = others.map((q) => ({ label: q.name, sub: `${q.coins} 🪙`, char: q.char, disabled: q.coins === 0 }));
      if (options.every((o) => o.disabled)) {
        await this.toast('🧤 Zsebtolvaj', 'Senkinek nincs érméje… 😅', 1.5);
        return 1;
      }
      const rich = others.indexOf([...others].sort((a, b) => b.coins - a.coins)[0]);
      const r = await net.ask(p.pid, { mode: 'choice', title: '🧤 Kitől lopsz?', options, botPick: rich });
      if (this.dead) return 1;
      const q = others[r.v];
      const amt = -addCoins(q, -randi(5, 15));
      this.coinFx(q, -amt);
      await this.sleep(0.6);
      this.give(p, amt);
      await this.toast('🧤 Zsebtolvaj', `${p.name} ellopott ${amt} érmét ${q.name} zsebéből!`, 1.8);
      return 1;
    }
    return 1;
  }

  async rollDie(p, i, n) {
    const { x, y } = this.pawnXY(p);
    this.dice = { x, y: y - 85, val: randi(1, 10), rolling: true, next: 0, hitT: 0 };
    const label = n > 1 ? `🎲 DOBJ! (${i + 1}/${n})` : '🎲 DOBJ!';
    await net.ask(p.pid, { mode: 'tap', label, hint: 'Koppints a dobáshoz!', botAuto: true }, ['tap'], 25);
    if (this.dead) return 0;
    this.dice.rolling = false;
    this.dice.hitT = this.t;
    sfx.hit();
    net.vibrate(p.pid, 80);
    burst(this.dice.x, this.dice.y, { n: 18, colors: ['#fff', p.color, '#ffd43b'], speed: 300 });
    await this.sleep(0.9);
    const v = this.dice.val;
    this.dice = null;
    return v;
  }

  async move(p, steps) {
    this.stepsLeft = steps;
    while (this.stepsLeft > 0) {
      const node = G.board.nodes[p.node];
      let nextId = node.next[0];
      if (node.next.length > 1) {
        this.forkFor = node;
        const r = await net.ask(p.pid, {
          mode: 'choice', title: 'Merre mész?', text: `Még ${this.stepsLeft} lépés`,
          options: [{ label: '➡️ Körút', sub: 'Hosszabb, de biztonságos' }, { label: '⬇️ Rövidítés', sub: 'Rövid, de sok a piros mező!' }],
        });
        this.forkFor = null;
        if (this.dead) return;
        nextId = node.next[r.v] ?? node.next[0];
      }
      await this.hop(p, nextId);
      if (this.dead) return;
      p.node = nextId;
      p.stats.steps++;
      this.stepsLeft--;
      if (nextId === G.crownNode) {
        await this.crownStop(p);
        if (this.dead) return;
      }
    }
  }

  hop(p, toId, dur = 0.28, height = 26) {
    const from = this.groundXY(p);
    const to = G.board.nodes[toId];
    this.anim.set(p.pid, { from, to: { x: to.x, y: to.y }, t0: this.t, dur, height });
    sfx.step();
    return this.sleep(dur).then(() => {
      this.anim.delete(p.pid);
      p.node = toId;
      sfx.land();
    });
  }

  async swapWith(p, q) {
    const a = p.node, b = q.node;
    sfx.whoosh();
    await Promise.all([this.hop(p, b, 0.8, 140), this.hop(q, a, 0.8, 140)]);
    p.node = b;
    q.node = a;
  }

  async crownStop(p) {
    if (p.coins >= CROWN_PRICE) {
      const r = await net.ask(p.pid, {
        mode: 'choice', title: '👑 Korona!', text: `Megveszed ${CROWN_PRICE} érméért? (${p.coins} 🪙 van)`,
        options: [{ label: '👑 Igen, kérem!' }, { label: 'Nem most' }], botPick: 0,
      });
      if (this.dead) return;
      if (r.v === 0) {
        addCoins(p, -CROWN_PRICE);
        p.crowns++;
        net.pushStatus(p.pid);
        net.vibrate(p.pid, [80, 60, 80, 60, 200]);
        if (this.use3d) b3.emote(p.pid, 'cheer');
        sfx.crown();
        const { x, y } = this.pawnXY(p);
        burst(x, y, { n: 60, colors: ['#ffd43b', '#fff3bf', '#fab005', p.color], speed: 500 });
        confetti(80);
        floatText(x, y - 50, '+1 👑', '#ffd43b', 44);
        await this.toast(`👑 ${p.name} koronát szerzett!`, `Már ${p.crowns} koronája van`, 2, p);
        await this.placeCrown();
      }
    } else {
      await this.toast('👑 A korona itt van!', `Ehhez ${CROWN_PRICE} érme kell – ${p.name} zsebében csak ${p.coins} van.`, 1.8);
    }
  }

  async placeCrown() {
    const occupied = new Set(G.players.map((p) => p.node));
    const cand = G.board.nodes.filter((n) => n.type === 'B' && !n.inner && n.id !== G.crownNode && !occupied.has(n.id));
    const target = pick(cand.length ? cand : G.board.nodes.filter((n) => n.type === 'B'));
    const from = G.crownNode != null ? G.board.nodes[G.crownNode] : { x: 640, y: -60 };
    G.crownNode = null;
    this.crownAnim = { from, to: target, t0: this.t, dur: 1.3 };
    sfx.whoosh();
    await this.sleep(1.3);
    G.crownNode = target.id;
    this.crownAnim = null;
    sfx.crown();
    const tq = this.scr(target.x, target.y, 40);
    burst(tq.x, tq.y, { n: 30, colors: ['#ffd43b', '#fff'], speed: 260 });
    await this.toast('👑 A korona új helye', `Lépj rá vagy haladj át rajta, és vedd meg ${CROWN_PRICE} érméért!`, 1.8);
  }

  async land(p) {
    const node = G.board.nodes[p.node];
    const mult = isLastRounds() ? 2 : 1;
    switch (node.type) {
      case 'B':
      case 'T': this.give(p, 3 * mult); await this.sleep(1); break;
      case 'R': this.give(p, -3 * mult); await this.sleep(1); break;
      case 'E': await this.event(p); break;
      case 'S': await this.shop(p); break;
      default:
    }
  }

  give(p, n) {
    const d = addCoins(p, n);
    this.coinFx(p, d);
    return d;
  }

  coinFx(p, d) {
    if (this.use3d && d) b3.emote(p.pid, d > 0 ? 'happy' : 'sad');
    const { x, y } = this.pawnXY(p);
    floatText(x, y - 36, `${d >= 0 ? '+' : ''}${d} 🪙`, d >= 0 ? '#ffd43b' : '#ff8787', 32);
    if (d > 0) { burst(x, y, { n: 14, colors: ['#ffd43b', '#fab005', '#fff3bf'] }); sfx.coin(); }
    else if (d < 0) sfx.bad();
    net.vibrate(p.pid, d >= 0 ? 40 : [60, 40, 60]);
  }

  async event(p) {
    const pool = EVENTS.filter((e) => !e.ok || e.ok());
    let r = Math.random() * pool.reduce((s, e) => s + e.w, 0);
    const ev = pool.find((e) => (r -= e.w) < 0) || pool[0];
    this.card = { ev, t0: this.t };
    sfx.whoosh();
    await this.sleep(2.2);
    if (this.dead) return;
    await ev.run(this, p);
    await this.sleep(1);
    this.card = null;
  }

  async shop(p) {
    const keys = Object.keys(ITEMS);
    const full = p.items.length >= MAX_ITEMS;
    const options = keys.map((k) => ({
      label: `${ITEMS[k].icon} ${ITEMS[k].name}  ·  ${ITEMS[k].price} 🪙`, sub: ITEMS[k].desc,
      disabled: full || p.coins < ITEMS[k].price,
    }));
    options.push({ label: 'Köszi, semmit' });
    this.shopFor = p;
    const r = await net.ask(p.pid, { mode: 'choice', title: '🛒 Bolt', text: full ? 'Tele a zsebed (max. 3 tárgy)' : `${p.coins} érméd van. Mit veszel?`, options });
    if (this.dead) return;
    if (r.v < keys.length && !options[r.v].disabled) {
      const k = keys[r.v];
      addCoins(p, -ITEMS[k].price);
      p.items.push(k);
      net.pushStatus(p.pid);
      sfx.coin();
      const { x, y } = this.pawnXY(p);
      floatText(x, y - 40, `${ITEMS[k].icon} ${ITEMS[k].name}`, '#fff', 30);
      await this.sleep(1.2);
    }
    this.shopFor = null;
  }

  toast(title, sub = '', dur = 1.6, p = null) {
    this.toastObj = { title, sub, t0: this.t, dur, p };
    return this.sleep(dur).then(() => { if (this.toastObj?.title === title) this.toastObj = null; });
  }

  // ---------------------------------------------------------------- pozíciók
  nodeSlot(p) {
    const here = G.players.filter((q) => q.node === p.node && !this.anim.has(q.pid));
    const n = G.board.nodes[p.node];
    if (here.length <= 1) return { x: n.x, y: n.y };
    const i = here.indexOf(p);
    const a = (i / here.length) * Math.PI * 2 - Math.PI / 2;
    const rx = this.use3d ? 19 + here.length * 3 : 17, ry = this.use3d ? 13 + here.length * 2 : 12;
    return { x: n.x + Math.cos(a) * rx, y: n.y + Math.sin(a) * ry };
  }

  // talajpozíció (2D tábla-koordináták) + ugrásmagasság px-ben
  groundXY(p) {
    const a = this.anim.get(p.pid);
    if (a) {
      const k = Math.min(1, (this.t - a.t0) / a.dur);
      const e = ease.inOutQuad(k);
      return { x: lerp(a.from.x, a.to.x, e), y: lerp(a.from.y, a.to.y, e), h: Math.sin(k * Math.PI) * a.height };
    }
    return { ...this.nodeSlot(p), h: 0 };
  }

  // tábla-pont -> képernyő (3D-ben vetítéssel)
  scr(x, y, h = 0) {
    return this.use3d ? b3.project(x, y, h) : { x, y: y - h };
  }

  // a bábu "közepe" a képernyőn – ehhez igazodnak a 2D effektek
  pawnXY(p) {
    const g = this.groundXY(p);
    return this.use3d ? b3.project(g.x, g.y, g.h + 50) : { x: g.x, y: g.y - g.h };
  }

  crownPos() {
    if (this.crownAnim) {
      const a = this.crownAnim;
      const k = Math.min(1, (this.t - a.t0) / a.dur);
      const e = ease.inOutQuad(k);
      return { x: lerp(a.from.x, a.to.x, e), y: lerp(a.from.y, a.to.y, e), h: Math.sin(k * Math.PI) * 200 };
    }
    if (G.crownNode == null) return null;
    const n = G.board.nodes[G.crownNode];
    return { x: n.x, y: n.y, h: 0 };
  }

  // ---------------------------------------------------------------- frissítés + rajz
  update(dt) {
    for (const p of G.players) p.dispCoins += (p.coins - p.dispCoins) * Math.min(1, dt * 8);
    if (this.dice?.rolling && this.t >= this.dice.next) {
      let v;
      do v = randi(1, 10); while (v === this.dice.val);
      this.dice.val = v;
      this.dice.next = this.t + 0.07;
      sfx.roll();
    }
  }

  draw(c) {
    const nodes = G.board.nodes;
    if (this.use3d) {
      b3.render({
        t: time,
        crown: this.crownPos(),
        pawns: G.players.map((p) => ({ p, ...this.groundXY(p), current: p === this.current })),
      });
    } else this.draw2dBoard(c);

    // elágazás jelzése
    if (this.forkFor) {
      this.forkFor.next.forEach((nid, i) => {
        const n = nodes[nid];
        const q = this.scr(n.x, n.y);
        const s = 1 + Math.sin(time * 6) * 0.15;
        c.beginPath();
        c.ellipse(q.x, q.y, NODE_R * 1.6 * s, NODE_R * (this.use3d ? 1.1 : 1.6) * s, 0, 0, Math.PI * 2);
        c.strokeStyle = '#fff';
        c.lineWidth = 4;
        c.stroke();
        text(c, i === 0 ? 'Körút ➡️' : '⬇️ Rövidítés', q.x + (i === 0 ? 34 : 0), q.y - 40,
          { size: 20, stroke: '#1b1036', sw: 6, align: i === 0 ? 'left' : 'center' });
      });
    }

    if (this.current) {
      const { x, y } = this.pawnXY(this.current);
      const top = y - (this.use3d ? 34 : 40);
      if (!this.use3d) text(c, '▼', x, top + Math.sin(time * 6) * 5, { size: 26, color: this.current.color, stroke: '#fff', sw: 5 });
      if (this.stepsLeft > 0 && !this.dice) {
        c.beginPath();
        c.arc(x + 30, top + 8, 17, 0, Math.PI * 2);
        c.fillStyle = '#fff';
        c.fill();
        text(c, String(this.stepsLeft), x + 30, top + 9, { size: 22, color: '#2b1055' });
      }
    }

    // kocka
    if (this.dice) this.drawDice(c);

    this.drawHud(c);
    if (this.card) this.drawCard(c);
    if (this.shopFor) this.drawShop(c);
    if (this.toastObj) this.drawToast(c);
  }

  // tartalék: a régi 2D tábla (ha nincs WebGL)
  draw2dBoard(c) {
    c.drawImage(staticCache.img, 0, 0, W, H);
    const nodes = G.board.nodes;

    // korona
    const cn = G.crownNode != null ? nodes[G.crownNode] : null;
    if (cn) {
      const pulse = 0.5 + Math.sin(time * 4) * 0.5;
      const g = c.createRadialGradient(cn.x, cn.y, 5, cn.x, cn.y, 46);
      g.addColorStop(0, `rgba(255,224,102,${0.55 + pulse * 0.3})`);
      g.addColorStop(1, 'rgba(255,224,102,0)');
      c.fillStyle = g;
      c.beginPath();
      c.arc(cn.x, cn.y, 46, 0, Math.PI * 2);
      c.fill();
      emoji(c, '👑', cn.x, cn.y - 34 + Math.sin(time * 3) * 5, 40);
    }
    if (this.crownAnim) {
      const a = this.crownAnim;
      const k = Math.min(1, (this.t - a.t0) / a.dur);
      const e = ease.inOutQuad(k);
      emoji(c, '👑', lerp(a.from.x, a.to.x, e), lerp(a.from.y, a.to.y, e) - 34 - Math.sin(k * Math.PI) * 180, 46 + Math.sin(k * Math.PI) * 30);
    }

    // bábuk (y szerint rendezve)
    const pawns = G.players.map((p) => ({ p, ...this.pawnXY(p) })).sort((a, b) => a.y - b.y);
    for (const { p, x, y } of pawns) {
      const cur = p === this.current;
      const a = this.anim.get(p.pid);
      avatar(c, p, x, y - 10, cur ? 19 : 16, { ring: cur ? '#fff' : null, squash: a ? -0.06 : Math.sin(time * 4 + p.coins) * 0.02 });
    }
  }

  drawDice(c) {
    const d = this.dice;
    const pop = d.rolling ? 1 : 1 + 0.4 * Math.max(0, 1 - (this.t - d.hitT) * 3);
    const shake = d.rolling ? Math.sin(time * 40) * 4 : 0;
    const s = 64 * pop;
    c.save();
    c.translate(d.x + shake, d.y + (d.rolling ? Math.sin(time * 12) * 6 : 0));
    c.rotate(d.rolling ? Math.sin(time * 20) * 0.12 : 0);
    rr(c, -s / 2, -s / 2 + 6, s, s, 14);
    c.fillStyle = '#b8a9e8';
    c.fill();
    rr(c, -s / 2, -s / 2, s, s, 14);
    c.fillStyle = '#fff';
    c.fill();
    c.lineWidth = 3;
    c.strokeStyle = '#2b1055';
    c.stroke();
    text(c, String(d.val), 0, 2, { size: 38 * pop, color: d.rolling ? '#5b3fb5' : '#e11d48' });
    c.restore();
  }

  drawHud(c) {
    // felső sáv
    panel(c, 14, 8, 250, 44, { r: 14, fill: 'rgba(24,14,56,.85)' });
    text(c, `🎲 ${G.round}. kör / ${G.maxRounds}`, 139, 31, { size: 23 });
    if (isLastRounds()) {
      panel(c, 274, 8, 190, 44, { r: 14, fill: 'rgba(220,38,38,.9)' });
      text(c, '🔥 Dupla mezők', 369, 31, { size: 20 });
    }
    panel(c, 1046, 8, 220, 44, { r: 14, fill: 'rgba(24,14,56,.85)' });
    text(c, `👑 ára: ${CROWN_PRICE} 🪙`, 1156, 31, { size: 21 });
    if (this.current) {
      const p = this.current;
      panel(c, 490, 6, 300, 48, { r: 24, fill: shade(p.color, -0.45), stroke: p.color });
      avatar(c, p, 516, 30, 17, { shadow: false });
      text(c, `${p.name} köre`, 652, 31, { size: 24, maxW: 250 });
    }

    // játékoskártyák
    const n = G.players.length;
    const cw = Math.min(232, (1250 - (n - 1) * 8) / n);
    const x0 = 640 - (n * cw + (n - 1) * 8) / 2;
    G.players.forEach((p, i) => {
      const cur = p === this.current;
      const x = x0 + i * (cw + 8), y = cur ? 606 : 616;
      panel(c, x, y, cw, 98, { r: 16, fill: shade(p.color, -0.55), stroke: cur ? '#ffd43b' : p.color, lw: cur ? 5 : 3 });
      avatar(c, p, x + 32, y + 36, 21, { alpha: p.connected || p.isBot ? 1 : 0.4, shadow: false });
      text(c, `${placeOf(p)}.`, x + 32, y + 78, { size: 18, color: '#ffd43b' });
      text(c, p.name, x + 60, y + 24, { size: 19, align: 'left', maxW: cw - 68 });
      text(c, `🪙 ${Math.round(p.dispCoins)}`, x + 60, y + 53, { size: 21, align: 'left', color: '#ffe066' });
      text(c, `👑 ${p.crowns}`, x + 60, y + 80, { size: 21, align: 'left', color: '#fff' });
      if (p.items.length) text(c, p.items.map((k) => ITEMS[k].icon).join(''), x + cw - 8, y + 80, { size: 16, align: 'right' });
      if (!p.connected && !p.isBot) text(c, '📵', x + cw - 14, y + 22, { size: 18 });
    });
  }

  drawCard(c) {
    const { ev, t0 } = this.card;
    const k = Math.min(1, (this.t - t0) / 0.6);
    const flip = Math.abs(Math.cos(k * Math.PI));
    const front = k >= 0.5;
    const s = ease.outBack(Math.min(1, (this.t - t0) * 3));
    c.save();
    c.translate(640, 320);
    c.scale(Math.max(0.02, flip) * s, s);
    panel(c, -190, -140, 380, 280, { fill: front ? '#faf5ff' : '#7c3aed', stroke: '#a855f7', lw: 6, r: 26 });
    if (front) {
      emoji(c, ev.icon, 0, -60, 80);
      text(c, ev.title, 0, 25, { size: 38, color: '#4c1d95' });
      text(c, ev.desc, 0, 80, { size: 22, color: '#6b21a8', weight: 600, maxW: 340 });
    } else {
      text(c, '?', 0, 5, { size: 140, color: '#fff' });
    }
    c.restore();
  }

  drawShop(c) {
    const p = this.shopFor;
    panel(c, 830, 120, 400, 330, { fill: 'rgba(255,247,230,.97)', stroke: '#f59e0b', lw: 5 });
    text(c, '🛒 Bolt', 1030, 158, { size: 34, color: '#92400e' });
    Object.values(ITEMS).forEach((it, i) => {
      const y = 205 + i * 56;
      const ok = p.coins >= it.price && p.items.length < MAX_ITEMS;
      emoji(c, it.icon, 870, y + 4, 34, ok ? 1 : 0.4);
      text(c, it.name, 900, y - 6, { size: 22, color: ok ? '#78350f' : '#b8a48a', align: 'left' });
      text(c, it.desc, 900, y + 17, { size: 15, color: '#a16207', align: 'left', weight: 400 });
      text(c, `${it.price} 🪙`, 1205, y + 4, { size: 22, color: ok ? '#b45309' : '#d6c4a8', align: 'right' });
    });
    text(c, `${p.name}: ${p.coins} 🪙`, 1030, 428, { size: 20, color: '#92400e' });
  }

  drawToast(c) {
    const { title, sub, t0, dur, p } = this.toastObj;
    const age = this.t - t0;
    const s = ease.outBack(Math.min(1, age * 4));
    const a = Math.min(1, (dur - age) * 5);
    c.save();
    c.globalAlpha = Math.max(0, a);
    c.translate(640, 300);
    c.scale(s, s);
    panel(c, -400, -78, 800, sub ? 156 : 110, { fill: p ? shade(p.color, -0.5) : 'rgba(24,14,56,.94)', stroke: p ? p.color : '#ffd43b', lw: 5, r: 28 });
    text(c, title, 0, sub ? -30 : -23, { size: 50, stroke: '#1b1036', sw: 8, maxW: 760 });
    if (sub) text(c, sub, 0, 34, { size: 24, color: '#e5dbff', weight: 600, maxW: 760 });
    c.restore();
  }
}
