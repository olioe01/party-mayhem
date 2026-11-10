// Fejszámolás – ki oldja meg leggyorsabban a feladatot?
import { text, avatar, burst, randi, rand, vgrad, time, panel, ease } from '../engine.js';
import { sfx } from '../audio.js';
import { timerHud } from './common.js';
import * as net from '../net.js';

const LIMIT = 12, REVEAL = 3.2;
const ORDER_PTS = [3, 2]; // 1. helyes: 3, 2. helyes: 2, a többi helyes: 1

// körönként nehezedő feladatok; az eredmény mindig 0..999
const MAKERS = [
  () => { const a = randi(12, 49), b = randi(11, 49); return { q: `${a} + ${b}`, a: a + b }; },
  () => { const a = randi(40, 99), b = randi(12, a - 5); return { q: `${a} − ${b}`, a: a - b }; },
  () => { const a = randi(3, 9), b = randi(4, 12); return { q: `${a} × ${b}`, a: a * b }; },
  () => { const a = randi(20, 60), b = randi(10, 40), c = randi(5, 25); return { q: `${a} + ${b} − ${c}`, a: a + b - c }; },
  () => { const a = randi(3, 9), b = randi(3, 9), c = randi(5, 30); return { q: `${a} × ${b} + ${c}`, a: a * b + c }; },
];

class QuickMath {
  constructor(players) {
    this.players = players;
    this.t = 0;
    this.finished = false;
    this.round = 0;
    this.pts = new Map(players.map((p) => [p.pid, 0]));
    this.phase = 'pre';
    this.phaseT = 0;
    this.ans = new Map();
    this.correctOrder = [];
    this.task = MAKERS[0]();
  }

  start() { this.next(); }

  next() {
    this.round++;
    if (this.round > MAKERS.length) { this.finished = true; return; }
    this.task = MAKERS[this.round - 1]();
    this.phase = 'ask';
    this.phaseT = 0;
    this.ans = new Map();
    this.correctOrder = [];
    this.botPlan = new Map(this.players.map((p) => [p.pid, {
      at: rand(2.2, 4) + this.round * rand(0.4, 1),
      v: Math.random() < 0.82 ? this.task.a : this.task.a + (Math.random() < 0.5 ? -1 : 1) * randi(1, 10),
    }]));
    sfx.select();
    for (const p of this.players) net.setCtrl(p.pid, { mode: 'number', title: `${this.task.q} = ?` });
  }

  input(p, msg) {
    if (msg.t !== 'num' || this.phase !== 'ask' || this.ans.has(p.pid)) return;
    const v = Math.max(0, Math.min(999, Math.round(Number(msg.v) || 0)));
    const ok = v === this.task.a;
    this.ans.set(p.pid, { v, ok, at: this.phaseT });
    if (ok) {
      this.correctOrder.push(p.pid);
      sfx.coin();
      net.vibrate(p.pid, 60);
    } else {
      sfx.bad();
      net.vibrate(p.pid, [120, 50, 120]);
    }
    net.setCtrl(p.pid, { mode: 'wait', icon: ok ? '✅' : '❌', title: ok ? 'Helyes!' : 'Nem talált…', text: `A tipped: ${v}` });
  }

  bot(p) {
    const plan = this.botPlan?.get(p.pid);
    if (this.phase === 'ask' && plan && !this.ans.has(p.pid) && this.phaseT >= plan.at) this.input(p, { t: 'num', v: plan.v });
  }

  award() {
    this.gained = new Map();
    this.correctOrder.forEach((pid, i) => {
      const g = ORDER_PTS[i] ?? 1;
      this.gained.set(pid, g);
      this.pts.set(pid, this.pts.get(pid) + g);
    });
    if (this.correctOrder.length) burst(640, 260, { n: 40, speed: 450 });
  }

  update(dt) {
    this.t += dt;
    if (this.phase === 'pre') return;
    this.phaseT += dt;
    if (this.phase === 'ask' && (this.phaseT >= LIMIT || this.players.every((p) => this.ans.has(p.pid)))) {
      this.phase = 'reveal';
      this.phaseT = 0;
      this.award();
      for (const p of this.players) if (!this.ans.has(p.pid)) net.setCtrl(p.pid, { mode: 'wait', icon: '⌛', title: 'Lejárt az idő!', text: `A megoldás: ${this.task.a}` });
    } else if (this.phase === 'reveal' && this.phaseT >= REVEAL) this.next();
  }

