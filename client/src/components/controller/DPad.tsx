import React, { useRef, useState, useEffect, useCallback } from 'react';

interface DPadProps {
  onDirectionChange: (dirs: { up: boolean; down: boolean; left: boolean; right: boolean }) => void;
  disabled?: boolean;
}

export const DPad: React.FC<DPadProps> = ({ onDirectionChange, disabled = false }) => {
  const [pressed, setPressed] = useState<{ up: boolean; down: boolean; left: boolean; right: boolean }>({
    up: false,
    down: false,
    left: false,
    right: false,
  });

  // Track active pointer touches by pointerId
  const activePointersRef = useRef<Map<number, string>>(new Map());
  const prevDirectionsRef = useRef<{ up: boolean; down: boolean; left: boolean; right: boolean }>({
    up: false,
    down: false,
    left: false,
    right: false,
  });

  const updateDirections = useCallback(() => {
    const activeValues = Array.from(activePointersRef.current.values());
    const nextDirs = {
      up: activeValues.some(v => v.includes('up')),
      down: activeValues.some(v => v.includes('down')),
      left: activeValues.some(v => v.includes('left')),
      right: activeValues.some(v => v.includes('right')),
    };

    const prev = prevDirectionsRef.current;
    if (
      prev.up !== nextDirs.up ||
      prev.down !== nextDirs.down ||
      prev.left !== nextDirs.left ||
      prev.right !== nextDirs.right
    ) {
      prevDirectionsRef.current = nextDirs;
      setPressed(nextDirs);
      onDirectionChange(nextDirs);

      // Light haptic pulse when new direction engaged
      if ((nextDirs.up || nextDirs.down || nextDirs.left || nextDirs.right) && typeof navigator !== 'undefined' && navigator.vibrate) {
        try {
          navigator.vibrate(8);
        } catch (_) {}
      }
    }
  }, [onDirectionChange]);

  const handlePointerDown = (dir: string, e: React.PointerEvent) => {
    if (disabled) return;
    e.preventDefault();
    e.stopPropagation();
    try {
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    } catch (_) {}
    activePointersRef.current.set(e.pointerId, dir);
    updateDirections();
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (disabled) return;
    e.preventDefault();
    e.stopPropagation();
    activePointersRef.current.delete(e.pointerId);
    updateDirections();
  };

  const handlePointerCancel = (e: React.PointerEvent) => {
    activePointersRef.current.delete(e.pointerId);
    updateDirections();
  };

  // Clear when unmounting or disabled
  useEffect(() => {
    if (disabled) {
      activePointersRef.current.clear();
      updateDirections();
    }
  }, [disabled, updateDirections]);

  useEffect(() => {
    const handleGlobalUp = () => {
      if (activePointersRef.current.size > 0) {
        activePointersRef.current.clear();
        updateDirections();
      }
    };
    window.addEventListener('pointerup', handleGlobalUp);
    window.addEventListener('pointercancel', handleGlobalUp);
    return () => {
      window.removeEventListener('pointerup', handleGlobalUp);
      window.removeEventListener('pointercancel', handleGlobalUp);
    };
  }, [updateDirections]);

  return (
    <div
      className="relative w-44 h-44 sm:w-52 sm:h-52 select-none touch-none flex items-center justify-center"
      style={{ touchAction: 'none', userSelect: 'none', WebkitUserSelect: 'none' }}
    >
      {/* Outer base circular bezel */}
      <div className="absolute inset-0 rounded-full bg-slate-900/90 border-4 border-slate-700/80 shadow-2xl backdrop-blur-md" />

      {/* Cross Center Plate */}
      <div className="absolute w-14 h-14 rounded-xl bg-slate-800 border-2 border-slate-700 pointer-events-none z-10 flex items-center justify-center shadow-inner">
        <div className="w-4 h-4 rounded-full bg-slate-700" />
      </div>

      {/* UP BUTTON */}
      <button
        type="button"
        onPointerDown={(e) => handlePointerDown('up', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className={`absolute top-1 left-1/2 -translate-x-1/2 w-14 h-16 sm:w-16 sm:h-18 rounded-t-2xl flex flex-col items-center justify-start pt-2 font-black transition-all active:scale-95 z-20 ${
          pressed.up
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.6)] scale-95'
            : 'bg-slate-800 hover:bg-slate-750 text-slate-300 border-t-2 border-x-2 border-slate-600'
        }`}
        aria-label="Up"
      >
        <span className="text-2xl leading-none">▲</span>
        <span className="text-[9px] uppercase tracking-tighter opacity-70">FEL</span>
      </button>

      {/* DOWN BUTTON */}
      <button
        type="button"
        onPointerDown={(e) => handlePointerDown('down', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className={`absolute bottom-1 left-1/2 -translate-x-1/2 w-14 h-16 sm:w-16 sm:h-18 rounded-b-2xl flex flex-col items-center justify-end pb-2 font-black transition-all active:scale-95 z-20 ${
          pressed.down
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.6)] scale-95'
            : 'bg-slate-800 hover:bg-slate-750 text-slate-300 border-b-2 border-x-2 border-slate-600'
        }`}
        aria-label="Down"
      >
        <span className="text-[9px] uppercase tracking-tighter opacity-70">LE</span>
        <span className="text-2xl leading-none">▼</span>
      </button>

      {/* LEFT BUTTON */}
      <button
        type="button"
        onPointerDown={(e) => handlePointerDown('left', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className={`absolute left-1 top-1/2 -translate-y-1/2 w-16 h-14 sm:w-18 sm:h-16 rounded-l-2xl flex items-center justify-start pl-2 font-black transition-all active:scale-95 z-20 ${
          pressed.left
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.6)] scale-95'
            : 'bg-slate-800 hover:bg-slate-750 text-slate-300 border-l-2 border-y-2 border-slate-600'
        }`}
        aria-label="Left"
      >
        <span className="text-2xl leading-none">◀</span>
        <span className="text-[9px] uppercase tracking-tighter opacity-70 ml-1">BAL</span>
      </button>

      {/* RIGHT BUTTON */}
      <button
        type="button"
        onPointerDown={(e) => handlePointerDown('right', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className={`absolute right-1 top-1/2 -translate-y-1/2 w-16 h-14 sm:w-18 sm:h-16 rounded-r-2xl flex items-center justify-end pr-2 font-black transition-all active:scale-95 z-20 ${
          pressed.right
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.6)] scale-95'
            : 'bg-slate-800 hover:bg-slate-750 text-slate-300 border-r-2 border-y-2 border-slate-600'
        }`}
        aria-label="Right"
      >
        <span className="text-[9px] uppercase tracking-tighter opacity-70 mr-1">JOBB</span>
        <span className="text-2xl leading-none">▶</span>
      </button>

      {/* DIAGONAL CORNERS (Touch triggers both adjacent directions) */}
      {/* Top-Left */}
      <div
        onPointerDown={(e) => handlePointerDown('up,left', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className="absolute top-2 left-2 w-12 h-12 z-20 cursor-pointer"
        aria-label="Up-Left"
      />
      {/* Top-Right */}
      <div
        onPointerDown={(e) => handlePointerDown('up,right', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className="absolute top-2 right-2 w-12 h-12 z-20 cursor-pointer"
        aria-label="Up-Right"
      />
      {/* Bottom-Left */}
      <div
        onPointerDown={(e) => handlePointerDown('down,left', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className="absolute bottom-2 left-2 w-12 h-12 z-20 cursor-pointer"
        aria-label="Down-Left"
      />
      {/* Bottom-Right */}
      <div
        onPointerDown={(e) => handlePointerDown('down,right', e)}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        className="absolute bottom-2 right-2 w-12 h-12 z-20 cursor-pointer"
        aria-label="Down-Right"
      />
    </div>
  );
};
