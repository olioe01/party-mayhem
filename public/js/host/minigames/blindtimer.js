// Vak időzítő – az óra eltűnik, neked kell érezni, mikor telt el pontosan X másodperc
import { text, avatar, burst, rand, vgrad, time, panel, shade, rr } from '../engine.js';
import { sfx } from '../audio.js';
import * as net from '../net.js';

const TARGETS = [10, 7, 13];
const VISIBLE = 3;      // ennyi ideig látszik az óra
const INTRO = 2.6, REVEAL = 5;
const PLACE_PTS = [3, 2, 1];

// szórás közelítőleg normális eloszlással (a botokhoz)
const gauss = () => (Math.random() + Math.random() + Math.random() - 1.5) * 1.15;

class BlindTimer {
  constructor(players) {
    this.players = players;
    this.t = 0;
    this.finished = false;
    this.round = 0;
    this.pts = new Map(players.map((p) => [p.pid, 0]));
    this.err = new Map(players.map((p) => [p.pid, 0]));
    this.phase = 'pre';
    this.phaseT = 0;
    this.stops = new Map();
    this.target = TARGETS[0];
  }

  start() { this.next(); }

  next() {
    this.round++;
    if (this.round > TARGETS.length) { this.finished = true; return; }
    this.target = TARGETS[this.round - 1];
    this.phase = 'intro';
    this.phaseT = 0;
    this.stops = new Map();
    this.gained = new Map();
    this.botAt = new Map(this.players.map((p) => [p.pid, this.target + gauss() * (0.35 + this.target * 0.05)]));
    for (const p of this.players) {
      net.setCtrl(p.pid, { mode: 'wait', icon: '⏱️', title: `Cél: ${this.target} mp`, text: 'Mindjárt indul az óra…' });
    }
  }

  go() {
    this.phase = 'run';
    this.phaseT = 0;
    sfx.go();
    for (const p of this.players) {
      net.setCtrl(p.pid, { mode: 'tap', label: '⏱️ STOP!', hint: `Nyomd meg, ha szerinted eltelt ${this.target} másodperc!` });
      net.vibrate(p.pid, 80);
    }
  }

  input(p, msg) {
    if (msg.t !== 'tap' || this.phase !== 'run' || this.stops.has(p.pid)) return;
    this.stops.set(p.pid, this.phaseT);
    sfx.pop();
    net.vibrate(p.pid, 40);
    net.setCtrl(p.pid, { mode: 'wait', icon: '🤞', title: 'Megállítva!', text: 'Lássuk, mennyire voltál pontos…' });
  }

  bot(p) {
    if (this.phase === 'run' && !this.stops.has(p.pid) && this.phaseT >= this.botAt.get(p.pid)) this.input(p, { t: 'tap' });
  }

  score() {
    const rows = this.players.map((p) => {
      const s = this.stops.get(p.pid);
      return { p, d: s == null ? null : Math.abs(s - this.target) };
    }).filter((r) => r.d != null).sort((a, b) => a.d - b.d);
    let place = 0;
    rows.forEach((r, i) => {
      if (i > 0 && Math.abs(r.d - rows[i - 1].d) > 0.0005) place = i;
      const g = (PLACE_PTS[place] ?? 0) + (r.d < 0.1 ? 1 : 0); // 0,1 mp-en belül: +1 bónusz
      this.gained.set(r.p.pid, g);
      this.pts.set(r.p.pid, this.pts.get(r.p.pid) + g);
    });
    for (const p of this.players) {
      const s = this.stops.get(p.pid);
      this.err.set(p.pid, this.err.get(p.pid) + (s == null ? 5 : Math.abs(s - this.target)));
    }
    this.best = rows[0]?.p ?? null;
    if (this.best) burst(640, 300, { n: 50, colors: [this.best.color, '#ffd43b', '#fff'], speed: 480 });
    sfx.coin();
  }

  update(dt) {
    this.t += dt;
    if (this.phase === 'pre') return;
    const prev = this.phaseT;
    this.phaseT += dt;
    if (this.phase === 'intro') {
      if (this.phaseT >= INTRO) this.go();
    } else if (this.phase === 'run') {
      if (prev < VISIBLE && this.phaseT >= VISIBLE) sfx.whoosh();
      else if (this.phaseT < VISIBLE && Math.floor(prev) !== Math.floor(this.phaseT)) sfx.tick();
      if (this.players.every((p) => this.stops.has(p.pid)) || this.phaseT > this.target + 5) {
        for (const p of this.players) {
          if (!this.stops.has(p.pid)) net.setCtrl(p.pid, { mode: 'wait', icon: '⌛', title: 'Lejárt az idő!', text: 'Ebben a körben nem nyomtál.' });
        }
        this.phase = 'reveal';
        this.phaseT = 0;
        this.score();
      }
    } else if (this.phase === 'reveal' && this.phaseT >= REVEAL) {
      this.next();
    }
  }

