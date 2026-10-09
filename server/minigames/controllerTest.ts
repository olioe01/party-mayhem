import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import {
  ArenaPlayerSim,
  ArenaBounds,
  updatePlayerMovement,
} from './arenaUtils';

const ARENA_BOUNDS: ArenaBounds = {
  minX: -6.5,
  maxX: 6.5,
  minZ: -4.5,
  maxZ: 4.5,
};

export const controllerTestMinigame: MinigameDefinition = {
  id: 'controller-test',
  name: 'CONTROLLER TEST ARENA',
  description: 'Teszteld a D-pad és gomb irányítást szabadon ebben a teszt arénában!',
  duration: 60,
  instructions: 'D-PAD = MOZGÁS • [A] = UGRÁS • [B] = AKCIÓ! Teszteld a nyomva tartást és átlókat!',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'UGRÁS',
    bLabel: 'AKCIÓ',
    aHidden: false,
    bHidden: false,
    instructions: 'Teszteld az összes gombot!',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, ArenaPlayerSim> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const spreadX = total > 1 ? ((idx - (total - 1) / 2) / (total - 1)) * 8.0 : 0;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: spreadX,
        z: 0,
        vx: 0,
        vz: 0,
        facing: 0,
        speed: 5.5,
        radius: 0.55,
        score: 0,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
    };
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim = mgData.players[playerId];

    if (data && typeof data === 'object') {
      sim.lastInput = {
        up: Boolean(data.up),
        down: Boolean(data.down),
        left: Boolean(data.left),
        right: Boolean(data.right),
        a: Boolean(data.a),
        b: Boolean(data.b),
      };

      if (data.a || data.b) {
        sim.score += 1;
        mgData.scores[playerId] = sim.score;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    Object.values(mgData.players as Record<string, ArenaPlayerSim>).forEach(p => {
      let input = p.lastInput;
      if (p.isBot) {
        // Bots wander gently
        if (!p.botTargetTimer || p.botTargetTimer <= 0) {
          p.botTargetTimer = 2.0;
          p.botTargetX = (Math.random() - 0.5) * 8.0;
          p.botTargetZ = (Math.random() - 0.5) * 5.0;
        } else {
          p.botTargetTimer -= dt;
        }
        const dx = (p.botTargetX || 0) - p.x;
        const dz = (p.botTargetZ || 0) - p.z;
        input = {
          left: dx < -0.3,
          right: dx > 0.3,
          up: dz < -0.3,
          down: dz > 0.3,
          a: false,
          b: false,
        };
      }
      updatePlayerMovement(p, input, dt, ARENA_BOUNDS);
    });

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    return Object.keys(room.players).map((pId, idx) => ({
      playerId: pId,
      score: scores[pId] || 0,
      rank: idx + 1,
      coinsEarned: 5,
      extraInfo: 'Teszt lezárva',
    }));
  },

  cleanup(room: RoomState) {
    if (room.activeMinigame) {
      room.activeMinigame.data = {};
    }
  },
};
