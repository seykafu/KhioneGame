// Island 6 — English Bay. Vancouver at blossom time: the seawall, a kite
// beach, a totem clearing, raccoons with opinions, and cherry petals riding a
// wind that never stops. Teaches: the wind is a tool. Built from the riddle
// compendium ("Island 6 · English Bay").
//
// Layout: the south is the lower seawall + kite beach (y 0.6 → sand → sea);
// a retaining wall (railed) lifts the upper park to y≈3. The seawall stairs
// (held by raccoons) are the way up. The totem clearing hides in a hedge ring
// to the north-west; the miniature Lions Gate juts off the west cliff.
import * as THREE from 'three';
import { G, rng, clamp, fbm, ease, V3 } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';
import { registerItems } from '../engine/state.js';
import { drawIcon } from '../engine/icons.js';

registerItems({
  shiny_spoon: { name: 'Shiny Spoon', icon: '\u{1F944}', desc: 'A silver teaspoon, polished by sand and sea. Somebody around here collects shiny things.' },
  kite: { name: 'Runaway Kite', icon: '\u{1FA81}', desc: 'A kite that escaped its reel. The kite beach has posts waiting for it.' },
  brass_lens: { name: 'Brass Lens', icon: '\u{1F50D}', desc: 'The crown jewel of a raccoon hoard: a heavy brass lens, ground for a light much bigger than a lantern. It is waiting for a lighthouse.' },
  stall_key: { name: 'Stall Key', icon: '\u{1F511}', desc: 'The produce stall’s key, won off the high pan of an honest scale.' },
  ranger_key: { name: 'Ranger’s Key', icon: '\u{1F5DD}️', desc: 'A key on a cedar tag, stamped with a tiny suspension bridge. Park Ranger, it says. Lions Gate.' },
  winch_crank: { name: 'Winch Crank', icon: '\u{1F527}', desc: 'A heavy iron crank from the ranger’s strongbox. Something by the water wants winding.' },
});

const WATER = 0;
const RAIL_Z = 10.35;
const STAIRS = { x0: 17.6, x1: 22.4, z0: 9.6, z1: 13.4 };
const RACCOON_TOP = V3(20, 0, 8.4);
const STASH = V3(26.5, 0, 15.6);
const SPOON = V3(-15, 0, 20.2);
const SPAWN = V3(-24, 0, 14.2);
const REELS = [-10, -5, 0, 5, 10].map((x) => V3(x, 0, 19.6));
const CLEARING = V3(-16, 0, -15);
const THICKET = V3(-9.4, 0, -15);
const CHERRY = V3(4, 0, -15);
const BENCH = V3(4, 0, -9.6);
const STALL = V3(14, 0, -4);
const SKY_TREE = V3(-36, 0, -36);
const GAP = V3(5.5, 0, -36);
const OPEN_WATER = V3(-50, 0, -17.8);
const BRIDGE = V3(-41, 0, -6);       // hinge of the miniature Lions Gate deck
const WINCH = V3(-38.4, 0, -3.2);
const POLES = [
  { key: 'raven', model: 'pole_raven', pos: V3(-18.6, 0, -12.8), target: SKY_TREE, note: 880, home: 'the tallest tree' },
  { key: 'bear', model: 'pole_bear', pos: V3(-13.5, 0, -13.4), target: GAP, note: 587, home: 'the forest', heavy: true },
  { key: 'orca', model: 'pole_orca', pos: V3(-16.2, 0, -18.2), target: OPEN_WATER, note: 392, home: 'the sea' },
];
// Kites snagged around the bay: each perch is a gust-jump above its launch spot.
const KITES = [
  { id: 0, pos: V3(-8, 0, 13.2), top: 3.2, color: '#ff6b4a', where: 'the seawall lamp' },
  { id: 1, pos: V3(10, 0, 31), top: 2.2, color: '#1fb5c9', where: 'the sea stack' },
  { id: 2, pos: V3(24, 0, -14), top: 5.6, color: '#ffc93c', where: 'the bandstand roof' },
  { id: 3, pos: V3(4.6, 0, -15.6), top: 5.6, color: '#b58cff', where: 'the cherry tree' },
];
const PRODUCE = [
  { id: 'plum', name: 'Plum', price: 1, n: 2, color: '#7b3fc4' },
  { id: 'apple', name: 'Apple', price: 2, n: 2, color: '#e8402f' },
  { id: 'pear', name: 'Pear', price: 3, n: 1, color: '#b6c94a' },
  { id: 'melon', name: 'Melon', price: 5, n: 1, color: '#4fa83a' },
];
const KEY_PAN = 7;
// Wind: calm → one readable beat of warning → gust. Directions cycle; west often.
const CALM = 6.5, WARN = 1.8, GUST = 2.6;
const DIRS = ['W', 'N', 'W', 'E', 'W', 'S'];
const DIRV = { N: [0, -1], S: [0, 1], E: [1, 0], W: [-1, 0] };
const DIRNAME = { N: 'north', S: 'south', E: 'east', W: 'west' };

const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const STEP = Math.PI / 4;

