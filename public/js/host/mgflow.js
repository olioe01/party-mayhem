// Minijáték körítés: sorsolás -> leírás + "kész" -> visszaszámlálás -> játék -> eredmény

import { Scene, W, H, text, panel, avatar, emoji, rr, vgrad, burst, confetti, shade, ease, time, pick, setScene, lerp } from './engine.js';
import { G, byPid, addCoins } from './state.js';
import * as net from './net.js';
import { sfx, music } from './audio.js';
import { MINIGAMES } from './minigames/index.js';
import { afterMinigame } from './game.js';

const AWARDS = [10, 6, 3, 1];
const MEDALS = ['🥇', '🥈', '🥉'];

function mgBackground(c, hue = 265) {
  vgrad(c, `hsl(${hue},60%,22%)`, `hsl(${hue + 30},65%,9%)`);
  c.save();
  c.globalAlpha = 0.07;
  for (let i = 0; i < 14; i++) {
    const x = ((i * 137 + time * 30) % (W + 200)) - 100;
    c.fillStyle = '#fff';
    c.beginPath();
    c.arc(x, (i * 211) % H, 40 + (i % 4) * 30, 0, Math.PI * 2);
    c.fill();
  }
  c.restore();
}

// ---------------------------------------------------------------- sorsolás
export class MgSelectScene extends Scene {
  constructor(force = null) { super(); this.force = force; }

  enter() {
    G.phase = 'mg';
    music('mg');
    const pool = MINIGAMES.filter((m) => !G.recentMg.includes(m.id));
    this.choice = (this.force && MINIGAMES.find((m) => m.id === this.force)) || pick(pool.length ? pool : MINIGAMES);
    G.recentMg = [...G.recentMg, this.choice.id].slice(-Math.min(3, MINIGAMES.length - 1));
    this.strip = [];
    for (let i = 0; i < 26; i++) this.strip.push(MINIGAMES[i % MINIGAMES.length]);
    this.strip.push(this.choice);
    for (let i = 0; i < 3; i++) this.strip.push(MINIGAMES[(i + 2) % MINIGAMES.length]);
    this.target = 26;
    this.dur = 3.4;
    this.lastIdx = -1;
    this.landed = false;
    for (const p of G.players) net.setCtrl(p.pid, { mode: 'wait', icon: '🎰', title: 'Minijáték sorsolás…', text: 'Nézd a nagy képernyőt!' });
    this.after(this.dur + 1.6, () => setScene(new MgIntroScene(this.choice)));
  }

  pos() { return ease.outCubic(Math.min(1, this.t / this.dur)) * this.target; }

  update() {
    const i = Math.round(this.pos());
    if (i !== this.lastIdx) { this.lastIdx = i; sfx.tick(); }
    if (!this.landed && this.t >= this.dur) {
      this.landed = true;
      sfx.fanfare();
      burst(640, 360, { n: 70, speed: 520 });
    }
  }

  draw(c) {
    mgBackground(c);
    text(c, '🎰 MINIJÁTÉK SORSOLÁS 🎰', 640, 110, { size: 48, stroke: '#1b1036', sw: 10, color: '#ffd43b' });
    const pos = this.pos();
    const spacing = 300;
    for (let i = 0; i < this.strip.length; i++) {
      const dx = (i - pos) * spacing;
      if (Math.abs(dx) > 800) continue;
      const m = this.strip[i];
      const center = Math.max(0, 1 - Math.abs(dx) / spacing);
      const pulse = this.landed && i === this.target ? 1 + Math.sin(time * 8) * 0.04 : 1;
      const s = (0.75 + center * 0.3) * pulse;
      c.save();
      c.translate(640 + dx, 380);
      c.scale(s, s);
      c.globalAlpha = 0.45 + center * 0.55;
      panel(c, -125, -150, 250, 300, { fill: shade(m.color, -0.45), stroke: center > 0.5 ? '#ffd43b' : m.color, lw: 6, r: 28 });
      emoji(c, m.icon, 0, -50, 100);
      text(c, m.name, 0, 70, { size: 28, maxW: 225 });
      c.restore();
    }
    text(c, '▼', 640, 205, { size: 40, color: '#ffd43b' });
    if (this.landed) text(c, this.choice.name.toUpperCase(), 640, 610, { size: 54, stroke: '#1b1036', sw: 10, color: '#fff' });
  }
}

// ---------------------------------------------------------------- leírás
export class MgIntroScene extends Scene {
  constructor(mg) { super(); this.mg = mg; }

  enter() {
    this.ready = new Set();
    this.limit = 30;
    for (const p of G.players) {
      net.setCtrl(p.pid, { mode: 'ready', icon: this.mg.icon, title: this.mg.name, text: this.mg.controls });
    }
    this.after(this.limit, () => this.go());
  }

