import { GamepadInputState } from '../../shared/types';

export interface Minigame2DPlayer {
  id: string;
  name: string;
  color: string;
  isBot: boolean;
  x: number;
  y: number;
  vx: number;
  vy: number;
  facing: number; // in radians: 0 is right, Math.PI/2 is down, etc.
  speed: number;
  radius: number;
  score: number;
  isHit?: boolean;
  hitTimer?: number;
  isStunned?: boolean;
  stunTimer?: number;
  lastInput?: GamepadInputState;
}

export interface Bounds2D {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

export const DEFAULT_2D_BOUNDS: Bounds2D = {
  minX: 120,
  maxX: 1800,
  minY: 140,
  maxY: 940,
};

/**
 * Updates player position using normalized direction vector.
 * Prevents diagonal speed-up (dx, dy normalized to unit length).
 */
export function updatePlayerMovement2D(
  player: Minigame2DPlayer,
  input: GamepadInputState | undefined,
  dt: number,
  bounds: Bounds2D = DEFAULT_2D_BOUNDS
) {
  if (player.stunTimer && player.stunTimer > 0) {
    player.stunTimer -= dt;
    player.vx = 0;
    player.vy = 0;
    if (player.stunTimer <= 0) {
      player.isStunned = false;
    }
    return;
  }

  if (player.hitTimer && player.hitTimer > 0) {
    player.hitTimer -= dt;
    if (player.hitTimer <= 0) {
      player.isHit = false;
    }
  }

  if (!input) {
    player.vx = 0;
    player.vy = 0;
    return;
  }

  let dx = 0;
  let dy = 0;
  if (input.left) dx -= 1;
  if (input.right) dx += 1;
  if (input.up) dy -= 1;
  if (input.down) dy += 1;

  const len = Math.hypot(dx, dy);
  if (len > 0) {
    dx /= len;
    dy /= len;

    player.vx = dx * player.speed;
    player.vy = dy * player.speed;
    player.facing = Math.atan2(dy, dx);

    player.x = Math.max(bounds.minX + player.radius, Math.min(bounds.maxX - player.radius, player.x + player.vx * dt));
    player.y = Math.max(bounds.minY + player.radius, Math.min(bounds.maxY - player.radius, player.y + player.vy * dt));
  } else {
    player.vx = 0;
    player.vy = 0;
  }
}

/**
 * Circular collision detection
 */
export function checkCircleCollision2D(
  x1: number,
  y1: number,
  r1: number,
  x2: number,
  y2: number,
  r2: number
): boolean {
  const dx = x1 - x2;
  const dy = y1 - y2;
  const distSq = dx * dx + dy * dy;
  const radSum = r1 + r2;
  return distSq <= radSum * radSum;
}

/**
 * Distance between two points
 */
export function distance2D(x1: number, y1: number, x2: number, y2: number): number {
  return Math.hypot(x1 - x2, y1 - y2);
}

/**
 * Autonomous steering logic for bot players
 */
export function generateBotSteering2D(
  bot: Minigame2DPlayer,
  targetX: number,
  targetY: number,
  avoidX?: number,
  avoidY?: number,
  avoidRadius: number = 220
): GamepadInputState {
  let moveX = targetX - bot.x;
  let moveY = targetY - bot.y;

  // Repulsion from hazard threat if provided
  if (avoidX !== undefined && avoidY !== undefined) {
    const dThreatX = bot.x - avoidX;
    const dThreatY = bot.y - avoidY;
    const dist = Math.hypot(dThreatX, dThreatY);
    if (dist < avoidRadius && dist > 1) {
      const pushFactor = (avoidRadius - dist) * 4.0;
      moveX += (dThreatX / dist) * pushFactor;
      moveY += (dThreatY / dist) * pushFactor;
    }
  }

  const threshold = 25;
  return {
    left: moveX < -threshold,
    right: moveX > threshold,
    up: moveY < -threshold,
    down: moveY > threshold,
    a: false,
    b: false,
  };
}
