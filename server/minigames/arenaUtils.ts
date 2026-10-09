import { GamepadInputState } from '../../shared/types';

export interface ArenaPlayerSim {
  id: string;
  name: string;
  color: string;
  isBot: boolean;
  x: number;
  y?: number;
  z: number;
  vx: number;
  vy?: number;
  vz: number;
  facing: number;
  speed: number;
  radius: number;
  score: number;
  isHit?: boolean;
  hitTimer?: number;
  isStunned?: boolean;
  stunTimer?: number;
  isJumping?: boolean;
  isDashing?: boolean;
  dashTimer?: number;
  actionA?: boolean;
  actionATimer?: number;
  actionACount?: number;
  actionB?: boolean;
  actionBTimer?: number;
  actionBCount?: number;
  lastInputTimestamp?: number;
  crownTime?: number;
  hasCrown?: boolean;
  cooldownA?: number;
  cooldownB?: number;
  lastInput?: GamepadInputState;
  botTargetTimer?: number;
  botTargetX?: number;
  botTargetZ?: number;
}

export interface ArenaBounds {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  radius?: number; // for circular arena
}

/**
 * Normalizes input vector and updates authoritative position within arena bounds.
 * Prevents diagonal speed-up (dx and dz normalized).
 */
export function updatePlayerMovement(
  player: ArenaPlayerSim,
  input: GamepadInputState | undefined,
  dt: number,
  bounds: ArenaBounds
) {
  if (player.isStunned && player.stunTimer && player.stunTimer > 0) {
    player.stunTimer -= dt;
    player.vx = 0;
    player.vz = 0;
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

  if (player.cooldownA && player.cooldownA > 0) {
    player.cooldownA = Math.max(0, player.cooldownA - dt);
  }
  if (player.cooldownB && player.cooldownB > 0) {
    player.cooldownB = Math.max(0, player.cooldownB - dt);
  }

  if (!input) {
    player.vx = 0;
    player.vz = 0;
    return;
  }

  let dx = 0;
  let dz = 0;
  if (input.left) dx -= 1;
  if (input.right) dx += 1;
  if (input.up) dz -= 1; // forward/up on board
  if (input.down) dz += 1; // backward/down on board

  const len = Math.hypot(dx, dz);
  if (len > 0) {
    // Normalization to prevent diagonal exploit
    dx /= len;
    dz /= len;

    const nextX = player.x + dx * player.speed * dt;
    const nextZ = player.z + dz * player.speed * dt;

    if (bounds.radius !== undefined) {
      // Circular bounds
      const dist = Math.hypot(nextX, nextZ);
      const maxR = bounds.radius - player.radius;
      if (dist <= maxR) {
        player.x = nextX;
        player.z = nextZ;
      } else {
        const factor = maxR / dist;
        player.x = nextX * factor;
        player.z = nextZ * factor;
      }
    } else {
      // Rectangular bounds
      player.x = Math.max(bounds.minX + player.radius, Math.min(bounds.maxX - player.radius, nextX));
      player.z = Math.max(bounds.minZ + player.radius, Math.min(bounds.maxZ - player.radius, nextZ));
    }

    player.facing = Math.atan2(dx, dz);
    player.vx = dx * player.speed;
    player.vz = dz * player.speed;
  } else {
    player.vx = 0;
    player.vz = 0;
  }
}

/**
 * Circle-to-circle collision test
 */
export function checkCircleCollision(
  x1: number,
  z1: number,
  r1: number,
  x2: number,
  z2: number,
  r2: number
): boolean {
  const dx = x1 - x2;
  const dz = z1 - z2;
  const distSq = dx * dx + dz * dz;
  const radSum = r1 + r2;
  return distSq <= radSum * radSum;
}

/**
 * Steers bot towards a target (x, z) or avoids a threat.
 * Returns normalized GamepadInputState so bots use the exact same input mechanism as humans.
 */
export function generateBotSteering(
  bot: ArenaPlayerSim,
  targetX: number,
  targetZ: number,
  avoidX?: number,
  avoidZ?: number,
  avoidRadius: number = 2.0
): GamepadInputState {
  let moveX = targetX - bot.x;
  let moveZ = targetZ - bot.z;

  // Repulsion from threat if present
  if (avoidX !== undefined && avoidZ !== undefined) {
    const dThreatX = bot.x - avoidX;
    const dThreatZ = bot.z - avoidZ;
    const threatDist = Math.hypot(dThreatX, dThreatZ);
    if (threatDist < avoidRadius && threatDist > 0.01) {
      // Repel away from threat with high weight
      const pushFactor = (avoidRadius - threatDist) * 3.5;
      moveX += (dThreatX / threatDist) * pushFactor;
      moveZ += (dThreatZ / threatDist) * pushFactor;
    }
  }

  const threshold = 0.25;
  return {
    left: moveX < -threshold,
    right: moveX > threshold,
    up: moveZ < -threshold,
    down: moveZ > threshold,
    a: false,
    b: false,
  };
}