  ranking() {
    return this.players.map((p) => ({ pid: p.pid, score: this.pts.get(p.pid), label: `${this.pts.get(p.pid)} pont` }))
      .sort((a, b) => b.score - a.score);
  }

  draw(c) {
    vgrad(c, '#0f3d3e', '#03161a');
    text(c, `${Math.max(1, Math.min(this.round, MAKERS.length))}. / ${MAKERS.length} feladat`, 110, 36, { size: 22, color: '#ddd' });
    if (this.phase === 'ask') timerHud(c, LIMIT - this.phaseT, 1180, 40);

    const s = ease.outBack(Math.min(1, this.phaseT * 3));
    c.save();
    c.translate(640, 250);
    if (this.phase === 'ask') c.scale(s, s);
    panel(c, -380, -110, 760, 220, { r: 40, fill: 'rgba(255,255,255,.95)', stroke: '#20c997', lw: 8 });
    const eq = this.phase === 'reveal' ? `${this.task.q} = ${this.task.a}` : `${this.task.q} = ?`;
    text(c, eq, 0, 6, { size: eq.length > 14 ? 76 : 96, color: '#0b3d3e', maxW: 720 });
    c.restore();
    text(c, this.phase === 'reveal' ? (this.correctOrder.length ? 'Szép munka!' : 'Senki nem találta el…') : 'Írd be a választ a telefonodon!',
      640, 410, { size: 28, color: '#c3fae8', weight: 600 });

    const n = this.players.length;
    const gap = Math.min(150, 1180 / n);
    this.players.forEach((p, i) => {
      const x = 640 + (i - (n - 1) / 2) * gap;
      const a = this.ans.get(p.pid);
      const rank = this.correctOrder.indexOf(p.pid);
      const hop = a && this.phaseT - a.at < 0.3 && this.phase === 'ask' ? 8 : 0;
      panel(c, x - gap / 2 + 6, 480, gap - 12, 200, { r: 18, fill: 'rgba(0,0,0,.4)', stroke: p.color, shadow: false });
      avatar(c, p, x, 530 - hop, 28, { shadow: false });
      text(c, p.name, x, 575, { size: 16, maxW: gap - 18 });
      if (this.phase === 'reveal') {
        if (a) text(c, String(a.v), x, 610, { size: 26, color: a.ok ? '#69db7c' : '#ff8787' });
        else text(c, '—', x, 610, { size: 26, color: '#aaa' });
        const g = this.gained?.get(p.pid);
        if (g) text(c, `+${g}${rank === 0 ? ' ⚡' : ''}`, x, 642, { size: 20, color: '#ffd43b' });
      } else if (a) {
        text(c, rank >= 0 ? `${rank + 1}. ✔` : '✔', x, 610, { size: 24, color: '#e9fac8' });
      } else text(c, '…', x, 610, { size: 26, color: '#999' });
      text(c, `${this.pts.get(p.pid)} pont`, x, 668, { size: 17, color: '#ffd43b' });
    });
    if (this.phase === 'ask') {
      const pulse = 0.5 + Math.sin(time * 4) * 0.5;
      text(c, '🧮', 1040, 250, { size: 70, alpha: 0.4 + pulse * 0.3 });
    }
  }
}

export default {
  id: 'quickmath', name: 'Fejszámolás', icon: '🧮', color: '#20c997',
  tagline: 'Gyorsabb vagy a számológépnél?',
  desc: 'Megjelenik egy feladat a képernyőn, és egyre nehezebb lesz. Az első helyes válasz 3 pontot ér, a második 2-t, a többi helyes 1-et. Egy feladatra csak egyszer válaszolhatsz!',
  controls: 'Írd be az eredményt a telefonod számbillentyűzetén, és nyomd meg a ✓-t. 5 feladat.',
  layout: () => ({ mode: 'wait', icon: '🧮', title: 'Fejszámolás', text: 'Figyeld a képernyőt!' }),
  create: (players) => new QuickMath(players),
};
