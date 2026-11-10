// Villámreflex – aki leggyorsabban reagál a zöld jelre
import { W, H, text, avatar, emoji, burst, rand, vgrad, time, ease, panel } from '../engine.js';
import { sfx } from '../audio.js';
import * as net from '../net.js';

const ROUNDS = 5;

class Reaction {
  constructor(players) {
    this.players = players;
    this.t = 0;
    this.finished = false;
    this.pts = new Map(players.map((p) => [p.pid, 0]));
    this.times = new Map(players.map((p) => [p.pid, []]));
    this.round = 0;
    this.last = new Map();
    this.phase = 'pre';
    this.phaseT = 0;
    this.fouled = new Set();
    this.tapped = new Map();
    this.delay = 0;
  }

  start() { this.next(); }

  next() {
    this.round++;
    if (this.round > ROUNDS) { this.finished = true; return; }
    this.phase = 'wait';
    this.phaseT = 0;
    this.delay = rand(1.8, 4.2);
    this.fake = this.round >= 2 && Math.random() < 0.55 ? rand(0.8, this.delay - 0.6) : null;
    this.fakeShown = false;
    this.fouled = new Set();
    this.tapped = new Map();
    this.winner = null;
    this.botRt = new Map(this.players.map((p) => [p.pid, rand(0.27, 0.6)]));
    this.botFoul = new Map(this.players.map((p) => [p.pid, Math.random() < 0.12]));
    this.last.clear();
  }

  isFake() { return this.fake !== null && this.phaseT >= this.fake && this.phaseT < this.fake + 0.55; }

  input(p, msg) {
    if (msg.t !== 'tap') return;
    if (this.phase === 'wait') {
      if (this.fouled.has(p.pid)) return;
      this.fouled.add(p.pid);
      this.pts.set(p.pid, this.pts.get(p.pid) - 1);
      this.last.set(p.pid, 'KORAI!');
      sfx.bad();
      net.vibrate(p.pid, [150, 50, 150]);
    } else if (this.phase === 'go') {
      if (this.fouled.has(p.pid) || this.tapped.has(p.pid)) return;
      const rt = this.phaseT - this.delay;
      this.tapped.set(p.pid, rt);
      this.times.get(p.pid).push(rt);
      this.last.set(p.pid, `${Math.round(rt * 1000)} ms`);
      if (!this.winner) {
        this.winner = p;
        this.pts.set(p.pid, this.pts.get(p.pid) + 2);
        sfx.coin();
        net.vibrate(p.pid, 120);
      } else if (this.tapped.size === 2) {
        this.pts.set(p.pid, this.pts.get(p.pid) + 1);
      }
    }
  }

  bot(p, dt) {
    if (this.phase === 'wait' && this.isFake() && this.botFoul.get(p.pid)) {
      this.botFoul.set(p.pid, false);
      this.input(p, { t: 'tap' });
    }
    if (this.phase === 'go' && this.phaseT - this.delay >= this.botRt.get(p.pid)) this.input(p, { t: 'tap' });
  }

  update(dt) {
    this.t += dt;
    if (this.phase === 'pre') return;
    this.phaseT += dt;
    if (this.phase === 'wait') {
      if (this.isFake() && !this.fakeShown) { this.fakeShown = true; sfx.select(); }
      if (this.phaseT >= this.delay) {
        this.phase = 'go';
        sfx.go();
        burst(640, 300, { n: 40, colors: ['#69db7c', '#fff', '#b2f2bb'], speed: 500 });
      }
    } else if (this.phase === 'go') {
      const active = this.players.filter((p) => !this.fouled.has(p.pid));
      if (active.every((p) => this.tapped.has(p.pid)) || this.phaseT > this.delay + 2.5) {
        this.phase = 'after';
        this.afterT = this.phaseT;
        if (this.winner) {
          burst(640, 300, { n: 50, colors: [this.winner.color, '#ffd43b', '#fff'], speed: 520 });
          sfx.win();
        }
      }
    } else if (this.phase === 'after' && this.phaseT - this.afterT > 2.4) {
      this.next();
    }
  }

  ranking() {
    const avg = (pid) => { const a = this.times.get(pid); return a.length ? a.reduce((s, x) => s + x, 0) / a.length : 9; };
    return this.players.map((p) => ({
      pid: p.pid,
      score: this.pts.get(p.pid) * 100 - avg(p.pid),
      label: `${this.pts.get(p.pid)} pont`,
    })).sort((a, b) => b.score - a.score);
  }

