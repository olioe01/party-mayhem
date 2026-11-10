// Kódból épített 3D karakterek. Minden figura kb. 1 egység magas, a talpa az origóban,
// a +Z irányba (a kamera felé) néz.
//   build(id) -> { root, rig, eyes: [..], tick(t) }
//   root: ezt mozgatjuk/forgatjuk, rig: ezt nyújtjuk/lapítjuk (squash & stretch)

import * as THREE from 'three';

const mat = (color, o = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.55, metalness: 0, ...o });
const BLACK = mat('#1f1b2e', { roughness: 0.3 });
const WHITE = mat('#ffffff', { roughness: 0.35 });
const PINK = mat('#ff9fb5');

function sphere(r, m, x = 0, y = 0, z = 0, sx = 1, sy = 1, sz = 1) {
  const s = new THREE.Mesh(new THREE.SphereGeometry(r, 24, 16), m);
  s.position.set(x, y, z);
  s.scale.set(sx, sy, sz);
  return s;
}
function cone(r, h, m, x, y, z, seg = 16) {
  const c = new THREE.Mesh(new THREE.ConeGeometry(r, h, seg), m);
  c.position.set(x, y, z);
  return c;
}
function cyl(r1, r2, h, m, x, y, z, seg = 20) {
  const c = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, h, seg), m);
  c.position.set(x, y, z);
  return c;
}

// két szem: fehér gömb, pupilla, csillanás. Visszaadja a pislogáshoz használható csoportokat.
function eyes(parent, { y, z, dx, r = 0.085, pupil = 0.55, white = true, look = 0 }) {
  const out = [];
  for (const s of [-1, 1]) {
    const g = new THREE.Group();
    g.position.set(s * dx, y, z);
    if (white) g.add(sphere(r, WHITE));
    const p = sphere(r * pupil, BLACK, look * r * 0.3, 0, white ? r * 0.62 : 0);
    if (!white) p.scale.set(1, 1.35, 0.6);
    g.add(p);
    g.add(sphere(r * 0.18, WHITE, r * 0.22, r * 0.25, white ? r * 0.95 : r * 0.45));
    parent.add(g);
    out.push(g);
  }
  return out;
}

function cheeks(parent, y, z, dx, r = 0.05) {
  for (const s of [-1, 1]) parent.add(sphere(r, PINK, s * dx, y, z, 1, 0.6, 0.4));
}

function smile(parent, y, z, r = 0.07, m = BLACK) {
  const t = new THREE.Mesh(new THREE.TorusGeometry(r, r * 0.22, 8, 16, Math.PI), m);
  t.position.set(0, y, z);
  t.rotation.z = Math.PI;
  parent.add(t);
  return t;
}

