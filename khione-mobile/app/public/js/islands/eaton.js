// Island 2 — The Eaton Centre. A silent glass mall grown out of an island.
// Teaches: hiss. Layout, heights and puzzle logic mirror the Godot island
// (scripts/islands/eaton.gd, scripts/puzzles/mall_clock.gd, fountain_wishes.gd,
// mannequin_shop.gd, pigeon_parliament.gd, flock_finale.gd).
import * as THREE from 'three';
import { G, rng, clamp, ease, V3, damp } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';

const WATER = -0.4;
const FLOOR = 0.38;            // mall tile floor
const MALL_W = 48, MALL_D = 32, HW = 24, HD = 16;
const BALCONY_Y = 4.4, BALC_TOP = 4.55;
const ROOF_Y = 10.5, ROOF_TOP = 10.7;
const CONCRETE = '#c7c4bd', FRAME = '#5a5e66', GLASS = '#b3d9eb';

const CLOCK = V3(5.2, FLOOR, 0);
const KIOSK = V3(-6.5, FLOOR, 2.5);
const DIRECTORY = V3(3.2, FLOOR, 11);
const ESCALATORS = [[V3(15, FLOOR, 4.5), V3(19.5, BALC_TOP, 0)], [V3(-15, FLOOR, -4.5), V3(-19.5, BALC_TOP, 0)]];
const RIM_R = 3.5, RIM_Y = 1.11;
const COIN_TYPES = ['H', 'T', 'H', 'T', 'T', 'H', 'T', 'H'];
const COIN_TARGET = ['H', 'H', 'T'];
const MANNEQUIN_Z = [6.5, 7.5, 8.5, 9.5], ROOM_X = 18;
const NAIVE = [2, 1, 0, 3], TARGET = [3, 2, 1, 0], ALT_TARGET = [2, 3, 0, 1];
const GRID_ORIGIN = V3(-13, FLOOR, -9), CELL = 2, GRID_N = 4;
const VENTS = [[0, 0], [0, 3], [3, 0], [3, 3]];
const START_CELLS = [[1, 1], [2, 1], [1, 2], [2, 2]];
const SOCKET = V3(6, BALC_TOP, -13.5);
const ELEVATOR = V3(16.5, FLOOR, -7.5);
const CAB_TOP = ROOF_TOP - 0.1;
const BANNER = V3(0, ROOF_TOP, 15.2);
const PET = V3(-19.9, FLOOR, 0);
const ROBOT_HOME = V3(-13, FLOOR, -9);
const PATROL = [V3(13, FLOOR, -5.4), V3(-13, FLOOR, -5.4), V3(-13, FLOOR, 5.4), V3(13, FLOOR, 5.4)];
const DOCK = V3(0, 0.18, 38.5);
// The generated goose faces -x in its file; turn it to fly toward +z.
const GOOSE_YAW = Math.PI / 2;

const SUNSET = { sky: '#f6c08a', fog: '#f2b98a', fogNear: 45, fogFar: 125, sun: '#ffb070', sunIntensity: 2.0, hemi: 1.05, skyLight: '#ffd9b0', groundLight: '#7a6a5a', sunDir: [-10, 6, 12], exposure: 1.05 };

