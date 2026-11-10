// Party Mayhem – helyi szerver
// A "host" (TV/laptop) böngésző futtatja a játékot, a telefonok kontrollerek.
// A szerver csak továbbítja az üzeneteket a host és a telefonok között.

const express = require('express');
const http = require('http');
const os = require('os');
const path = require('path');
const QRCode = require('qrcode');
const { Server } = require('socket.io');

const PORT = Number(process.env.PORT) || 3000;
const PUBLIC_HOST = process.env.PUBLIC_HOST || null; // pl. 192.168.1.20 – ha az automatikus IP nem jó
const PUBLIC_URL = process.env.PUBLIC_URL || null;   // teljes cím, pl. Cloudflare tunnel (https://xyz.trycloudflare.com)

const app = express();
const server = http.createServer(app);
const io = new Server(server, { pingInterval: 5000, pingTimeout: 8000 });

app.use(express.static(path.join(__dirname, 'public')));
app.use('/vendor/three', express.static(path.join(__dirname, 'node_modules', 'three')));
app.get('/host', (req, res) => res.sendFile(path.join(__dirname, 'public', 'host.html')));

function lanAddresses() {
  const out = [];
  for (const [name, list] of Object.entries(os.networkInterfaces())) {
    for (const a of list || []) {
      if (a.family !== 'IPv4' || a.internal) continue;
      if (/^(docker|br-|veth)/.test(name)) continue;
      out.push(a.address);
    }
  }
  // a tipikus otthoni (192.168.x.x) címek előre
  return out.sort((a, b) => (b.startsWith('192.168.') - a.startsWith('192.168.')));
}

app.get('/api/info', (req, res) => {
  res.json({ port: PORT, addresses: lanAddresses(), publicHost: PUBLIC_HOST, publicUrl: PUBLIC_URL });
});

app.get('/api/qr', async (req, res) => {
  const url = String(req.query.url || '').slice(0, 300);
  try {
    const svg = await QRCode.toString(url, {
      type: 'svg', margin: 1, errorCorrectionLevel: 'M',
      color: { dark: '#1b1036', light: '#ffffff' },
    });
    res.type('image/svg+xml').send(svg);
  } catch {
    res.status(400).end();
  }
});

let host = null;                 // a host socket
const players = new Map();       // pid -> socket

const cleanStr = (s, max) => String(s ?? '').replace(/[\u0000-\u001f]/g, '').trim().slice(0, max);

io.on('connection', (socket) => {
  socket.on('host:hello', () => {
    if (host && host.id !== socket.id) host.emit('host:replaced');
    host = socket;
    socket.data.role = 'host';
    for (const [pid, s] of players) socket.emit('p:join', { pid, name: s.data.name });
    for (const s of players.values()) s.emit('host:online');
  });

  socket.on('player:join', (data) => {
    const pid = cleanStr(data?.pid, 40);
    const name = cleanStr(data?.name, 14) || 'Játékos';
    if (!pid) return;
    const old = players.get(pid);
    if (old && old.id !== socket.id) old.disconnect(true);
    players.set(pid, socket);
    socket.data = { role: 'player', pid, name };
    if (host) host.emit('p:join', { pid, name });
    else socket.emit('host:offline');
  });

  socket.on('player:input', (msg) => {
    if (socket.data.role !== 'player' || !msg || typeof msg !== 'object') return;
    host?.emit('p:input', { pid: socket.data.pid, msg });
  });

  socket.on('host:send', ({ pid, msg } = {}) => {
    if (socket !== host) return;
    players.get(pid)?.emit('ctrl', msg);
  });

  socket.on('disconnect', () => {
    if (socket === host) {
      host = null;
      for (const s of players.values()) s.emit('host:offline');
      return;
    }
    const { role, pid } = socket.data || {};
    if (role === 'player' && players.get(pid) === socket) {
      players.delete(pid);
      host?.emit('p:leave', { pid });
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  const addrs = PUBLIC_HOST ? [PUBLIC_HOST] : lanAddresses();
  console.log('\n  🎉 PARTY MAYHEM fut!\n');
  console.log(`  Játékképernyő (TV/laptop):  http://localhost:${PORT}/host`);
  if (PUBLIC_URL) console.log(`  Telefonok (tunnel):         ${PUBLIC_URL}`);
  for (const a of addrs) console.log(`  Telefonok:                  http://${a}:${PORT}`);
  console.log('');
});
