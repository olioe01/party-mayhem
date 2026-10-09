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

  const clearAllInputs = useCallback(() => {
    const cleared: GamepadInputState = {
      up: false,
      down: false,
      left: false,
      right: false,
      a: false,
      b: false,
    };
    const cur = inputStateRef.current;
    if (cur.up || cur.down || cur.left || cur.right || cur.a || cur.b) {
      inputStateRef.current = cleared;
      sendInputState(cleared);
    }
  }, [sendInputState]);

  // Clean disconnect & unmount safety
  useEffect(() => {
    return () => {
      clearAllInputs();
    };
  }, [clearAllInputs]);

  // Visibility change & window blur safety (clears held inputs if phone app goes to background)
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.hidden) {
        clearAllInputs();
      }
    };
    const handleBlur = () => {
      clearAllInputs();
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('blur', handleBlur);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('blur', handleBlur);
    };
  }, [clearAllInputs]);

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
  const aDisabled = Boolean(config?.aHidden);
  const bDisabled = Boolean(config?.bHidden);
  const aLabel = aDisabled ? '—' : (config?.aLabel || 'AKCIÓ');
  const bLabel = bDisabled ? '—' : (config?.bLabel || 'KÜLÖNLEGES');

  return (
    <div
      className="fixed inset-0 w-screen h-screen bg-slate-950 text-white select-none touch-none overscroll-none overflow-hidden flex flex-col justify-between"
      style={{
        touchAction: 'none',
        userSelect: 'none',
        WebkitUserSelect: 'none',
        paddingTop: 'env(safe-area-inset-top, 0px)',
        paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        paddingLeft: 'env(safe-area-inset-left, 0px)',
        paddingRight: 'env(safe-area-inset-right, 0px)',
      }}
    >
      {/* PORTRAIT WARNING OVERLAY: Prompt to tilt to landscape */}
      {!isLandscape && (
        <div className="fixed inset-0 z-50 bg-slate-950/98 backdrop-blur-2xl flex flex-col items-center justify-center p-6 text-center gap-4">
          <div className="relative w-16 h-16 flex items-center justify-center">
            <RotateCcw className="w-14 h-14 text-amber-400 animate-spin" style={{ animationDuration: '4s' }} />
          </div>
          <h2 className="text-2xl font-black text-white font-heading">
            FORDÍTSD EL A TELEFONT!
          </h2>
          <p className="text-sm font-bold text-slate-400 max-w-xs">
            A minijátékokhoz fekvő tájolás szükséges a kényelmes kétkezes irányításhoz.
          </p>
          <div className="px-4 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-amber-300 font-mono">
            🔄 Képernyő elforgatása (Landscape)
          </div>
        </div>
      )}

      {/* TOP SLIM HUD */}
      <header className="w-full h-10 px-4 py-1 bg-slate-900/90 border-b border-slate-800/80 flex items-center justify-between shrink-0 z-20">
        {/* Left: Player identity */}
        <div className="flex items-center gap-2">
          <span className="text-lg">{avatar.emoji}</span>
          <span className="font-extrabold text-xs sm:text-sm truncate max-w-[120px] sm:max-w-xs" style={{ color: player.color || '#fff' }}>
            {player.name}
          </span>
        </div>

        {/* Center: Live minigame score / info */}
        <div className="flex items-center gap-2">
          {scoreDisplay ? (
            <div className="font-black text-amber-300 font-mono text-sm sm:text-base px-3 py-0.5 rounded-lg bg-slate-800 border border-amber-400/40">
              {scoreDisplay}
            </div>
          ) : (
            <span className="text-[11px] font-black uppercase tracking-wider text-slate-400">
              {mg?.name || 'MINIJÁTÉK'}
            </span>
          )}
        </div>

        {/* Right: Remaining timer */}
        <div className="flex items-center gap-1 font-mono font-black text-amber-400 text-xs bg-slate-800 px-2 py-0.5 rounded-lg border border-slate-700">
          <Timer className="w-3.5 h-3.5" />
          <span>{mg ? Math.ceil(mg.timeRemaining) : 0}s</span>
        </div>
      </header>

      {/* CONTROLLER MAIN PLAY AREA */}
      <main className="flex-1 w-full h-full px-2 sm:px-6 py-1 flex items-center justify-between relative overflow-hidden">
        {/* LEFT THUMB: D-PAD (~45% width) */}
        <section className="w-[45%] h-full flex items-center justify-center p-1 z-20" aria-label="D-Pad">
          <DPad onDirectionChange={handleDirectionChange} />
        </section>

        {/* CENTER DECORATIVE GAP (~10% width) */}
        <section className="w-[10%] flex flex-col items-center justify-center pointer-events-none opacity-30 select-none">
          <span className="text-[10px] font-black tracking-widest uppercase text-slate-500 font-mono text-center">
            PARTY<br />MAYHEM
          </span>
        </section>

        {/* RIGHT THUMB: ACTION BUTTONS (~45% width) */}
        <section className="w-[45%] h-full flex items-center justify-center gap-3 sm:gap-6 p-1 z-20" aria-label="Action Buttons">
          {/* B Button (Secondary, lower-left) */}
          <div className="flex flex-col items-center translate-y-3 sm:translate-y-4">
            <ActionButton
              label="B"
              subLabel={bLabel}
              colorScheme="secondary"
              size="medium"
              disabled={bDisabled}
              onChange={handleBChange}
            />
          </div>

          {/* A Button (Primary, upper-right, larger) */}
          <div className="flex flex-col items-center -translate-y-3 sm:-translate-y-4">
            <ActionButton
              label="A"
              subLabel={aLabel}
              colorScheme="primary"
              size="large"
              disabled={aDisabled}
              onChange={handleAChange}
            />
          </div>
        </section>
      </main>

      {/* BOTTOM ULTRA-SLIM FOOTER */}
      <footer className="w-full h-5 px-3 bg-slate-950 border-t border-slate-900/80 flex items-center justify-center text-[9px] text-slate-500 font-bold tracking-tight shrink-0">
        <span>🎮 Bal hüvelykujj: D-pad • Jobb hüvelykujj: Gombok</span>
      </footer>
    </div>
  );
};
