import React, { useState } from 'react';
import { RoomState, Player } from '@shared/types';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { sounds } from '../audio/soundSynth';
import { AVATARS, CROWN_COST_COINS } from '@shared/constants';
import { SoundToggle } from '../components/SoundToggle';
import { Dices, Crown, Shield, Eye, EyeOff } from 'lucide-react';

interface PlayerBoardControlsProps {
  room: RoomState;
  player: Player;
}

export const PlayerBoardControls: React.FC<PlayerBoardControlsProps> = ({ room, player }) => {
  const [showSecretMission, setShowSecretMission] = useState(false);
  const activePlayerId = room.playerOrder[room.currentPlayerIndex];
  const isMyTurn = activePlayerId === player.id;
  const isRollingPhase = room.phase === 'BOARD_ROLL';
  const isShopPhase = room.phase === 'SHOP_DECISION' && isMyTurn;
  const isForkPhase = Boolean(room.activeForkChoice && room.activeForkChoice.playerId === player.id);

  const handleRollDice = () => {
    sounds.playDice();
    socket.emit(SOCKET_EVENTS.PLAYER_ROLL_DICE, { roomCode: room.roomCode });
  };

  const handleForkChoice = (chosenBranch: number) => {
    sounds.playButton();
    socket.emit(SOCKET_EVENTS.CHOOSE_FORK, { roomCode: room.roomCode, chosenBranch });
  };

  const handleShopDecision = (buy: boolean) => {
    if (buy) {
      sounds.playCrown();
    } else {
      sounds.playButton();
    }
    socket.emit(SOCKET_EVENTS.DECIDE_SHOP, { roomCode: room.roomCode, buy });
  };

  const avatar = AVATARS[player.avatar] || AVATARS['fox'];
  const activePlayerObj = room.players[activePlayerId];

  return (
    <div className="min-h-screen bg-slate-950 text-white flex flex-col p-5 select-none relative justify-between">
      {/* Top HUD */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-3">
        <div className="flex items-center gap-2.5">
          <div
            className="w-10 h-10 rounded-xl flex items-center justify-center text-2xl shadow"
            style={{ backgroundColor: avatar.color + '33', border: `2px solid ${avatar.color}` }}
          >
            {avatar.emoji}
          </div>
          <div>
            <span className="font-extrabold text-sm block leading-none">{player.name}</span>
            <span className="text-[11px] font-bold text-slate-400">#{player.currentRank}. helyezett</span>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 font-black text-sm bg-slate-900 border border-slate-800 px-3 py-1.5 rounded-xl">
            <span className="text-amber-400">👑 {player.crowns}</span>
            <span className="text-yellow-300">🪙 {player.coins}</span>
          </div>
          <SoundToggle />
        </div>
      </div>

      {/* Main Interactive Center Area */}
      <div className="my-auto flex flex-col items-center justify-center gap-6 py-6 w-full max-w-sm mx-auto">
        {/* 1. Fork Branch Choice on Phone */}
        {isForkPhase ? (
          <div className="bg-slate-900 border-4 border-amber-400 p-6 rounded-3xl shadow-2xl w-full text-center flex flex-col items-center gap-4 animate-bounce">
            <span className="text-5xl">🔀</span>
            <h3 className="text-2xl font-black text-amber-300 font-heading">
              ELÁGAZÁS!
            </h3>
            <p className="text-sm font-bold text-slate-200">
              Válassz merre szeretnél továbbhaladni:
            </p>
            <div className="grid grid-cols-2 gap-3 w-full mt-2">
              {room.activeForkChoice!.branches.map((branchId, idx) => (
                <button
                  key={branchId}
                  onClick={() => handleForkChoice(branchId)}
                  className="py-4 px-3 rounded-2xl bg-gradient-to-r from-amber-500 to-orange-500 text-slate-950 font-black text-base shadow-xl active:scale-95 transition hover:brightness-110 flex flex-col items-center gap-1"
                >
                  <span>{idx === 0 ? '👈 BALRA' : '👉 JOBBRA'}</span>
                  <span className="text-[11px] opacity-80 font-mono">Mező #{branchId}</span>
                </button>
              ))}
            </div>
          </div>
        ) : isShopPhase ? (
          /* 2. Crown Shop Decision on Phone */
          <div className="bg-slate-900 border-4 border-amber-400 p-6 rounded-3xl shadow-2xl w-full text-center flex flex-col items-center gap-4 animate-bounce">
            <Crown className="w-14 h-14 text-amber-400" />
            <h3 className="text-2xl font-black text-amber-300 font-heading">
              CROWN SHOP!
            </h3>
            <p className="text-sm font-bold text-slate-200">
              Veszel egy Koronát 25 érméért?
            </p>
            <div className="grid grid-cols-2 gap-3 w-full mt-2">
              <button
                onClick={() => handleShopDecision(true)}
                disabled={player.coins < CROWN_COST_COINS}
                className={`py-4 rounded-2xl font-black text-base shadow-xl active:scale-95 transition ${
                  player.coins >= CROWN_COST_COINS
                    ? 'bg-emerald-600 text-white'
                    : 'bg-slate-800 text-slate-500 cursor-not-allowed'
                }`}
              >
                IGEN (-25🪙)
              </button>
              <button
                onClick={() => handleShopDecision(false)}
                className="py-4 rounded-2xl bg-slate-800 border border-slate-700 text-slate-300 font-black text-base active:scale-95"
              >
                NEM
              </button>
            </div>
          </div>
        ) : isMyTurn && isRollingPhase ? (
          /* 3. My Turn To Roll Dice! */
          <div className="flex flex-col items-center gap-4 w-full">
            <span className="text-xs uppercase font-black tracking-widest text-amber-400 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/30">
              A TE KÖRÖD KÖVETKEZIK!
            </span>
            <button
              onClick={handleRollDice}
              className="w-full h-56 rounded-3xl bg-gradient-to-br from-amber-400 via-orange-500 to-pink-500 text-slate-950 font-black text-4xl shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-3 transform hover:scale-[1.02] transition-all"
            >
              <Dices className="w-16 h-16 animate-bounce" />
              <span>DOBÁS! (ROLL)</span>
            </button>
          </div>
        ) : isMyTurn && room.phase === 'BOARD_ROLLING' ? (
          /* 4. Dice is Rolling in 3D */
          <div className="flex flex-col items-center gap-4 text-center">
            <div className="w-24 h-24 rounded-3xl bg-amber-500/20 border-2 border-amber-400 flex items-center justify-center text-5xl shadow-2xl animate-spin">
              🎲
            </div>
            <div>
              <span className="text-xs font-black uppercase tracking-widest text-amber-400 block mb-1">
                KOCKADOBÁS...
              </span>
              <h3 className="text-2xl font-black text-white">
                Nézz a TV-re!
              </h3>
              <p className="text-xs text-slate-400 font-bold mt-1">
                A 3D dobókocka épp pörög...
              </p>
            </div>
          </div>
        ) : isMyTurn && room.phase === 'BOARD_MOVE' ? (
          /* 5. Character is Moving Step-by-Step */
          <div className="flex flex-col items-center gap-4 text-center">
            <div className="w-24 h-24 rounded-3xl bg-emerald-500/20 border-2 border-emerald-400 flex items-center justify-center text-5xl shadow-2xl animate-bounce">
              🏃
            </div>
            <div>
              <span className="text-xs font-black uppercase tracking-widest text-emerald-400 block mb-1">
                MOZGÁS FOLYAMATBAN
              </span>
              <h3 className="text-2xl font-black text-white">
                Dobás: 🎲 {room.lastDiceRoll}
              </h3>
              <p className="text-xs text-slate-400 font-bold mt-1">
                A figurád lépked a mezőkön!
              </p>
            </div>
          </div>
        ) : (
          /* 6. Waiting for Other Player */
          <div className="flex flex-col items-center gap-4 text-center">
            <div className="w-20 h-20 rounded-full bg-slate-900 border-2 border-slate-800 flex items-center justify-center text-4xl animate-pulse">
              ⏳
            </div>
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block mb-1">
                KÖR FOLYAMATBAN
              </span>
              <h3 className="text-xl font-black text-slate-200">
                {activePlayerObj ? `${activePlayerObj.name} épp lép...` : 'Várakozás...'}
              </h3>
              <p className="text-xs text-slate-500 font-bold mt-1">
                Figyeld a TV képernyőjét a mozgáshoz!
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Secret Mission Card (Invisible to Host Screen!) */}
      {player.secretMission && (
        <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-3.5 mb-2 w-full max-w-sm mx-auto shadow-lg">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-lg">🤫</span>
              <span className="text-xs font-black uppercase tracking-wider text-purple-400">
                TITKOS KÜLDETÉS
              </span>
            </div>
            <button
              onClick={() => setShowSecretMission(!showSecretMission)}
              className="text-slate-400 hover:text-white p-1"
            >
              {showSecretMission ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>

          {showSecretMission && (
            <div className="mt-2 pt-2 border-t border-slate-800 flex flex-col gap-1 text-xs">
              <span className="font-bold text-white">{player.secretMission.title}</span>
              <span className="text-slate-400">{player.secretMission.description}</span>
              <span className="text-amber-400 font-black mt-1">
                Jutalom: +{player.secretMission.rewardCoins} 🪙
              </span>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
