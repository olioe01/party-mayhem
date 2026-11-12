// Party Mayhem – saját zenék renderelése (szintetizátor + szekvenszer, külső hangminta nélkül).
// Használat: node tools/make_music.mjs  ->  music/*.wav (44,1 kHz, 16 bit, sztereó)
// Minden dallam és akkordmenet saját szerzemény.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SR = 44100;
const OUT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'music');
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- alapok
const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);
const NOTE = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
function midi(tok) {
  const m = /^([A-G])(#|b)?(-?\d)$/.exec(tok);
  if (!m) throw new Error(`rossz hang: ${tok}`);
  return 12 * (Number(m[3]) + 1) + NOTE[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
}
function chordNotes(name) {
  const m = /^([A-G])(#|b)?(m)?(7)?/.exec(name);
  const root = NOTE[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
  const third = m[3] ? 3 : 4;
  const notes = [root, root + third, root + 7];
  if (m[4]) notes.push(root + 10);
  return notes;
}
let seed = 12345;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

class Track {
  constructor(seconds) {
    this.n = Math.ceil(seconds * SR) + SR * 3;
    this.L = new Float32Array(this.n);
    this.R = new Float32Array(this.n);
    this.verbL = new Float32Array(this.n);
    this.verbR = new Float32Array(this.n);
  }
  add(i, v, pan = 0, verb = 0.15) {
    if (i < 0 || i >= this.n) return;
    const l = Math.cos((pan + 1) * Math.PI / 4), r = Math.sin((pan + 1) * Math.PI / 4);
    this.L[i] += v * l; this.R[i] += v * r;
    this.verbL[i] += v * l * verb; this.verbR[i] += v * r * verb;
  }
}

function adsr(t, dur, a, d, s, r) {
  if (t < a) return t / a;
  if (t < a + d) return 1 - (1 - s) * ((t - a) / d);
  if (t < dur) return s;
  const k = (t - dur) / r;
  return k < 1 ? s * (1 - k) : 0;
}

// ---------------------------------------------------------------- hangszerek
const INST = {
  // kicsit lebegő négyszög-dallam vibratóval
  lead(tr, t0, f, dur, v, o = {}) {
    const rel = 0.08, len = dur + rel, start = Math.floor(t0 * SR);
    let ph = 0, ph2 = 0, lp = 0;
    const duty = o.duty ?? 0.3;
    for (let i = 0; i < len * SR; i++) {
      const t = i / SR;
      const vib = t > 0.12 ? Math.sin(t * 2 * Math.PI * 5.5) * 0.006 * Math.min(1, (t - 0.12) * 4) : 0;
      ph = (ph + f * (1 + vib) / SR) % 1;
      ph2 = (ph2 + f * 1.004 * (1 + vib) / SR) % 1;
      let s = (ph < duty ? 1 : -1) * 0.6 + (2 * ph2 - 1) * 0.35;
      lp += (s - lp) * 0.32;
      const e = adsr(t, dur, 0.008, 0.12, 0.72, rel);
      tr.add(start + i, lp * e * v, o.pan ?? 0, o.verb ?? 0.22);
    }
  },
  // pengetős (Karplus–Strong)
  pluck(tr, t0, f, dur, v, o = {}) {
    const N = Math.max(2, Math.round(SR / f));
    const buf = new Float32Array(N);
    for (let i = 0; i < N; i++) buf[i] = rnd() * 2 - 1;
    const len = Math.min(dur + 0.4, 2.0), start = Math.floor(t0 * SR);
    let idx = 0, prev = 0;
    const damp = o.damp ?? 0.996;
    for (let i = 0; i < len * SR; i++) {
      const cur = buf[idx];
      const nxt = (cur + prev) * 0.5 * damp;
      prev = cur;
      buf[idx] = nxt;
      idx = (idx + 1) % N;
      const t = i / SR;
      const e = t > dur ? Math.max(0, 1 - (t - dur) / 0.08) : 1;
      tr.add(start + i, cur * v * e, o.pan ?? 0, o.verb ?? 0.18);
    }
  },
  // csengő / glockenspiel
  bell(tr, t0, f, dur, v, o = {}) {
    const len = Math.max(dur, 1.2), start = Math.floor(t0 * SR);
    const parts = [[1, 1, 2.2], [2.76, 0.4, 4], [5.4, 0.18, 7], [8.93, 0.08, 10]];
    for (let i = 0; i < len * SR; i++) {
      const t = i / SR;
      let s = 0;
      for (const [m, a, d] of parts) s += Math.sin(2 * Math.PI * f * m * t) * a * Math.exp(-t * d);
      tr.add(start + i, s * v * Math.min(1, t / 0.002), o.pan ?? 0, o.verb ?? 0.35);
    }
  },
  // basszus: háromszög + szinusz alhang, enyhe ütés
  bass(tr, t0, f, dur, v, o = {}) {
    const rel = 0.05, start = Math.floor(t0 * SR);
    let ph = 0;
    for (let i = 0; i < (dur + rel) * SR; i++) {
      const t = i / SR;
      ph = (ph + f / SR) % 1;
      const tri = 4 * Math.abs(ph - 0.5) - 1;
      const s = tri * 0.7 + Math.sin(2 * Math.PI * ph) * 0.5 + (ph < 0.5 ? 0.12 : -0.12);
      const e = adsr(t, dur, 0.004, 0.15, 0.6, rel);
      tr.add(start + i, s * e * v, 0, 0.02);
    }
  },
  // pad: elhangolt fűrészek, szűrve, lassú felfutás
  pad(tr, t0, f, dur, v, o = {}) {
    const rel = 0.5, start = Math.floor(t0 * SR);
    const det = [0.994, 1, 1.006];
    const ph = [rnd(), rnd(), rnd()];
    let lp = 0, lp2 = 0;
    for (let i = 0; i < (dur + rel) * SR; i++) {
      const t = i / SR;
      let s = 0;
      for (let k = 0; k < 3; k++) { ph[k] = (ph[k] + f * det[k] / SR) % 1; s += 2 * ph[k] - 1; }
      lp += (s / 3 - lp) * 0.06;
      lp2 += (lp - lp2) * 0.06;
      const e = adsr(t, dur, o.attack ?? 0.25, 0.3, 0.8, rel);
      tr.add(start + i, lp2 * e * v, o.pan ?? 0, o.verb ?? 0.4);
    }
  },
  // rézfúvós jellegű: fűrész szűrő-burkolóval
  brass(tr, t0, f, dur, v, o = {}) {
    const rel = 0.12, start = Math.floor(t0 * SR);
    let ph = 0, ph2 = 0, lp = 0;
    for (let i = 0; i < (dur + rel) * SR; i++) {
      const t = i / SR;
      const vib = t > 0.2 ? Math.sin(t * 2 * Math.PI * 5) * 0.004 : 0;
      ph = (ph + f * (1 + vib) / SR) % 1;
      ph2 = (ph2 + f * 1.003 / SR) % 1;
      const s = (2 * ph - 1) * 0.6 + (2 * ph2 - 1) * 0.4;
      const cut = 0.05 + 0.25 * Math.exp(-t * 6) + 0.08;
      lp += (s - lp) * cut;
      const e = adsr(t, dur, 0.03, 0.2, 0.75, rel);
      tr.add(start + i, lp * e * v, o.pan ?? 0, o.verb ?? 0.3);
    }
  },
  kick(tr, t0, v = 1) {
    const start = Math.floor(t0 * SR);
    let ph = 0;
    for (let i = 0; i < 0.3 * SR; i++) {
      const t = i / SR;
      const f = 45 + 110 * Math.exp(-t * 28);
      ph += f / SR;
      tr.add(start + i, Math.sin(2 * Math.PI * ph) * Math.exp(-t * 9) * v * 0.95, 0, 0.02);
    }
  },
  snare(tr, t0, v = 1) {
    const start = Math.floor(t0 * SR);
    let hp = 0, prev = 0;
    for (let i = 0; i < 0.22 * SR; i++) {
      const t = i / SR;
      const n = rnd() * 2 - 1;
      hp = 0.85 * (hp + n - prev); prev = n;
      const tone = Math.sin(2 * Math.PI * 185 * t) * Math.exp(-t * 25);
      tr.add(start + i, (hp * 0.5 * Math.exp(-t * 16) + tone * 0.5) * v * 0.55, 0.05, 0.2);
    }
  },
  hat(tr, t0, v = 1, open = false) {
    const start = Math.floor(t0 * SR);
    let hp = 0, prev = 0;
    const len = open ? 0.2 : 0.05;
    for (let i = 0; i < len * SR; i++) {
      const t = i / SR;
      const n = rnd() * 2 - 1;
      hp = 0.6 * (hp + n - prev); prev = n;
      tr.add(start + i, hp * Math.exp(-t * (open ? 14 : 70)) * v * 0.22, 0.3, 0.05);
    }
  },
  clap(tr, t0, v = 1) {
    for (const off of [0, 0.011, 0.022]) {
      const start = Math.floor((t0 + off) * SR);
      let hp = 0, prev = 0;
      for (let i = 0; i < 0.12 * SR; i++) {
        const t = i / SR;
        const n = rnd() * 2 - 1;
        hp = 0.75 * (hp + n - prev); prev = n;
        tr.add(start + i, hp * Math.exp(-t * 30) * v * 0.22, -0.1, 0.25);
      }
    }
  },
  tom(tr, t0, f = 120, v = 1) {
    const start = Math.floor(t0 * SR);
    let ph = 0;
    for (let i = 0; i < 0.35 * SR; i++) {
      const t = i / SR;
      ph += (f * (1 + 0.5 * Math.exp(-t * 20))) / SR;
      tr.add(start + i, Math.sin(2 * Math.PI * ph) * Math.exp(-t * 8) * v * 0.6, -0.2, 0.25);
    }
  },
};

// ---------------------------------------------------------------- effektek
function reverb(tr) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491];
  const aps = [556, 441, 341];
  const out = [new Float32Array(tr.n), new Float32Array(tr.n)];
  [tr.verbL, tr.verbR].forEach((src, ch) => {
    const spread = ch ? 23 : 0;
    const acc = out[ch];
    for (const c of combs) {
      const d = c + spread, buf = new Float32Array(d);
      let idx = 0, lp = 0;
      for (let i = 0; i < tr.n; i++) {
        const y = buf[idx];
        lp = y * 0.7 + lp * 0.3;
        buf[idx] = src[i] + lp * 0.8;
        idx = (idx + 1) % d;
        acc[i] += y / combs.length;
      }
    }
    for (const a of aps) {
      const d = a + spread, buf = new Float32Array(d);
      let idx = 0;
      for (let i = 0; i < tr.n; i++) {
        const b = buf[idx];
        const y = -acc[i] + b;
        buf[idx] = acc[i] + b * 0.5;
        idx = (idx + 1) % d;
        acc[i] = y;
      }
    }
  });
  for (let i = 0; i < tr.n; i++) { tr.L[i] += out[0][i] * 0.9; tr.R[i] += out[1][i] * 0.9; }
}

function writeWav(file, L, R, from, to) {
  const n = to - from;
  let peak = 0;
  for (let i = from; i < to; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  const gain = peak > 0 ? 0.89 / Math.max(peak, 0.89) : 1;
  const buf = Buffer.alloc(44 + n * 4);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 4, 4); buf.write('WAVE', 8);
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(n * 4, 40);
  const sat = (x) => Math.tanh(x * gain * 1.1) / Math.tanh(1.1);
  for (let i = 0; i < n; i++) {
    buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sat(L[from + i]))) * 32767), 44 + i * 4);
    buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sat(R[from + i]))) * 32767), 46 + i * 4);
  }
  fs.writeFileSync(path.join(OUT, file), buf);
  console.log(`${file}: ${(n / SR).toFixed(1)} mp`);
}

