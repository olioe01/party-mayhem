import React, { useState, useEffect, useRef } from 'react';
import { RoomState } from '@shared/types';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { AVATARS } from '@shared/constants';
import { sounds } from '../audio/soundSynth';
import { Bomb, Flame, Shield, Zap, AlertTriangle } from 'lucide-react';

interface MinigamePlayerRendererProps {
  room: RoomState;
  playerId: string;
}

export const MinigamePlayerRenderer: React.FC<MinigamePlayerRendererProps> = ({ room, playerId }) => {
  const mg = room.activeMinigame;
  if (!mg) return null;
  const mgData = mg.data || {};
  const me = room.players[playerId];

  const sendInput = (input: any) => {
    socket.emit(SOCKET_EVENTS.MINIGAME_INPUT, {
      roomCode: room.roomCode,
      input
    });
  };

  switch (mg.id) {
    // 1. REACTION RUSH
    case 'reaction-rush': {
      const reacted = mgData.reactions?.[playerId];
      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          <button
            onClick={() => {
              sounds.playButton();
              sendInput({ action: 'tap' });
            }}
            disabled={!!reacted}
            className={`w-full max-w-sm h-64 rounded-3xl font-black text-3xl shadow-2xl transition-transform active:scale-95 flex flex-col items-center justify-center gap-4 ${
              reacted
                ? reacted.falseStart
                  ? 'bg-red-600 text-white'
                  : 'bg-emerald-600 text-white'
                : 'bg-gradient-to-br from-amber-400 to-orange-500 text-slate-950 animate-pulse'
            }`}
          >
            <span>{reacted ? (reacted.falseStart ? '❌ KORAI RAJT!' : '✅ MEGNYOMVA!') : '💥 NYOMD MEG!'}</span>
            {!reacted && <span className="text-xs font-bold opacity-80">Csak a GO után!</span>}
          </button>
        </div>
      );
    }

    // 2. SHAKE IT
    case 'shake-it': {
      const [shakeCount, setShakeCount] = useState(0);

      useEffect(() => {
        // Accelerometer handling
        const handleMotion = (event: DeviceMotionEvent) => {
          const acc = event.accelerationIncludingGravity;
          if (acc) {
            const speed = Math.abs(acc.x || 0) + Math.abs(acc.y || 0) + Math.abs(acc.z || 0);
            if (speed > 25) {
              setShakeCount(prev => prev + 1);
              sendInput({ intensity: 1 });
            }
          }
        };

        if (window.DeviceMotionEvent) {
          window.addEventListener('devicemotion', handleMotion);
        }
        return () => {
          if (window.DeviceMotionEvent) {
            window.removeEventListener('devicemotion', handleMotion);
          }
        };
      }, []);

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-6">
          <div className="text-center">
            <h3 className="text-2xl font-black text-amber-300 font-heading">
              RÁZD A TELEFONT!
            </h3>
            <p className="text-xs text-slate-400">Vagy nyomd a gombot ha nincs mozgásérzékelő!</p>
          </div>

          <button
            onClick={() => {
              sounds.playButton();
              setShakeCount(c => c + 1);
              sendInput({ intensity: 1 });
            }}
            className="w-full max-w-sm h-56 rounded-3xl bg-gradient-to-br from-orange-500 to-amber-400 font-black text-3xl text-slate-950 shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-2"
          >
            <span className="text-5xl animate-bounce">🚀</span>
            <span>RÁZD VAGY TAP!</span>
            <span className="text-sm font-mono font-bold bg-slate-950/20 px-3 py-1 rounded-full">
              Pontok: {shakeCount}
            </span>
          </button>
        </div>
      );
    }

    // 3. BOMB PASS
    case 'bomb-pass': {
      const isHolder = mgData.currentHolder === playerId;
      const otherPlayers = Object.values(room.players).filter(p => p.id !== playerId);

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-4">
          {isHolder ? (
            <>
              <div className="flex items-center gap-2 text-red-400 font-black text-xl animate-pulse">
                <Bomb className="w-8 h-8" />
                <span>NÁLAD A BOMBA! ADD TOVÁBB!</span>
              </div>
              <div className="grid grid-cols-2 gap-3 w-full max-w-sm">
                {otherPlayers.map(p => (
                  <button
                    key={p.id}
                    onClick={() => {
                      sounds.playBombTick(2);
                      sendInput({ targetPlayerId: p.id });
                    }}
                    className="p-4 rounded-2xl bg-slate-800 border-2 border-red-500/80 hover:bg-red-950 text-white font-bold flex flex-col items-center gap-2 active:scale-95 shadow-lg"
                  >
                    <span className="text-3xl">{AVATARS[p.avatar]?.emoji}</span>
                    <span className="text-sm truncate w-full text-center">{p.name}</span>
                  </button>
                ))}
              </div>
            </>
          ) : (
            <div className="text-center flex flex-col items-center gap-4">
              <span className="text-6xl animate-bounce">🛡️</span>
              <h3 className="text-2xl font-black text-emerald-400 font-heading">
                BIZTONSÁGBAN VAGY!
              </h3>
              <p className="text-sm text-slate-400 font-bold">
                A bomba másnál van... Figyeld, mikor passzolják neked!
              </p>
            </div>
          )}
        </div>
      );
    }

    // 4. DON'T TOUCH
    case 'dont-touch': {
      const tapped = mgData.taps?.[playerId];
      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          <button
            onClick={() => {
              sounds.playButton();
              sendInput({ action: 'touch' });
            }}
            disabled={!!tapped}
            className={`w-full max-w-sm h-64 rounded-3xl font-black text-3xl shadow-2xl flex flex-col items-center justify-center gap-3 active:scale-95 ${
              tapped
                ? tapped.disqualified
                  ? 'bg-red-600 text-white'
                  : 'bg-emerald-600 text-white'
                : 'bg-slate-800 border-4 border-rose-500 text-rose-300'
            }`}
          >
            <span>{tapped ? (tapped.disqualified ? '❌ KORAI ÉRINTÉS!' : '✅ SIKERES!') : 'NE ÉRJ HOZZÁ!'}</span>
            {!tapped && <span className="text-xs text-slate-400 font-bold">Figyeld a TV-t!</span>}
          </button>
        </div>
      );
    }

    // 5. PERFECT STOP
    case 'perfect-stop': {
      const [pos, setPos] = useState(0);
      const stopped = mgData.stops?.[playerId] !== undefined;

      useEffect(() => {
        if (stopped) return;
        let direction = 1;
        const interval = setInterval(() => {
          setPos(prev => {
            if (prev >= 100) direction = -1;
            if (prev <= -100) direction = 1;
            return prev + direction * 8;
          });
        }, 30);
        return () => clearInterval(interval);
      }, [stopped]);

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-8">
          <div className="w-full max-w-sm bg-slate-800 rounded-full h-8 relative overflow-hidden border-2 border-slate-700">
            {/* Center target zone */}
            <div className="absolute top-0 bottom-0 left-1/2 -translate-x-1/2 w-8 bg-amber-400/80 z-10" />
            {/* Moving Indicator */}
            <div
              className="absolute top-0 bottom-0 w-6 bg-cyan-400 rounded-full transition-all duration-30"
              style={{ left: `${50 + (pos / 2)}%`, transform: 'translateX(-50%)' }}
            />
          </div>

          <button
            onClick={() => {
              sounds.playButton();
              sendInput({ position: pos });
            }}
            disabled={stopped}
            className="w-full max-w-sm py-8 rounded-3xl bg-gradient-to-r from-cyan-500 to-blue-600 text-slate-950 font-black text-3xl shadow-2xl active:scale-95 disabled:opacity-60"
          >
            {stopped ? 'MEGÁLLÍTVA!' : '🎯 STOP!'}
          </button>
        </div>
      );
    }

    // 6. TAP WAR
    case 'tap-war': {
      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          <button
            onClick={() => {
              sounds.playButton();
              sendInput({ action: 'tap' });
            }}
            className="w-full max-w-sm h-64 rounded-3xl bg-gradient-to-br from-emerald-400 to-teal-500 text-slate-950 font-black text-4xl shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-2"
          >
            <span>⚡ TAPELJ!</span>
            <span className="text-xs uppercase font-bold text-slate-900">
              Figyelj a STOP jelzésre!
            </span>
          </button>
        </div>
      );
    }

    // 7. BALANCE
    case 'balance': {
      const [ballPos, setBallPos] = useState({ x: 0, y: 0 });

      useEffect(() => {
        const handleOrientation = (e: DeviceOrientationEvent) => {
          const gamma = e.gamma || 0; // Left-Right (-90 to 90)
          const beta = e.beta || 0;   // Front-Back (-180 to 180)
          const x = Math.max(-50, Math.min(50, gamma * 2));
          const y = Math.max(-50, Math.min(50, beta * 2));
          setBallPos({ x, y });
          const dist = Math.sqrt(x * x + y * y);
          if (dist < 25) {
            sendInput({ inCenter: true });
          }
        };

        if (window.DeviceOrientationEvent) {
          window.addEventListener('deviceorientation', handleOrientation);
        }
        return () => {
          if (window.DeviceOrientationEvent) {
            window.removeEventListener('deviceorientation', handleOrientation);
          }
        };
      }, []);

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-6">
          <h3 className="text-xl font-black text-teal-300 font-heading">
            TARTSD A KÖRBEN A GOLYÓT!
          </h3>
          <div className="w-64 h-64 bg-slate-900 border-4 border-teal-500/80 rounded-full relative flex items-center justify-center shadow-2xl overflow-hidden">
            <div className="w-24 h-24 border-2 border-dashed border-teal-300 rounded-full" />
            <div
              className="w-10 h-10 bg-teal-400 rounded-full absolute shadow-lg transition-all duration-75"
              style={{
                transform: `translate(${ballPos.x * 1.5}px, ${ballPos.y * 1.5}px)`
              }}
            />
          </div>
          <button
            onClick={() => {
              setBallPos({ x: 0, y: 0 });
              sendInput({ inCenter: true });
            }}
            className="text-xs text-slate-400 underline font-bold"
          >
            Középre állítás (Fallback)
          </button>
        </div>
      );
    }

    // 8. CHOOSE YOUR ENEMY
    case 'choose-your-enemy': {
      const voted = mgData.votes?.[playerId];
      const otherPlayers = Object.values(room.players).filter(p => p.id !== playerId);

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-4">
          <h3 className="text-xl font-black text-purple-400 font-heading text-center">
            {voted ? 'SZAVAZAT LEADVA!' : 'VÁLASSZ VALAKIT TITKOBAN!'}
          </h3>
          <div className="grid grid-cols-2 gap-3 w-full max-w-sm">
            {otherPlayers.map(p => (
              <button
                key={p.id}
                disabled={!!voted}
                onClick={() => {
                  sounds.playButton();
                  sendInput({ targetPlayerId: p.id });
                }}
                className={`p-4 rounded-2xl border-2 flex flex-col items-center gap-2 active:scale-95 shadow-md ${
                  voted === p.id
                    ? 'bg-purple-600 border-purple-300 text-white'
                    : 'bg-slate-800 border-slate-700 text-slate-200'
                }`}
              >
                <span className="text-3xl">{AVATARS[p.avatar]?.emoji}</span>
                <span className="text-sm font-bold truncate w-full text-center">{p.name}</span>
              </button>
            ))}
          </div>
        </div>
      );
    }

    // 9. BUTTON CHICKEN
    case 'button-chicken': {
      const banked = mgData.banked?.[playerId];
      const presses = mgData.presses?.[playerId] || 0;

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-4">
          <div className="text-center font-bold text-slate-300">
            Gyűjtött érme: <span className="text-2xl text-amber-300 font-black">{presses} 🪙</span>
          </div>

          <button
            onClick={() => {
              sounds.playCoin();
              sendInput({ action: 'press' });
            }}
            disabled={banked || mgData.exploded}
            className="w-full max-w-sm h-44 rounded-3xl bg-red-600 hover:bg-red-500 text-white font-black text-3xl shadow-2xl active:scale-95 disabled:opacity-50"
          >
            🔥 +1 COIN!
          </button>

          <button
            onClick={() => {
              sounds.playCorrect();
              sendInput({ action: 'bank' });
            }}
            disabled={banked || mgData.exploded}
            className="w-full max-w-sm py-4 rounded-2xl bg-emerald-600 text-white font-black text-xl shadow-xl active:scale-95 disabled:opacity-50"
          >
            {banked ? '✅ LEBANKOLVA!' : '💰 BANK IT (LEZÁRÁS)'}
          </button>
        </div>
      );
    }

    // 10. HOLD YOUR NERVE
    case 'hold-your-nerve': {
      const released = mgData.releasedAt?.[playerId] !== undefined;

      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          <button
            onPointerDown={() => {
              sounds.playButton();
            }}
            onPointerUp={() => {
              sounds.playCorrect();
              sendInput({ action: 'release' });
            }}
            disabled={released || mgData.crashed}
            className={`w-full max-w-sm h-72 rounded-3xl font-black text-3xl shadow-2xl flex flex-col items-center justify-center gap-3 ${
              released
                ? 'bg-emerald-600 text-white'
                : 'bg-gradient-to-br from-indigo-500 to-purple-600 text-white active:scale-95'
            }`}
          >
            <span>{released ? '✅ LEZÁRVA!' : '🖐️ TARTSD LENYOMVA!'}</span>
            <span className="text-xs font-bold opacity-80">
              Engedd fel a CRASH előtt!
            </span>
          </button>
        </div>
      );
    }

    // 11. SAFE TILE
    case 'safe-tile': {
      const chosen = mgData.choices?.[playerId];
      const tiles = [
        { id: 'red', icon: '🔴', label: 'Piros', bg: 'bg-red-600' },
        { id: 'blue', icon: '🔵', label: 'Kék', bg: 'bg-blue-600' },
        { id: 'green', icon: '🟢', label: 'Zöld', bg: 'bg-green-600' },
        { id: 'yellow', icon: '🟡', label: 'Sárga', bg: 'bg-yellow-500' }
      ];

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-4">
          <h3 className="text-xl font-black text-white font-heading">
            VÁLASSZ EGY SZÍNT!
          </h3>
          <div className="grid grid-cols-2 gap-4 w-full max-w-sm">
            {tiles.map(t => (
              <button
                key={t.id}
                disabled={!!chosen}
                onClick={() => {
                  sounds.playButton();
                  sendInput({ color: t.id });
                }}
                className={`${t.bg} h-36 rounded-3xl flex flex-col items-center justify-center gap-2 text-2xl font-black shadow-xl active:scale-95 ${
                  chosen === t.id ? 'ring-4 ring-white' : ''
                }`}
              >
                <span>{t.icon}</span>
                <span className="text-sm uppercase tracking-wider">{t.label}</span>
              </button>
            ))}
          </div>
        </div>
      );
    }

    // 12. COPYCAT
    case 'copycat': {
      const [seq, setSeq] = useState<string[]>([]);
      const buttons = ['🔴', '🔵', '🟢', '🟡'];

      const handlePress = (sym: string) => {
        sounds.playButton();
        const next = [...seq, sym];
        setSeq(next);
        if (next.length === 4) {
          sendInput({ sequence: next, time: 3 });
        }
      };

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-6">
          <div className="flex items-center gap-2 text-2xl h-12">
            {seq.map((s, i) => (
              <span key={i} className="animate-bounce">{s}</span>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-4 w-full max-w-sm">
            {buttons.map(b => (
              <button
                key={b}
                disabled={seq.length >= 4}
                onClick={() => handlePress(b)}
                className="bg-slate-800 border-2 border-slate-700 h-28 rounded-2xl text-4xl shadow-lg active:scale-95"
              >
                {b}
              </button>
            ))}
          </div>
        </div>
      );
    }

    // 16. TUG OF WAR
    case 'tug-of-war': {
      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          <button
            onClick={() => {
              sounds.playButton();
              sendInput({ action: 'pull' });
            }}
            className="w-full max-w-sm h-64 rounded-3xl bg-gradient-to-br from-amber-400 to-orange-500 text-slate-950 font-black text-3xl shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-2"
          >
            <span>🪢 HÚZD A KÖTELET!</span>
            <span className="text-xs uppercase font-bold">Gyors tapelés!</span>
          </button>
        </div>
      );
    }

    // 17. BOSS BATTLE
    case 'boss-battle': {
      const isBoss = mgData.bossId === playerId;
      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          {isBoss ? (
            <button
              onClick={() => {
                sounds.playButton();
                sendInput({ action: 'shield' });
              }}
              className="w-full max-w-sm h-64 rounded-3xl bg-red-600 text-white font-black text-3xl shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-2"
            >
              <Shield className="w-12 h-12" />
              <span>PAJZS TÖLTÉSE!</span>
            </button>
          ) : (
            <button
              onClick={() => {
                sounds.playButton();
                sendInput({ action: 'attack' });
              }}
              className="w-full max-w-sm h-64 rounded-3xl bg-gradient-to-br from-amber-400 to-orange-500 text-slate-950 font-black text-3xl shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-2"
            >
              <Flame className="w-12 h-12" />
              <span>TÁMADÁS A BOSSRA!</span>
            </button>
          )}
        </div>
      );
    }

    // 19. SECRET NUMBER
    case 'secret-number': {
      const chosen = mgData.choices?.[playerId];
      const numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

      return (
        <div className="flex flex-col items-center justify-center h-full p-4 gap-4">
          <h3 className="text-xl font-black text-white font-heading text-center">
            {chosen ? `KIVÁLASZTVA: ${chosen}` : 'VÁLASSZ SZÁMOT 1 ÉS 10 KÖZÖTT!'}
          </h3>
          <div className="grid grid-cols-5 gap-3 w-full max-w-sm">
            {numbers.map(num => (
              <button
                key={num}
                disabled={chosen !== undefined}
                onClick={() => {
                  sounds.playButton();
                  sendInput({ number: num });
                }}
                className={`py-4 rounded-2xl font-black text-2xl border-2 shadow-md active:scale-95 ${
                  chosen === num
                    ? 'bg-amber-400 border-white text-slate-950'
                    : 'bg-slate-800 border-slate-700 text-white'
                }`}
              >
                {num}
              </button>
            ))}
          </div>
        </div>
      );
    }

    // Fallback: Generic Tap Controller
    default:
      return (
        <div className="flex flex-col items-center justify-center h-full p-4">
          <button
            onClick={() => {
              sounds.playButton();
              sendInput({ action: 'tap' });
            }}
            className="w-full max-w-sm h-64 rounded-3xl bg-gradient-to-br from-amber-400 to-orange-500 text-slate-950 font-black text-3xl shadow-2xl active:scale-95 flex flex-col items-center justify-center gap-2"
          >
            <span>🎯 NYOMD MEG!</span>
            <span className="text-xs uppercase font-bold text-slate-900">
              {mg.instructions}
            </span>
          </button>
        </div>
      );
  }
};
