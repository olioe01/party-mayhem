import React, { useState } from 'react';
import { RoomState } from '@shared/types';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { CHAOS_EVENTS, MINIGAME_META_LIST } from '@shared/constants';
import { BOARD_TILES } from '@shared/boardData';
import { Wrench, UserPlus, Play, Sparkles, X, ChevronDown, Eye } from 'lucide-react';

interface DevModePanelProps {
  room: RoomState;
}

const SOLO_READY_MINIGAMES = [
  { id: 'fruit-frenzy', name: 'Fruit Frenzy', icon: '🍎' },
  { id: 'bomb-dodge', name: 'Bomb Dodge', icon: '💣' },
  { id: 'coin-scramble', name: 'Coin Scramble', icon: '🪙' },
  { id: 'treasure-grab', name: 'Treasure Grab', icon: '💎' },
  { id: 'paint-panic', name: 'Paint Panic', icon: '🎨' },
  { id: 'delivery-dash', name: 'Delivery Dash', icon: '📦' },
  { id: 'floor-is-lava', name: 'Floor Is Lava', icon: '🔥' },
  { id: 'monster-escape', name: 'Monster Escape', icon: '👾' },
  { id: 'push-arena', name: 'Push Arena', icon: '🥊' },
  { id: 'crown-chase', name: 'Crown Chase', icon: '👑' },
];

