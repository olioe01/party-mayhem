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

  const padRef = useRef<HTMLDivElement>(null);

  // Track active pointers by their pointerId: Map<pointerId, { up, down, left, right }>
  const activePointersRef = useRef<Map<number, { up: boolean; down: boolean; left: boolean; right: boolean }>>(new Map());
  const prevDirsRef = useRef<{ up: boolean; down: boolean; left: boolean; right: boolean }>({
    up: false,
    down: false,
    left: false,
    right: false,
  });

  const emitDirections = useCallback(() => {
    let up = false;
    let down = false;
    let left = false;
    let right = false;

    activePointersRef.current.forEach(dirs => {
      if (dirs.up) up = true;
      if (dirs.down) down = true;
      if (dirs.left) left = true;
      if (dirs.right) right = true;
    });

    const nextDirs = { up, down, left, right };
    const prev = prevDirsRef.current;

    if (
      prev.up !== nextDirs.up ||
      prev.down !== nextDirs.down ||
      prev.left !== nextDirs.left ||
      prev.right !== nextDirs.right
    ) {
      prevDirsRef.current = nextDirs;
      setPressed(nextDirs);
      onDirectionChange(nextDirs);

      if ((up || down || left || right) && typeof navigator !== 'undefined' && navigator.vibrate) {
        try {
          navigator.vibrate(8);
        } catch (_) {}
      }
    }
  }, [onDirectionChange]);

  // Calculate direction from touch offset relative to center of pad
  const getDirectionsFromCoord = (clientX: number, clientY: number) => {
    if (!padRef.current) return { up: false, down: false, left: false, right: false };
    const rect = padRef.current.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    const dx = clientX - centerX;
    const dy = clientY - centerY;
    const dist = Math.hypot(dx, dy);

    // Deadzone (too close to center = neutral)
    const deadzone = rect.width * 0.12;
    if (dist < deadzone) {
      return { up: false, down: false, left: false, right: false };
    }

    // Angle in degrees: 0 = East (Right), 90 = South (Down), 180 = West (Left), -90 = North (Up)
    const angle = Math.atan2(dy, dx) * (180 / Math.PI);

    let up = false;
    let down = false;
    let left = false;
    let right = false;

    // Up: [-157.5, -22.5]
    if (angle >= -157.5 && angle <= -22.5) {
      up = true;
    }
    // Down: [22.5, 157.5]
    if (angle >= 22.5 && angle <= 157.5) {
      down = true;
    }
    // Right: [-67.5, 67.5]
    if (angle >= -67.5 && angle <= 67.5) {
      right = true;
    }
    // Left: [112.5, 180] or [-180, -112.5]
    if (angle >= 112.5 || angle <= -112.5) {
      left = true;
    }

    return { up, down, left, right };
  };

  const handlePointerDown = (e: React.PointerEvent) => {
    if (disabled) return;
    e.preventDefault();
    e.stopPropagation();

    try {
      (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    } catch (_) {}

    const dirs = getDirectionsFromCoord(e.clientX, e.clientY);
    activePointersRef.current.set(e.pointerId, dirs);
    emitDirections();
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (disabled) return;
    if (!activePointersRef.current.has(e.pointerId)) return;
    e.preventDefault();
    e.stopPropagation();

    const dirs = getDirectionsFromCoord(e.clientX, e.clientY);
    activePointersRef.current.set(e.pointerId, dirs);
    emitDirections();
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (disabled) return;
    e.preventDefault();
    e.stopPropagation();

    if (activePointersRef.current.has(e.pointerId)) {
      activePointersRef.current.delete(e.pointerId);
      emitDirections();
    }
  };

  const handlePointerCancel = (e: React.PointerEvent) => {
    if (activePointersRef.current.has(e.pointerId)) {
      activePointersRef.current.delete(e.pointerId);
      emitDirections();
    }
  };

  // Global window listeners for safety — ONLY delete the specific pointerId that was released!
  useEffect(() => {
    const handleGlobalUp = (e: PointerEvent) => {
      if (activePointersRef.current.has(e.pointerId)) {
        activePointersRef.current.delete(e.pointerId);
        emitDirections();
      }
    };

    window.addEventListener('pointerup', handleGlobalUp);
    window.addEventListener('pointercancel', handleGlobalUp);
    return () => {
      window.removeEventListener('pointerup', handleGlobalUp);
      window.removeEventListener('pointercancel', handleGlobalUp);
    };
  }, [emitDirections]);

  // Clear when disabled or unmounting
  useEffect(() => {
    if (disabled) {
      activePointersRef.current.clear();
      emitDirections();
    }
  }, [disabled, emitDirections]);

  return (
    <div
      ref={padRef}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerCancel}
      className="relative w-36 h-36 sm:w-44 sm:h-44 max-w-[42vw] max-h-[42vw] aspect-square select-none touch-none flex items-center justify-center cursor-pointer"
      style={{ touchAction: 'none', userSelect: 'none', WebkitUserSelect: 'none' }}
      aria-label="D-Pad Controller"
    >
      {/* Outer base circular bezel */}
      <div className="absolute inset-0 rounded-full bg-slate-900/95 border-4 border-slate-700/80 shadow-2xl backdrop-blur-md pointer-events-none" />

      {/* Cross Center Plate */}
      <div className="absolute w-12 h-12 sm:w-14 sm:h-14 rounded-xl bg-slate-800 border-2 border-slate-700 pointer-events-none z-10 flex items-center justify-center shadow-inner">
        <div className="w-3.5 h-3.5 rounded-full bg-slate-600" />
      </div>

      {/* UP BUTTON INDICATOR */}
      <div
        className={`absolute top-1 left-1/2 -translate-x-1/2 w-12 h-14 sm:w-14 sm:h-16 rounded-t-2xl flex flex-col items-center justify-start pt-1.5 font-black transition-all z-20 pointer-events-none ${
          pressed.up
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.7)] scale-95'
            : 'bg-slate-800 text-slate-300 border-t-2 border-x-2 border-slate-600'
        }`}
      >
        <span className="text-xl sm:text-2xl leading-none">▲</span>
        <span className="text-[8px] sm:text-[9px] uppercase tracking-tighter opacity-70">FEL</span>
      </div>

      {/* DOWN BUTTON INDICATOR */}
      <div
        className={`absolute bottom-1 left-1/2 -translate-x-1/2 w-12 h-14 sm:w-14 sm:h-16 rounded-b-2xl flex flex-col items-center justify-end pb-1.5 font-black transition-all z-20 pointer-events-none ${
          pressed.down
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.7)] scale-95'
            : 'bg-slate-800 text-slate-300 border-b-2 border-x-2 border-slate-600'
        }`}
      >
        <span className="text-[8px] sm:text-[9px] uppercase tracking-tighter opacity-70">LE</span>
        <span className="text-xl sm:text-2xl leading-none">▼</span>
      </div>

      {/* LEFT BUTTON INDICATOR */}
      <div
        className={`absolute left-1 top-1/2 -translate-y-1/2 w-14 h-12 sm:w-16 sm:h-14 rounded-l-2xl flex items-center justify-start pl-1.5 font-black transition-all z-20 pointer-events-none ${
          pressed.left
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.7)] scale-95'
            : 'bg-slate-800 text-slate-300 border-l-2 border-y-2 border-slate-600'
        }`}
      >
        <span className="text-xl sm:text-2xl leading-none">◀</span>
        <span className="text-[8px] sm:text-[9px] uppercase tracking-tighter opacity-70 ml-1">BAL</span>
      </div>

      {/* RIGHT BUTTON INDICATOR */}
      <div
        className={`absolute right-1 top-1/2 -translate-y-1/2 w-14 h-12 sm:w-16 sm:h-14 rounded-r-2xl flex items-center justify-end pr-1.5 font-black transition-all z-20 pointer-events-none ${
          pressed.right
            ? 'bg-amber-400 text-slate-950 shadow-[0_0_20px_rgba(251,191,36,0.7)] scale-95'
            : 'bg-slate-800 text-slate-300 border-r-2 border-y-2 border-slate-600'
        }`}
      >
        <span className="text-[8px] sm:text-[9px] uppercase tracking-tighter opacity-70 mr-1">JOBB</span>
        <span className="text-xl sm:text-2xl leading-none">▶</span>
      </div>
    </div>
  );
};
