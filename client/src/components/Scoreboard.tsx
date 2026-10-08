import React from 'react';
import { Player } from '@shared/types';
import { AvatarBadge } from './AvatarBadge';

interface ScoreboardProps {
  players: Record<string, Player>;
  currentPlayerId?: string;
}

export const Scoreboard: React.FC<ScoreboardProps> = ({ players, currentPlayerId }) => {
  const sortedPlayers = Object.values(players).sort((a, b) => {
    if (b.crowns !== a.crowns) return b.crowns - a.crowns;
    return b.coins - a.coins;
  });

  return (
    <div className="flex flex-col gap-2.5 w-full">
      <div className="flex items-center justify-between px-2 text-xs font-black uppercase tracking-wider text-slate-400">
        <span>Játékosok</span>
        <span>Állás</span>
      </div>
      <div className="flex flex-col gap-2">
        {sortedPlayers.map((player) => (
          <AvatarBadge
            key={player.id}
            player={player}
            size="md"
            isCurrentTurn={player.id === currentPlayerId}
          />
        ))}
      </div>
    </div>
  );
};