// ---------------------------------------------------------------- szekvenszer
// mel: ütemek '|'-vel, ütemenként 8 nyolcad. Hang (C5), '-' kitartás, '.' szünet.
function parseMel(str) {
  const steps = [];
  for (const bar of str.trim().split('|')) {
    const toks = bar.trim().split(/\s+/);
    if (toks.length !== 8) throw new Error(`az ütemben nem 8 nyolcad van: "${bar}"`);
    steps.push(...toks);
  }
  const notes = [];
  for (let i = 0; i < steps.length; i++) {
    const s = steps[i];
    if (s === '-' || s === '.') continue;
    let len = 1;
    while (i + len < steps.length && steps[i + len] === '-') len++;
    notes.push({ step: i, len, m: midi(s) });
  }
  return { notes, steps: steps.length };
}

const DRUMS = {
  // 16 lépés / ütem: k=lábdob, s=pergő, h=cin, o=nyitott cin, c=taps, t=tam
  pop: { k: 'x.......x.x.....', s: '....x.......x...', h: 'x.x.x.x.x.x.x.x.' },
  bounce: { k: 'x.....x.x.......', s: '....x.......x..x', h: '..x...x...x...x.', c: '............x...' },
  soft: { k: 'x.......x.......', s: '....x.......x...', h: 'x...x...x...x...' },
  drive: { k: 'x...x...x...x...', s: '....x.......x...', h: 'xxxxxxxxxxxxxxxx', o: '..x...x...x...x.' },
  tense: { k: 'x..x..x...x..x..', s: '....x.......x...', h: 'x.x.x.x.x.x.x.x.', t: '..............xx' },
  march: { k: 'x.......x.......', s: '....x..x....x.xx', h: 'x.x.x.x.x.x.x.x.' },
  anthem: { k: 'x.......x.......', s: '....x.......x...', h: '..x...x...x...x.', t: '............x.x.' },
};

