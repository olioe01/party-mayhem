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

export interface CrownPlayerSim extends Minigame2DPlayer {
  hasCrown: boolean;
  crownTime: number;
  tagImmunityTimer: number;
  sprintTimer?: number;
  sprintCooldown?: number;
  isDummy?: boolean;
}

export const crownChaseMinigame: MinigameDefinition = {
  id: 'crown-chase',
  name: 'CROWN CHASE',
  description: 'Tartsd meg a koronát a legtovább! Aki a koronát hordja, folyamatosan pontot kap!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS • [A] = SPRINT! Érj hozzá a koronához, hogy megszerezd! Menekülj a többiek elől!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'SPRINT',
    bLabel: '—',
    aHidden: false,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS • [A] = SPRINT • Tartsd meg a koronát!',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, CrownPlayerSim> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      const dist = total > 1 ? 320 : 0;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: 960 + Math.cos(angle) * dist,
        y: 620 + Math.sin(angle) * dist,
        vx: 0,
        vy: 0,
        facing: -Math.PI / 2,
        speed: 550,
        radius: 36,
        score: 0,
        hasCrown: false,
        crownTime: 0,
        tagImmunityTimer: 0,
        sprintTimer: 0,
        sprintCooldown: 0,
        isHit: false,
        hitTimer: 0,
      };
      scores[p.id] = 0;
    });

    let initialHolderId = playersList[0]?.id;

    // SOLO MODE: If 1 human and 0 bots, add 2 Challenger Dummies
    if (total === 1 && !playersList[0].isBot) {
      const dummy1Id = '__dummy_1';
      simPlayers[dummy1Id] = {
        id: dummy1Id,
        name: '🤖 Korona Harcos 1',
        color: '#f59e0b',
        isBot: true,
        isDummy: true,
        x: 680,
        y: 420,
        vx: 0,
        vy: 0,
        facing: 0,
        speed: 510,
        radius: 36,
        score: 0,
        hasCrown: true, // Dummy starts with crown in solo mode so human gets to chase!
        crownTime: 0,
        tagImmunityTimer: 0,
        sprintTimer: 0,
        sprintCooldown: 0,
        isHit: false,
        hitTimer: 0,
      };

      const dummy2Id = '__dummy_2';
      simPlayers[dummy2Id] = {
        id: dummy2Id,
        name: '🤖 Korona Harcos 2',
        color: '#ec4899',
        isBot: true,
        isDummy: true,
        x: 1240,
        y: 420,
        vx: 0,
        vy: 0,
        facing: Math.PI,
        speed: 540,
        radius: 36,
        score: 0,
        hasCrown: false,
        crownTime: 0,
        tagImmunityTimer: 0,
        sprintTimer: 0,
        sprintCooldown: 0,
        isHit: false,
        hitTimer: 0,
      };

      initialHolderId = dummy1Id;
    } else {
      // Pick 1 random starting player to hold crown
      const randIdx = Math.floor(Math.random() * total);
      initialHolderId = playersList[randIdx]?.id;
      if (simPlayers[initialHolderId]) {
        simPlayers[initialHolderId].hasCrown = true;
      }
    }

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      currentCrownHolder: initialHolderId,
      tagEvents: [] as { fromId: string; toId: string; x: number; y: number; timestamp: number }[],
    };
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim = mgData.players[playerId] as CrownPlayerSim;

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

      // Sprint burst on [A] press
      if (nextA && !prevA && (!sim.sprintCooldown || sim.sprintCooldown <= 0)) {
        sim.sprintTimer = 0.28;
        sim.sprintCooldown = 1.4;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players) return false;

    const currentHolderId = mgData.currentCrownHolder;
    const holder = currentHolderId ? (mgData.players[currentHolderId] as CrownPlayerSim) : null;

    // 1. Crown possession score accumulation
    if (holder) {
      holder.crownTime = (holder.crownTime || 0) + dt;
      holder.score = Math.floor(holder.crownTime * 10) / 10;
      mgData.scores[holder.id] = holder.score;
    }

    const players = Object.values(mgData.players as Record<string, CrownPlayerSim>);

    // 2. Update players & bot AI
    players.forEach(p => {
      let input = p.lastInput;

      if (p.sprintCooldown && p.sprintCooldown > 0) p.sprintCooldown -= dt;
      if (p.sprintTimer && p.sprintTimer > 0) {
        p.sprintTimer -= dt;
        p.speed = 840; // Sprint burst
      } else {
        p.speed = p.hasCrown ? 505 : 550; // Crown bearer slightly slower so chasers can catch up
      }

      if (p.tagImmunityTimer > 0) p.tagImmunityTimer -= dt;

      if (p.isBot) {
        if (p.hasCrown) {
          // Bot has crown: flee from closest chaser!
          let nearestChaser: CrownPlayerSim | null = null;
          let nearestDist = 9999;
          players.forEach(other => {
            if (other.id === p.id) return;
            const d = distance2D(p.x, p.y, other.x, other.y);
            if (d < nearestDist) {
              nearestDist = d;
              nearestChaser = other;
            }
          });

          if (nearestChaser) {
            const ch = nearestChaser as CrownPlayerSim;
            const fleeX = p.x + (p.x - ch.x);
            const fleeY = p.y + (p.y - ch.y);
            input = generateBotSteering2D(p, fleeX, fleeY);

            // Sprint if chaser is close (< 180px)
            if (nearestDist < 180 && (!p.sprintCooldown || p.sprintCooldown <= 0)) {
              p.sprintTimer = 0.28;
              p.sprintCooldown = 1.5;
            }
          }
        } else if (holder) {
          // Bot is chaser: steer toward crown holder!
          input = generateBotSteering2D(p, holder.x, holder.y);
          const dToHolder = distance2D(p.x, p.y, holder.x, holder.y);
          if (dToHolder < 200 && (!p.sprintCooldown || p.sprintCooldown <= 0)) {
            p.sprintTimer = 0.28;
            p.sprintCooldown = 1.6;
          }
        }
      }

      updatePlayerMovement2D(p, input, dt, DEFAULT_2D_BOUNDS);
    });

    // 3. Tag / Crown Stealing Collision
    if (holder) {
      for (const chaser of players) {
        if (chaser.id === holder.id) continue;
        if (chaser.tagImmunityTimer > 0) continue;

        const dist = distance2D(chaser.x, chaser.y, holder.x, holder.y);
        if (dist <= chaser.radius + holder.radius + 14) {
          // Crown stolen!
          holder.hasCrown = false;
          holder.tagImmunityTimer = 1.1; // 1.1s immunity so crown doesn't bounce immediately back

          chaser.hasCrown = true;
          mgData.currentCrownHolder = chaser.id;

          mgData.tagEvents.push({
            fromId: holder.id,
            toId: chaser.id,
            x: chaser.x,
            y: chaser.y,
            timestamp: Date.now(),
          });
          break;
        }
      }
    }

    // Prune tag events older than 1.5s
    const now = Date.now();
    mgData.tagEvents = (mgData.tagEvents || []).filter((e: any) => now - e.timestamp < 1500);

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
