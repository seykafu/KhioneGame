// Story state + save file. Mirrors the Godot GameState/Inventory autoloads:
// flags, learned vocals, a satchel of 5 pockets (+1 per finished island),
// letter fragments and Oreo artifacts. Every change autosaves.
import { G, events } from './core.js';

// ?slot=name keeps a separate save (handy for testing islands side by side).
const SAVE_KEY = 'khione_save_v1' + (new URLSearchParams(location.search).get('slot') ? `_${new URLSearchParams(location.search).get('slot')}` : '');

export const ISLANDS = [
  { id: 'ahalo', n: 1, name: 'Ahalo', tag: 'The island is listening.' },
  { id: 'eaton', n: 2, name: 'The Eaton Centre', tag: 'Escalators still run. Nobody is home.' },
  { id: 'calgary', n: 3, name: "Prince's Island", tag: 'Golden hour that never quite ends.' },
  { id: 'winnipeg', n: 4, name: 'The Winnipeg Crescent', tag: 'First snow, seen through a tropical cat’s eyes.' },
  { id: 'montreal', n: 5, name: 'Montréal', tag: 'A mountain in red maple, and a cross gone dark.' },
  { id: 'englishbay', n: 6, name: 'English Bay', tag: 'Cherry petals on a wind that never stops.' },
  { id: 'agrea', n: 7, name: 'Agrea', tag: 'The whole journey, in one small place.' },
];
export const islandById = (id) => ISLANDS.find((i) => i.id === id);

// The letter, in reading order. `by` = island number that reveals the piece
// (0 = legible on the bottle from the start). Order of discovery is chosen for
// emotional shape, not sentence order (see the riddle compendium).
export const LETTER = [
  { t: 'Khione,', by: 0, br: true },
  { t: 'If you found this,', by: 6 },
  { t: 'know that you’re', by: 6 },
  { t: 'not supposed to', by: 2 },
  { t: 'be here.', by: 7, br: true },
  { t: 'Could I', by: 3 },
  { t: 'meet you?', by: 4, br: true },
  { t: 'I wish', by: 7 },
  { t: 'for just', by: 7 },
  { t: 'one final', by: 1 },
  { t: 'adventure.', by: 5, br: true },
  { t: 'Love,', by: 7, br: true },
  { t: 'Oreo.', by: 7, sig: true },
];
export const FRAGMENT_TEXT = {
  1: '… one final …',
  2: '… not supposed to …',
  3: 'Could I …',
  4: '… meet you?',
  5: '… adventure.',
  6: 'If you found this … know that …',
  7: 'I wish … … be here. Love,',
};

