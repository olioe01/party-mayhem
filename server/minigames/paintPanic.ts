import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  Minigame2DPlayer,
  updatePlayerMovement2D,
  generateBotSteering2D,
  distance2D,
} from './sim2dUtils';

export const PAINT_GRID_COLS = 28;
export const PAINT_GRID_ROWS = 16;
export const PAINT_CELL_SIZE = 50;
export const PAINT_GRID_X = 260; // 260 to 1660 = 1400px width
export const PAINT_GRID_Y = 140; // 140 to 940 = 800px height

export const PAINT_BOUNDS = {
  minX: PAINT_GRID_X + 25,
  maxX: PAINT_GRID_X + PAINT_GRID_COLS * PAINT_CELL_SIZE - 25,
  minY: PAINT_GRID_Y + 25,
  maxY: PAINT_GRID_Y + PAINT_GRID_ROWS * PAINT_CELL_SIZE - 25,
};

export const paintPanicMinigame: MinigameDefinition = {
  id: 'paint-panic',
  name: 'PAINT PANIC',
  description: 'Fesd le a padlót a saját színeddel! Minél nagyobb területet fedj le!',
  duration: 35,
  instructions: 'D-PAD = MOZGÁS! Járd be a pályát és színezd át a padlót a legtöbb pontért!',
  status: 'READY',
  controllerConfig: {
    layout: 'gamepad',
    aLabel: '—',
    bLabel: '—',
    aHidden: true,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS • Fesd le a padlót!',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, Minigame2DPlayer> = {};
    const scores: Record<string, number> = {};
    const playerIndices: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const pIdx = idx + 1; // 1-indexed (0 = unpainted)
      playerIndices[p.id] = pIdx;

      let startX = 960;
      let startY = 540;

      if (total > 1) {
        // Spread players across 4 corners / quadrants
        const angle = (idx / total) * Math.PI * 2 + Math.PI / 4;
        startX = 960 + Math.cos(angle) * 450;
        startY = 540 + Math.sin(angle) * 260;
      }

      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: startX,
        y: startY,
        vx: 0,
        vy: 0,
        facing: 0,
        speed: 560,
        radius: 36,
        score: 0,
        isHit: false,
        hitTimer: 0,
      };
      scores[p.id] = 0;
    });

    // 28 * 16 = 448 cells initialized to 0
    const cells = new Array(PAINT_GRID_COLS * PAINT_GRID_ROWS).fill(0);

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      playerIndices,
      gridCols: PAINT_GRID_COLS,
      gridRows: PAINT_GRID_ROWS,
      cellSize: PAINT_CELL_SIZE,
      gridX: PAINT_GRID_X,
      gridY: PAINT_GRID_Y,
      cells,
      botTargets: {} as Record<string, { targetX: number; targetY: number; timer: number }>,
    };

    // Initial paint stamp under players
    claimFootprintCells(room.activeMinigame!.data, simPlayers, cells, playerIndices);
  },

  start(room: RoomState) {},

  handleInput(room: RoomState, playerId: string, data: any) {
    const mgData = room.activeMinigame?.data;
    if (!mgData || !mgData.players || !mgData.players[playerId]) return;
    const sim = mgData.players[playerId];

    if (data && typeof data === 'object') {
      sim.lastInput = {
        up: Boolean(data.up),
        down: Boolean(data.down),
        left: Boolean(data.left),
        right: Boolean(data.right),
        a: Boolean(data.a),
        b: Boolean(data.b),
      };
    }
  },

  update(room: RoomState, dt: number): boolean {
    const mgData = room.activeMinigame?.data;
    if (!mgData) return false;

    const simPlayers = mgData.players as Record<string, Minigame2DPlayer>;
    const cells: number[] = mgData.cells;
    const playerIndices: Record<string, number> = mgData.playerIndices;
    const botTargets = mgData.botTargets || {};

    // 1. Update player movements & bot AI
    Object.values(simPlayers).forEach(sim => {
      let input = sim.lastInput;

      if (sim.isBot) {
        const botIdx = playerIndices[sim.id];
        let target = botTargets[sim.id];

        if (!target || target.timer <= 0 || distance2D(sim.x, sim.y, target.targetX, target.targetY) < 45) {
          // Find unpainted or enemy cells
          const candidateCols: number[] = [];
          const candidateRows: number[] = [];

          for (let r = 0; r < PAINT_GRID_ROWS; r++) {
            for (let c = 0; c < PAINT_GRID_COLS; c++) {
              if (cells[r * PAINT_GRID_COLS + c] !== botIdx) {
                candidateCols.push(c);
                candidateRows.push(r);
              }
            }
          }

          let pickCol = Math.floor(Math.random() * PAINT_GRID_COLS);
          let pickRow = Math.floor(Math.random() * PAINT_GRID_ROWS);
          if (candidateCols.length > 0) {
            const randIdx = Math.floor(Math.random() * candidateCols.length);
            pickCol = candidateCols[randIdx];
            pickRow = candidateRows[randIdx];
          }

          target = {
            targetX: PAINT_GRID_X + pickCol * PAINT_CELL_SIZE + PAINT_CELL_SIZE / 2,
            targetY: PAINT_GRID_Y + pickRow * PAINT_CELL_SIZE + PAINT_CELL_SIZE / 2,
            timer: 1.5 + Math.random() * 2.0,
          };
          botTargets[sim.id] = target;
        } else {
          target.timer -= dt;
        }

        input = generateBotSteering2D(sim, target.targetX, target.targetY);
      }

      updatePlayerMovement2D(sim, input, dt, PAINT_BOUNDS);
    });

    // 2. Claim cells under players footprint
    claimFootprintCells(mgData, simPlayers, cells, playerIndices);

    // 3. Tally territory percentages
    const totalCells = PAINT_GRID_COLS * PAINT_GRID_ROWS;
    const counts: Record<number, number> = {};
    for (let i = 0; i < totalCells; i++) {
      const owner = cells[i];
      if (owner > 0) {
        counts[owner] = (counts[owner] || 0) + 1;
      }
    }

    Object.values(simPlayers).forEach(sim => {
      const pIdx = playerIndices[sim.id];
      const count = counts[pIdx] || 0;
      const pct = Math.round((count / totalCells) * 100);
      sim.score = pct;
      mgData.scores[sim.id] = pct;
    });

    return false;
  },

  calculateResults(room: RoomState): MinigameResultEntry[] {
    const mgData = room.activeMinigame?.data;
    const scores = mgData?.scores || {};
    const results = Object.keys(room.players).map(pId => ({
      playerId: pId,
      score: scores[pId] || 0,
      extraInfo: `${scores[pId] || 0}% lefedettség festékkel`,
    }));

    results.sort((a, b) => b.score - a.score);

    return results.map((entry, index) => {
      let coins = MINIGAME_COIN_REWARDS[index] || 1;
      const player = room.players[entry.playerId];
      if (player?.boostActive) coins = Math.round(coins * 1.5);
      if (player?.trapActive) coins = Math.max(1, coins - 2);

      return {
        playerId: entry.playerId,
        score: entry.score,
        rank: index + 1,
        coinsEarned: coins,
        extraInfo: entry.extraInfo,
      };
    });
  },

  cleanup(room: RoomState) {
    if (room.activeMinigame) {
      room.activeMinigame.data = {};
    }
  },
};

