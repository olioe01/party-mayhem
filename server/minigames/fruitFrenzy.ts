import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  ArenaPlayerSim,
  ArenaBounds,
  updatePlayerMovement,
  generateBotSteering,
} from './arenaUtils';

export interface FallingFruitItem {
  id: number;
  type: 'apple' | 'orange' | 'banana' | 'strawberry' | 'watermelon' | 'golden' | 'star' | 'bomb';
  x: number;
  y: number;
  z: number;
  speed: number;
  points: number;
}

const ARENA_BOUNDS: ArenaBounds = {
  minX: -6.5,
  maxX: 6.5,
  minZ: -4.5,
  maxZ: 4.5,
};

let nextItemId = 1;

export const fruitFrenzyMinigame: MinigameDefinition = {
  id: 'fruit-frenzy',
  name: 'FRUIT FRENZY',
  description: 'Kapd el a hulló finom gyümölcsöket a kosárral, és kerüld el a bombákat!',
  duration: 45,
  instructions: 'MOZGÁS A D-PADDAL! Alma/narancs: +1 🍎, Arany: +3 🌟, Ritka: +5 💎! BOMBA: -3 pont! 💣',
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
      // Line up players nicely on the arena floor
      const spreadX = total > 1 ? ((idx - (total - 1) / 2) / (total - 1)) * 9.0 : 0;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: spreadX,
        z: 1.5,
        vx: 0,
        vz: 0,
        facing: 0,
        speed: 5.6,
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
      items: [] as FallingFruitItem[],
      catchEvents: [] as { playerId: string; points: number; type: string; timestamp: number }[],
      spawnTimer: 0,
      difficulty: 1.0,
    };
  },

  start(room: RoomState) {
    if (!room.activeMinigame?.data) return;
    room.activeMinigame.data.items = [];
    room.activeMinigame.data.spawnTimer = 0.2;
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
    const progress = Math.max(0, 1 - timeRemaining / 45); // 0 at start, 1 at end

    // Difficulty ramp: items fall faster and spawn more frequently
    const fallSpeedBase = 3.8 + progress * 3.5;
    const spawnInterval = Math.max(0.28, 0.75 - progress * 0.45);
    const bombChance = 0.12 + progress * 0.16;

    // 1. Spawning falling fruit & bombs
    mgData.spawnTimer = (mgData.spawnTimer || 0) + dt;
    if (mgData.spawnTimer >= spawnInterval) {
      mgData.spawnTimer = 0;

      const isBomb = Math.random() < bombChance;
      let type: FallingFruitItem['type'] = 'apple';
      let points = 1;

      if (isBomb) {
        type = 'bomb';
        points = -3;
      } else {
        const rand = Math.random();
        if (rand < 0.06) {
          type = 'star';
          points = 5;
        } else if (rand < 0.22) {
          type = 'golden';
          points = 3;
        } else {
          const fruits: FallingFruitItem['type'][] = ['apple', 'orange', 'banana', 'strawberry', 'watermelon'];
          type = fruits[Math.floor(Math.random() * fruits.length)];
          points = 1;
        }
      }

      const spawnX = (Math.random() - 0.5) * 11.5;
      const spawnZ = (Math.random() - 0.5) * 7.5;
      const speed = fallSpeedBase * (0.9 + Math.random() * 0.25);

      mgData.items.push({
        id: nextItemId++,
        type,
        x: spawnX,
        y: 8.5 + Math.random() * 1.5,
        z: spawnZ,
        speed,
        points,
      });
    }

    // 2. Update player movement & bot AI
    Object.values(mgData.players as Record<string, ArenaPlayerSim>).forEach((playerSim: any) => {
      let input = playerSim.lastInput;

      if (playerSim.isBot) {
        // Bot AI: Find target fruit and avoid nearest bomb
        let bestTarget: FallingFruitItem | null = null;
        let bestDist = 999;
        let nearestBomb: FallingFruitItem | null = null;
        let bombDist = 999;

        mgData.items.forEach((item: FallingFruitItem) => {
          const d = Math.hypot(item.x - playerSim.x, item.z - playerSim.z);
          if (item.type === 'bomb') {
            if (item.y < 4.5 && d < bombDist) {
              bombDist = d;
              nearestBomb = item;
            }
          } else {
            // Prioritize higher value fruits
            const weight = item.points >= 3 ? 0.6 : 1.0;
            const scoreDist = d * weight;
            if (item.y > 0.4 && item.y < 7.0 && scoreDist < bestDist) {
              bestDist = scoreDist;
              bestTarget = item;
            }
          }
        });

        const targetX = bestTarget ? bestTarget.x : playerSim.x;
        const targetZ = bestTarget ? bestTarget.z : playerSim.z;
        const avoidX = nearestBomb && bombDist < 2.5 ? nearestBomb.x : undefined;
        const avoidZ = nearestBomb && bombDist < 2.5 ? nearestBomb.z : undefined;

        input = generateBotSteering(playerSim, targetX, targetZ, avoidX, avoidZ, 2.2);
      }

      updatePlayerMovement(playerSim, input, dt, ARENA_BOUNDS);
    });

    // 3. Update falling items and handle basket catching collisions
    const remainingItems: FallingFruitItem[] = [];
    const catchRadius = 0.95; // basket catch radius

    mgData.items.forEach((item: FallingFruitItem) => {
      item.y -= item.speed * dt;

      // When fruit is in the catch plane (y between -0.2 and 1.1)
      if (item.y <= 1.05 && item.y >= -0.25) {
        let caughtByPlayerId: string | null = null;

        for (const sim of Object.values(mgData.players as Record<string, ArenaPlayerSim>)) {
          const dist = Math.hypot(item.x - sim.x, item.z - sim.z);
          if (dist <= catchRadius) {
            caughtByPlayerId = sim.id;
            break;
          }
        }

        if (caughtByPlayerId) {
          const playerSim = mgData.players[caughtByPlayerId];
          if (item.type === 'bomb') {
            // Bomb hit! -3 points (score = max(0, score - 3))
            playerSim.score = Math.max(0, playerSim.score - 3);
            playerSim.isHit = true;
            playerSim.hitTimer = 0.6;
          } else {
            // Catch fruit!
            playerSim.score += item.points;
          }

          mgData.scores[caughtByPlayerId] = playerSim.score;
          mgData.catchEvents.push({
            playerId: caughtByPlayerId,
            points: item.points,
            type: item.type,
            timestamp: Date.now(),
          });
          // Caught item is removed
          return;
        }
      }

      // If item fell past ground without being caught, remove it
      if (item.y > -0.3) {
        remainingItems.push(item);
      }
    });

    mgData.items = remainingItems;

    // Prune old catch events older than 1.5s
    const now = Date.now();
    mgData.catchEvents = (mgData.catchEvents || []).filter((e: any) => now - e.timestamp < 1500);

    return false; // run until time expires
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} db gyümölcs összegyűjtve`,
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
