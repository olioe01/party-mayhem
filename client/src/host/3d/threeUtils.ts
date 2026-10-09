import * as THREE from 'three';
import { BoardTile, HatId } from '@shared/types';
import { BOARD_TILES } from '@shared/boardData';

// Palette for low-poly party theme
export const PALETTE = {
  grass: 0x48bb78,
  grassDark: 0x38a169,
  dirt: 0x8b5a2b,
  rock: 0x718096,
  sand: 0xf6e05e,
  water: 0x319795,
  wood: 0x9c4221,
  gold: 0xf6ad55,
  crownGold: 0xffd700,
  neonCyan: 0x00f5ff,
  neonPink: 0xff007f,
  chaosPurple: 0x805ad5,
  lavaRed: 0xe53e3e,
  tileBlue: 0x3182ce,
  tileRed: 0xe53e3e,
  tileGold: 0xd69e2e,
  tilePurple: 0x9f7aea
};

// Reusable basic materials for high performance
export const sharedMaterials = {
  eyeWhite: new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.2 }),
  pupilBlack: new THREE.MeshStandardMaterial({ color: 0x111111, roughness: 0.1 }),
  cheekPink: new THREE.MeshBasicMaterial({ color: 0xff99bb }),
  goldShiny: new THREE.MeshStandardMaterial({ color: 0xffd700, metalness: 0.7, roughness: 0.3 }),
  topHatBlack: new THREE.MeshStandardMaterial({ color: 0x1a202c, roughness: 0.4 }),
  ribbonRed: new THREE.MeshStandardMaterial({ color: 0xe53e3e, roughness: 0.5 }),
  brownLeather: new THREE.MeshStandardMaterial({ color: 0x7b341e, roughness: 0.7 }),
  strawYellow: new THREE.MeshStandardMaterial({ color: 0xfef08a, roughness: 0.8 }),
  frogGreen: new THREE.MeshStandardMaterial({ color: 0x48bb78, roughness: 0.5 }),
  partyCone: new THREE.MeshStandardMaterial({ color: 0xed64a6, roughness: 0.3 }),
  pomPomYellow: new THREE.MeshStandardMaterial({ color: 0xfaf089, roughness: 0.2 })
};

/**
 * Creates low-poly 3D hats for characters
 */
export function createHatMesh(hatId: HatId): THREE.Group {
  const hat = new THREE.Group();
  hat.name = 'hatMesh';

  switch (hatId) {
    case 'top-hat': {
      // Brim
      const brimGeo = new THREE.CylinderGeometry(0.5, 0.5, 0.05, 16);
      const brim = new THREE.Mesh(brimGeo, sharedMaterials.topHatBlack);
      brim.position.y = 0.025;
      hat.add(brim);

      // Crown cylinder
      const crownGeo = new THREE.CylinderGeometry(0.35, 0.35, 0.5, 16);
      const crown = new THREE.Mesh(crownGeo, sharedMaterials.topHatBlack);
      crown.position.y = 0.28;
      hat.add(crown);

      // Red ribbon band
      const bandGeo = new THREE.CylinderGeometry(0.36, 0.36, 0.08, 16);
      const band = new THREE.Mesh(bandGeo, sharedMaterials.ribbonRed);
      band.position.y = 0.1;
      hat.add(band);
      break;
    }

    case 'cap': {
      // Dome
      const domeGeo = new THREE.SphereGeometry(0.38, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.5);
      const capMat = new THREE.MeshStandardMaterial({ color: 0x3b82f6, roughness: 0.5 });
      const dome = new THREE.Mesh(domeGeo, capMat);
      hat.add(dome);

      // Visor
      const visorGeo = new THREE.BoxGeometry(0.4, 0.04, 0.3);
      const visor = new THREE.Mesh(visorGeo, capMat);
      visor.position.set(0, 0.05, 0.35);
      visor.rotation.x = 0.15;
      hat.add(visor);
      break;
    }

    case 'crown': {
      // Golden base ring
      const baseGeo = new THREE.CylinderGeometry(0.35, 0.38, 0.18, 12, 1, true);
      const base = new THREE.Mesh(baseGeo, sharedMaterials.goldShiny);
      base.position.y = 0.09;
      hat.add(base);

      // Peaks
      for (let i = 0; i < 5; i++) {
        const peakGeo = new THREE.ConeGeometry(0.08, 0.22, 4);
        const peak = new THREE.Mesh(peakGeo, sharedMaterials.goldShiny);
        const angle = (i / 5) * Math.PI * 2;
        peak.position.set(Math.sin(angle) * 0.34, 0.24, Math.cos(angle) * 0.34);
        peak.rotation.y = angle;
        hat.add(peak);

        // Gemstone sphere on peak
        const gemGeo = new THREE.SphereGeometry(0.04, 6, 6);
        const gemMat = new THREE.MeshBasicMaterial({ color: i % 2 === 0 ? 0xff0044 : 0x00f0ff });
        const gem = new THREE.Mesh(gemGeo, gemMat);
        gem.position.set(Math.sin(angle) * 0.34, 0.35, Math.cos(angle) * 0.34);
        hat.add(gem);
      }
      break;
    }

    case 'cowboy': {
      // Wide curved brim
      const brimGeo = new THREE.CylinderGeometry(0.65, 0.65, 0.04, 16);
      const brim = new THREE.Mesh(brimGeo, sharedMaterials.brownLeather);
      brim.position.y = 0.02;
      brim.scale.set(1.1, 1, 0.9);
      hat.add(brim);

      // Pinched top
      const crownGeo = new THREE.CylinderGeometry(0.28, 0.36, 0.38, 12);
      const crown = new THREE.Mesh(crownGeo, sharedMaterials.brownLeather);
      crown.position.y = 0.2;
      crown.scale.set(0.9, 1, 1.1);
      hat.add(crown);
      break;
    }

    case 'grad-cap': {
      // Cap skull base
      const baseGeo = new THREE.CylinderGeometry(0.32, 0.34, 0.12, 12);
      const base = new THREE.Mesh(baseGeo, sharedMaterials.topHatBlack);
      base.position.y = 0.06;
      hat.add(base);

      // Flat mortarboard square
      const boardGeo = new THREE.BoxGeometry(0.75, 0.03, 0.75);
      const board = new THREE.Mesh(boardGeo, sharedMaterials.topHatBlack);
      board.position.y = 0.13;
      board.rotation.y = 0.35;
      hat.add(board);

      // Golden tassel
      const tasselGeo = new THREE.CylinderGeometry(0.015, 0.03, 0.25, 4);
      const tassel = new THREE.Mesh(tasselGeo, sharedMaterials.goldShiny);
      tassel.position.set(0.28, 0.04, 0.2);
      hat.add(tassel);
      break;
    }

    case 'party-hat': {
      // Party cone
      const coneGeo = new THREE.ConeGeometry(0.28, 0.65, 12);
      const cone = new THREE.Mesh(coneGeo, sharedMaterials.partyCone);
      cone.position.y = 0.32;
      hat.add(cone);

      // Top pom-pom
      const pomGeo = new THREE.SphereGeometry(0.08, 8, 8);
      const pom = new THREE.Mesh(pomGeo, sharedMaterials.pomPomYellow);
      pom.position.y = 0.68;
      hat.add(pom);
      break;
    }

    case 'frog-hat': {
      // Green beanie dome
      const domeGeo = new THREE.SphereGeometry(0.4, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.55);
      const dome = new THREE.Mesh(domeGeo, sharedMaterials.frogGreen);
      hat.add(dome);

      // 2 Frog eye bumps on top
      [-0.18, 0.18].forEach(x => {
        const eyeBase = new THREE.Mesh(
          new THREE.SphereGeometry(0.12, 8, 8),
          sharedMaterials.frogGreen
        );
        eyeBase.position.set(x, 0.38, 0.08);
        hat.add(eyeBase);

        const pupil = new THREE.Mesh(
          new THREE.SphereGeometry(0.06, 6, 6),
          sharedMaterials.pupilBlack
        );
        pupil.position.set(x, 0.4, 0.16);
        hat.add(pupil);
      });
      break;
    }

    case 'sun-hat': {
      // Wide circular straw brim
      const brimGeo = new THREE.CylinderGeometry(0.68, 0.68, 0.03, 16);
      const brim = new THREE.Mesh(brimGeo, sharedMaterials.strawYellow);
      brim.position.y = 0.02;
      hat.add(brim);

      // Dome
      const crownGeo = new THREE.SphereGeometry(0.35, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.5);
      const crown = new THREE.Mesh(crownGeo, sharedMaterials.strawYellow);
      crown.position.y = 0.03;
      hat.add(crown);
      break;
    }

    default:
      // 'none' -> empty
      break;
  }

  return hat;
}

