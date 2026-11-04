// Boot, the frame loop, and travel between islands.
import { G, events, tickTimers, clearTimers } from './core.js';
import { initRender } from './render.js';
import { assets } from './assets.js';
import { audio } from './audio.js';
import { input } from './input.js';
import { fx } from './fx.js';
import { ui } from './ui.js';
import { cine } from './cine.js';
import { state, ISLANDS, islandById, FRAGMENT_TEXT } from './state.js';
import { Player } from './player.js';
import { Oreo } from './oreo.js';
import { sharedClips } from './clips.js';
import { initCloud } from './cloud.js';

const ISLAND_MODULES = {
  ahalo: () => import('../islands/ahalo.js'),
  eaton: () => import('../islands/eaton.js'),
  calgary: () => import('../islands/calgary.js'),
  winnipeg: () => import('../islands/winnipeg.js'),
  montreal: () => import('../islands/montreal.js'),
  englishbay: () => import('../islands/englishbay.js'),
  agrea: () => import('../islands/agrea.js'),
};
const ORDER = ISLANDS.map((i) => i.id);

const TIPS = [
  'Drag anywhere to walk. Push to the rim to run.',
  'Tap something and Khione walks over to it.',
  'Meow near anything curious. Whisker Sense shimmers gold on an honest clue.',
  'Two fingers: twist to turn the camera, pinch to zoom.',
  'Failing is funny, never fatal. Try things!',
  'Your journey saves itself.',
];

class Game {
  async boot() {
    ui.init(document.getElementById('ui'));
    initRender(document.getElementById('game'));
    input.init(document.getElementById('game'), ui.joy);
    fx.init();
    ui.loader('Waking Khione…', TIPS[0]);
    window.addEventListener('error', (e) => console.error(e.error ?? e.message));

    G.game = this;
    G.islandClasses = {};
    await Promise.all([
      assets.preload(['khione', 'oreo'], (p) => ui.progress(p * 0.4)),
      sharedClips(),
      ...ORDER.map(async (id) => {
        try { G.islandClasses[id] = (await ISLAND_MODULES[id]()).default; }
        catch (e) { console.warn(`island ${id} failed to load`, e); }
      }),
    ]);
    G.player = new Player(); await G.player.init();
    G.oreo = new Oreo(); await G.oreo.init();
    audio.preloadSfx(['meow', 'hiss', 'growl', 'bark', 'pickup_chime', 'success', 'jump_whoosh', 'land', 'paw_sand', 'paw_grass', 'splash', 'swim_stroke', 'paper_open', 'paper_close', 'whisker_shimmer', 'fail', 'dig']);

    state.load();
    initCloud();
    this.refreshRiddleCache();
    this.wire();
    this.last = performance.now();
    this.fpsAcc = 0; this.fpsN = 0; this.quality = 0;
    requestAnimationFrame((t) => this.frame(t));
    // Test harness: keep simulating when the tab is hidden (debug only).
    this.lastRaf = performance.now();
    if (G.debug) setInterval(() => { if (performance.now() - this.lastRaf > 250) this.frame(performance.now(), true); }, 50);

    const startId = state.hasSave() ? state.island : 'ahalo';
    await this.loadIsland(startId, { quiet: true });
    ui.hideLoader();
    this.showTitle();
  }

  showTitle() {
    ui.showHUD(false);
    G.player.setControls(false);
    // Slow orbit behind the title.
    const p = G.player.pos.clone();
    G.rig.override = { pos: p.add(new G.THREE.Vector3(0, 0.6, 0)), dist: 14, speed: 0.6 };
    this.titleSpin = true;
    ui.title({
      hasSave: state.hasSave(),
      onContinue: () => this.startPlay(false),
      onNew: () => this.newGame(),
      onRestore: async () => { this.refreshRiddleCache(); await this.loadIsland(state.island); this.startPlay(false); },
    });
  }

  resetCamera() {
    G.rig.override = null;
    G.rig.yawTarget = G.rig.yaw = 36 * Math.PI / 180;
    G.rig.curYaw = G.rig.yawTarget;
    G.rig.zoomTarget = 1;
  }

