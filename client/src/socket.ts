import { io, Socket } from 'socket.io-client';

// Connect to current window.location.origin (LAN IP or domain)
export const socket: Socket = io(window.location.origin, {
  autoConnect: true,
  reconnection: true,
  reconnectionAttempts: Infinity,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
  timeout: 10000,
  transports: ['websocket', 'polling']
});
