// 3D tábla (Three.js). A játéklogika a régi 2D koordinátákban (1280x720 px) dolgozik,
// itt ezeket képezzük le a 3D világba: 1 egység = 40 px.

import * as THREE from 'three';
import { mergeGeometries } from '/vendor/three/examples/jsm/utils/BufferGeometryUtils.js';
import { W, H, emoji, text, shade } from './engine.js';
import { build as buildChar } from './chars3d.js';

const S = 40;
const toWorld = (x, y, h = 0) => new THREE.Vector3((x - 640) / S, h / S, (y - 330) / S);

let renderer = null, scene = null, camera = null, glCanvas = null;
let ok = false;
let boardGroup = null, builtFor = null;
const pawns = new Map();
let crown = null, crownGlow = null, crownLight = null;
const animated = []; // díszletek, amik mozognak (füst, láng)

// azonos beállítású anyagok megosztva (így a statikus elemek összevonhatók)
const matCache = new Map();
function std(color, o = {}) {
  const key = color + JSON.stringify(o);
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshStandardMaterial({ color, roughness: 0.75, metalness: 0, flatShading: true, ...o }));
  return matCache.get(key);
}

export function init() {
  glCanvas = document.getElementById('gl');
  try {
    renderer = new THREE.WebGLRenderer({ canvas: glCanvas, antialias: true });
  } catch (e) {
    console.warn('WebGL nem elérhető, 2D tábla lesz.', e);
    return false;
  }
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;

  scene = new THREE.Scene();
  scene.background = new THREE.Color('#5cc8f2');
  scene.fog = new THREE.Fog('#8fd9f7', 32, 70);

  camera = new THREE.PerspectiveCamera(36, W / H, 0.1, 200);
  camera.position.set(0, 21, 17.5);
  camera.lookAt(0, 0, 1.25);

  scene.add(new THREE.HemisphereLight('#e0f2fe', '#3f6212', 1.1));
  const sun = new THREE.DirectionalLight('#fff1d6', 2.4);
  sun.position.set(-9, 20, 9);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -18, right: 18, top: 12, bottom: -12, near: 1, far: 60 });
  sun.shadow.bias = -0.0006;
  sun.shadow.normalBias = 0.02;
  scene.add(sun);

  // tenger
  const sea = new THREE.Mesh(new THREE.PlaneGeometry(220, 220), new THREE.MeshStandardMaterial({ color: '#2aa7df', roughness: 0.35, metalness: 0.05 }));
  sea.rotation.x = -Math.PI / 2;
  sea.position.y = -0.4;
  sea.receiveShadow = true;
  scene.add(sea);

  buildCrown();
  buildMarker();
  ok = true;
  setVisible(false);
  return true;
}

export const available = () => ok;
export const stats = () => (renderer ? { ...renderer.info.render } : null);
export function setVisible(v) { if (glCanvas) glCanvas.style.display = v ? 'block' : 'none'; }

export function project(x, y, h = 0) {
  const v = toWorld(x, y, h).project(camera);
  return { x: ((v.x + 1) / 2) * W, y: ((1 - v.y) / 2) * H };
}

function syncSize() {
  const w = glCanvas.clientWidth, h = glCanvas.clientHeight;
  if (!w || !h) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  if (glCanvas.width !== Math.round(w * dpr) || glCanvas.height !== Math.round(h * dpr)) {
    renderer.setPixelRatio(dpr);
    renderer.setSize(w, h, false);
  }
}

// ---------------------------------------------------------------- tábla
function roundedRect(x0, z0, x1, z1, r) {
  const s = new THREE.Shape();
  s.moveTo(x0 + r, z0);
  s.lineTo(x1 - r, z0); s.quadraticCurveTo(x1, z0, x1, z0 + r);
  s.lineTo(x1, z1 - r); s.quadraticCurveTo(x1, z1, x1 - r, z1);
  s.lineTo(x0 + r, z1); s.quadraticCurveTo(x0, z1, x0, z1 - r);
  s.lineTo(x0, z0 + r); s.quadraticCurveTo(x0, z0, x0 + r, z0);
  return s;
}

function slab(shape, depth, mat, y) {
  const g = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: true, bevelThickness: 0.08, bevelSize: 0.08, bevelSegments: 2, curveSegments: 16 });
  g.rotateX(-Math.PI / 2);
  const m = new THREE.Mesh(g, mat);
  m.position.y = y;
  m.receiveShadow = true;
  return m;
}