function render(song) {
  const spb = 60 / song.bpm;          // negyed
  const bar = spb * 4;
  const mel = parseMel(song.mel);
  const bars = mel.steps / 8;
  if (song.chords.length !== bars) throw new Error(`${song.name}: ${song.chords.length} akkord, ${bars} ütem`);
  const loopLen = bars * bar;
  const tr = new Track(loopLen * 2 + 1);
  const swing = song.swing ?? 0;
  const stepT = (k) => (k * spb / 2) + ((k % 2) ? swing * spb / 2 : 0);   // nyolcad + swing
  const s16 = (k) => (k * spb / 4) + ((k % 2) ? swing * spb / 4 : 0);
  for (let pass = 0; pass < 2; pass++) {
    const off = pass * loopLen;
    // dallam
    for (const n of mel.notes) {
      const t0 = off + stepT(n.step);
      const dur = n.len * spb / 2 * 0.92;
      const f = mtof(n.m + (song.melShift ?? 0));
      INST[song.lead](tr, t0, f, dur, song.leadVol ?? 0.2, { pan: 0.05 });
      if (song.double) INST[song.double](tr, t0, f * 2, dur, (song.leadVol ?? 0.2) * 0.35, { pan: -0.3 });
    }
    // kíséret + basszus
    song.chords.forEach((ch, b) => {
      const t0 = off + b * bar;
      const notes = chordNotes(ch);
      const root = notes[0];
      const bassM = 36 + root;              // C2 körül
      const compBase = 60;                  // C4 körül
      const ch3 = notes.map((x) => compBase + ((x + 12 - (compBase % 12)) % 12) - (x % 12 > 7 ? 12 : 0));
      ch3.sort((a, c) => a - c);
      switch (song.bass) {
        case 'roots':
          [0, 2].forEach((q) => INST.bass(tr, t0 + q * spb, mtof(bassM + (q === 2 ? 7 : 0)), spb * 1.6, 0.42));
          break;
        case 'bounce':
          [[0, 0], [1.5, 7], [2, 12], [3, 7]].forEach(([q, iv]) => INST.bass(tr, t0 + q * spb, mtof(bassM + iv), spb * 0.45, 0.42));
          break;
        case 'eighths':
          for (let k = 0; k < 8; k++) INST.bass(tr, t0 + k * spb / 2, mtof(bassM + (k === 6 ? 7 : k === 7 ? 12 : 0)), spb * 0.4, 0.38);
          break;
        case 'walk': {
          const ivs = [0, notes[1] - notes[0], 7, 12];
          ivs.forEach((iv, q) => INST.bass(tr, t0 + q * spb, mtof(bassM + iv), spb * 0.85, 0.4));
          break;
        }
        default:
      }
      switch (song.comp) {
        case 'arp': {
          const seq = [0, 1, 2, 1, 0, 2, 1, 2];
          for (let k = 0; k < 8; k++) INST.pluck(tr, t0 + stepT(k), mtof(ch3[seq[k]] + 12), spb * 0.5, 0.2, { pan: -0.35 });
          break;
        }
        case 'offbeat':
          for (let q = 0; q < 4; q++) ch3.forEach((m, i) => INST.pluck(tr, t0 + q * spb + spb / 2, mtof(m + 12), spb * 0.3, 0.12, { pan: 0.3 - i * 0.2, damp: 0.99 }));
          break;
        case 'pad':
          ch3.forEach((m, i) => INST.pad(tr, t0, mtof(m), bar * 0.98, 0.07, { pan: -0.4 + i * 0.4 }));
          break;
        case 'padarp':
          ch3.forEach((m, i) => INST.pad(tr, t0, mtof(m), bar * 0.98, 0.05, { pan: -0.4 + i * 0.4 }));
          for (let k = 0; k < 16; k += 2) INST.pluck(tr, t0 + s16(k), mtof(ch3[(k / 2) % 3] + 24), spb * 0.25, 0.1, { pan: 0.4 });
          break;
        case 'brass':
          ch3.forEach((m, i) => INST.pad(tr, t0, mtof(m), bar * 0.98, 0.07, { pan: -0.4 + i * 0.4, attack: 0.08 }));
          ch3.forEach((m, i) => INST.brass(tr, t0, mtof(m), spb * 0.9, 0.05, { pan: -0.3 + i * 0.3 }));
          ch3.forEach((m, i) => INST.brass(tr, t0 + spb * 2.5, mtof(m), spb * 1.3, 0.045, { pan: -0.3 + i * 0.3 }));
          break;
        default:
      }
      if (song.bells && b % 2 === 1) INST.bell(tr, t0 + spb * 3.5, mtof(ch3[2] + 24), spb, 0.05, { pan: 0.5 });
      // dob
      const d = DRUMS[song.drums];
      if (d) {
        for (let k = 0; k < 16; k++) {
          const t = t0 + s16(k);
          if (d.k?.[k] === 'x') INST.kick(tr, t, 0.95);
          if (d.s?.[k] === 'x') INST.snare(tr, t, k % 4 === 0 ? 0.9 : 0.5);
          if (d.h?.[k] === 'x') INST.hat(tr, t, k % 2 ? 0.7 : 1);
          if (d.o?.[k] === 'x') INST.hat(tr, t, 0.7, true);
          if (d.c?.[k] === 'x') INST.clap(tr, t, 0.9);
          if (d.t?.[k] === 'x') INST.tom(tr, t, k % 2 ? 100 : 130, 0.8);
        }
        // ütemváltó tölteléks az utolsó ütemben
        if (b === bars - 1 && song.fill) for (let k = 12; k < 16; k++) INST.snare(tr, t0 + s16(k), 0.35 + (k - 12) * 0.15);
      }
    });
  }
  reverb(tr);
  // a második menetet vágjuk ki: így a zengés átér a hurok elejére, és varrat nélkül ismétlődik
  const from = Math.round(loopLen * SR);
  writeWav(`${song.name}.wav`, tr.L, tr.R, from, from + Math.round(loopLen * SR));
}

