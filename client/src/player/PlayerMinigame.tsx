import React from 'react';
import { RoomState, Player } from '@shared/types';
import { MinigamePlayerRenderer } from '../minigames/MinigamePlayerRenderer';
import { SoundToggle } from '../components/SoundToggle';
import { Award, Timer, CheckCircle2, Flame } from 'lucide-react';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { sounds } from '../audio/soundSynth';

import { GamepadController } from '../components/controller/GamepadController';

interface PlayerMinigameProps {
  room: RoomState;
  player: Player;
}

export const PlayerMinigame: React.FC<PlayerMinigameProps> = ({ room, player }) => {
  const mg = room.activeMinigame;
  if (!mg) return null;

  const isReady = Boolean(player.minigameReady);

  const handleReady = () => {
    sounds.playButton();
    socket.emit(SOCKET_EVENTS.MINIGAME_READY, { roomCode: room.roomCode });
  };

  // 1. INTRO & TUTORIAL (Waiting for player to press READY)
  if (room.phase === 'MINIGAME_INTRO') {
    return (
      <div className="min-h-screen bg-slate-950 text-white flex flex-col p-6 items-center justify-between text-center select-none">
        <div className="flex items-center justify-between w-full border-b border-slate-800 pb-3">
          <span className="text-xs font-black uppercase tracking-widest text-amber-400">
            MINIJÁTÉK FELKÉSZÜLÉS
          </span>
          <SoundToggle />
        </div>

        <div className="flex flex-col items-center gap-4 my-auto max-w-sm w-full">
          <span className="text-5xl animate-bounce">🎮</span>
          <div>
            <h2 className="text-3xl font-black text-white font-heading">
              {mg.name}
            </h2>
            <p className="text-xs text-slate-400 font-bold mt-1">
              {mg.description}
            </p>
          </div>

          <div className="bg-slate-900 border-2 border-amber-400/80 p-5 rounded-3xl w-full text-left shadow-2xl">
            <span className="text-xs font-black text-amber-400 uppercase tracking-wider block mb-2">
              📖 HOGYAN JÁTSSZ?
            </span>
            <p className="text-sm font-black text-amber-200 leading-relaxed">
              {mg.instructions}
            </p>
          </div>

          <div className="w-full mt-2">
            {!isReady ? (
              <button
                onClick={handleReady}
                className="w-full py-5 rounded-2xl bg-gradient-to-r from-emerald-400 via-teal-400 to-cyan-400 text-slate-950 font-black text-xl shadow-2xl active:scale-95 flex items-center justify-center gap-2 transform hover:scale-[1.02] transition-all border-2 border-white"
              >
                <CheckCircle2 className="w-6 h-6" />
                <span>KÉSZEN ÁLLOK! (I'M READY)</span>
              </button>
            ) : (
              <div className="w-full py-5 rounded-2xl bg-emerald-950/80 border-2 border-emerald-400 text-emerald-300 font-black text-xl flex items-center justify-center gap-2 shadow-xl animate-pulse">
                <CheckCircle2 className="w-6 h-6 text-emerald-400" />
                <span>READY ✓ (VÁRAKOZÁS A TÖBBIEKRE...)</span>
              </div>
            )}
          </div>
        </div>

        <p className="text-slate-500 text-[11px] font-bold">
          A játék akkor indul, ha mindenki megnyomta a Ready gombot!
        </p>
      </div>
    );
  }

  // 1.5. COUNTDOWN PHASE: EVERYONE IS READY! 3... 2... 1...
  if (room.phase === 'MINIGAME_COUNTDOWN') {
    return (
      <div className="min-h-screen bg-slate-950 text-white flex flex-col p-6 items-center justify-center text-center gap-6 select-none">
        <Flame className="w-16 h-16 text-amber-400 animate-bounce" />
        <div>
          <span className="text-xs uppercase font-black tracking-widest text-emerald-400 bg-emerald-500/10 px-4 py-1.5 rounded-full border border-emerald-500/30 inline-block mb-3">
            MINDENKI KÉSZEN ÁLL!
          </span>
          <h2 className="text-4xl font-black text-white font-heading">
            {mg.name}
          </h2>
        </div>
        <div className="bg-slate-900 border-2 border-amber-400 p-6 rounded-3xl max-w-xs w-full shadow-2xl animate-pulse">
          <span className="text-amber-300 font-black text-lg block">
            INDULÁS!
          </span>
          <p className="text-xs text-slate-400 font-bold mt-1">
            Figyeld a TV-t és a telefonodat!
          </p>
        </div>
      </div>
    );
  }

  // 2. ACTIVE PLAY
  if (room.phase === 'MINIGAME_PLAY') {
    if (mg.controllerConfig?.layout === 'gamepad') {
      let scoreDisplay: React.ReactNode = undefined;
      if (mg.id === 'fruit-frenzy') {
        const s = mg.data?.scores?.[player.id] ?? 0;
        scoreDisplay = <span>{s} 🍎</span>;
      } else if (mg.data?.scores?.[player.id] !== undefined) {
        scoreDisplay = <span>{mg.data.scores[player.id]} pts</span>;
      }

      return (
        <GamepadController
          room={room}
          player={player}
          config={mg.controllerConfig}
          scoreDisplay={scoreDisplay}
        />
      );
    }

    return (
      <div className="min-h-screen bg-slate-950 text-white flex flex-col select-none overflow-hidden justify-between">
        {/* Top HUD */}
        <div className="flex items-center justify-between p-4 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md">
          <div className="flex items-center gap-2">
            <span className="font-extrabold text-sm">{mg.name}</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1 font-mono font-black text-amber-400 text-sm bg-slate-800 px-3 py-1 rounded-xl">
              <Timer className="w-4 h-4" />
              <span>{Math.ceil(mg.timeRemaining)}s</span>
            </div>
            <SoundToggle />
          </div>
        </div>

        {/* Controller View */}
        <div className="flex-1 my-auto flex flex-col items-center justify-center">
          <MinigamePlayerRenderer room={room} playerId={player.id} />
        </div>
      </div>
    );
  }

  // 3. RESULTS
  if (room.phase === 'MINIGAME_RESULTS') {
    const myResult = mg.results?.find(r => r.playerId === player.id);

    return (
      <div className="min-h-screen bg-slate-950 text-white flex flex-col p-6 items-center justify-center text-center gap-6 select-none">
        <Award className="w-16 h-16 text-amber-400 animate-bounce" />
        <div>
          <span className="text-xs uppercase font-black tracking-widest text-slate-400 block mb-1">
            EREDMÉNY
          </span>
          <h2 className="text-4xl font-black text-white font-heading">
            {myResult ? `#${myResult.rank}. HELYEZÉS` : 'SZÉP JÁTÉK!'}
          </h2>
        </div>

        {myResult && (
          <div className="bg-slate-900 border-2 border-amber-400 p-6 rounded-3xl max-w-xs w-full flex flex-col items-center gap-2 shadow-2xl">
            <span className="text-4xl font-black text-amber-300 font-mono">
              +{myResult.coinsEarned} 🪙
            </span>
            <span className="text-xs text-slate-400 font-bold">
              {myResult.extraInfo || 'Jutalom jóváírva!'}
            </span>
          </div>
        )}

        <p className="text-slate-400 text-xs font-bold">
          Nézz a TV-re a teljes ranglistáért!
        </p>
      </div>
    );
  }

  return null;
};
