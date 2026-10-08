import React, { useEffect } from 'react';
import { RoomState } from '@shared/types';
import { HostLobby } from './HostLobby';
import { HostBoard } from './HostBoard';
import { HostMinigame } from './HostMinigame';
import { HostBonusCrowns } from './HostBonusCrowns';
import { HostPodium } from './HostPodium';
import { HostEventModal } from './HostEventModal';
import { DevModePanel } from '../components/DevModePanel';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';

interface HostViewProps {
  room: RoomState | null;
  roomCode: string;
}

export const HostView: React.FC<HostViewProps> = ({ room, roomCode }) => {
  useEffect(() => {
    const sendJoinHost = () => {
      socket.emit(SOCKET_EVENTS.JOIN_HOST, { roomCode });
    };

    if (socket.connected) {
      sendJoinHost();
    }
    socket.on('connect', sendJoinHost);

    // Keep retrying every 600ms until room state is received
    const interval = setInterval(() => {
      if (!room) {
        if (!socket.connected) {
          socket.connect();
        } else {
          sendJoinHost();
        }
      }
    }, 600);

    return () => {
      socket.off('connect', sendJoinHost);
      clearInterval(interval);
    };
  }, [roomCode, Boolean(room)]);

  if (!room) {
    return (
      <div className="h-screen w-screen bg-slate-950 text-white flex flex-col items-center justify-center gap-4">
        <div className="w-16 h-16 border-4 border-amber-400 border-t-transparent rounded-full animate-spin" />
        <p className="text-xl font-black text-amber-300 font-heading">
          CSATLAKOZÁS A PARTYHOZ ({roomCode})...
        </p>
      </div>
    );
  }

  return (
    <div className="relative h-screen w-screen overflow-hidden">
      {/* Dev Mode Panel Overlay */}
      <DevModePanel room={room} />

      {/* Global Chaos Event Modal */}
      <HostEventModal activeEvent={room.activeChaosEvent} />

      {/* Routing by Game Phase */}
      {room.phase === 'LOBBY' && <HostLobby room={room} />}

      {(room.phase === 'BOARD_ROLL' ||
        room.phase === 'BOARD_ROLLING' ||
        room.phase === 'BOARD_MOVE' ||
        room.phase === 'BOARD_ACTION' ||
        room.phase === 'SHOP_DECISION') && (
        <HostBoard room={room} />
      )}

      {(room.phase === 'MINIGAME_INTRO' ||
        room.phase === 'MINIGAME_COUNTDOWN' ||
        room.phase === 'MINIGAME_PLAY' ||
        room.phase === 'MINIGAME_RESULTS') && (
        <HostMinigame room={room} />
      )}

      {room.phase === 'BONUS_CROWNS' && <HostBonusCrowns room={room} />}

      {room.phase === 'PODIUM' && <HostPodium room={room} />}
    </div>
  );
};
