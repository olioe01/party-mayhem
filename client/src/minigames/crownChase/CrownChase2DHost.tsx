import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface CrownChase2DHostProps {
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

export const CrownChase2DHost: React.FC<CrownChase2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastEventTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  useEffect(() => {
    const events = (mgData.tagEvents || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;
          sounds.playCrown();

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y - 40,
            text: '👑 KORONA ELRABOLVA! ✨',
            color: '#fbbf24',
            alpha: 1.0,
          });
        }
      });
    }
  }, [mgData.tagEvents]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. ROYAL THRONE ROOM BACKGROUND
    ctx.fillStyle = '#110c24';
    ctx.fillRect(0, 0, width, height);

    // Royal Purple Carpet (Center)
    ctx.fillStyle = '#2e1065';
    drawRoundedRect(ctx, 220, 220, 1480, 700, 32);
    ctx.fill();

    // Gold Trim on Carpet
    ctx.strokeStyle = '#ca8a04';
    ctx.lineWidth = 4;
    drawRoundedRect(ctx, 230, 230, 1460, 680, 26);
    ctx.stroke();

    // Checkerboard floor accents
    ctx.fillStyle = 'rgba(251, 191, 36, 0.05)';
    for (let x = 240; x < 1680; x += 100) {
      for (let y = 240; y < 900; y += 100) {
        if ((x + y) % 200 === 0) {
          ctx.fillRect(x, y, 100, 100);
        }
      }
    }

    // Outer Room Border
    ctx.strokeStyle = '#854d0e';
    ctx.lineWidth = 6;
    drawRoundedRect(ctx, 176, 176, 1568, 788, 28);
    ctx.stroke();

    // 2. PLAYERS & CHALLENGER DUMMIES
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    const currentHolderId = mgData.currentCrownHolder;

    Object.values(simPlayers).forEach(sim => {
      const realPlayer = room.players[sim.id];
      const isDummy = Boolean(sim.isDummy);
      const isHolder = sim.id === currentHolderId;

      // Sprint dust particles
      if (sim.sprintTimer && sim.sprintTimer > 0) {
        ctx.strokeStyle = '#38bdf8';
        ctx.lineWidth = 3;
        for (let i = 0; i < 3; i++) {
          const trailX = sim.x - Math.cos(sim.facing || 0) * (30 + i * 16);
          const trailY = sim.y - Math.sin(sim.facing || 0) * (30 + i * 16);
          ctx.beginPath();
          ctx.arc(trailX, trailY, 6 - i * 1.5, 0, Math.PI * 2);
          ctx.stroke();
        }
      }

      // Tag Immunity Halo (shield bubble)
      if (sim.tagImmunityTimer && sim.tagImmunityTimer > 0) {
        ctx.strokeStyle = '#38bdf8';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(sim.x, sim.y, sim.radius + 14, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Render character
      if (realPlayer) {
        drawPlayerCharacter2D(
          ctx,
          realPlayer,
          sim.x,
          sim.y,
          74,
          Math.cos(sim.facing || 0),
          sim.isHit || false,
          Math.floor(sim.crownTime || 0)
        );
      } else if (isDummy) {
        drawDummyChallenger(ctx, sim);
      }

      // Crown above holder's head
      if (isHolder) {
        const bob = Math.sin(elapsed * 8) * 6;
        const crownY = sim.y - 62 + bob;

        // Glowing Golden Ray Beam
        const beamGrad = ctx.createLinearGradient(sim.x, crownY - 30, sim.x, sim.y);
        beamGrad.addColorStop(0, 'rgba(251, 191, 36, 0.45)');
        beamGrad.addColorStop(1, 'rgba(251, 191, 36, 0.0)');
        ctx.fillStyle = beamGrad;
        ctx.beginPath();
        ctx.moveTo(sim.x - 24, crownY);
        ctx.lineTo(sim.x + 24, crownY);
        ctx.lineTo(sim.x + 36, sim.y + 10);
        ctx.lineTo(sim.x - 36, sim.y + 10);
        ctx.closePath();
        ctx.fill();

        // Crown Icon
        ctx.font = '46px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('👑', sim.x, crownY);
      }
    });

    // 3. FLOATING POPUPS
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

    // 4. CURRENT CROWN HOLDER BANNER (Top Center)
    const holderSim = simPlayers[currentHolderId];
    const holderReal = holderSim ? room.players[currentHolderId] : null;
    const holderName = holderReal ? holderReal.name : holderSim ? holderSim.name : 'Senki';

    ctx.save();
    ctx.translate(width / 2, 54);
    ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
    drawRoundedRect(ctx, -280, -28, 560, 56, 16);
    ctx.fill();
    ctx.strokeStyle = '#fbbf24';
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.font = 'bold 20px sans-serif';
    ctx.fillStyle = '#facc15';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`👑 KORONÁS: ${holderName.toUpperCase()} (${(holderSim?.crownTime || 0).toFixed(1)}s)`, 0, 0);
    ctx.restore();

    // 5. SCOREBOARD STRIP (Top Left/Right)
    const players = Object.values(room.players);
    players.forEach((p, idx) => {
      const pSim = simPlayers[p.id];
      const timeVal = (pSim?.crownTime || 0).toFixed(1);
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
      ctx.fillText(`👑 ${timeVal}s`, -22, 0);
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
          'Holder': mgData.players?.[mgData.currentCrownHolder]?.name || 'None',
          'Tags': (mgData.tagEvents || []).length,
        }}
        className="w-full h-full"
      />
    </div>
  );
};

function drawDummyChallenger(ctx: CanvasRenderingContext2D, sim: any) {
  ctx.save();
  ctx.translate(sim.x, sim.y);

  // Bot Shadow
  ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
  ctx.beginPath();
  ctx.ellipse(0, 22, 32, 12, 0, 0, Math.PI * 2);
  ctx.fill();

  // Bot Body
  ctx.fillStyle = sim.color || '#f59e0b';
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

  // Label
  ctx.font = 'bold 12px sans-serif';
  ctx.fillStyle = '#f8fafc';
  ctx.fillText('KIHÍVÓ', 0, 48);

  ctx.restore();
}
