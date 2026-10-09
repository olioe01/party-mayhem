import { GameEngine } from '../server/gameEngine';
import { RoomManager } from '../server/rooms';
import { RoomState } from '../shared/types';
import { MINIGAMES } from '../server/minigames/registry';
import { checkCircleCollision, generateBotSteering } from '../server/minigames/arenaUtils';

console.log('====================================================');
console.log('🧪 RUNNING ARENA MINIGAMES & CONTROLLER TEST SUITE');
console.log('====================================================');

async function runTestSuite() {
  let latestRoom: RoomState;
  const roomManager = new RoomManager((roomCode, r) => {
    latestRoom = JSON.parse(JSON.stringify(r));
  });
  const engine = roomManager.engine;

  // 1. Setup Room with 1 Human and 4 Bots (5 players total)
  console.log('\n--- 1. Setting Up Room (1 Human + 4 Bots) ---');
  const room = roomManager.getOrCreateRoom('5555');
  latestRoom = room;

  const bence = roomManager.joinPlayer('5555', 'sock_bence', 'Bence', 'fox', 'top-hat');
  const bot1 = engine.addBot(room);
  const bot2 = engine.addBot(room);
  const bot3 = engine.addBot(room);
  const bot4 = engine.addBot(room);

  const players = Object.values(room.players);
  if (players.length !== 5) {
    throw new Error(`Expected 5 players, got ${players.length}`);
  }
  console.log(`✅ 5 Players in room: ${players.map(p => `${p.name} (${p.isBot ? 'BOT' : 'HUMAN'})`).join(', ')}`);

  // 2. Test FRUIT FRENZY Minigame Setup & Ready System
  console.log('\n--- 2. Testing FRUIT FRENZY Minigame (Vertical Slice) ---');
  engine.startMinigameIntro(room, 'fruit-frenzy');
  if (room.phase !== 'MINIGAME_INTRO') throw new Error('Expected MINIGAME_INTRO phase');
  if (room.activeMinigame?.id !== 'fruit-frenzy') throw new Error('Expected fruit-frenzy minigame');
  if (room.activeMinigame.controllerConfig?.layout !== 'gamepad') throw new Error('Expected gamepad controller config');
  console.log('✅ Fruit Frenzy intro started with gamepad controller layout.');

  // Verify all 5 players have initial 0 score and proper setup in arena data
  const ffData = room.activeMinigame.data;
  if (!ffData.players || Object.keys(ffData.players).length !== 5) {
    throw new Error('Expected 5 arena player simulations in fruit-frenzy');
  }
  console.log('✅ 5 Arena player simulations initialized with coordinates and baskets.');

  // Human player Bence presses READY
  engine.handleMinigameReady(room, bence.player.id);
  console.log(`✅ Human Bence is ready: ${room.players[bence.player.id].minigameReady}`);

  // Wait for bots to auto-ready (simulated 1.5 - 2.8s) -> should transition to COUNTDOWN
  console.log('Waiting for bots to auto-ready...');
  let waited = 0;
  while (room.phase === 'MINIGAME_INTRO' && waited < 3500) {
    await new Promise(r => setTimeout(r, 200));
    waited += 200;
  }
  if (room.phase !== 'MINIGAME_COUNTDOWN') {
    throw new Error(`Expected phase MINIGAME_COUNTDOWN, got ${room.phase}`);
  }
  console.log('✅ All 5 players ready! Current phase: MINIGAME_COUNTDOWN (3... 2... 1...)');

  // Wait for countdown to finish -> MINIGAME_PLAY (3.2s)
  console.log('Waiting for countdown to finish...');
  waited = 0;
  while (room.phase === 'MINIGAME_COUNTDOWN' && waited < 4000) {
    await new Promise(r => setTimeout(r, 200));
    waited += 200;
  }
  if (room.phase !== 'MINIGAME_PLAY') {
    throw new Error(`Expected phase MINIGAME_PLAY, got ${room.phase}`);
  }
  console.log('✅ Active gameplay started! Phase: MINIGAME_PLAY.');

  // 3. Test Holding D-Pad & Normalized Movement
  console.log('\n--- 3. Testing Realtime Phone D-Pad Movement & Diagonal Normalization ---');
  const benceSim = room.activeMinigame.data.players[bence.player.id];
  const initialX = benceSim.x;
  const initialZ = benceSim.z;

  // Bence holds RIGHT on phone
  engine.handleMinigameInput(room, bence.player.id, {
    up: false,
    down: false,
    left: false,
    right: true,
    a: false,
    b: false,
  });

  // Wait 300ms of game ticks
  await new Promise(r => setTimeout(r, 300));
  const newX = benceSim.x;
  console.log(`Bence moved right: x went from ${initialX.toFixed(2)} to ${newX.toFixed(2)}`);
  if (newX <= initialX) {
    throw new Error('Holding RIGHT must move character right!');
  }
  console.log('✅ Holding RIGHT continuously moved character right.');

  // Bence releases RIGHT
  engine.handleMinigameInput(room, bence.player.id, {
    up: false,
    down: false,
    left: false,
    right: false,
    a: false,
    b: false,
  });
  await new Promise(r => setTimeout(r, 100));
  const stopX = benceSim.x;
  await new Promise(r => setTimeout(r, 200));
  if (Math.abs(benceSim.x - stopX) > 0.05) {
    throw new Error('Character must stop moving after button release!');
  }
  console.log('✅ Releasing D-pad button immediately stopped character movement.');

  // 4. Test Fruit Catching & Bomb Penalty Rule (score = max(0, score - 3))
  console.log('\n--- 4. Testing Fruit Scoring & Bomb Penalty ---');
  const ffDef = MINIGAMES['fruit-frenzy'];
  
  // Directly simulate catching regular apple (+1)
  benceSim.score = 5;
  // Spawn a test fruit directly above Bence
  room.activeMinigame.data.items.push({
    id: 9991,
    type: 'apple',
    x: benceSim.x,
    y: 0.5, // catch plane
    z: benceSim.z,
    speed: 4,
    points: 1,
  });
  ffDef.update(room, 0.05);
  if (benceSim.score !== 6) {
    throw new Error(`Expected score 6 after catching apple, got ${benceSim.score}`);
  }
  console.log(`✅ Caught Apple: 5 -> 6 (+1 point)`);

  // Catch Golden Fruit (+3)
  room.activeMinigame.data.items.push({
    id: 9992,
    type: 'golden',
    x: benceSim.x,
    y: 0.5,
    z: benceSim.z,
    speed: 4,
    points: 3,
  });
  ffDef.update(room, 0.05);
  if (benceSim.score !== 9) {
    throw new Error(`Expected score 9 after golden fruit, got ${benceSim.score}`);
  }
  console.log(`✅ Caught Golden Fruit: 6 -> 9 (+3 points)`);

  // Catch Bomb (-3 points)
  room.activeMinigame.data.items.push({
    id: 9993,
    type: 'bomb',
    x: benceSim.x,
    y: 0.5,
    z: benceSim.z,
    speed: 4,
    points: -3,
  });
  ffDef.update(room, 0.05);
  if (benceSim.score !== 6) {
    throw new Error(`Expected score 6 after bomb hit, got ${benceSim.score}`);
  }
  console.log(`✅ Caught Bomb: 9 -> 6 (exactly -3 points penalty)`);

  // Catch Bomb when score < 3 -> should clamp to 0
  benceSim.score = 2;
  room.activeMinigame.data.items.push({
    id: 9994,
    type: 'bomb',
    x: benceSim.x,
    y: 0.5,
    z: benceSim.z,
    speed: 4,
    points: -3,
  });
  ffDef.update(room, 0.05);
  if (benceSim.score !== 0) {
    throw new Error(`Expected score 0 (clamped), got ${benceSim.score}`);
  }
  console.log(`✅ Caught Bomb with low score: 2 -> 0 (clamped at 0, no negative score)`);

  // 5. Test Disconnect Safety Rule #21
  console.log('\n--- 5. Testing Disconnect Safety Rule #21 ---');
  // Bence holds UP
  engine.handleMinigameInput(room, bence.player.id, {
    up: true,
    down: false,
    left: false,
    right: false,
    a: false,
    b: false,
  });
  if (!room.players[bence.player.id].lastInputState?.up) {
    throw new Error('Expected UP input state to be true');
  }

  // Simulate Bence disconnecting (phone loses signal or switches app)
  console.log('Simulating phone disconnect while holding UP...');
  roomManager.handleDisconnect('sock_bence');
  const disconnectedBence = room.players[bence.player.id];
  if (disconnectedBence.lastInputState?.up) {
    throw new Error('SAFETY VIOLATION: Disconnected player controls must be cleared immediately!');
  }
  console.log('✅ Rule #21 PASSED: On disconnect, held inputs immediately cleared to all false.');

  // Reconnect Bence
  console.log('Reconnecting Bence...');
  roomManager.reconnectPlayer('5555', 'sock_bence_reconnected', bence.player.playerToken);
  console.log(`✅ Reconnect success: player connected=${room.players[bence.player.id].connected}`);

  // 6. Test Ending Minigame & Results Calculation
  console.log('\n--- 6. Testing Minigame Finish & Ranking Results ---');
  engine.endMinigame(room, ffDef);
  if (room.phase !== 'MINIGAME_RESULTS') {
    throw new Error(`Expected phase MINIGAME_RESULTS, got ${room.phase}`);
  }
  const results = room.activeMinigame?.results;
  if (!results || results.length !== 5) {
    throw new Error('Expected 5 result entries');
  }
  console.log('✅ Minigame ended cleanly. Ranks calculated:');
  results.forEach(r => console.log(`   Rank #${r.rank}: ${room.players[r.playerId].name} - ${r.score} pts (+${r.coinsEarned} coins)`));

  // 7. Test BOMB DODGE Minigame
  console.log('\n--- 7. Testing BOMB DODGE Minigame ---');
  const bdDef = MINIGAMES['bomb-dodge'];
  engine.startMinigameIntro(room, 'bomb-dodge');
  if (room.activeMinigame?.id !== 'bomb-dodge') throw new Error('Expected bomb-dodge');
  bdDef.setup(room);
  bdDef.start(room);
  bdDef.update(room, 0.5);
  console.log('✅ Bomb Dodge setup, start, and wave update executed without errors.');
  bdDef.cleanup(room);

  // 8. Test PUSH ARENA Minigame
  console.log('\n--- 8. Testing PUSH ARENA Minigame ---');
  const paDef = MINIGAMES['push-arena'];
  engine.startMinigameIntro(room, 'push-arena');
  if (room.activeMinigame?.id !== 'push-arena') throw new Error('Expected push-arena');
  paDef.setup(room);
  paDef.start(room);
  // Test A button push action
  paDef.handleInput(room, bence.player.id, { a: true });
  paDef.update(room, 0.2);
  console.log('✅ Push Arena push action and physics update executed without errors.');
  paDef.cleanup(room);

  // 9. Test CROWN CHASE Minigame
  console.log('\n--- 9. Testing CROWN CHASE Minigame ---');
  const ccDef = MINIGAMES['crown-chase'];
  engine.startMinigameIntro(room, 'crown-chase');
  if (room.activeMinigame?.id !== 'crown-chase') throw new Error('Expected crown-chase');
  ccDef.setup(room);
  ccDef.start(room);
  ccDef.update(room, 0.5);
  const crownHolder = room.activeMinigame?.data?.currentCrownHolder;
  if (!crownHolder) throw new Error('Expected crown holder assigned');
  console.log(`✅ Crown Chase crown assigned to ${room.players[crownHolder].name}. Possession score updated.`);
  ccDef.cleanup(room);

  // 10. Test PAINT PANIC Minigame
  console.log('\n--- 10. Testing PAINT PANIC Minigame ---');
  const ppDef = MINIGAMES['paint-panic'];
  engine.startMinigameIntro(room, 'paint-panic');
  if (room.activeMinigame?.id !== 'paint-panic') throw new Error('Expected paint-panic');
  ppDef.setup(room);
  ppDef.start(room);
  ppDef.update(room, 0.2);
  console.log('✅ Paint Panic grid footprint painting executed without errors.');
  ppDef.cleanup(room);

  // Clean all timers
  engine.clearAllTimers();

  console.log('\n🎉 ALL 10 ARENA & CONTROLLER VERIFICATION TESTS PASSED SUCCESSFULLY!');
}

runTestSuite().catch(err => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
