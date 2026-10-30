// Cutscenes. `await G.cine.run(async (c) => { c.look(pos, {dist: 7}); await c.say('…'); })`
// Controls lock, letterbox slides in, and Skip fast-forwards (×8) instead of
// cutting, so every scripted side-effect still happens in order.
import * as THREE from 'three';
import { G, events } from './core.js';

const DEG = Math.PI / 180;

class Cine {
  constructor() { this.active = false; this.skipped = false; }

  async run(fn, { letterbox = true, skippable = true } = {}) {
    if (this.active) { await fn(this); return; } // nested: just run inline
    this.active = true; this.skipped = false;
    G.player?.setControls(false);
    G.ui.setAction(null);
    if (letterbox) G.ui.setCine(true);
    G.ui.skipBtn.style.visibility = skippable ? 'visible' : 'hidden';
    const off = events.on('skip', () => { if (skippable) { this.skipped = true; G.timeScale = 8; } });
    try { await fn(this); }
    catch (e) { console.error('[cine]', e); }
    finally {
      off();
      G.timeScale = 1;
      this.release();
      this.active = false;
      G.ui.setCine(false);
      G.ui.hideSay();
      G.player?.setControls(true);
    }
  }

  /** Point the camera at `pos`. Angles in degrees. */
  look(pos, { dist = 8, pitch, yaw, speed = 2.5 } = {}) {
    G.rig.override = {
      pos: pos.clone ? pos.clone() : new THREE.Vector3(pos.x, pos.y ?? 0, pos.z),
      dist,
      pitch: pitch != null ? pitch * DEG : undefined,
      yaw: yaw != null ? yaw * DEG : undefined,
      speed,
    };
  }
  /** Snap instantly (no ease) — use after a fade. */
  cut(pos, opts = {}) {
    this.look(pos, opts);
    const o = G.rig.override;
    G.rig.look.copy(o.pos);
    G.rig.curDist = o.dist; G.rig.curPitch = o.pitch ?? G.rig.pitch; G.rig.curYaw = o.yaw ?? G.rig.curYaw;
  }
  release() { G.rig.override = null; }
  say(text, opts) { return G.ui.say(text, opts); }
  wait(s) { return G.wait(s); }
  async fade(on, white) { await G.ui.fade(on, white); }
}

export const cine = new Cine();
G.cine = cine;
G.timeScale = 1;
