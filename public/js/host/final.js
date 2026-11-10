// Játék vége: bónusz koronák, dobogó
import { Scene, W, H, text, panel, avatar, emoji, rr, vgrad, burst, confetti, ease, time, shade } from './engine.js';
import { G, standings, placeOf } from './state.js';
import * as net from './net.js';
import { sfx, music } from './audio.js';
import { goLobby } from './game.js';

const BONUSES = [
  { icon: '🎮', title: 'Minijáték-mester', desc: 'Aki a legtöbb érmét nyerte minijátékokban', stat: (p) => p.stats.mgCoins },
  { icon: '🚶', title: 'Vándor', desc: 'Aki a legtöbb mezőt lépte', stat: (p) => p.stats.steps },
  { icon: '💰', title: 'Krőzus', desc: 'Akinél egyszerre a legtöbb érme volt', stat: (p) => p.stats.maxCoins },
];

export class FinalScene extends Scene {
  enter() {
    G.phase = 'final';
    music('final');
    this.stage = 'intro';
    for (const p of G.players) net.setCtrl(p.pid, { mode: 'wait', icon: '🏆', title: 'Vége a játéknak!', text: 'Jönnek a bónuszok…' });
    this.run();
  }

  async run() {
    sfx.fanfare();
    await this.sleep(2.5);
    for (const b of BONUSES) {
      if (this.dead) return;
      const best = Math.max(...G.players.map(b.stat));
      const winners = best > 0 ? G.players.filter((p) => b.stat(p) === best) : [];
      this.bonus = { ...b, winners, value: best, t0: this.t };
      this.stage = 'bonus';
      sfx.select();
      await this.sleep(1.2);
      for (const p of winners) {
        p.crowns++;
        net.pushStatus(p.pid);
        net.vibrate(p.pid, [80, 60, 200]);
      }
      if (winners.length) { sfx.crown(); burst(640, 380, { n: 60, colors: ['#ffd43b', '#fff'], speed: 500 }); }
      await this.sleep(2.6);
    }
    if (this.dead) return;
    this.stage = 'podium';
    this.podiumT = this.t;
    this.final = standings();
    sfx.win();
    confetti(160);
    for (const p of G.players) {
      const pl = placeOf(p);
      net.setCtrl(p.pid, {
        mode: 'result', icon: pl === 1 ? '🏆' : pl === 2 ? '🥈' : pl === 3 ? '🥉' : '🎉',
        title: pl === 1 ? 'GYŐZTÉL!' : `${pl}. hely`, text: `${p.crowns} 👑 · ${p.coins} 🪙`,
        again: p.pid === G.vip,
      });
    }
    this.after(1, () => this.loopConfetti());
  }

  loopConfetti() {
    if (this.dead) return;
    confetti(40);
    this.after(2.5, () => this.loopConfetti());
  }

  input(pid, msg) {
    if (msg.t === 'again' && pid === G.vip && this.stage === 'podium') goLobby();
  }

  key(e) { if (e.key === 'Enter' && this.stage === 'podium') goLobby(); }

