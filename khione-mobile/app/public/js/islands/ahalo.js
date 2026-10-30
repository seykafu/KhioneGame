// Island 1 — Ahalo. "The island is listening." Teaches: interact, jump, swim, meow.
// Layout, heights and puzzle positions mirror the Godot island (scripts/islands/ahalo.gd
// and scripts/puzzles/*): terraces at 0.3 / 1.3 / 2.3 / 3.3, water at -0.4.
import * as THREE from 'three';
import { G, rng, clamp, smooth, fbm, ease, V3 } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';

const WATER = -0.4;
const SAND = '#f0dcae', GRASS = '#7cc35a', ROCK = '#b98e5a';
const ECHO = V3(33, 0, -4);
const STONES = [
  { size: 0.8, hum: 'hum_high', freq: 880, off: V3(-3.2, 0, 0.4) },
  { size: 1.25, hum: 'hum_mid', freq: 587, off: V3(0.2, 0, -2.6) },
  { size: 1.7, hum: 'hum_low', freq: 392, off: V3(3.4, 0, 0.2) },
];
const POOL = V3(33.4, 0, 0.6);
const DEN = V3(-14.56, 0.3, 4.36), DEN_ROT = 1.283;
const SUNDIAL = V3(1.8, 3.3, -1.5);
const TARGET_ROCK = V3(38, -0.8, -32);
const DECOYS = [V3(-45, -0.8, 18), V3(-15, -0.8, -46)];
const BEACH = V3(-4, 0.14, 35);
const BOTTLE = V3(0, 0.1, 36);
const FROND_PALM = V3(18, 0.3, -14);
const CRAB = V3(36, 0, -12);
const NEST = V3(-3.5, 2.31, 8.5);
const LAMP = V3(16.4, 0.05, 30.6);
const RIVER = [[-8.8, -6.8], [-10.3, -7.9], [-11.8, -9.0], [-14.0, -11.0], [-16.5, -12.2], [-19.5, -12.8], [-22.5, -14.2], [-25.5, -16.2], [-29.0, -18.5], [-33.0, -21.0], [-36.0, -23.0]];
const RAFT_PARTS = { old_oar: 'an oar', palm_frond: 'a sail', vine_rope: 'rope' };

const wrap = (a) => { while (a > Math.PI) a -= Math.PI * 2; while (a < -Math.PI) a += Math.PI * 2; return a; };
const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

export default class Ahalo extends Island {
  static id = 'ahalo';

  constructor() {
    super();
    this.waterLevel = WATER;
    this.bounds = { x: 0, z: 0, r: 58 };
  }

  models() { return ['palm', 'bottle', 'raft', 'gull', 'crab', 'coconut', 'chest']; }
  sounds() { return ['hum_high', 'hum_mid', 'hum_low', 'drain', 'gate_open', 'coconut_thunk', 'wood_creak', 'crab_snip', 'gull', 'stone_slide', 'ocean_loop', 'waterfall', 'brook']; }
  atmosphere() {
    return { sky: '#9fe3ee', fog: '#9fe3ee', fogNear: 45, fogFar: 120, sun: '#fff1d6', sunIntensity: 2.5, hemi: 1.25, skyLight: '#fff4dc', groundLight: '#7a8a5a' };
  }

  coast(theta) {
    let wob = 2.6 * Math.sin(3 * theta + 1.7) + 1.7 * Math.sin(5 * theta + 4.2) + 1.1 * Math.sin(8 * theta + 0.9);
    const d = Math.abs(wrap(theta - Math.PI / 2));
    wob *= ss(0.55, 1.1, d);
    return 40 + wob;
  }
  height(x, z) {
    const d = Math.hypot(x, z), theta = Math.atan2(z, x);
    const coast = this.coast(theta);
    if (d >= coast) return -6 * clamp((d - coast) / 12, 0, 1) + 0.02 * fbm(x * 0.2, z * 0.2);
    const gr = coast * 0.74;
    let h = 0.3 * (1 - ss(gr - 2, gr - 0.4, d));
    h += 1 - ss(12.6, 13.4, d);
    h += 1 - ss(9.0, 9.7, d);
    h += 1 - ss(5.7, 6.4, d);
    // Soft dunes on the sand ring.
    if (d > gr) h += Math.max(0, fbm(x * 0.08, z * 0.08) * 0.35);
    return h;
  }
  splat(x, z) {
    const d = Math.hypot(x, z), coast = this.coast(Math.atan2(z, x));
    const h = this.height(x, z);
    const e = 0.4;
    const slope = Math.hypot(this.height(x + e, z) - this.height(x - e, z), this.height(x, z + e) - this.height(x, z - e)) / (2 * e);
    const g = clamp((coast * 0.74 - 0.8 - d) / 1.6, 0, 1);
    const rock = clamp((slope - 0.55) * 2.2, 0, 1);
    if (h < -0.2) return [1, 0, 0];
    return [(1 - g) * (1 - rock), g * (1 - rock), rock];
  }
  tint(x, z) {
    const h = this.height(x, z);
    const c = new THREE.Color('#ffffff');
    if (h < WATER) c.lerp(new THREE.Color('#5aa8a0'), clamp((WATER - h) / 4, 0, 0.8));
    else if (h < 0.05) c.lerp(new THREE.Color('#d8b98a'), 0.35); // wet band
    const n = fbm(x * 0.15, z * 0.15);
    c.multiplyScalar(0.93 + n * 0.12);
    return c;
  }
  footstep(x, z) { return this.height(x, z) > 0.25 ? 'paw_grass' : 'paw_sand'; }
  dustColor(x, z) { return this.height(x, z) > 0.25 ? '#9bd27a' : '#ecd6a4'; }

