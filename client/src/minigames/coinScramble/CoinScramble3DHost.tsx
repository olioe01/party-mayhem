import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { RoomState } from '@shared/types';
import { PartyCharacter3D } from '../../host/3d/PartyCharacter3D';
import { sounds } from '../../audio/soundSynth';
import { AVATARS } from '@shared/constants';

interface CoinScramble3DHostProps {
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

export const CoinScramble3DHost: React.FC<CoinScramble3DHostProps> = ({ room }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const animFrameIdRef = useRef<number | null>(null);

  // Characters Map
  const charactersMapRef = useRef<Map<string, PartyCharacter3D>>(new Map());

  // 3D Coins Pool: coin.id -> THREE.Group
  const coinMeshesPoolRef = useRef<Map<number, THREE.Group>>(new Map());

  // Sound and Popup tracking
  const lastEventTimeRef = useRef<number>(0);
  const [popups, setPopups] = useState<FloatingPopup[]>([]);

  // Real-time room ref so RAF loop always reads latest authoritative simulation state
  const roomRef = useRef<RoomState>(room);
  roomRef.current = room;

  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  // Coin collect audio & popup trigger
  useEffect(() => {
    const events = (mgData.coinCollectEvents || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;

          if (evt.type === 'cursed') {
            sounds.playExplosion();
          } else {
            sounds.playCoin();
          }

          const text = evt.type === 'cursed' ? '-3 💀' : evt.type === 'gold' ? '+5 🌟' : '+1 🪙';
          const color = evt.type === 'cursed' ? '#ef4444' : evt.type === 'gold' ? '#fbbf24' : '#4ade80';

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
  }, [mgData.coinCollectEvents]);

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

    // 2. Camera: Angled isometric stadium perspective
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

    // 4. Lighting: Golden treasury lighting with warm spotlights
    const ambientLight = new THREE.AmbientLight(0xffeedd, 0.65);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xfffbeb, 1.35);
    dirLight.position.set(8, 18, 10);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 1024;
    dirLight.shadow.mapSize.height = 1024;
    scene.add(dirLight);

    const goldRimLight = new THREE.DirectionalLight(0xf59e0b, 0.7);
    goldRimLight.position.set(-10, 8, -10);
    scene.add(goldRimLight);

    // 5. Arena Floor & Neon Amber Curb
    const floorGeo = new THREE.BoxGeometry(15, 0.5, 10.5);
    const floorMat = new THREE.MeshStandardMaterial({
      color: 0x1e293b,
      roughness: 0.5,
      metalness: 0.15,
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.position.y = -0.25;
    floor.receiveShadow = true;
    scene.add(floor);

    // Golden boundary curbs
    const borderGeoX = new THREE.BoxGeometry(15.4, 0.28, 0.3);
    const borderMat = new THREE.MeshStandardMaterial({
      color: 0xf59e0b,
      roughness: 0.3,
      metalness: 0.5,
      emissive: 0xb45309,
      emissiveIntensity: 0.25,
    });
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
      const currentRoom = roomRef.current;
      const currentMg = currentRoom?.activeMinigame;
      const currentMgData = currentMg?.data || {};

      // A. Smoothly update Player 3D characters
      const simPlayers = currentMgData.players as Record<string, any> | undefined;

      charactersMapRef.current.forEach((char, pId) => {
        const sim = simPlayers?.[pId];
        if (sim) {
          const targetWorldX = ((sim.x - 960) / 840) * 6.8;
          const targetWorldZ = ((sim.y - 540) / 400) * 4.2;

          char.root.position.x = THREE.MathUtils.lerp(char.root.position.x, targetWorldX, 0.4);
          char.root.position.z = THREE.MathUtils.lerp(char.root.position.z, targetWorldZ, 0.4);
          char.root.position.y = 0;

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

          if (sim.isHit) {
            char.root.scale.set(0.85, 0.85, 0.85);
          } else {
            char.root.scale.set(1.0, 1.0, 1.0);
          }
        }
      });

      // B. Render 3D Coins in arena
      const coins = (currentMgData.coins || []) as any[];
      const activeCoinIds = new Set<number>();

      coins.forEach(coin => {
        activeCoinIds.add(coin.id);
        let mesh = coinMeshesPoolRef.current.get(coin.id);

        const worldX = ((coin.x - 960) / 840) * 6.8;
        const worldZ = ((coin.y - 540) / 400) * 4.2;
        const bobY = 0.32 + Math.sin(elapsedTime * 3.5 + coin.id * 0.5) * 0.08;

        if (!mesh) {
          mesh = create3DCoinMesh(coin.type);
          scene.add(mesh);
          coinMeshesPoolRef.current.set(coin.id, mesh);
        }

        mesh.position.set(worldX, bobY, worldZ);
        mesh.rotation.y += 0.045; // smooth 3D spin
      });

      // Cleanup collected coins
      coinMeshesPoolRef.current.forEach((mesh, id) => {
        if (!activeCoinIds.has(id)) {
          scene.remove(mesh);
          disposeHierarchy(mesh);
          coinMeshesPoolRef.current.delete(id);
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
      coinMeshesPoolRef.current.forEach(m => {
        scene.remove(m);
        disposeHierarchy(m);
      });
      coinMeshesPoolRef.current.clear();
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

      {/* FLOATING SCORE POPUPS */}
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
                  🪙 {score} pont
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

function create3DCoinMesh(type: string): THREE.Group {
  const group = new THREE.Group();

  if (type === 'cursed') {
    // Obsidian / Cursed Skull Coin
    const coinMat = new THREE.MeshStandardMaterial({
      color: 0x18181b,
      metalness: 0.8,
      roughness: 0.2,
      emissive: 0x7f1d1d,
      emissiveIntensity: 0.5,
    });
    const coin = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 0.08, 16), coinMat);
    coin.rotation.x = Math.PI / 2;
    coin.castShadow = true;
    group.add(coin);

    // Glowing skull emblem dot
    const dot = new THREE.Mesh(
      new THREE.SphereGeometry(0.12, 8, 8),
      new THREE.MeshBasicMaterial({ color: 0xef4444 })
    );
    dot.position.z = 0.05;
    group.add(dot);
  } else if (type === 'gold') {
    // Glowing Star Gold Coin (+5 points)
    const starMat = new THREE.MeshStandardMaterial({
      color: 0xfacc15,
      metalness: 0.9,
      roughness: 0.1,
      emissive: 0xca8a04,
      emissiveIntensity: 0.6,
    });
    const star = new THREE.Mesh(new THREE.OctahedronGeometry(0.35, 0), starMat);
    star.castShadow = true;
    group.add(star);
  } else {
    // Normal Golden Coin (+1 point)
    const coinMat = new THREE.MeshStandardMaterial({
      color: 0xfbbf24,
      metalness: 0.85,
      roughness: 0.15,
      emissive: 0xd97706,
      emissiveIntensity: 0.3,
    });
    const coin = new THREE.Mesh(new THREE.CylinderGeometry(0.30, 0.30, 0.07, 16), coinMat);
    coin.rotation.x = Math.PI / 2;
    coin.castShadow = true;
    group.add(coin);

    // Inner rim
    const inner = new THREE.Mesh(
      new THREE.TorusGeometry(0.22, 0.025, 8, 16),
      new THREE.MeshStandardMaterial({ color: 0xca8a04, metalness: 0.9, roughness: 0.1 })
    );
    group.add(inner);
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
