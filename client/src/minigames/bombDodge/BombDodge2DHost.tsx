import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface BombDodge2DHostProps {
  room: RoomState;
}

export const BombDodge2DHost: React.FC<BombDodge2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastExplosionTimeRef = useRef<number>(0);

  // Trigger sound when new explosion occurs
  useEffect(() => {
    const explosions = (mgData.recentExplosions || []) as any[];
    if (explosions.length > 0) {
      const latest = explosions[explosions.length - 1];
      if (latest.timestamp > lastExplosionTimeRef.current) {
        lastExplosionTimeRef.current = latest.timestamp;
        sounds.playExplosion();
      }
    }
  }, [mgData.recentExplosions]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. ARENA FLOOR BACKGROUND (Dark slate stadium with glowing neon hazard perimeter)
    ctx.fillStyle = '#090d16';
    ctx.fillRect(0, 0, width, height);

    // Grid tile lines
    ctx.strokeStyle = 'rgba(51, 65, 85, 0.35)';
    ctx.lineWidth = 1.5;
    const gridSize = 80;
    for (let x = 120; x <= 1800; x += gridSize) {
      ctx.beginPath();
      ctx.moveTo(x, 140);
      ctx.lineTo(x, 940);
      ctx.stroke();
    }
    for (let y = 140; y <= 940; y += gridSize) {
      ctx.beginPath();
      ctx.moveTo(120, y);
      ctx.lineTo(1800, y);
      ctx.stroke();
    }

    // Outer Warning Curb
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 6;
    drawRoundedRect(ctx, 116, 136, 1688, 808, 28);
    ctx.stroke();

    // 2. ACTIVE HAZARDS (BOMBS & WARNING CIRCLES)
    const hazards = (mgData.hazards || []) as any[];
    hazards.forEach(hazard => {
      ctx.save();
      ctx.translate(hazard.x, hazard.y);

      if (!hazard.exploded) {
        // --- WARNING ZONE ---
        const pulse = 0.5 + Math.sin(elapsed * 12) * 0.3;
        const radius = hazard.radius;

        // Danger circle fill
        ctx.fillStyle = `rgba(239, 68, 68, ${0.15 + pulse * 0.15})`;
        ctx.beginPath();
        ctx.arc(0, 0, radius, 0, Math.PI * 2);
        ctx.fill();

        // Pulsing border ring
        ctx.strokeStyle = '#ef4444';
        ctx.lineWidth = 4 + pulse * 2;
        ctx.setLineDash([16, 10]);
        ctx.beginPath();
        ctx.arc(0, 0, radius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);

        // Falling bomb shadow / ticking bomb icon
        const bombProgress = Math.max(0, hazard.warningTime / 1.15); // 1.0 down to 0
        const bombY = -120 * bombProgress; // bomb drops downwards from sky
        const bombScale = 1.0 + (1 - bombProgress) * 0.4;

        ctx.font = `${Math.round(36 * bombScale)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('💣', 0, bombY);

        // Warning countdown bar inside circle
        const barW = 70;
        ctx.fillStyle = 'rgba(15, 23, 42, 0.8)';
        ctx.fillRect(-barW / 2, 24, barW, 8);
        ctx.fillStyle = '#ef4444';
        ctx.fillRect(-barW / 2, 24, barW * (1 - bombProgress), 8);
      } else {
        // --- EXPLOSION FLASH ---
        const expRadius = hazard.radius * 1.15;
        const flashGrad = ctx.createRadialGradient(0, 0, 10, 0, 0, expRadius);
        flashGrad.addColorStop(0, '#fef08a');
        flashGrad.addColorStop(0.3, '#f97316');
        flashGrad.addColorStop(0.7, '#ef4444');
        flashGrad.addColorStop(1, 'rgba(239, 68, 68, 0)');

        ctx.fillStyle = flashGrad;
        ctx.beginPath();
        ctx.arc(0, 0, expRadius, 0, Math.PI * 2);
        ctx.fill();

        ctx.font = '54px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('💥', 0, 0);
      }

      ctx.restore();
    });

    // 3. PLAYERS
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    Object.values(simPlayers).forEach(sim => {
      const p = room.players[sim.id];
      if (!p) return;

      drawPlayerCharacter2D(
        ctx,
        p,
        sim.x,
        sim.y,
        72,
        Math.cos(sim.facing || 0),
        sim.isHit || false,
        sim.score ?? 0
      );
    });

    // 4. TOP SCOREBOARD
    drawTopScoreboard(ctx, room, mgData, width);
  };

  return (
    <div className="relative w-full h-full flex items-center justify-center overflow-hidden">
      <MinigameCanvas2D
        room={room}
        onRender={handleRender}
        showDevOverlay={true}
        extraDevStats={{
          'Hazards': (mgData.hazards || []).length,
          'Hullám': mgData.waveCount || 0,
        }}
      />
    </div>
  );
};

function drawTopScoreboard(
  ctx: CanvasRenderingContext2D,
  room: RoomState,
  mgData: any,
  width: number
) {
  const players = Object.values(room.players);
  if (players.length === 0) return;

  const cardW = Math.min(220, (width - 120) / players.length);
  const totalWidth = players.length * cardW + (players.length - 1) * 14;
  const startX = (width - totalWidth) / 2;
  const startY = 16;

  players.forEach((p, idx) => {
    const sim = mgData.players?.[p.id];
    const score = mgData.scores?.[p.id] ?? sim?.score ?? 0;
    const avatar = AVATARS[p.avatar] || AVATARS['fox'];
    const cx = startX + idx * (cardW + 14);

    ctx.save();
    ctx.fillStyle = 'rgba(15, 23, 42, 0.88)';
    ctx.strokeStyle = sim?.isHit ? '#ef4444' : 'rgba(239, 68, 68, 0.6)';
    ctx.lineWidth = 2;
    drawRoundedRect(ctx, cx, startY, cardW, 50, 14);
    ctx.fill();
    ctx.stroke();

    ctx.font = '24px serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(avatar.emoji, cx + 10, startY + 25);

    ctx.font = 'bold 14px sans-serif';
    ctx.fillStyle = p.color || '#ffffff';
    const nameStr = p.name.length > 10 ? p.name.substring(0, 9) + '…' : p.name;
    ctx.fillText(nameStr, cx + 46, startY + 18);

    ctx.font = 'black 18px monospace';
    ctx.fillStyle = '#ef4444';
    ctx.fillText(`🛡️ ${score} pts`, cx + 46, startY + 36);

    ctx.restore();
  });
}
