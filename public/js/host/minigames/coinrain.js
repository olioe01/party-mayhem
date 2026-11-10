// Érmeeső – kapd el az érméket, kerüld a bombákat
import { W, H, text, avatar, emoji, burst, floatText, rand, vgrad, time, clamp } from '../engine.js';
import { sfx } from '../audio.js';
import { timerHud, scoreBar } from './common.js';
import * as net from '../net.js';

const LIMIT = 30;
const GROUND = 590;
const SPEED = 560;
const PR = 30;

class CoinRain {
  constructor(players) {
    this.t = 0;
    this.finished = false;
    const n = players.length;
    this.pl = players.map((p, i) => ({ p, x: 640 + (i - (n - 1) / 2) * Math.min(140, 1100 / n), dir: 0, score: 0, stun: 0, face: 1, squash: 0 }));
    this.items = [];
    this.spawnT = 0;
    this.clouds = Array.from({ length: 6 }, (_, i) => ({ x: i * 240 + rand(0, 100), y: rand(60, 220), s: rand(0.7, 1.3), v: rand(10, 25) }));
  }

  get(p) { return this.pl.find((x) => x.p === p); }

  input(p, msg) {
    if (msg.t !== 'lr') return;
    const s = this.get(p);
    if (s) s.dir = clamp(Math.round(Number(msg.v) || 0), -1, 1);
  }

  bot(p, dt) {
    const s = this.get(p);
    s.aiT = (s.aiT ?? 0) - dt;
    if (s.aiT > 0) return;
    s.aiT = rand(0.12, 0.3);
    s.greed = s.greed ?? rand(0.6, 1.4);
    let best = null, bestV = -Infinity;
    for (const it of this.items) {
      if (it.dead) continue;
      const tt = (GROUND - it.y) / it.vy;
      if (tt < 0) continue;
      const dx = it.x - s.x;
      if (it.type === 'bomb') {
        if (Math.abs(dx) < 70 && tt < 0.6) { s.dir = dx > 0 ? -1 : 1; return; }
        continue;
      }
      if (Math.abs(dx) > SPEED * tt + 20) continue;
      const crowd = this.pl.filter((o) => o !== s && Math.abs(o.x - it.x) < Math.abs(dx)).length;
      const v = ((it.type === 'gold' ? 3 : 1) * s.greed) / (0.3 + tt) - Math.abs(dx) / 1500 - crowd * 0.6 + rand(-0.3, 0.3);
      if (v > bestV) { bestV = v; best = it; }
    }
    if (!best) { s.dir = 0; return; }
    const dx = best.x - s.x;
    s.dir = Math.abs(dx) < 12 ? 0 : Math.sign(dx);
  }

  update(dt) {
    this.t += dt;
    for (const cl of this.clouds) { cl.x += cl.v * dt; if (cl.x > W + 150) cl.x = -150; }
    // spawn
    this.spawnT -= dt;
    if (this.spawnT <= 0) {
      const k = this.t / LIMIT;
      this.spawnT = (0.42 - k * 0.22) / Math.max(1, Math.sqrt(this.pl.length / 2));
      const r = Math.random();
      const type = r < 0.1 ? 'gold' : r < 0.32 + k * 0.1 ? 'bomb' : 'coin';
      this.items.push({ x: rand(40, W - 40), y: -30, vy: rand(220, 340) + k * 160, type, rot: rand(0, 6), dead: false });
    }
    for (const s of this.pl) {
      s.stun = Math.max(0, s.stun - dt);
      if (s.stun <= 0 && s.dir) { s.x = clamp(s.x + s.dir * SPEED * dt, PR, W - PR); s.face = s.dir; }
      s.squash *= Math.pow(0.02, dt);
    }
    // a játékosok nem mehetnek egymásba – eltolják egymást
    const sorted = [...this.pl].sort((a, b) => a.x - b.x);
    for (let k = 0; k < 3; k++) {
      for (let i = 1; i < sorted.length; i++) {
        const a = sorted[i - 1], b = sorted[i];
        const ov = PR * 1.9 - (b.x - a.x);
        if (ov > 0) {
          a.x = clamp(a.x - ov / 2, PR, W - PR);
          b.x = clamp(b.x + ov / 2, PR, W - PR);
        }
      }
    }
    for (const it of this.items) {
      if (it.dead) continue;
      it.y += it.vy * dt;
      it.rot += dt * 4;
      if (Math.abs(it.y - (GROUND - PR)) < PR + 18) {
        // a legközelebbi játékos kapja el
        let best = null;
        for (const s of this.pl) {
          const d = Math.abs(it.x - s.x);
          if (d < PR + 20 && (!best || d < Math.abs(it.x - best.x))) best = s;
        }
        if (best) { it.dead = true; this.catch(best, it); }
      }
      if (!it.dead && it.y > GROUND + 10) {
        it.dead = true;
        if (it.type === 'bomb') { burst(it.x, GROUND, { n: 14, colors: ['#ff922b', '#555'], speed: 200 }); sfx.hit(); }
      }
    }
    this.items = this.items.filter((it) => !it.dead);
    if (this.t >= LIMIT) this.finished = true;
  }