function jingle(name, bpm, events, tail = 1.5) {
  const spb = 60 / bpm;
  let end = 0;
  for (const e of events) end = Math.max(end, (e[1] + (e[2] ?? 0.5)) * spb);
  const tr = new Track(end + tail);
  for (const [inst, at, len, notes, vol] of events) {
    for (const n of [].concat(notes)) {
      if (inst === 'kick' || inst === 'snare' || inst === 'clap' || inst === 'tom') INST[inst](tr, at * spb, vol ?? 1);
      else INST[inst](tr, at * spb, mtof(midi(n)), len * spb, vol ?? 0.15);
    }
  }
  reverb(tr);
  writeWav(`${name}.wav`, tr.L, tr.R, 0, Math.round((end + tail) * SR));
}

// ---------------------------------------------------------------- dalok
const SONGS = [
  {
    name: 'board', bpm: 118, lead: 'lead', double: 'bell', leadVol: 0.17, bass: 'bounce', comp: 'offbeat', drums: 'bounce', fill: true,
    chords: ['C', 'G', 'Am', 'F', 'C', 'G', 'F', 'G', 'F', 'G', 'Em', 'Am', 'Dm', 'G', 'C', 'C'],
    mel: `C5 E5 G5 - E5 - C5 - | D5 - B4 - G4 - . . | A4 C5 E5 - A5 - G5 E5 | F5 - - - . . E5 F5 |
          G5 - E5 - C6 - B5 A5 | G5 - D5 - B4 - D5 F5 | A5 - G5 F5 E5 - D5 C5 | D5 - - - . . . . |
          A5 - C6 - A5 - F5 - | G5 - B5 - G5 - D5 - | E5 G5 B5 - G5 - E5 - | A5 - - - G5 F5 E5 D5 |
          F5 - E5 - D5 - A4 - | B4 - D5 - G5 - F5 - | E5 - G5 - C6 - - - | . . G5 F5 E5 D5 C5 B4`,
  },
  {
    name: 'lobby', bpm: 100, swing: 0.32, lead: 'bell', leadVol: 0.2, bass: 'walk', comp: 'arp', drums: 'soft',
    chords: ['F', 'Dm', 'Bb', 'C', 'F', 'Dm', 'Gm', 'C', 'Bb', 'C', 'Am', 'Dm', 'Gm', 'C', 'F', 'F'],
    mel: `A5 - - C6 - - A5 - | F5 - - - D5 - - - | D5 - F5 - Bb5 - A5 - | G5 - - - - - . . |
          A5 - - C6 - - F6 - | E6 - D6 - A5 - - - | Bb5 - A5 - G5 - D5 - | E5 - - - - - . . |
          F5 - D5 - F5 - Bb5 - | A5 - G5 - E5 - C5 - | E5 - A5 - C6 - B5 - | A5 - - - F5 - - - |
          G5 - Bb5 - D6 - C6 - | Bb5 - A5 - G5 - E5 - | F5 - - - - - - - | . . . . . . . .`,
  },
  {
    name: 'board_final', bpm: 132, lead: 'lead', double: 'pluck', leadVol: 0.17, bass: 'eighths', comp: 'pad', drums: 'tense', fill: true,
    chords: ['Am', 'F', 'G', 'E', 'Am', 'F', 'Dm', 'E', 'F', 'G', 'Am', 'Am', 'Dm', 'E', 'Am', 'E'],
    mel: `A4 - C5 - E5 - A5 - | A5 G5 F5 - C5 - F5 - | G5 - D5 - B4 - D5 G5 | G#5 - - - E5 - - - |
          A5 - E5 - C5 - E5 A5 | C6 - A5 - F5 - A5 C6 | D6 - A5 - F5 - D5 F5 | E5 - G#5 - B5 - - - |
          C6 - - B5 A5 - - - | B5 - - A5 G5 - - - | A5 - E5 - A5 - C6 - | B5 - A5 - E5 - - - |
          F5 - A5 - D6 - - - | E6 - D6 - B5 - G#5 - | A5 - - - E5 - C5 - | B4 - - - G#4 - B4 -`,
  },
  {
    name: 'minigame', bpm: 150, lead: 'lead', double: 'bell', leadVol: 0.16, bass: 'eighths', comp: 'padarp', drums: 'drive', fill: true,
    chords: ['Em', 'C', 'G', 'D', 'Em', 'C', 'G', 'D', 'C', 'D', 'Bm', 'Em', 'C', 'D', 'Em', 'Em'],
    mel: `E5 - G5 - B5 - G5 E5 | C6 - B5 - G5 - E5 - | D5 - G5 - B5 - D6 - | C6 B5 A5 - F#5 - D5 - |
          E5 G5 B5 E6 - - B5 - | C6 - E6 - - - C6 - | B5 - G5 - D5 - G5 - | A5 - - - F#5 - A5 - |
          G5 - - E5 G5 - C6 - | A5 - - F#5 A5 - D6 - | B5 - A5 - F#5 - D5 - | E5 - - - G5 - B5 - |
          E6 - D6 - C6 - B5 - | A5 - B5 - C6 - D6 - | E6 - - - B5 - - - | E5 - - - . . . .`,
  },
  {
    name: 'mg_select', bpm: 126, lead: 'bell', leadVol: 0.22, bass: 'roots', comp: 'arp', drums: 'march',
    chords: ['C', 'Ab', 'Bb', 'C', 'C', 'Ab', 'Bb', 'G'],
    mel: `C6 - G5 - E5 - G5 - | Ab5 - Eb5 - C5 - Eb5 - | Bb5 - F5 - D5 - F5 - | C6 - - - E6 - G6 - |
          C6 - G5 - E5 - G5 - | C6 - Ab5 - Eb5 - Ab5 - | D6 - Bb5 - F5 - D6 - | B5 - D6 - G6 - - -`,
  },
  {
    name: 'final', bpm: 92, lead: 'brass', double: 'bell', leadVol: 0.2, bass: 'roots', comp: 'brass', drums: 'anthem', bells: true,
    chords: ['Bb', 'F', 'Gm', 'Eb', 'Bb', 'F', 'Eb', 'F', 'Eb', 'F', 'Dm', 'Gm', 'Cm', 'F', 'Bb', 'Bb'],
    mel: `D5 - - - F5 - Bb5 - | A5 - - - G5 - F5 - | G5 - - - Bb5 - D6 - | C6 - - - - - Bb5 - |
          Bb5 - - - D6 - - - | C6 - - - A5 - F5 - | G5 - Bb5 - Eb6 - D6 - | C6 - - - - - - - |
          Eb6 - D6 - C6 - Bb5 - | C6 - - - A5 - - - | D6 - C6 - Bb5 - A5 - | Bb5 - - - G5 - - - |
          Eb6 - - - D6 - C6 - | D6 - C6 - A5 - F5 - | Bb5 - - - - - - - | . . . . . . . .`,
  },
];

