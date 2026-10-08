import React, { useState } from 'react';
import { Volume2, VolumeX, Sliders, Music, Zap, X } from 'lucide-react';
import { sounds } from '../audio/soundSynth';

export const SoundToggle: React.FC = () => {
  const [muted, setMuted] = useState(sounds.isMuted);
  const [showMixer, setShowMixer] = useState(false);
  const [masterVol, setMasterVol] = useState(sounds.masterVolume);
  const [musicVol, setMusicVol] = useState(sounds.musicVolume);
  const [sfxVol, setSfxVol] = useState(sounds.sfxVolume);

  const toggleMute = () => {
    const isMute = sounds.toggleMute();
    setMuted(isMute);
    if (!isMute) {
      sounds.playButton();
    }
  };

  const handleMasterChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = parseFloat(e.target.value);
    setMasterVol(val);
    sounds.setMasterVolume(val);
  };

  const handleMusicChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = parseFloat(e.target.value);
    setMusicVol(val);
    sounds.setMusicVolume(val);
  };

  const handleSfxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = parseFloat(e.target.value);
    setSfxVol(val);
    sounds.setSfxVolume(val);
  };

  return (
    <div className="relative">
      <div className="flex items-center gap-1 bg-slate-800/80 rounded-2xl border border-slate-700 p-1 shadow-md">
        <button
          onClick={toggleMute}
          className="p-1.5 rounded-xl hover:bg-slate-700 text-slate-200 transition-all flex items-center gap-1.5 font-bold text-xs"
          title={muted ? 'Hang bekapcsolása' : 'Némítás'}
        >
          {muted ? <VolumeX className="w-4 h-4 text-red-400" /> : <Volume2 className="w-4 h-4 text-emerald-400" />}
          <span className="hidden sm:inline uppercase text-[10px] tracking-wider">{muted ? 'Néma' : 'Hang'}</span>
        </button>

        <button
          onClick={() => setShowMixer(!showMixer)}
          className={`p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-700 transition ${
            showMixer ? 'bg-slate-700 text-amber-300' : ''
          }`}
          title="Hangerőszabályzó (Mixer)"
        >
          <Sliders className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* Audio Mixer Popover */}
      {showMixer && (
        <div className="absolute top-12 right-0 z-50 w-64 bg-slate-950/95 border border-slate-700 rounded-2xl p-4 shadow-2xl backdrop-blur-md flex flex-col gap-3 animate-in fade-in zoom-in-95 duration-150">
          <div className="flex items-center justify-between border-b border-slate-800 pb-2">
            <span className="text-xs font-black uppercase tracking-wider text-slate-300 font-heading">
              HANGERŐ MIXER
            </span>
            <button
              onClick={() => setShowMixer(false)}
              className="p-1 text-slate-400 hover:text-white rounded-lg hover:bg-slate-800"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Master Volume */}
          <div className="flex flex-col gap-1">
            <div className="flex items-center justify-between text-[11px] font-bold text-slate-300">
              <span className="flex items-center gap-1.5">
                <Volume2 className="w-3.5 h-3.5 text-amber-400" />
                Fő hangerő
              </span>
              <span className="font-mono text-slate-400">{Math.round(masterVol * 100)}%</span>
            </div>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={masterVol}
              onChange={handleMasterChange}
              className="accent-amber-400 cursor-pointer h-1.5 bg-slate-800 rounded-lg"
            />
          </div>

          {/* Music Volume */}
          <div className="flex flex-col gap-1">
            <div className="flex items-center justify-between text-[11px] font-bold text-slate-300">
              <span className="flex items-center gap-1.5">
                <Music className="w-3.5 h-3.5 text-cyan-400" />
                Háttérzene
              </span>
              <span className="font-mono text-slate-400">{Math.round(musicVol * 100)}%</span>
            </div>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={musicVol}
              onChange={handleMusicChange}
              className="accent-cyan-400 cursor-pointer h-1.5 bg-slate-800 rounded-lg"
            />
          </div>

          {/* SFX Volume */}
          <div className="flex flex-col gap-1">
            <div className="flex items-center justify-between text-[11px] font-bold text-slate-300">
              <span className="flex items-center gap-1.5">
                <Zap className="w-3.5 h-3.5 text-pink-400" />
                Hanghatások
              </span>
              <span className="font-mono text-slate-400">{Math.round(sfxVol * 100)}%</span>
            </div>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={sfxVol}
              onChange={handleSfxChange}
              className="accent-pink-400 cursor-pointer h-1.5 bg-slate-800 rounded-lg"
            />
          </div>
        </div>
      )}
    </div>
  );
};
