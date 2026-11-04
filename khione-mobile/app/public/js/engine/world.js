// Island base class. An island subclass describes its ground (height + splat
// functions), builds props/puzzles in build(), and reports its current goal in
// objective(). Everything it registers here is cleaned up on dispose().
import * as THREE from 'three';
import { G, events, clamp } from './core.js';
import { makeWater, makeTerrainMaterial } from './render.js';
import { texture } from './assets.js';
import { islandById, itemIcon, itemName as itemNameOf } from './state.js';
import { drawIcon } from './icons.js';

const itemTexCache = new Map();
/** Round parchment badge with the item's icon — the default look for loose items. */
function itemTexture(id) {
  if (itemTexCache.has(id)) return itemTexCache.get(id);
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = 'rgba(255,244,220,0.96)'; g.strokeStyle = '#173b44'; g.lineWidth = 7;
  g.beginPath(); g.arc(64, 64, 54, 0, Math.PI * 2); g.fill(); g.stroke();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const face = g.getImageData(0, 0, 128, 128);
  const paint = () => { g.putImageData(face, 0, 0); drawIcon(g, itemIcon(id), 64, 64, 80); t.needsUpdate = true; };
  if (!drawIcon(g, itemIcon(id), 64, 64, 80, paint)) t.needsUpdate = true;
  itemTexCache.set(id, t);
  return t;
}

const STEP = 0.5;   // how high Khione can step without jumping
const _v = new THREE.Vector3();
const _ray = new THREE.Raycaster();
const _ndc = new THREE.Vector2();

export class Island {
  /** Subclasses set: static id = 'ahalo' */
  constructor() {
    this.meta = islandById(this.constructor.id);
    this.root = new THREE.Group();
    this.root.name = this.constructor.id;
    this.solids = [];
    this.surfaces = [];
    this.interactables = [];
    this.triggers = [];
    this.updaters = [];
    this.unsubs = [];
    this.senses = [];
    this.pickables = [];
    this.groundMeshes = [];
    this.waterLevel = 0;
    this.hasWater = true;
    this.bounds = { x: 0, z: 0, r: 70 };
    this.focus = null;
  }

  // ── To override ────────────────────────────────────────
  /** Model names to preload before build(). */
  models() { return []; }
  /** SFX names to warm up. */
  sounds() { return []; }
  /** Render atmosphere (see render.setAtmosphere). */
  atmosphere() { return {}; }
  music() { return this.constructor.id; }
  height(x, z) { return 0.4; }
  /** [w0,w1,w2] texture weights at x,z (textures from terrainTextures()). */
  splat(x, z) { return [1, 0, 0]; }
  /** Vertex tint at x,z (THREE.Color or hex). */
  tint(x, z) { return 0xffffff; }
  terrainTextures() { return ['sand.jpg', 'grass.jpg', 'cobble.jpg']; }
  build() {}
  spawn() { return { x: 0, z: 0, rotY: 0 }; }
  objective() { return null; }
  /** [{id, name, done}] — shown in the journal. */
  riddles() { return []; }
  /** Optional world-space point the goal refers to (for the idle hint arrow). */
  objectiveTarget() { return null; }
  update(dt) {}
  /** Arrival beat (cutscene etc.). Runs after the island card. */
  async onEnter(firstVisit) {}

