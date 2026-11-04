// Island 5 — Montréal. Mont Royal in autumn over a downtown of glass and grey
// stone: the Old Port on the river, the Bell Centre and its four bronze
// legends, Place Ville Marie's sweeping beacon, a bagel oven still warm, the
// museum at the mountain's east foot, a calèche horse asleep across the only
// road up, and the mountain climbing in terraces to a dark cross.
// Teaches: growl, and vertical patience. Ported from the Godot island
// (scripts/islands/montreal.gd and its six puzzles).
import * as THREE from 'three';
import { G, rng, clamp, lerp, fbm, ease, V3 } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';
import { registerItems } from '../engine/state.js';

registerItems({
  bagel: { name: 'Sesame Bagel', icon: '\u{1F96F}', desc: 'Wood-fired, sesame, still warm. Squirrels accept these as legal tender, strictly by the count.' },
  arena_pane: { name: 'Arena Glass Pane', icon: '\u{1FA9F}', desc: 'A spare pane of arena glass from the penalty box. Clear as a held breath, and exactly lantern-sized.' },
  lafleur_portrait: { name: 'Portrait of the Démon Blond', icon: '\u{1F5BC}️', desc: 'Number 10 in a gilded frame, shaken loose by the winning horn. The plaque says it belongs to the museum at the mountain’s east foot.' },
  lever_handle: { name: 'Brass Lever Handle', icon: '\u{1F579}️', desc: 'The brass handle a squirrel stole off a staircase lever, returned on the museum steps with full ceremony.' },
});

// ── Layout ───────────────────────────────────────────────
// Terraces: [riser foot z (south), riser head z (north), terrace height].
// plain 0.35 · T1 4 · T2 (chalet) 8 · T3 12 · summit 15, |x| < 12.5.
const WATER = -0.4, COAST = 46, PLAIN = 0.35, QUAY = 31.5;
const TERRACES = [[-4, -7, 4], [-11.5, -14.5, 8], [-23, -26, 12], [-31, -34, 15]];
// Flight k climbs terrace k-1 → k, pivoting on its foot landing. Aligned = pointing north.
const FLIGHTS = [
  { x: 3, z: -3.6, run: 3.8, y0: PLAIN, y1: 4 },
  { x: -2, z: -10.9, run: 4.2, y0: 4, y1: 8 },
  { x: 3, z: -22.6, run: 3.8, y0: 8, y1: 12 },
  { x: -2, z: -30.6, run: 3.8, y0: 12, y1: 15 },
];
const START_TURNS = [0, 1, 0, 1];   // flights 2 and 4 start wrong
const FLIGHT_W = 1.6;
const WALL_Z = -1.6, ROAD = 2.4;    // the stone wall along the mountain's foot; the road is the one gap
const HORSE = V3(0, PLAIN, -0.4);
const OVEN = V3(-14, PLAIN, 4.5);
const ARENA = V3(16, PLAIN, 19);
const MUSEUM = V3(28, PLAIN, 3);
const CHALET = V3(-6, 8, -20.5);
const CROSS = V3(0, 15, -39);
const DRUM = V3(3.5, 15, -36);
const FUNI = [
  V3(-9, 15, -37.5), V3(-13.6, 15, -34), V3(-19, 11.5, -27), V3(-23, 7.5, -19),
  V3(-25.5, 4.2, -9), V3(-26, 3.1, 0), V3(-22, 1.2, 15), V3(-16, 0.6, 27.6),
];
const SPAWN = V3(0, 0.42, 39);
// The west-flank boulder scramble: the long way to the chalet terrace, one hop at a time.
const SCRAMBLE = [[-14.5, 0.35, -5], [-15.5, 1.5, -7.5], [-16.5, 2.7, -10], [-16, 3.9, -12.5], [-15, 5.1, -15], [-15.5, 6.3, -17.5], [-14.5, 7.4, -19.5]];
const STARS = [9, 4, 10];           // Richard, Béliveau, Lafleur
const BANNERS = [9, 4, 33, 10, 16];
const LANTERNS = (() => {
  const out = [];
  for (let k = 0; k < 6; k++) out.push(V3(0, 0.9 + k * 1.5, 0.45));
  for (let k = 0; k < 3; k++) { out.push(V3(-2.7 + k * 0.9, 7.5, 0.45)); out.push(V3(0.9 + k * 0.9, 7.5, 0.45)); }
  return out;
})();
const BROKEN = [2, 7, 10];
const LIGHT_ORDER = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 5];
const PATTERN = ['low', 'high', 'low', 'mid'];
const DRUM_SFX = { low: 'drum_low', mid: 'drum_mid', high: 'drum_high' };
const CYCLE = 2.6, GOLD_A = 1.15, GOLD_B = 1.85;

const STONE = '#827f79', GRANITE = '#73737a', GREYSTONE = '#a29d93', WOOD = '#80614a', WOOD_PALE = '#a8906c', IRON = '#38383d';
const MAPLES = ['#d9472a', '#eb8024', '#e6b333', '#b8331f'];
const DAY = { sky: '#f2c49a', fog: '#efc6a2', fogNear: 52, fogFar: 150, sun: '#ffd2a2', sunIntensity: 2.25, hemi: 1.15, skyLight: '#ffe7c8', groundLight: '#6a5a4a', sunDir: [16, 11, 14], exposure: 1.06 };
const DUSK = { sky: '#76639a', fog: '#836c99', fogNear: 46, fogFar: 140, sun: '#e0aed2', sunIntensity: 1.45, hemi: 1.1, skyLight: '#cdbde6', groundLight: '#4a3e58', sunDir: [-16, 8, 12], exposure: 1.08 };

const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const _v = new THREE.Vector3(), _t = new THREE.Vector3(), _hit = new THREE.Vector3(), _ray = new THREE.Ray(), _c = new THREE.Color();

/** The mountain: stepped terraces along -z, steep flanks in x, a steep back. */
function mountain(x, z) {
  if (z > TERRACES[0][0]) return PLAIN;
  let h = PLAIN, prev = PLAIN;
  for (const [z0, z1, top] of TERRACES) {
    if (z <= z1) h = top;
    else if (z <= z0) h = lerp(prev, top, ss(0, 1, (z0 - z) / (z0 - z1)));
    prev = top;
  }
  const lateral = 1 - ss(12.5, 15.5, Math.abs(x));
  const back = 1 - ss(-42, -44.5, z);
  return Math.max(PLAIN, lerp(PLAIN, h, lateral * back));
}

/** A triangular prism (roofs, pediments): ridge along x, base on y = 0. */
function prism(len, width, height, color) {
  const g = new THREE.CylinderGeometry(1, 1, len, 3, 1, false, Math.PI * 1.5);
  g.rotateZ(-Math.PI / 2);
  g.scale(1, height / 1.5, width / Math.sqrt(3));
  g.translate(0, height / 3, 0);
  const m = new THREE.Mesh(g, P.mat(color, { flat: true }));
  m.castShadow = true; m.receiveShadow = true;
  return m;
}

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  return t;
}
const textTex = (lines, o = {}) => P.textCanvas(lines, { bg: null, ...o });

