import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface PushArena2DHostProps {
  room: RoomState;
}

interface FloatingPopup {
  id: string;
  x: number;
  y: number;
  text: string;
  color: string;
  alpha: number;
}

const RING_X = 960;
const RING_Y = 540;
const RING_R = 430;

export const PushArena2DHost: React.FC<PushArena2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastEventTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  useEffect(() => {
    const events = (mgData.ringOutEvents || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;
          sounds.playExplosion();

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y,
            text: '+1 KIÜTÉS! 🥊💥',
            color: '#fbbf24',
            alpha: 1.0,
          });
        }
      });
    }
  }, [mgData.ringOutEvents]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. COSMIC VOID BACKGROUND
    ctx.fillStyle = '#030712';
    ctx.fillRect(0, 0, width, height);

    // Deep nebula background glow
    const nebulaGrad = ctx.createRadialGradient(RING_X, RING_Y, 100, RING_X, RING_Y, 800);
    nebulaGrad.addColorStop(0, 'rgba(30, 27, 75, 0.4)');
    nebulaGrad.addColorStop(1, 'rgba(3, 7, 18, 0.9)');
    ctx.fillStyle = nebulaGrad;
    ctx.fillRect(0, 0, width, height);

    // 2. FLOATING ARENA PLATFORM
    // Platform drop shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
    ctx.beginPath();
    ctx.arc(RING_X + 8, RING_Y + 18, RING_R, 0, Math.PI * 2);
    ctx.fill();

    // Platform Base
    const ringGrad = ctx.createRadialGradient(RING_X, RING_Y, 50, RING_X, RING_Y, RING_R);
    ringGrad.addColorStop(0, '#1e293b');
    ringGrad.addColorStop(0.75, '#0f172a');
    ringGrad.addColorStop(1, '#020617');
    ctx.fillStyle = ringGrad;
    ctx.beginPath();
    ctx.arc(RING_X, RING_Y, RING_R, 0, Math.PI * 2);
    ctx.fill();

    // Concentric Arena Rings
    ctx.strokeStyle = 'rgba(56, 189, 248, 0.18)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(RING_X, RING_Y, 260, 0, Math.PI * 2);
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(RING_X, RING_Y, 120, 0, Math.PI * 2);
    ctx.stroke();

    // Center Emblem
    ctx.font = '48px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('🥊', RING_X, RING_Y);

    // Outer Danger Border (Pulsing neon)
    const pulse = Math.sin(elapsed * 6) * 3;
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 6 + pulse;
    ctx.setLineDash([20, 14]);
    ctx.beginPath();
    ctx.arc(RING_X, RING_Y, RING_R, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);

    // 3. PLAYERS & TRAINING DUMMIES
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    Object.values(simPlayers).forEach(sim => {
      // Check if dummy bot or real player
      const realPlayer = room.players[sim.id];
      const isDummy = Boolean(sim.isDummy);

      // Falling into abyss animation
      if (sim.isFalling) {
        const fallProgress = Math.max(0, (sim.fallTimer || 0) / 1.2); // 1.0 down to 0
        const fallScale = fallProgress * 0.9;
        ctx.save();
        ctx.translate(sim.x, sim.y);
        ctx.scale(fallScale, fallScale);
        ctx.rotate((1.2 - (sim.fallTimer || 0)) * 10);
        ctx.globalAlpha = Math.max(0, fallProgress);

        if (realPlayer) {
          drawPlayerCharacter2D(ctx, realPlayer, 0, 0, 72, 1, true, 0);
        } else {
          drawDummyBot(ctx, sim);
        }
        ctx.restore();
        return;
      }

      // Normal Rendering on Arena
      if (realPlayer) {
        drawPlayerCharacter2D(
          ctx,
          realPlayer,
          sim.x,
          sim.y,
          74,
          Math.cos(sim.facing || 0),
          sim.isHit || false,
          sim.score ?? 0
        );
      } else if (isDummy) {
        drawDummyBot(ctx, sim);
      }
    });

    // 4. FLOATING POPUPS
    popupsRef.current.forEach(pop => {
      pop.y -= 70 * dt;
      pop.alpha -= 0.8 * dt;

      if (pop.alpha > 0) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, pop.alpha);
        ctx.font = 'black 30px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.strokeStyle = '#020617';
        ctx.lineWidth = 5;
        ctx.strokeText(pop.text, pop.x, pop.y);
        ctx.fillStyle = pop.color;
        ctx.fillText(pop.text, pop.x, pop.y);
        ctx.restore();
      }
    });

    popupsRef.current = popupsRef.current.filter(p => p.alpha > 0);

    // 5. BANNER (Top Center)
    ctx.save();
    ctx.translate(width / 2, 54);
    ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
    drawRoundedRect(ctx, -260, -28, 520, 56, 16);
    ctx.fill();
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.font = 'bold 20px sans-serif';
    ctx.fillStyle = '#f8fafc';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('🥊 LÖKD LE AZ ELLENFELEKET! [A] = PUSH • [B] = DASH', 0, 0);
    ctx.restore();

    // 6. SCOREBOARD STRIP (Top Left/Right)
    const players = Object.values(room.players);
    players.forEach((p, idx) => {
      const score = mgData.scores?.[p.id] || 0;
      const avatar = AVATARS[p.avatar] || AVATARS['fox'];
      const cx = 120 + idx * 190;
      const cy = 46;

      ctx.save();
      ctx.translate(cx, cy);
      ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
      drawRoundedRect(ctx, -70, -22, 140, 44, 12);
      ctx.fill();
      ctx.strokeStyle = p.color || '#3b82f6';
      ctx.lineWidth = 2.5;
      ctx.stroke();

      ctx.font = '22px serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(avatar.emoji, -60, 0);

      ctx.font = 'bold 16px monospace';
      ctx.fillStyle = '#facc15';
      ctx.fillText(`🥊 ${score} KO`, -22, 0);
      ctx.restore();
    });
  };

  return (
    <div className="relative w-full h-full select-none overflow-hidden bg-slate-950">
      <MinigameCanvas2D
        room={room}
        onRender={handleRender}
        showDevOverlay={true}
        extraDevStats={{
          'Ring Outs': (mgData.ringOutEvents || []).length,
          'Dummies': Object.values((mgData.players || {}) as Record<string, any>).filter(p => p.isDummy).length,
        }}
        className="w-full h-full"
      />
    </div>
  );
};

function drawDummyBot(ctx: CanvasRenderingContext2D, sim: any) {
  ctx.save();
  ctx.translate(sim.x, sim.y);

  // Bot Shadow
  ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
  ctx.beginPath();
  ctx.ellipse(0, 22, 32, 12, 0, 0, Math.PI * 2);
  ctx.fill();

  // Bot Body Circle
  ctx.fillStyle = sim.isHit ? '#ef4444' : sim.color || '#f59e0b';
  ctx.beginPath();
  ctx.arc(0, 0, sim.radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#020617';
  ctx.lineWidth = 3;
  ctx.stroke();

  // Bot Face
  ctx.font = '36px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('🤖', 0, 0);

  // Bot Label
  ctx.font = 'bold 12px sans-serif';
  ctx.fillStyle = '#f8fafc';
  ctx.fillText('GYAKORLÓ', 0, 48);

  ctx.restore();
}
