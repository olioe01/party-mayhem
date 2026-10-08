import { GameEngine } from '../server/gameEngine';
import { RoomManager } from '../server/rooms';
import { RoomState } from '../shared/types';

async function testGameFlow() {
  console.log('--- STARTING COMPREHENSIVE GAME FLOW TEST ---');
  let latestRoom: RoomState;
  const roomManager = new RoomManager((roomCode, r) => {
    latestRoom = JSON.parse(JSON.stringify(r));
  });
  const engine = roomManager.engine;

  // 1. Create Room
  const room = roomManager.getOrCreateRoom('9999');
  latestRoom = room;
  const liveRoom = room;
  console.log('✅ Room created: 9999');

  // 2. Join 2 Players (Bence, Anna)
  const bence = roomManager.joinPlayer('9999', 'sock_bence', 'Bence', 'fox', 'top-hat');
  const anna = roomManager.joinPlayer('9999', 'sock_anna', 'Anna', 'cat', 'cap');
  console.log(`✅ Players joined: Bence (${bence.player.id}), Anna (${anna.player.id})`);

  // 3. Start Game
  engine.startGame(liveRoom);
  console.log(`✅ Game started: phase=${liveRoom.phase}, currentPlayer=${liveRoom.playerOrder[liveRoom.currentPlayerIndex]}`);
  if (liveRoom.phase !== 'BOARD_ROLL') {
    throw new Error(`Expected phase BOARD_ROLL, got ${liveRoom.phase}`);
  }

  // 4. Test Dice Roll and Movement Flow
  const activePlayerId = liveRoom.playerOrder[liveRoom.currentPlayerIndex];
  console.log(`Active player rolling dice...`);
  const roll = engine.rollDice(liveRoom, activePlayerId);
  console.log(`✅ Dice rolled: result=${roll}, phase=${liveRoom.phase}`);
  if (liveRoom.phase !== 'BOARD_ROLLING') {
    throw new Error(`Expected phase BOARD_ROLLING, got ${liveRoom.phase}`);
  }

  // Wait for 3D dice roll animation duration (1800ms) -> should transition to BOARD_MOVE
  console.log('Waiting for 3D dice roll tumble animation (1900ms)...');
  await new Promise(r => setTimeout(r, 1950));
  console.log(`✅ After dice roll: phase=${liveRoom.phase}, movementPath=${liveRoom.movementPath ? 'present' : 'null'}`);
  if (liveRoom.phase !== 'BOARD_MOVE' || !liveRoom.movementPath) {
    throw new Error(`Expected phase BOARD_MOVE with movementPath, got phase=${liveRoom.phase}`);
  }
  console.log(`   Path: ${liveRoom.movementPath.path.join(' -> ')}`);

  // Wait for movement to finish
  console.log('Waiting for step-by-step character hopping to finish...');
  await new Promise(r => setTimeout(r, 2500));
  console.log(`✅ After movement: phase=${liveRoom.phase}, player boardPosition=${liveRoom.players[activePlayerId].boardPosition}`);

  // 5. Test Minigame Intro & Ready System
  console.log('\n--- TESTING MINIGAME INTRO & READY SYSTEM ---');
  engine.startMinigameIntro(liveRoom, 'reaction-rush');
  console.log(`✅ Minigame started: phase=${liveRoom.phase}, name=${liveRoom.activeMinigame?.name}`);
  if (liveRoom.phase !== 'MINIGAME_INTRO') {
    throw new Error(`Expected phase MINIGAME_INTRO, got ${liveRoom.phase}`);
  }

  // Verify all players have minigameReady = false initially
  const benceReady1 = liveRoom.players[bence.player.id].minigameReady;
  const annaReady1 = liveRoom.players[anna.player.id].minigameReady;
  console.log(`✅ Initial ready status: Bence=${benceReady1}, Anna=${annaReady1}`);
  if (benceReady1 || annaReady1) {
    throw new Error('Expected all players to be NOT ready initially!');
  }

  // Verify minigame timeRemaining is NOT ticking down during INTRO
  const initialTime = latestRoom.activeMinigame?.timeRemaining;
  await new Promise(r => setTimeout(r, 500));
  const timeAfter500 = latestRoom.activeMinigame?.timeRemaining;
  if (initialTime !== timeAfter500) {
    throw new Error('Minigame timer must NOT tick during intro/ready phase!');
  }
  console.log(`✅ Minigame timer is frozen during INTRO as expected (${timeAfter500}s)`);

  // Bence presses READY
  console.log('Bence presses READY on phone...');
  engine.handleMinigameReady(liveRoom, bence.player.id);
  console.log(`✅ Bence ready: ${liveRoom.players[bence.player.id].minigameReady}`);
  console.log(`   Phase still MINIGAME_INTRO because Anna is not ready yet: ${liveRoom.phase}`);
  if (liveRoom.phase !== 'MINIGAME_INTRO') {
    throw new Error('Phase should remain MINIGAME_INTRO until ALL players are ready!');
  }

  // Test Reconnect during ready: Bence reconnects, should REMEMBER that he was ready!
  console.log('Testing reconnect during ready state: Bence reconnects...');
  const reconnectResult = roomManager.reconnectPlayer('9999', 'sock_bence_new', bence.player.playerToken);
  console.log(`✅ Reconnect success: player minigameReady=${reconnectResult.player?.minigameReady}`);
  if (!reconnectResult.player?.minigameReady) {
    throw new Error('Player minigameReady flag must be preserved across reconnections!');
  }

  // Now Anna presses READY
  console.log('Anna presses READY on phone...');
  engine.handleMinigameReady(liveRoom, anna.player.id);
  console.log(`✅ All players ready! Current phase=${latestRoom.phase}`);
  if (latestRoom.phase !== 'MINIGAME_COUNTDOWN') {
    throw new Error(`Expected phase MINIGAME_COUNTDOWN, got ${latestRoom.phase}`);
  }

  // Wait for countdown (3200ms) to transition to MINIGAME_PLAY
  console.log('Waiting for 3... 2... 1... countdown (3300ms)...');
  await new Promise(r => setTimeout(r, 3400));
  console.log(`✅ After countdown: phase=${latestRoom.phase}`);
  if (latestRoom.phase !== 'MINIGAME_PLAY') {
    throw new Error(`Expected phase MINIGAME_PLAY, got ${latestRoom.phase}`);
  }

  engine.clearAllTimers();
  console.log('\n🎉 ALL TESTS PASSED SUCCESSFULLY! EVERYTHING WORKS AS SPECIFIED!');
  process.exit(0);
}

testGameFlow().catch(err => {
  console.error('❌ TEST FAILED:', err);
  process.exit(1);
});