  input(pid, msg) {
    if (msg.t !== 'ready' || this.ready.has(pid) || !byPid(pid)) return;
    this.ready.add(pid);
    sfx.pop();
    net.setCtrl(pid, { mode: 'wait', icon: '✅', title: 'Kész vagy!', text: 'Várakozás a többiekre…' });
    if (G.players.every((p) => this.ready.has(p.pid) || (!p.connected && !p.isBot))) this.after(0.7, () => this.go());
  }

  playersChanged() {
    if (G.players.every((p) => this.ready.has(p.pid) || (!p.connected && !p.isBot))) this.after(0.7, () => this.go());
  }

  key(e) { if (e.key === 'Enter') this.go(); }

  go() {
    if (this.started) return;
    this.started = true;
    setScene(new MgPlayScene(this.mg));
  }

  draw(c) {
    const m = this.mg;
    mgBackground(c);
    const s = ease.outBack(Math.min(1, this.t * 2.5));
    c.save();
    c.translate(640, 300);
    c.scale(s, s);
    panel(c, -470, -250, 940, 470, { fill: 'rgba(20,12,48,.92)', stroke: m.color, lw: 6, r: 32 });
    emoji(c, m.icon, -340, -150, 110);
    text(c, m.name, -250, -170, { size: 58, align: 'left', color: m.color, stroke: '#1b1036', sw: 8 });
    text(c, m.tagline || '', -250, -115, { size: 24, align: 'left', color: '#cfc6f5', weight: 600 });
    wrap(c, m.desc, -420, -45, 840, 30, { size: 27, color: '#fff', weight: 600 });
    panel(c, -420, 80, 840, 110, { fill: 'rgba(255,255,255,.08)', stroke: null, r: 20, shadow: false });
    text(c, '📱 Irányítás', -395, 108, { size: 22, align: 'left', color: '#ffd43b' });
    wrap(c, m.controls, -395, 145, 790, 28, { size: 24, color: '#fff', weight: 600 });
    c.restore();

    // kész jelzők
    const n = G.players.length;
    const gap = Math.min(130, 1150 / n);
    G.players.forEach((p, i) => {
      const x = 640 + (i - (n - 1) / 2) * gap;
      const r = this.ready.has(p.pid);
      avatar(c, p, x, 600 - (r ? Math.abs(Math.sin(time * 5 + i)) * 8 : 0), 30, { alpha: r ? 1 : 0.5 });
      text(c, r ? '✔' : '…', x + 26, 578, { size: 26, color: r ? '#69db7c' : '#aaa', stroke: '#1b1036', sw: 5 });
      text(c, p.name, x, 652, { size: 17, maxW: gap - 8 });
    });
    const left = Math.max(0, Math.ceil(this.limit - this.t));
    text(c, `Nyomd meg a telefonodon a „Kész” gombot!  (automatikus indulás: ${left} mp)`, 640, 695, { size: 18, color: '#b8acec', weight: 600 });
  }
}

export function wrap(c, str, x, y, maxW, lh, o) {
  c.font = `${o.weight || 700} ${o.size}px Fredoka, sans-serif`;
  const words = str.split(' ');
  let line = '';
  let yy = y;
  for (const w of words) {
    const test = line ? `${line} ${w}` : w;
    if (c.measureText(test).width > maxW && line) {
      text(c, line, x, yy, { ...o, align: 'left' });
      line = w;
      yy += lh;
    } else line = test;
  }
  if (line) text(c, line, x, yy, { ...o, align: 'left' });
}

// ---------------------------------------------------------------- játék
export class MgPlayScene extends Scene {
  constructor(mg) { super(); this.mg = mg; }

  enter() {
    this.players = [...G.players];
    this.inst = this.mg.create(this.players);
    this.phase = 'count';
    this.countT = 3;
    this.lastCount = 4;
    for (const p of this.players) net.setCtrl(p.pid, { mode: 'wait', icon: this.mg.icon, title: 'Készülj…', text: 'Mindjárt indul!' });
  }

  update(dt) {
    if (this.phase === 'count') {
      this.countT -= dt;
      const n = Math.ceil(this.countT);
      if (n !== this.lastCount && n > 0) { this.lastCount = n; sfx.count(); }
      if (this.countT <= 0) {
        this.phase = 'play';
        this.goT = this.t;
        sfx.countGo();
        for (const p of this.players) net.setCtrl(p.pid, this.mg.layout(p));
        this.inst.start?.();
      }
      this.inst.idle?.(dt);
    } else if (this.phase === 'play') {
      for (const p of this.players) if (net.isAuto(p.pid)) this.inst.bot?.(p, dt);
      this.inst.update(dt);
      if (this.inst.finished) {
        this.phase = 'end';
        this.endT = this.t;
        sfx.win();
        for (const p of this.players) net.setCtrl(p.pid, { mode: 'wait', icon: '🏁', title: 'VÉGE!', text: 'Mindjárt jönnek az eredmények…' });
        this.after(2, () => setScene(new MgResultScene(this.mg, this.inst.ranking())));
      }
    } else {
      this.inst.idle?.(dt);
    }
  }

