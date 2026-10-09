import React from 'react';
import { RoomState } from '@shared/types';
import { AVATARS } from '@shared/constants';
import { HostArena3D } from '../host/3d/arena/HostArena3D';

interface MinigameHostRendererProps {
  room: RoomState;
}

export const MinigameHostRenderer: React.FC<MinigameHostRendererProps> = ({ room }) => {
  const mg = room.activeMinigame;
  if (!mg) return null;
  const mgData = mg.data || {};
  const players = Object.values(room.players);

  // 3D Arena minigames with gamepad controls
  if (
    mg.id === 'fruit-frenzy' ||
    mg.id === 'bomb-dodge' ||
    mg.id === 'push-arena' ||
    mg.id === 'crown-chase' ||
    mg.id === 'paint-panic' ||
    mg.id === 'controller-test'
  ) {
    return <HostArena3D room={room} />;
  }

  switch (mg.id) {
    // 1. REACTION RUSH
    case 'reaction-rush':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <div className={`text-6xl lg:text-8xl font-black font-heading transition-all ${
            mgData.goTriggered ? 'text-emerald-400 scale-125 animate-bounce' : 'text-amber-400'
          }`}>
            {mgData.goTriggered ? '⚡ GO! GO! GO! ⚡' : '⏳ VÁRJ... VÁRJ... ⏳'}
          </div>
          <div className="flex flex-wrap gap-4 justify-center mt-8">
            {players.map(p => {
              const r = mgData.reactions?.[p.id];
              return (
                <div key={p.id} className="bg-slate-800/80 p-4 rounded-2xl border border-slate-700 flex items-center gap-3">
                  <span className="text-3xl">{AVATARS[p.avatar]?.emoji}</span>
                  <div>
                    <span className="font-bold text-white block">{p.name}</span>
                    <span className="text-xs font-mono font-black" style={{ color: r ? (r.falseStart ? '#ef4444' : '#10b981') : '#94a3b8' }}>
                      {r ? (r.falseStart ? 'KORAI RAJT!' : `${r.time} ms`) : 'Várakozás...'}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      );

    // 2. SHAKE IT
    case 'shake-it':
      return (
        <div className="flex flex-col items-center justify-center h-full w-full px-8">
          <h2 className="text-3xl font-black text-amber-400 mb-8 font-heading">
            🚀 RAKÉTA KILÖVÉS! RÁZZÁTOK GŐZERŐVEL!
          </h2>
          <div className="flex items-end justify-center gap-6 h-80 w-full max-w-4xl border-b-4 border-slate-700 pb-2">
            {players.map(p => {
              const shakes = mgData.shakes?.[p.id] || 0;
              const maxPossible = 50;
              const heightPercent = Math.min(100, (shakes / maxPossible) * 100);
              return (
                <div key={p.id} className="flex flex-col items-center flex-1 h-full justify-end">
                  <div
                    className="w-full max-w-[60px] bg-gradient-to-t from-orange-500 to-amber-300 rounded-t-2xl flex flex-col items-center justify-between p-2 shadow-lg transition-all duration-200"
                    style={{ height: `${Math.max(15, heightPercent)}%` }}
                  >
                    <span className="text-3xl animate-bounce">🚀</span>
                    <span className="text-xs font-black text-slate-950 font-mono">{shakes}</span>
                  </div>
                  <span className="text-xs font-bold text-slate-300 mt-2 truncate w-full text-center">
                    {p.name}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      );

    // 3. BOMB PASS
    case 'bomb-pass':
      const holder = room.players[mgData.currentHolder];
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <div className="text-8xl animate-bounce">💣</div>
          <div className="text-3xl font-black text-red-400 font-heading">
            A BOMBA NÁLA VAN: <span className="text-white underline">{holder?.name || 'Valaki'}</span>!
          </div>
          <p className="text-slate-400 text-sm font-bold">
            Add tovább a telefonodon mielőtt felrobban!
          </p>
          {mgData.passHistory && mgData.passHistory.length > 0 && (
            <div className="bg-slate-900/80 p-4 rounded-2xl border border-slate-800 max-w-md w-full">
              <span className="text-xs uppercase font-black text-slate-400 block mb-2">Továbbadások:</span>
              <div className="flex flex-col gap-1 text-xs">
                {mgData.passHistory.slice(-4).map((pass: any, i: number) => (
                  <div key={i} className="text-slate-300 font-bold">
                    {room.players[pass.from]?.name} ➔ {room.players[pass.to]?.name}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      );

    // 4. DON'T TOUCH
    case 'dont-touch':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-8">
          <div className={`text-6xl lg:text-7xl font-black font-heading ${
            mgData.nowTriggered ? 'text-emerald-400 scale-125 animate-ping' : 'text-rose-400'
          }`}>
            {mgData.currentPrompt || "NE ÉRJ HOZZÁ!"}
          </div>
          <p className="text-slate-400 text-base font-bold">
            Csak a NOW! jelzésre szabad nyomni!
          </p>
        </div>
      );

    // 5. PERFECT STOP
    case 'perfect-stop':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-8 w-full max-w-3xl">
          <h2 className="text-3xl font-black text-amber-300 font-heading">
            🎯 ÁLLÍTSD MEG A KÖZÉPPONTBAN!
          </h2>
          <div className="grid grid-cols-2 gap-4 w-full">
            {players.map(p => {
              const stop = mgData.stops?.[p.id];
              return (
                <div key={p.id} className="bg-slate-800/80 p-4 rounded-2xl border border-slate-700 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-2xl">{AVATARS[p.avatar]?.emoji}</span>
                    <span className="font-bold text-white">{p.name}</span>
                  </div>
                  <span className="font-mono font-black text-amber-400">
                    {stop !== undefined ? `${100 - Math.abs(stop)}% pontosság` : 'Céloz...'}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      );

    // 6. TAP WAR
    case 'tap-war':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <div className={`text-6xl font-black font-heading ${
            mgData.stopTriggered ? 'text-red-500 scale-125 animate-pulse' : 'text-emerald-400'
          }`}>
            {mgData.stopTriggered ? '⛔ STOP! NE NYOMD TOVÁBB! ⛔' : '⚡ TAPELJ GŐZERŐVEL! ⚡'}
          </div>
          <div className="flex flex-wrap gap-4 justify-center">
            {players.map(p => (
              <div key={p.id} className="bg-slate-800/80 p-4 rounded-2xl border border-slate-700 flex items-center gap-3">
                <span className="text-3xl">{AVATARS[p.avatar]?.emoji}</span>
                <div>
                  <span className="font-bold text-white block">{p.name}</span>
                  <span className="text-amber-400 font-black font-mono">
                    {mgData.taps?.[p.id] || 0} tap
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      );

    // 7. BALANCE
    case 'balance':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <h2 className="text-3xl font-black text-teal-300 font-heading">
            ⚖️ STABILITÁSI VERSENY
          </h2>
          <div className="flex flex-wrap gap-4 justify-center">
            {players.map(p => {
              const sec = Math.round((mgData.centerTime?.[p.id] || 0) * 10) / 10;
              return (
                <div key={p.id} className="bg-slate-800/80 p-4 rounded-2xl border border-slate-700 flex items-center gap-3">
                  <span className="text-3xl">{AVATARS[p.avatar]?.emoji}</span>
                  <div>
                    <span className="font-bold text-white block">{p.name}</span>
                    <span className="text-teal-400 font-mono font-black">{sec}s középen</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      );

    // 8. CHOOSE YOUR ENEMY
    case 'choose-your-enemy':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <h2 className="text-4xl font-black text-purple-400 font-heading">
            🗡️ VÁLASSZ ELLENSÉGET!
          </h2>
          <p className="text-slate-300 text-lg font-bold">
            Mindenki titokban választ a telefonján! Senki által nem választott = +5 coin!
          </p>
          <div className="text-2xl text-amber-400 font-mono font-bold animate-pulse">
            Szavazatok érkezése folyamatban...
          </div>
        </div>
      );

    // 9. BUTTON CHICKEN
    case 'button-chicken':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <div className={`text-6xl font-black font-heading ${
            mgData.exploded ? 'text-red-500 scale-125' : 'text-amber-400'
          }`}>
            {mgData.exploded ? '💥 BUMM! FELROBBANT A GOMB! 💥' : '🐔 BUTTON CHICKEN!'}
          </div>
          <div className="flex flex-wrap gap-4 justify-center">
            {players.map(p => {
              const banked = mgData.banked?.[p.id];
              const presses = mgData.presses?.[p.id] || 0;
              return (
                <div key={p.id} className="bg-slate-800/80 p-4 rounded-2xl border border-slate-700 flex items-center gap-3">
                  <span className="text-3xl">{AVATARS[p.avatar]?.emoji}</span>
                  <div>
                    <span className="font-bold text-white block">{p.name}</span>
                    <span className="text-xs font-bold" style={{ color: banked ? '#10b981' : '#f59e0b' }}>
                      {banked ? `✅ LEBANKOLVA (${presses}🪙)` : `Kockáztat (${presses}🪙)`}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      );

    // 10. HOLD YOUR NERVE
    case 'hold-your-nerve':
      const currentMult = (1 + (mgData.elapsed || 0) * 0.8).toFixed(1);
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <div className={`text-7xl lg:text-9xl font-black font-mono ${
            mgData.crashed ? 'text-red-500 animate-ping' : 'text-amber-400'
          }`}>
            {mgData.crashed ? 'CRASH! 0x' : `${currentMult}x`}
          </div>
          <p className="text-slate-300 text-lg font-bold">
            Engedd fel a telefonodon a CRASH előtt!
          </p>
        </div>
      );

    // 11. SAFE TILE
    case 'safe-tile':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <h2 className="text-3xl font-black text-white font-heading">
            🛡️ BIZTONSÁGOS MEZŐ KERESÉSE
          </h2>
          <div className="grid grid-cols-2 gap-4 w-80 h-80">
            <div className="bg-red-600 rounded-3xl flex items-center justify-center text-4xl shadow-xl">🔴</div>
            <div className="bg-blue-600 rounded-3xl flex items-center justify-center text-4xl shadow-xl">🔵</div>
            <div className="bg-green-600 rounded-3xl flex items-center justify-center text-4xl shadow-xl">🟢</div>
            <div className="bg-yellow-500 rounded-3xl flex items-center justify-center text-4xl shadow-xl">🟡</div>
          </div>
        </div>
      );

    // 12. COPYCAT
    case 'copycat':
      return (
        <div className="flex flex-col items-center justify-center h-full gap-8">
          <h2 className="text-3xl font-black text-amber-300 font-heading">
            🐱 KÖVESD A MINTÁT!
          </h2>
          <div className="flex items-center gap-4 bg-slate-900/80 p-6 rounded-3xl border border-slate-700 shadow-2xl">
            {mgData.sequence?.map((sym: string, i: number) => (
              <span key={i} className="text-6xl animate-bounce" style={{ animationDelay: `${i * 0.2}s` }}>
                {sym}
              </span>
            ))}
          </div>
        </div>
      );

    // 16. TUG OF WAR
    case 'tug-of-war':
      const teamScores = mgData.teamScores || {};
      return (
        <div className="flex flex-col items-center justify-center h-full gap-8 w-full max-w-4xl">
          <h2 className="text-3xl font-black text-amber-300 font-heading">
            🪢 KÖTÉLHÚZÁS (2 vs 2 vs 1)
          </h2>
          <div className="grid grid-cols-3 gap-6 w-full">
            <div className="bg-blue-600/30 p-6 rounded-3xl border border-blue-400 text-center">
              <span className="text-xs uppercase font-black text-blue-300 block">"A" CSAPAT</span>
              <span className="text-4xl font-black text-white font-mono">{Math.round(teamScores.A || 0)}</span>
            </div>
            <div className="bg-red-600/30 p-6 rounded-3xl border border-red-400 text-center">
              <span className="text-xs uppercase font-black text-red-300 block">"B" CSAPAT</span>
              <span className="text-4xl font-black text-white font-mono">{Math.round(teamScores.B || 0)}</span>
            </div>
            <div className="bg-amber-500/30 p-6 rounded-3xl border border-amber-400 text-center">
              <span className="text-xs uppercase font-black text-amber-300 block">SOLO JÁTÉKOS (1.7x)</span>
              <span className="text-4xl font-black text-white font-mono">{Math.round(teamScores.SOLO || 0)}</span>
            </div>
          </div>
        </div>
      );

    // 17. BOSS BATTLE
    case 'boss-battle':
      const boss = room.players[mgData.bossId];
      const bossHp = Math.round(mgData.bossHp || 0);
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6 w-full max-w-3xl">
          <div className="text-5xl animate-bounce">👹</div>
          <h2 className="text-3xl font-black text-rose-400 font-heading">
            BOSS BATTLE: {boss?.name || 'Vezető'} ellen!
          </h2>
          {/* HP Bar */}
          <div className="w-full bg-slate-800 rounded-full h-8 overflow-hidden border-2 border-red-500 shadow-xl">
            <div
              className="bg-gradient-to-r from-red-600 to-rose-400 h-full transition-all duration-300"
              style={{ width: `${Math.max(0, bossHp)}%` }}
            />
          </div>
          <span className="text-xl font-black text-red-300 font-mono">
            BOSS HP: {bossHp} / 100
          </span>
        </div>
      );

    // Generic fallback renderer for remaining games (Fake buttons, Last second, Secret number, etc.)
    default:
      return (
        <div className="flex flex-col items-center justify-center h-full gap-6">
          <div className="text-6xl animate-pulse">🎮</div>
          <h2 className="text-4xl font-black text-amber-300 font-heading">
            {mg.name}
          </h2>
          <p className="text-slate-300 text-xl font-bold max-w-xl text-center">
            {mg.description}
          </p>
          <div className="flex flex-wrap gap-4 justify-center mt-6">
            {players.map(p => (
              <div key={p.id} className="bg-slate-800/80 p-3 rounded-2xl border border-slate-700 flex items-center gap-2">
                <span className="text-2xl">{AVATARS[p.avatar]?.emoji}</span>
                <span className="font-bold text-white text-sm">{p.name}</span>
              </div>
            ))}
          </div>
        </div>
      );
  }
};