  draw(c) {
    const fake = this.phase === 'wait' && this.isFake();
    let top = '#3b0a1a', bot = '#14050c', lamp = '#ff4d6d', msg = 'VÁRJ…';
    if (this.phase === 'pre') { top = '#1f1147'; bot = '#0a0520'; lamp = '#6b7280'; msg = 'Készülj!'; }
    if (fake) { top = '#0b2a5b'; bot = '#03102a'; lamp = '#4dabf7'; msg = 'NEM MOST!'; }
    if (this.phase === 'go') { top = '#0d4f2a'; bot = '#032612'; lamp = '#51cf66'; msg = 'MOST!!!'; }
    if (this.phase === 'after') { top = '#1f1147'; bot = '#0a0520'; lamp = this.winner ? this.winner.color : '#6b7280'; msg = ''; }
    vgrad(c, top, bot);

    text(c, `${Math.min(this.round, ROUNDS)}. / ${ROUNDS} kör`, 640, 44, { size: 28, color: '#ddd' });

    // lámpa
    const pulse = this.phase === 'go' ? 1 + Math.sin(time * 30) * 0.03 : 1;
    const g = c.createRadialGradient(640, 290, 20, 640, 290, 230 * pulse);
    g.addColorStop(0, '#fff');
    g.addColorStop(0.35, lamp);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = g;
    c.beginPath();
    c.arc(640, 290, 230 * pulse, 0, Math.PI * 2);
    c.fill();
    c.beginPath();
    c.arc(640, 290, 120, 0, Math.PI * 2);
    c.fillStyle = lamp;
    c.fill();
    c.lineWidth = 10;
    c.strokeStyle = 'rgba(255,255,255,.7)';
    c.stroke();
    if (msg) text(c, msg, 640, 290, { size: msg.length > 6 ? 46 : 60, color: '#fff', stroke: 'rgba(0,0,0,.6)', sw: 8 });
    if (this.phase === 'after') {
      if (this.winner) {
        avatar(c, this.winner, 640, 275, 70);
        text(c, `${this.winner.name} volt a leggyorsabb!`, 640, 450, { size: 36, stroke: '#1b1036', sw: 7 });
      } else text(c, 'Senki nem nyomta meg…', 640, 290, { size: 36 });
    }
    if (this.phase === 'wait' || this.phase === 'pre') {
      text(c, 'Csak akkor nyomd, ha ZÖLD! A korai nyomás −1 pont.', 640, 460, { size: 22, color: '#ffc9c9', weight: 600 });
    }

    // játékosok
    const n = this.players.length;
    const gap = Math.min(150, 1180 / n);
    this.players.forEach((p, i) => {
      const x = 640 + (i - (n - 1) / 2) * gap;
      const foul = this.fouled.has(p.pid);
      const hit = this.tapped?.has(p.pid);
      const jump = hit ? Math.max(0, 1 - (this.phaseT - this.delay - this.tapped.get(p.pid)) * 3) * 18 : 0;
      avatar(c, p, x, 575 - jump, 30, { gray: foul, flash: this.winner === p && Math.sin(time * 20) > 0 });
      text(c, p.name, x, 620, { size: 16, maxW: gap - 6 });
      text(c, `${this.pts.get(p.pid)} pont`, x, 645, { size: 18, color: '#ffd43b' });
      const l = this.last.get(p.pid);
      if (l) text(c, l, x, 528, { size: 18, color: l === 'KORAI!' ? '#ff8787' : '#b2f2bb', stroke: '#000', sw: 4 });
    });
  }
}

export default {
  id: 'reaction', name: 'Villámreflex', icon: '⚡', color: '#51cf66',
  tagline: 'Csak semmi kapkodás!',
  desc: 'A lámpa egyszer csak ZÖLD lesz. Aki elsőként nyom, 2 pontot kap, a második 1-et. Vigyázz: a kék villanás csapda, és a korai nyomás pontlevonással jár!',
  controls: 'Nyomd meg a gombot, amikor a nagy képernyőn ZÖLD lesz a lámpa. 5 kör.',
  layout: () => ({ mode: 'tap', label: '⚡ MOST!', hint: 'Csak ha zöld!' }),
  create: (players) => new Reaction(players),
};
