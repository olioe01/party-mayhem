import * as THREE from 'three';
import { Player, HatId } from '@shared/types';
import { createHatMesh, sharedMaterials } from './threeUtils';

// Soft circular blob shadow shared texture
let cachedShadowTexture: THREE.CanvasTexture | null = null;
function getBlobShadowTexture(): THREE.CanvasTexture {
  if (cachedShadowTexture) return cachedShadowTexture;
  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    const gradient = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
    gradient.addColorStop(0, 'rgba(0, 0, 0, 0.7)');
    gradient.addColorStop(0.5, 'rgba(0, 0, 0, 0.35)');
    gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 128, 128);
  }
  cachedShadowTexture = new THREE.CanvasTexture(canvas);
  return cachedShadowTexture;
}

/**
 * Calculates subtle formation offsets for up to 8 players sharing the same tile space.
 * Prevents overlapping and Z-fighting while keeping all characters on the tile pad.
 */
export function getFormationOffset(index: number, totalOnTile: number): [number, number] {
  if (totalOnTile <= 1) return [0, 0];
  
  if (totalOnTile === 2) {
    return index === 0 ? [-0.30, 0] : [0.30, 0];
  }
  
  if (totalOnTile === 3) {
    const angle = (index / 3) * Math.PI * 2 - Math.PI / 2;
    return [Math.cos(angle) * 0.32, Math.sin(angle) * 0.32];
  }
  
  if (totalOnTile === 4) {
    const angle = (index / 4) * Math.PI * 2 + Math.PI / 4;
    return [Math.cos(angle) * 0.34, Math.sin(angle) * 0.34];
  }
  
  // 5 to 8 players: center first player, distribute rest evenly in a circular perimeter
  if (index === 0) return [0, 0];
  const perimeterCount = totalOnTile - 1;
  const angle = ((index - 1) / perimeterCount) * Math.PI * 2 - Math.PI / 2;
  return [Math.cos(angle) * 0.38, Math.sin(angle) * 0.38];
}

/**
 * Creates high-contrast, crisp billboard nameplate texture
 */
function createNameplateTexture(
  name: string,
  isBot: boolean,
  isActive: boolean,
  connected: boolean,
  playerColor: string
): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 384;
  canvas.height = 96;
  const ctx = canvas.getContext('2d');
  if (!ctx) return new THREE.CanvasTexture(canvas);

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  const x = 12;
  const y = 14;
  const w = canvas.width - 24;
  const h = canvas.height - 28;
  const r = 24;

  // Background pill shadow
  ctx.shadowColor = 'rgba(0, 0, 0, 0.7)';
  ctx.shadowBlur = 10;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 4;

  // Background pill body
  ctx.beginPath();
  if (ctx.roundRect) {
    ctx.roundRect(x, y, w, h, r);
  } else {
    ctx.rect(x, y, w, h);
  }
  ctx.fillStyle = isActive ? 'rgba(15, 23, 42, 0.96)' : 'rgba(15, 23, 42, 0.85)';
  ctx.fill();

  // Reset shadow
  ctx.shadowColor = 'transparent';

  // Border (gold glowing for active player, player-accent for others)
  ctx.lineWidth = isActive ? 5 : 3;
  ctx.strokeStyle = isActive ? '#ffd700' : (playerColor || '#60a5fa');
  ctx.stroke();

  // Draw Text
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = '900 28px "Inter", system-ui, -apple-system, sans-serif';

  let label = name.toUpperCase();
  if (isBot) {
    label = `🤖 ${label}`;
  }
  if (!connected && !isBot) {
    label = `⚠️ ${label}`;
  }
  if (isActive) {
    label = `⭐ ${label}`;
  }

  ctx.fillStyle = isActive ? '#fef08a' : '#ffffff';
  ctx.fillText(label, canvas.width / 2, canvas.height / 2 + 1);

  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}

/**
 * PartyCharacter3D represents a physical, visible 3D player on the game board.
 * Fully unified for both human and bot players.
 */
export class PartyCharacter3D {
  public readonly root: THREE.Group;
  public readonly playerId: string;
  public isBot: boolean;
  public isActive: boolean;
  public connected: boolean;
  public color: string;
  public cosmetic: HatId;
  public currentTileId: number;

