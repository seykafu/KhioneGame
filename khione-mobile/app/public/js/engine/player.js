// Khione — the player. Movement numbers match the Godot controller
// (walk 4, run 7, swim 3, jump 7.5, gravity 20). Model + clips are the white
// cat from the Whisker Isle PoC.
import * as THREE from 'three';
import { G, events, clamp, damp, angleLerp } from './core.js';
import { model } from './assets.js';
import { sharedClips } from './clips.js';
import { drawIcon } from './icons.js';

const WALK = 4.0, RUN = 7.0, SWIM = 3.0, JUMP = 7.5, GRAV = 20, RADIUS = 0.32;
const SWIM_DEPTH = 0.42;
const VOCAL_FX = {
  meow: { color: '#e9fbff', sfx: 'meow', rate: 1.0 },
  hiss: { color: '#ff8a4a', sfx: 'hiss', rate: 1.0 },
  growl: { color: '#9a7bff', sfx: 'growl', rate: 1.0 },
};

export class Player {
  constructor() {
    this.root = new THREE.Group();
    this.root.name = 'Khione';
    this.pos = this.root.position;
    this.velocity = new THREE.Vector3();
    this.yaw = 0;
    this.grounded = true;
    this.swimming = false;
    this.walk = null;
    this.stepT = 0;
    this.vocalCooldown = 0;
    this.lastSafe = new THREE.Vector3();
    this.frozen = false;
    this.speedMul = 1;
    this.airTime = 0;
  }

  async init() {
    const body = model('khione', { height: 1.0 });
    this.body = body;
    this.root.add(body);
    // Blob shadow keeps her grounded visually even when the sun is low.
    const blob = new THREE.Mesh(new THREE.CircleGeometry(0.42, 20), new THREE.MeshBasicMaterial({ color: 0x0b2a33, transparent: true, opacity: 0.22, depthWrite: false }));
    blob.rotation.x = -Math.PI / 2;
    blob.renderOrder = 2;
    this.blob = blob;
    G.scene.add(blob);
    const clips = await sharedClips();
    const ready = () => {
      const inner = body.userData.inner;
      if (!inner) return setTimeout(ready, 50);
      this.mixer = new THREE.AnimationMixer(inner);
      this.actions = {};
      for (const [k, c] of Object.entries(clips.forRig(inner))) this.actions[k] = this.mixer.clipAction(c);
      for (const k of ['attack', 'pickup', 'happy', 'jump']) {
        if (this.actions[k]) { this.actions[k].setLoop(THREE.LoopOnce); this.actions[k].clampWhenFinished = false; }
      }
      if (this.actions.death) { this.actions.death.setLoop(THREE.LoopOnce); this.actions.death.clampWhenFinished = true; }
      this.play('idle');
    };
    ready();
    G.scene.add(this.root);
    this.itemSprite = makeItemSprite();
    this.itemSprite.visible = false;
    this.root.add(this.itemSprite);
  }

  play(key, fade = 0.2) {
    if (!this.actions) return;
    const next = this.actions[key] ?? this.actions.idle;
    if (!next || this.current === next) return;
    next.reset().setEffectiveWeight(1).fadeIn(fade).play();
    if (this.current) this.current.fadeOut(fade);
    this.current = next;
  }
  oneShot(key, speed = 1.4) {
    const a = this.actions?.[key];
    if (!a) return;
    a.reset(); a.timeScale = speed; a.setEffectiveWeight(1); a.fadeIn(0.08).play();
    const dur = a.getClip().duration / speed;
    setTimeout(() => a.fadeOut(0.15), dur * 700);
  }

  teleport(x, z, rotY = this.yaw, y) {
    const w = G.island;
    this.pos.set(x, y ?? (w ? w.groundAt(x, z, 99) : 0), z);
    this.velocity.set(0, 0, 0);
    this.yaw = rotY; this.root.rotation.y = rotY;
    this.lastSafe.copy(this.pos);
    this.walk = null;
    if (G.rig) G.rig.look.set(x, this.pos.y + 0.6, z);
  }

  faceTo(p) {
    const dx = p.x - this.pos.x, dz = p.z - this.pos.z;
    if (Math.hypot(dx, dz) > 0.05) this.targetYaw = Math.atan2(dx, dz);
  }

