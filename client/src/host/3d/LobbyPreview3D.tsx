import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { RoomState, Player } from '@shared/types';
import { createPartyBlobMesh, updateBlobHat, animatePartyBlob, PALETTE } from './threeUtils';

interface LobbyPreview3DProps {
  room: RoomState;
}

export const LobbyPreview3D: React.FC<LobbyPreview3DProps> = ({ room }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const blobsMapRef = useRef<Map<string, THREE.Group>>(new Map());
  const animFrameIdRef = useRef<number | null>(null);

  const players = Object.values(room.players).slice(0, 5);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    // 1. Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;

    // 2. Camera
    const aspect = container.clientWidth / container.clientHeight;
    const camera = new THREE.PerspectiveCamera(40, aspect, 0.1, 50);
    camera.position.set(0, 3.2, 7.8);
    camera.lookAt(0, 0.6, 0);

    // 3. Renderer with 30 FPS throttling and DPR capped at 1.5
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.BasicShadowMap;
    rendererRef.current = renderer;
    container.appendChild(renderer.domElement);

    // 4. Lights: 1 Directional + 1 Hemisphere (Ultra lightweight)
    const hemiLight = new THREE.HemisphereLight(0xffffff, 0x444455, 1.2);
    scene.add(hemiLight);

    const dirLight = new THREE.DirectionalLight(0xfff5e6, 1.4);
    dirLight.position.set(5, 8, 5);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 512;
    dirLight.shadow.mapSize.height = 512;
    scene.add(dirLight);

    // 5. Stage Platform with 5 Podiums
    const stageGeo = new THREE.CylinderGeometry(5.2, 5.5, 0.4, 24);
    const stageMat = new THREE.MeshStandardMaterial({
      color: 0x1e293b,
      roughness: 0.6,
      metalness: 0.2
    });
    const stage = new THREE.Mesh(stageGeo, stageMat);
    stage.position.y = -0.2;
    stage.receiveShadow = true;
    scene.add(stage);

    // Ring glow rim
    const rimGeo = new THREE.TorusGeometry(5.2, 0.08, 8, 32);
    rimGeo.rotateX(Math.PI * 0.5);
    const rimMat = new THREE.MeshBasicMaterial({ color: PALETTE.crownGold });
    const rim = new THREE.Mesh(rimGeo, rimMat);
    rim.position.y = 0.02;
    scene.add(rim);

    // 6. Slots Setup (5 Podiums in gentle arc)
    const slotXPositions = [-3.2, -1.6, 0, 1.6, 3.2];
    const slotZPositions = [0.3, 0.1, 0, 0.1, 0.3];

    slotXPositions.forEach((x, i) => {
      const z = slotZPositions[i];
      // Pedestal
      const pedGeo = new THREE.CylinderGeometry(0.65, 0.72, 0.2, 16);
      const pedMat = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.4 });
      const ped = new THREE.Mesh(pedGeo, pedMat);
      ped.position.set(x, 0.05, z);
      ped.receiveShadow = true;
      scene.add(ped);

      // Gold number ring
      const numRingGeo = new THREE.RingGeometry(0.55, 0.62, 16);
      numRingGeo.rotateX(-Math.PI * 0.5);
      const numRing = new THREE.Mesh(numRingGeo, rimMat);
      numRing.position.set(x, 0.16, z);
      scene.add(numRing);
    });

    // 7. Render Loop with 30 FPS Cap
    let lastTime = performance.now();
    const fpsInterval = 1000 / 30; // 30 FPS target

    const animate = (now: number) => {
      animFrameIdRef.current = requestAnimationFrame(animate);

      const elapsed = now - lastTime;
      if (elapsed < fpsInterval) return;
      lastTime = now - (elapsed % fpsInterval);

      const time = now * 0.001;

      // Animate all active blobs with idle procedural animation
      blobsMapRef.current.forEach((blob, playerId) => {
        const playerObj = room.players[playerId];
        const animMode = playerObj?.isReady ? 'celebrate' : 'idle';
        animatePartyBlob(blob, animMode, time + playerId.charCodeAt(0) * 0.2);
      });

      renderer.render(scene, camera);
    };

    animFrameIdRef.current = requestAnimationFrame(animate);

    // Resize handler
    const handleResize = () => {
      if (!container || !renderer) return;
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
      renderer.dispose();
    };
  }, []);

  // Sync 3D Blob characters with connected players
  useEffect(() => {
    const scene = sceneRef.current;
    if (!scene) return;

    const slotXPositions = [-3.2, -1.6, 0, 1.6, 3.2];
    const slotZPositions = [0.3, 0.1, 0, 0.1, 0.3];
    const currentMap = blobsMapRef.current;

    // Remove blobs for players who left
    currentMap.forEach((blob, id) => {
      if (!room.players[id]) {
        scene.remove(blob);
        currentMap.delete(id);
      }
    });

    // Add or update blobs
    players.forEach((player, index) => {
      const targetX = slotXPositions[index];
      const targetZ = slotZPositions[index];

      let blob = currentMap.get(player.id);
      if (!blob) {
        blob = createPartyBlobMesh(player.color, player.cosmetic || 'none');
        blob.position.set(targetX, 0.2, targetZ);
        blob.rotation.y = index < 2 ? 0.25 : index > 2 ? -0.25 : 0;
        scene.add(blob);
        currentMap.set(player.id, blob);
      } else {
        // Update hat if changed
        updateBlobHat(blob, player.cosmetic || 'none');
        blob.position.set(targetX, 0.2, targetZ);
      }
    });
  }, [room.players, players]);

  return (
    <div className="relative w-full h-[320px] rounded-3xl bg-slate-900/60 border border-slate-800 shadow-2xl overflow-hidden backdrop-blur-md">
      {/* 3D Canvas Container */}
      <div ref={containerRef} className="w-full h-full" />

      {/* Floating 2D HUD labels above each pedestal */}
      <div className="absolute inset-x-0 bottom-4 flex justify-around px-2 pointer-events-none">
        {[0, 1, 2, 3, 4].map(idx => {
          const player: Player | undefined = players[idx];
          return (
            <div key={idx} className="flex flex-col items-center min-w-[70px]">
              {player ? (
                <div className="flex flex-col items-center animate-bounce">
                  <div className="flex items-center gap-1 bg-slate-950/80 px-2 py-0.5 rounded-full border border-slate-700 shadow-md">
                    <span
                      className="w-2 h-2 rounded-full"
                      style={{ backgroundColor: player.color }}
                    />
                    <span className="text-[11px] font-black text-white truncate max-w-[70px]">
                      {player.name}
                    </span>
                  </div>
                  <span
                    className={`text-[9px] font-black tracking-wider uppercase mt-0.5 ${
                      player.isReady ? 'text-emerald-400' : 'text-amber-400'
                    }`}
                  >
                    {player.isReady ? 'READY ✅' : 'WAITING ⏳'}
                  </span>
                </div>
              ) : (
                <div className="bg-slate-950/50 px-2 py-0.5 rounded-full border border-dashed border-slate-700 text-slate-500 text-[9px] font-bold">
                  SLOT #{idx + 1}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
