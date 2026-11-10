// Kapcsolat a szerverrel + a telefonos kontrollerek vezérlése + botok

const socket = io({ transports: ['websocket', 'polling'] });

const listeners = { join() {}, leave() {}, input() {} };
export const on = (evt, fn) => { listeners[evt] = fn; };

let statusOf = () => null;
export const setStatusProvider = (fn) => { statusOf = fn; };

const layouts = new Map();   // pid -> utolsó elküldött kontroller-elrendezés
const bots = new Set();      // gépi játékosok
const away = new Set();      // lecsatlakozott játékosok (ilyenkor bot vezérli őket)
let seq = 0;
let asks = [];

socket.on('connect', () => socket.emit('host:hello'));
socket.on('p:join', ({ pid, name }) => { away.delete(pid); listeners.join(pid, name, false); });
socket.on('p:leave', ({ pid }) => listeners.leave(pid));
socket.on('p:input', ({ pid, msg }) => handleInput(pid, msg));
socket.on('host:replaced', () => {
  const m = document.getElementById('msg');
  m.textContent = 'A játékot egy másik ablakban nyitották meg – ez az ablak már nem aktív.';
  m.style.display = 'block';
});

export const isBot = (pid) => bots.has(pid);
export const isAuto = (pid) => bots.has(pid) || away.has(pid);

export function handleInput(pid, msg) {
  if (!msg || typeof msg !== 'object') return;
  const i = asks.findIndex((a) => a.pid === pid && a.lid === msg.lid && a.types.includes(msg.t));
  if (i >= 0) {
    const a = asks[i];
    asks.splice(i, 1);
    clearTimeout(a.timer);
    a.resolve(msg);
    return;
  }
  listeners.input(pid, msg);
}

function send(pid, msg) {
  if (bots.has(pid)) return;
  socket.emit('host:send', { pid, msg });
}

export function setCtrl(pid, layout) {
  layout.id = ++seq;
  layout.me = statusOf(pid);
  layouts.set(pid, layout);
  if (isAuto(pid)) botReact(pid, layout);
  if (!bots.has(pid)) send(pid, { kind: 'layout', layout });
  return layout.id;
}

export function resendLayout(pid) {
  const l = layouts.get(pid);
  if (!l) return false;
  l.me = statusOf(pid);
  send(pid, { kind: 'layout', layout: l });
  return true;
}

export const pushStatus = (pid) => send(pid, { kind: 'status', me: statusOf(pid) });
export const vibrate = (pid, pattern = 60) => send(pid, { kind: 'vibrate', pattern });

// Elrendezést küld és megvárja a választ. Ha a játékos nem válaszol (pl. lemerült a telefonja),
// a timeout után a bot-logika dönt helyette, hogy a játék ne akadjon el.
export function ask(pid, layout, types = ['choice', 'tap', 'num', 'ready'], timeoutSec = 40) {
  return new Promise((resolve) => {
    const a = { pid, types, resolve, lid: 0, timer: null };
    asks.push(a);
    a.lid = setCtrl(pid, layout);
    a.timer = setTimeout(() => botReact(pid, layout, true), timeoutSec * 1000);
  });
}

export function cancelAsks() {
  asks.forEach((a) => clearTimeout(a.timer));
  asks = [];
}

export function addBot(name) {
  const pid = `bot-${Math.random().toString(36).slice(2, 8)}`;
  bots.add(pid);
  listeners.join(pid, name, true);
  return pid;
}
export const removeBot = (pid) => bots.delete(pid);

export function markAway(pid) {
  away.add(pid);
  const l = layouts.get(pid);
  if (l) botReact(pid, l);
}

const later = (ms, fn) => setTimeout(fn, ms);
function botReact(pid, l, now = false) {
  if (layouts.get(pid) !== l) return;
  const d = (a, b) => (now ? 0 : a + Math.random() * (b - a));
  const fire = (msg) => { if (layouts.get(pid) === l) handleInput(pid, { ...msg, lid: l.id }); };
  switch (l.mode) {
    case 'choice': {
      const ok = l.options.map((o, i) => ({ o, i })).filter((x) => !x.o.disabled);
      if (!ok.length) return;
      let v = ok[Math.floor(Math.random() * ok.length)].i;
      if (typeof l.botPick === 'number' && !l.options[l.botPick]?.disabled) v = l.botPick;
      later(d(600, 1400), () => fire({ t: 'choice', v }));
      break;
    }
    case 'tap':
      if (l.botAuto || now) later(d(500, 1300), () => fire({ t: 'tap' }));
      break;
    case 'ready':
      later(d(700, 2200), () => fire({ t: 'ready' }));
      break;
    case 'lobby':
      if (!l.ready) later(d(200, 600), () => fire({ t: 'ready', v: true }));
      break;
    case 'number':
      if (now) fire({ t: 'num', v: 0 });
      break;
    default:
  }
}