export default class Eaton extends Island {
  static id = 'eaton';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 4, r: 56 };
    this.clockHour = G.state.flag('mall_sunset') ? 6 : G.state.flag('mall_time_3') ? 3 : 7;
    this.occluders = [];
  }

  models() { return ['robot', 'goose', 'pigeon', 'raft']; }
  sounds() { return ['robot_whir', 'robot_flee', 'hiss', 'coconut_thunk', 'splash', 'drain', 'stone_slide', 'gull', 'pigeons', 'geese', 'wood_creak', 'gate_open', 'ocean_loop']; }
  atmosphere() {
    if (G.state.flag('mall_sunset')) return SUNSET;
    return { sky: '#a8e4ef', fog: '#a8e4ef', fogNear: 50, fogFar: 130, sun: '#fff1d6', sunIntensity: 2.3, hemi: 1.35, skyLight: '#fff4dc', groundLight: '#8a8478' };
  }
  terrainTextures() { return ['sand.jpg', 'mall_floor.jpg', 'cobble.jpg']; }

  inMall(x, z, pad = 0) { return Math.abs(x) < HW - 0.3 + pad && Math.abs(z) < HD - 0.3 + pad; }
  height(x, z) {
    if (this.inMall(x, z)) return FLOOR;
    const d = Math.hypot(x, z - 2);
    if (d < 33) return 0.3;
    if (d < 36) return 0.3 - (d - 33) * 0.1;
    if (d < 46) return -((d - 36) / 10) * 1.6;
    return -1.6 - Math.min(4.4, (d - 46) * 0.4);
  }
  splat(x, z) {
    if (this.inMall(x, z)) return [0, 1, 0];
    const d = Math.hypot(x, z - 2);
    if (d < 32.5) return [0, 0, 1];
    return [1, 0, 0];
  }
  tint(x, z) {
    if (this.inMall(x, z)) return '#ffffff';
    const h = this.height(x, z);
    const c = new THREE.Color('#ffffff');
    if (h < WATER) c.lerp(new THREE.Color('#5aa8a0'), clamp((WATER - h) / 4, 0, 0.8));
    else if (Math.hypot(x, z - 2) < 32.5) c.set('#e8e2d6');
    return c;
  }
  footstep(x, z) { return this.inMall(x, z) || G.player.pos.y > 1 ? 'paw_grass' : 'paw_sand'; }
  dustColor(x, z) { return this.inMall(x, z) ? '#f0ece4' : '#ecd6a4'; }
  spawn() { return { x: DOCK.x, z: DOCK.z, rotY: Math.PI }; }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 120, res: 120, repeat: 0.18 });
    this.makeWater({ level: WATER, size: 300, res: 110, colors: { deep: '#13a8c8', light: '#5fd8e8' } });
    this.static = new THREE.Group();
    this.buildShell();
    this.buildBalcony();
    this.buildRoof();
    this.buildShops();
    this.buildFurnishings();
    this.buildDock();
    this.buildFountain();
    this.buildClock();
    this.buildMannequins();
    this.buildPigeons();
    this.buildGeese();
    this.buildFinale();
    this.buildRobot();
    this.add(P.bake(this.static));
    this.add(this.static);
    this.setupOccluders();
    this.places([
      [V3(0, 0, 0), 9, 'The Atrium'], [V3(-20, 0, 0), 5, 'The Pet Shop'], [V3(12, 0, -11), 5.5, 'The Food Court'],
      [V3(0, 0, -13.5), 5.5, 'The North Arcade'],
    ]);
    this.trigger({ pos: V3(0, BALC_TOP, -13.5), y: BALC_TOP, radius: 6, once: true, onEnter: () => G.ui.showBanner('~ The Upper Gallery ~', 2.2) });
    this.every(() => {
      const p = G.player.pos;
      const outside = !this.inMall(p.x, p.z, 1);
      G.audio.ambient('ocean_loop', outside ? 0.22 : 0.06);
    });
  }

  places(list) {
    for (const [pos, r, name] of list) this.trigger({ pos, radius: r, y: FLOOR, yr: 2, once: true, onEnter: () => G.ui.showBanner(`~ ${name} ~`, 2.2) });
  }

  /** Static box: added to the bake group; optional collider. */
  sbox(w, h, d, x, y, z, color, { solid = true, rot = 0, top, occl = false, noStand = false, round } = {}) {
    const m = P.box(w, h, d, color, { round });
    m.position.set(x, y, z); m.rotation.y = rot;
    if (occl) { this.add(m); this.occluders.push(m); } else this.static.add(m);
    // solidBox turns opposite to rotation.y, so mirror the angle.
    if (solid) this.solidBox(x, z, w, d, y, top ?? y + h, -rot, { noStand });
    return m;
  }

  glass(w, h, d, x, y, z, { solid = true, rot = 0 } = {}) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), this.glassMat ??= new THREE.MeshLambertMaterial({ color: GLASS, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide }));
    m.geometry.translate(0, h / 2, 0);
    m.position.set(x, y, z); m.rotation.y = rot;
    m.castShadow = false; m.renderOrder = 3;
    this.static.add(m);
    if (solid) this.solidBox(x, z, w, d, y, y + h, -rot, { noStand: true });
    return m;
  }

  buildShell() {
    // Pillars.
    for (let i = 0; i < 7; i++) {
      const x = -HW + i * (MALL_W / 6);
      for (const z of [-HD, HD]) {
        if (Math.abs(x) < 4.5 && z === HD) continue;
        this.sbox(0.65, ROOF_Y, 0.65, x, 0.3, z, FRAME);
      }
    }
    for (const z of [-HD / 2, 0, HD / 2]) for (const x of [-HW, HW]) this.sbox(0.65, ROOF_Y, 0.65, x, 0.3, z, FRAME);
    // Glass walls with an 8m entrance on the south face.
    this.glass(MALL_W, ROOF_Y, 0.15, 0, 0.3, -HD);
    this.glass(0.15, ROOF_Y, MALL_D, -HW, 0.3, 0);
    this.glass(0.15, ROOF_Y, MALL_D, HW, 0.3, 0);
    const seg = (MALL_W - 8) / 2;
    this.glass(seg, ROOF_Y, 0.15, -(4 + seg / 2), 0.3, HD);
    this.glass(seg, ROOF_Y, 0.15, 4 + seg / 2, 0.3, HD);
    this.glass(8, ROOF_Y - BALCONY_Y, 0.15, 0, BALCONY_Y, HD, { solid: false });
    // Entrance canopy and sign band.
    this.sbox(10, 0.3, 3, 0, 4.0, HD + 1.5, FRAME, { solid: false, occl: true });
    const signTex = P.textCanvas('EATON CENTRE', { w: 1024, h: 128, bg: '#2f7a7a', fg: '#fff4dc', border: '#173b44', font: 'bold 78px "Baloo 2", sans-serif' });
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(12, 1.5), new THREE.MeshLambertMaterial({ map: signTex, emissive: '#ffffff', emissiveIntensity: 0.15, emissiveMap: signTex }));
    sign.position.set(0, 8.6, HD + 0.25);
    this.add(sign);
  }

  buildBalcony() {
    const mk = (w, d, x, z) => this.sbox(w, 0.3, d, x, BALCONY_Y - 0.15, z, CONCRETE, { occl: true });
    mk(MALL_W, 5, 0, -HD + 2.5);
    mk(MALL_W, 5, 0, HD - 2.5);
    mk(5, MALL_D - 10, -HW + 2.5, 0);
    mk(5, MALL_D - 10, HW - 2.5, 0);
    // Railings round the atrium opening (gaps where the escalators land).
    const rail = (w, d, x, z) => { const r = this.sbox(w, 0.9, d, x, BALC_TOP, z, FRAME, { occl: true }); return r; };
    rail(38, 0.12, 0, -HD + 5);
    rail(38, 0.12, 0, HD - 5);
    rail(0.12, 6.6, -HW + 5, -7.7); rail(0.12, 6.6, -HW + 5, 7.7);
    rail(0.12, 6.6, HW - 5, -7.7); rail(0.12, 6.6, HW - 5, 7.7);
    // Upper storefronts on the north balcony.
    const cols = ['#b3737f', '#7390b3', '#9a9a66', '#80a68c', '#a6805a'];
    for (let i = 0; i < 5; i++) {
      const x = -16 + i * 8;
      this.sbox(6, 3.2, 2.2, x, BALC_TOP, -HD + 1.4, '#d7d3cb');
      this.sbox(6.2, 0.7, 0.3, x, BALC_TOP + 2.85, -HD + 2.6, cols[i], { solid: false });
      const glow = P.box(4.6, 0.28, 0.06, cols[i], { emissive: cols[i], emissiveIntensity: 0.9 });
      glow.position.set(x, BALC_TOP + 3.06, -HD + 2.78); this.static.add(glow);
    }
    // Banners hanging from the rails.
    const bcols = ['#bf594d', '#5980b3', '#d9b34d', '#73a680'];
    for (let i = 0; i < 6; i++) {
      const x = -15 + i * 6;
      const b1 = P.box(0.06, 2.4, 1.3, bcols[i % 4]); b1.position.set(x, BALCONY_Y - 2.3, -HD + 5.1); this.static.add(b1);
    }
    // Light strips under the soffits.
    for (const [w, d, x, z] of [[36, 0.5, 0, -10.7], [36, 0.5, 0, 10.7], [0.5, 20, -18.7, 0], [0.5, 20, 18.7, 0]]) {
      const s = P.box(w, 0.08, d, '#fff0d0', { emissive: '#ffe8c0', emissiveIntensity: 1.2 });
      s.position.set(x, BALCONY_Y - 0.26, z); s.castShadow = false; this.static.add(s);
    }
    // Escalators: ramps that push against her until the mall believes it is 3 o'clock.
    this.escalators = ESCALATORS.map(([a, b]) => this.buildEscalator(a, b, 2.2));
    this.every((dt) => this.updateEscalators(dt));
  }

  buildEscalator(a, b, width) {
    const span = b.clone().sub(a);
    const flat = Math.hypot(span.x, span.z);
    const len = span.length();
    const yaw = Math.atan2(span.x, span.z);
    const pitch = -Math.atan2(span.y, flat);
    const g = new THREE.Group();
    g.position.copy(a).lerp(b, 0.5);
    g.rotation.order = 'YXZ'; g.rotation.y = yaw; g.rotation.x = pitch;
    const ramp = P.box(width, 0.25, len, '#7e848c', { base: false });
    g.add(ramp);
    // Moving tread stripes.
    const treadTex = P.textCanvas('', { w: 64, h: 256, bg: null, draw: (c) => { c.fillStyle = '#5f646b'; c.fillRect(0, 0, 64, 256); c.fillStyle = '#9aa0a8'; for (let i = 0; i < 8; i++) c.fillRect(0, i * 32, 64, 6); } });
    treadTex.wrapT = THREE.RepeatWrapping; treadTex.repeat.set(1, len / 1.2);
    const tread = new THREE.Mesh(new THREE.PlaneGeometry(width * 0.92, len), new THREE.MeshLambertMaterial({ map: treadTex }));
    tread.rotation.x = -Math.PI / 2; tread.position.y = 0.13; g.add(tread);
    for (const s of [-1, 1]) {
      const sk = P.box(0.15, 1.0, len, FRAME, { base: false });
      sk.position.set((width / 2) * s, 0.45, 0); g.add(sk);
    }
    this.add(g);
    const dir = V3(span.x, 0, span.z).normalize();
    const side = V3(dir.z, 0, -dir.x);
    const e = { a, b, dir, side, flat, width, tex: treadTex, upDir: span.clone().normalize() };
    this.surface((x, z) => {
      const rx = x - a.x, rz = z - a.z;
      const t = (rx * dir.x + rz * dir.z) / flat;
      const s = rx * side.x + rz * side.z;
      if (t < -0.02 || t > 1.02 || Math.abs(s) > width / 2) return null;
      return a.y + (b.y - a.y) * clamp(t, 0, 1) + 0.13;
    });
    // Skirts keep her on the treads.
    for (const s of [-1, 1]) {
      const c = a.clone().lerp(b, 0.5).addScaledVector(side, (width / 2 + 0.05) * s);
      this.solidBox(c.x, c.z, 0.2, flat, -1, BALC_TOP + 1.2, -yaw, { noStand: true });
    }
    return e;
  }

  updateEscalators(dt) {
    const up = G.state.flag('mall_time_3');
    const p = G.player.pos;
    for (const e of this.escalators) {
      e.tex.offset.y += dt * (up ? -0.6 : 0.6);
      // Skirts follow the ramp height so she can't step off mid-flight.
      const rx = p.x - e.a.x, rz = p.z - e.a.z;
      const t = (rx * e.dir.x + rz * e.dir.z) / e.flat;
      const s = rx * e.side.x + rz * e.side.z;
      const onRamp = t > -0.02 && t < 1.02 && Math.abs(s) < e.width / 2 + 0.1;
      const h = e.a.y + (e.b.y - e.a.y) * clamp(t, 0, 1) + 0.13;
      if (!onRamp || !G.player.grounded || Math.abs(p.y - h) > 0.3) continue;
      const push = up ? 2.4 : 7.6; // wrong-way: stronger than a running cat
      const d = up ? 1 : -1;
      p.x += e.dir.x * push * d * dt;
      p.z += e.dir.z * push * d * dt;
    }
  }

  buildRoof() {
    const strip = (w, d, x, z) => this.sbox(w, 0.4, d, x, ROOF_Y - 0.2, z, CONCRETE, { occl: true });
    strip(MALL_W + 1, 6.5, 0, -HD + 3.25);
    strip(MALL_W + 1, 6.5, 0, HD - 3.25);
    strip(6.5, MALL_D - 13, -HW + 3.25, 0);
    strip(6.5, MALL_D - 13, HW - 3.25, 0);
    // Skylight glass you can walk on.
    const sky = new THREE.Mesh(new THREE.BoxGeometry(MALL_W - 12, 0.1, MALL_D - 12.5), new THREE.MeshLambertMaterial({ color: '#d8f0fa', transparent: true, opacity: 0.18, depthWrite: false }));
    sky.position.set(0, ROOF_Y + 0.15, 0); sky.castShadow = false; this.add(sky);
    this.solidBox(0, 0, MALL_W - 12, MALL_D - 12.5, ROOF_Y, ROOF_Y + 0.2);
    for (let i = 0; i < 10; i++) this.sbox(0.25, 0.4, MALL_D - 13, -18 + i * 4, ROOF_Y - 0.3, 0, FRAME, { solid: false });
    // Parapet lips.
    for (const [w, d, x, z] of [[MALL_W + 1.2, 0.3, 0, -HD], [0.3, MALL_D + 1.2, -HW, 0], [0.3, MALL_D + 1.2, HW, 0]]) this.sbox(w, 0.5, d, x, ROOF_TOP, z, '#bdb9b1');
    this.sbox(MALL_W / 2 - 3, 0.5, 0.3, -HW / 2 - 1.5, ROOF_TOP, HD, '#bdb9b1');
    this.sbox(MALL_W / 2 - 3, 0.5, 0.3, HW / 2 + 1.5, ROOF_TOP, HD, '#bdb9b1');
    // HVAC units.
    for (const [x, w, h, d] of [[-15, 2.2, 1.2, 1.8], [10, 1.8, 1.0, 1.6], [-18.5, 1.2, 0.9, 1.2], [20, 1.6, 1.1, 1.4]]) this.sbox(w, h, d, x, ROOF_TOP, -HD + 3, '#8b9098');
    // Shutters over the skylight until the crank turns.
    this.shutters = [];
    for (let i = 0; i < 6; i++) {
      const s = P.box(6.0, 0.15, MALL_D - 12.5, '#8c8f96');
      const open = G.state.flag('skylight_open');
      s.position.set(open ? this.shutterOpenX(i) : -15.5 + i * 6.2, ROOF_Y + 0.25, 0);
      s.castShadow = false;
      this.add(s); this.occluders.push(s); this.shutters.push(s);
    }
  }
  shutterOpenX(i) { const dir = i < 3 ? -1 : 1; const order = i < 3 ? 2 - i : i - 3; return dir * (20.6 + 0.9 * order); }

  shopUnit(x, z, facing, accent, depth = 3, width = 5) {
    const rot = (v) => v.applyAxisAngle(V3(0, 1, 0), facing);
    const back = rot(V3(0, 0, -depth / 2 - 0.05)), front = rot(V3(0, 0, depth / 2 - 0.4));
    this.sbox(width, 3.6, depth, x + back.x, 0.3, z + back.z, '#dcd8d0', { rot: facing });
    this.glass(width - 0.8, 2.6, 0.1, x + front.x, 0.45, z + front.z, { rot: facing });
    const sp = rot(V3(0, 0, depth / 2 - 0.2));
    const sign = P.box(width - 0.2, 0.9, 0.35, accent); sign.position.set(x + sp.x, 3.1, z + sp.z); sign.rotation.y = facing; this.static.add(sign);
    const gp = rot(V3(0, 0, depth / 2 + 0.02));
    const glow = P.box(width - 1.6, 0.3, 0.06, '#ffffff', { emissive: accent, emissiveIntensity: 0.8 }); glow.position.set(x + gp.x, 3.4, z + gp.z); glow.rotation.y = facing; this.static.add(glow);
    for (const s of [-1, 1]) {
      const ap = rot(V3(s * (width - 1) / 4, 0, depth / 2 + 0.15));
      const awn = P.box((width - 1) / 2, 0.06, 0.9, s < 0 ? accent : '#efede6', { base: false });
      awn.position.set(x + ap.x, 3.02, z + ap.z); awn.rotation.order = 'YXZ'; awn.rotation.y = facing; awn.rotation.x = 0.28;
      this.static.add(awn);
    }
    const bc = ['#d99a4d', '#80a6cc', '#ccbf99'];
    for (let k = 0; k < 3; k++) {
      const mp = rot(V3(-1 + (k % 2) * 0.45, 0, 0.5));
      const b = P.box(0.35, 0.35, 0.35, bc[k]); b.position.set(x + mp.x, FLOOR + (k > 1 ? 0.36 : 0), z + mp.z); this.static.add(b);
    }
  }

  buildShops() {
    this.shopUnit(21, -10, -Math.PI / 2, '#bf6659');
    this.shopUnit(21, 0, -Math.PI / 2, '#668cb3');
    this.shopUnit(-21, -10, Math.PI / 2, '#8c73a6');
    this.shopUnit(-21, 10, Math.PI / 2, '#598c80');
    this.shopUnit(-18, -HD + 1.6, 0, '#b88c4d', 2.6, 5.4);
    this.shopUnit(-8, -HD + 1.6, 0, '#6699a6', 2.6, 5.4);
    this.shopUnit(8, -HD + 1.6, 0, '#9e6b8c', 2.6, 5.4);
    // The pet shop: one collar on a stand, and a door that will not open.
    this.sbox(3, 3.6, 6, -22.5, 0.3, 0, '#d7d3cb');
    this.glass(0.1, 2.4, 4.4, -19.9, 0.5, 0);
    const psign = P.box(0.35, 0.9, 5.4, '#739973'); psign.position.set(-19.8, 3.1, 0); this.static.add(psign);
    const pglow = P.box(0.06, 0.3, 4, '#ffffff', { emissive: '#99d999', emissiveIntensity: 0.9 }); pglow.position.set(-19.6, 3.4, 0); this.static.add(pglow);
    const stand = P.cyl(0.08, 0.12, 0.9, FRAME); stand.position.set(-20.8, FLOOR, 0); this.add(stand);
    const collar = P.torus(0.17, 0.035, '#8c5a3c'); collar.position.set(-20.8, 1.38, 0); collar.rotation.x = 0.4; this.add(collar);
    const charm = P.sphere(0.05, '#ffd24a', { emissive: '#ffb020', emissiveIntensity: 0.3 }); charm.position.set(-20.8, 1.2, 0.08); this.add(charm);
    this.sense(collar, { warm: () => !G.state.flag('pet_window_seen'), height: 0 });
    this.interact({
      pos: V3(-19.2, FLOOR, 0), obj: collar, radius: 2.4, icon: '\u{1F440}', label: 'Peer through the glass',
      use: () => {
        G.state.set('pet_window_seen');
        G.ui.say('One collar on a stand. The tag is blank, but the charm is a tiny paw. The door will not open.');
        G.state.addArtifact('collar', 'eaton', 'A Collar in the Pet Shop', 'One collar on a stand, tag blank, its charm a tiny paw — the same paw as the locket. The one door no key opens.');
      },
    });
  }

  buildFurnishings() {
    // Benches ringing the fountain.
    for (let i = 0; i < 4; i++) {
      const a = (Math.PI * 2 * i) / 4 + Math.PI / 4;
      const x = Math.cos(a) * 5.8, z = Math.sin(a) * 5.8;
      const g = new THREE.Group();
      const seat = P.box(1.8, 0.1, 0.55, '#a0662e'); seat.position.y = 0.45; g.add(seat);
      const back = P.box(1.8, 0.45, 0.08, '#a0662e'); back.position.set(0, 0.55, -0.24); g.add(back);
      for (const sx of [-0.75, 0.75]) { const leg = P.box(0.08, 0.45, 0.5, FRAME); leg.position.set(sx, 0, 0); g.add(leg); }
      g.position.set(x, FLOOR, z); g.rotation.y = Math.atan2(-x, -z) + Math.PI;
      this.static.add(g);
      this.solidBox(x, z, 1.8, 0.6, FLOOR, FLOOR + 0.55, -g.rotation.y);
    }
    // Food court: counter, menu board, parasol tables.
    this.sbox(4.6, 1.05, 1.2, 13, FLOOR, -13.6, '#80604a');
    this.sbox(4.6, 0.12, 1.5, 13, FLOOR + 1.05, -13.6, '#d9d2c2', { solid: false });
    const menu = P.box(3.0, 0.8, 0.06, '#ffd27a', { emissive: '#ffb04a', emissiveIntensity: 0.6 }); menu.position.set(13, 2.6, -14.46); this.static.add(menu);
    for (let i = 0; i < 4; i++) {
      const tx = 9.5 + (i % 2) * 3.4, tz = -10.8 + Math.floor(i / 2) * 3.2;
      const top = P.cyl(0.6, 0.6, 0.06, '#efe9dc'); top.position.set(tx, FLOOR + 0.72, tz); this.static.add(top);
      const leg = P.cyl(0.06, 0.06, 0.72, FRAME); leg.position.set(tx, FLOOR, tz); this.static.add(leg);
      const pole = P.cyl(0.035, 0.035, 2.4, FRAME); pole.position.set(tx, FLOOR + 0.72, tz); this.static.add(pole);
      const umb = P.cone(1.35, 0.5, i % 2 ? '#668cb3' : '#d9735a', { seg: 10 }); umb.position.set(tx, FLOOR + 2.9, tz); this.static.add(umb);
      this.solidCyl(tx, tz, 0.65, FLOOR, FLOOR + 0.78);
    }
    // Lounge, planters with indoor trees, bins.
    this.sbox(5.4, 0.04, 3.6, -12, FLOOR, 4.5, '#8c666b', { solid: false });
    for (const [x, z] of [[-9, -7], [9, 7], [-9, 7], [9, -7], [-5.5, 14], [5.5, 14], [-17, -7], [13.5, 11.8]]) {
      this.sbox(1.6, 0.7, 1.6, x, FLOOR, z, '#a8a49c', { round: 0.08 });
      const b = P.bush(0.75, '#4fa83a', x * 7 + z);
      b.position.set(x, FLOOR + 0.6, z); b.scale.set(1, 1.5, 1); this.static.add(b);
    }
    for (const [x, z] of [[6.5, 11.5], [-6.5, -10.5], [19, 4]]) { this.sbox(0.6, 0.75, 0.6, x, FLOOR, z, '#7a7f88', { round: 0.1 }); }
    // Wayfinding totem.
    this.sbox(0.9, 2.3, 0.28, -6, FLOOR, 8, FRAME);
    // Pendant lamps over the walkways.
    for (const x of [-18, -12, -6, 0, 6, 12, 18]) for (const z of [-13.5, 13.5]) {
      const shade = P.cone(0.4, 0.3, '#fff0d0', { emissive: '#ffe0a0', emissiveIntensity: 0.9, seg: 10 });
      shade.position.set(x, ROOF_Y - 1.9, z); shade.castShadow = false; this.static.add(shade);
    }
  }

  buildDock() {
    for (let i = 0; i < 7; i++) this.sbox(2.4, 0.15, 1.7, 0, 0.03 - i * 0.015, 29 + i * 1.8, '#a08060');
    for (const side of [-1, 1]) for (let i = 0; i < 3; i++) {
      const post = P.cyl(0.12, 0.14, 1.6, '#735f4a'); post.position.set(side * 1.1, -1.2, 30 + i * 4.5); this.static.add(post);
    }
    this.sbox(4, 0.1, 13, 0, 0.3, 22.5, '#bdb9b1', { solid: false });
    this.sbox(10, 0.1, 3, 0, 0.3, 17.5, '#c4c0b8', { solid: false });
    for (const side of [-1, 1]) {
      for (const z of [18.5, 22.5, 26.5]) this.sbox(0.22, 0.7, 0.22, side * 2.5, 0.3, z, '#8b9098', { round: 0.06 });
      const pole = P.cyl(0.05, 0.07, 5, '#8b9098'); pole.position.set(side * 4.2, 0.3, 17.5); this.static.add(pole);
      const fl = P.box(0.06, 1.4, 0.9, '#2f7a7a'); fl.position.set(side * 4.2, 3.6, 18); this.static.add(fl);
    }
    // The raft that brought her, tied up at the end.
    const raft = model('raft', { size: 2.6 }); raft.position.set(1.8, WATER - 0.05, 40.5); raft.rotation.y = 0.4; this.add(raft);
    // Once the flock has flown, the raft can always carry her on.
    this.interact({
      pos: V3(1.0, 0.18, 39.6), obj: raft, radius: 2.4, icon: '\u26F5',
      enabled: () => G.state.flag('island2_complete'),
      label: "Sail on to Prince's Island",
      use: () => G.events.emit('travel', 'calgary'),
    });
  }

  // ── The fountain of small wishes ──────────────────────
  buildFountain() {
    const basin = P.cyl(3.4, 3.6, 0.73, '#aaa69f', { seg: 32 }); basin.position.y = FLOOR; this.add(basin);
    this.solidCyl(0, 0, RIM_R + 0.05, FLOOR, RIM_Y - 0.04);
    this.fountainWater = new THREE.Mesh(new THREE.CircleGeometry(3.05, 32), new THREE.MeshLambertMaterial({ color: '#3a8fb0', transparent: true, opacity: 0.72, depthWrite: false }));
    this.fountainWater.rotation.x = -Math.PI / 2; this.fountainWater.position.y = 1.02; this.fountainWater.renderOrder = 2; this.add(this.fountainWater);
    const stem = P.cyl(0.5, 0.9, 1.2, '#9c988f'); stem.position.y = 0.85; this.add(stem);
    const upper = P.cyl(1.5, 1.6, 0.28, '#aaa69f'); upper.position.y = 2.0; this.add(upper);
    const uw = new THREE.Mesh(new THREE.CircleGeometry(1.3, 24), this.fountainWater.material); uw.rotation.x = -Math.PI / 2; uw.position.y = 2.3; this.add(uw);
    this.solidCyl(0, 0, 1.6, FLOOR, 2.3);
    // Little jets.
    this.every(() => { if (G.state.flag('fountain_wish_made')) return; if (Math.random() < 0.3) G.fx.spawn((Math.random() - 0.5) * 0.4, 2.35, (Math.random() - 0.5) * 0.4, { vy: 2.2, vx: (Math.random() - 0.5) * 1.5, vz: (Math.random() - 0.5) * 1.5, gravity: 9, size: 0.1, life: 0.6, color: '#d8f4ff' }); });
    // Mosaic under the water: start mark, then heads, heads, tails.
    const mosaic = new THREE.Group();
    const start = P.box(0.3, 0.02, 0.3, '#6b7fb3'); start.position.set(-1.15, 0, 0.9); mosaic.add(start);
    COIN_TARGET.forEach((t, i) => {
      const tile = P.box(0.5, 0.02, 0.5, '#e8e8ef'); tile.position.set(-0.6 + i * 0.6, 0, 0.9); mosaic.add(tile);
      const mark = t === 'H' ? P.cyl(0.11, 0.11, 0.03, '#c99a2e', { seg: 12 }) : P.box(0.34, 0.03, 0.09, '#c99a2e');
      mark.position.set(-0.6 + i * 0.6, 0.015, 0.9); mosaic.add(mark);
    });
    mosaic.position.y = 0.97; this.add(mosaic);
    this.sense(mosaic, { warm: () => !G.state.flag('fountain_wish_made'), height: 0.2 });
    this.interact({
      pos: V3(0, FLOOR, 0), obj: this.fountainWater, radius: 4.4, priority: -1, icon: '\u{1F440}',
      label: () => (G.state.flag('fountain_wish_made') ? null : 'Peer into the fountain'),
      use: () => this.openMosaic(),
    });
    // Coins on the ledge.
    this.coins = [];
    this.coinProgress = 0;
    const solved = G.state.flag('fountain_wish_made');
    COIN_TYPES.forEach((type, i) => {
      const a = (i / 8) * Math.PI * 2 + Math.PI / 8;
      const home = V3(Math.cos(a) * RIM_R, RIM_Y, Math.sin(a) * RIM_R);
      const coin = new THREE.Group();
      const disc = P.cyl(0.16, 0.16, 0.05, '#f2cc4d', { emissive: '#b08a20', emissiveIntensity: 0.25, seg: 16 }); coin.add(disc);
      const mark = type === 'H' ? P.cyl(0.05, 0.05, 0.02, '#9e781f', { seg: 10 }) : P.box(0.2, 0.02, 0.05, '#9e781f');
      mark.position.y = 0.05; coin.add(mark);
      coin.position.copy(home);
      if (solved) coin.position.set(home.x * 0.6, 0.98, home.z * 0.6);
      this.add(coin);
      const c = { coin, type, home, pushed: solved };
      this.coins.push(c);
      this.interact({
        obj: coin, radius: 1.5, icon: '\u{1FA99}',
        label: () => (c.pushed || this.coinResetting || G.state.flag('fountain_wish_made') ? null : `Nudge the ${type === 'H' ? 'dotted' : 'barred'} coin`),
        use: () => this.pushCoin(c),
      });
    });
    if (solved && !G.state.flag('took_brass_key')) this.spawnKey();
    if (solved) { this.fountainWater.position.y = 0.75; this.fountainWater.material.opacity = 0.35; }
  }

  openMosaic() {
    const c = document.createElement('canvas'); c.width = 600; c.height = 260; c.className = 'art-img';
    const g = c.getContext('2d');
    g.fillStyle = '#3a8fb0'; g.fillRect(0, 0, 600, 260);
    g.fillStyle = 'rgba(255,255,255,0.12)'; for (let i = 0; i < 40; i++) g.fillRect((i * 83) % 600, (i * 47) % 260, 40, 4);
    g.fillStyle = '#6b7fb3'; g.fillRect(40, 100, 60, 60);
    COIN_TARGET.forEach((t, i) => {
      const x = 150 + i * 140;
      g.fillStyle = '#e8e8ef'; g.fillRect(x, 70, 120, 120);
      g.fillStyle = '#c99a2e';
      if (t === 'H') { g.beginPath(); g.arc(x + 60, 130, 26, 0, Math.PI * 2); g.fill(); } else g.fillRect(x + 18, 118, 84, 24);
    });
    G.ui.panel('A mosaic under the water', c, { buttons: [{ label: 'Close', onClick: (close) => close() }] });
  }

  pushCoin(c) {
    if (c.pushed || this.coinResetting) return;
    c.pushed = true;
    G.player.emote('attack', 1.6);
    G.audio.sfx('splash', { vol: 0.5, rate: 1.7 });
    const to = V3(c.home.x * 0.62, 0.98, c.home.z * 0.62);
    G.tween(c.coin.position, { x: to.x, y: to.y, z: to.z }, 0.5, ease.in);
    if (G.state.flag('fountain_wish_made')) return;
    if (c.type === COIN_TARGET[this.coinProgress]) {
      this.coinProgress++;
      G.audio.tone(520 + this.coinProgress * 130, { dur: 0.5, vol: 0.25 });
      if (this.coinProgress >= COIN_TARGET.length) this.solveFountain();
    } else this.failFountain();
  }

  async failFountain() {
    this.coinResetting = true;
    G.audio.sfx('pigeons', { vol: 0.6 });
    G.ui.say('A pigeon lands on Khione’s head. It offers no advice.');
    const pg = model('pigeon', { height: 0.35 });
    pg.position.set(0, 3, 0);
    G.player.root.add(pg);
    G.tween(pg.position, { y: 1.02 }, 0.5, ease.outBounce);
    const bob = this.every(() => { if (!pg.parent) return true; pg.rotation.x = Math.sin(G.time * 9) * 0.12; });
    await G.wait(1.6);
    this.coinProgress = 0;
    for (const c of this.coins) if (c.pushed) { c.pushed = false; G.tween(c.coin.position, { x: c.home.x, y: c.home.y, z: c.home.z }, 0.5, ease.outBack); }
    G.audio.sfx('coconut_thunk', { vol: 0.4, rate: 1.8 });
    G.ui.toast('The soaked coins clink back onto the ledge, unimpressed.', '\u{1FA99}');
    this.coinResetting = false;
    await G.wait(2.6);
    G.audio.sfx('pigeons', { vol: 0.4 });
    G.tween(pg.position, { y: 4, x: 1.5 }, 1.0, ease.in).then(() => pg.removeFromParent());
    void bob;
  }

  async solveFountain() {
    G.state.set('fountain_wish_made');
    G.ui.celebrate('A wish, paid in kind!', 'The Fountain of Small Wishes');
    G.audio.sfx('drain', { vol: 0.9 });
    G.tween(this.fountainWater.position, { y: 0.75 }, 2.0);
    G.tween(this.fountainWater.material, { opacity: 0.35 }, 2.0);
    await G.wait(1.2);
    this.spawnKey();
    G.ui.say('The fountain sighs and drains. Something brass glints at the bottom.');
  }

  spawnKey() {
    const key = new THREE.Group();
    const bow = P.torus(0.09, 0.03, '#e6b84d'); bow.rotation.x = Math.PI / 2; bow.position.x = -0.1; key.add(bow);
    const shaft = P.box(0.26, 0.04, 0.04, '#e6b84d', { base: false }); shaft.position.x = 0.08; key.add(shaft);
    const tooth = P.box(0.04, 0.04, 0.08, '#e6b84d', { base: false }); tooth.position.set(0.18, 0, 0.04); key.add(tooth);
    key.position.y = 0.35;
    // Lift it to the rim so a cat can reach it.
    this.pickup({ id: 'brass_key', pos: V3(0, RIM_Y - 0.25, RIM_R + 0.4), obj: key, radius: 1.6 });
  }

  // ── The wrong-way stairs: clock, kiosk, directory ─────
  buildClock() {
    const pole = P.cyl(0.18, 0.22, 4.5, FRAME); pole.position.copy(CLOCK); this.add(pole);
    this.solidCyl(CLOCK.x, CLOCK.z, 0.3, FLOOR, FLOOR + 4.5);
    const face = P.cyl(0.95, 0.95, 0.12, '#f5f2e6', { base: false, seg: 32 }); face.rotation.x = Math.PI / 2; face.position.set(CLOCK.x, 5.3, CLOCK.z); this.add(face);
    const rim = P.torus(0.95, 0.07, '#8c6b4d'); rim.position.set(CLOCK.x, 5.3, CLOCK.z - 0.02); this.add(rim);
    // Both faces: the clock hangs in the atrium, readable from either side.
    for (const side of [1, -1]) {
      for (let h = 0; h < 12; h++) {
        const ang = (h / 12) * Math.PI * 2;
        const tick = P.box(0.06, h % 3 ? 0.12 : 0.22, 0.02, '#33281a', { base: false });
        tick.position.set(CLOCK.x + Math.sin(ang) * 0.78 * side, 5.3 + Math.cos(ang) * 0.78, CLOCK.z + 0.07 * side);
        tick.rotation.z = -ang * side; this.add(tick);
      }
      const minute = P.box(0.05, 0.72, 0.02, '#33281a', { base: false }); minute.position.set(CLOCK.x, 5.3 + 0.36, CLOCK.z + 0.09 * side); this.add(minute);
    }
    this.hands = [1, -1].map((side) => {
      const pivot = new THREE.Group(); pivot.position.set(CLOCK.x, 5.3, CLOCK.z + 0.11 * side);
      const hand = P.box(0.09, 0.52, 0.02, '#7a2e1f', { base: false }); hand.position.y = 0.26; pivot.add(hand);
      pivot.userData.side = side;
      this.add(pivot); return pivot;
    });
    this.setHands(false);
    this.sense(face, { warm: () => !G.state.flag('mall_time_3') || (G.state.flag('skylight_open') && !G.state.flag('mall_sunset')), height: 0, radius: 13 });
    this.interact({
      pos: V3(CLOCK.x, FLOOR, CLOCK.z), obj: pole, radius: 1.8, icon: '\u{1F570}️', label: 'Bat at the clock hands',
      use: () => this.advanceClock(),
    });
    // Flower kiosk with its sprinkler.
    const cart = new THREE.Group();
    const body = P.box(1.8, 0.75, 0.9, '#b3805a', { round: 0.06 }); body.position.y = 0.07; cart.add(body);
    for (const sx of [-0.7, 0.7]) { const w = P.cyl(0.18, 0.18, 0.08, '#333', { base: false }); w.rotation.x = Math.PI / 2; w.position.set(sx, 0.12, 0.47); cart.add(w); }
    const arm = P.cyl(0.03, 0.03, 2.2, FRAME); arm.position.set(-1.1, 0, 0); cart.add(arm);
    const horiz = P.cyl(0.03, 0.03, 1.1, FRAME, { base: false }); horiz.rotation.z = Math.PI / 2; horiz.position.set(-0.55, 2.2, 0); cart.add(horiz);
    const head = P.sphere(0.08, FRAME); head.position.set(0, 2.18, 0); cart.add(head);
    cart.position.copy(KIOSK); this.add(cart);
    this.solidBox(KIOSK.x, KIOSK.z, 1.9, 1.0, FLOOR, FLOOR + 0.9);
    this.flowers = ['#ff6b8a', '#ffd24a', '#b58cff'].map((col, i) => {
      const f = new THREE.Group();
      for (let k = 0; k < 4; k++) { const p = P.sphere(0.08, col, { seg: 8 }); p.position.set((k - 1.5) * 0.08, 0.25 + (k % 2) * 0.05, (k % 2) * 0.06); f.add(p); }
      const st = P.cyl(0.015, 0.015, 0.25, '#3e8a3a', { seg: 4 }); f.add(st);
      f.position.set(KIOSK.x - 0.55 + i * 0.55, FLOOR + 0.82, KIOSK.z);
      f.scale.setScalar(G.state.flag('mall_time_3') ? 1.9 : 1);
      this.add(f); return f;
    });
    // Directory board by the doors.
    const board = P.sign(['EATON CENTRE', 'DIRECTORY'], { w: 1.4, h: 0.9, post: 0.9, color: '#5a5e66', bg: '#fff4dc', font: 'bold 58px "Baloo 2", sans-serif' });
    board.position.copy(DIRECTORY); board.rotation.y = Math.PI; this.add(board);
    this.solidCyl(DIRECTORY.x, DIRECTORY.z, 0.4, FLOOR, FLOOR + 1.8);
    this.sense(board, { warm: () => !G.state.flag('mall_time_3'), height: 1.3 });
    this.interact({ obj: board, radius: 2.0, icon: '\u{1F4D6}', label: 'Read the directory', use: () => this.openDirectory() });
  }

  setHands(anim = true) {
    for (const pv of this.hands) {
      const side = pv.userData.side;
      if (anim) {
        const to = pv.rotation.z - (Math.PI * 2 / 12) * side;
        G.tween(pv.rotation, { z: to }, 0.3, ease.outBack).then(() => { pv.rotation.z = -Math.PI * 2 * this.clockHour / 12 * side; });
      } else pv.rotation.z = -Math.PI * 2 * this.clockHour / 12 * side;
    }
  }

  openDirectory() {
    G.ui.panel('Eaton Centre · Directory', `
      <div class="letter" style="font-family:var(--font);font-size:16px;line-height:1.7;transform:none">
        Pet Shop …… by appointment only<br>
        Home Goods …… closed for inventory<br>
        Flower Kiosk …… watered daily at 3 o’clock<br>
        Food Court …… gone for lunch<br>
        Glass Elevator …… out of service
      </div><p style="text-align:center"><small>The clock above the fountain hasn’t moved in years.</small></p>`,
    { buttons: [{ label: 'Close', onClick: (close) => close() }] });
  }

  advanceClock() {
    this.clockHour = (this.clockHour % 12) + 1;
    G.player.emote('attack', 1.8);
    G.audio.sfx('coconut_thunk', { vol: 0.5, rate: 1.6 });
    this.setHands(true);
    G.state.set('clock_at_6', this.clockHour === 6);
    if (this.clockHour === 3) {
      const first = !G.state.flag('mall_time_3');
      G.state.set('mall_time_3');
      if (first) this.timeIsThree(); else G.ui.toast('3 o’clock. The kiosk drinks happily.', '\u{1F33C}');
    } else if (this.clockHour === 6 && G.state.flag('skylight_open')) {
      if (!G.state.flag('mall_sunset')) this.sunset();
    } else G.ui.toast(`Clunk. The hands settle on ${this.clockHour} o’clock. Nothing happens.`, '\u{1F570}️');
  }

  async timeIsThree() {
    G.ui.celebrate('3 o’clock!', 'The Wrong-Way Stairs');
    G.ui.say('Somewhere, water is running. The mall believes it is 3 o’clock.');
    const t0 = G.time;
    this.every(() => {
      if (G.time - t0 > 7) return true;
      for (let k = 0; k < 3; k++) G.fx.spawn(KIOSK.x + (Math.random() - 0.5) * 0.3, FLOOR + 2.1, KIOSK.z + (Math.random() - 0.5) * 0.3, { vx: (Math.random() - 0.5) * 2, vz: (Math.random() - 0.5) * 2, vy: -1, gravity: 6, size: 0.09, life: 0.9, color: '#bfe6ff' });
    });
    for (let i = 0; i < 3; i++) setTimeout(() => G.audio.sfx('splash', { vol: 0.3, rate: 1.3 + i * 0.15 }), (0.5 + i * 0.7) * 1000);
    this.flowers.forEach((f, i) => setTimeout(() => G.tween(f.scale, { x: 1.9, y: 1.9, z: 1.9 }, 1.6, ease.outElastic), 400 + i * 300));
    await G.wait(3.5);
    G.ui.toast('The stairs run kindly now. The clock is hers.', '\u{1F570}️');
  }

  // ── The mannequin quartet ──────────────────────────────
  buildMannequins() {
    const WALL = '#bdb8ad';
    this.sbox(0.3, 3.6, 5.0, 19.6, 0.3, 8, WALL);
    this.sbox(3.9, 3.6, 0.3, 17.75, 0.3, 5.6, WALL);
    this.sbox(3.9, 3.6, 0.3, 17.75, 0.3, 10.4, WALL);
    this.sbox(3.9, 0.3, 5.2, 17.75, 3.8, 8, WALL, { solid: false, occl: true });
    for (const z of [6.35, 9.65]) this.glass(0.1, 3.2, 1.5, 15.95, 0.3, z);
    this.sbox(0.35, 0.9, 5.4, 15.8, 3.4, 8, '#80669e', { solid: false });
    // Door.
    this.door = P.box(0.12, 3.0, 1.8, '#47424d');
    this.door.position.set(15.95, 0.3, 8); this.add(this.door);
    this.doorSolid = this.solidBox(15.95, 8, 0.2, 1.8, 0, 3.3, 0, { noStand: true });
    if (G.state.flag('mannequin_shop_open')) { this.door.position.y = 3.0; this.doorSolid.enabled = false; }
    this.interact({
      pos: V3(15.4, FLOOR, 8), obj: this.door, radius: 1.8, icon: '\u{1F511}',
      label: () => (G.state.flag('mannequin_shop_open') ? null : G.state.has('brass_key') ? 'Unlock the shop door' : 'Try the shop door'),
      use: () => this.tryDoor(),
    });
    // Poster printed through the right-hand pane.
    const posterTex = this.posterTexture(false);
    const poster = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 1.25), new THREE.MeshLambertMaterial({ map: posterTex, transparent: true, side: THREE.DoubleSide }));
    poster.rotation.y = -Math.PI / 2; poster.position.set(15.88, 2.05, 9.65); this.add(poster);
    this.sense(poster, { warm: () => G.state.flag('mannequin_shop_open') && !G.state.flag('mannequins_posed'), height: 0 });
    this.interact({ pos: V3(15.9, FLOOR, 9.65), obj: poster, radius: 2.2, icon: '\u{1F440}', label: 'Study the poster', priority: -0.5, use: () => this.openPoster() });
    // Four mannequins on turntables.
    const posed = G.state.flag('mannequins_posed');
    this.facings = posed ? [...TARGET] : [0, 0, 0, 0];
    this.lastConfig = this.facings.join();
    this.mannequins = MANNEQUIN_Z.map((z, i) => {
      const ped = P.cyl(0.45, 0.5, 0.25, '#8a8f99'); ped.position.set(ROOM_X, FLOOR, z); this.add(ped);
      const m = new THREE.Group();
      const torso = P.cyl(0.18, 0.24, 0.85, '#e0dbd1'); torso.position.y = 0.15; m.add(torso);
      const head = P.sphere(0.16, '#e0dbd1'); head.position.y = 1.2; m.add(head);
      const nose = P.cone(0.05, 0.12, '#c96b4d'); nose.rotation.x = Math.PI / 2; nose.position.set(0, 1.2, 0.17); m.add(nose);
      const badge = P.box(0.16, 0.22, 0.04, '#b34d4d', { base: false }); badge.position.set(0, 0.75, 0.22); m.add(badge);
      for (const s of [-1, 1]) { const arm = P.box(0.08, 0.5, 0.08, '#e0dbd1', { base: false }); arm.position.set(0.3 * s, 0.6, 0); arm.rotation.z = -0.35 * s; m.add(arm); }
      m.position.set(ROOM_X, FLOOR + 0.25, z);
      m.rotation.y = -this.facings[i] * Math.PI / 2;
      this.add(m);
      if (i === 1) { const drum = P.cyl(0.22, 0.22, 0.32, '#c94d4d'); drum.position.set(ROOM_X - 0.7, FLOOR, z); this.add(drum); }
      this.solidCyl(ROOM_X, z, 0.42, FLOOR, FLOOR + 1.5);
      this.interact({
        pos: V3(ROOM_X - 0.75, FLOOR, z), obj: m, radius: 1.0, icon: '\u{1F504}',
        label: () => (G.state.flag('mannequins_posed') || !G.state.flag('mannequin_shop_open') ? null : 'Turn the mannequin'),
        use: () => this.rotateMannequin(i),
      });
      return m;
    });
    if (posed && !G.state.flag('took_skylight_crank')) this.spawnCrank();
  }

  posterTexture(mirrored) {
    return P.textCanvas('', {
      w: 512, h: 460, bg: '#efe6cc', border: '#8a7a5a', draw: (g, w) => {
        g.save();
        if (mirrored) { g.translate(w, 0); g.scale(-1, 1); }
        g.fillStyle = '#4d4030'; g.font = 'bold 34px "Baloo 2", sans-serif'; g.textAlign = 'center';
        g.fillText('★ THE QUARTET ★', w / 2, 70);
        g.strokeStyle = '#4d4030'; g.fillStyle = '#4d4030'; g.lineWidth = 12; g.lineCap = 'round';
        const xs = [90, 200, 310, 420], y = 220;
        // left arrow
        g.beginPath(); g.moveTo(xs[0] + 40, y); g.lineTo(xs[0] - 30, y); g.stroke();
        g.beginPath(); g.moveTo(xs[0] - 42, y); g.lineTo(xs[0] - 10, y - 30); g.lineTo(xs[0] - 10, y + 30); g.closePath(); g.fill();
        // dot (faces you)
        g.beginPath(); g.arc(xs[1], y, 26, 0, Math.PI * 2); g.fill();
        // right arrow
        g.beginPath(); g.moveTo(xs[2] - 40, y); g.lineTo(xs[2] + 30, y); g.stroke();
        g.beginPath(); g.moveTo(xs[2] + 42, y); g.lineTo(xs[2] + 10, y - 30); g.lineTo(xs[2] + 10, y + 30); g.closePath(); g.fill();
        // cross (faces away)
        g.beginPath(); g.moveTo(xs[3] - 28, y - 28); g.lineTo(xs[3] + 28, y + 28); g.moveTo(xs[3] + 28, y - 28); g.lineTo(xs[3] - 28, y + 28); g.stroke();
        g.fillRect(90, 330, 330, 14);
        g.font = 'bold 26px "Baloo 2", sans-serif';
        g.fillText('live tonight · one pose only', w / 2, 400);
        g.restore();
      },
    });
  }

  openPoster() {
    const inside = G.player.pos.x > 16.0;
    const tex = this.posterTexture(inside);
    const c = tex.image; c.className = 'art-img';
    G.ui.panel(inside ? 'The poster, from inside the glass' : 'A poster on the shop window', `<p style="text-align:center"><small>${inside ? 'Everything printed on glass reads backwards from in here.' : 'A dusty band poster, printed right onto the glass.'}</small></p>`, { buttons: [{ label: 'Close', onClick: (close) => close() }] }).prepend(c);
  }

  tryDoor() {
    if (G.state.flag('mannequin_shop_open')) return;
    if (!G.state.has('brass_key')) {
      G.audio.sfx('coconut_thunk', { vol: 0.4, rate: 1.3 });
      G.ui.say('Locked. The keyhole is small, brass, and smug.');
      return;
    }
    G.state.set('mannequin_shop_open');
    G.audio.sfx('coconut_thunk', { vol: 0.6, rate: 1.1 }); G.audio.sfx('stone_slide', { vol: 0.5, rate: 1.2 });
    this.doorSolid.enabled = false;
    G.tween(this.door.position, { y: 3.0 }, 1.2, ease.inOut);
    G.ui.say('The brass key turns like it never left. The shop exhales dust.');
  }

  rotateMannequin(i) {
    if (G.state.flag('mannequins_posed')) return;
    this.facings[i] = (this.facings[i] + 1) % 4;
    G.audio.sfx('stone_slide', { vol: 0.35, rate: 1.7 });
    const m = this.mannequins[i];
    G.tween(m.rotation, { y: m.rotation.y - Math.PI / 2 }, 0.35, ease.outBack);
    const cfg = this.facings.join();
    if (cfg === this.lastConfig) return;
    this.lastConfig = cfg;
    if (cfg === TARGET.join() || cfg === ALT_TARGET.join()) this.solveMannequins();
    else if (cfg === NAIVE.join()) {
      G.audio.sfx('fail', { vol: 0.4, rate: 1.4 });
      G.ui.say('They strike the pose… hold it… and slump. Something reads backwards.');
    }
  }

  async solveMannequins() {
    G.state.set('mannequins_posed');
    G.audio.sfx('whisker_shimmer', { vol: 0.6, rate: 0.9 });
    G.ui.celebrate('The quartet holds the pose!', 'The Mannequin Quartet');
    await G.wait(0.6);
    G.ui.say('Click. The drummer’s hand opens. It was holding a crank handle all along.');
    this.spawnCrank();
  }

  spawnCrank() {
    const crank = new THREE.Group();
    const shaft = P.box(0.32, 0.05, 0.05, '#8c8f96', { base: false }); crank.add(shaft);
    const up = P.box(0.05, 0.18, 0.05, '#8c8f96', { base: false }); up.position.set(0.15, 0.09, 0); crank.add(up);
    const knob = P.sphere(0.05, '#c94d4d'); knob.position.set(0.15, 0.2, 0); crank.add(knob);
    crank.position.y = 0.4;
    this.pickup({ id: 'skylight_crank', pos: V3(ROOM_X - 0.75, FLOOR + 0.4, MANNEQUIN_Z[1] + 0.5), obj: crank, radius: 1.3 });
  }

  // ── The pigeon parliament ──────────────────────────────
  cellWorld(cx, cz) { return V3(GRID_ORIGIN.x + cx * CELL, FLOOR, GRID_ORIGIN.z + cz * CELL); }

  buildPigeons() {
    this.fans = [];
    for (const [vx, vz] of VENTS) {
      const w = this.cellWorld(vx, vz);
      const base = P.box(1.8, 0.04, 1.8, '#383a42'); base.position.copy(w); base.castShadow = false; this.static.add(base);
      for (let i = 0; i < 3; i++) { const sl = P.box(1.6, 0.03, 0.18, '#6b7080'); sl.position.set(w.x, FLOOR + 0.04, w.z - 0.5 + i * 0.5); sl.castShadow = false; this.static.add(sl); }
      const fan = new THREE.Group(); fan.position.set(w.x, FLOOR + 0.02, w.z);
      for (const r of [0, Math.PI / 2]) { const b = P.box(1.4, 0.02, 0.18, '#9aa0aa', { base: false }); b.rotation.y = r; fan.add(b); }
      this.add(fan); this.fans.push(fan);
    }
    const solved = G.state.flag('pigeon_parliament_solved');
    this.pigeons = (solved ? VENTS : START_CELLS).map(([cx, cz], i) => {
      const node = model('pigeon', { height: 0.42 });
      node.position.copy(this.cellWorld(cx, cz));
      node.rotation.y = i * 1.7;
      this.add(node);
      const ph = i * 0.7;
      this.every(() => { node.children[0] && (node.children[0].rotation.x = Math.sin(G.time * 6 + ph) * 0.08); });
      return { node, cx, cz };
    });
    const center = this.cellWorld(1.5, 1.5);
    this.sense(center, { warm: () => G.state.knows('hiss') && !G.state.flag('pigeon_parliament_solved'), height: 0.3 });
    if (solved) {
      for (const f of this.fans) this.every(() => { f.rotation.y += 0.05; });
      this.panelPopped();
      if (!G.state.flag('took_elevator_fuse')) this.spawnFuse();
    }
    this.onVocal((e) => {
      if (G.state.flag('pigeon_parliament_solved')) return;
      const near = e.pos.distanceTo(center) < 9;
      if (e.kind === 'meow') {
        if (near && !this.meowTeased) { this.meowTeased = true; G.audio.sfx('pigeons', { vol: 0.3, rate: 0.6 }); G.ui.toast('The pigeons coo, deeply unimpressed by meows.', '\u{1F426}'); }
        return;
      }
      if (e.kind === 'hiss') this.hissFrom(e.pos);
    });
  }

  freeCell(cx, cz) {
    if (cx < 0 || cx >= GRID_N || cz < 0 || cz >= GRID_N) return false;
    return !this.pigeons.some((p) => p.cx === cx && p.cz === cz);
  }

  hissFrom(pos) {
    let moved = false;
    for (const p of this.pigeons) {
      const w = this.cellWorld(p.cx, p.cz);
      const dx = w.x - pos.x, dz = w.z - pos.z;
      if (Math.hypot(dx, dz) > 6.5) continue;
      const sx = dx >= 0 ? 1 : -1, sz = dz >= 0 ? 1 : -1;
      const opts = Math.abs(dx) >= Math.abs(dz) ? [[sx, 0], [0, sz]] : [[0, sz], [sx, 0]];
      let done = false;
      for (const [ox, oz] of opts) {
        if (this.freeCell(p.cx + ox, p.cz + oz)) {
          p.cx += ox; p.cz += oz;
          this.hop(p, ox, oz); done = true; moved = true; break;
        }
      }
      if (!done) { const y0 = p.node.position.y; G.tween(p.node.position, { y: y0 + 0.25 }, 0.12).then(() => G.tween(p.node.position, { y: y0 }, 0.12)); }
    }
    if (moved) {
      G.audio.sfx('pigeons', { vol: 0.5 });
      if (this.pigeons.every((p) => VENTS.some(([vx, vz]) => vx === p.cx && vz === p.cz))) this.solvePigeons();
    }
  }

  hop(p, ox, oz) {
    const to = this.cellWorld(p.cx, p.cz);
    const from = p.node.position.clone();
    p.node.rotation.y = Math.atan2(ox, oz);
    G.animate(0.32, (t) => { p.node.position.lerpVectors(from, to, t); p.node.position.y = FLOOR + Math.sin(t * Math.PI) * 0.5; });
    G.fx.burst(from.clone().setY(FLOOR + 0.3), { color: '#b8bcc6', count: 5, speed: 1.2, up: 1.5, size: 0.1, life: 0.5, gravity: 4 });
  }

  async solvePigeons() {
    G.state.set('pigeon_parliament_solved');
    G.audio.sfx('robot_whir', { vol: 0.6, rate: 0.6 }); G.audio.sfx('jump_whoosh', { vol: 0.8, rate: 0.7 });
    G.ui.celebrate('Four wingbeats, four vents!', 'The Pigeon Parliament');
    G.ui.say('Four wingbeats over four vents. The fans below wake with a howl.');
    for (const f of this.fans) G.tween(f.rotation, { y: f.rotation.y + Math.PI * 14 }, 2.8, ease.out).then(() => this.every(() => { f.rotation.y += 0.05; }));
    await G.wait(2.0);
    await G.cine.run(async (c) => {
      c.look(V3(11.5, 1, -7.2), { dist: 9, pitch: 42 });
      await c.wait(0.6);
      G.audio.sfx('coconut_thunk', { vol: 0.8, rate: 0.8 });
      this.panelPopped(true);
      this.spawnFuse();
      await c.say('Across the atrium, a panel clatters off the elevator. Something glassy rolls free.', { dur: 3.2 });
    });
  }

  panelPopped(anim = false) {
    const panel = P.box(0.08, 0.7, 0.7, '#6b7080', { base: false });
    panel.position.set(15.2, 1.1, -7.6);
    this.add(panel);
    const to = { x: 14.0, y: FLOOR + 0.06, z: -7.0 };
    if (anim) { G.tween(panel.position, to, 0.7, ease.in); G.tween(panel.rotation, { z: 1.5 }, 0.7); }
    else { Object.assign(panel.position, to); panel.rotation.z = 1.5; }
  }

  spawnFuse() {
    const fuse = new THREE.Group();
    const glass = P.cyl(0.08, 0.08, 0.3, '#e6c88a', { base: false, transparent: true, opacity: 0.85 }); glass.rotation.z = Math.PI / 2; fuse.add(glass);
    for (const s of [-1, 1]) { const cap = P.cyl(0.09, 0.09, 0.06, '#9aa0aa', { base: false }); cap.rotation.z = Math.PI / 2; cap.position.x = s * 0.17; fuse.add(cap); }
    fuse.position.y = 0.3;
    this.pickup({ id: 'elevator_fuse', pos: V3(12.8, FLOOR, -7.0), obj: fuse });
  }

  // ── The frozen flock ───────────────────────────────────
  buildGeese() {
    const items = [];
    const R = rng(60);
    // Two nested Vs, tips leading south toward the doors and the sea.
    for (const [tipZ, y0, n] of [[6.5, 1.6, 31], [3.0, 0.4, 29]]) {
      items.push({ x: 0, y: y0, z: tipZ, rotY: GOOSE_YAW, scale: 1 });
      for (let i = 1; i <= (n - 1) / 2; i++) {
        for (const s of [-1, 1]) items.push({ x: s * 0.62 * i, y: y0 + R.range(-0.25, 0.35), z: tipZ - 0.75 * i, rotY: GOOSE_YAW + R.range(-0.08, 0.08), scale: R.range(0.9, 1.05) });
      }
    }
    this.flock = instanced('goose', items, { size: 0.95, shadow: true });
    this.flock.position.y = 6.6;
    this.add(this.flock);
    this.flockBase = this.flock.position.clone();
    this.sense(V3(0, 7.5, 0), { warm: () => G.state.flag('skylight_open') && !G.state.flag('mall_sunset'), height: 0, radius: 12 });
  }

  // ── Main riddle: Make the Flock Fly ────────────────────
  buildFinale() {
    // Crank socket on the drummer's old dais, up on the north balcony.
    const dais = P.cyl(1.4, 1.5, 0.18, '#8c6b4d'); dais.position.copy(SOCKET); this.add(dais);
    this.solidCyl(SOCKET.x, SOCKET.z, 1.5, BALC_TOP - 0.1, BALC_TOP + 0.18);
    const stool = P.cyl(0.18, 0.2, 0.45, '#6b4d33'); stool.position.set(SOCKET.x - 0.95, BALC_TOP + 0.18, SOCKET.z + 0.4); this.add(stool);
    for (const [dx, dz, r] of [[0.85, -0.5, 0.34], [1.05, 0.45, 0.26]]) { const d = P.cyl(r, r, 0.42, '#b34d4d'); d.position.set(SOCKET.x + dx, BALC_TOP + 0.18, SOCKET.z + dz); this.add(d); }
    const ped = P.cyl(0.14, 0.18, 0.55, FRAME); ped.position.set(SOCKET.x, BALC_TOP + 0.18, SOCKET.z); this.add(ped);
    this.sense(ped, { warm: () => !G.state.flag('skylight_open'), height: 0.7 });
    this.interact({
      pos: V3(SOCKET.x, BALC_TOP + 0.18, SOCKET.z), obj: ped, radius: 1.9, icon: '\u{1F527}',
      label: () => (G.state.flag('skylight_open') ? 'The crank spins freely' : G.state.has('skylight_crank') ? 'Fit the crank' : 'A crank-shaped socket'),
      use: () => this.useCrank(),
    });
    // Elevator shaft.
    const E = ELEVATOR;
    const shaftH = ROOF_Y - 0.4;
    for (const [w, d, x, z] of [[2.4, 0.15, 0, 1.2], [0.15, 2.4, 1.2, 0], [0.15, 2.4, -1.2, 0], [0.5, 0.15, 0.95, -1.2], [0.5, 0.15, -0.95, -1.2]]) this.glass(w, shaftH, d, E.x + x, 0.3, E.z + z);
    for (const cx of [-1.2, 1.2]) for (const cz of [-1.2, 1.2]) this.sbox(0.16, ROOF_Y, 0.16, E.x + cx, 0.3, E.z + cz, FRAME, { solid: false });
    this.sbox(1.5, 0.8, 1.5, E.x, ROOF_TOP, E.z, '#8b9098', { solid: false });
    const callPost = P.box(0.22, 1.2, 0.22, FRAME); callPost.position.set(E.x - 1.6, FLOOR, E.z - 1.55); this.add(callPost);
    this.callBtn = P.box(0.12, 0.12, 0.1, '#c94033', { emissive: '#c94033', emissiveIntensity: G.state.flag('elevator_powered') ? 1.2 : 0 });
    this.callBtn.position.set(E.x - 1.6, FLOOR + 1.0, E.z - 1.68); this.add(this.callBtn);
    // The cab.
    this.cab = new THREE.Group();
    const cfloor = P.box(2.1, 0.15, 2.1, '#737880'); this.cab.add(cfloor);
    for (const [w, h, d, x, z] of [[2.0, 1.75, 0.08, 0, 0.98], [0.08, 1.75, 2.0, 0.98, 0], [0.08, 1.75, 2.0, -0.98, 0]]) { const wall = P.box(w, h, d, '#8b9098'); wall.position.set(x, 0.15, z); this.cab.add(wall); }
    const roof = P.box(2.1, 0.07, 2.1, '#737880'); roof.position.y = 1.9; this.cab.add(roof);
    this.cabLamp = P.box(0.6, 0.04, 0.6, '#fff0cc', { emissive: '#ffe0a0', emissiveIntensity: G.state.flag('elevator_powered') ? 1.5 : 0 }); this.cabLamp.position.y = 1.86; this.cab.add(this.cabLamp);
    this.cab.position.set(E.x, FLOOR, E.z);
    this.add(this.cab);
    this.cabFloor = this.solidBox(E.x, E.z, 2.0, 2.0, FLOOR - 0.1, FLOOR + 0.15);
    // Catwalk on the roof from the cab to the north roof strip.
    this.sbox(1.3, 0.12, 2.8, E.x, ROOF_TOP - 0.12, E.z - 2.6, '#8b9098');
    this.sense(this.cab, { warm: () => G.state.flag('mall_sunset') && !G.state.flag('elevator_powered'), height: 1 });
    this.interact({
      pos: V3(E.x, FLOOR, E.z - 1.5), obj: this.cab, radius: 2.2, icon: '\u{1F6D7}',
      enabled: () => G.player.pos.y < 3,
      label: () => (G.state.flag('elevator_powered') ? 'Ride the elevator up' : G.state.has('elevator_fuse') && G.state.flag('mall_sunset') ? 'Fit the glass fuse' : 'A dark glass elevator'),
      use: () => this.elevatorInteract(),
    });
    this.interact({
      pos: V3(E.x, ROOF_TOP, E.z - 2.8), radius: 1.8, icon: '\u{1F6D7}', yRange: 1.5,
      enabled: () => G.player.pos.y > 9 && G.state.flag('elevator_powered') && !this.gliding,
      label: 'Ride the elevator down',
      use: () => this.ride(false),
    });
    // The great banner at the roof's south edge.
    const pole = P.cyl(0.06, 0.06, 2.6, FRAME); pole.position.set(BANNER.x, ROOF_TOP, BANNER.z); this.add(pole);
    const roll = P.cyl(0.14, 0.14, 3.2, '#2f7a7a', { base: false }); roll.rotation.z = Math.PI / 2; roll.position.set(BANNER.x, ROOF_TOP + 2.3, BANNER.z); this.add(roll);
    const cloth = P.box(3.0, 1.6, 0.04, '#2f7a7a', { base: false }); cloth.position.set(BANNER.x, ROOF_TOP + 1.4, BANNER.z + 0.1); this.add(cloth);
    this.bannerCloth = cloth;
    this.sense(cloth, { warm: () => G.state.flag('elevator_powered'), height: 0 });
    this.interact({
      pos: V3(BANNER.x, ROOF_TOP, BANNER.z - 0.8), obj: cloth, radius: 2.2, icon: '\u{1FA82}', yRange: 1.5,
      enabled: () => !this.gliding && !G.state.flag('island2_complete'),
      label: 'Unhook the great banner',
      use: () => this.startGlide(),
    });
    if (G.state.flag('mall_sunset')) this.spawnShadowFlock(false);
  }

  useCrank() {
    if (G.state.flag('skylight_open')) { G.ui.toast('The crank spins freely. The sky is already open.', '\u{1F527}'); return; }
    if (!G.state.has('skylight_crank')) { G.ui.say('A crank-shaped socket, empty for years.'); return; }
    G.state.take('skylight_crank');
    G.state.set('skylight_open');
    G.audio.sfx('wood_creak', { vol: 0.7, rate: 0.9 }); G.audio.sfx('stone_slide', { vol: 0.8, rate: 0.8 });
    G.player.emote('pickup', 1.6);
    G.cine.run(async (c) => {
      c.look(V3(0, ROOF_Y, 0), { dist: 22, pitch: 60 });
      this.shutters.forEach((s, i) => G.tween(s.position, { x: this.shutterOpenX(i) }, 2.8, ease.inOut));
      await c.say('The shutters grind apart, and the skylight drinks the sky. Now the light must lean.', { dur: 3.6 });
    });
    if (this.clockHour === 6 && !G.state.flag('mall_sunset')) setTimeout(() => this.sunset(), 4000);
  }

  async sunset() {
    G.state.set('mall_sunset');
    G.audio.sfx('whisker_shimmer', { vol: 0.6, rate: 0.7 });
    G.ui.celebrate('Evening leans in', 'The light falls sideways');
    // Lean the light to evening over three seconds.
    const from = { sun: G.sun.color.clone(), sky: G.scene.background.clone(), fog: G.scene.fog.color.clone(), hemi: G.hemi.intensity, si: G.sun.intensity };
    const to = { sun: new THREE.Color(SUNSET.sun), sky: new THREE.Color(SUNSET.sky), fog: new THREE.Color(SUNSET.fog) };
    await G.animate(3, (t) => {
      G.sun.color.copy(from.sun).lerp(to.sun, t);
      G.scene.background.copy(from.sky).lerp(to.sky, t);
      G.scene.fog.color.copy(from.fog).lerp(to.fog, t);
      G.sun.intensity = from.si + (SUNSET.sunIntensity - from.si) * t;
      G.hemi.intensity = from.hemi + (SUNSET.hemi - from.hemi) * t;
    });
    G.render.setAtmosphere(SUNSET);
    await G.wait(0.6);
    await G.cine.run(async (c) => {
      c.look(V3(7, FLOOR, -3), { dist: 16, pitch: 62 });
      G.audio.sfx('geese', { vol: 0.5 });
      this.spawnShadowFlock(true);
      await c.say('Sixty shadows land on the tiles… and point, all of them, at the dark glass elevator.', { dur: 4 });
      for (let i = 0; i < 4; i++) setTimeout(() => G.fx.ring(V3(ELEVATOR.x, FLOOR + 0.05, ELEVATOR.z), '#ffd24a', 2.2, 1.0), i * 700);
      c.look(V3(ELEVATOR.x, 1.5, ELEVATOR.z), { dist: 10 });
      await c.wait(2.2);
    });
  }

  spawnShadowFlock(anim) {
    const from = V3(-2, FLOOR + 0.02, 1), to = V3(14.2, FLOOR + 0.02, -6.5);
    const dir = to.clone().sub(from).normalize();
    const side = V3(dir.z, 0, -dir.x);
    const yaw = Math.atan2(dir.x, dir.z);
    const mat = new THREE.MeshBasicMaterial({ color: '#2a2433', transparent: true, opacity: 0.5, depthWrite: false });
    const shape = new THREE.Shape();
    shape.moveTo(0, 0.42); shape.lineTo(0.06, 0.18); shape.lineTo(0.55, -0.02); shape.lineTo(0.08, -0.08); shape.lineTo(0.05, -0.32);
    shape.lineTo(-0.05, -0.32); shape.lineTo(-0.08, -0.08); shape.lineTo(-0.55, -0.02); shape.lineTo(-0.06, 0.18); shape.closePath();
    const geo = new THREE.ShapeGeometry(shape); geo.rotateX(-Math.PI / 2);
    const spots = [];
    for (let i = 0; i < 14; i++) { const t = i / 13; spots.push(from.clone().lerp(to, t).addScaledVector(side, Math.sin(t * 12) * 1.1)); }
    for (let k = 0; k < 3; k++) spots.push(to.clone().addScaledVector(dir, 1 + 0.5 * k).addScaledVector(side, (k - 1) * 0.6));
    spots.forEach((p, i) => {
      const m = new THREE.Mesh(geo, mat);
      m.position.copy(p); m.rotation.y = yaw + Math.PI; m.renderOrder = 2;
      this.add(m);
      if (anim) { m.scale.setScalar(0.01); setTimeout(() => G.tween(m.scale, { x: 1.3, y: 1.3, z: 1.3 }, 0.5, ease.outBack), 100 * i); }
      else m.scale.setScalar(1.3);
    });
  }

  elevatorInteract() {
    if (G.state.flag('elevator_powered')) { this.ride(true); return; }
    if (!G.state.flag('mall_sunset')) { G.ui.say('Dark, silent, waiting. Its call button wants something the mall hasn’t given yet.'); return; }
    if (!G.state.has('elevator_fuse')) { G.ui.say('The shadows all point here. Behind a little hatch: an empty fuse socket.'); return; }
    G.state.take('elevator_fuse');
    G.state.set('elevator_powered');
    G.audio.sfx('pickup_chime', { vol: 0.7, rate: 1.2 }); G.audio.sfx('robot_whir', { vol: 0.6, rate: 1.3 });
    this.callBtn.material = P.mat('#c94033', { emissive: '#ff6a4a', emissiveIntensity: 1.2 });
    this.cabLamp.material = P.mat('#fff0cc', { emissive: '#ffe0a0', emissiveIntensity: 1.5 });
    G.ui.celebrate('The elevator wakes!', 'The glass fuse fits');
    G.ui.say('The fuse seats with a satisfying clunk. The elevator wakes, and its doors part.');
  }

  /** The ride: Khione steps in, the cab hums to the other floor. */
  async ride(up) {
    if (this.riding) return;
    this.riding = true;
    const E = ELEVATOR;
    await G.cine.run(async (c) => {
      const fromY = up ? FLOOR : CAB_TOP, toY = up ? CAB_TOP : FLOOR;
      this.cab.position.y = fromY;
      G.player.teleport(E.x, E.z, Math.PI, fromY + 0.15);
      G.player.velocity.set(0, 0, 0);
      c.look(V3(E.x, fromY + 1, E.z), { dist: 11, pitch: 25, speed: 3 });
      G.audio.sfx('robot_whir', { vol: 0.6, rate: 1.3 });
      this.cabFloor.enabled = false;
      const hold = this.every(() => { G.player.pos.set(E.x, this.cab.position.y + 0.15, E.z); G.player.velocity.set(0, 0, 0); c.look(V3(E.x, this.cab.position.y + 1, E.z), { dist: 11, pitch: 25, speed: 4 }); });
      await G.tween(this.cab.position, { y: toY }, 4.2, ease.inOut);
      this.updaters.splice(this.updaters.indexOf(hold), 1);
      G.audio.sfx('pickup_chime', { vol: 0.5, rate: 1.5 });
      this.cabFloor.y0 = toY - 0.1; this.cabFloor.y1 = toY + 0.15; this.cabFloor.enabled = true;
      if (up) {
        G.player.teleport(E.x, E.z - 2.6, Math.PI, ROOF_TOP);
        if (!this.saidRoof) { this.saidRoof = true; await c.say('The roof of the world. Or at least of the mall. A great banner waits at the south edge.', { dur: 3.4 }); }
      } else G.player.teleport(E.x, E.z - 2.0, Math.PI, FLOOR);
    }, { skippable: false });
    this.riding = false;
  }

  async startGlide() {
    if (this.gliding) return;
    if (!G.state.flag('elevator_powered')) { G.ui.say('The banner is knotted tight. Perhaps after the elevator hums.'); return; }
    this.gliding = true;
    G.audio.music('intro', { fade: 2 });
    await G.cine.run(async (c) => {
      G.player.faceTo(V3(0, 0, 40));
      G.player.emote('happy', 1.4);
      c.look(V3(0, ROOF_TOP + 1, BANNER.z), { dist: 9, pitch: 20, yaw: 200, speed: 2 });
      G.audio.sfx('geese', { vol: 0.9 });
      const fb = this.flockBase.clone();
      G.tween(this.flock.position, { x: fb.x, y: fb.y + 7, z: fb.z + 55 }, 9, ease.in);
      await c.say('And when the flock finally flew, a little white cat flew with them.', { dur: 3 });
      // The banner becomes a glider over her head.
      const glider = P.box(2.6, 0.04, 1.2, '#2f7a7a', { base: false });
      glider.position.y = 1.5; G.player.root.add(glider);
      this.bannerCloth.visible = false;
      const p1 = V3(BANNER.x, ROOF_TOP + 0.6, BANNER.z + 0.8), p2 = V3(0, 6.5, 30), p3 = V3(0, 1.05, 38.5);
      const gp = p1.clone();
      const hold = this.every(() => { G.player.pos.copy(gp); G.player.velocity.set(0, 0, 0); G.player.yaw = 0; G.player.targetYaw = 0; });
      await G.animate(7, (u) => {
        gp.copy(u < 0.6 ? p1.clone().lerp(p2, u / 0.6) : p2.clone().lerp(p3, (u - 0.6) / 0.4));
        glider.rotation.z = Math.sin(u * 20) * 0.08;
        c.look(gp, { dist: 9, pitch: 18, yaw: 230, speed: 6 });
      }, ease.inOut);
      this.updaters.splice(this.updaters.indexOf(hold), 1);
      glider.removeFromParent();
      G.player.teleport(0, 38.5, 0);
      await c.wait(0.5);
    });
    await G.game.finishIsland();
  }

  // ── The robot and the hiss ─────────────────────────────
  buildRobot() {
    const r = model('robot', { size: 1.1 });
    r.position.copy(G.state.knows('hiss') ? ROBOT_HOME : PATROL[0]);
    this.add(r);
    this.robot = r;
    this.robotState = 'patrol';
    this.patrolI = 1;
    this.robotSolid = this.solidCyl(r.position.x, r.position.z, 0.5, FLOOR, FLOOR + 0.4, { noStand: true });
    this.sense(r, { warm: () => false, height: 0.5 });
    this.every((dt) => this.updateRobot(dt));
    // Confrontation when she first enters the mall.
    this.trigger({ pos: V3(0, FLOOR, 14.5), radius: 3.8, once: true, enabled: !G.state.knows('hiss'), onEnter: () => this.confront() });
    this.onVocal((e) => {
      if (e.kind !== 'hiss') return;
      if (e.pos.distanceTo(this.robot.position) > 7) return;
      this.robotFlee();
    });
  }

  updateRobot(dt) {
    const r = this.robot;
    if (this.robotState === 'patrol') {
      const tgt = PATROL[this.patrolI];
      const d = Math.hypot(tgt.x - r.position.x, tgt.z - r.position.z);
      if (d < 0.2) this.patrolI = (this.patrolI + 1) % PATROL.length;
      else {
        const sp = 2.4 * dt;
        r.position.x += ((tgt.x - r.position.x) / d) * Math.min(sp, d);
        r.position.z += ((tgt.z - r.position.z) / d) * Math.min(sp, d);
        r.rotation.y = Math.atan2(tgt.x - r.position.x, tgt.z - r.position.z) + this.robotYaw();
      }
    }
    if (this.robotState === 'home' && G.time > this.robotBackAt) this.robotState = 'patrol';
    this.robotSolid.x = r.position.x; this.robotSolid.z = r.position.z;
    // Bumps her gently if she blocks its rounds.
    const p = G.player.pos;
    const d = Math.hypot(p.x - r.position.x, p.z - r.position.z);
    if (d < 1.0 && this.robotState === 'patrol' && Math.abs(p.y - FLOOR) < 0.5 && !G.cine.active) {
      const k = (1.0 - d) * 6 * dt;
      p.x += ((p.x - r.position.x) / (d || 1)) * k; p.z += ((p.z - r.position.z) / (d || 1)) * k;
      if (!this.bumpT || G.time - this.bumpT > 2) { this.bumpT = G.time; G.audio.sfx('robot_whir', { pos: r.position, vol: 0.5 }); }
    }
  }
  robotYaw() { return Math.PI / 2; }

  async confront() {
    if (G.state.knows('hiss')) return;
    this.robotState = 'busy';
    const r = this.robot;
    await G.cine.run(async (c) => {
      const p = G.player.pos.clone();
      c.look(p.clone().add(V3(0, 0.5, -1)), { dist: 7, pitch: 32 });
      G.audio.sfx('robot_whir', { vol: 0.9 });
      const dest = V3(p.x + 1.1, FLOOR, p.z - 1.3);
      r.rotation.y = Math.atan2(dest.x - r.position.x, dest.z - r.position.z) + this.robotYaw();
      G.tween(r.position, { x: dest.x, z: dest.z }, 1.2, ease.out);
      await c.say('A cleaning robot rounds on Khione, brushes whirring…', { dur: 2.4 });
      G.player.faceTo(dest);
      G.tween(G.player.pos, { z: p.z + 0.8 }, 0.5, ease.out);
      await c.wait(0.4);
      G.state.learn('hiss');
      G.fx.burst(p.clone().setY(FLOOR + 0.6), { color: '#ffffff', count: 10, speed: 1.5, up: 2, size: 0.12, life: 0.6 });
      await c.say('Khione’s fur rises. Something new rattles in her throat.', { dur: 2.6 });
    });
    G.ui.toast('Learned: Hiss! (tap \u{1F640})', '\u{1F640}');
    // It hovers, whirring, until she uses it (or wanders off).
    this.robotState = 'home'; this.robotBackAt = G.time + 20;
  }

  robotFlee() {
    const r = this.robot;
    this.robotState = 'flee';
    G.audio.sfx('robot_flee', { pos: r.position, vol: 0.8 });
    const spin = r.rotation.y + Math.PI * 4;
    G.tween(r.rotation, { y: spin }, 1.4);
    G.tween(r.position, { x: ROBOT_HOME.x, z: ROBOT_HOME.z }, 1.4, ease.out).then(() => { this.robotState = 'home'; this.robotBackAt = G.time + 25; });
    if (!G.state.flag('robot_repelled')) { G.state.set('robot_repelled'); G.ui.say('The robot flees at top speed. Hissing: extremely effective.'); }
  }

  // ── Camera occlusion: fade whatever stands between camera and cat ──
  setupOccluders() {
    for (const m of this.occluders) {
      m.material = m.material.clone();
      m.material.transparent = true;
      m.userData.fade = 1;
      m.castShadow = false;
    }
    const ray = new THREE.Raycaster();
    const target = new THREE.Vector3();
    let tick = 0;
    this.every((dt) => {
      if (++tick % 2) return;
      target.copy(G.player.pos); target.y += 0.6;
      const dir = target.clone().sub(G.camera.position);
      const len = dir.length();
      ray.set(G.camera.position, dir.normalize());
      ray.far = len - 0.4;
      const hits = new Set(ray.intersectObjects(this.occluders, false).map((h) => h.object));
      for (const m of this.occluders) {
        const want = hits.has(m) ? 0.18 : 1;
        m.userData.fade = damp(m.userData.fade, want, 10, dt * 2);
        m.material.opacity = m.userData.fade;
        m.material.depthWrite = m.userData.fade > 0.95;
      }
    });
  }

  // ── Arrival, goals ─────────────────────────────────────
  async onEnter(first) {
    if (!first) return;
    await G.cine.run(async (c) => {
      c.cut(V3(0, 4, 8), { dist: 42, pitch: 30, yaw: 20 });
      await c.wait(0.3);
      c.look(V3(0, 3, 10), { dist: 34, pitch: 26, yaw: 10, speed: 0.6 });
      await c.say('A glass mall hums on the water… and something small and angry patrols its floors.', { dur: 4.2 });
      c.look(G.player.pos.clone().setY(1), { dist: 9, pitch: 35, speed: 1 });
      await c.wait(1.2);
    });
  }

  objective() {
    const s = G.state;
    if (s.flag('island2_complete')) return 'Island 3 waits beyond the horizon';
    if (!s.knows('hiss')) return 'Explore the glass mall';
    if (!s.flag('mall_time_3')) return 'The stairs run the wrong way';
    if (!s.flag('fountain_wish_made')) return 'Pay the fountain its wish';
    if (!s.flag('mannequin_shop_open')) return 'Find what the brass key opens';
    if (!s.flag('mannequins_posed')) return 'Pose the mannequin quartet';
    if (!s.flag('pigeon_parliament_solved')) return 'Herd the pigeons onto the vents';
    if (!s.flag('skylight_open')) return 'The crank wants a socket upstairs';
    if (!s.flag('mall_sunset')) return 'Lean the light to evening';
    if (!s.flag('elevator_powered')) return 'Wake the dark elevator';
    return 'Ride to the roof and take the banner';
  }
  hint() {
    const s = G.state;
    if (!s.knows('hiss')) return 'A glass mall hums on the water… and something small and angry patrols its floors.';
    if (!s.flag('mall_time_3')) return 'Every stair runs the wrong way. A clock hangs stuck above the fountain, and the directory by the doors remembers the mall’s habits.';
    if (!s.flag('fountain_wish_made')) return 'The fountain keeps old wishes. A mosaic under the water remembers three coins. Pay it in kind, in order.';
    if (!s.flag('mannequin_shop_open')) return 'The fountain’s brass key is warm in her satchel. A dark shop past the east escalator has been locked for years.';
    if (!s.flag('mannequins_posed')) return 'Four dancers wait for their pose. The poster reads one way from the atrium… and another way from inside the glass.';
    if (!s.flag('pigeon_parliament_solved')) return 'Pigeons have claimed the west tiles, and meows amuse them. They flee sharper sounds… always away from her, one tile at a time. The four grated tiles hum underneath.';
    if (!s.flag('skylight_open')) return 'The drummer’s crank wants a socket. The balcony above the atrium keeps one, near the skylight’s edge.';
    if (!s.flag('mall_sunset')) return 'Open sky above the frozen flock… now the light must lean. Evening reaches every mall at 6 o’clock.';
    return 'Sixty shadows point at the dark elevator, and it hungers for its glass fuse. Then: the roof, and the great banner.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.knows('hiss')) return V3(0, FLOOR, 14);
    if (!s.flag('mall_time_3')) return CLOCK.clone().setY(1);
    if (!s.flag('fountain_wish_made')) return V3(0, 1.1, 3.6);
    if (!s.flag('mannequin_shop_open') || !s.flag('mannequins_posed')) return V3(16, 1, 8);
    if (!s.flag('pigeon_parliament_solved')) return this.cellWorld(1.5, 1.5);
    if (!s.flag('skylight_open')) return SOCKET;
    if (!s.flag('mall_sunset')) return CLOCK.clone().setY(1);
    if (!s.flag('elevator_powered')) return ELEVATOR.clone().setY(1);
    return G.player.pos.y > 9 ? BANNER : ELEVATOR.clone().setY(1);
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'stairs', name: 'The Wrong-Way Stairs', done: s.flag('mall_time_3'), hint: 'Every stair runs against her. The stuck clock above the fountain still commands the mall, and the directory remembers when things happen.' },
      { id: 'fountain', name: 'The Fountain of Small Wishes', done: s.flag('fountain_wish_made'), hint: 'Coins wait on the ledge, marked two ways. The mosaic under the water remembers three of them, in order.' },
      { id: 'quartet', name: 'The Mannequin Quartet', done: s.flag('mannequins_posed'), hint: 'Four dancers behind brass-locked glass. The poster remembers their pose, but glass remembers things backwards.' },
      { id: 'pigeons', name: 'The Pigeon Parliament', done: s.flag('pigeon_parliament_solved'), hint: 'Pigeons rule the west tiles and flee from hisses, always away, one tile at a time. Four grated tiles wait beneath four birds.' },
      { id: 'flock', name: 'Make the Flock Fly', done: s.flag('island2_complete'), hint: 'Crank the sky open. Lean the light to evening. Follow sixty shadows to the sleeping elevator, wake it, and take the roof.' },
    ];
  }
}
