// Island 7 — Agrea. "The whole journey, in one small place."
// A memory palace: six mini-districts (one per island) ring a quiet West End
// block with one particular house. Six shrines remix each island's main riddle
// for mastery; each lights a beacon and returns a memory shard. Then the bells,
// the Letter Table, the melody at the door — and the ending.
// Built from docs/design/riddle-compendium.md (Island 7 · Agrea).
import * as THREE from 'three';
import { G, rng, clamp, fbm, ease, V3 } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';
import { LETTER, registerItems } from '../engine/state.js';

registerItems({
  memory_shard: { name: 'Memory Shard', icon: '\u{1F48E}', desc: 'A sliver of warm light. Holding it, she almost remembers somebody laughing.' },
});

const WATER = -0.4;
const HOUSE = V3(0, 0.3, -7);
const TABLE = V3(0, 0.3, 1.2);
const BELLS = V3(-4.6, 0.3, 1.8);
const DOGHOUSE = V3(5.2, 0.3, -1.6);
const SPAWN = V3(0, 0, 26);

// The six shrines, ringed around the house.
const SHRINES = [
  { n: 1, id: 'ahalo', name: 'Ahalo Shrine', pos: V3(-17, 0.3, 9), color: '#ffd24a',
    memory: 'A beach. A little white cat chasing snails, and somebody laughing from far away.' },
  { n: 2, id: 'eaton', name: 'Eaton Shrine', pos: V3(-19, 0.3, -7), color: '#ff9a5a',
    memory: 'A mall in winter, warm and bright. A small hand pointing up at sixty geese.' },
  { n: 3, id: 'calgary', name: 'Calgary Shrine', pos: V3(-9, 0.3, -20), color: '#7bd88f',
    memory: 'A park by a turquoise river. A leash, a ball, a bench in the sun. He remembers the yard.' },
  { n: 4, id: 'winnipeg', name: 'Winnipeg Shrine', pos: V3(9, 0.3, -20), color: '#bdf2ff',
    memory: 'First snow. A dog who could not believe his luck, and a cat who could not believe the cold.' },
  { n: 5, id: 'galleon', name: 'Galleon Shrine', pos: V3(19, 0.3, -7), color: '#5fd8e8',
    memory: 'An indoor sea, a wooden ship, a kid shrieking with joy on the big wave.' },
  { n: 6, id: 'totem', name: 'Totem Shrine', pos: V3(17, 0.3, 9), color: '#ff9ad5',
    memory: 'Cherry petals on a seawall wind. A house with a red door, and somebody waiting inside.' },
];

// The letter's melody: the hollow stones' song (high → low), carried on by the
// totems, finished at last with its fifth note. Each note has a colour.
const NOTES = [
  { f: 784, color: '#ffc93c', name: 'gold' },
  { f: 659, color: '#1fb5c9', name: 'teal' },
  { f: 523, color: '#ff6b4a', name: 'coral' },
  { f: 587, color: '#7bd88f', name: 'green' },
  { f: 392, color: '#9a7bff', name: 'violet' },
];
const PHRASE = [0, 1, 2, 3, 4];

// Letter Table pieces: the torn letter in reading order (header and signature
// are carved into the table already).
const TABLE_PIECES = (() => {
  const out = [];
  for (const p of LETTER) {
    if (p.by === 0 || p.sig) continue;
    const last = out[out.length - 1];
    if (last && last.by === p.by && !last.br) { last.t += ' ' + p.t; last.br = p.br; }
    else out.push({ t: p.t, by: p.by, br: p.br });
  }
  return out.map((p, i) => ({ ...p, i }));
})();

const wrapA = (a) => { while (a > Math.PI) a -= Math.PI * 2; while (a < -Math.PI) a += Math.PI * 2; return a; };
const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