/**
 * Creates cute low-poly Party Blob character model
 */
export function createPartyBlobMesh(playerColor: string, cosmetic: HatId = 'none'): THREE.Group {
  const root = new THREE.Group();
  root.name = 'playerRoot';

  const colorHex = new THREE.Color(playerColor);
  const bodyMaterial = new THREE.MeshStandardMaterial({
    color: colorHex,
    roughness: 0.35,
    metalness: 0.1
  });

  // 1. Blob Main Body
  const bodyGeo = new THREE.SphereGeometry(0.55, 16, 14);
  const body = new THREE.Mesh(bodyGeo, bodyMaterial);
  body.name = 'bodyMesh';
  body.position.y = 0.65;
  body.scale.set(1.0, 0.95, 0.95);
  body.castShadow = true;
  root.add(body);

  // 2. Eyes
  const eyeL = new THREE.Mesh(new THREE.SphereGeometry(0.12, 10, 10), sharedMaterials.eyeWhite);
  eyeL.position.set(-0.18, 0.15, 0.44);
  body.add(eyeL);

  const pupilL = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 8), sharedMaterials.pupilBlack);
  pupilL.position.set(-0.18, 0.15, 0.53);
  body.add(pupilL);

  const eyeR = new THREE.Mesh(new THREE.SphereGeometry(0.12, 10, 10), sharedMaterials.eyeWhite);
  eyeR.position.set(0.18, 0.15, 0.44);
  body.add(eyeR);

  const pupilR = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 8), sharedMaterials.pupilBlack);
  pupilR.position.set(0.18, 0.15, 0.53);
  body.add(pupilR);

  // 3. Cute Pink Cheeks
  const cheekL = new THREE.Mesh(new THREE.SphereGeometry(0.07, 8, 8), sharedMaterials.cheekPink);
  cheekL.position.set(-0.3, -0.02, 0.42);
  cheekL.scale.set(1, 0.7, 0.3);
  body.add(cheekL);

  const cheekR = new THREE.Mesh(new THREE.SphereGeometry(0.07, 8, 8), sharedMaterials.cheekPink);
  cheekR.position.set(0.3, -0.02, 0.42);
  cheekR.scale.set(1, 0.7, 0.3);
  body.add(cheekR);

  // 4. Feet (2 little stubby feet)
  const footGeo = new THREE.SphereGeometry(0.16, 8, 8);
  const footMat = new THREE.MeshStandardMaterial({
    color: colorHex.clone().multiplyScalar(0.85),
    roughness: 0.5
  });

  const footL = new THREE.Mesh(footGeo, footMat);
  footL.name = 'footL';
  footL.position.set(-0.25, 0.14, 0.05);
  footL.scale.set(0.9, 0.6, 1.2);
  footL.castShadow = true;
  root.add(footL);

  const footR = new THREE.Mesh(footGeo, footMat);
  footR.name = 'footR';
  footR.position.set(0.25, 0.14, 0.05);
  footR.scale.set(0.9, 0.6, 1.2);
  footR.castShadow = true;
  root.add(footR);

  // 5. Hands (2 stubby little hands)
  const handGeo = new THREE.SphereGeometry(0.12, 8, 8);
  const handL = new THREE.Mesh(handGeo, footMat);
  handL.name = 'handL';
  handL.position.set(-0.54, 0.58, 0.1);
  root.add(handL);

  const handR = new THREE.Mesh(handGeo, footMat);
  handR.name = 'handR';
  handR.position.set(0.54, 0.58, 0.1);
  root.add(handR);

  // 6. Hat Mount attached right above head
  const hatMount = new THREE.Group();
  hatMount.name = 'hatMount';
  hatMount.position.set(0, 0.52, 0);
  body.add(hatMount);

  if (cosmetic && cosmetic !== 'none') {
    const hatMesh = createHatMesh(cosmetic);
    hatMount.add(hatMesh);
  }

  return root;
}

/**
 * Updates an existing blob's hat
 */
export function updateBlobHat(blobRoot: THREE.Group, cosmetic: HatId) {
  const hatMount = blobRoot.getObjectByName('hatMount');
  if (hatMount) {
    while (hatMount.children.length > 0) {
      hatMount.remove(hatMount.children[0]);
    }
    const newHat = createHatMesh(cosmetic);
    hatMount.add(newHat);
  }
}

/**
 * Procedural animation for Party Blob
 */
export function animatePartyBlob(
  blobRoot: THREE.Group,
  state: 'idle' | 'walk' | 'celebrate' | 'sad',
  time: number,
  walkProgress: number = 0
) {
  const body = blobRoot.getObjectByName('bodyMesh');
  const footL = blobRoot.getObjectByName('footL');
  const footR = blobRoot.getObjectByName('footR');
  const handL = blobRoot.getObjectByName('handL');
  const handR = blobRoot.getObjectByName('handR');

  if (!body) return;

  if (state === 'idle') {
    // Gentle floating bob
    const bob = Math.sin(time * 3.5) * 0.05;
    body.position.y = 0.65 + bob;
    body.scale.set(1.0 + bob * 0.3, 0.95 - bob * 0.4, 0.95 + bob * 0.3);

    if (handL && handR) {
      handL.position.y = 0.58 + Math.sin(time * 3.5 + 0.5) * 0.03;
      handR.position.y = 0.58 + Math.cos(time * 3.5 + 0.5) * 0.03;
    }
    if (footL && footR) {
      footL.position.y = 0.14;
      footR.position.y = 0.14;
      footL.rotation.x = 0;
      footR.rotation.x = 0;
    }
  } else if (state === 'walk') {
    // Hopping arc with foot stepping
    const hop = Math.abs(Math.sin(walkProgress * Math.PI)) * 0.45;
    body.position.y = 0.65 + hop;
    body.rotation.z = Math.sin(walkProgress * Math.PI * 2) * 0.1;

    const footSwing = Math.sin(walkProgress * Math.PI * 2) * 0.4;
    if (footL && footR) {
      footL.position.z = footSwing * 0.18;
      footR.position.z = -footSwing * 0.18;
      footL.position.y = 0.14 + Math.max(0, footSwing * 0.1);
      footR.position.y = 0.14 + Math.max(0, -footSwing * 0.1);
    }
    if (handL && handR) {
      handL.position.z = -footSwing * 0.2;
      handR.position.z = footSwing * 0.2;
    }
  } else if (state === 'celebrate') {
    // High celebratory bounce
    const jump = Math.abs(Math.sin(time * 8)) * 0.6;
    body.position.y = 0.65 + jump;
    body.rotation.y = time * 4;

    if (handL && handR) {
      handL.position.y = 0.85 + Math.sin(time * 12) * 0.1;
      handR.position.y = 0.85 + Math.cos(time * 12) * 0.1;
    }
  } else if (state === 'sad') {
    body.position.y = 0.52;
    body.scale.set(1.08, 0.8, 1.08);
    if (handL && handR) {
      handL.position.y = 0.4;
      handR.position.y = 0.4;
    }
  }
}

// Cached tile icon textures for high performance (zero duplicate canvas generation)
const tileIconTextureCache = new Map<string, THREE.CanvasTexture>();

