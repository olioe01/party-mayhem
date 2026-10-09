import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  Minigame2DPlayer,
  DEFAULT_2D_BOUNDS,
  updatePlayerMovement2D,
  generateBotSteering2D,
  distance2D,
} from './sim2dUtils';

export interface TreasureChest {
  id: number;
  x: number;
  y: number;
  opened: boolean;
  openedBy?: string;
  points: number;
  type: 'coins1' | 'coins3' | 'jackpot5' | 'empty' | 'trap';
}

export const treasureGrabMinigame: MinigameDefinition = {
  id: 'treasure-grab',
  name: 'TREASURE GRAB',
  description: 'Járd be a kincseskamrát, és nyisd ki a ládákat az [A] gombbal!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS • [A] = LÁDA KINYITÁSA! Vigyázz, néhány láda csapdát rejt (-3 💣)!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'NYITÁS',
    bLabel: '—',
    aHidden: false,
    bHidden: false,
    instructions: 'Menj a ládához és nyomd meg az [A] gombot!',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, Minigame2DPlayer> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      const dist = total > 1 ? 260 : 0;
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

    // Generate 10 distinct treasure chests across the arena
    const chests: TreasureChest[] = [
      { id: 1, x: 360, y: 300, opened: false, points: 1, type: 'coins1' },
      { id: 2, x: 760, y: 280, opened: false, points: 3, type: 'coins3' },
      { id: 3, x: 1160, y: 280, opened: false, points: 1, type: 'coins1' },
      { id: 4, x: 1560, y: 300, opened: false, points: 5, type: 'jackpot5' },
      { id: 5, x: 420, y: 540, opened: false, points: 3, type: 'coins3' },
      { id: 6, x: 1500, y: 540, opened: false, points: 0, type: 'empty' },
      { id: 7, x: 360, y: 780, opened: false, points: -3, type: 'trap' },
      { id: 8, x: 760, y: 800, opened: false, points: 1, type: 'coins1' },
      { id: 9, x: 1160, y: 800, opened: false, points: 3, type: 'coins3' },
      { id: 10, x: 1560, y: 780, opened: false, points: 1, type: 'coins1' },
    ];

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      chests,
      openEvents: [] as { playerId: string; chestId: number; type: string; points: number; x: number; y: number; timestamp: number }[],
    };
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim = mgData.players[playerId];

    if (data && typeof data === 'object') {
      const prevA = sim.lastInput?.a;
      const nextA = Boolean(data.a);

      sim.lastInput = {
        up: Boolean(data.up),
        down: Boolean(data.down),
        left: Boolean(data.left),
        right: Boolean(data.right),
        a: nextA,
        b: Boolean(data.b),
      };

      // Button A pressed down edge (trigger open chest)
      if (nextA && !prevA) {
        attemptOpenChest(mgData, sim);
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !Array.isArray(mgData.chests)) return false;

    const simPlayers = mgData.players as Record<string, Minigame2DPlayer>;
    const chests = mgData.chests as TreasureChest[];

    // 1. Update player movement and Bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      if (sim.isBot) {
        // Bots seek nearest unopened chest
        let nearestUnopened: TreasureChest | null = null;
        let nearestDist = 9999;

        chests.forEach(ch => {
          if (!ch.opened) {
            const d = distance2D(sim.x, sim.y, ch.x, ch.y);
            if (d < nearestDist) {
              nearestDist = d;
              nearestUnopened = ch;
            }
          }
        });

        if (nearestUnopened) {
          const target = nearestUnopened as TreasureChest;
          input = generateBotSteering2D(sim, target.x, target.y);
          // If within range, bot presses A
          if (nearestDist < 75) {
            input.a = true;
            attemptOpenChest(mgData, sim);
          }
        } else {
          input = { up: false, down: false, left: false, right: false, a: false, b: false };
        }
      }

      updatePlayerMovement2D(sim, input, dt, DEFAULT_2D_BOUNDS);
    });

    // Prune open events older than 1.5s
    const now = Date.now();
    mgData.openEvents = (mgData.openEvents || []).filter((e: any) => now - e.timestamp < 1500);

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} kincs megszervezve`,
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

function attemptOpenChest(mgData: any, sim: Minigame2DPlayer) {
  const chests = mgData.chests as TreasureChest[];
  const interactRadius = 88;

  for (const ch of chests) {
    if (!ch.opened && distance2D(sim.x, sim.y, ch.x, ch.y) <= interactRadius) {
      ch.opened = true;
      ch.openedBy = sim.id;

      if (ch.type === 'trap') {
        sim.score = Math.max(0, sim.score - 3);
        sim.isHit = true;
        sim.hitTimer = 0.8;
      } else {
        sim.score += ch.points;
      }

      mgData.scores[sim.id] = sim.score;
      mgData.openEvents.push({
        playerId: sim.id,
        chestId: ch.id,
        type: ch.type,
        points: ch.points,
        x: ch.x,
        y: ch.y,
        timestamp: Date.now(),
      });
      break;
    }
  }
}