export default class Agrea extends Island {
  static id = 'agrea';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 0, r: 46 };
    this.moundColor = '#f4f7fb';
  }

  models() { return ['house_westend', 'goose', 'pole_raven', 'pole_bear', 'pole_orca', 'tiki', 'galleon', 'tree_cherry', 'palm', 'snowman', 'tree_pine', 'tree_leafy', 'canoe', 'chest']; }
  sounds() { return ['bell_ding', 'chime', 'bark', 'whimper', 'stone_slide', 'gate_open', 'success', 'fanfare', 'big_wave', 'splash', 'wood_creak', 'geese', 'snow_dig', 'whisker_shimmer', 'ocean_loop', 'park_birds']; }
  atmosphere() {
    return { sky: '#ffe3c4', fog: '#ffe3c4', fogNear: 40, fogFar: 110, sun: '#ffd9a8', sunIntensity: 2.3, hemi: 1.3, skyLight: '#fff1dc', groundLight: '#8a7a6a', exposure: 1.08 };
  }
  terrainTextures() { return ['sand.jpg', 'grass.jpg', 'snow.jpg']; }

  coast(theta) { return 37 + 2 * Math.sin(3 * theta + 0.4) + 1.2 * Math.sin(7 * theta + 2.0); }
  height(x, z) {
    const d = Math.hypot(x, z), coast = this.coast(Math.atan2(z, x));
    if (d >= coast) return -6 * clamp((d - coast) / 10, 0, 1) + 0.02 * fbm(x * 0.2, z * 0.2);
    let h = 0.3 * (1 - ss(coast - 4.5, coast - 1.2, d));
    // The never-melting drift and a few snow humps in the Winnipeg corner.
    const w = SHRINES[3].pos;
    const dw = Math.hypot(x - w.x, z - w.z);
    if (dw < 6) h += 0.18 * (1 - dw / 6) * (0.6 + 0.4 * fbm(x * 0.5, z * 0.5));
    return h;
  }
  splat(x, z) {
    const d = Math.hypot(x, z), coast = this.coast(Math.atan2(z, x));
    const a = SHRINES[0].pos, w = SHRINES[3].pos;
    let sand = clamp((d - (coast - 5)) / 1.5, 0, 1);
    sand = Math.max(sand, clamp((6.5 - Math.hypot(x - a.x, z - a.z)) / 1.5, 0, 1));
    const snow = clamp((6.8 - Math.hypot(x - w.x, z - w.z)) / 1.5, 0, 1);
    const grass = Math.max(0, 1 - sand - snow);
    return [sand, grass, snow];
  }
  tint(x, z) {
    const h = this.height(x, z);
    const c = new THREE.Color('#ffffff');
    if (h < WATER) c.lerp(new THREE.Color('#6ab0a6'), clamp((WATER - h) / 4, 0, 0.8));
    c.multiplyScalar(0.94 + fbm(x * 0.13, z * 0.13) * 0.1);
    return c;
  }
  footstep(x, z) { const [s, g] = this.splat(x, z); return g > 0.5 ? 'paw_grass' : 'paw_sand'; }
  dustColor(x, z) { const [s, g, w] = this.splat(x, z); return w > 0.5 ? '#ffffff' : g > 0.5 ? '#a8d88a' : '#ecd6a4'; }

  spawn() {
    if (G.state.flag('agrea_finale_done')) return { x: 0, z: 4, rotY: Math.PI };
    return { x: SPAWN.x, z: SPAWN.z, rotY: Math.PI };
  }

  lit(n) { return G.state.flag(`agrea_s${n}`); }

  /**
   * Caption that resolves on its own timer. (G.ui.say() drops the previous
   * caption's promise when a new caption interrupts it, which would stall an
   * awaiting cutscene forever.)
   */
  say2(text, opts = {}) {
    const d = opts.dur ?? Math.min(6, 1.6 + text.length * 0.045);
    G.ui.say(text, { ...opts, dur: d });
    return new Promise((r) => setTimeout(r, (d * 1000) / (G.timeScale || 1)));
  }
  litCount() { return SHRINES.filter((s) => this.lit(s.n)).length; }

  // ── Build ──────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 100, res: 120, repeat: 0.2 });
    this.makeWater({ level: WATER, size: 280, res: 110, colors: { deep: '#2fa8c0', light: '#8fe0e8' } });
    G.audio.ambient('ocean_loop', 0.16);
    G.audio.ambient('park_birds', 0.12);
    G.fx.setWeather('petals', { rate: 6, wind: [0.5, 0.15] });
    this.beacons = {};
    this.buildBlock();
    this.buildDistricts();
    this.buildAhaloShrine(SHRINES[0]);
    this.buildEatonShrine(SHRINES[1]);
    this.buildCalgaryShrine(SHRINES[2]);
    this.buildWinnipegShrine(SHRINES[3]);
    this.buildGalleonShrine(SHRINES[4]);
    this.buildTotemShrine(SHRINES[5]);
    for (const s of SHRINES) this.buildBeacon(s);
    this.buildBells();
    this.buildTable();
    this.buildDoor();
    // After the ending screen, she can keep exploring (the engine leaves the HUD hidden).
    this.on('ending_closed', () => G.ui.showHUD(true));
    for (const s of SHRINES) {
      this.trigger({ pos: s.pos, radius: 6, once: true, onEnter: () => G.ui.showBanner(`~ ${s.name} ~`, 2) });
    }
  }

  // The West End block: the house, a picket fence, a doghouse, paths.
  buildBlock() {
    const house = model('house_westend', { height: 8.5 });
    house.position.copy(HOUSE);
    this.add(house);
    this.house = house;
    // House body + its own front steps (the model's red door sits right of centre, up the steps).
    this.solidBox(HOUSE.x, HOUSE.z - 0.4, 7.0, 8.6, -1, 8);
    this.solidBox(HOUSE.x + 1.2, HOUSE.z + 4.75, 2.2, 1.7, -1, 1.0);
    const deco = new THREE.Group();
    // Picket fence around the front yard, open at the gate.
    const picket = (a, b) => deco.add(P.fence(a, b, { h: 0.75, gap: 0.5, color: '#f4efe4', rails: 2 }));
    picket(V3(-7.5, 0.3, 4.5), V3(-1.4, 0.3, 4.5));
    picket(V3(1.4, 0.3, 4.5), V3(7.5, 0.3, 4.5));
    picket(V3(-7.5, 0.3, 4.5), V3(-7.5, 0.3, -11));
    picket(V3(7.5, 0.3, 4.5), V3(7.5, 0.3, -11));
    for (const [x, z, w, d] of [[-4.45, 4.5, 6.1, 0.2], [4.45, 4.5, 6.1, 0.2], [-7.5, -3.25, 0.2, 15.5], [7.5, -3.25, 0.2, 15.5]]) this.solidBox(x, z, w, d, -1, 1.05);
    // Paths: stepping stones from the dock to the gate, and a ring to the shrines.
    const R = rng(77);
    const stone = (x, z, r = 0.55) => {
      const s = P.cyl(r, r * 1.05, 0.08, R() < 0.5 ? '#cfc2a8' : '#bfb196', { seg: 9 });
      s.position.set(x, this.height(x, z) - 0.02, z); s.rotation.y = R() * 6; s.castShadow = false;
      deco.add(s);
    };
    for (let z = 24; z > 5; z -= 1.3) stone(Math.sin(z * 0.4) * 0.6, z);
    for (let i = 0; i < 64; i++) {
      const a = (i / 64) * Math.PI * 2, r = 15.5;
      stone(Math.cos(a) * r, Math.sin(a) * r, 0.45);
    }
    // Lawn flowers and bushes inside the fence.
    for (let i = 0; i < 26; i++) {
      const x = R.range(-6.8, 6.8), z = R.range(-10.5, 3.8);
      if (Math.abs(x) < 4.2 && z < 0.5 && z > -10.5) continue;
      if (Math.abs(x) < 1.6 && z > 0) continue;
      const f = P.sphere(0.1, ['#ff6b8a', '#ffd24a', '#ffffff', '#b58cff'][i % 4], { seg: 6 });
      f.position.set(x, 0.42, z); f.castShadow = false; deco.add(f);
    }
    for (const [x, z] of [[-6.3, 3.6], [6.3, 3.6], [-6.4, -9.8], [6.4, -9.8]]) { const b = P.bush(0.75, '#5fb84a', x * 7); b.position.set(x, 0.3, z); deco.add(b); }
    // A mailbox post by the gate and a lamppost — the street she knows.
    const lampPost = P.cyl(0.07, 0.09, 2.6, '#3c4a52'); lampPost.position.set(2.2, 0.3, 5.2); deco.add(lampPost);
    this.add(P.bake(deco)); this.add(deco);
    const lampHead = P.sphere(0.2, '#fff2b0', { emissive: '#ffd27a', emissiveIntensity: 0.8 }); lampHead.position.set(2.2, 3.0, 5.2); this.add(lampHead);
    this.solidCyl(2.2, 5.2, 0.15, -1, 3);

    // The doghouse.
    const dh = new THREE.Group();
    const body = P.box(1.5, 1.1, 1.6, '#c96a4a', { round: 0.05 }); dh.add(body);
    const roofShape = new THREE.Shape(); roofShape.moveTo(-0.95, 0); roofShape.lineTo(0.95, 0); roofShape.lineTo(0, 0.75); roofShape.closePath();
    const rg = new THREE.ExtrudeGeometry(roofShape, { depth: 1.8, bevelEnabled: false }); rg.translate(0, 1.1, -0.9);
    const roof = new THREE.Mesh(rg, P.mat('#5a3d2e')); roof.castShadow = true; dh.add(roof);
    const hole = new THREE.Mesh(new THREE.CircleGeometry(0.36, 16, 0, Math.PI), P.mat('#1d1512')); hole.position.set(0, 0.25, 0.81); dh.add(hole);
    const holeB = new THREE.Mesh(new THREE.PlaneGeometry(0.72, 0.25), P.mat('#1d1512')); holeB.position.set(0, 0.125, 0.81); dh.add(holeB);
    const nameSign = P.sign('OREO', { w: 0.9, h: 0.28, font: 'bold 120px "Baloo 2", sans-serif', bg: '#fff4dc' });
    nameSign.position.set(0, 1.12, 0.83); dh.add(nameSign);
    const bowl = P.cyl(0.2, 0.16, 0.1, '#1fb5c9'); bowl.position.set(0.7, 0, 1.2); dh.add(bowl);
    dh.position.copy(DOGHOUSE); dh.rotation.y = -0.5;
    this.add(dh);
    this.solidBox(DOGHOUSE.x, DOGHOUSE.z, 1.6, 1.7, -1, 1.85, 0.5);
    let dhSeen = 0;
    this.interact({
      obj: dh, radius: 2.2, icon: '\u{1F3E0}', label: 'A doghouse',
      use: () => {
        dhSeen++;
        if (dhSeen === 1) G.ui.say('A food bowl, licked clean. A name painted over the door, in a child’s careful letters.');
        else { G.ui.say('Oreo sniffs the doorway for a long time. Then he lies down in front of it, like he always has.'); G.oreo?.bark(); }
      },
    });
  }

  // Little echoes of every island around the ring.
  buildDistricts() {
    const R = rng(4041);
    // Ahalo: palms on a sand patch.
    const a = SHRINES[0].pos;
    const palms = [[-3.5, -2.5], [3.8, 2.2], [-2.6, 3.4]].map(([dx, dz], i) => ({ x: a.x + dx, y: 0.25, z: a.z + dz, rotY: i * 2, scale: 0.9 + i * 0.1 }));
    this.add(instanced('palm', palms, { height: 5.2 }));
    for (const p of palms) this.solidCyl(p.x, p.z, 0.3, -1, 4);
    // Eaton: a goose in flight on a pole and a mall-tile plaza.
    const e = SHRINES[1].pos;
    const plaza = P.box(7, 0.06, 7, '#efe2c4'); plaza.position.set(e.x, 0.27, e.z); plaza.castShadow = false; this.add(plaza);
    // Calgary: the red lattice bridge over a little turquoise stream.
    const c = SHRINES[2].pos;
    const stream = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 9), new THREE.MeshLambertMaterial({ color: '#5fd8e8', emissive: '#2a8fb0', emissiveIntensity: 0.25 }));
    stream.rotation.x = -Math.PI / 2; stream.position.set(c.x - 5.5, 0.33, c.z + 1); this.add(stream);
    const bridge = new THREE.Group();
    for (const side of [-0.6, 0.6]) {
      const arc = P.torus(1.6, 0.06, '#d8402f', { arc: Math.PI }); arc.position.set(0, 0, side); bridge.add(arc);
    }
    for (let i = 0; i <= 6; i++) {
      const t = (i / 6) * Math.PI;
      const rib = P.box(0.06, 0.06, 1.2, '#d8402f', { base: false });
      rib.position.set(Math.cos(t) * 1.6, Math.sin(t) * 1.6, 0); bridge.add(rib);
    }
    bridge.position.set(c.x - 5.5, 0.3, c.z + 1); bridge.rotation.y = Math.PI / 2;
    this.add(bridge);
    // Winnipeg: pines + a snowman.
    const w = SHRINES[3].pos;
    const pines = [[4, -3], [-4.5, -2.5], [3.5, 3.5]].map(([dx, dz], i) => ({ x: w.x + dx, y: this.height(w.x + dx, w.z + dz), z: w.z + dz, rotY: i, scale: 1 }));
    this.add(instanced('tree_pine', pines, { height: 4.2 }));
    for (const p of pines) this.solidCyl(p.x, p.z, 0.5, -1, 3);
    const snowman = model('snowman', { height: 1.5 }); snowman.position.set(w.x - 3.2, this.height(w.x - 3.2, w.z + 2.6), w.z + 2.6); snowman.rotation.y = 0.6; this.add(snowman);
    this.solidCyl(w.x - 3.2, w.z + 2.6, 0.5, -1, 1.5);
    // Galleon: the Santa Maria, beached in a tiny lagoon.
    const g = SHRINES[4].pos;
    const lagoon = new THREE.Mesh(new THREE.CircleGeometry(3.4, 32), new THREE.MeshLambertMaterial({ color: '#2fb5cc', transparent: true, opacity: 0.9 }));
    lagoon.rotation.x = -Math.PI / 2; lagoon.position.set(g.x + 4.5, 0.32, g.z - 4); this.add(lagoon);
    const ship = model('galleon', { height: 4.2 }); ship.position.set(g.x + 4.5, 0.15, g.z - 4); ship.rotation.y = 0.8; ship.rotation.z = 0.08; this.add(ship);
    this.solidCyl(g.x + 4.5, g.z - 4, 2.2, -1, 3);
    // Totems: cherry trees + the tall "sky-tree" the raven faces.
    const t = SHRINES[5].pos;
    const cherries = [[-4.5, -3.5], [4.5, 3.8], [-1, 5.2]].map(([dx, dz], i) => ({ x: t.x + dx, y: 0.3, z: t.z + dz, rotY: i, scale: 1 + i * 0.08 }));
    this.add(instanced('tree_cherry', cherries, { height: 4.6 }));
    for (const p of cherries) this.solidCyl(p.x, p.z, 0.4, -1, 3);
    // Scattered grass bushes and beach rocks for texture.
    const deco = new THREE.Group();
    for (let i = 0; i < 30; i++) {
      const ang = R.range(0, 6.28), r = R.range(24, 31);
      const x = Math.cos(ang) * r, z = Math.sin(ang) * r;
      if (z > 18 && Math.abs(x) < 6) continue;
      if (R() < 0.5) { const b = P.bush(R.range(0.4, 0.8), '#5aa844', i); b.position.set(x, this.height(x, z), z); deco.add(b); }
      else { const rk = P.rock(R.range(0.4, 0.9), '#b9a07c', i + 7); rk.position.set(x, this.height(x, z) - 0.1, z); deco.add(rk); }
    }
    // A small dock at the south landing.
    for (let i = 0; i < 6; i++) {
      const plank = P.box(2.4, 0.12, 0.5, '#a0662e', { round: 0.02 });
      plank.position.set(0, 0.18, 29 + i * 0.55); deco.add(plank);
    }
    this.add(P.bake(deco)); this.add(deco);
    this.surface((x, z) => (Math.abs(x) < 1.25 && z > 28.6 && z < 32.4 ? 0.3 : null));
    const canoe = model('canoe', { size: 3.2 }); canoe.position.set(1.9, WATER + 0.05, 31.5); canoe.rotation.y = Math.PI / 2; this.add(canoe);
    this.every(() => { canoe.position.y = WATER + 0.05 + Math.sin(G.time * 1.3) * 0.04; });
  }

  // ── Beacons ────────────────────────────────────────────
  buildBeacon(s) {
    const out = V3(s.pos.x, 0, s.pos.z).normalize();
    const bp = s.pos.clone().addScaledVector(out, 3.2);
    const g = new THREE.Group();
    const base = P.cyl(0.45, 0.6, 1.5, '#cfc3ae', { round: 0.04 }); g.add(base);
    const bowl = P.cyl(0.55, 0.3, 0.3, '#a89a84'); bowl.position.y = 1.5; g.add(bowl);
    const orb = P.sphere(0.32, '#8a8a8a', { emissive: s.color, emissiveIntensity: 0 });
    orb.material = orb.material.clone(); orb.position.y = 2.0; g.add(orb);
    const col = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.4, 14, 12, 1, true),
      new THREE.MeshBasicMaterial({ color: s.color, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    col.position.y = 9; g.add(col);
    g.position.set(bp.x, this.height(bp.x, bp.z), bp.z);
    this.add(g);
    this.solidCyl(bp.x, bp.z, 0.6, -1, 2.3);
    this.beacons[s.n] = { g, orb, col, pos: bp };
    if (this.lit(s.n)) this.setBeacon(s.n, true, false);
    this.every(() => { if (this.lit(s.n)) { col.material.opacity = 0.3 + Math.sin(G.time * 2 + s.n) * 0.06; orb.position.y = 2.0 + Math.sin(G.time * 1.5 + s.n) * 0.08; } });
  }
  setBeacon(n, on, animate = true) {
    const b = this.beacons[n];
    const s = SHRINES[n - 1];
    if (!animate) { b.orb.material.emissiveIntensity = 1.6; b.orb.material.color.set(s.color); b.col.material.opacity = 0.3; return; }
    b.orb.material.color.set(s.color);
    G.animate(1.2, (t) => { b.orb.material.emissiveIntensity = t * 1.6; b.col.material.opacity = t * 0.3; });
    G.fx.sparkle(b.pos.clone().setY(2.4), [s.color, '#ffffff', '#fff2b0'], 22);
    G.fx.ring(b.pos.clone().setY(b.g.position.y + 0.05), s.color, 4.5, 1.2);
  }

  /** A shrine is solved: light its beacon, return its memory shard. */
  async solveShrine(n) {
    if (this.lit(n)) return;
    const s = SHRINES[n - 1];
    G.state.set(`agrea_s${n}`);
    G.state.give('memory_shard', { quiet: true });
    G.audio.duck(0.25, 4);
    G.audio.sfx('fanfare', { vol: 0.6 });
    const b = this.beacons[n];
    await G.cine.run(async (c) => {
      c.look(b.pos.clone().setY(2), { dist: 9, pitch: 35, speed: 2.5 });
      await c.wait(0.5);
      this.setBeacon(n, true);
      G.ui.celebrate('A beacon lights!', `${s.name} · ${this.litCount()}/6`);
      G.player.emote('happy', 1.6);
      G.player.showItem('\u{1F48E}');
      await c.wait(1.2);
      await this.say2(s.memory, { dur: 4.2 });
    });
    if (this.litCount() === 6) await this.raiseTable();
    else G.ui.toast(`Memory shard returned · ${this.litCount()}/6`, '\u{1F48E}');
  }

  // ── Shrine 1 · Ahalo: five water-worn stones, the melody is the order ──
  buildAhaloShrine(s) {
    const c = s.pos;
    // Pitches assigned to stones whose sizes no longer mean anything.
    const layout = [[-2.6, 1.0, 2], [-1.3, -1.9, 4], [1.2, -2.2, 0], [2.7, 0.6, 3], [0.1, 2.6, 1]];
    this.ahaloStones = layout.map(([dx, dz, note], i) => {
      const x = c.x + dx, z = c.z + dz;
      const g = new THREE.Group();
      const body = P.rock(0.75, '#9aa6c4', 300 + i, 1.4);
      body.material = body.material.clone();
      g.add(body);
      g.position.set(x, this.height(x, z) - 0.1, z);
      this.add(g);
      this.solidCyl(x, z, 0.6, -1, this.height(x, z) + 1.0);
      this.sense(g, { height: 1.2 });
      return { g, body, note, pos: V3(x, 0, z) };
    });
    // The water-worn carving: a melody's contour, not sizes.
    const slab = new THREE.Group();
    const st = P.box(2.0, 1.4, 0.3, '#b7a68a', { round: 0.1 }); slab.add(st);
    const face = new THREE.Mesh(new THREE.PlaneGeometry(1.7, 1.0), new THREE.MeshLambertMaterial({ map: this.contourTexture(true), transparent: true }));
    face.position.set(0, 0.75, 0.16); slab.add(face);
    const sp = c.clone().add(V3(0, 0, -4.6));
    slab.position.set(sp.x, this.height(sp.x, sp.z) - 0.05, sp.z);
    slab.rotation.y = Math.atan2(c.x - sp.x, c.z - sp.z);
    this.add(slab);
    this.solidBox(sp.x, sp.z, 2.0, 0.5, -1, 1.4);
    this.sense(slab, { warm: () => !this.lit(1), height: 1 });
    this.interact({ obj: slab, radius: 2.4, icon: '\u{1F440}', label: 'A water-worn carving', use: () => this.openContour() });
    this.ahaloProg = 0;
    this.onVocal((e) => {
      if (e.kind !== 'meow' || this.lit(1)) return;
      let best = null, bd = 3.0;
      for (const st2 of this.ahaloStones) { const d = Math.hypot(e.pos.x - st2.pos.x, e.pos.z - st2.pos.z); if (d < bd) { bd = d; best = st2; } }
      if (!best) return;
      const note = NOTES[best.note];
      G.audio.tone(note.f, { dur: 1.1, vol: 0.4 });
      best.body.material.emissive = new THREE.Color(note.color);
      G.animate(0.9, (t) => { best.body.material.emissiveIntensity = 0.9 * (1 - t); });
      G.fx.ring(best.g.position.clone().setY(best.g.position.y + 0.1), note.color, 2, 0.8);
      if (best.note === PHRASE[this.ahaloProg]) {
        this.ahaloProg++;
        if (this.ahaloProg >= PHRASE.length) { this.ahaloProg = 0; setTimeout(() => this.solveShrine(1), 700); }
      } else {
        this.ahaloProg = best.note === PHRASE[0] ? 1 : 0;
        G.ui.toast('The water hushes, patient. Begin again.', '\u{1F30A}');
      }
    });
  }

  contourTexture(worn) {
    return P.textCanvas('', {
      w: 512, h: 300, bg: null, draw: (g) => this.drawContour(g, 512, 300, worn),
    });
  }
  drawContour(g, w, h, worn) {
    // Five notes as stones on water-lines: higher pitch sits higher.
    const ys = (f) => h * 0.85 - ((f - 380) / 420) * h * 0.7;
    g.strokeStyle = 'rgba(107,79,48,0.45)'; g.lineWidth = 4;
    for (let k = 0; k < 4; k++) { g.beginPath(); for (let x = 20; x < w - 20; x += 8) { const y = h * (0.2 + k * 0.2) + Math.sin(x * 0.05 + k) * 4; x === 20 ? g.moveTo(x, y) : g.lineTo(x, y); } g.stroke(); }
    g.strokeStyle = '#6b4f30'; g.lineWidth = 6;
    g.beginPath();
    PHRASE.forEach((ni, i) => { const x = w * (0.14 + i * 0.18), y = ys(NOTES[ni].f); i ? g.lineTo(x, y) : g.moveTo(x, y); });
    g.stroke();
    PHRASE.forEach((ni, i) => {
      const x = w * (0.14 + i * 0.18), y = ys(NOTES[ni].f);
      g.fillStyle = worn ? '#6b4f30' : NOTES[ni].color;
      g.strokeStyle = '#173b44'; g.lineWidth = worn ? 0 : 4;
      g.beginPath(); g.arc(x, y, 18, 0, Math.PI * 2); g.fill(); if (!worn) g.stroke();
    });
  }
  playPhrase(gap = 520) {
    PHRASE.forEach((ni, i) => setTimeout(() => G.audio.tone(NOTES[ni].f, { dur: 0.9, vol: 0.38 }), i * gap));
  }
  openContour() {
    G.audio.sfx('stone_slide', { vol: 0.5 });
    const c = document.createElement('canvas'); c.width = 620; c.height = 320;
    const g = c.getContext('2d');
    g.fillStyle = '#d9c7a4'; g.fillRect(0, 0, 620, 320);
    this.drawContour(g, 620, 320, true);
    c.className = 'art-img';
    const wrap = document.createElement('div');
    wrap.append(c);
    const p = document.createElement('p');
    p.innerHTML = '<small>The spirals have worn away. What is left is a line of stones climbing and falling, like a song. Meow at each stone to hear its voice.</small>';
    wrap.append(p);
    G.ui.panel('A water-worn carving', wrap, {
      buttons: [
        { label: 'Hum the line \u{1F3B5}', onClick: () => this.playPhrase() },
        { label: 'Close', primary: true, onClick: (close) => close() },
      ],
    });
  }

  // ── Shrine 2 · Eaton: one goose, one lamp, one mirror ──
  buildEatonShrine(s) {
    const c = s.pos;
    const lamp = V3(c.x + 2.8, 1.2, c.z + 2.2);
    const mirror = V3(c.x - 0.4, 1.2, c.z + 2.2);
    const inDir = mirror.clone().sub(lamp).setY(0).normalize();
    // The answer: mirror normal pointing so the light leaves toward -z (the goose, then the door).
    const outDir = V3(0, 0, -1);
    const nAns = outDir.clone().sub(inDir).normalize();
    this.eatonAnswer = Math.atan2(nAns.x, nAns.z);
    this.eatonStep = Math.PI / 4;
    // One turn off true: "land the shadow on the door in one move."
    this.mirrorYaw = G.state.flag('agrea_s2') ? this.eatonAnswer : this.eatonAnswer - this.eatonStep;
    const gooseAt = mirror.clone().addScaledVector(outDir, 2.6);
    const doorAt = mirror.clone().addScaledVector(outDir, 5.0);
    this.eaton = { lamp, mirror, inDir, gooseAt, doorAt };
    // Lamp.
    const lp = new THREE.Group();
    const post = P.cyl(0.06, 0.08, 1.2, '#3c4a52'); lp.add(post);
    const shade = P.cone(0.32, 0.4, '#ffcf6a', { emissive: '#ffb020', emissiveIntensity: 0.7 }); shade.rotation.z = Math.PI / 2; shade.position.set(-0.1, 1.2, 0); lp.add(shade);
    lp.position.set(lamp.x, 0.3, lamp.z); lp.rotation.y = Math.atan2(inDir.x, inDir.z) + Math.PI / 2;
    this.add(lp); this.solidCyl(lamp.x, lamp.z, 0.25, -1, 1.4);
    // Mirror on a swivel.
    const mg = new THREE.Group();
    const stand = P.cyl(0.08, 0.1, 0.9, '#8a7458'); mg.add(stand);
    const frame = P.box(1.2, 0.9, 0.08, '#c9a46a', { base: false, round: 0.03 }); frame.position.y = 1.3; mg.add(frame);
    const glass = new THREE.Mesh(new THREE.PlaneGeometry(1.05, 0.75), new THREE.MeshLambertMaterial({ color: '#dff6ff', emissive: '#bfefff', emissiveIntensity: 0.35 }));
    glass.position.set(0, 1.3, 0.045); mg.add(glass);
    mg.position.set(mirror.x, 0.3, mirror.z); mg.rotation.y = this.mirrorYaw;
    this.add(mg); this.solidCyl(mirror.x, mirror.z, 0.35, -1, 1.8);
    this.mirrorObj = mg;
    // Goose on a perch.
    const perch = P.cyl(0.05, 0.05, 1.0, '#6b5a4a'); perch.position.set(gooseAt.x, 0.3, gooseAt.z); this.add(perch);
    const goose = model('goose', { size: 1.3 }); goose.position.set(gooseAt.x, 1.05, gooseAt.z); goose.rotation.y = Math.PI / 2; this.add(goose);
    this.solidCyl(gooseAt.x, gooseAt.z, 0.3, -1, 1.4);
    this.every(() => { goose.position.y = 1.05 + Math.sin(G.time * 1.4) * 0.05; });
    // A little shrine door that waits for a goose shadow.
    const dg = new THREE.Group();
    const dframe = P.box(1.8, 2.4, 0.3, '#d6c9b0', { round: 0.06 }); dg.add(dframe);
    const dpanel = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 1.8), new THREE.MeshLambertMaterial({ color: '#7a5a3a' }));
    dpanel.position.set(0, 1.05, 0.16); dg.add(dpanel);
    const shadowShape = new THREE.Shape();
    shadowShape.moveTo(-0.5, 0); shadowShape.quadraticCurveTo(-0.2, 0.18, 0, 0.05); shadowShape.quadraticCurveTo(0.2, 0.18, 0.5, 0);
    shadowShape.quadraticCurveTo(0.1, -0.05, 0.05, -0.25); shadowShape.lineTo(-0.05, -0.25); shadowShape.quadraticCurveTo(-0.1, -0.05, -0.5, 0);
    const shadow = new THREE.Mesh(new THREE.ShapeGeometry(shadowShape), new THREE.MeshBasicMaterial({ color: '#1d1a24', transparent: true, opacity: 0, depthWrite: false }));
    shadow.position.set(0, 1.15, 0.17); shadow.scale.setScalar(1.1); dg.add(shadow);
    dg.position.set(doorAt.x, 0.3, doorAt.z); dg.rotation.y = 0; // faces +z, toward the goose
    this.add(dg); this.solidBox(doorAt.x, doorAt.z, 1.8, 0.4, -1, 2.7);
    this.eaton.shadow = shadow; this.eaton.panel = dpanel;
    // Light beams (thin glowing sticks).
    const beamMat = new THREE.MeshBasicMaterial({ color: '#fff2b0', transparent: true, opacity: 0.75, depthWrite: false, blending: THREE.AdditiveBlending });
    const mkBeam = () => { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 1, 6), beamMat); m.renderOrder = 3; this.add(m); return m; };
    this.beamIn = mkBeam(); this.beamOut = mkBeam();
    const place = (m, a, b) => { const mid = a.clone().add(b).multiplyScalar(0.5); m.position.copy(mid); const d = b.clone().sub(a); m.scale.set(1, d.length(), 1); m.quaternion.setFromUnitVectors(V3(0, 1, 0), d.normalize()); };
    place(this.beamIn, lamp.clone().add(V3(0, 0.3, 0)), mirror.clone().add(V3(0, 0.3, 0)));
    this.updateEatonBeam = () => {
      const n = V3(Math.sin(this.mirrorYaw), 0, Math.cos(this.mirrorYaw));
      const d = this.eaton.inDir;
      const dot = d.dot(n);
      const r = d.clone().sub(n.clone().multiplyScalar(2 * dot)).setY(0).normalize();
      const from = mirror.clone().add(V3(0, 0.3, 0));
      const hitsGoose = r.dot(outDir) > 0.97;
      const len = hitsGoose ? 2.4 : 6;
      place(this.beamOut, from, from.clone().addScaledVector(r, dot < 0 ? len : 0.01));
      return hitsGoose && dot < 0;
    };
    this.updateEatonBeam();
    if (this.lit(2)) shadow.material.opacity = 0.85;
    this.sense(mg, { warm: () => !this.lit(2), height: 1.3 });
    this.interact({
      obj: mg, radius: 2.0, icon: '\u{1FA9E}',
      enabled: () => !this.lit(2) && !this.eatonBusy,
      label: 'Turn the mirror',
      use: async () => {
        this.eatonBusy = true;
        G.audio.sfx('stone_slide', { vol: 0.4, rate: 1.4 });
        const to = this.mirrorYaw + this.eatonStep;
        await G.animate(0.35, (t) => { mg.rotation.y = this.mirrorYaw + this.eatonStep * t; this.mirrorYaw0 = mg.rotation.y; }, ease.inOut);
        this.mirrorYaw = to; mg.rotation.y = to;
        const ok = this.updateEatonBeam();
        this.eatonBusy = false;
        if (ok) {
          G.audio.sfx('geese', { vol: 0.6 });
          await G.animate(1.0, (t) => { shadow.material.opacity = 0.85 * t; });
          G.ui.say('The goose’s shadow lands on the door, wings wide. One move. That was always all it took.');
          this.solveShrine(2);
        }
      },
    });
  }

  // ── Shrine 3 · Calgary: the knot around the shrine; Oreo unties, she walks it back ──
  buildCalgaryShrine(s) {
    const c = s.pos;
    const post = P.cyl(0.18, 0.22, 1.4, '#8a7458'); post.position.set(c.x, 0.3, c.z); this.add(post);
    const cap = P.sphere(0.24, s.color, { emissive: s.color, emissiveIntensity: 0.2 }); cap.position.set(c.x, 1.8, c.z); this.add(cap);
    this.solidCyl(c.x, c.z, 0.3, -1, 1.7);
    // Wound in this order: tree → bench → stone. Unwind: stone → bench → tree.
    const tree = V3(c.x + 3.6, 0.3, c.z - 2.4), bench = V3(c.x - 3.4, 0.3, c.z - 2.2), stone = V3(c.x + 0.4, 0.3, c.z + 3.8);
    const tr = model('tree_leafy', { height: 4.2 }); tr.position.copy(tree); this.add(tr); this.solidCyl(tree.x, tree.z, 0.45, -1, 3);
    const bg = new THREE.Group();
    const seat = P.box(1.6, 0.1, 0.5, '#a0662e', { round: 0.02 }); seat.position.y = 0.45; bg.add(seat);
    const back = P.box(1.6, 0.4, 0.08, '#a0662e', { round: 0.02 }); back.position.set(0, 0.65, -0.22); bg.add(back);
    for (const x of [-0.7, 0.7]) { const l = P.box(0.08, 0.45, 0.4, '#3c4a52'); l.position.x = x; bg.add(l); }
    bg.position.copy(bench); bg.rotation.y = Math.atan2(c.x - bench.x, c.z - bench.z); this.add(bg);
    this.solidCyl(bench.x, bench.z, 0.7, -1, 0.9);
    const rk = P.rock(0.55, '#a8a094', 333, 1.0); rk.position.set(stone.x, 0.25, stone.z); this.add(rk);
    this.solidCyl(stone.x, stone.z, 0.45, -1, 0.9);
    this.calgary = { posts: [tree, bench, stone], unwind: [2, 1, 0], prog: 0, center: c };
    const lift = (p) => V3(p.x, 0.75, p.z);
    const segPts = [[lift(c), lift(tree)], [lift(tree), lift(bench)], [lift(bench), lift(stone)]];
    this.calgarySegs = segPts.map(([a, b]) => {
      const mid = a.clone().lerp(b, 0.5).add(V3(0, 0.25, 0));
      const m = P.rope([a, mid, b], 0.05, '#2f6fd8');
      m.material = m.material.clone();
      this.add(m);
      return m;
    });
    if (this.lit(3)) for (const sg of this.calgarySegs) sg.visible = false;
    for (const [i, p] of this.calgary.posts.entries()) {
      this.sense(p, { warm: () => !this.lit(3) && this.calgary.unwind[this.calgary.prog] === i, height: 1 });
      this.trigger({
        pos: p, radius: 1.7,
        onEnter: () => this.calgaryVisit(i),
      });
    }
    // Near the shrine, Oreo takes his place at the post: this time, he holds the knot.
    this.trigger({ pos: c, radius: 7.5, onEnter: () => {
      if (this.lit(3) || !G.oreo.active || this.oreoAtPost) return;
      this.oreoAtPost = true;
      G.oreo.goTo(V3(c.x + 0.8, 0, c.z + 0.8), 0.4, 6).then(() => { G.oreo.faceTo(c); G.oreo.bark(); });
      G.ui.say('Oreo trots to the post and takes the knot in his teeth. He remembers this yard.');
    } });
  }
  calgaryVisit(i) {
    if (this.lit(3)) return;
    const k = this.calgary;
    if (!this.oreoAtPost && G.oreo.active) return; // the knot needs its other half first
    if (k.unwind[k.prog] === i) {
      const seg = this.calgarySegs[2 - k.prog];
      G.audio.sfx('wood_creak', { vol: 0.4, rate: 1.4 });
      G.tween(seg.scale, { x: 0.01, y: 0.01, z: 0.01 }, 0.4).then(() => { seg.visible = false; });
      G.fx.sparkle(V3(k.posts[i].x, 1, k.posts[i].z), '#7bd88f', 8);
      k.prog++;
      if (k.prog >= 3) {
        (async () => {
          if (G.oreo.active) { G.oreo.oneShot('pickup', 2.4); await G.wait(1.3); G.oreo.follow(); }
          G.ui.say('One tug from Oreo, and the knot lets go. Roles swapped, same yard.');
          this.solveShrine(3);
        })();
      } else G.ui.toast(['', 'A loop slips free…', 'One more loop…'][k.prog], '\u{1FAA2}');
    } else if (k.prog < 3) {
      // Wrong way round: the line tightens, his ears drop.
      for (const sg of this.calgarySegs) if (sg.visible) { sg.material.color.set('#d8402f'); setTimeout(() => sg.material.color.set('#2f6fd8'), 700); }
      if (G.oreo.active) G.audio.sfx('whimper', { pos: G.oreo.pos, vol: 0.6 });
      G.ui.toast('The line pulls tight. Walk it back the way it was wound…', '\u{1FAA2}');
      // Restore any loosened loops.
      k.prog = 0;
      for (const sg of this.calgarySegs) { sg.visible = true; sg.scale.set(1, 1, 1); }
    }
  }

  // ── Shrine 4 · Winnipeg: one drift that never melts — she marks, he digs ──
  buildWinnipegShrine(s) {
    const c = s.pos;
    const plinth = P.cyl(1.0, 1.2, 0.3, '#e9eef5'); plinth.position.set(c.x, this.height(c.x, c.z) - 0.1, c.z); this.add(plinth);
    const drift = P.sphere(1.0, '#fbfdff', { seg: 16 }); drift.scale.set(1.2, 0.55, 1.1); drift.position.set(c.x, this.height(c.x, c.z) + 0.1, c.z); this.add(drift);
    if (this.lit(4)) { drift.scale.y = 0.1; return; }
    this.every(() => { if (this.lit(4)) return true; if (Math.random() < 0.15) G.fx.spawn(c.x + (Math.random() - 0.5) * 2, c.y + 0.9, c.z + (Math.random() - 0.5) * 2, { vy: 0.2, gravity: -0.1, size: 0.08, life: 1.2, color: '#ffffff' }); });
    this.digSpot({
      pos: c, key: 'agrea_drift', radius: 3.0, mound: false,
      warm: () => !this.lit(4),
      onDug: () => {
        G.tween(drift.scale, { y: 0.1 }, 0.6);
        G.fx.burst(V3(c.x, c.y + 0.4, c.z), { color: '#ffffff', count: 30, speed: 3, up: 4, size: 0.2 });
        G.ui.say('She marks, he digs. The roles they learned together, one last time.');
        this.solveShrine(4);
      },
    });
    this.trigger({ pos: c, radius: 6, once: true, onEnter: () => { if (!this.lit(4)) G.ui.toast('One drift that never melts… (meow at it)', '❄️'); } });
  }

  // ── Shrine 5 · Galleon: a ship in a bottle and one wave lever ──
  buildGalleonShrine(s) {
    const c = s.pos;
    const basin = new THREE.Group();
    const rim = P.box(5.2, 0.45, 1.8, '#cfc3ae', { round: 0.08 }); basin.add(rim);
    const water = new THREE.Mesh(new THREE.PlaneGeometry(4.8, 1.4), new THREE.MeshLambertMaterial({ color: '#2fb5cc', transparent: true, opacity: 0.9 }));
    water.rotation.x = -Math.PI / 2; water.position.y = 0.4; basin.add(water);
    basin.position.set(c.x, 0.3, c.z); this.add(basin);
    this.solidBox(c.x, c.z, 5.2, 1.8, -1, 0.75);
    // Wooden cradle at the +x end, raised.
    const cradle = new THREE.Group();
    for (const dz of [-0.3, 0.3]) { const arm = P.box(0.12, 0.4, 0.12, '#8a5a2b'); arm.position.set(0, 0, dz); cradle.add(arm); }
    const bar = P.box(0.7, 0.08, 0.7, '#a0662e'); bar.position.y = 0.4; cradle.add(bar);
    cradle.position.set(c.x + 3.3, 0.3, c.z); this.add(cradle);
    this.solidBox(c.x + 3.3, c.z, 0.7, 0.7, -1, 0.8);
    // The ship in a bottle.
    const bottle = new THREE.Group();
    const glass = new THREE.Mesh(new THREE.CapsuleGeometry(0.28, 0.9, 6, 14), new THREE.MeshLambertMaterial({ color: '#cff6ff', transparent: true, opacity: 0.35, depthWrite: false }));
    glass.rotation.z = Math.PI / 2; bottle.add(glass);
    const cork = P.cyl(0.11, 0.12, 0.18, '#a07850', { base: false }); cork.rotation.z = Math.PI / 2; cork.position.x = -0.82; bottle.add(cork);
    const ship = model('galleon', { height: 0.42 }); ship.position.y = -0.2; ship.rotation.y = Math.PI / 2; bottle.add(ship);
    this.add(bottle);
    this.shipBottle = bottle;
    this.galleon = { c, water, phase: 0, done: this.lit(5) };
    if (this.lit(5)) bottle.position.set(c.x + 3.3, 1.05, c.z);
    this.every((dt) => {
      if (this.galleon.done || this.galleon.swelling) return;
      this.galleon.phase += dt;
      const x = Math.sin(this.galleon.phase * (Math.PI * 2 / 3.6)) * 1.7;
      bottle.position.set(c.x + x, 0.98 + Math.sin(G.time * 2.4) * 0.03, c.z);
      bottle.rotation.z = Math.sin(G.time * 1.7) * 0.06;
      if (x > 1.15 && Math.random() < 0.05) G.fx.sparkle(V3(c.x + 2.2, 1.0, c.z), '#bff3fb', 2);
    });
    // The wave lever.
    const lv = new THREE.Group();
    const lbase = P.box(0.5, 0.3, 0.5, '#6b5a4a'); lv.add(lbase);
    const arm = P.cyl(0.05, 0.05, 1.0, '#c9a46a'); arm.position.y = 0.25; arm.rotation.z = -0.5; lv.add(arm);
    const knob = P.sphere(0.12, '#ff6b4a'); knob.position.set(0.45, 1.1, 0); lv.add(knob);
    lv.position.set(c.x - 1.0, 0.3, c.z + 1.9); this.add(lv);
    this.solidCyl(c.x - 1.0, c.z + 1.9, 0.3, -1, 0.7);
    this.galleonLever = { arm, knob };
    this.sense(lv, { warm: () => !this.lit(5), height: 0.6 });
    this.interact({
      obj: lv, radius: 2.0, icon: '\u{1F30A}',
      enabled: () => !this.lit(5) && !this.galleon.swelling,
      label: 'Pull the wave lever',
      use: () => this.pullWave(),
    });
  }
  async pullWave() {
    const gl = this.galleon, c = gl.c, b = this.shipBottle;
    gl.swelling = true;
    G.audio.sfx('wood_creak', { vol: 0.5 });
    G.tween(this.galleonLever.arm.rotation, { z: 0.5 }, 0.2).then(() => G.tween(this.galleonLever.arm.rotation, { z: -0.5 }, 0.6));
    G.audio.sfx('big_wave', { vol: 0.6 });
    const x0 = b.position.x - c.x;
    // Generous window: anywhere on the near half of its drift toward the stand.
    const good = x0 > 0.75;
    await G.animate(0.5, (t) => { gl.water.position.y = 0.4 + Math.sin(t * Math.PI) * 0.18; b.position.y = 0.98 + Math.sin(t * Math.PI) * 0.25; });
    if (good) {
      await G.tween(b.position, { x: c.x + 3.3, y: 1.05 }, 0.6, ease.outBack);
      gl.done = true;
      G.audio.sfx('splash', { vol: 0.5 });
      G.ui.say('One swell, perfectly timed. The little Santa Maria settles onto its stand.');
      gl.swelling = false;
      this.solveShrine(5);
    } else {
      G.fx.splash(V3(c.x, 0.7, c.z));
      G.ui.toast('The swell rolls by. Watch the bottle drift toward its stand…', '\u{1F30A}');
      await G.wait(0.4);
      gl.swelling = false;
    }
  }

  // ── Shrine 6 · Totems: four animals, the fourth a cat. It faces the house. ──
  buildTotemShrine(s) {
    const c = s.pos;
    const R = 2.6;
    const defs = [
      { m: 'pole_raven', ang: 0.4, h: 3.4 },
      { m: 'pole_bear', ang: 2.0, h: 3.0 },
      { m: 'pole_orca', ang: 3.6, h: 3.2 },
    ];
    for (const d of defs) {
      const x = c.x + Math.cos(d.ang) * R, z = c.z + Math.sin(d.ang) * R;
      const pole = model(d.m, { height: d.h }); pole.position.set(x, 0.3, z);
      pole.rotation.y = d.ang + Math.PI; // they already face their homes
      this.add(pole); this.solidCyl(x, z, 0.4, -1, d.h);
    }
    // The cat pole: a carved post crowned with a cat's head (procedural face so
    // "where it looks" is unmistakable).
    const ang = 5.2;
    const cp = V3(c.x + Math.cos(ang) * R, 0.3, c.z + Math.sin(ang) * R);
    const cat = new THREE.Group();
    const trunk = model('tiki', { height: 2.4 }); cat.add(trunk);
    const head = P.sphere(0.42, '#f4efe4', { seg: 16 }); head.position.y = 2.75; head.scale.set(1.1, 0.95, 1); cat.add(head);
    for (const sx of [-1, 1]) {
      const ear = P.cone(0.15, 0.32, '#f4efe4', { seg: 4 }); ear.position.set(sx * 0.26, 3.05, 0); ear.rotation.z = -sx * 0.25; cat.add(ear);
      const eye = P.sphere(0.07, '#1fb5c9'); eye.position.set(sx * 0.15, 2.82, 0.36); cat.add(eye);
    }
    const nose = P.sphere(0.05, '#ff9ad5'); nose.position.set(0, 2.72, 0.42); cat.add(nose);
    cat.position.copy(cp);
    this.add(cat);
    this.solidCyl(cp.x, cp.z, 0.4, -1, 3);
    this.catPole = cat;
    const toHouse = Math.atan2(HOUSE.x - cp.x, HOUSE.z - cp.z);
    this.catAnswer = toHouse;
    this.catStep = Math.PI / 4;
    this.catYaw = this.lit(6) ? toHouse : toHouse - this.catStep * 3;
    cat.rotation.y = this.catYaw;
    // Weathered plaque: three animals facing their homes, and a fourth.
    const plaque = P.sign(['Raven: sky · Bear: forest', 'Orca: sea · Cat: ?'], { w: 1.6, h: 0.7, post: 0.6, font: 'bold 44px "Baloo 2", sans-serif' });
    plaque.position.set(c.x, 0.3, c.z + 0.2); plaque.rotation.y = Math.atan2(-c.x, 20 - c.z) * 0.3;
    this.add(plaque);
    this.interact({ obj: plaque, radius: 1.8, icon: '\u{1F440}', label: 'Read the plaque', use: () => G.ui.say('Raven faces the sky-tree. Bear, the forest. Orca, open water. The fourth carving is a cat, and the plaque has no word for where it looks.') });
    this.sense(cat, { warm: () => !this.lit(6), height: 2.6 });
    this.interact({
      obj: cat, radius: 2.0, icon: '\u{1F431}',
      enabled: () => !this.lit(6) && !this.catBusy && !this.catSolving,
      label: 'Shove the cat pole',
      use: async () => {
        this.catBusy = true;
        G.audio.sfx('stone_slide', { vol: 0.5, rate: 0.9 });
        G.player.emote('attack', 1.4);
        const from = this.catYaw, to = from + this.catStep;
        await G.animate(0.45, (t) => { cat.rotation.y = from + this.catStep * t; }, ease.inOut);
        this.catYaw = to; cat.rotation.y = to;
        this.catBusy = false;
        if (Math.abs(wrapA(this.catYaw - this.catAnswer)) < 0.05) {
          // The wind passes through all four carvings and they sing.
          this.catSolving = true;
          [NOTES[0], NOTES[1], NOTES[2], NOTES[3]].forEach((n, i) => setTimeout(() => G.audio.tone(n.f, { dur: 1.0, vol: 0.32 }), 300 + i * 420));
          G.fx.setWeather('petals', { rate: 30, wind: [1.2, 0.4] });
          setTimeout(() => G.fx.setWeather('petals', { rate: 6, wind: [0.5, 0.15] }), 3500);
          await G.wait(2.0);
          G.ui.say('It faces the house. It always faced the house.');
          this.solveShrine(6);
        }
      },
    });
  }

  // ── The five-bell stand ────────────────────────────────
  buildBells() {
    const g = new THREE.Group();
    for (const x of [-1.5, 1.5]) { const p = P.cyl(0.07, 0.08, 2.2, '#6b4a2a'); p.position.x = x; g.add(p); }
    const beam = P.box(3.3, 0.14, 0.14, '#6b4a2a', { base: false }); beam.position.y = 2.15; g.add(beam);
    // Bells low → high, left to right (bigger bells sing lower).
    const order = [4, 2, 3, 1, 0];
    this.bellMeshes = order.map((ni, i) => {
      const note = NOTES[ni];
      const size = 0.34 - i * 0.035;
      const bell = P.cone(size, size * 1.3, note.color, { emissive: note.color, emissiveIntensity: 0.15 });
      bell.material = bell.material.clone();
      bell.position.set(-1.2 + i * 0.6, 2.05 - size * 1.3, 0);
      g.add(bell);
      return { bell, ni };
    });
    g.position.copy(BELLS); g.rotation.y = 0.35;
    this.add(g);
    this.solidBox(BELLS.x, BELLS.z, 3.4, 0.4, -1, 2.3, -0.35); // collider rot = -mesh rotation.y
    this.sense(g, { warm: () => this.litCount() === 6 && !G.state.flag('agrea_bells'), height: 1.8 });
    this.interact({
      obj: g, radius: 2.4, icon: '\u{1F514}',
      label: () => (G.state.flag('agrea_bells') ? 'The five bells' : 'Ring the five bells'),
      use: () => this.openBells(),
    });
  }
  ringBell(ni) {
    G.audio.tone(NOTES[ni].f, { dur: 1.2, vol: 0.42, type: 'triangle' });
    const b = this.bellMeshes.find((x) => x.ni === ni);
    if (b) { G.animate(0.6, (t) => { b.bell.rotation.z = Math.sin(t * Math.PI * 3) * 0.3 * (1 - t); b.bell.material.emissiveIntensity = 0.15 + (1 - t) * 0.9; }); }
  }
  openBells() {
    const done = G.state.flag('agrea_bells');
    const wrap = document.createElement('div');
    wrap.innerHTML = `<p style="text-align:center">${done ? 'The bells remember the phrase. So does she.' : 'Five bells, low to high. You know the phrase. You have always known the phrase.'}</p>`;
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px;justify-content:center;flex-wrap:nowrap;margin:8px 0';
    const status = document.createElement('div');
    status.style.cssText = 'text-align:center;min-height:30px;font-size:22px;letter-spacing:4px';
    let seq = [], misses = 0;
    const hum = document.createElement('button');
    hum.className = 'btn small secondary'; hum.textContent = 'Hum it for me \u{1F3B5}'; hum.style.display = done ? 'inline-block' : 'none';
    hum.addEventListener('click', () => this.playPhrase());
    const finish = async () => {
      G.state.set('agrea_bells');
      status.textContent = '✨ ✨ ✨';
      await new Promise((r) => setTimeout(r, 900));
      G.ui.closeSheet();
      G.ui.celebrate('The bells ring true', 'The five-bell stand');
      G.fx.sparkle(BELLS.clone().setY(2.2), NOTES.map((n) => n.color), 20);
      this.doorGlow();
    };
    [4, 2, 3, 1, 0].forEach((ni, i) => {
      const n = NOTES[ni];
      const b = document.createElement('button');
      b.className = 'cell';
      const sz = 72 - i * 6;
      b.style.cssText = `width:${sz}px;height:${sz + 8}px;border-radius:50% 50% 18px 18px;background:${n.color};font-size:24px;align-self:flex-end`;
      b.textContent = '\u{1F514}';
      b.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        this.ringBell(ni);
        if (G.state.flag('agrea_bells')) return;
        seq.push(ni);
        const k = seq.length - 1;
        if (seq[k] !== PHRASE[k]) {
          misses++;
          seq = [];
          status.textContent = '';
          G.ui.toast('The bells hum, patient. Begin again.', '\u{1F514}');
          if (misses >= 2) hum.style.display = 'inline-block';
          return;
        }
        status.textContent = '\u{1F3B5}'.repeat(seq.length);
        if (seq.length === PHRASE.length) finish();
      });
      row.append(b);
    });
    wrap.append(row, status);
    const hr = document.createElement('div'); hr.style.textAlign = 'center'; hr.append(hum); wrap.append(hr);
    G.ui.panel('The five-bell stand', wrap, { buttons: [{ label: 'Close', onClick: (close) => close() }] });
  }

  // ── The Letter Table ──────────────────────────────────
  buildTable() {
    const g = new THREE.Group();
    const leg = P.cyl(0.5, 0.7, 0.9, '#bdb2a0'); g.add(leg);
    const top = P.box(2.6, 0.18, 1.5, '#d6ccb8', { round: 0.06 }); top.position.y = 0.9; g.add(top);
    const inlays = new THREE.Group();
    for (let i = 0; i < TABLE_PIECES.length; i++) {
      const inlay = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 0.26), new THREE.MeshLambertMaterial({ color: '#8f8270' }));
      inlay.rotation.x = -Math.PI / 2;
      inlay.position.set(-1.0 + (i % 5) * 0.5, 1.085, -0.3 + Math.floor(i / 5) * 0.55);
      inlays.add(inlay);
    }
    g.add(inlays);
    this.tableInlays = inlays;
    const risen = this.litCount() === 6;
    g.position.set(TABLE.x, risen ? TABLE.y - 0.2 : TABLE.y - 1.4, TABLE.z);
    this.add(g);
    this.table = g;
    this.tableSolid = this.solidBox(TABLE.x, TABLE.z, 2.6, 1.5, -1, TABLE.y + 0.9, 0, { enabled: risen });
    if (G.state.flag('agrea_table')) this.paintInlays();
    this.sense(g, { warm: () => this.litCount() === 6 && !G.state.flag('agrea_table'), height: 1 });
    this.interact({
      obj: g, radius: 2.4, icon: '\u{1F4DC}',
      enabled: () => this.litCount() === 6,
      label: () => (G.state.flag('agrea_table') ? 'Read the letter' : 'The Letter Table'),
      use: () => (G.state.flag('agrea_table') ? this.readWhole() : this.openTable()),
    });
  }
  paintInlays() {
    this.tableInlays.children.forEach((m) => { m.material = new THREE.MeshLambertMaterial({ color: '#f4e7c6', emissive: '#ffd27a', emissiveIntensity: 0.25 }); });
  }
  async raiseTable() {
    G.audio.sfx('gate_open', { vol: 0.8 });
    await G.cine.run(async (c) => {
      c.look(TABLE.clone().setY(1), { dist: 9, pitch: 38, speed: 2 });
      await c.wait(0.6);
      G.rig.shake = 0.6;
      await G.tween(this.table.position, { y: TABLE.y - 0.2 }, 2.2, ease.out);
      this.tableSolid.enabled = true;
      G.fx.burst(TABLE.clone().setY(0.4), { color: '#e8dcc0', count: 24, speed: 2.5, up: 2.5, size: 0.25 });
      await this.say2('Six beacons burn. In front of the house, a stone table rises, with torn-paper inlays waiting.', { dur: 4 });
    });
  }
  openTable() {
    const wrap = document.createElement('div');
    const pieces = TABLE_PIECES;
    const order = [...pieces];
    // Deterministic shuffle so it never comes out pre-solved.
    const R = rng(2026);
    for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(R() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
    let placed = 0;
    wrap.innerHTML = '<p style="text-align:center"><small>The pieces she carried across seven islands, and three new ones the shrines returned. Set them in the order a stranger wrote them.</small></p>';
    const letter = document.createElement('div');
    letter.className = 'letter';
    letter.style.minHeight = '150px';
    const head = document.createElement('div'); head.textContent = 'Khione,'; letter.append(head);
    const body = document.createElement('div'); letter.append(body);
    const sig = document.createElement('div'); sig.innerHTML = '<span class="sig smudge">Oreo.</span>'; sig.style.marginTop = '4px';
    letter.append(sig);
    const pool = document.createElement('div');
    pool.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin-top:12px';
    const renderBody = () => {
      body.innerHTML = '';
      pieces.forEach((p, i) => {
        const s = document.createElement('span');
        if (i < placed) { s.className = 'frag'; s.textContent = p.t; }
        else { s.className = 'gap'; s.textContent = '· · ·'; }
        body.append(s);
        body.append(p.br ? document.createElement('br') : document.createTextNode(' '));
      });
    };
    for (const p of order) {
      const b = document.createElement('button');
      b.className = 'btn small secondary';
      b.style.cssText = 'font-family:"Bradley Hand","Segoe Print","Comic Sans MS",var(--font);font-size:17px;min-height:44px';
      b.textContent = p.t;
      b.addEventListener('click', () => {
        if (p.i === placed) {
          placed++;
          b.remove();
          G.audio.tone(392 + placed * 45, { dur: 0.35, vol: 0.25 });
          renderBody();
          if (placed === pieces.length) this.tableSolved();
        } else {
          G.audio.tone(220, { dur: 0.25, vol: 0.18 });
          b.animate?.([{ transform: 'translateX(0)' }, { transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'translateX(0)' }], { duration: 260 });
        }
      });
      pool.append(b);
    }
    renderBody();
    wrap.append(letter, pool);
    G.ui.panel('The Letter Table', wrap, { buttons: [{ label: 'Step back', onClick: (close) => close() }] });
  }
  async tableSolved() {
    G.state.set('agrea_table');
    await new Promise((r) => setTimeout(r, 900));
    G.ui.closeSheet(true);
    this.paintInlays();
    G.ui.celebrate('The letter, whole', 'The Letter Table');
    G.fx.sparkle(TABLE.clone().setY(1.3), ['#ffe48a', '#ffffff'], 24);
    G.audio.duck(0.3, 4);
    await G.cine.run(async (c) => {
      c.look(TABLE.clone().setY(1), { dist: 7, pitch: 50 });
      await this.say2('Khione, if you found this, know that you’re not supposed to be here.', { dur: 4 });
      await this.say2('Could I meet you? I wish for just one final adventure.', { dur: 4 });
      await this.say2('The letter, whole, wants an answer.', { dur: 3 });
    });
    if (G.state.flag('agrea_bells')) this.doorGlow();
  }
  readWhole() {
    G.ui.panel('The Letter Table', `${G.ui.letterHTML(false)}`, { buttons: [{ label: 'Close', primary: true, onClick: (close) => close() }] });
  }

  // ── The door ──────────────────────────────────────────
  buildDoor() {
    this.doorPos = V3(HOUSE.x + 1.2, 0.3, HOUSE.z + 6.0);
    const glowMesh = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 2.3), new THREE.MeshBasicMaterial({ color: '#fff2b0', transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending }));
    glowMesh.position.set(HOUSE.x + 1.2, 2.55, HOUSE.z + 4.05);
    this.add(glowMesh);
    this.doorGlowMesh = glowMesh;
    if (G.state.flag('agrea_table') && G.state.flag('agrea_bells')) glowMesh.material.opacity = 0.35;
    this.sense(this.doorPos, { warm: () => G.state.flag('agrea_table') && G.state.flag('agrea_bells') && !G.state.flag('agrea_finale_done'), height: 1.4 });
    this.interact({
      pos: this.doorPos, radius: 2.4, icon: '\u{1F6AA}',
      enabled: () => !this.finaleRunning,
      label: () => (G.state.flag('agrea_finale_done') ? 'The red door' : 'The door'),
      use: () => {
        if (G.state.flag('agrea_finale_done')) { G.ui.say('Warm light spills from under the door. Home, finally, on the right side of it.'); return; }
        if (this.litCount() < 6) G.ui.say('A red door. Behind it, quiet. Six beacons around the island are still dark.');
        else if (!G.state.flag('agrea_table')) G.ui.say('The door waits. First, the letter on the stone table must be whole.');
        else if (!G.state.flag('agrea_bells')) G.ui.say('The letter wants an answer, and the answer is a song. The five bells by the gate know it.');
        else G.ui.say('Sing it. Meow the melody at the door.');
      },
    });
    this.onVocal((e) => {
      if (e.kind !== 'meow' || this.finaleRunning || G.state.flag('agrea_finale_done')) return;
      if (Math.hypot(e.pos.x - this.doorPos.x, e.pos.z - this.doorPos.z) > 3.6) return;
      if (G.state.flag('agrea_table') && G.state.flag('agrea_bells')) this.finale();
      else if (this.litCount() === 6 && G.state.flag('agrea_table')) G.ui.toast('The door listens… but the phrase must ring on the bells first.', '\u{1F514}');
    });
  }
  doorGlow() {
    if (!(G.state.flag('agrea_table') && G.state.flag('agrea_bells'))) return;
    G.animate(1.5, (t) => { this.doorGlowMesh.material.opacity = 0.35 * t; });
    G.ui.toast('The red door glows. Meow the melody there.', '\u{1F6AA}');
  }

  async finale() {
    this.finaleRunning = true;
    G.state.set('agrea_finale_started');
    await G.cine.run(async (c) => {
      c.look(this.doorPos.clone().setY(1.6), { dist: 7.5, pitch: 22, speed: 1.6 });
      // She sings the phrase.
      this.playPhrase(600);
      for (let i = 0; i < 5; i++) setTimeout(() => G.fx.ring(G.player.pos.clone().setY(G.player.pos.y + 0.1), NOTES[PHRASE[i]].color, 3 + i, 0.9), i * 600);
      await c.wait(3.4);
      // And for the first time, something answers first: one bark, from everywhere at once.
      G.audio.music(null, { fade: 1.2 });
      await c.wait(1.0);
      const pts = [V3(-30, 0, 0), V3(30, 0, 0), V3(0, 0, -30), V3(0, 0, 30), V3(0, 0, 0)];
      pts.forEach((p, i) => setTimeout(() => G.audio.sfx('bark', { vol: 1, rate: 1, minGap: 0 }), i * 18));
      G.rig.shake = 0.5;
      for (const s of SHRINES) G.fx.sparkle(this.beacons[s.n].pos.clone().setY(2.4), [s.color, '#ffffff'], 16);
      G.fx.ring(G.player.pos.clone(), '#ffffff', 30, 2.2);
      await this.say2('Woof!', { who: 'From everywhere at once', dur: 2.2 });
      G.oreo?.bark();
      await this.say2('One bark, joyful, instant. Oreo’s tail goes like a metronome in a hurricane.', { dur: 3.2 });
      await G.animate(1.4, (t) => { this.doorGlowMesh.material.opacity = 0.35 + t * 0.65; });
    }, { skippable: true });
    // White light, and the memory.
    await this.memoryBeats();
    G.state.set('agrea_finale_done');
    this.finaleRunning = false;
    await G.game.finishIsland();
    G.audio.music('agrea', { fade: 3 });
    G.game.ending();
  }

  memoryBeats() {
    return new Promise((resolve) => {
      const root = document.getElementById('ui');
      const el = document.createElement('div');
      el.style.cssText = 'position:absolute;inset:0;z-index:11;background:#fffaf0;opacity:0;transition:opacity 1.2s;display:flex;align-items:center;justify-content:center;padding:28px;box-sizing:border-box;text-align:center;pointer-events:auto';
      const line = document.createElement('div');
      line.style.cssText = 'font-weight:800;font-size:22px;line-height:1.35;color:#173b44;max-width:420px;opacity:0;transition:opacity .8s';
      el.append(line);
      const skip = document.createElement('button');
      skip.className = 'btn small secondary'; skip.textContent = 'Skip ⏩';
      skip.style.cssText += ';position:absolute;right:16px;bottom:calc(env(safe-area-inset-bottom,0px) + 16px)';
      el.append(skip);
      root.append(el);
      G.audio.sfx('chime', { vol: 0.7 });
      const beats = [
        'White light.',
        'A park, a long time ago. A girl, and a black-and-white dog with one blue eye.',
        'A storm. Wind like nothing before it.',
        'A vortex, and a girl swept away, and set down on a small lonely island, small and white and four-pawed.',
        'He looked for her everywhere. One island ahead, always. Leaving letters.',
        'Now the walk back to Ahalo begins. On two feet, this time, with a friend at her side.',
      ];
      let i = 0, stopped = false;
      const end = () => {
        if (stopped) return; stopped = true;
        el.style.opacity = '0';
        setTimeout(() => { el.remove(); resolve(); }, 1200);
      };
      skip.addEventListener('click', end);
      const next = () => {
        if (stopped) return;
        if (i >= beats.length) { end(); return; }
        line.style.opacity = '0';
        setTimeout(() => {
          if (stopped) return;
          line.textContent = beats[i++];
          line.style.opacity = '1';
          setTimeout(next, 1600 + line.textContent.length * 45);
        }, 700);
      };
      requestAnimationFrame(() => { el.style.opacity = '1'; });
      setTimeout(next, 1000);
    });
  }

  // ── Arrival, goals ────────────────────────────────────
  async onEnter(first) {
    if (G.state.flag('agrea_arrived')) return;
    G.state.set('agrea_arrived');
    await G.cine.run(async (c) => {
      c.cut(V3(0, 1, -2), { dist: 44, pitch: 42, yaw: 20 });
      await c.wait(0.3);
      c.look(V3(0, 1, -2), { dist: 36, pitch: 40, yaw: 50, speed: 0.4 });
      await this.say2('Agrea. Geese, a doghouse, totems, a galleon, a red bridge, all ringed around one quiet street.', { dur: 4.5 });
      await this.say2('The whole journey, small enough to hold. Because that is exactly what it is.', { dur: 4 });
      c.look(HOUSE.clone().setY(2), { dist: 16, pitch: 30, speed: 0.8 });
      await this.say2('And in the middle, one particular house with a red door.', { dur: 3.4 });
      for (const s of SHRINES) G.fx.sparkle(this.beacons[s.n].pos.clone().setY(2.2), s.color, 6);
      await this.say2('Six dark beacons. Six shrines, each one an island she already knows by heart.', { dur: 4 });
    });
    G.ui.toast('Light the six shrines.', '✨');
  }

  objective() {
    const s = G.state;
    if (s.flag('agrea_finale_done')) return null;
    const n = this.litCount();
    if (n < 6) return `Light the six shrines (${n}/6)`;
    if (!s.flag('agrea_table')) return 'Set the letter in order at the stone table';
    if (!s.flag('agrea_bells')) return 'Ring the phrase on the five bells';
    return 'Meow the melody at the red door';
  }
  hint() {
    const s = G.state;
    const n = this.litCount();
    if (n < 6) {
      const left = SHRINES.filter((x) => !this.lit(x.n));
      const tips = {
        1: 'Ahalo Shrine: five water-worn stones. The carving remembers a melody, not sizes. Meow at each stone to hear it.',
        2: 'Eaton Shrine: one goose, one lamp, one mirror. Turn the mirror until the goose’s shadow lands on the little door.',
        3: 'Calgary Shrine: the line was wound tree, bench, stone. Oreo holds the knot; walk it back the other way.',
        4: 'Winnipeg Shrine: one drift that never melts. She marks, he digs.',
        5: 'Galleon Shrine: pull the wave lever just as the bottle drifts toward its stand.',
        6: 'Totem Shrine: three animals face their homes. Where does the cat face?',
      };
      return tips[left[0].n];
    }
    if (!s.flag('agrea_table')) return 'The stone table rose in front of the house. Set the torn pieces in the order the letter was written.';
    if (!s.flag('agrea_bells')) return 'The five bells by the gate. Ring the phrase you have heard since Ahalo: the hollow stones’ song, finished with its fifth note.';
    return 'Stand at the red door and meow. Sing the letter’s melody.';
  }
  objectiveTarget() {
    const s = G.state;
    if (this.litCount() < 6) {
      const p = G.player.pos;
      let best = null, bd = Infinity;
      for (const x of SHRINES) { if (this.lit(x.n)) continue; const d = Math.hypot(p.x - x.pos.x, p.z - x.pos.z); if (d < bd) { bd = d; best = x.pos; } }
      return best;
    }
    if (!s.flag('agrea_table')) return TABLE;
    if (!s.flag('agrea_bells')) return BELLS;
    if (!s.flag('agrea_finale_done')) return this.doorPos ?? HOUSE;
    return null;
  }
  riddles() {
    const s = G.state;
    const lit = (n) => s.flag(`agrea_s${n}`);
    return [
      { id: 's1', name: 'Ahalo Shrine', done: lit(1), hint: 'Five stones, water-worn. The melody is the order.' },
      { id: 's2', name: 'Eaton Shrine', done: lit(2), hint: 'One goose, one lamp, one mirror.' },
      { id: 's3', name: 'Calgary Shrine', done: lit(3), hint: 'A knot around the shrine. Roles swapped.' },
      { id: 's4', name: 'Winnipeg Shrine', done: lit(4), hint: 'One drift that never melts.' },
      { id: 's5', name: 'Galleon Shrine', done: lit(5), hint: 'A ship in a bottle, and one wave lever.' },
      { id: 's6', name: 'Totem Shrine', done: lit(6), hint: 'Four animals. The fourth is a cat.' },
      { id: 'bells', name: 'The Five Bells', done: s.flag('agrea_bells'), hint: 'You have always known the phrase.' },
      { id: 'table', name: 'The Letter Table', done: s.flag('agrea_table'), hint: 'Seven islands of torn paper, in reading order.' },
      { id: 'door', name: 'The Red Door', done: s.flag('island7_complete'), hint: 'The letter, whole, wants an answer.' },
    ];
  }
}
