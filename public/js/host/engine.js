// Rajzolás, jelenetkezelés, részecskék, segédfüggvények

export const W = 1280, H = 720;
export const canvas = document.getElementById('game');
export const ctx = canvas.getContext('2d');
export const FONT = 'Fredoka, "Trebuchet MS", "Segoe UI", sans-serif';
export const EMOJI = '"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif';

let scale = 1, dpr = 1;
function resize() {
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  scale = Math.min(innerWidth / W, innerHeight / H);
  canvas.style.width = `${W * scale}px`;
  canvas.style.height = `${H * scale}px`;
  canvas.width = Math.round(W * scale * dpr);
  canvas.height = Math.round(H * scale * dpr);
}
addEventListener('resize', resize);
resize();

// ---------------------------------------------------------------- matek
export const rand = (a, b) => a + Math.random() * (b - a);
export const randi = (a, b) => Math.floor(rand(a, b + 1));
export const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const lerp = (a, b, t) => a + (b - a) * t;
export function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
export const ease = {
  outCubic: (t) => 1 - Math.pow(1 - t, 3),
  inOutQuad: (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
  outBack: (t) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
  outElastic: (t) => (t === 0 || t === 1 ? t : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI) / 3) + 1),
};

export function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const f = (c) => Math.round(amt >= 0 ? c + (255 - c) * amt : c * (1 + amt));
  r = f(r); g = f(g); b = f(b);
  return `#${((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1)}`;
}

// ---------------------------------------------------------------- rajzolás
export function rr(c, x, y, w, h, r) {
  c.beginPath();
  c.roundRect(x, y, w, h, r);
}

export function text(c, str, x, y, o = {}) {
  const { size = 32, color = '#fff', align = 'center', base = 'middle', weight = 700,
    stroke = null, sw = 6, font = FONT, alpha = 1, maxW } = o;
  c.save();
  c.globalAlpha *= alpha;
  c.font = `${weight} ${size}px ${font}`;
  c.textAlign = align;
  c.textBaseline = base;
  if (stroke) {
    c.lineJoin = 'round';
    c.strokeStyle = stroke;
    c.lineWidth = sw;
    c.strokeText(str, x, y, maxW);
  }
  c.fillStyle = color;
  c.fillText(str, x, y, maxW);
  c.restore();
}

export function emoji(c, e, x, y, size, alpha = 1) {
  c.save();
  c.globalAlpha *= alpha;
  c.font = `${size}px ${EMOJI}`;
  c.textAlign = 'center';
  c.textBaseline = 'middle';
  c.fillStyle = '#000'; // a színes emoji is átveszi a kitöltés átlátszóságát
  c.fillText(e, x, y + size * 0.05);
  c.restore();
}

export function panel(c, x, y, w, h, o = {}) {
  const { fill = 'rgba(24,14,56,.88)', stroke = 'rgba(255,255,255,.18)', r = 20, lw = 3, shadow = true } = o;
  c.save();
  if (shadow) {
    c.shadowColor = 'rgba(0,0,0,.45)';
    c.shadowBlur = 24;
    c.shadowOffsetY = 8;
  }
  rr(c, x, y, w, h, r);
  c.fillStyle = fill;
  c.fill();
  c.shadowColor = 'transparent';
  if (stroke) {
    c.lineWidth = lw;
    c.strokeStyle = stroke;
    c.stroke();
  }
  c.restore();
}