function claimFootprintCells(
  mgData: any,
  simPlayers: Record<string, Minigame2DPlayer>,
  cells: number[],
  playerIndices: Record<string, number>
) {
  Object.values(simPlayers).forEach(sim => {
    const pIdx = playerIndices[sim.id];
    if (!pIdx) return;

    const baseCol = Math.floor((sim.x - PAINT_GRID_X) / PAINT_CELL_SIZE);
    const baseRow = Math.floor((sim.y - PAINT_GRID_Y) / PAINT_CELL_SIZE);

    for (let r = baseRow - 1; r <= baseRow + 1; r++) {
      if (r < 0 || r >= PAINT_GRID_ROWS) continue;
      for (let c = baseCol - 1; c <= baseCol + 1; c++) {
        if (c < 0 || c >= PAINT_GRID_COLS) continue;

        const cx = PAINT_GRID_X + c * PAINT_CELL_SIZE + PAINT_CELL_SIZE / 2;
        const cy = PAINT_GRID_Y + r * PAINT_CELL_SIZE + PAINT_CELL_SIZE / 2;

        if (distance2D(sim.x, sim.y, cx, cy) <= sim.radius + 18) {
          const idx = r * PAINT_GRID_COLS + c;
          cells[idx] = pIdx;
        }
      }
    }
  });
}