  input(pid, msg) {
    if (this.phase !== 'play') return;
    const p = byPid(pid);
    if (p && this.players.includes(p)) this.inst.input(p, msg);
  }

  draw(c) {
    this.inst.draw(c);
    if (this.phase === 'count') {
      c.fillStyle = 'rgba(10,5,30,.55)';
      c.fillRect(0, 0, W, H);
      const n = Math.max(1, Math.ceil(this.countT));
      const k = 1 - (this.countT - Math.floor(this.countT));
      const s = 1.6 - ease.outCubic(Math.min(1, k * 1.5)) * 0.6;
      text(c, this.mg.name, 640, 180, { size: 44, color: this.mg.color, stroke: '#1b1036', sw: 8 });
      c.save();
      c.translate(640, 380);
      c.scale(s, s);
      text(c, String(n), 0, 0, { size: 200, color: '#fff', stroke: '#1b1036', sw: 14 });
      c.restore();
    } else if (this.phase === 'play' && this.t - this.goT < 0.9) {
      const k = (this.t - this.goT) / 0.9;
      c.save();
      c.globalAlpha = 1 - k;
      c.translate(640, 360);
      c.scale(1 + k, 1 + k);
      text(c, 'RAJT!', 0, 0, { size: 150, color: '#ffd43b', stroke: '#1b1036', sw: 14 });
      c.restore();
    } else if (this.phase === 'end') {
      c.fillStyle = 'rgba(10,5,30,.35)';
      c.fillRect(0, 0, W, H);
      const s = ease.outBack(Math.min(1, (this.t - this.endT) * 3));
      c.save();
      c.translate(640, 360);
      c.scale(s, s);
      text(c, 'VÉGE!', 0, 0, { size: 150, color: '#fff', stroke: '#e11d48', sw: 16 });
      c.restore();
    }
  }
}

// ---------------------------------------------------------------- eredmény
export class MgResultScene extends Scene {
  constructor(mg, ranking) { super(); this.mg = mg; this.ranking = ranking; }

  enter() {
    let place = 0;
    this.rows = this.ranking.map((r, i, arr) => {
      if (i === 0 || r.score !== arr[i - 1].score) place = i;
      const p = byPid(r.pid);
      const award = AWARDS[place] ?? 0;
      return { p, place, award, label: r.label, score: r.score };
    }).filter((r) => r.p);
    for (const r of this.rows) {
      addCoins(r.p, r.award);
      r.p.stats.mgCoins += r.award;
      if (r.place === 0) r.p.stats.mgWins++;
      net.setCtrl(r.p.pid, {
        mode: 'result', icon: MEDALS[r.place] || '🎮',
        title: `${r.place + 1}. hely`, text: r.award ? `+${r.award} 🪙` : 'Most nem jött össze – legközelebb!',
      });
      net.vibrate(r.p.pid, r.place === 0 ? [100, 50, 100, 50, 300] : 80);
    }
    this.after(0.3, () => { sfx.fanfare(); confetti(90); });
    this.after(3 + this.rows.length * 0.35, () => this.next());
  }

  key(e) { if (e.key === 'Enter') this.next(); }

  next() {
    if (this.done) return;
    this.done = true;
    afterMinigame();
  }

  draw(c) {
    mgBackground(c, 200);
    text(c, `${this.mg.icon} ${this.mg.name}`, 640, 70, { size: 46, color: this.mg.color, stroke: '#1b1036', sw: 8 });
    text(c, 'Eredmények', 640, 118, { size: 26, color: '#cfc6f5', weight: 600 });
    const n = this.rows.length;
    const rowH = Math.min(70, 520 / n);
    this.rows.forEach((r, i) => {
      const appear = Math.min(1, Math.max(0, (this.t - 0.3 - i * 0.3) * 3));
      if (appear <= 0) return;
      const y = 160 + i * (rowH + 6);
      const x = lerp(-700, 0, ease.outBack(appear));
      c.save();
      c.translate(x, 0);
      panel(c, 250, y, 780, rowH, { fill: r.place === 0 ? 'rgba(255,212,59,.22)' : 'rgba(255,255,255,.08)', stroke: r.place === 0 ? '#ffd43b' : r.p.color, r: 18 });
      const cy = y + rowH / 2;
      if (MEDALS[r.place]) emoji(c, MEDALS[r.place], 295, cy, rowH * 0.6);
      else text(c, `${r.place + 1}.`, 295, cy, { size: 28 });
      avatar(c, r.p, 355, cy, rowH * 0.36, { shadow: false });
      text(c, r.p.name, 395, cy, { size: 28, align: 'left', maxW: 260 });
      text(c, r.label, 760, cy, { size: 24, color: '#d0c8f0', weight: 600 });
      text(c, r.award ? `+${r.award} 🪙` : '–', 990, cy, { size: 30, color: '#ffd43b', align: 'right' });
      c.restore();
    });
    text(c, 'ENTER = tovább', 1250, 700, { size: 15, color: '#8f84c4', align: 'right', weight: 400 });
  }
}