  catch(s, it) {
    const y = GROUND - PR * 2;
    if (it.type === 'bomb') {
      s.score = Math.max(0, s.score - 3);
      s.stun = 1.1;
      sfx.boom();
      net.vibrate(s.p.pid, [200, 60, 200]);
      burst(s.x, y, { n: 40, colors: ['#ff922b', '#ffd43b', '#495057'], speed: 420 });
      floatText(s.x, y - 20, '−3', '#ff8787', 34);
    } else {
      const v = it.type === 'gold' ? 3 : 1;
      s.score += v;
      s.squash = 0.25;
      sfx.coin();
      net.vibrate(s.p.pid, 25);
      burst(s.x, y, { n: v === 3 ? 18 : 6, colors: ['#ffd43b', '#fff3bf'], speed: 220 });
      floatText(s.x, y - 20, `+${v}`, v === 3 ? '#ffe066' : '#fff', v === 3 ? 34 : 26);
    }
  }

  ranking() {
    return this.pl.map((s) => ({ pid: s.p.pid, score: s.score, label: `${s.score} pont` })).sort((a, b) => b.score - a.score);
  }

  draw(c) {
    vgrad(c, '#74c0fc', '#d0ebff', 0, GROUND);
    for (const cl of this.clouds) {
      c.fillStyle = 'rgba(255,255,255,.85)';
      for (const [dx, dy, r] of [[0, 0, 34], [36, -14, 40], [76, 0, 32], [38, 10, 30]]) {
        c.beginPath(); c.arc(cl.x + dx * cl.s, cl.y + dy * cl.s, r * cl.s, 0, Math.PI * 2); c.fill();
      }
    }
    c.fillStyle = '#5c940d';
    c.fillRect(0, GROUND, W, H - GROUND);
    c.fillStyle = '#82c91e';
    c.fillRect(0, GROUND, W, 14);

    for (const it of this.items) {
      if (it.type === 'bomb') {
        emoji(c, '💣', it.x, it.y, 46);
      } else {
        const sx = Math.abs(Math.cos(it.rot));
        c.save();
        c.translate(it.x, it.y);
        c.scale(Math.max(0.15, sx), 1);
        const r = it.type === 'gold' ? 22 : 16;
        c.fillStyle = it.type === 'gold' ? '#f59f00' : '#fab005';
        c.beginPath(); c.arc(0, 0, r, 0, Math.PI * 2); c.fill();
        c.fillStyle = it.type === 'gold' ? '#ffe066' : '#ffd43b';
        c.beginPath(); c.arc(0, 0, r * 0.72, 0, Math.PI * 2); c.fill();
        if (it.type === 'gold') text(c, '3', 0, 1, { size: 20, color: '#e67700' });
        c.restore();
        if (it.type === 'gold') {
          c.fillStyle = 'rgba(255,255,255,.8)';
          const a = time * 6;
          c.fillRect(it.x + Math.cos(a) * 28 - 2, it.y + Math.sin(a) * 28 - 2, 4, 4);
        }
      }
    }
    for (const s of this.pl) {
      const blink = s.stun > 0 && Math.sin(time * 30) > 0;
      avatar(c, s.p, s.x, GROUND - PR, PR, { squash: s.squash, flash: blink });
      if (s.stun > 0) emoji(c, '💫', s.x, GROUND - PR * 2 - 14, 28);
      text(c, String(s.score), s.x, GROUND + 34, { size: 22, color: '#fff', stroke: '#2b8a3e', sw: 5 });
    }
    timerHud(c, LIMIT - this.t);
    scoreBar(c, this.pl.map((s) => s.p), (p) => this.get(p).score, { y: 680 });
  }
}

export default {
  id: 'coinrain', name: 'Érmeeső', icon: '🪙', color: '#fab005',
  tagline: 'Gyűjts, amennyit csak tudsz!',
  desc: 'Érmék potyognak az égből! A sima érme 1 pont, a nagy arany 3. A bombák viszont 3 pontot visznek, és egy pillanatra elkábítanak.',
  controls: 'Tartsd nyomva a ◀ vagy ▶ gombot a mozgáshoz.',
  layout: () => ({ mode: 'lr' }),
  create: (players) => new CoinRain(players),
};