  // ── Ground ─────────────────────────────────────────────
  makeTerrain({ size = 140, res = 140, cx = 0, cz = 0, repeat = 0.22 } = {}) {
    const geo = new THREE.PlaneGeometry(size, size, res, res);
    geo.rotateX(-Math.PI / 2);
    geo.translate(cx, 0, cz);
    const pos = geo.attributes.position;
    const colors = new Float32Array(pos.count * 3);
    const splat = new Float32Array(pos.count * 3);
    const c = new THREE.Color();
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), z = pos.getZ(i);
      pos.setY(i, this.height(x, z));
      c.set(this.tint(x, z));
      colors[i * 3] = c.r; colors[i * 3 + 1] = c.g; colors[i * 3 + 2] = c.b;
      const w = this.splat(x, z);
      splat[i * 3] = w[0]; splat[i * 3 + 1] = w[1] ?? 0; splat[i * 3 + 2] = w[2] ?? 0;
    }
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geo.setAttribute('splat', new THREE.BufferAttribute(splat, 3));
    geo.computeVertexNormals();
    const [a, b, cc] = this.terrainTextures();
    const mat = makeTerrainMaterial({ texA: texture(a), texB: texture(b), texC: texture(cc), repeat });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.receiveShadow = true;
    mesh.name = 'terrain';
    this.root.add(mesh);
    this.groundMeshes.push(mesh);
    this.terrain = mesh;
    return mesh;
  }

  makeWater(opts = {}) {
    this.waterLevel = opts.level ?? this.waterLevel;
    const w = makeWater({ level: this.waterLevel, heightFn: (x, z) => this.height(x, z), ...opts });
    this.root.add(w);
    this.water = w;
    return w;
  }

  /** Terrain + solids + surfaces height under (x,z), for something whose feet are at `fromY`. */
  groundAt(x, z, fromY = Infinity) {
    let h = this.height(x, z);
    for (const s of this.surfaces) {
      if (s.enabled === false) continue;
      const sh = s.at(x, z);
      if (sh != null && sh <= fromY + STEP && sh > h) h = sh;
    }
    for (const s of this.solids) {
      if (s.enabled === false || s.noStand) continue;
      if (s.y1 > fromY + STEP || s.y1 <= h) continue;
      if (this._inside(s, x, z, 0.05)) h = s.y1;
    }
    return h;
  }

  /** Pushes a circle (x,z,r) out of solid volumes overlapping [feetY, feetY+height]. */
  collide(p, r, feetY, height = 0.9) {
    for (const s of this.solids) {
      if (s.enabled === false) continue;
      if (s.y1 <= feetY + STEP || s.y0 >= feetY + height) continue;
      if (s.type === 'cyl') {
        const dx = p.x - s.x, dz = p.z - s.z;
        const d = Math.hypot(dx, dz), min = s.r + r;
        if (d < min && d > 1e-5) { p.x = s.x + (dx / d) * min; p.z = s.z + (dz / d) * min; }
        else if (d <= 1e-5) { p.x += min; }
      } else {
        // Box: work in its local frame.
        const cos = Math.cos(-s.rot), sin = Math.sin(-s.rot);
        const lx = (p.x - s.x) * cos - (p.z - s.z) * sin;
        const lz = (p.x - s.x) * sin + (p.z - s.z) * cos;
        const cx = clamp(lx, -s.hx, s.hx), cz = clamp(lz, -s.hz, s.hz);
        let dx = lx - cx, dz = lz - cz;
        const d = Math.hypot(dx, dz);
        let nx = lx, nz = lz;
        if (d > 1e-5) {
          if (d < r) { nx = cx + (dx / d) * r; nz = cz + (dz / d) * r; } else continue;
        } else {
          // Centre inside the box: shove out along the shallowest side.
          const px = s.hx - Math.abs(lx), pz = s.hz - Math.abs(lz);
          if (px < pz) nx = Math.sign(lx || 1) * (s.hx + r); else nz = Math.sign(lz || 1) * (s.hz + r);
        }
        const c2 = Math.cos(s.rot), s2 = Math.sin(s.rot);
        p.x = s.x + nx * c2 - nz * s2;
        p.z = s.z + nx * s2 + nz * c2;
      }
    }
    // Soft island boundary.
    const b = this.bounds;
    const dx = p.x - b.x, dz = p.z - b.z, d = Math.hypot(dx, dz);
    if (d > b.r) { p.x = b.x + (dx / d) * b.r; p.z = b.z + (dz / d) * b.r; }
  }

  _inside(s, x, z, pad = 0) {
    if (s.type === 'cyl') return Math.hypot(x - s.x, z - s.z) <= s.r + pad;
    const cos = Math.cos(-s.rot), sin = Math.sin(-s.rot);
    const lx = (x - s.x) * cos - (z - s.z) * sin;
    const lz = (x - s.x) * sin + (z - s.z) * cos;
    return Math.abs(lx) <= s.hx + pad && Math.abs(lz) <= s.hz + pad;
  }

  /** Is (x,z) open water deep enough to swim? */
  isWater(x, z) { return this.hasWater && this.height(x, z) < this.waterLevel - 0.45 && !this._onSolidTop(x, z); }
  _onSolidTop(x, z) {
    for (const s of this.surfaces) if (s.enabled !== false && s.at(x, z) != null && s.at(x, z) > this.waterLevel - 0.3) return true;
    for (const s of this.solids) if (s.enabled !== false && !s.noStand && s.y1 > this.waterLevel - 0.2 && this._inside(s, x, z)) return true;
    return false;
  }

  // ── Colliders ──────────────────────────────────────────
  /**
   * Box collider centred at x,z with footprint w×d, spanning y0..y1.
   * NOTE: `rot` turns the opposite way to Three's rotation.y — for a mesh
   * rotated by θ, pass rot = -θ.
   */
  solidBox(x, z, w, d, y0, y1, rot = 0, extra = {}) {
    const s = { type: 'box', x, z, hx: w / 2, hz: d / 2, y0, y1, rot, ...extra };
    this.solids.push(s);
    return s;
  }
  solidCyl(x, z, r, y0, y1, extra = {}) {
    const s = { type: 'cyl', x, z, r, y0, y1, ...extra };
    this.solids.push(s);
    return s;
  }
  /** Collider matching a mesh's world bounding box (axis-aligned). */
  solidFrom(obj, { pad = 0, top, rot } = {}) {
    obj.updateMatrixWorld(true);
    const b = new THREE.Box3().setFromObject(obj);
    const c = b.getCenter(new THREE.Vector3()), s = b.getSize(new THREE.Vector3());
    return this.solidBox(c.x, c.z, s.x + pad, s.z + pad, b.min.y, top ?? b.max.y, rot ?? 0);
  }
  /** Walkable surface: at(x,z) → height or null (ramps, bridges, escalators). */
  surface(at, extra = {}) { const s = { at, ...extra }; this.surfaces.push(s); return s; }
  removeSolid(s) { const i = this.solids.indexOf(s); if (i >= 0) this.solids.splice(i, 1); }

  // ── Interaction ───────────────────────────────────────
  /**
   * interact({ pos | obj, radius, label, icon, use, enabled, priority })
   *  - label: string | () => string|null (null hides it)
   *  - obj: Object3D for tap-picking (taps on it walk Khione over and use it)
   */
  interact(def) {
    const it = { radius: 1.8, priority: 0, icon: '\u{1F43E}', ...def };
    if (!it.pos && it.obj) it.pos = () => it.obj.getWorldPosition(_v.clone());
    this.interactables.push(it);
    if (it.obj) this.pickable(it.obj, it);
    return it;
  }
  removeInteract(it) {
    const i = this.interactables.indexOf(it);
    if (i >= 0) this.interactables.splice(i, 1);
    this.pickables = this.pickables.filter((p) => p.it !== it);
  }
  pickable(obj, it) { obj.traverse((o) => { o.userData.pick = it; }); this.pickables.push({ obj, it }); }
  posOf(it) { return typeof it.pos === 'function' ? it.pos() : it.pos; }
  labelOf(it) {
    if (it.enabled === false || (typeof it.enabled === 'function' && !it.enabled())) return null;
    return typeof it.label === 'function' ? it.label() : it.label;
  }

  /** Circle trigger: onEnter/onExit/onStay(dt). */
  trigger(def) { const t = { radius: 2, inside: false, ...def }; this.triggers.push(t); return t; }

  /** Per-frame callback; return true to remove it. */
  every(fn) { this.updaters.push(fn); return fn; }
  on(name, fn) { const off = events.on(name, fn); this.unsubs.push(off); return off; }
  /** Vocal listener: fn({kind, pos}) — fires for meow/hiss/growl. */
  onVocal(fn) { return this.on('vocal', fn); }

  /**
   * Whisker Sense target: shimmers when Khione meows nearby. `warm()` true marks
   * the honest clue of an unsolved riddle (gold shimmer, never the answer).
   */
  sense(obj, { warm = () => false, radius = 11, height = 1 } = {}) {
    const s = { obj, warm, radius, height };
    this.senses.push(s);
    return s;
  }

  /**
   * A collectable item lying in the world. Persists: once taken (flag
   * `took_<key>`) it never respawns. `obj` = custom mesh (else a glowing orb
   * with the item emoji floats there).
   *   pickup({ id: 'coconut', key: 'coconut_a', pos: V3(...), obj, label, onTake })
   */
  pickup({ id, key = id, pos, obj, label, onTake, bob = true, radius = 1.4, sense = true }) {
    if (G.state.flag(`took_${key}`)) return null;
    const holder = new THREE.Group();
    holder.position.copy(pos);
    if (!obj) {
      obj = new THREE.Sprite(new THREE.SpriteMaterial({ map: itemTexture(id), transparent: true }));
      obj.scale.set(0.75, 0.75, 1);
      obj.position.y = 0.45;
    }
    holder.add(obj);
    this.root.add(holder);
    const base = obj.position.y;
    const t0 = Math.random() * 6;
    if (bob) this.every(() => {
      if (!holder.parent) return true;
      obj.position.y = base + Math.sin(G.time * 2.2 + t0) * 0.07;
      obj.rotation.y += 0.01;
    });
    const it = this.interact({
      obj: holder, radius, icon: '✋',
      label: label ?? (() => `Pick up ${itemNameOf(id)}`),
      use: () => {
        if (!G.state.give(id)) return;
        G.state.set(`took_${key}`);
        G.player.emote('pickup', 2.2);
        G.fx.sparkle(holder.position.clone().add(new THREE.Vector3(0, 0.4, 0)));
        holder.removeFromParent();
        this.removeInteract(it);
        onTake?.();
      },
    });
    if (sense) this.sense(holder, { height: 0.4 });
    holder.userData.interact = it;
    return holder;
  }

  /**
   * She marks, he digs. A buried thing at `pos`: when Khione meows within
   * `radius` and Oreo is with her, he digs it up and onDug() runs.
   */
  digSpot({ pos, key, radius = 2.4, onDug, mound = true, warm = () => true, needOreo = true }) {
    if (key && G.state.flag(`dug_${key}`)) return null;
    let moundMesh = null;
    if (mound) {
      moundMesh = new THREE.Mesh(new THREE.SphereGeometry(0.6, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshLambertMaterial({ color: this.moundColor ?? '#f4f7fb' }));
      moundMesh.scale.y = 0.45;
      moundMesh.position.set(pos.x, this.groundAt(pos.x, pos.z, 99) - 0.02, pos.z);
      moundMesh.receiveShadow = true;
      this.root.add(moundMesh);
    }
    const spot = { pos, dug: false, mesh: moundMesh, busy: false };
    this.sense(moundMesh ?? pos, { warm, height: 0.4 });
    this.onVocal(async (e) => {
      if (e.kind !== 'meow' || spot.dug || spot.busy) return;
      if (Math.hypot(e.pos.x - pos.x, e.pos.z - pos.z) > radius) return;
      if (needOreo && !G.oreo.active) return;
      spot.busy = true;
      G.fx.ring(new THREE.Vector3(pos.x, this.groundAt(pos.x, pos.z, 99), pos.z), '#ffd24a', 1.2, 0.8);
      if (needOreo) await G.oreo.dig(pos);
      spot.dug = true; spot.busy = false;
      if (key) G.state.set(`dug_${key}`);
      if (moundMesh) G.tween(moundMesh.scale, { y: 0.05 }, 0.4).then(() => moundMesh.removeFromParent());
      onDug?.(spot);
    });
    return spot;
  }

  add(...objs) { for (const o of objs) this.root.add(o); return objs[0]; }
  say(text, opts) { return G.ui.say(text, opts); }

  // ── Frame ──────────────────────────────────────────────
  _frame(dt) {
    if (this.water) this.water.userData.update(G.time);
    for (let i = this.updaters.length - 1; i >= 0; i--) {
      try { if (this.updaters[i](dt) === true) this.updaters.splice(i, 1); } catch (e) { console.error(e); this.updaters.splice(i, 1); }
    }
    const p = G.player?.pos;
    if (!p) return;
    for (const t of this.triggers) {
      if (t.enabled === false) continue;
      const tp = typeof t.pos === 'function' ? t.pos() : t.pos;
      const inside = Math.hypot(p.x - tp.x, p.z - tp.z) < t.radius && (t.y == null || Math.abs(p.y - t.y) < (t.yr ?? 2));
      if (inside && !t.inside) { t.inside = true; t.onEnter?.(); if (t.once) t.enabled = false; }
      else if (!inside && t.inside) { t.inside = false; t.onExit?.(); }
      if (inside) t.onStay?.(dt);
    }
    // Pick the interactable Khione is closest to (and facing, a little).
    let best = null, bestScore = Infinity;
    if (!G.cine?.active) {
      for (const it of this.interactables) {
        const label = this.labelOf(it);
        if (!label) continue;
        const ip = this.posOf(it);
        const d = Math.hypot(p.x - ip.x, p.z - ip.z);
        if (d > it.radius || Math.abs((ip.y ?? p.y) - p.y) > (it.yRange ?? 2.5)) continue;
        const score = d - it.priority * 10;
        if (score < bestScore) { bestScore = score; best = it; }
      }
    }
    this.focus = best;
  }

  useFocus() {
    const it = this.focus;
    if (!it) return false;
    G.player.faceTo(this.posOf(it));
    it.use?.();
    return true;
  }

  /** Tap at screen x,y: interactable → walk there and use; ground → walk there. */
  handleTap(x, y) {
    _ndc.set((x / window.innerWidth) * 2 - 1, -(y / window.innerHeight) * 2 + 1);
    _ray.setFromCamera(_ndc, G.camera);
    const objs = this.pickables.map((p) => p.obj).filter((o) => o.visible !== false);
    const hits = _ray.intersectObjects(objs, true);
    for (const h of hits) {
      const it = h.object.userData.pick;
      if (!it || !this.labelOf(it)) continue;
      const ip = this.posOf(it);
      const p = G.player.pos;
      if (Math.hypot(p.x - ip.x, p.z - ip.z) <= it.radius + 0.3) { G.player.faceTo(ip); it.use?.(); }
      else G.player.walkTo(ip, Math.max(0.6, it.radius * 0.7), () => { if (this.labelOf(it)) { G.player.faceTo(ip); it.use?.(); } });
      G.fx?.tapMark(h.point, true);
      return true;
    }
    const g = _ray.intersectObjects(this.groundMeshes, true)[0];
    if (g) {
      G.player.walkTo(g.point, 0.25);
      G.fx?.tapMark(g.point, false);
      return true;
    }
    return false;
  }

  /** Meow ripple: shimmer nearby senses. */
  whiskerSense(pos) {
    for (const s of this.senses) {
      const o = s.obj.isObject3D ? s.obj.getWorldPosition(_v.clone()) : (typeof s.obj === 'function' ? s.obj() : s.obj);
      if (!o) continue;
      const d = Math.hypot(o.x - pos.x, o.z - pos.z);
      if (d > s.radius) continue;
      const warm = !!s.warm();
      setTimeout(() => G.fx?.shimmer(_v.set(o.x, o.y + s.height, o.z).clone(), warm), 120 + d * 60);
    }
  }

  dispose() {
    for (const off of this.unsubs) off();
    this.root.traverse((o) => {
      if (o.isMesh || o.isPoints || o.isInstancedMesh) {
        if (!o.userData.shared) o.geometry?.dispose();
      }
    });
    this.root.removeFromParent();
  }
}
