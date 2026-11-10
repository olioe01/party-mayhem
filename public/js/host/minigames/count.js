// Számold meg! – hány darab volt a mozgó tömegben?
import { W, H, text, avatar, emoji, burst, randi, rand, vgrad, time, pick, shuffle, panel, ease } from '../engine.js';
import { sfx } from '../audio.js';
import { timerHud } from './common.js';
import * as net from '../net.js';

const ROUNDS = 3;
const SHOW = 6.5, INPUT = 12, REVEAL = 4.5;
const THEMES = [
  { target: '🐟', decoys: ['🐠', '🐡'], bg: ['#0b7285', '#0b3d5c'] },
  { target: '🍎', decoys: ['🍅', '🍒', '🍓'], bg: ['#2b8a3e', '#0b3d1c'] },
  { target: '🐑', decoys: ['🐐', '🐄'], bg: ['#5c940d', '#2b4005'] },
  { target: '⭐', decoys: ['🌟', '✨', '💫'], bg: ['#1c1652', '#05041a'] },
  { target: '🎈', decoys: ['🎀', '🎁'], bg: ['#c2255c', '#4a0d26'] },
  { target: '🐞', decoys: ['🐝', '🦋', '🐛'], bg: ['#66a80f', '#233d04'] },
];

class Count {
  constructor(players) {
    this.players = players;
    this.t = 0;
    this.finished = false;
    this.round = 0;
    this.pts = new Map(players.map((p) => [p.pid, 0]));
    this.themes = shuffle(THEMES);
    this.phase = 'pre';
    this.setupRound();
  }

  start() { this.round = 0; this.next(); }

  setupRound() {
    const th = this.themes[this.round % this.themes.length];
    this.theme = th;
    this.answer = randi(7 + this.round * 3, 13 + this.round * 5);
    const decoys = randi(12 + this.round * 4, 18 + this.round * 6);
    this.objs = shuffle([
      ...Array.from({ length: this.answer }, () => th.target),
      ...Array.from({ length: decoys }, () => pick(th.decoys)),
    ]).map((e) => {
      const a = rand(0, Math.PI * 2), sp = rand(50, 150) + this.round * 25;
      return { e, x: rand(120, 1160), y: rand(150, 560), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, s: rand(38, 50), w: rand(0, 6) };
    });
  }

  next() {
    this.round++;
    if (this.round > ROUNDS) { this.finished = true; return; }
    this.setupRound();
    this.phase = 'show';
    this.phaseT = 0;
    this.guess = new Map();
    this.revealN = 0;
    for (const p of this.players) net.setCtrl(p.pid, { mode: 'wait', icon: this.theme.target, title: `Számold: ${this.theme.target}`, text: 'Figyeld a képernyőt!' });
  }

  input(p, msg) {
    if (msg.t !== 'num' || this.phase !== 'input' || this.guess.has(p.pid)) return;
    const v = Math.max(0, Math.min(999, Math.round(Number(msg.v) || 0)));
    this.guess.set(p.pid, { v, at: this.phaseT });
    sfx.pop();
    net.setCtrl(p.pid, { mode: 'wait', icon: '📨', title: `Tipped: ${v}`, text: 'Várjuk a többieket…' });
  }

  bot(p) {
    if (this.phase !== 'input' || this.guess.has(p.pid)) return;
    const when = p._botWhen ?? (p._botWhen = rand(2, 7));
    if (this.phaseT >= when) {
      p._botWhen = undefined;
      const err = pick([0, 0, 0, 1, -1, 1, -1, 2, -2, 3]);
      this.input(p, { t: 'num', v: Math.max(0, this.answer + err) });
    }
  }

  score(g) {
    const d = Math.abs(g - this.answer);
    return d === 0 ? 3 : d === 1 ? 2 : d === 2 ? 1 : 0;
  }

  update(dt) {
    this.t += dt;
    const moving = this.phase === 'show' || this.phase === 'pre';
    if (moving) {
      for (const o of this.objs) {
        o.x += o.vx * dt; o.y += o.vy * dt;
        if (o.x < 60 || o.x > 1220) { o.vx *= -1; o.x = Math.max(60, Math.min(1220, o.x)); }
        if (o.y < 140 || o.y > 580) { o.vy *= -1; o.y = Math.max(140, Math.min(580, o.y)); }
      }
    }
    if (this.phase === 'pre') return;
    this.phaseT += dt;
    if (this.phase === 'show' && this.phaseT >= SHOW) {
      this.phase = 'input';
      this.phaseT = 0;
      sfx.select();
      for (const p of this.players) net.setCtrl(p.pid, { mode: 'number', title: `Hány ${this.theme.target} volt?` });
    } else if (this.phase === 'input' && (this.phaseT >= INPUT || this.players.every((p) => this.guess.has(p.pid)))) {
      this.phase = 'reveal';
      this.phaseT = 0;
      this.targets = this.objs.filter((o) => o.e === this.theme.target);
      for (const p of this.players) net.setCtrl(p.pid, { mode: 'wait', icon: '🔍', title: 'Lássuk…', text: 'Nézd a nagy képernyőt!' });
    } else if (this.phase === 'reveal') {
      const n = Math.min(this.answer, Math.floor(this.phaseT / (1.8 / this.answer)));
      if (n > this.revealN) {
        this.revealN = n;
        sfx.tick();
        if (n === this.answer) this.award();
      }
      if (this.phaseT >= 1.8 + REVEAL) this.next();
    }
  }