  ranking() {
    return this.players.map((p) => ({
      pid: p.pid,
      score: this.pts.get(p.pid) * 1000 - Math.round(this.err.get(p.pid) * 10),
      label: `${this.pts.get(p.pid)} pont`,
    })).sort((a, b) => b.score - a.score);
  }

  drawClock(c, x, y, r) {
    const run = this.phase === 'run';
    const shown = this.phase === 'intro' || (run && this.phaseT < VISIBLE);
    const fade = run ? Math.max(0, Math.min(1, (this.phaseT - VISIBLE + 0.5) / 0.5)) : 0;
    c.save();
    c.beginPath(); c.arc(x, y, r + 14, 0, Math.PI * 2);
    c.fillStyle = '#2b1a5c'; c.fill();
    c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2);
    c.fillStyle = '#fdfaff'; c.fill();
    for (let i = 0; i < 60; i++) {
      const a = (i / 60) * Math.PI * 2 - Math.PI / 2;
      const l = i % 5 === 0 ? 18 : 8;
      c.strokeStyle = i % 5 === 0 ? '#2b1a5c' : '#b8acec';
      c.lineWidth = i % 5 === 0 ? 5 : 2;
      c.beginPath();
      c.moveTo(x + Math.cos(a) * (r - 6), y + Math.sin(a) * (r - 6));
      c.lineTo(x + Math.cos(a) * (r - 6 - l), y + Math.sin(a) * (r - 6 - l));
      c.stroke();
    }
    // célpont jelölése a számlapon
    const ta = (this.target / 60) * Math.PI * 2 - Math.PI / 2;
    c.fillStyle = '#ffd43b';
    c.beginPath(); c.arc(x + Math.cos(ta) * (r - 40), y + Math.sin(ta) * (r - 40), 12, 0, Math.PI * 2); c.fill();
    const tt = run ? this.phaseT : this.phase === 'reveal' ? this.target : 0;
    if (shown || this.phase === 'reveal') {
      const a = (tt / 60) * Math.PI * 2 - Math.PI / 2;
      c.strokeStyle = '#e11d48';
      c.lineWidth = 7;
      c.lineCap = 'round';
      c.beginPath(); c.moveTo(x, y); c.lineTo(x + Math.cos(a) * (r - 24), y + Math.sin(a) * (r - 24)); c.stroke();
    }
    c.fillStyle = '#2b1a5c';
    c.beginPath(); c.arc(x, y, 10, 0, Math.PI * 2); c.fill();
    if (run && fade > 0) {
      c.globalAlpha = fade;
      c.beginPath(); c.arc(x, y, r + 2, 0, Math.PI * 2);
      c.fillStyle = '#3b1f7a'; c.fill();
      text(c, '?', x, y + 8, { size: 170, color: '#ffd43b', stroke: '#1b1036', sw: 10 });
      c.globalAlpha = 1;
    }
    c.restore();
    if (shown) text(c, tt.toFixed(1), x, y + r + 50, { size: 44, color: '#fff', stroke: '#1b1036', sw: 7 });
  }

  draw(c) {
    vgrad(c, '#2a1660', '#0b0622');
    text(c, `${Math.max(1, Math.min(this.round, TARGETS.length))}. / ${TARGETS.length} kör`, 100, 36, { size: 22, color: '#ddd' });
    panel(c, 390, 14, 500, 70, { r: 35, fill: 'rgba(0,0,0,.45)' });
    text(c, `🎯 Állítsd meg pontosan ${this.target} mp-nél!`, 640, 50, { size: 30, maxW: 470 });

    if (this.phase === 'reveal') this.drawReveal(c);
    else {
      this.drawClock(c, 640, 290, 165);
      if (this.phase === 'run' && this.phaseT >= VISIBLE) {
        text(c, 'Számolj magadban… 🤫', 640, 515, { size: 30, color: '#e5dbff', weight: 600 });
      } else if (this.phase === 'intro') {
        text(c, 'Az óra 3 mp után eltűnik!', 640, 515, { size: 28, color: '#e5dbff', weight: 600 });
      }
      const n = this.players.length;
      const gap = Math.min(150, 1180 / n);
      this.players.forEach((p, i) => {
        const x = 640 + (i - (n - 1) / 2) * gap;
        const done = this.stops.has(p.pid);
        avatar(c, p, x, 600 - (done ? 6 : 0), 28, { alpha: done ? 1 : 0.7 });
        text(c, p.name, x, 644, { size: 16, maxW: gap - 6 });
        text(c, done ? '✋ STOP' : `${this.pts.get(p.pid)} p`, x, 672, { size: 18, color: done ? '#69db7c' : '#ffd43b' });
      });
    }
  }

  drawReveal(c) {
    // vízszintes idővonal: a cél középen, a játékosok megállási pontjai körülötte
    const x0 = 140, x1 = 1140, y = 230;
    const span = Math.max(3, ...this.players.map((p) => Math.abs((this.stops.get(p.pid) ?? this.target) - this.target) + 0.5));
    const k = Math.min(1, this.phaseT / 1.2);
    const toX = (v) => 640 + ((v - this.target) / span) * ((x1 - x0) / 2);
    rr(c, x0, y - 8, x1 - x0, 16, 8);
    c.fillStyle = 'rgba(255,255,255,.15)'; c.fill();
    c.fillStyle = '#ffd43b';
    c.fillRect(638, y - 40, 4, 80);
    text(c, `${this.target}.00 mp`, 640, y - 58, { size: 26, color: '#ffd43b' });
    text(c, '◀ korán', x0 + 50, y - 28, { size: 18, color: '#b8acec' });
    text(c, 'későn ▶', x1 - 50, y - 28, { size: 18, color: '#b8acec' });

    const rows = [...this.players].sort((a, b) => (this.gained.get(b.pid) ?? -1) - (this.gained.get(a.pid) ?? -1));
    const n = rows.length;
    rows.forEach((p, i) => {
      const s = this.stops.get(p.pid);
      if (s != null) {
        const px = 640 + (toX(s) - 640) * k;
        c.strokeStyle = p.color;
        c.lineWidth = 3;
        c.beginPath(); c.moveTo(px, y); c.lineTo(px, y + 22 + (i % 3) * 12); c.stroke();
        avatar(c, p, px, y + 34 + (i % 3) * 12, 13, { shadow: false });
      }
      const ry = 330 + i * Math.min(46, 340 / n);
      const g = this.gained.get(p.pid);
      panel(c, 300, ry - 20, 680, 40, { r: 14, fill: 'rgba(255,255,255,.07)', stroke: p.color, shadow: false, lw: 2 });
      avatar(c, p, 326, ry, 15, { shadow: false });
      text(c, p.name, 352, ry, { size: 20, align: 'left', maxW: 220 });
      if (s == null) text(c, 'nem nyomott', 700, ry, { size: 20, color: '#ff8787' });
      else {
        const d = s - this.target;
        text(c, `${s.toFixed(2)} mp`, 640, ry, { size: 22 });
        text(c, `${d >= 0 ? '+' : '−'}${Math.abs(d).toFixed(2)}`, 790, ry, { size: 20, color: Math.abs(d) < 0.3 ? '#69db7c' : Math.abs(d) < 1 ? '#ffd43b' : '#ff8787' });
      }
      if (g) text(c, `+${g} p`, 950, ry, { size: 22, color: '#ffd43b', align: 'right' });
    });
    if (this.best) {
      const pulse = 1 + Math.sin(time * 6) * 0.04;
      c.save();
      c.translate(640, 125);
      c.scale(pulse, pulse);
      text(c, `🏅 ${this.best.name} a legpontosabb!`, 0, 0, { size: 34, stroke: shade(this.best.color, -0.6), sw: 7 });
      c.restore();
    }
  }
}

export default {
  id: 'blindtimer', name: 'Vak időzítő', icon: '⏱️', color: '#f59e0b',
  tagline: 'Mennyi az a 10 másodperc?',
  desc: 'Elindul egy óra, de 3 másodperc múlva eltűnik! Magadban számolva nyomd meg a gombot pontosan a megadott időnél (10, 7, majd 13 mp). A legpontosabb 3 pontot kap, a második 2-t, a harmadik 1-et. Ha 0,1 mp-en belül vagy, +1 bónusz jár.',
  controls: 'Figyeld az órát, aztán számolj magadban, és nyomd meg a STOP gombot, amikor szerinted letelt az idő. Körönként egyszer nyomhatsz.',
  layout: () => ({ mode: 'wait', icon: '⏱️', title: 'Vak időzítő', text: 'Figyeld az órát!' }),
  create: (players) => new BlindTimer(players),
};
