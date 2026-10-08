import React from 'react';
import { Player, AvatarId } from '@shared/types';
import { AVATARS } from '@shared/constants';

interface AvatarBadgeProps {
  player: Player;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  showStats?: boolean;
  isCurrentTurn?: boolean;
}

export const AvatarBadge: React.FC<AvatarBadgeProps> = ({
  player,
  size = 'md',
  showStats = true,
  isCurrentTurn = false
}) => {
  const avatarInfo = AVATARS[player.avatar] || AVATARS['fox'];

  const sizeClasses = {
    sm: 'w-10 h-10 text-xl',
    md: 'w-14 h-14 text-3xl',
    lg: 'w-20 h-20 text-5xl',
    xl: 'w-28 h-28 text-6xl'
  }[size];

  return (
    <div className={`flex items-center gap-3 p-2 rounded-2xl transition-all duration-300 ${
      isCurrentTurn ? 'ring-4 ring-amber-400 bg-amber-500/20 shadow-lg scale-105' : 'bg-slate-800/60'
    }`}>
      {/* Avatar Icon */}
      <div
        className={`${sizeClasses} rounded-2xl flex items-center justify-center font-bold shadow-md relative shrink-0`}
        style={{ backgroundColor: avatarInfo.color + '33', border: `3px solid ${avatarInfo.color}` }}
      >
        <span>{avatarInfo.emoji}</span>
        {player.isBot && (
          <span className="absolute -top-1 -right-1 bg-slate-700 text-[10px] px-1.5 py-0.5 rounded-full border border-slate-500 text-white font-mono">
            BOT
          </span>
        )}
      </div>

      {/* Info & Stats */}
      {showStats && (
        <div className="flex flex-col min-w-0 pr-2">
          <div className="flex items-center gap-1.5 truncate">
            <span className="font-extrabold text-slate-100 truncate text-base">{player.name}</span>
            <span className="text-[11px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider" style={{ backgroundColor: avatarInfo.color + '44', color: avatarInfo.color }}>
              #{player.currentRank}
            </span>
          </div>

          <div className="flex items-center gap-3 mt-0.5 text-sm font-black">
            <span className="flex items-center gap-1 text-amber-400" title="Koronák">
              👑 {player.crowns}
            </span>
            <span className="flex items-center gap-1 text-yellow-300" title="Érmék">
              🪙 {player.coins}
            </span>
          </div>
        </div>
      )}
    </div>
  );
};
