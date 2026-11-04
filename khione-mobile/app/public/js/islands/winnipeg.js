// Island 4 — The Winnipeg Crescent. "First snow, seen through a tropical cat's eyes."
// Teaches: dig, and the duet — she marks (meow), he digs. The squall is the
// island's metronome. Layout, numbers and puzzle rules mirror the Godot island
// (scripts/islands/winnipeg.gd + drift_line / rink_maze / mailbox_morse /
// swing_launch / longest_slide).
import * as THREE from 'three';
import { G, rng, clamp, fbm, ease, V3, damp } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';

const WATER = -0.4;
const COAST_BASE = 46;
const HOUSE_R = 21.5;
const HOUSE_ANGLES = [2.62, 3.32, 4.01, 4.71, 5.41, 6.11];
const HOUSE_COLORS = ['#9e8070', '#808f9e', '#a8997a', '#946f61', '#859985', '#998599'];
const RUN_PATH = [[-12, -35], [-12, -32.5], [-14, -27], [-15, -21], [-14, -14], [-13, -6], [-11.5, 3], [-9, 12], [-6, 20], [-3, 28], [-1.5, 34], [-1, 37]];
const SNOW = '#eef2fb';
const TRIM = '#e6e0d6';
const STEEL = '#737882';
// Drift line
const POLE_A = V3(-19, 0.35, 6.5), POLE_B = V3(-13, 0.35, 10.5);
const STOOP = V3(-19.4, 0.4, 12.6);
const PINS = ['green', 'red', 'blue', 'yellow'];
const WASH = {
  red: { color: '#cc4d47', id: 'frozen_mitten', pos: V3(-23, 0.35, 3.5) },
  blue: { color: '#5980bf', id: 'frozen_scarf', pos: V3(-17.5, 0.35, 1.5) },
  yellow: { color: '#d9bf4d', id: 'frozen_sock', pos: V3(-12, 0.35, 13.5) },
};
// Rink
const RINK = V3(-10, 0.35, 2);
const RMIN = { x: -13.25, z: -0.25 }, RMAX = { x: -6.75, z: 4.25 };
const ICE_Y = 0.46;
const TARGET = V3(-7.6, ICE_Y, 4.0), TARGET_R = 0.5;
const PUCK_START = V3(-12.5, ICE_Y, 0.5);
// Mailboxes
const MAILBOX_R = 19;
const NUMBERS = [3, 8, 5, 12, 7, 4];
const TRUCK = V3(17, 0.35, 9.5), TRUCK_ROT = 0.5;
// Playground / swing
const PLAY = V3(10, 0.35, 4);
const SEAT = V3(12.2, 1.15, 4.0);
const TIERS = [V3(16, 0.55, 9), V3(21.2, 4.55, -3.7), V3(13.9, 4.55, -16.4)];
// Longest slide
const CELLAR = V3(-1, 0.2, 36);
const GATES = 6;
const DOCK_SPAWN = V3(0, 0, 42);

const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const wrap = (a) => { while (a > Math.PI) a -= Math.PI * 2; while (a < -Math.PI) a += Math.PI * 2; return a; };

