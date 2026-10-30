// Dev-only test helpers, used from the browser console with ?debug:
//   const T = await import('/js/dev/harness.js');
//   await T.newGame(); await T.go(33, -6); await T.meow(); T.flag('echo_stones_solved')
import { G, events } from '../engine/core.js';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function until(fn, ms = 15000) {
  const t0 = performance.now();
  while (!fn()) { if (performance.now() - t0 > ms) return false; await sleep(50); }
  return true;
}

/** Start a fresh journey from the title screen and skip the intro. */
export async function newGame() {
  await until(() => document.querySelector('.title [data-a=new]'), 20000);
  const b = document.querySelector('.title [data-a=new]');
  if (b) { window.confirm = () => true; b.click(); }
  await until(() => G.cine?.active, 5000);
  await skip();
}

export async function skip() {
  for (let i = 0; i < 60 && (G.cine.active || G.ui.card.classList.contains('on')); i++) { events.emit('skip'); await sleep(250); }
  await sleep(200);
}

/** Teleport next to x,z (optionally y) and settle. */
export async function go(x, z, y) { G.player.teleport(x, z, G.player.yaw, y); await sleep(250); return G.player.pos.clone(); }

/** Use the current focus (like pressing the action button). */
export async function use() { const f = G.island.focus; const label = f ? G.island.labelOf(f) : null; G.input.pressAction(); await sleep(300); return label; }

export async function meow(kind = 'meow') { G.player.vocalCooldown = 0; G.player.vocal(kind); await sleep(700); }

export function flag(n) { return G.state.flag(n); }
export function items() { return G.state.stacks.map((s) => `${s.id}x${s.count}`); }
export function focus() { return G.island.focus ? G.island.labelOf(G.island.focus) : null; }
export function goal() { return document.querySelector('.goal').textContent; }
export async function closePanel() { if (G.ui.modalOpen) G.ui.closeSheet(); await sleep(200); }
/** Interactables near the player with their labels. */
export function near(r = 4) {
  const p = G.player.pos;
  return G.island.interactables.map((it) => { const q = G.island.posOf(it); return { label: G.island.labelOf(it), d: +Math.hypot(q.x - p.x, q.z - p.z).toFixed(2), x: +q.x.toFixed(1), z: +q.z.toFixed(1) }; }).filter((o) => o.d < r);
}
/** Walk toward x,z by holding the virtual stick (tests real collision). */
export async function walk(x, z, ms = 4000) {
  const t0 = performance.now();
  while (performance.now() - t0 < ms) {
    const p = G.player.pos, dx = x - p.x, dz = z - p.z, d = Math.hypot(dx, dz);
    if (d < 0.4) break;
    const b = G.render.camBasis();
    // Convert world direction to stick (screen) space.
    const sx = (dx * b.rx + dz * b.rz) / d, sy = -(dx * b.fx + dz * b.fz) / d;
    G.input.move.x = sx; G.input.move.y = sy; G.input.move.mag = 0.85; G.input.joyId = 'test';
    await sleep(40);
  }
  G.input.release();
  return G.player.pos.clone();
}
/** Grab the 3D view (no DOM UI) and post it to the local shot receiver on :8431. */
export async function shot(name = 'shot.jpg') {
  G.renderer.render(G.scene, G.camera);
  const url = G.renderer.domElement.toDataURL('image/jpeg', 0.8);
  await fetch(`http://127.0.0.1:8431/${name}`, { method: 'POST', body: url });
  return name;
}
export function errors() { return window.__errs ?? []; }
window.__errs = window.__errs ?? [];
window.addEventListener('error', (e) => window.__errs.push(String(e.message)));
window.addEventListener('unhandledrejection', (e) => window.__errs.push(String(e.reason)));