  async startPlay(first) {
    this.titleSpin = false;
    this.resetCamera();
    ui.showHUD(true);
    G.player.setControls(true);
    audio.music(G.island.music());
    if (!first) ui.toast(`Welcome back to ${G.island.meta.name}.`, '\u{1F43E}');
    if (!state.flag('seen_controls')) { ui.hint.classList.add('on'); state.set('seen_controls'); }
  }

  async newGame() {
    this.titleSpin = false;
    state.wipe();
    state.started = true;
    // Dev: ?island=<id> starts there with every earlier island already done.
    const devIsland = G.params.get('island');
    if (devIsland && ORDER.includes(devIsland)) {
      const n = ORDER.indexOf(devIsland) + 1;
      state._noSave = true;
      state.set('intro_done'); state.set('letter_read');
      for (let i = 1; i < n; i++) { state.set(`island${i}_complete`); state.addFragment(i); }
      if (n > 2) state.learn('hiss');
      if (n > 3) state.oreo = true;
      if (n > 5) state.learn('growl');
      state._noSave = false;
      state.visited = ORDER.slice(0, n);
      state.save();
      this.refreshRiddleCache();
      await this.loadIsland(devIsland, { quiet: true });
      this.resetCamera();
      ui.showHUD(true);
      await this.arrive(true);
      return;
    }
    state.save();
    this.refreshRiddleCache();
    await this.loadIsland('ahalo', { quiet: true });
    this.resetCamera();
    ui.showHUD(true);
    await this.arrive(true);
    if (!state.flag('seen_controls')) { ui.hint.classList.add('on'); state.set('seen_controls'); }
  }

  wire() {
    events.on('tap', ({ x, y }) => {
      if (G.paused || cine.active || ui.modalOpen || !G.island) return;
      G.island.handleTap(x, y);
    });
    events.on('travel', (id) => this.travel(id));
    events.on('to_title', async () => { await ui.fade(true); ui.fade(false); this.showTitle(); });
    events.on('reload_save', async () => { await this.loadIsland(state.island); this.startPlay(false); });
    events.on('ending_closed', () => { ui.showHUD(true); G.player.setControls(true); });
  }

  refreshRiddleCache() {
    G.riddleCache = {};
    for (const [id, Cls] of Object.entries(G.islandClasses)) {
      try { G.riddleCache[id] = new Cls().riddles(); } catch { G.riddleCache[id] = []; }
    }
  }

  async loadIsland(id, { quiet = false } = {}) {
    const Cls = G.islandClasses[id] ?? (await ISLAND_MODULES[id]()).default;
    if (!quiet) await ui.fade(true);
    ui.loader(`Sailing to ${islandById(id).name}…`, TIPS[Math.floor(Math.random() * TIPS.length)]);
    if (G.island) {
      G.riddleCache[G.island.constructor.id] = G.island.riddles();
      G.island.dispose();
      G.island = null;
    }
    clearTimers();
    fx.clear();
    audio.stopAllAmbient();
    G.rig.override = null;
    const isl = new Cls();
    await assets.preload(isl.models(), (p) => ui.progress(p * 0.85));
    audio.preloadSfx(isl.sounds());
    G.render.setAtmosphere(isl.atmosphere());
    G.island = isl;
    const sp = isl.spawn();
    // Oreo's default presence is decided before build() so an island can
    // override it (e.g. show him tangled before he has joined).
    if (state.oreo && !isl.noOreo) { G.oreo.show(sp.x - 1.2, sp.z - 1.2, sp.rotY ?? 0); G.oreo.mode = 'follow'; }
    else G.oreo.hide();
    isl.build();
    G.scene.add(isl.root);
    state.setIsland(id);
    G.player.teleport(sp.x, sp.z, sp.rotY ?? 0, sp.y);
    if (G.oreo.root.visible) G.oreo.teleport(G.oreo.pos.x, G.oreo.pos.z);
    G.rig.look.copy(G.player.pos);
    G.rig.curYaw = G.rig.yawTarget;
    ui.setIsland(isl.meta);
    ui.setGoal(isl.objective());
    ui.progress(1);
    // Let a frame render so the first view isn't blank.
    await new Promise((r) => { requestAnimationFrame(() => requestAnimationFrame(r)); setTimeout(r, 120); });
    ui.hideLoader();
    if (!quiet) await ui.fade(false);
    return isl;
  }

