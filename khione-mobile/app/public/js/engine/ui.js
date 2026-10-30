// All DOM UI: HUD, touch buttons, toasts/captions, sheets (satchel, journal,
// settings, puzzle panels), title, loader, island cards, ending.
import { G, events } from './core.js';
import { ISLANDS, LETTER, itemIcon, itemName, ITEMS, islandById } from './state.js';

const h = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const VOX = {
  meow: { icon: '\u{1F431}', label: 'Meow' },
  hiss: { icon: '\u{1F640}', label: 'Hiss' },
  growl: { icon: '\u{1F42F}', label: 'Growl' },
};

class UI {
  init(root) {
    this.root = root;
    root.innerHTML = '';
    // HUD
    this.hud = h('div', 'hud hidden');
    const top = h('div', 'row top');
    const left = h('div', 'chipcol');
    this.menuBtn = h('button', 'chip', '☰'); this.menuBtn.setAttribute('aria-label', 'Menu');
    this.bagBtn = h('button', 'chip', '\u{1F45C}<span class="dot"></span>'); this.bagBtn.setAttribute('aria-label', 'Satchel');
    left.append(this.menuBtn, this.bagBtn);
    this.islandPill = h('div', 'pill island', 'Ahalo');
    const right = h('div', 'chipcol');
    this.letterBtn = h('button', 'pill', '✉️ <span class="num">0/7</span>'); this.letterBtn.setAttribute('aria-label', 'Journal');
    this.letterBtn.style.cursor = 'pointer';
    right.append(this.letterBtn);
    top.append(left, this.islandPill, right);
    this.goal = h('div', 'goal');
    this.hud.append(top, this.goal);
    this.islandPill.style.alignSelf = 'flex-start';

    // Controls
    this.controls = h('div', 'controls hidden');
    this.joy = h('div', 'joy', '<div class="ring"></div><div class="knob"></div>');
    this.hint = h('div', 'hint', '<div class="hand">\u{1F446}</div><div class="hintTxt">Drag to walk · tap things to use them</div>');
    const cl = h('div', 'cluster');
    this.jumpBtn = h('button', 'cbtn jump', '⬆️'); this.jumpBtn.setAttribute('aria-label', 'Jump');
    this.actBtn = h('button', 'cbtn act off', '\u{1F43E}'); this.actBtn.setAttribute('aria-label', 'Interact');
    this.voxBtns = {};
    for (const [k, v] of Object.entries(VOX)) {
      const b = h('button', `cbtn vox ${k}`, `${v.icon}<span>${v.label}</span>`);
      b.setAttribute('aria-label', v.label); b.style.display = 'none';
      this.voxBtns[k] = b; cl.append(b);
    }
    this.oreoBtn = h('button', 'cbtn vox oreo', '\u{1F415}<span>Stay</span>'); this.oreoBtn.style.display = 'none';
    cl.append(this.oreoBtn, this.actBtn, this.jumpBtn);
    this.actLabel = h('div', 'actlabel');
    this.marker = h('div', 'marker', '<div class="arrow">⭐</div>');
    this.controls.append(this.joy, this.hint, cl, this.actLabel, this.marker);

    // Overlays
    this.toasts = h('div', 'toasts');
    this.banner = h('div', 'banner');
    this.badge = h('div', 'badge');
    this.caption = h('div', 'caption', '<div class="line"></div>');
    this.lbT = h('div', 'letterbox t'); this.lbB = h('div', 'letterbox b');
    this.skipBtn = h('button', 'skip', 'Skip ⏩');
    this.card = h('div', 'card');
    this.scrim = h('div', 'scrim');
    this.sheet = h('div', 'sheet');
    this.fadeEl = h('div', 'fade');
    this.ending = h('div', 'ending');
    root.append(this.hud, this.controls, this.toasts, this.banner, this.badge, this.caption, this.lbT, this.lbB, this.skipBtn, this.card, this.scrim, this.sheet, this.ending, this.fadeEl);
    if (G.debug) { this.dev = h('div', 'dev'); root.append(this.dev); }

    // Wiring
    const tap = (el, fn) => {
      el.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); G.audio.unlock(); fn(e); });
    };
    tap(this.jumpBtn, () => { G.input.pressJump(); G.input.jumpHeld = true; });
    this.jumpBtn.addEventListener('pointerup', () => { G.input.jumpHeld = false; });
    this.jumpBtn.addEventListener('pointercancel', () => { G.input.jumpHeld = false; });
    tap(this.actBtn, () => G.input.pressAction());
    for (const [k, b] of Object.entries(this.voxBtns)) tap(b, () => G.player?.vocal(k));
    tap(this.oreoBtn, () => events.emit('oreo_btn'));
    tap(this.menuBtn, () => this.openSettings());
    tap(this.bagBtn, () => this.openSatchel());
    tap(this.letterBtn, () => this.openJournal());
    tap(this.skipBtn, () => events.emit('skip'));
    this.scrim.addEventListener('pointerdown', (e) => { e.preventDefault(); this.closeSheet(); });
    this.goal.setAttribute('data-ui', '');
    tap(this.goal, () => {
      const hint = G.island?.hint?.() ?? G.island?.objective?.();
      if (hint) this.say(hint, { dur: Math.min(8, 2 + hint.length * 0.05) });
    });
    events.on('vocal_btn', (k) => G.player?.vocal(k));
    events.on('oreo_btn', () => this.toggleOreo());
    events.on('open', (w) => w === 'journal' ? this.openJournal() : this.openSatchel());
    events.on('escape', () => { if (this.modalOpen) this.closeSheet(); else this.openSettings(); });
    events.on('learned', () => this.refreshVox());
    events.on('oreo_joined', () => this.refreshVox());
    events.on('inventory', () => this.refreshCounts());
    events.on('fragment', () => this.refreshCounts());
    events.on('joystick', () => { this.hint.classList.remove('on'); });
    this.modalOpen = false;
  }

  // ── HUD state ──────────────────────────────────────────
  showHUD(on = true) { this.hud.classList.toggle('hidden', !on); this.controls.classList.toggle('hidden', !on); }
  setIsland(meta) { this.islandPill.textContent = `${meta.n} · ${meta.name}`; this.refreshCounts(); this.refreshVox(); }
  refreshCounts() {
    const s = G.state;
    this.letterBtn.querySelector('.num').textContent = `${s.fragments.length}/7`;
    const dot = this.bagBtn.querySelector('.dot');
    const n = s.stacks.length;
    dot.textContent = n; dot.classList.toggle('on', n > 0);
  }
  refreshVox() {
    for (const [k, b] of Object.entries(this.voxBtns)) b.style.display = G.state.knows(k) ? 'flex' : 'none';
    const o = G.oreo?.active;
    this.oreoBtn.style.display = o ? 'flex' : 'none';
    this.oreoBtn.querySelector('span').textContent = G.oreo?.mode === 'stay' ? 'Come' : 'Stay';
  }
  toggleOreo() {
    if (!G.oreo?.active) return;
    if (G.oreo.mode === 'stay') { G.oreo.follow(); this.toast('Oreo, come!', '\u{1F415}'); }
    else { G.oreo.stay(); this.toast('Oreo, stay.', '\u{1F415}'); }
    G.oreo.bark();
    this.refreshVox();
    events.emit('oreo_cmd', G.oreo.mode);
  }

  setGoal(text) {
    if (text === this._goal) return;
    this._goal = text;
    this.goal.textContent = text ?? '';
    this.goal.classList.remove('pop'); void this.goal.offsetWidth; this.goal.classList.add('pop');
  }

  setAction(label, icon) {
    const on = !!label;
    this.actBtn.classList.toggle('off', !on);
    this.actBtn.classList.toggle('on', on);
    if (on) { this.actLabel.textContent = label; if (icon && this.actBtn.textContent !== icon) this.actBtn.textContent = icon; }
    this.actLabel.classList.toggle('on', on);
  }

  // ── Messages ───────────────────────────────────────────
  toast(text, icon = '', item = false) {
    const t = h('div', 'toast', `${icon ? `<span class="ico">${icon}</span>` : ''}<span>${esc(text)}</span>`);
    this.toasts.append(t);
    while (this.toasts.children.length > 3) this.toasts.firstChild.remove();
    if (item && icon) G.player?.showItem(icon);
    setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 320); }, 2600);
  }
  showBanner(text, dur = 1.8) {
    this.banner.textContent = text;
    this.banner.classList.add('show');
    clearTimeout(this._bT);
    this._bT = setTimeout(() => this.banner.classList.remove('show'), dur * 1000);
  }
  /** Big celebratory badge — riddle solved, etc. */
  celebrate(title, sub = '') {
    this.badge.innerHTML = `${esc(title)}${sub ? `<small>${esc(sub)}</small>` : ''}`;
    this.badge.classList.add('show');
    G.audio.sfx('success', { vol: 0.9 });
    clearTimeout(this._cT);
    this._cT = setTimeout(() => this.badge.classList.remove('show'), 2200);
  }
  /** Caption line; resolves after it has been shown. */
  say(text, { who = '', dur } = {}) {
    const line = this.caption.querySelector('.line');
    line.innerHTML = `${who ? `<span class="who">${esc(who)}</span>` : ''}${esc(text)}`;
    line.classList.add('show');
    const d = dur ?? Math.min(6, 1.6 + text.length * 0.045);
    clearTimeout(this._sT);
    // A caption cut short by a newer one still resolves, so awaiting
    // cutscenes never hang.
    this._sResolve?.();
    return new Promise((r) => {
      this._sResolve = r;
      this._sT = setTimeout(() => { line.classList.remove('show'); this._sResolve = null; r(); }, d * 1000 / (G.timeScale || 1));
    });
  }
  hideSay() { this.caption.querySelector('.line').classList.remove('show'); }

  setCine(on) { this.root.classList.toggle('cine', on); }

  showCard(meta) {
    this.card.innerHTML = `<div class="k">Island ${meta.n}</div><div class="t">${esc(meta.name)}</div><div class="s">${esc(meta.tag)}</div>`;
    this.card.classList.add('on');
    return new Promise((r) => setTimeout(() => { this.card.classList.remove('on'); setTimeout(r, 400); }, 2600));
  }

  fade(on, white = false) {
    this.fadeEl.classList.toggle('white', white);
    this.fadeEl.classList.toggle('on', on);
    return new Promise((r) => setTimeout(r, 650));
  }

  // ── Hint arrow toward the goal when idle ──────────────
  updateMarker() {
    const isl = G.island;
    const target = isl?.objectiveTarget?.();
    const idle = G.time - (G.input.lastMoveAt || 0) > 14;
    if (!target || !idle || G.cine?.active) { this.marker.classList.remove('on'); return; }
    const v = target.clone().project(G.camera);
    const W = window.innerWidth, H = window.innerHeight;
    let x = (v.x * 0.5 + 0.5) * W, y = (-v.y * 0.5 + 0.5) * H;
    const on = v.z < 1 && x > 20 && x < W - 20 && y > 190 && y < H - 230;
    if (on) { this.marker.style.left = x + 'px'; this.marker.style.top = (y - 40) + 'px'; }
    else {
      // Clamp to the screen edge in the target's direction, clear of the HUD.
      const cx = W / 2, cy = H / 2;
      let dx = x - cx, dy = y - cy; if (v.z > 1) { dx = -dx; dy = -dy; }
      const k = Math.min((W / 2 - 34) / Math.abs(dx || 1), (H / 2 - (dy < 0 ? 180 : 230)) / Math.abs(dy || 1));
      this.marker.style.left = (cx + dx * k) + 'px'; this.marker.style.top = (cy + dy * k) + 'px';
    }
    this.marker.classList.add('on');
  }

  // ── Sheets ─────────────────────────────────────────────
  openSheet(title, body, { tabs, onClose, wide } = {}) {
    this.closeSheet(true);
    this.sheet.innerHTML = '';
    const head = h('div', 'sh-head', `<h2>${esc(title)}</h2>`);
    const x = h('button', 'x', '✕');
    x.addEventListener('click', () => this.closeSheet());
    head.append(x);
    this.sheet.append(head);
    if (tabs) this.sheet.append(tabs);
    const b = h('div', 'sh-body');
    if (typeof body === 'string') b.innerHTML = body; else if (body) b.append(body);
    this.sheet.append(b);
    this.sheet.classList.add('on');
    this.scrim.classList.add('on');
    this.modalOpen = true;
    this._onClose = onClose;
    G.paused = true;
    G.input.release();
    G.audio.sfx('paper_open', { vol: 0.6 });
    return b;
  }
  closeSheet(silent = false) {
    if (!this.modalOpen) return;
    this.sheet.classList.remove('on');
    this.scrim.classList.remove('on');
    this.modalOpen = false;
    G.paused = false;
    const cb = this._onClose; this._onClose = null;
    if (!silent) G.audio.sfx('paper_close', { vol: 0.5 });
    cb?.();
  }

  /**
   * Puzzle close-up panel. Returns the body element; resolves `.done` when closed.
   * buttons: [{label, primary, onClick(close)}]
   */
  panel(title, html, { buttons = [], onClose } = {}) {
    const wrap = h('div', 'pz');
    if (typeof html === 'string') wrap.innerHTML = html; else if (html) wrap.append(html);
    if (buttons.length) {
      const row = h('div', 'btnrow');
      for (const bt of buttons) {
        const b = h('button', `btn ${bt.primary ? 'primary' : 'secondary'} small`, esc(bt.label));
        b.addEventListener('click', () => bt.onClick?.(() => this.closeSheet()));
        row.append(b);
      }
      wrap.append(row);
    }
    let resolve;
    const done = new Promise((r) => { resolve = r; });
    this.openSheet(title, wrap, { onClose: () => { onClose?.(); resolve(); } });
    wrap.done = done;
    return wrap;
  }

  openSatchel() {
    const s = G.state;
    const wrap = h('div');
    const grid = h('div', 'slots');
    const desc = h('div', 'itemdesc', '<span>Tap a pocket to look closer.</span>');
    for (let i = 0; i < s.maxSlots; i++) {
      const st = s.stacks[i];
      const slot = h('button', `slot${st ? '' : ' empty'}`, st ? `${itemIcon(st.id)}${st.count > 1 ? `<span class="cnt">×${st.count}</span>` : ''}` : '');
      if (st) slot.addEventListener('click', () => {
        grid.querySelectorAll('.slot').forEach((x) => x.classList.remove('sel'));
        slot.classList.add('sel');
        desc.innerHTML = `<b>${esc(itemName(st.id))}</b><span>${esc(ITEMS[st.id]?.desc ?? '')}</span>`;
      });
      grid.append(slot);
    }
    wrap.append(grid, desc, h('p', '', `<small>${s.maxSlots} pockets · one more for every island finished.</small>`));
    this.openSheet('Satchel', wrap);
  }

  openJournal(tab = 'letter') {
    const tabs = h('div', 'tabs');
    const body = h('div');
    const views = {
      letter: () => this.letterHTML(),
      islands: () => this.islandsHTML(),
      oreo: () => this.artifactsHTML(),
    };
    const names = { letter: '✉️ Letter', islands: '\u{1F5FA}️ Islands', oreo: '\u{1F43E} Notes' };
    const show = (k) => {
      tabs.querySelectorAll('.tab').forEach((t) => t.classList.toggle('on', t.dataset.k === k));
      body.innerHTML = views[k]();
      body.querySelectorAll('[data-go]').forEach((b) => b.addEventListener('click', () => { this.closeSheet(true); events.emit('travel', b.dataset.go); }));
    };
    for (const k of Object.keys(views)) {
      const t = h('button', 'tab', names[k]); t.dataset.k = k;
      t.addEventListener('click', () => show(k));
      tabs.append(t);
    }
    this.openSheet('Journal', body, { tabs });
    show(tab);
  }
  letterHTML(final = false) {
    const s = G.state;
    const parts = LETTER.map((p) => {
      const known = p.by === 0 || s.hasFragment(p.by) || final;
      if (!known) return `<span class="gap">${'· '.repeat(Math.max(3, Math.round(p.t.length / 2.5)))}</span>${p.br ? '<br>' : ' '}`;
      if (p.sig) return `<span class="sig${final ? '' : ' smudge'}">${esc(p.t)}</span>`;
      return `<span class="${p.by ? 'frag' : ''}">${esc(p.t)}</span>${p.br ? '<br>' : ' '}`;
    }).join('');
    const found = s.fragments.length;
    return `<div class="letter">${parts}</div><p><small>${found ? `${found} of 7 torn pieces recovered.` : 'Most of it is torn away. Somewhere, the rest is waiting.'}</small></p>`;
  }
  islandsHTML() {
    const s = G.state;
    return ISLANDS.map((isl) => {
      const done = s.flag(`island${isl.n}_complete`);
      // The island after the last finished one is always reachable too, in case
      // the app closed between finishing an island and sailing on.
      const unlocked = done || isl.n === 1 || s.flag(`island${isl.n - 1}_complete`);
      const visited = s.visited.includes(isl.id) || unlocked;
      const cur = G.island?.constructor.id === isl.id;
      const riddles = (cur ? G.island.riddles() : (G.riddleCache?.[isl.id] ?? []));
      const list = visited && riddles.length ? `<ul>${riddles.map((r) => `<li class="${r.done ? 'ok' : ''}">${esc(r.done ? r.name : (r.hint ?? r.name))}</li>`).join('')}</ul>` : '';
      const go = unlocked && !cur ? `<button class="btn small secondary go" data-go="${isl.id}">Sail ⛵</button>` : '';
      return `<div class="isl${done ? ' done' : ''}${visited ? '' : ' locked'}"><div class="n">${isl.n}</div><div><h3>${visited ? esc(isl.name) : '???'}${cur ? ' · here' : ''}</h3>${list}</div>${go}</div>`;
    }).join('');
  }
  artifactsHTML() {
    const a = G.state.artifacts;
    if (!a.length) return '<p>Nothing yet. Some things on these islands don’t add up…</p>';
    return a.map((x) => `<div class="art"><b>${esc(x.title)}</b>${esc(x.text)}<br><small>${esc(islandById(x.island)?.name ?? '')}</small></div>`).join('');
  }

  openSettings() {
    const a = G.audio;
    const wrap = h('div');
    wrap.innerHTML = `
      <div class="set">Music<input type="range" min="0" max="1" step="0.05" value="${a.musicVol}" data-k="music"></div>
      <div class="set">Sound effects<input type="range" min="0" max="1" step="0.05" value="${a.sfxVol}" data-k="sfx"></div>
      ${G.haptics?.available ? `<div class="set">Vibration<button class="tg${G.haptics.enabled ? ' on' : ''}" data-a="haptics" aria-label="Vibration"></button></div>` : ''}
      <div class="set">Camera reset<button class="btn small secondary" data-a="cam">Reset view</button></div>
      <div class="set" style="flex-direction:column;align-items:stretch;gap:4px">Cloud code
        <small style="font-weight:700">Your journey backs itself up online. Use this code to continue on another device or after adding Khione to your Home Screen.</small>
        <code style="font:800 17px ui-monospace,monospace;background:#fffaf0;border:3px solid var(--ink);border-radius:12px;padding:6px 10px;text-align:center;user-select:all;-webkit-user-select:all">${esc(G.cloud?.code() ?? '')}</code>
      </div>
      <div class="btnrow">
        <button class="btn small secondary" data-a="copycloud">Copy cloud code</button>
        <button class="btn small secondary" data-a="restore">Restore from code</button>
      </div>
      <div class="btnrow">
        <button class="btn small secondary" data-a="journal">Journal</button>
        <button class="btn small secondary" data-a="stuck">I’m stuck</button>
        <button class="btn small secondary" data-a="title">Title screen</button>
      </div>
      <p><small>Drag anywhere to walk (push to the rim to run). Tap things to walk over and use them. Two fingers: twist to turn the camera, pinch to zoom. Your journey saves automatically.</small></p>`;
    wrap.querySelectorAll('input[type=range]').forEach((r) => r.addEventListener('input', () => {
      if (r.dataset.k === 'music') a.setMusicVolume(Number(r.value)); else a.setSfxVolume(Number(r.value));
    }));
    wrap.querySelector('[data-a=haptics]')?.addEventListener('click', (e) => {
      G.haptics.enabled = !G.haptics.enabled;
      e.currentTarget.classList.toggle('on', G.haptics.enabled);
      G.haptics.impact('medium');
    });
    wrap.querySelector('[data-a=cam]').addEventListener('click', () => { G.rig.yawTarget = 36 * Math.PI / 180; G.rig.zoomTarget = 1; this.closeSheet(); });
    wrap.querySelector('[data-a=journal]').addEventListener('click', () => this.openJournal());
    wrap.querySelector('[data-a=stuck]').addEventListener('click', () => {
      this.closeSheet(true);
      const p = G.player; p.teleport(p.lastSafe.x, p.lastSafe.z);
      const hint = G.island?.hint?.() ?? G.island?.objective?.();
      if (hint) this.say(hint, { dur: 5 });
    });
    wrap.querySelector('[data-a=copycloud]').addEventListener('click', async () => {
      const code = G.cloud.code();
      G.cloud.push({ manual: true });
      try { await navigator.clipboard.writeText(code); this.toast('Cloud code copied.', '☁️'); }
      catch { prompt('Your cloud code:', code); }
    });
    wrap.querySelector('[data-a=restore]').addEventListener('click', () => this.restorePrompt(() => { this.closeSheet(true); events.emit('reload_save'); }));
    wrap.querySelector('[data-a=title]').addEventListener('click', () => { this.closeSheet(true); events.emit('to_title'); });
    this.openSheet('Paused', wrap);
  }

  async restorePrompt(onDone) {
    const code = prompt('Enter your cloud code (looks like kabc123xyz-abcd1234ef):');
    if (!code) return;
    this.toast('Fetching your journey…', '☁️');
    if (await G.cloud.restore(code)) { this.toast('Journey restored!', '✨'); onDone?.(); }
    else this.toast('That code didn’t work (check it, and that you’re online).', '⚠️');
  }

  // ── Loader / title / ending ───────────────────────────
  loader(title = 'Loading the island…', tip = '') {
    if (!this.loaderEl) {
      this.loaderEl = h('div', 'loader', '<div class="ltitle"></div><div class="lbar"><div class="lfill"></div></div><div class="ltip"></div>');
      this.root.append(this.loaderEl);
    }
    this.loaderEl.classList.remove('off');
    this.loaderEl.querySelector('.ltitle').textContent = title;
    this.loaderEl.querySelector('.ltip').textContent = tip;
    this.progress(0);
  }
  progress(p) { if (this.loaderEl) this.loaderEl.querySelector('.lfill').style.width = `${Math.round(p * 100)}%`; }
  hideLoader() { this.loaderEl?.classList.add('off'); }

  title({ hasSave, onContinue, onNew, onRestore }) {
    const el = h('div', 'title');
    const standalone = window.navigator.standalone || matchMedia('(display-mode: standalone)').matches
      || matchMedia('(display-mode: fullscreen)').matches || !!window.Capacitor;
    const ios = /iPhone|iPad|iPod/.test(navigator.userAgent);
    el.innerHTML = `
      <div><div class="logo">Khione</div><div class="sub">a small white cat · a message in a bottle · seven islands</div></div>
      <div class="menu">
        ${hasSave ? '<button class="btn primary" data-a="cont">Continue</button>' : ''}
        <button class="btn ${hasSave ? 'secondary' : 'primary'}" data-a="new">${hasSave ? 'New Journey' : 'Begin'}</button>
        ${!hasSave ? '<button class="btn small secondary" data-a="restore">I have a cloud code</button>' : ''}
        ${ios && !standalone ? '<div class="a2hs">Tip: tap Share → “Add to Home Screen” to play full-screen like an app.</div>' : ''}
      </div>`;
    el.querySelector('[data-a=restore]')?.addEventListener('click', () => {
      G.audio.unlock();
      this.restorePrompt(() => { el.classList.add('off'); setTimeout(() => el.remove(), 500); onRestore?.(); });
    });
    el.querySelector('[data-a=cont]')?.addEventListener('click', () => { G.audio.unlock(); el.classList.add('off'); setTimeout(() => el.remove(), 500); onContinue(); });
    el.querySelector('[data-a=new]').addEventListener('click', () => {
      G.audio.unlock();
      if (hasSave && !confirm('Start a new journey? Your current progress will be replaced.')) return;
      el.classList.add('off'); setTimeout(() => el.remove(), 500); onNew();
    });
    this.root.append(el);
    return el;
  }

  showEnding() {
    this.ending.innerHTML = `<h1>Khione</h1>${this.letterHTML(true)}<p><b>Thank you for playing.</b><br>Made with love for a white Persian cat and a border collie with one blue eye.</p><button class="btn primary" data-a="t">Keep exploring</button>`;
    this.ending.classList.add('on');
    this.ending.querySelector('[data-a=t]').addEventListener('click', () => { this.ending.classList.remove('on'); events.emit('ending_closed'); });
  }

  devText(t) { if (this.dev) this.dev.textContent = t; }
}

export const ui = new UI();
G.ui = ui;
