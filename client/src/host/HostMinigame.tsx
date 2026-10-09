import React, { useEffect, useState } from 'react';
import { RoomState } from '@shared/types';
import { MinigameHostRenderer } from '../minigames/MinigameHostRenderer';
import { ConfettiEffect } from '../components/Confetti';
import { SoundToggle } from '../components/SoundToggle';
import { sounds } from '../audio/soundSynth';
import { AVATARS } from '@shared/constants';
import { Timer, Award, FastForward, CheckCircle2, Clock, WifiOff, Play } from 'lucide-react';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';

interface HostMinigameProps {
  room: RoomState;
}

export const HostMinigame: React.FC<HostMinigameProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const [countdownNum, setCountdownNum] = useState(3);
  const [demoStep, setDemoStep] = useState(0);

  // Visual demo animation loop (cycles every 4 seconds)
  useEffect(() => {
    if (room.phase === 'MINIGAME_INTRO') {
      const demoInterval = setInterval(() => {
        setDemoStep(prev => (prev + 1) % 4);
      }, 1000);
      return () => clearInterval(demoInterval);
    }
  }, [room.phase]);

  // Countdown sound effects
  useEffect(() => {
    if (room.phase === 'MINIGAME_COUNTDOWN') {
      setCountdownNum(3);
      sounds.playCountdown();
      const interval = setInterval(() => {
        setCountdownNum(prev => {
          if (prev <= 1) {
            sounds.playGo();
            return 0;
          }
          sounds.playCountdown();
          return prev - 1;
        });
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [room.phase]);

  // Play win fanfare when RESULTS appear
  useEffect(() => {
    if (room.phase === 'MINIGAME_RESULTS') {
      sounds.playWin();
    }
  }, [room.phase]);

  if (!mg) return null;

  const handleSkip = () => {
    socket.emit(SOCKET_EVENTS.SKIP_MINIGAME, { roomCode: room.roomCode });
  };

  const handleStartAnyway = () => {
    socket.emit(SOCKET_EVENTS.MINIGAME_HOST_OVERRIDE, { roomCode: room.roomCode });
  };

  const playersList = Object.values(room.players);
  const activePlayers = playersList.filter(p => p.connected || p.isBot);
  const readyCount = activePlayers.filter(p => p.minigameReady).length;
  const totalCount = activePlayers.length;

  // 1. INTRO & TUTORIAL PHASE: Instructions, Visual Demo & Player Ready Checklist
  if (room.phase === 'MINIGAME_INTRO') {
    return (
      <div className="h-screen w-screen bg-slate-950 text-white flex flex-col p-6 lg:p-8 select-none relative overflow-hidden">
        {/* Background Atmosphere */}
        <div className="absolute inset-0 bg-gradient-to-br from-purple-950/40 via-slate-950 to-indigo-950/30 pointer-events-none" />

        {/* Top Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-800 shrink-0 z-10">
          <div className="flex items-center gap-3">
            <span className="text-xs font-black uppercase tracking-widest text-amber-400 bg-amber-500/10 px-4 py-1.5 rounded-full border border-amber-500/30">
              MINIJÁTÉK INSTRUKCIÓK
            </span>
          </div>

          <div className="flex items-center gap-3">
            <SoundToggle />
            <button
              onClick={handleSkip}
              className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
              title="Átugrás"
            >
              <FastForward className="w-5 h-5 text-amber-400" />
            </button>
          </div>
        </div>

        {/* Two-column Layout: Left (Info & Demo), Right (Ready status) */}
        <div className="flex-1 grid grid-cols-12 gap-6 my-auto items-center z-10 max-w-7xl mx-auto w-full pt-2">
          {/* Left Column (7 cols): Game Title, Rules & Visual Demonstration */}
          <div className="col-span-7 bg-slate-900/90 border-4 border-amber-400/80 p-8 rounded-3xl shadow-2xl backdrop-blur-xl flex flex-col gap-5">
            <div>
              <span className="text-xs font-black uppercase tracking-wider text-amber-400 block mb-1">
                KÖVETKEZŐ JÁTÉK:
              </span>
              <h1 className="text-5xl font-black text-white font-heading tracking-wide">
                {mg.name}
              </h1>
              <p className="text-lg text-slate-300 font-bold mt-1">
                {mg.description}
              </p>
            </div>

            <div className="bg-slate-800/90 border-2 border-slate-700 p-4 rounded-2xl">
              <span className="text-xs font-black uppercase tracking-wider text-amber-300 block mb-1">
                💡 SZABÁLYOK / HOGYAN JÁTSSZ:
              </span>
              <p className="text-base font-extrabold text-amber-200">
                {mg.instructions}
              </p>
            </div>

            {/* Visual Demonstration Mockup Animation */}
            <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 flex flex-col items-center justify-center min-h-[140px] text-center gap-2">
              <span className="text-[11px] font-black uppercase tracking-widest text-slate-500">
                GYORS VIZUÁLIS BEMUTATÓ
              </span>
              
              {mg.id === 'reaction-rush' ? (
                <div className="flex items-center gap-6 mt-1">
                  <div className={`px-6 py-3 rounded-2xl font-black text-lg font-mono transition-all duration-300 ${
                    demoStep < 2 
                      ? 'bg-amber-500/20 text-amber-300 border border-amber-400/40 animate-pulse' 
                      : 'bg-emerald-500 text-slate-950 scale-110 shadow-lg'
                  }`}>
                    {demoStep < 2 ? '⏳ VÁRJ...' : '🟢 GO! NYOMD!'}
                  </div>
                  <div className={`text-4xl transition-transform duration-200 ${demoStep >= 2 ? 'scale-125 -translate-y-1' : 'opacity-40'}`}>
                    👆
                  </div>
                </div>
              ) : mg.id === 'shake-it' ? (
                <div className="flex items-center gap-6 mt-1">
                  <span className="text-5xl animate-bounce">🚀</span>
                  <div className="bg-purple-600/30 border border-purple-400 px-5 py-2.5 rounded-2xl text-purple-200 font-black text-base animate-pulse">
                    📱 RÁZD VAGY TAPELD!
                  </div>
                </div>
              ) : mg.id === 'bomb-pass' ? (
                <div className="flex items-center gap-4 mt-1">
                  <span className="text-4xl animate-bounce">💣</span>
                  <span className="text-2xl text-amber-400 font-mono font-black animate-pulse">➡️</span>
                  <span className="text-3xl">👥</span>
                  <span className="text-xs font-black text-amber-300 ml-2">ADD TOVÁBB GYORSAN!</span>
                </div>
              ) : (
                <div className="flex items-center gap-4 mt-1">
                  <div className="w-14 h-14 rounded-2xl bg-amber-500/20 border-2 border-amber-400 flex items-center justify-center text-3xl animate-bounce">
                    🎮
                  </div>
                  <span className="text-sm font-black text-slate-200">
                    Kövesd az utasításokat a telefonodon!
                  </span>
                </div>
              )}
            </div>

            <p className="text-xs text-slate-400 font-bold">
              📱 Olvasd el a telefonodon a leírást, és nyomd meg a <strong className="text-emerald-400">KÉSZEN ÁLLOK</strong> gombot!
            </p>
          </div>

          {/* Right Column (5 cols): Player Ready Checklist & Status */}
          <div className="col-span-5 bg-slate-900/90 border-2 border-slate-800 p-7 rounded-3xl shadow-2xl flex flex-col justify-between gap-5 backdrop-blur-xl">
            <div>
              <div className="flex items-center justify-between pb-3 border-b border-slate-800 mb-4">
                <div className="flex items-center gap-2">
                  <Clock className="w-5 h-5 text-amber-400" />
                  <span className="text-base font-black uppercase tracking-wider text-white">
                    JÁTÉKOSOK ÁLLAPOTA
                  </span>
                </div>
                <div className="bg-amber-500/20 border border-amber-400/40 px-3 py-1 rounded-xl text-amber-300 font-mono font-black text-sm">
                  {readyCount} / {totalCount} READY
                </div>
              </div>

              {/* Player list items */}
              <div className="flex flex-col gap-2.5 max-h-[320px] overflow-y-auto pr-1">
                {playersList.map(player => {
                  const avatar = AVATARS[player.avatar] || AVATARS['fox'];
                  const isReady = player.minigameReady;
                  const isDisc = !player.connected && !player.isBot;

                  return (
                    <div
                      key={player.id}
                      className={`p-3 rounded-2xl flex items-center justify-between border transition-all ${
                        isReady
                          ? 'bg-emerald-950/40 border-emerald-500/60 text-white'
                          : isDisc
                          ? 'bg-amber-950/40 border-amber-500/50 text-amber-200'
                          : 'bg-slate-800/60 border-slate-700/80 text-slate-300'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-2xl">{avatar.emoji}</span>
                        <div>
                          <span className="font-black text-sm block leading-none">
                            {player.name}
                          </span>
                          {isDisc && (
                            <span className="text-[10px] text-amber-400 font-bold flex items-center gap-1 mt-0.5">
                              <WifiOff className="w-3 h-3 inline" /> Reconnecting...
                            </span>
                          )}
                        </div>
                      </div>

                      <div>
                        {isReady ? (
                          <div className="flex items-center gap-1.5 text-xs font-black text-emerald-400 bg-emerald-500/20 px-2.5 py-1 rounded-lg">
                            <CheckCircle2 className="w-4 h-4" />
                            <span>READY ✓</span>
                          </div>
                        ) : (
                          <div className="flex items-center gap-1.5 text-xs font-bold text-slate-400 bg-slate-800 px-2.5 py-1 rounded-lg">
                            <Clock className="w-3.5 h-3.5 animate-spin" />
                            <span>Olvas...</span>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Host Override Button (Shown if someone is lagging or disconnected) */}
            {readyCount >= 1 && readyCount < totalCount && (
              <div className="pt-2 border-t border-slate-800">
                <button
                  onClick={handleStartAnyway}
                  className="w-full py-3.5 rounded-2xl bg-amber-500/20 hover:bg-amber-500/30 border-2 border-amber-400 text-amber-300 font-black text-sm flex items-center justify-center gap-2 shadow-lg active:scale-95 transition"
                >
                  <Play className="w-4 h-4 text-amber-400" />
                  <span>INDÍTÁS ENNYI JÁTÉKOSSAL (START ANYWAY)</span>
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  // 1.5. COUNTDOWN PHASE: EVERYONE IS READY! 3... 2... 1... GO!
  if (room.phase === 'MINIGAME_COUNTDOWN') {
    return (
      <div className="h-screen w-screen bg-slate-950 text-white flex flex-col items-center justify-center p-8 select-none relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-emerald-950/40 via-slate-950 to-slate-950 pointer-events-none" />

        <div className="bg-slate-900/95 border-4 border-emerald-400 p-12 lg:p-16 rounded-3xl shadow-2xl max-w-2xl w-full text-center flex flex-col items-center gap-6 backdrop-blur-2xl z-10 animate-fade-in">
          <span className="text-sm font-black uppercase tracking-widest text-emerald-400 bg-emerald-500/10 px-5 py-2 rounded-full border border-emerald-500/30">
            MINDENKI KÉSZEN ÁLL! (EVERYONE IS READY!)
          </span>

          <h1 className="text-5xl font-black text-white font-heading tracking-wide">
            {mg.name}
          </h1>

          <div className="my-6">
            <span className="text-8xl lg:text-9xl font-black text-amber-400 font-mono tracking-tighter animate-ping">
              {countdownNum > 0 ? countdownNum : 'GO!'}
            </span>
          </div>

          <p className="text-slate-400 text-sm font-bold">
            A minijáték azonnal kezdődik!
          </p>
        </div>
      </div>
    );
  }

  // 2. ACTIVE PLAY PHASE
  if (room.phase === 'MINIGAME_PLAY') {
    const timeLeft = Math.ceil(mg.timeRemaining);
    return (
      <div className="h-screen w-screen bg-slate-950 text-white flex flex-col p-6 select-none overflow-hidden relative">
        {/* Top Header */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-800 shrink-0">
          <div className="flex items-center gap-3">
            <span className="text-3xl">🎮</span>
            <div>
              <h2 className="text-3xl font-black text-amber-300 font-heading">
                {mg.name}
              </h2>
              <p className="text-xs text-slate-400 font-bold">{mg.instructions}</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            {/* Timer Badge */}
            <div className="flex items-center gap-2 bg-slate-900 border-2 border-amber-400/80 px-6 py-2 rounded-2xl shadow-xl">
              <Timer className="w-6 h-6 text-amber-400" />
              <span className="text-3xl font-black text-white font-mono">
                {timeLeft}s
              </span>
            </div>

            <SoundToggle />

            <button
              onClick={handleSkip}
              className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
              title="Átugrás"
            >
              <FastForward className="w-5 h-5 text-amber-400" />
            </button>
          </div>
        </div>

        {/* Minigame Arena */}
        <div className="flex-1 min-h-0 relative my-2 bg-slate-900/60 rounded-3xl border border-slate-800 shadow-2xl p-2 sm:p-4 backdrop-blur-md overflow-hidden">
          <MinigameHostRenderer room={room} />
        </div>
      </div>
    );
  }

  // 3. RESULTS PHASE
  if (room.phase === 'MINIGAME_RESULTS') {
    const results = mg.results || [];
    return (
      <div className="h-screen w-screen bg-slate-950 text-white flex flex-col items-center justify-center p-8 select-none relative overflow-hidden">
        <ConfettiEffect duration={4500} />

        <div className="bg-slate-900/90 border-4 border-amber-400/80 p-8 lg:p-12 rounded-3xl shadow-2xl max-w-4xl w-full flex flex-col items-center gap-6 backdrop-blur-2xl z-10 animate-fade-in">
          <div className="flex items-center gap-3">
            <Award className="w-10 h-10 text-amber-400" />
            <h1 className="text-4xl lg:text-5xl font-black text-amber-300 font-heading">
              MINIJÁTÉK EREDMÉNYEK
            </h1>
          </div>

          <div className="flex flex-col gap-3 w-full mt-4">
            {results.map((res, index) => {
              const player = room.players[res.playerId];
              if (!player) return null;
              const avatar = AVATARS[player.avatar] || AVATARS['fox'];
              const medals = ['🥇', '🥈', '🥉', '4.', '5.', '6.', '7.', '8.'];

              return (
                <div
                  key={res.playerId}
                  className={`p-4 rounded-2xl flex items-center justify-between shadow-lg transition-transform ${
                    index === 0
                      ? 'bg-amber-500/25 border-2 border-amber-400 scale-105'
                      : 'bg-slate-800/80 border border-slate-700'
                  }`}
                >
                  <div className="flex items-center gap-4">
                    <span className="text-3xl font-black font-mono w-10 text-center">
                      {medals[index] || `#${index + 1}`}
                    </span>
                    <span className="text-4xl">{avatar.emoji}</span>
                    <div>
                      <span className="text-xl font-black text-white block">
                        {player.name}
                      </span>
                      {res.extraInfo && (
                        <span className="text-xs text-slate-400 font-bold">
                          {res.extraInfo}
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="text-2xl font-black text-amber-300 font-mono">
                      +{res.coinsEarned} 🪙
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  return null;
};
