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
        y: 0,
        z: 0,
        vx: 0,
        vy: 0,
        vz: 0,
        facing: 0,
        speed: 5.5,
        radius: 0.55,
        score: 0,
        isJumping: false,
        isDashing: false,
        dashTimer: 0,
        actionA: false,
        actionATimer: 0,
        actionACount: 0,
        actionB: false,
        actionBTimer: 0,
        actionBCount: 0,
        lastInput: {
          up: false,
          down: false,
          left: false,
          right: false,
          a: false,
          b: false,
        },
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      serverTick: 0,
      lastInputTime: Date.now(),
    };
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim: ArenaPlayerSim = mgData.players[playerId];

    if (data && typeof data === 'object') {
      const prevA = sim.lastInput?.a ?? false;
      const prevB = sim.lastInput?.b ?? false;
      const curA = Boolean(data.a);
      const curB = Boolean(data.b);

      sim.lastInput = {
        up: Boolean(data.up),
        down: Boolean(data.down),
        left: Boolean(data.left),
        right: Boolean(data.right),
        a: curA,
        b: curB,
      };
      sim.lastInputTimestamp = Date.now();
      mgData.lastInputTime = Date.now();

      if (room.players[playerId]) {
        room.players[playerId].lastInputState = sim.lastInput;
      }

      // [A] Button Trigger: JUMP / HOP ARC
      if (curA && !prevA) {
        if ((sim.y ?? 0) <= 0.05) {
          sim.vy = 8.5; // launch velocity upward
          sim.isJumping = true;
          sim.actionA = true;
          sim.actionATimer = 0.5;
          sim.actionACount = (sim.actionACount || 0) + 1;
          sim.score += 1;
          mgData.scores[playerId] = sim.score;
        }
      }

      // [B] Button Trigger: DASH BURST / ACTION
      if (curB && !prevB) {
        sim.isDashing = true;
        sim.dashTimer = 0.3;
        sim.actionB = true;
        sim.actionBTimer = 0.45;
        sim.actionBCount = (sim.actionBCount || 0) + 1;
        sim.score += 1;
        mgData.scores[playerId] = sim.score;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    mgData.serverTick = (mgData.serverTick || 0) + 1;

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

      // Dash speed multiplier
      const baseSpeed = 5.5;
      if (p.isDashing && p.dashTimer && p.dashTimer > 0) {
        p.speed = baseSpeed * 1.85;
        p.dashTimer -= dt;
        if (p.dashTimer <= 0) {
          p.isDashing = false;
        }
      } else {
        p.speed = baseSpeed;
      }

      updatePlayerMovement(p, input, dt, ARENA_BOUNDS);

      // Vertical jump gravity physics
      if ((p.y ?? 0) > 0 || (p.vy ?? 0) > 0) {
        p.vy = (p.vy ?? 0) - 28.0 * dt;
        p.y = Math.max(0, (p.y ?? 0) + (p.vy ?? 0) * dt);
        if (p.y === 0) {
          p.vy = 0;
          p.isJumping = false;
        }
      }

      // Action timers decay
      if (p.actionATimer && p.actionATimer > 0) {
        p.actionATimer -= dt;
        if (p.actionATimer <= 0) p.actionA = false;
      }
      if (p.actionBTimer && p.actionBTimer > 0) {
        p.actionBTimer -= dt;
        if (p.actionBTimer <= 0) p.actionB = false;
      }
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
