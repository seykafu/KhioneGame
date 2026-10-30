// The shared game context. Every system hangs itself here at boot so islands
// can reach anything through one import: `import { G } from '../engine/core.js'`.
import * as THREE from 'three';

export const G = {
  THREE,
  time: 0,          // game seconds; frozen while paused
  dt: 0,
  paused: false,
  debug: new URLSearchParams(location.search).has('debug'),
  params: new URLSearchParams(location.search),
};

// ── Event bus ─────────────────────────────────────────────
const handlers = new Map();
export const events = {
  on(name, fn) {
    if (!handlers.has(name)) handlers.set(name, new Set());
    handlers.get(name).add(fn);
    return () => handlers.get(name)?.delete(fn);
  },
  emit(name, data) {
    const set = handlers.get(name);
    if (!set) return;
    for (const fn of [...set]) {
      try { fn(data); } catch (e) { console.error(`[event ${name}]`, e); }
    }
  },
};
G.events = events;

// ── Game-clock timers & tweens (pause with the game) ─────
const timers = [];
const tweens = [];

/** Resolves after `s` game-seconds. */
export function wait(s) {
  return new Promise((resolve) => timers.push({ at: G.time + s, resolve }));
}
G.wait = wait;

export const ease = {
  linear: (t) => t,
  inOut: (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
  out: (t) => 1 - (1 - t) * (1 - t),
  in: (t) => t * t,
  outBack: (t) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
  outBounce: (t) => {
    const n = 7.5625, d = 2.75;
    if (t < 1 / d) return n * t * t;
    if (t < 2 / d) return n * (t -= 1.5 / d) * t + 0.75;
    if (t < 2.5 / d) return n * (t -= 2.25 / d) * t + 0.9375;
    return n * (t -= 2.625 / d) * t + 0.984375;
  },
  outElastic: (t) => (t === 0 || t === 1 ? t : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI / 3)) + 1),
};

/**
 * Tween numeric props (or a Vector3/Euler/Color's components) on `target`.
 * tween(mesh.position, { y: 2 }, 0.5, ease.out) → Promise
 */
export function tween(target, to, dur = 0.5, fn = ease.inOut, onUpdate) {
  const from = {};
  for (const k in to) from[k] = target[k];
  return new Promise((resolve) => {
    // A new tween on the same target+keys supersedes the old one.
    for (const tw of tweens) {
      if (tw.target === target) for (const k in to) delete tw.to[k];
    }
    tweens.push({ target, from, to, start: G.time, dur: Math.max(0.0001, dur), fn, onUpdate, resolve });
  });
}
G.tween = tween;

/** Calls fn(t) each frame for `dur` seconds (t goes 0→1). */
export function animate(dur, fn, e = ease.linear) {
  return new Promise((resolve) => {
    tweens.push({ custom: fn, start: G.time, dur: Math.max(0.0001, dur), fn: e, resolve, to: {} });
  });
}
G.animate = animate;

export function tickTimers() {
  for (let i = timers.length - 1; i >= 0; i--) {
    if (G.time >= timers[i].at) { const t = timers[i]; timers.splice(i, 1); t.resolve(); }
  }
  for (let i = tweens.length - 1; i >= 0; i--) {
    const tw = tweens[i];
    const raw = Math.min(1, (G.time - tw.start) / tw.dur);
    const k = tw.fn(raw);
    if (tw.custom) tw.custom(k);
    else {
      for (const key in tw.to) tw.target[key] = tw.from[key] + (tw.to[key] - tw.from[key]) * k;
      tw.onUpdate?.(k);
    }
    if (raw >= 1) { tweens.splice(i, 1); tw.resolve(); }
  }
}

/** Drops pending timers/tweens (used on island change so stale awaits never fire into a new island). */
export function clearTimers() {
  timers.length = 0;
  tweens.length = 0;
}

// ── Math helpers ──────────────────────────────────────────
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const lerp = (a, b, t) => a + (b - a) * t;
export const damp = (a, b, lambda, dt) => lerp(a, b, 1 - Math.exp(-lambda * dt));
export const smooth = (t) => t * t * (3 - 2 * t);
export function angleLerp(a, b, t) {
  let d = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
  if (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}
export function dist2(ax, az, bx, bz) { const dx = ax - bx, dz = az - bz; return Math.sqrt(dx * dx + dz * dz); }

/** Deterministic RNG (mulberry32). */
export function rng(seed = 1) {
  let a = seed >>> 0;
  const r = () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  r.range = (lo, hi) => lo + r() * (hi - lo);
  r.int = (lo, hi) => Math.floor(lo + r() * (hi - lo + 1));
  r.pick = (arr) => arr[Math.floor(r() * arr.length)];
  return r;
}

/** Cheap 2D value noise in [-1,1], smooth enough for terrain detail. */
export function noise2(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const h = (i, j) => {
    let n = i * 374761393 + j * 668265263;
    n = (n ^ (n >>> 13)) * 1274126177;
    return ((n ^ (n >>> 16)) & 0xffff) / 0x7fff - 1;
  };
  const u = smooth(xf), v = smooth(yf);
  return lerp(lerp(h(xi, yi), h(xi + 1, yi), u), lerp(h(xi, yi + 1), h(xi + 1, yi + 1), u), v);
}
export function fbm(x, y, oct = 3) {
  let s = 0, a = 0.5, f = 1;
  for (let i = 0; i < oct; i++) { s += a * noise2(x * f, y * f); f *= 2; a *= 0.5; }
  return s;
}

export const V3 = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
