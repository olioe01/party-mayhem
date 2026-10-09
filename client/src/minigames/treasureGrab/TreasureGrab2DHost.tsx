import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface TreasureGrab2DHostProps {
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

export const TreasureGrab2DHost: React.FC<TreasureGrab2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastEventTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  useEffect(() => {
    const events = (mgData.openEvents || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;

          if (evt.type === 'trap') {
            sounds.playExplosion();
          } else if (evt.type === 'jackpot5') {
            sounds.playWin();
          } else {
            sounds.playCoin();
          }

          let text = '+1 🪙';
          let color = '#4ade80';
          if (evt.type === 'coins3') {
            text = '+3 🪙';
            color = '#fbbf24';
          } else if (evt.type === 'jackpot5') {
            text = '+5 💎 JACKPOT!';
            color = '#38bdf8';
          } else if (evt.type === 'trap') {
            text = '-3 💣 CSAPDA!';
            color = '#ef4444';
          } else if (evt.type === 'empty') {
            text = 'ÜRES 💨';
            color = '#94a3b8';
          }

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y - 20,
            text,
            color,
            alpha: 1.0,
          });
        }
      });
    }
  }, [mgData.openEvents]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. ANCIENT DUNGEON CHAMBER FLOOR
    ctx.fillStyle = '#090d16';
    ctx.fillRect(0, 0, width, height);

    // Stone slab tile lines
    ctx.strokeStyle = 'rgba(71, 85, 105, 0.25)';
    ctx.lineWidth = 2;
    const tileSize = 100;
    for (let x = 120; x <= 1800; x += tileSize) {
      ctx.beginPath();
      ctx.moveTo(x, 140);
      ctx.lineTo(x, 940);
      ctx.stroke();
    }
    for (let y = 140; y <= 940; y += tileSize) {
      ctx.beginPath();
      ctx.moveTo(120, y);
      ctx.lineTo(1800, y);
      ctx.stroke();
    }

    // Outer Chamber Wall
    ctx.strokeStyle = '#ca8a04';
    ctx.lineWidth = 5;
    drawRoundedRect(ctx, 116, 136, 1688, 808, 28);
    ctx.stroke();

    // 2. TREASURE CHESTS
    const chests = (mgData.chests || []) as any[];
    const simPlayers = (mgData.players || {}) as Record<string, any>;

    chests.forEach(ch => {
      ctx.save();
      ctx.translate(ch.x, ch.y);

      // Check if any player is in interaction range (<= 88px)
      let nearbyPlayer = false;
      for (const p of Object.values(simPlayers)) {
        if (!ch.opened && Math.hypot(p.x - ch.x, p.y - ch.y) <= 88) {
          nearbyPlayer = true;
          break;
        }
      }

      // Proximity glow & prompt
      if (nearbyPlayer && !ch.opened) {
        ctx.fillStyle = 'rgba(251, 191, 36, 0.25)';
        ctx.beginPath();
        ctx.arc(0, 0, 72, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = '#facc15';
        ctx.lineWidth = 3;
        ctx.setLineDash([8, 6]);
        ctx.beginPath();
        ctx.arc(0, 0, 72, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);

        // Interactive "A" prompt bubble overhead
        ctx.fillStyle = '#10b981';
        drawRoundedRect(ctx, -46, -60, 92, 24, 8);
        ctx.fill();
        ctx.font = 'bold 12px monospace';
        ctx.fillStyle = '#020617';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('[A] NYITÁS', 0, -48);
      }

      // Chest Shadow
      ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
      ctx.beginPath();
      ctx.ellipse(0, 20, 36, 12, 0, 0, Math.PI * 2);
      ctx.fill();

      // Chest Body
      const cW = 58;
      const cH = 40;

      if (!ch.opened) {
        // --- CLOSED CHEST ---
        const woodGrad = ctx.createLinearGradient(0, -cH / 2, 0, cH / 2);
        woodGrad.addColorStop(0, '#92400e');
        woodGrad.addColorStop(1, '#451a03');
        ctx.fillStyle = woodGrad;
        drawRoundedRect(ctx, -cW / 2, -cH / 2, cW, cH, 8);
        ctx.fill();
        ctx.strokeStyle = '#291102';
        ctx.lineWidth = 3;
        ctx.stroke();

        // Brass Metal Straps
        ctx.fillStyle = '#ca8a04';
        ctx.fillRect(-cW / 2 + 10, -cH / 2, 8, cH);
        ctx.fillRect(cW / 2 - 18, -cH / 2, 8, cH);

        // Gold Keyhole plate
        ctx.fillStyle = '#fbbf24';
        drawRoundedRect(ctx, -7, -4, 14, 12, 3);
        ctx.fill();
        ctx.fillStyle = '#0f172a';
        ctx.beginPath();
        ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
        ctx.fill();
      } else {
        // --- OPENED CHEST ---
        // Base box
        ctx.fillStyle = '#582305';
        drawRoundedRect(ctx, -cW / 2, 0, cW, cH / 2, 6);
        ctx.fill();
        ctx.strokeStyle = '#291102';
        ctx.lineWidth = 3;
        ctx.stroke();

        // Open tilted lid
        ctx.save();
        ctx.translate(-cW / 2, 0);
        ctx.rotate(-0.5);
        ctx.fillStyle = '#92400e';
        drawRoundedRect(ctx, 0, -cH / 2, cW, cH / 2, 6);
        ctx.fill();
        ctx.strokeStyle = '#291102';
        ctx.stroke();
        ctx.restore();

        // Content shimmer
        ctx.font = '24px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        if (ch.type === 'jackpot5') {
          ctx.fillText('💎', 0, -6);
        } else if (ch.type === 'trap') {
          ctx.fillText('💣', 0, -6);
        } else if (ch.type === 'empty') {
          ctx.fillText('💨', 0, -6);
        } else {
          ctx.fillText('✨', 0, -6);
        }
      }

      ctx.restore();
    });

    // 3. PLAYERS
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

    // 4. FLOATING POPUPS
    popupsRef.current.forEach(pop => {
      pop.y -= 70 * dt;
      pop.alpha -= 0.8 * dt;

      if (pop.alpha > 0) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, pop.alpha);
        ctx.font = 'black 28px sans-serif';
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

    // 5. TOP SCOREBOARD
    drawTopScoreboard(ctx, room, mgData, width);
  };

  return (
    <div className="relative w-full h-full flex items-center justify-center overflow-hidden">
      <MinigameCanvas2D
        room={room}
        onRender={handleRender}
        showDevOverlay={true}
        extraDevStats={{
          'Ládák': `${(mgData.chests || []).filter((c: any) => c.opened).length} / 10 nyitva`,
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
    ctx.strokeStyle = sim?.isHit ? '#ef4444' : 'rgba(234, 179, 8, 0.6)';
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
    ctx.fillStyle = '#fbbf24';
    ctx.fillText(`👑 ${score} pts`, cx + 46, startY + 36);

    ctx.restore();
  });
}
