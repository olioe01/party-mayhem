import React, { useState } from 'react';
import { AvatarId, HatId } from '@shared/types';
import { AVATARS, COSMETIC_HATS } from '@shared/constants';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { sounds } from '../audio/soundSynth';
import { ArrowRight, Sparkles } from 'lucide-react';

interface PlayerJoinProps {
  defaultRoomCode?: string;
  onJoined: (playerName: string, avatar: AvatarId, cosmetic?: HatId) => void;
}

export const PlayerJoin: React.FC<PlayerJoinProps> = ({ defaultRoomCode = '4827', onJoined }) => {
  const savedRoom = localStorage.getItem('partyMayhemRoomCode') || defaultRoomCode;
  const savedName = localStorage.getItem('partyMayhemPlayerName') || '';

  const [roomCode, setRoomCode] = useState(savedRoom);
  const [name, setName] = useState(savedName);
  const [selectedAvatar, setSelectedAvatar] = useState<AvatarId>('fox');
  const [selectedHat, setSelectedHat] = useState<HatId>('top-hat');

  const avatarList = Object.values(AVATARS);
  const hatList = Object.values(COSMETIC_HATS);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const cleanName = name.trim();
    if (!cleanName) return;

    sounds.playGo();
    const cleanRoom = roomCode.trim() || '4827';
    const storedToken = localStorage.getItem('partyMayhemPlayerToken') || undefined;

    // Save preliminary values
    localStorage.setItem('partyMayhemRoomCode', cleanRoom);
    localStorage.setItem('partyMayhemPlayerName', cleanName);

    socket.emit(SOCKET_EVENTS.JOIN_ROOM, {
      roomCode: cleanRoom,
      name: cleanName,
      avatar: selectedAvatar,
      cosmetic: selectedHat,
      playerToken: storedToken
    });

    onJoined(cleanName, selectedAvatar, selectedHat);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-white flex flex-col p-5 select-none relative overflow-y-auto">
      {/* Background radial glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-80 h-80 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />

      {/* Header */}
      <div className="text-center my-3 z-10">
        <h1 className="text-3xl font-black bg-gradient-to-r from-amber-300 via-orange-400 to-pink-500 bg-clip-text text-transparent font-heading">
          PARTY MAYHEM
        </h1>
        <p className="text-xs text-slate-400 font-bold tracking-wide mt-0.5">
          TELEFONOS KONTROLLER
        </p>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4 max-w-sm mx-auto w-full z-10 my-auto pb-6">
        {/* Room Code */}
        <div className="flex flex-col gap-1">
          <label className="text-[11px] font-black uppercase tracking-wider text-slate-400">
            Szoba kód
          </label>
          <input
            type="text"
            value={roomCode}
            onChange={(e) => setRoomCode(e.target.value.toUpperCase())}
            maxLength={6}
            className="bg-slate-900 border-2 border-slate-700 focus:border-amber-400 rounded-2xl py-2.5 px-4 text-center text-xl font-mono font-black text-amber-400 tracking-widest outline-none transition"
            placeholder="4827"
            required
          />
        </div>

        {/* Player Name */}
        <div className="flex flex-col gap-1">
          <label className="text-[11px] font-black uppercase tracking-wider text-slate-400">
            Add meg a neved
          </label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={14}
            className="bg-slate-900 border-2 border-slate-700 focus:border-amber-400 rounded-2xl py-3 px-4 text-base font-bold text-white outline-none transition"
            placeholder="pl. Bence"
            required
          />
        </div>

        {/* Choose Avatar */}
        <div className="flex flex-col gap-1.5">
          <label className="text-[11px] font-black uppercase tracking-wider text-slate-400 flex items-center justify-between">
            <span>1. Válassz karaktert</span>
            <span className="text-amber-400 font-bold">{AVATARS[selectedAvatar].name}</span>
          </label>
          <div className="grid grid-cols-5 gap-2">
            {avatarList.map((av) => (
              <button
                type="button"
                key={av.id}
                onClick={() => {
                  sounds.playButton();
                  setSelectedAvatar(av.id);
                }}
                className={`h-14 rounded-2xl flex flex-col items-center justify-center text-2xl transition-all shadow-md active:scale-90 ${
                  selectedAvatar === av.id
                    ? 'ring-4 ring-amber-400 scale-105 shadow-amber-500/30'
                    : 'bg-slate-800/80 border border-slate-700/80 opacity-75'
                }`}
                style={{
                  backgroundColor: selectedAvatar === av.id ? av.color + '44' : undefined,
                  borderColor: selectedAvatar === av.id ? av.color : undefined
                }}
              >
                <span>{av.emoji}</span>
                <span className="text-[8px] font-bold text-slate-300 truncate w-full text-center">
                  {av.name}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* Choose Hat Cosmetic */}
        <div className="flex flex-col gap-1.5">
          <label className="text-[11px] font-black uppercase tracking-wider text-slate-400 flex items-center justify-between">
            <span>2. Válassz kalapot</span>
            <span className="text-pink-400 font-bold">{COSMETIC_HATS[selectedHat].name}</span>
          </label>
          <div className="grid grid-cols-3 gap-2">
            {hatList.map((hat) => (
              <button
                type="button"
                key={hat.id}
                onClick={() => {
                  sounds.playButton();
                  setSelectedHat(hat.id);
                }}
                className={`p-2 rounded-xl flex items-center gap-2 transition-all border text-left active:scale-95 ${
                  selectedHat === hat.id
                    ? 'bg-pink-600/30 border-pink-400 text-white shadow-lg ring-2 ring-pink-400/50 scale-[1.02]'
                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-slate-200'
                }`}
              >
                <span className="text-xl shrink-0">{hat.emoji}</span>
                <span className="text-[10px] font-extrabold truncate leading-tight">
                  {hat.name}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* Join Button */}
        <button
          type="submit"
          disabled={!name.trim()}
          className={`w-full py-4 rounded-2xl font-black text-lg shadow-2xl flex items-center justify-center gap-2 transition-all duration-300 mt-2 ${
            name.trim()
              ? 'bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 text-slate-950 hover:brightness-110 active:scale-95 shadow-amber-500/25'
              : 'bg-slate-800 text-slate-500 cursor-not-allowed border border-slate-700'
          }`}
        >
          <span>BELÉPÉS A JÁTÉKBA</span>
          <ArrowRight className="w-5 h-5" />
        </button>
      </form>
    </div>
  );
};
