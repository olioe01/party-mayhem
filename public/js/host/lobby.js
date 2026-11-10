// Lobby: csatlakozás QR-kóddal, figura választás, indítás

import { Scene, W, H, text, panel, avatar, emoji, rr, vgrad, burst, shade, ease, time } from './engine.js';
import { G, CHARS, MAX_PLAYERS, byPid, setChar } from './state.js';
import * as net from './net.js';
import { sfx, music } from './audio.js';
import { startGame } from './game.js';

const ROUND_OPTIONS = [5, 10, 15, 20];

export class LobbyScene extends Scene {
  enter() {
    G.phase = 'lobby';
    music('lobby');
    this.url = '';
    this.qr = null;
    this.seen = new Map();
    this.deco = Array.from({ length: 18 }, (_, i) => ({
      x: Math.random() * W, y: Math.random() * H, s: 20 + Math.random() * 30,
      e: ['🎲', '👑', '🪙', '⭐', '🎉', '🍀'][i % 6], v: 10 + Math.random() * 25, r: Math.random() * 6,
    }));
    this.resolveUrl();
    this.refresh();
  }

  async resolveUrl() {
    let base = location.origin;
    if (['localhost', '127.0.0.1', '[::1]'].includes(location.hostname)) {
      try {
        const info = await (await fetch('/api/info')).json();
        const addr = info.publicHost || info.addresses[0];
        if (addr) base = `http://${addr}:${info.port}`;
      } catch { /* marad a localhost */ }
    }
    this.url = base;
    const img = new Image();
    img.onload = () => { this.qr = img; };
    img.src = `/api/qr?url=${encodeURIComponent(base)}`;
  }

  canStart() {
    return G.players.length >= 1 && G.players.every((p) => p.ready || !p.connected);
  }

  refresh() {
    const can = this.canStart();
    for (const p of G.players) {
      net.setCtrl(p.pid, {
        mode: 'lobby',
        chars: CHARS.map((c) => ({ id: c.id, name: c.name })),
        taken: G.players.filter((q) => q !== p).map((q) => q.char),
        char: p.char,
        ready: p.ready,
        vip: p.pid === G.vip,
        rounds: G.maxRounds,
        roundOptions: ROUND_OPTIONS,
        canStart: can,
        count: G.players.length,
      });
    }
  }

  playersChanged() { this.refresh(); }

  input(pid, msg) {
    const p = byPid(pid);
    if (!p) return;
    if (msg.t === 'char' && CHARS.some((c) => c.id === msg.v) && !G.players.some((q) => q !== p && q.char === msg.v)) {
      setChar(p, msg.v);
      sfx.pop();
    } else if (msg.t === 'ready') {
      p.ready = !!msg.v;
      if (p.ready) { sfx.select(); this.cheer(p); }
    } else if (msg.t === 'rounds' && pid === G.vip && ROUND_OPTIONS.includes(msg.v)) {
      G.maxRounds = msg.v;
      sfx.select();
    } else if (msg.t === 'start' && pid === G.vip && this.canStart()) {
      this.go();
      return;
    } else return;
    this.refresh();
  }

  cheer(p) {
    const i = G.players.indexOf(p);
    const { x, y } = this.slotPos(i);
    burst(x, y - 10, { n: 24, colors: [p.color, '#fff', '#ffd43b'], speed: 380 });
  }

  go() {
    if (!G.players.length || this.going) return;
    this.going = true;
    sfx.fanfare();
    startGame();
  }

