// Célzó – a mutató ide-oda leng, állítsd meg a célzónában!
import { text, avatar, burst, rand, vgrad, time, panel, rr, shade } from '../engine.js';
import { sfx } from '../audio.js';
import * as net from '../net.js';

const ROUNDS = 5;
const BAR_X0 = 160, BAR_X1 = 1120, BAR_Y = 300;
const LIMIT = 7, REVEAL = 2.6;

class Stopper {
  constructor(players) {
    this.players = players;
    this.t = 0;
    this.finished = false;
    this.round = 0;
    this.pts = new Map(players.map((p) => [p.pid, 0]));
    this.phase = 'pre';
    this.phaseT = 0;
    this.stops = new Map();
    this.target = 0.5;
    this.speed = 2.2;
  }

  start() { this.next(); }

  next() {
    this.round++;
    if (this.round > ROUNDS) { this.finished = true; return; }
    this.phase = 'run';
    this.phaseT = 0;
    this.target = rand(0.15, 0.85);
    this.speed = 1.5 + this.round * 0.3; // lassú, hogy a telefon–gép késés ne számítson sokat
    this.width = Math.max(0.05, 0.11 - this.round * 0.012);
    this.ph = rand(0, Math.PI * 2);
    this.stops = new Map();
    this.got = new Map();
    this.botTol = new Map(this.players.map((p) => [p.pid, rand(0.03, 0.16)]));
    this.botMin = new Map(this.players.map((p) => [p.pid, rand(0.6, 2.5)]));
    for (const p of this.players) net.setCtrl(p.pid, { mode: 'tap', label: '🎯 STOP!', hint: 'Állítsd meg a mutatót a sárga zónában!' });
  }

  pos(t = this.phaseT) { return 0.5 + 0.5 * Math.sin(t * this.speed + this.ph); }

  input(p, msg) {
    if (msg.t !== 'tap' || this.phase !== 'run' || this.stops.has(p.pid)) return;
    const v = this.pos();
    const d = Math.abs(v - this.target);
    const g = d <= this.width / 2 * 0.35 ? 100 : Math.max(0, Math.round(100 * (1 - d / 0.32)));
    this.stops.set(p.pid, v);
    this.got.set(p.pid, g);
    this.pts.set(p.pid, this.pts.get(p.pid) + g);
    if (g >= 100) { sfx.crown(); net.vibrate(p.pid, [60, 40, 160]); } else { sfx.pop(); net.vibrate(p.pid, 40); }
    net.setCtrl(p.pid, { mode: 'wait', icon: g >= 100 ? '🎯' : g >= 75 ? '👍' : '😬', title: `${g} pont`, text: g >= 100 ? 'TÖKÉLETES!' : 'Várj a többiekre…' });
  }

  bot(p) {
    if (this.phase !== 'run' || this.stops.has(p.pid)) return;
    const late = this.phaseT > LIMIT - 1;
    if ((this.phaseT >= this.botMin.get(p.pid) && Math.abs(this.pos() - this.target) < this.botTol.get(p.pid)) || late) this.input(p, { t: 'tap' });
  }

  update(dt) {
    this.t += dt;
    if (this.phase === 'pre') return;
    this.phaseT += dt;
    if (this.phase === 'run' && (this.phaseT >= LIMIT || this.players.every((p) => this.stops.has(p.pid)))) {
      for (const p of this.players) if (!this.stops.has(p.pid)) net.setCtrl(p.pid, { mode: 'wait', icon: '⌛', title: 'Lejárt az idő!', text: '0 pont ebben a körben' });
      this.phase = 'reveal';
      this.phaseT = 0;
      const best = [...this.got.entries()].sort((a, b) => b[1] - a[1])[0];
      if (best && best[1] > 0) {
        const p = this.players.find((q) => q.pid === best[0]);
        burst(BAR_X0 + this.stops.get(p.pid) * (BAR_X1 - BAR_X0), BAR_Y, { n: 40, colors: [p.color, '#ffd43b', '#fff'], speed: 420 });
      }
    } else if (this.phase === 'reveal' && this.phaseT >= REVEAL) this.next();
  }

  ranking() {
    return this.players.map((p) => ({ pid: p.pid, score: this.pts.get(p.pid), label: `${this.pts.get(p.pid)} pont` }))
      .sort((a, b) => b.score - a.score);
  }