export default class Winnipeg extends Island {
  static id = 'winnipeg';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 2, r: 60 };
    this.snowy = true;
    this.moundColor = '#f4f7fd';
    this.digSound = 'dig';
    this.squall = false;
    this.warning = false;
    this.digs = [];
    this.digBusy = false;
  }

  models() { return ['house_snow', 'snowman', 'toboggan', 'mailbox', 'car', 'tree_pine', 'canoe']; }
  sounds() { return ['winter_wind', 'snow_dig', 'sled', 'train_horn', 'wood_creak', 'drain', 'stone_slide', 'gate_open', 'whimper', 'land', 'splash', 'dig']; }
  atmosphere() {
    return {
      sky: '#7d86b4', fog: '#b4b6d2', fogNear: 40, fogFar: 125,
      sun: '#d6dcff', sunIntensity: 1.9, hemi: 1.45, skyLight: '#dfe6ff', groundLight: '#8a86a8',
      exposure: 1.05, sunDir: [-14, 12, -18],
    };
  }
  music() { return 'winnipeg'; }
  terrainTextures() { return ['snow.jpg', 'cobble.jpg', 'snow.jpg']; }

  coast(theta) {
    let wob = 2.6 * Math.sin(3 * theta + 1.7) + 1.7 * Math.sin(5 * theta + 4.2) + 1.1 * Math.sin(8 * theta + 0.9);
    wob *= ss(0.55, 1.1, Math.abs(wrap(theta - Math.PI / 2)));
    return COAST_BASE + wob;
  }
  height(x, z) {
    const d = Math.hypot(x, z), coast = this.coast(Math.atan2(z, x));
    if (d >= coast) return -6 * clamp((d - coast) / 12, 0, 1);
    let h = 0.35 * (1 - ss(coast - 4, coast - 1.5, d));
    const rim = ss(coast * 0.52, coast * 0.82, d);
    const north = ss(-14, -30, z);
    h += 2.6 * rim * north;
    if (!this.nearRun(x, z, 3.5)) h += Math.max(0, fbm(x * 0.12, z * 0.12)) * 0.25 * ss(26, 34, d);
    return h;
  }
  onRoad(x, z) {
    const d = Math.hypot(x, z);
    const ring = Math.abs(d - 16) < 1.5;
    const path = Math.abs(x) < 1.3 && z > 16 && z < 41;
    return ring || path;
  }
  splat(x, z) { return this.onRoad(x, z) ? [0.5, 0.5, 0] : [1, 0, 0]; }
  tint(x, z) {
    const c = new THREE.Color('#ffffff');
    const h = this.height(x, z);
    if (this.onRoad(x, z)) c.set('#b4b6c8');
    if (h < WATER) c.lerp(new THREE.Color('#5a7a9a'), clamp((WATER - h) / 4, 0, 0.8));
    c.multiplyScalar(0.94 + fbm(x * 0.2, z * 0.2) * 0.08);
    return c;
  }
  footstep() { return 'paw_sand'; }
  dustColor() { return '#ffffff'; }
  spawn() { return { x: DOCK_SPAWN.x, z: DOCK_SPAWN.z, rotY: Math.PI }; }

  nearRun(x, z, m = 2.4) {
    for (let i = 0; i < RUN_PATH.length - 1; i++) {
      const [ax, az] = RUN_PATH[i], [bx, bz] = RUN_PATH[i + 1];
      const dx = bx - ax, dz = bz - az;
      const t = clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1);
      if (Math.hypot(x - (ax + dx * t), z - (az + dz * t)) < m) return true;
    }
    return false;
  }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 124, res: 150, repeat: 0.18 });
    this.makeWater({ level: WATER, size: 320, res: 120, colors: { deep: '#3d6f9c', light: '#7aa6c8', foam: '#f2f6ff' } });
    this.buildCrescent();
    this.buildDock();
    this.buildPlayground();
    this.buildRink();
    this.buildYardEight();
    this.buildCars();
    this.buildBay();
    this.buildSkyAndCity();
    this.scatter();
    this.buildDriftLine();
    this.buildRinkPuzzle();
    this.buildMailboxes();
    this.buildSwing();
    this.buildSlide();
    this.buildDigListener();
    this.startWeather();
    this.trainHorn();
    this.places([
      [V3(0, 0, 10), 9, 'The Crescent'], [V3(10, 0, 4), 6, 'The Frozen Playground'], [V3(-10, 0, 2), 6, 'The Backyard Rink'],
      [V3(0, 0, -25), 7, 'Number Eight'], [V3(-13, 0, -27), 7, 'The Top of the Run'], [V3(38, 0, -28), 9, 'The Fishing Shacks'],
    ]);
  }

  /** Caption when free; a toast during cutscenes (ui.say() calls must not overlap a scripted say). */
  tell(text, icon = '\u2744\uFE0F') {
    if (G.cine.active || this.saying) { G.ui.toast(text, icon); return; }
    this.saying = true;
    G.ui.say(text).finally(() => { this.saying = false; });
    setTimeout(() => { this.saying = false; }, 7000);
  }

  places(list) {
    for (const [pos, r, name] of list) this.trigger({ pos, radius: r, once: true, onEnter: () => G.ui.showBanner(`~ ${name} ~`, 2.2) });
  }

  houseSpot(i) { const a = HOUSE_ANGLES[i]; return V3(Math.cos(a) * HOUSE_R, 0.35, Math.sin(a) * HOUSE_R); }

  buildCrescent() {
    const deco = new THREE.Group();
    this.houses = [];
    HOUSE_ANGLES.forEach((a, i) => {
      const pos = this.houseSpot(i);
      const facing = Math.atan2(-pos.x, -pos.z);
      const g = new THREE.Group();
      g.position.copy(pos); g.rotation.y = facing;
      const house = model('house_snow', { size: 6.6, rotY: -Math.PI / 2 });
      g.add(house);
      this.add(g);
      this.houses.push(g);
      // Body + roof ridge colliders (the ridge is where swing launches land).
      this.solidBox(pos.x, pos.z, 5.4, 4.4, -1, 0.35 + 2.6, -facing, { noStand: true });
      const ridgeTop = 4.5;
      this.solidBox(pos.x, pos.z, 4.8, 2.6, 2.9, ridgeTop, -facing);
      // Curb plaque; Number Eight's is unmistakably loved.
      const plaque = P.box(0.5, 0.35, 0.08, i === 3 ? '#d94d4d' : '#e6e0cc');
      plaque.position.set(pos.x + Math.sin(facing) * 3.4, 0.4, pos.z + Math.cos(facing) * 3.4);
      plaque.rotation.y = facing;
      deco.add(plaque);
      if (i % 2 === 0) this.chimneySmoke(g.localToWorld(V3(1.6, 5.0, -0.8)));
    });
    // Picket fence along the road's outer edge, gaps at the houses.
    for (let k = 0; k < 40; k++) {
      const a = 2.35 + (6.45 - 2.35) * (k / 39);
      if (HOUSE_ANGLES.some((ha) => Math.abs(wrap(a - ha)) < 0.17)) continue;
      const p = V3(Math.cos(a) * 18.9, 0.35, Math.sin(a) * 18.9);
      const post = P.box(0.09, 0.75, 0.09, TRIM); post.position.copy(p); deco.add(post);
      const rail = P.box(0.06, 0.1, 1.9, TRIM); rail.position.set(p.x, 0.85, p.z); rail.rotation.y = -a; deco.add(rail);
    }
    // Street lamps with warm halos.
    for (const a of [2.8, 3.7, 4.7, 5.7]) {
      const p = V3(Math.cos(a) * 14.2, 0.35, Math.sin(a) * 14.2);
      const post = P.cyl(0.06, 0.09, 3.0, '#33402f'); post.position.copy(p); deco.add(post);
      const head = P.sphere(0.2, '#ffe0a0', { emissive: '#ffd27a', emissiveIntensity: 1.4 }); head.position.set(p.x, 3.4, p.z); head.castShadow = false; deco.add(head);
      this.solidCyl(p.x, p.z, 0.12, -1, 3.3);
    }
    // String lights between the houses.
    const bulbCols = ['#ff6659', '#66d97f', '#ffcc66', '#7399ff', '#e680e6'];
    for (let i = 0; i < HOUSE_ANGLES.length - 1; i++) {
      const p1 = this.houseSpot(i), p2 = this.houseSpot(i + 1);
      p1.y = 3.4; p2.y = 3.4;
      const mid = p1.clone().lerp(p2, 0.5); mid.y -= 0.9;
      const curve = new THREE.QuadraticBezierCurve3(p1, mid, p2);
      deco.add(P.rope(curve.getPoints(10), 0.015, '#3a3a40'));
      for (let k = 1; k < 10; k++) {
        const b = P.sphere(0.07, bulbCols[k % 5], { seg: 6, emissive: bulbCols[k % 5], emissiveIntensity: 1.2 });
        b.position.copy(curve.getPoint(k / 10)); b.castShadow = false; deco.add(b);
      }
    }
    this.add(P.bake(deco)); this.add(deco);
  }

  chimneySmoke(at) {
    let acc = 0;
    this.every((dt) => {
      acc += dt * 4;
      while (acc > 1) {
        acc -= 1;
        G.fx.spawn(at.x + (Math.random() - 0.5) * 0.2, at.y, at.z + (Math.random() - 0.5) * 0.2, {
          vx: 0.25 + (this.squall ? 2 : 0), vy: 0.7, vz: 0, gravity: -0.15, drag: 0.3, size: 0.45, grow: 2, life: 4, color: '#d8d8e0',
        });
      }
    });
  }

  buildDock() {
    const deco = new THREE.Group();
    for (let i = 0; i < 6; i++) {
      const b = P.box(2.4, 0.15, 1.7, P.mat('#ffffff', { map: 'planks.jpg' }));
      b.position.set(0, 0.2 - i * 0.012, 40 + i * 1.8); deco.add(b);
      this.solidBox(0, 40 + i * 1.8, 2.4, 1.7, -2, 0.35 - i * 0.012);
    }
    for (const side of [-1, 1]) for (let i = 0; i < 3; i++) { const p = P.cyl(0.12, 0.14, 1.6, '#66544a'); p.position.set(side * 1.1, -1.1, 41 + i * 4); deco.add(p); }
    this.add(deco);
    // The canoe that brought them, hauled up on the snow.
    const canoe = model('canoe', { size: 3.6, rotY: 0.4 });
    canoe.position.set(3.2, 0.3, 38.5); this.add(canoe);
    this.solidBox(3.2, 38.5, 3.4, 1.2, -1, 0.75, -0.4);
    // Fire barrel: the island's warm heart.
    const barrel = P.cyl(0.42, 0.4, 1.0, '#403a3e'); barrel.position.set(3, 0.35, 14); this.add(barrel);
    this.solidCyl(3, 14, 0.45, -1, 1.35);
    const ember = P.sphere(0.3, '#ff9a40', { emissive: '#ff7a20', emissiveIntensity: 2 }); ember.scale.y = 0.4; ember.position.set(3, 1.33, 14); ember.castShadow = false; this.add(ember);
    let acc = 0;
    this.every((dt) => {
      acc += dt * 18;
      while (acc > 1) { acc -= 1; G.fx.spawn(3 + (Math.random() - 0.5) * 0.4, 1.4, 14 + (Math.random() - 0.5) * 0.4, { vy: 1.2 + Math.random(), gravity: -1, drag: 1, size: 0.18, life: 0.9, color: Math.random() < 0.5 ? '#ffb040' : '#ff7030' }); }
    });
  }

  buildPlayground() {
    const o = PLAY;
    const deco = new THREE.Group();
    // Slide: ladder, platform, and the long tongue.
    for (const x of [-1.2, -0.6]) { const l = P.box(0.12, 2.0, 0.12, STEEL); l.position.set(o.x + x, o.y, o.z - 1); deco.add(l); }
    for (let r = 0; r < 5; r++) { const rung = P.box(0.7, 0.06, 0.12, STEEL); rung.position.set(o.x - 0.9, o.y + 0.35 + r * 0.38, o.z - 1); deco.add(rung); }
    const plat = P.box(1.0, 0.12, 1.0, STEEL); plat.position.set(o.x - 0.9, o.y + 1.94, o.z - 0.4); deco.add(plat);
    this.solidBox(o.x - 0.9, o.z - 0.4, 1.0, 1.0, o.y + 1.8, o.y + 2.06);
    const tongue = P.box(0.9, 0.1, 3.2, '#bf4d47', { base: false }); tongue.position.set(o.x - 0.9, o.y + 1.25, o.z + 1.15); tongue.rotation.x = 0.45; deco.add(tongue);
    // The ladder as a walkable ramp of steps, and the tongue as a slope.
    this.surface((x, z) => {
      const lx = x - (o.x - 0.9), lz = z - (o.z + 1.15);
      if (Math.abs(lx) > 0.45 || Math.abs(lz) > 1.45) return null;
      return o.y + 1.25 - lz * Math.tan(0.45) + 0.05;
    });
    // Swing set: two A-frames, crossbar.
    for (const sx of [-1.6, 1.6]) for (const lean of [-0.35, 0.35]) {
      const leg = P.box(0.1, 2.6, 0.1, STEEL, { base: false }); leg.position.set(o.x + 3 + sx, o.y + 1.2, o.z + lean * 1.6); leg.rotation.x = lean; deco.add(leg);
    }
    const bar = P.box(3.6, 0.1, 0.1, STEEL, { base: false }); bar.position.set(o.x + 3, o.y + 2.45, o.z); deco.add(bar);
    // Merry-go-round.
    const disc = P.cyl(1.5, 1.5, 0.14, '#4d809e'); disc.position.set(o.x + 0.8, o.y + 0.35, o.z + 3.6); deco.add(disc);
    const dsnow = P.cyl(1.1, 1.3, 0.05, SNOW); dsnow.position.set(o.x + 0.8, o.y + 0.49, o.z + 3.6); deco.add(dsnow);
    const hub = P.cyl(0.08, 0.1, 0.9, STEEL); hub.position.set(o.x + 0.8, o.y + 0.35, o.z + 3.6); deco.add(hub);
    this.solidCyl(o.x + 0.8, o.z + 3.6, 1.5, -1, o.y + 0.5);
    this.add(P.bake(deco)); this.add(deco);
  }

  buildRink() {
    const o = RINK;
    const ice = P.box(7.0, 0.1, 5.0, P.mat('#c6dcef', { rough: 0.15 }));
    ice.position.set(o.x, o.y, o.z); this.add(ice);
    this.solidBox(o.x, o.z, 7.0, 5.0, -1, ICE_Y - 0.01);
    const boards = new THREE.Group();
    const defs = [[7.4, 0.15, 0, 2.55], [7.4, 0.15, 0, -2.55], [0.15, 5.2, -3.65, 0]];
    // East boards have a gap so a cat can walk on; the rest you hop.
    defs.push([0.15, 1.8, 3.65, -1.7], [0.15, 1.8, 3.65, 1.7]);
    for (const [w, d, x, z] of defs) {
      const b = P.box(w, 0.45, d, TRIM); b.position.set(o.x + x, o.y, o.z + z); boards.add(b);
      this.solidBox(o.x + x, o.z + z, w, d, -1, o.y + 0.45);
    }
    // Hockey nets and sticks.
    for (const [x, rot] of [[-13, Math.PI / 2], [-7, -Math.PI / 2]]) {
      const net = new THREE.Group(); net.position.set(x, ICE_Y, 2); net.rotation.y = rot;
      for (const [px, h] of [[-0.6, 0], [0.6, 0]]) { const p = P.box(0.06, 0.75, 0.06, '#cc4033'); p.position.set(px, h, 0); net.add(p); }
      const top = P.box(1.26, 0.06, 0.06, '#cc4033'); top.position.set(0, 0.72, 0); net.add(top);
      boards.add(net);
    }
    this.add(boards);
    const sm = model('snowman', { height: 1.7, rotY: 0.6 }); sm.position.set(o.x - 4.6, o.y, o.z - 1.6); this.add(sm);
    this.solidCyl(o.x - 4.6, o.z - 1.6, 0.5, -1, 1.8);
  }

  buildYardEight() {
    const fence = '#9e8c75';
    const deco = new THREE.Group();
    for (const [w, d, x, z] of [[12, 0.12, 0, -32], [0.12, 8, -6, -28], [0.12, 8, 6, -28], [4.6, 0.12, -3.6, -24], [4.6, 0.12, 3.6, -24], [2.5, 0.1, 0, -24]]) {
      const f = P.box(w, 0.9, d, x === 0 && z === -24 ? '#857462' : fence); f.position.set(x, this.height(x, z) - 0.05, z); deco.add(f);
      this.solidBox(x, z, Math.max(w, 0.2), Math.max(d, 0.2), -1, this.height(x, z) + 0.95);
    }
    // Icicles on the frozen gate.
    for (let i = 0; i < 6; i++) { const ic = P.cone(0.05, 0.35, '#d8ecff', { base: false }); ic.rotation.x = Math.PI; ic.position.set(-1 + i * 0.4, this.height(0, -24) + 0.7, -23.95); deco.add(ic); }
    // The yard's only tree: big, bare, patient.
    const tx = 0, tz = -28.5, ty = this.height(tx, tz);
    const trunk = P.cyl(0.18, 0.32, 3.4, '#5c4a3e'); trunk.position.set(tx, ty, tz); deco.add(trunk);
    const R = rng(88);
    for (let i = 0; i < 6; i++) {
      const br = P.cyl(0.05, 0.1, 1.8, '#5c4a3e', { base: false });
      br.position.set(tx + Math.cos(i) * 0.5, ty + 2.4 + R() * 0.8, tz + Math.sin(i) * 0.5);
      br.rotation.set(Math.sin(i * 2) * 0.9, i, Math.cos(i * 2) * 0.9); deco.add(br);
    }
    this.solidCyl(tx, tz, 0.35, -1, 5);
    // The doghouse, kid-built, half under a drift.
    const dh = new THREE.Group(); dh.position.set(2.4, this.height(2.4, -29.5), -29.5); dh.rotation.y = 0.5;
    const body = P.box(1.5, 1.0, 1.7, '#c26b4f'); dh.add(body);
    const roofShape = new THREE.Shape(); roofShape.moveTo(-0.85, 0); roofShape.lineTo(0.85, 0); roofShape.lineTo(0, 0.6); roofShape.closePath();
    const roof = new THREE.Mesh(new THREE.ExtrudeGeometry(roofShape, { depth: 1.9, bevelEnabled: false }), P.mat('#7a4a3a'));
    roof.position.set(0, 1.0, -0.95); roof.castShadow = true; dh.add(roof);
    const band = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 0.28), new THREE.MeshLambertMaterial({ map: P.textCanvas('', { w: 256, h: 52, bg: '#9fd0f0', border: null, draw: (g) => { g.fillStyle = '#6b7f9a'; g.beginPath(); g.moveTo(0, 52); for (let x = 0; x <= 256; x += 32) g.lineTo(x, 52 - (x / 32 % 2 ? 40 : 14)); g.lineTo(256, 52); g.fill(); g.fillStyle = '#fff'; for (let x = 32; x < 256; x += 64) { g.beginPath(); g.moveTo(x - 8, 20); g.lineTo(x, 12); g.lineTo(x + 8, 20); g.fill(); } } }) }));
    band.position.set(0, 0.72, 0.86); dh.add(band);
    const door = new THREE.Mesh(new THREE.CircleGeometry(0.3, 16), P.mat('#1c1414')); door.position.set(0, 0.42, 0.861); dh.add(door);
    deco.add(dh);
    const drift = P.sphere(1.3, SNOW); drift.scale.set(1.2, 0.5, 1.0); drift.position.set(2.4, this.height(2.4, -30.3), -30.3); deco.add(drift);
    this.solidBox(2.4, -29.5, 1.6, 1.8, -1, this.height(2.4, -29.5) + 1.3, -0.5);
    this.add(P.bake(deco)); this.add(deco);
    // Oreo knows this yard.
    this.trigger({
      pos: V3(0, 0, -23), radius: 3.5, once: true, onEnter: () => {
        if (!G.oreo.active) return;
        G.audio.sfx('whimper', { pos: G.oreo.pos, vol: 0.7 });
        this.tell('Oreo stops at the gate of Number Eight. His tail goes very still.');
      },
    });
  }

  buildCars() {
    // Cars that have not moved since November, wearing thick snow duvets. Solid
    // blocks ground-to-duvet so nothing walks through a tire; the hood is a ledge.
    for (const [x, z, rot] of [[20.6, 6.2, 0.9], [-19, 9.5, -0.7]]) {
      const car = model('car', { size: 3.5, rotY: 0 });
      car.position.set(x, 0.3, z); car.rotation.y = rot;
      this.add(car);
      this.solidBox(x, z, 1.8, 3.5, -1, 1.15, -rot);
      this.solidBox(x, z, 1.4, 1.6, 1.0, 1.55, -rot);
    }
  }

  buildBay() {
    // Frozen bay with fishing shacks to the north-east.
    const deco = new THREE.Group();
    for (const [x, z, r] of [[36, -30, 10], [44, -18, 9], [30, -38, 7.5]]) {
      const sheet = P.cyl(r, r, 0.25, P.mat('#d2e3f2', { rough: 0.2 }), { seg: 28 }); sheet.position.set(x, WATER - 0.05, z); deco.add(sheet);
      this.solidCyl(x, z, r, -6, WATER + 0.2);
    }
    for (const [x, z, col, rot] of [[36, -30, '#bf5a4d', 0.4], [43, -20, '#5a8ca6', -0.3], [31, -36, '#b39a4d', 1.1]]) {
      const shack = P.building({ w: 1.6, d: 1.9, h: 1.7, wall: col, roof: '#6b5a52', roofH: 0.6, windows: '#ffd890' });
      shack.position.set(x, WATER + 0.2, z); shack.rotation.y = rot; deco.add(shack);
      this.solidBox(x, z, 1.7, 2.0, -1, WATER + 2.2, -rot);
    }
    this.add(deco);
  }

  buildSkyAndCity() {
    // Aurora curtains over the north.
    const mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
      uniforms: { uTime: { value: 0 } },
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: `uniform float uTime; varying vec2 vUv;
        void main(){ float w = sin(vUv.x*9.0 + uTime*0.25)*0.5+0.5; float w2 = sin(vUv.x*23.0 - uTime*0.4)*0.5+0.5;
          float band = smoothstep(0.0,0.35,vUv.y)*smoothstep(1.0,0.45,vUv.y)*(0.45+0.55*w*w2);
          vec3 c = mix(vec3(0.25,1.0,0.6), vec3(0.6,0.4,1.0), vUv.y);
          gl_FragColor = vec4(c*band*0.55, 1.0); }`,
    });
    for (const [x, y, z, w, h, r] of [[-30, 34, -110, 160, 30, 0.1], [40, 40, -118, 130, 26, -0.25]]) {
      const curtain = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
      curtain.position.set(x, y, z); curtain.rotation.y = r; curtain.renderOrder = -1;
      curtain.material.fog = false;
      this.add(curtain);
    }
    this.every(() => { mat.uniforms.uTime.value = G.time; });
    // A city skyline far to the south-east; the golden boy catches the light.
    const glass = P.mat('#5a6b8c', { emissive: '#f2d999', emissiveIntensity: 0.25 });
    const city = new THREE.Group();
    for (const [x, z, w, h] of [[80, 70, 7, 24], [92, 60, 8, 30], [104, 66, 6, 20], [116, 56, 7, 26], [128, 64, 6, 16]]) {
      const t = P.box(w, h, w, glass); t.position.set(x, -1, z); t.castShadow = false; city.add(t);
    }
    const dome = P.sphere(2.6, '#5a8072'); dome.position.set(70, 10, 60); city.add(dome);
    const boy = P.sphere(0.5, '#ffd95a', { emissive: '#ffcc40', emissiveIntensity: 1.2 }); boy.position.set(70, 13.2, 60); city.add(boy);
    this.add(city);
  }

  scatter() {
    const R = rng(2026);
    const pines = [];
    for (let i = 0; i < 40; i++) {
      const a = R.range(0, Math.PI * 2), r = R.range(24, 41);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      if (z > 12 && Math.abs(x) < 8) continue;
      if (z < -20 && z > -33 && Math.abs(x) < 8) continue;
      if (this.nearRun(x, z, 3)) continue;
      if (Math.hypot(x - 36, z + 28) < 14) continue;
      const h = this.height(x, z);
      if (h < 0.25) continue;
      const s = R.range(0.8, 1.6);
      pines.push({ x, y: h - 0.05, z, rotY: R.range(0, 6.28), scale: s });
      this.solidCyl(x, z, 0.45 * s, -1, h + 4 * s);
    }
    this.add(instanced('tree_pine', pines, { height: 4.6 }));
    // Snowbanks and drifts.
    const deco = new THREE.Group();
    for (let i = 0; i < 26; i++) {
      const a = R.range(0, 6.28), r = R.range(10, 38);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      if (this.onRoad(x, z) || this.nearRun(x, z, 2.5) || Math.hypot(x - RINK.x, z - RINK.z) < 6 || Math.hypot(x - PLAY.x, z - PLAY.z) < 6) continue;
      const d = P.sphere(R.range(0.6, 1.4), SNOW, { seg: 12 }); d.scale.y = 0.4; d.position.set(x, this.height(x, z) - 0.1, z); deco.add(d);
    }
    this.add(P.bake(deco)); this.add(deco);
    // A jackrabbit in white winter coat that bounds away from you.
    const rabbit = new THREE.Group();
    const rb = P.sphere(0.22, '#f4f4f8'); rb.scale.set(1, 0.8, 1.3); rb.position.y = 0.22; rabbit.add(rb);
    const rh = P.sphere(0.13, '#f4f4f8'); rh.position.set(0, 0.38, 0.22); rabbit.add(rh);
    for (const s of [-1, 1]) { const ear = P.box(0.05, 0.28, 0.03, '#f4f4f8'); ear.position.set(0.05 * s, 0.45, 0.2); ear.rotation.z = 0.15 * s; rabbit.add(ear); }
    rabbit.position.set(24, this.height(24, 18), 18);
    this.add(rabbit);
    let hopT = 0;
    this.every((dt) => {
      hopT -= dt;
      const p = G.player.pos;
      const d = Math.hypot(p.x - rabbit.position.x, p.z - rabbit.position.z);
      if (d < 5 && hopT <= 0) {
        hopT = 1.2;
        const away = V3(rabbit.position.x - p.x, 0, rabbit.position.z - p.z).normalize().multiplyScalar(3);
        const to = rabbit.position.clone().add(away);
        to.x = clamp(to.x, -34, 34); to.z = clamp(to.z, -30, 34); to.y = this.height(to.x, to.z);
        rabbit.rotation.y = Math.atan2(away.x, away.z);
        const from = rabbit.position.clone();
        G.animate(0.6, (t) => { rabbit.position.lerpVectors(from, to, t); rabbit.position.y += Math.sin(t * Math.PI) * 0.6; });
      }
    });
  }

  // ── The squall (the island's metronome) ────────────────
  startWeather() {
    G.audio.ambient('winter_wind', 0.18);
    G.fx.setWeather('snow', { rate: 22, wind: [0.5, 0.2] });
    this.cycle = 0;
    const CALM = 40, WARN = 2.5, SQUALL = 11;
    this.every((dt) => {
      this.cycle += dt;
      const t = this.cycle % (CALM + WARN + SQUALL);
      const warning = t >= CALM && t < CALM + WARN;
      const squall = t >= CALM + WARN;
      if (warning && !this.warning) {
        this.warning = true;
        G.audio.sfx('winter_wind', { vol: 0.5, rate: 1.3, dur: 2 });
        G.ui.showBanner('\u{1F32C}️ The wind is rising!', 1.8);
      }
      if (!warning) this.warning = false;
      if (squall !== this.squall) this.setSquall(squall);
      const w = G.fx.weather;
      if (w) {
        w.rate = damp(w.rate, this.squall ? 160 : warning ? 60 : 22, 2, dt);
        w.wind[0] = damp(w.wind[0], this.squall ? 7 : 0.5, 2, dt);
        w.wind[1] = damp(w.wind[1], this.squall ? 2.5 : 0.2, 2, dt);
      }
      G.sun.intensity = damp(G.sun.intensity, this.squall ? 1.2 : 1.9, 1.5, dt);
    });
  }
  setSquall(on) {
    this.squall = on;
    G.audio.ambient('winter_wind', on ? 0.75 : 0.18);
    if (on) {
      if (!G.state.flag('seen_squall')) { G.state.set('seen_squall'); this.tell('The prairie wind leans hard off the ridge, and every icicle keens.'); }
      G.ui.showBanner('❄️ Squall!', 1.6);
      this.onSquallStart?.();
    } else {
      G.ui.showBanner('Stillness.', 1.4);
    }
  }

  trainHorn() {
    const loop = async () => {
      while (G.island === this) {
        await G.wait(95 + Math.random() * 75);
        if (G.island !== this) return;
        G.audio.sfx('train_horn', { vol: 0.22, rate: 0.94 + Math.random() * 0.08 });
      }
    };
    loop();
  }

  // ── She marks, he digs ────────────────────────────────
  digMound({ pos, key, r = 0.7, radius = 2.4, enabled = () => true, onDug }) {
    if (key && G.state.flag(`dug_${key}`)) return null;
    const y = this.groundAt(pos.x, pos.z, 99);
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(r, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2), P.mat(this.moundColor));
    mesh.scale.y = 0.55; mesh.position.set(pos.x, y - 0.03, pos.z); mesh.receiveShadow = true; mesh.castShadow = true;
    this.add(mesh);
    const spot = { pos: V3(pos.x, y, pos.z), key, r, radius, enabled, onDug, mesh, dug: false };
    this.digs.push(spot);
    this.sense(mesh, { warm: () => !spot.dug && enabled(), height: 0.3 });
    return spot;
  }
  buildDigListener() {
    this.onVocal(async (e) => {
      if (e.kind !== 'meow' || this.digBusy) return;
      let best = null, bd = Infinity;
      for (const s of this.digs) {
        if (s.dug || !s.enabled()) continue;
        const d = Math.hypot(e.pos.x - s.pos.x, e.pos.z - s.pos.z);
        if (d < s.radius && d < bd) { bd = d; best = s; }
      }
      if (!best) return;
      if (!G.oreo.active) { G.ui.toast('Somebody here was born to dig.', '\u{1F415}'); return; }
      this.digBusy = true;
      // Whisker Sense sinks INTO the drift: a ring marks the spot.
      G.audio.sfx('whisker_shimmer', { pos: best.pos, vol: 0.7 });
      const ring = new THREE.Mesh(new THREE.TorusGeometry(best.r * 1.05, 0.05, 6, 24), new THREE.MeshBasicMaterial({ color: '#9fe8f2', transparent: true, opacity: 0.85 }));
      ring.rotation.x = Math.PI / 2; ring.position.copy(best.pos).add(V3(0, 0.15, 0)); this.add(ring);
      const pulse = this.every(() => { if (!ring.parent) return true; const s = 1 + Math.sin(G.time * 6) * 0.1; ring.scale.set(s, s, 1); });
      try { await G.oreo.dig(best.pos); } catch (err) { console.error(err); }
      ring.removeFromParent();
      best.dug = true;
      if (best.key) G.state.set(`dug_${best.key}`);
      G.fx.burst(best.pos.clone().add(V3(0, 0.3, 0)), { color: '#ffffff', count: 26, speed: 3, up: 4, size: 0.16, life: 0.8 });
      G.tween(best.mesh.scale, { x: 1.1, y: 0.04, z: 1.1 }, 0.45, ease.out).then(() => best.mesh.removeFromParent());
      this.digBusy = false;
      best.onDug?.(best);
      void pulse;
    });
  }

  // ── Riddle 1: the Drift Line ───────────────────────────
  buildDriftLine() {
    const topA = POLE_A.clone().setY(POLE_A.y + 1.8), topB = POLE_B.clone().setY(POLE_B.y + 1.8);
    for (const p of [POLE_A, POLE_B]) { const pole = P.cyl(0.06, 0.08, 1.9, '#73614d'); pole.position.copy(p); this.add(pole); this.solidCyl(p.x, p.z, 0.1, -1, 2.3); }
    this.add(P.rope([topA, topA.clone().lerp(topB, 0.5).add(V3(0, -0.12, 0)), topB], 0.015, '#d9d4c7'));
    this.pinAt = (c) => { const i = PINS.indexOf(c); return topA.clone().lerp(topB, 0.2 + i * 0.2).add(V3(0, -0.06, 0)); };
    for (const c of PINS) {
      const at = this.pinAt(c);
      const pin = P.box(0.06, 0.14, 0.05, c === 'green' ? '#66a666' : WASH[c].color, { base: false });
      pin.position.copy(at); this.add(pin);
      if (c === 'green' || G.state.flag(`hung_${c}`)) { this.hangCloth(c); continue; }
      // A generous invisible tap target hanging under each pin.
      const target = new THREE.Mesh(new THREE.BoxGeometry(0.8, 1.2, 0.8), new THREE.MeshBasicMaterial({ visible: false }));
      target.position.copy(at).add(V3(0, -0.5, 0)); this.add(target);
      const it = this.interact({
        obj: target, radius: 1.5, icon: '\u{1F9F7}',
        enabled: () => !G.state.flag(`hung_${c}`),
        label: () => (G.state.has(WASH[c].id) ? `Hang the ${itemLabel(WASH[c].id)} (${c} pin)` : `A ${c} clothespin`),
        use: () => this.tryHang(c),
      });
      void it;
    }
    for (const c of Object.keys(WASH)) {
      const w = WASH[c];
      this.digMound({
        pos: w.pos, key: `wash_${c}`, r: 0.6,
        onDug: () => this.pickup({ id: w.id, key: `wash_${c}`, pos: w.pos.clone().add(V3(0.3, -0.1, 0.2)), obj: frozenThing(c, w.color) }),
      });
      if (G.state.flag(`dug_wash_${c}`) && !G.state.flag(`took_wash_${c}`) && !G.state.flag(`hung_${c}`)) {
        this.pickup({ id: w.id, key: `wash_${c}`, pos: w.pos.clone().add(V3(0.3, -0.1, 0.2)), obj: frozenThing(c, w.color) });
      }
    }
    // Number seven's porch light.
    this.porch = P.box(0.9, 0.75, 0.1, P.mat('#ffd98c', { emissive: '#ffcc80', emissiveIntensity: 0.4 }));
    this.porch.position.set(-20.2, 1.3, 13.4); this.add(this.porch);
    if (G.state.flag('drift_line_done') && !G.state.flag('took_cocoa_thermos')) this.pickup({ id: 'cocoa_thermos', pos: STOOP.clone() });
  }
  hangCloth(c) {
    const at = this.pinAt(c);
    const cloth = c === 'green' ? P.box(0.34, 0.42, 0.03, '#e6e0cc', { base: false }) : frozenThing(c, WASH[c].color);
    cloth.position.copy(at).add(V3(0, -0.28, 0));
    if (c !== 'green') cloth.scale.setScalar(0.8);
    this.add(cloth);
    const ph = Math.random() * 6;
    this.every(() => { cloth.rotation.z = Math.sin(G.time * (this.squall ? 6 : 1.6) + ph) * (this.squall ? 0.25 : 0.06); });
  }
  tryHang(c) {
    const w = WASH[c];
    if (G.state.flag(`hung_${c}`)) { this.tell('That pin already holds its piece, stiff as a board.'); return; }
    if (!G.state.has(w.id)) { this.tell(`An empty clothespin, painted ${c}. Somewhere under the drifts, its laundry waits.`); return; }
    G.state.take(w.id);
    G.state.set(`hung_${c}`);
    this.hangCloth(c);
    const n = Object.keys(WASH).filter((k) => G.state.flag(`hung_${k}`)).length;
    G.audio.sfx('pickup_chime', { rate: 1 + 0.1 * n, vol: 0.6 });
    if (n >= 3) this.finishDriftLine();
    else this.tell(`Hung, frozen solid, faintly heroic. ${3 - n} to go.`);
  }
  finishDriftLine() {
    G.state.set('drift_line_done');
    const m = this.porch.material;
    G.animate(2.1, (t) => { m.emissiveIntensity = 0.4 + Math.max(0, Math.sin(t * Math.PI * 6)) * 1.8; }).then(() => { m.emissiveIntensity = 0.4; });
    this.pickup({ id: 'cocoa_thermos', pos: STOOP.clone() });
    G.ui.celebrate('The line hangs full!', 'The Drift Line');
    this.tell('The whole line hangs full again. A porch light winks three times, and something warm appears on the stoop.');
  }

  // ── Riddle 2: the Backyard Rink ───────────────────────
  buildRinkPuzzle() {
    const circle = new THREE.Mesh(new THREE.CircleGeometry(TARGET_R, 28), new THREE.MeshBasicMaterial({ color: '#4d73b3', transparent: true, opacity: 0.55, depthWrite: false }));
    circle.rotation.x = -Math.PI / 2; circle.position.copy(TARGET).add(V3(0, 0.012, 0)); circle.renderOrder = 2; this.add(circle);
    const puck = P.cyl(0.2, 0.2, 0.11, '#1f1f24'); puck.position.copy(PUCK_START); this.add(puck);
    this.puck = puck;
    this.sliding = false;
    if (G.state.flag('rink_done')) {
      puck.position.set(TARGET.x, ICE_Y, TARGET.z);
      if (!G.state.flag('took_runner_wax')) this.pickup({ id: 'runner_wax', pos: TARGET.clone().add(V3(0, 0, -0.6)) });
      return;
    }
    // Direction arrow showing which way a bump will send it.
    const arrowShape = new THREE.Shape(); arrowShape.moveTo(-0.12, 0); arrowShape.lineTo(0.12, 0); arrowShape.lineTo(0.12, 0.5); arrowShape.lineTo(0.28, 0.5); arrowShape.lineTo(0, 0.85); arrowShape.lineTo(-0.28, 0.5); arrowShape.lineTo(-0.12, 0.5); arrowShape.closePath();
    const arrow = new THREE.Mesh(new THREE.ShapeGeometry(arrowShape), new THREE.MeshBasicMaterial({ color: '#ffc93c', transparent: true, opacity: 0.85, depthWrite: false }));
    arrow.rotation.x = -Math.PI / 2; arrow.renderOrder = 3; arrow.visible = false; this.add(arrow);
    this.every(() => {
      if (G.state.flag('rink_done') || this.sliding) { arrow.visible = false; return; }
      const p = G.player.pos, d = Math.hypot(p.x - puck.position.x, p.z - puck.position.z);
      arrow.visible = d < 1.8;
      if (!arrow.visible) return;
      const dir = this.bumpDir();
      arrow.position.set(puck.position.x + dir.x * 0.3, ICE_Y + 0.02, puck.position.z + dir.y * 0.3);
      arrow.rotation.set(-Math.PI / 2, 0, Math.atan2(-dir.x, -dir.y));
    });
    this.interact({
      obj: puck, radius: 1.5, icon: '\u{1F3D2}',
      enabled: () => !G.state.flag('rink_done') && !this.sliding,
      label: 'Bump the old puck',
      use: () => this.bumpPuck(),
    });
    // Meow on the ice: Oreo trots over and SITS where she stood.
    this.onVocal((e) => {
      if (e.kind !== 'meow' || G.state.flag('rink_done') || !G.oreo.active || !this.onIce(e.pos.x, e.pos.z)) return;
      const spot = V3(clamp(e.pos.x, RMIN.x + 0.4, RMAX.x - 0.4), ICE_Y, clamp(e.pos.z, RMIN.z + 0.4, RMAX.z - 0.4));
      this.bumperAt(spot);
    });
    this.sense(puck, { warm: () => !G.state.flag('rink_done'), height: 0.2 });
  }
  async bumperAt(spot) {
    G.oreo.noBark = true;
    await G.oreo.goTo(spot, 0.15, 5);
    G.oreo.teleport(spot.x, spot.z);
    G.oreo.stay();
    G.ui.refreshVox();
    G.oreo.noBark = false;
    if (!this.toldBumper) { this.toldBumper = true; this.tell('Oreo trots onto the ice and SITS where she stood. Immovable. Extremely proud of himself.'); }
  }
  onIce(x, z) { return x > RMIN.x - 0.3 && x < RMAX.x + 0.3 && z > RMIN.z - 0.3 && z < RMAX.z + 0.3; }
  bumpDir() {
    const ax = this.puck.position.x - G.player.pos.x, az = this.puck.position.z - G.player.pos.z;
    return Math.abs(ax) >= Math.abs(az) ? { x: Math.sign(ax) || 1, y: 0 } : { x: 0, y: Math.sign(az) || 1 };
  }
  slideStop(from, dir) {
    const stop = { x: from.x, y: from.y };
    if (dir.x > 0) stop.x = RMAX.x - 0.2; else if (dir.x < 0) stop.x = RMIN.x + 0.2;
    else if (dir.y > 0) stop.y = RMAX.z - 0.2; else stop.y = RMIN.z + 0.2;
    // A dog on a stay is the proudest bumper alive.
    if (G.oreo.active && G.oreo.mode === 'stay') {
      const op = { x: G.oreo.pos.x, y: G.oreo.pos.z };
      const lane = dir.x !== 0 ? Math.abs(op.y - from.y) < 0.55 : Math.abs(op.x - from.x) < 0.55;
      const ahead = (op.x - from.x) * dir.x + (op.y - from.y) * dir.y > 0.2;
      if (lane && ahead) {
        const blocked = { x: op.x - dir.x * 0.75, y: op.y - dir.y * 0.75 };
        if (Math.hypot(blocked.x - from.x, blocked.y - from.y) < Math.hypot(stop.x - from.x, stop.y - from.y)) return blocked;
      }
    }
    return stop;
  }
  async bumpPuck() {
    if (this.sliding || G.state.flag('rink_done')) return;
    const dir = this.bumpDir();
    const from = { x: this.puck.position.x, y: this.puck.position.z };
    const stop = this.slideStop(from, dir);
    const dist = Math.hypot(stop.x - from.x, stop.y - from.y);
    if (dist < 0.05) { this.tell('The puck is already against something that way.'); return; }
    this.sliding = true;
    G.player.emote('attack', 1.8);
    G.audio.sfx('stone_slide', { rate: 1.6, vol: 0.5 });
    await G.tween(this.puck.position, { x: stop.x, z: stop.y }, clamp(dist * 0.16, 0.25, 1.1), ease.out);
    this.sliding = false;
    if (G.oreo.mode === 'stay' && Math.hypot(G.oreo.pos.x - stop.x, G.oreo.pos.z - stop.y) < 0.9) G.oreo.bark();
    if (Math.hypot(stop.x - TARGET.x, stop.y - TARGET.z) <= TARGET_R) this.solveRink();
  }
  solveRink() {
    G.state.set('rink_done');
    G.audio.sfx('crab_snip', { rate: 0.7, vol: 0.6 }); G.audio.sfx('drain', { rate: 1.2, vol: 0.5 });
    const crack = new THREE.Mesh(new THREE.RingGeometry(TARGET_R + 0.05, TARGET_R + 0.18, 24), new THREE.MeshBasicMaterial({ color: '#eef6ff' }));
    crack.rotation.x = -Math.PI / 2; crack.position.copy(TARGET).add(V3(0, 0.015, 0)); this.add(crack);
    this.pickup({ id: 'runner_wax', pos: TARGET.clone().add(V3(0, 0, -0.6)) });
    G.oreo.follow(); G.ui.refreshVox();
    G.ui.celebrate('Dead centre!', 'The Backyard Rink');
    this.tell('The puck settles dead centre, the ice cracks a polite ring, and a tin of runner wax bobs up. Good bumper. The best bumper.');
  }

  // ── Riddle 3: the Mailbox Morse ───────────────────────
  buildMailboxes() {
    const R = rng(1212);
    this.flagsUp = [];
    this.flagMeshes = [];
    HOUSE_ANGLES.forEach((a, i) => {
      const pos = V3(Math.cos(a) * MAILBOX_R, 0.35, Math.sin(a) * MAILBOX_R);
      const g = new THREE.Group(); g.position.copy(pos); g.rotation.y = -a + Math.PI / 2;
      const box = model('mailbox', { height: 1.25 }); g.add(box);
      const flag = new THREE.Group(); flag.position.set(0.24, 1.0, 0);
      const fl = P.box(0.05, 0.4, 0.14, '#d9402e'); fl.position.y = 0; flag.add(fl);
      g.add(flag);
      this.add(g);
      this.solidCyl(pos.x, pos.z, 0.25, -1, 1.3);
      this.flagMeshes.push(flag);
      this.flagsUp.push(R() < 0.5);
      // Curb number painted on the road, readable from up high.
      const num = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 1.1), new THREE.MeshLambertMaterial({
        map: P.textCanvas(String(NUMBERS[i]), { w: 128, h: 128, bg: null, fg: '#f4f0e0', font: 'bold 92px "Baloo 2", sans-serif', border: null }), transparent: true,
      }));
      num.rotation.x = -Math.PI / 2; num.rotation.z = 0.628; // upright from the default camera
      num.position.set(Math.cos(a) * 17.2, this.height(Math.cos(a) * 17.2, Math.sin(a) * 17.2) + 0.04, Math.sin(a) * 17.2);
      this.add(num);
      this.interact({
        obj: g, radius: 1.7, icon: '\u{1F6A9}',
        label: () => (G.state.flag('mailbox_done') ? null : this.flagsUp[i] ? `Flag down (#${NUMBERS[i]})` : `Flag up (#${NUMBERS[i]})`),
        use: () => this.toggleFlag(i),
      });
      this.sense(g, { warm: () => !G.state.flag('mailbox_done') && this.flagsUp[i] !== (NUMBERS[i] % 2 === 1), height: 1.2 });
    });
    if (G.state.flag('mailbox_done')) NUMBERS.forEach((n, i) => { this.flagsUp[i] = n % 2 === 1; });
    else if (NUMBERS.every((n, i) => this.flagsUp[i] === (n % 2 === 1))) this.flagsUp[0] = !this.flagsUp[0];
    this.flagMeshes.forEach((f, i) => { f.rotation.z = this.flagsUp[i] ? 0 : -1.35; });
    // The postal truck.
    const truck = new THREE.Group(); truck.position.copy(TRUCK); truck.rotation.y = TRUCK_ROT;
    const body = P.box(1.9, 1.6, 3.6, '#ebe6dc', { round: 0.1 }); body.position.y = 0.35; truck.add(body);
    const stripe = P.box(1.94, 0.28, 3.62, '#bf4d4d'); stripe.position.y = 1.1; truck.add(stripe);
    const cab = P.box(1.7, 1.0, 1.1, '#d9d6cc', { round: 0.08 }); cab.position.set(0, 0.3, 2.3); truck.add(cab);
    for (const [x, z] of [[-0.8, 1.2], [0.8, 1.2], [-0.8, -1.2], [0.8, -1.2]]) { const w = P.cyl(0.32, 0.32, 0.2, '#262629', { base: false }); w.rotation.z = Math.PI / 2; w.position.set(x, 0.32, z); truck.add(w); }
    const door = P.box(1.7, 1.3, 0.08, '#999aa0'); door.position.set(0, 0.6, -1.85); truck.add(door);
    this.truckDoor = door;
    this.add(truck);
    this.solidBox(TRUCK.x, TRUCK.z, 2.0, 4.8, -1, 2.0, -TRUCK_ROT);
    this.truck = truck;
    if (G.state.flag('mailbox_done')) { door.position.y = 1.7; if (!G.state.flag('took_road_salt')) this.dropSalt(); }
    this.onSquallStart = () => {
      if (G.state.flag('mailbox_done')) return;
      const flips = 2 + (Math.random() < 0.5 ? 1 : 0);
      for (let k = 0; k < flips; k++) { const i = Math.floor(Math.random() * 6); this.flagsUp[i] = !this.flagsUp[i]; this.applyFlag(i); }
    };
  }
  applyFlag(i) { G.tween(this.flagMeshes[i].rotation, { z: this.flagsUp[i] ? 0 : -1.35 }, 0.3, ease.out); }
  toggleFlag(i) {
    if (G.state.flag('mailbox_done')) { this.tell('The route is read; the flags can rest.'); return; }
    this.flagsUp[i] = !this.flagsUp[i];
    this.applyFlag(i);
    G.audio.sfx('wood_creak', { rate: 1.5, vol: 0.4 });
    if (this.squall) { G.ui.toast('Nothing counts in flying snow.', '❄️'); return; }
    if (NUMBERS.every((n, k) => this.flagsUp[k] === (n % 2 === 1))) this.solveMailboxes();
  }
  solveMailboxes() {
    G.state.set('mailbox_done');
    G.audio.sfx('pickup_chime', { rate: 1.1 }); G.audio.sfx('stone_slide', { rate: 1.2, vol: 0.5 });
    G.tween(this.truckDoor.position, { y: 1.7 }, 1.0, ease.inOut);
    this.dropSalt();
    G.ui.celebrate('Six flags agree!', 'The Mailbox Morse');
    this.tell('Six flags agree, and the tape deck believes them. The truck rolls open: road salt, and a bundle of letters that never made it.');
  }
  dropSalt() {
    const p = this.truck.localToWorld(V3(0, 0, -2.9));
    this.pickup({ id: 'road_salt', pos: V3(p.x, this.height(p.x, p.z), p.z) });
  }

  // ── Riddle 4: the Swing Set Launch ────────────────────
  buildSwing() {
    const pivotY = PLAY.y + 2.4;
    const swing = new THREE.Group(); swing.position.set(SEAT.x, pivotY, SEAT.z);
    for (const z of [-0.18, 0.18]) { const ch = P.box(0.03, 1.6, 0.03, '#59595f', { base: false }); ch.position.set(0, -0.8, z); swing.add(ch); }
    const seat = P.box(0.5, 0.06, 0.4, '#33333d', { base: false }); seat.position.y = -1.6; swing.add(seat);
    this.add(swing);
    const other = swing.clone(); other.position.x = SEAT.x + 1.6; this.add(other);
    this.swing = swing;
    this.amp = 0; this.riding = false; this.lastPump = -10;
    this.every((dt) => {
      const target = this.riding ? [0, 0.25, 0.5, 0.8][this.amp] : 0;
      this.swingAmp = damp(this.swingAmp ?? 0, target, 3, dt);
      swing.rotation.z = Math.sin(G.time * 3.2) * this.swingAmp;
      if (this.riding) {
        const s = swing.localToWorld(V3(0, -1.55, 0));
        G.player.pos.copy(s); G.player.velocity.set(0, 0, 0);
        G.player.grounded = true; G.player.airTime = 0;
        G.player.yaw = Math.PI / 2; G.player.root.rotation.y = Math.PI / 2; G.player.targetYaw = Math.PI / 2;
      }
    });
    this.interact({
      obj: seat, radius: 1.6, icon: '\u{1FA81}',
      label: () => (this.riding ? (this.amp ? 'Let go!' : 'Hop off') : 'Hop on the swing'),
      use: () => (this.riding ? this.launch() : this.mount()),
    });
    this.on('jump', () => { if (this.riding) this.pump(); });
    for (const [i, id] of [[1, 'runner_bolts'], [2, 'old_loonie']]) {
      this.pickup({ id, pos: TIERS[i].clone().add(V3(0, -0.15, 0.5)) });
    }
  }
  mount() {
    if (this.riding) return;
    this.riding = true; this.amp = 0;
    G.player.walk = null;
    this.tell('She settles on the swing. Tap ⬆️ in rhythm to pump, then let go.');
  }
  pump() {
    const now = G.time, gap = now - this.lastPump;
    this.lastPump = now;
    this.amp = gap > 0.3 && gap < 1.6 ? Math.min(this.amp + 1, 3) : 1;
    G.audio.sfx('jump_whoosh', { rate: 0.8 + 0.15 * this.amp, vol: 0.4 });
    G.ui.showBanner(['', '★☆☆', '★★☆', '★★★'][this.amp], 0.9);
    if (this.amp === 3) this.tell('The swing sings at the top of its arc. Let go, whenever she dares.');
  }
  async launch() {
    if (!this.riding) return;
    if (this.amp < 1) { this.riding = false; G.player.teleport(SEAT.x - 1, SEAT.z + 1); return; }
    let tier = this.amp;
    if (this.squall && tier < 3) { tier++; this.tell('The squall catches her mid-air and CARRIES her.'); }
    this.riding = false;
    const target = TIERS[tier - 1];
    const from = G.player.pos.clone();
    const peak = Math.max(from.y, target.y) + 2.6;
    G.audio.sfx('jump_whoosh', { rate: 1.3, vol: 0.8 });
    await G.cine.run(async () => {
      G.cine.look(from.clone().lerp(target, 0.5), { dist: 15, speed: 2 });
      await G.animate(1.5, (t) => {
        const p = from.clone().lerp(target, t);
        p.y = from.y + (target.y - from.y) * t + Math.sin(t * Math.PI) * (peak - Math.max(from.y, target.y));
        G.player.pos.copy(p); G.player.velocity.set(0, 0, 0);
      });
      G.player.teleport(target.x, target.z, G.player.yaw, target.y);
      G.audio.sfx('land', { vol: 0.6 });
      if (tier >= 3 && !G.state.flag('seen_run_line')) {
        G.state.set('seen_run_line');
        G.cine.look(V3(-12, 1.5, -6), { dist: 26, pitch: 40, speed: 1 });
        await G.cine.say('From up here she sees it: a line of little red flags, poking from the drifts, running from the ridge all the way down to the shore.', { dur: 5 });
      }
    }, { letterbox: false });
    if (tier >= 2 && !G.state.flag('swing_done')) {
      G.state.set('swing_done');
      G.ui.celebrate('Rooftop!', 'The Swing Set Launch');
    } else if (tier === 1) this.tell('The lawn, with dignity intact. More height next time.');
  }

  // ── Main riddle: the Longest Slide ────────────────────
  buildSlide() {
    const start = RUN_PATH[0];
    const sy = this.height(start[0], start[1]);
    // The flag-line: little red flags either side of every buried gate.
    const deco = new THREE.Group();
    for (let g = 1; g <= GATES; g++) {
      const [px, pz] = RUN_PATH[g], [ax, az] = RUN_PATH[g - 1], [bx, bz] = RUN_PATH[g + 1];
      const dl = Math.hypot(bx - ax, bz - az), dx = (bx - ax) / dl, dz = (bz - az) / dl;
      for (const s of [-1, 1]) {
        const fx = px - dz * 1.3 * s, fz = pz + dx * 1.3 * s;
        const f = P.flag('#d9402e', 1.2); f.position.set(fx, this.groundAt(fx, fz, 99), fz); f.rotation.y = Math.atan2(dx, dz) + Math.PI / 2; deco.add(f);
      }
      this.digMound({
        pos: V3(px, 0, pz), key: `gate_${g}`, r: 1.0, radius: 2.6,
        enabled: () => g !== 6 || G.state.flag('rink_done'),
        onDug: () => {
          const left = GATES - this.gatesDug();
          if (left <= 0) { G.ui.celebrate('The run is ALIVE!', 'Every gate open'); this.tell('Every gate on the flag-line stands open, ridge to shore. The run is ALIVE again.'); }
          else G.ui.toast(`Gate open. ${left} more on the flag-line.`, '\u{1F6A9}');
        },
      });
    }
    this.add(deco);
    // The frozen start gate.
    this.iceBlock = null;
    if (!G.state.flag('gate_salted')) {
      const ice = P.box(1.5, 1.2, 1.1, P.mat('#b3d6f0', { transparent: true, opacity: 0.75 }), { round: 0.1 });
      ice.position.set(start[0], sy, start[1]); this.add(ice);
      this.iceBlock = ice;
      this.iceSolid = this.solidBox(start[0], start[1], 1.5, 1.1, -1, sy + 1.2);
      this.interact({
        obj: ice, radius: 2.2, icon: '\u{1F9CA}',
        enabled: () => !G.state.flag('gate_salted'),
        label: () => (G.state.has('road_salt') ? 'Salt the frozen gate' : 'A gate frozen solid'),
        use: () => this.saltGate(),
      });
      this.sense(ice, { warm: () => G.state.has('road_salt'), height: 1 });
    }
    // The toboggan, sleeping under the gate's drift.
    this.toboggan = null;
    this.digMound({
      pos: V3(start[0], 0, start[1]), key: 'toboggan', r: 0.9,
      enabled: () => G.state.flag('gate_salted'),
      onDug: () => { this.showToboggan(); this.tell('The toboggan! Cedar planks, curled nose, fifty years of stories. It wants wax, and its runner bolts back.'); },
    });
    if (G.state.flag('dug_toboggan')) this.showToboggan();
    // The storm cellar in the shore bank, sealed by one last drift.
    const frame = new THREE.Group(); frame.position.copy(CELLAR);
    const lintel = P.box(1.7, 0.25, 0.3, '#73614d'); lintel.position.set(0, 1.05, 0.2); frame.add(lintel);
    for (const s of [-0.8, 0.8]) { const post = P.box(0.2, 1.2, 0.3, '#73614d'); post.position.set(s, 0, 0.2); frame.add(post); }
    const dark = P.box(1.4, 1.05, 0.1, '#1a1612'); dark.position.set(0, 0, 0.05); frame.add(dark);
    this.add(frame);
    if (!G.state.flag('island4_complete')) {
      this.finalDrift = P.sphere(1.7, SNOW); this.finalDrift.scale.set(1.5, 0.75, 1.0);
      this.finalDrift.position.copy(CELLAR).add(V3(0, 0.2, -0.8)); this.add(this.finalDrift);
      this.driftSolid = this.solidCyl(CELLAR.x, CELLAR.z - 0.8, 1.9, -1, 1.2);
    }
  }
  gatesDug() { let n = 0; for (let g = 1; g <= GATES; g++) if (G.state.flag(`dug_gate_${g}`)) n++; return n; }
  async saltGate() {
    if (!G.state.has('road_salt')) { G.audio.sfx('stone_slide', { rate: 0.6, vol: 0.3 }); this.tell('Solid ice, older than three winters. Salt would talk sense into it.'); return; }
    G.state.take('road_salt');
    G.state.set('gate_salted');
    G.audio.sfx('drain', { rate: 0.8, vol: 0.6 });
    this.iceSolid.enabled = false;
    const ice = this.iceBlock; this.iceBlock = null;
    await G.tween(ice.scale, { x: 1.1, y: 0.04, z: 1.1 }, 1.6, ease.inOut);
    ice.removeFromParent();
    this.tell('The salt gnaws the gate open. Under the ice lies a long low lump of snow with two wooden tips poking out.');
  }
  showToboggan() {
    if (this.toboggan) return;
    const [sx, sz] = RUN_PATH[0];
    const holder = new THREE.Group();
    holder.position.set(sx, this.height(sx, sz), sz);
    const t = model('toboggan', { size: 2.2, rotY: Math.PI / 2 });
    holder.add(t);
    this.add(holder);
    this.toboggan = holder;
    this.interact({
      obj: holder, radius: 2.2, icon: '\u{1F6F7}',
      enabled: () => !this.riding,
      label: () => {
        if (!G.state.flag('sled_ready')) return G.state.has('runner_wax') && G.state.has('runner_bolts') ? 'Wax and bolt the toboggan' : 'The sleeping toboggan';
        return this.gatesDug() < GATES ? 'The run is still buried' : 'Ride the Longest Slide!';
      },
      use: () => this.sledInteract(),
    });
    this.sense(holder, { warm: () => true, height: 0.4 });
  }
  sledInteract() {
    if (!G.state.flag('sled_ready')) {
      if (G.state.has('runner_wax') && G.state.has('runner_bolts')) {
        G.state.take('runner_wax'); G.state.take('runner_bolts');
        G.state.set('sled_ready');
        G.audio.sfx('pickup_chime', { rate: 1.1 });
        G.fx.sparkle(this.toboggan.position.clone().add(V3(0, 0.5, 0)), '#ffe48a', 14);
        this.tell('Bolts seated, runners waxed to a wicked shine. The toboggan remembers exactly what it is.');
        return;
      }
      this.tell('It needs its runner bolts back, and a proper wax. The rink and the rooftops keep such things.');
      return;
    }
    const left = GATES - this.gatesDug();
    if (left > 0) { this.tell(`The run is still buried in ${left} place${left > 1 ? 's' : ''}. Walk the flag-line: she marks, he digs.`); return; }
    this.ride();
  }

  async ride() {
    this.riding = true;
    const curve = new THREE.CatmullRomCurve3(RUN_PATH.map(([x, z]) => V3(x, 0, z)), false, 'catmullrom', 0.5);
    const sled = this.toboggan;
    const spray = (p) => G.fx.burst(p, { color: '#ffffff', count: 3, speed: 1.5, up: 2.5, size: 0.14, life: 0.5 });
    G.audio.sfx('sled', { vol: 0.9 });
    await G.cine.run(async (c) => {
      G.oreo.mode = 'busy';
      G.fx.setWeather('snow', { rate: 25, wind: [0.4, 0.2] });
      let lastSfx = 0;
      await G.animate(9.5, (u) => {
        const p = curve.getPointAt(u), ahead = curve.getPointAt(Math.min(1, u + 0.02));
        const dir = ahead.clone().sub(p).setY(0).normalize();
        p.y = Math.max(this.groundAt(p.x, p.z, 99), 0.1);
        const yaw = Math.atan2(dir.x, dir.z);
        sled.position.copy(p); sled.rotation.y = yaw;
        G.player.pos.copy(p).add(V3(0, 0.25, 0)); G.player.yaw = yaw; G.player.root.rotation.y = yaw; G.player.targetYaw = yaw; G.player.velocity.set(0, 0, 0);
        G.oreo.pos.copy(p).add(V3(-dir.x * 0.75, 0.25, -dir.z * 0.75)); G.oreo.root.rotation.y = yaw; G.oreo.yaw = yaw; G.oreo.vel.set(0, 0, 0);
        c.look(p.clone().add(V3(0, 0.6, 0)).addScaledVector(dir, 2), { dist: 8, pitch: 26, yaw: (yaw * 180) / Math.PI + 180, speed: 6 });
        if (G.time - lastSfx > 0.08) { lastSfx = G.time; spray(p.clone().addScaledVector(dir, -0.8)); }
      }, ease.in);
      // Clean through the final drift.
      G.audio.sfx('land', { vol: 1, rate: 0.8 }); G.audio.sfx('splash', { vol: 0.6, rate: 0.7 });
      G.rig.shake = 1;
      if (this.finalDrift) { G.fx.burst(this.finalDrift.position.clone().add(V3(0, 0.6, 0)), { color: '#ffffff', count: 70, speed: 5, up: 6, size: 0.22, life: 1.1 }); this.finalDrift.removeFromParent(); this.finalDrift = null; this.driftSolid.enabled = false; }
      c.look(CELLAR.clone().add(V3(0, 0.8, 0)), { dist: 6, pitch: 30, speed: 2 });
      await c.wait(1.0);
      await c.say('In the storm cellar, among the boxed-up summer things: a kite reel with no kite.', { dur: 3.5 });
      G.state.give('kite_reel');
      await c.say('Taped to a box, a child’s crayon drawing of a black-and-white dog. Ears up. Tongue out. Drawn by somebody who loved one once.', { dur: 5 });
      G.state.addArtifact('crayon_dog', 'winnipeg', 'The Crayon Drawing', 'Taped to a box in the storm cellar: a child’s crayon drawing of a black-and-white dog, ears up, tongue out. Drawn by somebody who loved one once.');
      G.player.teleport(0.5, 38, Math.PI);
      G.oreo.teleport(-0.7, 37.4); G.oreo.follow();
      c.look(V3(1.5, 0.6, 38.5), { dist: 9, pitch: 34, speed: 1.2 });
      await c.say('The sled coasts the last stretch of frozen shore right up to the canoe. Some islands you leave at a walk. Not this one.', { dur: 4.5 });
    });
    this.riding = false;
    await G.game.finishIsland();
  }

  // ── Arrival ────────────────────────────────────────────
  async onEnter(first) {
    if (G.oreo.active) { G.oreo.teleport(-1.2, 41); G.oreo.follow(); }
    if (G.state.flag('wpg_arrived')) return;
    G.state.set('wpg_arrived');
    await G.cine.run(async (c) => {
      c.look(V3(0, 0.8, 34), { dist: 13, pitch: 34, speed: 1.5 });
      await c.say('First snow. A tropical cat sees it, and does not know what to do with her paws.', { dur: 4 });
      // Oreo hits the first drift at a dead run and simply vanishes.
      const drift = V3(-2.5, 0, 33);
      const mound = P.sphere(1.0, SNOW); mound.scale.y = 0.5; mound.position.set(drift.x, this.height(drift.x, drift.z) - 0.1, drift.z); this.add(mound);
      G.oreo.speedCap = 9;
      await G.oreo.goTo(drift, 0.3, 8);
      G.audio.sfx('snow_dig', { pos: drift, vol: 1 });
      G.fx.burst(drift.clone().setY(0.8), { color: '#ffffff', count: 40, speed: 3, up: 5, size: 0.2, life: 1 });
      G.oreo.root.visible = false;
      await c.say('Oreo hits the first drift at a dead run and simply vanishes. Tail up. Snow flying.', { dur: 3.2 });
      G.oreo.root.visible = true;
      G.oreo.bark();
      G.oreo.speedCap = 7.5;
      await c.say('When she meows at a lump in the snow, her Whisker Sense sinks INTO the drift, and he digs where she points.', { dur: 4.5 });
      G.oreo.follow();
    });
    G.ui.toast('Meow next to a lump in the snow and Oreo digs it out.', '\u{1F415}');
  }

  // ── Goals ──────────────────────────────────────────────
  objective() {
    const s = G.state;
    if (s.flag('island4_complete')) return 'The crescent sleeps under brand-new tracks.';
    if (!s.flag('drift_line_done')) return 'Dig out the laundry the squall buried';
    if (!s.flag('rink_done')) return 'Sink the old puck on the backyard rink';
    if (!s.flag('mailbox_done')) return 'Six mailbox flags: odd up, even down';
    if (!s.flag('swing_done')) return 'Pump the swing and land on a roof';
    if (!s.flag('gate_salted')) return 'Salt the frozen gate atop the ridge';
    if (!s.flag('dug_toboggan')) return 'Something sleeps under the gate’s drift';
    if (!s.flag('sled_ready')) return 'Wax and bolt the toboggan';
    const left = GATES - this.gatesDug();
    if (left > 0) return `Dig open the run: ${left} gate${left > 1 ? 's' : ''} left`;
    return 'Ride the Longest Slide!';
  }
  hint() {
    const s = G.state;
    if (!s.flag('drift_line_done')) return 'The squall stole the laundry off the line. Meow at the lumps in the drifts. Somebody here was born to dig. Then hang each piece back by its paired clothespin.';
    if (!s.flag('rink_done')) return 'An old puck waits on the backyard rink, and the target circle is nowhere near the boards. Snow will not pack on ice. A dog on a stay, though, will hold still. Meow on the ice where he should sit.';
    if (!s.flag('mailbox_done')) return 'Six red flags, and a squall that hates neat rows. The curb numbers read from up high: odd up, even down, all in one stillness.';
    if (!s.flag('swing_done')) return 'The swing remembers how to fly. Pump with the rhythm (⬆️), let go with courage, and see what the rooftops keep.';
    if (!s.flag('sled_ready')) return 'Salt for the frozen gate at the top of the ridge. Wax and bolts for whatever sleeps under it.';
    return 'Six gates under the drifts, marked by little red flags. She marks, he digs. Then: the ride.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.flag('drift_line_done')) {
      for (const c of Object.keys(WASH)) if (!s.flag(`dug_wash_${c}`)) return WASH[c].pos;
      return POLE_A.clone().lerp(POLE_B, 0.5);
    }
    if (!s.flag('rink_done')) return RINK;
    if (!s.flag('mailbox_done')) return this.houseSpot(3).multiplyScalar(MAILBOX_R / HOUSE_R);
    if (!s.flag('swing_done')) return SEAT;
    if (!s.flag('sled_ready')) return V3(RUN_PATH[0][0], 2.9, RUN_PATH[0][1]);
    for (let g = 1; g <= GATES; g++) if (!s.flag(`dug_gate_${g}`)) return V3(RUN_PATH[g][0], 1, RUN_PATH[g][1]);
    return V3(RUN_PATH[0][0], 2.9, RUN_PATH[0][1]);
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'drift', name: 'The Drift Line', done: s.flag('drift_line_done'), hint: 'The squall buried the laundry. Meow at the lumps, let him dig, and hang each piece back by its paired clothespin.' },
      { id: 'rink', name: 'The Backyard Rink', done: s.flag('rink_done'), hint: 'The puck slides until it hits something. A dog on a stay is the proudest bumper alive.' },
      { id: 'mailbox', name: 'The Mailbox Morse', done: s.flag('mailbox_done'), hint: 'Odd flags up, even flags down. All six in one stillness, before the squall scrambles them.' },
      { id: 'swing', name: 'The Swing Set Launch', done: s.flag('swing_done'), hint: 'Pump with the rhythm, let go with courage. The rooftops keep bolts, a loonie, and the view that matters.' },
      { id: 'slide', name: 'The Longest Slide', done: s.flag('island4_complete'), hint: 'Salt the gate, wake the toboggan, and dig the run open along the flag-line: she marks, he digs. Then ride it.' },
    ];
  }
}

