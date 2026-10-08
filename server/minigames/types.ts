import { RoomState, MinigameResultEntry } from '../../shared/types';

export interface MinigameDefinition {
  id: string;
  name: string;
  description: string;
  duration: number; // in seconds
  instructions: string;
  setup: (room: RoomState) => void;
  start: (room: RoomState) => void;
  handleInput: (room: RoomState, playerId: string, data: any) => void;
  update: (room: RoomState, dt: number) => boolean; // return true if game ended early
  calculateResults: (room: RoomState) => MinigameResultEntry[];
  cleanup: (room: RoomState) => void;
}
