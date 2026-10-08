import { Server, Socket } from 'socket.io';
import { RoomManager } from './rooms';
import { SOCKET_EVENTS } from '../shared/events';
import { PARTY_MODE_ROUNDS } from '../shared/constants';
import { PartyMode, HatId } from '../shared/types';

export function setupSocketHandlers(io: Server, roomManager: RoomManager) {
  io.on('connection', (socket: Socket) => {
    let currentRoomCode: string | null = null;
    let isHost = false;

    // Join as Host screen
    socket.on(SOCKET_EVENTS.JOIN_HOST, (data: { roomCode?: string }) => {
      const roomCode = data?.roomCode || '4827';
      currentRoomCode = roomCode;
      isHost = true;
      socket.join(roomCode);
      const room = roomManager.joinHost(roomCode, socket.id);
      socket.emit(SOCKET_EVENTS.ROOM_STATE, room);
    });

    // Join as Mobile Player controller
    socket.on(SOCKET_EVENTS.JOIN_ROOM, (data: { roomCode: string; name: string; avatar: any; cosmetic?: HatId; playerToken?: string }) => {
      const roomCode = data?.roomCode || '4827';
      currentRoomCode = roomCode;
      isHost = false;
      socket.join(roomCode);
      const { room, player, isReconnect } = roomManager.joinPlayer(
        roomCode,
        socket.id,
        data.name,
        data.avatar,
        data.cosmetic,
        data.playerToken
      );

      // Confirm join with player credentials
      socket.emit(SOCKET_EVENTS.PLAYER_JOIN_SUCCESS, {
        playerId: player.id,
        playerToken: player.playerToken,
        roomCode: room.roomCode,
        isReconnect
      });

      io.to(roomCode).emit(SOCKET_EVENTS.ROOM_STATE, room);
    });

    // Explicit Reconnect with playerToken
    socket.on(SOCKET_EVENTS.RECONNECT_PLAYER, (data: { roomCode: string; playerToken: string }) => {
      const roomCode = data?.roomCode || '4827';
      const result = roomManager.reconnectPlayer(roomCode, socket.id, data.playerToken);
      if (result.success && result.room && result.player) {
        currentRoomCode = roomCode;
        socket.join(roomCode);
        socket.emit(SOCKET_EVENTS.PLAYER_RECONNECT_SUCCESS, {
          player: result.player,
          room: result.room
        });
        io.to(roomCode).emit(SOCKET_EVENTS.ROOM_STATE, result.room);
      } else {
        socket.emit(SOCKET_EVENTS.ERROR, { message: result.error || 'Újracsatlakozási hiba' });
      }
    });

    // Player updates cosmetic
    socket.on(SOCKET_EVENTS.SET_COSMETIC, (data: { roomCode: string; playerId?: string; cosmetic: HatId }) => {
      const { player } = roomManager.getPlayerBySocket(socket.id);
      const playerId = player?.id || data?.playerId;
      if (playerId) {
        roomManager.setCosmetic(data.roomCode || currentRoomCode || '4827', playerId, data.cosmetic);
      }
    });

    // Player toggles ready status
    socket.on(SOCKET_EVENTS.TOGGLE_READY, (data: { roomCode: string; playerId?: string; ready?: boolean }) => {
      const { player } = roomManager.getPlayerBySocket(socket.id);
      const playerId = player?.id || data?.playerId;
      if (playerId) {
        roomManager.toggleReady(data.roomCode || currentRoomCode || '4827', playerId, data.ready);
      }
    });

    // Network latency / Ping check
    socket.on(SOCKET_EVENTS.PING_CHECK, (data: { timestamp: number }) => {
      socket.emit(SOCKET_EVENTS.PONG_CHECK, {
        timestamp: data.timestamp,
        serverTime: Date.now()
      });
    });

    // Host Controls: Kick Player
    socket.on(SOCKET_EVENTS.KICK_PLAYER, (data: { roomCode: string; playerId: string }) => {
      roomManager.kickPlayer(data.roomCode, data.playerId);
    });

    // Host Controls: Party Mode (Quick/Normal/Chaos)
    socket.on(SOCKET_EVENTS.SET_PARTY_MODE, (data: { roomCode: string; mode: PartyMode }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        room.partyMode = data.mode;
        room.totalRounds = PARTY_MODE_ROUNDS[data.mode] || 12;
        io.to(data.roomCode).emit(SOCKET_EVENTS.ROOM_STATE, room);
      }
    });

    // Host Controls: Toggle Party Challenge Mode
    socket.on(SOCKET_EVENTS.TOGGLE_PARTY_CHALLENGE, (data: { roomCode: string; enabled: boolean }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        room.partyChallengeEnabled = data.enabled;
        io.to(data.roomCode).emit(SOCKET_EVENTS.ROOM_STATE, room);
      }
    });

    // Host / Dev: Add Bot
    socket.on(SOCKET_EVENTS.ADD_BOT, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        roomManager.engine.addBot(room);
      }
    });

    // Host / Dev: Remove Bot
    socket.on(SOCKET_EVENTS.REMOVE_BOT, (data: { roomCode: string; botId: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        roomManager.engine.removeBot(room, data.botId);
      }
    });

    // Host / Dev: Select specific minigame
    socket.on(SOCKET_EVENTS.DEV_SELECT_MINIGAME, (data: { roomCode: string; minigameId: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        roomManager.engine.startMinigameIntro(room, data.minigameId);
      }
    });

    // Host / Dev: Modify Player Stats
    socket.on(SOCKET_EVENTS.DEV_MODIFY_PLAYER, (data: { roomCode: string; playerId: string; coins?: number; crowns?: number }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room && room.players[data.playerId]) {
        if (data.coins !== undefined) room.players[data.playerId].coins = data.coins;
        if (data.crowns !== undefined) room.players[data.playerId].crowns = data.crowns;
        roomManager.engine.updateRankings(room);
        io.to(data.roomCode).emit(SOCKET_EVENTS.ROOM_STATE, room);
      }
    });

    // Host / Dev: Trigger specific event
    socket.on(SOCKET_EVENTS.DEV_TRIGGER_EVENT, (data: { roomCode: string; eventId?: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        roomManager.engine.triggerRandomChaosEvent(room, data.eventId);
      }
    });

    // Start Game
    socket.on(SOCKET_EVENTS.START_GAME, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        roomManager.engine.startGame(room);
      }
    });

    // Pause Game
    socket.on(SOCKET_EVENTS.PAUSE_GAME, (data: { roomCode: string; isPaused: boolean }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        room.isPaused = data.isPaused;
        io.to(data.roomCode).emit(SOCKET_EVENTS.ROOM_STATE, room);
      }
    });

    // Skip Minigame
    socket.on(SOCKET_EVENTS.SKIP_MINIGAME, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room && room.activeMinigame) {
        roomManager.engine.advanceTurn(room);
      }
    });

    // Restart Game
    socket.on(SOCKET_EVENTS.RESTART_GAME, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      if (room) {
        roomManager.engine.restartGame(room);
      }
    });

    // Player: Roll Dice
    socket.on(SOCKET_EVENTS.PLAYER_ROLL_DICE, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode);
      const { player } = roomManager.getPlayerBySocket(socket.id);
      if (room && player) {
        roomManager.engine.rollDice(room, player.id);
      } else if (room) {
        roomManager.engine.rollDice(room, socket.id);
      }
    });

    // Player: Shop Decision (Buy Crown)
    socket.on(SOCKET_EVENTS.DECIDE_SHOP, (data: { roomCode: string; buy: boolean }) => {
      const room = roomManager.getRoom(data.roomCode);
      const { player } = roomManager.getPlayerBySocket(socket.id);
      const playerId = player?.id || socket.id;
      if (room) {
        roomManager.engine.handleShopDecision(room, playerId, data.buy);
      }
    });

    // Player: Choose Fork Branch
    socket.on(SOCKET_EVENTS.CHOOSE_FORK, (data: { roomCode: string; chosenBranch: number }) => {
      const room = roomManager.getRoom(data.roomCode);
      const { player } = roomManager.getPlayerBySocket(socket.id);
      const playerId = player?.id || socket.id;
      if (room) {
        roomManager.engine.handleForkChoice(room, playerId, data.chosenBranch);
      }
    });

    // Minigame Player Input
    socket.on(SOCKET_EVENTS.MINIGAME_INPUT, (data: { roomCode: string; input: any }) => {
      const room = roomManager.getRoom(data.roomCode);
      const { player } = roomManager.getPlayerBySocket(socket.id);
      const playerId = player?.id || socket.id;
      if (room) {
        roomManager.engine.handleMinigameInput(room, playerId, data.input);
      }
    });

    // Minigame: Player pressed READY
    socket.on(SOCKET_EVENTS.MINIGAME_READY, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode || currentRoomCode || '4827');
      const { player } = roomManager.getPlayerBySocket(socket.id);
      const playerId = player?.id || socket.id;
      if (room && playerId) {
        roomManager.engine.handleMinigameReady(room, playerId);
      }
    });

    // Minigame: Host Override ("START ANYWAY")
    socket.on(SOCKET_EVENTS.MINIGAME_HOST_OVERRIDE, (data: { roomCode: string }) => {
      const room = roomManager.getRoom(data.roomCode || currentRoomCode || '4827');
      if (room) {
        roomManager.engine.forceStartMinigame(room);
      }
    });

    // Disconnect
    socket.on('disconnect', () => {
      roomManager.handleDisconnect(socket.id);
    });
  });
}

