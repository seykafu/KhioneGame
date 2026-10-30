// Procedural building blocks for island dressing and puzzle props. Chunky,
// rounded, softly-shaded — the same toy-like language as the Higgsfield models.
import * as THREE from 'three';
import { G, rng } from './core.js';
import { texture } from './assets.js';

const matCache = new Map();
/** Cached Lambert material by colour (+ options). */
export function mat(color, { emissive, emissiveIntensity = 1, map, transparent = false, opacity = 1, side, flat = false, rough } = {}) {
  const key = [color, emissive, emissiveIntensity, map, transparent, opacity, side, flat, rough].join('|');
  if (!matCache.has(key)) {
    const m = rough != null
      ? new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: 0 })
      : new THREE.MeshLambertMaterial({ color });
    if (emissive) { m.emissive = new THREE.Color(emissive); m.emissiveIntensity = emissiveIntensity; }
    if (map) m.map = typeof map === 'string' ? texture(map) : map;
    if (transparent) { m.transparent = true; m.opacity = opacity; m.depthWrite = opacity > 0.6; }
    if (side) m.side = side;
    if (flat) m.flatShading = true;
    matCache.set(key, m);
  }
  return matCache.get(key);
}

function mesh(geo, material, { cast = true, receive = true } = {}) {
  const m = new THREE.Mesh(geo, material);
  m.castShadow = cast; m.receiveShadow = receive;
  return m;
}

export function box(w, h, d, color, opts = {}) {
  const g = opts.round ? roundedBox(w, h, d, opts.round) : new THREE.BoxGeometry(w, h, d);
  const m = mesh(g, typeof color === 'object' && color.isMaterial ? color : mat(color, opts), opts);
  if (opts.base !== false) g.translate(0, h / 2, 0); // origin at the base
  return m;
}
export function cyl(rTop, rBot, h, color, opts = {}) {
  const g = new THREE.CylinderGeometry(rTop, rBot, h, opts.seg ?? 16, 1, opts.open ?? false);
  if (opts.base !== false) g.translate(0, h / 2, 0);
  return mesh(g, typeof color === 'object' && color.isMaterial ? color : mat(color, opts), opts);
}
export function sphere(r, color, opts = {}) {
  const g = new THREE.SphereGeometry(r, opts.seg ?? 18, Math.max(8, (opts.seg ?? 18) * 0.66 | 0));
  return mesh(g, typeof color === 'object' && color.isMaterial ? color : mat(color, opts), opts);
}
export function cone(r, h, color, opts = {}) {
  const g = new THREE.ConeGeometry(r, h, opts.seg ?? 14);
  if (opts.base !== false) g.translate(0, h / 2, 0);
  return mesh(g, mat(color, opts), opts);
}
export function torus(r, tube, color, opts = {}) {
  return mesh(new THREE.TorusGeometry(r, tube, 10, opts.seg ?? 28, opts.arc ?? Math.PI * 2), mat(color, opts), opts);
}

/** Soft-edged box (chamfered by a scaled sphere-ish trick: cheap and cute). */
export function roundedBox(w, h, d, r = 0.08) {
  const g = new THREE.BoxGeometry(w, h, d, 3, 3, 3);
  const p = g.attributes.position, v = new THREE.Vector3();
  const hw = w / 2 - r, hh = h / 2 - r, hd = d / 2 - r;
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const cx = Math.max(-hw, Math.min(hw, v.x)), cy = Math.max(-hh, Math.min(hh, v.y)), cz = Math.max(-hd, Math.min(hd, v.z));
    const dx = v.x - cx, dy = v.y - cy, dz = v.z - cz, l = Math.hypot(dx, dy, dz) || 1;
    p.setXYZ(i, cx + (dx / l) * r, cy + (dy / l) * r, cz + (dz / l) * r);
  }
  g.computeVertexNormals();
  return g;
}

/** Lumpy boulder. */
export function rock(r = 1, color = '#b98e5a', seed = 1, squash = 0.75) {
  const g = new THREE.IcosahedronGeometry(r, 1);
  const p = g.attributes.position, R = rng(seed), v = new THREE.Vector3();
  const seen = new Map();
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const key = `${v.x.toFixed(3)},${v.y.toFixed(3)},${v.z.toFixed(3)}`;
    if (!seen.has(key)) seen.set(key, 0.82 + R() * 0.3);
    const k = seen.get(key);
    p.setXYZ(i, v.x * k, v.y * k * squash, v.z * k);
  }
  g.computeVertexNormals();
  g.translate(0, r * squash * 0.55, 0);
  return mesh(g, mat(color, { flat: true }));
}

/** Rope/vine/line between points (array of Vector3). */
export function rope(points, radius = 0.04, color = '#c9a46a', opts = {}) {
  const curve = new THREE.CatmullRomCurve3(points);
  const g = new THREE.TubeGeometry(curve, Math.max(8, points.length * 8), radius, 6, false);
  return mesh(g, mat(color, opts), { cast: opts.cast ?? false });
}