// Item catalogue. Islands may add more with registerItems().
export const ITEMS = {
  sun_shell: { name: 'Sun Shell', icon: '\u{1F41A}', desc: 'A golden scallop, warm to the touch. Shaped like it was made for something.' },
  coconut: { name: 'Coconut', icon: '\u{1F965}', desc: 'Heavy, hairy, and full of promise. Old wood would tip under a few of these.' },
  rusty_locket: { name: 'Rusty Locket', icon: '\u{1F4FF}', desc: 'Sea-worn bronze from the tide pool. The engraving inside is a pawprint far too big for a cat.' },
  stranded_fish: { name: 'Stranded Fish', icon: '\u{1F41F}', desc: 'Left behind when the pool drained. Somebody out there looks hungry.' },
  old_oar: { name: 'Old Oar', icon: ':oar:', desc: 'Smooth with years of use. Whose paws wore it smooth?' },
  palm_frond: { name: 'Dry Frond', icon: '\u{1F33F}', desc: 'A great dry frond. Practically a sail already.' },
  vine_rope: { name: 'Vine Rope', icon: '\u{1FAA2}', desc: 'Fresh-cut vine, crab-approved. Strong enough to bind timbers.' },
  brass_key: { name: 'Brass Key', icon: '\u{1F511}', desc: 'Small, brass, and important somewhere. The fountain kept it safe for years.' },
  skylight_crank: { name: 'Skylight Crank', icon: '\u{1F527}', desc: 'A well-oiled crank handle, warm from a drummer’s grip. Something above wants turning.' },
  elevator_fuse: { name: 'Elevator Fuse', icon: '\u{1F50B}', desc: 'A fat glass fuse, miraculously intact. The elevator’s call button has been waiting years for this.' },
  brass_clapper: { name: 'Brass Clapper', icon: '\u{1F514}', desc: 'Small, brass, and boat-delivered. Some bell somewhere has been clearing its throat for years.' },
  dog_biscuits: { name: 'Dog Biscuits', icon: '\u{1F9B4}', desc: 'A paper bag of biscuits from the vendor’s corkboard. She does not know why she needs these. Yet.' },
  paw_key: { name: 'Paw-Marked Key', icon: '\u{1F5DD}️', desc: 'A spare key on a nail-worn tag, one paw drawn in marker. It knows exactly which gate it opens.' },
  tennis_ball: { name: 'Chewed Tennis Ball', icon: '\u{1F3BE}', desc: 'Chewed soft, one blue thread in the felt. Buried long ago by somebody who meant to come back for it.' },
  cream_jug: { name: 'Cream Jug', icon: '\u{1F95B}', desc: 'Cold cream, kept perfect in glacier water. A picnicker’s loss is a friendship’s beginning.' },
  frozen_mitten: { name: 'Frozen Mitten', icon: '\u{1F9E4}', desc: 'Stiff as plywood and exactly mitten-shaped. Its clothespin was red.' },
  frozen_scarf: { name: 'Frozen Scarf', icon: '\u{1F9E3}', desc: 'A scarf frozen mid-flutter. Its clothespin was blue.' },
  frozen_sock: { name: 'One Red Sock', icon: '\u{1F9E6}', desc: 'One red sock, solid as a brick. Its clothespin was yellow. Its twin is a mystery for the ages.' },
  cocoa_thermos: { name: 'Cocoa Thermos', icon: '☕', desc: 'Still warm, somehow. Winnipeg hospitality does not freeze.' },
  runner_wax: { name: 'Runner Wax', icon: '\u{1F96B}', desc: 'A flat tin of runner wax, kept safe under the rink ice. Smells like every fast winter ever.' },
  road_salt: { name: 'Road Salt', icon: '\u{1F9C2}', desc: 'A bag of road salt from the postal truck. Ice, meet your negotiator.' },
  runner_bolts: { name: 'Runner Bolts', icon: '\u{1F529}', desc: 'Four runner bolts, rooftop-shiny. Some kid meant to fix the toboggan in spring.' },
  old_loonie: { name: 'Old Loonie', icon: '\u{1FA99}', desc: 'A loonie old enough to remember being lucky. Roof money is the luckiest money.' },
  kite_reel: { name: 'Kite Reel', icon: ':reel:', desc: 'A kite reel with no kite, from a Winnipeg storm cellar. It hums when the wind picks up.' },
};
export function registerItems(map) { Object.assign(ITEMS, map); }
export const itemName = (id) => ITEMS[id]?.name ?? id;
export const itemIcon = (id) => ITEMS[id]?.icon ?? '✨';

class GameState {
  constructor() { this.reset(); }

  reset() {
    this.flags = {};
    this.vocals = ['meow'];
    this.island = 'ahalo';
    this.stacks = [];        // [{id, count}]
    this.fragments = [];     // island numbers, in discovery order
    this.artifacts = [];     // [{id, island, title, text}]
    this.oreo = false;       // has joined
    this.visited = ['ahalo'];
    this.playTime = 0;
    this.started = false;
  }

  // ── flags ──
  flag(name) { return !!this.flags[name]; }
  set(name, value = true) {
    if (!!this.flags[name] === !!value) return;
    this.flags[name] = !!value;
    events.emit('flag', { name, value: !!value });
    this.save();
  }

  // ── vocals ──
  knows(kind) { return this.vocals.includes(kind); }
  learn(kind) {
    if (this.knows(kind)) return;
    this.vocals.push(kind);
    events.emit('learned', kind);
    this.save();
  }

