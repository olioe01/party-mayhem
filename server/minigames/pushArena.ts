import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  Minigame2DPlayer,
  generateBotSteering2D,
  distance2D,
} from './sim2dUtils';

export interface PushArenaPlayerSim extends Minigame2DPlayer {
  lastPushedBy?: string;
  isFalling?: boolean;
  fallTimer?: number;
  cooldownA?: number;
  cooldownB?: number;
  isDummy?: boolean;
}

export const PUSH_RING_CENTER_X = 960;
export const PUSH_RING_CENTER_Y = 540;
export const PUSH_RING_RADIUS = 430;

export const pushArenaMinigame: MinigameDefinition = {
  id: 'push-arena',
  name: 'PUSH ARENA',
  description: 'Lökd le az ellenfeleket a lebegő arénáról! Maradj talpon!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS • [A] = LÖKÉS (PUSH) • [B] = ROHAM (DASH)! Pontot kapsz minden kilökésért!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'LÖKÉS',
    bLabel: 'DASH',
    aHidden: false,
    bHidden: false,
    instructions: 'A = LÖKÉS • B = DASH',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, PushArenaPlayerSim> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      const dist = total > 1 ? 260 : 0;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: PUSH_RING_CENTER_X + Math.cos(angle) * dist,
        y: PUSH_RING_CENTER_Y + Math.sin(angle) * dist,
        vx: 0,
        vy: 0,
        facing: angle + Math.PI,
        speed: 530,
        radius: 36,
        score: 0,
        cooldownA: 0,
        cooldownB: 0,
        isFalling: false,
        fallTimer: 0,
        isHit: false,
        hitTimer: 0,
      };
      scores[p.id] = 0;
    });

    // SOLO MODE: If exactly 1 player and 0 bots, add 2 Training Dummies
    if (total === 1 && !playersList[0].isBot) {
      const dummy1Id = '__dummy_1';
      simPlayers[dummy1Id] = {
        id: dummy1Id,
        name: '🤖 Gyakorló Bot 1',
        color: '#f59e0b',
        isBot: true,
        isDummy: true,
        x: PUSH_RING_CENTER_X - 220,
        y: PUSH_RING_CENTER_Y,
        vx: 0,
        vy: 0,
        facing: 0,
        speed: 380,
        radius: 36,
        score: 0,
        cooldownA: 0,
        cooldownB: 0,
        isFalling: false,
        fallTimer: 0,
        isHit: false,
        hitTimer: 0,
      };

      const dummy2Id = '__dummy_2';
      simPlayers[dummy2Id] = {
        id: dummy2Id,
        name: '🤖 Gyakorló Bot 2',
        color: '#ec4899',
        isBot: true,
        isDummy: true,
        x: PUSH_RING_CENTER_X + 220,
        y: PUSH_RING_CENTER_Y,
        vx: 0,
        vy: 0,
        facing: Math.PI,
        speed: 380,
        radius: 36,
        score: 0,
        cooldownA: 0,
        cooldownB: 0,
        isFalling: false,
        fallTimer: 0,
        isHit: false,
        hitTimer: 0,
      };
    }

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      ringOutEvents: [] as { pusherId: string; victimId: string; x: number; y: number; timestamp: number }[],
    };
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim = mgData.players[playerId] as PushArenaPlayerSim;

    if (data && typeof data === 'object') {
      const prevA = sim.lastInput?.a;
      const prevB = sim.lastInput?.b;
      const nextA = Boolean(data.a);
      const nextB = Boolean(data.b);

      sim.lastInput = {
        up: Boolean(data.up),
        down: Boolean(data.down),
        left: Boolean(data.left),
        right: Boolean(data.right),
        a: nextA,
        b: nextB,
      };

      // Immediately orient facing from input if directional buttons are held
      let moveX = 0;
      let moveY = 0;
      if (data.left) moveX -= 1;
      if (data.right) moveX += 1;
      if (data.up) moveY -= 1;
      if (data.down) moveY += 1;
      if (moveX !== 0 || moveY !== 0) {
        sim.facing = Math.atan2(moveY, moveX);
      }

      // Push attack on [A] press
      if (nextA && !prevA && (!sim.cooldownA || sim.cooldownA <= 0) && !sim.isFalling) {
        sim.cooldownA = 0.55;
        performPush(mgData, sim);
      }

      // Dash burst on [B] press
      if (nextB && !prevB && (!sim.cooldownB || sim.cooldownB <= 0) && !sim.isFalling) {
        sim.cooldownB = 1.6;
        sim.vx += Math.cos(sim.facing) * 750;
        sim.vy += Math.sin(sim.facing) * 750;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const players = Object.values(mgData.players as Record<string, PushArenaPlayerSim>);

    players.forEach(p => {
      // Cooldowns
      if (p.cooldownA && p.cooldownA > 0) p.cooldownA -= dt;
      if (p.cooldownB && p.cooldownB > 0) p.cooldownB -= dt;
      if (p.hitTimer && p.hitTimer > 0) {
        p.hitTimer -= dt;
        if (p.hitTimer <= 0) p.isHit = false;
      }

      // Falling / Ring-out respawn state
      if (p.isFalling) {
        p.fallTimer = (p.fallTimer || 0) - dt;
        if (p.fallTimer <= 0) {
          // Respawn in ring center
          p.isFalling = false;
          p.x = PUSH_RING_CENTER_X + (Math.random() - 0.5) * 160;
          p.y = PUSH_RING_CENTER_Y + (Math.random() - 0.5) * 160;
          p.vx = 0;
          p.vy = 0;
          p.lastPushedBy = undefined;
        }
        return;
      }

      let input = p.lastInput;

      // Bot AI
      if (p.isBot) {
        const distFromCenter = distance2D(p.x, p.y, PUSH_RING_CENTER_X, PUSH_RING_CENTER_Y);
        if (distFromCenter > PUSH_RING_RADIUS - 90) {
          // Dangerously close to edge! Steer back toward center
          input = generateBotSteering2D(p, PUSH_RING_CENTER_X, PUSH_RING_CENTER_Y);
        } else {
          // Seek closest opponent
          let closestOpp: PushArenaPlayerSim | null = null;
          let closestDist = 9999;
          players.forEach(opp => {
            if (opp.id === p.id || opp.isFalling) return;
            const d = distance2D(p.x, p.y, opp.x, opp.y);
            if (d < closestDist) {
              closestDist = d;
              closestOpp = opp;
            }
          });

          if (closestOpp) {
            const opp = closestOpp as PushArenaPlayerSim;
            input = generateBotSteering2D(p, opp.x, opp.y);

            // Push if in range
            if (closestDist < 85 && (!p.cooldownA || p.cooldownA <= 0)) {
              input.a = true;
              p.cooldownA = 0.65;
              performPush(mgData, p);
            }
          }
        }
      }

      // Movement vector from input
      let moveX = 0;
      let moveY = 0;
      if (input?.left) moveX -= 1;
      if (input?.right) moveX += 1;
      if (input?.up) moveY -= 1;
      if (input?.down) moveY += 1;

      if (moveX !== 0 || moveY !== 0) {
        const len = Math.hypot(moveX, moveY);
        p.facing = Math.atan2(moveY, moveX);
        p.vx += (moveX / len) * p.speed * 4.0 * dt;
        p.vy += (moveY / len) * p.speed * 4.0 * dt;
      }

      // Apply physics velocity & friction damping
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= Math.pow(0.08, dt);
      p.vy *= Math.pow(0.08, dt);

      // Check Ring-out
      const distFromCenter = distance2D(p.x, p.y, PUSH_RING_CENTER_X, PUSH_RING_CENTER_Y);
      if (distFromCenter > PUSH_RING_RADIUS) {
        p.isFalling = true;
        p.fallTimer = 1.2;

        if (p.lastPushedBy && mgData.players[p.lastPushedBy]) {
          const pusher = mgData.players[p.lastPushedBy];
          pusher.score = (pusher.score || 0) + 1;
          mgData.scores[pusher.id] = pusher.score;

          mgData.ringOutEvents.push({
            pusherId: pusher.id,
            victimId: p.id,
            x: p.x,
            y: p.y,
            timestamp: Date.now(),
          });
        }
      }
    });

    // Prune ring-out events older than 1.5s
    const now = Date.now();
    mgData.ringOutEvents = (mgData.ringOutEvents || []).filter((e: any) => now - e.timestamp < 1500);

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} kiejtett ellenfél`,
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

function performPush(mgData: any, pusher: PushArenaPlayerSim) {
  const players = Object.values(mgData.players as Record<string, PushArenaPlayerSim>);
  const pushDirX = Math.cos(pusher.facing);
  const pushDirY = Math.sin(pusher.facing);

  players.forEach(opp => {
    if (opp.id === pusher.id || opp.isFalling) return;
    const d = distance2D(pusher.x, pusher.y, opp.x, opp.y);
    if (d < pusher.radius + opp.radius + 38) {
      opp.vx += pushDirX * 820;
      opp.vy += pushDirY * 820;
      opp.lastPushedBy = pusher.id;
      opp.isHit = true;
      opp.hitTimer = 0.55;
    }
  });
}