/** Wooden fence run from a→b with posts every `gap`. */
export function fence(a, b, { h = 0.9, gap = 1.6, color = '#a0662e', rails = 2 } = {}) {
  const g = new THREE.Group();
  const len = a.distanceTo(b), n = Math.max(1, Math.round(len / gap));
  const dir = b.clone().sub(a);
  const ang = Math.atan2(dir.x, dir.z);
  for (let i = 0; i <= n; i++) {
    const p = a.clone().lerp(b, i / n);
    const post = box(0.14, h, 0.14, color, { round: 0.03 });
    post.position.copy(p);
    g.add(post);
  }
  for (let r = 0; r < rails; r++) {
    const rail = box(0.06, 0.09, len, color);
    rail.geometry.translate(0, -0.045, 0);
    const mid = a.clone().lerp(b, 0.5);
    rail.position.set(mid.x, a.y + h * (0.35 + r * 0.4), mid.z);
    rail.rotation.y = ang;
    g.add(rail);
  }
  return g;
}

// ── Text on canvas ───────────────────────────────────────
export function textCanvas(lines, { w = 512, h = 256, bg = '#fff4dc', fg = '#173b44', border = '#173b44', font = 'bold 40px "Baloo 2", "Arial Rounded MT Bold", sans-serif', pad = 24, radius = 26, align = 'center', draw } = {}) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d');
  if (bg) {
    g.fillStyle = bg; g.strokeStyle = border; g.lineWidth = 10;
    roundRect(g, 5, 5, w - 10, h - 10, radius); g.fill(); if (border) g.stroke();
  }
  g.fillStyle = fg; g.font = font; g.textAlign = align; g.textBaseline = 'middle';
  const arr = Array.isArray(lines) ? lines : [lines];
  const lh = (h - pad * 2) / Math.max(1, arr.length);
  arr.forEach((ln, i) => g.fillText(ln, align === 'center' ? w / 2 : pad, pad + lh * (i + 0.5)));
  draw?.(g, w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}
function roundRect(g, x, y, w, h, r) {
  g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}

/** A flat sign/plaque panel facing +Z. */
export function sign(lines, { w = 1.6, h = 0.8, post = 0, color = '#8a5a2b', ...canvasOpts } = {}) {
  const g = new THREE.Group();
  const tex = textCanvas(lines, { w: 512, h: Math.round(512 * h / w), ...canvasOpts });
  const face = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshLambertMaterial({ map: tex, transparent: true }));
  const back = box(w + 0.08, h + 0.08, 0.06, color, { base: false });
  face.position.z = 0.035;
  const panel = new THREE.Group(); panel.add(back, face);
  panel.position.y = post + h / 2;
  g.add(panel);
  if (post > 0) { const p = box(0.12, post + h * 0.5, 0.12, color); p.position.z = -0.07; g.add(p); }
  g.userData.face = face;
  return g;
}

/** Billboard label that always faces the camera. */
export function label(text, { scale = 1, ...o } = {}) {
  const tex = textCanvas(text, { w: 512, h: 128, font: 'bold 54px "Baloo 2", sans-serif', ...o });
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthTest: false }));
  s.scale.set(2 * scale, 0.5 * scale, 1);
  s.renderOrder = 9;
  return s;
}

/** Pulsing glow orb (for keys, goals, beacons). */
export function glow(color = '#ffd24a', r = 0.25) {
  const g = new THREE.Group();
  const core = sphere(r, color, { emissive: color, emissiveIntensity: 1.2 });
  core.castShadow = false;
  const halo = new THREE.Mesh(new THREE.SphereGeometry(r * 2.2, 16, 12), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.18, depthWrite: false }));
  g.add(core, halo);
  g.userData.update = (t) => { const s = 1 + Math.sin(t * 3) * 0.12; halo.scale.setScalar(s); };
  return g;
}

/** Simple house/building box with roof and windows (for city dressing). */
export function building({ w = 6, d = 6, h = 4, wall = '#e8d9c0', roof = '#b5523b', windows = '#9fd6e8', roofH = 1.6, flat = false, door = '#6a3d2a' } = {}) {
  const g = new THREE.Group();
  const body = box(w, h, d, wall, { round: 0.06 });
  g.add(body);
  if (flat) {
    const cap = box(w + 0.3, 0.3, d + 0.3, roof); cap.position.y = h; g.add(cap);
  } else {
    const shape = new THREE.Shape();
    shape.moveTo(-w / 2 - 0.3, 0); shape.lineTo(w / 2 + 0.3, 0); shape.lineTo(0, roofH); shape.closePath();
    const rg = new THREE.ExtrudeGeometry(shape, { depth: d + 0.5, bevelEnabled: false });
    rg.translate(0, h, -(d + 0.5) / 2);
    g.add(mesh(rg, mat(roof)));
  }
  const winMat = mat(windows, { emissive: windows, emissiveIntensity: 0.15 });
  const cols = Math.max(1, Math.floor(w / 1.8)), rows = Math.max(1, Math.floor(h / 1.9));
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    if (r === 0 && c === Math.floor(cols / 2)) continue;
    const wn = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.9), winMat);
    wn.position.set(-w / 2 + (c + 0.5) * (w / cols), 1.1 + r * 1.8, d / 2 + 0.01);
    g.add(wn);
  }
  const dr = box(0.9, 1.6, 0.08, door); dr.position.set(-w / 2 + (Math.floor(cols / 2) + 0.5) * (w / cols), 0, d / 2);
  g.add(dr);
  return g;
}

