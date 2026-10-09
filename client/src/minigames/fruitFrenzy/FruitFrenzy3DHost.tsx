import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { RoomState } from '@shared/types';
import { PartyCharacter3D } from '../../host/3d/PartyCharacter3D';
import { sounds } from '../../audio/soundSynth';
import { AVATARS } from '@shared/constants';

interface FruitFrenzy3DHostProps {
  room: RoomState;
}

interface FloatingPopup {
  id: string;
  x: number;
  y: number;
  text: string;
  color: string;
  alpha: number;
}

export const FruitFrenzy3DHost: React.FC<FruitFrenzy3DHostProps> = ({ room }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const animFrameIdRef = useRef<number | null>(null);

  // Characters & Baskets
  const charactersMapRef = useRef<Map<string, PartyCharacter3D>>(new Map());
  const basketsMapRef = useRef<Map<string, THREE.Group>>(new Map());

  // Falling Items Pool (item.id -> THREE.Group)
  const itemMeshesPoolRef = useRef<Map<number, THREE.Group>>(new Map());

  // Sound & Popup tracking
  const lastCatchTimeRef = useRef<number>(0);
  const [popups, setPopups] = useState<FloatingPopup[]>([]);

  // Real-time room ref so RAF loop always reads latest authoritative simulation state
  const roomRef = useRef<RoomState>(room);
  roomRef.current = room;

  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  // Catch sound & score popup trigger
  useEffect(() => {
    const catchEvents = (mgData.catchEvents || []) as any[];
    if (catchEvents.length > 0) {
      catchEvents.forEach(evt => {
        if (evt.timestamp > lastCatchTimeRef.current) {
          lastCatchTimeRef.current = evt.timestamp;

          if (evt.type === 'bomb') {
            sounds.playExplosion();
          } else {
            sounds.playCoin();
          }

          const text = evt.type === 'bomb' ? '-3 💣' : `+${evt.points} ${evt.type === 'star' ? '💎' : evt.type === 'golden' ? '🌟' : '🍎'}`;
          const color = evt.type === 'bomb' ? '#ef4444' : evt.type === 'star' ? '#38bdf8' : evt.type === 'golden' ? '#fbbf24' : '#4ade80';

          // Screen space conversion for floating popup (from virtual 1920x1080)
          const screenX = (evt.x / 1920) * 100;
          const screenY = (evt.y / 1080) * 100;

          setPopups(prev => [
            ...prev.slice(-8),
            {
              id: `${evt.timestamp}-${Math.random()}`,
              x: screenX,
              y: screenY,
              text,
              color,
              alpha: 1.0,
            },
          ]);
        }
      });
    }
  }, [mgData.catchEvents]);

  // Fade popups over time
  useEffect(() => {
    if (popups.length === 0) return;
    const timer = setInterval(() => {
      setPopups(prev =>
        prev
          .map(p => ({ ...p, alpha: p.alpha - 0.08, y: p.y - 0.8 }))
          .filter(p => p.alpha > 0.05)
      );
    }, 40);
    return () => clearInterval(timer);
  }, [popups.length]);

  // Setup Three.js Stage & Loop
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const width = container.clientWidth || window.innerWidth;
    const height = container.clientHeight || window.innerHeight;

    // 1. Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.background = new THREE.Color(0x0c1222);
    scene.fog = new THREE.FogExp2(0x0c1222, 0.02);

    // 2. Camera: Angled front stadium view focused on the orchard stage
    const camera = new THREE.PerspectiveCamera(40, width / height, 0.1, 100);
    camera.position.set(0, 4.2, 14.5);
    camera.lookAt(0, 3.8, 0);
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

    // 4. Lighting: Golden sunset key light + orchard rim light + ambient
    const ambientLight = new THREE.AmbientLight(0xfff7ed, 0.7);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0xfef08a, 1.4);
    sunLight.position.set(6, 16, 10);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.width = 1024;
    sunLight.shadow.mapSize.height = 1024;
    sunLight.shadow.camera.near = 0.5;
    sunLight.shadow.camera.far = 40;
    sunLight.shadow.camera.left = -10;
    sunLight.shadow.camera.right = 10;
    sunLight.shadow.camera.top = 10;
    sunLight.shadow.camera.bottom = -10;
    scene.add(sunLight);

    const rimLight = new THREE.DirectionalLight(0x38bdf8, 0.5);
    rimLight.position.set(-8, 6, -8);
    scene.add(rimLight);

    // 5. Stage Geometry: Wooden Festival Platform & Orchard Backdrop
    const stageWidth = 18;
    const stageGeo = new THREE.BoxGeometry(stageWidth, 0.5, 4.5);
    const stageMat = new THREE.MeshStandardMaterial({
      color: 0x1e3a1e, // deep green orchard lawn
      roughness: 0.6,
      metalness: 0.1,
    });
    const stage = new THREE.Mesh(stageGeo, stageMat);
    stage.position.set(0, -0.25, 0);
    stage.receiveShadow = true;
    scene.add(stage);

    // Wooden front curb
    const curbGeo = new THREE.BoxGeometry(stageWidth + 0.2, 0.25, 0.35);
    const curbMat = new THREE.MeshStandardMaterial({ color: 0x854d0e, roughness: 0.4 });
    const curb = new THREE.Mesh(curbGeo, curbMat);
    curb.position.set(0, 0.05, 2.2);
    curb.receiveShadow = true;
    scene.add(curb);

    // Back curtain / festive stage wall
    const backWallGeo = new THREE.BoxGeometry(stageWidth, 12, 0.4);
    const backWallMat = new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.85 });
    const backWall = new THREE.Mesh(backWallGeo, backWallMat);
    backWall.position.set(0, 5.5, -2.3);
    backWall.receiveShadow = true;
    scene.add(backWall);

    // Festive bunting / glowing fairy lights along top
    for (let i = -7; i <= 7; i += 1.4) {
      const bulbGeo = new THREE.SphereGeometry(0.12, 8, 8);
      const bulbColor = (Math.abs(i) % 3 === 0) ? 0xf59e0b : (Math.abs(i) % 3 === 1) ? 0xef4444 : 0x10b981;
      const bulbMat = new THREE.MeshBasicMaterial({ color: bulbColor });
      const bulb = new THREE.Mesh(bulbGeo, bulbMat);
      bulb.position.set(i, 8.8 + Math.sin(i * 0.5) * 0.25, -2.1);
      scene.add(bulb);
    }

    // 6. 60 FPS Render Loop
    let clock = new THREE.Clock();

    const animate = () => {
      animFrameIdRef.current = requestAnimationFrame(animate);

      const elapsedTime = clock.getElapsedTime();
      const delta = clock.getDelta();

      const currentRoom = roomRef.current;
      const currentMg = currentRoom?.activeMinigame;
      const currentMgData = currentMg?.data || {};

      // A. Smoothly update Player 3D meshes and Baskets
      const simPlayers = currentMgData.players as Record<string, any> | undefined;

      charactersMapRef.current.forEach((char, pId) => {
        const sim = simPlayers?.[pId];
        if (sim) {
          // Map virtual 1920 space to 3D stage [-7.5 .. +7.5]
          const targetWorldX = ((sim.x - 960) / 960) * 7.5;
          char.root.position.x = THREE.MathUtils.lerp(char.root.position.x, targetWorldX, 0.45);
          char.root.position.y = 0;
          char.root.position.z = 0.2;

          // Cute 3D facing tilt based on movement direction
          let targetFacing = 0;
          if (sim.vx > 20) {
            targetFacing = 0.35; // tilt slightly right
          } else if (sim.vx < -20) {
            targetFacing = -0.35; // tilt slightly left
          }
          char.root.rotation.y = THREE.MathUtils.lerp(char.root.rotation.y, targetFacing, 0.3);

          // Walk vs Idle animation
          const speed = Math.abs(sim.vx || 0);
          if (speed > 40) {
            char.animate('walk', elapsedTime * 1.6, (elapsedTime * 4.5) % 1);
          } else {
            char.animate('idle', elapsedTime);
          }

          // Hit wobble / flash reaction
          if (sim.isHit) {
            char.root.scale.set(0.85, 0.85, 0.85);
            char.root.rotation.z = Math.sin(elapsedTime * 25) * 0.15;
          } else {
            char.root.scale.set(1.0, 1.0, 1.0);
            char.root.rotation.z = 0;
          }

          // Update Basket position in front of character
          const basket = basketsMapRef.current.get(pId);
          if (basket) {
            basket.position.set(
              char.root.position.x,
              char.root.position.y + 0.45,
              char.root.position.z + 0.55
            );
            basket.rotation.y = char.root.rotation.y;
            basket.rotation.z = char.root.rotation.z;
          }
        }
      });

      // B. Render Falling 3D Fruits and Bombs
      const items = (currentMgData.items || []) as any[];
      const activeItemIds = new Set<number>();

      items.forEach(item => {
        activeItemIds.add(item.id);
        let mesh = itemMeshesPoolRef.current.get(item.id);

        if (!mesh) {
          mesh = createFruit3DMesh(item.type);
          scene.add(mesh);
          itemMeshesPoolRef.current.set(item.id, mesh);
        }

        // Map item simulation coordinate (x in [0..1920], y in [0..1080]) to 3D world
        const worldX = ((item.x - 960) / 960) * 7.5;
        const worldY = ((920 - item.y) / 920) * 8.2;
        const worldZ = 0.55; // aligned directly with basket depth

        mesh.position.set(worldX, Math.max(-0.5, worldY), worldZ);
        mesh.rotation.y += 0.04;
        mesh.rotation.x += 0.02;
      });

      // Cleanup caught / despawned items
      itemMeshesPoolRef.current.forEach((mesh, id) => {
        if (!activeItemIds.has(id)) {
          scene.remove(mesh);
          disposeHierarchy(mesh);
          itemMeshesPoolRef.current.delete(id);
        }
      });

      renderer.render(scene, camera);
    };

    animFrameIdRef.current = requestAnimationFrame(animate);

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
  }, []);

  // Sync player characters
  useEffect(() => {
    const scene = sceneRef.current;
    if (!scene) return;

    const playersList = Object.values(room.players);
    const charsMap = charactersMapRef.current;

    // Remove left players
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

    // Add or update players
    playersList.forEach(player => {
      let char = charsMap.get(player.id);
      if (!char) {
        char = new PartyCharacter3D(player, false);
        scene.add(char.root);
        charsMap.set(player.id, char);

        const basket = create3DBasket();
        scene.add(basket);
        basketsMapRef.current.set(player.id, basket);
      } else {
        char.update(player, false);
      }
    });
  }, [room.players]);

  return (
    <div className="relative w-full h-full min-h-[500px] flex items-center justify-center overflow-hidden select-none">
      {/* 3D WebGL Canvas */}
      <div ref={containerRef} className="absolute inset-0 w-full h-full pointer-events-none" />

      {/* FLOATING CATCH SCORE POPUPS */}
      <div className="absolute inset-0 pointer-events-none z-30 overflow-hidden">
        {popups.map(p => (
          <div
            key={p.id}
            className="absolute -translate-x-1/2 -translate-y-1/2 font-black font-heading text-xl sm:text-2xl drop-shadow-[0_2px_8px_rgba(0,0,0,0.8)] transition-all"
            style={{
              left: `${p.x}%`,
              top: `${p.y}%`,
              color: p.color,
              opacity: p.alpha,
              transform: `scale(${1 + (1 - p.alpha) * 0.3})`,
            }}
          >
            {p.text}
          </div>
        ))}
      </div>

      {/* TOP HUD SCOREBOARD */}
      <div className="absolute top-3 inset-x-6 flex items-center justify-center gap-4 z-20 pointer-events-none">
        {Object.values(room.players).map(p => {
          const sim = mgData.players?.[p.id];
          const score = mgData.scores?.[p.id] ?? sim?.score ?? 0;
          const avatar = AVATARS[p.avatar] || AVATARS['fox'];

          return (
            <div
              key={p.id}
              className={`px-4 py-2 rounded-2xl flex items-center gap-2.5 backdrop-blur-md border shadow-xl transition-all ${
                sim?.isHit
                  ? 'bg-red-500/30 border-red-400 text-white animate-pulse'
                  : 'bg-slate-900/85 border-slate-700/80 text-slate-200'
              }`}
            >
              <span className="text-2xl">{avatar.emoji}</span>
              <div className="flex flex-col">
                <span className="text-xs font-black truncate max-w-[110px]" style={{ color: p.color || '#fff' }}>
                  {p.name}
                  {p.isBot && <span className="text-[9px] text-purple-300 ml-1">[BOT]</span>}
                </span>
                <span className="text-base font-black font-mono text-amber-300 leading-none">
                  🍎 {score} pont
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// --- HELPER 3D MESH GENERATORS ---

function create3DBasket(): THREE.Group {
  const group = new THREE.Group();

  // Woven wicker basket body
  const bodyGeo = new THREE.CylinderGeometry(0.42, 0.32, 0.36, 16, 1, true);
  const basketMat = new THREE.MeshStandardMaterial({
    color: 0xd97706, // golden woven wicker
    roughness: 0.75,
    metalness: 0.05,
    side: THREE.DoubleSide,
  });
  const body = new THREE.Mesh(bodyGeo, basketMat);
  body.castShadow = true;
  group.add(body);

  // Bottom plate
  const bottomGeo = new THREE.CylinderGeometry(0.32, 0.32, 0.04, 16);
  const bottom = new THREE.Mesh(bottomGeo, basketMat);
  bottom.position.y = -0.17;
  group.add(bottom);

  // Sturdy rim
  const rimGeo = new THREE.TorusGeometry(0.42, 0.045, 8, 20);
  rimGeo.rotateX(Math.PI / 2);
  const rimMat = new THREE.MeshStandardMaterial({ color: 0x92400e, roughness: 0.6 });
  const rim = new THREE.Mesh(rimGeo, rimMat);
  rim.position.y = 0.18;
  group.add(rim);

  return group;
}

function createFruit3DMesh(type: string): THREE.Group {
  const group = new THREE.Group();

  if (type === 'bomb') {
    // 3D Cartoon Bomb
    const bombMat = new THREE.MeshStandardMaterial({
      color: 0x1c1917,
      roughness: 0.3,
      metalness: 0.5,
    });
    const bombBody = new THREE.Mesh(new THREE.SphereGeometry(0.36, 16, 14), bombMat);
    bombBody.castShadow = true;
    group.add(bombBody);

    // Fuse cap & burning wick
    const capGeo = new THREE.CylinderGeometry(0.08, 0.08, 0.1, 8);
    const capMat = new THREE.MeshStandardMaterial({ color: 0x78716c });
    const cap = new THREE.Mesh(capGeo, capMat);
    cap.position.y = 0.38;
    group.add(cap);

    const sparkGeo = new THREE.SphereGeometry(0.06, 8, 8);
    const sparkMat = new THREE.MeshBasicMaterial({ color: 0xf59e0b });
    const spark = new THREE.Mesh(sparkGeo, sparkMat);
    spark.position.set(0, 0.48, 0);
    group.add(spark);
  } else if (type === 'golden') {
    // Golden Apple with glowing aura
    const goldMat = new THREE.MeshStandardMaterial({
      color: 0xfacc15,
      metalness: 0.9,
      roughness: 0.1,
      emissive: 0xca8a04,
      emissiveIntensity: 0.5,
    });
    const goldApple = new THREE.Mesh(new THREE.SphereGeometry(0.36, 16, 14), goldMat);
    goldApple.castShadow = true;
    group.add(goldApple);

    // Leaf
    const leafGeo = new THREE.ConeGeometry(0.09, 0.2, 6);
    leafGeo.rotateZ(Math.PI / 4);
    const leafMat = new THREE.MeshStandardMaterial({ color: 0x84cc16 });
    const leaf = new THREE.Mesh(leafGeo, leafMat);
    leaf.position.set(0.12, 0.40, 0);
    group.add(leaf);
  } else if (type === 'star') {
    // 3D Glowing Star
    const starMat = new THREE.MeshStandardMaterial({
      color: 0x38bdf8,
      metalness: 0.6,
      roughness: 0.2,
      emissive: 0x0284c7,
      emissiveIntensity: 0.6,
    });
    const starBody = new THREE.Mesh(new THREE.OctahedronGeometry(0.36, 0), starMat);
    starBody.castShadow = true;
    group.add(starBody);
  } else if (type === 'banana') {
    // Curved yellow crescent
    const banMat = new THREE.MeshStandardMaterial({ color: 0xfde047, roughness: 0.4 });
    const banBody = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.12, 0.65, 8), banMat);
    banBody.rotation.z = Math.PI / 4;
    banBody.castShadow = true;
    group.add(banBody);
  } else if (type === 'orange') {
    // Juicy Orange
    const orangeMat = new THREE.MeshStandardMaterial({ color: 0xf97316, roughness: 0.55 });
    const orangeBody = new THREE.Mesh(new THREE.SphereGeometry(0.34, 14, 12), orangeMat);
    orangeBody.castShadow = true;
    group.add(orangeBody);
  } else if (type === 'strawberry') {
    // Red Berry
    const berryMat = new THREE.MeshStandardMaterial({ color: 0xe11d48, roughness: 0.4 });
    const berryBody = new THREE.Mesh(new THREE.ConeGeometry(0.28, 0.48, 12), berryMat);
    berryBody.rotation.x = Math.PI;
    berryBody.castShadow = true;
    group.add(berryBody);
  } else {
    // Standard Shiny Red Apple
    const appleMat = new THREE.MeshStandardMaterial({ color: 0xdc2626, roughness: 0.35 });
    const appleBody = new THREE.Mesh(new THREE.SphereGeometry(0.33, 14, 12), appleMat);
    appleBody.castShadow = true;
    group.add(appleBody);

    const stemGeo = new THREE.CylinderGeometry(0.025, 0.025, 0.15, 6);
    const stemMat = new THREE.MeshStandardMaterial({ color: 0x78350f });
    const stem = new THREE.Mesh(stemGeo, stemMat);
    stem.position.y = 0.38;
    group.add(stem);
  }

  return group;
}

function disposeHierarchy(obj: THREE.Object3D) {
  obj.traverse(child => {
    if ((child as THREE.Mesh).isMesh) {
      const mesh = child as THREE.Mesh;
      if (mesh.geometry) mesh.geometry.dispose();
      if (mesh.material) {
        if (Array.isArray(mesh.material)) {
          mesh.material.forEach(m => m.dispose());
        } else {
          mesh.material.dispose();
        }
      }
    }
  });
}
