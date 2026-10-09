import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { RoomState } from '@shared/types';
import { PartyCharacter3D } from '../../host/3d/PartyCharacter3D';
import { sounds } from '../../audio/soundSynth';
import { AVATARS } from '@shared/constants';

interface BombDodge3DHostProps {
  room: RoomState;
}

export const BombDodge3DHost: React.FC<BombDodge3DHostProps> = ({ room }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const animFrameIdRef = useRef<number | null>(null);

  // Characters Map
  const charactersMapRef = useRef<Map<string, PartyCharacter3D>>(new Map());

  // Hazard Meshes Pool: hazard.id -> { ring: THREE.Mesh, bomb?: THREE.Group, explosion?: THREE.Mesh }
  const hazardMeshesRef = useRef<
    Map<number, { ring: THREE.Mesh; bombGroup: THREE.Group; explosionMesh: THREE.Mesh }>
  >(new Map());

  // Sound triggering cache
  const lastExplosionTimeRef = useRef<number>(0);

  // Real-time room ref so RAF loop always reads latest authoritative simulation state
  const roomRef = useRef<RoomState>(room);
  roomRef.current = room;

  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  // Explosion sound triggering
  useEffect(() => {
    const explosions = (mgData.recentExplosions || []) as any[];
    if (explosions.length > 0) {
      const latest = explosions[explosions.length - 1];
      if (latest.timestamp > lastExplosionTimeRef.current) {
        lastExplosionTimeRef.current = latest.timestamp;
        sounds.playExplosion();
      }
    }
  }, [mgData.recentExplosions]);

  // Three.js Scene Setup & Render Loop
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const width = container.clientWidth || window.innerWidth;
    const height = container.clientHeight || window.innerHeight;

    // 1. Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.background = new THREE.Color(0x090d16);
    scene.fog = new THREE.FogExp2(0x090d16, 0.022);

    // 2. Camera: Angled isometric perspective looking down at stadium
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

    // 4. Lighting: Dramatic red/amber arena hazard lighting
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
    scene.add(dirLight);

    const redRimLight = new THREE.DirectionalLight(0xef4444, 0.7);
    redRimLight.position.set(-10, 8, -10);
    scene.add(redRimLight);

    // 5. Arena Floor & Neon Red Hazard Curb
    const floorGeo = new THREE.BoxGeometry(15, 0.5, 10.5);
    const floorMat = new THREE.MeshStandardMaterial({
      color: 0x1e293b,
      roughness: 0.55,
      metalness: 0.2,
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.position.y = -0.25;
    floor.receiveShadow = true;
    scene.add(floor);

    // Warning boundary curbs
    const borderGeoX = new THREE.BoxGeometry(15.4, 0.28, 0.3);
    const borderMat = new THREE.MeshStandardMaterial({ color: 0xef4444, roughness: 0.35, emissive: 0x7f1d1d, emissiveIntensity: 0.3 });
    const bTop = new THREE.Mesh(borderGeoX, borderMat);
    bTop.position.set(0, 0.14, -5.25);
    scene.add(bTop);

    const bBot = new THREE.Mesh(borderGeoX, borderMat);
    bBot.position.set(0, 0.14, 5.25);
    scene.add(bBot);

    const borderGeoZ = new THREE.BoxGeometry(0.3, 0.28, 10.8);
    const bLeft = new THREE.Mesh(borderGeoZ, borderMat);
    bLeft.position.set(-7.55, 0.14, 0);
    scene.add(bLeft);

    const bRight = new THREE.Mesh(borderGeoZ, borderMat);
    bRight.position.set(7.55, 0.14, 0);
    scene.add(bRight);

    // 6. 60 FPS Render Loop
    let clock = new THREE.Clock();

    const animate = () => {
      animFrameIdRef.current = requestAnimationFrame(animate);

      const elapsedTime = clock.getElapsedTime();
      const delta = clock.getDelta();

      const currentRoom = roomRef.current;
      const currentMg = currentRoom?.activeMinigame;
      const currentMgData = currentMg?.data || {};

      // A. Smoothly update Player 3D characters
      const simPlayers = currentMgData.players as Record<string, any> | undefined;

      charactersMapRef.current.forEach((char, pId) => {
        const sim = simPlayers?.[pId];
        if (sim) {
          // Map 2D simulation coords (x in [120..1800], y in [140..940]) to 3D world ([-6.8..+6.8], [-4.2..+4.2])
          const targetWorldX = ((sim.x - 960) / 840) * 6.8;
          const targetWorldZ = ((sim.y - 540) / 400) * 4.2;

          char.root.position.x = THREE.MathUtils.lerp(char.root.position.x, targetWorldX, 0.4);
          char.root.position.z = THREE.MathUtils.lerp(char.root.position.z, targetWorldZ, 0.4);
          char.root.position.y = 0;

          // 3D Facing rotation
          if (sim.vx !== undefined && sim.vy !== undefined) {
            const speed = Math.hypot(sim.vx, sim.vy);
            if (speed > 30) {
              const targetAngle = Math.atan2(sim.vx, sim.vy);
              let diff = targetAngle - char.root.rotation.y;
              while (diff < -Math.PI) diff += Math.PI * 2;
              while (diff > Math.PI) diff -= Math.PI * 2;
              char.root.rotation.y += diff * 0.35;
              char.animate('walk', elapsedTime * 1.5, (elapsedTime * 4.5) % 1);
            } else {
              char.animate('idle', elapsedTime);
            }
          }

          // Hit reaction flash / scale
          if (sim.isHit) {
            char.root.scale.set(0.85, 0.85, 0.85);
          } else {
            char.root.scale.set(1.0, 1.0, 1.0);
          }
        }
      });

      // B. Render Bomb Hazards (Warning zones + Falling bombs + Explosions)
      const hazards = (currentMgData.hazards || []) as any[];
      const activeHazardIds = new Set<number>();

      hazards.forEach(h => {
        activeHazardIds.add(h.id);
        let entry = hazardMeshesRef.current.get(h.id);

        const worldX = ((h.x - 960) / 840) * 6.8;
        const worldZ = ((h.y - 540) / 400) * 4.2;
        const worldRadius = (h.radius / 840) * 6.8;

        if (!entry) {
          // Warning Circle Ring on ground
          const ringGeo = new THREE.RingGeometry(0.1, worldRadius, 28);
          ringGeo.rotateX(-Math.PI / 2);
          const ringMat = new THREE.MeshBasicMaterial({
            color: 0xef4444,
            side: THREE.DoubleSide,
            transparent: true,
            opacity: 0.6,
          });
          const ring = new THREE.Mesh(ringGeo, ringMat);
          scene.add(ring);

          // 3D Falling Bomb Group
          const bombGroup = create3DBomb();
          scene.add(bombGroup);

          // Explosion Flash Sphere
          const expGeo = new THREE.SphereGeometry(worldRadius * 0.95, 16, 14);
          const expMat = new THREE.MeshBasicMaterial({
            color: 0xf59e0b,
            transparent: true,
            opacity: 0,
          });
          const explosionMesh = new THREE.Mesh(expGeo, expMat);
          scene.add(explosionMesh);

          entry = { ring, bombGroup, explosionMesh };
          hazardMeshesRef.current.set(h.id, entry);
        }

        entry.ring.position.set(worldX, 0.02, worldZ);
        entry.explosionMesh.position.set(worldX, 0.4, worldZ);

        if (h.exploded) {
          // Hide bomb & ring, show fiery blast sphere
          entry.bombGroup.visible = false;
          entry.ring.visible = false;
          entry.explosionMesh.visible = true;

          const expMat = entry.explosionMesh.material as THREE.MeshBasicMaterial;
          expMat.opacity = Math.max(0, (h.explosionDuration || 0.35) * 2.5);
          entry.explosionMesh.scale.addScalar(0.04);
        } else {
          entry.bombGroup.visible = true;
          entry.ring.visible = true;
          entry.explosionMesh.visible = false;

          // Pulse warning ring
          const ringMat = entry.ring.material as THREE.MeshBasicMaterial;
          ringMat.opacity = 0.35 + Math.sin(elapsedTime * 14) * 0.25;

          // Bomb falls from sky (Y = 7 down to Y = 0.3) as warningTime expires
          const fallProgress = Math.max(0, Math.min(1, 1 - (h.warningTime || 1.2) / 1.2));
          const bombY = THREE.MathUtils.lerp(7.5, 0.35, fallProgress * fallProgress);

          entry.bombGroup.position.set(worldX, bombY, worldZ);
          entry.bombGroup.rotation.y += 0.05;
          entry.bombGroup.rotation.x += 0.03;
        }
      });

      // Cleanup despawned hazards
      hazardMeshesRef.current.forEach((entry, id) => {
        if (!activeHazardIds.has(id)) {
          scene.remove(entry.ring);
          entry.ring.geometry.dispose();
          (entry.ring.material as THREE.Material).dispose();

          scene.remove(entry.bombGroup);
          disposeHierarchy(entry.bombGroup);

          scene.remove(entry.explosionMesh);
          entry.explosionMesh.geometry.dispose();
          (entry.explosionMesh.material as THREE.Material).dispose();

          hazardMeshesRef.current.delete(id);
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
      hazardMeshesRef.current.forEach(entry => {
        scene.remove(entry.ring);
        scene.remove(entry.bombGroup);
        scene.remove(entry.explosionMesh);
        disposeHierarchy(entry.bombGroup);
        entry.ring.geometry.dispose();
        (entry.ring.material as THREE.Material).dispose();
        entry.explosionMesh.geometry.dispose();
        (entry.explosionMesh.material as THREE.Material).dispose();
      });
      hazardMeshesRef.current.clear();
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
      }
    });

    // Add or update players
    playersList.forEach(player => {
      let char = charsMap.get(player.id);
      if (!char) {
        char = new PartyCharacter3D(player, false);
        scene.add(char.root);
        charsMap.set(player.id, char);
      } else {
        char.update(player, false);
      }
    });
  }, [room.players]);

  return (
    <div className="relative w-full h-full min-h-[500px] flex items-center justify-center overflow-hidden select-none">
      {/* 3D WebGL Canvas */}
      <div ref={containerRef} className="absolute inset-0 w-full h-full pointer-events-none" />

      {/* TOP HUD SCOREBOARD & WAVE COUNTER */}
      <div className="absolute top-3 inset-x-6 flex items-center justify-between z-20 pointer-events-none">
        {/* Wave Badge */}
        <div className="px-4 py-2 rounded-2xl bg-red-950/80 border border-red-500/50 text-red-200 backdrop-blur-md shadow-xl flex items-center gap-2 font-mono">
          <span className="text-xl">💣</span>
          <span className="font-black text-sm">HULLÁM: #{mgData.waveCount || 1}</span>
        </div>

        {/* Players Scoreboard */}
        <div className="flex items-center gap-3">
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
                    ⭐ {score} pont
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

// --- HELPER 3D MESH GENERATORS ---

function create3DBomb(): THREE.Group {
  const group = new THREE.Group();

  const bombMat = new THREE.MeshStandardMaterial({
    color: 0x18181b,
    roughness: 0.35,
    metalness: 0.45,
  });
  const bombBody = new THREE.Mesh(new THREE.SphereGeometry(0.38, 16, 14), bombMat);
  bombBody.castShadow = true;
  group.add(bombBody);

  const capGeo = new THREE.CylinderGeometry(0.09, 0.09, 0.12, 8);
  const capMat = new THREE.MeshStandardMaterial({ color: 0x78716c });
  const cap = new THREE.Mesh(capGeo, capMat);
  cap.position.y = 0.42;
  group.add(cap);

  const sparkGeo = new THREE.SphereGeometry(0.07, 8, 8);
  const sparkMat = new THREE.MeshBasicMaterial({ color: 0xef4444 });
  const spark = new THREE.Mesh(sparkGeo, sparkMat);
  spark.position.set(0, 0.54, 0);
  group.add(spark);

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
