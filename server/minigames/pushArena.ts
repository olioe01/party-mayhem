import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  ArenaPlayerSim,
  ArenaBounds,
  updatePlayerMovement,
} from './arenaUtils';

export interface PushArenaPlayerSim extends ArenaPlayerSim {
  lastPushedBy?: string;
  isFalling?: boolean;
  fallTimer?: number;
}

const PLATFORM_RADIUS = 5.8;

const ARENA_BOUNDS: ArenaBounds = {
  minX: -8,
  maxX: 8,
  minZ: -8,
  maxZ: 8,
};

export const pushArenaMinigame: MinigameDefinition = {
  id: 'push-arena',
  name: 'PUSH ARENA',
  description: 'Lökd le az ellenfeleket a lebegő arénáról! Maradj talpon!',
  duration: 45,
  instructions: 'D-PAD = MOZGÁS • [A] = LÖKÉS (PUSH) • [B] = ROHAM (DASH)! Pontot kapsz minden kilökésért!',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'LÖKÉS',
    bLabel: 'DASH',
    aHidden: false,
    bHidden: false,
    instructions: 'A = Lökés, B = Dash',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, PushArenaPlayerSim> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: Math.cos(angle) * 3.0,
        z: Math.sin(angle) * 3.0,
        vx: 0,
        vz: 0,
        facing: angle + Math.PI,
        speed: 5.2,
        radius: 0.6,
        score: 0,
        cooldownA: 0,
        cooldownB: 0,
        isFalling: false,
        fallTimer: 0,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      ringOutEvents: [] as { pusherId: string; victimId: string; timestamp: number }[],
    };
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim = mgData.players[playerId] as PushArenaPlayerSim;

    if (data && typeof data === 'object') {
      sim.lastInput = {
        up: Boolean(data.up),
        down: Boolean(data.down),
        left: Boolean(data.left),
        right: Boolean(data.right),
        a: Boolean(data.a),
        b: Boolean(data.b),
      };

      // Handle A Button (PUSH)
      if (data.a && (!sim.cooldownA || sim.cooldownA <= 0) && !sim.isFalling) {
        sim.cooldownA = 0.6; // 0.6s cooldown

        // Check opponents in front of player
        Object.values(mgData.players as Record<string, PushArenaPlayerSim>).forEach(opp => {
          if (opp.id === sim.id || opp.isFalling) return;
          const dx = opp.x - sim.x;
          const dz = opp.z - sim.z;
          const dist = Math.hypot(dx, dz);

          if (dist < 1.7) {
            // Push vector in facing direction
            const pushDirX = Math.sin(sim.facing);
            const pushDirZ = Math.cos(sim.facing);
            opp.vx += pushDirX * 8.5;
            opp.vz += pushDirZ * 8.5;
            opp.lastPushedBy = sim.id;
            opp.hitTimer = 0.4;
            opp.isHit = true;
          }
        });
      }

      // Handle B Button (DASH)
      if (data.b && (!sim.cooldownB || sim.cooldownB <= 0) && !sim.isFalling) {
        sim.cooldownB = 2.0;
        const dashDirX = Math.sin(sim.facing);
        const dashDirZ = Math.cos(sim.facing);
        sim.vx += dashDirX * 7.0;
        sim.vz += dashDirZ * 7.0;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const players = Object.values(mgData.players as Record<string, PushArenaPlayerSim>);

    players.forEach(p => {
      // Handle respawn / falling
      if (p.isFalling) {
        p.fallTimer = (p.fallTimer || 0) - dt;
        if (p.fallTimer <= 0) {
          // Respawn in center
          p.isFalling = false;
          p.x = (Math.random() - 0.5) * 2.0;
          p.z = (Math.random() - 0.5) * 2.0;
          p.vx = 0;
          p.vz = 0;
          p.lastPushedBy = undefined;
        }
        return;
      }

      let input = p.lastInput;

      // Bot AI: Move toward nearest opponent and push when in range; avoid falling off edge
      if (p.isBot) {
        const distFromCenter = Math.hypot(p.x, p.z);
        if (distFromCenter > PLATFORM_RADIUS - 1.2) {
          // Danger! Steer back to center
          const angleToCenter = Math.atan2(-p.x, -p.z);
          input = {
            left: -p.x < -0.2,
            right: -p.x > 0.2,
            up: -p.z < -0.2,
            down: -p.z > 0.2,
            a: false,
            b: false,
          };
        } else {
          // Hunt closest opponent
          let closestOpp: PushArenaPlayerSim | null = null;
          let closestDist = 999;
          players.forEach(opp => {
            if (opp.id === p.id || opp.isFalling) return;
            const d = Math.hypot(opp.x - p.x, opp.z - p.z);
            if (d < closestDist) {
              closestDist = d;
              closestOpp = opp;
            }
          });

          if (closestOpp) {
            const dx = (closestOpp as PushArenaPlayerSim).x - p.x;
            const dz = (closestOpp as PushArenaPlayerSim).z - p.z;
            const shouldPush = closestDist < 1.4 && (!p.cooldownA || p.cooldownA <= 0);

            input = {
              left: dx < -0.2,
              right: dx > 0.2,
              up: dz < -0.2,
              down: dz > 0.2,
              a: shouldPush,
              b: closestDist > 3.0 && (!p.cooldownB || p.cooldownB <= 0),
            };

            if (shouldPush) {
              // Trigger A
              this.handleInput!(room, p.id, { a: true });
            }
          }
        }
      }

      // Apply input velocity
      updatePlayerMovement(p, input, dt, ARENA_BOUNDS);

      // Apply drag to impulse velocity
      p.x += p.vx * dt;
      p.z += p.vz * dt;
      p.vx *= Math.max(0, 1 - 5.0 * dt);
      p.vz *= Math.max(0, 1 - 5.0 * dt);

      // Check if fallen off platform
      const distFromCenter = Math.hypot(p.x, p.z);
      if (distFromCenter > PLATFORM_RADIUS + 0.3 && !p.isFalling) {
        p.isFalling = true;
        p.fallTimer = 1.8; // respawn in 1.8s

        if (p.lastPushedBy && mgData.players[p.lastPushedBy]) {
          const pusher = mgData.players[p.lastPushedBy];
          pusher.score += 1;
          mgData.scores[pusher.id] = pusher.score;
          mgData.ringOutEvents.push({
            pusherId: pusher.id,
            victimId: p.id,
            timestamp: Date.now(),
          });
        }
      }
    });

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} kilökés (ring-out)`,
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
