// Island 3 — Prince's Island, Calgary. "Golden hour that never quite ends."
// Oreo's hometown, and where he joins. Layout, flags and riddle logic mirror the
// Godot island (scripts/islands/calgary.gd, bow_breeze.gd, puzzles/paper_regatta,
// ice_cream_round, bridge_kite, gopher_semaphore, offleash_howl).
import * as THREE from 'three';
import { G, rng, clamp, fbm, ease, V3 } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';
import { makeWaterMaterial } from '../engine/render.js';

const WATER = -0.4;
const COAST_BASE = 46;
const PATH_R = 16;
const LAG = { x: -11, z: -1, rx: 7.5, rz: 5.5 };
const PARK_GREEN = '#2a6b4c', WOOD = '#80614a', RED = '#c72a24';
const BRIDGE = { x: -11, z0: LAG.z - LAG.rz - 1.5, z1: LAG.z + LAG.rz + 1.5 };
// Paper Regatta
const PLANK = V3(-6.2, 0.42, 3.6), LEVER = V3(-10, 0.35, 5.2), WEIR = V3(-11, WATER, 1.4), CLAPPER = V3(-15.75, 0.3, -1.9);
const FLOAT = WATER + 0.02;
const ROUTE = [V3(-7.7, FLOAT, 2.3), V3(-9, FLOAT, 1.0), V3(-11, FLOAT, -0.2), V3(-13.4, FLOAT, -1.0), V3(-15.2, FLOAT, -1.4)];
// Weir board heights (relative to the water): down in the channel, or lifted clear.
const BOARD_DOWN = 0.0, BOARD_UP = 0.62;
// Ice Cream Round
const CART = V3(3, 0.35, 14), RING_TARGET = 4, RING_WINDOW = 6;
// Bridge & kite
const KITE = V3(-11, 3.1, -1), JUG = V3(-12.2, 0.05, 3.9);
// Gophers
const TABLE = V3(13, 0.35, 6.5), PULSE = 2.2;
// Off-leash meadow
// The cottonwood's trunk is ~1.5m in radius (roots to 2m), so everything sits clear of it.
const TREE = V3(0, 0.35, -27), TRUNK_R = 1.5, BENCH = V3(-3.2, 0.35, -28.8), STONE = V3(3.2, 0.35, -27.9), OREO_HOME = V3(2.2, 0.35, -24.6);
const GATE = V3(0, 0.35, -23);
const UNWIND = ['stone', 'bench', 'tree'];
const CANOE = V3(3.2, 0.32, 38.5);

// ui.say() cancels the previous caption's timer, so an interrupted await would
// hang; race it against the game clock instead.
const say = (text, dur = 3) => Promise.race([G.ui.say(text, { dur }), G.wait(dur + 0.25)]);
const wrap = (a) => { while (a > Math.PI) a -= Math.PI * 2; while (a < -Math.PI) a += Math.PI * 2; return a; };
const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

