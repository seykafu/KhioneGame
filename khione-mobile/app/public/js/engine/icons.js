// Hand-painted icons (GPT Image 2.5 via Higgsfield; prompts in design/icons.csv).
// Game text keeps writing emoji; iconize() swaps every emoji that has a
// painted icon for an <img>, and watch() runs it over all UI the islands
// create (toasts, buttons, captions, puzzle panels). Items or interactions
// that want an icon no emoji names use a ':name:' token instead.
import { G } from './core.js';

const ICONS = {
  meow: ['🐱'], hiss: ['🙀'], growl: ['🐯'], dog: ['🐕'], satchel: ['👜'], letter: ['✉'], tap: ['👆'], jump: ['⬆'],
  paw: ['🐾'], star: ['⭐'], skip: ['⏩'], map: ['🗺'], sail: ['⛵'], cloud: ['☁'], sparkle: ['✨'], warning: ['⚠'],
  grab: ['✋'], shell: ['🐚'], coconut: ['🥥'], locket: ['📿'], fish: ['🐟'], log: ['🪵'], oar: [], frond: ['🌿'],
  rope: ['🪢'], key: ['🔑'], crank: ['🔧'], fuse: ['🔋'], bell: ['🔔'], biscuit: ['🦴'], oldkey: ['🗝'], ball: ['🎾'],
  cream: ['🥛'], mitten: ['🧤'], scarf: ['🧣'], sock: ['🧦'], cocoa: ['☕'], wax: ['🥫'], salt: ['🧂'], bolts: ['🔩'],
  coin: ['🪙'], kite: ['🪁'], reel: [], gem: ['💎'], spoon: ['🥄'], lens: ['🔍'], bagel: ['🥯'], pane: ['🪟'],
  portrait: ['🖼'], lever: ['🕹'], doghouse: ['🏠'], look: ['👀'], wave: ['🌊'], note: ['🎵'], mirror: ['🪞'],
  drum: ['🥁'], scroll: ['📜'], door: ['🚪'], sun: ['☀'], bird: ['🐦'], crab: ['🦀'], nest: ['🏡'], bulb: ['💡'],
  leaf: ['🍃'], valve: ['🚰'], canoe: ['🛶'], stone: ['🪦'], clock: ['🕰'], book: ['📖'], flower: ['🌼'], turn: ['🔄'],
  elevator: ['🛗'], parachute: ['🪂'], raccoon: ['🦝'], blossom: ['🌸'], scale: ['⚖'], apple: ['🍎'], gear: ['⚙'],
  sunrise: ['🌅'], gust: ['💨'], raven: ['🐦‍⬛'], pine: ['🌲'], bear: ['🐻'], tree: ['🌳'], orca: ['🐋'], flag: ['🚩'],
  ice: ['🧊'], hockey: ['🏒'], cross: ['✝'], cablecar: ['🚡'], horse: ['🐴'], fire: ['🔥'], squirrel: ['🐿'],
  stairs: ['🪜'], wind: ['🌬'], snow: ['❄'], clothespin: ['🧷'], sled: ['🛷'],
};

const byEmoji = new Map();
for (const [name, list] of Object.entries(ICONS)) for (const e of list) byEmoji.set(e, name);
const escRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
// Longest first so the raven (bird + ZWJ + black square) wins over the bird.
const alts = [...byEmoji.keys()].sort((a, b) => b.length - a.length).map(escRe).join('|');
const RE = new RegExp(`(?:${alts})\\uFE0F?|:([a-z]+):`, 'gu');

export const iconURL = (name) => `./assets/icons/${name}.png`;

/** Icon name for an emoji or ':name:' token, or null. */
export function iconName(s) {
  if (!s) return null;
  const t = /^:([a-z]+):$/.exec(s);
  if (t) return t[1] in ICONS ? t[1] : null;
  return byEmoji.get(s.replace(/️/g, '')) ?? null;
}

const imgTag = (name) => `<img class="gi" src="${iconURL(name)}" alt="" draggable="false">`;

/** Swaps painted icons into an HTML (or plain, already-escaped) string. */
export function iconize(html) {
  return String(html).replace(RE, (m, tok) => {
    const name = tok ? (tok in ICONS ? tok : null) : byEmoji.get(m.replace(/️/g, ''));
    return name ? imgTag(name) : m;
  });
}

// ── Canvas use (3D item badges, puzzle drawings) ─────────────────────────
const images = new Map();
function image(name) {
  if (!images.has(name)) { const im = new Image(); im.src = iconURL(name); images.set(name, im); }
  return images.get(name);
}
/** Starts loading every icon so canvases can draw them synchronously. */
export function preloadIcons() {
  return Promise.all(Object.keys(ICONS).map((n) => image(n).decode?.().catch(() => {})));
}
/**
 * Draws the icon for `s` (emoji or token) centred at cx,cy, `size` px across.
 * Falls back to the emoji glyph; if the image is still loading, `onLate` is
 * called once it arrives so the caller can redraw.
 */
export function drawIcon(g, s, cx, cy, size, onLate) {
  const name = iconName(s);
  const im = name && image(name);
  if (im && im.complete && im.naturalWidth) { g.drawImage(im, cx - size / 2, cy - size / 2, size, size); return true; }
  if (im && onLate) im.addEventListener('load', onLate, { once: true });
  if (s && !s.startsWith(':')) {
    g.save();
    g.font = `${Math.round(size * 0.85)}px "Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(s, cx, cy + size * 0.05);
    g.restore();
  }
  return false;
}

// ── Live DOM swap ────────────────────────────────────────────────────────
const SKIP = new Set(['SCRIPT', 'STYLE', 'TEXTAREA', 'INPUT', 'CODE']);
function swapText(node) {
  const text = node.nodeValue;
  RE.lastIndex = 0;
  if (!text || !RE.test(text)) return;
  const p = node.parentNode;
  if (!p || SKIP.has(p.nodeName)) return;
  const tpl = document.createElement('template');
  tpl.innerHTML = iconize(text.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c])));
  p.replaceChild(tpl.content, node);
}
function sweep(root) {
  if (root.nodeType === Node.TEXT_NODE) { swapText(root); return; }
  if (root.nodeType !== Node.ELEMENT_NODE || SKIP.has(root.nodeName)) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const hits = [];
  for (let n = walker.nextNode(); n; n = walker.nextNode()) hits.push(n);
  hits.forEach(swapText);
}
/** Keeps every emoji under `root` swapped for its painted icon. */
export function watchIcons(root) {
  sweep(root);
  new MutationObserver((list) => {
    for (const m of list) {
      if (m.type === 'characterData') swapText(m.target);
      else m.addedNodes.forEach(sweep);
    }
  }).observe(root, { childList: true, subtree: true, characterData: true });
}

G.icons = { iconize, iconName, drawIcon };