export function getTileIconTexture(tile: BoardTile): THREE.CanvasTexture {
  const key = tile.id === 0 ? 'START' : tile.type;
  const cached = tileIconTextureCache.get(key);
  if (cached) return cached;

  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext('2d')!;

  ctx.clearRect(0, 0, 128, 128);

  const drawText = (text: string, size: number, color: string, yOffset = 0, stroke = '#000000', strokeW = 4) => {
    ctx.font = `900 ${size}px system-ui, -apple-system, sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.lineWidth = strokeW;
    ctx.strokeStyle = stroke;
    ctx.strokeText(text, 64, 64 + yOffset);
    ctx.fillStyle = color;
    ctx.fillText(text, 64, 64 + yOffset);
  };

  const drawCircle = (x: number, y: number, r: number, fill: string, stroke?: string, strokeW = 3) => {
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = fill;
    ctx.fill();
    if (stroke) {
      ctx.lineWidth = strokeW;
      ctx.strokeStyle = stroke;
      ctx.stroke();
    }
  };

  if (tile.id === 0) {
    // START Tile
    drawCircle(64, 64, 52, '#f59e0b', '#ffffff', 4);
    drawText('GO!', 38, '#ffffff', 0, '#78350f', 6);
  } else {
    switch (tile.type) {
      case 'BLUE': {
        // +3 Coin
        drawCircle(64, 64, 52, '#f59e0b', '#fef08a', 4);
        drawCircle(64, 64, 42, '#d97706');
        drawText('+3', 44, '#ffffff', 2, '#78350f', 6);
        break;
      }
      case 'GOLD': {
        // +8 Gold Coin
        drawCircle(64, 64, 52, '#eab308', '#fef9c3', 5);
        drawCircle(64, 64, 42, '#ca8a04');
        drawText('+8', 44, '#ffffff', 2, '#713f12', 6);
        break;
      }
      case 'RED': {
        // -3 Hazard Coin
        drawCircle(64, 64, 52, '#dc2626', '#fca5a5', 4);
        drawCircle(64, 64, 42, '#991b1b');
        drawText('-3', 44, '#ffffff', 2, '#450a0a', 6);
        break;
      }
      case 'DUEL': {
        // Crossed Swords ⚔️
        drawCircle(64, 64, 52, '#7c3aed', '#c4b5fd', 4);
        ctx.save();
        ctx.translate(64, 64);
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 6;
        ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(-28, -28); ctx.lineTo(28, 28); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(28, -28); ctx.lineTo(-28, 28); ctx.stroke();
        ctx.restore();
        drawText('VS', 32, '#fbbf24', 0, '#4c1d95', 5);
        break;
      }
      case 'STEAL': {
        // Coin Bag / Steal
        drawCircle(64, 64, 52, '#059669', '#6ee7b7', 4);
        ctx.fillStyle = '#fbbf24';
        ctx.beginPath();
        ctx.arc(64, 72, 28, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(64, 42, 12, 0, Math.PI * 2);
        ctx.fill();
        drawText('$', 38, '#15803d', 10, '#ffffff', 4);
        break;
      }
      case 'SWAP': {
        // Curved Swap Arrows 🔄
        drawCircle(64, 64, 52, '#0284c7', '#7dd3fc', 4);
        ctx.save();
        ctx.translate(64, 64);
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 7;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.arc(0, 0, 26, -Math.PI * 0.8, -Math.PI * 0.1);
        ctx.stroke();
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.moveTo(26, -5); ctx.lineTo(33, -15); ctx.lineTo(19, -15); ctx.fill();
        ctx.beginPath();
        ctx.arc(0, 0, 26, Math.PI * 0.2, Math.PI * 0.9);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(-26, 5); ctx.lineTo(-33, 15); ctx.lineTo(-19, 15); ctx.fill();
        ctx.restore();
        break;
      }
      case 'CHAOS': {
        // Purple Spiral / Swirl 🌀
        drawCircle(64, 64, 52, '#7e22ce', '#e9d5ff', 4);
        ctx.save();
        ctx.translate(64, 64);
        ctx.strokeStyle = '#f43f5e';
        ctx.lineWidth = 5;
        ctx.lineCap = 'round';
        for (let i = 0; i < 4; i++) {
          ctx.rotate(Math.PI / 2);
          ctx.beginPath();
          ctx.moveTo(0, 0);
          ctx.quadraticCurveTo(15, -15, 30, -5);
          ctx.stroke();
        }
        ctx.restore();
        drawCircle(64, 64, 12, '#ffffff');
        break;
      }
      case 'SECRET': {
        drawCircle(64, 64, 52, '#4338ca', '#a5b4fc', 4);
        drawText('?', 58, '#fbbf24', 2, '#1e1b4b', 6);
        break;
      }
      case 'BOOST': {
        // Lightning Bolt ⚡
        drawCircle(64, 64, 52, '#0d9488', '#99f6e4', 4);
        ctx.fillStyle = '#facc15';
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(68, 24);
        ctx.lineTo(44, 64);
        ctx.lineTo(62, 64);
        ctx.lineTo(58, 104);
        ctx.lineTo(84, 56);
        ctx.lineTo(66, 56);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        break;
      }
      case 'TRAP': {
        // Hazard Exclamation ⚠️
        drawCircle(64, 64, 52, '#c2410c', '#fdba74', 4);
        drawText('!', 62, '#ffffff', 0, '#7c2d12', 7);
        break;
      }
      case 'TELEPORT': {
        drawCircle(64, 64, 52, '#6d28d9', '#ddd6fe', 4);
        drawCircle(64, 64, 38, 'transparent', '#a78bfa', 4);
        drawCircle(64, 64, 24, 'transparent', '#ffffff', 4);
        drawCircle(64, 64, 10, '#c084fc');
        break;
      }
      case 'JACKPOT': {
        drawCircle(64, 64, 52, '#ca8a04', '#fef08a', 4);
        drawText('777', 36, '#ffffff', 2, '#854d0e', 6);
        break;
      }
      default: {
        drawCircle(64, 64, 52, '#3b82f6', '#bfdbfe', 4);
        drawText('★', 46, '#ffffff', 2, '#1d4ed8', 5);
        break;
      }
    }
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  tileIconTextureCache.set(key, texture);
  return texture;
}

/**
 * Creates 3D tile pad mesh
 */
export function createTilePad(tile: BoardTile, isCrownShop: boolean): THREE.Group {
  const pad = new THREE.Group();
  pad.name = `tile_${tile.id}`;
  const [tx, ty, tz] = tile.position3D || [0, 0, 0];
  pad.position.set(tx, ty, tz);

  let tileColor = PALETTE.tileBlue;
  if (tile.type === 'GOLD') tileColor = PALETTE.tileGold;
  if (tile.type === 'RED') tileColor = PALETTE.tileRed;
  if (tile.type === 'CHAOS') tileColor = PALETTE.tilePurple;
  if (tile.type === 'JACKPOT') tileColor = 0xffe066;
  if (tile.type === 'TELEPORT') tileColor = 0x9f7aea;
  if (tile.type === 'STEAL') tileColor = 0x38a169;
  if (tile.type === 'DUEL') tileColor = 0x805ad5;
  if (tile.type === 'BOOST') tileColor = 0x319795;
  if (tile.type === 'TRAP') tileColor = 0xc05621;
  if (tile.type === 'SWAP') tileColor = 0x00b4d8;

  // Base cylinder
  const baseGeo = new THREE.CylinderGeometry(0.7, 0.78, 0.25, 8);
  const baseMat = new THREE.MeshStandardMaterial({
    color: 0x1a202c,
    roughness: 0.6
  });
  const baseMesh = new THREE.Mesh(baseGeo, baseMat);
  baseMesh.receiveShadow = true;
  pad.add(baseMesh);

  // Colored top ring / disc
  const topGeo = new THREE.CylinderGeometry(0.62, 0.62, 0.08, 8);
  const topMat = new THREE.MeshStandardMaterial({
    color: tileColor,
    roughness: 0.3,
    metalness: 0.1
  });
  const topMesh = new THREE.Mesh(topGeo, topMat);
  topMesh.name = 'tileTop';
  topMesh.position.y = 0.14;
  topMesh.receiveShadow = true;
  pad.add(topMesh);

  // Clear, high-contrast readable icon decal plane directly on top
  const iconTexture = getTileIconTexture(tile);
  const iconGeo = new THREE.PlaneGeometry(0.88, 0.88);
  const iconMat = new THREE.MeshBasicMaterial({
    map: iconTexture,
    transparent: true,
    depthWrite: false
  });
  const iconMesh = new THREE.Mesh(iconGeo, iconMat);
  iconMesh.name = 'tileIcon';
  iconMesh.position.y = 0.185;
  iconMesh.rotation.x = -Math.PI / 2;
  pad.add(iconMesh);

  // If Start tile, golden trim
  if (tile.id === 0) {
    const starGeo = new THREE.CylinderGeometry(0.65, 0.65, 0.02, 5);
    const starMesh = new THREE.Mesh(starGeo, sharedMaterials.goldShiny);
    starMesh.position.y = 0.19;
    pad.add(starMesh);
  }

  // If Crown Shop: floating rotating 3D Crown above it!
  if (isCrownShop) {
    const shopGroup = new THREE.Group();
    shopGroup.name = 'crownShopMarker';
    shopGroup.position.y = 1.3;

    const floatingCrown = createHatMesh('crown');
    floatingCrown.scale.set(1.8, 1.8, 1.8);
    // Solid golden plinth disc (no wireframe, smooth non-flashing finish)
    const pedestalGeo = new THREE.CylinderGeometry(0.72, 0.78, 0.08, 14);
    const pedestalMat = new THREE.MeshStandardMaterial({
      color: 0xffd700,
      metalness: 0.65,
      roughness: 0.25
    });
    const pedestal = new THREE.Mesh(pedestalGeo, pedestalMat);
    pedestal.position.y = -0.5;
    shopGroup.add(pedestal);

    pad.add(shopGroup);
  }

  return pad;
}

/**
 * Safe Zone Checker: Ensures scenery props never obstruct the board path tiles
 */
export function isNearPath(x: number, z: number, minRadius: number = 2.1): boolean {
  for (const t of BOARD_TILES) {
    if (t.position3D) {
      const dx = x - t.position3D[0];
      const dz = z - t.position3D[2];
      if (Math.hypot(dx, dz) < minRadius) return true;
    }
  }
  return false;
}

// All 36 board route connections with shortcuts and branches
export const BOARD_CONNECTIONS: { from: number; to: number; isShortcut?: boolean }[] = [
  // Start stretch
  { from: 0, to: 1 },
  { from: 1, to: 2 },
  { from: 2, to: 3 },
  { from: 3, to: 4 },
  { from: 4, to: 5 },
  { from: 5, to: 6 },
  { from: 6, to: 7 },
  { from: 7, to: 8 },
  // Fork 1 (Tile 8)
  { from: 8, to: 9, isShortcut: true },
  { from: 8, to: 13 },
  // Shortcut 1
  { from: 9, to: 10, isShortcut: true },
  { from: 10, to: 11, isShortcut: true },
  { from: 11, to: 12, isShortcut: true },
  { from: 12, to: 18, isShortcut: true },
  // Safe Lake & Boardwalk loop 1
  { from: 13, to: 14 },
  { from: 14, to: 15 },
  { from: 15, to: 16 },
  { from: 16, to: 17 },
  { from: 17, to: 18 },
  // Upper stretch
  { from: 18, to: 19 },
  { from: 19, to: 20 },
  { from: 20, to: 21 },
  { from: 21, to: 22 },
  { from: 22, to: 23 },
  // Fork 2 (Tile 23)
  { from: 23, to: 24, isShortcut: true },
  { from: 23, to: 27 },
  // Secret Shortcut 2
  { from: 24, to: 25, isShortcut: true },
  { from: 25, to: 26, isShortcut: true },
  { from: 26, to: 32, isShortcut: true },
  // Outer Scenic Loop 2
  { from: 27, to: 28 },
  { from: 28, to: 29 },
  { from: 29, to: 30 },
  { from: 30, to: 31 },
  { from: 31, to: 32 },
  // Final stretch back to Start
  { from: 32, to: 33 },
  { from: 33, to: 34 },
  { from: 34, to: 35 },
  { from: 35, to: 0 }
];

// Directional arrow textures (cached for high performance)
const routeArrowCache = new Map<boolean, THREE.CanvasTexture>();

export function getRouteArrowTexture(isShortcut: boolean = false): THREE.CanvasTexture {
  const cached = routeArrowCache.get(isShortcut);
  if (cached) return cached;

  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext('2d')!;
  ctx.clearRect(0, 0, 128, 128);

  const mainColor = isShortcut ? '#f59e0b' : '#38bdf8';
  const glowColor = isShortcut ? 'rgba(245, 158, 11, 0.45)' : 'rgba(56, 189, 248, 0.45)';

  ctx.shadowColor = glowColor;
  ctx.shadowBlur = 10;

  // Dual stylized forward chevrons pointing up in 2D (-Z in 3D)
  const drawChevron = (y: number, s: number) => {
    ctx.beginPath();
    ctx.moveTo(64, y - 28 * s);
    ctx.lineTo(64 + 36 * s, y + 14 * s);
    ctx.lineTo(64 + 24 * s, y + 26 * s);
    ctx.lineTo(64, y);
    ctx.lineTo(64 - 24 * s, y + 26 * s);
    ctx.lineTo(64 - 36 * s, y + 14 * s);
    ctx.closePath();
    ctx.fillStyle = mainColor;
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 4 * s;
    ctx.stroke();
  };

  drawChevron(72, 1.0);
  drawChevron(40, 0.75);

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  routeArrowCache.set(isShortcut, texture);
  return texture;
}

function createForkSignpost(labelTop: string, labelBottom: string): THREE.Group {
  const sign = new THREE.Group();
  const stoneMat = new THREE.MeshStandardMaterial({ color: 0x64748b, roughness: 0.85, flatShading: true });
  const woodMat = new THREE.MeshStandardMaterial({ color: 0x854d0e, roughness: 0.75, flatShading: true });
  const goldMat = new THREE.MeshStandardMaterial({ color: 0xf59e0b, roughness: 0.3 });

  // Stone plinth pillar
  const pillar = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.9, 0.24), stoneMat);
  pillar.position.y = 0.45;
  pillar.castShadow = true;
  sign.add(pillar);

  // Upper sign arm
  const arm1 = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.2, 0.08), woodMat);
  arm1.position.set(0.25, 0.75, 0.04);
  arm1.rotation.z = -0.05;
  sign.add(arm1);

  // Directional chevron indicator
  const chev1 = new THREE.Mesh(new THREE.ConeGeometry(0.08, 0.16, 4), goldMat);
  chev1.position.set(0.55, 0.75, 0.1);
  chev1.rotation.z = -Math.PI / 2;
  sign.add(chev1);

  // Lower sign arm
  const arm2 = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.2, 0.08), woodMat);
  arm2.position.set(-0.25, 0.52, -0.04);
  arm2.rotation.z = 0.05;
  sign.add(arm2);

  const chev2 = new THREE.Mesh(new THREE.ConeGeometry(0.08, 0.16, 4), goldMat);
  chev2.position.set(-0.55, 0.52, 0.1);
  chev2.rotation.z = Math.PI / 2;
  sign.add(chev2);

  return sign;
}

export function createBoardPathAndArrows(parent: THREE.Group) {
  const pathGroup = new THREE.Group();
  pathGroup.name = 'boardPathSystem';

  const regularArrowTex = getRouteArrowTexture(false);
  const shortcutArrowTex = getRouteArrowTexture(true);

  const arrowMatRegular = new THREE.MeshBasicMaterial({
    map: regularArrowTex,
    transparent: true,
    depthWrite: false
  });
  const arrowMatShortcut = new THREE.MeshBasicMaterial({
    map: shortcutArrowTex,
    transparent: true,
    depthWrite: false
  });

  const trackMatRegular = new THREE.MeshStandardMaterial({
    color: 0x94a3b8,
    roughness: 0.75,
    flatShading: true
  });
  const trackMatShortcut = new THREE.MeshStandardMaterial({
    color: 0x475569,
    roughness: 0.8,
    flatShading: true
  });

  BOARD_CONNECTIONS.forEach(({ from, to, isShortcut }) => {
    const fromTile = BOARD_TILES.find(t => t.id === from);
    const toTile = BOARD_TILES.find(t => t.id === to);
    if (!fromTile?.position3D || !toTile?.position3D) return;

    const [fx, fy, fz] = fromTile.position3D;
    const [tx, ty, tz] = toTile.position3D;

    const dx = tx - fx;
    const dy = ty - fy;
    const dz = tz - fz;
    const len = Math.hypot(dx, dz);
    if (len < 0.1) return;

    const mx = (fx + tx) * 0.5;
    const my = (fy + ty) * 0.5;
    const mz = (fz + tz) * 0.5;
    const dist3D = Math.hypot(dx, dy, dz);

    // Skip connecting track over boardwalk (tiles 13 to 17 have wooden bridge decks)
    if (!(from >= 13 && to <= 18 && !isShortcut)) {
      // 1. Carved stone connector track ribbon aligned with 3D slope
      const trackGeo = new THREE.BoxGeometry(0.44, 0.05, dist3D);
      const trackMesh = new THREE.Mesh(trackGeo, isShortcut ? trackMatShortcut : trackMatRegular);
      trackMesh.position.set(mx, my - 0.04, mz);
      trackMesh.lookAt(tx, ty - 0.04, tz);
      trackMesh.receiveShadow = true;
      pathGroup.add(trackMesh);
    }

    // 2. Crisp Directional Arrow Decal in middle of segment
    const arrowGeo = new THREE.PlaneGeometry(0.55, 0.55);
    const arrowMesh = new THREE.Mesh(arrowGeo, isShortcut ? arrowMatShortcut : arrowMatRegular);
    arrowMesh.position.set(mx, my + 0.03, mz);
    // Orient arrow plane flat and pointing from 'from' to 'to'
    const angle = Math.atan2(dx, -dz);
    arrowMesh.rotation.set(-Math.PI * 0.5, 0, -angle);
    pathGroup.add(arrowMesh);
  });

  // Fork Stone Signposts at Tile 8 and Tile 23
  const sign8 = createForkSignpost('SHORTCUT ➡️', 'LAKE ⬆️');
  sign8.position.set(11.8, 0.5, 1.8);
  sign8.rotation.y = -0.5;
  pathGroup.add(sign8);

  const sign23 = createForkSignpost('SECRET ⬇️', 'OUTER LOOP ⬅️');
  sign23.position.set(-6.5, 0.85, -7.6);
  sign23.rotation.y = 0.6;
  pathGroup.add(sign23);

  parent.add(pathGroup);
}

/**
 * Builds the Stepped Stone Ruins Courtyard Platform (Console party game quality - Whomp's Ruins theme)
 */
export function createIslandTerrain(): THREE.Group {
  const island = new THREE.Group();
  island.name = 'islandTerrain';

  // 1. Layered Rock Cliff Island Base (Natural warm low-poly basalt/granite)
  const cliffBaseGeo = new THREE.CylinderGeometry(15.8, 12.0, 7.5, 16, 2);
  const cliffMat = new THREE.MeshStandardMaterial({
    color: 0x3e352f,
    roughness: 0.88,
    flatShading: true
  });
  const cliffBase = new THREE.Mesh(cliffBaseGeo, cliffMat);
  cliffBase.position.y = -4.0;
  cliffBase.receiveShadow = true;
  island.add(cliffBase);

  // Perimeter rock outcroppings to break circular symmetry
  const outcroppingMat = new THREE.MeshStandardMaterial({
    color: 0x332a24,
    roughness: 0.9,
    flatShading: true
  });
  [
    [-11.5, -3.5, 4.5, 1.4, 0.4],
    [10.5, -3.8, -4.5, 1.6, -0.6],
    [-7.5, -4.0, -9.0, 1.3, 0.9],
    [8.0, -3.6, 7.5, 1.5, -0.3]
  ].forEach(([ox, oy, oz, s, rot]) => {
    const outGeo = new THREE.DodecahedronGeometry(3.5 * s, 0);
    const outMesh = new THREE.Mesh(outGeo, outcroppingMat);
    outMesh.position.set(ox, oy, oz);
    outMesh.rotation.set(0.3, rot, 0.2);
    outMesh.scale.set(1.1, 0.8, 1.2);
    outMesh.receiveShadow = true;
    island.add(outMesh);
  });

  // 2. Stepped Ancient Temple Terraces (Layered Architectural Platform)
  const stoneMatPlaza = new THREE.MeshStandardMaterial({
    color: 0x64748b,
    roughness: 0.78,
    flatShading: true
  });
  const stoneMatUpper = new THREE.MeshStandardMaterial({
    color: 0x788492,
    roughness: 0.75,
    flatShading: true
  });
  const curbMat = new THREE.MeshStandardMaterial({
    color: 0x334155,
    roughness: 0.85,
    flatShading: true
  });
  const mossMat = new THREE.MeshStandardMaterial({
    color: 0x166534,
    roughness: 0.7,
    flatShading: true
  });

  // Base Top Foundation Disc
  const baseTopGeo = new THREE.CylinderGeometry(15.2, 15.5, 0.6, 18);
  const baseTopMat = new THREE.MeshStandardMaterial({
    color: PALETTE.grass,
    roughness: 0.68,
    flatShading: true
  });
  const baseTop = new THREE.Mesh(baseTopGeo, baseTopMat);
  baseTop.position.y = 0.0;
  baseTop.receiveShadow = true;
  island.add(baseTop);

  // Terrace 1: South Lower Courtyard (Start area & Finish straight / Tiles 0-7, 32-35)
  const plazaSouthGeo = new THREE.BoxGeometry(16.5, 0.45, 8.5);
  const plazaSouth = new THREE.Mesh(plazaSouthGeo, stoneMatPlaza);
  plazaSouth.position.set(0, 0.2, 5.2);
  plazaSouth.receiveShadow = true;
  island.add(plazaSouth);

  // Terrace 2: East Terrace (Tiles 8-12 shortcut & lake approach)
  const plazaEastGeo = new THREE.BoxGeometry(7.2, 0.65, 8.5);
  const plazaEast = new THREE.Mesh(plazaEastGeo, stoneMatPlaza);
  plazaEast.position.set(9.5, 0.28, -2.5);
  plazaEast.receiveShadow = true;
  island.add(plazaEast);

  // Terrace 3: North Elevated Dais (Crown Temple Sanctuary / Tiles 18-22)
  const plazaNorthGeo = new THREE.BoxGeometry(14.0, 0.95, 5.8);
  const plazaNorth = new THREE.Mesh(plazaNorthGeo, stoneMatUpper);
  plazaNorth.position.set(1.5, 0.45, -6.8);
  plazaNorth.receiveShadow = true;
  island.add(plazaNorth);

  // Grand Stone Steps leading up to North Dais
  [
    { w: 3.2, h: 0.22, d: 0.9, y: 0.32, z: -3.6 },
    { w: 2.8, h: 0.22, d: 0.8, y: 0.52, z: -4.3 }
  ].forEach(st => {
    const step = new THREE.Mesh(new THREE.BoxGeometry(st.w, st.h, st.d), curbMat);
    step.position.set(1.5, st.y, st.z);
    step.receiveShadow = true;
    island.add(step);
  });

  // Terrace 4: West Terrace (Ancient Ruins & Fork / Tiles 23-31)
  const plazaWestGeo = new THREE.BoxGeometry(7.2, 0.65, 8.5);
  const plazaWest = new THREE.Mesh(plazaWestGeo, stoneMatPlaza);
  plazaWest.position.set(-8.5, 0.30, -2.0);
  plazaWest.receiveShadow = true;
  island.add(plazaWest);

  // Architectural Carved Stone Retaining Curbs along Terrace Edges
  [
    { pos: [0, 0.44, 9.4], size: [16.8, 0.12, 0.35] },
    { pos: [1.5, 0.94, -3.8], size: [14.2, 0.14, 0.35] },
    { pos: [5.8, 0.62, -2.5], size: [0.35, 0.14, 8.6] },
    { pos: [-4.8, 0.62, -2.0], size: [0.35, 0.14, 8.6] }
  ].forEach(({ pos, size }) => {
    const curb = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]), curbMat);
    curb.position.set(pos[0], pos[1], pos[2]);
    curb.receiveShadow = true;
    island.add(curb);
  });

  // Low Moss Beds along courtyard corners (Flat, zero camera obstruction)
  [
    { pos: [-3.5, 0.44, 4.0], r: 1.6 },
    { pos: [3.5, 0.44, 4.0], r: 1.5 },
    { pos: [-1.5, 0.44, 1.8], r: 1.8 },
    { pos: [2.0, 0.44, 1.8], r: 1.7 },
    { pos: [-3.8, 0.44, -4.5], r: 1.2 },
    { pos: [7.8, 0.62, -5.2], r: 1.5 }
  ].forEach(({ pos, r }) => {
    const moss = new THREE.Mesh(new THREE.CylinderGeometry(r, r * 1.1, 0.04, 7), mossMat);
    moss.position.set(pos[0], pos[1], pos[2]);
    moss.receiveShadow = true;
    island.add(moss);
  });

  // 3. Flagstone Paver Bases beneath the 36 board tiles
  const trailMat = new THREE.MeshStandardMaterial({
    color: 0x475569,
    roughness: 0.85,
    flatShading: true
  });
  const stepGeo = new THREE.CylinderGeometry(0.85, 0.92, 0.08, 8);

  BOARD_TILES.forEach((tile, idx) => {
    if (tile.position3D) {
      const [tx, ty, tz] = tile.position3D;
      if (idx >= 13 && idx <= 17) return; // Handled by wooden boardwalk

      // If tile is elevated above base courtyard, add stone pedestal supporting it
      if (ty > 0.45) {
        const plinthHeight = ty - 0.22;
        const plinthGeo = new THREE.CylinderGeometry(0.74, 0.82, plinthHeight, 8);
        const plinth = new THREE.Mesh(plinthGeo, trailMat);
        plinth.position.set(tx, 0.22 + plinthHeight * 0.5, tz);
        plinth.receiveShadow = true;
        island.add(plinth);
      }

      const step = new THREE.Mesh(stepGeo, trailMat);
      step.position.set(tx, ty - 0.06, tz);
      step.rotation.y = (idx * 0.4) % Math.PI;
      step.receiveShadow = true;
      island.add(step);
    }
  });

  // 4. Integrated Connecting Paths, Glowing Route Arrows & Fork Signposts!
  createBoardPathAndArrows(island);

  // 5. Wooden Boardwalk for Water Crossing (Tiles 13 - 17)
  const woodPlankMat = new THREE.MeshStandardMaterial({
    color: 0x8b5a2b,
    roughness: 0.75,
    flatShading: true
  });
  const ropePostMat = new THREE.MeshStandardMaterial({
    color: 0x5c3a1e,
    roughness: 0.8
  });

  const boardwalkTiles = BOARD_TILES.slice(13, 18);
  boardwalkTiles.forEach((tile, i) => {
    if (!tile.position3D) return;
    const [bx, by, bz] = tile.position3D;

    // Bridge deck
    const deckGeo = new THREE.BoxGeometry(1.9, 0.12, 1.6);
    const deck = new THREE.Mesh(deckGeo, woodPlankMat);
    deck.position.set(bx, by - 0.05, bz);
    deck.rotation.y = -0.35 + i * 0.15;
    deck.receiveShadow = true;
    island.add(deck);

    // Pilings
    [-0.8, 0.8].forEach(sideX => {
      const piling = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.09, 1.6, 6), ropePostMat);
      piling.position.set(bx + sideX * 0.8, by - 0.7, bz);
      island.add(piling);

      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.5, 6), ropePostMat);
      post.position.set(bx + sideX * 0.8, by + 0.25, bz);
      island.add(post);
    });
  });

  // ==========================================
  // PERIMETER BIOMES & LANDMARKS
  // (Zero trees inside courtyard! All props placed strictly on outer rim or backdrop)
  // ==========================================

  // BIOME 1: BEACH (Far South Rim / z: 9.0 to 12.0)
  const beachSandGeo = new THREE.CylinderGeometry(7.2, 7.8, 0.35, 14);
  const beachSandMat = new THREE.MeshStandardMaterial({
    color: PALETTE.sand,
    roughness: 0.85,
    flatShading: true
  });
  const beachSand = new THREE.Mesh(beachSandGeo, beachSandMat);
  beachSand.position.set(0.2, 0.14, 9.2);
  beachSand.scale.set(1.4, 1, 0.7);
  beachSand.receiveShadow = true;
  island.add(beachSand);

  // Palm Trees strictly on outer beach cliff rim (z > 10.0, never in gameplay corridor)
  const palmMat = new THREE.MeshStandardMaterial({ color: 0x16a34a, roughness: 0.55, flatShading: true });
  const palmTrunkMat = new THREE.MeshStandardMaterial({ color: 0x78563a, roughness: 0.8, flatShading: true });
  const coconutMat = new THREE.MeshStandardMaterial({ color: 0x452a13, roughness: 0.7 });

  [
    { pos: [-5.5, 10.8], lean: -0.22, height: 3.2 },
    { pos: [5.2, 10.6], lean: 0.20, height: 3.0 },
    { pos: [0.0, 11.4], lean: 0.12, height: 3.3 }
  ].forEach(({ pos: [px, pz], lean, height }) => {
    const palmGroup = new THREE.Group();
    palmGroup.position.set(px, 0.25, pz);

    const segments = 4;
    for (let s = 0; s < segments; s++) {
      const segLen = height / segments;
      const seg = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.20, segLen, 6), palmTrunkMat);
      seg.position.set(s * lean * 0.5, s * (segLen * 0.85) + segLen * 0.5, s * 0.08);
      seg.rotation.z = lean * (s * 0.35 + 0.2);
      seg.castShadow = true;
      palmGroup.add(seg);
    }

    const crownY = height * 0.88;
    const topX = (segments - 1) * lean * 0.5;
    for (let f = 0; f < 6; f++) {
      const frond = new THREE.Mesh(new THREE.ConeGeometry(0.48, 1.8, 4), palmMat);
      const angle = (f / 6) * Math.PI * 2;
      frond.position.set(topX + Math.sin(angle) * 0.8, crownY, Math.cos(angle) * 0.8);
      frond.rotation.set(0.7 * Math.cos(angle), angle, -0.7 * Math.sin(angle));
      frond.castShadow = true;
      palmGroup.add(frond);
    }

    for (let c = 0; c < 3; c++) {
      const coco = new THREE.Mesh(new THREE.SphereGeometry(0.12, 6, 6), coconutMat);
      const ca = (c / 3) * Math.PI * 2;
      coco.position.set(topX + Math.sin(ca) * 0.22, crownY - 0.12, Math.cos(ca) * 0.22);
      palmGroup.add(coco);
    }

    island.add(palmGroup);
  });

  // Coastal Details on sand
  const shellMat = new THREE.MeshStandardMaterial({ color: 0xffedd5, roughness: 0.3 });
  const starfishMat = new THREE.MeshStandardMaterial({ color: 0xf97316, roughness: 0.5 });
  [
    [-2.2, 9.8, 'shell'],
    [2.2, 9.6, 'starfish'],
    [-3.8, 10.2, 'starfish'],
    [3.5, 9.9, 'shell']
  ].forEach(([sx, sz, type]) => {
    if (type === 'starfish') {
      const sf = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.22, 0.04, 5), starfishMat);
      sf.position.set(Number(sx), 0.34, Number(sz));
      sf.rotation.y = Math.random() * Math.PI;
      island.add(sf);
    } else {
      const sh = new THREE.Mesh(new THREE.DodecahedronGeometry(0.15, 0), shellMat);
      sh.position.set(Number(sx), 0.34, Number(sz));
      sh.scale.set(1.2, 0.5, 1.0);
      island.add(sh);
    }
  });

  // BIOME 2: CROWN TEMPLE & SANCTUARY (North Elevated Terrace / Tile 18)
  const marbleMat = new THREE.MeshStandardMaterial({
    color: 0xf8fafc,
    roughness: 0.25,
    metalness: 0.05
  });
  const goldCapMat = new THREE.MeshStandardMaterial({ color: PALETTE.crownGold, metalness: 0.6, roughness: 0.3 });

  const templePlinth = new THREE.Mesh(new THREE.BoxGeometry(4.8, 0.6, 4.8), marbleMat);
  templePlinth.position.set(5.0, 1.15, -7.0);
  templePlinth.receiveShadow = true;
  island.add(templePlinth);

  // 4 Fluted Marble Columns
  const colGeo = new THREE.CylinderGeometry(0.22, 0.25, 2.6, 10);
  const capGeo = new THREE.CylinderGeometry(0.32, 0.26, 0.18, 10);
  [
    [-1.7, -1.7],
    [1.7, -1.7],
    [-1.7, 1.7],
    [1.7, 1.7]
  ].forEach(([cx, cz]) => {
    const colGroup = new THREE.Group();
    colGroup.position.set(5.0 + cx, 2.5, -7.0 + cz);

    const pillar = new THREE.Mesh(colGeo, marbleMat);
    pillar.castShadow = true;
    colGroup.add(pillar);

    const capTop = new THREE.Mesh(capGeo, goldCapMat);
    capTop.position.y = 1.35;
    colGroup.add(capTop);

    const capBottom = new THREE.Mesh(capGeo, goldCapMat);
    capBottom.position.y = -1.25;
    colGroup.add(capBottom);

    island.add(colGroup);
  });

  // Classical Shrine Roof
  const roofGeo = new THREE.ConeGeometry(3.6, 1.6, 4);
  roofGeo.rotateY(Math.PI * 0.25);
  const roofMat = new THREE.MeshStandardMaterial({
    color: PALETTE.crownGold,
    metalness: 0.5,
    roughness: 0.35
  });
  const roof = new THREE.Mesh(roofGeo, roofMat);
  roof.position.set(5.0, 4.3, -7.0);
  roof.castShadow = true;
  island.add(roof);

  const spireMesh = new THREE.Mesh(new THREE.OctahedronGeometry(0.35, 0), goldCapMat);
  spireMesh.position.set(5.0, 5.3, -7.0);
  island.add(spireMesh);

  // Royal Swallowtail Banners
  const bannerPoleGeo = new THREE.CylinderGeometry(0.04, 0.05, 2.5, 6);
  const bannerClothMat = new THREE.MeshStandardMaterial({ color: 0x7e22ce, roughness: 0.45, side: THREE.DoubleSide });
  [3.0, 7.0].forEach(bx => {
    const bannerGroup = new THREE.Group();
    bannerGroup.position.set(bx, 2.1, -5.0);

    const pole = new THREE.Mesh(bannerPoleGeo, goldCapMat);
    bannerGroup.add(pole);

    const flag = new THREE.Mesh(new THREE.PlaneGeometry(0.55, 1.1), bannerClothMat);
    flag.position.set(0.28, 0.55, 0);
    bannerGroup.add(flag);

    island.add(bannerGroup);
  });

  // Tall Pine Trees strictly behind the North Temple wall (z < -11.0)
  const trunkMat = new THREE.MeshStandardMaterial({ color: 0x5c3a21, roughness: 0.85, flatShading: true });
  const pineFoliageMat = new THREE.MeshStandardMaterial({ color: 0x15803d, roughness: 0.6, flatShading: true });
  [
    [-3.5, -11.5, 1.3],
    [1.5, -11.8, 1.4],
    [7.5, -11.5, 1.2]
  ].forEach(([tx, tz, scale]) => {
    const pine = new THREE.Group();
    pine.position.set(tx, 0.5, tz);

    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.18 * scale, 0.26 * scale, 1.3 * scale, 6), trunkMat);
    trunk.position.y = 0.65 * scale;
    trunk.castShadow = true;
    pine.add(trunk);

    [
      { r: 1.3, h: 1.6, y: 1.8 },
      { r: 1.0, h: 1.4, y: 2.7 },
      { r: 0.65, h: 1.1, y: 3.5 }
    ].forEach(tier => {
      const foliage = new THREE.Mesh(new THREE.ConeGeometry(tier.r * scale, tier.h * scale, 7), pineFoliageMat);
      foliage.position.y = tier.y * scale;
      foliage.castShadow = true;
      pine.add(foliage);
    });
    island.add(pine);
  });

  // BIOME 3: ANCIENT RUINS ARCHWAY (Far West Cliff / x: -11.8, z: 3.8)
  const ruinsArch = new THREE.Group();
  ruinsArch.position.set(-11.8, 0.4, 3.8);
  ruinsArch.rotation.y = 0.4;

  const ruinsStoneMat = new THREE.MeshStandardMaterial({ color: 0x64748b, roughness: 0.85, flatShading: true });
  const ruinsIvyMat = new THREE.MeshStandardMaterial({ color: 0x15803d, roughness: 0.6, flatShading: true });

  const archPillarGeo = new THREE.CylinderGeometry(0.3, 0.36, 2.5, 6);
  const archCol1 = new THREE.Mesh(archPillarGeo, ruinsStoneMat);
  archCol1.position.set(-1.1, 1.25, 0);
  archCol1.castShadow = true;
  ruinsArch.add(archCol1);

  const archCol2 = new THREE.Mesh(archPillarGeo, ruinsStoneMat);
  archCol2.position.set(1.1, 1.25, 0);
  archCol2.castShadow = true;
  ruinsArch.add(archCol2);

  const archBeam = new THREE.Mesh(new THREE.BoxGeometry(2.8, 0.4, 0.55), ruinsStoneMat);
  archBeam.position.set(0, 2.55, 0);
  archBeam.rotation.z = -0.04;
  archBeam.castShadow = true;
  ruinsArch.add(archBeam);

  const archIvy = new THREE.Mesh(new THREE.DodecahedronGeometry(0.32, 0), ruinsIvyMat);
  archIvy.position.set(-0.9, 2.2, 0.25);
  ruinsArch.add(archIvy);
  island.add(ruinsArch);

  // BIOME 4: ELDER OAK (Far Northwest Cliff Corner / x: -12.4, z: -6.5)
  const elderOak = new THREE.Group();
  elderOak.position.set(-12.4, 0.45, -6.5);
  const oakTrunk = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.85, 2.8, 7), trunkMat);
  oakTrunk.position.y = 1.4;
  oakTrunk.castShadow = true;
  elderOak.add(oakTrunk);

  const oakCanopyGeo = new THREE.DodecahedronGeometry(2.0, 1);
  const oakFoliageMat = new THREE.MeshStandardMaterial({ color: 0x22c55e, roughness: 0.65, flatShading: true });
  const oakCanopy1 = new THREE.Mesh(oakCanopyGeo, oakFoliageMat);
  oakCanopy1.position.set(0, 3.5, 0);
  oakCanopy1.castShadow = true;
  elderOak.add(oakCanopy1);

  const oakCanopy2 = new THREE.Mesh(new THREE.DodecahedronGeometry(1.4, 1), oakFoliageMat);
  oakCanopy2.position.set(0.8, 4.2, -0.4);
  oakCanopy2.castShadow = true;
  elderOak.add(oakCanopy2);
  island.add(elderOak);

  // BIOME 5: VOLCANIC SPIRES & FLOATING CRYSTALS (Far East Cliff Rim / x: 13.0, z: -2.5)
  const volcanicMat = new THREE.MeshStandardMaterial({ color: 0x1e1b4b, roughness: 0.65, flatShading: true });
  const crystalMat = new THREE.MeshStandardMaterial({
    color: 0xc084fc,
    emissive: 0x9333ea,
    emissiveIntensity: 0.6,
    roughness: 0.2,
    metalness: 0.1
  });
  const cyanCrystalMat = new THREE.MeshStandardMaterial({
    color: 0x38bdf8,
    emissive: 0x0284c7,
    emissiveIntensity: 0.6,
    roughness: 0.2
  });

  const cragGeo = new THREE.DodecahedronGeometry(1.5, 0);
  const crag1 = new THREE.Mesh(cragGeo, volcanicMat);
  crag1.position.set(13.0, 1.0, -1.2);
  crag1.scale.set(0.9, 1.4, 0.9);
  crag1.castShadow = true;
  island.add(crag1);

  const crag2 = new THREE.Mesh(cragGeo, volcanicMat);
  crag2.position.set(13.4, 1.2, -3.8);
  crag2.scale.set(1.0, 1.5, 1.0);
  crag2.castShadow = true;
  island.add(crag2);

  const octGeo = new THREE.OctahedronGeometry(0.7, 0);
  [
    { pos: [12.8, 2.4, -1.6], mat: crystalMat, s: 0.75 },
    { pos: [13.2, 2.0, -0.6], mat: cyanCrystalMat, s: 0.65 },
    { pos: [13.4, 2.2, -3.2], mat: crystalMat, s: 0.8 },
    { pos: [12.5, 1.8, 0.6], mat: cyanCrystalMat, s: 0.7 }
  ].forEach(({ pos: [cx, cy, cz], mat, s }) => {
    const cMesh = new THREE.Mesh(octGeo, mat);
    cMesh.position.set(cx, cy, cz);
    cMesh.rotation.set(0.4, 0.8, 0.3);
    cMesh.scale.set(s, s * 1.3, s);
    cMesh.name = 'chaosCrystal';
    island.add(cMesh);
  });

  // Ancient Runic Monolith on Far East Cliff
  const monolithGeo = new THREE.BoxGeometry(0.65, 2.2, 0.65);
  const monolith = new THREE.Mesh(monolithGeo, volcanicMat);
  monolith.position.set(12.5, 1.2, 1.2);
  monolith.rotation.set(0.08, 0.4, -0.05);
  monolith.castShadow = true;
  island.add(monolith);

  // Instanced Perimeter Decorations (Pebbles, Low Grass, Wildflowers - all strictly along perimeter cliffs)
  const instancedDecorations: THREE.InstancedMesh[] = [];
  const dummy = new THREE.Object3D();

  // Boulders (35 instances on perimeter cliffs)
  const pebbleGeo = new THREE.DodecahedronGeometry(0.38, 0);
  const pebbleMat = new THREE.MeshStandardMaterial({ color: PALETTE.rock, roughness: 0.85, flatShading: true });
  const maxPebbles = 35;
  const pebbleInstanced = new THREE.InstancedMesh(pebbleGeo, pebbleMat, maxPebbles);
  pebbleInstanced.name = 'instancedPebbles';
  pebbleInstanced.receiveShadow = true;

  let pebbleIdx = 0;
  for (let i = 0; i < maxPebbles * 4 && pebbleIdx < maxPebbles; i++) {
    const angle = Math.random() * Math.PI * 2;
    const rad = 11.5 + Math.random() * 3.5;
    const px = Math.cos(angle) * rad;
    const pz = Math.sin(angle) * rad;
    if (isNearPath(px, pz, 1.4)) continue;

    const s = 0.45 + Math.random() * 0.75;
    dummy.position.set(px, 0.35, pz);
    dummy.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
    dummy.scale.set(s, s * 0.65, s);
    dummy.updateMatrix();
    pebbleInstanced.setMatrixAt(pebbleIdx, dummy.matrix);
    pebbleIdx++;
  }
  pebbleInstanced.count = pebbleIdx;
  pebbleInstanced.instanceMatrix.needsUpdate = true;
  island.add(pebbleInstanced);
  instancedDecorations.push(pebbleInstanced);

  // Grass Tufts (40 instances on perimeter cliffs)
  const grassClumpGeo = new THREE.ConeGeometry(0.20, 0.45, 4);
  const clumpMat = new THREE.MeshStandardMaterial({ color: PALETTE.grassDark, roughness: 0.7, flatShading: true });
  const maxGrass = 40;
  const grassInstanced = new THREE.InstancedMesh(grassClumpGeo, clumpMat, maxGrass);
  grassInstanced.name = 'instancedGrass';

  let grassIdx = 0;
  for (let i = 0; i < maxGrass * 4 && grassIdx < maxGrass; i++) {
    const angle = Math.random() * Math.PI * 2;
    const rad = 11.0 + Math.random() * 3.8;
    const gx = Math.cos(angle) * rad;
    const gz = Math.sin(angle) * rad;
    if (isNearPath(gx, gz, 1.4)) continue;

    dummy.position.set(gx, 0.42, gz);
    dummy.rotation.set(0, Math.random() * Math.PI, 0);
    dummy.scale.set(0.9 + Math.random() * 0.5, 0.8 + Math.random() * 0.6, 0.9 + Math.random() * 0.5);
    dummy.updateMatrix();
    grassInstanced.setMatrixAt(grassIdx, dummy.matrix);
    grassIdx++;
  }
  grassInstanced.count = grassIdx;
  grassInstanced.instanceMatrix.needsUpdate = true;
  island.add(grassInstanced);
  instancedDecorations.push(grassInstanced);

  // Wildflowers (25 instances)
  const flowerGeo = new THREE.DodecahedronGeometry(0.14, 0);
  const flowerMat = new THREE.MeshBasicMaterial({ color: 0xfbbf24 });
  const maxFlowers = 25;
  const flowerInstanced = new THREE.InstancedMesh(flowerGeo, flowerMat, maxFlowers);
  flowerInstanced.name = 'instancedFlowers';

  let flowerIdx = 0;
  for (let i = 0; i < maxFlowers * 4 && flowerIdx < maxFlowers; i++) {
    const angle = Math.random() * Math.PI * 2;
    const rad = 11.2 + Math.random() * 3.5;
    const fx = Math.cos(angle) * rad;
    const fz = Math.sin(angle) * rad;
    if (isNearPath(fx, fz, 1.4)) continue;

    dummy.position.set(fx, 0.4, fz);
    dummy.rotation.set(0, Math.random() * Math.PI, 0);
    dummy.scale.set(1, 1, 1);
    dummy.updateMatrix();
    flowerInstanced.setMatrixAt(flowerIdx, dummy.matrix);
    flowerIdx++;
  }
  flowerInstanced.count = flowerIdx;
  flowerInstanced.instanceMatrix.needsUpdate = true;
  island.add(flowerInstanced);
  instancedDecorations.push(flowerInstanced);

  island.userData.instancedDecorations = instancedDecorations;
  island.userData.maxCounts = instancedDecorations.map(m => m.count);

  // Stylized Low-Poly Animated Turquoise Ocean (Calm, non-intersecting at y: -0.6)
  const waterGeo = new THREE.PlaneGeometry(80, 80, 24, 24);
  waterGeo.rotateX(-Math.PI * 0.5);
  const waterMat = new THREE.MeshStandardMaterial({
    color: 0x0ea5e9,
    roughness: 0.12,
    metalness: 0.18,
    transparent: true,
    opacity: 0.82
  });
  const water = new THREE.Mesh(waterGeo, waterMat);
  water.name = 'waterPlane';
  water.position.y = -0.6;
  island.add(water);

  return island;
}

/**
 * Dynamically scales scenery decoration count based on quality tier (100% -> 70% -> 35%)
 */
export function setIslandDecorationQuality(island: THREE.Group, quality: 'LOW' | 'MEDIUM' | 'HIGH') {
  const decorations = island.userData.instancedDecorations as THREE.InstancedMesh[] | undefined;
  const maxCounts = island.userData.maxCounts as number[] | undefined;
  if (!decorations || !maxCounts) return;

  const ratio = quality === 'LOW' ? 0.35 : quality === 'MEDIUM' ? 0.7 : 1.0;
  decorations.forEach((mesh, idx) => {
    const max = maxCounts[idx] || mesh.instanceMatrix.count;
    mesh.count = Math.floor(max * ratio);
    mesh.instanceMatrix.needsUpdate = true;
  });
}

/**
 * High-Definition Procedural Dice Canvas Texture Generator (256x256)
 */
function createDiceFaceCanvas(value: number): HTMLCanvasElement {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 256;
  const ctx = canvas.getContext('2d')!;

  // Smooth rounded background
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, 256, 256);

  // Subtle inner shading for dice depth / rounded edge illusion
  const grad = ctx.createRadialGradient(128, 128, 60, 128, 128, 130);
  grad.addColorStop(0, '#ffffff');
  grad.addColorStop(0.85, '#f8fafc');
  grad.addColorStop(1, '#cbd5e1');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 256, 256);

  // Elegant border bevel
  ctx.strokeStyle = '#94a3b8';
  ctx.lineWidth = 14;
  ctx.strokeRect(8, 8, 240, 240);

  // Pips styling
  const isOne = value === 1;
  const pipColor = isOne ? '#dc2626' : '#0f172a';

  const drawPip = (x: number, y: number, r = 24) => {
    // Drop shadow under pip
    ctx.beginPath();
    ctx.arc(x, y + 2, r, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.15)';
    ctx.fill();

    // Main pip body
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = pipColor;
    ctx.fill();

    // Subtle specular highlight on pip
    ctx.beginPath();
    ctx.arc(x - r * 0.3, y - r * 0.3, r * 0.32, 0, Math.PI * 2);
    ctx.fillStyle = isOne ? 'rgba(255,200,200,0.65)' : 'rgba(255,255,255,0.45)';
    ctx.fill();
  };

  const c = 128;
  const l = 68;
  const r = 188;
  const t = 68;
  const b = 188;

  switch (value) {
    case 1:
      drawPip(c, c, 38); // Extra large signature party-die red pip
      break;
    case 2:
      drawPip(l, t);
      drawPip(r, b);
      break;
    case 3:
      drawPip(l, t);
      drawPip(c, c);
      drawPip(r, b);
      break;
    case 4:
      drawPip(l, t);
      drawPip(r, t);
      drawPip(l, b);
      drawPip(r, b);
      break;
    case 5:
      drawPip(l, t);
      drawPip(r, t);
      drawPip(c, c);
      drawPip(l, b);
      drawPip(r, b);
      break;
    case 6:
      drawPip(l, t);
      drawPip(r, t);
      drawPip(l, c);
      drawPip(r, c);
      drawPip(l, b);
      drawPip(r, b);
      break;
  }

  return canvas;
}

/**
 * Creates a prominently sized 3D Die mesh with high-contrast faces and glowing shadow disc
 */
export function createDiceMesh(): THREE.Group {
  const diceGroup = new THREE.Group();
  diceGroup.name = 'dice3D';

  const faceValues = [1, 6, 2, 5, 3, 4];
  const materials = faceValues.map(val => {
    const canvas = createDiceFaceCanvas(val);
    const texture = new THREE.CanvasTexture(canvas);
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
    return new THREE.MeshStandardMaterial({
      map: texture,
      roughness: 0.18,
      metalness: 0.08
    });
  });

  // Compact 1.2 x 1.2 x 1.2 geometry - clear, readable, never dominates screen or covers players
  const geo = new THREE.BoxGeometry(1.2, 1.2, 1.2);
  const cubeMesh = new THREE.Mesh(geo, materials);
  cubeMesh.name = 'diceCube';
  cubeMesh.castShadow = true;
  diceGroup.add(cubeMesh);

  // Glowing Projection Disc / Pedestal Aura under the die
  const auraGeo = new THREE.RingGeometry(0.8, 1.3, 20);
  auraGeo.rotateX(-Math.PI * 0.5);
  const auraMat = new THREE.MeshBasicMaterial({
    color: 0xf59e0b,
    transparent: true,
    opacity: 0.6,
    side: THREE.DoubleSide
  });
  const auraMesh = new THREE.Mesh(auraGeo, auraMat);
  auraMesh.name = 'diceAura';
  auraMesh.position.y = -1.0;
  diceGroup.add(auraMesh);

  // Outer golden sparkle ring
  const ringGeo = new THREE.TorusGeometry(1.25, 0.03, 6, 20);
  ringGeo.rotateX(Math.PI * 0.5);
  const ringMat = new THREE.MeshBasicMaterial({ color: 0xffd700 });
  const ringMesh = new THREE.Mesh(ringGeo, ringMat);
  ringMesh.position.y = -1.0;
  diceGroup.add(ringMesh);

  return diceGroup;
}

/**
 * Calculates the exact Euler rotation so the rolled value directly faces the camera!
 * (Overhead camera is angled down towards the active board position)
 */
export function getDiceTargetEuler(roll: number): THREE.Euler {
  const tiltTowardsCam = 0.38; // Tilt face directly towards perspective camera
  switch (roll) {
    case 2: // Face +Y is UP
      return new THREE.Euler(tiltTowardsCam, 0, 0);
    case 5: // Face -Y is DOWN -> flip upside down
      return new THREE.Euler(Math.PI + tiltTowardsCam, 0, 0);
    case 1: // Face +X -> rotate +X to top
      return new THREE.Euler(tiltTowardsCam, 0, Math.PI / 2);
    case 6: // Face -X -> rotate -X to top
      return new THREE.Euler(tiltTowardsCam, 0, -Math.PI / 2);
    case 3: // Face +Z is FRONT -> tilt back
      return new THREE.Euler(-Math.PI / 2 + tiltTowardsCam, 0, 0);
    case 4: // Face -Z is BACK -> tilt forward
      return new THREE.Euler(Math.PI / 2 + tiltTowardsCam, 0, 0);
    default:
      return new THREE.Euler(0, 0, 0);
  }
}