  draw(c) {
    vgrad(c, '#3b0764', '#0c0420');
    // fénycsóvák
    c.save();
    c.translate(640, 760);
    for (let i = 0; i < 12; i++) {
      c.rotate(Math.PI / 6 + Math.sin(time * 0.3) * 0.01);
      c.fillStyle = i % 2 ? 'rgba(255,255,255,.035)' : 'rgba(255,212,59,.04)';
      c.beginPath(); c.moveTo(0, 0); c.lineTo(-120, -1100); c.lineTo(120, -1100); c.fill();
    }
    c.restore();

    if (this.stage === 'intro') {
      const s = ease.outBack(Math.min(1, this.t * 2));
      c.save(); c.translate(640, 330); c.scale(s, s);
      text(c, '🏁 VÉGE A JÁTÉKNAK! 🏁', 0, 0, { size: 72, color: '#ffd43b', stroke: '#1b1036', sw: 12 });
      text(c, 'De még jönnek a bónusz koronák…', 0, 80, { size: 30, color: '#e5dbff' });
      c.restore();
    } else if (this.stage === 'bonus') {
      const b = this.bonus;
      const age = this.t - b.t0;
      const s = ease.outBack(Math.min(1, age * 3));
      c.save(); c.translate(640, 300); c.scale(s, s);
      panel(c, -430, -220, 860, 440, { fill: 'rgba(20,12,48,.92)', stroke: '#ffd43b', lw: 6, r: 32 });
      text(c, 'BÓNUSZ KORONA', 0, -180, { size: 26, color: '#ffd43b' });
      emoji(c, b.icon, 0, -110, 80);
      text(c, b.title, 0, -30, { size: 52 });
      text(c, b.desc, 0, 18, { size: 24, color: '#cfc6f5', weight: 600 });
      if (age > 1.2) {
        if (!b.winners.length) text(c, 'Senki nem kapja meg.', 0, 110, { size: 30 });
        b.winners.forEach((p, i) => {
          const x = (i - (b.winners.length - 1) / 2) * 170;
          avatar(c, p, x, 100, 42);
          text(c, p.name, x, 165, { size: 22, maxW: 160 });
          emoji(c, '👑', x, 44 - Math.abs(Math.sin(time * 5)) * 8, 34);
        });
      }
      c.restore();
    } else {
      this.drawPodium(c);
    }
  }

  drawPodium(c) {
    const age = this.t - this.podiumT;
    text(c, '🏆 VÉGEREDMÉNY 🏆', 640, 60, { size: 56, color: '#ffd43b', stroke: '#1b1036', sw: 10 });
    const top = this.final.slice(0, 3);
    const spots = [{ x: 640, h: 210, c: '#ffd43b' }, { x: 430, h: 150, c: '#ced4da' }, { x: 850, h: 110, c: '#e8a87c' }];
    const base = 560;
    top.forEach((p, i) => {
      const sp = spots[i];
      const k = ease.outBack(Math.min(1, Math.max(0, (age - (2 - i) * 0.5) * 2)));
      const h = sp.h * k;
      rr(c, sp.x - 95, base - h, 190, h, 14);
      const g = c.createLinearGradient(0, base - h, 0, base);
      g.addColorStop(0, sp.c);
      g.addColorStop(1, shade(sp.c, -0.45));
      c.fillStyle = g;
      c.fill();
      if (k > 0.2) {
        const pl = placeOf(p);
        text(c, String(pl), sp.x, base - h + 50, { size: 60, color: '#fff', stroke: shade(sp.c, -0.5), sw: 8 });
        const jump = pl === 1 ? Math.abs(Math.sin(time * 4)) * 14 : 0;
        avatar(c, p, sp.x, base - h - 52 - jump, pl === 1 ? 50 : 42);
        if (pl === 1) emoji(c, '👑', sp.x, base - h - 118 - jump, 50);
        text(c, p.name, sp.x, base + 28, { size: 26, maxW: 200 });
        text(c, `${p.crowns} 👑  ${p.coins} 🪙`, sp.x, base + 60, { size: 22, color: '#ffe066' });
      }
    });
    const rest = this.final.slice(3);
    rest.forEach((p, i) => {
      const x = 1050, y = 180 + i * 62;
      panel(c, x, y, 210, 52, { r: 16, fill: 'rgba(255,255,255,.08)', stroke: p.color, shadow: false });
      text(c, `${placeOf(p)}.`, x + 22, y + 26, { size: 22 });
      avatar(c, p, x + 62, y + 26, 18, { shadow: false });
      text(c, p.name, x + 88, y + 18, { size: 17, align: 'left', maxW: 115 });
      text(c, `${p.crowns}👑 ${p.coins}🪙`, x + 88, y + 38, { size: 15, align: 'left', color: '#ffe066' });
    });
    if (age > 2.5) {
      this.button(c, 520, 640, 240, 56, '🔄 Új játék', () => goLobby(), { color: '#51cf66', size: 26 });
      text(c, 'vagy a ⭐ VIP a telefonjáról · ENTER', 640, 710, { size: 15, color: '#a99fd6', weight: 400 });
    }
  }
}
