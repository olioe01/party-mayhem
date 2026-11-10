// Szintetizált hangeffektek és háttérzene (WebAudio, külső fájl nélkül)

let ac = null, master = null, musicBus = null, muted = false;
let songName = null, nextNote = 0, step = 0, timer = null;

export function initAudio() {
  if (ac) { ac.resume(); return; }
  ac = new (window.AudioContext || window.webkitAudioContext)();
  master = ac.createGain();
  master.gain.value = 0.6;
  master.connect(ac.destination);
  musicBus = ac.createGain();
  musicBus.gain.value = 0.55;
  musicBus.connect(master);
  if (songName) music(songName);
}

export function toggleMute() {
  muted = !muted;
  if (master) master.gain.value = muted ? 0 : 0.6;
  return muted;
}

const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);

function tone(f, d = 0.12, o = {}) {
  if (!ac) return;
  const { type = 'square', v = 0.15, slide = 0, at = 0, attack = 0.005, dest = master } = o;
  const t = ac.currentTime + at;
  const osc = ac.createOscillator();
  const g = ac.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(f, t);
  if (slide) osc.frequency.exponentialRampToValueAtTime(Math.max(30, f + slide), t + d);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(v, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + d);
  osc.connect(g).connect(dest);
  osc.start(t);
  osc.stop(t + d + 0.03);
}

let noiseBuf = null;
function noise(d = 0.3, o = {}) {
  if (!ac) return;
  const { v = 0.3, at = 0, filter = 1500, dest = master } = o;
  if (!noiseBuf) {
    noiseBuf = ac.createBuffer(1, ac.sampleRate, ac.sampleRate);
    const ch = noiseBuf.getChannelData(0);
    for (let i = 0; i < ch.length; i++) ch[i] = Math.random() * 2 - 1;
  }
  const t = ac.currentTime + at;
  const src = ac.createBufferSource();
  src.buffer = noiseBuf;
  const fl = ac.createBiquadFilter();
  fl.type = 'lowpass';
  fl.frequency.value = filter;
  const g = ac.createGain();
  g.gain.setValueAtTime(v, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + d);
  src.connect(fl).connect(g).connect(dest);
  src.start(t);
  src.stop(t + d + 0.05);
}

const PAD_NOTES = [329.63, 261.63, 392.0, 523.25];

export const sfx = {
  tick: () => tone(880, 0.035, { v: 0.05 }),
  coin: () => { tone(988, 0.07, { v: 0.1 }); tone(1319, 0.2, { v: 0.1, at: 0.07 }); },
  bad: () => { tone(330, 0.3, { type: 'sawtooth', v: 0.1, slide: -170 }); },
  dice: () => { for (let i = 0; i < 4; i++) tone(200 + Math.random() * 500, 0.03, { type: 'triangle', v: 0.1, at: i * 0.03 }); },
  step: () => tone(520, 0.07, { type: 'triangle', v: 0.13, slide: 260 }),
  land: () => tone(200, 0.12, { type: 'triangle', v: 0.25, slide: -80 }),
  hit: () => { tone(150, 0.12, { type: 'triangle', v: 0.3, slide: -60 }); noise(0.08, { v: 0.15, filter: 3000 }); },
  pop: () => tone(620, 0.07, { type: 'sine', v: 0.22, slide: 380 }),
  select: () => tone(660, 0.08, { type: 'triangle', v: 0.15 }),
  count: () => tone(440, 0.18, { type: 'triangle', v: 0.25 }),
  countGo: () => { tone(880, 0.45, { type: 'triangle', v: 0.25 }); tone(1320, 0.45, { type: 'square', v: 0.05 }); },
  go: () => { tone(523, 0.1, { v: 0.12 }); tone(784, 0.25, { v: 0.12, at: 0.1 }); },
  win: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.2, { type: 'triangle', v: 0.2, at: i * 0.1 })),
  lose: () => [392, 349, 311, 262].forEach((f, i) => tone(f, 0.22, { type: 'triangle', v: 0.16, at: i * 0.13 })),
  crown: () => [784, 988, 1175, 1568, 1976].forEach((f, i) => tone(f, 0.28, { v: 0.07, at: i * 0.08 })),
  fanfare: () => [[523, 0], [523, 0.12], [523, 0.24], [659, 0.36], [784, 0.6], [659, 0.78], [784, 0.9]]
    .forEach(([f, at]) => { tone(f, 0.22, { type: 'square', v: 0.08, at }); tone(f / 2, 0.22, { type: 'triangle', v: 0.12, at }); }),
  whoosh: () => noise(0.25, { v: 0.25, filter: 2600 }),
  boom: () => { noise(0.7, { v: 0.5, filter: 700 }); tone(100, 0.45, { type: 'sine', v: 0.45, slide: -60 }); },
  splash: () => noise(0.5, { v: 0.35, filter: 1200 }),
  pad: (i) => tone(PAD_NOTES[i], 0.4, { type: 'triangle', v: 0.25 }),
  padSoft: (i) => tone(PAD_NOTES[i], 0.15, { type: 'sine', v: 0.08 }),
  roll: () => tone(300 + Math.random() * 300, 0.03, { type: 'square', v: 0.04 }),
};

// ---------------------------------------------------------------- zene
const SONGS = {
  lobby: { bpm: 104, prog: [[53, 57, 60], [55, 59, 62], [60, 64, 67], [57, 60, 64]], arp: [0, 1, 2, 1, 2, 1, 0, 1] },
  board: { bpm: 116, prog: [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]], arp: [0, 2, 1, 2, 0, 2, 1, 2] },
  mg: { bpm: 144, prog: [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]], arp: [0, 1, 2, 0, 1, 2, 1, 2] },
  final: { bpm: 96, prog: [[60, 64, 67], [65, 69, 72], [67, 71, 74], [60, 64, 67]], arp: [0, 1, 2, 1, 0, 1, 2, 1] },
};

export function music(name) {
  songName = name;
  if (!ac) return;
  step = 0;
  nextNote = ac.currentTime + 0.1;
  if (!timer) timer = setInterval(schedule, 25);
}

function schedule() {
  const song = SONGS[songName];
  if (!song || !ac) return;
  const spb = 60 / song.bpm / 2; // nyolcadok
  while (nextNote < ac.currentTime + 0.15) {
    const at = Math.max(0, nextNote - ac.currentTime);
    const bar = Math.floor(step / 8) % song.prog.length;
    const chord = song.prog[bar];
    const s = step % 8;
    tone(mtof(chord[song.arp[s]] + 12), spb * 0.9, { type: 'triangle', v: 0.06, at, dest: musicBus });
    if (s % 4 === 0) tone(mtof(chord[0] - 12), spb * 3, { type: 'triangle', v: 0.12, at, dest: musicBus });
    if (s % 4 === 2) tone(mtof(chord[2] - 12), spb * 1.2, { type: 'triangle', v: 0.07, at, dest: musicBus });
    if (s % 2 === 1) noise(0.04, { v: 0.03, at, filter: 8000, dest: musicBus });
    if (s === 0 || s === 4) tone(70, 0.12, { type: 'sine', v: 0.18, slide: -30, at, dest: musicBus });
    nextNote += spb;
    step++;
  }
}
