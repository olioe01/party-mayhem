import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface CoinScramble2DHostProps {
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

export const CoinScramble2DHost: React.FC<CoinScramble2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastEventTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  useEffect(() => {
    const events = (mgData.coinCollectEvents || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;

          if (evt.type === 'cursed') {
            sounds.playExplosion();
          } else {
            sounds.playCoin();
          }

          const text = evt.type === 'cursed' ? '-3 💀' : evt.type === 'gold' ? '+5 🌟' : '+1 🪙';
          const color = evt.type === 'cursed' ? '#ef4444' : evt.type === 'gold' ? '#fbbf24' : '#4ade80';

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y,
            text,
            color,
            alpha: 1.0,
          });
        }
      });
    }
  }, [mgData.coinCollectEvents]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. ARENA FLOOR
    ctx.fillStyle = '#081325';
    ctx.fillRect(0, 0, width, height);

    // Decorative grid tile lines
    ctx.strokeStyle = 'rgba(30, 58, 138, 0.3)';
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

    // Outer Glowing Border
    ctx.strokeStyle = '#eab308';
    ctx.lineWidth = 5;
    drawRoundedRect(ctx, 116, 136, 1688, 808, 28);
    ctx.stroke();

    // 2. ACTIVE COINS
    const coins = (mgData.coins || []) as any[];
    coins.forEach(coin => {
      ctx.save();
      ctx.translate(coin.x, coin.y);

      const bob = Math.sin(elapsed * 5 + coin.id) * 3;
      ctx.translate(0, bob);

      if (coin.type === 'gold') {
        // --- 🌟 SUPER GOLD COIN (+5) ---
        const r = coin.radius;
        // Outer glow
        ctx.fillStyle = 'rgba(250, 204, 21, 0.35)';
        ctx.beginPath();
        ctx.arc(0, 0, r * 1.5, 0, Math.PI * 2);
        ctx.fill();

        // 3D Coin face
        const grad = ctx.createRadialGradient(-6, -6, 2, 0, 0, r);
        grad.addColorStop(0, '#fef08a');
        grad.addColorStop(0.3, '#facc15');
        grad.addColorStop(1, '#b45309');
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(0, 0, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#78350f';
        ctx.lineWidth = 3;
        ctx.stroke();

        ctx.font = 'bold 22px sans-serif';
        ctx.fillStyle = '#ffffff';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('★', 0, 1);
      } else if (coin.type === 'cursed') {
        // --- 💀 CURSED COIN (-3) ---
        const r = coin.radius;
        // Purple danger glow
        ctx.fillStyle = 'rgba(168, 85, 247, 0.3)';
        ctx.beginPath();
        ctx.arc(0, 0, r * 1.4, 0, Math.PI * 2);
        ctx.fill();

        const grad = ctx.createRadialGradient(-5, -5, 2, 0, 0, r);
        grad.addColorStop(0, '#e879f9');
        grad.addColorStop(0.4, '#7e22ce');
        grad.addColorStop(1, '#3b0764');
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(0, 0, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#2e1065';
        ctx.lineWidth = 2.5;
        ctx.stroke();

        ctx.font = '18px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('💀', 0, 1);
      } else {
        // --- 🪙 NORMAL COIN (+1) ---
        const r = coin.radius;
        const grad = ctx.createRadialGradient(-4, -4, 2, 0, 0, r);
        grad.addColorStop(0, '#fef9c3');
        grad.addColorStop(0.3, '#facc15');
        grad.addColorStop(1, '#ca8a04');
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(0, 0, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#854d0e';
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.font = '17px serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('🪙', 0, 1);
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

    // 4. FLOATING POPUPS
    popupsRef.current.forEach(pop => {
      pop.y -= 70 * dt;
      pop.alpha -= 0.85 * dt;

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
          'Coins': (mgData.coins || []).length,
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
    ctx.fillText(`🪙 ${score} pts`, cx + 46, startY + 36);

    ctx.restore();
  });
}
