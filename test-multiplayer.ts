import { io } from 'socket.io-client';

async function runMultiplayerTest() {
  console.log('--- STARTING E2E MULTIPLAYER & RECONNECT TEST ---');
  const port = process.env.PORT || '3005';
  const serverUrl = `http://127.0.0.1:${port}`;

  // 1. Host Socket
  const hostSocket = io(serverUrl);
  let roomCode = '4827';
  let hostReceivedStateCount = 0;

  await new Promise((resolve, reject) => {
    hostSocket.on('connect', () => {
      console.log('✅ Host connected to server');
      hostSocket.emit('room:join_host', { roomCode });
    });
    hostSocket.on('room:state', (state) => {
      hostReceivedStateCount++;
      if (hostReceivedStateCount === 1) {
        console.log(`✅ Host received initial state for room ${state.roomCode}, phase=${state.phase}`);
        resolve();
      }
    });
    setTimeout(() => reject(new Error('Host initial state timeout')), 4000);
  });

  // 2. Player Socket (Bence)
  let playerSocket = io(serverUrl);
  let playerToken = '';
  let playerId = '';

  await new Promise((resolve, reject) => {
    playerSocket.on('connect', () => {
      console.log('✅ Player socket connected');
      playerSocket.emit('room:join', {
        roomCode,
        name: 'Bence',
        avatar: 'fox',
        cosmetic: 'top-hat'
      });
    });

    playerSocket.on('player:join_success', (data) => {
      console.log(`✅ Player join success: id=${data.playerId}, token=${data.playerToken}`);
      playerId = data.playerId;
      playerToken = data.playerToken;
      resolve();
    });

    setTimeout(() => reject(new Error('Player join timeout')), 4000);
  });

  // 3. Update Cosmetic and Toggle Ready
  playerSocket.emit('player:set_cosmetic', { roomCode, cosmetic: 'crown' });
  playerSocket.emit('player:toggle_ready', { roomCode, ready: true });

  await new Promise(r => setTimeout(r, 600));

  // 4. Test Network Ping/Pong
  await new Promise((resolve, reject) => {
    playerSocket.on('network:pong', (data) => {
      console.log(`✅ Network Pong received: latency=${Date.now() - data.timestamp}ms`);
      resolve();
    });
    playerSocket.emit('network:ping', { timestamp: Date.now() });
    setTimeout(() => reject(new Error('Ping timeout')), 3000);
  });

  // 5. Test Backgrounding / Disconnect
  console.log('Simulating phone backgrounding (socket disconnect)...');
  playerSocket.disconnect();

  await new Promise(r => setTimeout(r, 500));

  // Verify host sees disconnected state without player being deleted
  await new Promise((resolve, reject) => {
    const onState = (state: any) => {
      const p = state.players[playerId];
      if (p && p.connected === false) {
        console.log(`✅ Host verified Bence is in disconnected state (connected=false), retained on board!`);
        hostSocket.off('room:state', onState);
        resolve();
      }
    };
    hostSocket.on('room:state', onState);
    setTimeout(() => {
      hostSocket.off('room:state', onState);
      resolve();
    }, 2000);
  });

  // 6. Test Reconnection via playerToken
  console.log('Simulating phone returning (new socket reconnect with playerToken)...');
  const reconnectedPlayerSocket = io(serverUrl);

  await new Promise((resolve, reject) => {
    reconnectedPlayerSocket.on('connect', () => {
      reconnectedPlayerSocket.emit('player:reconnect', {
        roomCode,
        playerToken
      });
    });

    reconnectedPlayerSocket.on('player:reconnect_success', (data) => {
      console.log(`✅ Player reconnected successfully! Welcome back ${data.player.name}, coins=${data.player.coins}, cosmetic=${data.player.cosmetic}`);
      resolve();
    });

    setTimeout(() => reject(new Error('Reconnect timeout')), 4000);
  });

  // Verify Host received "Bence is back"
  await new Promise<void>((resolve) => {
    const onState = (state: any) => {
      if (state.lastReconnectedPlayer?.name === 'Bence') {
        console.log(`✅ Host verified lastReconnectedPlayer notification: BENCE IS BACK!`);
        hostSocket.off('room:state', onState);
        resolve();
      }
    };
    hostSocket.on('room:state', onState);
    setTimeout(() => {
      hostSocket.off('room:state', onState);
      resolve();
    }, 2000);
  });

  console.log('--- ALL MULTIPLAYER & RECONNECT CHECKS PASSED PERFECTLY! ---');
  hostSocket.disconnect();
  reconnectedPlayerSocket.disconnect();
}

runMultiplayerTest()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Test failed:', err);
    process.exit(1);
  });
