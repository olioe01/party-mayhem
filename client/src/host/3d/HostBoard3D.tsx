import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { RoomState, TileType } from '@shared/types';
import { BOARD_TILES } from '@shared/boardData';
import {
  createIslandTerrain,
  createTilePad,
  createDiceMesh,
  getDiceTargetEuler,
  setIslandDecorationQuality,
  PALETTE
} from './threeUtils';
import { PartyCharacter3D, getFormationOffset } from './PartyCharacter3D';
import { Player } from '@shared/types';

interface HostBoard3DProps {
  room: RoomState;
  quality?: 'LOW' | 'MEDIUM' | 'HIGH' | 'AUTO';
  onQualityChange?: (quality: 'LOW' | 'MEDIUM' | 'HIGH' | 'AUTO') => void;
}

export const HostBoard3D: React.FC<HostBoard3DProps> = ({
  room,
  quality = 'AUTO',
  onQualityChange
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const animFrameIdRef = useRef<number | null>(null);

  // Scene object instances
  const islandMeshRef = useRef<THREE.Group | null>(null);
  const diceMeshRef = useRef<THREE.Group | null>(null);
  const charactersMapRef = useRef<Map<string, PartyCharacter3D>>(new Map());
  const tileMeshesRef = useRef<Map<number, THREE.Group>>(new Map());

  // Camera targets for smooth lerping
  const targetCamPosRef = useRef<THREE.Vector3>(new THREE.Vector3(0, 16, 20));
  const targetCamLookRef = useRef<THREE.Vector3>(new THREE.Vector3(0, 0, 0));

  // FPS & Performance tracking
  const [fps, setFps] = useState(60);
  const [frameTimeMs, setFrameTimeMs] = useState(16);
  const [drawCalls, setDrawCalls] = useState(0);
  const [triangles, setTriangles] = useState(0);
  const [activeTier, setActiveTier] = useState<'LOW' | 'MEDIUM' | 'HIGH'>(
    quality === 'LOW' ? 'LOW' : quality === 'MEDIUM' ? 'MEDIUM' : 'HIGH'
  );

  // Animated 3D dice tumbling state
  const diceAnimRef = useRef<{
    startTime: number;
    duration: number;
    roll: number;
    targetEuler: THREE.Euler;
    baseX: number;
    baseY: number;
    baseZ: number;
  } | null>(null);

  // Animated movement state for player hopping step-by-step
  const moveAnimRef = useRef<{
    playerId: string;
    path: number[];
    currentStepIdx: number;
    stepProgress: number; // 0 to 1
    stepDuration: number; // ms per step
  } | null>(null);

  // Dynamic Tile Reactions (dip and flash effect on pad touch)
  const tileReactionsRef = useRef<Map<number, {
    startTime: number;
    duration: number;
    tileType: TileType;
    isFinal: boolean;
  }>>(new Map());

  // Helper to trigger reaction on a tile pad
  const triggerTileReaction = (tileId: number, isFinal: boolean = false) => {
    const tileDef = BOARD_TILES.find(t => t.id === tileId);
    tileReactionsRef.current.set(tileId, {
      startTime: performance.now(),
      duration: isFinal ? 500 : 220,
      tileType: tileDef?.type || 'BLUE',
      isFinal
    });
  };

  // Target FPS based on quality setting (Unlocked up to 60 FPS on high/auto)
  const targetFps = quality === 'LOW' ? 30 : quality === 'MEDIUM' ? 45 : 60;
  const fpsInterval = 1000 / targetFps;

  // Initialize Three.js 3D Scene
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    // 1. Scene & Environment
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x090d16);
    scene.fog = new THREE.FogExp2(0x090d16, 0.014);
    sceneRef.current = scene;

    // 2. Camera (High-angle isometric framing matching console party board reference)
    const aspect = container.clientWidth / container.clientHeight;
    const camera = new THREE.PerspectiveCamera(44, aspect, 0.5, 120);
    camera.position.set(0, 19, 21);
    camera.lookAt(0, 0.4, -0.5);
    cameraRef.current = camera;

    // 3. WebGL Renderer with adaptive DPR and shadows
    const renderer = new THREE.WebGLRenderer({
      antialias: quality !== 'LOW',
      powerPreference: 'high-performance'
    });
    const effectiveDpr = quality === 'LOW' ? 1.0 : quality === 'HIGH' ? 1.5 : 1.25;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, effectiveDpr));
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.shadowMap.enabled = quality !== 'LOW';
    renderer.shadowMap.type = THREE.BasicShadowMap;
    rendererRef.current = renderer;
    container.appendChild(renderer.domElement);

    // 4. Lighting: 1 Directional (Sun) + 1 Hemisphere
    const hemiLight = new THREE.HemisphereLight(0xe2e8f0, 0x1a202c, 1.25);
    scene.add(hemiLight);

    const sunLight = new THREE.DirectionalLight(0xffedd5, 1.65);
    sunLight.position.set(12, 22, 14);
    sunLight.castShadow = quality !== 'LOW';
    sunLight.shadow.mapSize.width = quality === 'HIGH' ? 1024 : 512;
    sunLight.shadow.mapSize.height = quality === 'HIGH' ? 1024 : 512;
    sunLight.shadow.camera.near = 0.5;
    sunLight.shadow.camera.far = 60;
    sunLight.shadow.camera.left = -20;
    sunLight.shadow.camera.right = 20;
    sunLight.shadow.camera.top = 20;
    sunLight.shadow.camera.bottom = -20;
    scene.add(sunLight);

    // 5. Stylized Floating Island with rich biomes & safe zones
    const island = createIslandTerrain();
    scene.add(island);
    islandMeshRef.current = island;

    // 6. 3D Dice Mesh
    const dice = createDiceMesh();
    dice.position.set(0, 4.5, 0);
    dice.visible = false;
    scene.add(dice);
    diceMeshRef.current = dice;

    // 7. Add All 36 Tiles as 3D pads
    BOARD_TILES.forEach(tile => {
      const isShop = tile.id === room.crownShopTileId;
      const pad = createTilePad(tile, isShop);
      scene.add(pad);
      tileMeshesRef.current.set(tile.id, pad);
    });

    // 8. Adaptive 30-60 FPS Render Loop
    let lastTime = performance.now();
    let frameCount = 0;
    let fpsTimer = performance.now();
    let lowFpsCount = 0;
    let highFpsCount = 0;

    const animate = (now: number) => {
      animFrameIdRef.current = requestAnimationFrame(animate);

      const elapsed = now - lastTime;
      if (elapsed < fpsInterval) return;
      lastTime = now - (elapsed % fpsInterval);

      frameCount++;
      const time = now * 0.001;

      // Rolling FPS and adaptive quality scaling
      if (now - fpsTimer >= 1000) {
        const measuredFps = Math.round((frameCount * 1000) / (now - fpsTimer));
        setFps(measuredFps);
        setFrameTimeMs(Math.round(elapsed));
        frameCount = 0;
        fpsTimer = now;

        // Adaptive scaling in AUTO mode
        if (quality === 'AUTO') {
          if (measuredFps < 28) {
            lowFpsCount++;
            highFpsCount = 0;
            if (lowFpsCount >= 2) {
              const nextTier = activeTier === 'HIGH' ? 'MEDIUM' : 'LOW';
              setActiveTier(nextTier);
              if (islandMeshRef.current) {
                setIslandDecorationQuality(islandMeshRef.current, nextTier);
              }
              lowFpsCount = 0;
            }
          } else if (measuredFps > 55) {
            highFpsCount++;
            lowFpsCount = 0;
            if (highFpsCount >= 4 && activeTier !== 'HIGH') {
              const nextTier = activeTier === 'LOW' ? 'MEDIUM' : 'HIGH';
              setActiveTier(nextTier);
              if (islandMeshRef.current) {
                setIslandDecorationQuality(islandMeshRef.current, nextTier);
              }
              highFpsCount = 0;
            }
          } else {
            lowFpsCount = 0;
            highFpsCount = 0;
          }
        }

        if (renderer.info) {
          setDrawCalls(renderer.info.render.calls);
          setTriangles(renderer.info.render.triangles);
        }
      }

      // Smooth Camera Lerp with look-ahead damping
      camera.position.lerp(targetCamPosRef.current, 0.068);
      const currentLook = new THREE.Vector3();
      camera.getWorldDirection(currentLook);
      const desiredLook = targetCamLookRef.current.clone().sub(camera.position).normalize();
      currentLook.lerp(desiredLook, 0.068);
      camera.lookAt(camera.position.clone().add(currentLook.multiplyScalar(20)));

      // Water animation (Smooth and calm at y: -0.6, zero shoreline intersection)
      const water = island.getObjectByName('waterPlane');
      if (water) {
        water.position.y = -0.6 + Math.sin(time * 1.5) * 0.04;
      }

      // Chaos Crystals gentle pulsing
      const crystals = island.children.filter(c => c.name === 'chaosCrystal');
      crystals.forEach((c, idx) => {
        c.rotation.y = time * 0.8 + idx * 0.5;
        c.position.y += Math.sin(time * 2.0 + idx) * 0.002;
      });

      // Crown Shop rotating marker (Smooth dignified rotation, no strobe)
      const shopPad = tileMeshesRef.current.get(room.crownShopTileId);
      const crownMarker = shopPad?.getObjectByName('crownShopMarker');
      if (crownMarker) {
        crownMarker.rotation.y = time * 1.2;
        crownMarker.position.y = 1.3 + Math.sin(time * 2) * 0.08;
      }

      // 3D Dice Tumble & Settle Animation
      const diceAnim = diceAnimRef.current;
      const diceGroup = diceMeshRef.current;
      if (diceAnim && diceGroup) {
        const diceElapsed = now - diceAnim.startTime;
        const p = Math.min(1, diceElapsed / diceAnim.duration);
        const easeP = 1 - Math.pow(1 - p, 3); // easeOutCubic

        const cube = diceGroup.getObjectByName('diceCube') || diceGroup;

        // Multi-axis spin tumble settling into the exact targetEuler
        const spinRounds = 4.2;
        const curSpin = (1 - easeP) * (Math.PI * 2 * spinRounds);
        cube.rotation.x = diceAnim.targetEuler.x + curSpin * 1.15;
        cube.rotation.y = diceAnim.targetEuler.y + curSpin * 0.85;
        cube.rotation.z = diceAnim.targetEuler.z + curSpin * 1.35;

        // Bouncing decay in Y
        const baseDiceY = diceAnim.baseY;
        const bounce = Math.abs(Math.sin((1 - easeP) * Math.PI * 3.5)) * (1 - easeP) * 1.7;
        diceGroup.position.set(diceAnim.baseX, baseDiceY + bounce, diceAnim.baseZ);

        // Ground aura pulse under die
        const aura = diceGroup.getObjectByName('diceAura');
        if (aura) {
          aura.scale.setScalar(1 + (1 - easeP) * 0.35);
        }

        if (p >= 1) {
          // Settled squarely on the rolled number!
          cube.rotation.copy(diceAnim.targetEuler);
          diceGroup.position.y = baseDiceY;
        }
      } else if (diceGroup && room.phase !== 'BOARD_ROLLING') {
        // Disappear smoothly when movement starts
        if (diceGroup.visible && diceGroup.scale.x > 0.05) {
          diceGroup.scale.multiplyScalar(0.85);
          if (diceGroup.scale.x <= 0.05) {
            diceGroup.visible = false;
            diceGroup.scale.set(1, 1, 1);
            diceAnimRef.current = null;
          }
        }
      }

      // Handle animated player hopping step-by-step
      const moveAnim = moveAnimRef.current;
      if (moveAnim) {
        // Delta-time accurate progress independent of display refresh rate
        const stepProgressInc = elapsed / moveAnim.stepDuration;
        moveAnim.stepProgress += stepProgressInc;
        const char = charactersMapRef.current.get(moveAnim.playerId);

        if (char && moveAnim.path.length > 1) {
          const fromTileId = moveAnim.path[moveAnim.currentStepIdx];
          const toTileId = moveAnim.path[moveAnim.currentStepIdx + 1];

          const fromTile = BOARD_TILES.find(t => t.id === fromTileId) || BOARD_TILES[0];
          const toTile = BOARD_TILES.find(t => t.id === toTileId) || BOARD_TILES[0];

          if (fromTile.position3D && toTile.position3D) {
            const [fx, fy, fz] = fromTile.position3D;
            const [tx, ty, tz] = toTile.position3D;
            const fromPadTopY = fy + 0.185;
            const toPadTopY = ty + 0.185;
            const t = Math.min(1, moveAnim.stepProgress);

            // Parabolic jump arc in Y (0.85 high)
            const arcY = Math.sin(t * Math.PI) * 0.85;

            // Target formation offset on the destination tile for the final hop
            let destOffsetX = 0;
            let destOffsetZ = 0;
            const isFinalHop = moveAnim.currentStepIdx >= moveAnim.path.length - 2;
            if (isFinalHop) {
              const destPlayers = Object.values(room.players).filter(
                p => p.boardPosition === toTileId && p.id !== moveAnim.playerId
              );
              const [ox, oz] = getFormationOffset(destPlayers.length, destPlayers.length + 1);
              destOffsetX = ox;
              destOffsetZ = oz;
            }

            const curX = THREE.MathUtils.lerp(fx, tx + destOffsetX, t);
            const curY = THREE.MathUtils.lerp(fromPadTopY, toPadTopY, t) + arcY;
            const curZ = THREE.MathUtils.lerp(fz, tz + destOffsetZ, t);

            char.root.position.set(curX, curY, curZ);

            // Turn face towards moving direction
            const dirX = (tx + destOffsetX) - fx;
            const dirZ = (tz + destOffsetZ) - fz;
            if (Math.hypot(dirX, dirZ) > 0.02) {
              char.root.rotation.y = Math.atan2(dirX, dirZ);
            }

            // Animate legs and arms walking/hopping
            char.animate('walk', time, t);

            // Camera look-ahead during movement
            targetCamLookRef.current.set(curX, curY + 0.8, curZ);
            targetCamPosRef.current.set(
              curX * 0.72 + Math.sign(dirX || 1) * 0.5,
              12.5,
              curZ * 0.72 + 13.5
            );

            if (moveAnim.stepProgress >= 1) {
              moveAnim.stepProgress = 0;
              moveAnim.currentStepIdx++;

              const isFinal = moveAnim.currentStepIdx >= moveAnim.path.length - 1;
              triggerTileReaction(toTileId, isFinal);

              if (isFinal) {
                // Arrived at destination!
                moveAnimRef.current = null;
                char.animate('celebrate', time);
              }
            }
          } else {
            moveAnimRef.current = null;
          }
        } else {
          moveAnimRef.current = null;
        }
      }

      // Animate idle breathing for all stationary characters
      charactersMapRef.current.forEach((c, id) => {
        if (!moveAnimRef.current || moveAnimRef.current.playerId !== id) {
          c.animate('idle', time);
        }
      });

      // Dynamic Tile Reactions (dip and emissive flash)
      tileReactionsRef.current.forEach((reaction, tId) => {
        const pad = tileMeshesRef.current.get(tId);
        const tileDef = BOARD_TILES.find(t => t.id === tId);
        if (!pad || !tileDef?.position3D) return;

        const el = now - reaction.startTime;
        const p = el / reaction.duration;
        if (p < 1) {
          const sinP = Math.sin(p * Math.PI);
          const dip = reaction.isFinal ? 0.2 : 0.1;
          pad.position.y = tileDef.position3D[1] - sinP * dip;

          const topMesh = pad.getObjectByName('tileTop') as THREE.Mesh | undefined;
          if (topMesh && topMesh.material && (topMesh.material as any).emissive) {
            const mat = topMesh.material as THREE.MeshStandardMaterial;
            mat.emissiveIntensity = sinP * (reaction.isFinal ? 1.0 : 0.5);
            if (reaction.tileType === 'RED') mat.emissive.setHex(0xe53e3e);
            else if (reaction.tileType === 'GOLD' || reaction.tileType === 'JACKPOT') mat.emissive.setHex(0xffd700);
            else if (reaction.tileType === 'CHAOS') mat.emissive.setHex(0x9f7aea);
            else mat.emissive.setHex(0x38bdf8);
          }
        } else {
          pad.position.y = tileDef.position3D[1];
          const topMesh = pad.getObjectByName('tileTop') as THREE.Mesh | undefined;
          if (topMesh && topMesh.material && (topMesh.material as any).emissive) {
            (topMesh.material as THREE.MeshStandardMaterial).emissiveIntensity = 0;
          }
          tileReactionsRef.current.delete(tId);
        }
      });

      renderer.render(scene, camera);
    };

    animFrameIdRef.current = requestAnimationFrame(animate);

    // Resize listener
    const handleResize = () => {
      if (!container || !renderer || !camera) return;
      const w = container.clientWidth;
      const h = container.clientHeight;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    };

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      if (animFrameIdRef.current) cancelAnimationFrame(animFrameIdRef.current);
      if (renderer.domElement && container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
      charactersMapRef.current.forEach(char => {
        scene.remove(char.root);
        char.dispose();
      });
      charactersMapRef.current.clear();
      renderer.dispose();
    };
  }, [quality]);

  // Sync Players 3D characters
  useEffect(() => {
    const scene = sceneRef.current;
    if (!scene) return;

    const charsMap = charactersMapRef.current;
    const activePlayerId = room.playerOrder[room.currentPlayerIndex];

    // Remove old disconnected or left players
    charsMap.forEach((char, id) => {
      if (!room.players[id]) {
        scene.remove(char.root);
        char.dispose();
        charsMap.delete(id);
      }
    });

    // Formation grouping: compute how many players are sharing each tile
    const playersByTile = new Map<number, Player[]>();
    Object.values(room.players).forEach(p => {
      const tileId = p.boardPosition;
      const list = playersByTile.get(tileId) || [];
      list.push(p);
      playersByTile.set(tileId, list);
    });

    // Add or update existing players
    Object.values(room.players).forEach(player => {
      const isActive = player.id === activePlayerId;
      let char = charsMap.get(player.id);

      const tile = BOARD_TILES.find(t => t.id === player.boardPosition) || BOARD_TILES[0];
      const [tx, ty, tz] = tile.position3D || [0, 0, 0];
      const padTopY = ty + 0.185;

      const tilePlayers = playersByTile.get(player.boardPosition) || [];
      const pIdx = tilePlayers.indexOf(player);
      const [offsetX, offsetZ] = getFormationOffset(pIdx, tilePlayers.length);

      const targetX = tx + offsetX;
      const targetY = padTopY;
      const targetZ = tz + offsetZ;

      if (!char) {
        char = new PartyCharacter3D(player, isActive);
        char.root.position.set(targetX, targetY, targetZ);
        scene.add(char.root);
        charsMap.set(player.id, char);
      } else {
        char.update(player, isActive);
        // Only update resting position if not currently mid-hop
        if (!moveAnimRef.current || moveAnimRef.current.playerId !== player.id) {
          char.root.position.set(targetX, targetY, targetZ);
        }
      }
    });
  }, [room.players, room.currentPlayerIndex, room.playerOrder]);

  // Handle 3D Dice Roll Trigger
  useEffect(() => {
    if (room.phase === 'BOARD_ROLLING' && room.lastDiceRoll) {
      const dice = diceMeshRef.current;
      const activePlayerId = room.playerOrder[room.currentPlayerIndex];
      const activePlayer = room.players[activePlayerId];
      const activeTile = activePlayer
        ? BOARD_TILES.find(t => t.id === activePlayer.boardPosition)
        : BOARD_TILES[0];
      const [tx, ty, tz] = activeTile?.position3D || [0, 0, 0];

      if (dice) {
        dice.visible = true;
        dice.scale.set(1, 1, 1);
        const targetEuler = getDiceTargetEuler(room.lastDiceRoll);

        // Position cleanly offset to the right & slightly above the active player
        const diceX = tx + 1.25;
        const diceY = ty + 2.2;
        const diceZ = tz - 0.4;
        dice.position.set(diceX, diceY, diceZ);

        diceAnimRef.current = {
          startTime: performance.now(),
          duration: 1400, // 1.4s energetic tumble & settle
          roll: room.lastDiceRoll,
          targetEuler,
          baseX: diceX,
          baseY: diceY,
          baseZ: diceZ
        };

        // Smoothly frame both active player and the compact die cleanly
        targetCamLookRef.current.set(tx + 0.4, ty + 0.8, tz);
        targetCamPosRef.current.set(tx * 0.65 + 0.4, 13.5, tz * 0.65 + 13.0);
      }
    }
  }, [room.phase, room.lastDiceRoll, room.currentPlayerIndex]);

  // Handle Movement Path Animation Trigger
  useEffect(() => {
    if (room.phase === 'BOARD_MOVE' && room.movementPath) {
      const { playerId, path } = room.movementPath;
      if (path && path.length > 1) {
        const isFast = (room.lastDiceRoll || 3) > 3;
        moveAnimRef.current = {
          playerId,
          path,
          currentStepIdx: 0,
          stepProgress: 0,
          stepDuration: isFast ? 320 : 380
        };
      }
    }
  }, [room.phase, room.movementPath]);

  // Camera Follow and Overview Framing
  useEffect(() => {
    const activePlayerId = room.playerOrder[room.currentPlayerIndex];
    const activePlayer = room.players[activePlayerId];

    // If dice rolling or movement animation is active, camera is driven dynamically
    if (room.phase === 'BOARD_ROLLING' || moveAnimRef.current) return;

    if (room.phase === 'SHOP_DECISION') {
      // Zoom close into Crown Temple
      const shopTile = BOARD_TILES.find(t => t.id === room.crownShopTileId);
      if (shopTile && shopTile.position3D) {
        const [sx, sy, sz] = shopTile.position3D;
        targetCamPosRef.current.set(sx + 3.0, sy + 3.8, sz + 5.5);
        targetCamLookRef.current.set(sx, sy + 1.2, sz);
      }
    } else if (room.activeForkChoice) {
      // Show both branching paths clearly
      const forkPad = tileMeshesRef.current.get(room.activeForkChoice.currentTileId);
      if (forkPad) {
        const fx = forkPad.position.x;
        const fy = forkPad.position.y;
        const fz = forkPad.position.z;
        targetCamPosRef.current.set(fx * 0.75, 14.5, fz * 0.75 + 14.5);
        targetCamLookRef.current.set(fx, fy + 0.6, fz);
      }
    } else if (activePlayer) {
      const tile = BOARD_TILES.find(t => t.id === activePlayer.boardPosition) || BOARD_TILES[0];
      if (tile && tile.position3D) {
        const [tx, ty, tz] = tile.position3D;
        // Follow smoothly behind and above active player
        targetCamPosRef.current.set(tx * 0.75, 12.0, tz * 0.75 + 13.5);
        targetCamLookRef.current.set(tx, ty + 0.8, tz);
      }
    } else {
      // Board Overview (Console-quality high-angle isometric framing)
      targetCamPosRef.current.set(0, 19, 21);
      targetCamLookRef.current.set(0, 0.4, -0.5);
    }
  }, [room.phase, room.currentPlayerIndex, room.crownShopTileId, room.activeForkChoice]);

  return (
    <div className="relative w-full h-full">
      {/* Three.js Canvas Container */}
      <div ref={containerRef} className="w-full h-full" />

      {/* Dev Mode Performance HUD (Only when isDevMode is active) */}
      {room.isDevMode && (
        <div className="absolute top-2 left-2 bg-slate-950/85 border border-slate-700/80 p-3 rounded-2xl font-mono text-[11px] text-cyan-300 pointer-events-none flex flex-col gap-1 shadow-2xl backdrop-blur-md">
          <div className="font-bold text-white flex items-center justify-between gap-4 border-b border-slate-800 pb-1">
            <span>3D PERFORMANCE:</span>
            <span className={fps >= 48 ? 'text-emerald-400' : fps >= 28 ? 'text-amber-400' : 'text-red-400'}>
              {fps} FPS (Target {targetFps})
            </span>
          </div>
          <div className="flex justify-between gap-4">
            <span className="text-slate-400">Frame Time:</span>
            <span className="text-white font-bold">{frameTimeMs} ms</span>
          </div>
          <div className="flex justify-between gap-4">
            <span className="text-slate-400">Draw Calls:</span>
            <span className="text-white font-bold">{drawCalls}</span>
          </div>
          <div className="flex justify-between gap-4">
            <span className="text-slate-400">Triangles:</span>
            <span className="text-white font-bold">{triangles.toLocaleString()}</span>
          </div>
          <div className="flex justify-between gap-4 border-t border-slate-800 pt-1">
            <span className="text-slate-400">Deco Tier:</span>
            <span className="text-amber-300 font-bold">{activeTier} ({quality})</span>
          </div>
        </div>
      )}
    </div>
  );
};