  /** Auto-walk (tap-to-move). Joystick input cancels it. */
  walkTo(target, stop = 0.3, cb) {
    this.walk = { x: target.x, z: target.z, stop, cb, t: 0, best: Infinity, stuck: 0 };
  }

  setControls(on) { this.frozen = !on; G.input.setEnabled(on); if (!on) this.walk = null; }

  vocal(kind) {
    if (this.vocalCooldown > 0 || this.frozen) return;
    if (!G.state.knows(kind)) return;
    this.vocalCooldown = 0.55;
    const fx = VOCAL_FX[kind];
    G.audio.sfx(fx.sfx, { jitter: 0.06, vol: 0.9 });
    const at = this.pos.clone();
    G.fx.ripple(at, fx.color, kind === 'meow' ? 6 : 4.5);
    if (kind === 'meow') {
      // Squash-and-stretch chirp.
      G.animate(0.35, (t) => { const s = 1 + Math.sin(t * Math.PI) * 0.12; this.body.scale.set(1 / Math.sqrt(s), s, 1 / Math.sqrt(s)); }).then(() => this.body.scale.set(1, 1, 1));
      G.island?.whiskerSense(at);
    } else {
      this.oneShot('attack', kind === 'growl' ? 1.0 : 1.6);
      G.rig.shake = kind === 'growl' ? 0.6 : 0.25;
    }
    events.emit('vocal', { kind, pos: at });
  }

  /** Plays a one-shot body clip (pickup, happy) and holds locomotion until it ends. */
  async emote(key = 'happy', speed = 1.2) {
    const a = this.actions?.[key];
    if (!a) return;
    this.busyAnim = true;
    const prev = this.current;
    a.reset(); a.timeScale = speed; a.fadeIn(0.12).play();
    if (prev && prev !== a) prev.fadeOut(0.12);
    this.current = a;
    await new Promise((r) => setTimeout(r, (a.getClip().duration / speed) * 1000 - 100));
    this.busyAnim = false;
    this.current = null;
    this.play('idle');
  }

  /** Little "got it!" hold-up of an item icon over her head. */
  showItem(icon, dur = 1.6) {
    const s = this.itemSprite;
    drawItemSprite(s, icon);
    s.visible = true;
    s.position.set(0, 1.45, 0);
    s.scale.set(0.01, 0.01, 0.01);
    G.tween(s.scale, { x: 0.7, y: 0.7, z: 0.7 }, 0.3, (t) => 1 + 2.7 * Math.pow(t - 1, 3) + 1.7 * Math.pow(t - 1, 2));
    clearTimeout(this._itemT);
    this._itemT = setTimeout(() => { s.visible = false; }, dur * 1000);
  }

  /**
   * Is she pushing toward a ledge too high to walk onto but low enough to
   * jump onto? Drives the jump button's glow. Stays true briefly so the cue
   * doesn't flicker while she shuffles along the edge.
   */
  ledgeAhead() {
    const w = G.island, inp = G.input;
    if (!w || this.frozen || this.swimming || !this.grounded || G.cine?.active || inp.move.mag < 0.3) return G.time < (this._ledgeUntil ?? 0);
    const b = G.render.camBasis();
    let dx = b.rx * inp.move.x - b.fx * inp.move.y, dz = b.rz * inp.move.x - b.fz * inp.move.y;
    const l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l;
    // Step along her path the way walking would: ramps and stairs rise a
    // little each step; a ledge is a sudden rise she can't step but can hop.
    const p = this.pos;
    let cur = p.y;
    for (let r = 0.1; r <= 0.95; r += 0.1) {
      const x = p.x + dx * r, z = p.z + dz * r;
      const step = w.groundAt(x, z, cur);
      const hop = w.groundAt(x, z, cur + 1.35);
      const built = step > w.height(x, z) + 0.01;
      const steep = step - cur > 0.13 && !(built && step - cur <= 0.3);
      const ledge = hop - step > 0.3 && hop - p.y <= 1.85;
      // A steep bank only counts if it levels off within jumping height.
      const at = (k) => w.groundAt(p.x + dx * (r + k), p.z + dz * (r + k), p.y + 1.35);
      const bank = steep && at(0.4) - p.y <= 1.85 && at(0.7) - at(0.4) < 0.3;
      if (ledge || bank) { this._ledgeUntil = G.time + 0.6; return true; }
      if (steep) break;
      cur = step;
    }
    return G.time < (this._ledgeUntil ?? 0);
  }