const iconCache = new Map();
function iconTexture(type, info) {
  if (iconCache.has(type)) return iconCache.get(type);
  const cv = document.createElement('canvas');
  cv.width = cv.height = 128;
  const c = cv.getContext('2d');
  const g = c.createRadialGradient(48, 44, 6, 64, 64, 64);
  g.addColorStop(0, shade(info.color, 0.45));
  g.addColorStop(1, info.color);
  c.fillStyle = g;
  c.beginPath(); c.arc(64, 64, 62, 0, Math.PI * 2); c.fill();
  c.lineWidth = 10;
  c.strokeStyle = '#ffffff';
  c.beginPath(); c.arc(64, 64, 56, 0, Math.PI * 2); c.stroke();
  if (type === 'S' || type === 'T') emoji(c, info.icon, 64, 64, 62);
  else text(c, info.icon, 64, 68, { size: 84, color: '#fff', stroke: shade(info.color, -0.4), sw: 10 });
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  iconCache.set(type, tex);
  return tex;
}

export function build(board, types, deco) {
  if (!ok || builtFor === board) return;
  if (boardGroup) scene.remove(boardGroup);
  builtFor = board;
  boardGroup = new THREE.Group();
  animated.length = 0;

  // sziget: homok + fű
  const sx0 = (78 - 640) / S, sx1 = (1202 - 640) / S, sz0 = (52 - 330) / S, sz1 = (608 - 330) / S;
  boardGroup.add(slab(roundedRect(sx0, sz0, sx1, sz1, 3.6), 0.55, std('#f2d18b', { flatShading: false }), -0.62));
  boardGroup.add(slab(roundedRect(sx0 + 0.45, sz0 + 0.42, sx1 - 0.45, sz1 - 0.42, 3.2), 0.08, std('#7cc552', { flatShading: false, roughness: 0.95 }), -0.1));

  // utak
  const roadDark = std('#7a5a32', { flatShading: false });
  const roadTop = std('#ecd09a', { flatShading: false });
  const roadRisky = std('#efb3a0', { flatShading: false });
  for (const nd of board.nodes) {
    for (const nid of nd.next) {
      const to = board.nodes[nid];
      const a = toWorld(nd.x, nd.y), b = toWorld(to.x, to.y);
      const len = a.distanceTo(b);
      const mid = a.clone().add(b).multiplyScalar(0.5);
      const ang = -Math.atan2(b.z - a.z, b.x - a.x);
      for (const [w, hgt, mat, y] of [[0.74, 0.08, roadDark, 0.02], [0.54, 0.08, (nd.inner || to.inner) ? roadRisky : roadTop, 0.05]]) {
        const m = new THREE.Mesh(new THREE.BoxGeometry(len, hgt, w), mat);
        m.position.set(mid.x, y, mid.z);
        m.rotation.y = ang;
        m.receiveShadow = true;
        boardGroup.add(m);
      }
    }
  }

  // mezők
  for (const nd of board.nodes) {
    const info = types[nd.type];
    const side = std(shade(info.color, -0.25), { flatShading: false });
    const top = new THREE.MeshStandardMaterial({ map: iconTexture(nd.type, info), roughness: 0.55 });
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.52, 0.58, 0.2, 40), [side, top, side]);
    const p = toWorld(nd.x, nd.y);
    m.position.set(p.x, 0.16, p.z);
    m.rotation.y = Math.PI / 2; // a henger tetején a textúra teteje így néz a kamerától el
    m.castShadow = true;
    m.receiveShadow = true;
    boardGroup.add(m);
  }

  // díszletek
  for (const [kind, x, y, s] of deco) {
    const obj = DECO[kind]?.();
    if (!obj) continue;
    const p = toWorld(x, y);
    obj.position.set(p.x, 0, p.z);
    obj.scale.setScalar(s);
    obj.rotation.y = (x * 7 + y * 3) % 6;
    obj.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    boardGroup.add(obj);
  }
  // kis sziklák a vízben
  for (const [x, z, s] of [[-17, -4, 0.8], [17.5, 3, 1], [-16.5, 6.5, 0.6], [15, -7.5, 0.7], [-12, 9.5, 0.5]]) {
    const r = DECO.rock();
    r.position.set(x, -0.45, z);
    r.scale.setScalar(s * 2);
    boardGroup.add(r);
  }
  mergeStatic(boardGroup);
  scene.add(boardGroup);
}