function itemLabel(id) {
  return { frozen_mitten: 'mitten', frozen_scarf: 'scarf', frozen_sock: 'sock' }[id] ?? 'laundry';
}

/** A stiff, frost-rimed piece of laundry. */
function frozenThing(c, color) {
  const g = new THREE.Group();
  if (c === 'red') {
    const palm = P.box(0.28, 0.36, 0.1, color, { round: 0.04 }); g.add(palm);
    const thumb = P.box(0.1, 0.16, 0.08, color, { round: 0.03 }); thumb.position.set(0.17, 0.12, 0); thumb.rotation.z = -0.5; g.add(thumb);
    const cuff = P.box(0.3, 0.08, 0.11, '#f2f2f2'); g.add(cuff);
  } else if (c === 'blue') {
    const s = P.box(0.18, 0.6, 0.05, color, { round: 0.02 }); g.add(s);
    for (let i = 0; i < 3; i++) { const st = P.box(0.19, 0.04, 0.055, '#ffffff'); st.position.y = 0.12 + i * 0.16; g.add(st); }
  } else {
    const leg = P.box(0.14, 0.36, 0.12, color, { round: 0.04 }); leg.position.y = 0.1; g.add(leg);
    const foot = P.box(0.14, 0.12, 0.26, color, { round: 0.04 }); foot.position.set(0, 0.06, 0.08); g.add(foot);
  }
  return g;
}
