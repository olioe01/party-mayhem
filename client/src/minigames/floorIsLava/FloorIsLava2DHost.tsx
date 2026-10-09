import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface FloorIsLava2DHostProps {
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

export const FloorIsLava2DHost: React.FC<FloorIsLava2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const lastEventTimeRef = useRef<number>(0);
  const popupsRef = useRef<FloatingPopup[]>([]);

  useEffect(() => {
    const events = (mgData.events || []) as any[];
    if (events.length > 0) {
      events.forEach(evt => {
        if (evt.timestamp > lastEventTimeRef.current) {
          lastEventTimeRef.current = evt.timestamp;

          if (evt.type === 'burn') {
            sounds.playExplosion();
          } else if (evt.type === 'ruby') {
            sounds.playCoin();
          } else {
            sounds.playButton();
          }

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y - 40,
            text: evt.text,
            color: evt.type === 'burn' ? '#ef4444' : evt.type === 'ruby' ? '#38bdf8' : '#fbbf24',
            alpha: 1.0,
          });
        }
      });
    }
  }, [mgData.events]);

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. MOLTEN LAVA LAKE BACKGROUND
    const lavaGrad = ctx.createLinearGradient(0, 0, 0, height);
    lavaGrad.addColorStop(0, '#450a0a');
    lavaGrad.addColorStop(0.5, '#7f1d1d');
    lavaGrad.addColorStop(1, '#991b1b');
    ctx.fillStyle = lavaGrad;
    ctx.fillRect(0, 0, width, height);

    // Dynamic lava heat waves & bubbles
    ctx.fillStyle = 'rgba(239, 68, 68, 0.25)';
    for (let i = 0; i < 8; i++) {
      const bx = (i * 240 + Math.sin(elapsed * 2 + i) * 60) % width;
      const by = 200 + ((i * 120 + elapsed * 40) % 700);
      const br = 28 + Math.sin(elapsed * 4 + i) * 12;
      ctx.beginPath();
      ctx.arc(bx, by, Math.max(10, br), 0, Math.PI * 2);
      ctx.fill();
    }

    // 2. STONE PLATFORMS
    const platforms = (mgData.platforms || []) as any[];
    platforms.forEach(pl => {
      ctx.save();
      ctx.translate(pl.x, pl.y);

      const pW = pl.width;
      const pH = pl.height;

      if (pl.state === 'safe') {
        // Safe Obsidian Stone Island
        ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
        ctx.fillRect(-pW / 2 + 6, -pH / 2 + 10, pW, pH);

        const stoneGrad = ctx.createLinearGradient(0, -pH / 2, 0, pH / 2);
        stoneGrad.addColorStop(0, '#334155');
        stoneGrad.addColorStop(1, '#1e293b');
        ctx.fillStyle = stoneGrad;
        drawRoundedRect(ctx, -pW / 2, -pH / 2, pW, pH, 14);
        ctx.fill();

        ctx.strokeStyle = '#475569';
        ctx.lineWidth = 3;
        ctx.stroke();

        // Inner runic floor pattern
        ctx.strokeStyle = 'rgba(148, 163, 184, 0.2)';
        ctx.lineWidth = 2;
        ctx.strokeRect(-pW / 2 + 16, -pH / 2 + 14, pW - 32, pH - 28);
      } else if (pl.state === 'warning') {
        // Warning: Cracking red-hot stone, violent shake
        const shakeX = Math.sin(elapsed * 50 + pl.id) * 3.5;
        const shakeY = Math.cos(elapsed * 50 + pl.id) * 3.5;
        ctx.translate(shakeX, shakeY);

        ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
        ctx.fillRect(-pW / 2 + 6, -pH / 2 + 10, pW, pH);

        const warnGrad = ctx.createLinearGradient(0, -pH / 2, 0, pH / 2);
        warnGrad.addColorStop(0, '#ea580c');
        warnGrad.addColorStop(1, '#9a3412');
        ctx.fillStyle = warnGrad;
        drawRoundedRect(ctx, -pW / 2, -pH / 2, pW, pH, 14);
        ctx.fill();

        ctx.strokeStyle = '#f97316';
        ctx.lineWidth = 4;
        ctx.stroke();

        // Warning Danger Cracks & Icon
        ctx.font = 'bold 16px sans-serif';
        ctx.fillStyle = '#fef08a';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('⚠️ SÜLLYED!', 0, 0);
      } else if (pl.state === 'lava') {
        // Lava: Sunken boiling magma pool
        ctx.fillStyle = 'rgba(239, 68, 68, 0.7)';
        drawRoundedRect(ctx, -pW / 2, -pH / 2, pW, pH, 14);
        ctx.fill();

        ctx.strokeStyle = '#facc15';
        ctx.lineWidth = 3;
        ctx.setLineDash([8, 6]);
        ctx.stroke();
        ctx.setLineDash([]);

        // Bubbling flames in center
        ctx.font = '32px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('🔥', 0, 0);
      }

      ctx.restore();
    });

    // 3. RUBY BONUS CRYSTALS
    const rubies = (mgData.rubies || []) as any[];
    rubies.forEach(r => {
      ctx.save();
      ctx.translate(r.x, r.y);
      const bob = Math.sin(elapsed * 6 + r.id) * 6;
      ctx.translate(0, bob);

      // Glow halo
      ctx.fillStyle = 'rgba(56, 189, 248, 0.3)';
      ctx.beginPath();
      ctx.arc(0, 0, 28, 0, Math.PI * 2);
      ctx.fill();

      ctx.font = '36px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('💎', 0, 0);
      ctx.restore();
    });

    // 4. PLAYERS
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    Object.values(simPlayers).forEach(sim => {
      const p = room.players[sim.id];
      if (!p) return;

      const isJumping = (sim.jumpTimer || 0) > 0;
      const jumpOffset = isJumping ? -Math.sin(((0.38 - sim.jumpTimer) / 0.38) * Math.PI) * 28 : 0;
      const jumpScale = isJumping ? 1.15 : 1.0;

      // Player shadow on platform
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath();
      ctx.ellipse(sim.x, sim.y + 12, 28, 10, 0, 0, Math.PI * 2);
      ctx.fill();

      ctx.save();
      ctx.translate(0, jumpOffset);
      drawPlayerCharacter2D(
        ctx,
        p,
        sim.x,
        sim.y,
        Math.round(74 * jumpScale),
        Math.cos(sim.facing || 0),
        sim.isHit || false,
        sim.score ?? 0
      );
      ctx.restore();

      // Jump indicator text if leaping
      if (isJumping) {
        ctx.font = 'bold 12px sans-serif';
        ctx.fillStyle = '#38bdf8';
        ctx.textAlign = 'center';
        ctx.fillText('💨 UGRÁS!', sim.x, sim.y + jumpOffset - 46);
      }
    });

    // 5. FLOATING POPUPS
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

    // 6. WAVE STATUS BANNER (Top Center)
    const waveState = mgData.waveState || 'rest';
    let bannerText = '🟢 BIZTONSÁGOS IDŐSZAK - KERESS JÓ KÖVET!';
    let bannerColor = '#10b981';
    let bannerBorder = '#34d399';

    if (waveState === 'warning') {
      bannerText = '⚠️ VIGYÁZAT! A KÖVEK SÜLLYEDNEK! KERESS SZILÁRD KÖVET!';
      bannerColor = '#f59e0b';
      bannerBorder = '#fbbf24';
    } else if (waveState === 'lava') {
      bannerText = '🔥 A PADLÓ LÁVA! MARADJ A BIZTONSÁGOS KÖVÖN!';
      bannerColor = '#ef4444';
      bannerBorder = '#f87171';
    }

    ctx.save();
    ctx.translate(width / 2, 54);
    ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
    drawRoundedRect(ctx, -340, -28, 680, 56, 16);
    ctx.fill();
    ctx.strokeStyle = bannerBorder;
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.font = 'bold 19px sans-serif';
    ctx.fillStyle = bannerColor;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(bannerText, 0, 0);
    ctx.restore();

    // 7. SCOREBOARD STRIP (Top Left/Right)
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
      ctx.fillStyle = '#fbbf24';
      ctx.fillText(`🔥 ${score}`, -22, 0);
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
          'State': mgData.waveState || 'rest',
          'Wave #': mgData.waveCount || 0,
          'Timer': `${Math.max(0, (mgData.waveTimer || 0)).toFixed(1)}s`,
        }}
        className="w-full h-full"
      />
    </div>
  );
};
