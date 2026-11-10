// Színmemória – ismételd meg a felvillanó sorozatot
import { W, H, text, avatar, rr, burst, randi, rand, vgrad, time, shade, panel } from '../engine.js';
import { sfx } from '../audio.js';
import * as net from '../net.js';

export const PADS = [
  { color: '#ff4d6d', shape: '▲' },
  { color: '#4dabf7', shape: '●' },
  { color: '#51cf66', shape: '■' },
  { color: '#ffd43b', shape: '★' },
];
const STEP = 0.6, LIT = 0.42, MAXLEN = 14;

class Memory {
  constructor(players) {
    this.players = players;
    this.t = 0;
    this.finished = false;
    this.seq = [randi(0, 3), randi(0, 3), randi(0, 3)];
    this.alive = new Set(players.map((p) => p.pid));
    this.st = new Map(players.map((p) => [p.pid, { idx: 0, done: false, failed: false, best: 0, total: 0, outAt: null, botT: 0 }]));
    this.phase = 'pre';
    this.lit = null;
    this.flash = new Map();
  }

  start() { this.showSeq(); }

  showSeq() {
    this.phase = 'show';
    this.phaseT = 0;
    this.lastShown = -1;
    for (const p of this.players) {
      if (this.alive.has(p.pid)) net.setCtrl(p.pid, { mode: 'pads', enabled: false, pads: PADS, title: 'Figyeld a képernyőt! 👀' });
      const s = this.st.get(p.pid);
      s.idx = 0;
      s.done = false;
    }
  }

  startInput() {
    this.phase = 'input';
    this.phaseT = 0;
    this.limit = 3 + this.seq.length * 0.75;
    for (const p of this.players) {
      if (this.alive.has(p.pid)) net.setCtrl(p.pid, { mode: 'pads', enabled: true, pads: PADS, title: `Ismételd! (${this.seq.length} szín)` });
    }
  }

  input(p, msg) {
    if (msg.t !== 'pad' || this.phase !== 'input' || !this.alive.has(p.pid)) return;
    const s = this.st.get(p.pid);
    if (s.done) return;
    const v = Number(msg.v);
    if (v === this.seq[s.idx]) {
      s.idx++;
      sfx.padSoft(v);
      this.flash.set(p.pid, { v, t: this.t });
      if (s.idx === this.seq.length) {
        s.done = true;
        s.best = this.seq.length;
        s.total += this.phaseT;
        net.vibrate(p.pid, 60);
        net.setCtrl(p.pid, { mode: 'wait', icon: '✅', title: 'Helyes!', text: 'Várj a következő sorozatra…' });
      }
    } else this.fail(p);
  }

  fail(p) {
    const s = this.st.get(p.pid);
    if (s.failed) return;
    s.failed = true;
    s.outAt = this.seq.length;
    this.alive.delete(p.pid);
    sfx.bad();
    net.vibrate(p.pid, [200, 80, 200]);
    net.setCtrl(p.pid, { mode: 'wait', icon: '❌', title: 'Hibáztál!', text: `Elért szint: ${s.best} szín` });
  }

  bot(p, dt) {
    if (this.phase !== 'input' || !this.alive.has(p.pid)) return;
    const s = this.st.get(p.pid);
    if (s.done) return;
    s.botT -= dt;
    if (s.botT > 0) return;
    s.botT = rand(0.3, 0.6);
    const errChance = 0.03 + Math.max(0, this.seq.length - 4) * 0.035;
    const right = this.seq[s.idx];
    this.input(p, { t: 'pad', v: Math.random() < errChance ? (right + randi(1, 3)) % 4 : right });
  }

  update(dt) {
    this.t += dt;
    if (this.phase === 'pre') return;
    this.phaseT += dt;
    if (this.phase === 'show') {
      const i = Math.floor((this.phaseT - 0.6) / STEP);
      const inLit = i >= 0 && i < this.seq.length && (this.phaseT - 0.6) - i * STEP < LIT;
      this.lit = inLit ? this.seq[i] : null;
      if (inLit && i !== this.lastShown) { this.lastShown = i; sfx.pad(this.seq[i]); }
      if (this.phaseT > 0.6 + this.seq.length * STEP + 0.2) { this.lit = null; this.startInput(); }
    } else if (this.phase === 'input') {
      const aliveP = this.players.filter((p) => this.alive.has(p.pid));
      if (aliveP.every((p) => this.st.get(p.pid).done) || this.phaseT >= this.limit) {
        for (const p of aliveP) if (!this.st.get(p.pid).done) this.fail(p);
        this.phase = 'check';
        this.phaseT = 0;
        if (this.alive.size) sfx.coin();
      }
    } else if (this.phase === 'check' && this.phaseT > 1.6) {
      // vége, ha mindenki kiesett, vagy már csak egy ember maradt (ő a győztes)
      if (this.alive.size === 0 || this.seq.length >= MAXLEN || (this.players.length > 1 && this.alive.size === 1)) {
        this.finished = true;
        return;
      }
      this.seq.push(randi(0, 3));
      this.showSeq();
    }
  }

