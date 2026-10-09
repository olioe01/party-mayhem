import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface DeliveryDash2DHostProps {
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

const DELIVERY_ZONES = [
  { id: 1, name: 'Pizza Shop', emoji: '🍕', x: 960, y: 220, radius: 95, color: '#f97316' },
  { id: 2, name: 'Game Store', emoji: '🎮', x: 1620, y: 560, radius: 95, color: '#8b5cf6' },
  { id: 3, name: 'Coffee Cafe', emoji: '☕', x: 960, y: 900, radius: 95, color: '#eab308' },
  { id: 4, name: 'Florist', emoji: '🌸', x: 300, y: 560, radius: 95, color: '#ec4899' },
];

export const DeliveryDash2DHost: React.FC<DeliveryDash2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastEventTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  useEffect(() => {
    const events = (mgData.deliveryEvents || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;
          sounds.playCoin();

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y - 40,
            text: `+1 KISZÁLLÍTVA! 📦✨`,
            color: '#4ade80',
            alpha: 1.0,
          });
        }
      });
    }
  }, [mgData.deliveryEvents]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. ARENA ROAD & PAVEMENT BACKGROUND
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, width, height);

    // Cross-roads paving
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(180, 480, 1560, 160); // East-West road
    ctx.fillRect(880, 140, 160, 840); // North-South road

    // Road dash lines
    ctx.strokeStyle = '#64748b';
    ctx.lineWidth = 4;
    ctx.setLineDash([24, 20]);
    // Horizontal road divider
    ctx.beginPath();
    ctx.moveTo(180, 560);
    ctx.lineTo(1740, 560);
    ctx.stroke();
    // Vertical road divider
    ctx.beginPath();
    ctx.moveTo(960, 140);
    ctx.lineTo(960, 980);
    ctx.stroke();
    ctx.setLineDash([]);

    // 2. CENTRAL PACKAGE DEPOT
    const depotW = 200;
    const depotH = 140;
    ctx.fillStyle = '#090d16';
    drawRoundedRect(ctx, 960 - depotW / 2, 560 - depotH / 2, depotW, depotH, 18);
    ctx.fill();
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 3;
    ctx.stroke();

    // Hazard stripes at depot border
    ctx.fillStyle = '#f59e0b';
    ctx.font = 'bold 12px monospace';
    ctx.textAlign = 'center';
    ctx.fillText('📦 CSOMAG RAKTÁR', 960, 560 - depotH / 2 + 18);

    // 3. DELIVERY ZONES
    const targetIdx = (mgData.targetZoneIndex || 0) % DELIVERY_ZONES.length;

    DELIVERY_ZONES.forEach((zone, idx) => {
      const isTarget = idx === targetIdx;

      ctx.save();
      ctx.translate(zone.x, zone.y);

      // Zone ring
      ctx.fillStyle = isTarget ? `${zone.color}33` : 'rgba(30, 41, 59, 0.4)';
      ctx.beginPath();
      ctx.arc(0, 0, zone.radius, 0, Math.PI * 2);
      ctx.fill();

      // Border ring (pulsing if active target)
      const pulse = isTarget ? Math.sin(elapsed * 6) * 4 : 0;
      ctx.strokeStyle = isTarget ? zone.color : '#475569';
      ctx.lineWidth = isTarget ? 5 + pulse * 0.5 : 2;
      if (isTarget) {
        ctx.setLineDash([12, 8]);
      }
      ctx.beginPath();
      ctx.arc(0, 0, zone.radius + pulse, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);

      // Shop canopy / building roof shadow
      ctx.fillStyle = 'rgba(0,0,0,0.4)';
      ctx.beginPath();
      ctx.ellipse(0, 24, 46, 16, 0, 0, Math.PI * 2);
      ctx.fill();

      // Shop Icon
      ctx.font = isTarget ? '52px sans-serif' : '40px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(zone.emoji, 0, -6);

      // Shop Title Plate
      ctx.fillStyle = isTarget ? zone.color : '#334155';
      drawRoundedRect(ctx, -64, 34, 128, 24, 8);
      ctx.fill();
      ctx.font = 'bold 12px sans-serif';
      ctx.fillStyle = isTarget ? '#020617' : '#94a3b8';
      ctx.fillText(zone.name, 0, 46);

      // Flashing TARGET BEACON ARROW
      if (isTarget) {
        const bounce = Math.sin(elapsed * 8) * 8;
        ctx.font = '32px sans-serif';
        ctx.fillText('⬇️', 0, -zone.radius - 24 + bounce);
      }

      ctx.restore();
    });

    // 4. UNHELD PACKAGES ON GROUND
    const packages = (mgData.packages || []) as any[];
    packages.forEach(pkg => {
      if (!pkg.isHeld) {
        drawPackageBox(ctx, pkg.x, pkg.y, 1.0, elapsed);
      }
    });

    // 5. PLAYERS & CARRIED PACKAGES
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    Object.values(simPlayers).forEach(sim => {
      const p = room.players[sim.id];
      if (!p) return;

      // Dash particle sprint lines
      if (sim.dashTimer && sim.dashTimer > 0) {
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

      drawPlayerCharacter2D(
        ctx,
        p,
        sim.x,
        sim.y,
        74,
        Math.cos(sim.facing || 0),
        sim.isHit || false,
        sim.score ?? 0
      );

      // Carried Package floating above player head
      if (sim.carryingPackage) {
        const bob = Math.sin(elapsed * 12) * 4;
        drawPackageBox(ctx, sim.x, sim.y - 54 + bob, 0.9, elapsed);
      }
    });

    // 6. FLOATING POPUPS
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

    // 7. ACTIVE ORDER BANNER (Top Center)
    const activeZone = DELIVERY_ZONES[targetIdx];
    ctx.save();
    ctx.translate(width / 2, 54);
    ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
    drawRoundedRect(ctx, -260, -28, 520, 56, 16);
    ctx.fill();
    ctx.strokeStyle = activeZone.color;
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.font = 'bold 20px sans-serif';
    ctx.fillStyle = '#f8fafc';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`RENDELÉS: ${activeZone.emoji} ${activeZone.name.toUpperCase()}`, 0, 0);
    ctx.restore();

    // 8. SCOREBOARD STRIP (Top Left/Right)
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
      ctx.fillText(`📦 ${score}`, -22, 0);
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
          'Packages': (mgData.packages || []).length,
          'Active Zone': DELIVERY_ZONES[(mgData.targetZoneIndex || 0) % DELIVERY_ZONES.length].name,
        }}
        className="w-full h-full"
      />
    </div>
  );
};

function drawPackageBox(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  scale: number = 1.0,
  elapsed: number = 0
) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);

  const bW = 38;
  const bH = 34;

  // Box Shadow
  ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
  ctx.beginPath();
  ctx.ellipse(0, bH / 2 + 4, bW * 0.45, 6, 0, 0, Math.PI * 2);
  ctx.fill();

  // Cardboard body
  ctx.fillStyle = '#b45309';
  drawRoundedRect(ctx, -bW / 2, -bH / 2, bW, bH, 6);
  ctx.fill();
  ctx.strokeStyle = '#78350f';
  ctx.lineWidth = 2.5;
  ctx.stroke();

  // Packing tape
  ctx.fillStyle = '#ca8a04';
  ctx.fillRect(-6, -bH / 2, 12, bH);
  ctx.fillRect(-bW / 2, -4, bW, 8);

  // Fragile stamp
  ctx.font = '14px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('📦', 0, 0);

  ctx.restore();
}
