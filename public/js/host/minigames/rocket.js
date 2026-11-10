// Rakétaverseny – gyors koppintás
import { W, H, text, rr, emoji, burst, shade, rand, vgrad, time } from '../engine.js';
import { sfx } from '../audio.js';
import { timerHud } from './common.js';
import * as net from '../net.js';

const GOAL = 65;
const LIMIT = 22;
const BOTTOM = 590, TOP = 150;

class Rocket {
  constructor(players) {
    this.t = 0;
    this.finished = false;
    const n = players.length;
    const lane = Math.min(150, 1150 / n);
    this.r = players.map((p, i) => ({ p, x: 640 + (i - (n - 1) / 2) * lane, prog: 0, disp: 0, fin: null, flame: 0, botT: 0 }));
    this.stars = Array.from({ length: 140 }, () => ({ x: rand(0, W), y: rand(0, H), s: rand(0.5, 2.2), tw: rand(0, 6) }));
    this.place = 0;
  }

  input(p, msg) {
    if (msg.t !== 'tap') return;
    const r = this.r.find((x) => x.p === p);
    if (!r || r.fin !== null) return;
    r.prog++;
    r.flame = 1;
    if (r.prog % 8 === 0) sfx.tick();
    if (r.prog >= GOAL) {
      r.fin = this.t;
      this.place++;
      r.place = this.place;
      sfx.win();
      net.vibrate(p.pid, [100, 50, 200]);
      burst(r.x, TOP, { n: 50, colors: [p.color, '#fff', '#ffd43b'], speed: 450 });
      net.setCtrl(p.pid, { mode: 'wait', icon: '🌕', title: `Célba értél! (${this.place}.)`, text: `${r.fin.toFixed(2)} másodperc` });
    }
  }

  bot(p, dt) {
    const r = this.r.find((x) => x.p === p);
    r.botT -= dt;
    if (r.botT <= 0) {
      this.input(p, { t: 'tap' });
      r.botT = 1 / rand(4.5, 7.5);
    }
  }

  update(dt) {
    this.t += dt;
    for (const r of this.r) {
      r.disp += (r.prog - r.disp) * Math.min(1, dt * 10);
      r.flame = Math.max(0, r.flame - dt * 3);
      if (r.flame > 0.5 && Math.random() < 0.5) {
        const y = this.ry(r) + 55;
        burst(r.x, y, { n: 1, colors: ['#ffffff55', '#cbd5e1aa'], speed: 60, size: 16, gravity: -40, life: 0.7, angle: Math.PI / 2, spread: 1.2 });
      }
    }
    if (this.r.every((r) => r.fin !== null) || this.t >= LIMIT) this.finished = true;
  }

  ry(r) { return BOTTOM - (Math.min(r.disp, GOAL) / GOAL) * (BOTTOM - TOP); }

  ranking() {
    return this.r.map((r) => ({
      pid: r.p.pid,
      score: r.fin !== null ? 1000 - r.fin : r.prog,
      label: r.fin !== null ? `${r.fin.toFixed(2)} mp` : `${Math.round((r.prog / GOAL) * 100)}%`,
    })).sort((a, b) => b.score - a.score);
  }

