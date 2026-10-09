import React, { useState, useRef, useEffect, useCallback } from 'react';
import { GamepadInputState } from '@shared/types';
import { DPad } from './DPad';
import { ActionButton } from './ActionButton';
import { CheckCircle2, AlertTriangle, ArrowLeft, RotateCcw, Zap } from 'lucide-react';

export const ControllerTestScreen: React.FC = () => {
  const [inputState, setInputState] = useState<GamepadInputState>({
    up: false,
    down: false,
    left: false,
    right: false,
    a: false,
    b: false,
  });

  const [activePointerCount, setActivePointerCount] = useState<number>(0);
  const [rightAndAHeldCount, setRightAndAHeldCount] = useState<number>(0);
  const [lastEvent, setLastEvent] = useState<string>('Várakozás érintésre...');

  // Track orientation
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

  // Monitor active touches on window
  useEffect(() => {
    const activePointers = new Set<number>();
    const onDown = (e: PointerEvent) => {
      activePointers.add(e.pointerId);
      setActivePointerCount(activePointers.size);
    };
    const onUp = (e: PointerEvent) => {
      activePointers.delete(e.pointerId);
      setActivePointerCount(activePointers.size);
    };
    window.addEventListener('pointerdown', onDown);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onUp);
    return () => {
      window.removeEventListener('pointerdown', onDown);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointercancel', onUp);
    };
  }, []);

  const handleDirectionChange = useCallback((dirs: { up: boolean; down: boolean; left: boolean; right: boolean }) => {
    setInputState(prev => {
      const next = { ...prev, ...dirs };
      if (next.right && next.a) {
        setRightAndAHeldCount(c => c + 1);
      }
      setLastEvent(`DPad: ${dirs.up ? 'FEL ' : ''}${dirs.down ? 'LE ' : ''}${dirs.left ? 'BAL ' : ''}${dirs.right ? 'JOBB ' : ''}`.trim() || 'DPad felengedve');
      return next;
    });
  }, []);

  const handleAChange = useCallback((pressed: boolean) => {
    setInputState(prev => {
      const next = { ...prev, a: pressed };
      if (next.right && next.a) {
        setRightAndAHeldCount(c => c + 1);
      }
      setLastEvent(`Gomb A: ${pressed ? 'LENYOMVA' : 'FELENGEDVE'}`);
      return next;
    });
  }, []);

  const handleBChange = useCallback((pressed: boolean) => {
    setInputState(prev => {
      const next = { ...prev, b: pressed };
      setLastEvent(`Gomb B: ${pressed ? 'LENYOMVA' : 'FELENGEDVE'}`);
      return next;
    });
  }, []);

  const isRightAndA = inputState.right && inputState.a;
  const isLeftAndB = inputState.left && inputState.b;
  const isDownLeftAndA = inputState.down && inputState.left && inputState.a;

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
      {/* PORTRAIT WARNING */}
      {!isLandscape && (
        <div className="fixed inset-0 z-50 bg-slate-950/98 backdrop-blur-2xl flex flex-col items-center justify-center p-6 text-center gap-4">
          <RotateCcw className="w-14 h-14 text-amber-400 animate-spin" style={{ animationDuration: '4s' }} />
          <h2 className="text-2xl font-black text-white font-heading">
            FORDÍTSD EL A TELEFONT!
          </h2>
          <p className="text-sm font-bold text-slate-400 max-w-xs">
            A diagnosztikai teszthez fordítsd el a telefont fekvő helyzetbe a kétkezes multitouch ellenőrzéshez!
          </p>
        </div>
      )}

      {/* TOP DIAGNOSTIC HUD */}
      <header className="w-full bg-slate-900/95 border-b border-slate-800 px-4 py-2 flex items-center justify-between shrink-0 z-20">
        <div className="flex items-center gap-3">
          <button
            onClick={() => {
              window.location.href = '/';
            }}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300"
            title="Vissza"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
          <div>
            <h1 className="text-sm font-black text-white font-heading tracking-wide flex items-center gap-2">
              <span>MULTITOUCH DIAGNOSZTIKA</span>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300 font-mono">
                {activePointerCount} ujjas érintés
              </span>
            </h1>
            <p className="text-[10px] text-slate-400 font-mono truncate max-w-[200px] sm:max-w-md">
              {lastEvent}
            </p>
          </div>
        </div>

        {/* Live Input Matrix Badge */}
        <div className="flex items-center gap-1.5 font-mono text-[11px] font-black">
          <span className={`px-1.5 py-0.5 rounded ${inputState.up ? 'bg-amber-400 text-slate-950 shadow' : 'bg-slate-800 text-slate-500'}`}>
            FEL:{inputState.up ? 'ON' : 'OFF'}
          </span>
          <span className={`px-1.5 py-0.5 rounded ${inputState.down ? 'bg-amber-400 text-slate-950 shadow' : 'bg-slate-800 text-slate-500'}`}>
            LE:{inputState.down ? 'ON' : 'OFF'}
          </span>
          <span className={`px-1.5 py-0.5 rounded ${inputState.left ? 'bg-amber-400 text-slate-950 shadow' : 'bg-slate-800 text-slate-500'}`}>
            BAL:{inputState.left ? 'ON' : 'OFF'}
          </span>
          <span className={`px-1.5 py-0.5 rounded ${inputState.right ? 'bg-amber-400 text-slate-950 shadow' : 'bg-slate-800 text-slate-500'}`}>
            JOBB:{inputState.right ? 'ON' : 'OFF'}
          </span>
          <span className={`px-2 py-0.5 rounded ${inputState.a ? 'bg-emerald-400 text-slate-950 shadow' : 'bg-slate-800 text-slate-500'}`}>
            A:{inputState.a ? 'ON' : 'OFF'}
          </span>
          <span className={`px-2 py-0.5 rounded ${inputState.b ? 'bg-rose-500 text-white shadow' : 'bg-slate-800 text-slate-500'}`}>
            B:{inputState.b ? 'ON' : 'OFF'}
          </span>
        </div>
      </header>

      {/* CRITICAL MULTITOUCH COMBO VERIFICATION BANNER */}
      <div className="w-full bg-slate-900/60 border-b border-slate-800/80 px-4 py-1 flex items-center justify-center gap-4 text-xs font-black z-10 shrink-0">
        <div
          className={`flex items-center gap-1.5 px-3 py-1 rounded-xl transition-all ${
            isRightAndA
              ? 'bg-emerald-500 text-slate-950 scale-105 shadow-[0_0_20px_rgba(16,185,129,0.8)] animate-pulse'
              : 'bg-slate-800/80 text-slate-400 border border-slate-700'
          }`}
        >
          {isRightAndA ? <CheckCircle2 className="w-4 h-4 text-slate-950" /> : <Zap className="w-3.5 h-3.5" />}
          <span>[JOBB + A] EGYIDEJŰ: {isRightAndA ? 'SIKERES! ✓' : 'NYOMD MEG EGYSZERRE'}</span>
        </div>

        <div
          className={`hidden sm:flex items-center gap-1.5 px-3 py-1 rounded-xl transition-all ${
            isLeftAndB
              ? 'bg-cyan-500 text-slate-950 scale-105 shadow-[0_0_20px_rgba(6,182,212,0.8)]'
              : 'bg-slate-800/80 text-slate-400 border border-slate-700'
          }`}
        >
          <span>[BAL + B]: {isLeftAndB ? 'AKTÍV! ✓' : 'OFF'}</span>
        </div>

        <div
          className={`hidden md:flex items-center gap-1.5 px-3 py-1 rounded-xl transition-all ${
            isDownLeftAndA
              ? 'bg-purple-500 text-white scale-105 shadow-[0_0_20px_rgba(168,85,247,0.8)]'
              : 'bg-slate-800/80 text-slate-400 border border-slate-700'
          }`}
        >
          <span>[LE + BAL + A]: {isDownLeftAndA ? 'AKTÍV! ✓' : 'OFF'}</span>
        </div>
      </div>

      {/* MAIN PLAY / TEST CONTROLLER AREA */}
      <main className="flex-1 w-full h-full px-2 sm:px-6 py-1 flex items-center justify-between relative overflow-hidden">
        {/* Left: D-pad (~45%) */}
        <section className="w-[45%] h-full flex items-center justify-center p-1 z-20" aria-label="D-Pad">
          <DPad onDirectionChange={handleDirectionChange} />
        </section>

        {/* Center: Live indicator instructions (~10%) */}
        <section className="w-[10%] flex flex-col items-center justify-center pointer-events-none select-none text-center">
          <span className="text-[10px] font-black uppercase text-amber-400/80 font-mono">
            TESZT
          </span>
          <span className="text-[9px] text-slate-500 font-bold">
            Fogd két kézzel!
          </span>
        </section>

        {/* Right: Action Buttons (~45%) */}
        <section className="w-[45%] h-full flex items-center justify-center gap-4 sm:gap-8 p-1 z-20" aria-label="Action Buttons">
          {/* B Button */}
          <div className="flex flex-col items-center translate-y-3 sm:translate-y-4">
            <ActionButton
              label="B"
              subLabel="TESZT"
              colorScheme="secondary"
              size="medium"
              onChange={handleBChange}
            />
          </div>

          {/* A Button */}
          <div className="flex flex-col items-center -translate-y-3 sm:-translate-y-4">
            <ActionButton
              label="A"
              subLabel="TESZT"
              colorScheme="primary"
              size="large"
              onChange={handleAChange}
            />
          </div>
        </section>
      </main>

      {/* FOOTER */}
      <footer className="w-full h-5 px-3 bg-slate-950 border-t border-slate-900 flex items-center justify-between text-[9px] text-slate-500 font-bold font-mono shrink-0">
        <span>Próbáld ki: Tartsd nyomva a JOBB gombot a bal kezeddel, és közben kopogtass az A gombbal!</span>
        <span>JOBB+A detektálva: {rightAndAHeldCount} alkalommal</span>
      </footer>
    </div>
  );
};