export const DevModePanel: React.FC<DevModePanelProps> = ({ room }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [showCharDebug, setShowCharDebug] = useState(false);
  const [selectedMinigame, setSelectedMinigame] = useState<string>('fruit-frenzy');
  const [selectedEvent, setSelectedEvent] = useState<string>('coin_storm');

  const addBot = () => {
    socket.emit(SOCKET_EVENTS.ADD_BOT, { roomCode: room.roomCode });
  };

  const addFourBots = () => {
    for (let i = 0; i < 4; i++) {
      setTimeout(() => {
        socket.emit(SOCKET_EVENTS.ADD_BOT, { roomCode: room.roomCode });
      }, i * 150);
    }
  };

  const addFiveBots = () => {
    for (let i = 0; i < 5; i++) {
      setTimeout(() => {
        socket.emit(SOCKET_EVENTS.ADD_BOT, { roomCode: room.roomCode });
      }, i * 150);
    }
  };

  const launchMinigame = () => {
    socket.emit(SOCKET_EVENTS.DEV_SELECT_MINIGAME, {
      roomCode: room.roomCode,
      minigameId: selectedMinigame
    });
  };

  const triggerEvent = () => {
    socket.emit(SOCKET_EVENTS.DEV_TRIGGER_EVENT, {
      roomCode: room.roomCode,
      eventId: selectedEvent
    });
  };

  const modifyPlayer = (playerId: string, deltaCoins: number, deltaCrowns: number) => {
    const player = room.players[playerId];
    if (!player) return;
    socket.emit(SOCKET_EVENTS.DEV_MODIFY_PLAYER, {
      roomCode: room.roomCode,
      playerId,
      coins: Math.max(0, player.coins + deltaCoins),
      crowns: Math.max(0, player.crowns + deltaCrowns)
    });
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-4 right-4 bg-amber-500 hover:bg-amber-400 text-slate-950 font-black px-4 py-2.5 rounded-2xl shadow-2xl flex items-center gap-2 border-2 border-amber-300 z-50 transition-transform active:scale-95"
      >
        <Wrench className="w-5 h-5" />
        <span>DEV MODE</span>
      </button>
    );
  }

  return (
    <div className="fixed inset-y-0 right-0 w-96 bg-slate-900/95 backdrop-blur-2xl border-l border-slate-700/80 p-5 shadow-2xl z-50 overflow-y-auto flex flex-col gap-4 text-slate-100">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-3">
        <div className="flex items-center gap-2 text-amber-400 font-black text-lg">
          <Wrench className="w-5 h-5" />
          <span>DEV CONTROLS</span>
        </div>
        <button
          onClick={() => setIsOpen(false)}
          className="p-1 rounded-xl hover:bg-slate-800 text-slate-400 hover:text-white"
        >
          <X className="w-6 h-6" />
        </button>
      </div>

      {/* 1 HUMAN + 0 BOTS SOLO DEV PLAYLIST */}
      <div className="flex flex-col gap-2 border border-emerald-500/30 bg-emerald-950/20 p-3 rounded-2xl">
        <div className="flex items-center justify-between">
          <label className="text-[11px] font-black uppercase tracking-wider text-emerald-400">
            🕹️ SOLO DEV PLAYLIST (1P / 0 Bots)
          </label>
          <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
            10 READY
          </span>
        </div>
        <p className="text-[10px] text-slate-400">
          Kattints bármelyikre az azonnali szóló teszteléshez (1 ember, 0 bot).
        </p>
        <div className="grid grid-cols-2 gap-1.5 max-h-48 overflow-y-auto pr-1">
          {SOLO_READY_MINIGAMES.map(mg => (
            <button
              key={mg.id}
              onClick={() => {
                socket.emit(SOCKET_EVENTS.DEV_SELECT_MINIGAME, {
                  roomCode: room.roomCode,
                  minigameId: mg.id,
                });
              }}
              className="bg-slate-800/90 hover:bg-emerald-600 hover:text-slate-950 text-white font-bold p-2 rounded-xl text-[11px] flex items-center justify-between gap-1 border border-slate-700 hover:border-emerald-400 transition-colors shadow-sm group text-left"
            >
              <span className="truncate">{mg.icon} {mg.name}</span>
              <span className="text-[8px] font-black px-1 py-0.2 rounded bg-emerald-500/20 text-emerald-400 group-hover:bg-slate-950 group-hover:text-emerald-300">
                READY
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Bot Controls */}
      <div className="flex flex-col gap-2">
        <label className="text-xs font-black uppercase tracking-wider text-slate-400">Bot Játékosok</label>
        <div className="grid grid-cols-3 gap-1.5">
          <button
            onClick={addBot}
            className="bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-2 px-2 rounded-xl flex items-center justify-center gap-1 text-xs"
          >
            <UserPlus className="w-3.5 h-3.5" />
            +1 Bot
          </button>
          <button
            onClick={addFourBots}
            className="bg-indigo-700 hover:bg-indigo-600 text-white font-bold py-2 px-2 rounded-xl flex items-center justify-center gap-1 text-xs"
          >
            <UserPlus className="w-3.5 h-3.5" />
            +4 Bot
          </button>
          <button
            onClick={addFiveBots}
            className="bg-purple-700 hover:bg-purple-600 text-white font-bold py-2 px-2 rounded-xl flex items-center justify-center gap-1 text-xs"
          >
            <UserPlus className="w-3.5 h-3.5" />
            +5 Bot
          </button>
        </div>

        <button
          onClick={() => {
            socket.emit(SOCKET_EVENTS.RESTART_GAME, { roomCode: room.roomCode });
          }}
          className="bg-red-900/80 hover:bg-red-800 text-white font-bold py-1.5 px-3 rounded-xl flex items-center justify-center gap-1.5 text-xs mt-1"
        >
          🔄 Meccs Visszaállítása (Reset Lobby)
        </button>
      </div>

      {/* Direct Minigame Launcher */}
      <div className="flex flex-col gap-2">
        <label className="text-xs font-black uppercase tracking-wider text-slate-400">Minijáték Indítása</label>
        <select
          value={selectedMinigame}
          onChange={(e) => setSelectedMinigame(e.target.value)}
          className="bg-slate-800 border border-slate-700 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-amber-400"
        >
          {MINIGAME_META_LIST.map((mg) => (
            <option key={mg.id} value={mg.id}>
              {mg.name}
            </option>
          ))}
        </select>
        <button
          onClick={launchMinigame}
          className="bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-2.5 px-4 rounded-xl flex items-center justify-center gap-2 text-xs shadow-md"
        >
          <Play className="w-4 h-4" />
          Minijáték Indítása Most
        </button>
      </div>

      {/* Trigger Random Event */}
      <div className="flex flex-col gap-2">
        <label className="text-xs font-black uppercase tracking-wider text-slate-400">Kaotikus Esemény</label>
        <select
          value={selectedEvent}
          onChange={(e) => setSelectedEvent(e.target.value)}
          className="bg-slate-800 border border-slate-700 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-amber-400"
        >
          {CHAOS_EVENTS.map((evt) => (
            <option key={evt.id} value={evt.id}>
              {evt.icon} {evt.name}
            </option>
          ))}
        </select>
        <button
          onClick={triggerEvent}
          className="bg-purple-600 hover:bg-purple-500 text-white font-bold py-2.5 px-4 rounded-xl flex items-center justify-center gap-2 text-xs shadow-md"
        >
          <Sparkles className="w-4 h-4" />
          Esemény Kiváltása
        </button>
      </div>

      {/* Player Stats Live Editor */}
      <div className="flex flex-col gap-2 border-t border-slate-800 pt-3">
        <label className="text-xs font-black uppercase tracking-wider text-slate-400">Játékosok Statisztikái</label>
        <div className="flex flex-col gap-2 max-h-60 overflow-y-auto pr-1">
          {Object.values(room.players).map((p) => (
            <div key={p.id} className="bg-slate-800/80 p-2.5 rounded-xl border border-slate-700 flex flex-col gap-1.5 text-xs">
              <div className="flex items-center justify-between font-bold">
                <span className="truncate">{p.name}</span>
                <span className="text-slate-400">🪙 {p.coins} | 👑 {p.crowns}</span>
              </div>
              <div className="grid grid-cols-4 gap-1">
                <button
                  onClick={() => modifyPlayer(p.id, 5, 0)}
                  className="bg-slate-700 hover:bg-slate-600 text-amber-300 font-bold py-1 rounded"
                >
                  +5 🪙
                </button>
                <button
                  onClick={() => modifyPlayer(p.id, -5, 0)}
                  className="bg-slate-700 hover:bg-slate-600 text-red-300 font-bold py-1 rounded"
                >
                  -5 🪙
                </button>
                <button
                  onClick={() => modifyPlayer(p.id, 0, 1)}
                  className="bg-amber-600 hover:bg-amber-500 text-white font-bold py-1 rounded"
                >
                  +1 👑
                </button>
                <button
                  onClick={() => modifyPlayer(p.id, 0, -1)}
                  className="bg-red-800 hover:bg-red-700 text-white font-bold py-1 rounded"
                >
                  -1 👑
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 3D Characters Debug */}
      <div className="flex flex-col gap-2 border-t border-slate-800 pt-3">
        <button
          onClick={() => setShowCharDebug(!showCharDebug)}
          className="flex items-center justify-between text-xs font-black uppercase tracking-wider text-slate-400 hover:text-white"
        >
          <span className="flex items-center gap-1.5">
            <Eye className="w-3.5 h-3.5 text-cyan-400" />
            3D Karakterek Állapota ({Object.keys(room.players).length})
          </span>
          <ChevronDown className={`w-4 h-4 transition-transform ${showCharDebug ? 'rotate-180' : ''}`} />
        </button>

        {showCharDebug && (
          <div className="flex flex-col gap-2 max-h-64 overflow-y-auto pr-1">
            {Object.values(room.players).map((p) => {
              const tile = BOARD_TILES[p.boardPosition] || BOARD_TILES[0];
              const pos3d = tile ? `[${tile.position3D[0].toFixed(1)}, ${(tile.position3D[1] + 0.185).toFixed(2)}, ${tile.position3D[2].toFixed(1)}]` : 'N/A';
              return (
                <div key={p.id} className="bg-slate-800/90 p-2 rounded-lg border border-slate-700/80 text-[11px] flex flex-col gap-1">
                  <div className="flex items-center justify-between font-bold">
                    <span className="flex items-center gap-1">
                      <span className="w-2.5 h-2.5 rounded-full inline-block" style={{ backgroundColor: p.color || '#fff' }} />
                      <span className="text-white">{p.name}</span>
                      {p.isBot && <span className="bg-purple-900/80 text-purple-200 text-[9px] px-1 rounded">BOT</span>}
                    </span>
                    <span className={p.connected !== false ? 'text-emerald-400' : 'text-rose-400'}>
                      {p.connected !== false ? 'online' : 'offline'}
                    </span>
                  </div>
                  <div className="grid grid-cols-2 gap-x-2 gap-y-0.5 text-slate-400 text-[10px]">
                    <div>Mező: <span className="text-amber-300 font-mono">#{p.boardPosition}</span> ({tile?.label || 'START'})</div>
                    <div>Kalap: <span className="text-slate-200">{p.cosmetic || 'none'}</span></div>
                    <div className="col-span-2">3D Pos: <span className="text-cyan-300 font-mono">{pos3d}</span></div>
                    <div>ID: <span className="text-slate-500 font-mono">{p.id.slice(0, 8)}</span></div>
                    <div>Szín: <span className="text-slate-300 font-mono">{p.color}</span></div>
                    {p.lastInputState && (
                      <div className="col-span-2 flex items-center justify-between font-mono text-[9px] bg-slate-950/80 px-1.5 py-0.5 rounded border border-slate-700/60 mt-0.5">
                        <span className="text-slate-400 font-bold">PAD:</span>
                        <span className="flex items-center gap-1">
                          <span className={p.lastInputState.up ? 'text-amber-400 font-black' : 'text-slate-600'}>▲</span>
                          <span className={p.lastInputState.down ? 'text-amber-400 font-black' : 'text-slate-600'}>▼</span>
                          <span className={p.lastInputState.left ? 'text-amber-400 font-black' : 'text-slate-600'}>◀</span>
                          <span className={p.lastInputState.right ? 'text-amber-400 font-black' : 'text-slate-600'}>▶</span>
                        </span>
                        <span className="text-slate-600">|</span>
                        <span className="flex items-center gap-1">
                          <span className={p.lastInputState.a ? 'text-emerald-400 font-black' : 'text-slate-600'}>[A]</span>
                          <span className={p.lastInputState.b ? 'text-rose-400 font-black' : 'text-slate-600'}>[B]</span>
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};