export default class Calgary extends Island {
  static id = 'calgary';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 0, r: 60 };
    this.phase = 'calm';
  }

  models() { return ['tree_leafy', 'icecart', 'gopher', 'canoe', 'oreo']; }
  sounds() { return ['park_birds', 'brook', 'howl', 'bark', 'whimper', 'bell_ding', 'coconut_thunk', 'wood_creak', 'stone_slide', 'splash', 'breeze_gust', 'swim_stroke', 'crab_snip']; }
  atmosphere() {
    return { sky: '#f4d6a4', fog: '#efd6ae', fogNear: 55, fogFar: 175, sun: '#ffdcae', sunIntensity: 2.3, hemi: 1.15, skyLight: '#fff0d4', groundLight: '#6b7a4a', sunDir: [18, 15, 20], exposure: 1.08 };
  }
  music() { return 'calgary'; }

  // ── Ground ─────────────────────────────────────────────
  coast(theta) {
    let wob = 2.6 * Math.sin(3 * theta + 1.7) + 1.7 * Math.sin(5 * theta + 4.2) + 1.1 * Math.sin(8 * theta + 0.9);
    wob *= ss(0.55, 1.1, Math.abs(wrap(theta - Math.PI / 2)));
    return COAST_BASE + wob;
  }
  lagD(x, z) { return Math.hypot((x - LAG.x) / LAG.rx, (z - LAG.z) / LAG.rz); }
  height(x, z) {
    const d = Math.hypot(x, z), coast = this.coast(Math.atan2(z, x));
    if (d >= coast) return -6 * clamp((d - coast) / 12, 0, 1);
    let h = 0.35 * (1 - ss(coast - 4, coast - 1.5, d));
    // The lagoon: a real pond, swimming-deep in the middle (bed ~1.5m under the
    // surface), with sandy banks she can wade out of.
    h -= 2.3 * (1 - ss(0.42, 1.0, this.lagD(x, z)));
    let fringe = ss(26, 30, d) * (1 - ss(coast - 7, coast - 4, d));
    if (z < -19 || (Math.abs(x) < 5 && z > 8)) fringe = 0;
    h += fringe * 0.38 * (0.5 + 0.5 * Math.sin(x * 0.17 + 1.3) * Math.sin(z * 0.15 + 2.1));
    h += 0.85 * (1 - ss(3, 8, Math.hypot(x - 27, z - 6)));
    return h;
  }
  isPath(x, z) {
    const d = Math.hypot(x, z);
    if (this.lagD(x, z) < 0.98) return false; // the boardwalk carries the ring path over the lagoon
    if (Math.abs(d - PATH_R) < 1.1) return true;
    if (Math.abs(x) < 1.3 && z > PATH_R && z < 40) return true;
    if (Math.abs(x) < 1.1 && z < -PATH_R && z > -22.5) return true;
    return false;
  }
  splat(x, z) {
    const d = Math.hypot(x, z), coast = this.coast(Math.atan2(z, x));
    const sand = clamp((d - (coast - 4.5)) / 2, 0, 1);
    const lag = 1 - ss(0.75, 1.05, this.lagD(x, z));
    const path = this.isPath(x, z) ? 1 : 0;
    const s = Math.max(sand, lag);
    return [s * (1 - path), (1 - s) * (1 - path), path];
  }
  terrainTextures() { return ['sand.jpg', 'grass.jpg', 'cobble.jpg']; }
  tint(x, z) {
    const h = this.height(x, z);
    const c = new THREE.Color('#ffffff');
    if (h < WATER) c.lerp(new THREE.Color('#4aa0a0'), clamp((WATER - h) / 4, 0, 0.8));
    if (this.lagD(x, z) < 1.05 && h < 0.3) c.lerp(new THREE.Color('#b8c8b0'), 0.35);
    else c.lerp(new THREE.Color('#ffe8b8'), 0.12); // golden light on the lawns
    c.multiplyScalar(0.93 + fbm(x * 0.15, z * 0.15) * 0.12);
    return c;
  }
  footstep(x, z) { return this.splat(x, z)[1] > 0.5 ? 'paw_grass' : 'paw_sand'; }
  dustColor(x, z) { return this.splat(x, z)[1] > 0.5 ? '#9bd27a' : '#e6d6b0'; }

  spawn() { return { x: 0, z: 46.5, rotY: Math.PI, y: 0.36 }; }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 128, res: 150, repeat: 0.2 });
    this.makeWater({ level: WATER, size: 320, res: 120, colors: { deep: '#3aaeb0', light: '#8ddcd2', foam: '#f4fff8' } });
    this.buildLagoon();
    this.buildBridge();
    this.buildBoardwalk();
    this.buildDock();
    this.buildPark();
    this.buildHorizon();
    this.buildBreeze();
    this.buildRegatta();
    this.buildIceCream();
    this.buildKite();
    this.buildGophers();
    this.buildMeadow();
    this.buildCanoe();
    this.places([
      [V3(0, 0, 15), 6, 'The Landing'], [V3(LAG.x, 0, LAG.z), 8, 'The Lagoon'], [V3(-11, 0, -7), 4, 'The Peace Bridge'],
      [V3(14, 0, 1), 6, 'The Gopher Lawn'], [V3(8, 0, 5), 5, 'The Bandstand'], [V3(0, 0, -27), 7, 'The Off-Leash Meadow'],
    ]);
    G.audio.ambient('park_birds', 0.22);
    this.every(() => {
      const p = G.player.pos;
      G.audio.ambient('brook', clamp(1 - Math.hypot(p.x + 5.5, p.z - 3.5) / 12, 0, 1) * 0.3);
    });
  }

  places(list) {
    for (const [pos, r, name] of list) this.trigger({ pos, radius: r, once: true, onEnter: () => G.ui.showBanner(`~ ${name} ~`, 2.2) });
  }

  buildLagoon() {
    // The lagoon shares the island's water level, so she swims in it, but gets
    // its own finer, greener surface: the sea plane's 2.7m grid is too coarse
    // to draw a foam line around a pond. Punch the sea plane out underneath.
    const sea = this.water.geometry.attributes.position;
    for (let i = 0; i < sea.count; i++) if (this.lagD(sea.getX(i), sea.getZ(i)) < 1.45) sea.setY(i, -6);
    sea.needsUpdate = true;
    const RINGS = 22, SEGS = 72, pos = [], shore = [], idx = [];
    for (let r = 0; r <= RINGS; r++) {
      const k = (r / RINGS) * 1.12;
      for (let sgi = 0; sgi < SEGS; sgi++) {
        const a = (sgi / SEGS) * Math.PI * 2;
        const x = LAG.x + Math.cos(a) * LAG.rx * k, z = LAG.z + Math.sin(a) * LAG.rz * k;
        pos.push(x, WATER, z);
        const d = WATER - this.height(x, z);
        shore.push(d < 0 ? 1 : Math.max(0, 1 - d / 0.5));
        if (r) {
          const a0 = (r - 1) * SEGS + sgi, a1 = (r - 1) * SEGS + ((sgi + 1) % SEGS);
          const b0 = r * SEGS + sgi, b1 = r * SEGS + ((sgi + 1) % SEGS);
          idx.push(a0, a1, b0, a1, b1, b0);
        }
      }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('shore', new THREE.Float32BufferAttribute(shore, 1));
    geo.setIndex(idx);
    const pondMat = makeWaterMaterial({ deep: '#1b6672', light: '#3f9c98', foam: '#e8f8ee', scale: 0.16, opacity: 0.94 });
    const pond = new THREE.Mesh(geo, pondMat);
    pond.renderOrder = 1;
    this.add(pond);
    this.pond = pond;
    this.every(() => { pondMat.uniforms.uTime.value = G.time; });
    // Reeds around the rim, and lily pads.
    const R = rng(391);
    const deco = new THREE.Group();
    for (let i = 0; i < 40; i++) {
      const a = R.range(0, 6.28), k = R.range(0.92, 1.08);
      const x = LAG.x + Math.cos(a) * LAG.rx * k, z = LAG.z + Math.sin(a) * LAG.rz * k;
      if (Math.abs(x - BRIDGE.x) < 2) continue;
      const reed = P.cyl(0.025, 0.035, R.range(0.6, 1.1), '#6e8a3c', { seg: 4 });
      reed.position.set(x, this.height(x, z), z); reed.castShadow = false;
      deco.add(reed);
    }
    // Cattails standing in the shallows at the waterline.
    for (let i = 0; i < 46; i++) {
      const a = R.range(0, 6.28), k = R.range(0.74, 0.86);
      const x = LAG.x + Math.cos(a) * LAG.rx * k, z = LAG.z + Math.sin(a) * LAG.rz * k;
      if (Math.abs(x - BRIDGE.x) < 2.2 || Math.hypot(x - ROUTE[0].x, z - ROUTE[0].z) < 1.4 || Math.abs(Math.hypot(x, z) - PATH_R) < 1.3) continue;
      const y = this.height(x, z), tall = R.range(0.9, 1.5);
      const reed = P.cyl(0.02, 0.03, tall + (WATER - y), '#5f7f34', { seg: 4 });
      reed.position.set(x, y, z); reed.rotation.z = R.range(-0.08, 0.08); reed.castShadow = false;
      deco.add(reed);
      if (i % 3 === 0) { const head = P.cyl(0.045, 0.045, 0.2, '#6b4426', { seg: 5 }); head.position.set(x, WATER + tall - 0.05, z); head.castShadow = false; deco.add(head); }
    }
    for (let i = 0; i < 9; i++) {
      const a = R.range(0, 6.28), k = R.range(0.3, 0.68);
      const pad = P.cyl(0.22, 0.22, 0.02, '#4f8a3c', { seg: 10 });
      pad.position.set(LAG.x + Math.cos(a) * LAG.rx * k, WATER + 0.015, LAG.z + Math.sin(a) * LAG.rz * k);
      pad.castShadow = false; deco.add(pad);
    }
    this.add(P.bake(deco)); this.add(deco);
    // A mother duck and three ducklings lapping the lagoon.
    const ducks = [];
    const duck = (s, col) => {
      const g = new THREE.Group();
      const body = P.sphere(s, col, { seg: 10 }); body.scale.set(1, 0.75, 1.5); g.add(body);
      const head = P.sphere(s * 0.55, col, { seg: 8 }); head.position.set(0, s * 0.9, s * 1.1); g.add(head);
      const bill = P.box(s * 0.5, s * 0.2, s * 0.5, '#f0a030', { base: false }); bill.position.set(0, s * 0.8, s * 1.6); g.add(bill);
      this.add(g); return g;
    };
    ducks.push(duck(0.22, '#8c6a4c'));
    for (let i = 0; i < 3; i++) ducks.push(duck(0.1, '#ecd866'));
    this.every(() => {
      ducks.forEach((d, i) => {
        const t = G.time * 0.22 - i * 0.18;
        d.position.set(LAG.x + Math.cos(t) * LAG.rx * 0.5, WATER + 0.03, LAG.z + Math.sin(t) * LAG.rz * 0.5);
        d.rotation.y = -t;
      });
    });
  }

  deckY(z) {
    const t = (z - BRIDGE.z0) / (BRIDGE.z1 - BRIDGE.z0);
    if (t < 0 || t > 1) return null;
    return 0.3 + 0.95 * Math.sin(t * Math.PI);
  }

  buildBridge() {
    const g = new THREE.Group();
    const N = 26;
    const pos = [], idx = [];
    for (let i = 0; i < N; i++) {
      const t = i / (N - 1), z = BRIDGE.z0 + (BRIDGE.z1 - BRIDGE.z0) * t, y = this.deckY(z);
      pos.push(BRIDGE.x - 1.1, y, z, BRIDGE.x + 1.1, y, z);
      if (i) { const a = (i - 1) * 2; idx.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setIndex(idx); geo.computeVertexNormals();
    const deck = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ color: '#e2e2e6', side: THREE.DoubleSide }));
    deck.receiveShadow = true; deck.castShadow = true;
    this.add(deck);
    this.groundMeshes.push(deck);
    for (let i = 0; i < N - 1; i++) {
      const za = BRIDGE.z0 + (BRIDGE.z1 - BRIDGE.z0) * (i / (N - 1)), zb = BRIDGE.z0 + (BRIDGE.z1 - BRIDGE.z0) * ((i + 1) / (N - 1));
      const ya = this.deckY(za), yb = this.deckY(zb);
      const len = Math.hypot(zb - za, yb - ya) + 0.06, pitch = -Math.atan2(yb - ya, zb - za);
      for (const s of [-1, 1]) {
        const rail = P.box(0.08, 0.08, len, RED, { base: false });
        rail.position.set(BRIDGE.x + s * 1.08, (ya + yb) / 2 + 1.02, (za + zb) / 2); rail.rotation.x = pitch; g.add(rail);
        const low = P.box(0.06, 0.06, len, RED, { base: false });
        low.position.set(BRIDGE.x + s * 1.08, (ya + yb) / 2 + 0.1, (za + zb) / 2); low.rotation.x = pitch; g.add(low);
        if (i % 2 === 0) {
          const rib = P.box(0.055, 1.15, 0.055, RED, { base: false });
          rib.position.set(BRIDGE.x + s * 1.08, (ya + yb) / 2 + 0.55, (za + zb) / 2);
          rib.rotation.x = (i / 2) % 2 === 0 ? 0.45 : -0.45; g.add(rib);
        }
      }
    }
    for (let k = 0; k < 5; k++) {
      const t = (k + 0.5) / 5, z = BRIDGE.z0 + (BRIDGE.z1 - BRIDGE.z0) * t;
      const hoop = P.torus(1.46, 0.05, RED, { arc: Math.PI }); hoop.rotation.y = Math.PI / 2; hoop.position.set(BRIDGE.x, this.deckY(z) + 0.05, z); g.add(hoop);
    }
    this.add(P.bake(g)); this.add(g);
    // Walkable deck + its side rails so nobody walks off the edge.
    this.surface((x, z) => (Math.abs(x - BRIDGE.x) <= 1.05 ? this.deckY(z) : null));
    this.bridgeChalk();
  }

  /** Where the park's ring path meets the lagoon, it crosses on a low wooden boardwalk. */
  buildBoardwalk() {
    const A0 = 2.72, A1 = 3.6, W = 1.9, Y = 0.3;  // angles around the ring (west side)
    const g = new THREE.Group();
    const N = 22;
    for (let i = 0; i < N; i++) {
      const a = A0 + (A1 - A0) * ((i + 0.5) / N);
      const len = PATH_R * (A1 - A0) / N + 0.05;
      const plank = P.box(W, 0.1, len - 0.06, i % 2 ? '#8a6c50' : '#94765a');
      plank.position.set(Math.cos(a) * PATH_R, Y - 0.1, Math.sin(a) * PATH_R); plank.rotation.y = -a;
      g.add(plank);
    }
    for (let i = 0; i <= 8; i++) {
      const a = A0 + (A1 - A0) * (i / 8);
      for (const s of [-1, 1]) {
        const r = PATH_R + s * (W / 2 - 0.05), x = Math.cos(a) * r, z = Math.sin(a) * r;
        const post = P.cyl(0.07, 0.08, Y + 0.55 - Math.min(0, this.height(x, z)) + 0.2, '#6b5644', { seg: 6 });
        post.position.set(x, Math.min(this.height(x, z), Y) - 0.2, z); g.add(post);
      }
    }
    for (const s of [-1, 1]) {
      const r = PATH_R + s * (W / 2 - 0.05), pts = [];
      for (let i = 0; i <= 16; i++) { const a = A0 + (A1 - A0) * (i / 16); pts.push(V3(Math.cos(a) * r, Y + 0.5, Math.sin(a) * r)); }
      g.add(P.rope(pts, 0.035, '#7a5e46'));
      // Low rail colliders so nobody strolls off the side by accident (she can still hop over).
      for (let i = 0; i < 8; i++) {
        const a = A0 + (A1 - A0) * ((i + 0.5) / 8), rr = PATH_R + s * (W / 2 + 0.02);
        this.solidBox(Math.cos(a) * rr, Math.sin(a) * rr, 0.1, PATH_R * (A1 - A0) / 8 + 0.1, -3, Y + 0.55, a, { noStand: true });
      }
    }
    this.add(P.bake(g)); this.add(g);
    this.surface((x, z) => {
      const d = Math.hypot(x, z);
      if (Math.abs(d - PATH_R) > W / 2) return null;
      let a = Math.atan2(z, x); if (a < 0) a += Math.PI * 2;
      if (a < A0 || a > A1) return null;
      return Math.max(Y, this.height(x, z));
    });
  }

  bridgeChalk() {
    // The kids' chalk arrows daring you up and over.
    for (const z of [BRIDGE.z1 - 0.6, BRIDGE.z0 + 0.6]) {
      const arrow = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.9), new THREE.MeshBasicMaterial({ map: P.textCanvas('⬆', { w: 128, h: 128, bg: null, fg: 'rgba(255,255,255,0.85)', font: 'bold 110px sans-serif' }), transparent: true, depthWrite: false }));
      arrow.rotation.x = -Math.PI / 2; arrow.rotation.z = z > LAG.z ? 0 : Math.PI;
      arrow.position.set(BRIDGE.x, this.height(BRIDGE.x, z) + 0.03, z + (z > LAG.z ? 1.2 : -1.2));
      this.add(arrow);
    }
  }

  buildDock() {
    const g = new THREE.Group();
    for (let i = 0; i < 6; i++) {
      const p = P.box(2.4, 0.15, 1.7, '#8c7258', { round: 0.03 });
      p.position.set(0, 0.2 - i * 0.012, 40 + i * 1.8); g.add(p);
    }
    for (const s of [-1, 1]) for (let i = 0; i < 3; i++) { const post = P.cyl(0.12, 0.14, 1.6, '#6b5644'); post.position.set(s * 1.1, -1.0, 41 + i * 4); g.add(post); }
    this.add(P.bake(g)); this.add(g);
    this.surface((x, z) => (Math.abs(x) <= 1.2 && z >= 39 && z <= 50 ? 0.34 : null));
  }

  buildPark() {
    const deco = new THREE.Group();
    // Lamp posts around the ring.
    for (const a of [2.5, 3.3, 4.1, 4.9, 5.7, 0.2]) {
      // The one that would stand in the lagoon goes on the boardwalk instead.
      const wet = this.lagD(Math.cos(a) * 14, Math.sin(a) * 14) < 1.1, r = wet ? PATH_R - 0.72 : 14;
      const x = Math.cos(a) * r, z = Math.sin(a) * r, y = wet ? 0.3 : this.height(x, z);
      const post = P.cyl(0.05, 0.08, 2.8, PARK_GREEN); post.position.set(x, y, z); deco.add(post);
      const head = P.cyl(0.2, 0.28, 0.22, '#fff0c0', { emissive: '#ffd890', emissiveIntensity: 0.8 }); head.position.set(x, y + 2.8, z); deco.add(head);
      this.solidCyl(x, z, 0.12, -1, y + 2.8);
    }
    // Entrance sign.
    const sign = P.sign(["PRINCE'S ISLAND", 'PARK'], { w: 2.4, h: 0.9, post: 0.9, color: '#5a4636', font: 'bold 52px "Baloo 2", sans-serif' });
    sign.position.set(-3.6, this.height(-3.6, 17), 17); sign.rotation.y = 0.1;
    this.add(sign);
    // Bandstand.
    const bo = V3(8, 0.35, 5);
    const plat = P.cyl(2.7, 2.9, 0.35, '#b8a894'); plat.position.copy(bo); deco.add(plat);
    for (let k = 0; k < 6; k++) { const a = (Math.PI * 2 * k) / 6; const c = P.box(0.14, 2.3, 0.14, PARK_GREEN); c.position.set(bo.x + Math.cos(a) * 2.3, bo.y + 0.35, bo.z + Math.sin(a) * 2.3); deco.add(c); this.solidCyl(bo.x + Math.cos(a) * 2.3, bo.z + Math.sin(a) * 2.3, 0.1, 0, 3); }
    const roof = P.cone(3.2, 1.3, '#4c8080', { seg: 6 }); roof.position.set(bo.x, bo.y + 2.65, bo.z); deco.add(roof);
    this.solidCyl(bo.x, bo.z, 2.8, -1, bo.y + 0.35);
    // Benches ring the path, facing the lawn.
    for (const a of [2.7, 3.6, 4.4, 5.2, 6.0]) {
      const x = Math.cos(a) * (PATH_R + 2.2), z = Math.sin(a) * (PATH_R + 2.2);
      this.bench(deco, V3(x, this.height(x, z), z), Math.atan2(-x, -z));
    }
    // Picnic tables on the east lawn (the first hides the crayon map).
    for (const tp of [TABLE, V3(18, 0.35, 0.5), V3(11, 0.35, -4.5)]) this.picnicTable(deco, tp);
    // Flower beds.
    const R = rng(606);
    const cols = ['#e04a4a', '#f2c040', '#9a66c0', '#f08aa0'];
    for (const b of [V3(-3.2, 0, 17), V3(3.2, 0, 20), V3(-14, 0, 9), V3(9, 0, -13), V3(-4, 0, -15)]) {
      const y = this.height(b.x, b.z);
      const bed = P.box(2.0, 0.35, 1.2, '#8c7a66'); bed.position.set(b.x, y, b.z); deco.add(bed);
      this.solidBox(b.x, b.z, 2.0, 1.2, -1, y + 0.35);
      for (let k = 0; k < 7; k++) { const f = P.sphere(0.09, cols[R.int(0, 3)], { seg: 6 }); f.position.set(b.x + R.range(-0.8, 0.8), y + 0.42, b.z + R.range(-0.4, 0.4)); f.castShadow = false; deco.add(f); }
    }
    // Somebody's picnic, abandoned to the afternoon.
    const bl = V3(15.5, this.height(15.5, 9.5), 9.5);
    const blanket = P.box(1.7, 0.03, 1.3, '#cc5048'); blanket.position.copy(bl); deco.add(blanket);
    const basket = P.box(0.5, 0.35, 0.32, '#9c7a4c', { round: 0.04 }); basket.position.set(bl.x + 0.45, bl.y, bl.z - 0.3); deco.add(basket);
    const frisbee = P.cyl(0.26, 0.22, 0.05, '#4cc0d8'); frisbee.position.set(13.8, this.height(13.8, 8) + 0.02, 8); deco.add(frisbee);
    // Trash bins.
    for (const b of [V3(4.2, 0, 12.5), V3(14.5, 0, -3.5)]) { const bin = P.cyl(0.28, 0.24, 0.7, PARK_GREEN); bin.position.set(b.x, this.height(b.x, b.z), b.z); deco.add(bin); this.solidCyl(b.x, b.z, 0.3, -1, 1); }
    // Bushes.
    const RB = rng(4243);
    for (let i = 0; i < 30; i++) {
      const a = RB.range(0, 6.28), r = RB.range(19, 38);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      if (this.isPath(x, z) || this.lagD(x, z) < 1.2 || (z < -21 && Math.abs(x) < 9) || (z > 12 && Math.abs(x) < 7)) continue;
      const b = P.bush(RB.range(0.4, 0.75), RB() < 0.5 ? '#4f9a3a' : '#5fae4a', i); b.position.set(x, this.height(x, z), z); deco.add(b);
    }
    this.add(P.bake(deco)); this.add(deco);

    // Cottonwoods (instanced) with trunk colliders.
    const RT = rng(4242);
    const trees = [];
    for (let i = 0; i < 24; i++) {
      const a = RT.range(0, 6.28), r = RT.range(20, 39);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      if ((z > 12 && Math.abs(x) < 7) || (z < -20 && Math.abs(x) < 10) || this.isPath(x, z) || this.lagD(x, z) < 1.3) continue;
      if (Math.hypot(x - 27, z - 6) < 3) continue;
      const s = RT.range(0.8, 1.2);
      trees.push({ x, y: this.height(x, z) - 0.05, z, rotY: RT.range(0, 6.28), scale: s });
      this.solidCyl(x, z, 0.4 * s, -1, 5);
    }
    this.trees = this.add(instanced('tree_leafy', trees, { height: 6.5 }));
    // Grass tufts.
    const tufts = [];
    const RG = rng(3131);
    for (let i = 0; i < 1500; i++) {
      const x = RG.range(-38, 38), z = RG.range(-38, 38);
      const h = this.height(x, z);
      if (h < 0.3 || this.isPath(x, z) || this.splat(x, z)[1] < 0.6) continue;
      tufts.push([x, h, z, RG.range(0.6, 1.2), RG.range(0, 6)]);
    }
    const tg = new THREE.ConeGeometry(0.07, 0.32, 4); tg.translate(0, 0.16, 0);
    const im = new THREE.InstancedMesh(tg, P.mat('#6cb848'), tufts.length);
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3();
    tufts.forEach(([x, y, z, sc, r], i) => { q.setFromAxisAngle(V3(0, 1, 0), r); s.set(sc, sc, sc); m4.compose(V3(x, y, z), q, s); im.setMatrixAt(i, m4); });
    im.receiveShadow = true; this.add(im);
  }

  bench(group, pos, rotY) {
    const b = new THREE.Group(); b.position.copy(pos); b.rotation.y = rotY;
    const seat = P.box(1.5, 0.07, 0.45, PARK_GREEN); seat.position.y = 0.42; b.add(seat);
    const back = P.box(1.5, 0.5, 0.06, PARK_GREEN); back.position.set(0, 0.52, -0.24); back.rotation.x = -0.15; b.add(back);
    for (const sx of [-0.6, 0.6]) { const leg = P.box(0.08, 0.45, 0.4, '#3a3e3c'); leg.position.x = sx; b.add(leg); }
    group.add(b);
    this.solidBox(pos.x, pos.z, 1.5, 0.5, -1, pos.y + 0.48, -rotY);
    return b;
  }
  picnicTable(group, pos) {
    const y = this.height(pos.x, pos.z);
    const top = P.box(1.8, 0.08, 0.9, WOOD); top.position.set(pos.x, y + 0.74, pos.z); group.add(top);
    for (const s of [-1, 1]) {
      const seat = P.box(1.8, 0.07, 0.3, WOOD); seat.position.set(pos.x, y + 0.42, pos.z + s * 0.72); group.add(seat);
      const leg = P.box(0.09, 0.78, 0.8, '#6a5240'); leg.position.set(pos.x + s * 0.75, y, pos.z); group.add(leg);
    }
    this.solidBox(pos.x, pos.z, 1.8, 2.0, -1, y + 0.82);
  }

  buildHorizon() {
    const far = new THREE.Group();
    // Downtown across the water: towers, the Bow's glass crescent, the Calgary Tower, the Saddledome.
    const base = V3(78, 0, 70);
    const glass = P.mat('#9fb0c0', { emissive: '#b8c8d8', emissiveIntensity: 0.25 });
    for (const [x, z, w, h] of [[-24, 8, 7, 26], [-10, -4, 8, 34], [6, 6, 6, 22], [30, -2, 9, 30], [12, -16, 7, 40], [24, 14, 5, 24], [-18, 18, 5, 20]]) {
      const t = P.box(w, h, w, glass); t.position.set(base.x + x, -1, base.z + z); t.castShadow = false; far.add(t);
    }
    for (let k = 0; k < 3; k++) { const s = P.box(9, 37, 4, glass); s.position.set(base.x + 34 + (k - 1) * 7.5, -1, base.z - 12 - Math.abs(k - 1) * 2.5); s.rotation.y = (k - 1) * 0.3; s.castShadow = false; far.add(s); }
    const shaft = P.cyl(1.6, 2.4, 30, '#b8b4ae'); shaft.position.set(base.x + 16, -1, base.z + 2); far.add(shaft);
    const pod = P.cyl(3.6, 3.0, 3.6, '#c04c3c'); pod.position.set(base.x + 16, 29, base.z + 2); far.add(pod);
    const dome = P.cyl(8, 9.5, 5, '#a8a098'); dome.scale.x = 1.3; dome.position.set(base.x - 38, -1, base.z + 16); far.add(dome);
    // The Rockies, hazy on the west.
    const R = rng(403);
    for (let i = 0; i < 9; i++) {
      const z = -90 + i * 22 + R.range(-6, 6), h = R.range(30, 50);
      const m = P.cone(R.range(22, 32), h, '#8f9cbc', { seg: 6 }); m.position.set(-150 + R.range(-15, 15), -2, z); m.castShadow = false; far.add(m);
      const cap = P.cone(R.range(7, 10), h * 0.28, '#f4f6fa', { seg: 6 }); cap.position.set(m.position.x, h * 0.72 - 2, z); cap.castShadow = false; far.add(cap);
    }
    far.traverse((o) => { if (o.isMesh) o.castShadow = false; });
    this.add(far);
    // A hot-air balloon drifting over the river.
    const bal = new THREE.Group();
    const env = P.sphere(3.6, '#d8584c', { seg: 14 }); env.scale.y = 1.1; env.position.y = 4; bal.add(env);
    const band = P.cyl(3.4, 3.4, 1.2, '#f2e6c0'); band.position.y = 3.4; bal.add(band);
    const bask = P.box(1, 0.8, 1, '#7a5c3c'); bask.position.y = -1; bal.add(bask);
    bal.position.set(58, 26, -78); this.add(bal);
    this.every(() => { const t = (Math.sin(G.time * 0.03) + 1) / 2; bal.position.set(58 - 20 * t, 26 + 3 * t, -78 + 18 * t); });
  }

  // ── The Bow breeze: calm → one-beat warning → gust ─────
  buildBreeze() {
    this.phase = 'calm';
    G.fx.setWeather('fluff', { rate: 10, wind: [0.15, 0.05] });
    let t = 6, taught = false;
    const R = rng(626);
    const set = (ph) => {
      this.phase = ph;
      const w = G.fx.weather;
      if (ph === 'calm') { if (w) { w.rate = 10; w.wind = [0.15, 0.05]; } }
      if (ph === 'warning') {
        if (w) { w.rate = 70; w.wind = [2.6, 0.8]; }
        // The tell: a surge of fluff lifting right around her.
        const p = G.player.pos;
        for (let i = 0; i < 70; i++) {
          G.fx.spawn(p.x + (Math.random() - 0.5) * 16, p.y + 0.2 + Math.random() * 2.5, p.z + (Math.random() - 0.5) * 16,
            { vx: 1.5 + Math.random() * 2, vy: 0.6 + Math.random() * 0.8, vz: 0.4 + Math.random() * 0.5, gravity: -0.05, drag: 0.2, size: 0.14, life: 3.5, color: '#fffdf2', sway: 1.2 });
        }
        G.audio.sfx('breeze_gust', { vol: 0.75 });
        if (!taught) { taught = true; G.ui.toast('The fluff lifts. A breeze is coming!', '\u{1F343}'); }
      }
      if (ph === 'gust') { if (w) { w.rate = 85; w.wind = [3.6, 1.0]; } }
      for (const fn of this.breezeListeners) fn(ph);
    };
    this.breezeListeners = [];
    this.every((dt) => {
      t -= dt;
      if (t > 0) return;
      if (this.phase === 'calm') { set('warning'); t = 1.3; }
      else if (this.phase === 'warning') { set('gust'); t = R.range(5, 7.5); }
      else { set('calm'); t = R.range(9, 15); }
      this.breezeT = t;
    });
    // Trees and reeds lean with the wind.
    this.every(() => {
      const k = this.phase === 'gust' ? 1 : this.phase === 'warning' ? 0.5 : 0.1;
      if (this.trees) this.trees.rotation.z = Math.sin(G.time * 1.7) * 0.006 * k;
    });
    this.forceBreeze = (ph) => { set(ph); t = ph === 'gust' ? 999 : ph === 'calm' ? 999 : 1.3; };
  }
  isGusting() { return this.phase === 'gust'; }
  isCalm() { return this.phase === 'calm'; }

  // ── Riddle 1: the Paper Regatta ────────────────────────
  paperBoat() {
    const b = new THREE.Group();
    const hull = P.cone(0.2, 0.14, '#fbfbf6', { seg: 4, base: false }); hull.rotation.x = Math.PI; hull.scale.set(1.4, 1, 0.8); hull.position.y = 0.08; b.add(hull);
    const sail = P.cone(0.1, 0.18, '#ffffff', { seg: 3 }); sail.position.y = 0.08; b.add(sail);
    return b;
  }
  buildRegatta() {
    const g = new THREE.Group();
    const plank = P.box(1.6, 0.1, 0.9, '#9c8064'); plank.position.copy(PLANK).setY(PLANK.y - 0.05); g.add(plank);
    const stack = P.box(0.4, 0.12, 0.5, '#f4f4ee'); stack.position.copy(PLANK).add(V3(-0.4, 0.05, 0.1)); g.add(stack);
    // The kids' chalk clue drawn on the plank: fluff puffs → arrow → gate.
    const chalk = new THREE.Mesh(new THREE.PlaneGeometry(1.0, 0.35), new THREE.MeshBasicMaterial({ transparent: true, map: P.textCanvas('☁☁ → ⌂', { w: 256, h: 96, bg: null, fg: '#ffffff', font: 'bold 64px sans-serif' }) }));
    chalk.rotation.x = -Math.PI / 2; chalk.position.copy(PLANK).add(V3(0.2, 0.012, 0.25)); g.add(chalk);
    this.add(g);
    this.solidBox(PLANK.x, PLANK.z, 1.6, 0.9, -1, PLANK.y);
    this.interact({
      obj: plank, pos: PLANK.clone(), radius: 2.0, icon: '⛵', label: 'Fold a paper boat', use: () => this.launchBoat(),
    });
    this.sense(plank, { warm: () => !G.state.flag('regatta_done'), height: 0.3 });

    // The weir in the narrows: two posts and a board that lifts.
    const route = V3(-1, 0, -0.55).normalize();
    const across = V3(-route.z, 0, route.x);
    const wg = new THREE.Group(); wg.position.copy(WEIR); wg.rotation.y = Math.atan2(across.x, across.z) + Math.PI / 2;
    // Posts are driven into the lagoon bed; the board rides between them.
    for (const s of [-1, 1]) { const post = P.box(0.14, 2.6, 0.14, '#6e5a46'); post.position.set(s * 0.9, -1.9, 0); wg.add(post); }
    const board = P.box(1.7, 0.45, 0.08, '#8c7458', { base: false }); board.position.y = BOARD_DOWN; wg.add(board);
    this.add(wg);
    this.weirBoard = board;
    this.sluiceOpen = G.state.flag('regatta_done');
    if (this.sluiceOpen) board.position.y = BOARD_UP;
    wg.updateMatrixWorld(true);
    for (const s of [-1, 1]) { const q = wg.localToWorld(V3(s * 0.9, 0, 0)); this.solidCyl(q.x, q.z, 0.12, -3, WATER + 0.7); }
    this.weirSolid = this.solidBox(WEIR.x, WEIR.z, 1.7, 0.14, -3, WATER + 0.22, -wg.rotation.y, { noStand: true });
    this.weirSolid.enabled = !this.sluiceOpen;
    const lever = new THREE.Group(); lever.position.copy(LEVER);
    const base = P.box(0.3, 0.5, 0.3, '#6e5a46'); lever.add(base);
    const arm = P.box(0.07, 0.7, 0.07, '#b84c3c', { base: false }); arm.geometry.translate(0, 0.35, 0); arm.position.set(0, 0.5, 0); arm.rotation.z = this.sluiceOpen ? 0.5 : -0.5; lever.add(arm);
    const knob = P.sphere(0.07, '#b84c3c'); knob.position.y = 0.7; arm.add(knob);
    this.add(lever);
    this.leverArm = arm;
    this.solidCyl(LEVER.x, LEVER.z, 0.25, -1, LEVER.y + 0.5);
    this.interact({ obj: lever, radius: 1.8, icon: '\u{1F6B0}', label: () => (this.sluiceOpen ? 'Close the little weir' : 'The little weir’s lever'), use: () => this.toggleSluice() });
    this.sense(lever, { warm: () => !G.state.flag('regatta_done') && !this.sluiceOpen, height: 0.6 });

    // Becalmed paper boats.
    for (const p of [V3(-8.5, FLOAT, -3.2), V3(-13.5, FLOAT, 2.0), V3(-11.8, FLOAT, -4.0)]) {
      const b = this.paperBoat(); b.position.copy(p); b.rotation.y = Math.random() * 6; this.add(b);
      const ph = Math.random() * 6;
      this.every(() => { b.position.y = p.y + Math.sin(G.time * 1.3 + ph) * 0.02; b.rotation.z = this.phase === 'gust' ? Math.sin(G.time * 6 + ph) * 0.15 : 0; });
    }
    if (G.state.flag('regatta_done') && !G.state.flag('took_brass_clapper') && !G.state.flag('bell_fixed')) this.spawnClapper();
  }
  toggleSluice() {
    this.sluiceOpen = !this.sluiceOpen;
    G.audio.sfx('wood_creak', { vol: 0.6, rate: 1.1 });
    G.tween(this.weirBoard.position, { y: this.sluiceOpen ? BOARD_UP : BOARD_DOWN }, 0.7, ease.inOut);
    this.weirSolid.enabled = !this.sluiceOpen;
    G.tween(this.leverArm.rotation, { z: this.sluiceOpen ? 0.5 : -0.5 }, 0.5);
    G.ui.toast(`The weir board ${this.sluiceOpen ? 'lifts clear of the water' : 'drops back into the narrows'}.`, '\u{1F6B0}');
  }
  launchBoat() {
    if (G.state.flag('regatta_done')) { G.ui.say('The regatta is won. The lagoon keeps the paper fleet as a monument.'); return; }
    if (this.sailing) { G.ui.say('Her boat is still out there, doing its best.'); return; }
    const boat = this.paperBoat();
    boat.position.copy(ROUTE[0]);
    this.add(boat);
    G.player.emote('pickup', 2.4);
    G.audio.sfx('paper_open', { vol: 0.6, rate: 1.2 });
    if (!this.isGusting()) {
      G.tween(boat.position, { x: ROUTE[0].x + 0.3, z: ROUTE[0].z + 0.2 }, 2.2, ease.inOut)
        .then(() => G.tween(boat.position, { x: ROUTE[0].x, z: ROUTE[0].z }, 2.2, ease.inOut))
        .then(() => boat.removeFromParent());
      G.ui.say('The boat bobs and goes nowhere. The fluff hangs dead still in the air.');
      return;
    }
    this.sailing = true;
    if (!this.sluiceOpen) {
      const jam = WEIR.clone().add(V3(0.5, 0, 0.4));
      G.tween(boat.position, { x: ROUTE[1].x, z: ROUTE[1].z }, 2.0)
        .then(() => G.tween(boat.position, { x: jam.x, z: jam.z }, 1.6, ease.out))
        .then(() => G.tween(boat.rotation, { y: 1.4 }, 1.0))
        .then(() => {
          this.sailing = false; boat.removeFromParent();
          G.ui.say('The boat rides the breeze straight into the weir board, and sulks in the reeds.');
        });
      return;
    }
    (async () => {
      for (const wp of ROUTE.slice(1)) {
        boat.rotation.y = Math.atan2(wp.x - boat.position.x, wp.z - boat.position.z);
        await G.tween(boat.position, { x: wp.x, z: wp.z }, 1.5);
      }
      this.sailing = false;
      boat.removeFromParent();
      G.state.set('regatta_done');
      G.audio.sfx('pickup_chime', { vol: 0.6, rate: 1.1 });
      this.spawnClapper();
      G.ui.celebrate('Under the bridge!', 'The Paper Regatta');
      G.ui.say('Under the red bridge and gone! The west reeds stir, and something small and brass washes loose.');
    })();
  }
  spawnClapper() {
    // Washed up on the boardwalk planks, right where the boat slipped away.
    this.pickup({ id: 'brass_clapper', pos: V3(CLAPPER.x, this.groundAt(CLAPPER.x, CLAPPER.z, 1), CLAPPER.z) });
  }

  // ── Riddle 2: the Ice Cream Round ─────────────────────
  buildIceCream() {
    const cart = model('icecart', { height: 2.5, rotY: -Math.PI / 2 });
    cart.position.copy(CART);
    this.add(cart);
    this.solidBox(CART.x, CART.z, 1.9, 1.2, -1, CART.y + 1.3);
    // Four painted note dots on the flank — the vendor's round.
    const notes = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 0.45), new THREE.MeshLambertMaterial({
      transparent: true, map: P.textCanvas('♪ ♪ ♪ ♪', { w: 384, h: 144, bg: '#fff8e8', fg: '#2a3e7a', border: '#2a3e7a', font: 'bold 84px sans-serif', radius: 30 }),
    }));
    notes.position.set(CART.x, CART.y + 0.95, CART.z + 0.66);
    this.add(notes);
    const hatch = P.box(0.9, 0.55, 0.06, '#d9d4c8', { round: 0.02 });
    hatch.position.set(CART.x, CART.y + 0.18, CART.z + 0.64);
    this.add(hatch);
    this.hatch = hatch;
    if (G.state.flag('ice_cream_done')) hatch.position.y = CART.y - 0.1;
    this.bellPos = V3(CART.x + 0.45, CART.y + 2.0, CART.z + 0.2);
    this.rings = 0; this.windowLeft = 0;
    this.interact({
      pos: V3(CART.x, CART.y, CART.z + 0.9), obj: cart, radius: 2.2, icon: '\u{1F514}',
      label: () => (G.state.flag('ice_cream_done') ? 'Ring the bell' : G.state.flag('bell_fixed') ? 'Ring the cart’s bell' : G.state.has('brass_clapper') ? 'Fit the brass clapper' : 'The cart’s little bell'),
      use: () => this.bellUse(),
    });
    this.sense(notes, { warm: () => G.state.flag('bell_fixed') && !G.state.flag('ice_cream_done'), height: 0 });
    this.every((dt) => {
      if (this.windowLeft > 0) { this.windowLeft -= dt; if (this.windowLeft <= 0) this.judgeRound(); }
    });
    if (G.state.flag('ice_cream_done')) this.spawnCartGoods();
  }
  ring(rate) {
    G.audio.sfx('bell_ding', { pos: this.bellPos, vol: 1, rate, minGap: 0.02 });
    G.fx.ring(this.bellPos, '#ffe48a', 1.6, 0.55, this.bellPos.y);
    G.fx.sparkle(this.bellPos, '#ffe48a', 3);
  }
  bellUse() {
    if (G.state.flag('ice_cream_done')) { this.ring(1); G.ui.say('The bell rings bright and clear. Somewhere, an old routine smiles.'); return; }
    if (!G.state.flag('bell_fixed')) {
      G.audio.sfx('coconut_thunk', { vol: 0.5, rate: 1.7 });
      if (G.state.has('brass_clapper')) {
        G.state.take('brass_clapper');
        G.state.set('bell_fixed');
        this.ring(0.9);
        G.ui.say('The clapper seats with a click. The bell has its voice back, and the cart wears four painted notes.');
        return;
      }
      G.ui.say('A little brass bell, silent. Its clapper is missing, and the lagoon keeps its secrets.');
      return;
    }
    this.rings++;
    this.ring(1 + 0.04 * this.rings);
    if (this.rings === 1) this.windowLeft = RING_WINDOW;
    else if (this.rings > RING_TARGET) this.windowLeft = 0.001;
  }
  judgeRound() {
    const rings = this.rings;
    this.rings = 0; this.windowLeft = 0;
    if (rings === RING_TARGET) {
      G.state.set('ice_cream_done');
      G.audio.sfx('stone_slide', { vol: 0.5, rate: 1.3 });
      G.tween(this.hatch.position, { y: CART.y - 0.1 }, 0.8, ease.inOut);
      this.spawnCartGoods();
      G.ui.celebrate('The round lands!', 'The Ice Cream Round');
      G.ui.say('The hatch pops: a bag of biscuits, and a spare key with a paw drawn on the tag.');
    } else {
      G.audio.sfx('whisker_shimmer', { vol: 0.5, rate: 0.7 });
      G.ui.say('The bell fades to quiet. Four notes are painted on the flank. Ring the round just so.');
    }
  }
  spawnCartGoods() {
    const y = this.height(CART.x, CART.z + 1.2);
    this.pickup({ id: 'dog_biscuits', pos: V3(CART.x - 0.45, y, CART.z + 1.2) });
    this.pickup({ id: 'paw_key', pos: V3(CART.x + 0.5, y, CART.z + 1.2) });
  }

  // ── Riddle 3: the Bridge and the Kite ─────────────────
  buildKite() {
    if (G.state.flag('kite_freed')) {
      if (!G.state.flag('took_cream_jug') && !G.state.flag('oreo_fed')) this.spawnJug();
      return;
    }
    const kite = new THREE.Group();
    const sh = new THREE.Shape(); sh.moveTo(0, 0.42); sh.lineTo(0.3, 0); sh.lineTo(0, -0.5); sh.lineTo(-0.3, 0); sh.closePath();
    const body = new THREE.Mesh(new THREE.ShapeGeometry(sh), P.mat('#ff6b4a', { side: THREE.DoubleSide }));
    kite.add(body);
    const cross = P.box(0.6, 0.02, 0.02, '#6b4a2c', { base: false }); kite.add(cross);
    for (let i = 0; i < 3; i++) { const bow = P.box(0.12, 0.04, 0.03, ['#ffd24a', '#1fb5c9', '#ffd24a'][i], { base: false }); bow.position.set(0, -0.6 - i * 0.2, 0.03 * (i % 2)); kite.add(bow); }
    kite.position.copy(KITE);
    kite.rotation.y = Math.PI / 2;
    this.add(kite);
    this.kite = kite;
    const from = KITE.clone().add(V3(0, -0.4, 0)), to = JUG.clone().add(V3(0, 0.15, 0));
    const str = P.rope([from, from.clone().lerp(to, 0.5).add(V3(0, -0.1, 0)), to], 0.012, '#f0ecdc');
    this.add(str);
    this.kiteString = str;
    const jugStub = P.cyl(0.11, 0.13, 0.28, '#f2eee2'); jugStub.position.copy(JUG).setY(this.height(JUG.x, JUG.z)); this.add(jugStub);
    this.jugStub = jugStub;
    this.every(() => {
      if (!this.kite) return true;
      const k = this.phase === 'gust' ? 2.2 : this.phase === 'warning' ? 1.3 : 0.4;
      kite.rotation.z = Math.sin(G.time * 5 * k) * 0.3 * k;
      kite.position.y = KITE.y + Math.abs(Math.sin(G.time * 3 * k)) * 0.2 * k;
    });
    this.kiteIt = this.interact({
      pos: KITE.clone().setY(1.3), radius: 1.9, yRange: 1.0, icon: '\u{1FA81}', label: 'Grab for the kite', use: () => this.grabKite(),
    });
    this.pickable(kite, this.kiteIt);
    this.sense(kite, { warm: () => true, height: 0, radius: 14 });
  }
  grabKite() {
    if (G.state.flag('kite_freed')) return;
    if (this.isGusting()) {
      G.audio.sfx('whisker_shimmer', { vol: 0.5, rate: 1.2 });
      G.tween(this.kite.position, { x: KITE.x + 0.6, y: KITE.y + 0.5, z: KITE.z - 0.4 }, 0.25).then(() => G.tween(this.kite.position, { x: KITE.x, y: KITE.y, z: KITE.z }, 0.4));
      G.ui.say('The kite whips away from her paws! It only rests when the fluff rests.');
      return;
    }
    G.state.set('kite_freed');
    G.player.emote('happy', 2.2);
    G.audio.sfx('pickup_chime', { vol: 0.6, rate: 1.2 });
    const kite = this.kite; this.kite = null;
    this.removeInteract(this.kiteIt);
    G.tween(kite.position, { y: KITE.y + 0.8 }, 0.8, ease.out)
      .then(() => G.tween(kite.position, { x: KITE.x + 8, y: KITE.y + 14, z: KITE.z + 30 }, 5, ease.in))
      .then(() => kite.removeFromParent());
    G.tween(this.kiteString.position, { y: -1.2 }, 1.0, ease.in).then(() => {
      this.kiteString.removeFromParent(); this.jugStub.removeFromParent();
      this.spawnJug();
    });
    G.ui.celebrate('The kite flies free!', 'The Bridge and the Kite');
    G.ui.say('The kite lifts free and sails for the mountains. Its string splashes down by the south shallows, tied to something.');
  }
  spawnJug() {
    const jug = new THREE.Group();
    const body = P.cyl(0.11, 0.13, 0.28, '#f2eee2'); jug.add(body);
    const neck = P.cyl(0.05, 0.08, 0.1, '#f2eee2'); neck.position.y = 0.28; jug.add(neck);
    this.pickup({ id: 'cream_jug', pos: V3(JUG.x, Math.max(this.height(JUG.x, JUG.z), WATER), JUG.z), obj: jug, bob: false });
  }

  // ── Riddle 4: the Gopher Semaphore ────────────────────
  buildGophers() {
    const R = rng(5050);
    this.mounds = [];
    for (let i = 0; i < 6; i++) {
      let x, z, tries = 0;
      do { x = R.range(9, 20); z = R.range(-6, 8); tries++; } while (tries < 30 && (this.mounds.some((m) => Math.hypot(m.x - x, m.z - z) < 3.2) || Math.hypot(x - TABLE.x, z - TABLE.z) < 2.2 || Math.hypot(x - 18, z - 0.5) < 2 || Math.hypot(x - 11, z + 4.5) < 2 || Math.hypot(x - 8, z - 5) < 3.4));
      const m = V3(x, this.height(x, z), z);
      this.mounds.push(m);
      const mound = P.cyl(0.4, 0.5, 0.12, '#9c8466'); mound.position.copy(m); this.add(mound);
      const hole = P.cyl(0.16, 0.16, 0.02, '#2a2018'); hole.position.copy(m).add(V3(0, 0.12, 0)); hole.castShadow = false; this.add(hole);
      this.sense(mound, { warm: () => G.state.flag('gopher_map_seen') && !G.state.flag('gopher_semaphore_done') && this.mounds[this.order[this.gProgress]] === m, height: 0.3 });
    }
    const Ro = rng(8181);
    const idx = [0, 1, 2, 3, 4, 5];
    for (let i = 0; i < idx.length; i++) { const j = Ro.int(0, idx.length - 1); [idx[i], idx[j]] = [idx[j], idx[i]]; }
    this.order = idx;
    this.gProgress = 0;
    // Idle peeking.
    let next = 2;
    this.every((dt) => {
      next -= dt;
      if (next > 0) return;
      next = 3 + Math.random() * 4;
      this.peek(this.mounds[Math.floor(Math.random() * 6)], false, 1.2);
    });
    // The crayon map taped under the first picnic table.
    const paper = P.box(0.5, 0.02, 0.36, '#f6eed8'); paper.position.set(TABLE.x + 0.2, this.height(TABLE.x, TABLE.z) + 0.7, TABLE.z + 0.1); paper.rotation.z = 0.06;
    this.add(paper);
    this.interact({ pos: TABLE.clone(), obj: paper, radius: 2.0, icon: '\u{1F5FA}️', label: 'Peek under the picnic table', use: () => this.showMap() });
    this.sense(paper, { warm: () => !G.state.flag('gopher_semaphore_done'), height: 0.2 });
    this.onVocal((e) => {
      if (e.kind !== 'meow' || G.state.flag('gopher_semaphore_done')) return;
      let near = -1, best = PULSE;
      this.mounds.forEach((m, i) => { const d = Math.hypot(e.pos.x - m.x, e.pos.z - m.z); if (d < best) { best = d; near = i; } });
      if (near < 0) return;
      G.fx.ring(this.mounds[near], '#ffd24a', 1.0, 0.6, this.mounds[near].y + 0.14);
      if (near === this.order[this.gProgress]) {
        this.gProgress++;
        G.audio.sfx('pickup_chime', { vol: 0.5, rate: 0.8 + 0.12 * this.gProgress });
        this.peek(this.mounds[near], true);
        if (this.gProgress >= 6) this.semaphoreWon();
      } else {
        if (this.gProgress > 0) G.ui.say('A gopher pops up, chirps something extremely rude, and the order is lost.');
        this.peek(this.mounds[near], false);
        this.gProgress = 0;
        if (near === this.order[0]) { this.gProgress = 1; this.peek(this.mounds[near], true); }
      }
    });
    if (G.state.flag('gopher_semaphore_done') && !G.state.flag('took_tennis_ball') && !G.state.flag('oreo_joined')) this.spawnBall();
  }
  peek(m, happy, hold) {
    const gph = model('gopher', { height: 0.5 });
    gph.position.set(m.x, m.y - 0.45, m.z);
    gph.rotation.y = Math.atan2(G.player.pos.x - m.x, G.player.pos.z - m.z);
    this.add(gph);
    if (!happy && hold == null) G.audio.sfx('crab_snip', { pos: m, vol: 0.4, rate: 1.6 });
    G.tween(gph.position, { y: m.y + 0.1 }, 0.2, ease.outBack)
      .then(() => G.wait(hold ?? (happy ? 0.6 : 1.0)))
      .then(() => G.tween(gph.position, { y: m.y - 0.5 }, 0.18))
      .then(() => gph.removeFromParent());
  }
  showMap() {
    G.state.set('gopher_map_seen');
    const xs = this.mounds.map((m) => m.x), zs = this.mounds.map((m) => m.z);
    const minX = Math.min(...xs), maxX = Math.max(...xs), minZ = Math.min(...zs), maxZ = Math.max(...zs);
    const c = document.createElement('canvas'); c.width = 560; c.height = 440;
    const g = c.getContext('2d');
    g.fillStyle = '#fbf3df'; g.fillRect(0, 0, 560, 440);
    g.fillStyle = '#c84c3c'; g.font = 'bold 30px "Comic Sans MS", "Chalkboard SE", sans-serif'; g.textAlign = 'center';
    g.fillText('gofer town secret nock order!!', 280, 44);
    g.strokeStyle = '#6aa84c'; g.lineWidth = 3;
    for (let i = 0; i < 40; i++) { const x = (i * 97) % 520 + 20, y = (i * 53) % 330 + 80; g.beginPath(); g.moveTo(x, y); g.lineTo(x + 4, y - 10); g.stroke(); }
    // Picnic table, for orientation.
    const tx = 70 + 420 * (TABLE.x - minX) / Math.max(0.01, maxX - minX), ty = 90 + 300 * (TABLE.z - minZ) / Math.max(0.01, maxZ - minZ);
    g.fillStyle = '#9c7454'; g.fillRect(Math.max(10, Math.min(520, tx)) - 18, Math.max(70, Math.min(400, ty)) - 8, 36, 16);
    this.order.forEach((mi, rank) => {
      const m = this.mounds[mi];
      const px = 70 + 420 * (m.x - minX) / Math.max(0.01, maxX - minX);
      const py = 90 + 300 * (m.z - minZ) / Math.max(0.01, maxZ - minZ);
      g.fillStyle = '#8c6a48'; g.beginPath(); g.arc(px, py, 14, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#2a4a9a'; g.font = 'bold 40px "Comic Sans MS", "Chalkboard SE", sans-serif';
      g.fillText(String(rank + 1), px + 26, py - 12);
    });
    g.fillStyle = '#8a7650'; g.font = '20px sans-serif';
    g.fillText('(smells of crayons)', 280, 425);
    c.className = 'art-img';
    const wrapEl = document.createElement('div');
    wrapEl.append(c);
    const p = document.createElement('p');
    p.innerHTML = '<small>The map is drawn as you face it from the park’s south end: the picnic table is the brown bar. Meow beside each burrow in order.</small>';
    wrapEl.append(p);
    G.ui.panel('A crayon map', wrapEl, { buttons: [{ label: 'Fold it back', onClick: (close) => close() }] });
  }
  semaphoreWon() {
    G.state.set('gopher_semaphore_done');
    for (const m of this.mounds) this.peek(m, true, 1.6);
    G.audio.sfx('crab_snip', { vol: 0.5, rate: 0.8 });
    this.spawnBall();
    G.ui.celebrate('Gopher town surfaces!', 'The Gopher Semaphore');
    G.ui.say('Fifty gophers surface at once and stare. The eldest pushes up a tennis ball, chewed soft, one blue thread in the felt.');
  }
  spawnBall() {
    const eldest = this.mounds[this.order[5]];
    const ball = P.sphere(0.1, '#cfe04a'); ball.position.y = 0.1;
    this.pickup({ id: 'tennis_ball', pos: V3(eldest.x + 0.5, this.height(eldest.x + 0.5, eldest.z + 0.3), eldest.z + 0.3), obj: ball, bob: false });
  }

  // ── Main riddle: the Howl in the Off-Leash Meadow ──────
  buildMeadow() {
    const g = new THREE.Group();
    const runs = [
      [V3(-7, 0, -31), V3(7, 0, -31)], [V3(-7, 0, -31), V3(-7, 0, -23)], [V3(7, 0, -31), V3(7, 0, -23)],
      [V3(-7, 0, -23), V3(-0.95, 0, -23)], [V3(0.95, 0, -23), V3(7, 0, -23)],
    ];
    const panelMat = P.mat('#8ea09a', { transparent: true, opacity: 0.35 });
    for (const [a, b] of runs) {
      const len = a.distanceTo(b), mid = a.clone().lerp(b, 0.5), ang = Math.atan2(b.x - a.x, b.z - a.z);
      const y = this.height(mid.x, mid.z);
      const rail = P.box(0.06, 0.06, len, PARK_GREEN); rail.position.set(mid.x, y + 2.2, mid.z); rail.rotation.y = ang; g.add(rail);
      const pane = new THREE.Mesh(new THREE.BoxGeometry(0.04, 1.8, len), panelMat); pane.position.set(mid.x, y + 1.25, mid.z); pane.rotation.y = ang; pane.castShadow = false; pane.userData.noBake = true; g.add(pane);
      const n = Math.max(1, Math.round(len / 3.5));
      for (let i = 0; i <= n; i++) { const p = a.clone().lerp(b, i / n); const post = P.box(0.09, 2.25, 0.09, PARK_GREEN); post.position.set(p.x, this.height(p.x, p.z), p.z); g.add(post); }
      this.solidBox(mid.x, mid.z, Math.abs(b.x - a.x) + 0.12, Math.abs(b.z - a.z) + 0.12, -1, 2.6, 0, { noStand: true });
    }
    for (const gx of [-0.95, 0.95]) { const p = P.box(0.14, 2.4, 0.14, PARK_GREEN); p.position.set(gx, GATE.y, GATE.z); g.add(p); }
    const arch = P.box(2.2, 0.3, 0.16, WOOD); arch.position.set(0, GATE.y + 2.4, GATE.z); g.add(arch);
    const notice = P.sign(['OFF-LEASH', 'friends only'], { w: 0.9, h: 0.5, color: '#7a6450', font: 'bold 56px "Baloo 2", sans-serif' });
    notice.position.set(0, GATE.y + 1.75, GATE.z + 0.1); g.add(notice);
    this.add(P.bake(g)); this.add(g);
    // The gate itself.
    const gate = new THREE.Group(); gate.position.set(-0.89, GATE.y, GATE.z);
    const leaf = P.box(1.78, 1.9, 0.08, '#24583e'); leaf.position.x = 0.89; gate.add(leaf);
    for (let i = 0; i < 5; i++) { const bar = P.box(0.04, 1.8, 0.1, '#1b4430'); bar.position.set(0.2 + i * 0.35, 0.05, 0); gate.add(bar); }
    this.add(gate);
    this.gate = gate;
    this.gateSolid = this.solidBox(0, GATE.z, 1.8, 0.2, -1, 2.6, 0, { noStand: true });
    if (G.state.flag('meadow_open')) { gate.rotation.y = 1.4; this.gateSolid.enabled = false; }
    this.interact({
      pos: V3(0, GATE.y, GATE.z + 0.6), obj: leaf, radius: 1.9, icon: '\u{1F511}',
      enabled: () => !G.state.flag('meadow_open'),
      label: () => (G.state.has('paw_key') ? 'Unlock with the paw-marked key' : 'A dog-proof gate latch'),
      use: () => this.gateUse(),
    });
    this.sense(gate, { warm: () => G.state.has('paw_key'), height: 1 });

    // The great cottonwood, the memorial stone, a water bowl, half-swallowed balls.
    const tree = model('tree_leafy', { height: 8, rotY: 0.6 }); tree.position.copy(TREE); this.add(tree);
    this.solidCyl(TREE.x, TREE.z, TRUNK_R, -1, 8);
    this.fadeCanopy(tree);
    // A mossy old boulder with a small brass plaque, the kind parks put under
    // a favourite tree. (Not a gravestone: it reads as one from above.)
    const stone = new THREE.Group(); stone.position.copy(STONE); stone.rotation.y = -0.3;
    const rock = P.rock(0.5, '#8d9184', 11, 0.72); rock.scale.set(1.15, 1, 0.9); stone.add(rock);
    for (const [x, z, r] of [[-0.18, -0.08, 0.2], [0.16, 0.1, 0.16], [0.02, -0.2, 0.13]]) {
      const moss = P.sphere(r, '#6f9a3c', { seg: 8 }); moss.scale.y = 0.35; moss.position.set(x, 0.42, z); stone.add(moss);
    }
    const plaque = P.box(0.26, 0.17, 0.025, '#c9a24a', { base: false }); plaque.position.set(0, 0.2, 0.43); plaque.rotation.x = -0.35; stone.add(plaque);
    this.add(stone);
    this.solidCyl(STONE.x, STONE.z, 0.5, -1, STONE.y + 0.5);
    const bowl = P.cyl(0.22, 0.26, 0.12, '#4c80c0'); bowl.position.set(-1.2, this.height(-1.2, -23.8), -23.8); this.add(bowl);
    for (const b of [V3(-2.6, 0, -26.2), V3(3.4, 0, -29)]) { const s = P.sphere(0.09, '#c8d84a'); s.position.set(b.x, this.height(b.x, b.z) + 0.04, b.z); this.add(s); }
    this.bench(this.root, BENCH, 0.55);
    this.interact({
      obj: stone, radius: 1.6, icon: ':boulder:', label: 'The old stone with a plaque',
      use: () => {
        G.ui.say(G.state.flag('oreo_joined') ? 'Old and sun-warmed, its engraving always just out of frame. He leans against it like it is the warmest thing in the park.' : 'Old and sun-warmed. The engraving is worn too soft to read.');
        G.state.addArtifact('memorial', 'calgary', 'The Memorial Stone', 'Under the great cottonwood, a stone old and sun-warmed, its engraving always just out of frame. He sleeps against it like it is the warmest thing in the park.');
      },
    });

    // The howl, surfacing between breezes.
    let howlT = 4;
    const R = rng(404);
    this.every((dt) => {
      if (G.state.flag('oreo_untangled')) return true;
      howlT -= dt;
      if (howlT > 0) return;
      howlT = R.range(16, 28);
      if (!this.isCalm()) { howlT = 4; return; }
      G.audio.sfx('howl', { pos: TREE, vol: 0.9, range: 60, rate: R.range(0.92, 1.05) });
    });

    if (G.state.flag('oreo_joined')) return;
    // Oreo, tangled. (He is shown on the first frame: the loader hides him after build.)
    this.every(() => {
      if (G.state.oreo) return true;
      G.oreo.show(OREO_HOME.x, OREO_HOME.z, 2.6);
      G.oreo.mode = 'hidden';
      G.oreo.root.visible = true; G.oreo.blob.visible = true;
      return true;
    });
    this.ropes = {};
    this.buildRopes();
    this.pads = {};
    this.unwound = 0;
    for (const [name, p] of [['stone', STONE.clone().add(V3(0, 0, 0.9))], ['bench', BENCH.clone().add(V3(0.9, 0, 0.6))], ['tree', TREE.clone().add(V3(-1.5, 0, 1.5))]]) {
      const pad = new THREE.Mesh(new THREE.CircleGeometry(0.42, 24), new THREE.MeshBasicMaterial({ color: '#ffd24a', transparent: true, opacity: 0.65, depthWrite: false }));
      pad.rotation.x = -Math.PI / 2; pad.position.set(p.x, this.height(p.x, p.z) + 0.03, p.z); pad.renderOrder = 2;
      pad.visible = G.state.flag('meadow_open') && !G.state.flag('oreo_untangled');
      this.add(pad);
      this.pads[name] = pad;
      this.trigger({ pos: p, radius: 0.6, onEnter: () => this.onPad(name) });
    }
    this.every(() => { for (const p of Object.values(this.pads)) p.material.opacity = 0.45 + Math.sin(G.time * 4) * 0.2; });
    if (G.state.flag('oreo_untangled')) for (const k of Object.keys(this.ropes)) this.dropRope(k, true);
    this.fed = G.state.flag('oreo_fed');
    this.oreoIt = this.interact({
      pos: () => G.oreo.pos.clone(), radius: 2.0, icon: '\u{1F415}', priority: 1,
      enabled: () => !G.state.flag('oreo_joined') && !this.throwing,
      label: () => {
        if (!G.state.flag('oreo_untangled')) return 'The tangled dog';
        if (!this.fed) return (G.state.has('cream_jug') && G.state.has('dog_biscuits')) ? 'Share the cream and biscuits' : 'The dog watches her';
        return G.state.has('tennis_ball') ? 'Throw the chewed tennis ball' : 'He wants something';
      },
      use: () => this.oreoUse(),
    });
    this.pickable(G.oreo.root, this.oreoIt);
    this.sense(() => G.oreo.pos, { warm: () => true, height: 0.9, radius: 14 });
  }
  /**
   * The great cottonwood's canopy covers the whole meadow. While Khione is in
   * or near it, the leaves go see-through (the trunk stays solid) so the
   * camera can see her, the dog and the run-line underneath.
   */
  fadeCanopy(tree) {
    const u = { uFade: { value: 0 }, uBase: { value: TREE.y + 1.9 } };
    const apply = () => {
      tree.traverse((o) => {
        if (!o.isMesh || o.userData.canopy) return;
        o.userData.canopy = true;
        o.material = o.material.clone();
        o.material.transparent = true;
        o.material.onBeforeCompile = (sh) => {
          Object.assign(sh.uniforms, u);
          sh.vertexShader = sh.vertexShader
            .replace('#include <common>', '#include <common>\nvarying float vCanopyY;')
            .replace('#include <project_vertex>', '#include <project_vertex>\nvCanopyY = (modelMatrix * vec4(transformed, 1.0)).y;');
          sh.fragmentShader = sh.fragmentShader
            .replace('#include <common>', '#include <common>\nuniform float uFade; uniform float uBase; varying float vCanopyY;')
            .replace('#include <dithering_fragment>', '#include <dithering_fragment>\ngl_FragColor.a *= 1.0 - 0.74 * uFade * smoothstep(uBase, uBase + 1.2, vCanopyY);');
        };
        o.material.customProgramCacheKey = () => 'canopy-fade';
        o.material.needsUpdate = true;
      });
      return !!tree.userData.inner;
    };
    apply();
    this.every((dt) => {
      if (!tree.userData.canopy && apply()) tree.userData.canopy = true;
      const p = G.player.pos, o = G.oreo;
      const near = (q) => Math.abs(q.x - TREE.x) < 8.5 && q.z > TREE.z - 7.5 && q.z < TREE.z + 7.5;
      const want = near(p) || (o.root.visible && G.cine?.active && near(o.pos)) ? 1 : 0;
      u.uFade.value += (want - u.uFade.value) * Math.min(1, dt * 5);
    });
  }
  ropeLeg(name) {
    // A point on the trunk's bark, facing `toward`.
    const bark = (toward, y) => { const d = toward.clone().sub(TREE).setY(0).normalize(); return TREE.clone().addScaledVector(d, TRUNK_R - 0.05).add(V3(0, y, 0)); };
    const legs = {
      bench: [bark(BENCH, 0.5), BENCH.clone().add(V3(0.2, 0.45, 0.1))],
      stone: [BENCH.clone().add(V3(0.3, 0.4, -0.25)), STONE.clone().add(V3(-0.3, 0.3, -0.2))],
      tree: [STONE.clone().add(V3(-0.2, 0.3, 0.3)), bark(STONE, 0.45)],
      collar: [bark(OREO_HOME, 0.5), OREO_HOME.clone().add(V3(0, 0.55, 0.2))],
    };
    const [a, b] = legs[name];
    const mid = a.clone().lerp(b, 0.5).add(V3(0, -0.12, 0));
    // A leg that would cut through the trunk wraps around behind it instead.
    const off = mid.clone().sub(TREE).setY(0);
    if (off.length() < TRUNK_R + 0.2) { off.setLength(TRUNK_R + 0.2); mid.x = TREE.x + off.x; mid.z = TREE.z + off.z; }
    return P.rope([a, mid, b], 0.03, '#d8b84a');
  }
  buildRopes() {
    for (const k of ['bench', 'stone', 'tree', 'collar']) { if (this.ropes[k]) continue; const r = this.ropeLeg(k); this.add(r); this.ropes[k] = r; }
  }
  dropRope(k, instant) {
    const r = this.ropes[k];
    if (!r) return;
    delete this.ropes[k];
    if (instant) { r.removeFromParent(); return; }
    G.tween(r.scale, { x: 0.05, z: 0.05 }, 0.5).then(() => r.removeFromParent());
  }
  gateUse() {
    if (!G.state.has('paw_key')) {
      G.audio.sfx('stone_slide', { vol: 0.3, rate: 0.7 });
      G.ui.say('The latch is dog-proof and stranger-proof both. It wants a key, one that knows about paws.');
      return;
    }
    G.state.take('paw_key');
    G.state.set('meadow_open');
    G.audio.sfx('pickup_chime', { vol: 0.5 }); G.audio.sfx('wood_creak', { vol: 0.6 });
    this.gateSolid.enabled = false;
    G.tween(this.gate.rotation, { y: 1.4 }, 1.1, ease.inOut);
    for (const p of Object.values(this.pads ?? {})) p.visible = true;
    G.ui.say('The paw key turns. The gate swings wide and the howler falls silent, watching her come.');
  }
  onPad(name) {
    if (G.state.flag('oreo_untangled') || !G.state.flag('meadow_open')) return;
    if (name === UNWIND[this.unwound]) {
      this.unwound++;
      G.audio.sfx('pickup_chime', { vol: 0.5, rate: 0.75 + 0.15 * this.unwound });
      this.dropRope(['tree', 'stone', 'bench'][this.unwound - 1]);
      this.pads[name].visible = false;
      if (this.unwound >= 3) this.untangle();
      else G.ui.toast('A loop lets go. The line hangs looser.', '\u{1FAA2}');
    } else {
      if (!this.pads[name].visible) return; // already let go of this loop
      this.unwound = 0;
      G.audio.sfx('whimper', { pos: OREO_HOME, vol: 0.9 });
      for (const p of Object.values(this.pads)) p.visible = true;
      this.buildRopes();
      G.ui.say('The line cinches tighter and his ears drop. Walk it backwards: the way it was wound, undone.');
    }
  }
  untangle() {
    G.state.set('oreo_untangled');
    this.dropRope('collar');
    for (const p of Object.values(this.pads)) p.visible = false;
    G.oreo.oneShot('attack', 1.2);
    G.audio.sfx('bark', { pos: G.oreo.pos, vol: 0.9 });
    G.ui.celebrate('Free!', 'The run-line lets go');
    G.ui.say('The last loop slides free. He shakes from nose to tail and sits, watching her. Free is not the same as friends.');
  }
  oreoUse() {
    if (!G.state.flag('oreo_untangled')) {
      G.audio.sfx('whimper', { pos: G.oreo.pos, vol: 0.8 });
      G.ui.say('He goes very still, tangled to the tree. The line loops tree, bench, stone, wound in that order.');
      return;
    }
    if (!this.fed) {
      if (G.state.has('cream_jug') && G.state.has('dog_biscuits')) {
        G.state.take('cream_jug'); G.state.take('dog_biscuits');
        this.fed = true;
        G.state.set('oreo_fed');
        const saucer = P.cyl(0.18, 0.15, 0.04, '#f2eee2'); saucer.position.copy(OREO_HOME).add(V3(-0.5, 0, 0.4)); saucer.position.y = this.height(saucer.position.x, saucer.position.z); this.add(saucer);
        const bag = P.box(0.24, 0.06, 0.16, '#b88c4c'); bag.position.copy(OREO_HOME).add(V3(0.5, 0, 0.5)); bag.position.y = this.height(bag.position.x, bag.position.z); this.add(bag);
        G.audio.sfx('pickup_chime', { vol: 0.5, rate: 0.9 });
        G.oreo.faceTo(G.player.pos);
        G.ui.say('Cream, and biscuits, laid in the grass. He eats like it is a ceremony. Then he looks up, expecting one more thing.');
        return;
      }
      const missing = [];
      if (!G.state.has('cream_jug')) missing.push('cream');
      if (!G.state.has('dog_biscuits')) missing.push('biscuits');
      G.ui.say(`He will not follow a stranger. A friend shares food, and she still needs ${missing.join(' and ')}.`);
      return;
    }
    if (!G.state.has('tennis_ball')) { G.ui.say('He nudges her paw, then stares at the grass, then at her, then at the grass. He wants something thrown.'); return; }
    if (this.throwing) return;
    this.throwing = true;
    G.state.take('tennis_ball');
    this.throwBall();
  }
  async throwBall() {
    await G.cine.run(async (c) => {
      const from = G.player.pos.clone().add(V3(0, 0.6, 0));
      const land = V3(-4.2, this.height(-4.2, -25.6) + 0.1, -25.6);
      const ball = P.sphere(0.1, '#cfe04a'); ball.position.copy(from); this.add(ball);
      c.look(V3(-2, 0.6, -26), { dist: 9, pitch: 42 });
      G.player.oneShot('attack', 1.4);
      G.audio.sfx('whisker_shimmer', { vol: 0.5, rate: 1.3 });
      await G.animate(0.9, (t) => { ball.position.lerpVectors(from, land, t); ball.position.y += 1.6 * Math.sin(t * Math.PI); });
      G.oreo.bark();
      await G.oreo.goTo(land, 0.4, 6.5);
      G.oreo.root.add(ball);
      ball.position.set(0, 0.62, 0.32);
      await G.oreo.goTo(G.player.pos.clone().add(V3(0.6, 0, 0.6)), 0.5, 5.5);
      this.add(ball);
      ball.position.copy(G.player.pos).add(V3(0.3, 0.1, 0.3));
      G.oreo.faceTo(G.player.pos);
      G.oreo.bark();
      await c.wait(0.3);
      G.audio.sfx('bark', { pos: G.oreo.pos, vol: 0.8, rate: 1.15 });
      G.oreo.oneShot('happy', 2);
      await say('He drops the ball at her paws. That is the whole handshake. From here on, Oreo follows.', 4);
    });
    this.throwing = false;
    G.state.set('oreo_friend');
    G.state.set('oreo_joined');
    G.oreo.join();
    G.ui.celebrate('Oreo joins!', 'The Howl in the Off-Leash Meadow');
    G.ui.toast('Meow and he barks back. Tap \u{1F415} to tell him to stay or come.', '\u{1F415}');
    setTimeout(() => { if (G.island === this && !G.cine.active) G.ui.toast('The canoe on the gravel bar is heavy, but she is not alone anymore.', '\u{1F6F6}'); }, 6000);
  }

  // ── Exit: the canoe on the gravel bar ─────────────────
  buildCanoe() {
    const canoe = model('canoe', { size: 3.6, rotY: Math.PI / 2 });
    const holder = new THREE.Group(); holder.add(canoe);
    holder.position.copy(CANOE); holder.rotation.y = 0.4;
    this.add(holder);
    this.canoe = holder;
    this.canoeSolid = this.solidBox(CANOE.x, CANOE.z, 1.0, 3.4, -1, 0.75, -0.4, { noStand: true });
    this.interact({
      obj: holder, radius: 2.6, icon: '\u{1F6F6}',
      enabled: () => !this.departing,
      label: () => (G.state.flag('oreo_joined') ? 'Shove off together' : 'The beached canoe'),
      use: () => this.canoeUse(),
    });
    this.sense(holder, { warm: () => G.state.flag('oreo_joined'), height: 0.5 });
  }
  async canoeUse() {
    if (!G.state.flag('oreo_joined')) { G.ui.say('Beached hard on the gravel. Far too heavy for one small cat.'); return; }
    this.departing = true;
    const first = !G.state.flag('island3_complete');
    const canoe = this.canoe;
    G.audio.music('intro', { fade: 2.5 });
    await G.cine.run(async (c) => {
      c.look(CANOE.clone().setY(0.6), { dist: 10, pitch: 36 });
      await G.oreo.goTo(V3(3.0, 0, 37.0), 0.4, 6);
      G.oreo.mode = 'busy';
      G.oreo.faceTo(CANOE);
      await c.wait(0.4);
      G.oreo.bark();
      this.canoeSolid.enabled = false;
      G.oreo.oneShot('pickup', 1.8);
      G.audio.sfx('splash', { pos: CANOE, vol: 0.8 });
      await Promise.all([G.tween(canoe.position, { x: 2.6, y: WATER + 0.1, z: 48 }, 1.6, ease.out), G.tween(canoe.rotation, { y: 0 }, 1.6)]);
      // She takes the stern, he takes the bow. Obviously.
      const ride = this.every(() => {
        const p = canoe.position;
        G.player.pos.set(p.x, p.y + 0.3, p.z - 0.6); G.player.velocity.set(0, 0, 0); G.player.yaw = 0; G.player.root.rotation.y = 0;
        G.oreo.pos.set(p.x, p.y + 0.25, p.z + 0.8); G.oreo.yaw = 0; G.oreo.root.rotation.y = 0;
      });
      G.audio.sfx('bark', { vol: 0.7, rate: 1.1 });
      if (first) await say('As he settles into the bow, a scrap slips from under his collar.', 3);
      else await say('East again. The water remembers them.', 2.5);
      c.look(canoe.position.clone(), { dist: 9, pitch: 26, speed: 1.5 });
      const strokes = setInterval(() => G.audio.sfx('swim_stroke', { vol: 0.5, rate: 0.85 }), 1350);
      const follow = this.every(() => c.look(canoe.position.clone().add(V3(0, 0.5, 2)), { dist: 9, pitch: 24, speed: 2 }));
      await G.tween(canoe.position, { x: 6, z: 64 }, 4.5, ease.in);
      await G.tween(canoe.position, { x: 11, z: 78 }, 3, ease.linear);
      clearInterval(strokes);
      this.updaters.splice(this.updaters.indexOf(follow), 1);
      this.updaters.splice(this.updaters.indexOf(ride), 1);
    });
    G.state.addArtifact('memorial', 'calgary', 'The Memorial Stone', 'Under the great cottonwood, a stone old and sun-warmed, its engraving always just out of frame. He sleeps against it like it is the warmest thing in the park.');
    this.departing = false;
    G.oreo.mode = 'follow';
    await G.game.finishIsland();
  }

  // ── Arrival, goals ─────────────────────────────────────
  async onEnter(first) {
    if (!first || G.state.flag('calgary_arrived')) return;
    G.state.set('calgary_arrived');
    await G.cine.run(async (c) => {
      c.look(V3(0, 1, 20), { dist: 30, pitch: 34, yaw: 200, speed: 0.6 });
      await say('The Bow runs turquoise around a green park island. Golden hour, and it never quite ends.', 4);
      c.look(TREE.clone().setY(1), { dist: 16, pitch: 30, speed: 0.8 });
      G.audio.sfx('howl', { vol: 0.9 });
      await say('Somewhere to the north, something is howling for company.', 3.5);
    });
  }

  objective() {
    const s = G.state;
    if (s.flag('island3_complete')) return 'The canoe knows the way east';
    if (!s.flag('regatta_done')) return 'Sail a paper boat under the red bridge';
    if (!s.flag('ice_cream_done')) return s.flag('bell_fixed') ? 'Ring the vendor’s round' : 'The ice-cream cart’s bell is silent';
    if (!s.flag('kite_freed')) return 'Free the kite atop the Peace Bridge';
    if (!s.flag('gopher_semaphore_done')) return 'Wake gopher town in the right order';
    if (!s.flag('meadow_open')) return 'Open the off-leash meadow gate';
    if (!s.flag('oreo_untangled')) return 'Untangle the howling dog';
    if (!s.flag('oreo_joined')) return 'Free is not the same as friends';
    return 'Shove off in the canoe, together';
  }
  hint() {
    const s = G.state;
    if (s.flag('island3_complete')) return 'Prince’s Island hums with summer. The canoe by the gravel bar knows the way east, whenever they are ready.';
    if (!s.flag('regatta_done')) return 'Paper boats lie becalmed on the lagoon. The cottonwood fluff knows when the breeze comes, and the little weir decides what passes the narrows.';
    if (!s.flag('ice_cream_done')) return 'A brass clapper wants a bell. The old ice-cream cart wears four painted notes: the vendor’s round, rung just so.';
    if (!s.flag('kite_freed')) return 'A kite thrashes at the top of the red bridge. Grab it when the fluff rests, and mind where its string leads.';
    if (!s.flag('gopher_semaphore_done')) return 'The gophers keep something buried. A crayon map under a picnic table knows their doors by number, and meows carry underground.';
    if (!s.flag('meadow_open')) return 'The howl comes from the fenced meadow at the north point. The vendor’s spare key wears a paw.';
    if (!s.flag('oreo_untangled')) return 'The run-line loops tree, bench, and stone, wound in that order. Walk it backwards, and it lets go.';
    if (!s.flag('oreo_joined')) return 'Free is not the same as friends. Cream, biscuits, and one good throw.';
    return 'The canoe on the gravel bar is heavy, and she is small. Her new friend knows the way to the water.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.flag('regatta_done')) return s.has('brass_clapper') ? CART : PLANK;
    if (!s.flag('ice_cream_done')) return CART;
    if (!s.flag('kite_freed')) return KITE;
    if (!s.flag('gopher_semaphore_done')) return TABLE;
    if (!s.flag('oreo_joined')) return TREE;
    return CANOE;
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'regatta', name: 'The Paper Regatta', done: s.flag('regatta_done'), hint: 'Paper boats lie becalmed on the lagoon. The fluff gives one beat of warning, and the little weir decides what passes under the red bridge.' },
      { id: 'icecream', name: 'The Ice Cream Round', done: s.flag('ice_cream_done'), hint: 'The cart’s bell wants its clapper back, and then the vendor’s round: four painted notes, rung just so, in one short breath.' },
      { id: 'kite', name: 'The Bridge and the Kite', done: s.flag('kite_freed'), hint: 'A kite thrashes at the arch of the red bridge, still only in the lull. Its string runs down into the shallows, tied to something.' },
      { id: 'gophers', name: 'The Gopher Semaphore', done: s.flag('gopher_semaphore_done'), hint: 'A crayon map under a picnic table numbers six burrows. Meows carry underground. Pulse the doors in the map’s order.' },
      { id: 'howl', name: 'The Howl in the Off-Leash Meadow', done: s.flag('oreo_joined'), hint: 'The paw key opens the gate. The run-line loops tree, bench, stone: walk it backwards. Then cream, biscuits, and one good throw.' },
    ];
  }
}
