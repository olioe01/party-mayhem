import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { RoomState } from '@shared/types';
import { PartyCharacter3D } from '../PartyCharacter3D';
import { sounds } from '../../../audio/soundSynth';
import { AVATARS } from '@shared/constants';

interface HostArena3DProps {
  room: RoomState;
}

export const HostArena3D: React.FC<HostArena3DProps> = ({ room }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const animFrameIdRef = useRef<number | null>(null);

  // 3D character instances for each player in arena
  const charactersMapRef = useRef<Map<string, PartyCharacter3D>>(new Map());
  // Baskets map for Fruit Frenzy
  const basketsMapRef = useRef<Map<string, THREE.Group>>(new Map());
  // Crowns mesh for Crown Chase
  const crownMeshRef = useRef<THREE.Group | null>(null);

  // Object pool for falling items (fruits, bombs)
  const itemMeshesPoolRef = useRef<Map<number, THREE.Group>>(new Map());
  // Object pool for bomb dodge hazard warning circles
  const hazardMeshesRef = useRef<Map<number, THREE.Mesh>>(new Map());
  // Paint Panic floor tile meshes
  const paintTilesRef = useRef<THREE.Mesh[]>([]);

  // Sound triggering cache
  const lastCatchEventIdRef = useRef<number>(0);

  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  // Setup Three.js Arena Scene
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const width = container.clientWidth || window.innerWidth;
    const height = container.clientHeight || window.innerHeight;

    // 1. Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.background = new THREE.Color(0x090d16);
    scene.fog = new THREE.FogExp2(0x090d16, 0.025);

    // 2. Camera: Angled isometric / stadium perspective
    const camera = new THREE.PerspectiveCamera(42, width / height, 0.1, 100);
    camera.position.set(0, 14.5, 12.5);
    camera.lookAt(0, 0.5, 0);
    cameraRef.current = camera;

    // 3. WebGL Renderer
    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    rendererRef.current = renderer;
    container.appendChild(renderer.domElement);

    // 4. Lighting: Warm festival key light + ambient fill + rim lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.65);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffeedd, 1.3);
    dirLight.position.set(8, 18, 10);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 1024;
    dirLight.shadow.mapSize.height = 1024;
    dirLight.shadow.camera.near = 0.5;
    dirLight.shadow.camera.far = 40;
    dirLight.shadow.camera.left = -10;
    dirLight.shadow.camera.right = 10;
    dirLight.shadow.camera.top = 10;
    dirLight.shadow.camera.bottom = -10;
    dirLight.shadow.bias = -0.0005;
    scene.add(dirLight);

    const rimLight = new THREE.DirectionalLight(0x60a5fa, 0.6);
    rimLight.position.set(-10, 8, -10);
    scene.add(rimLight);

    // 5. Arena Floor Geometry
    const isPushArena = mg?.id === 'push-arena';
    const isPaintPanic = mg?.id === 'paint-panic';

    if (isPushArena) {
      // Floating circular platform with glowing rim
      const platGeo = new THREE.CylinderGeometry(5.8, 5.4, 0.6, 36);
      const platMat = new THREE.MeshStandardMaterial({
        color: 0x1e293b,
        roughness: 0.4,
        metalness: 0.2,
      });
      const platform = new THREE.Mesh(platGeo, platMat);
      platform.position.y = -0.3;
      platform.receiveShadow = true;
      scene.add(platform);

      // Warning neon rim
      const rimGeo = new THREE.RingGeometry(5.6, 5.85, 36);
      rimGeo.rotateX(-Math.PI / 2);
      const rimMat = new THREE.MeshBasicMaterial({
        color: 0xf59e0b,
        side: THREE.DoubleSide,
      });
      const rim = new THREE.Mesh(rimGeo, rimMat);
      rim.position.y = 0.01;
      scene.add(rim);
    } else if (isPaintPanic) {
      // 14x14 Grid Floor tiles
      const gridSize = 14;
      const cellSize = 0.8;
      const halfW = (gridSize * cellSize) / 2;
      const tileGeo = new THREE.PlaneGeometry(cellSize * 0.94, cellSize * 0.94);
      tileGeo.rotateX(-Math.PI / 2);

      const defaultMat = new THREE.MeshStandardMaterial({
        color: 0x1e293b,
        roughness: 0.6,
      });

      const tilesArr: THREE.Mesh[] = [];
      for (let r = 0; r < gridSize; r++) {
        for (let c = 0; c < gridSize; c++) {
          const tile = new THREE.Mesh(tileGeo, defaultMat.clone());
          tile.position.set(-halfW + c * cellSize + cellSize / 2, 0.01, -halfW + r * cellSize + cellSize / 2);
          tile.receiveShadow = true;
          scene.add(tile);
          tilesArr.push(tile);
        }
      }
      paintTilesRef.current = tilesArr;

      // Base floor under tiles
      const baseFloor = new THREE.Mesh(
        new THREE.BoxGeometry(13, 0.4, 13),
        new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.8 })
      );
      baseFloor.position.y = -0.21;
      baseFloor.receiveShadow = true;
      scene.add(baseFloor);
    } else {
      // Standard colorful Festival Arena floor (for Fruit Frenzy, Bomb Dodge, etc.)
      const floorGeo = new THREE.BoxGeometry(15, 0.5, 11);
      const floorMat = new THREE.MeshStandardMaterial({
        color: 0x1e293b,
        roughness: 0.5,
        metalness: 0.15,
      });
      const floor = new THREE.Mesh(floorGeo, floorMat);
      floor.position.y = -0.25;
      floor.receiveShadow = true;
      scene.add(floor);

      // Arena boundary curb/border
      const borderGeo = new THREE.BoxGeometry(15.4, 0.25, 0.3);
      const borderMat = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.4 });

      const bTop = new THREE.Mesh(borderGeo, borderMat);
      bTop.position.set(0, 0.12, -5.35);
      scene.add(bTop);

      const bBot = new THREE.Mesh(borderGeo, borderMat);
      bBot.position.set(0, 0.12, 5.35);
      scene.add(bBot);

      const borderSideGeo = new THREE.BoxGeometry(0.3, 0.25, 11);
      const bLeft = new THREE.Mesh(borderSideGeo, borderMat);
      bLeft.position.set(-7.35, 0.12, 0);
      scene.add(bLeft);

      const bRight = new THREE.Mesh(borderSideGeo, borderMat);
      bRight.position.set(7.35, 0.12, 0);
      scene.add(bRight);
    }

    // 6. Floating 👑 Crown Model for Crown Chase
    if (mg?.id === 'crown-chase') {
      const crownGroup = new THREE.Group();
      const goldMat = new THREE.MeshStandardMaterial({
        color: 0xffd700,
        metalness: 0.85,
        roughness: 0.15,
        emissive: 0xffb700,
        emissiveIntensity: 0.4,
      });
      const crownBase = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.3, 0.22, 7), goldMat);
      crownGroup.add(crownBase);
      crownGroup.scale.set(1.2, 1.2, 1.2);
      scene.add(crownGroup);
      crownMeshRef.current = crownGroup;
    }

    // 7. Render Loop
    let clock = new THREE.Clock();

    const animate = () => {
      animFrameIdRef.current = requestAnimationFrame(animate);

      const elapsedTime = clock.getElapsedTime();
      const delta = clock.getDelta();

      // Animate 👑 Crown rotation and bobbing for Crown Chase
      if (crownMeshRef.current && mg?.data?.currentCrownHolder) {
        const holderId = mg.data.currentCrownHolder;
        const holderChar = charactersMapRef.current.get(holderId);
        if (holderChar) {
          crownMeshRef.current.position.set(
            holderChar.root.position.x,
            holderChar.root.position.y + 1.8 + Math.sin(elapsedTime * 4) * 0.12,
            holderChar.root.position.z
          );
          crownMeshRef.current.rotation.y = elapsedTime * 2.5;
          crownMeshRef.current.visible = true;
        } else {
          crownMeshRef.current.visible = false;
        }
      }

      // Smoothly update characters in arena
      const simPlayers = mgData.players as Record<string, any> | undefined;
      charactersMapRef.current.forEach((char, pId) => {
        const sim = simPlayers?.[pId];
        if (sim) {
          // Smooth interpolation towards authoritative server position
          char.root.position.x = THREE.MathUtils.lerp(char.root.position.x, sim.x, 0.35);
          char.root.position.z = THREE.MathUtils.lerp(char.root.position.z, sim.z, 0.35);
          char.root.position.y = sim.isFalling ? THREE.MathUtils.lerp(char.root.position.y, -4, 0.2) : 0;

          // Facing rotation
          if (sim.facing !== undefined) {
            char.root.rotation.y = THREE.MathUtils.lerp(char.root.rotation.y, sim.facing, 0.3);
          }

          // Walking vs Idle animation
          const speed = Math.hypot(sim.vx || 0, sim.vz || 0);
          if (speed > 0.3) {
            char.animate('walk', elapsedTime * 1.5, (elapsedTime * 4) % 1);
          } else {
            char.animate('idle', elapsedTime);
          }

          // Visual hit flash
          if (sim.isHit) {
            char.root.scale.set(0.85, 0.85, 0.85);
          } else {
            char.root.scale.set(1.0, 1.0, 1.0);
          }

          // Basket attachment positioning for Fruit Frenzy
          const basket = basketsMapRef.current.get(pId);
          if (basket) {
            basket.position.set(
              char.root.position.x + Math.sin(char.root.rotation.y) * 0.55,
              char.root.position.y + 0.42,
              char.root.position.z + Math.cos(char.root.rotation.y) * 0.55
            );
            basket.rotation.y = char.root.rotation.y;
          }
        }
      });

      // Render falling items for Fruit Frenzy
      if (mg?.id === 'fruit-frenzy') {
        const items = (mg.data?.items || []) as any[];
        const activeIds = new Set<number>();

        items.forEach(item => {
          activeIds.add(item.id);
          let itemMesh = itemMeshesPoolRef.current.get(item.id);

          if (!itemMesh) {
            itemMesh = createFruitMesh(item.type);
            scene.add(itemMesh);
            itemMeshesPoolRef.current.set(item.id, itemMesh);
          }

          itemMesh.position.set(item.x, item.y, item.z);
          itemMesh.rotation.y += 0.04;
          itemMesh.rotation.x += 0.02;
        });

        // Remove caught/despawned items from scene
        itemMeshesPoolRef.current.forEach((mesh, id) => {
          if (!activeIds.has(id)) {
            scene.remove(mesh);
            disposeHierarchy(mesh);
            itemMeshesPoolRef.current.delete(id);
          }
        });

        // Trigger sound effects for new catch events
        const catchEvents = (mg.data?.catchEvents || []) as any[];
        if (catchEvents.length > 0) {
          const latest = catchEvents[catchEvents.length - 1];
          if (latest.timestamp > lastCatchEventIdRef.current) {
            lastCatchEventIdRef.current = latest.timestamp;
            if (latest.type === 'bomb') {
              sounds.playExplosion();
            } else {
              sounds.playCoin();
            }
          }
        }
      }

      // Render Bomb Dodge hazard warning circles
      if (mg?.id === 'bomb-dodge') {
        const hazards = (mg.data?.hazards || []) as any[];
        const activeHazards = new Set<number>();

        hazards.forEach(h => {
          activeHazards.add(h.id);
          let mesh = hazardMeshesRef.current.get(h.id);

          if (!mesh) {
            const geo = new THREE.RingGeometry(0.1, h.radius || 1.75, 24);
            geo.rotateX(-Math.PI / 2);
            const mat = new THREE.MeshBasicMaterial({
              color: 0xef4444,
              side: THREE.DoubleSide,
              transparent: true,
              opacity: 0.6,
            });
            mesh = new THREE.Mesh(geo, mat);
            scene.add(mesh);
            hazardMeshesRef.current.set(h.id, mesh);
          }

          mesh.position.set(h.x, 0.02, h.z);
          // Pulsing danger warning
          const mat = mesh.material as THREE.MeshBasicMaterial;
          if (h.exploded) {
            mat.color.setHex(0xffaa00);
            mat.opacity = 0.9;
            mesh.scale.set(1.15, 1.15, 1.15);
          } else {
            const pulse = 0.4 + Math.sin(elapsedTime * 12) * 0.25;
            mat.opacity = pulse;
          }
        });

        hazardMeshesRef.current.forEach((m, id) => {
          if (!activeHazards.has(id)) {
            scene.remove(m);
            m.geometry.dispose();
            (m.material as THREE.Material).dispose();
            hazardMeshesRef.current.delete(id);
          }
        });
      }

      // Update Paint Panic tiles colors
      if (mg?.id === 'paint-panic' && mg.data?.cells) {
        const cells: number[] = mg.data.cells;
        const tiles = paintTilesRef.current;
        const playerIndices: Record<string, number> = mg.data.playerIndices || {};
        const colorsByIndex: Record<number, number> = {};

        Object.entries(playerIndices).forEach(([pId, idx]) => {
          const p = room.players[pId];
          if (p && p.color) {
            colorsByIndex[idx] = parseInt(p.color.replace('#', '0x'), 16);
          }
        });

        for (let i = 0; i < Math.min(cells.length, tiles.length); i++) {
          const ownerIdx = cells[i];
          const mat = tiles[i].material as THREE.MeshStandardMaterial;
          if (ownerIdx > 0 && colorsByIndex[ownerIdx]) {
            mat.color.setHex(colorsByIndex[ownerIdx]);
            mat.emissive.setHex(colorsByIndex[ownerIdx]);
            mat.emissiveIntensity = 0.2;
          }
        }
      }

      renderer.render(scene, camera);
    };

    animFrameIdRef.current = requestAnimationFrame(animate);

    // Resize handler
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
      charactersMapRef.current.forEach(c => c.dispose());
      charactersMapRef.current.clear();
      basketsMapRef.current.forEach(b => {
        scene.remove(b);
        disposeHierarchy(b);
      });
      basketsMapRef.current.clear();
      itemMeshesPoolRef.current.forEach(m => {
        scene.remove(m);
        disposeHierarchy(m);
      });
      itemMeshesPoolRef.current.clear();
      renderer.dispose();
    };
  }, [mg?.id]);

  // Synchronize 3D characters when players join or change
  useEffect(() => {
    const scene = sceneRef.current;
    if (!scene) return;

    const playersList = Object.values(room.players);
    const charsMap = charactersMapRef.current;

    // Remove characters for players who left
    charsMap.forEach((char, id) => {
      if (!room.players[id]) {
        scene.remove(char.root);
        char.dispose();
        charsMap.delete(id);

        const basket = basketsMapRef.current.get(id);
        if (basket) {
          scene.remove(basket);
          disposeHierarchy(basket);
          basketsMapRef.current.delete(id);
        }
      }
    });

    // Add or update characters
    playersList.forEach(player => {
      let char = charsMap.get(player.id);
      if (!char) {
        char = new PartyCharacter3D(player, false);
        scene.add(char.root);
        charsMap.set(player.id, char);

        // For Fruit Frenzy: create basket mesh
        if (mg?.id === 'fruit-frenzy') {
          const basket = createBasketMesh();
          scene.add(basket);
          basketsMapRef.current.set(player.id, basket);
        }
      } else {
        char.update(player, false);
      }
    });
  }, [room.players, mg?.id]);

  return (
    <div className="relative w-full h-full min-h-[500px] flex items-center justify-center overflow-hidden">
      {/* 3D WebGL Canvas */}
      <div ref={containerRef} className="absolute inset-0 w-full h-full pointer-events-none" />

      {/* HOST SCOREBOARD HUD OVERLAY */}
      <div className="absolute top-3 inset-x-6 flex items-center justify-center gap-4 z-20 pointer-events-none">
        {Object.values(room.players).map(p => {
          const sim = mgData.players?.[p.id];
          const score = mgData.scores?.[p.id] ?? sim?.score ?? 0;
          const avatar = AVATARS[p.avatar] || AVATARS['fox'];
          const isCrownHolder = mg?.id === 'crown-chase' && mgData.currentCrownHolder === p.id;

          return (
            <div
              key={p.id}
              className={`px-4 py-2 rounded-2xl flex items-center gap-2.5 backdrop-blur-md border shadow-xl transition-all ${
                isCrownHolder
                  ? 'bg-amber-500/30 border-amber-400 text-white scale-110 shadow-[0_0_25px_rgba(251,191,36,0.5)]'
                  : 'bg-slate-900/85 border-slate-700/80 text-slate-200'
              }`}
            >
              <span className="text-2xl">{isCrownHolder ? '👑' : avatar.emoji}</span>
              <div className="flex flex-col">
                <span className="text-xs font-black truncate max-w-[100px]" style={{ color: p.color || '#fff' }}>
                  {p.name}
                  {p.isBot && <span className="text-[9px] text-purple-300 ml-1">[BOT]</span>}
                </span>
                <span className="text-base font-black font-mono text-amber-300 leading-none">
                  {mg?.id === 'fruit-frenzy' && `🍎 ${score}`}
                  {mg?.id === 'bomb-dodge' && `🛡️ ${score} hullám`}
                  {mg?.id === 'push-arena' && `💥 ${score} KO`}
                  {mg?.id === 'crown-chase' && `👑 ${score.toFixed(1)}s`}
                  {mg?.id === 'paint-panic' && `🎨 ${score}%`}
                  {mg?.id === 'controller-test' && `🎮 ${score} tap`}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// --- HELPER THREE.JS FACTORIES ---

function createBasketMesh(): THREE.Group {
  const group = new THREE.Group();
  const basketGeo = new THREE.CylinderGeometry(0.38, 0.28, 0.32, 14, 1, true);
  const basketMat = new THREE.MeshStandardMaterial({
    color: 0xca8a04, // woven wicker amber
    roughness: 0.8,
    metalness: 0.05,
    side: THREE.DoubleSide,
  });
  const basketBody = new THREE.Mesh(basketGeo, basketMat);
  basketBody.castShadow = true;
  group.add(basketBody);

  // Rim ring
  const rimGeo = new THREE.TorusGeometry(0.38, 0.04, 8, 20);
  rimGeo.rotateX(Math.PI / 2);
  const rimMat = new THREE.MeshStandardMaterial({ color: 0xa16207, roughness: 0.7 });
  const rim = new THREE.Mesh(rimGeo, rimMat);
  rim.position.y = 0.16;
  group.add(rim);

  return group;
}

function createFruitMesh(type: string): THREE.Group {
  const group = new THREE.Group();

  if (type === 'bomb') {
    // Cartoon Bomb
    const bombMat = new THREE.MeshStandardMaterial({ color: 0x18181b, roughness: 0.3, metalness: 0.4 });
    const bombBody = new THREE.Mesh(new THREE.SphereGeometry(0.34, 14, 12), bombMat);
    bombBody.castShadow = true;
    group.add(bombBody);

    // Fuse cap & spark
    const fuseCap = new THREE.Mesh(
      new THREE.CylinderGeometry(0.08, 0.08, 0.1, 8),
      new THREE.MeshStandardMaterial({ color: 0x71717a })
    );
    fuseCap.position.y = 0.34;
    group.add(fuseCap);

    const spark = new THREE.Mesh(
      new THREE.SphereGeometry(0.08, 8, 8),
      new THREE.MeshBasicMaterial({ color: 0xf59e0b })
    );
    spark.position.y = 0.44;
    group.add(spark);
  } else if (type === 'golden') {
    // Golden Apple
    const goldMat = new THREE.MeshStandardMaterial({
      color: 0xffd700,
      metalness: 0.9,
      roughness: 0.15,
      emissive: 0xffb700,
      emissiveIntensity: 0.5,
    });
    const apple = new THREE.Mesh(new THREE.SphereGeometry(0.36, 16, 14), goldMat);
    apple.castShadow = true;
    group.add(apple);
  } else if (type === 'star') {
    // Rare Star Fruit (Diamond cyan glow)
    const starMat = new THREE.MeshStandardMaterial({
      color: 0x38bdf8,
      metalness: 0.8,
      roughness: 0.1,
      emissive: 0x0284c7,
      emissiveIntensity: 0.7,
    });
    const star = new THREE.Mesh(new THREE.OctahedronGeometry(0.38, 0), starMat);
    star.castShadow = true;
    group.add(star);
  } else {
    // Regular Fruit: apple (red), orange (orange), banana (yellow), etc.
    let col = 0xef4444; // default red apple
    if (type === 'orange') col = 0xf97316;
    else if (type === 'banana') col = 0xfacc15;
    else if (type === 'strawberry') col = 0xf43f5e;
    else if (type === 'watermelon') col = 0x22c55e;

    const fruitMat = new THREE.MeshStandardMaterial({ color: col, roughness: 0.35, metalness: 0.1 });
    const fruit = new THREE.Mesh(new THREE.SphereGeometry(0.32, 14, 12), fruitMat);
    fruit.castShadow = true;
    group.add(fruit);

    // Green leaf / stem
    const stemMat = new THREE.MeshStandardMaterial({ color: 0x15803d });
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.12, 6), stemMat);
    stem.position.y = 0.32;
    group.add(stem);
  }

  return group;
}

function disposeHierarchy(obj: THREE.Object3D) {
  obj.traverse(child => {
    if (child instanceof THREE.Mesh) {
      if (child.geometry) child.geometry.dispose();
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material.forEach(m => m.dispose());
        } else {
          child.material.dispose();
        }
      }
    }
  });
}
