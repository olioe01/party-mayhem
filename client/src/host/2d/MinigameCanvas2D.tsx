import React, { useRef, useEffect, useState, useCallback } from 'react';
import { RoomState, Player } from '@shared/types';
import { AVATARS } from '@shared/constants';
import { AlertTriangle, Activity } from 'lucide-react';

export const VIRTUAL_WIDTH = 1920;
export const VIRTUAL_HEIGHT = 1080;

interface MinigameCanvas2DProps {
  room: RoomState;
  onRender: (
    ctx: CanvasRenderingContext2D,
    dt: number,
    logicalWidth: number,
    logicalHeight: number,
    elapsed: number
  ) => void;
  showDevOverlay?: boolean;
  extraDevStats?: Record<string, string | number>;
  className?: string;
}

export const MinigameCanvas2D: React.FC<MinigameCanvas2DProps> = ({
  room,
  onRender,
  showDevOverlay = false,
  extraDevStats,
  className = '',
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animFrameIdRef = useRef<number | null>(null);

  const [hasError, setHasError] = useState<string | null>(null);
  const [fps, setFps] = useState<number>(60);
  const [frameTimeMs, setFrameTimeMs] = useState<number>(16);

  const onRenderRef = useRef(onRender);
  onRenderRef.current = onRender;

  // Track transform metrics
  const transformRef = useRef<{
    scale: number;
    offsetX: number;
    offsetY: number;
    dpr: number;
    width: number;
    height: number;
  }>({
    scale: 1,
    offsetX: 0,
    offsetY: 0,
    dpr: 1,
    width: VIRTUAL_WIDTH,
    height: VIRTUAL_HEIGHT,
  });

  const updateCanvasDimensions = useCallback(() => {
    const container = containerRef.current;
    const canvas = canvasRef.current;
    if (!container || !canvas) return;

    const rect = container.getBoundingClientRect();
    const cWidth = Math.max(rect.width, 320);
    const cHeight = Math.max(rect.height, 240);

    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    // Maintain 16:9 virtual aspect ratio
    const scale = Math.min(cWidth / VIRTUAL_WIDTH, cHeight / VIRTUAL_HEIGHT);
    const renderW = VIRTUAL_WIDTH * scale;
    const renderH = VIRTUAL_HEIGHT * scale;
    const offsetX = (cWidth - renderW) / 2;
    const offsetY = (cHeight - renderH) / 2;

    canvas.width = Math.floor(cWidth * dpr);
    canvas.height = Math.floor(cHeight * dpr);
    canvas.style.width = `${cWidth}px`;
    canvas.style.height = `${cHeight}px`;

    transformRef.current = {
      scale,
      offsetX,
      offsetY,
      dpr,
      width: cWidth,
      height: cHeight,
    };
  }, []);

  useEffect(() => {
    updateCanvasDimensions();

    const resizeObserver = new ResizeObserver(() => {
      updateCanvasDimensions();
    });

    if (containerRef.current) {
      resizeObserver.observe(containerRef.current);
    }
    window.addEventListener('resize', updateCanvasDimensions);

    return () => {
      resizeObserver.disconnect();
      window.removeEventListener('resize', updateCanvasDimensions);
    };
  }, [updateCanvasDimensions]);

  // 60 FPS Render loop with deltaTime
  useEffect(() => {
    let lastTime = performance.now();
    let frameCount = 0;
    let fpsTimer = performance.now();
    let startTime = performance.now();

    const loop = (currentTime: number) => {
      animFrameIdRef.current = requestAnimationFrame(loop);

      const dt = Math.min((currentTime - lastTime) / 1000, 0.1); // clamp large lag spikes to 100ms
      lastTime = currentTime;

      // Track FPS every 500ms
      frameCount++;
      if (currentTime - fpsTimer >= 500) {
        const curFps = Math.round((frameCount * 1000) / (currentTime - fpsTimer));
        setFps(curFps);
        setFrameTimeMs(Math.round(dt * 1000));
        frameCount = 0;
        fpsTimer = currentTime;
      }

      const canvas = canvasRef.current;
      if (!canvas) return;

      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      const { scale, offsetX, offsetY, dpr, width, height } = transformRef.current;

      try {
        // Reset full physical canvas
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Fill background letterbox borders with slate-950
        ctx.fillStyle = '#020617';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Clip and scale to virtual 1920 x 1080 canvas
        ctx.save();
        ctx.setTransform(
          scale * dpr,
          0,
          0,
          scale * dpr,
          offsetX * dpr,
          offsetY * dpr
        );

        // Clip to 1920x1080 playfield
        ctx.beginPath();
        ctx.rect(0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT);
        ctx.clip();

        // Render minigame frame
        const elapsed = (currentTime - startTime) / 1000;
        onRenderRef.current(ctx, dt, VIRTUAL_WIDTH, VIRTUAL_HEIGHT, elapsed);

        ctx.restore();
      } catch (err: any) {
        console.error('2D Minigame Render error:', err);
        setHasError(err?.message || 'Ismeretlen renderelési hiba');
      }
    };

    animFrameIdRef.current = requestAnimationFrame(loop);

    return () => {
      if (animFrameIdRef.current) {
        cancelAnimationFrame(animFrameIdRef.current);
        animFrameIdRef.current = null;
      }
    };
  }, []);

  if (hasError) {
    return (
      <div className="w-full h-full bg-slate-950 border-2 border-red-500 rounded-3xl p-8 flex flex-col items-center justify-center text-center gap-4 text-white">
        <AlertTriangle className="w-16 h-16 text-red-400 animate-bounce" />
        <h2 className="text-3xl font-black text-red-400 font-heading">
          MINIGAME ERROR
        </h2>
        <p className="text-sm font-bold text-slate-300 max-w-lg">
          A minijáték 2D megjelenítő motorja hibát észlelt:
        </p>
        <div className="bg-slate-900 border border-red-900 p-4 rounded-xl font-mono text-xs text-red-300 max-w-xl break-all">
          {hasError}
        </div>
        <button
          onClick={() => setHasError(null)}
          className="px-6 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white font-black text-sm"
        >
          Újrapróbálás
        </button>
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className={`relative w-full h-full flex items-center justify-center overflow-hidden bg-slate-950 select-none ${className}`}
    >
      <canvas
        ref={canvasRef}
        className="block touch-none select-none max-w-full max-h-full"
        style={{ imageRendering: 'auto' }}
      />

      {/* DEV DIAGNOSTICS OVERLAY (Always available in dev mode) */}
      {showDevOverlay && (
        <div className="absolute bottom-2 left-2 bg-slate-950/90 border border-slate-700/80 rounded-2xl p-2.5 flex flex-col gap-1 text-[10px] font-mono text-slate-300 z-30 pointer-events-none backdrop-blur-md shadow-2xl max-w-lg">
          <div className="flex items-center justify-between gap-3 border-b border-slate-800 pb-1">
            <span className="font-black text-amber-400 uppercase tracking-wider">
              {room.activeMinigame?.name || 'MINIGAME'}
            </span>
            <div className="flex items-center gap-1.5">
              <span className="px-1.5 py-0.2 rounded bg-emerald-500/20 text-emerald-400 font-bold">
                {fps} FPS
              </span>
              <span className="text-slate-500">•</span>
              <span className="text-slate-400">{frameTimeMs}ms</span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-x-3 gap-y-0.5 text-[9px] text-slate-400">
            <div>FÁZIS: <strong className="text-white">{room.phase}</strong></div>
            <div>SZIMULÁCIÓ: <strong className="text-emerald-400">20 Hz</strong></div>
            <div>JÁTÉKOSOK: <strong className="text-cyan-300">{Object.keys(room.players).length}</strong></div>
            <div>RENDER: <strong className="text-emerald-400">AKTÍV (60 FPS)</strong></div>
          </div>

          {/* First player input state */}
          {Object.values(room.players)[0]?.lastInputState && (
            <div className="flex items-center justify-between text-[9px] bg-slate-900 px-2 py-0.5 rounded border border-slate-800">
              <span className="text-slate-400 font-bold">INPUT:</span>
              <span className="flex items-center gap-1">
                <span className={Object.values(room.players)[0].lastInputState?.up ? 'text-amber-400 font-black' : 'text-slate-600'}>▲</span>
                <span className={Object.values(room.players)[0].lastInputState?.down ? 'text-amber-400 font-black' : 'text-slate-600'}>▼</span>
                <span className={Object.values(room.players)[0].lastInputState?.left ? 'text-amber-400 font-black' : 'text-slate-600'}>◀</span>
                <span className={Object.values(room.players)[0].lastInputState?.right ? 'text-amber-400 font-black' : 'text-slate-600'}>▶</span>
              </span>
              <span className="flex items-center gap-1">
                <span className={Object.values(room.players)[0].lastInputState?.a ? 'text-emerald-400 font-black' : 'text-slate-600'}>[A]</span>
                <span className={Object.values(room.players)[0].lastInputState?.b ? 'text-rose-400 font-black' : 'text-slate-600'}>[B]</span>
              </span>
            </div>
          )}

          {extraDevStats && (
            <div className="flex flex-wrap gap-x-2 gap-y-0.5 border-t border-slate-800 pt-1 text-[9px]">
              {Object.entries(extraDevStats).map(([key, val]) => (
                <span key={key}>
                  {key}: <strong className="text-amber-300">{val}</strong>
                </span>
              ))}
            </div>
          )}
        </div>
      )}

      {/* SOLO TEST MODE BADGE */}
      {Object.values(room.players).length === 1 && !Object.values(room.players)[0]?.isBot && (
        <div className="absolute top-2 right-4 bg-purple-950/85 border border-purple-500/80 rounded-xl px-3 py-1 text-[11px] font-black text-purple-200 z-30 pointer-events-none shadow-xl flex items-center gap-1.5">
          <span>🎮</span>
          <span>SOLO TEST MODE (1 Játékos • 0 Bot)</span>
        </div>
      )}
    </div>
  );
};

// ==========================================
// 2D CANVAS DRAWING UTILITIES
// ==========================================

export function drawRoundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number
) {
  ctx.beginPath();
  ctx.roundRect(x, y, width, height, radius);
}

export function drawPlayerCharacter2D(
  ctx: CanvasRenderingContext2D,
  player: Player,
  x: number,
  y: number,
  size: number = 70,
  facing: number = 0, // -1: left, 0: center, 1: right
  isHit: boolean = false,
  score?: number
) {
  ctx.save();
  ctx.translate(x, y);

  // 1. Soft ground shadow
  ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
  ctx.beginPath();
  ctx.ellipse(0, size * 0.48, size * 0.44, size * 0.16, 0, 0, Math.PI * 2);
  ctx.fill();

  // 2. Character Pill / Capsule Body
  const bodyColor = isHit ? '#f43f5e' : (player.color || '#3b82f6');
  const bodyW = size * 0.72;
  const bodyH = size * 0.88;

  ctx.fillStyle = bodyColor;
  ctx.strokeStyle = '#0f172a';
  ctx.lineWidth = 4;

  drawRoundedRect(ctx, -bodyW / 2, -bodyH / 2, bodyW, bodyH, bodyW / 2);
  ctx.fill();
  ctx.stroke();

  // Subtle highlight shine on character body
  ctx.fillStyle = 'rgba(255, 255, 255, 0.25)';
  ctx.beginPath();
  ctx.ellipse(-bodyW * 0.2, -bodyH * 0.24, bodyW * 0.16, bodyH * 0.14, -0.4, 0, Math.PI * 2);
  ctx.fill();

  // 3. Cute Cartoon Eyes
  const eyeOffset = facing * 6; // eyes glance in movement direction
  const eyeY = -bodyH * 0.1;
  const eyeSpacing = 10;
  const eyeRadius = 5.5;

  // Left Eye (white + pupil)
  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  ctx.arc(-eyeSpacing + eyeOffset, eyeY, eyeRadius, 0, Math.PI * 2);
  ctx.arc(eyeSpacing + eyeOffset, eyeY, eyeRadius, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#0f172a';
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // Pupils (black)
  ctx.fillStyle = '#0f172a';
  const pupilOffset = facing * 2.5;
  ctx.beginPath();
  ctx.arc(-eyeSpacing + eyeOffset + pupilOffset, eyeY, 2.5, 0, Math.PI * 2);
  ctx.arc(eyeSpacing + eyeOffset + pupilOffset, eyeY, 2.5, 0, Math.PI * 2);
  ctx.fill();

  // 4. Avatar Emoji Overhead Badge
  const avatar = AVATARS[player.avatar] || AVATARS['fox'];
  ctx.font = '24px serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(avatar.emoji, 0, -bodyH / 2 - 18);

  // 5. Name tag badge
  ctx.font = 'bold 15px sans-serif';
  const nameText = player.name + (player.isBot ? ' [BOT]' : '');
  const textMetrics = ctx.measureText(nameText);
  const tagW = textMetrics.width + 16;
  const tagH = 22;
  const tagY = bodyH / 2 + 10;

  ctx.fillStyle = 'rgba(15, 23, 42, 0.88)';
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
  ctx.lineWidth = 1.5;
  drawRoundedRect(ctx, -tagW / 2, tagY, tagW, tagH, 8);
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#ffffff';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(nameText, 0, tagY + tagH / 2);

  // 6. Score Pill (if provided)
  if (score !== undefined) {
    ctx.font = 'bold 14px monospace';
    const scoreText = `${score} pts`;
    const sW = ctx.measureText(scoreText).width + 12;
    const sY = tagY + tagH + 4;

    ctx.fillStyle = '#fbbf24';
    drawRoundedRect(ctx, -sW / 2, sY, sW, 18, 6);
    ctx.fill();

    ctx.fillStyle = '#0f172a';
    ctx.fillText(scoreText, 0, sY + 9);
  }

  ctx.restore();
}