  draw(c) {
    vgrad(c, '#3d1d0f', '#140803');
    text(c, `${Math.max(1, Math.min(this.round, ROUNDS))}. / ${ROUNDS} kör`, 100, 36, { size: 22, color: '#ddd' });
    panel(c, 400, 14, 480, 70, { r: 35, fill: 'rgba(0,0,0,.45)' });
    text(c, '🎯 Állítsd meg a sárgában!', 640, 50, { size: 32 });

    const W0 = BAR_X1 - BAR_X0;
    const toX = (v) => BAR_X0 + v * W0;
    // sáv: színátmenet a cél felé
    rr(c, BAR_X0 - 10, BAR_Y - 38, W0 + 20, 76, 38);
    c.fillStyle = '#2a140a'; c.fill();
    const g = c.createLinearGradient(BAR_X0, 0, BAR_X1, 0);
    const tg = this.target;
    g.addColorStop(0, '#7f1d1d');
    g.addColorStop(Math.max(0, tg - 0.25), '#ea580c');
    g.addColorStop(tg, '#facc15');
    g.addColorStop(Math.min(1, tg + 0.25), '#ea580c');
    g.addColorStop(1, '#7f1d1d');
    rr(c, BAR_X0, BAR_Y - 26, W0, 52, 26);
    c.fillStyle = g; c.fill();
    // célzóna
    const zx = toX(tg - this.width / 2), zw = this.width * W0;
    rr(c, zx, BAR_Y - 34, zw, 68, 12);
    c.fillStyle = 'rgba(255,255,255,.35)'; c.fill();
    c.lineWidth = 4; c.strokeStyle = '#fff'; c.stroke();

    // játékosok megállított jelölői
    let k = 0;
    for (const p of this.players) {
      const v = this.stops.get(p.pid);
      if (v == null) continue;
      const x = toX(v);
      const up = (k++ % 2) ? 1 : -1;
      c.strokeStyle = p.color;
      c.lineWidth = 4;
      c.beginPath(); c.moveTo(x, BAR_Y + up * 26); c.lineTo(x, BAR_Y + up * 62); c.stroke();
      avatar(c, p, x, BAR_Y + up * 82, 17, { shadow: false });
      if (this.phase === 'reveal') text(c, String(this.got.get(p.pid)), x, BAR_Y + up * 118, { size: 20, color: '#ffd43b', stroke: '#000', sw: 4 });
    }

    // a mutató
    if (this.phase === 'run') {
      const x = toX(this.pos());
      c.fillStyle = '#fff';
      c.beginPath();
      c.moveTo(x, BAR_Y - 30); c.lineTo(x - 16, BAR_Y - 58); c.lineTo(x + 16, BAR_Y - 58); c.closePath();
      c.fill();
      c.fillRect(x - 3, BAR_Y - 32, 6, 64);
      const pulse = 0.5 + Math.sin(time * 10) * 0.5;
      text(c, 'MOST?', 640, 470, { size: 40, color: shade('#facc15', pulse * 0.4), stroke: '#000', sw: 6 });
    }

    // pontsáv alul
    const n = this.players.length;
    const gap = Math.min(150, 1180 / n);
    this.players.forEach((p, i) => {
      const x = 640 + (i - (n - 1) / 2) * gap;
      const done = this.stops.has(p.pid);
      panel(c, x - gap / 2 + 6, 560, gap - 12, 120, { r: 18, fill: 'rgba(0,0,0,.45)', stroke: p.color, shadow: false });
      avatar(c, p, x, 598, 24, { shadow: false, alpha: done || this.phase !== 'run' ? 1 : 0.6 });
      text(c, p.name, x, 636, { size: 16, maxW: gap - 18 });
      text(c, `${this.pts.get(p.pid)}`, x, 662, { size: 20, color: '#ffd43b' });
    });
  }
}

export default {
  id: 'stopper', name: 'Célzó', icon: '🎯', color: '#facc15',
  tagline: 'Egy jól időzített koppintás',
  desc: 'Egy mutató ide-oda leng a sávon. Állítsd meg minél közelebb a sárga célzóna közepéhez! Minél pontosabb vagy, annál több pontot kapsz (max. 100). Körről körre gyorsul a mutató, és szűkül a zóna.',
  controls: 'Nyomd meg a STOP gombot, amikor a mutató a sárga zónában van. Körönként egyszer nyomhatsz. 5 kör.',
  layout: () => ({ mode: 'wait', icon: '🎯', title: 'Célzó', text: 'Figyeld a mutatót!' }),
  create: (players) => new Stopper(players),
};
