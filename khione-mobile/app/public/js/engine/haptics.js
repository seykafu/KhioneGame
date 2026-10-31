// Taptic feedback in the native iOS app (KhioneHaptics plugin in
// native/ios/App/App/KhioneViewController.swift). On the web it does nothing.
// Most feedback rides on sound effects, so every island gets it for free.
import { G } from './core.js';

const cap = window.Capacitor;
const native = !!cap?.isNativePlatform?.() && typeof cap.nativePromise === 'function';
const KEY = 'khione_haptics';
let enabled = localStorage.getItem(KEY) !== '0';
const lastAt = new Map();

function call(method, options) {
  try { cap.nativePromise('KhioneHaptics', method, options)?.catch?.(() => {}); } catch {}
}
function throttled(key, ms) {
  const now = performance.now();
  if (now - (lastAt.get(key) ?? -1e9) < ms) return true;
  lastAt.set(key, now);
  return false;
}

export const haptics = {
  available: native,
  get enabled() { return enabled; },
  set enabled(v) { enabled = !!v; localStorage.setItem(KEY, enabled ? '1' : '0'); },
  impact(style = 'light', intensity = 1, key = style) {
    if (!native || !enabled || throttled(key, 70)) return;
    call('impact', { style, intensity });
  },
  notify(type = 'success') {
    if (!native || !enabled || throttled(`n-${type}`, 400)) return;
    call('notify', { type });
  },
  selection() {
    if (!native || !enabled || throttled('sel', 50)) return;
    call('selection', {});
  },
};

// sound effect → [kind, style/type, intensity]
const SFX_HAPTICS = {
  meow: ['impact', 'light', 0.6], hiss: ['impact', 'medium', 0.9], growl: ['impact', 'heavy', 1],
  success: ['notify', 'success'], fail: ['notify', 'warning'],
  pickup_chime: ['impact', 'light', 0.8], land: ['impact', 'soft', 0.7], jump_whoosh: ['impact', 'light', 0.35],
  coconut_thunk: ['impact', 'medium', 0.8], gate_open: ['impact', 'medium', 0.9], stone_slide: ['impact', 'rigid', 0.6],
  bonk: ['impact', 'medium', 0.8], smash: ['impact', 'heavy', 0.8], crab_snip: ['impact', 'rigid', 0.5],
  splash: ['impact', 'soft', 0.6], drain: ['impact', 'soft', 0.7], dig: ['impact', 'light', 0.5], snow_dig: ['impact', 'light', 0.5],
  sled: ['impact', 'medium', 0.7],
  bell_ding: ['impact', 'rigid', 0.5], wood_creak: ['impact', 'soft', 0.5],
  goal_horn: ['impact', 'heavy', 1], lever_clunk: ['impact', 'rigid', 0.8], oven_pop: ['impact', 'light', 0.7],
  drum_low: ['impact', 'heavy', 0.9], drum_mid: ['impact', 'medium', 0.8], drum_high: ['impact', 'light', 0.8],
  horse_snort: ['impact', 'medium', 0.6],
};

/** Called by audio.sfx(): buzz for nearby, meaningful sounds only. */
export function hapticForSfx(name, pos) {
  const h = SFX_HAPTICS[name];
  if (!h || !native || !enabled) return;
  const p = G.player?.pos;
  if (pos && p && Math.hypot(pos.x - p.x, pos.z - p.z) > 7) return;
  if (h[0] === 'notify') haptics.notify(h[1]);
  else haptics.impact(h[1], h[2] ?? 1, name);
}

G.haptics = haptics;
