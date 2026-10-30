// Cloud save: each journey gets a private room on the game server (see
// src/logic.js). Progress syncs there a few seconds after every save, and the
// "cloud code" restores it on any device — including a Home Screen install,
// which on iOS does not share storage with Safari.
import { G, events } from './core.js';
import { state } from './state.js';

const KEY = 'khione_cloud_v1';
// Inside the native iOS wrapper the page is served from capacitor://localhost,
// so cloud saves go to the hosted game server instead.
const SERVER = /^https?:$/.test(location.protocol) && !/^(localhost|127\.0\.0\.1)(:\d+)?$/.test(location.host)
  ? { proto: location.protocol === 'https:' ? 'wss' : 'ws', host: location.host }
  : { proto: 'wss', host: 'khione-islands.higgsfield.app' };
const rand = (n) => Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => 'abcdefghjkmnpqrstuvwxyz23456789'[b % 31]).join('');

function identity() {
  let id = null;
  try { id = JSON.parse(localStorage.getItem(KEY)); } catch {}
  if (!id?.room || !id?.pid) { id = { room: `k${rand(9)}`, pid: rand(10) }; localStorage.setItem(KEY, JSON.stringify(id)); }
  return id;
}
export const cloudCode = () => { const id = identity(); return `${id.room}-${id.pid}`; };
const parseCode = (code) => {
  const m = String(code).trim().toLowerCase().match(/^(k[a-z0-9]{6,20})-([a-z0-9]{6,20})$/);
  return m ? { room: m[1], pid: m[2] } : null;
};

/** One request/response round trip with the room. */
function session(id, onView, timeout = 8000) {
  return new Promise((resolve, reject) => {
    if (!navigator.onLine) return reject(new Error('offline'));
    const ws = new WebSocket(`${SERVER.proto}://${SERVER.host}/ws/${id.room}`);
    const t = setTimeout(() => { try { ws.close(); } catch {} reject(new Error('timeout')); }, timeout);
    ws.onopen = () => ws.send(JSON.stringify({ type: 'join', playerId: id.pid }));
    ws.onerror = () => { clearTimeout(t); reject(new Error('network')); };
    ws.onmessage = (ev) => {
      let msg; try { msg = JSON.parse(ev.data); } catch { return; }
      if (msg.type === 'error') { clearTimeout(t); ws.close(); reject(new Error(msg.error)); return; }
      if (msg.type !== 'state') return;
      const done = onView(msg.view, ws);
      if (done !== false) { clearTimeout(t); ws.close(); resolve(msg.view); }
    };
  });
}

let pending = null;
let lastPushed = '';
let failures = 0;
const LOCAL_DEV = /^(localhost|127\.0\.0\.1)(:\d+)?$/.test(location.host);
/** Push the current save (debounced by caller). */
export async function push({ manual = false } = {}) {
  if (!state.started) return;
  // Stay quiet after repeated failures (offline, or the server wants a sign-in).
  if (!manual && (failures >= 2 || LOCAL_DEV)) return;
  const data = JSON.stringify(state.toJSON());
  if (data === lastPushed) return;
  const rev = Math.floor(Date.now() / 1000);
  const id = identity();
  let sent = false;
  await session(id, (view, ws) => {
    if (sent) return true;
    ws.send(JSON.stringify({ type: 'action', action: { type: 'save', data, rev } }));
    sent = true;
    return false; // wait for the confirming state frame
  }).then(() => { lastPushed = data; failures = 0; }).catch(() => { failures++; });
}

/** Restore a journey from a cloud code. Returns true on success. */
export async function restore(code) {
  const id = parseCode(code);
  if (!id) return false;
  try {
    const view = await session(id, () => true);
    if (!view?.mine || !view.save) return false;
    if (!state.load(JSON.parse(view.save))) return false;
    localStorage.setItem(KEY, JSON.stringify(id)); // adopt this journey's slot
    state.save();
    return true;
  } catch { return false; }
}

export function initCloud() {
  events.on('saved', () => {
    clearTimeout(pending);
    pending = setTimeout(push, 4000);
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden) push(); });
}

G.cloud = { code: cloudCode, push, restore };