// A mozdulatlan, egyanyagú elemeket anyagonként egy-egy hálóvá vonjuk össze:
// kevesebb rajzolási hívás = gyorsabb (főleg gyengébb gépen).
function mergeStatic(group) {
  group.updateMatrixWorld(true);
  const buckets = new Map();
  const victims = [];
  group.traverse((o) => {
    if (!o.isMesh || Array.isArray(o.material) || o.userData.dynamic) return;
    let p = o.parent, dyn = false;
    while (p && p !== group) { if (p.userData.dynamic) dyn = true; p = p.parent; }
    if (dyn) return;
    let g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k);
    if (!g.attributes.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
    g.applyMatrix4(o.matrixWorld);
    const key = `${o.material.uuid}|${o.castShadow}|${o.receiveShadow}`;
    if (!buckets.has(key)) buckets.set(key, { mat: o.material, cast: o.castShadow, recv: o.receiveShadow, geos: [] });
    buckets.get(key).geos.push(g);
    victims.push(o);
  });
  for (const o of victims) o.parent.remove(o);
  for (const b of buckets.values()) {
    const m = new THREE.Mesh(mergeGeometries(b.geos, false), b.mat);
    m.castShadow = b.cast;
    m.receiveShadow = b.recv;
    group.add(m);
  }
}

