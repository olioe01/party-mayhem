// Party Mayhem közvetítő szerver.
//
// Akkor kell, ha a gépek között nincs közvetlen út (a szoba gazdája szolgáltatói NAT mögött van,
// a router nem nyit portot stb.). Mindenki kifelé csatlakozik ide, a szerver pedig szobakód
// alapján összeköti őket. A játék üzeneteibe nem néz bele, csak továbbítja őket.
//
//   /host?key=K[&code=C]      a szoba gazdájának vezérlőcsatornája; válasz: {t:"room", code}
//   /join?code=C              egy vendég gép; a gazda {t:"guest", id} értesítést kap róla
//   /pipe?code=C&id=I&key=K   a gazda ezt nyitja meg a vendéghez: a kettő közé cső kerül
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = Number(process.env.PORT) || 8787;
const ALPHA = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CODE_LEN = 5;
const MAX_ROOMS = 500;
const MAX_GUESTS = 8;
const MAX_QUEUE = 64;                 // ennyi vendégüzenet várhat, amíg a gazda megnyitja a csövet
const MAX_BUFFERED = 32 << 20;        // ennél jobban lemaradó kapcsolatot bontunk
const PIPE_WAIT_MS = 15000;
const ROOM_LINGER_MS = 60000;         // a gazda ennyi ideig jöhet vissza ugyanazzal a kóddal

const rooms = new Map();              // kód -> {key, host, guests: Map(id -> {guest, pipe, queue, timer}), gone}

function validCode(c) {
  return typeof c === 'string' && c.length === CODE_LEN && [...c].every((ch) => ALPHA.includes(ch));
}

function newCode() {
  for (;;) {
    let c = '';
    for (let i = 0; i < CODE_LEN; i++) c += ALPHA[crypto.randomInt(ALPHA.length)];
    if (!rooms.has(c)) return c;
  }
}

function sendJson(ws, obj) {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
}

// Az okot előbb elküldjük, és csak kicsit később bontunk: ha a kettő egyszerre érkezik,
// a játék már csak a bontást látja, az üzenetet nem.
function refuse(ws, msg) {
  sendJson(ws, { t: 'err', m: msg });
  setTimeout(() => { if (ws.readyState <= WebSocket.OPEN) ws.close(1008, 'refused'); }, 1000);
}

function forward(to, data, isBinary) {
  if (!to || to.readyState !== WebSocket.OPEN) return;
  if (to.bufferedAmount > MAX_BUFFERED) {
    to.terminate();
    return;
  }
  to.send(data, { binary: isBinary });
}

function dropGuest(room, id) {
  const g = room.guests.get(id);
  if (!g) return;
  room.guests.delete(id);
  clearTimeout(g.timer);
  if (g.guest.readyState <= WebSocket.OPEN) g.guest.close();
  if (g.pipe && g.pipe.readyState <= WebSocket.OPEN) g.pipe.close();
}

function destroyRoom(code) {
  const room = rooms.get(code);
  if (!room) return;
  rooms.delete(code);
  clearTimeout(room.gone);
  for (const id of [...room.guests.keys()]) dropGuest(room, id);
  if (room.host && room.host.readyState <= WebSocket.OPEN) room.host.close();
}

function onHost(ws, q) {
  const key = q.get('key') || '';
  if (key.length < 8 || key.length > 64) return refuse(ws, 'Hibás szobakulcs.');
  let code = (q.get('code') || '').toUpperCase();
  let room = validCode(code) ? rooms.get(code) : null;
  if (room && room.key !== key) room = null;          // más szobája: új kódot kap
  if (!room) {
    if (rooms.size >= MAX_ROOMS) return refuse(ws, 'A közvetítő szerver megtelt, próbáld később.');
    if (!validCode(code) || rooms.has(code)) code = newCode();
    room = { key, host: null, guests: new Map(), gone: null };
    rooms.set(code, room);
  }
  clearTimeout(room.gone);
  const old = room.host;
  room.host = ws;
  if (old && old.readyState <= WebSocket.OPEN) old.close();
  sendJson(ws, { t: 'room', code });

  ws.on('message', (data, isBinary) => {
    if (isBinary) return;
    let m = null;
    try { m = JSON.parse(data.toString()); } catch (e) { return; }
    if (m && m.t === 'ping') sendJson(ws, { t: 'pong' });
  });
  ws.on('close', () => {
    if (room.host !== ws) return;
    room.host = null;
    room.gone = setTimeout(() => destroyRoom(code), ROOM_LINGER_MS);
  });
}

function onJoin(ws, q) {
  const code = (q.get('code') || '').toUpperCase();
  const room = rooms.get(code);
  if (!room || !room.host || room.host.readyState !== WebSocket.OPEN) {
    return refuse(ws, 'Nincs ilyen szoba. Jó a kód, és a gazda megnyitotta a szobát?');
  }
  if (room.guests.size >= MAX_GUESTS) return refuse(ws, 'A szoba megtelt.');
  const id = crypto.randomBytes(6).toString('hex');
  const g = { guest: ws, pipe: null, queue: [], timer: null };
  g.timer = setTimeout(() => {
    if (!g.pipe) {
      room.guests.delete(id);
      refuse(ws, 'A szoba gazdája nem válaszol.');
    }
  }, PIPE_WAIT_MS);
  room.guests.set(id, g);
  sendJson(room.host, { t: 'guest', id });

  ws.on('message', (data, isBinary) => {
    if (g.pipe) return forward(g.pipe, data, isBinary);
    if (g.queue.length >= MAX_QUEUE) return dropGuest(room, id);
    g.queue.push([data, isBinary]);
  });
  ws.on('close', () => dropGuest(room, id));
}

function onPipe(ws, q) {
  const room = rooms.get((q.get('code') || '').toUpperCase());
  const g = room && room.key === q.get('key') ? room.guests.get(q.get('id') || '') : null;
  if (!g || g.pipe) return ws.close(1008, 'refused');
  const id = q.get('id');
  g.pipe = ws;
  clearTimeout(g.timer);
  for (const [data, isBinary] of g.queue) forward(ws, data, isBinary);
  g.queue = [];
  ws.on('message', (data, isBinary) => forward(g.guest, data, isBinary));
  ws.on('close', () => dropGuest(room, id));
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
  res.end(`Party Mayhem relay: fut, szobák: ${rooms.size}\n`);
});

const wss = new WebSocketServer({ server, perMessageDeflate: false, maxPayload: 16 << 20 });

wss.on('connection', (ws, req) => {
  if (ws._socket) ws._socket.setNoDelay(true);
  ws.alive = true;
  ws.on('pong', () => { ws.alive = true; });
  ws.on('error', () => {});
  const u = new URL(req.url, 'http://relay');
  if (u.pathname === '/host') onHost(ws, u.searchParams);
  else if (u.pathname === '/join') onJoin(ws, u.searchParams);
  else if (u.pathname === '/pipe') onPipe(ws, u.searchParams);
  else ws.close(1008, 'unknown path');
});

// elnémult kapcsolatok kiszűrése
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.alive) { ws.terminate(); continue; }
    ws.alive = false;
    ws.ping();
  }
}, 30000);

server.listen(PORT, () => console.log(`Party Mayhem relay a ${PORT}. porton`));
