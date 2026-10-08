import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import os from 'os';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { createServer as createViteServer } from 'vite';
import { Bonjour } from 'bonjour-service';
import { RoomManager } from './rooms';
import { setupSocketHandlers } from './socketHandlers';
import { SOCKET_EVENTS } from '../shared/events';
import { HealthResponse } from '../shared/types';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export interface LanNetworkInfo {
  recommendedIp: string;
  allIps: { name: string; address: string; isLikelyPhysical: boolean }[];
  alternativeIps: string[];
}

export function detectLanNetworkInfo(): LanNetworkInfo {
  const envIp = process.env.HOST_IP || process.env.LAN_IP;
  if (envIp) {
    return {
      recommendedIp: envIp,
      allIps: [{ name: 'env', address: envIp, isLikelyPhysical: true }],
      alternativeIps: []
    };
  }

  const interfaces = os.networkInterfaces();
  const candidates: { name: string; address: string; score: number }[] = [];

  for (const name of Object.keys(interfaces)) {
    const ifaceList = interfaces[name];
    if (!ifaceList) continue;

    const lowerName = name.toLowerCase();
    const isVirtual = /docker|veth|br-|tailscale|tun|tap|wsl|vbox|vmnet|hyper-v|vethernet/.test(lowerName);

    for (const iface of ifaceList) {
      if (iface.family !== 'IPv4' || iface.internal) continue;
      const addr = iface.address;
      if (addr.startsWith('127.') || addr.startsWith('169.254.')) continue;

      let score = 0;
      if (!isVirtual) score += 50;

      // Prioritize Wi-Fi and Ethernet
      if (/wlan|wi-fi|wifi|eth|en|wl/.test(lowerName)) score += 30;

      // Subnet preferences
      if (addr.startsWith('192.168.')) {
        // Penalize VirtualBox default host-only 192.168.56.x
        if (addr.startsWith('192.168.56.')) {
          score += 5;
        } else {
          score += 40;
        }
      } else if (addr.startsWith('10.')) {
        score += 30;
      } else if (/^172\.(1[6-9]|2\d|3[01])\./.test(addr)) {
        score += 20;
      }

      candidates.push({ name, address: addr, score });
    }
  }

  candidates.sort((a, b) => b.score - a.score);

  const recommendedIp = candidates.length > 0 ? candidates[0].address : '127.0.0.1';
  const alternativeIps = candidates.slice(1).map(c => c.address);
  const allIps = candidates.map(c => ({
    name: c.name,
    address: c.address,
    isLikelyPhysical: c.score >= 50
  }));

  return { recommendedIp, allIps, alternativeIps };
}

async function findAvailablePort(startPort: number): Promise<number> {
  const net = await import('net');
  return new Promise((resolve) => {
    const tester = net.createServer();
    tester.once('error', (err: any) => {
      if (err.code === 'EADDRINUSE') {
        resolve(findAvailablePort(startPort + 1));
      } else {
        resolve(startPort);
      }
    });
    tester.once('listening', () => {
      tester.close(() => resolve(startPort));
    });
    tester.listen(startPort, '0.0.0.0');
  });
}

async function startServer() {
  const app = express();
  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: '*' }
  });

  const requestedPort = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
  const PORT = await findAvailablePort(requestedPort);
  const DEFAULT_ROOM = '4827';
  const netInfo = detectLanNetworkInfo();
  const recommendedIp = netInfo.recommendedIp;

  // Room manager with socket broadcast
  const roomManager = new RoomManager((roomCode, state) => {
    state.serverLanIp = recommendedIp;
    state.serverPort = PORT;
    state.serverLanUrl = `http://${recommendedIp}:${PORT}`;
    io.to(roomCode).emit(SOCKET_EVENTS.ROOM_STATE, state);
  }, recommendedIp, PORT);

  setupSocketHandlers(io, roomManager);

  app.use(cors());
  app.use(express.json());

  // GET /api/health - Instant check for phones and laptops
  app.get('/api/health', (req, res) => {
    const response: HealthResponse = {
      status: 'ok',
      server: 'Party Mayhem',
      time: Date.now(),
      lanIp: recommendedIp,
      port: PORT,
      uptime: Math.floor(process.uptime())
    };
    res.json(response);
  });

  // API endpoint for server info
  app.get('/api/info', (req, res) => {
    const currentNet = detectLanNetworkInfo();
    res.json({
      name: 'PARTY MAYHEM',
      version: '1.0.0',
      defaultRoom: DEFAULT_ROOM,
      lanIp: currentNet.recommendedIp,
      port: PORT,
      lanUrl: `http://${currentNet.recommendedIp}:${PORT}`,
      alternativeLanIps: currentNet.alternativeIps
    });
  });

  // API endpoint to reset room cleanly to Lobby
  app.all('/api/reset', (req, res) => {
    const room = roomManager.getRoom('4827');
    if (room) {
      roomManager.engine.restartGame(room, true);
    }
    res.json({ success: true, message: 'Room 4827 reset to Lobby' });
  });

  const distPath = path.resolve(__dirname, '../dist/client');
  const hasDist = fs.existsSync(path.join(distPath, 'index.html'));

  if (hasDist) {
    // Serve production built client
    app.use(express.static(distPath));
    app.use((req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  } else {
    // Vite dev middleware fallback
    const vite = await createViteServer({
      configFile: path.resolve(__dirname, '../vite.config.ts'),
      server: { middlewareMode: true },
      appType: 'spa'
    });
    app.use(vite.middlewares);
  }

  server.listen(PORT, '0.0.0.0', () => {
    // Try starting mDNS advertiser
    try {
      const bonjour = new Bonjour();
      bonjour.publish({
        name: 'partymayhem',
        type: 'http',
        port: PORT,
        host: 'partymayhem.local'
      });
    } catch (e) {
      // mDNS fallback silently handled
    }

    console.log('\n=========================================');
    console.log('PARTY MAYHEM SERVER\n');
    console.log('Local:');
    console.log(`http://localhost:${PORT}\n`);
    console.log('LAN:');
    console.log(`http://${recommendedIp}:${PORT}\n`);

    if (netInfo.alternativeIps.length > 0) {
      console.log('Alternative LAN interfaces:');
      netInfo.alternativeIps.forEach(ip => {
        console.log(`http://${ip}:${PORT}`);
      });
      console.log('');
    }

    console.log('Recommended:');
    console.log(`http://${recommendedIp}:${PORT}\n`);
    console.log('HOST:');
    console.log(`http://${recommendedIp}:${PORT}/host\n`);
    console.log('PLAYERS:');
    console.log(`http://${recommendedIp}:${PORT}/join\n`);
    console.log('HEALTH:');
    console.log(`http://${recommendedIp}:${PORT}/api/health\n`);
    console.log('ROOM CODE:');
    console.log(`${DEFAULT_ROOM}\n`);
    console.log('=========================================\n');
  });
}

startServer().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

