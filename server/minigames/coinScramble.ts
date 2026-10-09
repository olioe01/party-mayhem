import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  Minigame2DPlayer,
  DEFAULT_2D_BOUNDS,
  updatePlayerMovement2D,
  generateBotSteering2D,
  checkCircleCollision2D,
} from './sim2dUtils';

export interface ScrambleCoin {
  id: number;
  x: number;
  y: number;
  type: 'normal' | 'gold' | 'cursed';
  radius: number;
  points: number;
}

let nextCoinId = 1;

export const coinScrambleMinigame: MinigameDefinition = {
  id: 'coin-scramble',
  name: 'COIN SCRAMBLE',
  description: 'Gyűjtsd be a legtöbb érmét az arénában a D-paddal!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS! Sárga érme: +1 🪙, Arany csillag: +5 🌟! Kerüld az elátkozott koponya érmét: -3 💀!',
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
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      const dist = total > 1 ? 280 : 0;
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
        speed: 530,
        radius: 34,
        score: 0,
        isHit: false,
        hitTimer: 0,
      };
      scores[p.id] = 0;
    });

    // Generate initial batch of 14 coins scattered on arena
    const initialCoins: ScrambleCoin[] = [];
    for (let i = 0; i < 14; i++) {
      initialCoins.push(spawnRandomCoin());
    }

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      coins: initialCoins,
      coinCollectEvents: [] as { playerId: string; type: string; points: number; x: number; y: number; timestamp: number }[],
      respawnTimer: 0,
    };
  },

  start(room: RoomState) {
    if (!room.activeMinigame?.data) return;
    // Ensure coins are present
    if (!room.activeMinigame.data.coins || room.activeMinigame.data.coins.length === 0) {
      const initialCoins: ScrambleCoin[] = [];
      for (let i = 0; i < 14; i++) {
        initialCoins.push(spawnRandomCoin());
      }
      room.activeMinigame.data.coins = initialCoins;
    }
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
    if (!mgData || !mgData.players || !Array.isArray(mgData.coins)) return false;

    const simPlayers = mgData.players as Record<string, Minigame2DPlayer>;
    let coins = mgData.coins as ScrambleCoin[];

    // 1. Check coin collection collisions with all players
    const remainingCoins: ScrambleCoin[] = [];
    coins.forEach(coin => {
      let collectedBy: Minigame2DPlayer | null = null;

      for (const p of Object.values(simPlayers)) {
        if (checkCircleCollision2D(p.x, p.y, p.radius, coin.x, coin.y, coin.radius)) {
          collectedBy = p;
          break;
        }
      }

      if (collectedBy) {
        if (coin.type === 'cursed') {
          collectedBy.score = Math.max(0, collectedBy.score - 3);
          collectedBy.isHit = true;
          collectedBy.hitTimer = 0.6;
        } else {
          collectedBy.score += coin.points;
        }

        mgData.scores[collectedBy.id] = collectedBy.score;
        mgData.coinCollectEvents.push({
          playerId: collectedBy.id,
          type: coin.type,
          points: coin.points,
          x: coin.x,
          y: coin.y,
          timestamp: Date.now(),
        });
      } else {
        remainingCoins.push(coin);
      }
    });

    // 2. Continuous respawn of coins to keep density at 12-16
    mgData.respawnTimer = (mgData.respawnTimer || 0) + dt;
    if (remainingCoins.length < 12 || mgData.respawnTimer >= 1.2) {
      mgData.respawnTimer = 0;
      if (remainingCoins.length < 16) {
        remainingCoins.push(spawnRandomCoin());
      }
    }
    mgData.coins = remainingCoins;

    // Prune old collect events
    const now = Date.now();
    mgData.coinCollectEvents = (mgData.coinCollectEvents || []).filter((e: any) => now - e.timestamp < 1200);

    // 3. Update player movement and Bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      if (sim.isBot) {
        let bestCoin: ScrambleCoin | null = null;
        let bestDist = 9999;
        let cursedCoin: ScrambleCoin | null = null;
        let cursedDist = 9999;

        remainingCoins.forEach(coin => {
          const d = Math.hypot(coin.x - sim.x, coin.y - sim.y);
          if (coin.type === 'cursed') {
            if (d < 180 && d < cursedDist) {
              cursedCoin = coin;
              cursedDist = d;
            }
          } else {
            const weight = coin.type === 'gold' ? 0.45 : 1.0;
            const effDist = d * weight;
            if (effDist < bestDist) {
              bestDist = effDist;
              bestCoin = coin;
            }
          }
        });

        const targetX = bestCoin ? bestCoin.x : 960;
        const targetY = bestCoin ? bestCoin.y : 540;
        const avoidX = cursedCoin ? cursedCoin.x : undefined;
        const avoidY = cursedCoin ? cursedCoin.y : undefined;

        input = generateBotSteering2D(sim, targetX, targetY, avoidX, avoidY, 160);
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
      extraInfo: `${scores[pId] || 0} érme gyűjtve`,
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

function spawnRandomCoin(): ScrambleCoin {
  const rand = Math.random();
  let type: ScrambleCoin['type'] = 'normal';
  let points = 1;
  let radius = 24;

  if (rand < 0.15) {
    type = 'gold';
    points = 5;
    radius = 32;
  } else if (rand < 0.28) {
    type = 'cursed';
    points = -3;
    radius = 26;
  }

  return {
    id: nextCoinId++,
    x: 180 + Math.random() * 1560,
    y: 180 + Math.random() * 720,
    type,
    radius,
    points,
  };
}
