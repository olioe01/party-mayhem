import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  ArenaPlayerSim,
  ArenaBounds,
  updatePlayerMovement,
  generateBotSteering,
} from './arenaUtils';

export interface BombHazard {
  id: number;
  x: number;
  z: number;
  warningTime: number; // counts down from 1.1s to 0
  exploded: boolean;
  radius: number;
}

const ARENA_BOUNDS: ArenaBounds = {
  minX: -6.5,
  maxX: 6.5,
  minZ: -6.5,
  maxZ: 6.5,
  radius: 6.5,
};

let nextHazardId = 1;

export const bombDodgeMinigame: MinigameDefinition = {
  id: 'bomb-dodge',
  name: 'BOMB DODGE',
  description: 'Térj ki a lehulló bombák elől! Figyeld a piros figyelmeztető köröket a földön!',
  duration: 40,
  instructions: 'MOZGÁS A D-PADDAL! Fuss ki a piros veszélyzónákból a robbanás előtt! +1 túlélési pont minden hullámért!',
  controllerConfig: {
    layout: 'gamepad',
    aHidden: true,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, ArenaPlayerSim> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: Math.cos(angle) * 3.5,
        z: Math.sin(angle) * 3.5,
        vx: 0,
        vz: 0,
        facing: 0,
        speed: 5.8,
        radius: 0.55,
        score: 0,
        isHit: false,
        hitTimer: 0,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      hazards: [] as BombHazard[],
      waveTimer: 0.5,
      waveCount: 0,
    };
  },

  start(room: RoomState) {
    if (!room.activeMinigame?.data) return;
    room.activeMinigame.data.hazards = [];
  },

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
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const timeRemaining = room.activeMinigame!.timeRemaining;
    const progress = Math.max(0, 1 - timeRemaining / 40);

    // Wave spawning: spawn 2-5 bomb hazards
    mgData.waveTimer = (mgData.waveTimer || 0) + dt;
    const waveInterval = Math.max(1.3, 2.2 - progress * 0.9);

    if (mgData.waveTimer >= waveInterval) {
      mgData.waveTimer = 0;
      mgData.waveCount = (mgData.waveCount || 0) + 1;

      const bombCount = Math.floor(2 + progress * 4);
      for (let i = 0; i < bombCount; i++) {
        const rad = Math.random() * (ARENA_BOUNDS.radius! - 1.2);
        const ang = Math.random() * Math.PI * 2;
        mgData.hazards.push({
          id: nextHazardId++,
          x: Math.cos(ang) * rad,
          z: Math.sin(ang) * rad,
          warningTime: 1.15 - progress * 0.25,
          exploded: false,
          radius: 1.75,
        });
      }
    }

    // Update hazards
    const activeHazards: BombHazard[] = [];
    mgData.hazards.forEach((hazard: BombHazard) => {
      hazard.warningTime -= dt;
      if (hazard.warningTime <= 0 && !hazard.exploded) {
        hazard.exploded = true;
        // Check which players got caught in explosion radius
        Object.values(mgData.players as Record<string, ArenaPlayerSim>).forEach(p => {
          const dist = Math.hypot(p.x - hazard.x, p.z - hazard.z);
          if (dist <= hazard.radius + p.radius) {
            p.isHit = true;
            p.hitTimer = 0.8;
            p.score = Math.max(0, p.score - 1);
            mgData.scores[p.id] = p.score;
          } else {
            // Survived this explosion
            p.score += 1;
            mgData.scores[p.id] = p.score;
          }
        });
      }

      // Keep for 0.4s explosion animation
      if (hazard.warningTime > -0.4) {
        activeHazards.push(hazard);
      }
    });
    mgData.hazards = activeHazards;

    // Update players & bot AI
    Object.values(mgData.players as Record<string, ArenaPlayerSim>).forEach((playerSim: any) => {
      let input = playerSim.lastInput;

      if (playerSim.isBot) {
        // Bots identify nearest warning circle threat and steer safely away
        let threat: BombHazard | null = null;
        let threatDist = 999;

        mgData.hazards.forEach((h: BombHazard) => {
          if (!h.exploded) {
            const d = Math.hypot(h.x - playerSim.x, h.z - playerSim.z);
            if (d < threatDist) {
              threatDist = d;
              threat = h;
            }
          }
        });

        const avoidX = threat && threatDist < 3.0 ? (threat as BombHazard).x : undefined;
        const avoidZ = threat && threatDist < 3.0 ? (threat as BombHazard).z : undefined;
        input = generateBotSteering(playerSim, 0, 0, avoidX, avoidZ, 3.2);
      }

      updatePlayerMovement(playerSim, input, dt, ARENA_BOUNDS);
    });

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} túlélési pont`,
    }));

    results.sort((a, b) => b.score - a.score);

    return results.map((entry, index) => {
      let coins = MINIGAME_COIN_REWARDS[index] || 1;
      const player = room.players[entry.playerId];
      if (player?.boostActive) coins = Math.round(coins * 1.5);
      if (player?.trapActive) coins = Math.max(1, coins - 2);

      return {
        playerId: entry.playerId,
        score: entry.score,
        rank: index + 1,
        coinsEarned: coins,
        extraInfo: entry.extraInfo,
      };
    });
  },

  cleanup(room: RoomState) {
    if (room.activeMinigame) {
      room.activeMinigame.data = {};
    }
  },
};