/** A pennant flag on a pole. */
export function flag(color = '#ff6b4a', h = 1.4) {
  const g = new THREE.Group();
  const pole = cyl(0.03, 0.03, h, '#6b5a4a'); g.add(pole);
  const sh = new THREE.Shape(); sh.moveTo(0, 0); sh.lineTo(0.55, -0.16); sh.lineTo(0, -0.32); sh.closePath();
  const f = new THREE.Mesh(new THREE.ShapeGeometry(sh), mat(color, { side: THREE.DoubleSide }));
  f.position.y = h; g.add(f);
  g.userData.cloth = f;
  return g;
}

/** Stylised low bush. */
export function bush(r = 0.7, color = '#4fa83a', seed = 3) {
  const g = new THREE.Group(); const R = rng(seed);
  for (let i = 0; i < 4; i++) {
    const s = sphere(r * (0.55 + R() * 0.35), color, { seg: 10 });
    s.position.set((R() - 0.5) * r, r * 0.45 + R() * r * 0.2, (R() - 0.5) * r);
    g.add(s);
  }
  return g;
}

/** Ground decal circle (shadow / mark). */
export function decal(r, color = '#000', opacity = 0.2) {
  const m = new THREE.Mesh(new THREE.CircleGeometry(r, 24), new THREE.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false }));
  m.rotation.x = -Math.PI / 2; m.renderOrder = 2;
  return m;
}

/** A soft beam of light (sundial shadow pointer, lighthouse beam, totem gaze). */
export function beam(len = 6, width = 0.4, color = '#fff2b0', opacity = 0.5) {
  const g = new THREE.PlaneGeometry(width, len);
  g.rotateX(-Math.PI / 2); g.translate(0, 0, len / 2);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color, transparent: true, opacity, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending }));
  m.renderOrder = 3;
  return m;
}

/**
 * Merge many static meshes (same material) into one draw call each. Keeps
 * the scene light on phones. Meshes keep their world transform.
 */
export function bake(group) {
  group.updateMatrixWorld(true);
  const byMat = new Map();
  const remove = [];
  group.traverse((o) => {
    if (!o.isMesh || o.isSkinnedMesh || o.isInstancedMesh || o.userData.noBake || o.userData.shared || Array.isArray(o.material)) return;
    if (o.material.map?.isCanvasTexture) return;
    const k = o.material.uuid + (o.castShadow ? 'c' : '');
    if (!byMat.has(k)) byMat.set(k, []);
    byMat.get(k).push(o);
  });
  const out = new THREE.Group();
  for (const list of byMat.values()) {
    if (list.length < 2) continue;
    const geos = [];
    for (const o of list) {
      let g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
      for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(name)) g.deleteAttribute(name);
      if (!g.attributes.uv) g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
      if (!g.attributes.normal) g.computeVertexNormals();
      g.applyMatrix4(o.matrixWorld);
      geos.push(g);
      remove.push(o);
    }
    const merged = mergeSimple(geos);
    const m = new THREE.Mesh(merged, list[0].material);
    m.castShadow = list[0].castShadow; m.receiveShadow = true;
    out.add(m);
  }
  for (const o of remove) o.removeFromParent();
  return out;
}
function mergeSimple(geos) {
  let n = 0; for (const g of geos) n += g.attributes.position.count;
  const pos = new Float32Array(n * 3), nor = new Float32Array(n * 3), uv = new Float32Array(n * 2);
  let o = 0;
  for (const g of geos) {
    pos.set(g.attributes.position.array, o * 3); nor.set(g.attributes.normal.array, o * 3); uv.set(g.attributes.uv.array, o * 2);
    o += g.attributes.position.count; g.dispose();
  }
  const m = new THREE.BufferGeometry();
  m.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  m.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  m.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
  m.computeBoundingSphere();
  return m;
}

export const P = { mat, box, cyl, sphere, cone, torus, rock, rope, fence, textCanvas, sign, label, glow, building, flag, bush, decal, beam, bake, roundedBox };
G.prefabs = P;