export default class EnglishBay extends Island {
  static id = 'englishbay';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 0, r: 60 };
    this.wind = { phase: 'calm', t: 2, idx: 0, dir: 'W' };
    this.produce = {};
    this.moundColor = '#cfb58a';
  }

  models() { return ['pole_raven', 'pole_bear', 'pole_orca', 'tree_cherry', 'tree_leafy', 'raccoon', 'chest']; }
  sounds() { return ['gust', 'raccoon', 'winter_wind', 'ocean_loop', 'park_birds', 'wood_creak', 'stone_slide', 'gate_open', 'bell_ding', 'chime', 'push', 'dig']; }
  music() { return 'englishbay'; }
  atmosphere() {
    if (G.state.flag('eb_sunset')) return this.sunsetAtmo();
    return { sky: '#a6dcf2', fog: '#d6eef6', fogNear: 45, fogFar: 125, sun: '#fff3e0', sunIntensity: 2.4, hemi: 1.3, skyLight: '#fff4ec', groundLight: '#7a906a' };
  }
  sunsetAtmo() {
    return { sky: '#ffb889', fog: '#f7c29a', fogNear: 40, fogFar: 115, sun: '#ff9a5a', sunIntensity: 2.6, hemi: 1.0, skyLight: '#ffd6b0', groundLight: '#6a5a6a', sunDir: [-20, 12, 6], exposure: 1.1 };
  }
  terrainTextures() { return ['grass.jpg', 'sand.jpg', 'cobble.jpg']; }

  // ── Ground ─────────────────────────────────────────────
  coast(theta) { return 47 + 2 * Math.sin(3 * theta + 0.4) + 1.4 * Math.sin(5 * theta + 2.1); }
  height(x, z) {
    const d = Math.hypot(x, z), c = this.coast(Math.atan2(z, x));
    // Seawall stairs: a clean ramp so the steps climb evenly.
    if (x > STAIRS.x0 - 0.6 && x < STAIRS.x1 + 0.6 && z > STAIRS.z0 && z < STAIRS.z1) {
      return 3.0 + (0.6 - 3.0) * ((z - STAIRS.z0) / (STAIRS.z1 - STAIRS.z0));
    }
    const upper = 3.0 + 0.9 * ss(-12, -42, z) + fbm(x * 0.06, z * 0.06) * 0.18;
    let h = upper + (0.6 - upper) * ss(10.6, 11.5, z);
    if (z > 17) h = 0.6 - ss(17, 30, z) * 2.3;
    // The island drops into the bay at the edges.
    h = h + (-1.6 - h) * ss(c - 3.5, c, d);
    if (d >= c) h = -1.6 - 4 * clamp((d - c) / 10, 0, 1);
    return h;
  }
  splat(x, z) {
    const h = this.height(x, z);
    if (z > 17 || h < 0.3) return [0, 1, 0];
    if (z > 10.4) return [0, 0, 1];               // seawall walkway + retaining wall
    return [1, 0, 0];
  }
  tint(x, z) {
    const c = new THREE.Color('#ffffff');
    const h = this.height(x, z);
    if (h < 0) c.lerp(new THREE.Color('#5aa8a0'), clamp(-h / 3, 0, 0.8));
    c.multiplyScalar(0.94 + fbm(x * 0.13, z * 0.13) * 0.1);
    return c;
  }
  footstep(x, z) { return z > 17 ? 'paw_sand' : 'paw_grass'; }
  dustColor(x, z) { return z > 17 ? '#ecd6a4' : '#f6c6d6'; }
  spawn() { return { x: SPAWN.x, z: SPAWN.z, rotY: Math.PI * 0.75 }; }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 124, res: 150, repeat: 0.2 });
    this.makeWater({ level: WATER, size: 320, res: 120, colors: { deep: '#1b9cc4', light: '#69d6ea' } });
    this.buildSeawall();
    this.buildPark();
    this.buildKites();
    this.buildRaccoons();
    this.buildBlossom();
    this.buildMarket();
    this.buildClearing();
    this.buildBridge();
    this.buildWind();
    G.audio.ambient('ocean_loop', 0.2);
    G.audio.ambient('park_birds', 0.15);
    for (const [pos, r, name] of [[V3(0, 0, 21), 9, 'The Kite Beach'], [V3(-10, 0, 14), 7, 'The Seawall'], [CHERRY, 7, 'Blossom Lawn'], [STALL, 6, 'The Market'], [CLEARING, 6, 'The Totem Clearing']]) {
      this.trigger({ pos, radius: r, once: true, onEnter: () => G.ui.showBanner(`~ ${name} ~`, 2.2) });
    }
  }

  dispose() {
    this.chip?.remove();
    G.fx.setWeather(null);
    super.dispose();
  }

  buildSeawall() {
    const deco = new THREE.Group();
    // Railing along the top of the retaining wall, with a gap at the stairs.
    for (const [a, b] of [[-46, STAIRS.x0], [STAIRS.x1, 46]]) {
      for (let x = a; x < b - 0.5; x += 2.6) {
        const x2 = Math.min(b, x + 2.6);
        const za = RAIL_Z;
        if (this.height(x, za) < 2.4) continue;
        deco.add(P.fence(V3(x, this.height(x, za), za), V3(x2, this.height(x2, za), za), { h: 0.95, gap: 1.3, color: '#5a6a72' }));
      }
      this.solidBox((a + b) / 2, RAIL_Z, b - a, 0.5, 2.0, 4.6, 0, { noStand: true });
    }
    // Stair treads (visual) + side walls.
    for (let i = 0; i < 12; i++) {
      const z = STAIRS.z0 + (i + 0.5) * ((STAIRS.z1 - STAIRS.z0) / 12);
      const t = P.box(STAIRS.x1 - STAIRS.x0, 0.12, 0.34, '#bdb6a8');
      t.position.set((STAIRS.x0 + STAIRS.x1) / 2, this.height(20, z) - 0.06, z);
      deco.add(t);
    }
    for (const x of [STAIRS.x0 - 0.3, STAIRS.x1 + 0.3]) {
      const w = P.box(0.4, 0.9, STAIRS.z1 - STAIRS.z0, '#9a948a'); w.position.set(x, 0.6, (STAIRS.z0 + STAIRS.z1) / 2); w.scale.y = 3; deco.add(w);
      this.solidBox(x, (STAIRS.z0 + STAIRS.z1) / 2, 0.4, STAIRS.z1 - STAIRS.z0, -1, 3.4, 0, { noStand: true });
    }
    // Lamps, bollards, benches along the walkway.
    for (let x = -36; x <= 36; x += 9) {
      if (Math.abs(x - KITES[0].pos.x) < 2 || Math.abs(x - 20) < 4) continue;
      const lamp = this.lamp(); lamp.position.set(x, 0.6, 16.4); deco.add(lamp);
      this.solidCyl(x, 16.4, 0.18, 0, 3.4, { noStand: true });
    }
    for (let x = -40; x <= 40; x += 3.2) {
      if (this.height(x, 17.1) < 0.4) continue;
      const b = P.cyl(0.14, 0.17, 0.5, '#8a8f94'); b.position.set(x, 0.6, 17.1); deco.add(b);
    }
    // Driftwood at the stash.
    const log = P.cyl(0.25, 0.32, 2.6, '#a89a88', { base: false, seg: 9 }); log.rotation.z = Math.PI / 2; log.rotation.y = 0.4;
    log.position.set(STASH.x + 0.4, 0.85, STASH.z - 0.6); deco.add(log);
    // A little dock where they came ashore.
    const dock = P.box(2.4, 0.2, 7, '#a0662e'); dock.position.set(-24, 0.45, 20.5); deco.add(dock);
    this.surface((x, z) => (x > -25.2 && x < -22.8 && z > 17 && z < 24 ? 0.65 : null));
    for (const z of [18, 20.5, 23]) for (const x of [-25.1, -22.9]) { const p = P.cyl(0.12, 0.12, 2, '#7a5030'); p.position.set(x, -1.4, z); deco.add(p); }
    this.add(P.bake(deco)); this.add(deco);
  }

  lamp() {
    const g = new THREE.Group();
    const post = P.cyl(0.08, 0.11, 2.6, '#33424a'); g.add(post);
    const head = P.sphere(0.2, '#fff2c0', { emissive: '#ffd27a', emissiveIntensity: 0.35 }); head.position.y = 2.75; g.add(head);
    return g;
  }

  buildPark() {
    const R = rng(606);
    // Forest ring to the north, with one honest gap.
    const forest = [];
    for (let i = 0; i < 46; i++) {
      const x = R.range(-40, 40), z = R.range(-42, -29);
      if (x > 1.5 && x < 9.5) continue;
      if (Math.hypot(x, z) > this.coast(Math.atan2(z, x)) - 4) continue;
      if (Math.hypot(x - SKY_TREE.x, z - SKY_TREE.z) < 6) continue;
      forest.push({ x, y: this.height(x, z) - 0.1, z, rotY: R.range(0, 6.28), scale: R.range(0.85, 1.2) });
      this.solidCyl(x, z, 0.5, -1, 8);
    }
    this.add(instanced('tree_leafy', forest, { height: 7.5 }));
    // The sky-tree: the tallest thing on the island.
    const sky = model('tree_leafy', { height: 17 }); sky.position.set(SKY_TREE.x, this.height(SKY_TREE.x, SKY_TREE.z) - 0.2, SKY_TREE.z); this.add(sky);
    this.solidCyl(SKY_TREE.x, SKY_TREE.z, 1.2, -1, 12);
    // Blossom trees scattered on the lawns.
    const cherries = [];
    for (let i = 0; i < 16; i++) {
      const x = R.range(-34, 34), z = R.range(-26, 8);
      if (Math.hypot(x - CLEARING.x, z - CLEARING.z) < 9 || Math.hypot(x - CHERRY.x, z - CHERRY.z) < 6 || Math.hypot(x - STALL.x, z - STALL.z) < 6) continue;
      if (Math.hypot(x - KITES[2].pos.x, z - KITES[2].pos.z) < 5 || Math.abs(x - BRIDGE.x) < 6 && Math.abs(z - BRIDGE.z) < 6) continue;
      if (Math.hypot(x, z) > this.coast(Math.atan2(z, x)) - 5) continue;
      cherries.push({ x, y: this.height(x, z) - 0.05, z, rotY: R.range(0, 6.28), scale: R.range(0.8, 1.1) });
      this.solidCyl(x, z, 0.35, -1, 5);
    }
    this.add(instanced('tree_cherry', cherries, { height: 5 }));
    // Bandstand (kite perch on its roof).
    const bs = new THREE.Group();
    const k = KITES[2].pos, base = this.height(k.x, k.z);
    const floor = P.cyl(2.8, 2.9, 0.3, '#e8dcc6'); bs.add(floor);
    for (let i = 0; i < 6; i++) { const a = (i / 6) * Math.PI * 2; const c = P.cyl(0.12, 0.12, 2.3, '#f4f0e6'); c.position.set(Math.cos(a) * 2.4, 0.3, Math.sin(a) * 2.4); bs.add(c); }
    const roof = P.cone(3.1, 0.8, '#3e8a7a', { seg: 6 }); roof.position.y = 2.6; bs.add(roof);
    bs.position.set(k.x, base, k.z); this.add(bs);
    this.solidCyl(k.x, k.z, 2.2, base + 2.5, base + 2.65);          // roof (walk under, stand on top)
    this.surface((x, z) => (Math.hypot(x - k.x, z - k.z) < 2.85 ? base + 0.3 : null));
    const bench = P.box(1.4, 0.5, 0.5, '#8a5a2b', { round: 0.05 }); bench.position.set(k.x + 3.6, base, k.z); this.add(bench);
    this.solidBox(k.x + 3.6, k.z, 1.4, 0.5, base - 1, base + 0.5);
    // Bushes, flowers.
    const deco = new THREE.Group();
    for (let i = 0; i < 40; i++) {
      const x = R.range(-38, 38), z = R.range(-28, 8);
      if (Math.hypot(x - CLEARING.x, z - CLEARING.z) < 8.5 || Math.hypot(x, z) > this.coast(Math.atan2(z, x)) - 4) continue;
      const b = P.bush(R.range(0.4, 0.7), R() < 0.5 ? '#5fae4a' : '#4c9a40', i + 9); b.position.set(x, this.height(x, z), z); deco.add(b);
    }
    for (let i = 0; i < 60; i++) {
      const x = R.range(-36, 36), z = R.range(-26, 8);
      if (Math.hypot(x, z) > this.coast(Math.atan2(z, x)) - 4) continue;
      const f = P.sphere(0.09, ['#ffc2d6', '#ffffff', '#ffd24a'][i % 3], { seg: 6 }); f.position.set(x, this.height(x, z) + 0.12, z); f.castShadow = false; deco.add(f);
    }
    this.add(P.bake(deco)); this.add(deco);
  }

  // ── The wind ───────────────────────────────────────────
  buildWind() {
    G.fx.setWeather('petals', { rate: 26, wind: [-0.6, 0] });
    const chip = document.createElement('div');
    chip.style.cssText = 'position:absolute;left:calc(env(safe-area-inset-left,0px) + 12px);top:calc(env(safe-area-inset-top,0px) + 118px);transform-origin:left center;display:flex;align-items:center;gap:8px;background:#fff4dc;border:3px solid #173b44;border-radius:16px;padding:3px 12px 3px 6px;font:800 14px "Baloo 2","Arial Rounded MT Bold",sans-serif;color:#173b44;box-shadow:0 3px 0 rgba(23,59,68,.55);transition:background .2s,transform .2s;pointer-events:none;z-index:2;white-space:nowrap';
    chip.innerHTML = '<span class="wa" style="display:inline-flex;width:26px;height:26px;border-radius:50%;background:#e8f6ff;border:2px solid #173b44;align-items:center;justify-content:center;font-size:16px;transition:transform .2s">↑</span><span class="wt">Calm</span>';
    G.ui.hud.append(chip);
    this.chip = chip;
  }

  windVec() { const d = DIRV[this.wind.dir]; return { x: d[0], z: d[1] }; }

  updateWind(dt) {
    const w = this.wind;
    w.t += dt;
    if (w.phase === 'calm' && w.t > CALM) {
      w.phase = 'warn'; w.t = 0;
      w.dir = DIRS[w.idx++ % DIRS.length];
      G.audio.sfx('gust', { vol: 0.5, rate: 0.85 });
      this.onWarn?.();
    } else if (w.phase === 'warn' && w.t > WARN) {
      w.phase = 'gust'; w.t = 0;
      G.rig.shake = Math.max(G.rig.shake, 0.3);
      G.audio.sfx('gust', { vol: 0.9 });
      this.gustStart();
    } else if (w.phase === 'gust' && w.t > GUST) {
      w.phase = 'calm'; w.t = 0;
      this.gustEnd();
    }
    // Petals: drift in calm, lie flat and stream before a gust, race during it.
    const v = this.windVec();
    const wx = G.fx.weather;
    if (wx) {
      const s = w.phase === 'calm' ? 0.6 : w.phase === 'warn' ? 3.2 : 4.5;
      wx.wind = w.phase === 'calm' ? [-0.4, 0.15] : [v.x * s, v.z * s];
      wx.rate = w.phase === 'calm' ? 24 : w.phase === 'warn' ? 75 : 95;
    }
    G.audio.ambient('winter_wind', w.phase === 'gust' ? 0.45 : w.phase === 'warn' ? 0.2 : 0.04);
    // Gust lift: jumping WITH the wind roughly doubles her arc.
    const p = G.player;
    if (w.phase === 'gust' && !p.grounded && !p.swimming && !G.cine.active) {
      p.velocity.y += 11 * dt;
      p.velocity.x += v.x * 5 * dt; p.velocity.z += v.z * 5 * dt;
    }
    // HUD chip: arrow drawn relative to the camera, tucked under the goal banner.
    if (this.chip) {
      const gb = G.ui.goal.getBoundingClientRect();
      this.chip.style.top = `${Math.max(110, (gb.height ? gb.bottom : 64) + 8)}px`;
      const b = G.render.camBasis();
      const sx = v.x * b.rx + v.z * b.rz, sy = v.x * b.fx + v.z * b.fz;
      const ang = Math.atan2(sx, sy) * 180 / Math.PI;
      const arrow = this.chip.querySelector('.wa');
      arrow.style.transform = `rotate(${ang}deg)`;
      const txt = this.chip.querySelector('.wt');
      const name = DIRNAME[w.dir];
      if (w.phase === 'calm') { txt.textContent = this.kitesHome() >= 4 ? `Calm · kites resting` : 'Calm'; this.chip.style.background = '#fff4dc'; this.chip.style.transform = 'none'; arrow.style.opacity = '0.35'; }
      else if (w.phase === 'warn') { txt.textContent = `Gust coming → ${name}!`; this.chip.style.background = (G.time * 6 | 0) % 2 ? '#ffe39a' : '#fff4dc'; this.chip.style.transform = 'scale(1.08)'; arrow.style.opacity = '1'; }
      else { txt.textContent = `\u{1F4A8} GUST → ${name} — jump!`; this.chip.style.background = '#9fe3ee'; this.chip.style.transform = 'scale(1.12)'; arrow.style.opacity = '1'; }
    }
  }

  // ── The Kite Truants ───────────────────────────────────
  kitesHome() { return KITES.filter((k) => G.state.flag(`eb_kite_flown_${k.id}`)).length; }

  kiteMesh(color) {
    const g = new THREE.Group();
    const sh = new THREE.Shape(); sh.moveTo(0, 0.55); sh.lineTo(0.4, 0); sh.lineTo(0, -0.7); sh.lineTo(-0.4, 0); sh.closePath();
    const face = new THREE.Mesh(new THREE.ShapeGeometry(sh), P.mat(color, { side: THREE.DoubleSide }));
    g.add(face);
    const cross = P.box(0.03, 1.2, 0.03, '#6b4f30', { base: false }); cross.position.y = -0.07; g.add(cross);
    const cross2 = P.box(0.8, 0.03, 0.03, '#6b4f30', { base: false }); g.add(cross2);
    for (let i = 0; i < 3; i++) { const bow = P.box(0.16, 0.08, 0.02, ['#ffffff', color, '#ffffff'][i], { base: false }); bow.position.set(0, -0.85 - i * 0.22, 0); g.add(bow); }
    return g;
  }

  buildKites() {
    // Perches (heights follow the ground they stand on).
    KITES[2].top = this.height(KITES[2].pos.x, KITES[2].pos.z) + 2.65;
    KITES[3].top = this.height(KITES[3].pos.x, KITES[3].pos.z) + 2.6;
    const k0 = KITES[0];
    const pillar = new THREE.Group();
    const col = P.cyl(0.42, 0.48, k0.top - 0.6, '#a9a39a'); pillar.add(col);
    const cap = P.cyl(0.6, 0.5, 0.18, '#8a8f94'); cap.position.y = k0.top - 0.6; pillar.add(cap);
    const glob = P.sphere(0.25, '#fff2c0', { emissive: '#ffd27a', emissiveIntensity: 0.3 }); glob.position.set(0.25, k0.top - 0.15, 0.25); pillar.add(glob);
    pillar.position.set(k0.pos.x, 0.6, k0.pos.z); this.add(pillar);
    this.solidCyl(k0.pos.x, k0.pos.z, 0.6, 0, k0.top);
    const bench = P.box(1.6, 0.5, 0.55, '#8a5a2b', { round: 0.05 }); bench.position.set(k0.pos.x + 1.6, 0.6, k0.pos.z + 0.2); this.add(bench);
    this.solidBox(k0.pos.x + 1.6, k0.pos.z + 0.2, 1.6, 0.55, 0, 1.1);
    const k1 = KITES[1];
    const stack = P.rock(1.5, '#9b8a78', 61, 1.5); stack.position.set(k1.pos.x, k1.top - 1.5 * 1.5 * 1.6, k1.pos.z); this.add(stack);
    this.solidCyl(k1.pos.x, k1.pos.z, 1.3, -6, k1.top);
    const step = P.rock(0.8, '#a6957f', 62, 0.6); step.position.set(k1.pos.x, 0.25 - 0.8 * 0.6 * 1.6, k1.pos.z - 2.4); this.add(step);
    this.solidCyl(k1.pos.x, k1.pos.z - 2.4, 0.75, -6, 0.25);
    const k3 = KITES[3];
    const cherry = model('tree_cherry', { height: 7.4 }); cherry.position.set(CHERRY.x, this.height(CHERRY.x, CHERRY.z) - 0.1, CHERRY.z); this.add(cherry);
    this.bigCherry = cherry;
    this.solidCyl(CHERRY.x, CHERRY.z, 0.55, -1, 4);
    const crown = P.box(2.2, 0.25, 2.2, '#f2a6c2', { round: 0.1 }); crown.position.set(k3.pos.x, k3.top - 0.25, k3.pos.z); crown.visible = false; this.add(crown);
    this.solidBox(k3.pos.x, k3.pos.z, 2.2, 2.2, k3.top - 0.3, k3.top);
    const launch = P.rock(0.45, '#a38668', 63, 0.85); launch.position.set(k3.pos.x + 1.9, this.height(k3.pos.x + 1.9, k3.pos.z + 2.0) - 0.05, k3.pos.z + 2.0); this.add(launch);
    this.solidCyl(k3.pos.x + 1.9, k3.pos.z + 2.0, 0.6, -1, this.height(k3.pos.x + 1.9, k3.pos.z + 2.0) + 0.65);

    // Snagged kites (until collected).
    this.snagged = [];
    for (const k of KITES) {
      if (G.state.flag(`eb_kite_got_${k.id}`)) continue;
      const m = this.kiteMesh(k.color);
      m.position.set(k.pos.x, k.top + 0.9, k.pos.z);
      m.rotation.set(-0.3, k.id, 0.4);
      this.add(m);
      const s = { k, m };
      this.snagged.push(s);
      this.sense(m, { warm: () => true, height: 0, radius: 14 });
      this.every(() => {
        if (!m.parent) return true;
        const gust = this.wind.phase !== 'calm';
        m.rotation.z = 0.4 + Math.sin(G.time * (gust ? 14 : 3) + k.id) * (gust ? 0.35 : 0.1);
        const p = G.player.pos;
        if (Math.hypot(p.x - k.pos.x, p.z - k.pos.z) < 1.3 && Math.abs(p.y - k.top) < 0.7) { this.grabKite(s); return true; }
      });
      // Tapping a kite from below explains the problem instead of grabbing it.
      this.interact({
        obj: m, radius: 3.5, yRange: 6, icon: '\u{1FA81}', priority: -1,
        enabled: () => !!m.parent && G.player.pos.y < k.top - 0.6,
        label: 'A kite, snagged up high',
        use: () => G.ui.say(`Snagged on ${k.where}, out of reach. A plain jump won’t do it… but when a gust comes, jump WITH it.`),
      });
    }

    // Reel posts on the kite beach.
    this.reelKites = [];
    REELS.forEach((pos, i) => {
      const y = this.height(pos.x, pos.z);
      const post = new THREE.Group();
      const pole = P.cyl(0.1, 0.12, 1.1, '#8a5a2b'); post.add(pole);
      const reel = P.cyl(i === 4 ? 0.26 : 0.18, i === 4 ? 0.26 : 0.18, 0.12, i === 4 ? '#c9a46a' : '#e8dcc6', { base: false }); reel.rotation.x = Math.PI / 2; reel.position.y = 0.95; post.add(reel);
      post.position.set(pos.x, y, pos.z); this.add(post);
      this.solidCyl(pos.x, pos.z, 0.2, -1, y + 1.1, { noStand: true });
      const flown = i < 4 ? KITES.find((k) => k.id === i) : null;
      if ((i < 4 && G.state.flag(`eb_kite_flown_${i}`)) || (i === 4 && G.state.flag('eb_reel_mounted'))) this.flyKite(i);
      this.interact({
        obj: post, radius: 1.8, icon: '\u{1FA81}',
        enabled: () => !this.reelKites[i],
        label: () => {
          if (i === 4) return G.state.has('kite_reel') ? 'Mount the old kite reel' : 'A wide, empty reel post';
          return G.state.has('kite') ? 'Fly a kite from this post' : 'An empty reel post';
        },
        use: () => {
          if (i === 4) {
            if (!G.state.has('kite_reel')) { G.ui.say('This post is sized for a bigger reel than the others. One you might have seen boxed up somewhere cold.'); return; }
            G.state.take('kite_reel'); G.state.set('eb_reel_mounted'); this.flyKite(4);
            G.ui.celebrate('The Winnipeg kite flies!', 'A reel from a storm cellar');
            return;
          }
          if (!G.state.has('kite')) { G.ui.say('An empty reel post. Somewhere around the bay, its kite is snagged and sulking.'); return; }
          G.state.take('kite');
          const id = KITES.map((k) => k.id).find((n) => G.state.flag(`eb_kite_got_${n}`) && !G.state.flag(`eb_kite_flown_${n}`));
          G.state.set(`eb_kite_flown_${id ?? i}`);
          this.flyKite(i, KITES[id ?? i]?.color);
          G.audio.sfx('chime', { vol: 0.7 });
          const n = this.kitesHome();
          if (n >= 4) {
            G.state.set('kites_done');
            G.ui.celebrate('Four kites fly!', 'The Kite Truants');
            G.ui.say('Four kites dance over the beach: the island’s living wind gauge. They lurch a beat before every gust.');
          } else G.ui.toast(`Kites home: ${n}/4`, '\u{1FA81}');
        },
      });
    });
  }

  grabKite(s) {
    s.m.removeFromParent();
    G.state.set(`eb_kite_got_${s.k.id}`);
    if (!G.state.give('kite', { quiet: true })) { G.state.set(`eb_kite_got_${s.k.id}`, false); this.add(s.m); return; }
    G.player.showItem('\u{1FA81}');
    G.audio.sfx('pickup_chime', { vol: 0.8 });
    G.ui.toast('Runaway Kite — take it to the reel posts on the kite beach.', '\u{1FA81}');
  }

  flyKite(i, color) {
    const post = REELS[i];
    const y = this.height(post.x, post.z) + 0.95;
    const m = this.kiteMesh(color ?? ['#ff6b4a', '#1fb5c9', '#ffc93c', '#b58cff', '#7bd88f'][i]);
    m.scale.setScalar(1.3);
    this.add(m);
    const string = new THREE.Line(new THREE.BufferGeometry().setFromPoints([V3(), V3()]), new THREE.LineBasicMaterial({ color: '#ffffff' }));
    this.add(string);
    const kite = { m, string };
    this.reelKites[i] = kite;
    const ph = i * 1.3;
    this.every(() => {
      const w = this.wind, v = this.windVec();
      const gust = w.phase === 'gust', warn = w.phase === 'warn';
      const lift = gust ? 9 : warn ? 7 : 5.5;
      const reach = gust ? 5 : warn ? 3 : 1.4;
      const tx = post.x + v.x * reach + Math.sin(G.time * (gust ? 5 : 1.2) + ph) * (warn ? 0.8 : 0.4);
      const tz = post.z - 3 + v.z * reach + Math.cos(G.time * 1.1 + ph) * 0.4;
      const ty = y + lift + Math.sin(G.time * (warn ? 9 : 1.5) + ph) * (warn ? 0.6 : 0.25);
      m.position.lerp(V3(tx, ty, tz), 0.05);
      m.rotation.set(-0.4, Math.atan2(v.x, v.z) * 0.3, Math.sin(G.time * (warn ? 12 : 2) + ph) * (warn ? 0.4 : 0.12));
      const a = string.geometry.attributes.position;
      a.setXYZ(0, post.x, y, post.z); a.setXYZ(1, m.position.x, m.position.y, m.position.z); a.needsUpdate = true;
    });
  }

  // ── The Raccoon Toll ───────────────────────────────────
  buildRaccoons() {
    const paid = G.state.flag('raccoons_paid');
    this.raccoons = [];
    for (let i = 0; i < 3; i++) {
      const r = model('raccoon', { height: 0.75 });
      this.add(r);
      this.raccoons.push(r);
    }
    this.placeRaccoons(paid ? 'stash' : 'stairs');
    this.stairBlock = this.solidBox(20, 11.6, STAIRS.x1 - STAIRS.x0, 3.4, -1, 6, 0, { noStand: true, enabled: !paid });
    this.every(() => {
      for (const [i, r] of this.raccoons.entries()) r.rotation.y = (r.userData.face ?? 0) + Math.sin(G.time * 1.3 + i) * 0.25;
    });
    if (!paid) {
      this.pickup({ id: 'shiny_spoon', pos: V3(SPOON.x, this.height(SPOON.x, SPOON.z), SPOON.z) });
    }
    this.sense(this.raccoons[1], { warm: () => !G.state.flag('raccoons_paid') && G.state.has('shiny_spoon'), height: 0.8 });
    this.interact({
      obj: this.raccoons[1], pos: V3(20, 0.6, 13.6), radius: 2.6, icon: '\u{1F99D}',
      enabled: () => !G.state.flag('raccoons_paid'),
      label: () => (G.state.has('shiny_spoon') ? 'Pay the toll (Shiny Spoon)' : 'Raccoons hold the stairs'),
      use: () => {
        if (!G.state.has('shiny_spoon')) {
          this.raccoonFury();
          G.ui.say('Three raccoons hold the seawall stairs. They hold out tiny hands. Payment. Something shiny.');
          return;
        }
        this.payToll();
      },
    });
    this.onVocal((e) => {
      if (G.state.flag('raccoons_paid') && G.state.flag('dug_eb_stash')) return;
      const near = this.raccoons.some((r) => Math.hypot(e.pos.x - r.position.x, e.pos.z - r.position.z) < 6);
      if (!near) return;
      if (e.kind === 'hiss' || e.kind === 'growl') {
        this.raccoonFury();
        G.ui.toast(e.kind === 'hiss' ? 'The raccoons hiss back. Louder. Raccoons fear nothing.' : 'The raccoons growl back, delighted. They fear nothing at all.', '\u{1F99D}');
      }
    });
    if (paid) this.makeStash();
  }

  /** The stash under the driftwood: only worth digging once you know it's there. */
  makeStash() {
    if (this.stashSpot) return;
    this.stashSpot = this.digSpot({ pos: STASH, key: 'eb_stash', radius: 2.6, warm: () => true, onDug: () => this.hoard() });
  }

  placeRaccoons(where) {
    this.raccoons.forEach((r, i) => {
      if (where === 'stairs') { r.position.set(STAIRS.x0 + 1.1 + i * 1.3, this.height(20, 9.9) , 9.9 + (i % 2) * 0.4); r.userData.face = 0; }
      else { r.position.set(STASH.x - 1.2 + i * 1.1, 0.6, STASH.z + 1.4 + (i % 2) * 0.5); r.userData.face = Math.PI * 0.9; }
    });
  }

  raccoonFury() {
    G.audio.sfx('raccoon', { pos: this.raccoons[0].position, vol: 0.9, jitter: 0.1 });
    this.raccoons.forEach((r, i) => {
      const y0 = r.position.y;
      setTimeout(() => G.animate(0.45, (t) => { r.position.y = y0 + Math.abs(Math.sin(t * Math.PI * 2)) * 0.3; }).then(() => { r.position.y = y0; }), i * 90);
    });
  }

  async payToll() {
    G.state.take('shiny_spoon');
    G.state.set('raccoons_paid');
    this.stairBlock.enabled = false;
    G.audio.sfx('raccoon', { vol: 0.8 });
    await G.cine.run(async (c) => {
      c.look(V3(23, 1, 12), { dist: 11 });
      await c.say('The toll is paid. The raccoons snatch the spoon and scurry off, straight to… wherever they keep things.', { dur: 3.2 });
      const from = this.raccoons.map((r) => r.position.clone());
      this.placeRaccoons('stash');
      const to = this.raccoons.map((r) => r.position.clone());
      this.raccoons.forEach((r, i) => r.position.copy(from[i]));
      c.look(V3(24, 1, 14.5), { dist: 10 });
      await G.animate(1.8, (t) => { this.raccoons.forEach((r, i) => { r.position.lerpVectors(from[i], to[i], t); r.position.y += Math.abs(Math.sin(t * 20 + i)) * 0.15; }); });
      await c.say('They retreat exactly to their stash, under the driftwood. They did not think this through.', { dur: 3 });
    });
    this.makeStash();
    G.ui.celebrate('Toll paid!', 'The stairs are open');
  }

  hoard() {
    G.audio.sfx('raccoon', { pos: STASH, vol: 1 });
    this.raccoonFury();
    G.fx.sparkle(STASH.clone().setY(1), '#ffe48a', 22);
    G.fx.burst(STASH.clone().setY(0.9), { color: ['#d0d0d0', '#ffd24a', '#b58cff', '#ffffff'], count: 26, speed: 3, up: 5, size: 0.16, life: 1.4 });
    G.state.give('brass_lens');
    G.state.set('raccoon_hoard');
    G.ui.celebrate('The hoard!', 'The Raccoon Toll');
    G.ui.say('Spoons, bottle caps, a bicycle bell, nine buttons, one earring… and its crown jewel: a heavy brass lens. The raccoons are furious. Harmlessly, magnificently furious.', { dur: 6 });
  }

  // ── The Blossom Current ────────────────────────────────
  buildBlossom() {
    // Bench with the mosaic.
    const bench = new THREE.Group();
    const seat = P.box(2.2, 0.45, 0.8, '#c9c2b4', { round: 0.06 }); bench.add(seat);
    const mos = new THREE.Mesh(new THREE.PlaneGeometry(1.9, 0.6), new THREE.MeshLambertMaterial({ map: P.textCanvas('', { w: 512, h: 160, bg: '#e8dcc6', draw: (g) => this.drawMosaic(g, 512, 160) }) }));
    mos.rotation.x = -Math.PI / 2; mos.position.y = 0.46; bench.add(mos);
    bench.position.set(BENCH.x, this.height(BENCH.x, BENCH.z), BENCH.z); this.add(bench);
    this.solidBox(BENCH.x, BENCH.z, 2.2, 0.8, -1, this.height(BENCH.x, BENCH.z) + 0.45);
    this.interact({
      obj: bench, radius: 2.2, icon: '\u{1F440}', label: 'Look at the bench mosaic',
      use: () => {
        const c = document.createElement('canvas'); c.width = 620; c.height = 360; c.className = 'art-img';
        this.drawMosaic(c.getContext('2d'), 620, 360, true);
        G.ui.panel('A mosaic set into the bench', c, { buttons: [{ label: 'Close', onClick: (close) => close() }] });
      },
    });
    this.sense(bench, { warm: () => !G.state.flag('blossom_done'), height: 0.6 });
    // Shake the big cherry: action button, or jump and land near the trunk.
    this.interact({
      pos: V3(CHERRY.x, this.height(CHERRY.x, CHERRY.z), CHERRY.z), obj: this.bigCherry, radius: 2.6, icon: '\u{1F338}',
      enabled: () => !G.state.flag('blossom_done'),
      label: 'Shove the blossom tree',
      use: () => this.shakeTree(),
    });
    this.wasAir = false;
    this.every(() => {
      const p = G.player;
      if (!p.grounded) { this.wasAir = true; this.airVy = Math.min(this.airVy ?? 0, p.velocity.y); return; }
      if (this.wasAir) {
        this.wasAir = false;
        const slam = (this.airVy ?? 0) < -6;
        this.airVy = 0;
        if (slam && !G.state.flag('blossom_done') && Math.hypot(p.pos.x - CHERRY.x, p.pos.z - CHERRY.z) < 3 && p.pos.y < 4) this.shakeTree(true);
      }
    });
    // The thicket that hides the clearing's mouth, and the drain grate.
    const grate = P.cyl(0.6, 0.6, 0.05, '#3a4048'); grate.position.set(THICKET.x + 1.6, this.height(THICKET.x + 1.6, THICKET.z) + 0.01, THICKET.z); this.add(grate);
    this.thicket = new THREE.Group();
    const R = rng(77);
    for (let i = 0; i < 6; i++) {
      const b = P.bush(R.range(0.8, 1.1), '#3f8a3a', 300 + i);
      b.position.set(THICKET.x + R.range(-0.6, 0.6), this.height(THICKET.x, THICKET.z), THICKET.z + (i - 2.5) * 0.75);
      this.thicket.add(b);
    }
    this.add(this.thicket);
    this.thicketSolid = this.solidCyl(THICKET.x, THICKET.z, 2.4, -1, 8, { noStand: true });
    if (G.state.flag('blossom_done')) this.openThicket(true);
    this.sense(this.thicket, { warm: () => !G.state.flag('blossom_done'), height: 1 });
  }

  drawMosaic(g, w, h, big = false) {
    g.fillStyle = '#e8dcc6'; g.fillRect(0, 0, w, h);
    const tile = big ? 12 : 8;
    for (let x = 0; x < w; x += tile) for (let y = 0; y < h; y += tile) {
      g.fillStyle = (x * 7 + y * 13) % 5 ? 'rgba(160,140,110,0.08)' : 'rgba(160,140,110,0.18)';
      g.fillRect(x + 1, y + 1, tile - 2, tile - 2);
    }
    // Sea along the bottom edge (south), blossom tree on the right (east), grate on the left (west).
    g.fillStyle = '#4cb4d8'; g.fillRect(0, h * 0.84, w, h * 0.16);
    g.fillStyle = '#6b4a3a'; g.fillRect(w * 0.86, h * 0.35, w * 0.03, h * 0.4);
    g.fillStyle = '#f5a8c4'; g.beginPath(); g.arc(w * 0.875, h * 0.32, h * 0.2, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#3a4048'; g.beginPath(); g.arc(w * 0.1, h * 0.5, h * 0.09, 0, Math.PI * 2); g.fill();
    g.strokeStyle = '#8a8f94'; g.lineWidth = 2;
    for (let k = -2; k <= 2; k++) { g.beginPath(); g.moveTo(w * 0.1 - h * 0.08, h * 0.5 + k * h * 0.03); g.lineTo(w * 0.1 + h * 0.08, h * 0.5 + k * h * 0.03); g.stroke(); }
    // Petals: from the tree, swept westward, spiralling into the grate.
    g.fillStyle = '#f07aa4';
    for (let i = 0; i < 46; i++) {
      const t = i / 45;
      let x = w * (0.82 - t * 0.66), y = h * (0.36 + Math.sin(t * 5) * 0.08);
      if (t > 0.78) { const a = (t - 0.78) * 30; const r = h * 0.16 * (1 - (t - 0.78) / 0.22); x = w * 0.1 + Math.cos(a) * r; y = h * 0.5 + Math.sin(a) * r; }
      g.beginPath(); g.ellipse(x, y, big ? 6 : 4, big ? 3.5 : 2.4, t * 3, 0, Math.PI * 2); g.fill();
    }
    // Little wind swirls drawn in the same direction.
    g.strokeStyle = 'rgba(23,59,68,0.45)'; g.lineWidth = big ? 3 : 2;
    for (let i = 0; i < 3; i++) {
      const y = h * (0.15 + i * 0.12), x0 = w * (0.7 - i * 0.12);
      g.beginPath(); g.moveTo(x0, y); g.lineTo(x0 - w * 0.18, y); g.stroke();
      g.beginPath(); g.moveTo(x0 - w * 0.18, y); g.lineTo(x0 - w * 0.16, y - 6); g.moveTo(x0 - w * 0.18, y); g.lineTo(x0 - w * 0.16, y + 6); g.stroke();
    }
  }

  async shakeTree(slam = false) {
    if (this.shaking || G.state.flag('blossom_done')) return;
    this.shaking = true;
    G.audio.sfx('wood_creak', { pos: CHERRY, vol: 0.8 });
    if (this.bigCherry) {
      const r0 = this.bigCherry.rotation.z;
      G.animate(0.6, (t) => { this.bigCherry.rotation.z = r0 + Math.sin(t * Math.PI * 4) * 0.04 * (1 - t); });
    }
    const top = V3(CHERRY.x, this.height(CHERRY.x, CHERRY.z) + 4.5, CHERRY.z);
    const w = this.wind, v = this.windVec();
    if (w.phase !== 'gust') {
      G.fx.burst(top, { color: ['#ffc2d6', '#ffd9e6'], count: 26, speed: 1.4, up: 0.5, size: 0.2, life: 2.5, gravity: 0.8, shape: 2 });
      G.ui.toast(slam ? 'Thump! Petals drift down… and just lie there. No wind to carry them.' : 'Petals drift down and settle. They need wind to go anywhere.', '\u{1F338}');
    } else if (w.dir !== 'W') {
      G.fx.burst(top, { color: ['#ffc2d6', '#ffd9e6'], count: 40, speed: 2, up: 0.8, size: 0.22, life: 2.5, gravity: 0.4, shape: 2 });
      for (let i = 0; i < 40; i++) G.fx.spawn(top.x, top.y - Math.random() * 2, top.z, { vx: v.x * 7 + (Math.random() - 0.5), vz: v.z * 7 + (Math.random() - 0.5), vy: 0.2, gravity: 0.3, drag: 0.2, size: 0.2, life: 3, color: '#ffc2d6', shape: 2 });
      G.ui.toast(`A cloud of petals whirls off ${DIRNAME[w.dir]}ward. Pretty… but not where the mosaic says.`, '\u{1F338}');
      // A few land on Khione. She sneezes.
      setTimeout(() => { G.fx.burst(G.player.pos.clone().setY(G.player.pos.y + 1), { color: '#ffc2d6', count: 10, speed: 1, up: 1, size: 0.18, life: 1, shape: 2 }); G.audio.sfx('meow', { rate: 1.5, vol: 0.5 }); }, 500);
    } else {
      await this.blossomSolved(top);
    }
    setTimeout(() => { this.shaking = false; }, 700);
  }

  async blossomSolved(top) {
    G.state.set('blossom_done');
    G.ui.celebrate('The petals know the way', 'The Blossom Current');
    const grate = V3(THICKET.x + 1.6, this.height(THICKET.x, THICKET.z) + 0.3, THICKET.z);
    const curve = new THREE.CatmullRomCurve3([top, V3((top.x + grate.x) / 2, 3.4, top.z + 2.2), V3(grate.x + 3, 2.4, grate.z - 1.6), grate]);
    await G.cine.run(async (c) => {
      c.look(V3((CHERRY.x + THICKET.x) / 2, 3, CHERRY.z), { dist: 15, pitch: 45 });
      for (let k = 0; k < 90; k++) {
        const t = k / 90;
        setTimeout(() => {
          const p = curve.getPoint(Math.min(1, t));
          for (let j = 0; j < 3; j++) G.fx.spawn(p.x + (Math.random() - 0.5) * 0.5, p.y + (Math.random() - 0.5) * 0.4, p.z + (Math.random() - 0.5) * 0.5, { vx: 0, vy: -0.1, vz: 0, gravity: 0, drag: 1, size: 0.2, life: 2.5, color: Math.random() < 0.5 ? '#ffc2d6' : '#ff9ac0', shape: 2 });
        }, k * 28 / (G.timeScale || 1));
      }
      await c.say('The gust lifts the petals in a long pink ribbon… exactly the mosaic’s spiral.', { dur: 3 });
      c.look(THICKET.clone().setY(2), { dist: 9 });
      G.fx.burst(grate, { color: ['#ffc2d6', '#ff9ac0'], count: 30, speed: 1.2, up: 0.4, size: 0.2, life: 1.5, shape: 2 });
      await c.wait(0.8);
      this.openThicket(false);
      await c.say('They spiral down the old grate, and the thicket rustles aside. A path, into a clearing nobody mentioned.', { dur: 3.6 });
    });
  }

  openThicket(instant) {
    this.thicketSolid.enabled = false;
    this.thicket.children.forEach((b, i) => {
      const side = i < 3 ? -1 : 1;
      if (instant) { b.position.z += side * 1.6; b.scale.multiplyScalar(0.7); }
      else { G.audio.sfx('push', { vol: 0.5 }); G.tween(b.position, { z: b.position.z + side * 1.6 }, 1.2, ease.out); G.tween(b.scale, { x: 0.7, y: 0.7, z: 0.7 }, 1.2); }
    });
  }

  // ── The Market Scales ──────────────────────────────────
  buildMarket() {
    const y = this.height(STALL.x, STALL.z);
    const stall = new THREE.Group();
    stall.position.set(STALL.x, y, STALL.z);
    const counter = P.box(4, 1, 1.2, '#b07a4a', { round: 0.05 }); stall.add(counter);
    for (const x of [-1.9, 1.9]) { const p = P.cyl(0.08, 0.08, 2.6, '#8a5a2b'); p.position.set(x, 0, 0.5); stall.add(p); const q = P.cyl(0.08, 0.08, 2.6, '#8a5a2b'); q.position.set(x, 0, -0.6); stall.add(q); }
    for (let i = 0; i < 6; i++) {
      const stripe = P.box(4 / 6, 0.08, 1.8, i % 2 ? '#ffffff' : '#ff6b4a', { base: false }); stripe.position.set(-2 + (i + 0.5) * (4 / 6), 2.62, 0); stripe.rotation.x = 0.18; stall.add(stripe);
    }
    // Produce bins along the counter.
    PRODUCE.forEach((p, i) => {
      const bin = P.box(0.75, 0.25, 0.7, '#8a5a2b'); bin.position.set(-1.4 + i * 0.95, 1, 0.15); stall.add(bin);
      for (let k = 0; k < 4; k++) { const f = P.sphere(0.1 + p.price * 0.03, p.color, { seg: 10 }); f.position.set(-1.6 + i * 0.95 + (k % 2) * 0.22, 1.32, 0.05 + (k >> 1) * 0.22); stall.add(f); }
    });
    // Chalkboard.
    const board = P.sign(['FRESH & HONEST', 'Plum $1 · Apple $2', 'Pear $3 · Melon $5', '$1 a pound, always'], { w: 1.6, h: 1.2, post: 0.3, bg: '#2f3a36', fg: '#f4f0e6', border: '#8a5a2b', font: 'bold 50px "Baloo 2", sans-serif' });
    board.position.set(-2.8, 0, 0.6); board.rotation.y = 0.3; stall.add(board);
    this.add(stall);
    this.solidBox(STALL.x, STALL.z, 4, 1.2, -1, y + 1, 0);
    this.interact({ obj: board, radius: 2.2, icon: '\u{1F440}', label: 'Read the chalkboard', use: () => G.ui.panel('The chalkboard', '<p style="font-size:20px;text-align:center;line-height:1.6"><b>FRESH &amp; HONEST</b><br>Plum … $1<br>Apple … $2<br>Pear … $3<br>Melon … $5<br><i>Everything $1 a pound. Always.</i></p>', { buttons: [{ label: 'Close', onClick: (c) => c() }] }) });

    // The hanging scale beside the stall.
    const sp = V3(STALL.x + 3.4, y, STALL.z + 0.6);
    const sc = new THREE.Group(); sc.position.copy(sp);
    const post = P.cyl(0.1, 0.12, 3.2, '#5a4a3a'); sc.add(post);
    const beam = new THREE.Group(); beam.position.y = 3.1; sc.add(beam);
    const bar = P.box(2.4, 0.08, 0.08, '#c9a46a', { base: false }); beam.add(bar);
    const mkPan = (x) => {
      const g = new THREE.Group(); g.position.x = x; beam.add(g);
      for (const dx of [-0.25, 0.25]) { const s = P.cyl(0.01, 0.01, 1.4, '#888', { base: false }); s.position.set(dx, -0.7, 0); g.add(s); }
      const pan = P.cyl(0.4, 0.32, 0.08, '#c9a46a', { base: false }); pan.position.y = -1.42; g.add(pan);
      return g;
    };
    this.panL = mkPan(-1.1); this.panR = mkPan(1.1);
    this.beam = beam;
    const key = new THREE.Group();
    const ring = P.torus(0.12, 0.03, '#ffd24a'); ring.rotation.x = Math.PI / 2; key.add(ring);
    const shaft = P.box(0.32, 0.05, 0.05, '#ffd24a', { base: false }); shaft.position.x = 0.26; key.add(shaft);
    const weight = P.cyl(0.16, 0.18, 0.22, '#55595e'); weight.position.set(-0.12, -0.02, 0.1); key.add(weight);
    key.position.set(0, -1.32, 0); this.panL.add(key);
    this.keyMesh = key;
    this.fruitOnPan = new THREE.Group(); this.fruitOnPan.position.y = -1.36; this.panR.add(this.fruitOnPan);
    this.add(sc);
    this.solidCyl(sp.x, sp.z, 0.2, -1, y + 3.2, { noStand: true });
    this.scalePos = sp;
    this.tilt = 0.3;
    if (G.state.flag('scales_done')) { this.panL.remove(key); this.tilt = 0; }
    this.interact({
      obj: sc, radius: 2.4, icon: '⚖️',
      enabled: () => !G.state.flag('scales_done'),
      label: 'Weigh produce on the scale',
      use: () => this.openScale(),
    });
    this.sense(board, { warm: () => !G.state.flag('scales_done'), height: 1.2 });
    let still = 0;
    this.every((dt) => {
      const right = this.panWeight();
      const done = G.state.flag('scales_done');
      const diff = done ? 0 : right - KEY_PAN;
      let target = clamp(-diff * 0.08, -0.35, 0.35);
      const gust = this.wind.phase === 'gust';
      if (gust && !done) target += Math.sin(G.time * 9) * 0.22;
      this.tilt += (target - this.tilt) * Math.min(1, dt * 3);
      beam.rotation.z = this.tilt;
      this.panL.rotation.z = -this.tilt; this.panR.rotation.z = -this.tilt;
      if (!done && diff === 0 && !gust && !G.ui.modalOpen) {
        still += dt;
        if (still > 1.5) this.scaleBalanced();
      } else still = 0;
    });
    // Cash drawer under the counter (stall key).
    const drawer = P.box(0.9, 0.3, 0.1, '#7a5030'); drawer.position.set(STALL.x + 1.2, y + 0.4, STALL.z + 0.62); this.add(drawer);
    this.drawer = drawer;
    this.interact({
      obj: drawer, radius: 1.8, icon: '\u{1F511}',
      enabled: () => !G.state.flag('drawer_open'),
      label: () => (G.state.has('stall_key') ? 'Unlock the cash drawer' : 'A locked cash drawer'),
      use: () => {
        if (!G.state.has('stall_key')) { G.ui.say('A little cash drawer, locked. The stall’s key is hanging somewhere honest.'); return; }
        G.state.take('stall_key'); G.state.set('drawer_open');
        G.audio.sfx('gate_open', { vol: 0.5, rate: 1.6 });
        G.tween(drawer.position, { z: drawer.position.z + 0.4 }, 0.4);
        G.state.give('ranger_key');
        G.ui.say('No cash. Just a key on a cedar tag, stamped with a tiny suspension bridge. Park Ranger, Lions Gate.');
      },
    });
  }

  panWeight() { return PRODUCE.reduce((s, p) => s + (this.produce[p.id] ?? 0) * p.price, 0); }

  refreshPanFruit() {
    const g = this.fruitOnPan;
    while (g.children.length) g.remove(g.children[0]);
    let k = 0;
    for (const p of PRODUCE) for (let i = 0; i < (this.produce[p.id] ?? 0); i++) {
      const f = P.sphere(0.07 + p.price * 0.025, p.color, { seg: 10 });
      const a = k * 1.9; f.position.set(Math.cos(a) * 0.18 * Math.min(1, k), 0.08 + (k > 3 ? 0.12 : 0), Math.sin(a) * 0.18 * Math.min(1, k));
      g.add(f); k++;
    }
  }

  openScale() {
    const wrap = document.createElement('div');
    wrap.style.cssText = 'display:flex;flex-direction:column;align-items:center;gap:8px;width:100%';
    const c = document.createElement('canvas'); c.width = 520; c.height = 200; c.className = 'art-img';
    const status = document.createElement('p'); status.style.cssText = 'margin:0;text-align:center;font-weight:800';
    const grid = document.createElement('div'); grid.style.cssText = 'display:grid;grid-template-columns:1fr 1fr;gap:8px;width:100%';
    const draw = () => {
      const g = c.getContext('2d'), right = this.panWeight(), diff = right - KEY_PAN;
      g.fillStyle = '#fffaf0'; g.fillRect(0, 0, 520, 200);
      const ang = clamp(-diff * 0.08, -0.35, 0.35);
      g.save(); g.translate(260, 50); g.rotate(ang);
      g.fillStyle = '#c9a46a'; g.fillRect(-180, -5, 360, 10);
      g.restore();
      g.fillStyle = '#5a4a3a'; g.fillRect(255, 50, 10, 140);
      const ly = 50 - Math.sin(ang) * 180, ry = 50 + Math.sin(ang) * 180;
      g.fillStyle = '#c9a46a';
      g.beginPath(); g.ellipse(80, ly + 90, 60, 14, 0, 0, Math.PI * 2); g.fill();
      g.beginPath(); g.ellipse(440, ry + 90, 60, 14, 0, 0, Math.PI * 2); g.fill();
      g.strokeStyle = '#888'; g.lineWidth = 2;
      for (const [x, yy] of [[80, ly], [440, ry]]) { g.beginPath(); g.moveTo(x, yy); g.lineTo(x - 40, yy + 88); g.moveTo(x, yy); g.lineTo(x + 40, yy + 88); g.stroke(); }
      drawIcon(g, '\u{1F511}', 80, ly + 66, 48);
      let k = 0;
      for (const p of PRODUCE) for (let i = 0; i < (this.produce[p.id] ?? 0); i++) { g.fillStyle = p.color; g.beginPath(); g.arc(410 + (k % 4) * 20, ry + 78 - (k >> 2) * 18, 6 + p.price * 1.6, 0, Math.PI * 2); g.fill(); k++; }
      status.textContent = diff === 0 ? 'Level! Step back and let it settle in the stillness…' : diff < 0 ? 'The key’s pan hangs lower. Needs more.' : 'The produce pan sinks. Too much.';
      grid.querySelectorAll('button').forEach((b) => {
        const p = PRODUCE.find((q) => q.id === b.dataset.id);
        if (p) b.textContent = `+ ${p.name} (${p.n - (this.produce[p.id] ?? 0)} left)`;
      });
    };
    for (const p of PRODUCE) {
      const b = document.createElement('button'); b.className = 'btn small secondary'; b.dataset.id = p.id;
      b.addEventListener('click', () => {
        if ((this.produce[p.id] ?? 0) >= p.n) { G.ui.toast(`No more ${p.name.toLowerCase()}s in the bin.`, '\u{1F34E}'); return; }
        this.produce[p.id] = (this.produce[p.id] ?? 0) + 1;
        G.audio.sfx('coin', { vol: 0.4, rate: 0.8 });
        this.refreshPanFruit(); draw();
      });
      grid.append(b);
    }
    const clear = document.createElement('button'); clear.className = 'btn small secondary'; clear.textContent = 'Empty the pan';
    clear.style.gridColumn = '1 / span 2';
    clear.addEventListener('click', () => { this.produce = {}; this.refreshPanFruit(); draw(); });
    grid.append(clear);
    wrap.append(c, status, grid);
    G.ui.panel('The hanging scale', wrap, { buttons: [{ label: 'Done', primary: true, onClick: (close) => close() }] });
    draw();
  }

  scaleBalanced() {
    if (G.state.flag('scales_done')) return;
    G.state.set('scales_done');
    G.audio.sfx('bell_ding', { pos: this.scalePos, vol: 0.9 });
    this.panL.remove(this.keyMesh);
    G.ui.celebrate('Perfectly level!', 'The Market Scales');
    G.ui.say('In the stillness, the pans level out. The key’s pan dips into reach, and the key slides onto the counter.');
    const sp = this.scalePos;
    this.pickup({ id: 'stall_key', pos: V3(sp.x - 1.1, sp.y + 1.05, sp.z + 0.1), radius: 2 });
  }

  // ── The Totem's Gaze ───────────────────────────────────
  targetStep(pole) {
    const a = Math.atan2(pole.target.x - pole.pos.x, pole.target.z - pole.pos.z);
    return ((Math.round(a / STEP) % 8) + 8) % 8;
  }
  poleStep(pole) {
    const v = G.state.flags[`eb_pole_${pole.key}`];
    if (typeof v === 'number') return v;
    const scr = { raven: 3, bear: 5, orca: 2 }[pole.key];
    return (this.targetStep(pole) + scr) % 8;
  }
  aligned(pole) { return this.poleStep(pole) === this.targetStep(pole); }
  allAligned() { return POLES.every((p) => this.aligned(p)); }

  buildClearing() {
    // Hedge ring with the mouth facing east (the thicket).
    const R = rng(55);
    const hedge = new THREE.Group();
    for (let i = 0; i < 26; i++) {
      const a = (i / 26) * Math.PI * 2;
      if (Math.abs(Math.atan2(Math.sin(a), Math.cos(a))) < 0.32) continue;
      const x = CLEARING.x + Math.cos(a) * 6.6, z = CLEARING.z + Math.sin(a) * 6.6;
      const b = P.bush(R.range(0.9, 1.2), '#3f8a3a', 400 + i); b.position.set(x, this.height(x, z), z); hedge.add(b);
      this.solidCyl(x, z, 0.95, -1, 8, { noStand: true });
    }
    this.add(P.bake(hedge)); this.add(hedge);
    // Three poles on round plinths.
    for (const pole of POLES) {
      const y = this.height(pole.pos.x, pole.pos.z);
      const plinth = P.cyl(1.0, 1.15, 0.35, '#8c8a84'); plinth.position.set(pole.pos.x, y - 0.05, pole.pos.z); this.add(plinth);
      const g = new THREE.Group(); g.position.set(pole.pos.x, y + 0.3, pole.pos.z);
      // Generated poles come out facing ~45° off +z; turn them so the carved face meets the gaze stone.
      const m = model(pole.model, { height: pole.key === 'raven' ? 5.4 : 4.8, rotY: -Math.PI / 4 });
      g.add(m);
      // A carved gaze-stone so the facing reads clearly from the iso camera.
      const gaze = P.cone(0.18, 0.5, '#ffd24a', { emissive: '#ffb020', emissiveIntensity: 0.2 }); gaze.rotation.x = Math.PI / 2; gaze.position.set(0, 0.08, 0.95); gaze.castShadow = false;
      g.add(gaze);
      g.rotation.y = this.poleStep(pole) * STEP;
      this.add(g);
      pole.g = g;
      this.solidCyl(pole.pos.x, pole.pos.z, 0.95, -1, y + 6, { noStand: true });
      this.interact({
        pos: V3(pole.pos.x, y, pole.pos.z), obj: g, radius: 2.3, icon: '\u{1FAB5}',
        enabled: () => !G.state.flag('eb_song'),
        label: `Shove the ${pole.key} pole${pole.heavy ? ' (heavy)' : ''}`,
        use: () => this.shovePole(pole),
      });
      this.sense(g, { warm: () => !G.state.flag('eb_song') && !this.aligned(pole), height: 2.5 });
    }
    // The lowest carving on the orca pole (Oreo artifact) shows under Whisker Sense.
    this.onVocal((e) => {
      if (e.kind !== 'meow' || G.state.hasArtifact('eb_waiting_dog')) return;
      const orca = POLES[2];
      if (Math.hypot(e.pos.x - orca.pos.x, e.pos.z - orca.pos.z) > 3.2) return;
      G.fx.shimmer(V3(orca.pos.x, this.height(orca.pos.x, orca.pos.z) + 0.8, orca.pos.z), true);
      G.ui.say('Under Whisker Sense, the lowest carving on the pole shows itself, weathered but unmistakable: a dog, lying down, waiting.', { dur: 5 });
      G.state.addArtifact('eb_waiting_dog', 'englishbay', 'The Lowest Carving', 'At the foot of a carved pole in English Bay: a dog, lying down, waiting. Very old. Very patient.');
    });
    // The plaque.
    const plaque = P.sign(['Raven · Bear · Orca', 'each faces its home'], { w: 1.5, h: 0.9, post: 0.5, bg: '#3b4a3a', fg: '#f4f0e6', border: '#c9a46a', font: 'bold 48px "Baloo 2", sans-serif' });
    const pp = V3(CLEARING.x + 4.4, 0, CLEARING.z - 1.8);
    plaque.position.set(pp.x, this.height(pp.x, pp.z), pp.z); plaque.rotation.y = Math.PI / 2 + 0.3; this.add(plaque);
    this.solidBox(pp.x, pp.z, 0.4, 1.5, -1, this.height(pp.x, pp.z) + 1.4, 0, { noStand: true });
    this.interact({ obj: plaque, radius: 2.0, icon: '\u{1F440}', label: 'Read the weathered plaque', use: () => this.openPlaque() });
    this.sense(plaque, { warm: () => G.state.flag('blossom_done') && !this.allAligned(), height: 1.2 });

    if (G.state.flag('eb_song')) this.afterSong(true);
  }

  openPlaque() {
    const c = document.createElement('canvas'); c.width = 620; c.height = 330; c.className = 'art-img';
    const g = c.getContext('2d');
    g.fillStyle = '#3b4a3a'; g.fillRect(0, 0, 620, 330);
    g.strokeStyle = '#c9a46a'; g.lineWidth = 8; g.strokeRect(8, 8, 604, 314);
    g.fillStyle = '#f4f0e6'; g.font = 'bold 26px "Baloo 2", sans-serif'; g.textAlign = 'center';
    g.fillText('THE THREE WHO FACE THEIR HOMES', 310, 48);
    g.font = '56px "Apple Color Emoji","Segoe UI Emoji",sans-serif';
    const rows = [['\u{1F426}‍⬛', '→', '\u{1F332}', 'Raven → the tallest tree'], ['\u{1F43B}', '→', '\u{1F333}\u{1F333}', 'Bear → the forest’s open door'], ['\u{1F40B}', '→', '\u{1F30A}', 'Orca → the open sea']];
    rows.forEach(([a, arr, b, t], i) => {
      const y = 112 + i * 72;
      drawIcon(g, a, 70, y - 14, 54);
      const twin = b.length > 2 && !b.includes('‍') ? [...b] : [b];
      twin.forEach((e, k) => drawIcon(g, e, 210 + (k - (twin.length - 1) / 2) * 34, y - 14, twin.length > 1 ? 40 : 54));
      g.font = '44px "Apple Color Emoji","Segoe UI Emoji",sans-serif'; g.textAlign = 'center';
      g.fillStyle = '#c9a46a'; g.fillText(arr, 140, y); g.fillStyle = '#f4f0e6';
      // Shrink a long line to fit inside the plaque frame.
      let px = 26; g.textAlign = 'left';
      do g.font = `bold ${px--}px "Baloo 2", sans-serif`; while (px > 16 && g.measureText(t).width > 315);
      g.fillText(t, 280, y - 8);
    });
    const note = document.createElement('p');
    note.innerHTML = '<small>Carved in red cedar by master carvers of the Northwest Coast, whose living tradition tells the stories of family and place. Please treat them with respect.</small>';
    const wrap = document.createElement('div'); wrap.append(c, note);
    G.ui.panel('A weathered plaque', wrap, {
      buttons: [
        { label: 'Look at the back', onClick: () => {
          G.ui.closeSheet(true);
          const d = document.createElement('canvas'); d.width = 620; d.height = 300; d.className = 'art-img';
          const q = d.getContext('2d');
          q.fillStyle = '#d9c7a4'; q.fillRect(0, 0, 620, 300);
          q.strokeStyle = '#555'; q.lineWidth = 3; q.lineCap = 'round';
          q.beginPath(); q.moveTo(160, 220); q.lineTo(460, 220); q.lineTo(430, 250); q.lineTo(190, 250); q.closePath(); q.stroke();
          q.beginPath(); q.moveTo(310, 220); q.lineTo(310, 80); q.lineTo(390, 200); q.lineTo(310, 200); q.stroke();
          q.beginPath(); q.arc(240, 175, 16, 0, 7); q.stroke(); q.beginPath(); q.moveTo(240, 191); q.lineTo(240, 215); q.moveTo(225, 200); q.lineTo(255, 200); q.stroke();
          q.beginPath(); q.moveTo(229, 162); q.lineTo(232, 150); q.lineTo(238, 160); q.moveTo(242, 160); q.lineTo(248, 150); q.lineTo(251, 162); q.stroke();
          q.beginPath(); q.ellipse(370, 200, 30, 12, 0, 0, 7); q.stroke(); q.beginPath(); q.arc(400, 182, 13, 0, 7); q.stroke();
          q.beginPath(); q.moveTo(405, 172); q.lineTo(414, 162); q.moveTo(340, 196); q.lineTo(326, 186); q.stroke();
          q.font = 'italic 22px "Bradley Hand","Segoe Print",cursive'; q.fillStyle = '#555'; q.textAlign = 'center'; q.fillText('(pencil, very faint)', 310, 285);
          G.ui.panel('The back of the plaque', d, { buttons: [{ label: 'Close', onClick: (cl) => cl() }] });
          G.state.addArtifact('eb_raft_doodle', 'englishbay', 'A Doodle on the Plaque', 'In faint pencil on the back of the totem plaque: a stick-figure dog and cat, together on a raft. She has never told anyone about the raft.');
        } },
        { label: 'Close', primary: true, onClick: (cl) => cl() },
      ],
    });
  }

  async shovePole(pole) {
    if (this.shoving) return;
    if (pole.heavy) {
      const o = G.oreo;
      if (!o?.active || o.mode === 'stay' || Math.hypot(o.pos.x - pole.pos.x, o.pos.z - pole.pos.z) > 9) {
        G.ui.say('The bear pole won’t budge for one small cat. It needs someone bigger leaning in too.');
        G.audio.sfx('fail', { vol: 0.5 });
        return;
      }
      this.shoving = true;
      const side = V3(pole.pos.x + 1.4, 0, pole.pos.z + 1.0);
      await o.goTo(side, 0.6, 6.5);
      o.faceTo(pole.pos);
      o.mode = 'follow';
      o.bark();
    }
    this.shoving = true;
    if (this.wind.phase === 'gust') this.songBroken = true;
    const next = (this.poleStep(pole) + 1) % 8;
    G.state.flags[`eb_pole_${pole.key}`] = next;
    G.state.save();
    G.player.emote('pickup', 2.4);
    G.audio.sfx('stone_slide', { pos: pole.pos, vol: 0.8, rate: pole.heavy ? 0.7 : 0.9 });
    const from = pole.g.rotation.y;
    await G.tween(pole.g.rotation, { y: from + STEP }, 0.6, ease.inOut);
    pole.g.rotation.y = next * STEP;
    this.shoving = false;
    if (this.aligned(pole)) {
      G.fx.sparkle(V3(pole.pos.x, this.height(pole.pos.x, pole.pos.z) + 3, pole.pos.z), '#ffe48a', 10);
      G.ui.toast(`The ${pole.key} settles, facing ${pole.home}.`, '✨');
    }
    if (this.allAligned()) G.ui.toast('All three face their homes. Now… the wind.', '\u{1F343}');
  }

  gustStart() {
    this.songBroken = false;
    this.songArmed = !G.state.flag('eb_song') && G.state.flag('blossom_done') && this.allAligned() && Math.hypot(G.player.pos.x - CLEARING.x, G.player.pos.z - CLEARING.z) < 22;
    // Aligned poles whistle their note as the gust passes through their carved mouths.
    if (!G.state.flag('eb_song') && Math.hypot(G.player.pos.x - CLEARING.x, G.player.pos.z - CLEARING.z) < 22) {
      POLES.forEach((pole, i) => {
        if (!this.aligned(pole)) return;
        setTimeout(() => {
          G.audio.tone(pole.note, { dur: 1.4, vol: 0.3, type: 'triangle' });
          G.fx.ring(V3(pole.pos.x, this.height(pole.pos.x, pole.pos.z) + 4.5, pole.pos.z), '#bdf2ff', 1.6, 1);
        }, i * 650);
      });
    }
  }

  async gustEnd() {
    if (!this.songArmed) return;
    this.songArmed = false;
    if (this.songBroken || !this.allAligned()) { G.ui.toast('The song breaks off. Hold them steady through a whole gust.', '\u{1F3B5}'); return; }
    G.state.set('eb_song');
    G.state.set('eb_sunset');
    G.ui.celebrate('The poles sing!', 'An old song, an ocean ago');
    await G.cine.run(async (c) => {
      c.look(CLEARING.clone().setY(3.5), { dist: 14, pitch: 35 });
      for (const [i, f] of [880, 587, 392].entries()) { G.audio.tone(f, { dur: 1.8, vol: 0.35 }); G.fx.ring(V3(POLES[i].pos.x, 6, POLES[i].pos.z), '#ffe48a', 2.4, 1.2); await c.wait(0.7); }
      await c.say('Three notes, together. She knows this tune: the hollow stones’ song, an ocean ago… written by whoever keeps walking one island ahead.', { dur: 4.5 });
      G.render.setAtmosphere(this.sunsetAtmo());
      await c.say('The light leans gold. Sunset comes to the clearing all at once.', { dur: 3 });
      this.afterSong(false);
      c.look(CLEARING.clone().setY(1), { dist: 10, pitch: 55 });
      await c.say('The carved eyes catch the sun and throw three thin beams. They cross at one spot of lawn.', { dur: 3.6 });
    });
  }

  afterSong(instant) {
    const spot = V3(CLEARING.x, this.height(CLEARING.x, CLEARING.z), CLEARING.z);
    if (!G.state.flag('dug_eb_strongbox')) {
      for (const pole of POLES) {
        const from = V3(pole.pos.x, this.height(pole.pos.x, pole.pos.z) + 4.2, pole.pos.z);
        const len = from.distanceTo(spot);
        const b = P.beam(len, 0.18, '#ffe9a8', 0.55);
        b.position.copy(from);
        b.lookAt(spot);
        this.add(b);
        (this.beams ??= []).push(b);
      }
      const glowSpot = P.glow('#ffd24a', 0.18); glowSpot.position.copy(spot).add(V3(0, 0.2, 0)); this.add(glowSpot);
      this.glowSpot = glowSpot;
      this.every(() => { if (!glowSpot.parent) return true; glowSpot.userData.update(G.time); });
      this.digSpot({
        pos: spot, key: 'eb_strongbox', radius: 2.6, warm: () => true,
        onDug: () => { this.beams?.forEach((b) => b.removeFromParent()); glowSpot.removeFromParent(); this.spawnStrongbox(spot); G.ui.say('Oreo’s paws hit metal. A park ranger’s strongbox, buried right where the beams met.'); },
      });
    } else this.spawnStrongbox(spot);
  }

  spawnStrongbox(spot) {
    if (this.box) return;
    const box = model('chest', { height: 0.7 });
    box.position.copy(spot); this.add(box);
    this.box = box;
    this.interact({
      obj: box, radius: 1.8, icon: '\u{1F5DD}️',
      enabled: () => !G.state.flag('eb_box_open'),
      label: () => (G.state.has('ranger_key') ? 'Unlock the strongbox' : 'A locked ranger’s strongbox'),
      use: () => {
        if (!G.state.has('ranger_key')) { G.ui.say('PARK RANGER — LIONS GATE, stencilled on the lid. Locked tight. Somebody keeps the ranger’s key somewhere ordinary.'); return; }
        G.state.take('ranger_key'); G.state.set('eb_box_open');
        G.audio.sfx('gate_open', { vol: 0.6, rate: 1.4 });
        G.state.give('winch_crank');
        G.ui.celebrate('The winch crank!', 'The Totem’s Gaze');
        G.ui.say('Inside: a heavy iron winch crank. Out on the west cliff, the little Lions Gate is still standing on its end.');
      },
    });
    this.sense(box, { warm: () => !G.state.flag('eb_box_open'), height: 0.6 });
  }

  // ── The miniature Lions Gate ───────────────────────────
  buildBridge() {
    const y = this.height(BRIDGE.x, BRIDGE.z);
    this.deckY = y + 0.05;
    const green = '#3e8a5a';
    // Towers out over the water.
    for (const x of [-46, -52]) for (const dz of [-1.3, 1.3]) {
      const t = P.box(0.5, 10, 0.5, green); t.position.set(x, -2, BRIDGE.z + dz); this.add(t);
      const cap = P.box(0.6, 0.4, 3.1, green); cap.position.set(x, 7.6, BRIDGE.z); this.add(cap);
    }
    // Deck on a hinge at the cliff.
    const hinge = new THREE.Group(); hinge.position.set(BRIDGE.x, this.deckY, BRIDGE.z); this.add(hinge);
    const deck = P.box(15, 0.25, 2.4, '#7a7570', { base: false }); deck.position.x = -7.5; hinge.add(deck);
    for (let i = 0; i < 2; i++) { const rail = P.box(15, 0.4, 0.08, '#c75a3a', { base: false }); rail.position.set(-7.5, 0.3, i ? 1.15 : -1.15); hinge.add(rail); }
    this.hinge = hinge;
    const down = G.state.flag('eb_bridge_down');
    hinge.rotation.z = down ? 0 : -1.25;
    this.deckSurface = this.surface((x, z) => (x < BRIDGE.x + 0.3 && x > BRIDGE.x - 15 && Math.abs(z - BRIDGE.z) < 1.1 ? this.deckY + 0.13 : null), { enabled: down });
    // Keep her on the deck.
    this.deckRails = [-1, 1].map((s) => this.solidBox(BRIDGE.x - 7.5, BRIDGE.z + s * 1.35, 15, 0.3, this.deckY - 1, this.deckY + 1.5, 0, { noStand: true, enabled: down }));
    // Cables (visual).
    for (const dz of [-1.3, 1.3]) {
      const pts = [];
      for (let i = 0; i <= 12; i++) { const x = -42 + (-56 + 42) * (i / 12); pts.push(V3(x, this.deckY + 1 + Math.pow(Math.abs(x + 49) / 7, 2) * 4.6, BRIDGE.z + dz)); }
      this.add(P.rope(pts, 0.05, '#c75a3a'));
    }
    // The winch wheel.
    const wy = this.height(WINCH.x, WINCH.z);
    const wh = new THREE.Group(); wh.position.set(WINCH.x, wy, WINCH.z);
    const stand = P.box(0.3, 1.2, 0.3, '#5a4a3a'); wh.add(stand);
    const wheel = P.torus(0.6, 0.08, '#8a5a2b'); wheel.position.y = 1.3; wheel.rotation.y = Math.PI / 2; wh.add(wheel);
    for (let i = 0; i < 4; i++) { const sp = P.box(0.05, 1.2, 0.05, '#8a5a2b', { base: false }); sp.position.y = 1.3; sp.rotation.x = i * Math.PI / 4; sp.rotation.order = 'YXZ'; sp.rotation.y = Math.PI / 2; wh.add(sp); }
    this.add(wh);
    this.wheel = wheel; this.wheelGroup = wh;
    this.solidBox(WINCH.x, WINCH.z, 0.6, 0.6, -1, wy + 1.9, 0, { noStand: true });
    this.interact({
      obj: wh, radius: 2.2, icon: '⚙️',
      enabled: () => !G.state.flag('eb_bridge_down'),
      label: () => (G.state.has('winch_crank') || G.state.flag('eb_crank_fitted') ? 'Turn the winch together' : 'A winch with no crank'),
      use: () => this.turnWinch(),
    });
    this.sense(wh, { warm: () => G.state.has('winch_crank'), height: 1.2 });
    this.interact({
      pos: V3(BRIDGE.x - 1.2, this.deckY, BRIDGE.z), radius: 2.4, icon: '\u{1F305}',
      enabled: () => G.state.flag('eb_bridge_down') && !this.leaving,
      label: 'Walk out over the water',
      use: () => this.leave(),
    });
    this.trigger({ pos: V3(BRIDGE.x - 5, 0, BRIDGE.z), radius: 2.2, enabled: true, onEnter: () => { if (G.state.flag('eb_bridge_down') && !this.leaving) this.leave(); } });
  }

  async turnWinch() {
    if (!G.state.has('winch_crank') && !G.state.flag('eb_crank_fitted')) {
      G.ui.say('A big winch wheel with an empty square socket where a crank belongs. The little bridge stands on its end, waiting.');
      return;
    }
    if (G.state.has('winch_crank')) { G.state.take('winch_crank'); G.state.set('eb_crank_fitted'); G.audio.sfx('push', { vol: 0.6 }); }
    if (!G.oreo?.active) { G.ui.say('The crank fits, but the wheel is heavy. Two would turn it.'); return; }
    G.state.set('eb_bridge_down');
    await G.cine.run(async (c) => {
      c.look(V3(BRIDGE.x - 4, this.deckY + 2, BRIDGE.z), { dist: 14, pitch: 30 });
      G.oreo.goTo(V3(WINCH.x + 0.9, 0, WINCH.z + 0.6), 0.5, 6);
      await c.say('Both of them on the wheel. Cat paws, dog shoulder.', { dur: 2.2 });
      G.audio.sfx('wood_creak', { vol: 0.8, rate: 0.7 });
      G.animate(3.2, (t) => { this.wheel.rotation.x = t * Math.PI * 6; });
      await G.tween(this.hinge.rotation, { z: 0 }, 3.2, ease.inOut);
      G.audio.sfx('gate_open', { vol: 0.8, rate: 0.6 });
      G.rig.shake = 0.4;
      this.deckSurface.enabled = true;
      this.deckRails.forEach((r) => { r.enabled = true; });
      await c.say('The little Lions Gate lowers out over the water, gold with sunset.', { dur: 3 });
    });
    G.oreo.follow();
    G.ui.celebrate('The bridge is down!', 'Walk out over the water');
  }

  async leave() {
    if (this.leaving) return;
    this.leaving = true;
    await G.cine.run(async (c) => {
      const start = V3(BRIDGE.x - 1, this.deckY + 0.13, BRIDGE.z);
      G.player.teleport(start.x, start.z, -Math.PI / 2, start.y);
      G.oreo.teleport(start.x + 0.2, start.z + 0.7, -Math.PI / 2);
      G.oreo.mode = 'busy';
      c.look(V3(BRIDGE.x - 8, this.deckY + 1, BRIDGE.z), { dist: 16, pitch: 22, yaw: 150, speed: 1 });
      const walk = this.every((dt) => {
        G.player.pos.x -= 2.2 * dt; G.player.pos.y = this.deckY + 0.13; G.player.velocity.set(-2.2, 0, 0);
        G.oreo.pos.x = G.player.pos.x + 0.3; G.oreo.vel.set(-2.2, 0, 0);
        if (G.player.pos.x < BRIDGE.x - 14.4) G.player.pos.x = BRIDGE.x - 14.4;
      });
      G.fx.setWeather('petals', { rate: 60, wind: [-2.5, 0] });
      await c.say('And so they simply walk out over the water at sunset, petals behind them.', { dur: 4 });
      await c.say('Somewhere ahead, the wind smells of home.', { dur: 3 });
      this.updaters.splice(this.updaters.indexOf(walk), 1);
    });
    G.oreo.follow();
    await G.game.finishIsland();
  }

  // ── Arrival, frame, goals ─────────────────────────────
  async onEnter(first) {
    if (!first || G.state.flag('eb_intro')) return;
    await G.cine.run(async (c) => {
      c.cut(V3(0, 2, 8), { dist: 40, pitch: 35, yaw: 20 });
      c.look(V3(0, 2, 8), { dist: 34, pitch: 38, yaw: 50, speed: 0.4 });
      await c.say('English Bay, at blossom time. The wind here never stops coming off the water.', { dur: 4 });
      c.look(G.player.pos.clone().setY(1), { dist: 9, speed: 0.9 });
      await c.say('It comes in waves: the petals lie flat a beat before every gust. Jump WITH a gust, and it carries you twice as high.', { dur: 5 });
    });
    G.state.set('eb_intro');
  }

  update(dt) {
    this.updateWind(dt);
  }

  objective() {
    const s = G.state;
    if (!s.flag('raccoons_paid')) return s.has('shiny_spoon') ? 'Pay the raccoons’ toll at the seawall stairs' : 'Raccoons hold the seawall stairs. They want something shiny';
    if (!s.flag('dug_eb_stash')) return 'Follow the raccoons to their stash';
    if (!s.flag('kites_done')) return `Return the runaway kites (${this.kitesHome()}/4 home)`;
    if (!s.flag('blossom_done')) return 'The bench mosaic knows where the petals go';
    if (!s.flag('drawer_open')) return s.flag('scales_done') ? 'The stall key opens the cash drawer' : 'Win the key off the market’s hanging scale';
    if (!s.flag('eb_song')) return this.allAligned() ? 'Hold the poles steady through a gust' : 'Turn each carved pole to face its home';
    if (!s.flag('dug_eb_strongbox')) return 'Dig where the beams cross';
    if (!s.flag('eb_box_open')) return 'Open the ranger’s strongbox';
    if (!s.flag('eb_bridge_down')) return 'Wind the little Lions Gate down';
    return 'Walk out over the water';
  }
  hint() {
    const s = G.state;
    if (!s.flag('raccoons_paid')) return 'Raccoons hold the seawall stairs and will not scatter for a hiss (raccoons fear nothing). They want payment: something shiny. The kite beach sand glitters here and there.';
    if (!s.flag('dug_eb_stash')) return 'Paying the toll taught the real lesson: they ran straight to their stash. Mark it with a meow, and Oreo will dig.';
    if (!s.flag('kites_done')) return 'Four kites escaped their reels and snagged around the bay. Gusts come in readable waves; the petals lie flat a beat before. Jump WITH a gust to double the arc, then bring each kite to a reel post on the kite beach.';
    if (!s.flag('blossom_done')) return 'Cherry petals stream along the wind. The bench mosaic shows a petal path spiralling into a drain grate. Shake the big blossom tree (shove it, or jump and slam down beside it) when the gust blows the way the mosaic does.';
    if (!s.flag('drawer_open')) return 'The market’s hanging scale holds the stall key on its high pan. Counterweight it with produce. The chalkboard’s prices are honest: $1 a pound. Weigh in the stillness, between gusts.';
    if (!s.flag('eb_song')) return 'Three carved poles: Raven, Bear, Orca. The plaque shows each facing its home: sky-tree, forest, sea. Shove them round (the bear needs Oreo’s shoulder too), then hold them steady through one full gust; the kites give the warning.';
    if (!s.flag('dug_eb_strongbox')) return 'The carved eyes throw three beams at sunset. Where they cross, she marks, he digs.';
    if (!s.flag('eb_box_open')) return 'The strongbox wants the ranger’s key. The market’s cash drawer keeps one.';
    if (!s.flag('eb_bridge_down')) return 'The winch crank fits the little Lions Gate on the west cliff. Both of them on the wheel.';
    return 'The bridge is down. Walk out over the water.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.flag('raccoons_paid')) return s.has('shiny_spoon') ? V3(20, 1, 12) : SPOON;
    if (!s.flag('dug_eb_stash')) return STASH;
    if (!s.flag('kites_done')) {
      if (s.has('kite')) return REELS[0];
      const k = KITES.find((q) => !s.flag(`eb_kite_got_${q.id}`));
      return k ? k.pos.clone().setY(k.top) : REELS[0];
    }
    if (!s.flag('blossom_done')) return BENCH;
    if (!s.flag('drawer_open')) return STALL;
    if (!s.flag('eb_song')) return CLEARING;
    if (!s.flag('eb_box_open')) return CLEARING;
    return WINCH;
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'kites', name: 'The Kite Truants', done: s.flag('kites_done'), hint: 'Four kites escaped their reels and snagged around the bay. Jump with the gusts.' },
      { id: 'blossom', name: 'The Blossom Current', done: s.flag('blossom_done'), hint: 'A bench mosaic shows a petal path spiralling into a drain grate.' },
      { id: 'raccoon', name: 'The Raccoon Toll', done: s.flag('dug_eb_stash'), hint: 'Raccoons hold the seawall stairs. They want something shiny.' },
      { id: 'scales', name: 'The Market Scales', done: s.flag('scales_done'), hint: 'The stall key hangs on the high pan of an honest scale.' },
      { id: 'totem', name: 'The Totem’s Gaze', done: s.flag('island6_complete'), hint: 'Raven, Bear, Orca: each faces its home.' },
    ];
  }
}
