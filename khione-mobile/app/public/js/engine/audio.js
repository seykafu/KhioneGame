// WebAudio mixer: music with crossfades, one-shot SFX with cheap distance
// attenuation + stereo pan, and looping ambience beds. iOS needs the context
// resumed inside a user gesture, which input.js does on the first touch.
import { G, clamp } from './core.js';
import { hapticForSfx } from './haptics.js';

const BASE = './assets/';
const SFX_FILES = {
  // Bespoke Khione sounds carried over from the Godot project.
  bark: 'bark.mp3', bell_ding: 'bell_ding.mp3', coconut_thunk: 'coconut_thunk.mp3', crab_snip: 'crab_snip.mp3',
  drain: 'drain.mp3', fail: 'fail.mp3', gate_open: 'gate_open.mp3', gull: 'gull.mp3', hiss: 'hiss.mp3', howl: 'howl.mp3',
  hum_high: 'hum_high.wav', hum_low: 'hum_low.wav', hum_mid: 'hum_mid.wav', jump_whoosh: 'jump_whoosh.mp3', land: 'land.mp3',
  meow: 'meow.mp3', paper_close: 'paper_close.mp3', paper_open: 'paper_open.mp3', paw_grass: 'paw_grass.mp3', paw_sand: 'paw_sand.mp3',
  pickup_chime: 'pickup_chime.mp3', robot_flee: 'robot_flee.mp3', robot_whir: 'robot_whir.mp3', splash: 'splash.mp3',
  stone_slide: 'stone_slide.mp3', success: 'success.mp3', swim_stroke: 'swim_stroke.mp3', train_horn: 'train_horn.mp3',
  whimper: 'whimper.mp3', whisker_shimmer: 'whisker_shimmer.mp3', wood_creak: 'wood_creak.mp3',
  // Loops
  ocean_loop: 'ocean_loop.wav', park_birds: 'park_birds.wav', winter_wind: 'winter_wind.wav', brook: 'brook.wav', waterfall: 'waterfall.wav',
  // Whisker Isle PoC sounds
  bonk: 'poc_bonk.mp3', chime: 'poc_chime.mp3', coin: 'poc_coin.mp3', dig: 'poc_dig.mp3', fanfare: 'poc_fanfare.mp3',
  push: 'poc_push.mp3', smash: 'poc_smash.mp3', snap: 'poc_snap.mp3',
  // Generated on Higgsfield for this build
  growl: 'growl.mp3', geese: 'geese.mp3', pigeons: 'pigeons.mp3', snow_dig: 'snow_dig.mp3', big_wave: 'big_wave.mp3',
  cannon: 'cannon.mp3', sled: 'sled.mp3', raccoon: 'raccoon.mp3', parrot: 'parrot.mp3',
};

class Audio {
  constructor() {
    this.ctx = null;
    this.buffers = new Map();
    this.loading = new Map();
    this.musicVol = Number(localStorage.getItem('khione_music') ?? 0.55);
    this.sfxVol = Number(localStorage.getItem('khione_sfx') ?? 0.8);
    this.current = null; // {name, src, gain}
    this.ambience = new Map();
    this.lastPlay = new Map();
    this.wantedMusic = null;
  }

