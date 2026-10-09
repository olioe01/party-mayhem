import crypto from 'crypto';
import { RoomState, Player, AvatarId, HatId } from '../shared/types';
import { AVATARS, COSMETIC_HATS } from '../shared/constants';
import { GameEngine } from './gameEngine';

export class RoomManager {
  private rooms: Map<string, RoomState> = new Map();
  public engine: GameEngine;
  private broadcastCallback: (roomCode: string, state: RoomState) => void;
  private socketToPlayer: Map<string, { roomCode: string; playerId: string }> = new Map();
  private defaultLanIp?: string;
  private defaultPort?: number;

  constructor(
    broadcastCallback: (roomCode: string, state: RoomState) => void,
    defaultLanIp?: string,
    defaultPort?: number
  ) {
    this.broadcastCallback = broadcastCallback;
    this.defaultLanIp = defaultLanIp;
    this.defaultPort = defaultPort;

    this.engine = new GameEngine((room) => {
      this.broadcastCallback(room.roomCode, room);
    });

    // Default primary room '4827'
    const defaultRoom = this.engine.createRoom('4827', defaultLanIp, defaultPort);
    this.rooms.set('4827', defaultRoom);
  }

  public getRoom(roomCode: string): RoomState | undefined {
    return this.rooms.get(roomCode);
  }

  public broadcastRoom(roomCode: string) {
    const room = this.rooms.get(roomCode);
    if (room) {
      this.broadcastCallback(roomCode, room);
    }
  }

  public getOrCreateRoom(roomCode: string): RoomState {
    let room = this.rooms.get(roomCode);
    if (!room) {
      room = this.engine.createRoom(roomCode, this.defaultLanIp, this.defaultPort);
      this.rooms.set(roomCode, room);
    }
    return room;
  }

  public joinHost(roomCode: string, socketId: string): RoomState {
    const room = this.getOrCreateRoom(roomCode);
    room.hostSocketId = socketId;
    return room;
  }

  public joinPlayer(
    roomCode: string,
    socketId: string,
    name: string,
    avatar: AvatarId,
    cosmetic: HatId = 'none',
    clientPlayerToken?: string
  ): { room: RoomState; player: Player; isReconnect: boolean } {
    const room = this.getOrCreateRoom(roomCode);

    // 1. Check if reconnecting via clientPlayerToken
    if (clientPlayerToken) {
      const existingByToken = Object.values(room.players).find(p => p.playerToken === clientPlayerToken);
      if (existingByToken) {
        existingByToken.socketId = socketId;
        existingByToken.connected = true;
        existingByToken.disconnectedAt = null;
        if (cosmetic && cosmetic !== 'none') existingByToken.cosmetic = cosmetic;
        this.socketToPlayer.set(socketId, { roomCode, playerId: existingByToken.id });
        room.lastReconnectedPlayer = { name: existingByToken.name, timestamp: Date.now() };
        this.engine.updateRankings(room);
        return { room, player: existingByToken, isReconnect: true };
      }
    }

    // 2. Check if player with the same name already exists in room (e.g. disconnected phone returning)
    const existingByName = Object.values(room.players).find(
      p => p.name.trim().toLowerCase() === name.trim().toLowerCase()
    );
    if (existingByName) {
      existingByName.socketId = socketId;
      existingByName.connected = true;
      existingByName.disconnectedAt = null;
      if (cosmetic && cosmetic !== 'none') existingByName.cosmetic = cosmetic;
      this.socketToPlayer.set(socketId, { roomCode, playerId: existingByName.id });
      room.lastReconnectedPlayer = { name: existingByName.name, timestamp: Date.now() };
      this.engine.updateRankings(room);
      return { room, player: existingByName, isReconnect: true };
    }

    // 3. Brand new player
    const playerId = `p_${crypto.randomUUID().slice(0, 8)}`;
    const playerToken = crypto.randomUUID();
    const avatarInfo = AVATARS[avatar] || AVATARS['fox'];
    const validCosmetic = COSMETIC_HATS[cosmetic] ? cosmetic : 'none';

    const newPlayer: Player = {
      id: playerId,
      socketId,
      playerToken,
      name: name.trim().slice(0, 16) || 'Játékos',
      avatar,
      color: avatarInfo.color,
      cosmetic: validCosmetic,
      isReady: false,
      isBot: false,
      connected: true,
      disconnectedAt: null,
      coins: 10,
      crowns: 0,
      boardPosition: 0,
      totalCoinsEarned: 10,
      minigamesWon: 0,
      positiveEvents: 0,
      riskyDecisions: 0,
      currentRank: Object.keys(room.players).length + 1,
      boostActive: false,
      trapActive: false,
      luckyDayActive: false,
      slowModeActive: false,
      shieldActive: false,
      secretMission: null,
      minigameReady: false
    };

    room.players[playerId] = newPlayer;
    if (!room.playerOrder.includes(playerId)) {
      room.playerOrder.push(playerId);
    }
    this.socketToPlayer.set(socketId, { roomCode, playerId });

    this.engine.updateRankings(room);
    return { room, player: newPlayer, isReconnect: false };
  }

