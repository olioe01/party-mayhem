import { useState, useEffect } from 'react';

export type GraphicsMode = '2D' | '3D' | 'AUTO';

const STORAGE_KEY = 'pm_graphics_mode';

let currentMode: GraphicsMode = (() => {
  if (typeof window !== 'undefined') {
    try {
      const saved = localStorage.getItem(STORAGE_KEY) as GraphicsMode;
      if (saved === '2D' || saved === '3D' || saved === 'AUTO') return saved;
    } catch (_) {}
  }
  return '2D'; // DEFAULT IS '2D'
})();

const listeners = new Set<(mode: GraphicsMode) => void>();

export function getGraphicsMode(): GraphicsMode {
  return currentMode;
}

export function setGraphicsMode(mode: GraphicsMode) {
  currentMode = mode;
  if (typeof window !== 'undefined') {
    try {
      localStorage.setItem(STORAGE_KEY, mode);
    } catch (_) {}
  }
  listeners.forEach(fn => fn(mode));
}

export function useGraphicsMode(): [GraphicsMode, (mode: GraphicsMode) => void] {
  const [mode, setModeState] = useState<GraphicsMode>(getGraphicsMode);

  useEffect(() => {
    const handler = (newMode: GraphicsMode) => setModeState(newMode);
    listeners.add(handler);
    return () => {
      listeners.delete(handler);
    };
  }, []);

  return [mode, setGraphicsMode];
}