  init() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.connect(this.ctx.destination);
    this.musicBus = this.ctx.createGain(); this.musicBus.gain.value = this.musicVol; this.musicBus.connect(this.master);
    this.sfxBus = this.ctx.createGain(); this.sfxBus.gain.value = this.sfxVol; this.sfxBus.connect(this.master);
    // iOS starts (and, after calls or app switches, restarts) the context
    // asynchronously; music asked for while it was off starts once it's on.
    this.ctx.onstatechange = () => { if (this.ctx.state === 'running') this.resumeMusic(); };
    document.addEventListener('visibilitychange', () => {
      if (!this.ctx) return;
      if (document.hidden) this.ctx.suspend();
      else this.ctx.resume().then(() => this.resumeMusic()).catch(() => {});
    });
  }

  /** Must run inside a user gesture on iOS. */
  unlock() {
    this.init();
    if (!this.ctx) return;
    if (this.ctx.state !== 'running') this.ctx.resume().then(() => this.resumeMusic()).catch(() => {});
    // A silent buffer kicks iOS into actually starting the graph.
    const b = this.ctx.createBuffer(1, 1, 22050);
    const s = this.ctx.createBufferSource(); s.buffer = b; s.connect(this.master); s.start(0);
    this.resumeMusic();
  }

  resumeMusic() {
    if (!this.ctx || this.ctx.state !== 'running' || !this.wantedMusic) return;
    if (this.current?.name === this.wantedMusic && (this.current.src || this.current.loading)) return;
    this.music(this.wantedMusic);
  }

  async buffer(url) {
    if (this.buffers.has(url)) return this.buffers.get(url);
    if (!this.loading.has(url)) {
      this.loading.set(url, (async () => {
        this.init();
        const res = await fetch(url);
        // The native iOS app serves files from capacitor://, which reports status 0.
        if (!res.ok && res.status !== 0) throw new Error(`audio ${url}: ${res.status}`);
        const arr = await res.arrayBuffer();
        const buf = await new Promise((ok, bad) => this.ctx.decodeAudioData(arr, ok, bad));
        this.buffers.set(url, buf);
        return buf;
      })().catch((e) => { console.warn(e.message ?? e); this.loading.delete(url); return null; }));
    }
    return this.loading.get(url);
  }

  preloadSfx(names) {
    for (const n of names) this.buffer(BASE + 'sfx/' + (SFX_FILES[n] ?? `${n}.mp3`));
  }

  /**
   * sfx('meow', {pos, vol, rate, jitter}) — pos fades with distance from the
   * camera focus and pans left/right.
   */
  sfx(name, opts = {}) {
    hapticForSfx(name, opts.pos);
    if (!this.ctx || this.ctx.state !== 'running') return;
    // Unregistered names fall back to assets/sfx/<name>.mp3.
    const file = SFX_FILES[name] ?? `${name}.mp3`;
    const now = this.ctx.currentTime;
    const minGap = opts.minGap ?? 0.04;
    if ((this.lastPlay.get(name) ?? -1) > now - minGap) return;
    this.lastPlay.set(name, now);
    const url = BASE + 'sfx/' + file;
    const play = (buf) => {
      if (!buf) return;
      const src = this.ctx.createBufferSource();
      src.buffer = buf;
      src.playbackRate.value = (opts.rate ?? 1) * (1 + (Math.random() * 2 - 1) * (opts.jitter ?? 0));
      const gain = this.ctx.createGain();
      let vol = opts.vol ?? 1;
      let panNode = null;
      if (opts.pos && G.rig) {
        const dx = opts.pos.x - G.rig.look.x, dz = opts.pos.z - G.rig.look.z;
        const d = Math.sqrt(dx * dx + dz * dz);
        const range = opts.range ?? 24;
        vol *= clamp(1 - (d - 4) / range, 0, 1);
        if (vol <= 0.01) return;
        if (this.ctx.createStereoPanner) {
          const b = G.render.camBasis();
          const side = (dx * b.rx + dz * b.rz) / Math.max(4, d);
          panNode = this.ctx.createStereoPanner();
          panNode.pan.value = clamp(side, -0.8, 0.8);
        }
      }
      gain.gain.value = vol;
      src.connect(gain);
      if (panNode) { gain.connect(panNode); panNode.connect(this.sfxBus); } else gain.connect(this.sfxBus);
      src.start(0, 0, opts.dur);
      return src;
    };
    const cached = this.buffers.get(url);
    if (cached) return play(cached);
    this.buffer(url).then(play);
  }

  /** Crossfade to a music track (file name without extension), or null for silence. */
  async music(name, { fade = 2.0, vol = 1 } = {}) {
    this.wantedMusic = name;
    if (!this.ctx || this.ctx.state !== 'running') return;
    if (this.current?.name === name && (this.current.src || this.current.loading)) return;
    const old = this.current;
    this.current = name ? { name, loading: true } : null;
    if (old?.gain) {
      const g = old.gain.gain;
      g.cancelScheduledValues(this.ctx.currentTime);
      g.setValueAtTime(g.value, this.ctx.currentTime);
      g.linearRampToValueAtTime(0, this.ctx.currentTime + fade);
      old.src.stop(this.ctx.currentTime + fade + 0.05);
    }
    // A decoded track is tens of MB of PCM; keep only the one playing.
    if (old?.name && old.name !== name) {
      const oldUrl = BASE + 'music/' + old.name + '.mp3';
      setTimeout(() => { if (this.current?.name !== old.name) { this.buffers.delete(oldUrl); this.loading.delete(oldUrl); } }, (fade + 0.5) * 1000);
    }
    if (!name) return;
    const buf = await this.buffer(BASE + 'music/' + name + '.mp3');
    if (this.current?.name !== name) return;
    if (!buf) { this.current = null; return; }
    const src = this.ctx.createBufferSource();
    src.buffer = buf; src.loop = true;
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0, this.ctx.currentTime);
    gain.gain.linearRampToValueAtTime(vol, this.ctx.currentTime + fade);
    src.connect(gain); gain.connect(this.musicBus);
    src.start();
    this.current = { name, src, gain };
  }

  /** Duck music under a big moment. */
  duck(amount = 0.3, dur = 2) {
    if (!this.current?.gain || !this.ctx) return;
    const g = this.current.gain.gain, t = this.ctx.currentTime;
    g.cancelScheduledValues(t);
    g.setValueAtTime(g.value, t);
    g.linearRampToValueAtTime(amount, t + 0.3);
    g.linearRampToValueAtTime(1, t + dur);
  }

  /** Start/stop a looping ambience bed by name. */
  async ambient(name, vol = 0.35) {
    if (!this.ctx) return;
    if (this.ambience.has(name)) { this.ambience.get(name).gain.gain.value = vol; return; }
    const buf = await this.buffer(BASE + 'sfx/' + (SFX_FILES[name] ?? `${name}.mp3`));
    if (!buf || this.ambience.has(name)) return;
    const src = this.ctx.createBufferSource(); src.buffer = buf; src.loop = true;
    const gain = this.ctx.createGain(); gain.gain.value = 0;
    gain.gain.linearRampToValueAtTime(vol, this.ctx.currentTime + 1.5);
    src.connect(gain); gain.connect(this.sfxBus); src.start();
    this.ambience.set(name, { src, gain });
  }
  stopAmbient(name) {
    const a = this.ambience.get(name);
    if (!a || !this.ctx) return;
    a.gain.gain.linearRampToValueAtTime(0, this.ctx.currentTime + 1);
    a.src.stop(this.ctx.currentTime + 1.1);
    this.ambience.delete(name);
  }
  stopAllAmbient() { for (const n of [...this.ambience.keys()]) this.stopAmbient(n); }

  setMusicVolume(v) { this.musicVol = v; localStorage.setItem('khione_music', v); if (this.musicBus) this.musicBus.gain.value = v; }
  setSfxVolume(v) { this.sfxVol = v; localStorage.setItem('khione_sfx', v); if (this.sfxBus) this.sfxBus.gain.value = v; }

  /** A tiny synthesized tone — for pitched puzzle notes (bells, stones). */
  tone(freq, { dur = 0.6, type = 'sine', vol = 0.35, attack = 0.01 } = {}) {
    if (!this.ctx || this.ctx.state !== 'running') return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator(); o.type = type; o.frequency.value = freq;
    const o2 = this.ctx.createOscillator(); o2.type = 'sine'; o2.frequency.value = freq * 2.01;
    const g = this.ctx.createGain(); const g2 = this.ctx.createGain(); g2.gain.value = 0.25;
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g); o2.connect(g2); g2.connect(g); g.connect(this.sfxBus);
    o.start(t); o2.start(t); o.stop(t + dur + 0.05); o2.stop(t + dur + 0.05);
  }
}

export const audio = new Audio();
G.audio = audio;
export { SFX_FILES };