const only = process.argv[2];
for (const s of SONGS) if (!only || only === s.name) render(s);

// rövid betétek: [hangszer, kezdet(negyed), hossz(negyed), hang(ok), hangerő]
if (!only || only === 'jingles') {
  jingle('start', 140, [
    ['brass', 0, 0.45, ['C5', 'E5', 'G5'], 0.09], ['brass', 0.5, 0.45, ['C5', 'E5', 'G5'], 0.09], ['brass', 1, 0.45, ['C5', 'E5', 'G5'], 0.09],
    ['brass', 1.5, 2.5, ['F5', 'A5', 'C6'], 0.09], ['lead', 1.5, 2.5, 'C6', 0.16], ['bell', 1.5, 2, 'C7', 0.12],
    ['kick', 0], ['kick', 0.5], ['kick', 1], ['snare', 1.5], ['tom', 1.25], ['bass', 1.5, 2.5, 'F2', 0.4],
  ]);
  jingle('crown', 160, [
    ['bell', 0, 0.5, 'G5', 0.16], ['bell', 0.25, 0.5, 'B5', 0.16], ['bell', 0.5, 0.5, 'D6', 0.16], ['bell', 0.75, 0.5, 'G6', 0.16],
    ['brass', 1, 2, ['G4', 'B4', 'D5'], 0.08], ['lead', 1, 2, 'B5', 0.14], ['bell', 1, 2, 'G7', 0.08], ['kick', 1], ['clap', 1],
  ]);
  jingle('ally', 150, [
    ['pluck', 0, 0.4, 'C5', 0.3], ['pluck', 0.33, 0.4, 'E5', 0.3], ['pluck', 0.66, 0.4, 'G5', 0.3], ['bell', 1, 1.5, ['C6', 'E6'], 0.12],
  ], 1.0);
  jingle('victory', 130, [
    ['brass', 0, 0.4, ['G4', 'C5', 'E5'], 0.08], ['brass', 0.5, 0.4, ['G4', 'C5', 'E5'], 0.08], ['brass', 1, 0.4, ['G4', 'C5', 'E5'], 0.08],
    ['brass', 1.5, 1.2, ['Ab4', 'C5', 'Eb5'], 0.08], ['brass', 2.75, 1.2, ['Bb4', 'D5', 'F5'], 0.08], ['brass', 4, 3, ['C5', 'E5', 'G5'], 0.09],
    ['lead', 0, 0.4, 'E5', 0.15], ['lead', 0.5, 0.4, 'E5', 0.15], ['lead', 1, 0.4, 'E5', 0.15], ['lead', 1.5, 1.2, 'Eb5', 0.15],
    ['lead', 2.75, 1.2, 'F5', 0.15], ['lead', 4, 3, 'G5', 0.15], ['bell', 4, 3, ['C7', 'G6'], 0.1],
    ['kick', 0], ['kick', 1], ['snare', 1.5], ['snare', 2.75], ['tom', 3.5], ['tom', 3.75], ['kick', 4], ['clap', 4],
    ['bass', 1.5, 1.2, 'Ab2', 0.4], ['bass', 2.75, 1.2, 'Bb2', 0.4], ['bass', 4, 3, 'C2', 0.45],
  ]);
}