// ---------------------------------------------------------------- figurák
const BUILDERS = {
  frog(rig) {
    const g = mat('#4cbb57'), light = mat('#c9ef9f');
    rig.add(sphere(0.42, g, 0, 0.36, 0, 1.15, 0.82, 1));
    rig.add(sphere(0.3, light, 0, 0.3, 0.17, 1, 0.8, 0.6));
    rig.add(sphere(0.15, g, -0.21, 0.66, 0.08));
    rig.add(sphere(0.15, g, 0.21, 0.66, 0.08));
    const e = eyes(rig, { y: 0.69, z: 0.17, dx: 0.21, r: 0.1 });
    const mouth = new THREE.Mesh(new THREE.TorusGeometry(0.15, 0.018, 8, 24, Math.PI * 0.8), mat('#1d6b2a'));
    mouth.position.set(0, 0.47, 0.36);
    mouth.rotation.set(-0.35, 0, Math.PI + Math.PI * 0.1);
    rig.add(mouth);
    cheeks(rig, 0.48, 0.35, 0.27);
    for (const s of [-1, 1]) rig.add(sphere(0.12, g, s * 0.25, 0.05, 0.2, 1.3, 0.45, 1.5));
    return { eyes: e };
  },

  cat(rig) {
    const fur = mat('#f2a541'), cream = mat('#fff1d6');
    rig.add(sphere(0.28, fur, 0, 0.3, 0, 1, 1.05, 0.95));
    rig.add(sphere(0.2, cream, 0, 0.27, 0.12, 1, 1, 0.6));
    rig.add(sphere(0.3, fur, 0, 0.72, 0.02));
    for (const s of [-1, 1]) {
      const ear = cone(0.11, 0.22, fur, s * 0.17, 0.98, 0, 4);
      ear.rotation.z = -s * 0.35;
      rig.add(ear);
      const inner = cone(0.06, 0.13, PINK, s * 0.165, 0.96, 0.04, 4);
      inner.rotation.z = -s * 0.35;
      rig.add(inner);
      for (const k of [-1, 1]) {
        const w = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.01, 0.01), BLACK);
        w.position.set(s * 0.2, 0.66 + k * 0.03, 0.27);
        w.rotation.z = s * k * 0.15;
        rig.add(w);
      }
    }
    const e = eyes(rig, { y: 0.76, z: 0.27, dx: 0.11, r: 0.075 });
    rig.add(sphere(0.035, PINK, 0, 0.68, 0.3));
    smile(rig, 0.64, 0.28, 0.035);
    const tail = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.05, 8, 16, Math.PI * 1.2), fur);
    tail.position.set(0.12, 0.35, -0.24);
    tail.rotation.y = Math.PI / 2;
    rig.add(tail);
    return { eyes: e, tick: (t) => { tail.rotation.x = Math.sin(t * 3) * 0.3; } };
  },

  fox(rig) {
    const fur = mat('#f2711c'), white = mat('#fff8ee'), dark = mat('#3a2418');
    rig.add(sphere(0.28, fur, 0, 0.3, 0, 1, 1.05, 0.95));
    rig.add(sphere(0.19, white, 0, 0.27, 0.13, 1, 1, 0.6));
    rig.add(sphere(0.29, fur, 0, 0.72, 0.02));
    const muzzle = cone(0.11, 0.28, white, 0, 0.62, 0.3);
    muzzle.rotation.x = Math.PI / 2;
    rig.add(muzzle);
    rig.add(sphere(0.04, BLACK, 0, 0.62, 0.45));
    for (const s of [-1, 1]) {
      const ear = cone(0.1, 0.28, fur, s * 0.16, 1.02, -0.02, 4);
      ear.rotation.z = -s * 0.25;
      rig.add(ear);
      const tip = cone(0.05, 0.1, dark, s * 0.19, 1.13, -0.02, 4);
      tip.rotation.z = -s * 0.25;
      rig.add(tip);
    }
    const e = eyes(rig, { y: 0.81, z: 0.25, dx: 0.13, r: 0.07 });
    const tail = new THREE.Group();
    tail.position.set(0, 0.25, -0.22);
    tail.add(sphere(0.17, fur, 0, 0.12, -0.12, 1, 1, 1.9));
    tail.add(sphere(0.1, white, 0, 0.2, -0.38, 1, 1, 1.2));
    tail.rotation.x = -0.6;
    rig.add(tail);
    return { eyes: e, tick: (t) => { tail.rotation.y = Math.sin(t * 2.5) * 0.35; } };
  },

  panda(rig) {
    const w = mat('#fafafa'), b = mat('#2b2b33');
    rig.add(sphere(0.32, w, 0, 0.32, 0, 1, 1, 0.95));
    for (const s of [-1, 1]) {
      rig.add(sphere(0.1, b, s * 0.3, 0.38, 0.06, 1, 1.4, 1));
      rig.add(sphere(0.11, b, s * 0.16, 0.06, 0.08, 1, 0.7, 1.2));
      rig.add(sphere(0.09, b, s * 0.21, 0.98, -0.02));
      const patch = sphere(0.075, b, s * 0.11, 0.76, 0.25, 1, 1.35, 0.5);
      patch.rotation.z = s * 0.5;
      rig.add(patch);
    }
    rig.add(sphere(0.3, w, 0, 0.74, 0.02));
    const e = eyes(rig, { y: 0.77, z: 0.28, dx: 0.11, r: 0.045 });
    rig.add(sphere(0.04, b, 0, 0.68, 0.31, 1.3, 0.9, 1));
    smile(rig, 0.63, 0.3, 0.03, b);
    return { eyes: e };
  },

  pig(rig) {
    const p = mat('#f9a8c4'), d = mat('#e77fa4');
    rig.add(sphere(0.4, p, 0, 0.42, 0, 1.08, 0.98, 1));
    const snout = cyl(0.12, 0.13, 0.1, d, 0, 0.42, 0.39);
    snout.rotation.x = Math.PI / 2;
    rig.add(snout);
    for (const s of [-1, 1]) {
      rig.add(sphere(0.025, mat('#8a3b5c'), s * 0.045, 0.42, 0.45));
      const ear = cone(0.1, 0.18, d, s * 0.22, 0.78, 0.06, 3);
      ear.rotation.set(0.6, 0, -s * 0.4);
      rig.add(ear);
      for (const k of [-1, 1]) rig.add(cyl(0.06, 0.06, 0.12, d, s * 0.2, 0.05, k * 0.16));
    }
    const e = eyes(rig, { y: 0.6, z: 0.33, dx: 0.14, r: 0.065 });
    cheeks(rig, 0.48, 0.36, 0.24);
    const tail = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.02, 6, 14, Math.PI * 1.7), d);
    tail.position.set(0, 0.45, -0.41);
    rig.add(tail);
    return { eyes: e, tick: (t) => { tail.rotation.z = t * 4; } };
  },

  penguin(rig) {
    const b = mat('#24304a'), o = mat('#ff9f1c');
    rig.add(sphere(0.34, b, 0, 0.48, 0, 1, 1.38, 0.95));
    rig.add(sphere(0.27, WHITE, 0, 0.42, 0.13, 0.85, 1.25, 0.6));
    const beak = cone(0.07, 0.18, o, 0, 0.7, 0.36);
    beak.rotation.x = Math.PI / 2;
    rig.add(beak);
    const e = eyes(rig, { y: 0.8, z: 0.27, dx: 0.11, r: 0.065 });
    const flippers = [];
    for (const s of [-1, 1]) {
      const f = sphere(0.1, b, s * 0.34, 0.45, 0, 0.45, 1.6, 0.9);
      f.rotation.z = s * 0.35;
      rig.add(f);
      flippers.push(f);
      rig.add(sphere(0.09, o, s * 0.13, 0.03, 0.12, 1, 0.4, 1.5));
    }
    cheeks(rig, 0.68, 0.28, 0.17, 0.04);
    return { eyes: e, tick: (t) => flippers.forEach((f, i) => { f.rotation.z = (i ? -1 : 1) * (0.35 + Math.sin(t * 5) * 0.15); }) };
  },

  duck(rig) {
    const y = mat('#ffd43b', { roughness: 0.25 }), o = mat('#ff8c1a', { roughness: 0.3 });
    rig.add(sphere(0.36, y, 0, 0.3, -0.03, 1.15, 0.85, 1.1));
    const tail = cone(0.12, 0.22, y, 0, 0.42, -0.4);
    tail.rotation.x = -1.1;
    rig.add(tail);
    rig.add(sphere(0.25, y, 0, 0.74, 0.08));
    rig.add(sphere(0.12, o, 0, 0.67, 0.31, 1.15, 0.38, 1.1));
    for (const s of [-1, 1]) rig.add(sphere(0.14, y, s * 0.34, 0.36, -0.02, 0.4, 0.75, 1.1));
    const e = eyes(rig, { y: 0.8, z: 0.27, dx: 0.1, r: 0.06 });
    return { eyes: e, tick: (t) => { rig.rotation.z = Math.sin(t * 2.2) * 0.07; } };
  },

  robot(rig) {
    const steel = mat('#9fb3c8', { metalness: 0.55, roughness: 0.35 });
    const dark = mat('#475569', { metalness: 0.4, roughness: 0.4 });
    const glow = mat('#5eead4', { emissive: '#2dd4bf', emissiveIntensity: 1.6 });
    const red = mat('#ff4d6d', { emissive: '#ff1744', emissiveIntensity: 1.2 });
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.46, 0.4, 0.34), steel);
    body.position.y = 0.38;
    rig.add(body);
    for (let i = 0; i < 3; i++) {
      const led = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.06, 0.02), i === 1 ? red : glow);
      led.position.set(-0.1 + i * 0.1, 0.4, 0.18);
      rig.add(led);
    }
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.32, 0.36), steel);
    head.position.y = 0.8;
    rig.add(head);
    const visor = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.14, 0.02), dark);
    visor.position.set(0, 0.82, 0.185);
    rig.add(visor);
    const e = [];
    for (const s of [-1, 1]) {
      const g = new THREE.Group();
      g.position.set(s * 0.09, 0.82, 0.2);
      g.add(new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.02, 12).rotateX(Math.PI / 2), glow));
      rig.add(g);
      e.push(g);
      rig.add(cyl(0.045, 0.045, 0.24, dark, s * 0.29, 0.38, 0));
      rig.add(sphere(0.06, steel, s * 0.29, 0.23, 0));
      const leg = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.18, 0.14), dark);
      leg.position.set(s * 0.12, 0.09, 0);
      rig.add(leg);
    }
    rig.add(cyl(0.012, 0.012, 0.2, dark, 0, 1.05, 0));
    const bulb = sphere(0.05, red, 0, 1.16, 0);
    rig.add(bulb);
    return { eyes: e, tick: (t) => { bulb.material.emissiveIntensity = Math.sin(t * 6) > 0 ? 2 : 0.2; } };
  },

  ghost(rig) {
    const m = mat('#f8f9ff', { transparent: true, opacity: 0.9, emissive: '#c7d2fe', emissiveIntensity: 0.25 });
    const float = new THREE.Group();
    rig.add(float);
    float.add(new THREE.Mesh(new THREE.SphereGeometry(0.34, 24, 16, 0, Math.PI * 2, 0, Math.PI / 2), m).translateY(0.62));
    float.add(cyl(0.34, 0.36, 0.34, m, 0, 0.45, 0, 24));
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      const c = cone(0.1, 0.16, m, Math.sin(a) * 0.28, 0.22, Math.cos(a) * 0.28, 8);
      c.rotation.x = Math.PI;
      float.add(c);
    }
    for (const s of [-1, 1]) float.add(sphere(0.08, m, s * 0.36, 0.48, 0.05, 0.8, 1, 0.8));
    const e = eyes(float, { y: 0.66, z: 0.31, dx: 0.12, r: 0.075, white: false });
    const mouth = sphere(0.045, BLACK, 0, 0.53, 0.33, 1, 1.3, 0.5);
    float.add(mouth);
    return { eyes: e, tick: (t) => { float.position.y = 0.12 + Math.sin(t * 2) * 0.06; float.rotation.z = Math.sin(t * 1.3) * 0.08; } };
  },

  queen(rig) {
    const dress = mat('#8b5cf6'), trim = mat('#fde68a', { metalness: 0.5, roughness: 0.3 });
    const skin = mat('#ffd7b0'), hair = mat('#7a3e1d');
    const pts = [[0, 0], [0.36, 0], [0.34, 0.08], [0.26, 0.3], [0.16, 0.48], [0.13, 0.58], [0, 0.6]].map(([x, y]) => new THREE.Vector2(x, y));
    rig.add(new THREE.Mesh(new THREE.LatheGeometry(pts, 28), dress));
    const hem = new THREE.Mesh(new THREE.TorusGeometry(0.35, 0.03, 8, 32), trim);
    hem.rotation.x = Math.PI / 2;
    hem.position.y = 0.04;
    rig.add(hem);
    const neck = new THREE.Mesh(new THREE.TorusGeometry(0.11, 0.022, 8, 24), trim);
    neck.rotation.x = Math.PI / 2;
    neck.position.y = 0.6;
    rig.add(neck);
    for (const s of [-1, 1]) {
      const arm = sphere(0.06, dress, s * 0.2, 0.42, 0.04, 0.8, 1.8, 0.8);
      arm.rotation.z = s * 0.5;
      rig.add(arm);
    }
    rig.add(sphere(0.21, hair, 0, 0.82, -0.04, 1.05, 1.05, 1));
    rig.add(sphere(0.19, skin, 0, 0.8, 0.03));
    rig.add(sphere(0.1, hair, 0, 0.9, -0.2));
    const e = eyes(rig, { y: 0.82, z: 0.19, dx: 0.07, r: 0.045 });
    cheeks(rig, 0.75, 0.18, 0.12, 0.035);
    smile(rig, 0.74, 0.205, 0.03, mat('#c0392b'));
    // tiara
    const band = cyl(0.12, 0.12, 0.04, trim, 0, 1.0, 0, 20);
    rig.add(band);
    for (let i = -1; i <= 1; i++) {
      rig.add(cone(0.03, i === 0 ? 0.12 : 0.08, trim, i * 0.07, 1.06 + (i === 0 ? 0.02 : 0), 0.08, 6));
    }
    rig.add(sphere(0.025, mat('#e11d48', { roughness: 0.2 }), 0, 1.12, 0.09));
    return { eyes: e };
  },

  thimble(rig) {
    // pöttyös fém gyűszű
    const cv = document.createElement('canvas');
    cv.width = 128; cv.height = 128;
    const c = cv.getContext('2d');
    c.fillStyle = '#d7dee6';
    c.fillRect(0, 0, 128, 128);
    c.fillStyle = '#8f9bab';
    for (let y = 0; y < 128; y += 12) for (let x = (y / 12) % 2 ? 6 : 0; x < 128; x += 12) { c.beginPath(); c.arc(x, y, 3.2, 0, Math.PI * 2); c.fill(); }
    const tex = new THREE.CanvasTexture(cv);
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
    tex.repeat.set(4, 2);
    tex.colorSpace = THREE.SRGBColorSpace;
    const metal = new THREE.MeshStandardMaterial({ map: tex, metalness: 0.75, roughness: 0.3 });
    const pts = [[0, 0.02], [0.31, 0.02], [0.3, 0.1], [0.27, 0.55], [0.24, 0.65], [0.17, 0.72], [0, 0.75]].map(([x, y]) => new THREE.Vector2(x, y));
    rig.add(new THREE.Mesh(new THREE.LatheGeometry(pts, 32), metal));
    const rim = new THREE.Mesh(new THREE.TorusGeometry(0.31, 0.035, 8, 32), mat('#b8c2cf', { metalness: 0.8, roughness: 0.25 }));
    rim.rotation.x = Math.PI / 2;
    rim.position.y = 0.05;
    rig.add(rim);
    const e = eyes(rig, { y: 0.44, z: 0.27, dx: 0.1, r: 0.085 });
    smile(rig, 0.3, 0.29, 0.06);
    cheeks(rig, 0.32, 0.28, 0.18, 0.04);
    for (const s of [-1, 1]) rig.add(sphere(0.07, mat('#ef4444'), s * 0.14, 0.02, 0.18, 1.2, 0.5, 1.5));
    return { eyes: e };
  },

  donut(rig) {
    const dough = mat('#d99a5b'), icing = mat('#ff8fb8', { roughness: 0.35 });
    const ring = new THREE.Group();
    ring.position.y = 0.48;
    rig.add(ring);
    ring.add(new THREE.Mesh(new THREE.TorusGeometry(0.29, 0.17, 18, 36), dough));
    const top = new THREE.Mesh(new THREE.TorusGeometry(0.29, 0.155, 18, 36), icing);
    top.scale.set(1.04, 1.04, 0.75);
    top.position.z = 0.06;
    ring.add(top);
    const cols = ['#fde047', '#60a5fa', '#34d399', '#ffffff', '#c084fc'];
    for (let i = 0; i < 26; i++) {
      const a = (i / 26) * Math.PI * 2 + (i % 3) * 0.2;
      const rr = 0.29 + ((i * 37) % 10 - 5) * 0.018;
      const sp = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.018, 0.018), mat(cols[i % cols.length]));
      sp.position.set(Math.cos(a) * rr, Math.sin(a) * rr, 0.19);
      sp.rotation.z = a * 3;
      ring.add(sp);
    }
    const e = eyes(ring, { y: 0.29, z: 0.2, dx: 0.12, r: 0.07 });
    for (const s of [-1, 1]) rig.add(sphere(0.07, mat('#7c4a24'), s * 0.15, 0.03, 0.05, 1.2, 0.5, 1.4));
    return { eyes: e };
  },
};

export const CHAR_IDS = Object.keys(BUILDERS);

export function build(id) {
  const root = new THREE.Group();
  const rig = new THREE.Group();
  root.add(rig);
  const res = (BUILDERS[id] || BUILDERS.frog)(rig) || {};
  rig.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = false; } });
  return { root, rig, eyes: res.eyes || [], tick: res.tick || (() => {}) };
}
