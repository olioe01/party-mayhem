// Lökdösődő aréna – lökd le a többieket a zsugorodó platformról
import { W, H, text, avatar, burst, rand, vgrad, time, clamp, emoji } from '../engine.js';
import { sfx } from '../audio.js';
import { timerHud } from './common.js';
import * as net from '../net.js';

const LIMIT = 45;
const CX = 640, CY = 370;
const BALL = 27;
const ACC = 1300, MAXV = 430, DASH = 720;

class Arena {
  constructor(players) {
    this.t = 0;
    this.finished = false;
    this.R = 300;
    this.elim = [];
    this.lastHit = 0;
    const n = players.length;
    this.b = players.map((p, i) => {
      const a = (i / n) * Math.PI * 2 - Math.PI / 2;
      return { p, x: CX + Math.cos(a) * 180, y: CY + Math.sin(a) * 180, vx: 0, vy: 0, ix: 0, iy: 0, cd: 0, dashT: 0, out: false, fallT: 0, trail: [], aiT: 0 };
    });
    this.endAt = null;
    this.bubbles = Array.from({ length: 30 }, () => ({ x: rand(0, W), y: rand(0, H), r: rand(4, 14), s: rand(0.5, 2) }));
  }

  ball(p) { return this.b.find((b) => b.p === p); }

  input(p, msg) {
    const b = this.ball(p);
    if (!b || b.out) return;
    if (msg.t === 'stick') {
      b.ix = clamp(Number(msg.x) || 0, -1, 1);
      b.iy = clamp(Number(msg.y) || 0, -1, 1);
    } else if (msg.t === 'btn' && b.cd <= 0) {
      let dx = b.ix, dy = b.iy;
      if (Math.hypot(dx, dy) < 0.2) { dx = b.vx; dy = b.vy; }
      const l = Math.hypot(dx, dy) || 1;
      b.vx += (dx / l) * DASH;
      b.vy += (dy / l) * DASH;
      b.cd = 1.3;
      b.dashT = 0.25;
      sfx.whoosh();
    }
  }

  bot(p, dt) {
    const b = this.ball(p);
    if (b.out) return;
    b.aiT -= dt;
    if (b.aiT > 0) return;
    b.aiT = 0.12;
    const others = this.b.filter((o) => o !== b && !o.out);
    const d0 = Math.hypot(b.x - CX, b.y - CY);
    let tx = CX, ty = CY;
    if (others.length && d0 < this.R * 0.55) {
      const tgt = others.sort((a, c) => Math.hypot(a.x - b.x, a.y - b.y) - Math.hypot(c.x - b.x, c.y - b.y))[0];
      tx = tgt.x + (tgt.x - CX) * 0.2;
      ty = tgt.y + (tgt.y - CY) * 0.2;
      if (Math.hypot(tgt.x - b.x, tgt.y - b.y) < 150 && b.cd <= 0 && Math.random() < 0.35) {
        b.ix = (tgt.x - b.x); b.iy = (tgt.y - b.y);
        const l = Math.hypot(b.ix, b.iy) || 1;
        b.ix /= l; b.iy /= l;
        this.input(p, { t: 'btn' });
        return;
      }
    }
    const dx = tx - b.x, dy = ty - b.y, l = Math.hypot(dx, dy) || 1;
    const k = Math.min(1, l / 60);
    b.ix = (dx / l) * k + rand(-0.15, 0.15);
    b.iy = (dy / l) * k + rand(-0.15, 0.15);
  }

  update(dt) {
    this.t += dt;
    if (this.t > 5) this.R = Math.max(125, 300 - (this.t - 5) * 5.2);
    for (const b of this.b) {
      if (b.out) { b.fallT += dt; continue; }
      b.cd = Math.max(0, b.cd - dt);
      b.dashT = Math.max(0, b.dashT - dt);
      b.vx += b.ix * ACC * dt;
      b.vy += b.iy * ACC * dt;
      const fr = Math.pow(0.12, dt);
      b.vx *= fr;
      b.vy *= fr;
      const sp = Math.hypot(b.vx, b.vy);
      const cap = b.dashT > 0 ? 1000 : Math.max(MAXV, sp * 0.97);
      if (sp > cap) { b.vx *= cap / sp; b.vy *= cap / sp; }
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.trail.push({ x: b.x, y: b.y });
      if (b.trail.length > 8) b.trail.shift();
    }
    // ütközések
    const alive = this.b.filter((b) => !b.out);
    for (let i = 0; i < alive.length; i++) {
      for (let j = i + 1; j < alive.length; j++) {
        const a = alive[i], c = alive[j];
        const dx = a.x - c.x, dy = a.y - c.y;
        const d = Math.hypot(dx, dy);
        if (d >= BALL * 2 || d === 0) continue;
        const nx = dx / d, ny = dy / d;
        const ov = BALL * 2 - d;
        a.x += nx * ov / 2; a.y += ny * ov / 2;
        c.x -= nx * ov / 2; c.y -= ny * ov / 2;
        const rel = (a.vx - c.vx) * nx + (a.vy - c.vy) * ny;
        if (rel < 0) {
          const j2 = -(1.0 + 0.9) * rel / 2 + 90;
          a.vx += nx * j2; a.vy += ny * j2;
          c.vx -= nx * j2; c.vy -= ny * j2;
          if (this.t - this.lastHit > 0.08) {
            this.lastHit = this.t;
            sfx.hit();
            burst((a.x + c.x) / 2, (a.y + c.y) / 2, { n: 8, colors: ['#fff', '#ffe066'], speed: 220, gravity: 0, life: 0.4 });
          }
        }
      }
    }
    // leesés
    for (const b of alive) {
      if (Math.hypot(b.x - CX, b.y - CY) > this.R + BALL * 0.3) {
        b.out = true;
        this.elim.push(b);
        sfx.splash();
        net.vibrate(b.p.pid, [200, 80, 200]);
        burst(b.x, b.y, { n: 30, colors: ['#ff922b', '#ffd43b', '#ff4d6d'], speed: 300 });
        net.setCtrl(b.p.pid, { mode: 'wait', icon: '🔥', title: 'Leestél!', text: `${this.elim.length}. kiesett` });
      }
    }
    const left = this.b.filter((b) => !b.out).length;
    if (this.endAt === null && ((this.b.length > 1 && left <= 1) || left === 0 || this.t >= LIMIT)) this.endAt = this.t + 1;
    if (this.endAt !== null && this.t >= this.endAt) this.finished = true;
  }