// ---------------------------------------------------------------- díszlet-modellek
const DECO = {
  tree() {
    const g = new THREE.Group();
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.11, 0.5, 6), std('#8b5a2b'));
    trunk.position.y = 0.25;
    const top = new THREE.Mesh(new THREE.IcosahedronGeometry(0.42, 0), std('#3f9b3a'));
    top.position.y = 0.78;
    const top2 = new THREE.Mesh(new THREE.IcosahedronGeometry(0.3, 0), std('#52b848'));
    top2.position.set(0.18, 1.0, 0.05);
    g.add(trunk, top, top2);
    return g;
  },
  pine() {
    const g = new THREE.Group();
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.09, 0.35, 6), std('#7a4a22'));
    trunk.position.y = 0.17;
    g.add(trunk);
    [[0.45, 0.55, 0.5], [0.34, 0.45, 0.85], [0.22, 0.35, 1.12]].forEach(([r, h, y]) => {
      const c = new THREE.Mesh(new THREE.ConeGeometry(r, h, 7), std('#2f7d3b'));
      c.position.y = y;
      g.add(c);
    });
    return g;
  },
  palm() {
    const g = new THREE.Group();
    for (let i = 0; i < 4; i++) {
      const seg = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.32, 6), std('#a0703a'));
      seg.position.set(i * 0.04, 0.16 + i * 0.3, 0);
      seg.rotation.z = -0.12;
      g.add(seg);
    }
    for (let i = 0; i < 6; i++) {
      const leaf = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.85, 4), std('#2fa84f'));
      const a = (i / 6) * Math.PI * 2;
      leaf.position.set(0.16 + Math.cos(a) * 0.32, 1.22, Math.sin(a) * 0.32);
      leaf.rotation.z = Math.PI / 2 + 0.5;
      leaf.rotation.y = -a;
      leaf.scale.set(1, 1, 0.35);
      g.add(leaf);
    }
    return g;
  },
  castle() {
    const g = new THREE.Group();
    const stone = std('#d6d3e6'), roof = std('#e0457b'), dark = std('#4c3d6b');
    const base = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.9, 1.1), stone);
    base.position.y = 0.45;
    g.add(base);
    for (const [x, z] of [[-0.85, -0.55], [0.85, -0.55], [-0.85, 0.55], [0.85, 0.55]]) {
      const t = new THREE.Mesh(new THREE.CylinderGeometry(0.26, 0.28, 1.35, 10), stone);
      t.position.set(x, 0.67, z);
      const r = new THREE.Mesh(new THREE.ConeGeometry(0.34, 0.55, 10), roof);
      r.position.set(x, 1.62, z);
      g.add(t, r);
    }
    const keep = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.7, 0.6), stone);
    keep.position.y = 1.25;
    const keepRoof = new THREE.Mesh(new THREE.ConeGeometry(0.55, 0.7, 4), roof);
    keepRoof.position.y = 1.95;
    keepRoof.rotation.y = Math.PI / 4;
    const door = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.5, 0.05), dark);
    door.position.set(0, 0.25, 0.56);
    const flag = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.18, 0.02), std('#ffd43b'));
    flag.position.set(0.15, 2.45, 0);
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.5), dark);
    pole.position.set(0, 2.35, 0);
    g.add(keep, keepRoof, door, pole, flag);
    flag.userData.dynamic = true;
    animated.push((t) => { flag.rotation.y = Math.sin(t * 3) * 0.4; });
    return g;
  },
  volcano() {
    const g = new THREE.Group();
    const cone = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 1.45, 1.7, 9), std('#8a5a3c'));
    cone.position.y = 0.85;
    const lava = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.36, 0.06, 9), new THREE.MeshStandardMaterial({ color: '#ff6b1a', emissive: '#ff4500', emissiveIntensity: 1.6 }));
    lava.position.y = 1.71;
    g.add(cone, lava);
    for (let i = 0; i < 5; i++) {
      const drip = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.7, 0.06), new THREE.MeshStandardMaterial({ color: '#ff7a1a', emissive: '#ff4500', emissiveIntensity: 1.2 }));
      const a = (i / 5) * Math.PI * 2 + 0.3;
      drip.position.set(Math.cos(a) * 0.62, 1.32, Math.sin(a) * 0.62);
      drip.lookAt(0, 1.32, 0);
      drip.rotation.x += 0.45;
      g.add(drip);
    }
    const smoke = [];
    for (let i = 0; i < 4; i++) {
      const s = new THREE.Mesh(new THREE.IcosahedronGeometry(0.25, 1), new THREE.MeshStandardMaterial({ color: '#d1d5db', transparent: true, opacity: 0.7 }));
      s.castShadow = false;
      s.userData.dynamic = true;
      g.add(s);
      smoke.push(s);
    }
    animated.push((t) => smoke.forEach((s, i) => {
      const k = ((t * 0.35 + i / smoke.length) % 1);
      s.position.set(Math.sin(k * 6 + i) * 0.2, 1.8 + k * 1.6, 0);
      s.scale.setScalar(0.6 + k * 1.4);
      s.material.opacity = 0.75 * (1 - k);
    }));
    return g;
  },
  rock() {
    const m = new THREE.Mesh(new THREE.DodecahedronGeometry(0.3, 0), std('#9ca3af'));
    m.position.y = 0.15;
    m.scale.y = 0.7;
    return m;
  },
  mushroom() {
    const g = new THREE.Group();
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.25, 8), std('#fef3c7'));
    stem.position.y = 0.12;
    const cap = new THREE.Mesh(new THREE.SphereGeometry(0.2, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), std('#ef4444'));
    cap.position.y = 0.22;
    g.add(stem, cap);
    return g;
  },
  flowers() {
    const g = new THREE.Group();
    const cols = ['#f472b6', '#facc15', '#a78bfa', '#fb7185', '#ffffff'];
    for (let i = 0; i < 7; i++) {
      const f = new THREE.Mesh(new THREE.SphereGeometry(0.07, 6, 4), std(cols[i % cols.length]));
      f.position.set(Math.cos(i * 2.4) * 0.3 * (i / 7 + 0.3), 0.12, Math.sin(i * 2.4) * 0.3 * (i / 7 + 0.3));
      g.add(f);
    }
    return g;
  },
  fountain() {
    const g = new THREE.Group();
    const bowl = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.55, 0.22, 16), std('#cbd5e1', { flatShading: false }));
    bowl.position.y = 0.11;
    const water = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.04, 16), new THREE.MeshStandardMaterial({ color: '#60c8f5', roughness: 0.1 }));
    water.position.y = 0.22;
    const col = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.09, 0.5, 8), std('#cbd5e1'));
    col.position.y = 0.4;
    g.add(bowl, water, col);
    return g;
  },
  tent() {
    const g = new THREE.Group();
    const t = new THREE.Mesh(new THREE.ConeGeometry(0.55, 0.75, 4), std('#f97316'));
    t.position.y = 0.37;
    t.rotation.y = Math.PI / 4;
    const fire = new THREE.Mesh(new THREE.ConeGeometry(0.1, 0.25, 6), new THREE.MeshStandardMaterial({ color: '#ffb020', emissive: '#ff6a00', emissiveIntensity: 1.5 }));
    fire.position.set(0.75, 0.13, 0.2);
    fire.userData.dynamic = true;
    g.add(t, fire);
    animated.push((t2) => { fire.scale.y = 0.8 + Math.sin(t2 * 18) * 0.25; });
    return g;
  },
  cactus() {
    const g = new THREE.Group();
    const m = std('#3c8f4a');
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.13, 0.6, 4, 8), m);
    body.position.y = 0.43;
    const arm = new THREE.Mesh(new THREE.CapsuleGeometry(0.08, 0.25, 4, 8), m);
    arm.position.set(0.2, 0.55, 0);
    g.add(body, arm);
    return g;
  },
};

