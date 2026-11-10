import { text, panel, avatar } from '../engine.js';

export function timerHud(c, remain, x = 640, y = 36) {
  const r = Math.max(0, remain);
  const low = r <= 5;
  panel(c, x - 75, y - 25, 150, 50, { r: 25, fill: low ? 'rgba(220,38,38,.92)' : 'rgba(20,12,48,.85)' });
  text(c, `⏱ ${Math.ceil(r)}`, x, y + 1, { size: 28, color: '#fff' });
}

// alsó sáv: játékosok pontszámmal
export function scoreBar(c, players, valueOf, o = {}) {
  const { y = 680, h = 56 } = o;
  const n = players.length;
  const w = Math.min(200, (1240 - (n - 1) * 8) / n);
  const x0 = 640 - (n * w + (n - 1) * 8) / 2;
  players.forEach((p, i) => {
    const x = x0 + i * (w + 8);
    panel(c, x, y - h / 2, w, h, { r: 16, fill: 'rgba(20,12,48,.8)', stroke: p.color, shadow: false });
    avatar(c, p, x + 28, y, 18, { shadow: false });
    text(c, String(valueOf(p)), x + w - 14, y + 1, { size: 26, align: 'right', color: '#ffd43b' });
    text(c, p.name, x + 52, y - 13, { size: 13, align: 'left', color: '#ddd', weight: 600, maxW: w - 90 });
  });
}
