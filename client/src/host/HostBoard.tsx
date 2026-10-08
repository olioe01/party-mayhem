import React, { useEffect, useState } from 'react';
import { RoomState, TileType } from '@shared/types';
import { BOARD_TILES } from '@shared/boardData';
import { AVATARS } from '@shared/constants';
import { Scoreboard } from '../components/Scoreboard';
import { SoundToggle } from '../components/SoundToggle';
import { HostBoard3D } from './3d/HostBoard3D';
import { sounds } from '../audio/soundSynth';
import {
  Crown,
  Sparkles,
  Pause,
  Play,
  FastForward,
  RotateCcw,
  Maximize2,
  Minimize2,
  Box,
  Layers,
  WifiOff
} from 'lucide-react';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';

interface HostBoardProps {
  room: RoomState;
}

export const HostBoard: React.FC<HostBoardProps> = ({ room }) => {
  const [viewMode, setViewMode] = useState<'3d' | '2d'>('3d');
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [welcomeBackToast, setWelcomeBackToast] = useState<string | null>(null);

  const activePlayerId = room.playerOrder[room.currentPlayerIndex];
  const activePlayer = room.players[activePlayerId];

  // Ambient board background music lifecycle & user-interaction audio unlock
  useEffect(() => {
    sounds.startAmbientMusic();

    const handleFirstInteraction = () => {
      sounds.startAmbientMusic();
      window.removeEventListener('click', handleFirstInteraction);
      window.removeEventListener('keydown', handleFirstInteraction);
      window.removeEventListener('touchstart', handleFirstInteraction);
    };

    window.addEventListener('click', handleFirstInteraction, { once: true });
    window.addEventListener('keydown', handleFirstInteraction, { once: true });
    window.addEventListener('touchstart', handleFirstInteraction, { once: true });

    return () => {
      sounds.stopAmbientMusic();
      window.removeEventListener('click', handleFirstInteraction);
      window.removeEventListener('keydown', handleFirstInteraction);
      window.removeEventListener('touchstart', handleFirstInteraction);
    };
  }, []);

  // Duck music when tile effect action is resolving
  useEffect(() => {
    if (room.phase === 'BOARD_ACTION') {
      sounds.setMusicDuck(true);
    } else {
      sounds.setMusicDuck(false);
    }
  }, [room.phase]);

  // Show "BENCE IS BACK!" toast on reconnect
  useEffect(() => {
    if (room.lastReconnectedPlayer) {
      const diff = Date.now() - room.lastReconnectedPlayer.timestamp;
      if (diff < 4000) {
        setWelcomeBackToast(room.lastReconnectedPlayer.name);
        sounds.playGo();
        const t = setTimeout(() => setWelcomeBackToast(null), 3500);
        return () => clearTimeout(t);
      }
    }
  }, [room.lastReconnectedPlayer]);

  // Play sound on dice roll or tile action
  useEffect(() => {
    if (room.lastDiceRoll) {
      sounds.playDice();
    }
  }, [room.lastDiceRoll]);

  useEffect(() => {
    if (room.currentTileEffect) {
      if (room.currentTileEffect.type === 'GOLD' || room.currentTileEffect.type === 'JACKPOT') {
        sounds.playCoin();
      } else if (room.currentTileEffect.type === 'RED') {
        sounds.playWrong();
      } else if (room.currentTileEffect.type === 'CHAOS') {
        sounds.playEvent();
      } else if (room.currentTileEffect.type === 'TELEPORT') {
        sounds.playTeleport();
      } else {
        sounds.playButton();
      }
    }
  }, [room.currentTileEffect]);

  const tileColors: Record<TileType, { bg: string; border: string; text: string; icon: string }> = {
    BLUE: { bg: 'bg-blue-600/30', border: 'border-blue-400', text: 'text-blue-300', icon: '💎' },
    GOLD: { bg: 'bg-amber-500/40', border: 'border-amber-300', text: 'text-amber-200', icon: '💰' },
    RED: { bg: 'bg-red-600/30', border: 'border-red-400', text: 'text-red-300', icon: '💥' },
    DUEL: { bg: 'bg-purple-600/30', border: 'border-purple-400', text: 'text-purple-300', icon: '⚔️' },
    STEAL: { bg: 'bg-emerald-600/30', border: 'border-emerald-400', text: 'text-emerald-300', icon: '🗡️' },
    SWAP: { bg: 'bg-cyan-600/30', border: 'border-cyan-400', text: 'text-cyan-300', icon: '🔄' },
    CHAOS: { bg: 'bg-fuchsia-600/40', border: 'border-fuchsia-300', text: 'text-fuchsia-200', icon: '🌀' },
    SECRET: { bg: 'bg-indigo-600/30', border: 'border-indigo-400', text: 'text-indigo-300', icon: '🤫' },
    BOOST: { bg: 'bg-teal-600/30', border: 'border-teal-400', text: 'text-teal-300', icon: '⚡' },
    TRAP: { bg: 'bg-orange-700/40', border: 'border-orange-500', text: 'text-orange-300', icon: '🪤' },
    TELEPORT: { bg: 'bg-violet-600/30', border: 'border-violet-400', text: 'text-violet-300', icon: '🚀' },
    JACKPOT: { bg: 'bg-yellow-400/50', border: 'border-yellow-200', text: 'text-yellow-100', icon: '🎰' }
  };

  const handlePause = () => {
    socket.emit(SOCKET_EVENTS.PAUSE_GAME, { roomCode: room.roomCode, isPaused: !room.isPaused });
  };

  const handleSkip = () => {
    socket.emit(SOCKET_EVENTS.SKIP_MINIGAME, { roomCode: room.roomCode });
  };

  const handleRestart = () => {
    if (confirm('Biztosan újraindítod a meccset?')) {
      socket.emit(SOCKET_EVENTS.RESTART_GAME, { roomCode: room.roomCode });
    }
  };

  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
      setIsFullscreen(true);
    } else {
      document.exitFullscreen().catch(() => {});
      setIsFullscreen(false);
    }
  };

  // Find disconnected players
  const disconnectedPlayers = Object.values(room.players).filter(p => !p.connected && !p.isBot);

  return (
    <div className="h-screen w-screen bg-slate-950 text-white flex flex-col p-4 lg:p-6 overflow-hidden select-none relative">
      {/* "BENCE IS BACK!" celebration toast */}
      {welcomeBackToast && (
        <div className="absolute top-20 left-1/2 -translate-x-1/2 z-50 bg-gradient-to-r from-amber-400 to-pink-500 text-slate-950 font-black px-8 py-3.5 rounded-3xl shadow-2xl flex items-center gap-3 text-lg animate-bounce border-4 border-white">
          <Sparkles className="w-6 h-6 animate-spin" />
          <span>{welcomeBackToast.toUpperCase()} IS BACK! 🎉</span>
        </div>
      )}

      {/* Disconnected Player Warning Bar */}
      {disconnectedPlayers.length > 0 && (
        <div className="absolute top-2 left-1/2 -translate-x-1/2 z-40 bg-amber-500/90 text-slate-950 px-5 py-1.5 rounded-full font-black text-xs flex items-center gap-2 shadow-lg backdrop-blur-md">
          <WifiOff className="w-4 h-4 animate-pulse" />
          <span>
            {disconnectedPlayers.map(p => p.name).join(', ')} újracsatlakozik... (Reconnecting)
          </span>
        </div>
      )}

      {/* Top Header Bar */}
      <div className="flex items-center justify-between pb-3 border-b border-slate-800 shrink-0">
        <div className="flex items-center gap-4">
          <div className="bg-amber-500/20 border border-amber-400/40 px-4 py-1.5 rounded-2xl flex items-center gap-2">
            <span className="text-amber-400 font-black text-sm uppercase tracking-wider">KÖR</span>
            <span className="text-2xl font-black text-white font-mono">
              {room.currentRound} / {room.totalRounds}
            </span>
          </div>

          <div className="bg-slate-900 border border-slate-800 px-4 py-1.5 rounded-2xl flex items-center gap-2">
            <Crown className="w-5 h-5 text-amber-400" />
            <span className="text-xs text-slate-400 font-bold uppercase tracking-wider">Crown Shop:</span>
            <span className="text-sm font-black text-amber-300 font-mono">
              Mező #{room.crownShopTileId} (25🪙)
            </span>
          </div>
        </div>

        {/* Turn Status Message */}
        <div className="flex items-center gap-3">
          {activePlayer && (
            <div className="flex items-center gap-3 bg-slate-900/90 border-2 border-amber-400/80 px-6 py-2 rounded-2xl shadow-xl animate-pulse">
              <span className="text-2xl">{AVATARS[activePlayer.avatar]?.emoji}</span>
              <div>
                <span className="text-xs text-slate-400 font-black uppercase tracking-wider block">
                  AKTUÁLIS KÖR:
                </span>
                <span className="text-lg font-black text-amber-300" style={{ color: activePlayer.color }}>
                  {activePlayer.name}
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Host Controls */}
        <div className="flex items-center gap-2">
          {/* 3D / 2D toggle */}
          <button
            onClick={() => setViewMode(viewMode === '3d' ? '2d' : '3d')}
            className={`p-2.5 rounded-xl border flex items-center gap-1.5 text-xs font-bold transition ${
              viewMode === '3d'
                ? 'bg-purple-600/30 border-purple-400 text-purple-300'
                : 'bg-slate-800 border-slate-700 text-slate-400'
            }`}
            title="3D / 2D Nézet váltás"
          >
            {viewMode === '3d' ? <Box className="w-4 h-4" /> : <Layers className="w-4 h-4" />}
            <span className="hidden sm:inline">{viewMode === '3d' ? '3D PÁLYA' : '2D PÁLYA'}</span>
          </button>

          {/* Fullscreen toggle */}
          <button
            onClick={toggleFullscreen}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
            title={isFullscreen ? 'Kilépés a teljes képernyőből' : 'Teljes képernyő (ENTER FULLSCREEN)'}
          >
            {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
          </button>

          <SoundToggle />

          <button
            onClick={handlePause}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
            title="Szünet"
          >
            {room.isPaused ? <Play className="w-4 h-4 text-emerald-400" /> : <Pause className="w-4 h-4" />}
          </button>
          <button
            onClick={handleSkip}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
            title="Lépés átugrása"
          >
            <FastForward className="w-4 h-4 text-amber-400" />
          </button>
          <button
            onClick={handleRestart}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
            title="Újraindítás"
          >
            <RotateCcw className="w-4 h-4 text-red-400" />
          </button>
        </div>
      </div>

      {/* Main Board Viewport */}
      <div className="flex-1 grid grid-cols-12 gap-4 mt-3 min-h-0 relative">
        {/* Board Area (9 Cols) */}
        <div className="col-span-9 relative bg-slate-900/60 rounded-3xl border border-slate-800 shadow-2xl overflow-hidden backdrop-blur-md">
          {viewMode === '3d' ? (
            /* 3D Party Board */
            <HostBoard3D room={room} quality="AUTO" />
          ) : (
            /* 2D Fallback View */
            <div className="relative w-full h-full">
              {/* SVG Connection Lines between Tiles */}
              <svg className="absolute inset-0 w-full h-full pointer-events-none">
                {BOARD_TILES.map((tile) => {
                  const nextTile = BOARD_TILES.find(t => t.id === ((tile.id + 1) % BOARD_TILES.length));
                  if (!nextTile) return null;
                  return (
                    <line
                      key={`line-${tile.id}`}
                      x1={`${tile.x}%`}
                      y1={`${tile.y}%`}
                      x2={`${nextTile.x}%`}
                      y2={`${nextTile.y}%`}
                      stroke="rgba(255,255,255,0.15)"
                      strokeWidth="4"
                      strokeDasharray={tile.isDangerous ? '6,6' : undefined}
                    />
                  );
                })}
              </svg>

              {/* Render 36 Tiles in 2D */}
              {BOARD_TILES.map((tile) => {
                const conf = tileColors[tile.type] || tileColors.BLUE;
                const isCrownShop = tile.id === room.crownShopTileId;
                const playersHere = Object.values(room.players).filter(p => p.boardPosition === tile.id);

                return (
                  <div
                    key={tile.id}
                    className={`absolute -translate-x-1/2 -translate-y-1/2 rounded-2xl flex flex-col items-center justify-center p-1.5 transition-transform duration-300 shadow-lg border-2 ${
                      conf.bg
                    } ${conf.border} ${isCrownShop ? 'ring-4 ring-amber-400 ring-offset-2 ring-offset-slate-950 scale-125 z-20 animate-pulse' : 'z-10'}`}
                    style={{
                      left: `${tile.x}%`,
                      top: `${tile.y}%`,
                      width: '56px',
                      height: '56px'
                    }}
                  >
                    {isCrownShop ? (
                      <div className="text-2xl animate-bounce">👑</div>
                    ) : (
                      <div className="text-xl">{conf.icon}</div>
                    )}
                    <span className={`text-[9px] font-black tracking-tight ${conf.text} leading-none mt-0.5`}>
                      {tile.id === 0 ? 'START' : tile.label}
                    </span>

                    {playersHere.length > 0 && (
                      <div className="absolute -top-3.5 -right-3.5 flex -space-x-2 z-30">
                        {playersHere.map((p) => (
                          <div
                            key={p.id}
                            className="w-7 h-7 rounded-full flex items-center justify-center text-sm shadow-xl border-2 border-white animate-bounce"
                            style={{ backgroundColor: p.color }}
                            title={`${p.name} (#${p.currentRank})`}
                          >
                            {AVATARS[p.avatar]?.emoji}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* Non-intrusive Turn & Dice Status HUD in Corner (Top-Right of board viewport) */}
          {activePlayer && (
            <div className="absolute top-4 right-4 z-20 pointer-events-none">
              <div className="bg-slate-950/85 border-2 border-amber-400/80 p-3 rounded-2xl shadow-2xl backdrop-blur-md flex items-center gap-3 min-w-[210px]">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center text-2xl shadow border border-white/20 shrink-0"
                  style={{ backgroundColor: activePlayer.color }}
                >
                  {AVATARS[activePlayer.avatar]?.emoji}
                </div>
                <div className="flex-1">
                  <span className="text-[10px] font-black uppercase tracking-wider text-slate-400 block leading-none mb-1">
                    {activePlayer.name.toUpperCase()}'S TURN
                  </span>
                  <div className="flex items-center gap-1.5">
                    {room.phase === 'BOARD_ROLL' && (
                      <span className="text-xs font-black text-amber-300 animate-pulse">
                        🎲 DOBÁSRA VÁR...
                      </span>
                    )}
                    {room.phase === 'BOARD_ROLLING' && (
                      <span className="text-xs font-black text-amber-400 animate-bounce">
                        🎲 PÖRÖG A KOCKA...
                      </span>
                    )}
                    {(room.phase === 'BOARD_MOVE' || room.phase === 'BOARD_ACTION') && room.lastDiceRoll && (
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-black text-white">DOBÁS:</span>
                        <span className="text-base font-black text-amber-300 font-mono bg-amber-500/20 px-2 py-0.5 rounded-lg border border-amber-400/40">
                          🎲 {room.lastDiceRoll}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Landed Tile Action Alert Banner (Positioned at bottom center, leaving players and board in full view) */}
          {room.phase === 'BOARD_ACTION' && room.currentTileEffect && (
            <div className="absolute bottom-6 left-1/2 -translate-x-1/2 bg-slate-950/95 border-2 border-amber-400/90 px-8 py-4 rounded-3xl shadow-2xl flex items-center gap-4 z-30 max-w-xl pointer-events-none backdrop-blur-md animate-in fade-in slide-in-from-bottom-4 duration-300">
              <span className="text-4xl shrink-0 p-2 rounded-2xl bg-amber-400/10 border border-amber-400/30">
                {tileColors[room.currentTileEffect.type]?.icon || '✨'}
              </span>
              <div>
                <span className="text-[11px] font-black uppercase tracking-wider text-amber-400 block leading-tight">
                  MEZŐ HATÁS • {room.currentTileEffect.type}
                </span>
                <p className="text-lg font-black text-white leading-snug">
                  {room.currentTileEffect.message}
                </p>
              </div>
            </div>
          )}

          {/* Shop Decision Modal */}
          {room.phase === 'SHOP_DECISION' && activePlayer && (
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-slate-950/95 border-4 border-amber-400 p-8 rounded-3xl shadow-2xl flex flex-col items-center justify-center text-center gap-4 z-30 pointer-events-none">
              <span className="text-6xl animate-bounce">👑</span>
              <h3 className="text-3xl font-black text-amber-300 font-heading">
                CROWN SHOP ELÉRVE!
              </h3>
              <p className="text-lg font-bold text-slate-200">
                {activePlayer.name} a telefonján dönt arról, vesz-e Koronát 25 érméért!
              </p>
            </div>
          )}
        </div>

        {/* Right Sidebar: Scoreboard & Mini HUD (3 Cols) */}
        <div className="col-span-3 flex flex-col h-full bg-slate-900/60 rounded-3xl border border-slate-800 p-4 shadow-xl overflow-y-auto">
          <Scoreboard players={room.players} currentPlayerId={activePlayerId} />
        </div>
      </div>
    </div>
  );
};