  spawn() { return { x: -2.4, z: 9.6, rotY: 0.6 }; }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 116, res: 150, repeat: 0.2 });
    this.makeWater({ level: WATER, size: 300, res: 120, colors: { deep: '#13a8c8', light: '#5fd8e8' } });
    this.buildRiver();
    this.scatter();
    this.buildBottle();
    this.buildEchoStones();
    this.buildDen();
    this.buildSundial();
    this.buildSeaRocks();
    this.buildFrondPalm();
    this.buildCrab();
    this.buildRaft();
    this.buildFlourishes();
    this.places([
      [V3(0, 0, 33), 8, 'South Beach'], [ECHO, 9, 'Echo Cove'], [V3(-14.5, 0, 4.4), 8, 'The Hillside Den'],
      [V3(0, 0, 0), 6, 'The Old Summit'], [V3(-11.8, 0, -9), 6, 'The Falls'],
    ]);
    G.audio.ambient('ocean_loop', 0.22);
  }

  places(list) {
    for (const [pos, r, name] of list) {
      this.trigger({ pos, radius: r, once: true, onEnter: () => { if (G.state.flag('intro_done')) G.ui.showBanner(`~ ${name} ~`, 2.2); } });
    }
  }

  scatter() {
    const R = rng(20260728);
    // Palm groves with trunk colliders.
    const palms = [];
    for (let g = 0; g < 7; g++) {
      const gr = R.range(16, 26), ga = R.range(0, Math.PI * 2);
      const cx = Math.cos(ga) * gr, cz = Math.sin(ga) * gr;
      const n = R.int(3, 6);
      for (let i = 0; i < n; i++) {
        const x = cx + R.range(-3.5, 3.5), z = cz + R.range(-3.5, 3.5);
        const fr = Math.hypot(x, z);
        if (fr > 28 || fr < 14.5) continue;
        if (Math.hypot(x - FROND_PALM.x, z - FROND_PALM.z) < 6 || Math.hypot(x - DEN.x, z - DEN.z) < 5) continue;
        const s = R.range(0.85, 1.15);
        palms.push({ x, y: this.height(x, z) - 0.05, z, rotY: R.range(0, 6.28), scale: s });
        this.solidCyl(x, z, 0.3 * s, -1, 5);
      }
    }
    this.palmSpots = palms;
    this.add(instanced('palm', palms, { height: 6.2 }));

    // Beach + outcrop boulders (baked into a few draw calls).
    const deco = new THREE.Group();
    const RB = rng(4242);
    for (let i = 0; i < 16; i++) {
      const a = RB.range(0, Math.PI * 2), r = RB.range(31, 38.5);
      let x = Math.cos(a) * r, z = Math.sin(a) * r;
      if (z > 24 && Math.abs(x) < 22) z = -z; // keep the southern boat lane clear
      const s = RB.range(0.5, 1.3);
      const rk = P.rock(s, RB() < 0.5 ? ROCK : '#c9a070', i + 3);
      rk.position.set(x, this.height(x, z) - 0.15, z); rk.rotation.y = RB.range(0, 6);
      deco.add(rk);
      if (s > 0.7) this.solidCyl(x, z, s * 0.8, -2, this.height(x, z) + s * 0.9);
    }
    for (const [radius, count, y] of [[13.0, 10, 0.6], [9.35, 8, 1.6], [6.05, 6, 2.6]]) {
      for (let i = 0; i < count; i++) {
        const a = (Math.PI * 2 * i) / count + RB.range(-0.2, 0.2);
        const x = Math.cos(a) * radius, z = Math.sin(a) * radius;
        if (Math.hypot(x - SUNDIAL.x, z - SUNDIAL.z) < 2) continue;
        const rk = P.rock(RB.range(0.45, 0.75), '#a88c6a', 100 + i + radius);
        rk.position.set(x, y + RB.range(-0.15, 0.05), z);
        deco.add(rk);
      }
    }
    // Bushes, flowers and shells.
    for (let i = 0; i < 46; i++) {
      const a = RB.range(0, 6.28), r = RB.range(14, 28);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      if (this.nearRiver(x, z, 2)) continue;
      const b = P.bush(RB.range(0.35, 0.7), RB() < 0.5 ? '#4fa83a' : '#5fb84a', i);
      b.position.set(x, this.height(x, z), z);
      deco.add(b);
    }
    const flowerCols = ['#ff6b8a', '#ffd24a', '#b58cff', '#ffffff'];
    for (let i = 0; i < 70; i++) {
      const a = RB.range(0, 6.28), r = RB.range(6.5, 28);
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      const h = this.height(x, z);
      if (h < 0.28 || this.nearRiver(x, z, 1.4)) continue;
      const f = P.sphere(0.09, flowerCols[i % 4], { seg: 6 });
      f.position.set(x, h + 0.16, z); f.castShadow = false;
      const st = P.cyl(0.015, 0.015, 0.16, '#3e8a3a', { seg: 4 }); st.position.set(x, h, z); st.castShadow = false;
      deco.add(f, st);
    }
    for (let i = 0; i < 18; i++) {
      const a = RB.range(0, 6.28), r = RB.range(31.5, 38.5);
      let x = Math.cos(a) * r, z = Math.sin(a) * r; if (z > 24 && Math.abs(x) < 22) z = -z;
      const sh = P.cone(RB.range(0.06, 0.1), 0.05, ['#f6ecd8', '#f2c6bf', '#e6dcbf'][i % 3], { seg: 7 });
      sh.position.set(x, this.height(x, z) + 0.01, z); sh.castShadow = false;
      deco.add(sh);
    }
    for (let i = 0; i < 4; i++) {
      const a = RB.range(0, 6.28), r = RB.range(31, 37);
      let x = Math.cos(a) * r, z = Math.sin(a) * r; if (z > 24 && Math.abs(x) < 22) z = -z;
      const log = P.cyl(0.12, 0.16, RB.range(1.6, 2.6), '#a89a88', { base: false, seg: 8 });
      log.rotation.z = Math.PI / 2; log.rotation.y = RB.range(0, 6);
      log.position.set(x, this.height(x, z) + 0.12, z);
      deco.add(log);
    }
    this.add(P.bake(deco));
    this.add(deco);

    // Grass tufts (instanced cones) on the plateau.
    const tufts = [];
    const RT = rng(3131);
    for (let i = 0; i < 1400; i++) {
      const x = RT.range(-30, 30), z = RT.range(-30, 30);
      const h = this.height(x, z);
      if (h < 0.28 || h > 3.4 || this.nearRiver(x, z, 1.4)) continue;
      tufts.push([x, h, z, RT.range(0.6, 1.2), RT.range(0, 6)]);
    }
    const tuftGeo = new THREE.ConeGeometry(0.07, 0.32, 4); tuftGeo.translate(0, 0.16, 0);
    const im = new THREE.InstancedMesh(tuftGeo, P.mat('#5cae42'), tufts.length);
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3();
    tufts.forEach(([x, y, z, sc, r], i) => { q.setFromEuler(new THREE.Euler(0, r, 0)); s.set(sc, sc, sc); m4.compose(V3(x, y, z), q, s); im.setMatrixAt(i, m4); });
    im.receiveShadow = true;
    this.add(im);

    // Butterflies.
    const RBf = rng(555);
    const cols = ['#ff9a3c', '#a58cff', '#ffd84a'];
    for (let i = 0; i < 8; i++) {
      const b = new THREE.Group();
      for (const side of [-1, 1]) {
        const w = new THREE.Mesh(new THREE.PlaneGeometry(0.14, 0.18), P.mat(cols[i % 3], { side: THREE.DoubleSide }));
        w.position.x = 0.07 * side; w.rotation.x = -Math.PI / 2; w.castShadow = false;
        b.add(w);
      }
      const a = RBf.range(0, 6.28), r = RBf.range(14, 27);
      const home = V3(Math.cos(a) * r, 0, Math.sin(a) * r);
      home.y = this.height(home.x, home.z) + RBf.range(0.8, 1.5);
      b.position.copy(home);
      const ph = RBf.range(0, 10);
      this.every(() => {
        const t = G.time * 0.5 + ph;
        b.position.set(home.x + Math.sin(t) * 2.5, home.y + Math.sin(t * 2.3) * 0.3, home.z + Math.cos(t * 0.8) * 2.5);
        b.scale.x = 0.45 + Math.abs(Math.sin(G.time * 18 + ph)) * 0.55;
        b.rotation.y = t;
      });
      this.add(b);
    }
  }

  nearRiver(x, z, m) {
    if (Math.hypot(x + 8.8, z + 6.8) < 2.9) return true;
    for (let i = 0; i < RIVER.length - 1; i++) {
      const [ax, az] = RIVER[i], [bx, bz] = RIVER[i + 1];
      const dx = bx - ax, dz = bz - az;
      const t = clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1);
      if (Math.hypot(x - (ax + dx * t), z - (az + dz * t)) < m) return true;
    }
    return false;
  }

  buildRiver() {
    const curve = new THREE.CatmullRomCurve3(RIVER.map(([x, z]) => V3(x, 0, z)));
    const pts = curve.getPoints(110);
    const pos = [], uv = [], idx = [];
    let arc = 0;
    pts.forEach((p, i) => {
      const prev = pts[Math.max(0, i - 1)], next = pts[Math.min(pts.length - 1, i + 1)];
      const dir = next.clone().sub(prev).setY(0).normalize();
      const side = V3(-dir.z, 0, dir.x);
      if (i) arc += p.distanceTo(prev);
      const w = 0.55 + 0.25 * Math.sin(arc * 0.31 + 1.1) + arc * 0.008;
      const drop = Math.abs(this.height(prev.x, prev.z) - this.height(next.x, next.z));
      const lift = 0.06 + Math.min(0.34, drop * 0.55);
      for (const sgn of [1, -1]) {
        const q = p.clone().addScaledVector(side, w * sgn);
        pos.push(q.x, Math.max(this.height(q.x, q.z), WATER - 0.1) + lift, q.z);
        uv.push(sgn > 0 ? 0 : 1, arc * 0.25);
      }
      if (i) { const a = (i - 1) * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    });
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    geo.setIndex(idx); geo.computeVertexNormals();
    const tex = P.textCanvas('', { w: 64, h: 256, bg: null, draw: (g) => {
      const gr = g.createLinearGradient(0, 0, 64, 0);
      gr.addColorStop(0, '#bff3fb'); gr.addColorStop(0.2, '#4cc8dc'); gr.addColorStop(0.8, '#4cc8dc'); gr.addColorStop(1, '#bff3fb');
      g.fillStyle = gr; g.fillRect(0, 0, 64, 256);
      g.fillStyle = 'rgba(255,255,255,0.5)';
      for (let i = 0; i < 18; i++) g.fillRect(10 + (i * 37) % 44, (i * 53) % 256, 3, 18);
    } });
    tex.wrapT = THREE.RepeatWrapping;
    const mat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, opacity: 0.92 });
    const ribbon = new THREE.Mesh(geo, mat);
    ribbon.renderOrder = 1;
    this.add(ribbon);
    this.every((dt) => { tex.offset.y -= dt * 0.6; });
    const pond = new THREE.Mesh(new THREE.CircleGeometry(1.25, 24), mat);
    pond.rotation.x = -Math.PI / 2; pond.position.set(-8.8, 1.36, -6.8);
    this.add(pond);
    const R = rng(909);
    for (let i = 0; i < 7; i++) {
      const a = (Math.PI * 2 * i) / 7 + R.range(-0.15, 0.15);
      const rk = P.rock(R.range(0.25, 0.4), '#9a8a74', 50 + i);
      rk.position.set(-8.8 + Math.cos(a) * 1.5, 1.28, -6.8 + Math.sin(a) * 1.5);
      this.add(rk);
    }
    for (const [x, z] of [[-16.5, -12.2], [-19.5, -12.8], [-25.5, -16.2]]) {
      const st = P.rock(0.45, '#a8957a', x * 3, 0.45); st.position.set(x, this.height(x, z) + 0.05, z); this.add(st);
    }
    // Waterfall + brook murmur as you get close.
    this.every(() => {
      const p = G.player.pos;
      const d1 = Math.hypot(p.x + 11.5, p.z + 8.8), d2 = Math.hypot(p.x + 22.5, p.z + 14.2);
      G.audio.ambient('waterfall', clamp(1 - d1 / 22, 0, 1) * 0.5);
      G.audio.ambient('brook', clamp(1 - d2 / 15, 0, 1) * 0.4);
    });
  }

  // ── Beat 0: the bottle ─────────────────────────────────
  buildBottle() {
    const b = model('bottle', { height: 0.5, rotY: 0.4 });
    b.rotation.z = Math.PI / 2.3;
    b.position.y = 0.12;
    const holder = new THREE.Group(); holder.position.copy(BOTTLE); holder.add(b); this.add(holder);
    this.bottle = holder;
    this.sense(holder, { warm: () => !G.state.flag('letter_read'), height: 0.3 });
    this.interact({
      obj: holder, radius: 1.8, icon: '✉️',
      label: () => (G.state.flag('letter_read') ? 'Read the letter again' : 'Read the message'),
      use: () => this.readLetter(),
    });
    this.every(() => { b.rotation.x = Math.sin(G.time * 1.2) * 0.08; });
  }

  async readLetter() {
    const first = !G.state.flag('letter_read');
    G.state.set('letter_read');
    G.audio.sfx('paper_open');
    const body = G.ui.panel('A message in a bottle', `${G.ui.letterHTML()}<p style="text-align:center"><small>Most of it is torn away. The handwriting is careful, as if it mattered very much.</small></p>`, {
      buttons: [{ label: 'Keep it close', primary: true, onClick: (close) => close() }],
    });
    await body.done;
    if (first) {
      G.ui.toast('A torn letter. And somewhere east, a low hum on the wind.', '\u{1F4DC}');
      G.ui.hint.classList.remove('on');
    }
  }

  // ── Beat 1: the three hollow stones ───────────────────
  buildEchoStones() {
    const solved = G.state.flag('echo_stones_solved');
    this.echoProgress = 0;
    this.stones = STONES.map((def, i) => {
      const pos = ECHO.clone().add(def.off);
      const g = new THREE.Group();
      const body = P.rock(0.75 * def.size, ['#9aa6c4', '#8f9bb8', '#8490ad'][i], 70 + i, 1.6);
      g.add(body);
      // The hollow: a dark mouth on the side.
      const mouth = new THREE.Mesh(new THREE.CircleGeometry(0.18 * def.size, 14), P.mat('#2a2f3a'));
      mouth.position.set(0, 0.8 * def.size, 0.62 * def.size); g.add(mouth);
      g.position.set(pos.x, this.height(pos.x, pos.z) - 0.1, pos.z);
      g.rotation.y = i * 2.1;
      this.add(g);
      this.solidCyl(pos.x, pos.z, 0.6 * def.size, -1, this.height(pos.x, pos.z) + 1.6 * def.size);
      this.sense(g, { warm: () => false, height: 1.2 * def.size });
      return { ...def, pos, g };
    });
    // Carving slab with three spirals.
    const slab = new THREE.Group();
    const stone = P.box(2.2, 1.6, 0.35, '#b7a68a', { round: 0.12 });
    const face = new THREE.Mesh(new THREE.PlaneGeometry(1.9, 1.2), new THREE.MeshLambertMaterial({ map: this.spiralTexture(), transparent: true }));
    face.position.set(0, 0.85, 0.18);
    slab.add(stone, face);
    const sp = ECHO.clone().add(V3(-0.6, 0, -5.6));
    slab.position.set(sp.x, this.height(sp.x, sp.z) - 0.05, sp.z);
    slab.rotation.y = -0.5;
    this.add(slab);
    this.solidBox(sp.x, sp.z, 2.2, 0.5, -1, this.height(sp.x, sp.z) + 1.5, -0.5);
    this.sense(slab, { warm: () => !G.state.flag('echo_stones_solved'), height: 1 });
    this.interact({ obj: slab, radius: 2.4, icon: '\u{1F440}', label: 'Study the carving', use: () => this.openCarving() });

    // Tide pool.
    const ring = new THREE.Group();
    const R = rng(99);
    for (let i = 0; i < 7; i++) {
      const a = (Math.PI * 2 * i) / 7 + R.range(-0.2, 0.2);
      const rk = P.rock(R.range(0.35, 0.55), '#a8957a', 200 + i);
      rk.position.set(POOL.x + Math.cos(a) * 1.75, this.height(POOL.x, POOL.z) - 0.1, POOL.z + Math.sin(a) * 1.75);
      ring.add(rk);
    }
    this.add(ring);
    const water = new THREE.Mesh(new THREE.CircleGeometry(1.5, 28), new THREE.MeshLambertMaterial({ color: '#2a8fb0', transparent: true, opacity: 0.85 }));
    water.rotation.x = -Math.PI / 2;
    water.position.set(POOL.x, this.height(POOL.x, POOL.z) + 0.08, POOL.z);
    this.add(water);
    this.poolWater = water;
    if (solved) { water.visible = false; this.spawnPoolCache(); }

    this.trigger({ pos: ECHO, radius: 10, once: true, enabled: !solved, onEnter: () => {
      if (!G.state.flag('echo_stones_solved')) G.ui.toast('The stones are humming… (tap \u{1F431} Meow)', '\u{1F3B5}');
    } });
    // Hums swell as you approach (silent once solved).
    this.every(() => {
      const p = G.player.pos;
      for (const s of this.stones) {
        const d = Math.hypot(p.x - s.pos.x, p.z - s.pos.z);
        G.audio.ambient(s.hum, G.state.flag('echo_stones_solved') ? 0 : clamp(1 - d / 26, 0, 1) * 0.28);
      }
    });
    this.onVocal((e) => {
      if (e.kind !== 'meow' || G.state.flag('echo_stones_solved')) return;
      let idx = -1, best = 4.2;
      this.stones.forEach((s, i) => { const d = Math.hypot(e.pos.x - s.pos.x, e.pos.z - s.pos.z); if (d < best) { best = d; idx = i; } });
      if (idx < 0) return;
      const s = this.stones[idx];
      G.audio.sfx(s.hum, { vol: 1, dur: 1.4 });
      G.fx.ring(V3(s.pos.x, s.g.position.y + 0.1, s.pos.z), '#bdf2ff', 2.2, 0.9);
      G.tween(s.g.scale, { x: 1.09, y: 1.09, z: 1.09 }, 0.12).then(() => G.tween(s.g.scale, { x: 1, y: 1, z: 1 }, 0.25));
      if (idx === this.echoProgress) {
        this.echoProgress++;
        if (this.echoProgress >= 3) this.solveEcho();
      } else {
        this.echoProgress = 0;
        this.echoFail();
      }
    });
  }

  spiralTexture() {
    return P.textCanvas('', {
      w: 512, h: 320, bg: null, draw: (g) => {
        g.strokeStyle = '#6b4f30'; g.lineWidth = 7; g.lineCap = 'round';
        [[95, 0.55], [250, 0.8], [420, 1.1]].forEach(([cx, s]) => {
          g.beginPath();
          for (let k = 0; k <= 140; k++) {
            const t = k / 140, ang = t * 3 * Math.PI * 2, r = (5 + 52 * t) * s;
            const x = cx + Math.cos(ang) * r, y = 165 + Math.sin(ang) * r;
            k ? g.lineTo(x, y) : g.moveTo(x, y);
          }
          g.stroke();
        });
      },
    });
  }

  openCarving() {
    G.audio.sfx('stone_slide', { vol: 0.6 });
    const c = document.createElement('canvas'); c.width = 620; c.height = 320;
    const g = c.getContext('2d');
    g.fillStyle = '#d9c7a4'; g.fillRect(0, 0, 620, 320);
    g.fillStyle = 'rgba(120,96,60,0.12)';
    for (let i = 0; i < 300; i++) g.fillRect((i * 97) % 620, (i * 61) % 320, 3, 3);
    g.strokeStyle = '#6b4f30'; g.lineWidth = 5; g.lineCap = 'round';
    [[110, 0.55], [300, 0.8], [500, 1.1]].forEach(([cx, s]) => {
      g.beginPath();
      for (let k = 0; k <= 140; k++) {
        const t = k / 140, ang = t * 3 * Math.PI * 2, r = (6 + 62 * t) * s;
        const x = cx + Math.cos(ang) * r, y = 165 + Math.sin(ang) * r;
        k ? g.lineTo(x, y) : g.moveTo(x, y);
      }
      g.stroke();
    });
    c.className = 'art-img';
    G.ui.panel('A weathered carving', c, { buttons: [{ label: 'Close', onClick: (close) => close() }] });
  }

  echoFail() {
    G.audio.sfx('fail', { vol: 0.7 });
    for (const s of this.stones) {
      const x0 = s.g.position.x;
      G.animate(0.2, (t) => { s.g.position.x = x0 + Math.sin(t * Math.PI * 4) * 0.06; }).then(() => { s.g.position.x = x0; });
    }
    G.ui.toast('The stones fall silent…', '\u{1F3B5}');
    // A crab pops out of the sand to see what the fuss is about.
    const crab = model('crab', { height: 0.35 });
    const at = ECHO.clone().add(V3((Math.random() - 0.5) * 4, 0, 2 + Math.random() * 2));
    crab.position.set(at.x, this.height(at.x, at.z) - 0.4, at.z);
    crab.rotation.y = Math.random() * 6;
    this.add(crab);
    G.tween(crab.position, { y: this.height(at.x, at.z) }, 0.3, ease.outBack)
      .then(() => G.wait(1.4))
      .then(() => { G.audio.sfx('crab_snip', { pos: at, vol: 0.6 }); return G.tween(crab.position, { y: crab.position.y - 0.5 }, 0.4); })
      .then(() => crab.removeFromParent());
  }

  async solveEcho() {
    G.state.set('echo_stones_solved');
    G.ui.celebrate('The stones sing!', 'The Three Hollow Stones');
    for (const s of this.stones) G.audio.stopAmbient(s.hum);
    await G.cine.run(async (c) => {
      c.look(POOL.clone().setY(0.5), { dist: 7, pitch: 50 });
      await c.wait(0.8);
      G.audio.sfx('drain', { vol: 0.9 });
      c.say('Nearby, the tide pool drains with a groan…');
      await G.tween(this.poolWater.position, { y: this.poolWater.position.y - 0.5 }, 2.0);
      this.poolWater.visible = false;
      this.spawnPoolCache();
      G.fx.sparkle(POOL.clone().setY(0.6), '#ffe48a', 14);
      await c.wait(1.2);
    });
  }

  spawnPoolCache() {
    const y = this.height(POOL.x, POOL.z);
    this.pickup({
      id: 'rusty_locket', pos: V3(POOL.x - 0.5, y, POOL.z + 0.2),
      onTake: () => G.state.addArtifact('locket', 'ahalo', 'The Rusty Locket', 'Sea-worn bronze from the tide pool. The pawprint engraved inside is far too big for a cat.'),
    });
    this.pickup({ id: 'stranded_fish', pos: V3(POOL.x + 0.6, y, POOL.z - 0.3) });
  }

  // ── Beat 2: the driftwood seesaw & the den ────────────
  buildDen() {
    const den = new THREE.Group();
    den.position.copy(DEN);
    den.rotation.y = DEN_ROT;
    this.add(den);
    this.den = den;
    const local = (x, y, z) => den.localToWorld(V3(x, y, z));
    den.updateMatrixWorld(true);
    // Rock arch around the burrow mouth.
    for (const [x, y, z, r] of [[-1.15, 0, -0.5, 1.0], [1.15, 0, -0.5, 1.0], [0, 1.25, -0.7, 1.1], [-0.6, 0.2, -1.5, 1.2], [0.6, 0.2, -1.5, 1.2]]) {
      const rk = P.rock(r, '#a38668', x * 10 + z, 0.9);
      rk.position.set(x, y - 0.25, z); den.add(rk);
    }
    const back = P.box(1.8, 1.7, 0.15, '#191717'); back.position.set(0, 0, -1.9); den.add(back);
    const floor = P.box(1.7, 0.05, 2.0, '#5a4c40'); floor.position.set(0, 0, -0.95); den.add(floor);
    for (let i = 0; i < 4; i++) {
      const mk = P.box(0.03, 0.3, 0.03, '#0d0b0a'); mk.position.set(-0.35 + i * 0.22, 0.27, -1.81); mk.rotation.z = 0.12 - i * 0.05; den.add(mk);
    }
    // Den walls as colliders (box in den space → world).
    const wl = local(-1.2, 0, -0.8), wr = local(1.2, 0, -0.8), wb = local(0, 0, -2.0);
    this.solidBox(wl.x, wl.z, 0.6, 2.4, -1, 2.2, -DEN_ROT);
    this.solidBox(wr.x, wr.z, 0.6, 2.4, -1, 2.2, -DEN_ROT);
    this.solidBox(wb.x, wb.z, 2.4, 0.4, -1, 2.2, -DEN_ROT);
    // Vine gate.
    const gate = new THREE.Group(); gate.position.set(0, 0, 0.55); den.add(gate);
    for (const x of [-0.75, 0.75]) { const b = P.box(0.09, 1.5, 0.09, '#73512f'); b.position.set(x, 0, 0); gate.add(b); }
    for (const x of [-0.38, 0, 0.38]) { const b = P.box(0.06, 1.5, 0.06, '#6b8048'); b.position.set(x, 0, 0.03); gate.add(b); }
    for (const y of [0.42, 1.05]) { const b = P.box(1.6, 0.07, 0.07, '#6b8048'); b.position.set(0, y, -0.03); gate.add(b); }
    this.gate = gate;
    const gp = local(0, 0, 0.55);
    this.gateSolid = this.solidBox(gp.x, gp.z, 1.7, 0.25, -1, 1.6, -DEN_ROT, { noStand: true });

    // Seesaw on its wedge.
    const wedgeGeo = new THREE.CylinderGeometry(0.01, 0.55, 0.55, 3); wedgeGeo.rotateY(Math.PI / 6); wedgeGeo.translate(0, 0.275, 0);
    const wedge = new THREE.Mesh(wedgeGeo, P.mat('#8c8c90')); wedge.position.set(0, 0, 2.8); wedge.rotation.x = Math.PI / 2; wedge.castShadow = true;
    const wedge2 = P.box(0.7, 0.55, 0.7, '#8c8c90', { round: 0.08 }); wedge2.position.set(0, 0, 2.8); wedge2.scale.set(0.6, 1, 1);
    den.add(wedge2);
    const pivot = new THREE.Group(); pivot.position.set(0, 0.58, 2.8); den.add(pivot);
    const plank = P.box(3.6, 0.12, 0.6, '#b8a68c', { base: false, round: 0.04 }); pivot.add(plank);
    const pad = P.box(0.75, 0.1, 0.7, '#6b8048', { base: false }); pad.position.set(1.45, 0.1, 0); pivot.add(pad);
    this.pivot = pivot;
    const TILTS = [0.18, 0.1, 0.0, -0.18];
    const placed = () => [1, 2, 3].filter((n) => G.state.flag(`seesaw_${n}`)).length;
    const cocoSpots = [V3(1.3, 0.24, -0.12), V3(1.58, 0.24, 0.12), V3(1.44, 0.5, 0)];
    const addCoco = (i) => { const c = model('coconut', { height: 0.3 }); c.position.copy(cocoSpots[i]); c.position.y -= 0.12; pivot.add(c); };
    for (let i = 0; i < placed(); i++) addCoco(i);
    pivot.rotation.z = TILTS[placed()];
    const open = G.state.flag('seesaw_gate_open');
    if (open) { gate.position.y = 1.5; this.gateSolid.enabled = false; }
    const bp = local(1.9, 0.5, 2.8);
    const basket = new THREE.Group(); basket.position.copy(bp); this.add(basket);
    this.interact({
      pos: bp, obj: plank, radius: 2.2, icon: '\u{1F965}',
      label: () => (G.state.flag('seesaw_gate_open') ? null : G.state.has('coconut') ? 'Place a coconut' : 'An old plank on a rock'),
      use: () => {
        if (!G.state.has('coconut')) { G.ui.toast('Khione’s paws are empty… the palms drop coconuts.', '\u{1F965}'); return; }
        const n = placed() + 1;
        G.state.take('coconut');
        G.state.set(`seesaw_${n}`);
        addCoco(n - 1);
        G.audio.sfx('coconut_thunk', { vol: 0.9 });
        G.audio.sfx('wood_creak', { vol: 0.5 });
        G.tween(pivot.rotation, { z: TILTS[Math.min(n, 3)] }, 0.7, ease.out);
        if (n >= 3) this.openGate();
        else G.ui.toast(n === 1 ? 'The plank dips… a little.' : 'Creak. Almost…', '\u{1FAB5}');
      },
    });
    this.sense(plank, { warm: () => !G.state.flag('seesaw_gate_open'), height: 0.3 });
    // Oar inside, scratch marks on the wall.
    const op = local(0, 0.1, -1.15);
    const oar = new THREE.Group();
    const shaft = P.cyl(0.045, 0.045, 1.4, '#b8a68c', { base: false }); shaft.rotation.z = 1.35; oar.add(shaft);
    const blade = P.box(0.3, 0.02, 0.16, '#9c8c74', { base: false }); blade.position.set(0.62, 0.12, 0); oar.add(blade);
    oar.position.y = 0.1; oar.rotation.y = DEN_ROT;
    this.pickup({ id: 'old_oar', pos: op, obj: oar, bob: false, radius: 1.4 });
    const mp = local(0, 0.5, -1.5);
    this.interact({
      pos: mp, radius: 1.4, icon: '\u{1F440}', label: 'Look at the scratch marks',
      use: () => {
        G.state.set('seen_scratches');
        G.ui.say('Low scratch marks line the den walls… something dug here, long ago.');
        G.state.addArtifact('scratches', 'ahalo', 'Scratches in the Den', 'Low on the den walls, something dug here long ago. Not a cat. Something with bigger paws.');
      },
    });
    // Coconuts under the palms (Godot positions).
    [[10, 20], [-18, -8], [-14, 15], [21, -7]].forEach(([x, z], i) => {
      this.pickup({ id: 'coconut', key: `coconut_${i}`, pos: V3(x, this.height(x, z), z), obj: model('coconut', { height: 0.32 }), bob: false });
    });
  }

  async openGate() {
    G.state.set('seesaw_gate_open');
    await G.wait(0.8);
    G.audio.sfx('gate_open', { vol: 0.9 });
    this.gateSolid.enabled = false;
    G.tween(this.gate.position, { y: 1.5 }, 1.6, ease.inOut);
    G.ui.celebrate('The vine gate rises!', 'The Driftwood Seesaw');
    G.ui.say('The vine gate groans upward… the den lies open.');
  }

  // ── Beat 3: the sundial ────────────────────────────────
  buildSundial() {
    const g = new THREE.Group();
    g.position.copy(SUNDIAL);
    const ped = P.cyl(0.45, 0.55, 0.5, '#9a9a9e', { round: 0.03 }); g.add(ped);
    const dial = P.cyl(0.62, 0.62, 0.1, '#d9ccaa'); dial.position.y = 0.5; g.add(dial);
    for (let i = 0; i < 8; i++) {
      const tick = P.box(0.04, 0.02, 0.18, '#6b5a4a'); const a = (i / 8) * Math.PI * 2;
      tick.position.set(Math.cos(a) * 0.48, 0.6, Math.sin(a) * 0.48); tick.rotation.y = -a; g.add(tick);
    }
    const socket = P.cyl(0.08, 0.08, 0.04, '#2a2520'); socket.position.y = 0.6; g.add(socket);
    this.add(g);
    this.solidCyl(SUNDIAL.x, SUNDIAL.z, 0.62, 0, SUNDIAL.y + 0.62);
    this.dial = g;
    this.targetDir = Math.atan2(TARGET_ROCK.x - SUNDIAL.x, TARGET_ROCK.z - SUNDIAL.z);
    if (G.state.flag('sundial_shell_placed')) this.addGnomon(false);
    this.sense(g, { warm: () => !G.state.flag('sundial_shell_placed') || !G.state.flag('raft_released'), height: 0.7 });
    this.interact({
      obj: g, radius: 1.9, icon: '☀️',
      label: () => (G.state.flag('sundial_shell_placed') ? 'Sight along the shadow' : G.state.has('sun_shell') ? 'Place the Sun Shell' : 'An empty socket…'),
      use: () => {
        if (G.state.flag('sundial_shell_placed')) { this.lightTrail(); G.ui.say('The shadow reaches toward a far rock, out across the water…'); return; }
        if (!G.state.has('sun_shell')) { G.ui.say('An empty socket on the dial… shaped like a shell.'); return; }
        G.state.take('sun_shell');
        G.state.set('sundial_shell_placed');
        G.audio.sfx('stone_slide', { vol: 0.5, rate: 1.3 });
        this.addGnomon(true);
      },
    });
    // The Sun Shell rests on the summit.
    const shell = new THREE.Group();
    const s = P.sphere(0.2, '#ffcf4a', { emissive: '#ffb020', emissiveIntensity: 0.35 }); s.scale.set(1.2, 0.5, 1); s.position.y = 0.25; shell.add(s);
    for (let i = 0; i < 5; i++) { const rib = P.box(0.03, 0.06, 0.42, '#e6a92a', { base: false }); rib.position.y = 0.3; rib.rotation.y = (i - 2) * 0.32; shell.add(rib); }
    this.pickup({ id: 'sun_shell', pos: V3(0, this.height(0, 0), 0), obj: shell });
  }

  addGnomon(withScene) {
    const gn = P.cone(0.22, 0.42, '#ffcf4a', { emissive: '#ffb020', emissiveIntensity: 0.4 });
    gn.position.y = 0.6; this.dial.add(gn);
    // The shadow: a long dark wedge across the summit toward the sea rock.
    const shadow = P.beam(5.2, 0.38, '#2a2a3a', 0.35);
    shadow.material.blending = THREE.NormalBlending;
    shadow.position.set(SUNDIAL.x, SUNDIAL.y + 0.62, SUNDIAL.z);
    shadow.rotation.y = this.targetDir;
    this.add(shadow);
    if (withScene) {
      G.ui.celebrate('A shadow stretches out', 'The Golden Heart');
      G.cine.run(async (c) => {
        this.lightTrail();
        c.look(SUNDIAL, { dist: 9 });
        await c.say('The shell’s shadow stretches far across the water…', { dur: 2.4 });
        c.look(TARGET_ROCK.clone().setY(1), { dist: 16, speed: 1.2 });
        await c.wait(2.6);
      });
    }
  }

  lightTrail() {
    const from = SUNDIAL.clone().setY(SUNDIAL.y + 0.8), to = TARGET_ROCK.clone().setY(1.6);
    for (let i = 0; i < 18; i++) {
      setTimeout(() => G.fx.sparkle(from.clone().lerp(to, (i + 1) / 18), '#ffe48a', 3), i * 110);
    }
  }

  // ── Sea rocks + gulls + the raft frame ─────────────────
  buildSeaRocks() {
    this.seaRocks = [];
    const R = rng(4243);
    const all = [{ pos: TARGET_ROCK, target: true }, ...DECOYS.map((p) => ({ pos: p, target: false }))];
    for (let i = 0; i < 4; i++) {
      const a = R.range(0, 6.28), r = R.range(45, 52);
      const p = V3(Math.cos(a) * r, -0.8, Math.sin(a) * r);
      if (p.z > 24 && Math.abs(p.x) < 26) continue;
      all.push({ pos: p, target: false, plain: true });
    }
    for (const info of all) {
      const top = 1.3;
      const rk = P.rock(2.1, '#9b8a78', info.pos.x, 0.85);
      rk.position.set(info.pos.x, top - 2.1 * 0.85 * 1.05, info.pos.z);
      this.add(rk);
      this.solidCyl(info.pos.x, info.pos.z, 1.75, -8, top);
      // Step stone toward the island so a swimmer can climb out.
      const dir = V3(-info.pos.x, 0, -info.pos.z).normalize();
      const sp = info.pos.clone().addScaledVector(dir, 2.4);
      const step = P.rock(0.9, '#a6957f', info.pos.z, 0.6);
      step.position.set(sp.x, 0.05 - 0.9 * 0.6 * 1.05, sp.z);
      this.add(step);
      this.solidCyl(sp.x, sp.z, 0.8, -8, 0.05);
      if (info.plain) continue;
      info.top = V3(info.pos.x, top, info.pos.z);
      this.seaRocks.push(info);
      if (!(info.target && G.state.flag('raft_released'))) this.addGulls(info);
      this.sense(rk, { warm: () => info.target && G.state.flag('sundial_shell_placed') && !G.state.flag('raft_released'), height: 2.4, radius: 14 });
    }
    this.onVocal((e) => {
      if (e.kind !== 'meow') return;
      for (const info of this.seaRocks) {
        if (Math.hypot(e.pos.x - info.top.x, e.pos.z - info.top.z) < 4.8 && e.pos.y > 0.5) { this.scatterGulls(info); break; }
      }
    });
  }

  addGulls(info) {
    info.birds = [];
    for (let i = 0; i < 3; i++) {
      const b = model('gull', { height: 0.55 });
      b.position.set(info.pos.x + (i - 1) * 0.7, info.top.y, info.pos.z + (i % 2 ? 0.5 : -0.4));
      b.rotation.y = Math.random() * 6.28;
      this.add(b);
      info.birds.push(b);
      const ph = Math.random() * 6;
      this.every(() => { if (!b.parent) return true; b.position.y = info.top.y + Math.abs(Math.sin(G.time * 1.6 + ph)) * 0.04; });
    }
  }

  scatterGulls(info) {
    if (!info.birds?.length) return;
    G.audio.sfx('gull', { pos: info.top, vol: 1, rate: 1.1 });
    setTimeout(() => G.audio.sfx('gull', { pos: info.top, vol: 0.8, rate: 0.92 }), 200);
    for (const b of info.birds) {
      const to = b.position.clone().add(V3((Math.random() - 0.5) * 5, 7 + Math.random() * 2, (Math.random() - 0.5) * 5));
      G.tween(b.position, { x: to.x, y: to.y, z: to.z }, 1.5, ease.in);
      G.tween(b.scale, { x: 0.05, y: 0.05, z: 0.05 }, 1.5, ease.in).then(() => b.removeFromParent());
    }
    info.birds = [];
    if (info.target) { if (!G.state.flag('raft_released')) this.releaseRaft(); }
    else {
      G.ui.toast('The gulls resettle somewhere else… unimpressed.', '\u{1F426}');
      setTimeout(() => { if (G.island === this) this.addGulls(info); }, 25000);
    }
  }

  async releaseRaft() {
    G.state.set('raft_released');
    G.ui.celebrate('The gulls burst skyward!', 'The Shadow’s Rock');
    G.audio.sfx('splash', { vol: 0.8, rate: 0.8 });
    G.audio.sfx('wood_creak', { vol: 0.6 });
    const frame = this.raftFrame;
    frame.visible = true;
    frame.position.copy(TARGET_ROCK).add(V3(-3, 0.18 + WATER + 0.8, 3));
    await G.cine.run(async (c) => {
      c.say('Something shakes loose from the reef below…');
      const path = [V3(52, WATER + 0.2, 10), V3(20, WATER + 0.25, 40), BEACH.clone()];
      for (const [i, p] of path.entries()) {
        const follow = this.every(() => { c.look(frame.position.clone().setY(0.5), { dist: 13, speed: 2 }); });
        await G.tween(frame.position, { x: p.x, y: p.y, z: p.z }, i === 2 ? 1.8 : 2.2, ease.inOut);
        this.updaters.splice(this.updaters.indexOf(follow), 1);
        frame.rotation.y += 0.4;
      }
      G.state.set('raft_frame_beached');
      this.raftSolid.enabled = true;
      G.audio.sfx('wood_creak', { vol: 0.6 });
      await c.say('Timbers wash up on the south beach.', { dur: 2 });
    });
  }

  buildRaft() {
    const frame = new THREE.Group();
    for (const z of [-0.7, 0, 0.7]) { const log = P.cyl(0.18, 0.18, 2.6, '#b8a68c', { base: false, seg: 10 }); log.rotation.z = Math.PI / 2; log.position.set(0, 0.18, z); frame.add(log); }
    for (const x of [-1, 1]) { const cross = P.box(0.16, 0.12, 1.9, '#8a7458', { base: false }); cross.position.set(x, 0.38, 0); frame.add(cross); }
    this.add(frame);
    this.raftFrame = frame;
    this.raftParts = new THREE.Group(); frame.add(this.raftParts);
    frame.visible = G.state.flag('raft_frame_beached');
    if (frame.visible) frame.position.copy(BEACH);
    for (const id of Object.keys(RAFT_PARTS)) if (G.state.flag(`raft_${id}`)) this.addRaftPart(id);
    if (this.raftComplete()) this.swapToRaft();
    this.raftSolid = this.solidBox(BEACH.x, BEACH.z, 2.7, 1.9, -1, 0.5, 0, { enabled: frame.visible });
    this.interact({
      obj: frame, radius: 2.6, icon: '⛵',
      enabled: () => G.state.flag('raft_frame_beached') && !this.sailing,
      label: () => (this.raftComplete() ? 'Set sail' : Object.keys(RAFT_PARTS).some((id) => !G.state.flag(`raft_${id}`) && G.state.has(id)) ? 'Rig the raft' : 'Examine the timbers'),
      use: () => this.rigRaft(),
    });
    this.sense(frame, { warm: () => G.state.flag('raft_frame_beached'), height: 0.6 });
  }
  raftComplete() { return Object.keys(RAFT_PARTS).every((id) => G.state.flag(`raft_${id}`)); }
  missingParts() { return Object.keys(RAFT_PARTS).filter((id) => !G.state.flag(`raft_${id}`)).map((id) => RAFT_PARTS[id]).join(', '); }
  addRaftPart(id) {
    const g = this.raftParts;
    if (id === 'old_oar') { const s = P.cyl(0.04, 0.04, 1.4, '#b8a68c', { base: false }); s.rotation.set(0, 0.5, 1.25); s.position.set(-0.5, 0.42, 0.35); g.add(s); }
    if (id === 'palm_frond') { const m = P.cyl(0.05, 0.05, 2, '#8a7458'); m.position.set(0.15, 0.3, 0); g.add(m); const sail = P.box(0.04, 1.1, 1.2, '#d8bd5e', { base: false }); sail.position.set(0.2, 1.6, 0); g.add(sail); }
    if (id === 'vine_rope') for (const x of [-1, 1]) { const k = P.torus(0.2, 0.05, '#6b8048'); k.rotation.y = Math.PI / 2; k.position.set(x, 0.3, 0); g.add(k); }
  }
  swapToRaft() {
    if (this.raftModel) return;
    this.raftParts.visible = false;
    for (const c of this.raftFrame.children) if (c !== this.raftParts) c.visible = false;
    const r = model('raft', { size: 3.0 });
    this.raftFrame.add(r);
    this.raftModel = r;
  }
  rigRaft() {
    if (this.raftComplete()) { this.setSail(); return; }
    let placed = false;
    for (const id of Object.keys(RAFT_PARTS)) {
      if (!G.state.flag(`raft_${id}`) && G.state.has(id)) {
        G.state.take(id); G.state.set(`raft_${id}`); this.addRaftPart(id); placed = true;
      }
    }
    if (placed) {
      G.audio.sfx('wood_creak', { vol: 0.6 }); G.audio.sfx('pickup_chime', { vol: 0.5, rate: 0.9 });
      if (this.raftComplete()) {
        G.state.set('raft_rigged');
        G.fx.sparkle(this.raftFrame.position.clone().setY(1), '#ffe48a', 18);
        this.swapToRaft();
        G.ui.celebrate('The raft is ready!', 'Rig the Raft');
        G.ui.say('The raft is ready. The sea is waiting.');
      } else G.ui.say(`Lashed on. Still missing: ${this.missingParts()}.`);
    } else G.ui.say(`The frame wants: ${this.missingParts()}.`);
  }

  async setSail() {
    this.sailing = true;
    G.state.set('set_sail_started');
    G.audio.music('intro', { fade: 2.5 });
    const raft = this.raftFrame;
    await G.cine.run(async (c) => {
      G.player.teleport(raft.position.x, raft.position.z, Math.PI, raft.position.y + 0.45);
      this.raftSolid.enabled = false;
      c.look(raft.position.clone().setY(0.6), { dist: 11, pitch: 30, speed: 1.5 });
      const ride = this.every(() => { G.player.pos.set(raft.position.x, raft.position.y + 0.45, raft.position.z); G.player.velocity.set(0, 0, 0); });
      await c.say('And so, with borrowed timbers and a stranger’s wish, Khione left the only home she had ever known.', { dur: 4.5 });
      G.tween(raft.position, { z: 70, y: WATER + 0.05 }, 9, ease.in);
      await c.wait(2.5);
      c.look(V3(-3, 0.3, 31), { dist: 8, pitch: 45, speed: 1 });
      await c.say('Behind her, the beach held its breath.', { dur: 3 });
      // Prints in the sand that are not hers.
      for (let i = 0; i < 9; i++) {
        const pr = P.decal(0.16, '#8a7050', 0.45);
        pr.scale.set(1, 1.35, 1);
        pr.position.set(-6 + i * 0.75 + (i % 2) * 0.12, this.height(-6 + i * 0.75, 31.5 - i * 0.3) + 0.03, 31.5 - i * 0.3 + (i % 2 ? 0.25 : -0.25));
        this.add(pr);
      }
      await c.wait(1.2);
      await c.say('And in the sand, pressed soft, were prints that were not hers.', { dur: 3.6 });
      G.state.addArtifact('pawprints', 'ahalo', 'Pawprints on the Beach', 'As the raft pulled away, prints appeared in the sand. Bigger than hers. Somebody was watching her go.');
      this.updaters.splice(this.updaters.indexOf(ride), 1);
    }, { skippable: true });
    await G.game.finishIsland();
  }

  // ── Beat 4b: the frond on the tallest palm ─────────────
  buildFrondPalm() {
    const base = FROND_PALM;
    const tall = model('palm', { height: 8.2 }); tall.position.copy(base); this.add(tall);
    this.solidCyl(base.x, base.z, 0.35, -1, 7);
    const bent = model('palm', { height: 4.6, rotY: 0.4 }); bent.position.set(base.x - 2.6, base.y, base.z + 0.6); bent.rotation.z = 0.25; this.add(bent);
    this.solidCyl(base.x - 2.6, base.z + 0.6, 0.3, -1, 0.9);
    // Boulder + two crown ledges to climb.
    const boulder = P.rock(0.8, '#a38668', 31, 0.8);
    boulder.position.set(base.x - 4.2, base.y - 0.1, base.z + 1.5); this.add(boulder);
    this.solidCyl(base.x - 4.2, base.z + 1.5, 0.75, -1, base.y + 0.65);
    for (const [x, y, z, s] of [[-3.2, 1.05, 0.9, 1.3], [-2.2, 2.25, 0.4, 1.5]]) {
      const ledge = P.box(s, 0.18, s, '#6faa48', { round: 0.08 });
      ledge.position.set(base.x + x, base.y + y - 0.09, base.z + z);
      this.add(ledge);
      this.solidBox(base.x + x, base.z + z, s, s, base.y + y - 0.2, base.y + y + 0.09);
    }
    if (G.state.flag('frond_down') || G.state.flag('raft_palm_frond')) {
      if (!G.state.flag('took_palm_frond') && !G.state.flag('raft_palm_frond')) this.dropFrondPickup();
      return;
    }
    const frond = new THREE.Group();
    frond.position.set(base.x + 0.3, base.y + 3.35 + 0.3, base.z + 0.3);
    for (let i = 0; i < 4; i++) {
      const blade = P.box(1.2, 0.04, 0.3, '#e0c060', { base: false, emissive: '#e0c060', emissiveIntensity: 0.25 });
      blade.position.x = 0.5; blade.rotation.y = -0.65 + i * 0.42; blade.rotation.z = -0.28;
      frond.add(blade);
    }
    this.add(frond);
    this.frond = frond;
    this.sense(frond, { warm: () => G.state.flag('raft_frame_beached'), height: 0, radius: 12 });
    this.every(() => {
      if (!this.frond) return true;
      frond.rotation.z = Math.sin(G.time * 1.3) * 0.05;
      const p = G.player.pos;
      if (Math.hypot(p.x - frond.position.x, p.z - frond.position.z) < 1.6 && Math.abs(p.y + 0.5 - frond.position.y) < 1.3) { this.knockFrond(); return true; }
    });
  }
  knockFrond() {
    const f = this.frond; this.frond = null;
    G.state.set('frond_down');
    G.audio.sfx('paper_open', { vol: 0.8, rate: 0.6 }); G.audio.sfx('wood_creak', { vol: 0.4, rate: 1.3 });
    const to = V3(FROND_PALM.x + 0.9, FROND_PALM.y + 0.15, FROND_PALM.z + 0.9);
    G.tween(f.rotation, { x: 0.4, y: 1.2, z: 1.3 }, 0.9);
    G.tween(f.position, { x: to.x, y: to.y, z: to.z }, 0.9, ease.in).then(() => {
      G.audio.sfx('land', { vol: 0.6 }); f.removeFromParent();
      this.dropFrondPickup();
      G.ui.say('A great dry frond drops to the grass.');
    });
  }
  dropFrondPickup() {
    const obj = new THREE.Group();
    for (let i = 0; i < 4; i++) { const b = P.box(1.1, 0.03, 0.28, '#e0c060', { base: false }); b.rotation.y = -0.6 + i * 0.4; b.position.y = 0.05; obj.add(b); }
    this.pickup({ id: 'palm_frond', pos: V3(FROND_PALM.x + 0.9, this.height(FROND_PALM.x + 0.9, FROND_PALM.z + 0.9), FROND_PALM.z + 0.9), obj, bob: false });
  }

  // ── Beat 4c: the crab and the vines ───────────────────
  buildCrab() {
    const rk = P.rock(1.8, '#a08468', 77, 1.0);
    rk.position.set(CRAB.x, this.height(CRAB.x, CRAB.z - 1.5) - 0.3, CRAB.z - 1.5); this.add(rk);
    this.solidCyl(CRAB.x, CRAB.z - 1.5, 1.5, -1, 2.6);
    this.vines = [];
    if (!G.state.flag('vines_snipped')) {
      for (let i = 0; i < 3; i++) {
        const v = P.cyl(0.05, 0.05, 2.2, '#5c8540', { base: false, seg: 6 });
        v.position.set(CRAB.x - 0.5 + i * 0.5, 1.4, CRAB.z - 0.2); v.rotation.z = 0.06 - i * 0.05;
        this.add(v); this.vines.push(v);
      }
    } else if (!G.state.flag('took_vine_rope') && !G.state.flag('raft_vine_rope')) this.dropRope();
    const crab = model('crab', { height: 0.55 });
    crab.position.set(CRAB.x + 0.4, this.height(CRAB.x, CRAB.z + 1.2), CRAB.z + 1.2);
    this.add(crab);
    this.crab = crab;
    this.every(() => { crab.position.x = CRAB.x + 0.4 + Math.sin(G.time * 1.9) * 0.5; crab.rotation.y = Math.sin(G.time * 0.7) * 0.4; });
    this.sense(crab, { warm: () => !G.state.flag('vines_snipped') && G.state.has('stranded_fish'), height: 0.5 });
    this.interact({
      obj: crab, radius: 2.0, icon: '\u{1F980}',
      enabled: () => !G.state.flag('vines_snipped'),
      label: () => (G.state.has('stranded_fish') ? 'Offer the Stranded Fish' : 'A crab guards the vines'),
      use: () => {
        if (!G.state.has('stranded_fish')) {
          G.audio.sfx('crab_snip', { vol: 0.7 });
          G.ui.say('The crab snaps its claws and eyes Khione’s empty paws. It looks hungry.');
          return;
        }
        G.state.take('stranded_fish');
        G.state.set('vines_snipped');
        G.audio.sfx('crab_snip', { vol: 1 }); setTimeout(() => G.audio.sfx('crab_snip', { vol: 0.8, rate: 1.15 }), 350);
        G.animate(0.7, (t) => { crab.position.y = this.height(CRAB.x, CRAB.z + 1.2) + Math.abs(Math.sin(t * Math.PI * 2)) * 0.35; });
        for (const v of this.vines) G.tween(v.position, { y: 0.1 }, 0.7, ease.in).then(() => v.removeFromParent());
        this.vines = [];
        setTimeout(() => this.dropRope(), 800);
        G.ui.celebrate('Snip, snip!', 'A fair trade');
        G.ui.say('A fair trade. The crab cuts you a length of vine.');
      },
    });
  }
  dropRope() {
    const coil = P.torus(0.22, 0.06, '#5c8540'); coil.rotation.x = Math.PI / 2; coil.position.y = 0.08;
    this.pickup({ id: 'vine_rope', pos: V3(CRAB.x, this.height(CRAB.x, CRAB.z - 0.1), CRAB.z - 0.1), obj: coil, bob: false });
  }

  // ── Little story flourishes ───────────────────────────
  buildFlourishes() {
    // The nest she wakes in.
    const nest = new THREE.Group();
    const ring = P.torus(0.55, 0.16, '#c9b070'); ring.rotation.x = Math.PI / 2; ring.position.y = 0.1; nest.add(ring);
    const bed = P.cyl(0.5, 0.5, 0.06, '#a8c070'); nest.add(bed);
    const ribbon = P.box(0.5, 0.02, 0.06, '#ff6b8a'); ribbon.position.set(0.15, 0.08, 0.1); ribbon.rotation.y = 0.6; nest.add(ribbon);
    const cap = P.cyl(0.07, 0.07, 0.03, '#d0d0d0'); cap.position.set(-0.2, 0.08, -0.15); nest.add(cap);
    nest.position.copy(NEST); this.add(nest);
    let nestSeen = 0;
    this.interact({
      obj: nest, radius: 1.6, icon: '\u{1F3E1}', label: 'Her nest',
      use: () => { nestSeen++; G.ui.say(nestSeen === 1 ? 'Pressed grass, a ribbon, a bottle cap. Your harbour, before the letter came.' : 'The nest still holds your shape. It will keep holding it.'); },
    });
    // A streetlamp that should not exist.
    const lamp = new THREE.Group();
    const post = P.cyl(0.07, 0.09, 1.1, '#3c4a52'); lamp.add(post);
    const head = P.box(0.32, 0.3, 0.32, '#3c4a52', { round: 0.04 }); head.position.y = 1.05; lamp.add(head);
    const bulb = P.sphere(0.11, '#fff2b0', { emissive: '#ffd27a', emissiveIntensity: 0.3 }); bulb.position.y = 1.08; lamp.add(bulb);
    lamp.position.copy(LAMP); lamp.rotation.z = 0.32; lamp.rotation.x = -0.12;
    this.add(lamp);
    this.every(() => { bulb.material.emissiveIntensity = Math.random() < 0.02 ? 1.2 : 0.3; });
    let lampSeen = 0;
    this.interact({
      obj: lamp, radius: 1.8, icon: '\u{1F4A1}', label: 'A buried lamppost?',
      use: () => {
        lampSeen++;
        if (lampSeen === 1) G.ui.say('It smells like rain on warm pavement. Like a street you have walked before.');
        else if (lampSeen === 2) G.ui.say('But you have always lived on this island. Haven’t you?');
        else G.ui.say('The lamp stutters its small light, remembering a city.');
      },
    });
    // Far towers on the southern horizon, catching the sun now and then.
    const towers = new THREE.Group();
    for (const [x, z, h, w] of [[10, 105, 16, 5], [-2, 108, 11, 4], [20, 103, 8, 3.5]]) {
      const t = P.box(w, h, w, '#b6c8d6', { emissive: '#c0d6e6', emissiveIntensity: 0.3 });
      t.position.set(x, -1, z); t.castShadow = false; towers.add(t);
    }
    this.add(towers);
  }

  // ── Arrival, goals ─────────────────────────────────────
  async onEnter(first) {
    if (G.state.flag('intro_done')) return;
    await G.cine.run(async (c) => {
      c.cut(V3(0, 1, 0), { dist: 46, pitch: 38, yaw: 200 });
      await c.wait(0.4);
      c.look(V3(0, 1, 0), { dist: 40, pitch: 40, yaw: 230, speed: 0.4 });
      await c.say('Once upon a time, on a small and lonely island called Ahalo, there lived a small white Persian cat named Khione.', { dur: 5 });
      c.look(G.player.pos.clone().setY(G.player.pos.y + 0.5), { dist: 6, pitch: 30, speed: 0.8 });
      await c.say('She knew no one, and no one knew her. She hunted fish, ate berries, and drank from the river that crossed the island.', { dur: 5 });
      await c.say('She cured her boredom by chasing snails along the beach, and by leaping from branch to branch like a monkey.', { dur: 4.5 });
      c.look(BOTTLE.clone().setY(0.4), { dist: 9, pitch: 35, speed: 0.9 });
      await c.say('But one morning, the tide brought something that had never come before…', { dur: 4 });
      G.fx.sparkle(BOTTLE.clone().setY(0.6), '#ffffff', 12);
      await c.say('A bottle, with a letter inside.', { dur: 3 });
    });
    G.state.set('intro_done');
    G.ui.toast('Reach the bottle on the south beach…', '\u{1F43E}');
  }

  objective() {
    const s = G.state;
    if (s.flag('set_sail_started')) return null;
    if (!s.flag('letter_read')) return 'Reach the bottle on the south beach';
    if (!s.flag('echo_stones_solved')) return 'Find the humming stones in the east cove';
    if (!s.flag('seesaw_gate_open')) return 'Open the vine gate on the west hillside';
    if (!s.flag('sundial_shell_placed')) return 'The summit dial wants its golden heart';
    if (!s.flag('raft_released')) return 'Climb where the shadow points, and speak';
    if (!s.flag('raft_frame_beached')) return 'Loose timbers drift toward the south beach…';
    if (!this.raftComplete()) return `Rig the raft: ${this.missingParts()}`;
    return 'The raft is ready. Set sail!';
  }
  hint() {
    const s = G.state;
    if (!s.flag('letter_read')) return 'Reach the bottle on the south beach. (Tap it, and Khione walks right over.)';
    if (!s.flag('echo_stones_solved')) return 'The letter is torn, but the island is humming. Three hollow stones wait by the eastern cove, and a carving remembers their song. (Tap \u{1F431} to meow)';
    if (!s.flag('seesaw_gate_open')) return 'Something sleeps behind the vine gate on the west hillside. Old wood tips under heavy things, and the palms drop them.';
    if (!s.flag('sundial_shell_placed')) return 'Atop the old summit, a dial waits for its golden heart.';
    if (!s.flag('raft_released')) return 'The shell’s shadow points far across the water. Climb where it leads, and speak.';
    if (!s.flag('raft_frame_beached')) return 'Loose timbers drift toward the south beach…';
    if (!this.raftComplete()) return `Bind the raft. It still wants ${this.missingParts()}. The den keeps an oar, the tallest palm a dry frond, and the crab trades for a price.`;
    return 'The raft is ready. The sea is waiting.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.flag('letter_read')) return BOTTLE;
    if (!s.flag('echo_stones_solved')) return ECHO;
    if (!s.flag('seesaw_gate_open')) return DEN;
    if (!s.flag('sundial_shell_placed')) return s.has('sun_shell') ? SUNDIAL : V3(0, 3.3, 0);
    if (!s.flag('raft_released')) return TARGET_ROCK.clone().setY(1.3);
    if (!s.flag('raft_frame_beached')) return BEACH;
    return BEACH;
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'bottle', name: 'The Bottle', done: s.flag('letter_read'), hint: 'Reach the bottle on the south beach.' },
      { id: 'echo', name: 'The Three Hollow Stones', done: s.flag('echo_stones_solved'), hint: 'Three hollow stones hum by the eastern cove, and a carving remembers their song.' },
      { id: 'seesaw', name: 'The Driftwood Seesaw', done: s.flag('seesaw_gate_open'), hint: 'Old wood tips under heavy things.' },
      { id: 'sundial', name: 'The Sundial Reef', done: s.flag('raft_released'), hint: 'Atop the old summit, a dial waits for its golden heart.' },
      { id: 'raft', name: 'Rig the Raft', done: s.flag('raft_rigged'), hint: 'The frame wants an oar, a sail, and rope to bind it.' },
      { id: 'sail', name: 'Set Sail', done: s.flag('island1_complete'), hint: 'The raft is ready. The sea is waiting.' },
    ];
  }
}
