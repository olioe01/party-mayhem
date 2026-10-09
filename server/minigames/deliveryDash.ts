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

export interface DeliveryPackage {
  id: number;
  x: number;
  y: number;
  isHeld: boolean;
  heldBy?: string;
}

export interface DeliveryZone {
  id: number;
  name: string;
  emoji: string;
  x: number;
  y: number;
  radius: number;
  color: string;
}

const DELIVERY_ZONES: DeliveryZone[] = [
  { id: 1, name: 'Pizza Shop', emoji: '🍕', x: 960, y: 220, radius: 95, color: '#f97316' },
  { id: 2, name: 'Game Store', emoji: '🎮', x: 1620, y: 560, radius: 95, color: '#8b5cf6' },
  { id: 3, name: 'Coffee Cafe', emoji: '☕', x: 960, y: 900, radius: 95, color: '#eab308' },
  { id: 4, name: 'Florist', emoji: '🌸', x: 300, y: 560, radius: 95, color: '#ec4899' },
];

export const deliveryDashMinigame: MinigameDefinition = {
  id: 'delivery-dash',
  name: 'DELIVERY DASH',
  description: 'Vedd fel a csomagokat a raktárból, és szállítsd le a rendelőkhöz!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS • [A] = TURBÓ LÖKÉS! Kapj fel egy csomagot és vidd a jelzett zónába!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: 'TURBÓ',
    bLabel: '—',
    aHidden: false,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS • [A] = TURBÓ LÖKÉS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, Minigame2DPlayer & { carryingPackage?: boolean; dashCooldown?: number; dashTimer?: number }> = {};
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
        y: 560 + Math.sin(angle) * dist,
        vx: 0,
        vy: 0,
        facing: 0,
        speed: 520,
        radius: 34,
        score: 0,
        isHit: false,
        hitTimer: 0,
        carryingPackage: false,
        dashCooldown: 0,
        dashTimer: 0,
      };
      scores[p.id] = 0;
    });

    // Initial packages in depot (center)
    const packages: DeliveryPackage[] = [
      { id: 1, x: 920, y: 530, isHeld: false },
      { id: 2, x: 1000, y: 530, isHeld: false },
      { id: 3, x: 960, y: 590, isHeld: false },
    ];

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      packages,
      nextPackageId: 4,
      targetZoneIndex: 0, // Starts at Pizza Shop
      zoneChangeTimer: 10,
      deliveryEvents: [] as { playerId: string; zoneName: string; points: number; x: number; y: number; timestamp: number }[],
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

      // Turbo Dash trigger on [A] press
      if (nextA && !prevA && (!sim.dashCooldown || sim.dashCooldown <= 0)) {
        sim.dashTimer = 0.28;
        sim.dashCooldown = 1.4;
      }
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const simPlayers = mgData.players as Record<string, Minigame2DPlayer & { carryingPackage?: boolean; dashCooldown?: number; dashTimer?: number }>;
    const packages = mgData.packages as DeliveryPackage[];
    const activeZone = DELIVERY_ZONES[mgData.targetZoneIndex % DELIVERY_ZONES.length];

    // 1. Update player movements and bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      // Dash timers
      if (sim.dashCooldown && sim.dashCooldown > 0) sim.dashCooldown -= dt;
      if (sim.dashTimer && sim.dashTimer > 0) {
        sim.dashTimer -= dt;
        sim.speed = 880; // High speed burst
      } else {
        // Normal or package burdened speed
        sim.speed = sim.carryingPackage ? 460 : 540;
      }

      if (sim.isBot) {
        if (!sim.carryingPackage) {
          // Find closest available unheld package
          let nearestPkg: DeliveryPackage | null = null;
          let nearestDist = 9999;
          packages.forEach(pkg => {
            if (!pkg.isHeld) {
              const d = distance2D(sim.x, sim.y, pkg.x, pkg.y);
              if (d < nearestDist) {
                nearestDist = d;
                nearestPkg = pkg;
              }
            }
          });

          if (nearestPkg) {
            input = generateBotSteering2D(sim, (nearestPkg as DeliveryPackage).x, (nearestPkg as DeliveryPackage).y);
          } else {
            // Wait near depot center
            input = generateBotSteering2D(sim, 960, 560);
          }
        } else {
          // Carry package to target zone
          input = generateBotSteering2D(sim, activeZone.x, activeZone.y);
          // Dash occasionally towards zone
          if ((!sim.dashCooldown || sim.dashCooldown <= 0) && Math.random() < 0.05) {
            sim.dashTimer = 0.28;
            sim.dashCooldown = 1.6;
          }
        }
      }

      updatePlayerMovement2D(sim, input, dt, DEFAULT_2D_BOUNDS);

      // 2. Package pickup collision
      if (!sim.carryingPackage) {
        for (const pkg of packages) {
          if (!pkg.isHeld && distance2D(sim.x, sim.y, pkg.x, pkg.y) <= sim.radius + 20) {
            pkg.isHeld = true;
            pkg.heldBy = sim.id;
            sim.carryingPackage = true;
            break;
          }
        }
      } else {
        // Move held package along with player
        const heldPkg = packages.find(p => p.heldBy === sim.id);
        if (heldPkg) {
          heldPkg.x = sim.x;
          heldPkg.y = sim.y - 32;
        }

        // 3. Delivery drop-off collision
        if (distance2D(sim.x, sim.y, activeZone.x, activeZone.y) <= activeZone.radius) {
          // Delivered successfully!
          sim.carryingPackage = false;
          sim.score = (sim.score || 0) + 1;
          mgData.scores[sim.id] = sim.score;

          // Remove the delivered package from arena
          const pIndex = packages.findIndex(p => p.heldBy === sim.id);
          if (pIndex !== -1) {
            packages.splice(pIndex, 1);
          }

          // Record delivery event
          mgData.deliveryEvents.push({
            playerId: sim.id,
            zoneName: activeZone.name,
            points: 1,
            x: activeZone.x,
            y: activeZone.y,
            timestamp: Date.now(),
          });

          // Switch to a new delivery zone
          let nextIdx = (mgData.targetZoneIndex + 1 + Math.floor(Math.random() * 2)) % DELIVERY_ZONES.length;
          if (nextIdx === mgData.targetZoneIndex) nextIdx = (nextIdx + 1) % DELIVERY_ZONES.length;
          mgData.targetZoneIndex = nextIdx;
          mgData.zoneChangeTimer = 12;
        }
      }
    });

    // 4. Ensure depot always has packages available
    const unheldCount = packages.filter(p => !p.isHeld).length;
    if (unheldCount < 2) {
      const offsetX = (Math.random() - 0.5) * 120;
      const offsetY = (Math.random() - 0.5) * 80;
      packages.push({
        id: mgData.nextPackageId++,
        x: 960 + offsetX,
        y: 560 + offsetY,
        isHeld: false,
      });
    }

    // Prune old delivery events
    const now = Date.now();
    mgData.deliveryEvents = (mgData.deliveryEvents || []).filter((e: any) => now - e.timestamp < 1500);

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0} csomag kézbesítve`,
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
