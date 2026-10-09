import React, { useRef, useEffect } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';
import { sounds } from '../../audio/soundSynth';

interface MonsterEscape2DHostProps {
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

export const MonsterEscape2DHost: React.FC<MonsterEscape2DHostProps> = ({ room }) => {
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

          if (evt.type === 'chomp') {
            sounds.playExplosion();
          } else {
            sounds.playCoin();
          }

          popupsRef.current.push({
            id: `${evt.timestamp}-${Math.random()}`,
            x: evt.x,
            y: evt.y - 40,
            text: evt.text,
            color: evt.type === 'chomp' ? '#ef4444' : evt.text.includes('🔮') ? '#a855f7' : '#38bdf8',
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
    // 1. HAUNTED DUNGEON BACKGROUND
    ctx.fillStyle = '#050814';
    ctx.fillRect(0, 0, width, height);

    // Stone tile pattern
    ctx.strokeStyle = 'rgba(67, 56, 202, 0.15)';
    ctx.lineWidth = 2;
    for (let x = 180; x <= 1740; x += 120) {
      ctx.beginPath();
      ctx.moveTo(x, 180);
      ctx.lineTo(x, 960);
      ctx.stroke();
    }
    for (let y = 180; y <= 960; y += 120) {
      ctx.beginPath();
      ctx.moveTo(180, y);
      ctx.lineTo(1740, y);
      ctx.stroke();
    }

    // Outer Dungeon Boundary
    ctx.strokeStyle = '#6366f1';
    ctx.lineWidth = 5;
    drawRoundedRect(ctx, 176, 176, 1568, 788, 28);
    ctx.stroke();

    // 2. ENERGY CRYSTALS
    const crystals = (mgData.crystals || []) as any[];
    crystals.forEach(c => {
      ctx.save();
      ctx.translate(c.x, c.y);
      const bob = Math.sin(elapsed * 5 + c.id) * 5;
      ctx.translate(0, bob);

      // Glow Aura
      ctx.fillStyle = c.type === 'purple' ? 'rgba(168, 85, 247, 0.28)' : 'rgba(56, 189, 248, 0.25)';
      ctx.beginPath();
      ctx.arc(0, 0, c.radius + 12, 0, Math.PI * 2);
      ctx.fill();

      // Crystal Icon
      ctx.font = c.type === 'purple' ? '34px sans-serif' : '26px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(c.type === 'purple' ? '🔮' : '⚡', 0, 0);

      ctx.restore();
    });

    // 3. MONSTER (Shadow Beast)
    const monster = mgData.monster;
    if (monster) {
      ctx.save();
      ctx.translate(monster.x, monster.y);

      // Monster Terror Radius / Flashlight Cone
      const coneAngle = monster.facing || 0;
      const coneDist = 260;
      const coneWidth = Math.PI * 0.38;

      ctx.save();
      ctx.rotate(coneAngle);
      const coneGrad = ctx.createRadialGradient(0, 0, 30, 0, 0, coneDist);
      if (monster.isEnraged) {
        coneGrad.addColorStop(0, 'rgba(239, 68, 68, 0.45)');
        coneGrad.addColorStop(1, 'rgba(239, 68, 68, 0.0)');
      } else {
        coneGrad.addColorStop(0, 'rgba(168, 85, 247, 0.35)');
        coneGrad.addColorStop(1, 'rgba(168, 85, 247, 0.0)');
      }
      ctx.fillStyle = coneGrad;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, coneDist, -coneWidth / 2, coneWidth / 2);
      ctx.closePath();
      ctx.fill();
      ctx.restore();

      // Monster Shadow
      ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
      ctx.beginPath();
      ctx.ellipse(0, 32, monster.radius * 0.9, 18, 0, 0, Math.PI * 2);
      ctx.fill();

      // Enraged Flame Aura
      if (monster.isEnraged) {
        const pulse = Math.sin(elapsed * 25) * 8;
        ctx.fillStyle = 'rgba(239, 68, 68, 0.35)';
        ctx.beginPath();
        ctx.arc(0, 0, monster.radius + 16 + pulse, 0, Math.PI * 2);
        ctx.fill();
      }

      // Monster Body (Beast circle)
      const bodyGrad = ctx.createRadialGradient(0, -10, 10, 0, 0, monster.radius);
      bodyGrad.addColorStop(0, monster.isEnraged ? '#7f1d1d' : '#1e1b4b');
      bodyGrad.addColorStop(1, monster.isEnraged ? '#450a0a' : '#090514');
      ctx.fillStyle = bodyGrad;
      ctx.beginPath();
      ctx.arc(0, 0, monster.radius, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = monster.isEnraged ? '#ef4444' : '#a855f7';
      ctx.lineWidth = 4;
      ctx.stroke();

      // Monster Horns / Spikes
      ctx.fillStyle = monster.isEnraged ? '#ef4444' : '#c084fc';
      // Left horn
      ctx.beginPath();
      ctx.moveTo(-28, -monster.radius + 10);
      ctx.lineTo(-44, -monster.radius - 22);
      ctx.lineTo(-14, -monster.radius + 4);
      ctx.fill();
      // Right horn
      ctx.beginPath();
      ctx.moveTo(28, -monster.radius + 10);
      ctx.lineTo(44, -monster.radius - 22);
      ctx.lineTo(14, -monster.radius + 4);
      ctx.fill();

      // Glowing Eyes
      const eyeOffsetX = Math.cos(monster.facing || 0) * 8;
      const eyeOffsetY = Math.sin(monster.facing || 0) * 8;
      ctx.fillStyle = monster.isEnraged ? '#fef08a' : '#f43f5e';
      ctx.beginPath();
      ctx.arc(-16 + eyeOffsetX, -10 + eyeOffsetY, 9, 0, Math.PI * 2);
      ctx.arc(16 + eyeOffsetX, -10 + eyeOffsetY, 9, 0, Math.PI * 2);
      ctx.fill();

      // Eye pupils
      ctx.fillStyle = '#020617';
      ctx.beginPath();
      ctx.arc(-16 + eyeOffsetX * 1.3, -10 + eyeOffsetY * 1.3, 4, 0, Math.PI * 2);
      ctx.arc(16 + eyeOffsetX * 1.3, -10 + eyeOffsetY * 1.3, 4, 0, Math.PI * 2);
      ctx.fill();

      // Sharp Teeth / Mouth
      ctx.fillStyle = '#ffffff';
      for (let t = -24; t <= 24; t += 12) {
        ctx.beginPath();
        ctx.moveTo(t, 14);
        ctx.lineTo(t + 6, 26);
        ctx.lineTo(t + 12, 14);
        ctx.fill();
      }

      // Enraged or Cooldown Banner
      if (monster.isEnraged) {
        ctx.font = 'bold 16px sans-serif';
        ctx.fillStyle = '#ef4444';
        ctx.textAlign = 'center';
        ctx.fillText('🔥 DÜHÖS!', 0, -monster.radius - 32);
      } else if (monster.catchCooldown > 0) {
        ctx.font = 'bold 16px sans-serif';
        ctx.fillStyle = '#38bdf8';
        ctx.textAlign = 'center';
        ctx.fillText('💫 CSÁMPÁS!', 0, -monster.radius - 32);
      }

      ctx.restore();
    }

    // 4. PLAYERS
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    Object.values(simPlayers).forEach(sim => {
      const p = room.players[sim.id];
      if (!p) return;

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

      // Sweat / fear icon if monster is very close (< 240px)
      if (monster && Math.hypot(sim.x - monster.x, sim.y - monster.y) < 240) {
        ctx.font = '22px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('💦', sim.x + 28, sim.y - 36);
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

    // 6. MONSTER STATUS BANNER (Top Center)
    const isEnraged = monster?.isEnraged;
    ctx.save();
    ctx.translate(width / 2, 54);
    ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
    drawRoundedRect(ctx, -280, -28, 560, 56, 16);
    ctx.fill();
    ctx.strokeStyle = isEnraged ? '#ef4444' : '#a855f7';
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.font = 'bold 19px sans-serif';
    ctx.fillStyle = isEnraged ? '#ef4444' : '#c084fc';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(
      isEnraged ? '🚨 A SZÖRNY BEVADULT! GYORSABBAN FUT! 🚨' : '👾 VIGYÁZZ A SZÖRNYRE! GYŰJTS ENERGIAKRISTÁLYT!',
      0,
      0
    );
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
      ctx.fillStyle = '#a855f7';
      ctx.fillText(`🔮 ${score}`, -22, 0);
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
          'Monster Rage': mgData.monster?.isEnraged ? 'ENRAGED' : 'CALM',
          'Crystals': (mgData.crystals || []).length,
        }}
        className="w-full h-full"
      />
    </div>
  );
};