  /** Island card + music + the island's arrival beat. */
  async arrive(first) {
    audio.music(G.island.music());
    G.player.setControls(false);
    await ui.showCard(G.island.meta);
    G.player.setControls(true);
    try { await G.island.onEnter(first); } catch (e) { console.error(e); }
  }

  async travel(id) {
    const first = !state.visited.includes(id);
    await this.loadIsland(id);
    ui.showHUD(true);
    await this.arrive(first);
  }

  /**
   * Called by an island when its exit sequence ends. Awards the letter
   * fragment, marks the island complete, shows the letter, then sails on.
   */
  async finishIsland() {
    const isl = G.island;
    const n = isl.meta.n;
    const firstTime = !state.flag(`island${n}_complete`);
    state.set(`island${n}_complete`);
    if (!state.hasFragment(n)) {
      state.addFragment(n);
      audio.sfx('paper_open');
      const body = ui.panel('A torn piece of the letter', `<p style="text-align:center;font-size:20px"><b>“${FRAGMENT_TEXT[n]}”</b></p>${ui.letterHTML()}`, {
        buttons: [{ label: n < 7 ? 'Sail on ⛵' : 'Close', primary: true, onClick: (close) => close() }],
      });
      await body.done;
    }
    if (firstTime && n < 7) ui.toast('A new pocket in her satchel.', '\u{1F45C}');
    const next = ORDER[n];
    if (next) await this.travel(next);
  }

  ending() { ui.showHUD(false); ui.showEnding(); }

  frame(now, manual = false) {
    if (!manual) { this.lastRaf = performance.now(); requestAnimationFrame((t) => this.frame(t)); }
    const raw = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    if (!G.paused) {
      const dt = raw * (G.timeScale || 1);
      G.dt = dt;
      G.time += dt;
      if (state.started) state.playTime += raw;
      tickTimers();
      input.poll();
      const isl = G.island;
      if (isl) {
        G.player.update(dt);
        G.oreo.update(dt);
        isl._frame(dt);
        try { isl.update(dt); } catch (e) { console.error(e); }
        if (input.takeAction() && !cine.active) isl.useFocus();
        const f = isl.focus;
        ui.setAction(f && !cine.active ? isl.labelOf(f) : null, f?.icon);
        ui.jumpCue(G.player.ledgeAhead());
        this.goalT = (this.goalT ?? 0) - raw;
        if (this.goalT <= 0) { this.goalT = 0.3; ui.setGoal(isl.objective()); }
      }
      if (this.titleSpin && G.rig.override) G.rig.yawTarget += raw * 0.12, G.rig.override.yaw = G.rig.yawTarget;
      fx.update(dt);
      G.render.updateCamera(raw);
    }
    G.renderer.render(G.scene, G.camera);
    ui.updateMarker();
    ui.updateBubbles(G.island);
    if (!manual && !document.hidden) this.adapt(raw);
  }

  /** Drop resolution / shadow quality if the phone is struggling. */
  adapt(raw) {
    this.fpsAcc += raw; this.fpsN++;
    if (this.fpsAcc < 3) return;
    const fps = this.fpsN / this.fpsAcc;
    this.fpsAcc = 0; this.fpsN = 0;
    if (G.debug) ui.devText(`${fps.toFixed(0)} fps  dpr ${G.renderer.getPixelRatio().toFixed(2)}  calls ${G.renderer.info.render.calls}  tris ${(G.renderer.info.render.triangles / 1000).toFixed(0)}k`);
    if (fps < 40 && this.quality < 3) {
      this.quality++;
      if (this.quality === 1) G.renderer.setPixelRatio(Math.min(G.renderer.getPixelRatio(), 1.5));
      if (this.quality === 2) { G.renderer.setPixelRatio(1.2); G.sun.shadow.mapSize.set(512, 512); G.sun.shadow.map?.dispose(); G.sun.shadow.map = null; }
      if (this.quality === 3) { G.renderer.shadowMap.enabled = false; G.scene.traverse((o) => { if (o.material) o.material.needsUpdate = true; }); }
      G.render.resize();
    }
  }
}

export const game = new Game();
