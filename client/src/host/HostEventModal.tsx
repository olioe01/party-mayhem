import React from 'react';
import { ChaosEvent } from '@shared/types';
import { Sparkles } from 'lucide-react';

interface HostEventModalProps {
  activeEvent: {
    event: ChaosEvent;
    details: string;
  } | null;
}

export const HostEventModal: React.FC<HostEventModalProps> = ({ activeEvent }) => {
  if (!activeEvent) return null;

  return (
    <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-xl flex items-center justify-center p-6 z-50 animate-fade-in select-none">
      <div className="bg-gradient-to-b from-purple-900/90 to-slate-900/95 border-4 border-fuchsia-400 p-10 rounded-3xl shadow-2xl max-w-2xl w-full text-center flex flex-col items-center gap-6 animate-bounce">
        <span className="text-7xl">{activeEvent.event.icon}</span>

        <div className="flex items-center gap-2">
          <Sparkles className="w-6 h-6 text-fuchsia-400" />
          <span className="text-xs font-black uppercase tracking-widest text-fuchsia-300">
            VÉLETLEN KÁOSZ ESEMÉNY!
          </span>
        </div>

        <h2 className="text-4xl lg:text-5xl font-black text-white font-heading">
          {activeEvent.event.name}
        </h2>

        <p className="text-xl font-bold text-slate-200">
          {activeEvent.details}
        </p>
      </div>
    </div>
  );
};
