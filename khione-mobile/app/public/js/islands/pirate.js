// Island 5 — The Pirate Ship. West Edmonton Mall distilled to a kid's fever
// dream: an indoor sea, a wave machine, the galleon Santa Maria, a mini-golf
// reef, one loud parrot. Teaches: growl. Built from the riddle compendium.
import * as THREE from 'three';
import { G, rng, clamp, lerp, fbm, ease, V3 } from '../engine/core.js';
import { Island } from '../engine/world.js';
import { model, instanced } from '../engine/assets.js';
import { P } from '../engine/prefabs.js';
import { makeWaterMaterial } from '../engine/render.js';
import { registerItems } from '../engine/state.js';

registerItems({
  mini_putter: { name: 'Mini Putter', icon: '⛳', desc: 'A kid-sized putter, abandoned on the high platform. Nine holes on the reef are waiting.' },
  captains_whistle: { name: 'Captain’s Whistle', icon: '\u{1F4EF}', desc: 'Brass, salty, and very loud. One blow and Oreo is at her side, wherever he was.' },
  spigot_wheel: { name: 'Spigot Wheel', icon: '☸️', desc: 'A brass valve wheel from behind the aquarium grate. Somewhere, a drydock is thirsty.' },
});

// ── Layout (water at 0, deck at 0.4) ─────────────────────
const POOL = [-17, 17, -13, 12];
const CHAN = [-6, 6, 12, 36];
const DOCK = [-7.5, 7.5, -28, -13];
const REEF = V3(-9.5, 0.6, 1), REEF_R = 4.5;
const PLAT = { x0: 9, x1: 12.5, z0: -3, z1: 3, top: 1.5 };
const SHIP = V3(0, -0.6, -20.5);   // keel resting on blocks in the dock
const DECK_H = 3.08;                // main deck height above the keel
const QD = 0.92;                    // quarterdeck step at the stern
const SPIGOT = V3(-8.9, 0.4, -16);
const BOOTH = V3(11.5, 0.4, -17);
const PERCH = V3(12.6, 0.4, 17);
const SPAWN = V3(10, 0.4, 24);
const TANK = { x0: 19, x1: 29, z0: -9, z1: 13 };
const GRATES = [-6, -2, 2.5, 6.5, 10.5];
const TRUE_GRATE = 3;
const CYCLE = 17;
const SMALL_AMP = 0.32, BIG = 1.9, MAX = 2.85;
const JR = new Set(['black', 'white', 'red']);
const HOLES = [
  ['blue', '#2f6fd6'], ['white', '#ffffff'], ['green', '#3fae4a'], ['red', '#d6322b'], ['yellow', '#f2c230'],
  ['purple', '#8a4fd0'], ['black', '#1c1c1c'], ['orange', '#ff8a1f'], ['pink', '#ff8fc0'],
];
const VOX_ICON = { meow: '\u{1F431}', growl: '\u{1F42F}', hiss: '\u{1F640}' };
const PARROT_SONG = ['meow', 'growl', 'hiss', 'meow', 'hiss', 'growl', 'meow'];

const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
function boxD(x, z, [x0, x1, z0, z1]) {
  const dx = Math.max(x0 - x, x - x1), dz = Math.max(z0 - z, z - z1);
  if (dx <= 0 && dz <= 0) return Math.max(dx, dz);
  return Math.hypot(Math.max(dx, 0), Math.max(dz, 0));
}

export default class PirateShip extends Island {
  static id = 'pirate';

  constructor() {
    super();
    this.waterLevel = 0;
    this.bounds = { x: 0, z: 0, r: 47 };
    this.waveT = 0;
    this.waveHold = null;
    this.mocks = 0;
    this.dockLevel = -1.2;
  }

  models() { return ['galleon', 'parrot', 'pelican', 'palm']; }
  sounds() { return ['big_wave', 'cannon', 'parrot', 'growl', 'bark', 'bell_ding', 'gate_open', 'wood_creak', 'drain', 'splash', 'smash', 'chime', 'coin', 'fanfare', 'stone_slide']; }
  atmosphere() {
    return { sky: '#bfe3f2', fog: '#d6eef8', fogNear: 55, fogFar: 140, sun: '#fff0dc', sunIntensity: 2.3, hemi: 1.35, skyLight: '#fff6e8', groundLight: '#8a9ab0', exposure: 1.05 };
  }
  music() { return 'pirate'; }
  terrainTextures() { return ['mall_floor.jpg', 'planks.jpg', 'sand.jpg']; }

  wetD(x, z) { return Math.min(boxD(x, z, POOL), boxD(x, z, CHAN), boxD(x, z, DOCK)); }
  height(x, z) {
    let h = 0.4;
    const hd = boxD(x, z, [-33, 33, -33, 33]);
    if (hd > 0 && boxD(x, z, CHAN) > 0) h = lerp(0.4, -6, clamp(hd / 3, 0, 1));
    const wet = this.wetD(x, z);
    const target = boxD(x, z, DOCK) < 0 ? -1.2 : -3;
    h = lerp(h, target, 1 - ss(-0.6, 0, wet));
    const r = Math.hypot(x - REEF.x, z - REEF.z);
    h = lerp(h, 0.6, 1 - ss(REEF_R - 0.8, REEF_R, r));
    return h;
  }
  splat(x, z) {
    const h = this.height(x, z);
    if (Math.hypot(x - REEF.x, z - REEF.z) < REEF_R || h < 0.3) return [0, 0, 1];
    const w = this.wetD(x, z);
    if (w > 0 && w < 2.2 && boxD(x, z, [-33, 33, -33, 33]) < 0) return [0, 1, 0];
    return [1, 0, 0];
  }
  tint(x, z) {
    const h = this.height(x, z);
    const c = new THREE.Color('#ffffff');
    if (h < -0.5) c.lerp(new THREE.Color('#4aa3b8'), 0.35);
    c.multiplyScalar(0.95 + fbm(x * 0.2, z * 0.2) * 0.08);
    return c;
  }
  footstep(x, z) { return Math.hypot(x - REEF.x, z - REEF.z) < REEF_R ? 'paw_sand' : 'paw_grass'; }
  dustColor() { return '#efe4cc'; }

  region(x, z) {
    if (boxD(x, z, DOCK) < 0) return 'dock';
    if (boxD(x, z, POOL) < 0 || boxD(x, z, CHAN) < 0) return 'pool';
    return null;
  }
  isWater(x, z) {
    const r = this.region(x, z);
    if (!r) return false;
    if (r === 'dock' && !G.state.flag('drydock_flooded')) return false;
    return this.height(x, z) < this.waterLevel - 0.45 && !this._onSolidTop(x, z);
  }

  spawn() { return { x: SPAWN.x, z: SPAWN.z, rotY: Math.PI }; }

  // ── Build ─────────────────────────────────────────────
  build() {
    this.makeTerrain({ size: 120, res: 150, repeat: 0.18 });
    this.makeWater({ level: -1.5, size: 280, res: 90 });
    this.waterLevel = 0;
    this.buildPoolWater();
    this.buildHall();
    this.buildWaveMachine();
    this.buildPlatform();
    this.buildReef();
    this.buildShip();
    this.buildDock();
    this.buildAquarium();
    this.buildParrot();
    this.buildWhistleButton();
    G.audio.ambient('ocean_loop', 0.12);
  }

  buildPoolWater() {
    const mat = makeWaterMaterial({ deep: '#14a6c9', light: '#6fe0ee', opacity: 0.86, scale: 0.12 });
    const make = ([x0, x1, z0, z1], floor) => {
      const g = new THREE.BoxGeometry(x1 - x0, 1, z1 - z0);
      g.translate((x0 + x1) / 2, 0.5, (z0 + z1) / 2);
      g.setAttribute('shore', new THREE.BufferAttribute(new Float32Array(g.attributes.position.count), 1));
      const m = new THREE.Mesh(g, mat);
      m.position.y = floor;
      m.renderOrder = 1;
      this.add(m);
      return m;
    };
    this.poolMat = mat;
    this.poolBoxes = [make(POOL, -3.05), make([CHAN[0], CHAN[1], 12, 31.6], -3.05)];
    this.dockBox = make(DOCK, -1.25);
    if (G.state.flag('drydock_flooded')) this.dockLevel = 0;
  }

