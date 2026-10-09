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

export interface LavaPlatform {
  id: number;
  col: number;
  row: number;
  x: number;
  y: number;
  width: number;
  height: number;
  state: 'safe' | 'warning' | 'lava';
  timer: number;
}

export interface LavaRuby {
  id: number;
  x: number;
  y: number;
  platformId: number;
}

const COLS = 6;
const ROWS = 4;
const TILE_W = 210;
const TILE_H = 160;
const GAP_X = 48;
const GAP_Y = 46;
const START_X = 210;
const START_Y = 150;

export const floorIsLavaMinigame: MinigameDefinition = {
  id: 'floor-is-lava',
  name: 'FLOOR IS LAVA',
  description: 'A padló lávává válik! Menj a stabil kőtömbökre és kerüld el a forró magmát!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS • [A] = UGRÁS! Maradj a szilárd kőtömbökön a túlélésért!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'UGRÁS',
    bLabel: '—',
    aHidden: false,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS • [A] = UGRÁS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    // Create 24 platforms
    const platforms: LavaPlatform[] = [];
    let pId = 0;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const x = START_X + c * (TILE_W + GAP_X) + TILE_W / 2;
        const y = START_Y + r * (TILE_H + GAP_Y) + TILE_H / 2;
        platforms.push({
          id: pId++,
          col: c,
          row: r,
          x,
          y,
          width: TILE_W,
          height: TILE_H,
          state: 'safe',
          timer: 0,
        });
      }
    }

    const simPlayers: Record<string, Minigame2DPlayer & { jumpTimer?: number; jumpCooldown?: number }> = {};
    const scores: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      // Pick starting safe platform near center
      const startPlatform = platforms[10 + (idx % 4)];
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: startPlatform.x,
        y: startPlatform.y,
        vx: 0,
        vy: 0,
        facing: 0,
        speed: 520,
        radius: 34,
        score: 0,
        isHit: false,
        hitTimer: 0,
        jumpTimer: 0,
        jumpCooldown: 0,
      };
      scores[p.id] = 0;
    });

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      platforms,
      rubies: [] as LavaRuby[],
      nextRubyId: 1,
      rubySpawnTimer: 3.5,
      waveState: 'rest', // 'rest' | 'warning' | 'lava'
      waveTimer: 2.2, // 2.2s before first wave
      waveCount: 0,
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

      // Jump on [A] press
      if (nextA && !prevA && (!sim.jumpCooldown || sim.jumpCooldown <= 0)) {
        sim.jumpTimer = 0.38;
        sim.jumpCooldown = 0.75;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !Array.isArray(mgData.platforms)) return false;

    const simPlayers = mgData.players as Record<string, Minigame2DPlayer & { jumpTimer?: number; jumpCooldown?: number }>;
    const platforms = mgData.platforms as LavaPlatform[];
    const rubies = mgData.rubies as LavaRuby[];

    // 1. Ruby spawning
    mgData.rubySpawnTimer -= dt;
    if (mgData.rubySpawnTimer <= 0 && rubies.length < 3) {
      mgData.rubySpawnTimer = 5.0;
      // Pick a platform that is safe
      const safePlats = platforms.filter(pl => pl.state === 'safe');
      if (safePlats.length > 0) {
        const plat = safePlats[Math.floor(Math.random() * safePlats.length)];
        rubies.push({
          id: mgData.nextRubyId++,
          x: plat.x,
          y: plat.y,
          platformId: plat.id,
        });
      }
    }

    // 2. Wave state machine
    mgData.waveTimer -= dt;

    if (mgData.waveState === 'rest' && mgData.waveTimer <= 0) {
      // Transition from REST to WARNING
      mgData.waveState = 'warning';
      mgData.waveTimer = 1.6; // 1.6s warning
      mgData.waveCount++;

      // Pick 12 to 15 platforms to become lava (leaving 9-12 safe)
      const count = Math.min(15, 10 + Math.floor(mgData.waveCount * 1.2));
      const shuffled = [...platforms].sort(() => Math.random() - 0.5);
      for (let i = 0; i < platforms.length; i++) {
        if (i < count) {
          shuffled[i].state = 'warning';
        } else {
          shuffled[i].state = 'safe';
        }
      }
    } else if (mgData.waveState === 'warning' && mgData.waveTimer <= 0) {
      // Transition from WARNING to LAVA
      mgData.waveState = 'lava';
      mgData.waveTimer = 1.8; // 1.8s lava surge

      platforms.forEach(pl => {
        if (pl.state === 'warning') {
          pl.state = 'lava';
        }
      });

      // Award survival points to players currently on safe platforms
      Object.values(simPlayers).forEach(sim => {
        const currentPlat = platforms.find(
          pl => Math.abs(sim.x - pl.x) <= pl.width / 2 && Math.abs(sim.y - pl.y) <= pl.height / 2
        );
        if (currentPlat && currentPlat.state === 'safe') {
          sim.score = (sim.score || 0) + 4;
          mgData.scores[sim.id] = sim.score;
          mgData.events.push({
            type: 'survival',
            x: sim.x,
            y: sim.y,
            text: '+4 TÚLÉLVE! 🔥',
            timestamp: Date.now(),
          });
        }
      });
    } else if (mgData.waveState === 'lava' && mgData.waveTimer <= 0) {
      // Transition from LAVA back to REST
      mgData.waveState = 'rest';
      mgData.waveTimer = 1.5; // 1.5s rest

      platforms.forEach(pl => {
        pl.state = 'safe';
      });
    }

    // 3. Update player movement, jumping & bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      if (sim.jumpCooldown && sim.jumpCooldown > 0) sim.jumpCooldown -= dt;
      if (sim.jumpTimer && sim.jumpTimer > 0) sim.jumpTimer -= dt;
      if (sim.hitTimer && sim.hitTimer > 0) {
        sim.hitTimer -= dt;
        if (sim.hitTimer <= 0) sim.isHit = false;
      }

      const isJumping = (sim.jumpTimer || 0) > 0;

      if (sim.isBot) {
        // Bots seek the nearest safe platform
        const safePlats = platforms.filter(pl => pl.state === 'safe');
        let nearestSafe: LavaPlatform | null = null;
        let nearestDist = 9999;

        safePlats.forEach(pl => {
          const d = distance2D(sim.x, sim.y, pl.x, pl.y);
          if (d < nearestDist) {
            nearestDist = d;
            nearestSafe = pl;
          }
        });

        if (nearestSafe) {
          input = generateBotSteering2D(sim, (nearestSafe as LavaPlatform).x, (nearestSafe as LavaPlatform).y);
          // Jump if approaching gap or danger
          if (nearestDist > 120 && (!sim.jumpCooldown || sim.jumpCooldown <= 0) && Math.random() < 0.08) {
            sim.jumpTimer = 0.38;
            sim.jumpCooldown = 0.8;
          }
        }
      }

      updatePlayerMovement2D(sim, input, dt, DEFAULT_2D_BOUNDS);

      // Check lava burns (only if not jumping)
      if (!isJumping && !sim.isHit && mgData.waveState === 'lava') {
        const currentPlat = platforms.find(
          pl => Math.abs(sim.x - pl.x) <= pl.width / 2 && Math.abs(sim.y - pl.y) <= pl.height / 2
        );

        // If on a lava platform OR in open gap outside platforms
        if (!currentPlat || currentPlat.state === 'lava') {
          sim.isHit = true;
          sim.hitTimer = 0.9;
          sim.score = Math.max(0, (sim.score || 0) - 3);
          mgData.scores[sim.id] = sim.score;

          mgData.events.push({
            type: 'burn',
            x: sim.x,
            y: sim.y,
            text: '-3 🔥 LÁVA ÉGÉS!',
            timestamp: Date.now(),
          });
        }
      }

      // Check ruby collection
      for (let i = rubies.length - 1; i >= 0; i--) {
        const r = rubies[i];
        if (distance2D(sim.x, sim.y, r.x, r.y) <= sim.radius + 24) {
          sim.score = (sim.score || 0) + 3;
          mgData.scores[sim.id] = sim.score;
          rubies.splice(i, 1);

          mgData.events.push({
            type: 'ruby',
            x: sim.x,
            y: sim.y,
            text: '+3 💎 RUBIN!',
            timestamp: Date.now(),
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