// ---------------------------------------------------------------- korona
function buildCrown() {
  crown = new THREE.Group();
  const gold = new THREE.MeshStandardMaterial({ color: '#ffd43b', metalness: 0.7, roughness: 0.25, emissive: '#7a5200', emissiveIntensity: 0.35 });
  const band = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.3, 0.26, 20, 1, true), gold);
  band.material.side = THREE.DoubleSide;
  crown.add(band);
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    const spike = new THREE.Mesh(new THREE.ConeGeometry(0.09, 0.3, 6), gold);
    spike.position.set(Math.cos(a) * 0.33, 0.27, Math.sin(a) * 0.33);
    const gem = new THREE.Mesh(new THREE.SphereGeometry(0.055, 8, 6), new THREE.MeshStandardMaterial({ color: i % 2 ? '#e11d48' : '#3b82f6', roughness: 0.2, metalness: 0.2 }));
    gem.position.set(Math.cos(a) * 0.33, 0.44, Math.sin(a) * 0.33);
    crown.add(spike, gem);
  }
  crown.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  crown.scale.setScalar(1.4);
  crownGlow = new THREE.Mesh(new THREE.RingGeometry(0.55, 1.0, 32), new THREE.MeshBasicMaterial({ color: '#ffe066', transparent: true, opacity: 0.6, depthWrite: false }));
  crownGlow.rotation.x = -Math.PI / 2;
  crownLight = new THREE.PointLight('#ffd166', 6, 4, 1.6);
  scene.add(crown, crownGlow, crownLight);
}

// ---------------------------------------------------------------- figurák
const PAWN_SCALE = 1.2;
let marker = null;

function buildMarker() {
  marker = new THREE.Group();
  const m = new THREE.MeshStandardMaterial({ color: '#ffd43b', emissive: '#b8860b', emissiveIntensity: 0.6, metalness: 0.3, roughness: 0.3 });
  const tip = new THREE.Mesh(new THREE.ConeGeometry(0.26, 0.5, 4), m);
  tip.rotation.x = Math.PI;
  marker.add(tip);
  scene.add(marker);
}

function pawnFor(p) {
  let o = pawns.get(p.pid);
  const key = `${p.char}|${p.color}`;
  if (o && o.key === key) return o;
  if (o) scene.remove(o.group);
  const group = new THREE.Group();
  const ch = buildChar(p.char);
  ch.root.scale.setScalar(PAWN_SCALE);
  group.add(ch.root);
  // talapzat-gyűrű a játékos színében
  const base = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.38, 0.05, 32), new THREE.MeshStandardMaterial({ color: p.color, roughness: 0.4 }));
  base.position.y = 0.025;
  base.receiveShadow = true;
  group.add(base);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.46, 0.04, 8, 40), new THREE.MeshBasicMaterial({ color: '#ffffff' }));
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 0.04;
  group.add(ring);
  scene.add(group);
  o = {
    group, ch, ring, base, key,
    yaw: 0, targetYaw: 0, last: null, still: 0, prevH: 0, land: 0,
    emote: null, phase: Math.random() * 10, blinkAt: 1 + Math.random() * 3,
  };
  pawns.set(p.pid, o);
  return o;
}

export function emote(pid, type) {
  const o = pawns.get(pid);
  if (o) o.emote = { type, t0: lastT };
}

const angDiff = (a, b) => Math.atan2(Math.sin(b - a), Math.cos(b - a));