  buildHall() {
    const deco = new THREE.Group();
    // Tall shopfronts north and west; low glass east and south so the iso camera sees in.
    const wallMat = '#efe2cc';
    const nw = P.box(66, 6, 0.6, wallMat); nw.position.set(0, 0.4, -33.3); deco.add(nw);
    const ww = P.box(0.6, 6, 66, wallMat); ww.position.set(-33.3, 0.4, 0); deco.add(ww);
    this.solidBox(0, -33.3, 66, 0.6, -2, 8);
    this.solidBox(-33.3, 0, 0.6, 66, -2, 8);
    this.solidBox(33.3, 0, 0.6, 66, -2, 8);
    this.solidBox(-19.5, 33.3, 27, 0.6, -2, 8);
    this.solidBox(19.5, 33.3, 27, 0.6, -2, 8);
    const glass = new THREE.MeshLambertMaterial({ color: '#cfefff', transparent: true, opacity: 0.28, depthWrite: false });
    for (const [x, z, w, d] of [[33.3, 0, 0.2, 66], [-19.5, 33.3, 27, 0.2], [19.5, 33.3, 27, 0.2]]) {
      const gw = new THREE.Mesh(new THREE.BoxGeometry(w, 1.6, d), glass); gw.position.set(x, 1.2, z); this.add(gw);
      const rail = P.box(w + 0.1, 0.12, d + 0.1, '#7a8c9a'); rail.position.set(x, 1.95, z); deco.add(rail);
    }
    // Shops along the north wall.
    const R = rng(505);
    const shopCols = ['#ffb3c7', '#9fd6e8', '#ffe08a', '#b9e3a4', '#d7b9ff', '#ffc89a'];
    for (let i = 0; i < 6; i++) {
      const x = -28 + i * 11.2;
      if (Math.abs(x) < 9) continue;
      const b = P.building({ w: 8, d: 4, h: 4.5, wall: shopCols[i], roof: '#c8b8a0', flat: true, windows: '#bfe9ff' });
      b.position.set(x, 0.4, -30.6); deco.add(b);
      this.solidBox(x, -30.6, 8, 4, -1, 5);
    }
    // Pillars and a skylight truss along the edges (no roof: we're looking down through it).
    for (const [x, z] of [[-31, -31], [-31, 31], [31, -31], [31, 31], [-31, 0], [0, -31]]) {
      const p = P.cyl(0.55, 0.65, 7, '#e8dcc4'); p.position.set(x, 0.4, z); deco.add(p);
      this.solidCyl(x, z, 0.6, -1, 8);
    }
    // Umbrellas and loungers on the deck.
    const umbCols = ['#ff6b4a', '#1fb5c9', '#ffc93c'];
    for (let i = 0; i < 10; i++) {
      const x = R() < 0.5 ? R.range(-30, -19) : R.range(-14, 16), z = R.range(15, 30);
      if (boxD(x, z, CHAN) < 2 || Math.hypot(x - PERCH.x, z - PERCH.z) < 3 || Math.hypot(x - SPAWN.x, z - SPAWN.z) < 3) continue;
      const pole = P.cyl(0.05, 0.05, 2.3, '#f6f0e4'); pole.position.set(x, 0.4, z); deco.add(pole);
      const top = P.cone(1.3, 0.55, umbCols[i % 3], { seg: 10 }); top.position.set(x, 2.45, z); deco.add(top);
      const lo = P.box(0.8, 0.25, 1.9, '#ffffff', { round: 0.08 }); lo.position.set(x + 1.2, 0.4, z + 0.3); deco.add(lo);
      this.solidCyl(x, z, 0.15, -1, 2.4);
    }
    this.add(P.bake(deco)); this.add(deco);
    // Indoor palms in planters.
    const palms = [];
    for (const [x, z] of [[-29, -24], [-29, -12], [-29, 10], [-24, 29], [24, 29], [-22, -28], [22, -28], [30, 20]]) {
      palms.push({ x, y: 0.9, z, rotY: x * z, scale: 1 });
      const pl = P.cyl(0.9, 0.8, 0.5, '#c58a5a'); pl.position.set(x, 0.4, z); this.add(pl);
      this.solidCyl(x, z, 0.9, -1, 0.9);
    }
    this.add(instanced('palm', palms, { height: 5.2 }));
    // Glass wave doors at the end of the channel.
    this.doors = [];
    for (const sx of [-1, 1]) {
      const d = new THREE.Group();
      const pane = new THREE.Mesh(new THREE.BoxGeometry(6, 4, 0.25), new THREE.MeshLambertMaterial({ color: '#bfeaff', transparent: true, opacity: 0.4, depthWrite: false }));
      pane.position.y = 1.3;
      const frame = P.box(6.1, 0.25, 0.35, '#5c7080'); frame.position.y = 3.2;
      d.add(pane, frame);
      d.position.set(sx * 3, 0, 31.6);
      this.add(d);
      this.doors.push(d);
    }
    this.doorSolid = this.solidBox(0, 31.6, 12, 0.5, -4, 8);
    const sign = P.sign(['WAVE DOORS', 'keep clear'], { w: 3, h: 0.9, post: 0, bg: '#173b44', fg: '#ffffff' });
    sign.position.set(0, 3.5, 31.85); sign.rotation.y = Math.PI; this.add(sign);
  }

