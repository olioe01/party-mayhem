import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';

export interface FruitFrenzyItem {
  id: number;
  type: 'apple' | 'orange' | 'banana' | 'strawberry' | 'golden' | 'star' | 'bomb';
  x: number;
  y: number;
  speed: number;
  points: number;
}

export interface FruitFrenzyPlayerSim {
  id: string;
  name: string;
  color: string;
  isBot: boolean;
  x: number;
  y: number;
  vx: number;
  facing: number; // -1: left, 0: idle, 1: right
  speed: number;
  score: number;
  isHit: boolean;
  hitTimer: number;
  basketWidth: number;
  basketHeight: number;
  lastInput?: {
    up?: boolean;
    down?: boolean;
    left?: boolean;
    right?: boolean;
    a?: boolean;
    b?: boolean;
  };
}

let nextItemId = 1;

export const fruitFrenzyMinigame: MinigameDefinition = {
  id: 'fruit-frenzy',
  name: 'FRUIT FRENZY',
  description: 'Kapd el a hulló finom gyümölcsöket a kosárral, és kerüld el a bombákat!',
  duration: 45,
  instructions: 'D-PAD BAL/JOBB = MOZGÁS! Alma/narancs: +1 🍎, Arany: +3 🌟, Csillag: +5 💎! BOMBA: -3 pont! 💣',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: '—',
    bLabel: '—',
    aHidden: false, // Keep visible on controller surface for consistency
    bHidden: false,
    instructions: 'D-PAD BAL / JOBB = MOZGÁS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, FruitFrenzyPlayerSim> = {};
    const scores: Record<string, number> = {};

    // Spread players horizontally across ground (Y = 920 on 1920x1080 canvas)
    const playMinX = 260;
    const playMaxX = 1660;

    playersList.forEach((p, idx) => {
      const spreadX = total > 1
        ? playMinX + (idx / (total - 1)) * (playMaxX - playMinX)
        : 960;

      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: spreadX,
        y: 920,
        vx: 0,
        facing: 0,
        speed: 560, // pixels per second
        score: 0,
        isHit: false,
        hitTimer: 0,
        basketWidth: 110,
        basketHeight: 50,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      items: [] as FruitFrenzyItem[],
      catchEvents: [] as { playerId: string; points: number; type: string; x: number; y: number; timestamp: number }[],
      spawnTimer: 0.1,
      matchProgress: 0,
    };
  },

  start(room: RoomState) {
    if (!room.activeMinigame?.data) return;
    room.activeMinigame.data.items = [];
    room.activeMinigame.data.catchEvents = [];
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
    if (!mgData || !mgData.players || !Array.isArray(mgData.items)) return false;

    const timeRemaining = room.activeMinigame?.timeRemaining ?? 45;
    const totalDuration = 45;
    const progress = Math.min(1, Math.max(0, 1 - timeRemaining / totalDuration)); // 0 to 1
    mgData.matchProgress = progress;

    // Difficulty curve
    const fallSpeedBase = 340 + progress * 240; // 340 -> 580 px/sec
    const spawnInterval = Math.max(0.28, 0.65 - progress * 0.32);
    const bombChance = 0.12 + progress * 0.15; // 12% -> 27%

    // 1. Spawning falling items
    mgData.spawnTimer = (mgData.spawnTimer || 0) + dt;
    if (mgData.spawnTimer >= spawnInterval) {
      mgData.spawnTimer = 0;

      const isBomb = Math.random() < bombChance;
      let type: FruitFrenzyItem['type'] = 'apple';
      let points = 1;

      if (isBomb) {
        type = 'bomb';
        points = -3;
      } else {
        const rand = Math.random();
        if (rand < 0.07) {
          type = 'star';
          points = 5;
        } else if (rand < 0.24) {
          type = 'golden';
          points = 3;
        } else {
          const fruits: FruitFrenzyItem['type'][] = ['apple', 'orange', 'banana', 'strawberry'];
          type = fruits[Math.floor(Math.random() * fruits.length)];
          points = 1;
        }
      }

      // Spawn across screen width [160, 1760]
      const spawnX = 160 + Math.random() * 1600;
      const speed = fallSpeedBase * (0.88 + Math.random() * 0.24);

      mgData.items.push({
        id: nextItemId++,
        type,
        x: spawnX,
        y: -40,
        speed,
        points,
      });
    }

    // 2. Update players & Bot AI
    const playersMap = mgData.players as Record<string, FruitFrenzyPlayerSim>;
    Object.values(playersMap).forEach(sim => {
      // Hit flash decay
      if (sim.isHit) {
        sim.hitTimer -= dt;
        if (sim.hitTimer <= 0) {
          sim.isHit = false;
        }
      }

      let input = sim.lastInput || {};

      // Smart Bot AI: Seek nearest high-scoring fruit, dodge falling bombs
      if (sim.isBot) {
        let bestTarget: FruitFrenzyItem | null = null;
        let bestScoreDist = 9999;
        let threatBomb: FruitFrenzyItem | null = null;
        let bombDist = 9999;

        mgData.items.forEach((item: FruitFrenzyItem) => {
          const dx = item.x - sim.x;
          const dist = Math.abs(dx);
          const timeToLand = (sim.y - item.y) / item.speed;

          // Bomb evasion: if bomb will land near bot's basket within 1.5s
          if (item.type === 'bomb') {
            if (dist < 140 && item.y > 400 && dist < bombDist) {
              threatBomb = item;
              bombDist = dist;
            }
          } else {
            // Fruit attraction: evaluate time and reward
            if (item.y > 50 && item.y < 900 && timeToLand > 0.1 && timeToLand < 2.5) {
              const weight = item.points === 5 ? 0.35 : item.points === 3 ? 0.55 : 1.0;
              const effectiveDist = dist * weight;
              if (effectiveDist < bestScoreDist) {
                bestScoreDist = effectiveDist;
                bestTarget = item;
              }
            }
          }
        });

        // If bomb is dangerously close, dodge away
        if (threatBomb) {
          const bombDx = (threatBomb as FruitFrenzyItem).x - sim.x;
          input = {
            left: bombDx > 0, // flee left if bomb is to the right
            right: bombDx <= 0, // flee right if bomb is to the left
          };
        } else if (bestTarget) {
          const targetDx = (bestTarget as FruitFrenzyItem).x - sim.x;
          input = {
            left: targetDx < -20,
            right: targetDx > 20,
          };
        } else {
          input = {};
        }
      }

      // Compute horizontal velocity
      if (input.right && !input.left) {
        sim.vx = sim.speed;
        sim.facing = 1;
      } else if (input.left && !input.right) {
        sim.vx = -sim.speed;
        sim.facing = -1;
      } else {
        sim.vx = 0;
        // Keep facing direction for animation
      }

      // Move player and clamp within stage borders [140, 1780]
      sim.x += sim.vx * dt;
      if (sim.x < 140) sim.x = 140;
      if (sim.x > 1780) sim.x = 1780;
    });

    // 3. Update falling items and handle basket catches
    const remainingItems: FruitFrenzyItem[] = [];
    const items = (mgData.items || []) as FruitFrenzyItem[];

    items.forEach((item: FruitFrenzyItem) => {
      item.y += item.speed * dt;

      // Basket catch zone (Y between 860 and 945)
      if (item.y >= 860 && item.y <= 945) {
        let caughtPlayer: FruitFrenzyPlayerSim | null = null;

        for (const sim of Object.values(playersMap)) {
          const halfW = sim.basketWidth / 2 + 15; // friendly catch hitbox
          if (Math.abs(item.x - sim.x) <= halfW) {
            caughtPlayer = sim;
            break;
          }
        }

        if (caughtPlayer) {
          if (item.type === 'bomb') {
            // Bomb penalty: score = max(0, score - 3)
            caughtPlayer.score = Math.max(0, caughtPlayer.score - 3);
            caughtPlayer.isHit = true;
            caughtPlayer.hitTimer = 0.6;
          } else {
            // Fruit bonus
            caughtPlayer.score += item.points;
          }

          mgData.scores[caughtPlayer.id] = caughtPlayer.score;
          mgData.catchEvents.push({
            playerId: caughtPlayer.id,
            points: item.points,
            type: item.type,
            x: item.x,
            y: item.y,
            timestamp: Date.now(),
          });
          return; // Item caught and removed
        }
      }

      // If fallen past floor (Y > 1040), remove it
      if (item.y <= 1040) {
        remainingItems.push(item);
      }
    });

    mgData.items = remainingItems;

    // Prune catch events older than 1.5 seconds
    const now = Date.now();
    mgData.catchEvents = (mgData.catchEvents || []).filter((e: any) => now - e.timestamp < 1500);

    return false; // Run until duration expires
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} pont összegyűjtve`,
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