  award() {
    sfx.coin();
    let fastest = null;
    for (const p of this.players) {
      const g = this.guess.get(p.pid);
      if (!g) continue;
      const s = this.score(g.v);
      this.pts.set(p.pid, this.pts.get(p.pid) + s);
      if (s === 3 && (!fastest || g.at < fastest.at)) fastest = { p, at: g.at };
    }
    if (fastest) {
      this.pts.set(fastest.p.pid, this.pts.get(fastest.p.pid) + 1);
      this.fastest = fastest.p;
    } else this.fastest = null;
    burst(640, 360, { n: 50, speed: 500 });
  }

  ranking() {
    return this.players.map((p) => ({ pid: p.pid, score: this.pts.get(p.pid), label: `${this.pts.get(p.pid)} pont` })).sort((a, b) => b.score - a.score);
  }

  draw(c) {
    vgrad(c, this.theme.bg[0], this.theme.bg[1]);
    const showObjs = this.phase === 'show' || this.phase === 'reveal' || this.phase === 'pre';
    if (showObjs) {
      for (const o of this.objs) {
        const isT = o.e === this.theme.target;
        const dim = this.phase === 'reveal' && !isT;
        emoji(c, o.e, o.x, o.y + Math.sin(time * 3 + o.w) * 4, o.s, dim ? 0.25 : 1);
      }
      if (this.phase === 'reveal') {
        this.targets.slice(0, this.revealN).forEach((o, i) => {
          c.strokeStyle = '#ffd43b';
          c.lineWidth = 4;
          c.beginPath(); c.arc(o.x, o.y, o.s * 0.62, 0, Math.PI * 2); c.stroke();
          text(c, String(i + 1), o.x + o.s * 0.5, o.y - o.s * 0.5, { size: 18, color: '#fff', stroke: '#000', sw: 4 });
        });
      }
    } else {
      text(c, '❓', 640, 330, { size: 180 });
      text(c, 'Írd be a tipped a telefonodon!', 640, 470, { size: 38, stroke: '#000', sw: 6 });
    }

    panel(c, 330, 14, 620, 70, { r: 35, fill: 'rgba(0,0,0,.55)' });
    const head = this.phase === 'reveal' ? `Pontosan ${this.revealN} ${this.theme.target} volt!` : `Számold meg: ${this.theme.target}`;
    text(c, head, 640, 50, { size: 38 });
    text(c, `${Math.max(1, Math.min(this.round, ROUNDS))}. / ${ROUNDS} kör`, 90, 36, { size: 22, color: '#eee' });
    if (this.phase === 'show') timerHud(c, SHOW - this.phaseT, 1180, 40);
    if (this.phase === 'input') timerHud(c, INPUT - this.phaseT, 1180, 40);

    // játékosok
    const n = this.players.length;
    const gap = Math.min(150, 1200 / n);
    const done = this.phase === 'reveal' && this.revealN === this.answer;
    this.players.forEach((p, i) => {
      const x = 640 + (i - (n - 1) / 2) * gap;
      panel(c, x - gap / 2 + 6, 612, gap - 12, 100, { r: 18, fill: 'rgba(0,0,0,.5)', stroke: p.color, shadow: false });
      avatar(c, p, x, 646, 22, { shadow: false });
      const g = this.guess?.get(p.pid);
      if (this.phase === 'reveal' && g) {
        const sc = this.score(g.v);
        text(c, `${g.v}`, x - 18, 690, { size: 24 });
        if (done) text(c, sc ? `+${sc}${this.fastest === p ? '+1⚡' : ''}` : '✗', x + 26, 690, { size: 20, color: sc ? '#69db7c' : '#ff8787' });
      } else if (this.phase === 'input') {
        text(c, g ? '✔' : '…', x, 690, { size: 24, color: g ? '#69db7c' : '#bbb' });
      } else text(c, `${this.pts.get(p.pid)} p`, x, 690, { size: 20, color: '#ffd43b' });
    });
  }
}

export default {
  id: 'count', name: 'Számold meg!', icon: '🔢', color: '#b197fc',
  tagline: 'Sasszem kell hozzá',
  desc: 'A képernyőn rengeteg figura mozog össze-vissza. Számold meg, hány darab van a kért fajtából! Pontos tipp: 3 pont, 1-gyel mellé: 2, 2-vel: 1. A leggyorsabb pontos tipp +1 pontot ér.',
  controls: 'Figyeld a képernyőt, aztán írd be a számot a telefonod billentyűzetén, és nyomd meg a ✓-t. 3 kör.',
  layout: () => ({ mode: 'wait', icon: '👀', title: 'Számolj!', text: 'Figyeld a képernyőt!' }),
  create: (players) => new Count(players),
};
