import React, { useState, useEffect, useCallback } from 'react';
import { RoomState, AvatarId, Player } from '@shared/types';
import { PlayerJoin } from './PlayerJoin';
import { PlayerLobby } from './PlayerLobby';
import { PlayerBoardControls } from './PlayerBoardControls';
import { PlayerMinigame } from './PlayerMinigame';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { sounds } from '../audio/soundSynth';
import { Trophy, WifiOff, Sparkles, RefreshCw } from 'lucide-react';

interface PlayerViewProps {
  room: RoomState | null;
  defaultRoomCode?: string;
}

export const PlayerView: React.FC<PlayerViewProps> = ({ room, defaultRoomCode = '4827' }) => {
  const [localPlayerId, setLocalPlayerId] = useState<string | null>(
    localStorage.getItem('partyMayhemPlayerId')
  );
  const [welcomeBackName, setWelcomeBackName] = useState<string | null>(null);
  const [isReconnecting, setIsReconnecting] = useState(false);

  // Request wake lock on mobile to keep screen awake during party game
  const requestWakeLock = useCallback(async () => {
    if ('wakeLock' in navigator) {
      try {
        await (navigator as any).wakeLock.request('screen');
      } catch (e) {
        // Ignored safely
      }
    }
  }, []);

  // Find local player object in current room state
  const localPlayer: Player | null = room && localPlayerId
    ? room.players[localPlayerId] ||
      Object.values(room.players).find(
        p => p.playerToken === localStorage.getItem('partyMayhemPlayerToken')
      ) ||
      null
    : null;

  // Handle successful join / reconnect
  const triggerReconnect = useCallback(() => {
    const token = localStorage.getItem('partyMayhemPlayerToken');
    const roomCode = localStorage.getItem('partyMayhemRoomCode') || defaultRoomCode;
    if (token && roomCode) {
      setIsReconnecting(true);
      if (!socket.connected) {
        socket.connect();
      }
      socket.emit(SOCKET_EVENTS.RECONNECT_PLAYER, {
        roomCode,
        playerToken: token
      });
    }
  }, [defaultRoomCode]);

  useEffect(() => {
    requestWakeLock();

    // Reconnection triggers: 1) Initial mount if token exists
    triggerReconnect();

    // 2) Page visibility change (when returning from Messenger, WhatsApp, Safari background)
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        requestWakeLock();
        triggerReconnect();
      }
    };

    // 3) Network online event
    const handleOnline = () => {
      triggerReconnect();
    };

    // Socket response listeners
    const handleJoinSuccess = (data: { playerId: string; playerToken: string; roomCode: string; isReconnect: boolean }) => {
      setLocalPlayerId(data.playerId);
      localStorage.setItem('partyMayhemPlayerId', data.playerId);
      localStorage.setItem('partyMayhemPlayerToken', data.playerToken);
      localStorage.setItem('partyMayhemRoomCode', data.roomCode);
      setIsReconnecting(false);
    };

    const handleReconnectSuccess = (data: { player: Player; room: RoomState }) => {
      setLocalPlayerId(data.player.id);
      localStorage.setItem('partyMayhemPlayerId', data.player.id);
      localStorage.setItem('partyMayhemPlayerToken', data.player.playerToken);
      setIsReconnecting(false);
      setWelcomeBackName(data.player.name);
      sounds.playGo();
      setTimeout(() => setWelcomeBackName(null), 3000);
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('online', handleOnline);
    socket.on(SOCKET_EVENTS.PLAYER_JOIN_SUCCESS, handleJoinSuccess);
    socket.on(SOCKET_EVENTS.PLAYER_RECONNECT_SUCCESS, handleReconnectSuccess);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('online', handleOnline);
      socket.off(SOCKET_EVENTS.PLAYER_JOIN_SUCCESS, handleJoinSuccess);
      socket.off(SOCKET_EVENTS.PLAYER_RECONNECT_SUCCESS, handleReconnectSuccess);
    };
  }, [triggerReconnect, requestWakeLock]);

  if (!localPlayer) {
    return (
      <PlayerJoin
        defaultRoomCode={defaultRoomCode}
        onJoined={(name, avatar, cosmetic) => {
          // Handled via PLAYER_JOIN_SUCCESS socket event
        }}
      />
    );
  }

  return (
    <div className="relative min-h-screen">
      {/* Welcome Back Overlay */}
      {welcomeBackName && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50 bg-gradient-to-r from-amber-400 to-pink-500 text-slate-950 font-black px-6 py-3 rounded-2xl shadow-2xl flex items-center gap-2 text-sm animate-bounce border-2 border-white">
          <Sparkles className="w-5 h-5" />
          <span>WELCOME BACK, {welcomeBackName.toUpperCase()}! 👋</span>
        </div>
      )}

      {/* Disconnected / Reconnecting banner on phone */}
      {(!socket.connected || !localPlayer.connected) && (
        <div className="fixed top-0 inset-x-0 z-40 bg-red-600/95 text-white text-xs font-black py-2 px-4 text-center flex items-center justify-center gap-2 shadow-lg">
          <WifiOff className="w-4 h-4 animate-pulse" />
          <span>Kapcsolat megszakadt. Újracsatlakozás folyamatban...</span>
          <button
            onClick={triggerReconnect}
            className="underline ml-2 bg-red-700 px-2 py-0.5 rounded text-[10px]"
          >
            Újrapróbálás
          </button>
        </div>
      )}

      {/* 1. LOBBY */}
      {room!.phase === 'LOBBY' && (
        <PlayerLobby player={localPlayer} roomCode={room!.roomCode} />
      )}

      {/* 2. BOARD PHASES */}
      {(room!.phase === 'BOARD_ROLL' ||
        room!.phase === 'BOARD_ROLLING' ||
        room!.phase === 'BOARD_MOVE' ||
        room!.phase === 'BOARD_ACTION' ||
        room!.phase === 'SHOP_DECISION' ||
        room!.phase === 'ROUND_SUMMARY') && (
        <PlayerBoardControls room={room!} player={localPlayer} />
      )}

      {/* 3. MINIGAME PHASES */}
      {(room!.phase === 'MINIGAME_INTRO' ||
        room!.phase === 'MINIGAME_COUNTDOWN' ||
        room!.phase === 'MINIGAME_PLAY' ||
        room!.phase === 'MINIGAME_RESULTS') && (
        <PlayerMinigame room={room!} player={localPlayer} />
      )}

      {/* 4. FINALE / PODIUM */}
      {(room!.phase === 'BONUS_CROWNS' || room!.phase === 'PODIUM') && (
        <div className="min-h-screen bg-slate-950 text-white flex flex-col items-center justify-center p-6 text-center gap-6 select-none">
          <Trophy className="w-20 h-20 text-amber-400 animate-bounce" />
          <div>
            <h2 className="text-3xl font-black text-amber-300 font-heading">
              VÉGSŐ EREDMÉNYHIRDETÉS!
            </h2>
            <p className="text-slate-300 text-sm font-bold mt-2">
              Nézz a TV képernyőjére a győztes és a dobogósok kihirdetéséhez!
            </p>
          </div>
          <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl max-w-xs text-xs font-mono text-slate-400">
            PARTY MAYHEM • KÖSZÖNJÜK A JÁTÉKOT!
          </div>
        </div>
      )}
    </div>
  );
};