  key(e) {
    if (e.key === 'Enter') this.go();
    if (e.key === 'b' || e.key === 'B') this.addBot();
    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
      const i = ROUND_OPTIONS.indexOf(G.maxRounds);
      const j = Math.max(0, Math.min(ROUND_OPTIONS.length - 1, (i < 0 ? 1 : i) + (e.key === 'ArrowRight' ? 1 : -1)));
      G.maxRounds = ROUND_OPTIONS[j];
      this.refresh();
    }
  }

  addBot() {
    if (G.players.length >= MAX_PLAYERS) return;
    const n = G.players.filter((p) => p.isBot).length + 1;
    net.addBot(`Bot ${n}`);
    sfx.pop();
  }

  removeBot() {
    const b = [...G.players].reverse().find((p) => p.isBot);
    if (!b) return;
    net.removeBot(b.pid);
    G.players.splice(G.players.indexOf(b), 1);
    this.refresh();
  }

  slotPos(i) {
    const col = i % 4, row = Math.floor(i / 4);
    return { x: 545 + col * 182, y: 240 + row * 205 };
  }

  update(dt) {
    for (const d of this.deco) {
      d.y -= d.v * dt;
      d.r += dt * 0.5;
      if (d.y < -40) { d.y = H + 40; d.x = Math.random() * W; }
    }
    for (const p of G.players) if (!this.seen.has(p.pid)) { this.seen.set(p.pid, this.t); sfx.pop(); }
  }

  draw(c) {
    vgrad(c, '#2a1060', '#120a2e');
    for (const d of this.deco) emoji(c, d.e, d.x, d.y, d.s, 0.12);

    // cím
    const title = 'PARTY MAYHEM';
    let x = 60;
    c.font = '700 64px Fredoka, sans-serif';
    for (let i = 0; i < title.length; i++) {
      const ch = title[i];
      const w = c.measureText(ch).width;
      const y = 78 + Math.sin(time * 3 + i * 0.5) * 6;
      const col = ['#ff4d6d', '#ffd43b', '#51cf66', '#4dabf7', '#b197fc'][i % 5];
      text(c, ch, x + w / 2, y, { size: 64, color: col, stroke: '#1b1036', sw: 10 });
      x += w + 2;
    }
    text(c, 'Táblás partijáték – a telefonod a kontroller!', 62, 128, { size: 22, color: '#d6ccff', align: 'left', weight: 600 });

    // QR
    panel(c, 50, 160, 380, 470, { fill: 'rgba(255,255,255,.07)' });
    text(c, '📱 Csatlakozz!', 240, 196, { size: 30 });
    rr(c, 95, 222, 290, 290, 18);
    c.fillStyle = '#fff';
    c.fill();
    if (this.qr) c.drawImage(this.qr, 105, 232, 270, 270);
    else text(c, 'QR-kód betöltése…', 240, 367, { size: 20, color: '#555' });
    text(c, 'Olvasd be, vagy írd be:', 240, 540, { size: 19, color: '#cfc6f5', weight: 600 });
    text(c, this.url.replace(/^https?:\/\//, ''), 240, 574, { size: 28, color: '#ffd43b', maxW: 350 });
    text(c, 'Ugyanazon a Wi-Fi hálózaton legyél!', 240, 607, { size: 16, color: '#a99fd6', weight: 400 });

    // játékosok
    text(c, `Játékosok (${G.players.length}/${MAX_PLAYERS})`, 470, 152, { size: 26, align: 'left' });
    for (let i = 0; i < MAX_PLAYERS; i++) {
      const { x: sx, y: sy } = this.slotPos(i);
      const p = G.players[i];
      rr(c, sx - 80, sy - 75, 160, 185, 22);
      c.fillStyle = p ? shade(p.color, -0.55) : 'rgba(255,255,255,.05)';
      c.fill();
      c.lineWidth = 3;
      c.setLineDash(p ? [] : [10, 8]);
      c.strokeStyle = p ? p.color : 'rgba(255,255,255,.18)';
      c.stroke();
      c.setLineDash([]);
      if (!p) {
        text(c, '?', sx, sy + 5, { size: 48, color: 'rgba(255,255,255,.15)' });
        continue;
      }
      const age = this.t - (this.seen.get(p.pid) ?? this.t);
      const pop = ease.outBack(Math.min(1, age * 2.5));
      const bob = p.ready ? Math.abs(Math.sin(time * 5 + i)) * 10 : 0;
      avatar(c, p, sx, sy - bob, 44 * pop, { alpha: p.connected ? 1 : 0.4 });
      text(c, p.name, sx, sy + 68, { size: 22, maxW: 150 });
      text(c, p.ready ? '✔ KÉSZ' : (p.connected ? 'választ…' : 'lecsatlakozott'), sx, sy + 95,
        { size: 17, color: p.ready ? '#69db7c' : '#bbb', weight: 600 });
      if (p.pid === G.vip) text(c, '⭐ VIP', sx + 52, sy - 58, { size: 15, color: '#ffd43b' });
      if (p.isBot) text(c, '🤖', sx - 58, sy - 56, { size: 20 });
    }

    // alsó vezérlősáv
    text(c, 'Körök:', 470, 668, { size: 24, align: 'left' });
    ROUND_OPTIONS.forEach((r, i) => {
      const bx = 555 + i * 72;
      const on = r === G.maxRounds;
      this.button(c, bx, 645, 62, 46, String(r), () => { G.maxRounds = r; sfx.select(); this.refresh(); },
        { color: on ? '#ffd43b' : '#4b3a8a', textColor: on ? '#2b1055' : '#fff', size: 22 });
    });
    this.button(c, 855, 645, 110, 46, '+ Bot', () => this.addBot(), { color: '#4dabf7', size: 20 });
    this.button(c, 975, 645, 90, 46, '− Bot', () => this.removeBot(), { color: '#868e96', size: 20 });
    const can = G.players.length > 0;
    this.button(c, 1080, 640, 160, 56, '▶ START', () => this.go(), { color: can ? '#51cf66' : '#555', size: 26 });
    text(c, 'A ⭐ VIP a telefonjáról is indíthat, ha mindenki kész. Itt: ENTER = indítás', 50, 668,
      { size: 14, color: '#8f84c4', align: 'left', weight: 400, maxW: 400 });
    text(c, 'B = bot hozzáadása · F = teljes képernyő · M = hang', 50, 690,
      { size: 14, color: '#8f84c4', align: 'left', weight: 400 });
  }
}