  draw(c) {
    vgrad(c, '#05061a', '#3b1f6b');
    for (const s of this.stars) {
      c.globalAlpha = 0.4 + Math.sin(time * 2 + s.tw) * 0.3;
      c.fillStyle = '#fff';
      c.fillRect(s.x, s.y, s.s, s.s);
    }
    c.globalAlpha = 1;
    // Hold
    const g = c.createRadialGradient(640, -380, 50, 640, -380, 520);
    g.addColorStop(0, '#fff9db');
    g.addColorStop(0.75, '#ffe8a3');
    g.addColorStop(1, 'rgba(255,232,163,0)');
    c.fillStyle = g;
    c.beginPath();
    c.arc(640, -380, 520, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = 'rgba(200,170,90,.35)';
    for (const [x, y, r] of [[480, 60, 30], [760, 90, 22], [620, 110, 14], [900, 30, 26], [380, 20, 18]]) {
      c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill();
    }
    // célvonal
    for (let x = 0; x < W; x += 24) {
      c.fillStyle = (x / 24) % 2 ? '#fff' : '#111';
      c.fillRect(x, TOP - 46, 24, 8);
    }
    text(c, 'CÉL', 60, TOP - 66, { size: 22, color: '#ffd43b' });
    // föld
    c.fillStyle = '#1e293b';
    c.fillRect(0, BOTTOM + 70, W, H);
    c.fillStyle = '#334155';
    c.fillRect(0, BOTTOM + 66, W, 6);

    for (const r of this.r) this.drawRocket(c, r);
    timerHud(c, LIMIT - this.t, 1180, 40);
  }

  drawRocket(c, r) {
    const { p } = r;
    const y = this.ry(r);
    const x = r.x + (r.flame > 0.3 && r.fin === null ? Math.sin(time * 50) * 1.5 : 0);
    // kilövőállás
    c.fillStyle = '#475569';
    c.fillRect(r.x - 34, BOTTOM + 60, 68, 10);
    text(c, p.name, r.x, BOTTOM + 95, { size: 18, maxW: 130 });
    text(c, r.fin !== null ? `🏁 ${r.place}.` : `${Math.round((Math.min(r.prog, GOAL) / GOAL) * 100)}%`, r.x, BOTTOM + 118, { size: 17, color: '#ffd43b' });
    // láng
    const f = r.fin !== null ? 0.6 : r.flame;
    if (f > 0.05) {
      const len = 30 + f * 55 + Math.sin(time * 40) * 6;
      c.fillStyle = '#ff922b';
      c.beginPath();
      c.moveTo(x - 15, y + 42);
      c.quadraticCurveTo(x, y + 42 + len * 1.2, x + 15, y + 42);
      c.fill();
      c.fillStyle = '#ffe066';
      c.beginPath();
      c.moveTo(x - 8, y + 42);
      c.quadraticCurveTo(x, y + 42 + len * 0.7, x + 8, y + 42);
      c.fill();
    }
    // szárnyak
    c.fillStyle = shade(p.color, -0.35);
    c.beginPath();
    c.moveTo(x - 22, y + 10); c.lineTo(x - 38, y + 46); c.lineTo(x - 18, y + 40); c.fill();
    c.beginPath();
    c.moveTo(x + 22, y + 10); c.lineTo(x + 38, y + 46); c.lineTo(x + 18, y + 40); c.fill();
    // test
    rr(c, x - 22, y - 30, 44, 76, 18);
    const g = c.createLinearGradient(x - 22, 0, x + 22, 0);
    g.addColorStop(0, '#e2e8f0');
    g.addColorStop(0.5, '#ffffff');
    g.addColorStop(1, '#cbd5e1');
    c.fillStyle = g;
    c.fill();
    // orr
    c.fillStyle = p.color;
    c.beginPath();
    c.moveTo(x - 22, y - 18);
    c.quadraticCurveTo(x, y - 75, x + 22, y - 18);
    c.fill();
    c.fillRect(x - 22, y + 30, 44, 8);
    // ablak
    c.fillStyle = shade(p.color, -0.4);
    c.beginPath(); c.arc(x, y + 4, 17, 0, Math.PI * 2); c.fill();
    c.fillStyle = '#bfe3ff';
    c.beginPath(); c.arc(x, y + 4, 14, 0, Math.PI * 2); c.fill();
    emoji(c, p.animal, x, y + 4, 20);
  }
}

export default {
  id: 'rocket', name: 'Rakétaverseny', icon: '🚀', color: '#ff922b',
  tagline: 'Gyors ujjak versenye',
  desc: 'Mindenkinek van egy rakétája. Minden koppintás egy kis tolóerő – aki elsőként éri el a Holdat, nyer!',
  controls: 'Koppints a nagy gombra olyan gyorsan, ahogy csak tudsz! (Több ujjal is lehet.)',
  layout: () => ({ mode: 'tap', label: '🔥 TOLÁS!', hint: 'Koppints gyorsan!', rapid: true }),
  create: (players) => new Rocket(players),
};
