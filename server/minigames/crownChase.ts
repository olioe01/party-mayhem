import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  ArenaPlayerSim,
  ArenaBounds,
  updatePlayerMovement,
  generateBotSteering,
} from './arenaUtils';

const ARENA_BOUNDS: ArenaBounds = {
  minX: -6.5,
  maxX: 6.5,
  minZ: -4.5,
  maxZ: 4.5,
};

export const crownChaseMinigame: MinigameDefinition = {
  id: 'crown-chase',
  name: 'CROWN CHASE',
  description: 'Tartsd meg a koronát a legtovább! Aki a koronát hordja, folyamatosan pontot kap!',
  duration: 40,
  instructions: 'MOZGÁS A D-PADDAL! Érj hozzá a koronáshoz, hogy megszerezd! Menekülj a többiek elől!',
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

    // Pick 1 random initial crown holder
    const initialCrownIndex = Math.floor(Math.random() * total);

    playersList.forEach((p, idx) => {
      const spreadX = total > 1 ? ((idx - (total - 1) / 2) / (total - 1)) * 9.0 : 0;
      const isHolder = idx === initialCrownIndex;

      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: spreadX,
        z: isHolder ? -2.0 : 2.0,
        vx: 0,
        vz: 0,
        facing: 0,
        speed: isHolder ? 5.2 : 5.6, // Crown bearer is slightly slower so chasers can catch up!
        radius: 0.55,
        score: 0,
        crownTime: 0,
        hasCrown: isHolder,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      currentCrownHolder: playersList[initialCrownIndex]?.id,
      tagHistory: [] as { fromId: string; toId: string; timestamp: number }[],
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
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const currentHolderId = mgData.currentCrownHolder;
    const holder = currentHolderId ? (mgData.players[currentHolderId] as ArenaPlayerSim) : null;

    // Crown holder accumulates possession score
    if (holder) {
      holder.crownTime = (holder.crownTime || 0) + dt;
      holder.score = Math.floor(holder.crownTime * 10) / 10;
      mgData.scores[holder.id] = holder.score;
    }

    const players = Object.values(mgData.players as Record<string, ArenaPlayerSim>);

    // Update movement & bot AI
    players.forEach(p => {
      let input = p.lastInput;

      if (p.isBot) {
        if (p.hasCrown) {
          // Bot is holding crown: run away from nearest chaser!
          let nearestChaser: ArenaPlayerSim | null = null;
          let minD = 999;
          players.forEach(other => {
            if (other.id === p.id) return;
            const d = Math.hypot(other.x - p.x, other.z - p.z);
            if (d < minD) {
              minD = d;
              nearestChaser = other;
            }
          });

          const avoidX = nearestChaser ? (nearestChaser as ArenaPlayerSim).x : undefined;
          const avoidZ = nearestChaser ? (nearestChaser as ArenaPlayerSim).z : undefined;
          input = generateBotSteering(p, 0, 0, avoidX, avoidZ, 3.5);
        } else if (holder) {
          // Bot is chasing crown: run straight toward crown holder!
          input = generateBotSteering(p, holder.x, holder.z);
        }
      }

      updatePlayerMovement(p, input, dt, ARENA_BOUNDS);
    });

    // Check tag collision: anyone touching crown holder steals the crown
    if (holder) {
      for (const chaser of players) {
        if (chaser.id === holder.id) continue;
        const dist = Math.hypot(chaser.x - holder.x, chaser.z - holder.z);
        if (dist <= chaser.radius + holder.radius + 0.15) {
          // Crown stolen!
          holder.hasCrown = false;
          holder.speed = 5.6; // restore normal speed
          chaser.hasCrown = true;
          chaser.speed = 5.2; // crown holder slightly slower
          mgData.currentCrownHolder = chaser.id;

          mgData.tagHistory.push({
            fromId: holder.id,
            toId: chaser.id,
            timestamp: Date.now(),
          });
          break;
        }
      }
    }

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${(scores[pId] || 0).toFixed(1)} mp birtoklás 👑`,
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
