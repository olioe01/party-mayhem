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

export interface MonsterSim {
  x: number;
  y: number;
  vx: number;
  vy: number;
  facing: number;
  speed: number;
  radius: number;
  targetPlayerId: string | null;
  targetSwitchTimer: number;
  rageTimer: number;
  isEnraged: boolean;
  catchCooldown: number;
}

export interface CrystalCollectible {
  id: number;
  x: number;
  y: number;
  type: 'blue' | 'purple';
  points: number;
  radius: number;
}

export const monsterEscapeMinigame: MinigameDefinition = {
  id: 'monster-escape',
  name: 'MONSTER ESCAPE',
  description: 'Menekülj az éhes szörny elől és gyűjts minél több energiakristályt!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS • [A] = SPRINT / KITÉRÉS! Gyűjts kristályokat és ne hagyd, hogy elkapjon a szörny!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'SPRINT',
    bLabel: '—',
    aHidden: false,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS • [A] = SPRINT / KITÉRÉS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, Minigame2DPlayer & { sprintTimer?: number; sprintCooldown?: number }> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      const dist = total > 1 ? 380 : 0;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: 960 + Math.cos(angle) * dist,
        y: 720 + Math.sin(angle) * dist, // Spawn in southern quadrant
        vx: 0,
        vy: 0,
        facing: -Math.PI / 2,
        speed: 520,
        radius: 34,
        score: 0,
        isHit: false,
        hitTimer: 0,
        sprintTimer: 0,
        sprintCooldown: 0,
      };
      scores[p.id] = 0;
    });

    const monster: MonsterSim = {
      x: 960,
      y: 360, // Spawn in northern quadrant
      vx: 0,
      vy: 0,
      facing: Math.PI / 2,
      speed: 400,
      radius: 56,
      targetPlayerId: null,
      targetSwitchTimer: 0,
      rageTimer: 8.0,
      isEnraged: false,
      catchCooldown: 0,
    };

    // 12 initial crystals scattered across the arena
    const crystals: CrystalCollectible[] = [];
    let nextId = 1;
    for (let i = 0; i < 12; i++) {
      const isPurple = i % 4 === 0;
      crystals.push({
        id: nextId++,
        x: 260 + Math.random() * (1660 - 260),
        y: 260 + Math.random() * (900 - 260),
        type: isPurple ? 'purple' : 'blue',
        points: isPurple ? 3 : 1,
        radius: isPurple ? 26 : 20,
      });
    }

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      monster,
      crystals,
      nextCrystalId: nextId,
      events: [] as { type: string; x: number; y: number; text: string; timestamp: number }[],
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

      // Sprint burst on [A] press
      if (nextA && !prevA && (!sim.sprintCooldown || sim.sprintCooldown <= 0)) {
        sim.sprintTimer = 0.32;
        sim.sprintCooldown = 1.3;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const simPlayers = mgData.players as Record<string, Minigame2DPlayer & { sprintTimer?: number; sprintCooldown?: number }>;
    const monster = mgData.monster as MonsterSim;
    const crystals = mgData.crystals as CrystalCollectible[];

    // 1. Monster AI & Rage Cycle
    if (monster.catchCooldown > 0) {
      monster.catchCooldown -= dt;
      monster.vx = 0;
      monster.vy = 0;
    } else {
      // Rage timer countdown
      monster.rageTimer -= dt;
      if (monster.rageTimer <= 0) {
        if (!monster.isEnraged) {
          monster.isEnraged = true;
          monster.rageTimer = 2.5; // Enraged for 2.5s
          monster.speed = 570;
        } else {
          monster.isEnraged = false;
          monster.rageTimer = 7.5; // Rest for 7.5s
          monster.speed = 400;
        }
      }

      // Pick target player (nearest active player)
      monster.targetSwitchTimer -= dt;
      if (monster.targetSwitchTimer <= 0 || !monster.targetPlayerId || !simPlayers[monster.targetPlayerId]) {
        monster.targetSwitchTimer = 2.0;
        let nearestP: Minigame2DPlayer | null = null;
        let nearestDist = 9999;
        Object.values(simPlayers).forEach(p => {
          const d = distance2D(monster.x, monster.y, p.x, p.y);
          if (d < nearestDist) {
            nearestDist = d;
            nearestP = p;
          }
        });
        if (nearestP) {
          monster.targetPlayerId = (nearestP as Minigame2DPlayer).id;
        }
      }

      // Steer monster towards target
      if (monster.targetPlayerId && simPlayers[monster.targetPlayerId]) {
        const target = simPlayers[monster.targetPlayerId];
        const dx = target.x - monster.x;
        const dy = target.y - monster.y;
        const dist = Math.hypot(dx, dy);
        if (dist > 10) {
          monster.vx = (dx / dist) * monster.speed;
          monster.vy = (dy / dist) * monster.speed;
          monster.facing = Math.atan2(dy, dx);
        }
      }

      // Update monster position
      monster.x += monster.vx * dt;
      monster.y += monster.vy * dt;

      // Keep monster within arena bounds
      monster.x = Math.max(DEFAULT_2D_BOUNDS.minX, Math.min(DEFAULT_2D_BOUNDS.maxX, monster.x));
      monster.y = Math.max(DEFAULT_2D_BOUNDS.minY, Math.min(DEFAULT_2D_BOUNDS.maxY, monster.y));
    }

    // 2. Update players & bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      if (sim.sprintCooldown && sim.sprintCooldown > 0) sim.sprintCooldown -= dt;
      if (sim.sprintTimer && sim.sprintTimer > 0) {
        sim.sprintTimer -= dt;
        sim.speed = 860; // Sprint burst
      } else {
        sim.speed = 520;
      }

      if (sim.hitTimer && sim.hitTimer > 0) {
        sim.hitTimer -= dt;
        if (sim.hitTimer <= 0) sim.isHit = false;
      }

      if (sim.isBot) {
        const distToMonster = distance2D(sim.x, sim.y, monster.x, monster.y);
        if (distToMonster < 300) {
          // Flee from monster
          const fleeX = sim.x + (sim.x - monster.x);
          const fleeY = sim.y + (sim.y - monster.y);
          input = generateBotSteering2D(sim, fleeX, fleeY);
          // Sprint to escape
          if ((!sim.sprintCooldown || sim.sprintCooldown <= 0) && distToMonster < 200) {
            sim.sprintTimer = 0.32;
            sim.sprintCooldown = 1.4;
          }
        } else {
          // Seek nearest crystal
          let nearestC: CrystalCollectible | null = null;
          let nearestCDist = 9999;
          crystals.forEach(c => {
            const d = distance2D(sim.x, sim.y, c.x, c.y);
            if (d < nearestCDist) {
              nearestCDist = d;
              nearestC = c;
            }
          });
          if (nearestC) {
            input = generateBotSteering2D(sim, (nearestC as CrystalCollectible).x, (nearestC as CrystalCollectible).y);
          }
        }
      }

      updatePlayerMovement2D(sim, input, dt, DEFAULT_2D_BOUNDS);

      // 3. Collision with Monster
      if (monster.catchCooldown <= 0 && !sim.isHit) {
        if (distance2D(sim.x, sim.y, monster.x, monster.y) <= sim.radius + monster.radius - 8) {
          sim.isHit = true;
          sim.hitTimer = 1.0;
          sim.score = Math.max(0, (sim.score || 0) - 3);
          mgData.scores[sim.id] = sim.score;

          // Monster cooldown
          monster.catchCooldown = 1.4;
          monster.isEnraged = false;

          mgData.events.push({
            type: 'chomp',
            x: sim.x,
            y: sim.y,
            text: '-3 💥 BEKAPOTT A SZÖRNY!',
            timestamp: Date.now(),
          });
        }
      }

      // 4. Crystal collection
      for (let i = crystals.length - 1; i >= 0; i--) {
        const c = crystals[i];
        if (distance2D(sim.x, sim.y, c.x, c.y) <= sim.radius + c.radius) {
          sim.score = (sim.score || 0) + c.points;
          mgData.scores[sim.id] = sim.score;

          mgData.events.push({
            type: 'crystal',
            x: c.x,
            y: c.y,
            text: `+${c.points} ${c.type === 'purple' ? '🔮' : '⚡'}`,
            timestamp: Date.now(),
          });

          // Respawn crystal in new location
          crystals.splice(i, 1);
          crystals.push({
            id: mgData.nextCrystalId++,
            x: 260 + Math.random() * (1660 - 260),
            y: 260 + Math.random() * (900 - 260),
            type: Math.random() < 0.25 ? 'purple' : 'blue',
            points: Math.random() < 0.25 ? 3 : 1,
            radius: Math.random() < 0.25 ? 26 : 20,
          });
        }
      }
    });

    // Prune events older than 1.5s
    const now = Date.now();
    mgData.events = (mgData.events || []).filter((e: any) => now - e.timestamp < 1500);

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} kristály összegyűjtve`,
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
