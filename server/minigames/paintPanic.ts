import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import {
  ArenaPlayerSim,
  ArenaBounds,
  updatePlayerMovement,
} from './arenaUtils';

const GRID_SIZE = 14; // 14x14 = 196 cells
const CELL_SIZE = 0.8;
const ARENA_WIDTH = GRID_SIZE * CELL_SIZE; // 11.2

const ARENA_BOUNDS: ArenaBounds = {
  minX: -ARENA_WIDTH / 2,
  maxX: ARENA_WIDTH / 2,
  minZ: -ARENA_WIDTH / 2,
  maxZ: ARENA_WIDTH / 2,
};

export const paintPanicMinigame: MinigameDefinition = {
  id: 'paint-panic',
  name: 'PAINT PANIC',
  description: 'Fesd le a padlót a saját színeddel! Terjeszkedj és színezd át a többiekét!',
  duration: 40,
  instructions: 'MOZGÁS A D-PADDAL! Ahol jársz, felveszi a színedet! A legnagyobb lefedettség nyer!',
  controllerConfig: {
    layout: 'gamepad',
    aHidden: true,
    bHidden: true,
    instructions: 'D-PAD = MOZGÁS',
  },

  setup(room: RoomState) {
    const playersList = Object.values(room.players);
    const total = playersList.length;

    const simPlayers: Record<string, ArenaPlayerSim> = {};
    const scores: Record<string, number> = {};
    const playerIndices: Record<string, number> = {};

    playersList.forEach((p, idx) => {
      const angle = (idx / Math.max(1, total)) * Math.PI * 2;
      simPlayers[p.id] = {
        id: p.id,
        name: p.name,
        color: p.color || '#3b82f6',
        isBot: Boolean(p.isBot),
        x: Math.cos(angle) * 3.5,
        z: Math.sin(angle) * 3.5,
        vx: 0,
        vz: 0,
        facing: 0,
        speed: 5.6,
        radius: 0.5,
        score: 0,
      };
      scores[p.id] = 0;
      playerIndices[p.id] = idx + 1; // 1-indexed (0 = unpainted)
    });

    // 14x14 = 196 cells initialized to 0
    const cells = new Array(GRID_SIZE * GRID_SIZE).fill(0);

    room.activeMinigame!.data = {
      players: simPlayers,
      scores,
      playerIndices,
      gridSize: GRID_SIZE,
      cellSize: CELL_SIZE,
      cells,
    };
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

    const players = Object.values(mgData.players as Record<string, ArenaPlayerSim>);
    const cells: number[] = mgData.cells;
    const playerIndices: Record<string, number> = mgData.playerIndices;

    // 1. Move players & bot AI
    players.forEach(p => {
      let input = p.lastInput;

      if (p.isBot) {
        // Bots pick an unpainted or enemy cell and wander across it
        const botIdx = playerIndices[p.id];
        // Sample random nearby offsets to paint territory
        if (!p.botTargetTimer || p.botTargetTimer <= 0) {
          p.botTargetTimer = 1.0 + Math.random() * 1.5;
          p.botTargetX = (Math.random() - 0.5) * (ARENA_WIDTH - 1.5);
          p.botTargetZ = (Math.random() - 0.5) * (ARENA_WIDTH - 1.5);
        } else {
          p.botTargetTimer -= dt;
        }

        const dx = (p.botTargetX || 0) - p.x;
        const dz = (p.botTargetZ || 0) - p.z;
        input = {
          left: dx < -0.3,
          right: dx > 0.3,
          up: dz < -0.3,
          down: dz > 0.3,
          a: false,
          b: false,
        };
      }

      updatePlayerMovement(p, input, dt, ARENA_BOUNDS);

      // 2. Paint cells under player footprint
      const pIdx = playerIndices[p.id];
      const halfW = ARENA_WIDTH / 2;
      const col = Math.floor((p.x + halfW) / CELL_SIZE);
      const row = Math.floor((p.z + halfW) / CELL_SIZE);

      if (col >= 0 && col < GRID_SIZE && row >= 0 && row < GRID_SIZE) {
        cells[row * GRID_SIZE + col] = pIdx;
      }
    });

    // 3. Tally percentages
    const totalCells = GRID_SIZE * GRID_SIZE;
    const counts: Record<number, number> = {};
    for (let i = 0; i < totalCells; i++) {
      const val = cells[i];
      if (val > 0) counts[val] = (counts[val] || 0) + 1;
    }

    players.forEach(p => {
      const pIdx = playerIndices[p.id];
      const count = counts[pIdx] || 0;
      const pct = Math.round((count / totalCells) * 100);
      p.score = pct;
      mgData.scores[p.id] = pct;
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
