import React from 'react';
import { Player, HatId } from '@shared/types';
import { AVATARS, COSMETIC_HATS } from '@shared/constants';
import { SoundToggle } from '../components/SoundToggle';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { sounds } from '../audio/soundSynth';
import { CheckCircle2, Clock, Sparkles } from 'lucide-react';

interface PlayerLobbyProps {
  player: Player;
  roomCode: string;
}

export const PlayerLobby: React.FC<PlayerLobbyProps> = ({ player, roomCode }) => {
  const avatar = AVATARS[player.avatar] || AVATARS['fox'];
  const currentHat = COSMETIC_HATS[player.cosmetic || 'none'] || COSMETIC_HATS['none'];
  const hatList = Object.values(COSMETIC_HATS);

  const handleHatChange = (hatId: HatId) => {
    sounds.playButton();
    socket.emit(SOCKET_EVENTS.SET_COSMETIC, {
      roomCode,
      playerId: player.id,
      cosmetic: hatId
    });
  };

  const handleToggleReady = () => {
    if (!player.isReady) {
      sounds.playGo();
    } else {
      sounds.playButton();
    }
    // Attempt wake lock on user gesture
    if ('wakeLock' in navigator) {
      try {
        (navigator as any).wakeLock.request('screen').catch(() => {});
      } catch (e) {}
    }
    socket.emit(SOCKET_EVENTS.TOGGLE_READY, {
      roomCode,
      playerId: player.id,
      ready: !player.isReady
    });
  };

  return (
    <div className="min-h-screen bg-slate-950 text-white flex flex-col p-5 select-none relative justify-between overflow-y-auto">
      {/* Top Bar */}
      <div className="w-full flex items-center justify-between border-b border-slate-800 pb-3">
        <div className="flex items-center gap-2">
          <span className="text-xs font-black text-amber-400 font-mono tracking-wider">
            SZOBA: {roomCode}
          </span>
          <span className="text-[10px] bg-slate-800 text-slate-300 font-bold px-2 py-0.5 rounded-full">
            LOBBY
          </span>
        </div>
        <SoundToggle />
      </div>

      {/* Center Avatar & Hat Display */}
      <div className="flex flex-col items-center gap-4 my-auto max-w-sm mx-auto text-center w-full py-4">
        {/* 3D-ish Avatar Card */}
        <div className="relative">
          <div
            className="w-28 h-28 rounded-3xl flex items-center justify-center text-6xl shadow-2xl relative transition-all duration-300"
            style={{
              backgroundColor: avatar.color + '2b',
              border: `4px solid ${avatar.color}`,
              boxShadow: `0 10px 30px ${avatar.color}33`
            }}
          >
            {/* Hat Emoji overlay floating above character */}
            {currentHat.id !== 'none' && (
              <div className="absolute -top-6 text-4xl animate-bounce drop-shadow-md">
                {currentHat.emoji}
              </div>
            )}
            <span>{avatar.emoji}</span>
          </div>

          {/* Ready badge */}
          {player.isReady && (
            <div className="absolute -bottom-2 -right-2 bg-emerald-500 text-slate-950 p-1 rounded-full shadow-lg border-2 border-slate-950 animate-pulse">
              <CheckCircle2 className="w-5 h-5" />
            </div>
          )}
        </div>

        <div>
          <h2 className="text-2xl font-black text-white font-heading">
            {player.name}
          </h2>
          <span className="text-xs font-bold block mt-0.5" style={{ color: avatar.color }}>
            {avatar.name} • {currentHat.name}
          </span>
        </div>

        {/* Change Hat Section */}
        <div className="w-full bg-slate-900/80 border border-slate-800 rounded-2xl p-3 text-left">
          <span className="text-[10px] font-black uppercase tracking-wider text-slate-400 block mb-2">
            🎩 VÁLASSZ KALAPOT (TV-N AZONNAL LÁTHATÓ):
          </span>
          <div className="grid grid-cols-3 gap-1.5 max-h-36 overflow-y-auto pr-1">
            {hatList.map((hat) => (
              <button
                key={hat.id}
                type="button"
                onClick={() => handleHatChange(hat.id)}
                className={`py-1.5 px-2 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all border ${
                  player.cosmetic === hat.id
                    ? 'bg-pink-600/30 border-pink-400 text-white shadow ring-2 ring-pink-500/40'
                    : 'bg-slate-950 border-slate-800/80 text-slate-400 hover:text-slate-200'
                }`}
              >
                <span className="text-base">{hat.emoji}</span>
                <span className="text-[10px] truncate">{hat.name}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Ready Toggle Button */}
        <button
          type="button"
          onClick={handleToggleReady}
          className={`w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-2xl transition-all duration-300 active:scale-95 ${
            player.isReady
              ? 'bg-emerald-500 hover:bg-emerald-400 text-slate-950 shadow-emerald-500/30'
              : 'bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 text-slate-950 hover:brightness-110 shadow-amber-500/30'
          }`}
        >
          {player.isReady ? (
            <>
              <CheckCircle2 className="w-6 h-6" />
              <span>KÉSZEN ÁLLSZ! (READY)</span>
            </>
          ) : (
            <>
              <Clock className="w-6 h-6 animate-spin" />
              <span>KÉSZEN ÁLLOK! (NYOMD MEG)</span>
            </>
          )}
        </button>

        <p className="text-slate-400 text-xs font-bold">
          📺 Nézz a TV képernyőjére! A játék hamarosan indul.
        </p>
      </div>

      {/* Bottom Hint */}
      <div className="text-slate-500 text-[10px] font-mono text-center pb-1">
        PARTY MAYHEM • TELEFONOS IRÁNYÍTÓ
      </div>
    </div>
  );
};