export function avatar(c, p, x, y, r, o = {}) {
  const { squash = 0, alpha = 1, ring = null, shadow = true, flash = false, gray = false } = o;
  c.save();
  c.globalAlpha *= alpha;
  if (shadow) {
    c.fillStyle = 'rgba(0,0,0,.28)';
    c.beginPath();
    c.ellipse(x, y + r * 0.95, r * 0.85, r * 0.26, 0, 0, Math.PI * 2);
    c.fill();
  }
  c.translate(x, y);
  c.scale(1 + squash, 1 - squash);
  const col = gray ? '#6b7280' : p.color;
  const g = c.createRadialGradient(-r * 0.35, -r * 0.4, r * 0.1, 0, 0, r);
  g.addColorStop(0, shade(col, 0.5));
  g.addColorStop(1, col);
  c.fillStyle = flash ? '#ffffff' : g;
  c.beginPath();
  c.arc(0, 0, r, 0, Math.PI * 2);
  c.fill();
  c.lineWidth = Math.max(2, r * 0.12);
  c.strokeStyle = shade(col, -0.4);
  c.stroke();
  if (ring) {
    c.lineWidth = Math.max(3, r * 0.16);
    c.strokeStyle = ring;
    c.beginPath();
    c.arc(0, 0, r * 1.22, 0, Math.PI * 2);
    c.stroke();
  }
  if (gray) c.globalAlpha *= 0.6;
  c.fillStyle = '#000';
  c.font = `${r * 1.1}px ${EMOJI}`;
  c.textAlign = 'center';
  c.textBaseline = 'middle';
  c.fillText(p.animal, 0, r * 0.1);
  c.restore();
}

export function vgrad(c, top, bottom, y0 = 0, y1 = H) {
  const g = c.createLinearGradient(0, y0, 0, y1);
  g.addColorStop(0, top);
  g.addColorStop(1, bottom);
  c.fillStyle = g;
  c.fillRect(0, y0, W, y1 - y0);
}

// ---------------------------------------------------------------- részecskék
export const particles = [];
export function burst(x, y, o = {}) {
  const { n = 20, colors = ['#ffd43b', '#ff4d6d', '#4dabf7', '#51cf66'], speed = 320, life = 0.9,
    size = 7, gravity = 700, shape = 'circle', spread = Math.PI * 2, angle = -Math.PI / 2, drag = 0.6 } = o;
  for (let i = 0; i < n; i++) {
    const a = angle + (Math.random() - 0.5) * spread;
    const s = speed * (0.35 + Math.random() * 0.65);
    particles.push({
      x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: life * (0.6 + Math.random() * 0.4), max: life,
      size: size * (0.6 + Math.random() * 0.7), color: pick(colors), shape, gravity, drag,
      rot: Math.random() * 6, vr: rand(-10, 10),
    });
  }
}
export function floatText(x, y, str, color = '#fff', size = 34) {
  particles.push({ x, y, vx: 0, vy: -70, life: 1.4, max: 1.4, size, color, shape: 'text', text: str, gravity: 0, drag: 0, rot: 0, vr: 0 });
}
export function confetti(n = 120) {
  for (let i = 0; i < n; i++) {
    particles.push({
      x: rand(0, W), y: rand(-200, -10), vx: rand(-60, 60), vy: rand(80, 260), life: 4, max: 4,
      size: rand(6, 12), color: pick(['#ffd43b', '#ff4d6d', '#4dabf7', '#51cf66', '#b197fc', '#ff922b']),
      shape: 'rect', gravity: 60, drag: 0, rot: rand(0, 6), vr: rand(-8, 8),
    });
  }
}
function updateParticles(dt) {
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.life -= dt;
    if (p.life <= 0) { particles.splice(i, 1); continue; }
    p.vy += p.gravity * dt;
    p.vx *= 1 - p.drag * dt;
    p.vy *= 1 - p.drag * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.rot += p.vr * dt;
  }
}
function drawParticles(c) {
  for (const p of particles) {
    const a = Math.min(1, p.life / (p.max * 0.4));
    c.save();
    c.globalAlpha = a;
    if (p.shape === 'text') {
      text(c, p.text, p.x, p.y, { size: p.size, color: p.color, stroke: '#1b1036', sw: 7 });
    } else {
      c.translate(p.x, p.y);
      c.rotate(p.rot);
      c.fillStyle = p.color;
      if (p.shape === 'rect') c.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
      else { c.beginPath(); c.arc(0, 0, p.size / 2, 0, Math.PI * 2); c.fill(); }
    }
    c.restore();
  }
}

