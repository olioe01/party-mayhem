// Web Audio API Procedural Sound Synthesizer & Ambient Music Manager
// Completely offline, zero external mp3/wav files required!

class SoundSynthesizer {
  private ctx: AudioContext | null = null;
  public isMuted: boolean = false;

  // Master, Music, SFX Gains
  private masterGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private musicGain: GainNode | null = null;

  public masterVolume: number = 0.8;
  public musicVolume: number = 0.22; // Low, gentle ambient background by default
  public sfxVolume: number = 0.75;

  private isMusicPlaying: boolean = false;
  private musicTimer: any = null;
  private musicStep: number = 0;
  private isDucked: boolean = false;

  private initAudio() {
    if (this.ctx) return;
    const AudioCtxClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtxClass) return;

    this.ctx = new AudioCtxClass();

    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.setValueAtTime(this.isMuted ? 0 : this.masterVolume, this.ctx.currentTime);
    this.masterGain.connect(this.ctx.destination);

    this.sfxGain = this.ctx.createGain();
    this.sfxGain.gain.setValueAtTime(this.sfxVolume, this.ctx.currentTime);
    this.sfxGain.connect(this.masterGain);

    this.musicGain = this.ctx.createGain();
    this.musicGain.gain.setValueAtTime(this.musicVolume, this.ctx.currentTime);
    this.musicGain.connect(this.masterGain);
  }

  private getContext(): AudioContext | null {
    if (this.isMuted) return null;
    this.initAudio();
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  public getSfxDestination(): AudioNode | null {
    const ctx = this.getContext();
    if (!ctx || !this.sfxGain) return null;
    return this.sfxGain;
  }

  public setMasterVolume(vol: number) {
    this.masterVolume = Math.max(0, Math.min(1, vol));
    if (this.masterGain && this.ctx) {
      this.masterGain.gain.setValueAtTime(this.isMuted ? 0 : this.masterVolume, this.ctx.currentTime);
    }
  }

  public setMusicVolume(vol: number) {
    this.musicVolume = Math.max(0, Math.min(1, vol));
    if (this.musicGain && this.ctx) {
      const effective = this.isDucked ? this.musicVolume * 0.25 : this.musicVolume;
      this.musicGain.gain.setValueAtTime(effective, this.ctx.currentTime);
    }
  }

  public setSfxVolume(vol: number) {
    this.sfxVolume = Math.max(0, Math.min(1, vol));
    if (this.sfxGain && this.ctx) {
      this.sfxGain.gain.setValueAtTime(this.sfxVolume, this.ctx.currentTime);
    }
  }

  public toggleMute(): boolean {
    this.isMuted = !this.isMuted;
    if (this.masterGain && this.ctx) {
      this.masterGain.gain.setValueAtTime(this.isMuted ? 0 : this.masterVolume, this.ctx.currentTime);
    }
    return this.isMuted;
  }

  // Duck music during minigames or voiceovers
  public setMusicDuck(duck: boolean) {
    this.isDucked = duck;
    if (this.musicGain && this.ctx) {
      const target = duck ? this.musicVolume * 0.25 : this.musicVolume;
      this.musicGain.gain.setTargetAtTime(target, this.ctx.currentTime, 0.4);
    }
  }

  // ----------------------------------------------------
  // Relaxing Ambient Board Background Music Generator
  // Calming, gentle, melodic lo-fi marimba/kalimba chords
  // ----------------------------------------------------
  public startAmbientMusic() {
    if (this.isMusicPlaying) return;
    const ctx = this.getContext();
    if (!ctx) return;

    this.isMusicPlaying = true;
    this.musicStep = 0;

    // Pleasant, sunny party-game chord progression in C major / A minor
    // Chord 1: Cmaj9 (C, G, B, D, E)
    // Chord 2: Fmaj7 (F, A, C, E)
    // Chord 3: Am9 (A, C, E, G, B)
    // Chord 4: Gsus4 -> G (G, C, D -> G, B, D)
    const chords = [
      [261.63, 392.00, 493.88, 587.33, 659.25], // Cmaj9
      [349.23, 440.00, 523.25, 659.25],         // Fmaj7
      [220.00, 329.63, 392.00, 493.88, 523.25], // Am9
      [196.00, 293.66, 392.00, 493.88, 587.33]  // G6
    ];

    const playBar = () => {
      if (!this.isMusicPlaying || this.isMuted) return;
      const nowCtx = this.getContext();
      if (!nowCtx || !this.musicGain) return;

      const chordIdx = Math.floor(this.musicStep / 4) % chords.length;
      const chord = chords[chordIdx];
      const beat = this.musicStep % 4;

      // Soft root note on beat 0
      if (beat === 0) {
        this.playSoftTone(chord[0] * 0.5, 0.08, 1.8, 'triangle');
      }

      // Kalimba / marimba arpeggio notes
      const noteA = chord[(beat * 2) % chord.length];
      const noteB = chord[((beat * 2) + 2) % chord.length];

      this.playSoftTone(noteA, 0.05, 0.9, 'sine');
      setTimeout(() => {
        if (this.isMusicPlaying) {
          this.playSoftTone(noteB, 0.04, 0.7, 'sine');
        }
      }, 350);

      this.musicStep++;
    };

    // Play every 750ms (~80 BPM relaxing swing)
    this.musicTimer = setInterval(playBar, 750);
    playBar();
  }

  private playSoftTone(freq: number, peakVol: number, duration: number, type: OscillatorType = 'sine') {
    if (!this.ctx || !this.musicGain || this.isMuted) return;
    try {
      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = type;
      osc.frequency.setValueAtTime(freq, now);

      // Lowpass filter for warm, round acoustic warmth
      const filter = this.ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(1400, now);

      // Gentle attack and decaying release
      gain.gain.setValueAtTime(0.001, now);
      gain.gain.linearRampToValueAtTime(peakVol, now + 0.06);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(this.musicGain);

      osc.start(now);
      osc.stop(now + duration + 0.1);
    } catch (e) {
      // Audio context state recovery handled silently
    }
  }

  public stopAmbientMusic() {
    this.isMusicPlaying = false;
    if (this.musicTimer) {
      clearInterval(this.musicTimer);
      this.musicTimer = null;
    }
  }

  // ----------------------------------------------------
  // Sound Effects (Routed to sfxGain)
  // ----------------------------------------------------

  // UI Button Click
  playButton() {
    const ctx = this.getContext();
    const dest = this.getSfxDestination();
    if (!ctx || !dest) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(600, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(800, ctx.currentTime + 0.05);
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.05);
    osc.connect(gain);
    gain.connect(dest);
    osc.start();
    osc.stop(ctx.currentTime + 0.05);
  }

  // Coin Sound (Mario style high chime)
  playCoin() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    
    const playTone = (freq: number, start: number, dur: number) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, start);
      gain.gain.setValueAtTime(0.25, start);
      gain.gain.exponentialRampToValueAtTime(0.001, start + dur);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(start);
      osc.stop(start + dur);
    };

    playTone(987.77, now, 0.08); // B5
    playTone(1318.51, now + 0.08, 0.25); // E6
  }

  // Crown (Royal shimmer chord)
  playCrown() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]; // C major chord
    notes.forEach((freq, idx) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, now + idx * 0.06);
      gain.gain.setValueAtTime(0.2, now + idx * 0.06);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.06 + 0.6);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(now + idx * 0.06);
      osc.stop(now + idx * 0.06 + 0.6);
    });
  }

  // Countdown Blip
  playCountdown() {
    const ctx = this.getContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(440, ctx.currentTime);
    gain.gain.setValueAtTime(0.3, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
    osc.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.15);
  }

  // GO! (High chime)
  playGo() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'square';
    osc.frequency.setValueAtTime(880, now);
    osc.frequency.exponentialRampToValueAtTime(1760, now + 0.2);
    gain.gain.setValueAtTime(0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
    osc.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    osc.start(now);
    osc.stop(now + 0.35);
  }

  // Dice roll rattle
  playDice() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    for (let i = 0; i < 6; i++) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(200 + Math.random() * 300, now + i * 0.06);
      gain.gain.setValueAtTime(0.15, now + i * 0.06);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.06 + 0.05);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(now + i * 0.06);
      osc.stop(now + i * 0.06 + 0.05);
    }
  }

  // Bomb Ticking
  playBombTick(rateMultiplier = 1) {
    const ctx = this.getContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(1200 * rateMultiplier, ctx.currentTime);
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.04);
    osc.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.04);
  }

  // Explosion (Low frequency noise rumble)
  playExplosion() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const dur = 1.0;
    const bufferSize = ctx.sampleRate * dur;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      output[i] = Math.random() * 2 - 1;
    }
    const whiteNoise = ctx.createBufferSource();
    whiteNoise.buffer = buffer;

    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(800, now);
    filter.frequency.exponentialRampToValueAtTime(40, now + dur);

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.6, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + dur);

    whiteNoise.connect(filter);
    filter.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    whiteNoise.start(now);
    whiteNoise.stop(now + dur);
  }

  // Teleport (sci-fi warp sweep)
  playTeleport() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(150, now);
    osc.frequency.exponentialRampToValueAtTime(1800, now + 0.3);
    gain.gain.setValueAtTime(0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
    osc.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    osc.start(now);
    osc.stop(now + 0.35);
  }

  // Correct / Ding
  playCorrect() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(587.33, now); // D5
    osc.frequency.setValueAtTime(880, now + 0.1); // A5
    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
    osc.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    osc.start(now);
    osc.stop(now + 0.3);
  }

  // Wrong / Buzzer
  playWrong() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(130, now);
    osc.frequency.setValueAtTime(115, now + 0.1);
    gain.gain.setValueAtTime(0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
    osc.connect(gain);
    gain.connect(this.getSfxDestination() || ctx.destination);
    osc.start(now);
    osc.stop(now + 0.3);
  }

  // Random Event Magical Glissando
  playEvent() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const notes = [440, 554.37, 659.25, 830.61, 987.77, 1318.51];
    notes.forEach((freq, idx) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, now + idx * 0.05);
      gain.gain.setValueAtTime(0.2, now + idx * 0.05);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.05 + 0.4);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(now + idx * 0.05);
      osc.stop(now + idx * 0.05 + 0.4);
    });
  }

  // Victory / Final Fanfare
  playVictory() {
    const ctx = this.getContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const melody = [
      { f: 523.25, t: 0.0, d: 0.15 },
      { f: 523.25, t: 0.16, d: 0.15 },
      { f: 523.25, t: 0.32, d: 0.15 },
      { f: 659.25, t: 0.48, d: 0.4 },
      { f: 587.33, t: 0.90, d: 0.15 },
      { f: 659.25, t: 1.06, d: 0.15 },
      { f: 783.99, t: 1.25, d: 0.7 }
    ];
    melody.forEach(({ f, t, d }) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(f, now + t);
      gain.gain.setValueAtTime(0.35, now + t);
      gain.gain.exponentialRampToValueAtTime(0.001, now + t + d);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(now + t);
      osc.stop(now + t + d);
    });
  }

  // Crash
  playCrash() {
    this.playExplosion();
  }

  // Win minigame
  playWin() {
    this.playVictory();
  }

  // Jump audio (procedural frequency sweep up)
  playJump() {
    const ctx = this.getContext();
    if (!ctx) return;
    try {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      const now = ctx.currentTime;
      osc.frequency.setValueAtTime(160, now);
      osc.frequency.exponentialRampToValueAtTime(520, now + 0.14);
      gain.gain.setValueAtTime(0.22, now);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.14);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(now);
      osc.stop(now + 0.15);
    } catch (_) {}
  }

  // Dash audio (whoosh / burst sound)
  playDash() {
    const ctx = this.getContext();
    if (!ctx) return;
    try {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      const now = ctx.currentTime;
      osc.frequency.setValueAtTime(360, now);
      osc.frequency.exponentialRampToValueAtTime(140, now + 0.13);
      gain.gain.setValueAtTime(0.18, now);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.13);
      osc.connect(gain);
      gain.connect(this.getSfxDestination() || ctx.destination);
      osc.start(now);
      osc.stop(now + 0.14);
    } catch (_) {}
  }
}

export const sounds = new SoundSynthesizer();