  ranking() {
    return this.b.map((b) => {
      const d = Math.hypot(b.x - CX, b.y - CY);
      const ei = this.elim.indexOf(b);
      return {
        pid: b.p.pid,
        score: b.out ? ei : 1000 + Math.round(this.R - d),
        label: b.out ? `${ei + 1}. kiesett` : 'Túlélte! 💪',
      };
    }).sort((a, b) => b.score - a.score);
  }

  draw(c) {
    // láva
    vgrad(c, '#7f1d1d', '#431407');
    for (const bb of this.bubbles) {
      const y = (bb.y - time * 30 * bb.s + H * 10) % H;
      c.fillStyle = `rgba(255,${120 + bb.r * 6},40,.35)`;
      c.beginPath();
      c.arc(bb.x + Math.sin(time + bb.y) * 10, y, bb.r * (1 + Math.sin(time * 3 + bb.x) * 0.2), 0, Math.PI * 2);
      c.fill();
    }
    // platform
    c.fillStyle = 'rgba(0,0,0,.35)';
    c.beginPath(); c.ellipse(CX, CY + 22, this.R + 6, this.R + 6, 0, 0, Math.PI * 2); c.fill();
    const g = c.createRadialGradient(CX - 80, CY - 90, 30, CX, CY, this.R);
    g.addColorStop(0, '#94a3b8');
    g.addColorStop(1, '#475569');
    c.fillStyle = g;
    c.beginPath(); c.arc(CX, CY, this.R, 0, Math.PI * 2); c.fill();
    c.lineWidth = 12;
    c.setLineDash([22, 16]);
    c.lineDashOffset = -time * 40;
    c.strokeStyle = this.R < 180 ? '#ff4d6d' : '#facc15';
    c.beginPath(); c.arc(CX, CY, this.R - 6, 0, Math.PI * 2); c.stroke();
    c.setLineDash([]);
    c.lineWidth = 3;
    c.strokeStyle = 'rgba(255,255,255,.12)';
    for (const k of [0.33, 0.66]) { c.beginPath(); c.arc(CX, CY, this.R * k, 0, Math.PI * 2); c.stroke(); }

    // golyók
    for (const b of this.b) {
      if (b.out) {
        const k = Math.min(1, b.fallT / 0.7);
        if (k < 1) avatar(c, b.p, b.x, b.y + k * 30, BALL * (1 - k * 0.8), { alpha: 1 - k, shadow: false });
        continue;
      }
      if (b.dashT > 0) {
        b.trail.forEach((tp, i) => {
          c.globalAlpha = (i / b.trail.length) * 0.4;
          c.fillStyle = b.p.color;
          c.beginPath(); c.arc(tp.x, tp.y, BALL, 0, Math.PI * 2); c.fill();
        });
        c.globalAlpha = 1;
      }
      avatar(c, b.p, b.x, b.y, BALL, { ring: b.cd <= 0 ? 'rgba(255,255,255,.75)' : null });
      text(c, b.p.name, b.x, b.y - BALL - 14, { size: 15, stroke: '#000', sw: 4, maxW: 120 });
    }

    const alive = this.b.filter((b) => !b.out).length;
    text(c, `🔥 Talpon: ${alive}/${this.b.length}`, 30, 36, { size: 26, align: 'left', stroke: '#000', sw: 5 });
    text(c, 'Fehér gyűrű = kész a lökés', 30, 70, { size: 16, align: 'left', color: '#fecaca', weight: 600 });
    timerHud(c, LIMIT - this.t, 1180, 40);
  }
}

export default {
  id: 'arena', name: 'Lökdösődő aréna', icon: '💥', color: '#ff4d6d',
  tagline: 'Az utolsó talpon maradó nyer',
  desc: 'Egy láva fölötti, folyamatosan zsugorodó platformon álltok. Lökd le a többieket, de vigyázz, nehogy te ess le!',
  controls: 'Bal oldalon a joystickkal mozogsz, jobb oldalon a LÖKÉS gombbal gyorsan előrevetődsz.',
  layout: () => ({ mode: 'stick', btn: '💥 LÖKÉS' }),
  create: (players) => new Arena(players),
};
