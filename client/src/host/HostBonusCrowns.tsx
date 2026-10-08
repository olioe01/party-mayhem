import React, { useEffect } from 'react';
import { RoomState } from '@shared/types';
import { sounds } from '../audio/soundSynth';
import { Crown, Sparkles } from 'lucide-react';

interface HostBonusCrownsProps {
  room: RoomState;
}

export const HostBonusCrowns: React.FC<HostBonusCrownsProps> = ({ room }) => {
  useEffect(() => {
    sounds.playCrown();
  }, []);

  return (
    <div className="h-screen w-screen bg-slate-950 text-white flex flex-col items-center justify-center p-8 select-none relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-b from-amber-600/15 via-purple-900/10 to-slate-950 pointer-events-none" />

      <div className="bg-slate-900/90 border-4 border-amber-400 p-10 lg:p-14 rounded-3xl shadow-2xl max-w-3xl w-full text-center flex flex-col items-center gap-6 backdrop-blur-2xl z-10 animate-fade-in">
        <div className="flex items-center gap-2">
          <Sparkles className="w-8 h-8 text-amber-400" />
          <h1 className="text-4xl lg:text-5xl font-black text-amber-300 font-heading">
            BONUS CROWN DÍJÁTADÓ!
          </h1>
        </div>

        <p className="text-slate-300 text-lg font-bold">
          A játék végi különdíjak átadása a végső eredményhirdetés előtt!
        </p>

        <div className="flex flex-col gap-4 w-full mt-4">
          {room.bonusCrowns.map((award, i) => (
            <div
              key={i}
              className="bg-slate-800/90 border-2 border-amber-400/80 p-5 rounded-2xl flex items-center justify-between shadow-xl animate-bounce"
              style={{ animationDelay: `${i * 0.4}s` }}
            >
              <div className="flex items-center gap-4 text-left">
                <span className="text-4xl">👑</span>
                <div>
                  <span className="text-xs font-black uppercase tracking-wider text-amber-400 block">
                    {award.category} • {award.title}
                  </span>
                  <span className="text-sm text-slate-400 font-semibold block">
                    {award.description}
                  </span>
                </div>
              </div>

              <div className="text-right">
                <span className="text-2xl font-black text-white block">
                  {award.winnerPlayerName}
                </span>
                <span className="text-xs font-black text-amber-300 uppercase tracking-wider">
                  +1 KORONA!
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