  update(dt) {
    const w = G.island;
    if (!w) return;
    const inp = G.input;
    this.vocalCooldown = Math.max(0, this.vocalCooldown - dt);

    // Desired direction: joystick (camera-relative) or auto-walk.
    let dx = 0, dz = 0, mag = 0;
    if (!this.frozen && inp.move.mag > 0.05) {
      const b = G.render.camBasis();
      dx = b.rx * inp.move.x - b.fx * inp.move.y;
      dz = b.rz * inp.move.x - b.fz * inp.move.y;
      const l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l;
      mag = inp.move.mag;
      if (this.walk) this.walk = null;
    } else if (this.walk) {
      const wk = this.walk;
      const ex = wk.x - this.pos.x, ez = wk.z - this.pos.z, d = Math.hypot(ex, ez);
      wk.t += dt;
      if (d < wk.best - 0.05) { wk.best = d; wk.stuck = 0; } else wk.stuck += dt;
      if (d <= wk.stop) { const cb = wk.cb; this.walk = null; cb?.(); }
      else if (wk.stuck > 1.2 || wk.t > 12) { this.walk = null; }
      else { dx = ex / d; dz = ez / d; mag = d > 5 ? 1 : 0.75; }
    }

    const swimming = w.isWater(this.pos.x, this.pos.z, this.pos.y) && this.pos.y < w.waterLevel - 0.15;
    if (swimming && !this.swimming) { G.audio.sfx('splash', { pos: this.pos, vol: 0.7 }); G.fx.splash(this.pos); }
    this.swimming = swimming;
    const running = mag > 0.92 || (this.walk && mag >= 1);
    const speed = (swimming ? SWIM : (running ? RUN : WALK * Math.min(1, mag / 0.8 + 0.15))) * this.speedMul;
    const accel = this.grounded || swimming ? 12 : 4;
    this.velocity.x = damp(this.velocity.x, dx * speed * (mag > 0 ? 1 : 0), accel, dt);
    this.velocity.z = damp(this.velocity.z, dz * speed * (mag > 0 ? 1 : 0), accel, dt);

    const jump = inp.takeJump() && !this.frozen;
    if (swimming) {
      const target = w.waterLevel - SWIM_DEPTH;
      this.velocity.y = clamp((target - this.pos.y) * 4, -3, 3);
      if (jump || (inp.jumpHeld && !this.frozen)) {
        // Paddle up and out: lets her climb onto shores and low rocks.
        this.velocity.y = 6.2;
        this.pos.y = Math.max(this.pos.y, target + 0.05);
        G.audio.sfx('swim_stroke', { pos: this.pos, vol: 0.6 });
      }
    } else {
      this.velocity.y -= GRAV * dt;
      if (jump && (this.grounded || this.airTime < 0.12)) {
        this.velocity.y = JUMP;
        this.grounded = false;
        this.airTime = 1;
        G.audio.sfx('jump_whoosh', { vol: 0.5, jitter: 0.08 });
        events.emit('jump');
      }
    }

    // Integrate + collide.
    const prevY = this.pos.y;
    const ox = this.pos.x, oz = this.pos.z;
    this.pos.x += this.velocity.x * dt;
    this.pos.z += this.velocity.z * dt;
    w.collide(this.pos, RADIUS, this.pos.y);
    // Terrain steeper than ~50° is a wall: slide along it instead of climbing.
    if (!swimming) {
      const steep = (x, z) => {
        const g = w.groundAt(x, z, this.pos.y);
        const rise = g - this.pos.y;
        if (rise <= 0.015) return false;
        // Low ledges built from solids (curbs, steps, planks) can be stepped onto.
        if (g > w.height(x, z) + 0.01 && rise <= 0.3) return false;
        const run = Math.hypot(x - ox, z - oz);
        return rise > 0.015 + run * 1.1;
      };
      if (steep(this.pos.x, this.pos.z)) {
        // Tap-to-walk hops up ledges it can clear on its own.
        const rise = w.groundAt(this.pos.x, this.pos.z, this.pos.y + 1.3) - this.pos.y;
        if (this.walk && this.grounded && rise < 1.3 && !this.frozen) {
          this.velocity.y = JUMP; this.grounded = false; this.airTime = 1;
          G.audio.sfx('jump_whoosh', { vol: 0.4, jitter: 0.08 });
        }
        if (!steep(this.pos.x, oz)) this.pos.z = oz;
        else if (!steep(ox, this.pos.z)) this.pos.x = ox;
        else { this.pos.x = ox; this.pos.z = oz; }
      }
    }
    this.pos.y += this.velocity.y * dt;
    const ground = w.groundAt(this.pos.x, this.pos.z, Math.max(prevY, this.pos.y));
    if (this.pos.y <= ground) {
      if (!this.grounded && this.velocity.y < -7) { G.audio.sfx('land', { vol: 0.5 }); G.fx.dust(this.pos); }
      this.pos.y = ground;
      if (this.velocity.y < 0) this.velocity.y = 0;
      this.grounded = true;
      this.airTime = 0;
    } else if (!swimming) {
      // Glue to gentle downhill slopes instead of hopping off them.
      if (this.grounded && this.pos.y - ground < 0.35 && this.velocity.y <= 0) { this.pos.y = ground; this.velocity.y = 0; }
      else { this.grounded = false; this.airTime += dt; }
    } else {
      this.grounded = false;
    }
    if (this.grounded && !swimming && !w.isWater(this.pos.x, this.pos.z)) this.lastSafe.copy(this.pos);
    if (this.pos.y < w.waterLevel - 8 || this.pos.y < -30) {
      this.teleport(this.lastSafe.x, this.lastSafe.z);
      G.ui.toast('Whoops! Back on solid ground.', '\u{1F43E}');
    }

    // Facing.
    const hs = Math.hypot(this.velocity.x, this.velocity.z);
    if (hs > 0.4) this.targetYaw = Math.atan2(this.velocity.x, this.velocity.z);
    if (this.targetYaw != null) this.yaw = angleLerp(this.yaw, this.targetYaw, 1 - Math.exp(-12 * dt));
    this.root.rotation.y = this.yaw;

    // Animation.
    if (this.actions && !this.busyAnim) {
      if (swimming && hs > 0.2) {
        this.play('walk'); if (this.actions.walk) this.actions.walk.timeScale = 0.8;
      } else if (hs > 4.6) {
        this.play('run'); if (this.actions.run) this.actions.run.timeScale = clamp(hs / 6.5, 0.8, 1.25);
      } else if (hs > 0.5) {
        this.play('walk'); if (this.actions.walk) this.actions.walk.timeScale = clamp(hs / 2.4, 0.8, 1.7);
      } else this.play('idle');
    }
    // Swimming rides low in the water; airborne tilts a bit.
    this.body.position.y = damp(this.body.position.y, swimming ? -0.35 : 0, 10, dt);
    this.body.rotation.x = damp(this.body.rotation.x, !this.grounded && !swimming ? -0.15 * Math.sign(this.velocity.y) : 0, 8, dt);
    this.mixer?.update(dt);

    // Footsteps.
    if (this.grounded && hs > 1 && !swimming) {
      this.stepT -= dt * (hs / 4);
      if (this.stepT <= 0) {
        this.stepT = 0.3;
        const surf = w.footstep?.(this.pos.x, this.pos.z) ?? 'paw_sand';
        G.audio.sfx(surf, { vol: 0.35, jitter: 0.12, minGap: 0.1 });
        if (surf === 'paw_sand' || surf === 'snow') G.fx.kick(this.pos, w.dustColor?.(this.pos.x, this.pos.z));
      }
    }
    // Blob shadow on the ground under her.
    this.blob.position.set(this.pos.x, ground + 0.03, this.pos.z);
    const air = clamp(1 - (this.pos.y - ground) / 3, 0.3, 1);
    this.blob.scale.setScalar(air);
    this.blob.material.opacity = swimming ? 0 : 0.22 * air;
  }
}

function makeItemSprite() {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true }));
  s.renderOrder = 10;
  s.userData.canvas = c;
  return s;
}
function drawItemSprite(s, icon) {
  const c = s.userData.canvas, g = c.getContext('2d');
  g.clearRect(0, 0, 128, 128);
  g.fillStyle = 'rgba(255,244,220,0.95)'; g.strokeStyle = '#173b44'; g.lineWidth = 7;
  g.beginPath(); g.arc(64, 64, 52, 0, Math.PI * 2); g.fill(); g.stroke();
  drawIcon(g, icon, 64, 64, 78);
  s.material.map.needsUpdate = true;
}
