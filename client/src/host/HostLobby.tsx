import React, { useState, useEffect } from 'react';
import { RoomState, PartyMode } from '@shared/types';
import { QRCodeDisplay } from '../components/QRCodeDisplay';
import { SoundToggle } from '../components/SoundToggle';
import { AVATARS, PARTY_MODE_ROUNDS, COSMETIC_HATS } from '@shared/constants';
import { LobbyPreview3D } from './3d/LobbyPreview3D';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { Play, UserPlus, Users, Sparkles, X, Maximize2, Minimize2, CheckCircle2, Copy, Check, Edit2 } from 'lucide-react';
import { sounds } from '../audio/soundSynth';

interface HostLobbyProps {
  room: RoomState;
}

export const HostLobby: React.FC<HostLobbyProps> = ({ room }) => {
  const [apiLanIp, setApiLanIp] = useState<string | null>(null);
  const [apiPort, setApiPort] = useState<number | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [copied, setCopied] = useState(false);

  // Fetch verified LAN IP from server info endpoint
  useEffect(() => {
    fetch('/api/info')
      .then(res => res.json())
      .then(data => {
        if (data.lanIp) setApiLanIp(data.lanIp);
        if (data.port) setApiPort(data.port);
      })
      .catch(() => {});

    // Try keeping screen awake
    if ('wakeLock' in navigator) {
      try {
        (navigator as any).wakeLock.request('screen').catch(() => {});
      } catch (e) {}
    }
  }, []);

  const [customIp, setCustomIp] = useState<string>(() => localStorage.getItem('pm_custom_ip') || '');
  const [isEditingIp, setIsEditingIp] = useState(false);
  const [ipInput, setIpInput] = useState('');

  // Determine non-localhost LAN IP for QR code and join URL
  const effectiveLanIp =
    customIp ||
    room.serverLanIp ||
    apiLanIp ||
    (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1'
      ? window.location.hostname
      : '192.168.1.74');

  const effectivePort = room.serverPort || apiPort || window.location.port || '3000';
  const manualJoinAddress = `${effectiveLanIp}:${effectivePort}/join`;
  const joinUrl = `http://${effectiveLanIp}:${effectivePort}/join?room=${room.roomCode}`;

  const handleSaveIp = (newIp: string) => {
    const trimmed = newIp.trim();
    if (trimmed) {
      setCustomIp(trimmed);
      localStorage.setItem('pm_custom_ip', trimmed);
    } else {
      setCustomIp('');
      localStorage.removeItem('pm_custom_ip');
    }
    setIsEditingIp(false);
  };

  const playersList = Object.values(room.players);
  const playerCount = playersList.length;
  const readyCount = playersList.filter(p => p.isReady).length;
  const allReady = playerCount > 0 && readyCount === playerCount;

  const handleStartGame = () => {
    sounds.playGo();
    socket.emit(SOCKET_EVENTS.START_GAME, { roomCode: room.roomCode });
  };

  const handleSetPartyMode = (mode: PartyMode) => {
    sounds.playButton();
    socket.emit(SOCKET_EVENTS.SET_PARTY_MODE, { roomCode: room.roomCode, mode });
  };

  const handleTogglePartyChallenge = () => {
    sounds.playButton();
    socket.emit(SOCKET_EVENTS.TOGGLE_PARTY_CHALLENGE, {
      roomCode: room.roomCode,
      enabled: !room.partyChallengeEnabled
    });
  };

  const handleAddBot = () => {
    sounds.playButton();
    socket.emit(SOCKET_EVENTS.ADD_BOT, { roomCode: room.roomCode });
  };

  const handleAddFivePlayers = () => {
    sounds.playButton();
    const needed = Math.max(0, 5 - playerCount);
    for (let i = 0; i < needed; i++) {
      setTimeout(() => {
        socket.emit(SOCKET_EVENTS.ADD_BOT, { roomCode: room.roomCode });
      }, i * 150);
    }
  };

  const handleKick = (playerId: string) => {
    sounds.playWrong();
    socket.emit(SOCKET_EVENTS.KICK_PLAYER, { roomCode: room.roomCode, playerId });
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

  const handleCopyLink = () => {
    navigator.clipboard.writeText(manualJoinAddress);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-white flex flex-col p-4 lg:p-8 select-none relative overflow-y-auto">
      {/* Background radial glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[500px] bg-gradient-to-b from-amber-500/15 via-purple-600/10 to-transparent blur-3xl pointer-events-none" />

      {/* Top Header */}
      <div className="flex items-center justify-between relative z-10 shrink-0 mb-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-amber-400 rounded-2xl flex items-center justify-center text-3xl shadow-lg border-2 border-amber-200 animate-bounce">
            👑
          </div>
          <div>
            <h1 className="text-3xl lg:text-4xl font-black tracking-wider bg-gradient-to-r from-amber-300 via-orange-400 to-pink-500 bg-clip-text text-transparent font-heading">
              PARTY MAYHEM
            </h1>
            <p className="text-slate-400 text-xs font-semibold tracking-wide">
              A KÖZÖS 3D HÁZIBULI-JÁTÉK • TELEFONOS KONTROLLEREKKEL
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={toggleFullscreen}
            className="p-2.5 rounded-xl bg-slate-900 border border-slate-700 hover:bg-slate-800 text-slate-200 transition"
            title="Teljes képernyő (ENTER FULLSCREEN)"
          >
            {isFullscreen ? <Minimize2 className="w-5 h-5" /> : <Maximize2 className="w-5 h-5" />}
          </button>
          <SoundToggle />
          <div className="bg-slate-900/90 border-2 border-amber-400/80 px-5 py-2 rounded-2xl shadow-xl flex items-center gap-3">
            <span className="text-slate-400 text-xs font-black uppercase tracking-widest">SZOBA KÓD:</span>
            <span className="text-3xl font-black text-amber-400 tracking-widest font-mono">
              {room.roomCode}
            </span>
          </div>
        </div>
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 my-auto relative z-10 items-stretch">
        {/* Left Column: QR Code & LAN Connection Info (5 Cols) */}
        <div className="lg:col-span-5 flex flex-col items-center justify-between p-5 bg-slate-900/70 rounded-3xl border border-slate-800 shadow-2xl backdrop-blur-xl text-center">
          <div className="w-full">
            <span className="text-xs font-black tracking-widest uppercase text-amber-400 bg-amber-500/10 border border-amber-500/30 px-3 py-1 rounded-full inline-block mb-3">
              CSATLAKOZZ A TELEFONODDAL!
            </span>

            {/* QR Code with Guaranteed LAN IP */}
            <div className="flex justify-center my-2">
              <QRCodeDisplay url={joinUrl} size={220} />
            </div>

            {/* Human Readable Manual URL */}
            <div className="mt-3 flex flex-col items-center gap-1">
              <span className="text-[11px] font-black uppercase tracking-wider text-slate-400">
                MANUÁLISAN BEÍRHATÓ CÍM A TELEFON BÖNGÉSZŐJÉBE:
              </span>

              {isEditingIp ? (
                <div className="flex items-center gap-1.5 bg-slate-950 border border-amber-400 p-1 rounded-xl">
                  <input
                    type="text"
                    placeholder="Pl. 192.168.1.55"
                    value={ipInput}
                    onChange={e => setIpInput(e.target.value)}
                    className="bg-slate-900 text-amber-300 font-mono text-xs px-2 py-1 rounded outline-none border border-slate-700 w-36"
                    autoFocus
                  />
                  <button
                    onClick={() => handleSaveIp(ipInput)}
                    className="bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs px-2 py-1 rounded"
                  >
                    Mentés
                  </button>
                  <button
                    onClick={() => setIsEditingIp(false)}
                    className="text-slate-400 hover:text-white text-xs px-1"
                  >
                    Mégse
                  </button>
                </div>
              ) : (
                <div className="flex items-center gap-2 bg-slate-950/80 border border-amber-400/40 px-3 py-1.5 rounded-xl">
                  <span className="text-sm font-mono font-black text-amber-300 select-all">
                    {manualJoinAddress}
                  </span>
                  <button
                    onClick={handleCopyLink}
                    className="p-1 hover:bg-slate-800 rounded text-slate-400 hover:text-white"
                    title="Másolás"
                  >
                    {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                  <button
                    onClick={() => {
                      setIpInput(customIp || effectiveLanIp);
                      setIsEditingIp(true);
                    }}
                    className="p-1 hover:bg-slate-800 rounded text-slate-400 hover:text-amber-300"
                    title="IP cím kézi módosítása (pl. Wi-Fi IP megadása)"
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}

              <span className="text-[10px] text-slate-500 font-mono">
                Szoba kód: <b className="text-amber-400">{room.roomCode}</b>
                {customIp && <span className="ml-2 text-emerald-400">(Kézi IP aktív)</span>}
              </span>
            </div>
          </div>

          {/* Party Mode Selection */}
          <div className="mt-4 w-full pt-3 border-t border-slate-800/80 flex flex-col gap-2">
            <span className="text-[11px] font-black text-slate-400 uppercase tracking-wider text-left">
              JÁTÉKHOSSZ VÁLASZTÁS:
            </span>
            <div className="grid grid-cols-3 gap-2">
              {(['quick', 'normal', 'chaos'] as PartyMode[]).map((mode) => (
                <button
                  key={mode}
                  onClick={() => handleSetPartyMode(mode)}
                  className={`py-2 px-1 rounded-xl text-xs font-extrabold transition-all border ${
                    room.partyMode === mode
                      ? 'bg-amber-500 text-slate-950 border-amber-300 shadow-lg scale-105'
                      : 'bg-slate-800/80 text-slate-300 border-slate-700 hover:bg-slate-700/80'
                  }`}
                >
                  <div className="capitalize">{mode === 'quick' ? 'Gyors' : mode === 'normal' ? 'Normál' : 'Káosz'}</div>
                  <div className="text-[10px] opacity-80">{PARTY_MODE_ROUNDS[mode]} kör</div>
                </button>
              ))}
            </div>

            {/* Optional Party Challenge toggle */}
            <button
              onClick={handleTogglePartyChallenge}
              className={`py-1.5 px-3 rounded-xl text-xs font-bold transition-all border flex items-center justify-center gap-2 ${
                room.partyChallengeEnabled
                  ? 'bg-pink-600/30 border-pink-500 text-pink-300'
                  : 'bg-slate-800/60 border-slate-700 text-slate-400 hover:text-slate-200'
              }`}
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Party Kihívások: {room.partyChallengeEnabled ? 'BEKAPCSOLVA' : 'KIKAPCSOLVA'}</span>
            </button>
          </div>
        </div>

        {/* Right Column: 3D Preview Platform & Player List (7 Cols) */}
        <div className="lg:col-span-7 flex flex-col justify-between bg-slate-900/70 rounded-3xl border border-slate-800 p-5 shadow-2xl backdrop-blur-xl">
          {/* Header of Right Column */}
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <div className="flex items-center gap-2">
              <Users className="w-5 h-5 text-amber-400" />
              <h2 className="text-xl font-black text-slate-100 font-heading">
                3D LOBBY • JÁTÉKOSOK ({playerCount}/8)
              </h2>
            </div>

            <div className="flex items-center gap-2">
              {/* Ready status pill */}
              <div className="bg-slate-800 px-3 py-1 rounded-xl border border-slate-700 flex items-center gap-1.5">
                <CheckCircle2 className={`w-3.5 h-3.5 ${allReady ? 'text-emerald-400' : 'text-amber-400'}`} />
                <span className="text-xs font-black font-mono">
                  {readyCount}/{playerCount} READY
                </span>
              </div>

              <button
                onClick={handleAddBot}
                className="bg-indigo-600/30 hover:bg-indigo-600/50 border border-indigo-500/50 text-indigo-200 text-xs font-bold py-1.5 px-3 rounded-xl flex items-center gap-1 transition"
                title="Adj hozzá 1 botot a teszteléshez"
              >
                <UserPlus className="w-3.5 h-3.5" />
                +1 Bot
              </button>
              {playerCount < 5 && (
                <button
                  onClick={handleAddFivePlayers}
                  className="bg-amber-500/20 hover:bg-amber-500/30 border border-amber-400/50 text-amber-300 text-xs font-bold py-1.5 px-3 rounded-xl flex items-center gap-1 transition"
                  title="Feltöltés 5 játékosra a tökéletes bulihoz"
                >
                  ⚡ Legyen 5 játékos
                </button>
              )}
            </div>
          </div>

          {/* 3D Platform Viewport (Shows actual 3D blobs with hats in real time!) */}
          <div className="my-3">
            <LobbyPreview3D room={room} />
          </div>

          {/* Player Cards Mini Grid */}
          <div className="grid grid-cols-2 md:grid-cols-3 gap-2.5 max-h-36 overflow-y-auto pr-1">
            {playerCount === 0 ? (
              <div className="col-span-3 py-4 text-center text-slate-500 text-xs font-bold">
                Várakozás játékosokra... Olvasd be a bal oldali QR-kódot!
              </div>
            ) : (
              playersList.map((player) => {
                const avatar = AVATARS[player.avatar] || AVATARS['fox'];
                const hat = COSMETIC_HATS[player.cosmetic || 'none'] || COSMETIC_HATS['none'];
                return (
                  <div
                    key={player.id}
                    className="p-2 rounded-xl bg-slate-800/80 border border-slate-700/80 flex items-center justify-between shadow relative group"
                  >
                    <div className="flex items-center gap-2 min-w-0">
                      <div
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-lg shrink-0 relative"
                        style={{ backgroundColor: player.color + '26', border: `1.5px solid ${player.color}` }}
                      >
                        {hat.id !== 'none' && (
                          <span className="absolute -top-2.5 -right-1 text-xs">{hat.emoji}</span>
                        )}
                        <span>{avatar.emoji}</span>
                      </div>
                      <div className="flex flex-col min-w-0">
                        <span className="font-extrabold text-slate-100 truncate text-xs leading-none">
                          {player.name}
                        </span>
                        <span className="text-[9px] font-bold text-slate-400 truncate mt-0.5">
                          {hat.name}
                        </span>
                      </div>
                    </div>

                    <div className="flex items-center gap-1">
                      {player.isReady && (
                        <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      )}
                      <button
                        onClick={() => handleKick(player.id)}
                        className="opacity-0 group-hover:opacity-100 p-1 hover:bg-red-500/20 text-red-400 rounded transition"
                        title="Játékos kirúgása"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Start Game Button */}
          <div className="mt-3 pt-3 border-t border-slate-800">
            <button
              onClick={handleStartGame}
              disabled={playerCount < 1}
              className={`w-full py-4 rounded-2xl font-black text-xl flex items-center justify-center gap-3 transition-all duration-300 shadow-2xl ${
                allReady
                  ? 'bg-gradient-to-r from-emerald-400 to-green-500 hover:brightness-110 text-slate-950 shadow-emerald-500/30 scale-[1.01]'
                  : playerCount >= 1
                  ? 'bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 hover:brightness-110 text-slate-950 shadow-amber-500/30'
                  : 'bg-slate-800 text-slate-500 cursor-not-allowed border border-slate-700'
              }`}
            >
              <Play className="w-6 h-6 fill-current" />
              <span>
                {allReady ? 'MINDENKI KÉSZEN ÁLL! INDÍTÁS!' : `JÁTÉK INDÍTÁSA (${playerCount} FŐVEL)`}
              </span>
            </button>
            {playerCount > 0 && !allReady && (
              <p className="text-center text-[11px] text-amber-400/80 font-bold mt-1.5">
                💡 A host azonnal elindíthatja a játékot, vagy megvárhatja, amíg mindenki READY-t nyom a telefonján.
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
