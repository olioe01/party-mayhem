import React, { useState, useRef, useEffect } from 'react';

interface ActionButtonProps {
  label: string; // 'A' or 'B'
  subLabel?: string; // e.g. 'PUSH', 'DASH', 'OPEN', 'GRAB'
  colorScheme?: 'primary' | 'secondary'; // primary: emerald/amber, secondary: red/cyan
  disabled?: boolean;
  hidden?: boolean;
  onChange: (pressed: boolean) => void;
}

export const ActionButton: React.FC<ActionButtonProps> = ({
  label,
  subLabel,
  colorScheme = 'primary',
  disabled = false,
  hidden = false,
  onChange,
}) => {
  const [isPressed, setIsPressed] = useState(false);
  const pointerIdRef = useRef<number | null>(null);

  const setPressedState = (pressed: boolean) => {
    setIsPressed(pressed);
    onChange(pressed);
    if (pressed && typeof navigator !== 'undefined' && navigator.vibrate) {
      try {
        navigator.vibrate(12);
      } catch (_) {}
    }
  };

  const handlePointerDown = (e: React.PointerEvent) => {
    if (disabled || hidden) return;
    e.preventDefault();
    e.stopPropagation();
    try {
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    } catch (_) {}
    pointerIdRef.current = e.pointerId;
    setPressedState(true);
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (pointerIdRef.current === e.pointerId) {
      pointerIdRef.current = null;
      setPressedState(false);
    }
  };

  const handlePointerCancel = (e: React.PointerEvent) => {
    if (pointerIdRef.current === e.pointerId) {
      pointerIdRef.current = null;
      setPressedState(false);
    }
  };

  useEffect(() => {
    const handleGlobalUp = () => {
      if (pointerIdRef.current !== null) {
        pointerIdRef.current = null;
        setPressedState(false);
      }
    };
    window.addEventListener('pointerup', handleGlobalUp);
    window.addEventListener('pointercancel', handleGlobalUp);
    return () => {
      window.removeEventListener('pointerup', handleGlobalUp);
      window.removeEventListener('pointercancel', handleGlobalUp);
    };
  }, []);

  if (hidden) {
    return <div className="w-20 h-20 sm:w-24 sm:h-24 opacity-0 pointer-events-none" />;
  }

  const isPrimary = colorScheme === 'primary';

  return (
    <button
      type="button"
      disabled={disabled}
      onPointerDown={handlePointerDown}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerCancel}
      className={`relative w-20 h-20 sm:w-24 sm:h-24 rounded-full flex flex-col items-center justify-center font-black select-none touch-none shadow-2xl transition-all duration-75 border-4 ${
        disabled
          ? 'bg-slate-800/50 border-slate-700/40 text-slate-600 opacity-40 cursor-not-allowed'
          : isPressed
          ? isPrimary
            ? 'bg-emerald-400 border-emerald-300 text-slate-950 scale-95 shadow-[0_0_30px_rgba(52,211,153,0.8)]'
            : 'bg-rose-500 border-rose-400 text-white scale-95 shadow-[0_0_30px_rgba(244,63,94,0.8)]'
          : isPrimary
          ? 'bg-gradient-to-br from-emerald-500 to-teal-700 border-emerald-400 text-white hover:brightness-110 active:scale-95 shadow-lg'
          : 'bg-gradient-to-br from-rose-500 to-red-700 border-rose-400 text-white hover:brightness-110 active:scale-95 shadow-lg'
      }`}
      style={{ touchAction: 'none', userSelect: 'none', WebkitUserSelect: 'none' }}
      aria-label={`${label} Button`}
    >
      <span className="text-2xl sm:text-3xl font-black leading-none drop-shadow-md">
        {label}
      </span>
      {subLabel && (
        <span className="text-[10px] sm:text-xs uppercase font-extrabold tracking-wider mt-0.5 opacity-90 drop-shadow">
          {subLabel}
        </span>
      )}
    </button>
  );
};
