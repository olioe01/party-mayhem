import * as THREE from 'three';
import { Player } from '@shared/types';
import { PartyCharacter3D } from './PartyCharacter3D';
import { sounds } from '../../audio/soundSynth';

export interface CharacterSimState {
  x: number;
  y?: number;
  z: number;
  vx?: number;
  vy?: number;
  vz?: number;
  facing?: number;
  speed?: number;
  isJumping?: boolean;
  isDashing?: boolean;
  isFalling?: boolean;
  isHit?: boolean;
  actionA?: boolean;
  actionB?: boolean;
  actionACount?: number;
  actionBCount?: number;
}

export class ArenaCharacterController {
  public characters: Map<string, PartyCharacter3D> = new Map();
  private lastActionACount: Map<string, number> = new Map();
  private lastActionBCount: Map<string, number> = new Map();

  /**
   * Synchronizes the 3D character meshes with current room players.
   * Spawns new character meshes and cleans up players who left.
   */
  public syncPlayers(players: Record<string, Player>, scene: THREE.Scene) {
    const playerIds = new Set(Object.keys(players));

    // Remove disconnected players
    this.characters.forEach((char, id) => {
      if (!playerIds.has(id)) {
        scene.remove(char.root);
        char.dispose();
        this.characters.delete(id);
        this.lastActionACount.delete(id);
        this.lastActionBCount.delete(id);
      }
    });

    // Add or update existing players
    Object.values(players).forEach(player => {
      let char = this.characters.get(player.id);
      if (!char) {
        char = new PartyCharacter3D(player, false);
        scene.add(char.root);
        this.characters.set(player.id, char);
      } else {
        char.update(player, false);
      }
    });
  }

  /**
   * Authoritative transform, interpolation, animation, and visual effects update.
   * Call once per frame inside requestAnimationFrame.
   */
  public update(
    delta: number,
    elapsedTime: number,
    simPlayers: Record<string, CharacterSimState> | undefined
  ) {
    this.characters.forEach((char, playerId) => {
      const sim = simPlayers?.[playerId];
      if (!sim) return;

      // 1. Position Interpolation (towards authoritative server state)
      const targetX = sim.x ?? 0;
      const targetY = sim.isFalling ? -4.0 : (sim.y ?? 0);
      const targetZ = sim.z ?? 0;

      char.root.position.x = THREE.MathUtils.lerp(char.root.position.x, targetX, 0.4);
      char.root.position.y = THREE.MathUtils.lerp(char.root.position.y, targetY, 0.4);
      char.root.position.z = THREE.MathUtils.lerp(char.root.position.z, targetZ, 0.4);

      // 2. Facing Angle Interpolation (shortest angle difference)
      if (sim.facing !== undefined) {
        let diff = sim.facing - char.root.rotation.y;
        while (diff < -Math.PI) diff += Math.PI * 2;
        while (diff > Math.PI) diff -= Math.PI * 2;
        char.root.rotation.y += diff * 0.35;
      }

      // 3. Audio Triggers on Button Action Events
      const curA = sim.actionACount || 0;
      const prevA = this.lastActionACount.get(playerId) || 0;
      if (curA > prevA) {
        this.lastActionACount.set(playerId, curA);
        sounds.playJump();
      }

      const curB = sim.actionBCount || 0;
      const prevB = this.lastActionBCount.get(playerId) || 0;
      if (curB > prevB) {
        this.lastActionBCount.set(playerId, curB);
        sounds.playDash();
      }

      // 4. Procedural Animation State Dispatch
      const isJumping = (sim.y ?? 0) > 0.05 || Boolean(sim.isJumping);
      const isDashing = Boolean(sim.isDashing || sim.actionB);
      const speed = Math.hypot(sim.vx || 0, sim.vz || 0);

      if (isJumping) {
        char.animate('jump', elapsedTime);
      } else if (isDashing) {
        char.animate('dash', elapsedTime);
      } else if (speed > 0.3) {
        char.animate('walk', elapsedTime * 1.5, (elapsedTime * 4) % 1);
      } else {
        char.animate('idle', elapsedTime);
      }

      // 5. Visual Effects: Spin flare & Squash/Stretch
      if (isDashing) {
        char.root.rotation.y += Math.PI * 6 * delta;
      }

      if (isJumping) {
        char.root.scale.set(0.9, 1.2, 0.9);
      } else if (sim.actionB) {
        char.root.scale.set(1.2, 1.1, 1.2);
      } else if (sim.isHit) {
        char.root.scale.set(0.85, 0.85, 0.85);
      } else {
        char.root.scale.set(1.0, 1.0, 1.0);
      }
    });
  }

  /**
   * Cleanup all allocated Three.js meshes and listeners
   */
  public dispose(scene?: THREE.Scene) {
    this.characters.forEach(char => {
      if (scene) {
        scene.remove(char.root);
      }
      char.dispose();
    });
    this.characters.clear();
    this.lastActionACount.clear();
    this.lastActionBCount.clear();
  }
}