// ---------------------------------------------------------------- jelenetek
export class Scene {
  constructor() { this.t = 0; this.timers = []; this.buttons = []; this.dead = false; }
  after(sec, fn) { const tm = { at: this.t + sec, fn }; this.timers.push(tm); return tm; }
  sleep(sec) { return new Promise((r) => this.after(sec, r)); }
  _tick(dt) {
    this.t += dt;
    if (!this.timers.length) return;
    const due = this.timers.filter((x) => x.at <= this.t);
    if (due.length) {
      this.timers = this.timers.filter((x) => x.at > this.t);
      due.forEach((x) => x.fn());
    }
  }
  // gomb, amire a host egérrel kattinthat
  button(c, x, y, w, h, label, onClick, o = {}) {
    const { color = '#ffd43b', textColor = '#2b1055', size = 24 } = o;
    const hover = mouse.x >= x && mouse.x <= x + w && mouse.y >= y && mouse.y <= y + h;
    c.save();
    rr(c, x, y + 5, w, h, h / 2);
    c.fillStyle = shade(color, -0.35);
    c.fill();
    rr(c, x, y + (hover ? 2 : 0), w, h, h / 2);
    c.fillStyle = hover ? shade(color, 0.15) : color;
    c.fill();
    c.restore();
    text(c, label, x + w / 2, y + h / 2 + (hover ? 2 : 0), { size, color: textColor });
    this.buttons.push({ x, y, w, h, onClick });
  }
  enter() {} exit() {} update() {} draw() {} input() {} key() {}
}

let scene = null, nextScene = null, fade = 0, fadeDir = 0;
const hooks = { onSwap: null };
export const onSceneSwap = (fn) => { hooks.onSwap = fn; };
export const current = () => scene;
export function setScene(s, instant = false) {
  if (instant || !scene) { swap(s); return; }
  nextScene = s;
  fadeDir = 1;
}
function swap(s) {
  if (scene) { scene.dead = true; scene.exit(); }
  particles.length = 0;
  hooks.onSwap?.();
  scene = s;
  s.enter();
}

export const mouse = { x: -1, y: -1 };
canvas.addEventListener('mousemove', (e) => {
  const r = canvas.getBoundingClientRect();
  mouse.x = ((e.clientX - r.left) / r.width) * W;
  mouse.y = ((e.clientY - r.top) / r.height) * H;
});
canvas.addEventListener('click', () => {
  if (!scene || fadeDir) return;
  const b = scene.buttons.find((b) => mouse.x >= b.x && mouse.x <= b.x + b.w && mouse.y >= b.y && mouse.y <= b.y + b.h);
  b?.onClick();
});
addEventListener('keydown', (e) => { if (scene && !fadeDir) scene.key(e); });

export let time = 0;
let last = 0;
let overlay = null;
export const setOverlay = (fn) => { overlay = fn; };

function frame(now) {
  requestAnimationFrame(frame);
  try {
    step(now);
  } catch (err) {
    console.error(err); // egy hiba ne fagyassza le az egész játékot
  }
}

function step(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  time += dt;
  if (fadeDir === 1) {
    fade += dt * 4;
    if (fade >= 1) { fade = 1; swap(nextScene); nextScene = null; fadeDir = -1; }
  } else if (fadeDir === -1) {
    fade -= dt * 4;
    if (fade <= 0) { fade = 0; fadeDir = 0; }
  }
  if (scene) { scene._tick(dt); scene.update(dt); }
  updateParticles(dt);

  ctx.setTransform(scale * dpr, 0, 0, scale * dpr, 0, 0);
  ctx.clearRect(0, 0, W, H);
  if (scene) {
    scene.buttons = [];
    ctx.save();
    scene.draw(ctx);
    ctx.restore();
  }
  drawParticles(ctx);
  overlay?.(ctx);
  if (fade > 0) {
    ctx.fillStyle = `rgba(15,8,35,${fade})`;
    ctx.fillRect(0, 0, W, H);
  }
}
export function start() {
  requestAnimationFrame((t) => { last = t; frame(t); });
}