  // ── The wave machine (Wave Clock) ─────────────────────
  buildWaveMachine() {
    // Louvred wave wall along the pool's north-east edge, with a siren lamp.
    const wall = new THREE.Group();
    const body = P.box(8.5, 2.6, 1.2, '#2c6f8e', { round: 0.1 }); wall.add(body);
    for (let i = 0; i < 6; i++) { const lv = P.box(1.1, 1.6, 0.1, '#9fd6e8'); lv.position.set(-3.4 + i * 1.35, 0.5, 0.62); wall.add(lv); }
    const lamp = P.sphere(0.35, '#ff5040', { emissive: '#ff3020', emissiveIntensity: 0.1 }); lamp.position.set(3.6, 2.9, 0); wall.add(lamp);
    const lbl = P.sign(['WAVE MACHINE'], { w: 3.2, h: 0.7, bg: '#ffc93c' }); lbl.position.set(-1, 2.65, 0.62); wall.add(lbl);
    wall.position.set(12.5, -0.6, -13.4);
    this.add(wall);
    this.solidBox(12.5, -13.4, 8.5, 1.2, -3, 2.6);
    this.siren = lamp;
    this.sense(wall, { warm: () => !G.state.flag('wave_clock_done'), height: 2 });

    // Booth with the stuck MAX SWELL lever and a pelican sitting on it.
    const booth = new THREE.Group();
    const kiosk = P.box(2.6, 2.4, 2.2, '#ffffff', { round: 0.12 }); booth.add(kiosk);
    const stripe = P.box(2.65, 0.4, 2.25, '#ff6b4a'); stripe.position.y = 2.0; booth.add(stripe);
    const win = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 0.9), P.mat('#9fd6e8', { emissive: '#9fd6e8', emissiveIntensity: 0.2 })); win.position.set(0, 1.4, 1.11); booth.add(win);
    const plaque = P.sign(['MAX SWELL'], { w: 1.2, h: 0.4, bg: '#ffc93c' }); plaque.position.set(-1.0, 0.6, 1.12); booth.add(plaque);
    const leverBase = P.box(0.25, 0.25, 0.25, '#555'); leverBase.position.set(-1.0, 1.0, 1.25); booth.add(leverBase);
    const lever = new THREE.Group(); lever.position.set(-1.0, 1.15, 1.3);
    const stick = P.cyl(0.05, 0.05, 0.75, '#c33'); lever.add(stick);
    const knob = P.sphere(0.12, '#ff3020'); knob.position.y = 0.75; lever.add(knob);
    booth.add(lever);
    booth.position.copy(BOOTH);
    this.add(booth);
    this.solidBox(BOOTH.x, BOOTH.z, 2.6, 2.2, -1, 2.8);
    this.lever = lever;
    if (G.state.flag('max_swell')) lever.rotation.x = 1.2;
    else {
      lever.rotation.x = -0.4;
      const pel = model('pelican', { height: 1.1 });
      pel.position.set(BOOTH.x - 1.0, BOOTH.y + 2.4, BOOTH.z + 0.3);
      pel.rotation.y = 0.4;
      this.add(pel);
      this.pelican = pel;
      this.every(() => { if (!this.pelican) return true; pel.rotation.z = Math.sin(G.time * 0.9) * 0.05; });
      this.sense(pel, { warm: () => !G.state.flag('max_swell'), height: 0.8 });
    }
    this.interact({
      pos: BOOTH.clone().add(V3(-1, 0, 1.6)), radius: 2.0, icon: '\u{1F30A}',
      label: () => (G.state.flag('max_swell') ? 'The lever is at MAX' : 'The MAX SWELL lever'),
      use: () => {
        if (G.state.flag('max_swell')) { G.ui.say('MAX SWELL. Every big wave now crests as high as a ship’s deck.'); return; }
        G.ui.say('The MAX SWELL lever is stuck fast. A pelican is sitting on it, and it does not plan to move.');
      },
    });
    this.onVocal((e) => {
      if (G.state.flag('max_swell') || !this.pelican) return;
      if (Math.hypot(e.pos.x - BOOTH.x, e.pos.z - BOOTH.z) > 7) return;
      if (e.kind === 'growl') this.startlePelican();
      else G.ui.toast('The pelican doesn’t budge. Big things listen to something bigger.', '\u{1F9A9}');
    });
  }

  async startlePelican() {
    G.state.set('max_swell');
    const pel = this.pelican; this.pelican = null;
    G.audio.sfx('wood_creak', { vol: 0.6 });
    G.fx.burst(pel.position.clone().add(V3(0, 0.6, 0)), { color: ['#ffffff', '#c9a070'], count: 16, speed: 2, up: 3, size: 0.2 });
    G.tween(this.lever.rotation, { x: 1.2 }, 0.4, ease.outBounce);
    G.audio.sfx('stone_slide', { vol: 0.6, rate: 1.4 });
    G.tween(pel.position, { x: pel.position.x + 14, y: pel.position.y + 10, z: pel.position.z - 8 }, 2.6, ease.in).then(() => pel.removeFromParent());
    G.animate(2.6, (t) => { pel.rotation.z = Math.sin(t * 40) * 0.3; });
    G.ui.celebrate('MAX SWELL!', 'The pelican drops the lever');
    G.ui.say('The pelican startles, flaps, and the lever clunks all the way to MAX. The next big swell will be a monster.');
  }

  waveLevel(t) {
    const peak = G.state.flag('max_swell') ? MAX : BIG;
    if (t < 9) { const s = Math.sin(Math.PI * (t % 3) / 3); return SMALL_AMP * s * s; }
    if (t < 11) return 0;
    if (t < 12.5) return peak * ease.inOut((t - 11) / 1.5);
    if (t < 15) return peak + Math.sin((t - 12.5) * 3) * 0.05;
    return peak * (1 - ease.inOut((t - 15) / 2));
  }

  updateWaves(dt) {
    const prev = this.waveT;
    this.waveT = (this.waveT + dt) % CYCLE;
    const L = this.waveHold ?? this.waveLevel(this.waveT);
    this.waterLevel = L;
    for (const b of this.poolBoxes) b.scale.y = L - b.position.y;
    if (G.state.flag('drydock_flooded') && !this.flooding) this.dockLevel = L;
    this.dockBox.visible = this.dockLevel > -1.15;
    this.dockBox.scale.y = Math.max(0.01, this.dockLevel - this.dockBox.position.y);
    this.poolMat.uniforms.uTime.value = G.time;
    // Siren cue: two seconds of warning, then the big one.
    const warn = this.waveT >= 9 && this.waveT < 15;
    this.siren.material.emissiveIntensity = warn ? 0.6 + Math.sin(G.time * 12) * 0.5 : 0.1;
    if (this.waveHold == null && prev < 9 && this.waveT >= 9) {
      G.audio.sfx('bell_ding', { vol: 0.5, pos: this.siren.getWorldPosition(V3()) , range: 50});
      const p = G.player.pos;
      if (G.player.swimming || this.wetD(p.x, p.z) < 4) G.ui.showBanner('〰️ Big swell coming!', 2);
    }
    if (this.waveHold == null && prev < 11 && this.waveT >= 11) G.audio.sfx('big_wave', { vol: 0.7 });
  }

  buildPlatform() {
    const { x0, x1, z0, z1, top } = PLAT;
    const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    const tower = P.box(x1 - x0, top + 3, z1 - z0, '#f6f0e4', { round: 0.12 }); tower.position.set(cx, -3, cz); this.add(tower);
    const lip = P.box(x1 - x0 + 0.2, 0.15, z1 - z0 + 0.2, '#ff6b4a'); lip.position.set(cx, top - 0.15, cz); this.add(lip);
    const sign = P.sign(['HIGH DECK'], { w: 1.8, h: 0.5, bg: '#1fb5c9', fg: '#fff' }); sign.position.set(cx, top + 0.6, z1 + 0.05); this.add(sign);
    this.solidBox(cx, cz, x1 - x0, z1 - z0, -3.2, top);
    // The putter waits up top.
    const putter = new THREE.Group();
    const shaft = P.cyl(0.03, 0.03, 0.9, '#c0c0c8', { base: false }); shaft.rotation.z = 1.2; shaft.position.y = 0.15; putter.add(shaft);
    const head = P.box(0.28, 0.1, 0.1, '#2f6fd6', { base: false }); head.position.set(0.42, 0.06, 0); putter.add(head);
    this.pickup({ id: 'mini_putter', pos: V3(cx, top, cz), obj: putter, bob: false });
    this.every(() => {
      if (G.state.flag('wave_clock_done')) return true;
      const p = G.player.pos;
      if (p.x > x0 && p.x < x1 && p.z > z0 && p.z < z1 && p.y > top - 0.3) {
        G.state.set('wave_clock_done');
        G.ui.celebrate('The obstacle was the elevator!', 'The Wave Clock');
        G.ui.say('The big swell set her down on the high deck, dry-pawed. The wave wasn’t in the way. It was the way up.');
        return true;
      }
    });
  }

  // ── The reef: Cannonball Nine ─────────────────────────
  buildReef() {
    const deco = new THREE.Group();
    // Stepping stones from the west deck.
    for (const [x, z] of [[-16.0, 1.2], [-14.6, 0.6]]) {
      const st = P.cyl(0.6, 0.7, 0.4, '#d9c39a', { round: 0.05 }); st.position.set(x, -0.05, z); deco.add(st);
      this.solidCyl(x, z, 0.6, -3, 0.35);
    }
    // Coral bumps.
    const R = rng(77);
    for (let i = 0; i < 9; i++) {
      const a = R.range(0, 6.28), r = R.range(3.4, 4.2);
      const c = P.sphere(R.range(0.25, 0.45), ['#ff8fa8', '#ffb35c', '#b48cff'][i % 3], { seg: 10 });
      c.position.set(REEF.x + Math.cos(a) * r, 0.55, REEF.z + Math.sin(a) * r); deco.add(c);
    }
    this.holes = HOLES.map(([name, color], i) => {
      const a = (i / 9) * Math.PI * 2;
      const pos = V3(REEF.x + Math.cos(a) * 2.7, REEF.y, REEF.z + Math.sin(a) * 2.7);
      const cup = P.decal(0.2, '#0b1418', 0.9); cup.position.set(pos.x, REEF.y + 0.02, pos.z); deco.add(cup);
      const fl = P.flag(color, 1.0); fl.position.copy(pos); fl.position.x += 0.15; deco.add(fl);
      const green = P.decal(0.55, '#5fbf5a', 0.6); green.position.set(pos.x, REEF.y + 0.015, pos.z); deco.add(green);
      return { name, color, pos, i };
    });
    // Cutaway pipes from the holes under the water toward the ship.
    for (let i = 0; i < 3; i++) {
      const h = this.holes[i * 3];
      const pipe = P.rope([V3(h.pos.x, -0.6, h.pos.z), V3(-8, -2.2, -6), V3(-4, -2.4, -12), V3(-2, -1.4, -17)], 0.12, '#9fb6c4', { transparent: true, opacity: 0.55 });
      this.add(pipe);
    }
    this.add(deco);
    for (const h of this.holes) {
      this.interact({
        pos: h.pos, radius: 1.3, icon: '⛳', priority: 1,
        enabled: () => !G.state.flag('broadside_done'),
        label: () => (G.state.has('mini_putter') ? `Putt into the ${h.name} hole` : `A mini-golf hole (${h.name} flag)`),
        use: () => this.putt(h),
      });
    }
  }

  async putt(h) {
    if (!G.state.has('mini_putter')) { G.ui.say('Nine little holes, nine little flags. A putter would help. Maybe somebody left one somewhere high up.'); return; }
    if (G.state.flag(`golf_loaded_${h.i}`)) { G.ui.toast('That one’s already loaded.', '⛳'); return; }
    if (this.putting) return;
    this.putting = true;
    const ball = P.sphere(0.09, '#ffffff'); ball.castShadow = false;
    const from = G.player.pos.clone().lerp(h.pos, 0.3);
    ball.position.set(from.x, REEF.y + 0.09, from.z);
    this.add(ball);
    G.player.emote('attack', 1.6);
    await G.tween(ball.position, { x: h.pos.x, z: h.pos.z }, 0.7, ease.out);
    G.audio.sfx('coin', { vol: 0.8 });
    await G.tween(ball.position, { y: REEF.y - 0.2 }, 0.15);
    ball.removeFromParent();
    const cannon = this.cannons[h.i];
    if (JR.has(h.name)) {
      G.state.set(`golf_loaded_${h.i}`);
      cannon.userData.glow.visible = true;
      G.audio.sfx('wood_creak', { vol: 0.5, rate: 1.4 });
      G.ui.toast(`Clunk… somewhere under the reef, a ${h.name}-pennant cannon is loaded.`, '\u{1F4A3}');
      const loaded = this.holes.filter((x) => G.state.flag(`golf_loaded_${x.i}`)).length;
      if (loaded >= 3) await this.broadside();
    } else {
      // Wrong load: party.
      const at = cannon.getWorldPosition(V3()).add(V3(-0.6, 0.3, 0));
      G.audio.sfx('cannon', { vol: 0.8, pos: at, range: 60 });
      G.fx.confetti(at, 50);
      setTimeout(() => G.audio.sfx('parrot', { vol: 0.8, rate: 1.2 }), 500);
      G.ui.toast(`Pop! The ${h.name}-pennant cannon fires confetti. The parrot laughs so hard it nearly falls off its perch.`, '\u{1F389}');
    }
    this.putting = false;
  }

  async broadside() {
    G.state.set('broadside_done');
    await G.cine.run(async (c) => {
      c.look(SHIP.clone().setY(2), { dist: 16, pitch: 38 });
      await c.wait(1.2);
      for (const h of this.holes) {
        if (!JR.has(h.name)) continue;
        const cn = this.cannons[h.i];
        const at = cn.getWorldPosition(V3()).add(V3(-0.7, 0.3, 0));
        G.audio.sfx('cannon', { vol: 1, pos: at, range: 80 });
        G.fx.burst(at, { color: ['#ffffff', '#d0d0d0', '#ffcf6a'], count: 20, speed: 4, up: 2, size: 0.4, life: 1.2, gravity: -0.5 });
        G.rig.shake = 0.6;
        cn.userData.glow.visible = false;
        await c.wait(0.45);
      }
      G.audio.sfx('smash', { vol: 0.7 });
      G.fx.burst(this.chainTop.clone(), { color: ['#b5582a', '#8a4420', '#d17a3a'], count: 30, speed: 3, up: 2, size: 0.18, gravity: 8 });
      this.chainMat.color.set('#7c858c');
      await c.say('BOOM. The broadside shakes the drydock, and the rust cracks off the anchor chain in flakes.', { dur: 3.5 });
    });
    G.ui.celebrate('Broadside!', 'The Cannonball Nine');
  }

  // ── The Santa Maria ───────────────────────────────────
  buildShip() {
    const ship = new THREE.Group();
    ship.position.copy(SHIP);
    this.add(ship);
    this.ship = ship;
    const hull = model('galleon', { size: 12.5 });
    ship.add(hull);
    // The Jolly Roger at the stern.
    const jrPole = P.cyl(0.07, 0.07, 3, '#4a3a2a'); jrPole.position.set(0, DECK_H + QD, -5.4); ship.add(jrPole);
    const jrTex = P.textCanvas('', { w: 256, h: 160, bg: null, draw: (g) => {
      g.fillStyle = '#141414'; g.fillRect(0, 0, 256, 160);
      g.fillStyle = '#d6322b'; g.fillRect(0, 0, 256, 18); g.fillRect(0, 142, 256, 18);
      g.fillStyle = '#ffffff';
      g.beginPath(); g.arc(128, 70, 30, 0, Math.PI * 2); g.fill();
      g.fillRect(110, 88, 36, 22);
      g.fillStyle = '#141414'; g.beginPath(); g.arc(116, 68, 8, 0, 7); g.arc(140, 68, 8, 0, 7); g.fill();
      g.strokeStyle = '#ffffff'; g.lineWidth = 12; g.lineCap = 'round';
      g.beginPath(); g.moveTo(70, 112); g.lineTo(186, 140); g.moveTo(186, 112); g.lineTo(70, 140); g.stroke();
    } });
    const jr = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 1.0), new THREE.MeshLambertMaterial({ map: jrTex, side: THREE.DoubleSide }));
    jr.position.set(0.82, DECK_H + QD + 2.5, -5.4); jr.rotation.y = Math.PI / 2;
    ship.add(jr);
    this.jolly = jr;
    this.every(() => { jr.rotation.x = Math.sin(G.time * 2.1) * 0.08; });
    this.sense(jr, { warm: () => G.state.has('mini_putter') && !G.state.flag('broadside_done'), height: 0, radius: 16 });
    // Nine cannons with pennants on the port rail.
    this.cannons = HOLES.map(([name, color], i) => {
      const cn = new THREE.Group();
      const barrel = P.cyl(0.16, 0.2, 0.9, '#2b2b30', { base: false }); barrel.rotation.z = Math.PI / 2; cn.add(barrel);
      const pen = P.flag(color, 0.55); pen.position.set(0.2, 0.1, 0); cn.add(pen);
      const glow = P.sphere(0.12, '#ffcf4a', { emissive: '#ffb020', emissiveIntensity: 1.2 }); glow.position.set(0.45, 0, 0); glow.visible = G.state.flag(`golf_loaded_${i}`) && !G.state.flag('broadside_done'); cn.add(glow);
      cn.userData.glow = glow;
      cn.position.set(-2.55, DECK_H - 0.7, -4 + i * 1.0);
      ship.add(cn);
      return cn;
    });
    // Anchor chain at the bow.
    this.chainMat = P.mat(G.state.flag('broadside_done') ? '#7c858c' : '#b5582a').clone();
    const chain = new THREE.Group();
    for (let i = 0; i < 9; i++) {
      const link = new THREE.Mesh(new THREE.TorusGeometry(0.16, 0.05, 6, 12), this.chainMat);
      link.position.set(1.9, DECK_H - 0.4 - i * 0.42, 5.6 + i * 0.12); link.rotation.y = i % 2 ? Math.PI / 2 : 0;
      chain.add(link);
    }
    const anchor = P.box(0.9, 0.9, 0.2, '#555a60'); anchor.position.set(1.9, DECK_H - 4.5, 6.7); chain.add(anchor);
    ship.add(chain);
    this.chain = chain;
    this.chainTop = SHIP.clone().add(V3(1.9, DECK_H - 1, 6));
    if (G.state.flag('anchor_raised')) chain.position.y = 3.6;
    // Capstan with the carving.
    const cap = new THREE.Group();
    const drum = P.cyl(0.42, 0.5, 0.9, '#8a6440'); cap.add(drum);
    for (let i = 0; i < 4; i++) { const bar = P.box(2.0, 0.09, 0.09, '#b08a5a', { base: false }); bar.position.y = 0.75; bar.rotation.y = (i * Math.PI) / 4; cap.add(bar); }
    cap.position.set(0, DECK_H, 2.2);
    ship.add(cap);
    this.capstan = cap;
    const helm = new THREE.Group();
    const wheel = P.torus(0.45, 0.05, '#8a6440'); wheel.position.y = 1.0; helm.add(wheel);
    for (let i = 0; i < 4; i++) { const sp = P.box(1.0, 0.05, 0.05, '#8a6440', { base: false }); sp.position.y = 1.0; sp.rotation.z = (i * Math.PI) / 4; helm.add(sp); }
    const post = P.box(0.18, 1.0, 0.18, '#6a4a30'); helm.add(post);
    helm.position.set(0, DECK_H + QD, -4.2);
    ship.add(helm);
    this.helm = helm;
    // Colliders: hull blocks swimmers; the deck is only reachable from above.
    this.hullSolid = this.solidBox(SHIP.x, SHIP.z, 4.6, 11, -4, SHIP.y + DECK_H);
    this.capSolid = this.solidCyl(SHIP.x, SHIP.z + 2.2, 0.5, SHIP.y + DECK_H, SHIP.y + DECK_H + 1);
    this.qdSolid = this.solidBox(SHIP.x, SHIP.z - 4.4, 4.4, 3.6, SHIP.y + DECK_H - 0.1, SHIP.y + DECK_H + QD);
    this.fcSolid = this.solidBox(SHIP.x, SHIP.z + 5.3, 3.6, 1.8, SHIP.y + DECK_H - 0.1, SHIP.y + DECK_H + 0.4);
    // Keel blocks in the dock.
    for (const z of [-4, 0, 4]) { const kb = P.box(1.6, 0.6, 1.0, '#6a5a4a'); kb.position.set(SHIP.x, -1.2, SHIP.z + z); this.add(kb); }
    if (!G.state.flag('drydock_flooded')) {
      ship.rotation.z = 0.42; ship.position.y = SHIP.y - 0.5;
      this.hullSolid.y1 = 1.2; this.hullSolid.noStand = true; this.qdSolid.enabled = false; this.fcSolid.enabled = false;
    }
    // Interactions on deck.
    const deckY = () => SHIP.y + DECK_H;
    this.interact({
      pos: () => V3(SHIP.x, deckY(), SHIP.z + 2.2), radius: 2.0, icon: '⚓', yRange: 1.5,
      enabled: () => G.state.flag('drydock_flooded') && !G.state.flag('anchor_raised'),
      label: () => (G.state.flag('broadside_done') ? 'Turn the capstan' : 'The anchor chain is rusted solid'),
      use: () => this.capstanDuet(),
    });
    this.interact({
      pos: () => V3(SHIP.x + 0.9, deckY(), SHIP.z + 2.2), radius: 1.4, icon: '\u{1F440}', yRange: 1.5,
      enabled: () => G.state.flag('drydock_flooded') && !G.state.hasArtifact('capstan_tally'),
      label: 'Look at the capstan’s carvings',
      use: () => {
        G.ui.say('Carved into the capstan’s wood, old and shallow: tally marks in sets of four with a diagonal fifth, like something counted the days. Beside them, one pawprint.', { dur: 6 });
        G.state.addArtifact('capstan_tally', 'pirate', 'Tallies on the Capstan', 'Old, shallow tally marks in sets of four with a diagonal fifth, like something counted the days. Beside them, one pawprint.');
      },
    });
    this.sense(cap, { warm: () => G.state.flag('drydock_flooded') && !G.state.hasArtifact('capstan_tally'), height: 1 });
    this.interact({
      pos: () => V3(SHIP.x, deckY() + QD, SHIP.z - 4.2), radius: 1.8, icon: '⛵', yRange: 1.5,
      enabled: () => G.state.flag('anchor_raised') && !this.sailing,
      label: 'Take the wheel: full sail!',
      use: () => {
        if (!G.state.flag('max_swell')) { G.ui.say('Anchor up, sails ready… but no ordinary swell will carry her out. The wave machine has to go to MAX.'); return; }
        this.setSail();
      },
    });
    // Climbing aboard on a monster swell.
    this.every(() => {
      const p = G.player.pos;
      const onDeck = Math.abs(p.x - SHIP.x) < 2.3 && Math.abs(p.z - SHIP.z) < 5.5 && p.y > deckY() - 0.25 && G.state.flag('drydock_flooded');
      if (onDeck && !this.aboard) {
        this.aboard = true;
        if (!G.state.flag('boarded_ship')) { G.state.set('boarded_ship'); G.ui.celebrate('All aboard!', 'The Santa Maria'); }
        else G.ui.toast('Aboard the Santa Maria.', '\u{1F3F4}‍☠️');
      } else if (!onDeck && p.y < deckY() - 1) this.aboard = false;
    });
  }

  buildDock() {
    // Railings keep cats out of the dry dock (it's a long climb back out).
    const rail = new THREE.Group();
    const [x0, x1, z0, z1] = DOCK;
    for (const [x, z, w, d] of [[x0 - 0.3, (z0 + z1) / 2, 0.25, z1 - z0], [x1 + 0.3, (z0 + z1) / 2, 0.25, z1 - z0], [0, z0 - 0.3, x1 - x0 + 0.85, 0.25]]) {
      const r = P.box(w, 1.0, d, '#5c7080'); r.position.set(x, 0.4, z); rail.add(r);
      const top = P.box(w + 0.05, 0.1, d + 0.05, '#ffc93c'); top.position.set(x, 1.4, z); rail.add(top);
      this.solidBox(x, z, w + 0.2, d + 0.2, -3, 2.2);
    }
    this.add(P.bake(rail)); this.add(rail);
    // The sill between pool and dock (opens when flooded).
    const sill = P.box(x1 - x0, 1.9, 0.6, '#5c7080'); sill.position.set(0, -1.5, -13); this.add(sill);
    this.sillMesh = sill;
    this.sill = this.solidBox(0, -13, x1 - x0, 0.6, -3, 0.4);
    if (G.state.flag('drydock_flooded')) { this.sill.enabled = false; sill.position.y = -3.3; }
    const name = P.sign(['SANTA MARIA'], { w: 3.4, h: 0.8, bg: '#173b44', fg: '#ffc93c' });
    name.position.set(0, 1.6, z0 - 0.45); this.add(name);
    // The spigot on the west rail.
    const sp = new THREE.Group();
    const pipe = P.cyl(0.18, 0.18, 1.2, '#6f8a9a'); sp.add(pipe);
    const spout = P.cyl(0.12, 0.12, 1.2, '#6f8a9a', { base: false }); spout.rotation.z = Math.PI / 2; spout.position.set(0.6, 1.0, 0); sp.add(spout);
    const socket = P.cyl(0.08, 0.08, 0.2, '#333', { base: false }); socket.rotation.x = Math.PI / 2; socket.position.set(0, 1.0, -0.2); sp.add(socket);
    sp.position.copy(SPIGOT);
    this.add(sp);
    this.spigot = sp;
    if (G.state.flag('drydock_flooded')) this.addWheel(false);
    this.interact({
      obj: sp, radius: 2.0, icon: '☸️',
      enabled: () => !G.state.flag('drydock_flooded'),
      label: () => (G.state.has('spigot_wheel') ? 'Fit the spigot wheel' : 'A spigot with no wheel'),
      use: () => {
        if (!G.state.has('spigot_wheel')) { G.ui.say('A drydock spigot, wheel missing. Somebody pried it off and hid it… somewhere a fish would know about.'); return; }
        G.state.take('spigot_wheel');
        this.addWheel(true);
        this.flood();
      },
    });
    this.sense(sp, { warm: () => G.state.has('spigot_wheel') && !G.state.flag('drydock_flooded'), height: 1 });
  }
  addWheel(spin) {
    const w = P.torus(0.35, 0.05, '#c9a24a'); w.position.set(0, 1.0, -0.35);
    this.spigot.add(w);
    if (spin) G.animate(2, (t) => { w.rotation.z = t * 12; });
  }

  async flood() {
    G.state.set('drydock_flooded');
    this.flooding = true;
    await G.cine.run(async (c) => {
      c.look(SHIP.clone().setY(1), { dist: 18, pitch: 40 });
      G.audio.sfx('drain', { vol: 0.9, rate: 0.7 });
      G.audio.sfx('big_wave', { vol: 0.5 });
      c.say('The spigot coughs, then roars. Water floods the drydock…');
      await G.animate(3.2, (t) => { this.dockLevel = lerp(-1.2, this.waterLevel, t); });
      G.audio.sfx('wood_creak', { vol: 0.9, rate: 0.7 });
      await G.tween(this.ship.rotation, { z: 0 }, 1.6, ease.out);
      this.ship.position.y = SHIP.y;
      this.hullSolid.y1 = SHIP.y + DECK_H; this.hullSolid.noStand = false;
      this.qdSolid.enabled = true; this.fcSolid.enabled = true;
      this.sill.enabled = false;
      G.tween(this.sillMesh.position, { y: -3.3 }, 1.2);
      await c.say('The Santa Maria rights herself with a groan. But her deck sits far above the water, and the boarding rope dangles out of reach.', { dur: 4 });
    });
    this.flooding = false;
    G.ui.celebrate('The drydock floods!', 'Float the Santa Maria');
  }

  async capstanDuet() {
    if (!G.state.flag('broadside_done')) { G.ui.say('The anchor chain is rusted solid. It would take a cannon blast to crack that rust.'); return; }
    const o = G.oreo;
    const near = o.active && Math.hypot(o.pos.x - G.player.pos.x, o.pos.z - G.player.pos.z) < 6 && Math.abs(o.pos.y - G.player.pos.y) < 1;
    if (!near) { G.ui.say('Too heavy for one small cat. If only she could get Oreo up here, wherever he is.'); return; }
    o.mode = 'busy';
    o.teleport(SHIP.x - 1.0, SHIP.z + 3.0, Math.PI);
    G.player.faceTo(this.capstan.getWorldPosition(V3()));
    let hits = 0, misses = 0;
    const wrap = document.createElement('div');
    wrap.innerHTML = `<p style="text-align:center">Heave on the beat, together! Tap <b>HEAVE</b> when the marker is in the gold.</p>
      <div style="position:relative;width:260px;height:34px;border:3px solid #173b44;border-radius:12px;background:#fffaf0;margin:8px auto;overflow:hidden">
        <div class="zone" style="position:absolute;left:40%;width:20%;top:0;bottom:0;background:#ffc93c"></div>
        <div class="mk" style="position:absolute;top:-2px;bottom:-2px;width:8px;background:#ff6b4a;border-radius:4px"></div>
      </div><p class="st" style="text-align:center;font-weight:800">0 / 4</p>`;
    const panel = G.ui.panel('The capstan duet', wrap, {
      buttons: [{ label: 'HEAVE!', primary: true, onClick: () => {
        const x = this.duetPos;
        if (x > 0.38 && x < 0.62) {
          hits++; o.bark(); G.audio.sfx('wood_creak', { vol: 0.8, rate: 0.8 + hits * 0.1 });
          this.capstan.rotation.y += Math.PI / 4; this.chain.position.y += 0.9;
        } else { misses++; G.audio.sfx('fail', { vol: 0.5 }); G.ui.toast(misses % 2 ? 'Oreo heaves early. They both fall over. Again!' : 'Khione heaves late. Oreo looks at her. Again!', '\u{1F43E}'); }
        wrap.querySelector('.st').textContent = `${hits} / 4`;
        if (hits >= 4) setTimeout(() => G.ui.closeSheet(), 300);
      } }],
    });
    // The panel pauses the world, so the marker runs on real time.
    const t0 = performance.now();
    const mk = wrap.querySelector('.mk');
    const tick = () => {
      if (!G.ui.modalOpen) return;
      const t = (performance.now() - t0) / 1000;
      this.duetPos = 0.5 + 0.5 * Math.sin(t * (2.6 + hits * 0.3));
      mk.style.left = `calc(${this.duetPos * 100}% - 4px)`;
      requestAnimationFrame(tick);
    };
    tick();
    await panel.done;
    o.follow();
    if (hits >= 4) {
      G.state.set('anchor_raised');
      G.tween(this.chain.position, { y: 3.6 }, 0.8);
      G.audio.sfx('gate_open', { vol: 0.7 });
      G.ui.celebrate('Anchor’s up!', 'The capstan duet');
      G.ui.say('Clank by clank, the anchor rises. Now: the wheel, and the biggest wave this mall has ever made.');
    }
  }

  async setSail() {
    this.sailing = true;
    G.state.set('santa_maria_sails');
    const ship = this.ship;
    await G.cine.run(async (c) => {
      // Everyone aboard: parrot takes the wheel-perch.
      const deck = () => V3(ship.position.x, ship.position.y + DECK_H, ship.position.z);
      G.player.teleport(SHIP.x - 0.6, SHIP.z + 0.6, 0, deck().y);
      if (G.oreo.active) G.oreo.teleport(SHIP.x + 0.8, SHIP.z + 1.2, 0);
      this.parrot.removeFromParent();
      ship.add(this.parrot); this.parrot.position.set(0, DECK_H + QD + 1.55, -4.2); this.parrot.rotation.set(0, 0, 0);
      const ride = this.every(() => {
        const d = deck();
        G.player.pos.set(d.x - 0.6, d.y, d.z + 0.6); G.player.velocity.set(0, 0, 0);
        if (G.oreo.active) { G.oreo.pos.set(d.x + 0.8, d.y, d.z + 1.2); G.oreo.mode = 'busy'; }
      });
      this.hullSolid.enabled = false; this.capSolid.enabled = false; this.qdSolid.enabled = false; this.fcSolid.enabled = false;
      c.look(deck().add(V3(0, 1, 0)), { dist: 14, pitch: 32, yaw: 150, speed: 1.5 });
      G.audio.sfx('parrot', { vol: 1 });
      await c.say('The parrot hops onto the wheel. Wave machine to MAX!', { dur: 2.6 });
      this.waveHold = 0;
      await G.animate(1.6, (t) => { this.waveHold = MAX * ease.inOut(t); });
      G.audio.sfx('big_wave', { vol: 1 });
      G.audio.duck(0.4, 6);
      const follow = this.every(() => c.look(deck().add(V3(0, 1, 0)), { dist: 16, pitch: 30, yaw: 150, speed: 2.5 }));
      await G.tween(ship.position, { y: MAX - 2.2 }, 1.0, ease.out);
      await G.tween(ship.position, { z: 22 }, 4.2, ease.in);
      // Through the glass wave doors.
      G.audio.sfx('smash', { vol: 1 }); G.audio.sfx('gate_open', { vol: 0.8 });
      this.doorSolid.enabled = false;
      G.tween(this.doors[0].position, { x: -9 }, 0.8, ease.out);
      G.tween(this.doors[1].position, { x: 9 }, 0.8, ease.out);
      G.fx.burst(V3(0, 2, 31.6), { color: ['#bfeaff', '#ffffff'], count: 40, speed: 6, up: 4, size: 0.25, life: 1.4 });
      c.say('The Santa Maria surfs the swell straight through the glass wave doors…', { dur: 3 });
      G.tween(ship.position, { y: -2.6 }, 2.4, ease.in);
      await G.tween(ship.position, { z: 62 }, 4.0, ease.inOut);
      G.fx.splash(V3(0, 0, 40));
      G.audio.sfx('splash', { vol: 1, rate: 0.7 });
      await c.say('…and out onto the real, wide ocean.', { dur: 3 });
      this.updaters.splice(this.updaters.indexOf(ride), 1);
      this.updaters.splice(this.updaters.indexOf(follow), 1);
    });
    await G.game.finishIsland();
  }

  // ── The aquarium tunnel (Aquarium Key) ─────────────────
  buildAquarium() {
    const { x0, x1, z0, z1 } = TANK;
    const cz = (z0 + z1) / 2, len = z1 - z0;
    const waterMat = new THREE.MeshLambertMaterial({ color: '#3ab8d8', transparent: true, opacity: 0.45, depthWrite: false });
    for (const [a, b] of [[x0, 23], [25, x1]]) {
      const tank = new THREE.Mesh(new THREE.BoxGeometry(b - a, 2.8, len), waterMat);
      tank.position.set((a + b) / 2, 0.4 + 1.4, cz); tank.renderOrder = 2;
      this.add(tank);
      this.solidBox((a + b) / 2, cz, b - a, len, -1, 4);
      const sand = P.box(b - a - 0.1, 0.12, len - 0.1, '#e8d6a8'); sand.position.set((a + b) / 2, 0.4, cz); this.add(sand);
      const frame = P.box(b - a + 0.1, 0.15, len + 0.1, '#5c7080'); frame.position.set((a + b) / 2, 3.2, cz); this.add(frame);
    }
    // Acrylic tunnel arch over the walkway.
    const arch = new THREE.Mesh(new THREE.CylinderGeometry(1.15, 1.15, len, 20, 1, true, -Math.PI / 2, Math.PI), new THREE.MeshLambertMaterial({ color: '#d8f6ff', transparent: true, opacity: 0.22, side: THREE.DoubleSide, depthWrite: false }));
    arch.rotation.x = Math.PI / 2; arch.rotation.y = Math.PI / 2;
    arch.position.set(24, 0.45, cz);
    arch.renderOrder = 3;
    this.add(arch);
    const sign = P.sign(['AQUARIUM', 'tunnel →'], { w: 2.4, h: 0.9, bg: '#1fb5c9', fg: '#fff', post: 1.2 });
    sign.position.set(26.5, 0.4, z1 + 1.2); sign.rotation.y = 0; this.add(sign);
    // Grates low in the tunnel's west wall.
    this.grates = GRATES.map((z, i) => {
      const g = new THREE.Group();
      const back = P.box(0.06, 0.6, 0.9, '#2a3238'); g.add(back);
      for (let k = 0; k < 4; k++) { const bar = P.box(0.05, 0.6, 0.05, '#9aa6ae'); bar.position.set(0.05, 0, -0.36 + k * 0.24); g.add(bar); }
      g.position.set(23.02, 0.45, z);
      this.add(g);
      const it = this.interact({
        pos: V3(23.6, 0.4, z), radius: 1.0, icon: '\u{1F527}',
        enabled: () => !G.state.flag('aquarium_done'),
        label: 'Pry at the grate',
        use: () => this.openGrate(i),
      });
      return { g, z, it };
    });
    if (G.state.flag('aquarium_done') && !G.state.flag('took_spigot_wheel') && !G.state.flag('drydock_flooded')) this.dropWheel();
    // Fish.
    this.fish = [];
    const R = rng(12);
    const cols = ['#ff9a3c', '#ffd84a', '#ff6b8a', '#7bd88f', '#b58cff'];
    for (let i = 0; i < 16; i++) {
      const f = this.makeFish(cols[i % cols.length], 0.25 + R() * 0.15);
      const left = i % 2 === 0;
      const st = { mesh: f, x: left ? R.range(19.6, 22.4) : R.range(25.6, 28.4), y: R.range(1.0, 2.8), z: R.range(z0 + 1, z1 - 1), sp: R.range(0.6, 1.4), ph: R.range(0, 6), dir: R() < 0.5 ? 1 : -1, z0: z0 + 0.8, z1: z1 - 0.8 };
      this.fish.push(st);
      this.add(f);
    }
    // The silvery-blue one: the colour of the stranded fish from Ahalo.
    this.keyFish = this.makeFish('#a9c8e6', 0.42, true);
    this.add(this.keyFish);
    this.keyT = 0;
    this.sense(this.keyFish, { warm: () => !G.state.flag('aquarium_done'), height: 0, radius: 12 });
  }

  makeFish(color, s, shiny = false) {
    const f = new THREE.Group();
    const body = P.sphere(s, color, shiny ? { emissive: '#9fc2e8', emissiveIntensity: 0.35 } : {}); body.scale.set(0.45, 0.6, 1); body.castShadow = false; f.add(body);
    const tail = P.cone(s * 0.45, s * 0.6, color, { base: false, seg: 6 }); tail.rotation.x = -Math.PI / 2; tail.position.z = -s * 1.05; tail.castShadow = false; f.add(tail);
    return f;
  }

  updateFish(dt) {
    for (const f of this.fish) {
      f.z += f.dir * f.sp * dt;
      if (f.z > f.z1 || f.z < f.z0) f.dir *= -1;
      f.mesh.position.set(f.x + Math.sin(G.time * 0.7 + f.ph) * 0.4, f.y + Math.sin(G.time * 1.3 + f.ph) * 0.2, f.z);
      f.mesh.rotation.y = f.dir > 0 ? 0 : Math.PI;
    }
    // Key fish patrol: down the west tank and back; at the true grate it
    // pauses three times, wiggling, every lap.
    const gz = GRATES[TRUE_GRATE];
    const route = [
      { z: TANK.z0 + 1, t: 5 }, { z: gz, t: 3.5 }, { pause: 1.3 }, { z: gz + 0.6, t: 0.6 }, { pause: 1.3 }, { z: gz, t: 0.6 }, { pause: 1.3 },
      { z: TANK.z1 - 1, t: 2 }, { z: gz, t: 2 }, { pause: 1.3 }, { z: gz - 0.6, t: 0.6 }, { pause: 1.3 }, { z: gz, t: 0.6 }, { pause: 1.3 },
    ];
    const total = route.reduce((a, s) => a + (s.t ?? s.pause), 0);
    this.keyT = (this.keyT + dt) % total;
    let t = this.keyT, z = TANK.z0 + 1, prevZ = gz, pausing = false;
    for (const s of route) {
      const d = s.t ?? s.pause;
      if (t <= d) {
        if (s.pause) { z = prevZ; pausing = true; }
        else { const k = ease.inOut(t / d); z = lerp(prevZ, s.z, k); }
        break;
      }
      t -= d;
      if (!s.pause) prevZ = s.z;
    }
    const f = this.keyFish;
    const dz = z - f.position.z;
    f.position.set(pausing ? 22.55 : 21.6, pausing ? 0.75 : 1.6, z);
    if (Math.abs(dz) > 0.001) f.rotation.y = dz > 0 ? 0 : Math.PI;
    if (pausing) f.rotation.z = Math.sin(G.time * 14) * 0.25; else f.rotation.z = 0;
  }

  openGrate(i) {
    const g = this.grates[i];
    if (i !== TRUE_GRATE) {
      const lines = ['Pipes. An old flip-flop. No.', 'A very surprised hermit crab.', 'Just bubbles.', 'A lost goggle strap.'];
      G.audio.sfx('stone_slide', { vol: 0.4, rate: 1.4 });
      G.ui.toast(lines[i % lines.length], '\u{1FAE7}');
      return;
    }
    G.state.set('aquarium_done');
    G.audio.sfx('gate_open', { vol: 0.6, rate: 1.4 });
    G.tween(g.g.rotation, { y: -1.4 }, 0.5);
    G.ui.celebrate('Behind the grate…', 'The Aquarium Key');
    G.ui.say('Where the silvery fish kept stopping, the grate swings loose. Behind it, wedged among the pipes: a brass wheel.');
    this.dropWheel();
  }
  dropWheel() {
    const w = P.torus(0.28, 0.05, '#c9a24a'); w.rotation.x = Math.PI / 2; w.position.y = 0.1;
    this.pickup({ id: 'spigot_wheel', pos: V3(23.7, 0.4, GRATES[TRUE_GRATE]), obj: w, bob: false, radius: 1.2 });
  }

  // ── The parrot: growl lesson + the Parrot's Game ──────
  buildParrot() {
    const chair = new THREE.Group();
    for (const [x, z] of [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]) { const leg = P.box(0.12, 2.4, 0.12, '#ffffff'); leg.position.set(x, 0, z); chair.add(leg); }
    const seat = P.box(1.3, 0.15, 1.3, '#ff6b4a'); seat.position.y = 2.4; chair.add(seat);
    chair.position.copy(PERCH);
    this.add(chair);
    this.solidBox(PERCH.x, PERCH.z, 1.3, 1.3, -1, PERCH.y + 2.55);
    const parrot = model('parrot', { height: 0.8 });
    parrot.position.set(PERCH.x, PERCH.y + 2.55, PERCH.z);
    parrot.rotation.y = Math.atan2(SPAWN.x - PERCH.x, SPAWN.z - PERCH.z);
    this.add(parrot);
    this.parrot = parrot;
    this.every(() => { if (parrot.parent !== this.root) return; parrot.position.y = PERCH.y + 2.55 + Math.abs(Math.sin(G.time * 2)) * 0.03; });
    this.sense(parrot, { warm: () => !G.state.knows('growl') || !G.state.flag('parrot_game_done'), height: 0.7 });
    // Speech-bubble sprite over the parrot for its songs.
    const c = document.createElement('canvas'); c.width = c.height = 128;
    const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
    this.bubble = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true }));
    this.bubble.scale.set(1.1, 1.1, 1); this.bubble.renderOrder = 10; this.bubble.visible = false;
    this.bubble.position.set(PERCH.x, PERCH.y + 4.2, PERCH.z);
    this.bubble.userData.canvas = c;
    this.add(this.bubble);
    this.interact({
      pos: PERCH, radius: 3.2, icon: '\u{1F99C}',
      enabled: () => !this.gamePlaying,
      label: () => (!G.state.knows('growl') ? 'A parrot, copying everything' : G.state.flag('parrot_game_done') ? 'The parrot bobs happily' : 'Play the parrot’s game'),
      use: () => {
        if (!G.state.knows('growl')) { G.ui.say('The parrot cocks its head. It seems to be waiting for her to make a sound.'); return; }
        if (G.state.flag('parrot_game_done')) { G.audio.sfx('parrot', { vol: 0.7 }); G.ui.toast('Squawk! (It means: good game.)', '\u{1F99C}'); return; }
        this.parrotGame();
      },
    });
    this.onVocal((e) => {
      if (Math.hypot(e.pos.x - PERCH.x, e.pos.z - PERCH.z) > 11) return;
      if (this.gamePlaying) { this.gameInput(e.kind); return; }
      if (G.state.knows('growl') || this.lesson) return;
      // Mock her, sound for sound.
      setTimeout(() => {
        this.squawk(e.kind);
        this.mocks++;
        if (this.mocks === 1) G.ui.toast(`The parrot ${e.kind}s right back at her. Perfectly.`, '\u{1F99C}');
        if (this.mocks >= 2) this.growlLesson();
      }, 450);
    });
  }

  squawk(kind, rate = 1.3) {
    G.audio.sfx(kind, { vol: 0.8, rate });
    G.audio.sfx('parrot', { vol: 0.35, rate: 1.4 });
    this.showBubble(VOX_ICON[kind]);
    G.animate(0.3, (t) => { this.parrot.scale.setScalar(1 + Math.sin(t * Math.PI) * 0.15); });
  }
  showBubble(icon, dur = 600) {
    const b = this.bubble, g = b.userData.canvas.getContext('2d');
    g.clearRect(0, 0, 128, 128);
    g.fillStyle = 'rgba(255,244,220,0.96)'; g.strokeStyle = '#173b44'; g.lineWidth = 7;
    g.beginPath(); g.arc(64, 60, 50, 0, Math.PI * 2); g.fill(); g.stroke();
    g.font = '60px "Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
    g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(icon, 64, 64);
    b.material.map.needsUpdate = true;
    b.visible = true;
    clearTimeout(this._bubT);
    this._bubT = setTimeout(() => { b.visible = false; }, dur);
  }

  async growlLesson() {
    this.lesson = true;
    await G.cine.run(async (c) => {
      c.look(PERCH.clone().setY(2.5).lerp(G.player.pos, 0.5), { dist: 9, pitch: 35 });
      await c.say('Meow for meow, hiss for hiss. The parrot mimics her perfectly. It is insufferable.', { dur: 3.2 });
      if (G.oreo.active) {
        G.oreo.faceTo(PERCH);
        G.oreo.bark();
        await c.wait(0.3);
        G.oreo.bark();
        await c.say('Oreo, fed up, barks. The parrot flinches.', { dur: 2.4 });
      }
      G.tween(this.parrot.position, { y: this.parrot.position.y + 0.3 }, 0.15).then(() => G.tween(this.parrot.position, { y: PERCH.y + 2.55 }, 0.3));
      await c.say('Khione tries to bark too…', { dur: 2 });
      G.audio.sfx('growl', { vol: 1 });
      G.fx.ripple(G.player.pos.clone(), '#9a7bff', 5);
      G.rig.shake = 0.7;
      G.player.emote('attack', 1.0);
      await c.wait(0.8);
      await c.say('What comes out is her first growl. The parrot respects it.', { dur: 3 });
    });
    G.state.learn('growl');
    G.ui.celebrate('Learned: Growl!', 'Growl is command. Big things listen.');
    G.ui.toast('Tap \u{1F42F} Growl. Big things listen.', '\u{1F42F}');
  }

  async parrotGame() {
    this.gamePlaying = true;
    this.round = this.round ?? 0;
    G.player.faceTo(PERCH);
    G.ui.say('The parrot puffs up. It sings; she sings it back. Five rounds.', { dur: 2.5 });
    await G.wait(2.6);
    while (this.round < 5 && G.island === this) {
      const seq = PARROT_SONG.slice(0, this.round + 3);
      const gap = 0.95 - this.round * 0.1;
      G.ui.say(`Round ${this.round + 1} of 5: listen…`, { dur: seq.length * gap + 0.6 });
      await G.wait(0.8);
      for (const k of seq) { this.squawk(k, 1.35); await G.wait(gap); }
      this.expect = seq; this.got = 0; this.result = null;
      G.ui.say(`Your turn!  ${seq.map(() => '❔').join(' ')}`, { dur: 20 });
      const t0 = G.time;
      while (!this.result && G.time - t0 < 16) await G.wait(0.1);
      if (this.result === 'ok') {
        this.round++;
        G.audio.sfx('chime', { vol: 0.8, rate: 1 + this.round * 0.08 });
        G.fx.sparkle(PERCH.clone().setY(3.4), '#ffe48a', 10);
        if (this.round < 5) { G.ui.say('The parrot bobs its head. Faster now…', { dur: 1.6 }); await G.wait(1.6); }
      } else {
        G.audio.sfx('parrot', { vol: 1, rate: 1.1 });
        setTimeout(() => G.audio.sfx('parrot', { vol: 0.8, rate: 1.3 }), 250);
        G.fx.confetti(PERCH.clone().setY(3.2), 25);
        G.ui.say(this.result === 'bad' ? 'The parrot cackles. Wrong note! Again…' : 'The parrot taps its foot. Again…', { dur: 2 });
        await G.wait(2.2);
      }
      this.expect = null;
    }
    this.gamePlaying = false;
    if (this.round >= 5) {
      G.state.set('parrot_game_done');
      G.audio.sfx('fanfare', { vol: 0.8 });
      G.ui.celebrate('Five rounds!', 'The Parrot’s Game');
      G.state.give('captains_whistle');
      G.ui.say('Its treasure: the captain’s whistle. One blow, and Oreo is at her side wherever he is.', { dur: 4 });
      this.refreshWhistle();
    }
  }

  gameInput(kind) {
    if (!this.expect || this.result) return;
    if (kind === this.expect[this.got]) {
      this.got++;
      G.ui.say(`Your turn!  ${this.expect.map((k, i) => (i < this.got ? VOX_ICON[k] : '❔')).join(' ')}`, { dur: 20 });
      if (this.got >= this.expect.length) this.result = 'ok';
    } else this.result = 'bad';
  }

  // ── The captain's whistle: summon Oreo ────────────────
  buildWhistleButton() {
    const b = document.createElement('button');
    b.className = 'cbtn vox';
    b.innerHTML = '\u{1F4EF}<span>Whistle</span>';
    b.setAttribute('aria-label', 'Captain’s whistle');
    b.style.cssText = 'position:absolute;right:calc(env(safe-area-inset-right,0px) + 14px);bottom:calc(env(safe-area-inset-bottom,0px) + 224px);display:none;';
    b.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); G.audio.unlock(); this.whistle(); });
    G.ui.controls.append(b);
    this.whistleBtn = b;
    this.refreshWhistle();
    this.on('inventory', () => this.refreshWhistle());
  }
  refreshWhistle() { if (this.whistleBtn) this.whistleBtn.style.display = G.state.has('captains_whistle') ? 'flex' : 'none'; }
  whistle() {
    if (G.cine.active) return;
    G.audio.sfx('bell_ding', { vol: 0.6, rate: 2.2 });
    const o = G.oreo;
    if (!o.active) { G.ui.toast('Fweee! Nobody comes.', '\u{1F4EF}'); return; }
    const p = G.player.pos;
    const ang = G.player.yaw + Math.PI + 0.7;
    const x = p.x + Math.sin(ang) * 1.3, z = p.z + Math.cos(ang) * 1.3;
    G.fx.burst(o.pos.clone().add(V3(0, 0.5, 0)), { color: '#ffffff', count: 10, speed: 2, up: 2, size: 0.25 });
    o.pos.set(x, Math.max(p.y, this.groundAt(x, z, p.y + 0.5)), z);
    o.follow();
    G.fx.burst(o.pos.clone().add(V3(0, 0.5, 0)), { color: '#ffffff', count: 12, speed: 2, up: 2, size: 0.25 });
    setTimeout(() => o.bark(), 150);
    G.ui.toast('Fweee! Oreo is right there.', '\u{1F415}');
  }

  // ── Frame ──────────────────────────────────────────────
  update(dt) {
    this.updateWaves(dt);
    this.updateFish(dt);
  }

  dispose() {
    this.whistleBtn?.remove();
    super.dispose();
  }

  async onEnter(first) {
    if (!G.state.flag('pirate_arrived')) {
      G.state.set('pirate_arrived');
      await G.cine.run(async (c) => {
        c.look(V3(0, 0, -4), { dist: 40, pitch: 46, yaw: 30, speed: 0.8 });
        await c.say('An indoor sea. A wave machine. A galleon called the Santa Maria, keeled over in a dry dock.', { dur: 4.2 });
        c.look(PERCH.clone().setY(3), { dist: 8, pitch: 30, speed: 1.2 });
        G.audio.sfx('parrot', { vol: 0.9 });
        await c.say('And one loud parrot.', { dur: 2.4 });
      });
    }
    if (!G.state.knows('growl')) G.ui.toast('Something up there copies every sound. Try a meow.', '\u{1F99C}');
  }

  objective() {
    const s = G.state;
    if (s.flag('santa_maria_sails')) return null;
    if (!s.knows('growl')) return 'Make a sound for the parrot';
    if (!s.flag('wave_clock_done')) return 'Ride the big swell up to the high deck';
    if (!s.flag('broadside_done')) return 'Load the cannons that match the Jolly Roger';
    if (!s.flag('parrot_game_done')) return 'Play the parrot’s game';
    if (!s.flag('drydock_flooded')) return s.has('spigot_wheel') ? 'Fit the wheel on the drydock spigot' : 'Follow the silvery fish in the aquarium';
    if (!s.flag('max_swell')) return 'Unstick the MAX SWELL lever';
    if (!s.flag('boarded_ship')) return 'Ride a MAX swell onto the Santa Maria';
    if (!s.flag('anchor_raised')) return 'Turn the capstan, together';
    return 'Take the wheel. Full sail!';
  }
  hint() {
    const s = G.state;
    if (!s.knows('growl')) return 'The parrot by the pool copies every sound Khione makes. Meow at it, and see who answers.';
    if (!s.flag('wave_clock_done')) return 'Three small swells, then one big one, over and over. The stepping stones only clear between them… but whoever is swimming when the big one comes rides it high. Watch the red siren.';
    if (!s.flag('broadside_done')) return 'Nine holes on the reef feed nine cannons on the ship (look for the pipes under the water). Flags match pennants. Load only the colours the Jolly Roger flies.';
    if (!s.flag('parrot_game_done')) return 'The parrot wants to play: it sings, she sings it back with her own voice. Meow, hiss, growl. Five rounds.';
    if (!s.flag('drydock_flooded')) return s.has('spigot_wheel') ? 'The spigot on the drydock’s west rail is missing its wheel.' : 'In the aquarium tunnel, one fish is the exact silvery blue of the stranded fish from Ahalo. Follow it. Where does it keep stopping?';
    if (!s.flag('max_swell')) return 'The MAX SWELL lever by the wave machine is stuck under a pelican. Meows don’t move big things. Something bigger might.';
    if (!s.flag('boarded_ship')) return 'The Santa Maria’s deck is far above the water. Swim beside her in the drydock when a MAX swell rises.';
    if (!s.flag('anchor_raised')) return 'The capstan takes two. The captain’s whistle brings Oreo anywhere, even onto a ship.';
    return 'Anchor up, swell at MAX. Take the wheel at the stern.';
  }
  objectiveTarget() {
    const s = G.state;
    if (!s.knows('growl')) return PERCH.clone().setY(3);
    if (!s.flag('wave_clock_done')) return V3((PLAT.x0 + PLAT.x1) / 2, PLAT.top, 0);
    if (!s.flag('broadside_done')) return s.has('mini_putter') ? REEF : V3(11, 1.5, 0);
    if (!s.flag('parrot_game_done')) return PERCH.clone().setY(3);
    if (!s.flag('drydock_flooded')) return s.has('spigot_wheel') ? SPIGOT : V3(24, 0.5, GRATES[TRUE_GRATE]);
    if (!s.flag('max_swell')) return BOOTH;
    return SHIP.clone().setY(SHIP.y + DECK_H);
  }
  riddles() {
    const s = G.state;
    return [
      { id: 'growl', name: 'Learning the Growl', done: s.knows('growl'), hint: 'A parrot copies every sound she makes.' },
      { id: 'wave', name: 'The Wave Clock', done: s.flag('wave_clock_done'), hint: 'Three small swells, one big one. The obstacle might be the elevator.' },
      { id: 'cannon', name: 'The Cannonball Nine', done: s.flag('broadside_done'), hint: 'Nine holes feed nine cannons. Load only the Jolly Roger’s colours.' },
      { id: 'parrot', name: 'The Parrot’s Game', done: s.flag('parrot_game_done'), hint: 'It sings, she sings it back. Five rounds.' },
      { id: 'aquarium', name: 'The Aquarium Key', done: s.flag('aquarium_done'), hint: 'One fish is a colour she already knows. Follow it.' },
      { id: 'float', name: 'Float the Santa Maria', done: s.flag('island5_complete'), hint: 'Flood the dock, ride a MAX swell aboard, raise the anchor together, and sail.' },
    ];
  }
}
