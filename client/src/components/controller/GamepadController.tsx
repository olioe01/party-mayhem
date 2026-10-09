import React, { useState, useEffect, useRef, useCallback } from 'react';
import { RoomState, Player, GamepadInputState, MinigameControllerConfig } from '@shared/types';
import { socket } from '../../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { DPad } from './DPad';
import { ActionButton } from './ActionButton';
import { RotateCcw, Timer } from 'lucide-react';
import { AVATARS } from '@shared/constants';

interface GamepadControllerProps {
  room: RoomState;
  player: Player;
  config?: MinigameControllerConfig;
  scoreDisplay?: React.ReactNode;
}

export const GamepadController: React.FC<GamepadControllerProps> = ({
  room,
  player,
  config,
  scoreDisplay,
}) => {
  const mg = room.activeMinigame;

  // Track orientation: is phone currently landscape?
  const [isLandscape, setIsLandscape] = useState<boolean>(() => {
    if (typeof window === 'undefined') return true;
    return window.innerWidth >= window.innerHeight;
  });

  useEffect(() => {
    const checkOrientation = () => {
      setIsLandscape(window.innerWidth >= window.innerHeight);
    };
    window.addEventListener('resize', checkOrientation);
    window.addEventListener('orientationchange', checkOrientation);
    return () => {
      window.removeEventListener('resize', checkOrientation);
      window.removeEventListener('orientationchange', checkOrientation);
    };
  }, []);

  // Current controller input state
  const inputStateRef = useRef<GamepadInputState>({
    up: false,
    down: false,
    left: false,
    right: false,
    a: false,
    b: false,
  });

  const sendInputState = useCallback((state: GamepadInputState) => {
    socket.emit(SOCKET_EVENTS.MINIGAME_INPUT, {
      roomCode: room.roomCode,
      input: state,
    });
  }, [room.roomCode]);

  // Clean disconnect safety: reset inputs when unmounting
  useEffect(() => {
    return () => {
      sendInputState({
        up: false,
        down: false,
        left: false,
        right: false,
        a: false,
        b: false,
      });
    };
  }, [sendInputState]);

  const handleDirectionChange = (dirs: { up: boolean; down: boolean; left: boolean; right: boolean }) => {
    const cur = inputStateRef.current;
    if (
      cur.up !== dirs.up ||
      cur.down !== dirs.down ||
      cur.left !== dirs.left ||
      cur.right !== dirs.right
    ) {
      const next = { ...cur, ...dirs };
      inputStateRef.current = next;
      sendInputState(next);
    }
  };

  const handleAChange = (pressed: boolean) => {
    if (inputStateRef.current.a !== pressed) {
      const next = { ...inputStateRef.current, a: pressed };
      inputStateRef.current = next;
      sendInputState(next);
    }
  };

  const handleBChange = (pressed: boolean) => {
    if (inputStateRef.current.b !== pressed) {
      const next = { ...inputStateRef.current, b: pressed };
      inputStateRef.current = next;
      sendInputState(next);
    }
  };

  const avatar = AVATARS[player.avatar] || AVATARS['fox'];
  const aLabel = config?.aLabel || 'AKCIÓ';
  const bLabel = config?.bLabel || 'KÜLÖNLEGES';
  const aHidden = Boolean(config?.aHidden);
  const bHidden = Boolean(config?.bHidden);

  return (
    <div
      className="fixed inset-0 w-screen h-screen bg-slate-950 text-white select-none touch-none overscroll-none overflow-hidden flex flex-col justify-between"
      style={{ touchAction: 'none', userSelect: 'none', WebkitUserSelect: 'none' }}
    >
      {/* PORTRAIT WARNING OVERLAY: Gentle prompt to tilt to landscape */}
      {!isLandscape && (
        <div className="fixed inset-0 z-50 bg-slate-950/95 backdrop-blur-xl flex flex-col items-center justify-center p-6 text-center gap-4">
          <div className="relative w-20 h-20 flex items-center justify-center">
            <RotateCcw className="w-16 h-16 text-amber-400 animate-spin" style={{ animationDuration: '4s' }} />
          </div>
          <h2 className="text-2xl font-black text-white font-heading">
            FORDÍTSD EL A TELEFONT!
          </h2>
          <p className="text-sm font-bold text-slate-400 max-w-xs">
            A játékhoz fekvő tájolás szükséges a kényelmes kétkezes irányításhoz.
          </p>
          <div className="px-4 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-amber-300 font-mono">
            🔄 Képernyő elforgatása (Landscape)
          </div>
        </div>
      )}

      {/* TOP COMPACT HUD */}
      <header className="w-full px-6 py-2 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between shrink-0 z-20">
        {/* Left: Player identity */}
        <div className="flex items-center gap-2">
          <span className="text-xl">{avatar.emoji}</span>
          <span className="font-extrabold text-sm truncate max-w-[120px] sm:max-w-xs" style={{ color: player.color || '#fff' }}>
            {player.name}
          </span>
        </div>

        {/* Center: Live minigame score / info */}
        <div className="flex items-center gap-3">
          {scoreDisplay ? (
            <div className="font-black text-amber-300 font-mono text-base px-3 py-0.5 rounded-lg bg-slate-800 border border-amber-400/40">
              {scoreDisplay}
            </div>
          ) : (
            <span className="text-xs font-black uppercase tracking-wider text-slate-400">
              {mg?.name || 'MINIJÁTÉK'}
            </span>
          )}
        </div>

        {/* Right: Remaining timer */}
        <div className="flex items-center gap-1 font-mono font-black text-amber-400 text-xs bg-slate-800 px-2.5 py-1 rounded-lg border border-slate-700">
          <Timer className="w-3.5 h-3.5" />
          <span>{mg ? Math.ceil(mg.timeRemaining) : 0}s</span>
        </div>
      </header>

      {/* CONTROLLER MAIN PLAY AREA */}
      <main className="flex-1 w-full px-4 sm:px-8 py-2 flex items-center justify-between relative">
        {/* LEFT THUMB: D-PAD */}
        <section className="flex items-center justify-center p-2 z-20" aria-label="D-Pad">
          <DPad onDirectionChange={handleDirectionChange} />
        </section>

        {/* CENTER DECORATIVE LOGO / GAMEPAD BADGE */}
        <section className="hidden md:flex flex-col items-center justify-center pointer-events-none opacity-30 select-none">
          <span className="text-xs font-black tracking-widest uppercase text-slate-500 font-mono">
            PARTY MAYHEM
          </span>
          <span className="text-[10px] text-slate-600 font-bold">
            WIRELESS CONTROLLER
          </span>
        </section>

        {/* RIGHT THUMB: ACTION BUTTONS (A / B) */}
        <section className="flex items-center justify-center gap-4 sm:gap-6 p-2 z-20" aria-label="Action Buttons">
          {/* B Button (Secondary) */}
          {!bHidden && (
            <div className="flex flex-col items-center">
              <ActionButton
                label="B"
                subLabel={bLabel}
                colorScheme="secondary"
                disabled={bHidden}
                onChange={handleBChange}
              />
            </div>
          )}

          {/* A Button (Primary) */}
          {!aHidden && (
            <div className="flex flex-col items-center translate-y-[-12px] sm:translate-y-[-16px]">
              <ActionButton
                label="A"
                subLabel={aLabel}
                colorScheme="primary"
                disabled={aHidden}
                onChange={handleAChange}
              />
            </div>
          )}
        </section>
      </main>

      {/* BOTTOM SLIM BAR */}
      <footer className="w-full py-1 px-4 bg-slate-950/80 border-t border-slate-900 flex items-center justify-center text-[10px] text-slate-500 font-bold tracking-tight">
        <span>🎮 Bal kéz: D-pad mozgatás • Jobb kéz: Gombok</span>
      </footer>
    </div>
  );
};
