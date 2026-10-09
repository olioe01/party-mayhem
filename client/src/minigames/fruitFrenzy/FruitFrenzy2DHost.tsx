import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, VIRTUAL_WIDTH, VIRTUAL_HEIGHT, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface FruitFrenzy2DHostProps {
  room: RoomState;
}

interface FloatingPopup {
  id: string;
  x: number;
  y: number;
  text: string;
  color: string;
  alpha: number;
  scale: number;
}

export const FruitFrenzy2DHost: React.FC<FruitFrenzy2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  // Track sound triggers
  const lastCatchTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  // Sound & popup trigger effect on new catchEvents
  useEffect(() => {
    const catchEvents = (mgData.catchEvents || []) as any[];
    if (catchEvents.length > 0) {
      catchEvents.forEach(evt => {
        if (evt.timestamp > lastCatchTimeRef.current) {
          lastCatchTimeRef.current = evt.timestamp;

          // Sound effect
          if (evt.type === 'bomb') {
            sounds.playExplosion();
          } else {
            sounds.playCoin();
          }

          // Spawn floating score popup
          const text = evt.type === 'bomb' ? '-3 💣' : `+${evt.points} ${evt.type === 'star' ? '💎' : evt.type === 'golden' ? '🌟' : '🍎'}`;
          const color = evt.type === 'bomb' ? '#ef4444' : evt.type === 'star' ? '#38bdf8' : evt.type === 'golden' ? '#fbbf24' : '#4ade80';

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y,
            text,
            color,
            alpha: 1.0,
            scale: 1.3,
          });
        }
      });
    }
  }, [mgData.catchEvents]);

  // Main 60 FPS Canvas Render Function
  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. STAGE BACKGROUND: Sunny orchard sunset & ground
    const bgGradient = ctx.createLinearGradient(0, 0, 0, height);
    bgGradient.addColorStop(0, '#0f172a'); // night sky top
    bgGradient.addColorStop(0.55, '#1e1b4b'); // purple horizon
    bgGradient.addColorStop(0.75, '#431407'); // warm glow
    bgGradient.addColorStop(0.85, '#14532d'); // orchard grass
    bgGradient.addColorStop(1, '#052e16'); // deep forest floor
    ctx.fillStyle = bgGradient;
    ctx.fillRect(0, 0, width, height);

    // Decorative background stars / distant floating lights
    ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
    for (let i = 0; i < 24; i++) {
      const sx = (i * 83 + elapsed * 5) % width;
      const sy = 40 + (i * 37) % 360;
      const radius = 1.2 + Math.sin(elapsed * 2 + i) * 0.8;
      ctx.beginPath();
      ctx.arc(sx, sy, Math.max(0.5, radius), 0, Math.PI * 2);
      ctx.fill();
    }

    // Ground platform line
    const groundY = 960;
    ctx.fillStyle = '#166534';
    ctx.fillRect(0, groundY - 20, width, height - groundY + 20);

    // Platform wooden curb / border
    ctx.fillStyle = '#b45309';
    ctx.fillRect(0, groundY - 26, width, 8);
    ctx.fillStyle = '#78350f';
    ctx.fillRect(0, groundY - 18, width, 4);

    // 2. FALLING ITEMS (FRUITS & BOMBS)
    const items = (mgData.items || []) as any[];
    items.forEach(item => {
      drawFallingItem(ctx, item, elapsed);
    });

    // 3. PLAYERS & BASKETS
    const playersSim = (mgData.players || {}) as Record<string, any>;
    Object.values(playersSim).forEach(sim => {
      const player = room.players[sim.id];
      if (!player) return;

      const px = sim.x;
      const py = sim.y;

      // Draw Player Pill Body & Head
      drawPlayerCharacter2D(
        ctx,
        player,
        px,
        py,
        74,
        sim.facing || 0,
        sim.isHit || false,
        sim.score ?? 0
      );

      // Draw Basket in front of player
      drawWickerBasket(ctx, px, py - 6, sim.basketWidth || 110, sim.isHit || false, elapsed);
    });

    // 4. FLOATING SCORE POPUPS (+1, +3, -3)
    popupsRef.current.forEach(pop => {
      pop.y -= 75 * dt; // float upwards
      pop.alpha -= 0.9 * dt; // fade out
      pop.scale = Math.max(1.0, pop.scale - 0.4 * dt);

      if (pop.alpha > 0) {
        ctx.save();
        ctx.globalAlpha = Math.max(0, pop.alpha);
        ctx.font = `black ${Math.round(26 * pop.scale)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        // Outer glow
        ctx.strokeStyle = '#020617';
        ctx.lineWidth = 6;
        ctx.strokeText(pop.text, pop.x, pop.y);

        ctx.fillStyle = pop.color;
        ctx.fillText(pop.text, pop.x, pop.y);
        ctx.restore();
      }
    });

    // Prune expired popups
    popupsRef.current = popupsRef.current.filter(p => p.alpha > 0);

    // 5. TOP LEADERBOARD SCORE STRIP
    drawTopScoreboard(ctx, room, mgData, width);
  };

  return (
    <div className="relative w-full h-full flex items-center justify-center overflow-hidden">
      <MinigameCanvas2D
        room={room}
        onRender={handleRender}
        showDevOverlay={true}
        extraDevStats={{
          'Items': (mgData.items || []).length,
          'Progress': `${Math.round((mgData.matchProgress || 0) * 100)}%`,
        }}
      />
    </div>
  );
};

// ==========================================
// ITEM DRAWING HELPERS (Vector/Canvas Art)
// ==========================================

function drawFallingItem(ctx: CanvasRenderingContext2D, item: any, elapsed: number) {
  const { x, y, type } = item;
  ctx.save();
  ctx.translate(x, y);

  // Slight wobble rotation while falling
  const wobble = Math.sin(elapsed * 6 + item.id) * 0.15;
  ctx.rotate(wobble);

  if (type === 'bomb') {
    // 💣 CARTOON BOMB
    const r = 26;
    // Bomb black body with specular sheen
    const grad = ctx.createRadialGradient(-6, -6, 2, 0, 0, r);
    grad.addColorStop(0, '#52525b');
    grad.addColorStop(0.4, '#27272a');
    grad.addColorStop(1, '#09090b');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 3;
    ctx.stroke();

    // Fuse cap
    ctx.fillStyle = '#71717a';
    ctx.fillRect(-6, -r - 5, 12, 6);

    // Fuse wire
    ctx.strokeStyle = '#d97706';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, -r - 5);
    ctx.quadraticCurveTo(8, -r - 14, 4, -r - 18);
    ctx.stroke();

    // Flickering Animated Spark
    const sparkR = 5 + Math.sin(elapsed * 30 + item.id) * 2;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath();
    ctx.arc(4, -r - 18, sparkR, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#fef08a';
    ctx.beginPath();
    ctx.arc(4, -r - 18, sparkR * 0.5, 0, Math.PI * 2);
    ctx.fill();

    // Skull or "!" on bomb
    ctx.font = 'bold 15px sans-serif';
    ctx.fillStyle = '#ef4444';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('💣', 0, 1);
  } else if (type === 'golden') {
    // 🌟 GOLDEN APPLE (radiant gold with sparkle)
    const r = 25;

    // Golden glow ring
    ctx.fillStyle = 'rgba(251, 191, 36, 0.25)';
    ctx.beginPath();
    ctx.arc(0, 0, r * 1.5, 0, Math.PI * 2);
    ctx.fill();

    const grad = ctx.createRadialGradient(-7, -7, 2, 0, 0, r);
    grad.addColorStop(0, '#fef08a');
    grad.addColorStop(0.3, '#facc15');
    grad.addColorStop(1, '#b45309');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#78350f';
    ctx.lineWidth = 2.5;
    ctx.stroke();

    // Leaf stem
    ctx.fillStyle = '#15803d';
    ctx.beginPath();
    ctx.ellipse(5, -r - 3, 6, 3, 0.5, 0, Math.PI * 2);
    ctx.fill();

    // Star icon overlay
    ctx.font = 'bold 16px sans-serif';
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('★', 0, 1);
  } else if (type === 'star') {
    // 💎 STAR FRUIT (Diamond neon star)
    const r = 28;

    // Cyan glow
    ctx.fillStyle = 'rgba(56, 189, 248, 0.3)';
    ctx.beginPath();
    ctx.arc(0, 0, r * 1.6, 0, Math.PI * 2);
    ctx.fill();

    // 8-point diamond star
    ctx.fillStyle = '#38bdf8';
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    for (let i = 0; i < 8; i++) {
      const angle = (i * Math.PI) / 4;
      const rad = i % 2 === 0 ? r : r * 0.45;
      const sx = Math.cos(angle) * rad;
      const sy = Math.sin(angle) * rad;
      if (i === 0) ctx.moveTo(sx, sy);
      else ctx.lineTo(sx, sy);
    }
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(0, 0, 5, 0, Math.PI * 2);
    ctx.fill();
  } else {
    // 🍎 REGULAR FRUITS
    const r = 23;
    let mainColor = '#ef4444'; // Apple default
    let darkColor = '#991b1b';
    let icon = '🍎';

    if (type === 'orange') {
      mainColor = '#f97316';
      darkColor = '#9a3412';
      icon = '🍊';
    } else if (type === 'banana') {
      mainColor = '#eab308';
      darkColor = '#854d0e';
      icon = '🍌';
    } else if (type === 'strawberry') {
      mainColor = '#f43f5e';
      darkColor = '#9f1239';
      icon = '🍓';
    }

    const grad = ctx.createRadialGradient(-6, -6, 2, 0, 0, r);
    grad.addColorStop(0, '#ffffff');
    grad.addColorStop(0.2, mainColor);
    grad.addColorStop(1, darkColor);
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = darkColor;
    ctx.lineWidth = 2.5;
    ctx.stroke();

    // Stem
    ctx.fillStyle = '#15803d';
    ctx.beginPath();
    ctx.ellipse(4, -r - 2, 5, 2.5, 0.4, 0, Math.PI * 2);
    ctx.fill();

    // Fruit emoji tag
    ctx.font = '16px serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(icon, 0, 1);
  }

  ctx.restore();
}

// ==========================================
// BASKET DRAWING HELPER
// ==========================================

function drawWickerBasket(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number = 110,
  isHit: boolean = false,
  elapsed: number = 0
) {
  ctx.save();
  ctx.translate(x, y);

  const bH = 34;
  const bW = width;

  // Basket shadow
  ctx.fillStyle = 'rgba(0, 0, 0, 0.25)';
  ctx.beginPath();
  ctx.ellipse(0, bH / 2 + 2, bW * 0.45, 6, 0, 0, Math.PI * 2);
  ctx.fill();

  // Basket Wicker Body (tapered trapezoid)
  ctx.beginPath();
  ctx.moveTo(-bW / 2, -bH / 2);
  ctx.lineTo(bW / 2, -bH / 2);
  ctx.lineTo((bW * 0.78) / 2, bH / 2);
  ctx.lineTo((-bW * 0.78) / 2, bH / 2);
  ctx.closePath();

  const wickerGrad = ctx.createLinearGradient(0, -bH / 2, 0, bH / 2);
  if (isHit) {
    wickerGrad.addColorStop(0, '#f87171');
    wickerGrad.addColorStop(1, '#dc2626');
  } else {
    wickerGrad.addColorStop(0, '#eab308'); // gold weave
    wickerGrad.addColorStop(0.5, '#ca8a04');
    wickerGrad.addColorStop(1, '#854d0e'); // warm leather bottom
  }
  ctx.fillStyle = wickerGrad;
  ctx.fill();
  ctx.strokeStyle = '#451a03';
  ctx.lineWidth = 3;
  ctx.stroke();

  // Woven texture lines
  ctx.strokeStyle = 'rgba(0, 0, 0, 0.25)';
  ctx.lineWidth = 1.5;
  for (let i = -bW / 2 + 15; i < bW / 2; i += 18) {
    ctx.beginPath();
    ctx.moveTo(i, -bH / 2);
    ctx.lineTo(i * 0.82, bH / 2);
    ctx.stroke();
  }

  // Sturdy Basket Wooden Top Rim
  ctx.fillStyle = isHit ? '#ef4444' : '#a16207';
  ctx.strokeStyle = '#451a03';
  ctx.lineWidth = 2.5;
  drawRoundedRect(ctx, -bW / 2 - 4, -bH / 2 - 4, bW + 8, 8, 4);
  ctx.fill();
  ctx.stroke();

  // Hit stars indicator
  if (isHit) {
    ctx.font = '20px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('💫', 0, -bH / 2 - 16);
  }

  ctx.restore();
}

// ==========================================
// LEADERBOARD STRIP
// ==========================================

function drawTopScoreboard(
  ctx: CanvasRenderingContext2D,
  room: RoomState,
  mgData: any,
  width: number
) {
  const players = Object.values(room.players);
  const totalPlayers = players.length;
  if (totalPlayers === 0) return;

  const cardW = Math.min(220, (width - 120) / totalPlayers);
  const totalWidth = players.length * cardW + (players.length - 1) * 14;
  const startX = (width - totalWidth) / 2;
  const startY = 16;

  players.forEach((p, idx) => {
    const sim = mgData.players?.[p.id];
    const score = mgData.scores?.[p.id] ?? sim?.score ?? 0;
    const avatar = AVATARS[p.avatar] || AVATARS['fox'];
    const cx = startX + idx * (cardW + 14);

    ctx.save();
    // Card background
    ctx.fillStyle = 'rgba(15, 23, 42, 0.88)';
    ctx.strokeStyle = sim?.isHit ? '#ef4444' : 'rgba(251, 191, 36, 0.5)';
    ctx.lineWidth = 2;
    drawRoundedRect(ctx, cx, startY, cardW, 50, 14);
    ctx.fill();
    ctx.stroke();

    // Avatar emoji
    ctx.font = '24px serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(avatar.emoji, cx + 10, startY + 25);

    // Player name
    ctx.font = 'bold 14px sans-serif';
    ctx.fillStyle = p.color || '#ffffff';
    const nameStr = p.name.length > 10 ? p.name.substring(0, 9) + '…' : p.name;
    ctx.fillText(nameStr, cx + 46, startY + 18);

    // Score
    ctx.font = 'black 18px monospace';
    ctx.fillStyle = '#fbbf24';
    ctx.fillText(`🍎 ${score}`, cx + 46, startY + 36);

    ctx.restore();
  });
}
