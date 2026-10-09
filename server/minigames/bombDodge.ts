import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  Minigame2DPlayer,
  Bounds2D,
  DEFAULT_2D_BOUNDS,
  updatePlayerMovement2D,
  generateBotSteering2D,
} from './sim2dUtils';

export interface BombDodgeHazard {
  id: number;
  x: number;
  y: number;
  radius: number;
  warningTime: number; // counts down from ~1.2s to 0
  exploded: boolean;
  explosionDuration: number; // 0.35s
}

let nextHazardId = 1;

export const bombDodgeMinigame: MinigameDefinition = {
  id: 'bomb-dodge',
  name: 'BOMB DODGE',
  description: 'Térj ki a lehulló bombák elől! Figyeld a piros figyelmeztető köröket a földön!',
  duration: 40,
  instructions: 'D-PAD = MOZGÁS! Fuss ki a piros veszélyzónákból a robbanás előtt! +1 túlélési pont minden kikerült robbanásért!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: '—',
    bLabel: '—',
    aHidden: false,
    bHidden: false,
    instructions: 'D-PAD = SZABAD MOZGÁS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, Minigame2DPlayer> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      // Spread players around the arena center
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      const dist = total > 1 ? 260 : 0; // solo player starts right at center
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: 960 + Math.cos(angle) * dist,
        y: 540 + Math.sin(angle) * dist,
        vx: 0,
        vy: 0,
        facing: 0,
        speed: 520,
        radius: 34,
        score: 0,
        isHit: false,
        hitTimer: 0,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      hazards: [] as BombDodgeHazard[],
      waveTimer: 0.8, // first wave triggers quickly (0.8s)
      waveCount: 0,
      recentExplosions: [] as { x: number; y: number; radius: number; timestamp: number }[],
    };
  },

  start(room: RoomState) {
    if (!room.activeMinigame?.data) return;
    room.activeMinigame.data.hazards = [];
    room.activeMinigame.data.waveTimer = 1.0;
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

    // Wave spawning: bombs MUST spawn in solo and multi-player alike!
    mgData.waveTimer = (mgData.waveTimer || 0) + dt;
    const waveInterval = Math.max(1.2, 2.1 - progress * 0.8);

    if (mgData.waveTimer >= waveInterval) {
      mgData.waveTimer = 0;
      mgData.waveCount = (mgData.waveCount || 0) + 1;

      // Spawn 2 to 5 bombs per wave across the arena [200, 1720] x [180, 900]
      const bombCount = Math.floor(2 + progress * 3.5);
      for (let i = 0; i < bombCount; i++) {
        const bx = 240 + Math.random() * 1440;
        const by = 200 + Math.random() * 680;
        mgData.hazards.push({
          id: nextHazardId++,
          x: bx,
          y: by,
          radius: 135 + Math.random() * 30,
          warningTime: 1.15 - progress * 0.25,
          exploded: false,
          explosionDuration: 0.35,
        });
      }
    }

    // Update active hazards
    const activeHazards: BombDodgeHazard[] = [];
    const simPlayers = mgData.players as Record<string, Minigame2DPlayer>;

    mgData.hazards.forEach((hazard: BombDodgeHazard) => {
      if (!hazard.exploded) {
        hazard.warningTime -= dt;

        if (hazard.warningTime <= 0) {
          // EXPLODE!
          hazard.exploded = true;
          mgData.recentExplosions.push({
            x: hazard.x,
            y: hazard.y,
            radius: hazard.radius,
            timestamp: Date.now(),
          });

          // Check collisions with all players
          Object.values(simPlayers).forEach(p => {
            const dist = Math.hypot(p.x - hazard.x, p.y - hazard.y);
            if (dist <= hazard.radius + p.radius) {
              // Player got caught in explosion!
              p.isHit = true;
              p.hitTimer = 0.8;
              p.score = Math.max(0, p.score - 1);
              mgData.scores[p.id] = p.score;
            } else {
              // Successfully survived this explosion
              p.score += 1;
              mgData.scores[p.id] = p.score;
            }
          });
        }
        activeHazards.push(hazard);
      } else {
        // Explosion flash active for 0.35s
        hazard.explosionDuration -= dt;
        if (hazard.explosionDuration > 0) {
          activeHazards.push(hazard);
        }
      }
    });

    mgData.hazards = activeHazards;

    // Prune old explosions
    const now = Date.now();
    mgData.recentExplosions = (mgData.recentExplosions || []).filter((e: any) => now - e.timestamp < 1000);

    // Update players movement & Bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      if (sim.isBot) {
        // Bot evasion: identify closest active warning circle
        let threat: BombDodgeHazard | null = null;
        let threatDist = 9999;

        mgData.hazards.forEach((h: BombDodgeHazard) => {
          if (!h.exploded) {
            const d = Math.hypot(h.x - sim.x, h.y - sim.y);
            if (d < threatDist) {
              threatDist = d;
              threat = h;
            }
          }
        });

        const avoidX = threat && threatDist < 260 ? (threat as BombDodgeHazard).x : undefined;
        const avoidY = threat && threatDist < 260 ? (threat as BombDodgeHazard).y : undefined;
        input = generateBotSteering2D(sim, 960, 540, avoidX, avoidY, 260);
      }

      updatePlayerMovement2D(sim, input, dt, DEFAULT_2D_BOUNDS);
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