  // ── satchel ──
  get maxSlots() {
    let done = 0;
    for (const isl of ISLANDS) if (this.flags[`island${isl.n}_complete`]) done++;
    return Math.min(10, 5 + done);
  }
  has(id) { return this.stacks.some((s) => s.id === id); }
  count(id) { return this.stacks.find((s) => s.id === id)?.count ?? 0; }
  /** Returns false (and toasts) when the satchel is full. */
  give(id, { quiet = false } = {}) {
    const s = this.stacks.find((x) => x.id === id);
    if (s) s.count++;
    else {
      if (this.stacks.length >= this.maxSlots) {
        if (!quiet) G.ui?.toast('Her satchel is full.', '\u{1F45C}');
        events.emit('satchel_full', id);
        return false;
      }
      this.stacks.push({ id, count: 1 });
    }
    if (!quiet) { G.ui?.toast(`${itemName(id)}`, itemIcon(id), true); G.audio?.sfx('pickup_chime', { vol: 0.7 }); }
    events.emit('inventory', { id, change: 1 });
    this.save();
    return true;
  }
  take(id, n = 1) {
    const i = this.stacks.findIndex((s) => s.id === id);
    if (i < 0) return false;
    this.stacks[i].count -= n;
    if (this.stacks[i].count <= 0) this.stacks.splice(i, 1);
    events.emit('inventory', { id, change: -n });
    this.save();
    return true;
  }

  // ── letter + artifacts ──
  hasFragment(n) { return this.fragments.includes(n); }
  addFragment(n) {
    if (this.hasFragment(n)) return;
    this.fragments.push(n);
    events.emit('fragment', n);
    this.save();
  }
  hasArtifact(id) { return this.artifacts.some((a) => a.id === id); }
  addArtifact(id, island, title, text) {
    if (this.hasArtifact(id)) return;
    this.artifacts.push({ id, island, title, text });
    events.emit('artifact', id);
    G.ui?.toast(`Noted in the journal: ${title}`, '\u{1F43E}');
    this.save();
  }

  setIsland(id) {
    this.island = id;
    if (!this.visited.includes(id)) this.visited.push(id);
    this.save();
  }
  setOreo(v) { this.oreo = v; this.save(); }

  // ── persistence ──
  toJSON() {
    return {
      v: 1, flags: this.flags, vocals: this.vocals, island: this.island, stacks: this.stacks,
      fragments: this.fragments, artifacts: this.artifacts, oreo: this.oreo, visited: this.visited,
      playTime: Math.round(this.playTime), started: this.started,
    };
  }
  save() {
    if (this._noSave) return;
    clearTimeout(this._saveT);
    this._saveT = setTimeout(() => {
      try { localStorage.setItem(SAVE_KEY, JSON.stringify(this.toJSON())); } catch (e) { console.warn('save failed', e); }
      events.emit('saved');
    }, 150);
  }
  hasSave() { try { return !!JSON.parse(localStorage.getItem(SAVE_KEY))?.started; } catch { return false; } }
  load(json) {
    let d = json;
    if (!d) { try { d = JSON.parse(localStorage.getItem(SAVE_KEY)); } catch { d = null; } }
    if (!d) return false;
    this.reset();
    Object.assign(this, {
      flags: d.flags ?? {}, vocals: d.vocals ?? ['meow'], island: d.island ?? 'ahalo', stacks: d.stacks ?? [],
      fragments: d.fragments ?? [], artifacts: d.artifacts ?? [], oreo: !!d.oreo, visited: d.visited ?? ['ahalo'],
      playTime: d.playTime ?? 0, started: !!d.started,
    });
    // Island 5 was the Pirate Ship before it became Montréal.
    const was = (id) => (id === 'pirate' ? 'montreal' : id);
    this.island = was(this.island);
    this.visited = [...new Set(this.visited.map(was))];
    for (const a of this.artifacts) a.island = was(a.island);
    this.stacks = this.stacks.filter((s) => !['mini_putter', 'captains_whistle', 'spigot_wheel'].includes(s.id));
    return true;
  }
  wipe() { localStorage.removeItem(SAVE_KEY); this.reset(); }
  exportCode() { return btoa(unescape(encodeURIComponent(JSON.stringify(this.toJSON())))); }
  importCode(code) {
    try { const d = JSON.parse(decodeURIComponent(escape(atob(code.trim())))); if (!d.v) return false; this.load(d); this.save(); return true; } catch { return false; }
  }
}

export const state = new GameState();
G.state = state;
