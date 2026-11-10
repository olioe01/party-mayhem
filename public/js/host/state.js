// A játék állapota

import * as net from './net.js';

export const COLORS = ['#ff4d6d', '#4dabf7', '#51cf66', '#ffd43b', '#b197fc', '#ff922b', '#22d3ee', '#f783ac'];
// figurák: a 3D modell a chars3d.js-ben, a portrékép a public/img/chars/<id>.png
export const CHARS = [
  { id: 'frog', name: 'Béka', emoji: '🐸' },
  { id: 'cat', name: 'Cica', emoji: '🐱' },
  { id: 'fox', name: 'Róka', emoji: '🦊' },
  { id: 'panda', name: 'Panda', emoji: '🐼' },
  { id: 'pig', name: 'Malac', emoji: '🐷' },
  { id: 'penguin', name: 'Pingvin', emoji: '🐧' },
  { id: 'duck', name: 'Gumikacsa', emoji: '🦆' },
  { id: 'robot', name: 'Robot', emoji: '🤖' },
  { id: 'ghost', name: 'Szellem', emoji: '👻' },
  { id: 'queen', name: 'Királynő', emoji: '👸' },
  { id: 'thimble', name: 'Gyűszű', emoji: '🔘' },
  { id: 'donut', name: 'Fánk', emoji: '🍩' },
];
export const charById = (id) => CHARS.find((c) => c.id === id) || CHARS[0];
export function setChar(p, id) {
  p.char = charById(id).id;
  p.animal = charById(id).emoji; // tartalék, ha a portrékép nem töltődik be
}
export const MAX_PLAYERS = 8;
export const CROWN_PRICE = 20;
export const MAX_ITEMS = 3;

export const ITEMS = {
  double: { icon: '🎲', name: 'Dupla kocka', price: 5, desc: 'Két kockával dobsz' },
  triple: { icon: '🎰', name: 'Tripla kocka', price: 10, desc: 'Három kockával dobsz' },
  thief: { icon: '🧤', name: 'Zsebtolvaj', price: 12, desc: 'Lopj 5–15 érmét valakitől' },
  warp: { icon: '🌀', name: 'Teleport', price: 8, desc: 'Helyet cserélsz valakivel' },
};

export const G = {
  phase: 'lobby',
  players: [],
  maxRounds: 10,
  round: 1,
  vip: null,
  crownNode: null,
  recentMg: [],
};

export const byPid = (pid) => G.players.find((p) => p.pid === pid);
export const humans = () => G.players.filter((p) => !p.isBot);

export function newPlayer(pid, name, isBot) {
  const usedC = new Set(G.players.map((p) => p.color));
  const usedC2 = new Set(G.players.map((p) => p.char));
  const ch = CHARS.find((c) => !usedC2.has(c.id)) || CHARS[0];
  return {
    pid, name, isBot, connected: true, ready: isBot,
    color: COLORS.find((c) => !usedC.has(c)) || COLORS[0],
    char: ch.id, animal: ch.emoji,
    coins: 10, crowns: 0, node: 0, items: [],
    dispCoins: 10,
    stats: { mgCoins: 0, steps: 0, maxCoins: 10, mgWins: 0 },
  };
}

export function resetForGame(p) {
  Object.assign(p, {
    coins: 10, crowns: 0, items: [], dispCoins: 10,
    stats: { mgCoins: 0, steps: 0, maxCoins: 10, mgWins: 0 },
  });
}

export function statusOf(pid) {
  const p = byPid(pid);
  if (!p) return null;
  return {
    name: p.name, color: p.color, char: p.char, coins: p.coins, crowns: p.crowns,
    items: p.items.map((i) => ITEMS[i].icon), playing: G.phase !== 'lobby',
  };
}

export function addCoins(p, n) {
  const before = p.coins;
  p.coins = Math.max(0, p.coins + n);
  p.stats.maxCoins = Math.max(p.stats.maxCoins, p.coins);
  net.pushStatus(p.pid);
  return p.coins - before;
}

export function standings() {
  return [...G.players].sort((a, b) => b.crowns - a.crowns || b.coins - a.coins);
}

// helyezés holtversennyel: azonos korona+érme = azonos hely
export function placeOf(p) {
  const s = standings();
  const i = s.findIndex((q) => q.crowns === p.crowns && q.coins === p.coins);
  return i + 1;
}

export const isLastRounds = () => G.maxRounds >= 5 && G.round > G.maxRounds - 3;