export default class Montreal extends Island {
  static id = 'montreal';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 0, r: 47 };
    this.occluders = [];
    this.windowMats = [];
    this.glows = [];          // {mat, day, dusk} emissive intensities
    this.turns = [...START_TURNS];
    this.tries = 0;
    this.hoisted = [];
    this.callRound = 0;
    this.progress = 0;
    this.lastHit = -10;
    this.bellT = 90; this.chitterT = 30;
  }

  models() { return ['horse']; }
  sounds() {
    return ['horse_snort', 'growl', 'bark', 'oven_pop', 'fail', 'goal_horn', 'crowd_cheer', 'crowd_groan', 'bell_ding', 'robot_flee',
      'wood_creak', 'coconut_thunk', 'squirrel_chitter', 'lever_clunk', 'stone_slide', 'gate_open', 'firefly_hum', 'drum_low',
      'drum_mid', 'drum_high', 'funicular_bell', 'chime', 'fanfare'];
  }
  atmosphere() { return G.state.flag('bagels_placed') ? DUSK : DAY; }
  music() { return 'montreal'; }
  terrainTextures() { return ['grass.jpg', 'greystone.jpg', 'sand.jpg']; }

  // ── Ground ────────────────────────────────────────────
  coastR(th) {
    const wob = 2.6 * Math.sin(3 * th + 1.7) + 1.7 * Math.sin(5 * th + 4.2) + 1.1 * Math.sin(8 * th + 0.9);
    let d = th - Math.PI / 2;
    while (d > Math.PI) d -= Math.PI * 2;
    while (d < -Math.PI) d += Math.PI * 2;
    return COAST + wob * ss(0.55, 1.1, Math.abs(d));
  }
  slot(x, z) {
    for (let k = 0; k < FLIGHTS.length; k++) {
      const f = FLIGHTS[k];
      if (Math.abs(x - f.x) < 0.95 && z < f.z + 0.2 && z > f.z - f.run - 0.05) return f;
    }
    return null;
  }
  height(x, z) {
    const d = Math.hypot(x, z), coast = this.coastR(Math.atan2(z, x));
    let h;
    if (d >= coast) h = -6 * clamp((d - coast) / 12, 0, 1);
    else {
      const m = mountain(x, z);
      h = m > PLAIN + 0.01 ? m : PLAIN * (1 - ss(coast - 4, coast - 1.5, d));
      // Each staircase lands in a slot cut into its riser.
      const f = this.slot(x, z);
      if (f) h = Math.min(h, f.y0);
    }
    // The Old Port: a stone quay drops straight into the St. Lawrence.
    if (z > QUAY) h = Math.min(h, lerp(PLAIN, -3.2, ss(QUAY, QUAY + 1, z)));
    return h;
  }
  paved(x, z) {
    if (z > WALL_Z + 0.3 && z < QUAY + 0.6 && x > -31 && x < 36) return true;            // downtown
    if (Math.abs(x) < ROAD && z <= WALL_Z && z > -4.2) return true;                      // the calèche road
    if (this.slot(x, z)) return true;
    if (Math.hypot(x - CROSS.x, z - CROSS.z) < 5.5) return true;
    return Math.abs(x - CHALET.x) < 7 && z > -19 && z < -14.6;   // the belvedere forecourt
  }
  splat(x, z) {
    const h = this.height(x, z);
    if (h < 0.3 && h > -1.2 && z < QUAY) return [0, 0, 1];
    if (this.paved(x, z)) return [0, 1, 0];
    return [1, 0, 0];
  }
  tint(x, z) {
    const h = this.height(x, z);
    const c = new THREE.Color();
    const n = fbm(x * 0.13, z * 0.13);
    const w = this.splat(x, z);
    if (w[1] > 0.5) c.set('#f4f0e8').multiplyScalar(0.94 + n * 0.08);
    else if (w[2] > 0.5) c.set('#f1e3c8');
    else {
      // Autumn lawns, drifted with fallen maple leaves.
      c.set('#e9c27c').lerp(new THREE.Color('#ff7d3c'), clamp((n + 0.15) * 1.6, 0, 1) * 0.65);
      c.multiplyScalar(0.92 + fbm(x * 0.5, z * 0.5) * 0.1);
    }
    if (h < WATER) c.lerp(new THREE.Color('#4f7c80'), clamp((WATER - h) / 3, 0, 0.7));
    return c;
  }
  footstep(x, z) { return this.splat(x, z)[2] > 0.5 ? 'paw_sand' : 'paw_grass'; }
  dustColor() { return '#e3c49a'; }
  spawn() { return { x: SPAWN.x, z: SPAWN.z, rotY: Math.PI }; }

  // ── Helpers ───────────────────────────────────────────
  /** Collider for something placed in a rotated group, in that group's local frame. */
  solidLocal(group, lx, lz, w, d, y0, y1, extra) {
    group.updateWorldMatrix(true, false);
    const p = group.localToWorld(_v.set(lx, 0, lz));
    return this.solidBox(p.x, p.z, w, d, y0, y1, -group.rotation.y, extra);
  }
  worldOf(group, lx, ly, lz) { group.updateWorldMatrix(true, false); return group.localToWorld(V3(lx, ly, lz)); }

  /** Fades `obj` whenever it stands between the camera and Khione. */
  occlude(obj) {
    obj.updateWorldMatrix(true, true);
    const mats = [];
    obj.traverse((o) => {
      if (!o.isMesh) return;
      const arr = Array.isArray(o.material) ? o.material : [o.material];
      const cl = arr.map((m) => {
        const k = m.userData.own ? m : m.clone();
        if (k.userData.baseOp == null) { k.userData.baseOp = m.opacity; k.userData.baseTr = m.transparent; }
        if (!mats.includes(k)) mats.push(k);
        return k;
      });
      o.material = Array.isArray(o.material) ? cl : cl[0];
    });
    this.occluders.push({ box: new THREE.Box3().setFromObject(obj), mats, a: 1 });
  }
  updateOccluders(dt) {
    const cam = G.camera.position, p = G.player.pos;
    _t.set(p.x, p.y + 0.6, p.z);
    const dir = _v.subVectors(_t, cam);
    const len = dir.length();
    _ray.set(cam, dir.divideScalar(len));
    const k = 1 - Math.exp(-10 * dt);
    for (const o of this.occluders) {
      const hit = _ray.intersectBox(o.box, _hit);
      const target = hit && hit.distanceTo(cam) < len - 0.4 ? 0.22 : 1;
      if (o.a === target) continue;
      o.a = Math.abs(o.a - target) < 0.02 ? target : lerp(o.a, target, k);
      for (const m of o.mats) {
        const tr = m.userData.baseTr || o.a < 0.99;
        if (m.transparent !== tr) { m.transparent = tr; m.needsUpdate = true; }
        m.opacity = m.userData.baseOp * o.a;
        m.depthWrite = !tr;
      }
    }
  }

  /** A facade material: wall colour with a grid of windows that light up at dusk. */
  facadeMat(wall, glass, cols, rows, seed = 1) {
    const R = rng(seed);
    const lit = [];
    for (let i = 0; i < cols * rows; i++) lit.push(R() < 0.72);
    const draw = (emissive) => (g, w, h) => {
      g.fillStyle = emissive ? '#000' : wall; g.fillRect(0, 0, w, h);
      const cw = w / cols, rh = h / rows;
      for (let i = 0; i < cols; i++) for (let j = 0; j < rows; j++) {
        if (emissive && !lit[i * rows + j]) continue;
        g.fillStyle = emissive ? '#fff' : glass;
        g.fillRect(i * cw + cw * 0.2, j * rh + rh * 0.22, cw * 0.6, rh * 0.52);
      }
    };
    const map = canvasTex(128, 256, draw(false));
    const em = canvasTex(128, 256, draw(true));
    const m = new THREE.MeshLambertMaterial({ map, emissive: '#ffcf86', emissiveMap: em, emissiveIntensity: 0.1 });
    m.userData.own = true;
    this.windowMats.push(m);
    return m;
  }
  /** A tower block: facade on the four sides, a plain roof. Origin at its base. */
  tower(w, h, d, facade, roof = '#5f5a55') {
    const g = new THREE.BoxGeometry(w, h, d); g.translate(0, h / 2, 0);
    const r = P.mat(roof).clone(); r.userData.own = true;
    const m = new THREE.Mesh(g, [facade, facade, r, r, facade, facade]);
    m.castShadow = true; m.receiveShadow = true;
    return m;
  }
  glowMat(color, day, dusk) {
    const m = new THREE.MeshLambertMaterial({ color, emissive: color, emissiveIntensity: day });
    m.userData.own = true;
    this.glows.push({ mat: m, day, dusk });
    return m;
  }
  lamp(group, x, y, z, h = 3.4) {
    const post = P.cyl(0.06, 0.09, h, IRON); post.position.set(x, y, z); group.add(post);
    if (!this.lampMat) this.lampMat = this.glowMat('#ffe2a8', 0.35, 1.6);
    const head = P.cyl(0.22, 0.28, 0.26, this.lampMat); head.position.set(x, y + h, z); group.add(head);
    this.solidCyl(x, z, 0.12, y - 1, y + h);
  }
  bench(group, x, y, z, rot = 0) {
    const b = new THREE.Group();
    const seat = P.box(1.8, 0.08, 0.5, WOOD, { round: 0.02 }); seat.position.y = 0.42; b.add(seat);
    const back = P.box(1.8, 0.4, 0.06, WOOD, { round: 0.02 }); back.position.set(0, 0.55, -0.24); b.add(back);
    for (const sx of [-0.75, 0.75]) { const leg = P.box(0.1, 0.45, 0.45, IRON); leg.position.x = sx; b.add(leg); }
    b.position.set(x, y, z); b.rotation.y = rot; group.add(b);
    this.solidBox(x, z, Math.abs(Math.cos(rot)) * 1.8 + Math.abs(Math.sin(rot)) * 0.56, Math.abs(Math.sin(rot)) * 1.8 + Math.abs(Math.cos(rot)) * 0.56, y - 1, y + 0.6);
  }
  maple(group, x, y, z, R, scale = 1) {
    const col = MAPLES[Math.floor(R() * MAPLES.length)];
    const trunk = P.cyl(0.14 * scale, 0.22 * scale, 1.9 * scale, '#5a4334'); trunk.position.set(x, y - 0.1, z); group.add(trunk);
    for (let k = 0; k < 3; k++) {
      const r = (R.range(1.2, 1.8) - k * 0.25) * scale;
      const s = P.sphere(r, col, { seg: 10 }); s.scale.y = 0.82;
      s.position.set(x + R.range(-0.5, 0.5) * scale, y + (2.2 + k * 0.7) * scale, z + R.range(-0.5, 0.5) * scale);
      group.add(s);
    }
    const pile = P.cyl(0.9 * scale, 1.1 * scale, 0.1, col); pile.position.set(x + R.range(-0.6, 0.6), y - 0.04, z + R.range(-0.6, 0.6)); group.add(pile);
  }
  squirrel(crown = false) {
    const s = new THREE.Group();
    const fur = '#7d746c';
    const body = P.sphere(0.12, fur, { seg: 10 }); body.scale.set(0.8, 1.2, 0.9); body.position.y = 0.15; s.add(body);
    const head = P.sphere(0.085, '#8a8178', { seg: 10 }); head.position.set(0, 0.33, 0.05); s.add(head);
    for (const sx of [-1, 1]) {
      const ear = P.cone(0.025, 0.07, '#8a8178', { seg: 5 }); ear.position.set(sx * 0.045, 0.39, 0.04); s.add(ear);
      const eye = P.sphere(0.014, '#111'); eye.position.set(sx * 0.035, 0.35, 0.125); s.add(eye);
    }
    const tail = P.sphere(0.1, '#90867c', { seg: 10 }); tail.scale.set(0.7, 1.7, 0.8); tail.position.set(0, 0.27, -0.15); tail.rotation.x = -0.35; s.add(tail);
    if (crown) { const c = P.cyl(0.065, 0.05, 0.07, '#e8c24a', { seg: 6 }); c.position.y = 0.42; s.add(c); }
    s.userData.tail = tail;
    return s;
  }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 124, res: 210, repeat: 0.2 });
    this.makeWater({ level: WATER, size: 300, res: 100, colors: { deep: '#1f4752', light: '#4f8784', foam: '#d3e2dc' } });
    this.buildPort();
    this.buildDowntown();
    this.buildWall();
    this.buildArena();
    this.buildThreeStars();
    this.buildMuseum();
    this.buildMountain();
    this.buildChalet();
    this.buildCross();
    this.buildFunicular();
    this.buildTrees();
    this.buildHorizon();
    this.buildLeaves();
    this.buildHorse();
    this.buildOven();
    this.buildStairs();
    this.buildDrumBar();
    this.buildLocations();
    G.audio.ambient('ocean_loop', 0.08);
    if (G.state.flag('bagels_placed')) {
      this.setDusk(true);
      if (!G.state.flag('cross_lit')) this.summonSwarm(true);
    }
  }

  // ── The Old Port ──────────────────────────────────────
  buildPort() {
    const deco = new THREE.Group();
    for (let i = 0; i < 7; i++) { const pl = P.box(3.4, 0.16, 1.74, WOOD, { round: 0.03 }); pl.position.set(0, 0.26, 30.9 + i * 1.8); deco.add(pl); }
    for (const sx of [-1.55, 1.55]) for (let i = 0; i < 4; i++) { const pile = P.cyl(0.14, 0.16, 2.8, WOOD_PALE); pile.position.set(sx, -2.4, 32.6 + i * 3.1); deco.add(pile); }
    this.solidBox(0, 36.3, 3.4, 12.6, -4, 0.42);
    // The quay face, where the city meets the St. Lawrence.
    const face = P.box(68, 3.6, 0.5, GREYSTONE); face.position.set(0, -3.2, QUAY + 0.35); deco.add(face);
    for (const [x, z] of [[-3.2, 30.9], [4.2, 30.8], [-9, 31], [9, 31], [-16, 31], [16, 31]]) {
      const b = P.cyl(0.14, 0.18, 0.55, IRON); b.position.set(x, PLAIN, z); deco.add(b);
      const coil = P.torus(0.22, 0.07, '#a8946a'); coil.rotation.x = Math.PI / 2; coil.position.set(x + 0.45, PLAIN + 0.07, z - 0.2); deco.add(coil);
      this.solidCyl(x, z, 0.22, -1, PLAIN + 0.55);
    }
    this.add(P.bake(deco)); this.add(deco);

    // The Old Port clock tower.
    const tower = new THREE.Group(); tower.position.set(6, PLAIN, 28.6); this.add(tower);
    tower.add(P.box(2.4, 9, 2.4, '#e6e1d6'));
    const belfry = P.box(2, 1.6, 2, '#e6e1d6'); belfry.position.y = 9; tower.add(belfry);
    const cap = P.cone(1.55, 1.9, '#5d807a', { seg: 4 }); cap.position.y = 10.6; cap.rotation.y = Math.PI / 4; tower.add(cap);
    const clock = canvasTex(128, 128, (g) => {
      g.fillStyle = '#fbf8ee'; g.beginPath(); g.arc(64, 64, 60, 0, 7); g.fill();
      g.strokeStyle = '#2b2b2b'; g.lineWidth = 6; g.stroke();
      g.lineCap = 'round'; g.lineWidth = 7; g.beginPath(); g.moveTo(64, 64); g.lineTo(64, 26); g.moveTo(64, 64); g.lineTo(92, 74); g.stroke();
    });
    for (let k = 0; k < 4; k++) {
      const a = k * Math.PI / 2;
      const f = new THREE.Mesh(new THREE.CircleGeometry(0.58, 24), new THREE.MeshLambertMaterial({ map: clock }));
      f.position.set(Math.sin(a) * 1.01, 9.8, Math.cos(a) * 1.01); f.rotation.y = a; tower.add(f);
    }
    this.occlude(tower);
    this.solidBox(6, 28.6, 2.4, 2.4, -1, 11);

    // A moored river ferry, nodding at its lines.
    const ferry = new THREE.Group(); ferry.position.set(15, WATER + 0.25, 39); ferry.rotation.y = 0.35; this.add(ferry);
    const hull = P.box(2.6, 0.8, 7, '#2f3a48', { round: 0.12 }); hull.position.y = -0.3; ferry.add(hull);
    const cabin = P.box(2.2, 1.0, 4.2, '#ebe7de'); cabin.position.set(0, 0.5, -0.4); ferry.add(cabin);
    const upper = P.box(1.6, 0.8, 1.6, '#ebe7de'); upper.position.set(0, 1.5, -1); ferry.add(upper);
    const stack = P.cyl(0.16, 0.2, 1.0, '#c0392b'); stack.position.set(0, 2.3, -1); ferry.add(stack);
    const fw = this.glowMat('#ffd79a', 0.25, 1.3);
    for (const wz of [-2, -0.8, 0.4, 1.6]) for (const sx of [-1, 1]) {
      const w = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.4), fw); w.position.set(sx * 1.11, 1.0, wz); w.rotation.y = sx * Math.PI / 2; ferry.add(w);
    }
    this.every(() => { ferry.position.y = WATER + 0.25 + Math.sin(G.time * 0.9) * 0.08; ferry.rotation.z = Math.sin(G.time * 0.7) * 0.02; });

    // The Farine Five Roses sign on its brick mill, facing the river.
    const mill = new THREE.Group(); mill.position.set(26, PLAIN, 27.5); mill.rotation.y = -0.3; this.add(mill);
    mill.add(this.tower(6, 7, 4, this.facadeMat('#7e4c3c', '#3b3330', 3, 4, 55), '#4a3a34'));
    for (const sx of [-2, 2]) { const leg = P.box(0.12, 1.8, 0.12, IRON); leg.position.set(sx, 7, 0.6); mill.add(leg); }
    const signTex = textTex(['FARINE', 'FIVE ROSES'], { w: 512, h: 170, fg: '#ea3a2a', font: 'bold 66px "Arial Black", "Baloo 2", sans-serif' });
    const signMat = new THREE.MeshLambertMaterial({ map: signTex, transparent: true, emissive: '#ff3a24', emissiveMap: signTex, emissiveIntensity: 0.15, side: THREE.DoubleSide });
    signMat.userData.own = true;
    this.glows.push({ mat: signMat, day: 0.15, dusk: 1.3 });
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(6.2, 2.05), signMat); sign.position.set(0, 8.4, 0.6); mill.add(sign);
    this.occlude(mill);
    this.solidLocal(mill, 0, 0, 6, 4, -1, 8);

    // The funicular's lower station on the west quay.
    const st = new THREE.Group(); st.position.set(-18.5, PLAIN, 27.8); this.add(st);
    st.add(P.box(2.4, 2.4, 3, '#806b56'));
    const roof = P.box(2.8, 0.4, 3.4, '#5c4d42'); roof.position.y = 2.4; st.add(roof);
    this.occlude(st);
    this.solidBox(-18.5, 27.8, 2.4, 3, -1, 2.8);
  }

  // ── Downtown ──────────────────────────────────────────
  buildDowntown() {
    // Place Ville Marie: the cruciform glass tower and its sweeping beacon.
    const pvm = new THREE.Group(); pvm.position.set(-22, PLAIN, 17); this.add(pvm);
    const glass = this.facadeMat('#8aa3b2', '#cfe1e9', 4, 10, 3);
    pvm.add(this.tower(3.2, 18, 8, glass, '#6c7f8a'));
    pvm.add(this.tower(8, 18, 3.2, glass, '#6c7f8a'));
    this.occlude(pvm);
    this.solidBox(-22, 17, 3.2, 8, -1, 19); this.solidBox(-22, 17, 8, 3.2, -1, 19);
    this.beacon = new THREE.Group(); this.beacon.position.y = 18.6; pvm.add(this.beacon);
    const beamMat = new THREE.MeshBasicMaterial({ color: '#fff1c8', transparent: true, opacity: 0.3, depthWrite: false, blending: THREE.AdditiveBlending });
    this.beamMat = beamMat;
    for (let k = 0; k < 4; k++) {
      const a = k * Math.PI / 2;
      const b = new THREE.Mesh(new THREE.BoxGeometry(0.18, 0.18, 12), beamMat); b.position.set(Math.sin(a) * 6, 0, Math.cos(a) * 6); b.rotation.y = a; this.beacon.add(b);
    }
    const bl = P.sphere(0.3, '#fff6dc', { emissive: '#fff1c8', emissiveIntensity: 1 }); bl.position.y = 18.6; pvm.add(bl);

    // Greystone and glass, back from the plaza.
    for (const [x, z, w, h, d, col, cols, rows] of [[-26, 5, 5, 12, 5, '#a39b8e', 4, 7], [-9, 26.5, 4, 9, 4, '#7d8b96', 3, 5], [32, 21, 4.5, 14, 4.5, '#8fa6b4', 3, 8]]) {
      const m = this.tower(w, h, d, this.facadeMat(col, '#d6e4ea', cols, rows, (x * 7 + z) | 0));
      m.position.set(x, PLAIN, z); this.add(m); this.occlude(m);
      this.solidBox(x, z, w, d, -1, h + 1);
    }

    const deco = new THREE.Group();
    // Orange cones: nobody moved them. Nobody ever will.
    for (const [x, z] of [[-4, 8], [-3, 9.5], [6, 6], [21, 11.5], [-9, 30], [3.4, 1.6]]) {
      const c = P.cone(0.3, 0.8, '#f27318', { seg: 10 }); c.position.set(x, PLAIN + 0.06, z); deco.add(c);
      const stripe = P.cyl(0.19, 0.22, 0.12, '#ffffff', { seg: 10 }); stripe.position.set(x, PLAIN + 0.42, z); deco.add(stripe);
      const base = P.box(0.6, 0.06, 0.6, '#f27318'); base.position.set(x, PLAIN, z); deco.add(base);
      this.solidCyl(x, z, 0.25, -1, PLAIN + 0.9);
    }
    for (const [x, z] of [[-6, 12], [8, 11], [-6, 24], [8, 25], [-14, 12], [-2, 0.4]]) this.lamp(deco, x, PLAIN, z);
    this.bench(deco, -2, PLAIN, 17, 0);
    this.bench(deco, 4, PLAIN, 17, 0);
    this.bench(deco, -10, PLAIN, 6, Math.PI / 2);
    // Street maples in stone planters.
    const R = rng(808);
    for (const [x, z] of [[-8, 16], [5, 21], [-3, 5], [10, 4], [-18, 23]]) {
      const pl = P.box(2.0, 0.5, 2.0, GREYSTONE, { round: 0.06 }); pl.position.set(x, PLAIN, z); deco.add(pl);
      this.maple(deco, x, PLAIN + 0.5, z, R, 0.75);
      this.solidBox(x, z, 2.0, 2.0, -1, PLAIN + 0.5);
      this.solidCyl(x, z, 0.25, PLAIN, PLAIN + 3);
    }
    // The Cartier monument just over the wall: plinth, column, a bronze arm raised.
    const mx = 21, mz = -7.5;
    const pl = P.box(2.4, 2.4, 2.4, GREYSTONE); pl.position.set(mx, PLAIN, mz); deco.add(pl);
    const col = P.cyl(0.5, 0.6, 3.6, GREYSTONE); col.position.set(mx, PLAIN + 2.4, mz); deco.add(col);
    const fig = new THREE.Mesh(new THREE.CapsuleGeometry(0.28, 0.7, 4, 10), P.mat('#6b5a40')); fig.position.set(mx, PLAIN + 6.6, mz); deco.add(fig);
    const arm = P.cyl(0.06, 0.06, 0.9, '#6b5a40', { base: false }); arm.position.set(mx + 0.38, PLAIN + 7.2, mz); arm.rotation.z = -0.9; deco.add(arm);
    const angel = P.sphere(0.2, '#6b5a40'); angel.position.set(mx, PLAIN + 7.2, mz); deco.add(angel);
    this.solidBox(mx, mz, 2.4, 2.4, -1, PLAIN + 6);
    this.add(P.bake(deco)); this.add(deco);
  }

  buildWall() {
    for (const s of [-1, 1]) {
      // In segments, so only the stretch between her and the camera fades.
      for (let x0 = ROAD; x0 < 48; x0 += 8) {
        const len = Math.min(48, x0 + 8) - x0, cx = s * (x0 + len / 2);
        const seg = new THREE.Group();
        const w = P.box(len, 4.0, 0.6, STONE); w.position.set(cx, PLAIN + 2.3 - 4.0, WALL_Z); seg.add(w);
        const cap = P.box(len + 0.02, 0.18, 0.8, '#aaa59c'); cap.position.set(cx, PLAIN + 2.3, WALL_Z); seg.add(cap);
        this.add(seg); this.occlude(seg);
      }
      this.solidBox(s * (ROAD + 24), WALL_Z, 48, 0.6, -4, PLAIN + 2.3);
      // Gate pillars either side of the road, each with a lamp.
      const pil = P.box(0.9, 3.0, 0.9, GREYSTONE); pil.position.set(s * (ROAD + 0.45), PLAIN, WALL_Z); this.add(pil);
      if (!this.lampMat) this.lampMat = this.glowMat('#ffe2a8', 0.35, 1.6);
      const globe = P.sphere(0.26, this.lampMat); globe.position.set(s * (ROAD + 0.45), PLAIN + 3.3, WALL_Z); this.add(globe);
    }
    const sign = P.sign(['CHEMIN', 'OLMSTED'], { w: 1.0, h: 0.5, bg: '#2f5a3a', fg: '#f4f1ea', border: '#f4f1ea', color: '#2f5a3a' });
    sign.position.set(ROAD + 0.45, PLAIN + 1.6, WALL_Z + 0.46); this.add(sign);
  }

  // ── The Bell Centre ───────────────────────────────────
  buildArena() {
    const A = ARENA, W = 14, D = 12, H = 6;
    const g = new THREE.Group(); g.position.copy(A); this.add(g); this.arena = g;
    const wallCol = '#a39d93';
    const walls = [[0, -D / 2, W, 0.5], [-W / 2, 0, 0.5, D], [W / 2, 0, 0.5, D], [-(W / 4 + 0.7), D / 2, W / 2 - 1.4, 0.5], [W / 4 + 0.7, D / 2, W / 2 - 1.4, 0.5]];
    walls.forEach(([x, z, w, d], i) => {
      const grp = new THREE.Group(); g.add(grp);
      const m = P.box(w, H, d, wallCol); m.position.set(x, 0, z); grp.add(m);
      if (i === 1 || i === 2) {
        // The stands: bleu-blanc-rouge seat bands on the long walls.
        const side = i === 1 ? -1 : 1;
        ['#bf2a33', '#efede6', '#294a8f'].forEach((c, row) => {
          const st = P.box(0.08, 0.55, D - 1.2, c, { base: false }); st.position.set(side * (W / 2 - 0.32), 1.0 + row * 0.85, 0); st.rotation.z = side * 0.28; grp.add(st);
        });
      }
      this.occlude(grp);
      this.solidBox(A.x + x, A.z + z, w, d, -1, A.y + H);
    });
    const lintel = P.box(2.9, 1.6, 0.5, wallCol); lintel.position.set(0, H - 1.6, D / 2); g.add(lintel); this.occlude(lintel);
    const roof = P.box(W + 0.6, 0.4, D + 0.6, '#5c6068'); roof.position.y = H; g.add(roof); this.occlude(roof);
    const front = new THREE.Group(); g.add(front);
    const band = P.box(W + 0.2, 0.9, 0.12, '#bf2a33'); band.position.set(0, H - 2.05, D / 2 + 0.31); front.add(band);
    const name = new THREE.Mesh(new THREE.PlaneGeometry(6, 0.75), new THREE.MeshLambertMaterial({ map: textTex('CENTRE BELL', { w: 512, h: 64, fg: '#fbf6ea', font: 'bold 50px "Baloo 2", sans-serif', pad: 4 }), transparent: true }));
    name.position.set(0, H - 1.6, D / 2 + 0.38); front.add(name);
    this.occlude(front);
    // House pennants on a line overhead.
    for (let k = 0; k < 8; k++) {
      const p = P.box(0.3, 0.4, 0.03, k % 2 ? '#efede6' : '#bf2a33', { base: false }); p.position.set(-4.9 + k * 1.4, H - 1.0, -1.6 + (k % 2) * 3.2); p.rotation.x = 0.15; g.add(p);
    }
    // The four bronze legends on the plaza, mid-stride.
    const deco = new THREE.Group();
    const bronze = '#6e5232';
    for (let i = 0; i < 4; i++) {
      const x = -4.5 + i * 3, z = D / 2 + 2.6;
      const pl = P.box(1.0, 0.6, 1.0, STONE); pl.position.set(A.x + x, A.y, A.z + z); deco.add(pl);
      const s = new THREE.Group(); s.position.set(A.x + x, A.y + 0.6, A.z + z); s.rotation.y = 0.2 * (i - 1.5);
      const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.26, 0.6, 4, 10), P.mat(bronze)); body.position.y = 0.7; body.rotation.z = 0.12 * (i % 2 ? 1 : -1); s.add(body);
      const head = P.sphere(0.2, bronze); head.position.y = 1.4; s.add(head);
      const stick = P.cyl(0.03, 0.03, 1.5, bronze, { base: false }); stick.position.set(0.35, 0.6, 0.2); stick.rotation.z = 0.5; stick.rotation.x = 0.4 * (i % 2); s.add(stick);
      deco.add(s);
      this.solidBox(A.x + x, A.z + z, 1.0, 1.0, -1, A.y + 2.2);
    }
    this.add(P.bake(deco)); this.add(deco);
  }

  arenaLocal(p) { return _v.set(p.x - ARENA.x, p.y, p.z - ARENA.z); }
  inArena(p = G.player.pos) { const l = this.arenaLocal(p); return Math.abs(l.x) < 6.8 && Math.abs(l.z) < 5.8; }

  buildThreeStars() {
    const g = this.arena, A = ARENA;
    const ice = P.box(11.5, 0.06, 9.5, '#e2edf5', { emissive: '#a9c4dc', emissiveIntensity: 0.22 }); g.add(ice);
    this.solidBox(A.x, A.z, 11.5, 9.5, -1, A.y + 0.06);
    const lines = new THREE.Group();
    const red = P.box(0.12, 0.012, 9.3, '#c8322f'); red.position.y = 0.06; lines.add(red);
    for (const bx of [-3.5, 3.5]) { const b = P.box(0.1, 0.012, 9.3, '#2b5fb8'); b.position.set(bx, 0.06, 0); lines.add(b); }
    const dot = P.cyl(0.26, 0.26, 0.014, '#c8322f'); dot.position.y = 0.06; lines.add(dot);
    // Boards (a cat hops them; the gate is the south gap).
    const bw = (w, d, x, z) => {
      const b = P.box(w, 0.5, d, '#f4f2ec'); b.position.set(x, 0, z); lines.add(b);
      const t = P.box(w + 0.02, 0.06, d + 0.02, '#2b6cb5'); t.position.set(x, 0.5, z); lines.add(t);
    };
    bw(11.7, 0.12, 0, -4.8); bw(0.12, 9.7, -5.85, 0); bw(0.12, 9.7, 5.85, 0); bw(4.65, 0.12, -3.52, 4.8); bw(4.65, 0.12, 3.52, 4.8);
    for (const gx of [-5, 5]) {
      const net = P.box(0.35, 0.9, 1.6, '#d33a33'); net.position.set(gx, 0.06, 0); lines.add(net);
      const mesh = P.box(0.3, 0.8, 1.5, '#f6f6f6'); mesh.position.set(gx + Math.sign(gx) * 0.04, 0.08, 0); lines.add(mesh);
      this.solidBox(A.x + gx, A.z, 0.5, 1.6, -1, A.y + 1.0);
    }
    g.add(lines);

    // The Zamboni, parked on the centre dot.
    const zam = new THREE.Group(); g.add(zam); this.zamboni = zam;
    const zb = P.box(1.6, 1.0, 2.6, '#f2f2f2', { round: 0.1 }); zb.position.y = 0.12; zam.add(zb);
    const zs = P.box(1.62, 0.18, 2.62, '#2b5fb8'); zs.position.y = 0.6; zam.add(zs);
    const cab = P.box(1.4, 0.7, 1.0, '#c8322f', { round: 0.06 }); cab.position.set(0, 1.12, -0.6); zam.add(cab);
    for (const [sx, sz] of [[-0.75, 0.9], [0.75, 0.9], [-0.75, -0.9], [0.75, -0.9]]) {
      const w = P.cyl(0.28, 0.28, 0.2, '#232326', { base: false }); w.rotation.z = Math.PI / 2; w.position.set(sx, 0.34, sz); zam.add(w);
    }
    this.zamSolid = this.solidBox(A.x, A.z, 1.6, 2.6, -1, A.y + 1.9);
    if (G.state.flag('three_stars_done')) this.parkZamboni(true);

    // The great scoreboard cube, hanging dark over centre ice.
    const cube = new THREE.Group(); cube.position.y = 4.6; g.add(cube); this.cube = cube;
    cube.add(P.box(2.4, 1.6, 2.4, '#1d1d22', { base: false }));
    for (const y of [0.78, -0.78]) { const b = P.box(2.5, 0.12, 2.5, '#bf2a33', { base: false }); b.position.y = y; cube.add(b); }
    const cable = P.cyl(0.04, 0.04, 1.2, '#333'); cable.position.y = 0.8; cube.add(cable);
    const sc = document.createElement('canvas'); sc.width = 256; sc.height = 160;
    this.screenCanvas = sc;
    this.screenTex = new THREE.CanvasTexture(sc); this.screenTex.colorSpace = THREE.SRGBColorSpace;
    this.screenMat = new THREE.MeshBasicMaterial({ map: this.screenTex, color: '#26262c' });
    for (let k = 0; k < 4; k++) {
      const a = k * Math.PI / 2;
      const s = new THREE.Mesh(new THREE.PlaneGeometry(2.0, 1.2), this.screenMat); s.position.set(Math.sin(a) * 1.215, 0, Math.cos(a) * 1.215); s.rotation.y = a; cube.add(s);
    }
    this.setScreen('', '');
    this.sense(cube, { warm: () => G.state.knows('growl') && !this.awake && !G.state.flag('three_stars_done'), height: 0, radius: 13 });

    // Retired numbers in the rafters, and the five fallen banners on the ice.
    [1, 2, 3, 5, 12, 29].forEach((n, i) => {
      const b = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 1.1), new THREE.MeshLambertMaterial({ map: this.bannerTex(n) }));
      b.position.set(-4.5 + i * 1.8, 5.0, -5.6); g.add(b);
    });
    this.banners = {};
    BANNERS.forEach((n, i) => {
      const x = -4 + i * 2;
      const hoist = new THREE.Group(); hoist.position.set(x, 0.07, 3.0); g.add(hoist);
      const cloth = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 1.4), new THREE.MeshLambertMaterial({ map: this.bannerTex(n), side: THREE.DoubleSide }));
      cloth.rotation.x = -Math.PI / 2 + 0.04; cloth.position.y = 0.02; hoist.add(cloth);
      const rope = P.cyl(0.015, 0.015, 5.8, '#9a9a9a'); rope.position.set(x, 0, 2.4); g.add(rope);
      this.banners[n] = { hoist, cloth };
      if (G.state.flag('three_stars_done') && STARS.includes(n)) { hoist.position.y = 3.4; cloth.rotation.x = 0; }
      this.interact({
        pos: V3(A.x + x, A.y, A.z + 3.0), radius: 1.1, icon: '\u{1F6A9}',
        label: () => (G.state.flag('three_stars_done') ? null : `Hoist the ${n} banner`),
        use: () => this.hoist(n),
      });
    });

    // The penalty box against the north boards: three spare panes inside.
    const box = new THREE.Group(); box.position.set(-4, 0.06, -3.9); g.add(box);
    const glassMat = new THREE.MeshLambertMaterial({ color: '#cfe3ee', transparent: true, opacity: 0.45, depthWrite: false });
    const back = P.box(2.4, 1.2, 0.08, glassMat); back.position.z = -0.5; box.add(back);
    for (const sx of [-1.2, 1.2]) { const s = P.box(0.08, 1.2, 1.0, glassMat); s.position.x = sx; box.add(s); }
    const bench = P.box(2.0, 0.4, 0.4, '#3b3b40'); bench.position.z = -0.25; box.add(bench);
    const hinge = new THREE.Group(); hinge.position.set(-1.2, 0, 0.5); box.add(hinge);
    const door = P.box(2.4, 1.2, 0.06, glassMat); door.position.x = 1.2; hinge.add(door);
    const rail = P.box(2.4, 0.06, 0.08, '#2b2b30'); rail.position.set(1.2, 1.2, 0); hinge.add(rail);
    this.boxDoor = hinge;
    this.solidBox(A.x - 4, A.z - 3.9, 2.5, 1.1, -1, A.y + 1.3, 0, { noStand: true });
    if (G.state.flag('three_stars_done')) this.openBox(true);

    this.onVocal((e) => {
      if (!this.inArena(e.pos) || G.state.flag('three_stars_done')) return;
      const l = this.arenaLocal(e.pos);
      const zp = this.zamboni.position;
      if (e.kind === 'hiss' && !this.zamboniMoved) {
        if (Math.hypot(l.x - zp.x, l.z - zp.z) < 6) this.parkZamboni(false);
      } else if (e.kind === 'growl' && !this.awake) {
        if (!this.zamboniMoved) G.ui.toast('The Zamboni’s engine drowns her out. Machines don’t fear a growl. They flee a hiss.', '\u{1F9CA}');
        else if (Math.hypot(l.x, l.z) < 2.6) this.wakeCube();
        else G.ui.toast('The cube hangs dark over the centre dot. Growl from RIGHT under it.', '\u{1F3D2}');
      }
    });
  }

  bannerTex(n) {
    return P.textCanvas(String(n), { w: 128, h: 192, bg: '#bf2a33', fg: '#fffaf0', border: '#f2efe6', font: 'bold 92px "Baloo 2", sans-serif', radius: 8 });
  }
  setScreen(stars, num) {
    const g = this.screenCanvas.getContext('2d');
    g.fillStyle = '#0d0b08'; g.fillRect(0, 0, 256, 160);
    g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = '#ffc24a';
    if (stars) { g.font = 'bold 40px sans-serif'; g.fillText(stars, 128, num ? 40 : 80); }
    if (num) { g.font = `bold ${Math.min(84, Math.floor(430 / num.length))}px "Baloo 2", sans-serif`; g.fillText(num, 128, stars ? 108 : 80); }
    this.screenTex.needsUpdate = true;
  }
  parkZamboni(instant) {
    this.zamboniMoved = true;
    const to = { x: 4.4, z: -2.9 };
    const sync = () => { this.zamSolid.x = ARENA.x + this.zamboni.position.x; this.zamSolid.z = ARENA.z + this.zamboni.position.z; this.zamSolid.rot = -this.zamboni.rotation.y; };
    if (instant) { this.zamboni.position.set(to.x, 0, to.z); this.zamboni.rotation.y = -0.9; sync(); return; }
    G.audio.sfx('robot_flee', { vol: 0.8, rate: 0.8 });
    G.tween(this.zamboni.position, to, 2.2, ease.inOut, sync);
    G.tween(this.zamboni.rotation, { y: -0.9 }, 2.2);
    G.ui.say('The Zamboni flees to the corner, resurfacing as it goes. Machines still hate a hiss. The centre dot is clear.', { dur: 4 });
  }
  wakeCube() {
    this.awake = true;
    G.audio.sfx('goal_horn', { vol: 1 });
    G.rig.shake = 0.4;
    this.screenMat.color.set('#ffffff');
    this.cube.children[0].material = P.mat('#2a2522', { emissive: '#ff9a40', emissiveIntensity: 0.25 });
    G.ui.celebrate('The cube wakes!', 'Horn! House lights!');
    G.ui.say('Horn, house lights, and the cube calls the three stars of the game.', { dur: 3.6 });
    this.callStars();
  }
  /** The callout, the way a rink does it: three stars, two, one. Repeats until the banners answer. */
  async callStars() {
    const my = ++this.callRound;
    await G.wait(2);
    const alive = () => G.island === this && this.awake && my === this.callRound && !G.state.flag('three_stars_done');
    const at = this.cube.getWorldPosition(V3());
    while (alive()) {
      for (let i = 0; i < 3; i++) {
        if (!alive()) return;
        const stars = ['★ ★ ★', '★ ★', '★'][i];
        this.setScreen(stars, String(STARS[i]));
        G.audio.sfx('bell_ding', { vol: 0.6, rate: 1 + 0.1 * i, pos: at, range: 40 });
        if (this.inArena()) G.ui.showBanner(`${stars}   #${STARS[i]}`, 1.6);
        await G.wait(1.8);
      }
      if (!alive()) return;
      this.setScreen('', '');
      await G.wait(1.4);
    }
  }
  hoist(n) {
    if (!this.awake) { G.ui.say('The hoist works, but the rafters keep their secret while the cube is dark.'); return; }
    if (this.hoisted.includes(n) || this.buzzing || this.winning) return;
    const b = this.banners[n];
    G.tween(b.hoist.position, { y: 3.4 }, 1.2, ease.out);
    G.tween(b.cloth.rotation, { x: 0 }, 1.2);
    G.audio.sfx('wood_creak', { vol: 0.5, rate: 1.2 });
    if (n !== STARS[this.hoisted.length]) { this.buzzing = true; G.wait(1.3).then(() => this.buzz()); return; }
    this.hoisted.push(n);
    if (this.hoisted.length >= STARS.length) { this.winning = true; G.wait(1.3).then(() => this.winStars()); }
  }
  buzz() {
    G.audio.sfx('fail', { vol: 0.8, rate: 0.7 });
    G.audio.sfx('crowd_groan', { vol: 0.9 });
    for (const n of BANNERS) {
      const b = this.banners[n];
      G.tween(b.hoist.position, { y: 0.07 }, 0.7, ease.outBounce);
      G.tween(b.cloth.rotation, { x: -Math.PI / 2 + 0.04 }, 0.7);
    }
    this.hoisted = [];
    this.buzzing = false;
    G.ui.say('BUZZER. Every banner drops and the whole building groans. Not that star, not in that order. The cube calls them again.', { dur: 4.5 });
    this.callStars();
  }
  winStars() {
    G.state.set('three_stars_done');
    this.callRound++;
    G.audio.sfx('goal_horn', { vol: 1, rate: 1.05 });
    G.audio.sfx('crowd_cheer', { vol: 0.9 });
    this.setScreen('OLÉ!', '9   4   10');
    G.fx.confetti(ARENA.clone().setY(4.5), 70);
    this.openBox(false);
    G.ui.celebrate('The Three Stars!', 'Olé, olé, olé');
    G.ui.say('The horn again, and a crowd that is not there sings. The penalty box door swings open: three spare panes of arena glass.', { dur: 5 });
    // …and the horn shakes something loose from the rafters.
    G.wait(4).then(() => { if (G.island === this) this.dropPortrait(true); });
  }
  openBox(instant) {
    if (instant) this.boxDoor.rotation.y = -1.4;
    else G.tween(this.boxDoor.rotation, { y: -1.4 }, 0.9, ease.outBounce);
    if (G.state.flag('panes_fitted')) return;
    for (let i = 0; i < 3; i++) {
      const pane = new THREE.Group();
      const gl = P.box(0.42, 0.5, 0.05, new THREE.MeshLambertMaterial({ color: '#d8ecf6', transparent: true, opacity: 0.6 })); pane.add(gl);
      const fr = P.box(0.46, 0.04, 0.07, '#9aa6ae'); fr.position.y = 0.5; pane.add(fr);
      pane.rotation.x = -0.2;
      this.pickup({ id: 'arena_pane', key: `arena_pane_${i}`, pos: V3(ARENA.x - 4.6 + i * 0.6, ARENA.y + 0.06, ARENA.z - 2.9), obj: pane, bob: false, radius: 1.0 });
    }
  }
  dropPortrait(animated) {
    if (G.state.flag('mmfa_delivered') || G.state.has('lafleur_portrait')) return;
    const target = V3(ARENA.x + 2, ARENA.y + 0.07, ARENA.z + 1.5);
    const obj = new THREE.Group();
    const frame = P.box(1.0, 0.08, 1.3, '#cfae4c'); obj.add(frame);
    const canvas = new THREE.Mesh(new THREE.PlaneGeometry(0.84, 1.14), new THREE.MeshLambertMaterial({ map: this.portraitTex() }));
    canvas.rotation.x = -Math.PI / 2; canvas.position.y = 0.085; obj.add(canvas);
    const holder = this.pickup({ id: 'lafleur_portrait', pos: target, obj, bob: false, radius: 1.5 });
    if (!holder || !animated) return;
    holder.position.y += 4.8;
    G.tween(holder.position, { y: target.y }, 0.9, ease.in).then(() => {
      G.audio.sfx('coconut_thunk', { vol: 0.9, rate: 0.7 });
      G.audio.sfx('crowd_groan', { vol: 0.4, rate: 1.2 });
      G.fx.dust(target);
      G.ui.say('Something shakes loose from the rafters and lands FLAT on the ice: a framed portrait, number 10. The plaque: Propriété du Musée des beaux-arts, en prêt.', { dur: 6.5 });
    });
  }
  portraitTex() {
    return canvasTex(128, 176, (g, w, h) => {
      g.fillStyle = '#b9332f'; g.fillRect(0, 0, w, h);
      g.fillStyle = '#e9d6b8'; g.beginPath(); g.ellipse(64, 70, 24, 30, 0, 0, 7); g.fill();
      g.fillStyle = '#f3dc8a'; g.beginPath(); g.ellipse(64, 50, 28, 16, 0, Math.PI, 0); g.fill();
      g.fillStyle = '#fffaf0'; g.font = 'bold 40px "Baloo 2", sans-serif'; g.textAlign = 'center'; g.fillText('10', 64, 150);
    });
  }

  // ── The museum (The Fallen Star) ──────────────────────
  buildMuseum() {
    const m = new THREE.Group(); m.position.copy(MUSEUM); m.rotation.y = Math.PI / 2; this.add(m); this.museum = m;
    m.updateWorldMatrix(true, false);
    const stone = '#ddd6c8';
    const W = (lx, ly, lz, w, h, d, col = stone, solid = true) => {
      const b = P.box(w, h, d, col); b.position.set(lx, ly, lz); m.add(b);
      this.occlude(b);
      if (solid) this.solidLocal(m, lx, lz, w, d, -1, MUSEUM.y + ly + h);
      return b;
    };
    W(3.8, 0, 0, 0.4, 4, 7);
    W(0, 0, 3.5, 7, 4, 0.4);
    W(0, 0, -3.5, 7, 4, 0.4);
    W(-3.4, 0, 2.35, 0.4, 4, 2.3);
    W(-3.4, 0, -2.35, 0.4, 4, 2.3);
    W(-3.4, 2.6, 0, 0.4, 1.4, 2.5, stone, false);
    W(0, 4.0, 0, 7.6, 0.4, 7.6, '#8f949b', false);
    W(-4.4, 3.8, 0, 2.2, 0.3, 7.8, stone, false);
    const ped = prism(1.4, 8.2, 1.5, stone); ped.position.set(-4.4, 4.1, 0); m.add(ped);
    const frieze = new THREE.Mesh(new THREE.PlaneGeometry(5.2, 0.4), new THREE.MeshLambertMaterial({ map: textTex('MUSÉE DES BEAUX-ARTS', { w: 512, h: 40, fg: '#6b604f', font: 'bold 30px serif', pad: 2 }), transparent: true }));
    frieze.position.set(-5.13, 4.38, 0); frieze.rotation.y = -Math.PI / 2; m.add(frieze);
    const front = new THREE.Group(); m.add(front); front.add(ped.removeFromParent(), frieze.removeFromParent());
    this.occlude(front);
    // Floor, columns, steps, the MBAM banner.
    const floor = P.box(7, 0.1, 7, '#b88d5e'); m.add(floor);
    this.solidLocal(m, 0, 0, 7, 7, -1, MUSEUM.y + 0.1);
    const deco = new THREE.Group(); m.add(deco);
    for (const cz of [-2.6, -0.9, 0.9, 2.6]) {
      const c = P.cyl(0.28, 0.32, 3.8, '#efebe2'); c.position.set(-4.6, 0, cz); deco.add(c);
      const w = this.worldOf(m, -4.6, 0, cz); this.solidCyl(w.x, w.z, 0.3, -1, 4);
    }
    for (let s = 0; s < 3; s++) { const st = P.box(0.9, 0.1, 7.6, '#c9c3b8'); st.position.set(-5.2 - s * 0.9, -0.05 - s * 0.06, 0); deco.add(st); }
    const mbam = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 2.2), new THREE.MeshLambertMaterial({ map: P.textCanvas(['M', 'B', 'A', 'M'], { w: 128, h: 320, bg: '#2f4a8a', fg: '#f4f1ea', border: '#f4f1ea', font: 'bold 54px "Baloo 2", sans-serif', radius: 8 }) }));
    mbam.position.set(-4.95, 2.2, 3.15); mbam.rotation.y = -Math.PI / 2; deco.add(mbam);
    // The grand door: dark wood, a rope handle, and the fateful word.
    const hinge = new THREE.Group(); hinge.position.set(-3.42, 0, 1.2); m.add(hinge);
    const door = P.box(0.16, 3.2, 2.4, '#4d3626'); door.position.z = -1.2; hinge.add(door);
    const word = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 0.45), new THREE.MeshLambertMaterial({ map: textTex('TIREZ', { w: 256, h: 88, fg: '#efe2c6', font: 'bold 64px serif' }), transparent: true }));
    word.position.set(-0.09, 2.4, -1.2); word.rotation.y = -Math.PI / 2; hinge.add(word);
    const rope = P.cyl(0.05, 0.07, 0.7, '#b39a66'); rope.position.set(-0.14, 0.9, -2.0); hinge.add(rope);
    this.museumDoor = hinge;
    this.doorSolid = this.solidLocal(m, -3.42, 0, 0.3, 2.4, -1, MUSEUM.y + 3.2);
    if (G.state.flag('museum_door_open')) { hinge.rotation.y = 1.7; this.doorSolid.enabled = false; }
    // Inside: the empty easel, two loaned pieces, sconces dark until the delivery.
    const easel = new THREE.Group(); easel.position.set(2.4, 0.1, 0); easel.rotation.y = -Math.PI / 2 - 0.15; m.add(easel); this.easel = easel;
    for (const sx of [-0.4, 0.4]) { const leg = P.cyl(0.04, 0.05, 1.9, '#73563c'); leg.position.set(sx, 0, -0.1); leg.rotation.x = 0.16; easel.add(leg); }
    const leg3 = P.cyl(0.04, 0.05, 1.8, '#73563c'); leg3.position.set(0, 0, 0.42); leg3.rotation.x = -0.32; easel.add(leg3);
    const ledge = P.box(1.1, 0.08, 0.14, '#73563c'); ledge.position.set(0, 0.62, -0.02); easel.add(ledge);
    this.missingSign = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.28), new THREE.MeshLambertMaterial({ map: P.textCanvas('pièce manquante', { w: 256, h: 80, bg: '#f7f2e6', fg: '#6b5440', border: '#6b5440', font: 'italic bold 30px serif', radius: 6 }) }));
    this.missingSign.position.set(0, 1.25, 0.02); easel.add(this.missingSign);
    for (const [z, col] of [[2.0, '#b84a3a'], [-2.0, '#3d5a9a']]) {
      const fr = P.box(0.06, 1.0, 0.8, '#cfae4c', { base: false }); fr.position.set(3.55, 2.0, z); m.add(fr);
      const art = P.box(0.04, 0.84, 0.64, col, { base: false }); art.position.set(3.51, 2.0, z); m.add(art);
    }
    this.museumGlow = [];
    for (const wz of [-2.2, 2.2]) {
      const mat = new THREE.MeshLambertMaterial({ color: '#6b6152', emissive: '#ffd590', emissiveIntensity: 0 });
      const s = P.cyl(0.12, 0.16, 0.3, mat); s.position.set(3.55, 2.6, wz); m.add(s);
      this.museumGlow.push(mat);
    }
    // The sculpture-garden squirrel, waiting on the steps.
    const sq = this.squirrel(); sq.position.set(-5.3, 0.02, 2.0); sq.rotation.y = -Math.PI / 2; m.add(sq); this.gardenSquirrel = sq;
    this.every(() => { sq.userData.tail.rotation.x = -0.35 + Math.sin(G.time * 3) * 0.12; });
    if (G.state.flag('mmfa_delivered')) { this.hangPortrait(true); this.museumLights(); }

    const doorW = this.worldOf(m, -4.4, 0, 0);
    this.interact({
      pos: doorW, radius: 2.2, icon: '\u{1F6AA}',
      label: () => (G.state.flag('museum_door_open') ? null : 'The grand door (TIREZ)'),
      use: () => this.museumDoorUse(),
    });
    this.sense(door, { warm: () => !G.state.flag('museum_door_open') && G.state.has('lafleur_portrait'), height: 1.5 });
    this.interact({
      pos: this.worldOf(m, 1.4, 0, 0), radius: 1.8, icon: '\u{1F5BC}️',
      label: () => (G.state.flag('mmfa_delivered') ? 'The Démon Blond, home' : G.state.has('lafleur_portrait') ? 'Hang the portrait' : 'The empty easel'),
      use: () => this.easelUse(),
    });
    this.sense(easel, { warm: () => !G.state.flag('mmfa_delivered') && G.state.has('lafleur_portrait'), height: 1.2 });
    if (G.state.flag('mmfa_delivered') && !G.state.flag('lever2_handled')) this.dropHandle();
    if (G.state.flag('three_stars_done')) this.dropPortrait(false);
  }
  async museumDoorUse() {
    const o = G.oreo, doorW = this.worldOf(this.museum, -3.6, 0, 0);
    if (!o.active || Math.hypot(o.pos.x - doorW.x, o.pos.z - doorW.z) > 12) {
      G.ui.say('TIREZ: pull. She pushes anyway. Nothing. Cats push; this door wants the other thing, and a mouth that can grip a rope.', { dur: 5 });
      return;
    }
    G.state.set('museum_door_open');
    await G.cine.run(async (c) => {
      c.look(doorW.clone().setY(1.6), { dist: 9, pitch: 26, yaw: 20 });
      await o.goTo(this.worldOf(this.museum, -4.2, 0, -0.8), 0.3, 6);
      o.mode = 'busy'; o.faceTo(doorW);
      o.bark();
      G.audio.sfx('wood_creak', { vol: 0.9, rate: 0.8 });
      this.doorSolid.enabled = false;
      await G.tween(this.museumDoor.rotation, { y: 1.7 }, 1.0, ease.out);
      await c.say('Oreo takes the rope handle and LEANS. The grand door swings wide, as doors do for those who can pull.', { dur: 4 });
      o.follow();
    });
  }
  easelUse() {
    if (G.state.flag('mmfa_delivered')) { G.ui.say('The Démon Blond hangs where he belongs, lit warm. The easel sign is gone; nothing is missing anymore.'); return; }
    if (!G.state.has('lafleur_portrait')) { G.ui.say('An empty easel under a small sign: pièce manquante. Something is missing, and the museum knows exactly what.'); return; }
    G.state.take('lafleur_portrait');
    G.state.set('mmfa_delivered');
    this.hangPortrait(false);
    this.museumLights();
    G.audio.sfx('chime', { vol: 0.8 });
    G.audio.sfx('crowd_cheer', { vol: 0.35, rate: 0.8 });
    G.audio.sfx('squirrel_chitter', { vol: 0.8, pos: this.gardenSquirrel.getWorldPosition(V3()) });
    G.ui.celebrate('Home, at last', 'The Fallen Star');
    G.ui.say('The portrait settles onto the easel and the whole museum lights up warm. On the steps, the sculpture-garden squirrel sets down something brass, with ceremony.', { dur: 6 });
    this.dropHandle();
  }
  hangPortrait(instant) {
    this.missingSign.visible = false;
    const p = new THREE.Group(); p.position.set(0, 1.3, -0.04); p.rotation.x = 0.16;
    const frame = P.box(1.0, 1.3, 0.08, '#cfae4c', { base: false }); p.add(frame);
    const canvas = new THREE.Mesh(new THREE.PlaneGeometry(0.84, 1.14), new THREE.MeshLambertMaterial({ map: this.portraitTex() })); canvas.position.z = 0.045; p.add(canvas);
    this.easel.add(p);
    if (!instant) { p.scale.setScalar(0.1); G.tween(p.scale, { x: 1, y: 1, z: 1 }, 0.5, ease.outBack); }
  }
  museumLights() { for (const m of this.museumGlow) { m.emissiveIntensity = 1.4; m.color.set('#ffe6b0'); } }
  dropHandle() {
    const h = new THREE.Group();
    const arm = P.cyl(0.035, 0.035, 0.7, '#d9b34a', { base: false }); arm.rotation.z = Math.PI / 2; arm.position.y = 0.06; h.add(arm);
    const knob = P.sphere(0.07, '#e8c24a'); knob.position.set(0.36, 0.06, 0); h.add(knob);
    this.pickup({ id: 'lever_handle', pos: this.worldOf(this.museum, -5.6, 0.0, 1.2), obj: h, bob: false, radius: 1.4 });
  }

  // ── The mountain ──────────────────────────────────────
  buildMountain() {
    const deco = new THREE.Group();
    // The boulder scramble: columns of granite, each a hop above the last.
    SCRAMBLE.forEach(([x, y, z], i) => {
      const ground = this.height(x, z) - 0.6, top = y + 1.0;
      const r = P.box(2.2, top - ground, 2.2, i % 2 ? STONE : GRANITE, { round: 0.25 }); r.position.set(x, ground, z); r.rotation.y = 0.3 * i; deco.add(r);
      const cap = P.rock(0.7, '#8c8a84', 40 + i, 0.5); cap.position.set(x + 0.4, top - 0.2, z - 0.3); deco.add(cap);
      this.solidBox(x, z, 2.2, 2.2, ground - 1, top, -0.3 * i);
    });
    const ledge = P.box(3.0, 0.4, 2.0, STONE); ledge.position.set(-13.6, 7.6, -20); deco.add(ledge);
    this.solidBox(-13.6, -20, 3.0, 2.0, 5, 8.0);
    // Granite outcrops shouldering out of the riser faces.
    for (const [x, z, r] of [[8, -5.5, 0.3], [-7.5, -6, -0.2], [10, -13, 0.5], [-8, -13.5, 0.1], [7, -24.5, -0.4], [-9, -25, 0.35], [9.5, -32.5, 0.2], [-7, -33, -0.3]]) {
      const h = this.height(x, z);
      const rock = P.box(2.6, 1.6, 1.8, GRANITE, { round: 0.3 }); rock.position.set(x, h - 1.0, z); rock.rotation.set(0, r, 0.12); deco.add(rock);
      const cap = P.rock(0.9, '#7c7c82', (x * 3) | 0, 0.6); cap.position.set(x + 0.4, h + 0.2, z + 0.2); deco.add(cap);
    }
    // A park lamp at every flight's foot, warm halos up the dark mountain.
    FLIGHTS.forEach((f, k) => this.lamp(deco, f.x + (k === 0 ? 3.0 : -1.9), f.y0, f.z + 1.4, 2.8));
    this.lamp(deco, CROSS.x + 4.8, CROSS.y, CROSS.z + 1.6, 2.8);
    this.add(P.bake(deco)); this.add(deco);
  }

  buildChalet() {
    const c = new THREE.Group(); c.position.copy(CHALET); this.add(c);
    const body = P.box(9, 3.6, 5, '#e4ddcf'); body.position.z = -2.5; c.add(body);
    const roof = prism(9.8, 5.8, 1.7, '#6b564c'); roof.position.set(0, 3.6, -2.5); c.add(roof);
    const winMat = this.glowMat('#ffd79a', 0.2, 1.2);
    for (const wx of [-3.2, -1.6, 1.6, 3.2]) {
      const w = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 1.6), winMat); w.position.set(wx, 1.9, 0.02); c.add(w);
      const arch = new THREE.Mesh(new THREE.CircleGeometry(0.45, 16, 0, Math.PI), winMat); arch.position.set(wx, 2.7, 0.02); c.add(arch);
    }
    const frame = P.box(1.3, 2.4, 0.16, WOOD); frame.position.z = 0.08; c.add(frame);
    const door = P.box(1.0, 2.2, 0.06, '#5a4030'); door.position.z = 0.17; c.add(door);
    const tally = new THREE.Mesh(new THREE.PlaneGeometry(0.3, 0.16), new THREE.MeshLambertMaterial({ transparent: true, map: canvasTex(96, 48, (g) => {
      g.strokeStyle = '#3b2a1e'; g.lineWidth = 4; g.lineCap = 'round';
      for (const ox of [8, 52]) { for (let i = 0; i < 4; i++) { g.beginPath(); g.moveTo(ox + i * 8, 8); g.lineTo(ox + i * 8, 40); g.stroke(); } g.beginPath(); g.moveTo(ox - 4, 36); g.lineTo(ox + 30, 12); g.stroke(); }
    }) }));
    tally.position.set(0.6, 0.62, 0.17); c.add(tally);
    this.solidBox(CHALET.x, CHALET.z - 2.5, 9, 5, CHALET.y - 2, CHALET.y + 5);
    // The belvedere balustrade, open where flight two arrives.
    const bal = new THREE.Group();
    for (const [x0, x1] of [[-6.5, 2.6], [5.4, 6.5]]) {
      for (let x = x0; x <= x1 + 0.01; x += 1.0) { const p = P.cyl(0.08, 0.1, 0.85, '#e4ddcf', { seg: 8 }); p.position.set(x, 0, 5.6); bal.add(p); }
      const rail = P.box(x1 - x0 + 0.2, 0.14, 0.24, '#e4ddcf'); rail.position.set((x0 + x1) / 2, 0.85, 5.6); bal.add(rail);
      this.solidBox(CHALET.x + (x0 + x1) / 2, CHALET.z + 5.6, x1 - x0 + 0.2, 0.3, CHALET.y - 1, CHALET.y + 1.0);
    }
    c.add(bal);
    const deco = new THREE.Group();
    this.bench(deco, CHALET.x - 1, CHALET.y, CHALET.z + 3.4, Math.PI);
    this.bench(deco, CHALET.x + 3.2, CHALET.y, CHALET.z + 3.4, Math.PI);
    this.lamp(deco, CHALET.x - 4.5, CHALET.y, CHALET.z + 4.6, 2.8);
    this.add(deco);
    // The doorframe: the Oreo artifact lives at dog-shoulder height.
    this.interact({
      pos: V3(CHALET.x + 0.5, CHALET.y, CHALET.z + 0.9), radius: 1.5, icon: '\u{1F440}', yRange: 1.5,
      enabled: () => !G.state.hasArtifact('chalet_tally'),
      label: 'Look at the doorframe',
      use: () => {
        const text = 'Scratched into the chalet’s doorframe at exactly dog-shoulder height: tally marks in sets of four with a diagonal fifth, like something counted the days. Fresh enough to still smell of pine.';
        G.ui.say(text, { dur: 6 });
        G.state.addArtifact('chalet_tally', 'montreal', 'Tallies on the Doorframe', text);
      },
    });
    this.sense(tally, { warm: () => !G.state.hasArtifact('chalet_tally'), height: 0.2 });
    // The balcony: from here the whole staircase reads at a glance.
    this.trigger({ pos: V3(CHALET.x, CHALET.y, CHALET.z + 3.8), y: CHALET.y, yr: 1.5, radius: 4.2, onEnter: () => this.belvedere() });
  }
  async belvedere() {
    if (G.state.flag('saw_zigzag') || G.state.flag('stairs_fixed') || G.cine.active) return;
    G.state.set('saw_zigzag');
    const wrong = this.turns.filter((t) => t !== 0).length;
    await G.cine.run(async (c) => {
      c.look(V3(0.5, 9, -19), { dist: 36, pitch: 64, yaw: 30, speed: 1.2 });
      await c.wait(1.2);
      for (let k = 0; k < FLIGHTS.length; k++) {
        const f = FLIGHTS[k], ok = this.turns[k] === 0;
        G.fx.ring(V3(f.x, f.y0 + 0.1, f.z), ok ? '#7bd88f' : '#ff6b4a', 1.6, 1.6);
        G.fx.sparkle(V3(f.x, f.y0 + 1, f.z - 1), ok ? '#bff3c8' : '#ffb39a', 10);
        await c.wait(0.35);
      }
      await c.say(`From the belvedere the whole staircase reads at a glance: one zigzag, all the way up, with ${wrong === 1 ? 'one flight' : `${['no', 'one', 'two', 'three', 'four'][wrong]} flights`} pointing off into nothing.`, { dur: 5 });
      await c.say('Every lever swings its own flight, and the next one up.', { dur: 3 });
    });
  }

  // ── The summit cross ──────────────────────────────────
  buildCross() {
    const g = new THREE.Group(); g.position.copy(CROSS); this.add(g); this.cross = g;
    g.add(P.box(0.6, 10, 0.6, IRON));
    const arms = P.box(6, 0.6, 0.6, IRON); arms.position.y = 7.2; g.add(arms);
    for (const sx of [-1, 1]) { const brace = P.box(0.12, 9.4, 0.12, '#4a4a50'); brace.position.set(sx * 0.36, 0.3, 0.36); g.add(brace); }
    this.solidBox(CROSS.x, CROSS.z, 0.8, 0.8, CROSS.y - 1, CROSS.y + 10);
    const base = P.box(2.4, 0.3, 2.4, GREYSTONE); base.position.y = -0.05; g.add(base);
    this.solidBox(CROSS.x, CROSS.z, 2.4, 2.4, CROSS.y - 1, CROSS.y + 0.25);
    const haloTex = canvasTex(64, 64, (c) => { const gr = c.createRadialGradient(32, 32, 2, 32, 32, 32); gr.addColorStop(0, 'rgba(255,230,160,1)'); gr.addColorStop(1, 'rgba(255,200,120,0)'); c.fillStyle = gr; c.fillRect(0, 0, 64, 64); });
    this.lanterns = LANTERNS.map((p, i) => {
      const l = new THREE.Group(); l.position.copy(p); g.add(l);
      for (const y of [-0.3, 0.3]) { const plate = P.box(0.5, 0.06, 0.36, '#2e2c2a', { base: false }); plate.position.y = y; l.add(plate); }
      const glassMat = new THREE.MeshLambertMaterial({ color: '#b6c0c8', transparent: true, opacity: 0.45, emissive: '#ffd890', emissiveIntensity: 0 });
      const glass = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.52, 0.32), glassMat);
      glass.visible = !BROKEN.includes(i) || G.state.flag('panes_fitted');
      l.add(glass);
      const bagel = P.torus(0.12, 0.05, '#d99a4d'); bagel.rotation.x = Math.PI / 2; bagel.position.y = -0.2; bagel.visible = G.state.flag('bagels_placed'); l.add(bagel);
      const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: haloTex, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0 }));
      halo.scale.set(1.6, 1.6, 1); l.add(halo);
      return { group: l, glass, bagel, halo };
    });
    if (G.state.flag('cross_lit')) for (const l of this.lanterns) this.lightLantern(l);
    this.interact({
      pos: V3(CROSS.x, CROSS.y, CROSS.z + 1.8), radius: 2.6, icon: '✝️', yRange: 2,
      label: () => {
        const s = G.state;
        if (!s.flag('panes_fitted')) return s.count('arena_pane') >= 3 ? 'Fit the arena panes' : 'The dark lanterns';
        if (!s.flag('bagels_placed')) return s.count('bagel') >= 12 ? 'Set twelve warm bagels' : 'Twelve cold lantern bases';
        if (!s.flag('cross_lit')) return 'The circling fireflies';
        return 'The lit cross';
      },
      use: () => this.crossUse(),
    });
    this.sense(g, { warm: () => (!G.state.flag('panes_fitted') && G.state.count('arena_pane') >= 3) || (G.state.flag('panes_fitted') && !G.state.flag('bagels_placed') && G.state.count('bagel') >= 12), height: 4, radius: 13 });

    // The summit drum, chalk on its rim: the finale's rhythm keeper.
    const d = new THREE.Group(); d.position.copy(DRUM); this.add(d); this.drum = d;
    d.add(P.cyl(0.5, 0.42, 0.7, WOOD));
    const head = P.cyl(0.5, 0.5, 0.04, '#e3d6bd'); head.position.y = 0.7; d.add(head);
    for (const [r, x, z] of [[0.14, 0, 0.22], [0.1, 0.24, -0.16], [0.06, -0.24, -0.16]]) { const mk = P.cyl(r, r, 0.012, '#fbfbf6'); mk.position.set(x, 0.74, z); d.add(mk); }
    for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2; const peg = P.box(0.05, 0.6, 0.05, '#c9b48a'); peg.position.set(Math.sin(a) * 0.47, 0.06, Math.cos(a) * 0.47); peg.rotation.y = a; d.add(peg); }
    this.solidCyl(DRUM.x, DRUM.z, 0.5, CROSS.y - 1, CROSS.y + 0.75);
    // The chalk pattern: big, small, big, medium — with rests left for an echo.
    const slate = P.sign([' '], { w: 1.3, h: 0.6, post: 0.5, color: '#4a3a2a', bg: '#2c3a33', border: '#6b5a40' });
    const chalk = canvasTex(256, 118, (g2) => {
      g2.fillStyle = '#2c3a33'; g2.fillRect(0, 0, 256, 118);
      g2.fillStyle = '#f4f4ec'; g2.strokeStyle = '#f4f4ec'; g2.lineWidth = 4;
      const sizes = [16, 7, 16, 11];
      sizes.forEach((r, i) => { const x = 22 + i * 58; g2.beginPath(); g2.arc(x, 56, r, 0, 7); g2.fill(); g2.beginPath(); g2.moveTo(x + 22, 56); g2.lineTo(x + 38, 56); g2.stroke(); });
      g2.font = 'italic 18px serif'; g2.textAlign = 'center'; g2.fillText('(rests are for the echo)', 128, 104);
    });
    slate.userData.face.material = new THREE.MeshLambertMaterial({ map: chalk });
    slate.position.set(DRUM.x + 1.1, DRUM.y, DRUM.z + 0.3); slate.rotation.y = -0.35; this.add(slate);
    this.interact({
      pos: DRUM, radius: 2.0, icon: '\u{1F941}', yRange: 2,
      label: () => (G.state.flag('cross_lit') ? null : 'The summit drum'),
      use: () => G.ui.say('An old drum, chalk on its rim: big, small, big, medium, with a rest after every beat. Rests left for an echo. Use the drum marks to play.', { dur: 5 }),
    });
    this.sense(d, { warm: () => this.swarming && !this.settled, height: 0.8 });
  }
  lightLantern(l) {
    l.glass.visible = true;
    l.glass.material.color.set('#ffc867'); l.glass.material.opacity = 0.95;
    l.glass.material.emissive.set('#ffa83a'); l.glass.material.emissiveIntensity = 1.3;
    l.halo.material.opacity = 1;
    l.halo.scale.set(2.2, 2.2, 1);
  }
  crossUse() {
    const s = G.state;
    if (!s.flag('panes_fitted')) {
      if (s.count('arena_pane') >= 3) {
        s.take('arena_pane', 3);
        s.set('panes_fitted');
        G.audio.sfx('chime', { vol: 0.8 });
        for (const i of BROKEN) { const l = this.lanterns[i]; l.glass.visible = true; l.glass.scale.setScalar(0.1); G.tween(l.glass.scale, { x: 1, y: 1, z: 1 }, 0.5, ease.outBack); }
        G.ui.say('Three panes of arena glass, exactly lantern-sized. Every lantern on the cross can hold light now. If light could be found.', { dur: 5 });
        return;
      }
      G.ui.say('A lattice of dark lanterns, twelve bases up the post and along the arms. Three have no glass at all. Nothing up here holds a light yet.', { dur: 5 });
      return;
    }
    if (!s.flag('bagels_placed')) {
      const n = s.count('bagel');
      if (n >= 12) { this.placeBagels(); return; }
      G.ui.say(n > 0 ? `Twelve bases; ${n} bagel${n === 1 ? '' : 's'}. The sign at the oven said à la douzaine, and this mountain counts.` : 'Twelve lantern bases, cold. Fireflies love warmth. Something on this mountain bakes it by the dozen.', { dur: 4.5 });
      return;
    }
    if (!s.flag('cross_lit')) { G.ui.say('The swarm circles and circles. They will not settle for warmth alone. Fireflies blink in rhythm, and the drum by the cross wears a chalk one, with rests left for an echo.', { dur: 5 }); return; }
    G.ui.say('The cross burns warm over the city. Its shadow points down the west slope: the funicular gate stands open.');
  }
  async placeBagels() {
    G.state.take('bagel', 12);
    G.state.set('bagels_placed');
    G.audio.sfx('oven_pop', { vol: 0.8, rate: 0.9 });
    this.lanterns.forEach((l, i) => { l.bagel.visible = true; l.bagel.scale.setScalar(0.01); G.wait(i * 0.08).then(() => G.tween(l.bagel.scale, { x: 1, y: 1, z: 1 }, 0.3, ease.outBack)); });
    await G.cine.run(async (c) => {
      c.look(CROSS.clone().add(V3(0, 5, 0)), { dist: 22, pitch: 16, yaw: 20, speed: 1 });
      this.setDusk(false);
      await c.say('Twelve warm bagels in twelve bases. The sky leans to dusk, the city lights come on below.', { dur: 4.5 });
      this.summonSwarm(false);
      await c.say('Up the slope, one blink. Then hundreds.', { dur: 3.5 });
    });
    G.ui.toast('The fireflies circle, but will not settle.', '✨');
  }

  // ── Fireflies, and the summit duet ────────────────────
  summonSwarm(quiet) {
    if (this.swarming) return;
    this.swarming = true;
    if (!quiet) G.audio.sfx('firefly_hum', { vol: 0.8 });
    const R = rng(909);
    const mat = new THREE.MeshBasicMaterial({ color: '#dcff8a' });
    this.flies = [];
    for (let i = 0; i < 48; i++) {
      const m = new THREE.Mesh(new THREE.SphereGeometry(0.07, 6, 5), mat);
      m.position.copy(CROSS).add(V3(R.range(-6, 6), R.range(-4, 2), R.range(-2, 12)));
      this.add(m);
      this.flies.push({ m, ph: R.range(0, Math.PI * 2), r: R.range(2.5, 5), h: R.range(1, 9), sp: R.range(0.5, 1.1), live: true });
    }
    this.swarmT = 0;
  }
  updateSwarm(dt) {
    if (!this.flies) return;
    this.swarmT += dt;
    for (const f of this.flies) {
      if (!f.live) continue;
      const ph = f.ph + this.swarmT * f.sp;
      _v.set(CROSS.x + Math.cos(ph) * f.r, CROSS.y + f.h + Math.sin(ph * 2.3) * 0.5, CROSS.z + Math.sin(ph) * f.r * 0.6 + 1.0);
      f.m.position.lerp(_v, 1 - Math.exp(-3 * dt));
      f.m.scale.setScalar(0.5 + 1.1 * Math.max(0, Math.sin(ph * 4 + f.ph)));
    }
  }
  drumHit(kind) {
    if (G.cine.active) return;
    G.audio.sfx(DRUM_SFX[kind], { vol: 1 });
    G.fx.ring(DRUM.clone().setY(DRUM.y + 0.75), '#fff3d0', kind === 'low' ? 1.0 : kind === 'mid' ? 0.75 : 0.5, 0.5);
    G.animate(0.2, (t) => { this.drum.scale.y = 1 - Math.sin(t * Math.PI) * 0.08; });
    G.player.emote('attack', 1.8);
    if (this.settled || G.state.flag('cross_lit')) return;
    if (!this.swarming) { G.ui.toast('The drum booms over an empty summit. Warmth first; the fireflies are not here yet.', '\u{1F941}'); return; }
    const o = G.oreo;
    if (!o.active || Math.hypot(o.pos.x - DRUM.x, o.pos.z - DRUM.z) > 10) { G.ui.toast('The chalk leaves a rest after every beat, for an echo. The duet needs its other half.', '\u{1F415}'); return; }
    // Oreo barks the echo: the duet's other half.
    setTimeout(() => { if (G.island === this) { o.faceTo(DRUM); o.bark(); } }, 450);
    const gap = G.time - this.lastHit;
    this.lastHit = G.time;
    if (this.progress > 0 && (gap < 0.7 || gap > 1.8)) this.progress = 0;
    if (kind === PATTERN[this.progress]) {
      this.progress++;
      for (const f of this.flies) f.r = Math.max(1.2, f.r * 0.82);
      G.ui.showBanner(this.progress ? `\u{1F941} Beat ${this.progress} of ${PATTERN.length}` : '\u{1F941} Lost the beat. Start again!', 1.2);
      if (this.progress >= PATTERN.length) this.settle();
    } else {
      this.progress = kind === PATTERN[0] ? 1 : 0;
      for (const f of this.flies) f.r = Math.min(5.5, f.r * 1.25);
      G.ui.showBanner(this.progress ? `\u{1F941} Beat ${this.progress} of ${PATTERN.length}` : '\u{1F941} Lost the beat. Start again!', 1.2);
    }
  }
  async settle() {
    this.settled = true;
    G.state.set('cross_lit');
    this.drumBar.style.display = 'none';
    await G.cine.run(async (c) => {
      c.look(CROSS.clone().add(V3(0, 5, 0)), { dist: 20, pitch: 14, yaw: 15, speed: 1.2 });
      G.audio.sfx('firefly_hum', { vol: 1, rate: 1.2 });
      await c.wait(0.6);
      for (let i = 0; i < LIGHT_ORDER.length; i++) {
        const l = this.lanterns[LIGHT_ORDER[i]];
        const at = l.group.getWorldPosition(V3());
        for (let k = 0; k < 4; k++) {
          const f = this.flies[i * 4 + k];
          if (!f) continue;
          f.live = false;
          G.tween(f.m.position, { x: at.x, y: at.y, z: at.z }, 0.5, ease.in).then(() => f.m.removeFromParent());
        }
        await c.wait(0.5);
        this.lightLantern(l);
        G.audio.sfx('chime', { vol: 0.5, rate: 0.8 + i * 0.05 });
      }
      await c.wait(0.6);
      this.swarming = false;
      this.openGate(false);
      await c.say('Tier by tier the swarm pours in and the CROSS LIGHTS, a slow vertical sunrise over the whole city.', { dur: 4.5 });
      c.look(FUNI[0].clone().setY(16), { dist: 14, pitch: 30, yaw: 40, speed: 1.2 });
      await c.say('Its shadow falls down the west slope onto the old funicular’s gate.', { dur: 3.5 });
    });
    G.ui.celebrate('The cross is lit!', 'Light the Cross');
  }

  buildDrumBar() {
    const bar = document.createElement('div');
    bar.style.cssText = 'position:absolute;left:50%;transform:translateX(-50%);bottom:calc(env(safe-area-inset-bottom,0px) + 168px);display:none;gap:16px;align-items:center;';
    for (const [k, size, dot] of [['low', 76, 30], ['high', 56, 12], ['mid', 64, 20]]) {
      const b = document.createElement('button');
      b.className = 'cbtn';
      b.setAttribute('aria-label', `Drum ${k}`);
      b.style.cssText = `position:relative;width:${size}px;height:${size}px;background:#e9dcc0;`;
      b.innerHTML = `<span style="display:block;width:${dot}px;height:${dot}px;border-radius:50%;background:#173b44"></span>`;
      b.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); G.audio.unlock(); this.drumHit(k); });
      bar.append(b);
    }
    G.ui.controls.append(bar);
    this.drumBar = bar;
  }
  updateDrumBar() {
    const p = G.player.pos;
    const near = !G.state.flag('cross_lit') && !G.cine.active && Math.abs(p.y - DRUM.y) < 1.5 && Math.hypot(p.x - DRUM.x, p.z - DRUM.z) < 3.4;
    const want = near ? 'flex' : 'none';
    if (this.drumBar.style.display !== want) {
      this.drumBar.style.display = want;
      if (near && !this.drumTold) { this.drumTold = true; G.ui.toast('Strike the drum’s chalk marks: big, small, big, medium.', '\u{1F941}'); }
    }
  }

  // ── The funicular ─────────────────────────────────────
  buildFunicular() {
    const st = new THREE.Group(); st.position.set(-11.4, 15, -40.4); this.add(st);
    st.add(P.box(2.4, 2.4, 3, '#806b56'));
    const roof = P.box(2.8, 0.4, 3.4, '#5c4d42'); roof.position.y = 2.4; st.add(roof);
    this.solidBox(-11.4, -40.4, 2.4, 3, 13, 18);
    // The gate: iron, shut until the cross's shadow finds it.
    const hinge = new THREE.Group(); hinge.position.set(-7.6, 15, -36.4); this.add(hinge);
    for (let i = 0; i < 6; i++) { const bar = P.box(0.06, 1.6, 0.06, IRON); bar.position.set(0, 0, -i * 0.26); hinge.add(bar); }
    for (const y of [0.2, 1.5]) { const r = P.box(0.08, 0.08, 1.4, IRON); r.position.set(0, y, -0.65); hinge.add(r); }
    this.gate = hinge;
    if (G.state.flag('cross_lit')) this.openGate(true);
    // Rails down the west flank, on trestles where they leave the ground.
    const rails = new THREE.Group();
    const up = V3(0, 1, 0);
    for (let i = 0; i < FUNI.length - 1; i++) {
      const a = FUNI[i], b = FUNI[i + 1];
      const dir = V3().subVectors(b, a); const len = dir.length(); dir.normalize();
      const side = V3(dir.z, 0, -dir.x).normalize();
      for (const s of [-0.5, 0.5]) {
        const r = P.cyl(0.05, 0.05, len, IRON, { base: false, seg: 6 });
        r.position.copy(a).add(b).multiplyScalar(0.5).addScaledVector(side, s); r.position.y += 0.05;
        r.quaternion.setFromUnitVectors(up, dir);
        rails.add(r);
      }
      for (let t = 0; t < len; t += 2.4) {
        const p = V3().copy(a).addScaledVector(dir, t);
        const gy = this.height(p.x, p.z);
        if (p.y - gy > 0.35) { const post = P.box(0.16, p.y - gy + 0.2, 0.16, WOOD); post.position.set(p.x, gy - 0.2, p.z); rails.add(post); }
        const tie = P.box(1.3, 0.06, 0.16, WOOD); tie.position.copy(p); tie.quaternion.setFromUnitVectors(V3(0, 0, 1), V3(dir.x, 0, dir.z).normalize()); rails.add(tie);
      }
    }
    this.add(P.bake(rails)); this.add(rails);
    // The car, waiting at the top.
    const car = new THREE.Group(); car.position.copy(FUNI[0]); this.add(car); this.car = car;
    const floor = P.box(1.6, 0.2, 2.4, WOOD); floor.position.y = 0.2; car.add(floor);
    for (const sx of [-0.75, 0.75]) { const w = P.box(0.1, 1.0, 2.4, '#9e3a2e'); w.position.set(sx, 0.4, 0); car.add(w); }
    const back = P.box(1.6, 1.0, 0.1, '#9e3a2e'); back.position.set(0, 0.4, -1.15); car.add(back);
    const top = P.box(1.8, 0.1, 2.6, '#5c4d42'); top.position.y = 1.9; car.add(top);
    for (const [sx, sz] of [[-0.8, 1.2], [0.8, 1.2], [-0.8, -1.2], [0.8, -1.2]]) { const p = P.box(0.08, 1.5, 0.08, '#5c4d42'); p.position.set(sx, 0.4, sz); car.add(p); }
    const seat = P.box(1.4, 0.36, 0.5, WOOD_PALE); seat.position.set(0, 0.4, -0.7); car.add(seat);
    this.aimCar(0);
    this.carSolid = this.solidBox(FUNI[0].x, FUNI[0].z, 1.8, 2.6, CROSS.y - 1, CROSS.y + 0.4);
    this.interact({
      obj: car, radius: 2.4, icon: '\u{1F6A1}', yRange: 2,
      label: () => (G.state.flag('island5_complete') ? 'The funicular' : G.state.flag('cross_lit') ? 'Board the funicular' : 'The old funicular'),
      use: () => this.board(),
    });
  }
  aimCar(u) {
    const n = FUNI.length - 1, f = clamp(u, 0, 1) * n, i = Math.min(n - 1, Math.floor(f));
    const a = FUNI[i], b = FUNI[i + 1];
    this.car.position.copy(a).lerp(b, f - i);
    const nx = FUNI[Math.min(i + 2, n)];
    const dx = nx.x - this.car.position.x, dz = nx.z - this.car.position.z;
    this.car.rotation.y = Math.atan2(dx, dz);
    return { x: dx, z: dz };
  }
  openGate(instant) {
    if (instant) { this.gate.rotation.y = 1.5; return; }
    G.audio.sfx('gate_open', { vol: 0.8 });
    G.tween(this.gate.rotation, { y: 1.5 }, 1.0, ease.outBounce);
  }
  board() {
    if (this.riding) return;
    if (!G.state.flag('cross_lit')) { G.ui.say('The old funicular waits behind a shut gate. Nothing has told it to move in a hundred years.'); return; }
    if (G.state.flag('island5_complete')) { G.ui.say('The car rides at the summit again, patient as the mountain. She has taken this ride; the fragment is hers.'); return; }
    this.ride();
  }
  async ride() {
    this.riding = true;
    this.carSolid.enabled = false;
    const o = G.oreo;
    await G.cine.run(async (c) => {
      G.audio.sfx('funicular_bell', { vol: 0.9 });
      if (o.active) o.mode = 'busy';
      const seat = (u) => {
        const dir = this.aimCar(u);
        this.car.updateWorldMatrix(true, false);
        const p = this.car.localToWorld(V3(-0.35, 0.3, 0.1));
        G.player.pos.copy(p); G.player.velocity.set(0, 0, 0); G.player.yaw = this.car.rotation.y;
        if (o.active) { const q = this.car.localToWorld(V3(0.35, 0.3, -0.3)); o.pos.copy(q); o.yaw = this.car.rotation.y; }
        const yaw = Math.atan2(-dir.x, -dir.z) * 180 / Math.PI;
        c.look(this.car.position.clone().add(V3(0, 1, 0)), { dist: 13, pitch: 30, yaw, speed: 3 });
      };
      seat(0);
      await c.wait(0.8);
      await G.animate(12, seat, ease.inOut);
      G.audio.sfx('funicular_bell', { vol: 0.9, rate: 0.95 });
      await c.wait(0.6);
      await c.say('At the bottom, tucked under the funicular’s bench, folded small, in a hand that pressed too hard on the pencil.', { dur: 4.5 });
      const end = FUNI[FUNI.length - 1];
      G.player.teleport(end.x + 2.2, end.z + 0.4, Math.PI / 2);
      if (o.active) { o.teleport(end.x + 3.2, end.z + 1.2); o.follow(); }
    });
    this.riding = false;
    await G.game.finishIsland();
  }

  // ── Trees, horizon, the falling leaves ────────────────
  mapleFits(x, z) {
    if (z > WALL_Z - 1) return false;
    if (Math.abs(x) < 5.5 && z > -36.5) return false;
    if (x < -11.5 && x > -19.5 && z > -22 && z < -3) return false;
    if (Math.hypot(x - CHALET.x, z - CHALET.z) < 8.5) return false;
    if (Math.hypot(x - CROSS.x, z - CROSS.z) < 7) return false;
    if (Math.hypot(x - 21, z + 7.5) < 3.5) return false;
    for (const f of FLIGHTS) if (Math.hypot(x - f.x, z - f.z) < f.run + 1.4) return false;
    for (let i = 0; i < FUNI.length - 1; i++) {
      const a = FUNI[i], b = FUNI[i + 1];
      const abx = b.x - a.x, abz = b.z - a.z, t = clamp(((x - a.x) * abx + (z - a.z) * abz) / (abx * abx + abz * abz), 0, 1);
      if (Math.hypot(x - (a.x + abx * t), z - (a.z + abz * t)) < 3) return false;
    }
    if (Math.abs(x) < 16 && z < -3) {
      if (Math.abs(x) > 11.8) return false;               // the steep flanks
      for (const [z0, z1] of TERRACES) if (z < z0 + 0.6 && z > z1 - 0.6) return false;
    }
    return true;
  }
  buildTrees() {
    const deco = new THREE.Group();
    const R = rng(505);
    let placed = 0;
    for (let tries = 0; placed < 46 && tries < 500; tries++) {
      const x = R.range(-38, 38), z = R.range(-44, -2.5);
      if (!this.mapleFits(x, z)) continue;
      const h = this.height(x, z);
      if (h < 0.3) continue;
      this.maple(deco, x, h, z, R, R.range(0.85, 1.1));
      this.solidCyl(x, z, 0.28, h - 1, h + 2.4);
      placed++;
    }
    // Birches among the maples: white bark, sparse gold crowns.
    const B = rng(606);
    placed = 0;
    for (let tries = 0; placed < 14 && tries < 300; tries++) {
      const x = B.range(-36, 36), z = B.range(-42, -2.5);
      if (!this.mapleFits(x, z)) continue;
      const h = this.height(x, z);
      if (h < 0.3) continue;
      const t = P.cyl(0.08, 0.12, 2.8, '#ece8e0'); t.position.set(x, h - 0.1, z); deco.add(t);
      for (let k = 0; k < 3; k++) { const band = P.box(0.18, 0.08, 0.04, '#2a2a2a'); band.position.set(x, h + 0.6 + k * 0.7, z + 0.1); deco.add(band); }
      const crown = P.sphere(1.0, '#e5bf4c', { seg: 10 }); crown.scale.y = 1.1; crown.position.set(x, h + 3.4, z); deco.add(crown);
      this.solidCyl(x, z, 0.15, h - 1, h + 2.4);
      placed++;
    }
    this.add(P.bake(deco)); this.add(deco);
  }
  buildHorizon() {
    const deco = new THREE.Group();
    // Habitat 67: stacked, offset concrete boxes across the river.
    const R = rng(67);
    for (let i = 0; i < 16; i++) {
      const b = P.box(1.8, 1.1, 2.2, '#d3cdc2'); b.position.set(36 + R.range(-4.5, 4.5), -0.4 + (i % 4) * 1.15 + R.range(0, 0.4), 47 + R.range(-2.2, 2.2)); b.rotation.y = -0.4 + R.range(-0.15, 0.15); deco.add(b);
    }
    // The Biosphère: a pale lattice dome on the west shallows.
    const dome = new THREE.Mesh(new THREE.SphereGeometry(4.2, 12, 8), new THREE.MeshLambertMaterial({ color: '#dbe6ee', transparent: true, opacity: 0.4, depthWrite: false }));
    dome.position.set(-37, 2.1, 45); this.add(dome);
    for (let k = 0; k < 3; k++) { const ring = P.torus(4.06 - k * 0.9, 0.06, '#b3bcc4'); ring.rotation.x = Math.PI / 2; ring.position.set(-37, 2.1 + k * 1.4, 45); deco.add(ring); }
    // The Big O: the leaning tower over its bowl, far north-east.
    const bowl = P.cyl(5, 6, 2.2, '#c9c5bd'); bowl.position.set(47, -1.2, -27); deco.add(bowl);
    const tw = P.cyl(0.7, 1.3, 11, '#dad6cf', { base: false }); tw.position.set(44.2, 4.6, -27); tw.rotation.z = 0.55; deco.add(tw);
    const obs = P.box(2.0, 0.9, 1.4, '#b8bcc0', { base: false }); obs.position.set(41.4, 9.4, -27); deco.add(obs);
    this.add(P.bake(deco)); this.add(deco);
  }
  buildLeaves() {
    const N = 240;
    const pos = new Float32Array(N * 3), col = new Float32Array(N * 3);
    const R = rng(77);
    const cols = ['#e2572b', '#f08a24', '#e9b23a', '#c0391f'].map((c) => new THREE.Color(c));
    this.leafData = [];
    for (let i = 0; i < N; i++) {
      pos[i * 3] = SPAWN.x + R.range(-22, 22); pos[i * 3 + 1] = R.range(-2, 12); pos[i * 3 + 2] = SPAWN.z + R.range(-22, 22);
      const c = cols[i % 4]; col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
      this.leafData.push({ ph: R.range(0, 6.28), sp: R.range(0.5, 1.0) });
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
    const tex = canvasTex(32, 32, (g) => {
      g.fillStyle = '#fff'; g.beginPath();
      for (let k = 0; k < 10; k++) { const a = k / 10 * Math.PI * 2 - Math.PI / 2, r = k % 2 ? 6 : 14; g.lineTo(16 + Math.cos(a) * r, 16 + Math.sin(a) * r); }
      g.closePath(); g.fill();
    });
    this.leaves = new THREE.Points(geo, new THREE.PointsMaterial({ size: 0.26, map: tex, vertexColors: true, transparent: true, depthWrite: false, alphaTest: 0.3 }));
    this.leaves.frustumCulled = false;
    this.add(this.leaves);
  }
  updateLeaves(dt) {
    const p = G.player.pos, a = this.leaves.geometry.attributes.position, arr = a.array;
    for (let i = 0; i < this.leafData.length; i++) {
      const d = this.leafData[i], j = i * 3;
      arr[j] += (0.35 + Math.sin(G.time * 0.8 + d.ph) * 0.5) * dt;
      arr[j + 1] -= d.sp * 0.9 * dt;
      arr[j + 2] += (0.12 + Math.cos(G.time * 0.6 + d.ph) * 0.3) * dt;
      if (arr[j + 1] < p.y - 3) { arr[j + 1] = p.y + 10 + Math.random() * 4; arr[j] = p.x + (Math.random() - 0.5) * 44; arr[j + 2] = p.z + (Math.random() - 0.5) * 44; }
      if (arr[j] - p.x > 22) arr[j] -= 44; else if (p.x - arr[j] > 22) arr[j] += 44;
      if (arr[j + 2] - p.z > 22) arr[j + 2] -= 44; else if (p.z - arr[j + 2] > 22) arr[j + 2] += 44;
    }
    a.needsUpdate = true;
  }

  // ── The calèche horse: growl teacher ──────────────────
  buildHorse() {
    const g = new THREE.Group(); g.position.copy(HORSE); g.rotation.y = Math.PI / 2; this.add(g); this.horse = g;
    const horse = model('horse', { height: 2.0 }); horse.position.z = -0.2; g.add(horse);
    const gltf = horse.userData.gltf, inner = horse.userData.inner;
    if (gltf?.animations?.length && inner) {
      this.horseMixer = new THREE.AnimationMixer(inner);
      this.horseClips = {};
      for (const c of gltf.animations) this.horseClips[c.name.split('|').pop()] = c;
    }
    // The calèche behind: a black carriage with two big wheels.
    const cart = new THREE.Group(); cart.position.z = -2.6; g.add(cart);
    const body = P.box(1.4, 0.9, 1.8, '#1e1e21', { round: 0.08 }); body.position.y = 0.55; cart.add(body);
    const seat = P.box(1.3, 0.3, 0.5, '#7a2c2c'); seat.position.set(0, 1.45, 0.5); cart.add(seat);
    const canopy = P.box(1.5, 0.08, 1.2, '#1e1e21'); canopy.position.set(0, 2.1, -0.3); cart.add(canopy);
    for (const [sx, sz] of [[-0.7, -0.85], [0.7, -0.85], [-0.7, 0.25], [0.7, 0.25]]) { const p = P.box(0.04, 0.7, 0.04, '#1e1e21'); p.position.set(sx, 1.45, sz); cart.add(p); }
    for (const sx of [-0.8, 0.8]) {
      const wheel = P.torus(0.5, 0.05, '#8a6038', { seg: 20 }); wheel.rotation.y = Math.PI / 2; wheel.position.set(sx, 0.55, 0.2); cart.add(wheel);
      const hub = P.cyl(0.08, 0.08, 0.12, '#5a4030', { base: false }); hub.rotation.z = Math.PI / 2; hub.position.set(sx, 0.55, 0.2); cart.add(hub);
      for (let k = 0; k < 4; k++) { const sp = P.box(0.03, 0.95, 0.03, '#8a6038', { base: false }); sp.position.set(sx, 0.55, 0.2); sp.rotation.x = k * Math.PI / 4; cart.add(sp); }
    }
    for (const sx of [-0.35, 0.35]) { const sh = P.cyl(0.03, 0.03, 2.2, '#6a4a30', { base: false }); sh.rotation.x = Math.PI / 2; sh.position.set(sx, 1.0, 1.4); cart.add(sh); }
    this.horseSolids = [
      { s: this.solidBox(HORSE.x + 0.4, HORSE.z, 3.4, 1.2, -1, PLAIN + 2.8), dx: 0.4 },
      { s: this.solidBox(HORSE.x - 2.6, HORSE.z, 2.2, 1.9, -1, PLAIN + 2.6), dx: -2.6 },
    ];
    if (G.state.flag('horse_moved')) { g.position.x += 5.5; this.syncHorse(); this.playHorse('Idle_Eating'); }
    else this.playHorse('Idle');
    this.interact({
      obj: g, radius: 3.2, icon: '\u{1F434}',
      label: () => {
        if (G.state.flag('horse_moved')) return null;
        if (!G.state.knows('growl') && this.demonstrated) return 'Square up and bark';
        return 'The calèche horse';
      },
      use: () => {
        if (!G.state.knows('growl') && this.demonstrated) { this.learnGrowl(); return; }
        if (G.state.knows('growl')) { G.ui.say('It stands across the road, enormous and unbothered. Big things listen to something big.'); return; }
        G.ui.say('A big calèche horse, blinkered, asleep on its feet across the only road up the mountain. Say something to it?');
      },
    });
    this.sense(g, { warm: () => !G.state.flag('horse_moved'), height: 1.8 });
    this.onVocal((e) => {
      if (G.state.flag('horse_moved') || G.cine.active) return;
      if (Math.hypot(e.pos.x - this.horse.position.x, e.pos.z - this.horse.position.z) > 9) return;
      if (e.kind === 'growl') { this.horseMovesCine(); return; }
      this.tries++;
      if (e.kind === 'meow') G.ui.toast('The horse does not so much as flick an ear.', '\u{1F434}');
      else if (e.kind === 'hiss') {
        G.audio.sfx('horse_snort', { vol: 0.8, rate: 0.9 });
        this.playHorse('Headbutt', { once: true });
        G.ui.toast('One ear flicks, the head tosses. The hooves plant harder. It is not going anywhere for a hiss.', '\u{1F434}');
      }
      if (this.tries >= 2 && !this.demonstrated) { this.demonstrated = true; G.wait(1.6).then(() => this.oreoDemonstrates()); }
    });
  }
  syncHorse() { for (const h of this.horseSolids) { h.s.x = this.horse.position.x + h.dx; h.s.z = this.horse.position.z; } }
  playHorse(name, { once = false, then = 'Idle' } = {}) {
    const clip = this.horseClips?.[name];
    if (!clip) return;
    const a = this.horseMixer.clipAction(clip);
    a.reset();
    a.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat, Infinity);
    a.clampWhenFinished = once;
    a.fadeIn(0.3).play();
    if (this.horseAction && this.horseAction !== a) this.horseAction.fadeOut(0.3);
    this.horseAction = a;
    if (once) G.wait(clip.duration + 0.05).then(() => { if (this.horseAction === a) this.playHorse(then); });
  }
  async oreoDemonstrates() {
    const o = G.oreo;
    if (!o.active || G.state.flag('horse_moved')) {
      this.demonstrated = false; this.tries = 0;
      G.ui.toast('Nothing she says moves it. Somebody with a bigger voice might.', '\u{1F434}');
      return;
    }
    await G.cine.run(async (c) => {
      c.look(this.horse.position.clone().setY(1.2), { dist: 9, pitch: 28, yaw: 25 });
      o.mode = 'busy'; o.faceTo(this.horse.position);
      await c.wait(0.6);
      o.bark();
      G.audio.sfx('horse_snort', { vol: 0.9, rate: 1.1 });
      this.playHorse('Walk');
      await G.tween(this.horse.position, { z: HORSE.z - 0.45 }, 0.7, ease.inOut, () => this.syncHorse());
      this.playHorse('Idle');
      await c.say('Oreo BARKS. The horse snorts and backs one whole step. That voice has weight.', { dur: 3.4 });
      await c.say('Khione squares up. Maybe she can bark too.', { dur: 2.6 });
      o.follow();
    });
    G.ui.toast('Tap the horse: square up and bark.', '\u{1F434}');
  }
  async learnGrowl() {
    await G.cine.run(async (c) => {
      c.look(this.horse.position.clone().setY(1.2).lerp(G.player.pos, 0.4), { dist: 8, pitch: 28, yaw: 30 });
      G.player.faceTo(this.horse.position);
      await c.say('She plants her paws, fills her small chest, and tries to bark the way he does.', { dur: 2.8 });
      G.audio.sfx('growl', { vol: 1 });
      G.fx.ripple(G.player.pos.clone(), '#9a7bff', 5);
      G.rig.shake = 0.7;
      G.player.emote('attack', 1.0);
      await c.wait(0.8);
      await c.say('What comes out is not a bark. It is a GROWL, low and true.', { dur: 3 });
      G.state.learn('growl');
      await this.horseMoves(c);
    });
    G.ui.celebrate('Learned: Growl!', 'Growl is command. Big things listen.');
    G.ui.toast('Tap \u{1F42F} Growl. Big things listen.', '\u{1F42F}');
  }
  async horseMovesCine() {
    await G.cine.run(async (c) => {
      c.look(this.horse.position.clone().setY(1.2), { dist: 10, pitch: 28, yaw: 30 });
      await this.horseMoves(c);
    });
  }
  async horseMoves(c) {
    if (G.state.flag('horse_moved')) return;
    G.state.set('horse_moved');
    G.audio.sfx('horse_snort', { vol: 0.9, rate: 0.8 });
    this.playHorse('Walk');
    const x0 = this.horse.position.x;
    c.say('The horse regards her for a long moment. Then it steps aside, with enormous dignity.', { dur: 4 });
    await G.animate(2.6, (t) => { this.horse.position.x = x0 + 5.5 * t; this.syncHorse(); }, ease.inOut);
    this.playHorse('Idle_Eating');
    await c.wait(1.4);
  }

  // ── The Bagel Standard ────────────────────────────────
  buildOven() {
    const shop = new THREE.Group(); shop.position.copy(OVEN); this.add(shop);
    const brick = P.box(4.6, 3.0, 4.0, '#9b5a46'); brick.position.z = -2.6; shop.add(brick);
    const awn = P.box(4.8, 0.12, 1.0, '#2f6a4a'); awn.position.set(0, 2.5, -0.15); awn.rotation.x = 0.25; shop.add(awn);
    const oven = P.box(1.6, 1.4, 1.2, '#5a524c', { round: 0.1 }); oven.position.z = -0.2; shop.add(oven);
    const mouthMat = this.glowMat('#ff8a2a', 1.2, 1.6);
    const mouth = new THREE.Mesh(new THREE.CircleGeometry(0.4, 18, 0, Math.PI), mouthMat); mouth.position.set(0, 0.55, 0.41); shop.add(mouth);
    const sign = P.sign('12 à la douzaine', { w: 2.4, h: 0.6, bg: '#f2e6cf', fg: '#5a3a28', border: '#5a3a28', color: '#5a3a28', font: 'bold 52px "Baloo 2", sans-serif' });
    sign.position.set(0, 3.0, -0.55); shop.add(sign);
    const peel = P.box(0.5, 0.03, 1.4, '#b39467'); peel.position.set(0, 0.98, 0.9); shop.add(peel);
    this.bagelMat = new THREE.MeshLambertMaterial({ color: '#ebd9b3' });
    this.bagel = new THREE.Mesh(new THREE.TorusGeometry(0.15, 0.06, 10, 22), this.bagelMat);
    this.bagel.rotation.x = Math.PI / 2; this.bagel.position.set(OVEN.x, OVEN.y + 1.07, OVEN.z + 0.55); this.bagel.visible = false; this.add(this.bagel);
    // A doneness gauge floats over the peel while one bakes.
    const mc = document.createElement('canvas'); mc.width = 256; mc.height = 40;
    this.meterCanvas = mc;
    this.meterTex = new THREE.CanvasTexture(mc); this.meterTex.colorSpace = THREE.SRGBColorSpace;
    this.meter = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.meterTex, depthTest: false, transparent: true }));
    this.meter.scale.set(1.8, 0.28, 1); this.meter.position.set(OVEN.x, OVEN.y + 2.2, OVEN.z + 0.8); this.meter.renderOrder = 9; this.meter.visible = false; this.add(this.meter);
    this.solidBox(OVEN.x, OVEN.z - 2.6, 4.6, 4.0, -1, OVEN.y + 3.2);
    this.solidBox(OVEN.x, OVEN.z - 0.2, 1.6, 1.2, -1, OVEN.y + 1.4);
    this.interact({
      pos: V3(OVEN.x, OVEN.y, OVEN.z + 1.3), radius: 2.2, icon: '\u{1F96F}',
      label: () => (this.baking ? 'PULL the bagel!' : 'Bake a bagel'),
      use: () => this.ovenUse(),
    });
    this.sense(shop, { warm: () => G.state.flag('panes_fitted') && !G.state.flag('bagels_placed') && G.state.count('bagel') < 12, height: 2 });
  }
  ovenUse() {
    if (!this.baking) {
      this.baking = true; this.bakeT = 0;
      this.bagel.visible = true; this.meter.visible = true;
      G.audio.sfx('wood_creak', { vol: 0.3, rate: 1.4 });
      if (!G.state.flag('bagel_taught')) {
        G.state.set('bagel_taught');
        G.ui.say('A bagel goes onto the peel and into the heat. Pale, golden, black: pull it in the golden second.', { dur: 4 });
      }
      return;
    }
    if (this.bakeT >= GOLD_A && this.bakeT <= GOLD_B) {
      this.baking = false; this.bagel.visible = false; this.meter.visible = false;
      G.audio.sfx('oven_pop', { vol: 0.8 });
      if (!G.state.give('bagel')) return;
      const n = G.state.count('bagel');
      G.fx.sparkle(this.bagel.position.clone(), '#ffd27a', 8);
      if (n === 12) G.ui.say('Twelve! A dozen, exactly as the sign spells it. Squirrels count. So does the mountain.', { dur: 4 });
      else G.ui.showBanner(`Golden. That is ${n}.`, 1.4);
    } else this.burn();
  }
  burn() {
    this.baking = false; this.bagel.visible = false; this.meter.visible = false;
    G.audio.sfx('fail', { vol: 0.5, rate: 0.9 });
    G.fx.burst(this.bagel.position.clone(), { color: ['#555', '#777', '#999'], count: 14, speed: 1, up: 1.4, size: 0.3, life: 1.2, gravity: -0.6 });
    this.burns = (this.burns ?? 0) + 1;
    if (this.burns <= 2) G.ui.say('Smoke. Too early is dough; too late is charcoal. The golden second is short.', { dur: 3 });
    else G.ui.toast('Smoke. Watch for the gold.', '\u{1F525}');
  }
  updateOven(dt) {
    if (!this.baking) return;
    this.bakeT += dt;
    const t = this.bakeT;
    const pale = _v.set(0.92, 0.85, 0.7), gold = _t.set(0.85, 0.6, 0.3);
    if (t < GOLD_A) this.bagelMat.color.setRGB(lerp(pale.x, gold.x, t / GOLD_A), lerp(pale.y, gold.y, t / GOLD_A), lerp(pale.z, gold.z, t / GOLD_A));
    else if (t < GOLD_B) this.bagelMat.color.setRGB(gold.x, gold.y, gold.z);
    else { const k = (t - GOLD_B) / (CYCLE - GOLD_B); this.bagelMat.color.setRGB(lerp(gold.x, 0.12, k), lerp(gold.y, 0.1, k), lerp(gold.z, 0.09, k)); }
    const g = this.meterCanvas.getContext('2d');
    const grad = g.createLinearGradient(0, 0, 256, 0);
    grad.addColorStop(0, '#ecd9b3'); grad.addColorStop(GOLD_A / CYCLE, '#d99a4d'); grad.addColorStop(GOLD_B / CYCLE, '#d99a4d'); grad.addColorStop(1, '#1f1a17');
    g.clearRect(0, 0, 256, 40);
    g.fillStyle = grad; g.fillRect(4, 8, 248, 24);
    g.strokeStyle = '#ffe9a0'; g.lineWidth = 4; g.strokeRect(4 + 248 * GOLD_A / CYCLE, 6, 248 * (GOLD_B - GOLD_A) / CYCLE, 28);
    g.fillStyle = '#173b44'; g.fillRect(4 + 248 * clamp(t / CYCLE, 0, 1) - 3, 0, 6, 40);
    this.meterTex.needsUpdate = true;
    if (t >= CYCLE) this.burn();
  }

  // ── The Staircase Shuffle ─────────────────────────────
  buildStairs() {
    if (G.state.flag('stairs_fixed')) this.turns = [0, 0, 0, 0];
    this.flights = FLIGHTS.map((f, k) => {
      const g = new THREE.Group(); g.position.set(f.x, f.y0, f.z); g.rotation.y = -this.turns[k] * Math.PI / 2; this.add(g);
      const rise = f.y1 - f.y0, n = 12;
      for (let i = 0; i < n; i++) {
        const top = rise * (i + 1) / n;
        const st = P.box(FLIGHT_W, top + 0.3, f.run / n + 0.02, i % 2 ? '#a19c93' : '#958f86'); st.position.set(0, -0.3, -f.run * (i + 0.5) / n); g.add(st);
      }
      for (const sx of [-0.84, 0.84]) {
        const a = V3(sx, 0.85, 0.05), b = V3(sx, rise + 0.85, -f.run);
        g.add(P.rope([a, b], 0.035, IRON));
        for (const p of [a, b]) { const post = P.box(0.06, 0.85, 0.06, IRON); post.position.set(p.x, p.y - 0.85, p.z); g.add(post); }
      }
      const rails = [-0.86, 0.86].map((sx) => ({ sx, s: this.solidBox(0, 0, 0.12, f.run + 0.2, f.y0 - 1, f.y1 + 1.2) }));
      this.surface((x, z) => this.flightAt(k, x, z));
      // The lever on the landing beside the flight's foot.
      const lv = new THREE.Group(); lv.position.set(f.x + 1.6, f.y0, f.z + 1.4); this.add(lv);
      lv.add(P.cyl(0.1, 0.13, 0.9, '#4a4440'));
      const arm = new THREE.Group(); arm.position.y = 0.9; arm.rotation.z = 0.5; lv.add(arm);
      const stick = P.cyl(0.035, 0.035, 0.7, '#d9b34a'); arm.add(stick);
      const knob = P.sphere(0.08, '#e8c24a'); knob.position.y = 0.72; arm.add(knob);
      arm.visible = k !== 1 || G.state.flag('lever2_handled');
      this.solidCyl(lv.position.x, lv.position.z, 0.15, f.y0 - 1, f.y0 + 1.2);
      this.interact({
        obj: lv, radius: 1.6, icon: '\u{1F579}️', yRange: 1.5,
        label: () => {
          if (k === 1 && !G.state.flag('lever2_handled')) return G.state.has('lever_handle') ? 'Fit the brass handle' : 'A lever with no handle';
          return `Pull lever ${k + 1}`;
        },
        use: () => this.pull(k),
      });
      if (k === 1) this.sense(lv, { warm: () => G.state.has('lever_handle'), height: 1 });
      return { g, rails, arm, lever: lv };
    });
    this.syncRails();

    // The squirrel baron's toll rope across flight one's foot.
    const f0 = FLIGHTS[0];
    const toll = new THREE.Group(); toll.position.set(f0.x, PLAIN, f0.z + 0.3); this.add(toll);
    for (const sx of [-0.95, 0.95]) { const n = P.cyl(0.07, 0.09, 1.1, '#5d4a3c'); n.position.x = sx; toll.add(n); this.solidCyl(f0.x + sx, f0.z + 0.3, 0.12, -1, PLAIN + 1.1); }
    this.tollRope = P.cyl(0.04, 0.04, 1.9, '#b39a66', { base: false }); this.tollRope.rotation.z = Math.PI / 2; this.tollRope.position.y = 0.9; toll.add(this.tollRope);
    const baron = this.squirrel(true); baron.position.set(0.95, 1.1, 0); baron.rotation.y = 0.4; toll.add(baron); this.baron = baron;
    this.every(() => { baron.userData.tail.rotation.x = -0.35 + Math.sin(G.time * 2.4) * 0.15; });
    this.tollSolid = this.solidBox(f0.x, f0.z + 0.3, 1.9, 0.25, -1, PLAIN + 2.6);
    if (G.state.flag('toll_paid')) { this.tollSolid.enabled = false; this.tollRope.position.y = 0.06; }
    this.interact({
      pos: V3(f0.x, PLAIN, f0.z + 1.1), radius: 1.6, icon: '\u{1F43F}️',
      label: () => (G.state.flag('toll_paid') ? null : 'The squirrel baron’s toll rope'),
      use: () => this.payToll(),
    });
  }
  flightAt(k, x, z) {
    const f = FLIGHTS[k], a = this.flights[k].g.rotation.y;
    const dx = x - f.x, dz = z - f.z, c = Math.cos(a), s = Math.sin(a);
    const lx = dx * c - dz * s, lz = dx * s + dz * c;
    if (Math.abs(lx) > FLIGHT_W / 2 || lz > 0.15 || lz < -f.run - 0.1) return null;
    return f.y0 + (f.y1 - f.y0) * clamp(-lz / f.run, 0, 1) + 0.12;
  }
  syncRails() {
    FLIGHTS.forEach((f, k) => {
      const fl = this.flights[k], a = fl.g.rotation.y, c = Math.cos(a), s = Math.sin(a);
      for (const r of fl.rails) {
        const lz = -f.run / 2 + 0.05;
        r.s.x = f.x + r.sx * c + lz * s;
        r.s.z = f.z - r.sx * s + lz * c;
        r.s.rot = -a;
      }
    });
  }
  payToll() {
    if (G.state.flag('toll_paid')) return;
    if (!G.state.has('bagel')) {
      G.audio.sfx('squirrel_chitter', { vol: 0.8, rate: 1.1 });
      G.ui.say('The baron holds out one paw. The paw means: one bagel. There is a bagel oven at the mountain’s foot, and a longer way up for the patient.', { dur: 5 });
      return;
    }
    G.state.take('bagel');
    G.state.set('toll_paid');
    G.audio.sfx('squirrel_chitter', { vol: 0.9 });
    this.tollSolid.enabled = false;
    G.tween(this.tollRope.position, { y: 0.06 }, 0.5, ease.outBounce);
    G.ui.say('One bagel, taken with ceremony. The rope drops. Contracts are honoured to the letter, on this mountain.', { dur: 4.5 });
  }
  pull(k) {
    if (this.turning) return;
    const fl = this.flights[k];
    if (k === 1 && !G.state.flag('lever2_handled')) {
      if (G.state.has('lever_handle')) {
        G.state.take('lever_handle');
        G.state.set('lever2_handled');
        fl.arm.visible = true;
        G.audio.sfx('lever_clunk', { vol: 0.8, rate: 1.2 });
        G.ui.say('The brass handle seats with a click. Lever two lives again.');
        return;
      }
      G.ui.say(G.state.flag('mmfa_delivered')
        ? 'A bare iron stub. The museum’s garden squirrel left something brass on the front steps, exactly handle-shaped.'
        : 'A lever with no handle: a bare iron stub. Squirrels steal brass on this mountain, though the one loitering at the museum looks like it keeps accounts.', { dur: 5 });
      return;
    }
    if (G.state.flag('stairs_fixed')) { G.ui.toast('The zigzag is true, top to bottom. Leave it be.', '\u{1FA9C}'); return; }
    this.turning = true;
    G.audio.sfx('lever_clunk', { vol: 0.9 });
    G.tween(fl.arm.rotation, { z: -0.5 }, 0.25).then(() => G.tween(fl.arm.rotation, { z: 0.5 }, 0.35));
    // This flight and the next swing a quarter turn.
    const moved = [k]; if (k + 1 < FLIGHTS.length) moved.push(k + 1);
    G.audio.sfx('stone_slide', { vol: 0.7, rate: 0.9 });
    for (const m of moved) {
      this.turns[m] = (this.turns[m] + 1) % 4;
      const g = this.flights[m].g;
      G.tween(g.rotation, { y: g.rotation.y - Math.PI / 2 }, 1.4, ease.inOut);
    }
    G.wait(1.45).then(() => {
      for (const m of moved) { const g = this.flights[m].g; g.rotation.y = -this.turns[m] * Math.PI / 2; }
      this.turning = false;
      if (this.turns.every((t) => t === 0)) {
        G.state.set('stairs_fixed');
        G.audio.sfx('fanfare', { vol: 0.7 });
        G.ui.celebrate('Every flight points true', 'The Staircase Shuffle');
        G.ui.say('One clean zigzag from the plaza to the summit. The mountain is hers, the short way, for good.', { dur: 4.5 });
      }
    });
  }

  buildLocations() {
    for (const [pos, r, name, y] of [[V3(0, 0, 33), 8, 'The Old Port'], [V3(0, 0, 14), 8, 'Downtown'], [ARENA, 7, 'The Bell Centre'], [V3(MUSEUM.x, 0, MUSEUM.z + 6), 6, 'The Museum'],
      [V3(CHALET.x, 0, CHALET.z + 4), 6, 'The Belvedere', CHALET.y], [CROSS, 8, 'The Summit', CROSS.y]]) {
      this.trigger({ pos, radius: r, y, yr: y != null ? 2 : undefined, once: true, onEnter: () => G.ui.showBanner(`~ ${name} ~`, 2.2) });
    }
  }

  // ── Dusk ──────────────────────────────────────────────
  setDusk(instant) {
    if (this.dusk) return;
    this.dusk = true;
    const lights = (t) => {
      for (const m of this.windowMats) m.emissiveIntensity = lerp(0.1, 1.1, t);
      for (const gl of this.glows) gl.mat.emissiveIntensity = lerp(gl.day, gl.dusk, t);
      this.beacon.scale.z = lerp(1, 1.8, t);
      this.beamMat.opacity = lerp(0.3, 0.55, t);
      const u = this.water.material.uniforms;
      u.uDeep.value.set('#1f4752').lerp(_c.set('#1a2a40'), t);
      u.uLight.value.set('#4f8784').lerp(_c.set('#3b4f6c'), t);
      u.uFoam.value.set('#d3e2dc').lerp(_c.set('#a99cc0'), t);
    };
    if (instant) { lights(1); return; }
    const from = { sun: G.sun.color.clone(), sky: G.scene.background.clone(), fog: G.scene.fog.color.clone(), hemi: G.hemi.intensity, si: G.sun.intensity, sl: G.hemi.color.clone(), gl: G.hemi.groundColor.clone() };
    const to = { sun: new THREE.Color(DUSK.sun), sky: new THREE.Color(DUSK.sky), fog: new THREE.Color(DUSK.fog), sl: new THREE.Color(DUSK.skyLight), gl: new THREE.Color(DUSK.groundLight) };
    G.animate(6, (t) => {
      G.sun.color.copy(from.sun).lerp(to.sun, t);
      G.scene.background.copy(from.sky).lerp(to.sky, t);
      G.scene.fog.color.copy(from.fog).lerp(to.fog, t);
      G.hemi.color.copy(from.sl).lerp(to.sl, t);
      G.hemi.groundColor.copy(from.gl).lerp(to.gl, t);
      G.sun.intensity = lerp(from.si, DUSK.sunIntensity, t);
      G.hemi.intensity = lerp(from.hemi, DUSK.hemi, t);
      lights(t);
    }).then(() => { if (G.island === this) G.render.setAtmosphere(DUSK); });
  }

  // ── Frame ─────────────────────────────────────────────
  update(dt) {
    this.beacon.rotation.y += dt * 0.9;
    this.horseMixer?.update(dt);
    this.updateOven(dt);
    if (this.turning) this.syncRails();
    this.updateSwarm(dt);
    this.updateLeaves(dt);
    this.updateOccluders(dt);
    this.updateDrumBar();
    // The city of a hundred steeples, and mountain small-talk.
    this.bellT -= dt;
    if (this.bellT <= 0) { this.bellT = 80 + Math.random() * 70; G.audio.sfx('funicular_bell', { vol: 0.25, rate: 0.55 + Math.random() * 0.15 }); }
    this.chitterT -= dt;
    if (this.chitterT <= 0) { this.chitterT = 25 + Math.random() * 30; if (G.player.pos.z < -3) G.audio.sfx('squirrel_chitter', { vol: 0.3, rate: 0.9 + Math.random() * 0.3 }); }
  }

  dispose() {
    this.drumBar?.remove();
    super.dispose();
  }

  async onEnter() {
    if (!G.state.flag('montreal_arrived')) {
      G.state.set('montreal_arrived');
      await G.cine.run(async (c) => {
        c.look(V3(0, 6, -16), { dist: 50, pitch: 28, yaw: 20, speed: 0.8 });
        await c.say('Montréal in autumn: a whole mountain in red maple, over a city of glass and grey stone.', { dur: 4.4 });
        c.look(CROSS.clone().add(V3(0, 6, 0)), { dist: 20, pitch: 16, yaw: 25, speed: 1.0 });
        await c.say('At the summit, a great cross of lanterns. Every one of them dark.', { dur: 3.6 });
        c.look(HORSE.clone().setY(1.5), { dist: 10, pitch: 28, yaw: 30, speed: 1.2 });
        G.audio.sfx('horse_snort', { vol: 0.8 });
        await c.say('And across the only road up the mountain, a calèche horse, asleep on its feet.', { dur: 3.8 });
      });
    }
    if (!G.state.knows('growl')) G.ui.toast('A horse blocks the mountain road. Say something to it.', '\u{1F434}');
  }

  // ── Goals ─────────────────────────────────────────────
  leverNeeded() {
    // Lever k swings flights k and k+1; solve for the first lever that still needs pulls.
    const t = [...this.turns];
    for (let k = 0; k < t.length; k++) {
      const c = (4 - t[k]) % 4;
      if (c > 0) return k;
      if (k + 1 < t.length) t[k + 1] = (t[k + 1] + c) % 4;
    }
    return -1;
  }
  objective() {
    const s = G.state;
    if (s.flag('island5_complete')) return null;
    if (!s.knows('growl')) return 'Get the calèche horse off the mountain road';
    if (!s.flag('three_stars_done')) return this.zamboniMoved ? 'Wake the great cube over centre ice' : 'Clear the Bell Centre’s centre ice';
    if (!s.flag('mmfa_delivered')) return s.has('lafleur_portrait') ? 'Return the portrait to the museum' : 'Pick up the fallen portrait';
    if (!s.flag('stairs_fixed')) {
      if (!s.flag('lever2_handled')) return s.has('lever_handle') ? 'Fit the brass handle on lever two' : 'Fetch the brass handle from the museum steps';
      return 'Line up the mountain staircases';
    }
    if (!s.flag('panes_fitted')) return s.count('arena_pane') >= 3 ? 'Fit the panes in the summit cross' : 'Collect the spare arena glass';
    if (!s.flag('bagels_placed')) return s.count('bagel') >= 12 ? 'Warm the cross with twelve bagels' : `Bake bagels for the cross (${s.count('bagel')}/12)`;
    if (!s.flag('cross_lit')) return 'Play the summit drum, with Oreo';
    return 'Ride the funicular down';
  }
  hint() {
    const s = G.state;
    if (!s.knows('growl')) return 'A calèche horse sleeps across the mountain road and nothing she says moves it. Her friend’s big voice does. Maybe hers can learn its shape.';
    if (!s.flag('three_stars_done')) return 'The Bell Centre is empty and its ice still glows. Something parked on the centre dot fears a hiss, and the great dark cube above it is the biggest thing downtown. Hoist the stars it calls, in order.';
    if (!s.flag('mmfa_delivered')) return 'A framed number 10, and a plaque that names the museum at the mountain’s east foot. The grand door there says TIREZ, and cats push. Bring Oreo.';
    if (!s.flag('stairs_fixed')) {
      if (!s.flag('lever2_handled')) return 'The staircases pivot, and every lever swings two flights, but lever two is a bare stub. The brass handle the museum squirrel returned waits on the front steps.';
      return 'Every lever swings its own flight and the next. From the chalet balcony the whole zigzag reads at a glance. The long way up is the boulder scramble on the west flank.';
    }
    if (!s.flag('panes_fitted')) return 'Three lanterns on the summit cross have no glass. The Bell Centre’s penalty box keeps spares.';
    if (!s.flag('bagels_placed')) return 'Twelve lantern bases want twelve warm bagels: the oven at the mountain’s foot bakes them in the golden second. The sign says à la douzaine, and squirrels count.';
    if (!s.flag('cross_lit')) return 'The fireflies circle but will not settle. They love warmth, and rhythm. Play the drum’s chalk pattern by the cross, a beat about every second; Oreo barks the echoes.';
    return 'The cross’s shadow found the funicular gate on the summit’s west lip. Ride it down to the river.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.knows('growl')) return this.horse.position.clone().setY(1.6);
    if (!s.flag('three_stars_done')) return this.zamboniMoved ? ARENA.clone().setY(1) : this.zamboni.getWorldPosition(V3()).setY(1.5);
    if (!s.flag('mmfa_delivered')) return s.has('lafleur_portrait') ? this.worldOf(this.museum, -3.4, 1, 0) : V3(ARENA.x + 2, 0.6, ARENA.z + 1.5);
    if (!s.flag('stairs_fixed')) {
      if (!s.flag('lever2_handled')) return s.has('lever_handle') ? this.flights[1].lever.position.clone().setY(FLIGHTS[1].y0 + 1) : this.worldOf(this.museum, -5.6, 0.5, 1.2);
      if (!s.flag('saw_zigzag')) return V3(CHALET.x, CHALET.y + 0.5, CHALET.z + 3.8);
      const k = this.leverNeeded();
      return k >= 0 ? this.flights[k].lever.position.clone().setY(FLIGHTS[k].y0 + 1) : null;
    }
    if (!s.flag('panes_fitted')) return s.count('arena_pane') >= 3 ? CROSS.clone().setY(16) : V3(ARENA.x - 4, 1, ARENA.z - 3);
    if (!s.flag('bagels_placed')) return s.count('bagel') >= 12 ? CROSS.clone().setY(16) : OVEN.clone().setY(1.5);
    if (!s.flag('cross_lit')) return DRUM.clone().setY(DRUM.y + 1);
    return FUNI[0].clone().setY(16);
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'growl', name: 'Learning the Growl', done: s.knows('growl'), hint: 'A calèche horse ignores a meow and plants its hooves at a hiss.' },
      { id: 'stars', name: 'The Three Stars', done: s.flag('three_stars_done'), hint: 'Hiss the Zamboni aside, growl the cube awake, hoist the stars it calls.' },
      { id: 'fallen', name: 'The Fallen Star', done: s.flag('mmfa_delivered'), hint: 'A portrait on loan, and a door that says TIREZ.' },
      { id: 'stairs', name: 'The Staircase Shuffle', done: s.flag('stairs_fixed'), hint: 'Every lever swings two flights. Climb high to think, then act.' },
      { id: 'bagels', name: 'The Bagel Standard', done: s.flag('bagels_placed'), hint: 'Pull it in the golden second. Twelve à la douzaine.' },
      { id: 'cross', name: 'Light the Cross', done: s.flag('island5_complete'), hint: 'Panes, warm bagels, and a drum duet for the fireflies.' },
    ];
  }
}