  ranking() {
    return this.players.map((p) => {
      const s = this.st.get(p.pid);
      return { pid: p.pid, score: s.best * 1000 - Math.round(s.total * 10), label: `${s.best} szín` };
    }).sort((a, b) => b.score - a.score);
  }

  draw(c) {
    vgrad(c, '#1e1b4b', '#0b0920');
    const label = { pre: 'Készülj!', show: 'Figyeld a sorrendet! 👀', input: 'Most te jössz – a telefonodon!', check: this.alive.size ? 'Szuper! Jön a következő…' : 'Mindenki kiesett!' }[this.phase];
    text(c, label, 640, 50, { size: 34, stroke: '#000', sw: 6 });
    text(c, `Sorozat hossza: ${this.seq.length}`, 640, 92, { size: 22, color: '#c5bdf2', weight: 600 });
    if (this.phase === 'input') {
      const k = Math.max(0, 1 - this.phaseT / this.limit);
      rr(c, 440, 112, 400, 10, 5);
      c.fillStyle = 'rgba(255,255,255,.15)'; c.fill();
      rr(c, 440, 112, 400 * k, 10, 5);
      c.fillStyle = k < 0.3 ? '#ff6b6b' : '#69db7c'; c.fill();
    }
    // 2x2 párna
    const S = 150, G = 18, x0 = 640 - S - G / 2, y0 = 140;
    PADS.forEach((pd, i) => {
      const x = x0 + (i % 2) * (S + G), y = y0 + Math.floor(i / 2) * (S + G);
      const on = this.lit === i;
      c.save();
      if (on) { c.shadowColor = pd.color; c.shadowBlur = 60; }
      rr(c, x, y, S, S, 30);
      c.fillStyle = on ? shade(pd.color, 0.35) : shade(pd.color, -0.55);
      c.fill();
      c.restore();
      c.lineWidth = 5;
      c.strokeStyle = on ? '#fff' : shade(pd.color, -0.2);
      rr(c, x, y, S, S, 30);
      c.stroke();
      text(c, pd.shape, x + S / 2, y + S / 2 + 4, { size: 64, color: on ? '#fff' : shade(pd.color, -0.25) });
    });

    // játékosok
    const n = this.players.length;
    const gap = Math.min(155, 1200 / n);
    this.players.forEach((p, i) => {
      const x = 640 + (i - (n - 1) / 2) * gap;
      const s = this.st.get(p.pid);
      const out = !this.alive.has(p.pid);
      const f = this.flash.get(p.pid);
      const bounce = f && this.t - f.t < 0.2 ? 6 : 0;
      avatar(c, p, x, 540 - bounce, 30, { gray: out });
      text(c, p.name, x, 588, { size: 16, maxW: gap - 6 });
      if (out) text(c, `❌ ${s.best}`, x, 618, { size: 20, color: '#ff8787' });
      else if (this.phase === 'input' || s.done) {
        const len = this.seq.length;
        const w = Math.min(gap - 16, len * 12);
        for (let k = 0; k < len; k++) {
          c.fillStyle = k < s.idx ? PADS[this.seq[k]].color : 'rgba(255,255,255,.2)';
          c.beginPath();
          c.arc(x - w / 2 + (k + 0.5) * (w / len), 618, Math.min(5, w / len / 2 - 0.5), 0, Math.PI * 2);
          c.fill();
        }
        if (s.done) text(c, '✔', x + 26, 518, { size: 24, color: '#69db7c', stroke: '#000', sw: 4 });
      } else text(c, `🧠 ${s.best}`, x, 618, { size: 18, color: '#ffd43b' });
    });
  }
}

export default {
  id: 'memory', name: 'Színmemória', icon: '🧠', color: '#4dabf7',
  tagline: 'Ki bírja a legtovább?',
  desc: 'A nagy képernyőn felvillan egy színsorozat. Ismételd meg pontosan a telefonodon! A sorozat minden körben eggyel hosszabb, és aki hibázik, kiesik.',
  controls: 'Figyeld a képernyőt, aztán nyomd meg a színes gombokat ugyanabban a sorrendben.',
  layout: (p) => ({ mode: 'pads', enabled: false, pads: PADS, title: 'Figyeld a képernyőt! 👀' }),
  create: (players) => new Memory(players),
};