  // Explicit reconnect via playerToken (sent on page visibility change or socket reconnection)
  public reconnectPlayer(
    roomCode: string,
    socketId: string,
    playerToken: string
  ): { success: boolean; room?: RoomState; player?: Player; error?: string } {
    const room = this.getRoom(roomCode);
    if (!room) {
      return { success: false, error: 'Room not found' };
    }

    const player = Object.values(room.players).find(p => p.playerToken === playerToken);
    if (!player) {
      return { success: false, error: 'Invalid player token' };
    }

    // Re-link
    player.socketId = socketId;
    player.connected = true;
    player.disconnectedAt = null;
    this.socketToPlayer.set(socketId, { roomCode, playerId: player.id });
    room.lastReconnectedPlayer = { name: player.name, timestamp: Date.now() };

    this.broadcastCallback(roomCode, room);
    return { success: true, room, player };
  }

  // Player updates cosmetic hat
  public setCosmetic(roomCode: string, playerId: string, cosmetic: HatId) {
    const room = this.getRoom(roomCode);
    if (room && room.players[playerId]) {
      room.players[playerId].cosmetic = COSMETIC_HATS[cosmetic] ? cosmetic : 'none';
      this.broadcastCallback(roomCode, room);
    }
  }

  // Player toggles ready status in lobby
  public toggleReady(roomCode: string, playerId: string, ready?: boolean) {
    const room = this.getRoom(roomCode);
    if (room && room.players[playerId]) {
      room.players[playerId].isReady = ready !== undefined ? ready : !room.players[playerId].isReady;
      this.broadcastCallback(roomCode, room);
    }
  }

  public getPlayerBySocket(socketId: string): { room?: RoomState; player?: Player } {
    const mapping = this.socketToPlayer.get(socketId);
    if (!mapping) return {};
    const room = this.getRoom(mapping.roomCode);
    if (!room) return {};
    const player = room.players[mapping.playerId];
    return { room, player };
  }

  public handleDisconnect(socketId: string) {
    const mapping = this.socketToPlayer.get(socketId);
    if (mapping) {
      const room = this.getRoom(mapping.roomCode);
      if (room && room.players[mapping.playerId]) {
        const player = room.players[mapping.playerId];
        player.connected = false;
        player.disconnectedAt = Date.now();
        // Immediately clear held inputs so character does not run forever
        const clearedInput = { up: false, down: false, left: false, right: false, a: false, b: false };
        player.lastInputState = clearedInput;
        if (room.activeMinigame && room.phase === 'MINIGAME_PLAY') {
          this.engine.handleMinigameInput(room, player.id, clearedInput);
        }
        // Keep in room! DO NOT DELETE PLAYER!
        this.broadcastCallback(room.roomCode, room);
      }
      this.socketToPlayer.delete(socketId);
    }
  }

  public kickPlayer(roomCode: string, playerId: string) {
    const room = this.rooms.get(roomCode);
    if (room && room.players[playerId]) {
      const player = room.players[playerId];
      if (player.socketId) {
        this.socketToPlayer.delete(player.socketId);
      }
      delete room.players[playerId];
      room.playerOrder = room.playerOrder.filter(id => id !== playerId);
      this.engine.updateRankings(room);
      this.broadcastCallback(room.roomCode, room);
    }
  }
}

