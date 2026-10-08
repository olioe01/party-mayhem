import React, { useEffect } from 'react';
import { RoomState } from '@shared/types';
import { ConfettiEffect } from '../components/Confetti';
import { sounds } from '../audio/soundSynth';
import { AVATARS } from '@shared/constants';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { RotateCcw, Trophy, Crown } from 'lucide-react';

interface HostPodiumProps {
  room: RoomState;
}

export const HostPodium: React.FC<HostPodiumProps> = ({ room }) => {
  useEffect(() => {
    sounds.playVictory();
  }, []);

  const sortedPlayers = Object.values(room.players).sort((a, b) => {
    if (b.crowns !== a.crowns) return b.crowns - a.crowns;
    return b.coins - a.coins;
  });

  const champion = sortedPlayers[0];
  const second = sortedPlayers[1];
  const third = sortedPlayers[2];

  const handleRestart = () => {
    sounds.playGo();
    socket.emit(SOCKET_EVENTS.RESTART_GAME, { roomCode: room.roomCode });
  };

  return (
    <div className="h-screen w-screen bg-slate-950 text-white flex flex-col items-center justify-between p-8 select-none relative overflow-hidden">
      <ConfettiEffect duration={8000} />
      <div className="absolute inset-0 bg-gradient-to-b from-amber-500/20 via-purple-950/20 to-slate-950 pointer-events-none" />

      {/* Top Header */}
      <div className="text-center z-10 flex flex-col items-center gap-2">
        <div className="text-6xl animate-bounce">👑</div>
        <h2 className="text-2xl font-black text-amber-400 uppercase tracking-widest font-heading">
          PARTY MAYHEM CHAMPION
        </h2>
        <h1 className="text-6xl lg:text-7xl font-black text-white font-heading tracking-wide">
          {champion?.name || 'GYŐZTES'}
        </h1>
      </div>

      {/* Podium Steps Area */}
      <div className="flex items-end justify-center gap-6 w-full max-w-4xl h-72 z-10">
        {/* 2nd Place (Silver) */}
        {second && (
          <div className="flex flex-col items-center flex-1 h-full justify-end">
            <div className="flex flex-col items-center mb-2">
              <span className="text-4xl">{AVATARS[second.avatar]?.emoji}</span>
              <span className="font-black text-slate-200 mt-1">{second.name}</span>
              <span className="text-xs font-bold text-slate-400">👑 {second.crowns} • 🪙 {second.coins}</span>
            </div>
            <div className="w-full bg-slate-700/80 border-t-4 border-slate-400 rounded-t-3xl h-44 flex items-center justify-center shadow-xl">
              <span className="text-5xl font-black text-slate-300 font-heading">2</span>
            </div>
          </div>
        )}

        {/* 1st Place (Gold) */}
        {champion && (
          <div className="flex flex-col items-center flex-1 h-full justify-end">
            <div className="flex flex-col items-center mb-2">
              <span className="text-6xl animate-bounce">👑</span>
              <span className="text-5xl">{AVATARS[champion.avatar]?.emoji}</span>
              <span className="text-xl font-black text-amber-300 mt-1">{champion.name}</span>
              <span className="text-sm font-black text-amber-400">👑 {champion.crowns} • 🪙 {champion.coins}</span>
            </div>
            <div className="w-full bg-gradient-to-t from-amber-600 to-amber-400 border-t-4 border-yellow-200 rounded-t-3xl h-60 flex items-center justify-center shadow-2xl">
              <span className="text-7xl font-black text-slate-950 font-heading">1</span>
            </div>
          </div>
        )}

        {/* 3rd Place (Bronze) */}
        {third && (
          <div className="flex flex-col items-center flex-1 h-full justify-end">
            <div className="flex flex-col items-center mb-2">
              <span className="text-4xl">{AVATARS[third.avatar]?.emoji}</span>
              <span className="font-black text-slate-200 mt-1">{third.name}</span>
              <span className="text-xs font-bold text-slate-400">👑 {third.crowns} • 🪙 {third.coins}</span>
            </div>
            <div className="w-full bg-amber-900/80 border-t-4 border-amber-600 rounded-t-3xl h-32 flex items-center justify-center shadow-xl">
              <span className="text-5xl font-black text-amber-500 font-heading">3</span>
            </div>
          </div>
        )}
      </div>

      {/* Bottom Rematch Controls */}
      <div className="z-10 mt-6 flex flex-col items-center gap-4">
        <button
          onClick={handleRestart}
          className="bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 hover:brightness-110 text-slate-950 font-black text-xl py-4 px-10 rounded-2xl shadow-2xl flex items-center gap-3 transition-transform hover:scale-105 active:scale-95"
        >
          <RotateCcw className="w-6 h-6" />
          <span>REMATCH / ÚJ JÁTÉK</span>
        </button>
      </div>
    </div>
  );
};