function animatePawn(o, d, t, dt) {
  const w = toWorld(d.x, d.y, d.h);
  // irány: mozgás közben a haladás felé, állva a kamera felé
  if (o.last) {
    const dx = w.x - o.last.x, dz = w.z - o.last.z;
    if (Math.hypot(dx, dz) > 0.004) { o.targetYaw = Math.atan2(dx, dz); o.still = 0; }
    else { o.still += dt; if (o.still > 0.5) o.targetYaw = 0; }
  }
  o.last = w.clone();
  o.yaw += angDiff(o.yaw, o.targetYaw) * Math.min(1, dt * 10);

  // ugrás / landolás
  if (o.prevH > 0.5 && d.h <= 0.5) o.land = 1;
  o.prevH = d.h;
  o.land = Math.max(0, o.land - dt * 5);

  let sy = 1 + Math.sin(t * 3 + o.phase) * 0.025; // lélegzés
  let sx = 1, extraY = 0, spin = 0, tilt = 0;
  if (d.h > 0.5) { sy *= 1.12; sx = 0.92; }
  sy *= 1 - o.land * 0.28;
  sx *= 1 + o.land * 0.22;

  if (o.emote) {
    const k = t - o.emote.t0;
    const ty = o.emote.type;
    if (ty === 'happy' && k < 0.8) {
      extraY = Math.sin((k / 0.8) * Math.PI) * 0.55;
      spin = (k / 0.8) * Math.PI * 2;
    } else if (ty === 'cheer' && k < 1.8) {
      const kk = (k % 0.6) / 0.6;
      extraY = Math.sin(kk * Math.PI) * 0.7;
      spin = (k / 1.8) * Math.PI * 4;
    } else if (ty === 'sad' && k < 1.4) {
      const a = Math.sin(Math.min(1, k / 0.3) * Math.PI / 2) * (1 - Math.max(0, (k - 1.0) / 0.4));
      sy *= 1 - 0.18 * a;
      sx *= 1 + 0.08 * a;
      tilt = 0.35 * a;
    } else o.emote = null;
  }

  o.group.position.set(w.x, w.y + extraY, w.z);
  o.ch.root.rotation.y = o.yaw + spin;
  o.ch.root.rotation.x = tilt;
  o.ch.rig.scale.set(sx, sy, sx);
  const cur = !!d.current;
  o.ch.root.scale.setScalar(PAWN_SCALE * (cur ? 1.12 : 1));
  o.ring.visible = cur;
  if (cur) o.ring.scale.setScalar(1 + Math.sin(t * 6) * 0.08);

  // pislogás
  if (t > o.blinkAt) {
    const b = t - o.blinkAt;
    const sc = b < 0.12 ? 0.1 : 1;
    o.ch.eyes.forEach((e) => { e.scale.y = sc; });
    if (b > 0.12) o.blinkAt = t + 2 + Math.random() * 3;
  }
  o.ch.tick(t + o.phase);
}

let lastT = 0;
// ---------------------------------------------------------------- rajz
// st = { pawns: [{p, x, y, h, current}], crown: {x, y, h} | null, t }
export function render(st) {
  if (!ok) return;
  syncSize();
  const dt = Math.min(0.05, Math.max(0, st.t - lastT));
  lastT = st.t;
  const seen = new Set();
  let curPos = null;
  for (const d of st.pawns) {
    const o = pawnFor(d.p);
    seen.add(d.p.pid);
    animatePawn(o, d, st.t, dt);
    if (d.current) curPos = o.group.position;
  }
  for (const [pid, o] of pawns) if (!seen.has(pid)) { scene.remove(o.group); pawns.delete(pid); }
  marker.visible = !!curPos;
  if (curPos) {
    marker.position.set(curPos.x, curPos.y + 1.9 + Math.sin(st.t * 5) * 0.1, curPos.z);
    marker.rotation.y = st.t * 2.5;
  }

  if (st.crown) {
    const w = toWorld(st.crown.x, st.crown.y, st.crown.h);
    crown.visible = crownLight.visible = true;
    crown.position.set(w.x, w.y + 0.9 + Math.sin(st.t * 3) * 0.12, w.z);
    crown.rotation.y = st.t * 1.4;
    crownLight.position.set(w.x, w.y + 1.2, w.z);
    crownGlow.visible = st.crown.h < 5;
    crownGlow.position.set(w.x, 0.28, w.z);
    crownGlow.material.opacity = 0.35 + Math.sin(st.t * 4) * 0.25;
    crownGlow.scale.setScalar(1 + Math.sin(st.t * 4) * 0.08);
  } else {
    crown.visible = crownLight.visible = crownGlow.visible = false;
  }
  for (const f of animated) f(st.t);
  renderer.render(scene, camera);
}