  private bodyMesh: THREE.Mesh;
  public name: string;
  private headMesh: THREE.Mesh;
  private footL: THREE.Mesh;
  private footR: THREE.Mesh;
  private handL: THREE.Mesh;
  private handR: THREE.Mesh;
  private hatMount: THREE.Group;
  public activeRing: THREE.Mesh;
  private shadowMesh: THREE.Mesh;
  private nameplateSprite: THREE.Sprite;
  private bodyMaterial: THREE.MeshStandardMaterial;

  constructor(player: Player, isActive: boolean = false) {
    this.playerId = player.id;
    this.name = player.name;
    this.isBot = Boolean(player.isBot);
    this.isActive = isActive;
    this.connected = player.connected !== false;
    this.color = player.color || '#3b82f6';
    this.cosmetic = player.cosmetic || 'none';
    this.currentTileId = player.boardPosition || 0;

    this.root = new THREE.Group();
    this.root.name = `character_${player.id}`;

    const colorHex = new THREE.Color(this.color);

    // 1. Ground Contact Blob Shadow (at y = 0.005)
    const shadowGeo = new THREE.PlaneGeometry(0.85, 0.85);
    shadowGeo.rotateX(-Math.PI / 2);
    const shadowMat = new THREE.MeshBasicMaterial({
      map: getBlobShadowTexture(),
      transparent: true,
      depthWrite: false
    });
    this.shadowMesh = new THREE.Mesh(shadowGeo, shadowMat);
    this.shadowMesh.position.y = 0.005;
    this.root.add(this.shadowMesh);

    // 2. Active Player Floor Aura Ring (at y = 0.01)
    const ringGeo = new THREE.RingGeometry(0.42, 0.54, 28);
    ringGeo.rotateX(-Math.PI / 2);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0xffd700,
      transparent: true,
      opacity: 0.88,
      side: THREE.DoubleSide,
      depthWrite: false
    });
    this.activeRing = new THREE.Mesh(ringGeo, ringMat);
    this.activeRing.position.y = 0.012;
    this.activeRing.visible = this.isActive;
    this.root.add(this.activeRing);

    // 3. Body & Head Materials with slight emissive boost for high readability
    this.bodyMaterial = new THREE.MeshStandardMaterial({
      color: colorHex,
      emissive: colorHex,
      emissiveIntensity: 0.12,
      roughness: 0.35,
      metalness: 0.12
    });

    const footMat = new THREE.MeshStandardMaterial({
      color: colorHex.clone().multiplyScalar(0.75),
      roughness: 0.5,
      metalness: 0.1
    });

    // 4. Feet
    const footGeo = new THREE.SphereGeometry(0.14, 10, 8);
    this.footL = new THREE.Mesh(footGeo, footMat);
    this.footL.position.set(-0.18, 0.10, 0.04);
    this.footL.scale.set(0.9, 0.65, 1.25);
    this.footL.castShadow = true;
    this.root.add(this.footL);

    this.footR = new THREE.Mesh(footGeo, footMat);
    this.footR.position.set(0.18, 0.10, 0.04);
    this.footR.scale.set(0.9, 0.65, 1.25);
    this.footR.castShadow = true;
    this.root.add(this.footR);

    // 5. Torso / Body (y = 0.44)
    const bodyGeo = new THREE.SphereGeometry(0.38, 16, 14);
    this.bodyMesh = new THREE.Mesh(bodyGeo, this.bodyMaterial);
    this.bodyMesh.position.y = 0.44;
    this.bodyMesh.scale.set(1.0, 1.15, 0.95);
    this.bodyMesh.castShadow = true;
    this.root.add(this.bodyMesh);

    // 6. Arms / Hands
    const handGeo = new THREE.SphereGeometry(0.11, 8, 8);
    this.handL = new THREE.Mesh(handGeo, footMat);
    this.handL.position.set(-0.42, 0.44, 0.05);
    this.root.add(this.handL);

    this.handR = new THREE.Mesh(handGeo, footMat);
    this.handR.position.set(0.42, 0.44, 0.05);
    this.root.add(this.handR);

    // 7. Head (y = 0.84)
    const headGeo = new THREE.SphereGeometry(0.35, 18, 14);
    this.headMesh = new THREE.Mesh(headGeo, this.bodyMaterial);
    this.headMesh.position.y = 0.84;
    this.headMesh.castShadow = true;
    this.root.add(this.headMesh);

    // 8. Eyes & Face Features
    const eyeWhiteMat = sharedMaterials.eyeWhite;
    const pupilMat = sharedMaterials.pupilBlack;
    const cheekMat = sharedMaterials.cheekPink;

    const eyeL = new THREE.Mesh(new THREE.SphereGeometry(0.085, 10, 10), eyeWhiteMat);
    eyeL.position.set(-0.11, 0.05, 0.30);
    this.headMesh.add(eyeL);

    const pupilL = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 8), pupilMat);
    pupilL.position.set(-0.11, 0.05, 0.355);
    this.headMesh.add(pupilL);

    const eyeR = new THREE.Mesh(new THREE.SphereGeometry(0.085, 10, 10), eyeWhiteMat);
    eyeR.position.set(0.11, 0.05, 0.30);
    this.headMesh.add(eyeR);

    const pupilR = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 8), pupilMat);
    pupilR.position.set(0.11, 0.05, 0.355);
    this.headMesh.add(pupilR);

    // Rosy Cheeks
    const cheekL = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 8), cheekMat);
    cheekL.position.set(-0.19, -0.06, 0.27);
    cheekL.scale.set(1, 0.7, 0.4);
    this.headMesh.add(cheekL);

    const cheekR = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 8), cheekMat);
    cheekR.position.set(0.19, -0.06, 0.27);
    cheekR.scale.set(1, 0.7, 0.4);
    this.headMesh.add(cheekR);

    // 9. Hat Mount at top of Head
    this.hatMount = new THREE.Group();
    this.hatMount.name = 'hatMount';
    this.hatMount.position.set(0, 0.32, 0);
    this.headMesh.add(this.hatMount);

    if (this.cosmetic && this.cosmetic !== 'none') {
      const hat = createHatMesh(this.cosmetic);
      this.hatMount.add(hat);
    }

    // 10. Billboard Nameplate Sprite (Always camera-facing)
    const nameTex = createNameplateTexture(
      player.name,
      this.isBot,
      this.isActive,
      this.connected,
      this.color
    );
    const spriteMat = new THREE.SpriteMaterial({
      map: nameTex,
      transparent: true,
      depthTest: false,
      depthWrite: false
    });
    this.nameplateSprite = new THREE.Sprite(spriteMat);
    this.nameplateSprite.scale.set(1.5, 0.38, 1.0);
    this.nameplateSprite.position.set(0, 1.62, 0);
    this.root.add(this.nameplateSprite);
  }

  /**
   * Updates state from player sync
   */
  public update(player: Player, isActive: boolean) {
    this.name = player.name;
    let needsNameplateRefresh = false;

    if (this.isActive !== isActive) {
      this.isActive = isActive;
      this.activeRing.visible = isActive;
      needsNameplateRefresh = true;
    }

    const newConnected = player.connected !== false;
    if (this.connected !== newConnected) {
      this.connected = newConnected;
      needsNameplateRefresh = true;
      // Fade slightly if disconnected
      this.bodyMaterial.opacity = this.connected ? 1.0 : 0.55;
      this.bodyMaterial.transparent = !this.connected;
    }

    if (this.cosmetic !== (player.cosmetic || 'none')) {
      this.updateCosmetic(player.cosmetic || 'none');
    }

    if (this.color !== player.color) {
      this.updateColor(player.color);
      needsNameplateRefresh = true;
    }

    this.currentTileId = player.boardPosition;

    if (needsNameplateRefresh) {
      this.refreshNameplate(player.name);
    }
  }

  public setActive(isActive: boolean) {
    if (this.isActive !== isActive) {
      this.isActive = isActive;
      this.activeRing.visible = isActive;
      this.refreshNameplate(this.name);
    }
  }

  public updateCosmetic(cosmetic: HatId) {
    this.cosmetic = cosmetic;
    while (this.hatMount.children.length > 0) {
      this.hatMount.remove(this.hatMount.children[0]);
    }
    if (cosmetic && cosmetic !== 'none') {
      const hat = createHatMesh(cosmetic);
      this.hatMount.add(hat);
    }
  }

  public updateColor(newColor: string) {
    this.color = newColor;
    const col = new THREE.Color(newColor);
    this.bodyMaterial.color.copy(col);
    this.bodyMaterial.emissive.copy(col);
  }

  public refreshNameplate(name: string) {
    const newTex = createNameplateTexture(
      name,
      this.isBot,
      this.isActive,
      this.connected,
      this.color
    );
    if (this.nameplateSprite.material.map) {
      this.nameplateSprite.material.map.dispose();
    }
    this.nameplateSprite.material.map = newTex;
    this.nameplateSprite.material.needsUpdate = true;
  }

  /**
   * Procedural animation updates (run every frame)
   */
  public animate(
    state: 'idle' | 'walk' | 'celebrate' | 'sad' | 'jump' | 'dash',
    time: number,
    walkProgress: number = 0
  ) {
    // 1. Active Ring Pulsing
    if (this.isActive) {
      const pulse = Math.sin(time * 3.8);
      this.activeRing.scale.setScalar(1.0 + pulse * 0.08);
      (this.activeRing.material as THREE.MeshBasicMaterial).opacity = 0.75 + pulse * 0.2;
    }

    // 2. Body States
    if (state === 'idle') {
      const idleBob = Math.sin(time * 3.2 + (this.isBot ? 1.5 : 0)) * 0.035;
      this.bodyMesh.position.y = 0.44 + idleBob;
      this.headMesh.position.y = 0.84 + idleBob * 1.1;

      this.handL.position.y = 0.44 + Math.sin(time * 3.2 + 0.4) * 0.02;
      this.handR.position.y = 0.44 + Math.cos(time * 3.2 + 0.4) * 0.02;
      this.handL.position.z = 0.05;
      this.handR.position.z = 0.05;

      this.footL.position.y = 0.10;
      this.footR.position.y = 0.10;
      this.footL.position.z = 0.04;
      this.footR.position.z = 0.04;
      this.footL.rotation.x = 0;
      this.footR.rotation.x = 0;
    } else if (state === 'walk') {
      const hop = Math.abs(Math.sin(walkProgress * Math.PI)) * 0.35;
      this.bodyMesh.position.y = 0.44 + hop;
      this.headMesh.position.y = 0.84 + hop;

      const footSwing = Math.sin(walkProgress * Math.PI * 2) * 0.35;
      this.footL.position.z = 0.04 + footSwing * 0.16;
      this.footR.position.z = 0.04 - footSwing * 0.16;
      this.footL.position.y = 0.10 + Math.max(0, footSwing * 0.12);
      this.footR.position.y = 0.10 + Math.max(0, -footSwing * 0.12);

      this.handL.position.z = 0.05 - footSwing * 0.18;
      this.handR.position.z = 0.05 + footSwing * 0.18;
    } else if (state === 'jump') {
      // Jump pose: arms reaching up, feet tucked
      this.bodyMesh.position.y = 0.50;
      this.headMesh.position.y = 0.90;
      this.handL.position.y = 0.70;
      this.handR.position.y = 0.70;
      this.footL.position.y = 0.22;
      this.footR.position.y = 0.22;
      this.footL.rotation.x = -0.3;
      this.footR.rotation.x = -0.3;
    } else if (state === 'dash') {
      // Dash pose: aerodynamic tilt forward, hands trailing
      this.bodyMesh.position.y = 0.38;
      this.headMesh.position.y = 0.76;
      this.handL.position.y = 0.35;
      this.handR.position.y = 0.35;
      this.handL.position.z = -0.22;
      this.handR.position.z = -0.22;
      this.footL.position.y = 0.08;
      this.footR.position.y = 0.08;
    } else if (state === 'celebrate') {
      const jump = Math.abs(Math.sin(time * 8.0)) * 0.45;
      this.bodyMesh.position.y = 0.44 + jump;
      this.headMesh.position.y = 0.84 + jump;
      this.headMesh.rotation.y = Math.sin(time * 6.0) * 0.3;

      this.handL.position.y = 0.58 + Math.sin(time * 10) * 0.08;
      this.handR.position.y = 0.58 + Math.cos(time * 10) * 0.08;
    }
  }

  public dispose() {
    if (this.nameplateSprite.material.map) {
      this.nameplateSprite.material.map.dispose();
    }
    this.nameplateSprite.material.dispose();
  }
}
