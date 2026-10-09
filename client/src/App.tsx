import React, { useEffect, useState } from 'react';
import { RoomState } from '@shared/types';
import { socket } from './socket';
import { SOCKET_EVENTS } from '@shared/events';
import { HostView } from './host/HostView';
import { PlayerView } from './player/PlayerView';
import { NetworkTest } from './network/NetworkTest';
import { ControllerTestScreen } from './components/controller/ControllerTestScreen';
import { Tv, Smartphone, Sparkles, Activity, Gamepad2 } from 'lucide-react';
import { sounds } from './audio/soundSynth';

export function App() {
  const [room, setRoom] = useState<RoomState | null>(null);
  const [isConnected, setIsConnected] = useState(socket.connected);

  // Determine mode from URL path or query params
  const path = window.location.pathname;
  const searchParams = new URLSearchParams(window.location.search);
  const roomCodeParam = searchParams.get('room') || '4827';
  
  const isNetworkTest = path === '/network-test' || searchParams.has('network-test');
  const isControllerTest = path === '/controller-test' || searchParams.has('controller-test');
  const isExplicitHost = path === '/host' || searchParams.has('host');
  const isExplicitPlayer = path === '/join' || path === '/play' || searchParams.has('join') || searchParams.has('player');

  const [mode, setMode] = useState<'host' | 'player' | 'select' | 'network-test' | 'controller-test'>(
    isControllerTest ? 'controller-test' : isNetworkTest ? 'network-test' : isExplicitHost ? 'host' : isExplicitPlayer ? 'player' : 'select'
  );

  useEffect(() => {
    const handleConnect = () => setIsConnected(true);
    const handleDisconnect = () => setIsConnected(false);
    const handleRoomState = (newRoom: RoomState) => setRoom(newRoom);

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);
    socket.on(SOCKET_EVENTS.ROOM_STATE, handleRoomState);

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off(SOCKET_EVENTS.ROOM_STATE, handleRoomState);
    };
  }, []);

  if (mode === 'controller-test') {
    return <ControllerTestScreen />;
  }

  if (mode === 'network-test') {
    return <NetworkTest />;
  }

  // Mode Selection Screen (when visiting root without path)
  if (mode === 'select') {
    return (
      <div className="min-h-screen bg-slate-950 text-white flex flex-col items-center justify-center p-6 select-none relative overflow-hidden">
        {/* Glow */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-gradient-to-r from-amber-500/10 via-purple-600/10 to-pink-500/10 blur-3xl rounded-full pointer-events-none" />

        <div className="flex flex-col items-center gap-6 max-w-lg w-full z-10 text-center">
          <div className="w-20 h-20 bg-amber-400 rounded-3xl flex items-center justify-center text-5xl shadow-2xl border-4 border-amber-200 animate-bounce">
            👑
          </div>

          <div>
            <h1 className="text-5xl lg:text-6xl font-black bg-gradient-to-r from-amber-300 via-orange-400 to-pink-500 bg-clip-text text-transparent font-heading tracking-wide">
              PARTY MAYHEM
            </h1>
            <p className="text-slate-400 text-sm font-bold mt-2">
              A KÖZÖS HÁZIBULI-JÁTÉK • TELEFONOS KONTROLLERREL
            </p>
          </div>

          <div className="flex flex-col gap-4 w-full mt-4">
            <button
              onClick={() => {
                sounds.playButton();
                setMode('host');
                window.history.pushState({}, '', '/host');
              }}
              className="w-full py-5 px-6 rounded-3xl bg-slate-900 border-2 border-amber-400/80 hover:border-amber-400 hover:bg-slate-800 text-left flex items-center justify-between shadow-2xl transition-all hover:scale-[1.02] active:scale-95 group"
            >
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-2xl bg-amber-500/20 text-amber-400 flex items-center justify-center text-2xl group-hover:bg-amber-500 group-hover:text-slate-950 transition">
                  <Tv className="w-8 h-8" />
                </div>
                <div>
                  <span className="text-xl font-black text-white block font-heading">
                    HOST / TV KÉPERNYŐ
                  </span>
                  <span className="text-xs text-slate-400 font-bold">
                    3D sziget pálya, minijátékok és eredményhirdetés
                  </span>
                </div>
              </div>
            </button>

            <button
              onClick={() => {
                sounds.playButton();
                setMode('player');
                window.history.pushState({}, '', '/join');
              }}
              className="w-full py-5 px-6 rounded-3xl bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 text-slate-950 text-left flex items-center justify-between shadow-2xl transition-all hover:scale-[1.02] active:scale-95 group hover:brightness-110"
            >
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-2xl bg-slate-950/20 text-slate-950 flex items-center justify-center text-2xl">
                  <Smartphone className="w-8 h-8" />
                </div>
                <div>
                  <span className="text-xl font-black text-slate-950 block font-heading">
                    JÁTÉKOS (TELEFON)
                  </span>
                  <span className="text-xs text-slate-900 font-extrabold">
                    Csatlakozás telefonos kontrollerként
                  </span>
                </div>
              </div>
            </button>

            {/* Diagnostic links */}
            <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
              <button
                onClick={() => {
                  setMode('controller-test');
                  window.history.pushState({}, '', '/controller-test');
                }}
                className="text-xs text-amber-400 hover:text-amber-300 font-mono flex items-center gap-1.5 transition bg-slate-900 px-3 py-1.5 rounded-xl border border-amber-500/30"
              >
                <Gamepad2 className="w-3.5 h-3.5" />
                <span>Kontroller Teszt (/controller-test)</span>
              </button>

              <button
                onClick={() => {
                  setMode('network-test');
                  window.history.pushState({}, '', '/network-test');
                }}
                className="text-xs text-slate-400 hover:text-cyan-400 font-mono flex items-center gap-1.5 transition px-2 py-1.5"
              >
                <Activity className="w-3.5 h-3.5" />
                <span>LAN Teszt</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Host Screen
  if (mode === 'host') {
    return <HostView room={room} roomCode={roomCodeParam} />;
  }

  // Player Controller Screen
  return <PlayerView room={room} defaultRoomCode={roomCodeParam} />;
}

