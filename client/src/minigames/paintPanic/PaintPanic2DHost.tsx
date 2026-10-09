import React, { useRef } from 'react';
import { RoomState } from '@shared/types';
import { MinigameCanvas2D, drawRoundedRect, drawPlayerCharacter2D } from '../../host/2d/MinigameCanvas2D';
import { AVATARS } from '@shared/constants';

interface PaintPanic2DHostProps {
  room: RoomState;
}

export const PaintPanic2DHost: React.FC<PaintPanic2DHostProps> = ({ room }) => {
  const mg = room.activeMinigame;
  const mgData = mg?.data || {};

  const handleRender = (
    ctx: CanvasRenderingContext2D,
    dt: number,
    width: number,
    height: number,
    elapsed: number
  ) => {
    // 1. ARENA BACKGROUND
    ctx.fillStyle = '#0b0f19';
    ctx.fillRect(0, 0, width, height);

    const cols = mgData.gridCols || 28;
    const rows = mgData.gridRows || 16;
    const cellSize = mgData.cellSize || 50;
    const gridX = mgData.gridX || 260;
    const gridY = mgData.gridY || 140;
    const gridW = cols * cellSize;
    const gridH = rows * cellSize;

    // Outer Arena Border & Shadow
    ctx.fillStyle = '#111827';
    drawRoundedRect(ctx, gridX - 16, gridY - 16, gridW + 32, gridH + 32, 24);
    ctx.fill();
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 4;
    ctx.stroke();

    // 2. GRID TILES
    const cells: number[] = mgData.cells || [];
    const playerIndices: Record<string, number> = mgData.playerIndices || {};

    // Map 1-indexed playerIdx -> player object
    const idxToPlayer: Record<number, any> = {};
    Object.entries(playerIndices).forEach(([pId, idx]) => {
      idxToPlayer[idx] = room.players[pId];
    });

    const tileGap = 2;
    const innerTileSize = cellSize - tileGap;

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const x = gridX + c * cellSize + tileGap / 2;
        const y = gridY + r * cellSize + tileGap / 2;
        const cellVal = cells[r * cols + c] || 0;

        if (cellVal > 0 && idxToPlayer[cellVal]) {
          const owner = idxToPlayer[cellVal];
          ctx.fillStyle = owner.color || '#3b82f6';
          drawRoundedRect(ctx, x, y, innerTileSize, innerTileSize, 6);
          ctx.fill();

          // Highlight gloss on tile top
          ctx.fillStyle = 'rgba(255, 255, 255, 0.18)';
          ctx.fillRect(x + 2, y + 2, innerTileSize - 4, innerTileSize * 0.35);
        } else {
          // Unpainted neutral tile
          const isCheckered = (r + c) % 2 === 0;
          ctx.fillStyle = isCheckered ? '#1e293b' : '#172033';
          drawRoundedRect(ctx, x, y, innerTileSize, innerTileSize, 4);
          ctx.fill();
        }
      }
    }

    // 3. PLAYERS
    const simPlayers = (mgData.players || {}) as Record<string, any>;
    Object.values(simPlayers).forEach(sim => {
      const p = room.players[sim.id];
      if (!p) return;

      // Paint splash halo under player
      ctx.fillStyle = `${p.color || '#3b82f6'}55`;
      ctx.beginPath();
      ctx.arc(sim.x, sim.y + 12, sim.radius + 14, 0, Math.PI * 2);
      ctx.fill();

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
    });

    // 4. LIVE TERRITORY PROGRESS BAR (Top Center)
    const barW = 860;
    const barH = 34;
    const barX = (width - barW) / 2;
    const barY = 48;

    // Bar background
    ctx.fillStyle = '#0f172a';
    drawRoundedRect(ctx, barX - 4, barY - 4, barW + 8, barH + 8, 18);
    ctx.fill();
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 3;
    ctx.stroke();

    let curX = barX;
    const totalCells = cols * rows;

    Object.entries(playerIndices).forEach(([pId, idx]) => {
      const p = room.players[pId];
      if (!p) return;
      const pct = (mgData.scores?.[pId] || 0) as number;
      const segW = (pct / 100) * barW;

      if (segW > 2) {
        ctx.fillStyle = p.color || '#3b82f6';
        ctx.fillRect(curX, barY, segW, barH);
        curX += segW;
      }
    });

    // Score Badges flanking the progress bar
    const pEntries = Object.entries(playerIndices);
    pEntries.forEach(([pId, idx], i) => {
      const p = room.players[pId];
      if (!p) return;
      const pct = mgData.scores?.[pId] || 0;
      const badgeX = i === 0 ? barX - 110 : barX + barW + 110;
      const badgeY = barY + barH / 2;

      ctx.save();
      ctx.translate(badgeX, badgeY);
      ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
      drawRoundedRect(ctx, -85, -24, 170, 48, 14);
      ctx.fill();
      ctx.strokeStyle = p.color || '#3b82f6';
      ctx.lineWidth = 3;
      ctx.stroke();

      ctx.font = '22px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(AVATARS[p.avatar]?.emoji || '🎨', -75, 0);

      ctx.font = 'bold 20px monospace';
      ctx.fillStyle = '#ffffff';
      ctx.fillText(`${pct}%`, -38, 0);
      ctx.restore();
    });
  };

  return (
    <div className="relative w-full h-full select-none overflow-hidden bg-slate-950">
      <MinigameCanvas2D
        room={room}
        onRender={handleRender}
        showDevOverlay={true}
        className="w-full h-full"
      />
    </div>
  );
};
