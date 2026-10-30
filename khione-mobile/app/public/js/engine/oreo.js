// Oreo — the border collie. Joins on Prince's Island (Calgary). Follows,
// stays on command, digs where Khione marks, and always barks back when she
// meows ("If the player meows, he barks back, always, instantly, joyfully").
import * as THREE from 'three';
import { G, events, clamp, damp, angleLerp } from './core.js';
import { model } from './assets.js';
import { sharedClips } from './clips.js';

const RADIUS = 0.36;

export class Oreo {
  constructor() {
    this.root = new THREE.Group();
    this.root.name = 'Oreo';
    this.pos = this.root.position;
    this.vel = new THREE.Vector3();
    this.yaw = 0;
    this.mode = 'hidden';   // hidden | follow | stay | goto | busy
    this.goal = null;
    this.idleT = 0;
    this.root.visible = false;
    this.speedCap = 7.5;
  }

  async init() {
    this.body = model('oreo', { height: 1.12 });
    this.root.add(this.body);
    const blob = new THREE.Mesh(new THREE.CircleGeometry(0.45, 20), new THREE.MeshBasicMaterial({ color: 0x0b2a33, transparent: true, opacity: 0.2, depthWrite: false }));
    blob.rotation.x = -Math.PI / 2; blob.renderOrder = 2;
    this.blob = blob; blob.visible = false;
    G.scene.add(this.root, blob);
    const clips = await sharedClips();
    const ready = () => {
      const inner = this.body.userData.inner;
      if (!inner) return setTimeout(ready, 60);
      this.mixer = new THREE.AnimationMixer(inner);
      this.actions = {};
      for (const [k, c] of Object.entries(clips.forRig(inner))) this.actions[k] = this.mixer.clipAction(c);
      for (const k of ['pickup', 'happy', 'attack']) if (this.actions[k]) { this.actions[k].setLoop(THREE.LoopOnce); this.actions[k].clampWhenFinished = false; }
      this.play('idle');
    };
    ready();
    events.on('vocal', (e) => {
      if (this.mode === 'hidden' || !this.root.visible) return;
      if (e.kind === 'meow' && !this.noBark) setTimeout(() => this.bark(), 260);
    });
  }

  get active() { return this.mode !== 'hidden' && this.root.visible; }

  play(key, fade = 0.2) {
    if (!this.actions) return;
    const next = this.actions[key] ?? this.actions.idle;
    if (!next || this.current === next) return;
    next.reset().setEffectiveWeight(1).fadeIn(fade).play();
    if (this.current) this.current.fadeOut(fade);
    this.current = next;
  }
  oneShot(key, speed = 1) {
    return new Promise((resolve) => {
      const a = this.actions?.[key];
      if (!a) return resolve();
      const prev = this.current;
      a.reset(); a.timeScale = speed; a.fadeIn(0.12).play();
      if (prev && prev !== a) prev.fadeOut(0.12);
      this.current = a;
      setTimeout(() => { this.current = null; this.play('idle'); resolve(); }, (a.getClip().duration / speed) * 1000 - 120);
    });
  }

  show(x, z, yaw = 0) {
    this.root.visible = true; this.blob.visible = true;
    this.teleport(x, z, yaw);
  }
  hide() { this.root.visible = false; this.blob.visible = false; this.mode = 'hidden'; }
  /** Oreo officially joins the journey (persists). */
  join(x, z) {
    if (x != null) this.show(x, z);
    this.mode = 'follow';
    G.state.setOreo(true);
    events.emit('oreo_joined');
  }
  teleport(x, z, yaw = this.yaw) {
    const w = G.island;
    // Land at Khione's level, not on whatever roof happens to be overhead.
    const fromY = G.player ? G.player.pos.y + 0.6 : 99;
    this.pos.set(x, w ? w.groundAt(x, z, fromY) : 0, z);
    this.vel.set(0, 0, 0);
    this.yaw = yaw; this.root.rotation.y = yaw;
  }
  follow() { if (this.mode !== 'hidden') { this.mode = 'follow'; this.goal = null; } }
  stay() { if (this.mode !== 'hidden') { this.mode = 'stay'; this.goal = null; } }

  /** Walk to a point; resolves on arrival (or after a timeout). */
  goTo(p, stop = 0.5, speed = 6) {
    return new Promise((resolve) => {
      // A newer errand supersedes the old one, but the old caller still hears back.
      this.goal?.resolve?.();
      this.mode = 'goto';
      this.goal = { x: p.x, z: p.z, stop, speed, resolve, t: 0 };
    });
  }

  /** She marks, he digs. */
  async dig(p, { times = 2 } = {}) {
    if (!this.active) return false;
    const was = this.mode === 'stay' ? 'stay' : 'follow';
    await this.goTo(p, 0.7, 7.5);
    this.mode = 'busy';
    this.faceTo(p);
    for (let i = 0; i < times; i++) {
      G.audio.sfx(G.island?.digSound ?? 'dig', { pos: this.pos, vol: 0.8 });
      if (G.island?.snowy) G.audio.sfx('snow_dig', { pos: this.pos, vol: 0.8 });
      G.fx.burst(new THREE.Vector3(p.x, this.pos.y + 0.2, p.z), { color: G.island?.dustColor?.(p.x, p.z) ?? '#e8d2a0', count: 18, speed: 3.2, up: 4, size: 0.18, life: 0.8 });
      await this.oneShot('pickup', 1.6);
    }
    this.mode = was;
    return true;
  }

  bark() {
    if (!this.active) return;
    G.audio.sfx('bark', { pos: this.pos, vol: 0.9, jitter: 0.08 });
    G.animate(0.3, (t) => { this.body.position.y = Math.sin(t * Math.PI) * 0.18; }).then(() => { this.body.position.y = 0; });
  }

  faceTo(p) { this.targetYaw = Math.atan2(p.x - this.pos.x, p.z - this.pos.z); }

  update(dt) {
    if (!this.root.visible) return;
    const w = G.island, pl = G.player;
    if (!w || !pl) return;
    let tx = null, tz = null, speed = 0, stop = 1.8;
    if (this.mode === 'follow') {
      const d = Math.hypot(pl.pos.x - this.pos.x, pl.pos.z - this.pos.z);
      if (d > 24) {
        // Lost? He catches up off-screen.
        const b = G.render.camBasis();
        this.teleport(pl.pos.x - b.fx * 2, pl.pos.z - b.fz * 2);
      }
      if (d > 2.4) {
        // Aim for a spot just behind and beside her.
        const ang = pl.yaw + Math.PI + 0.6;
        tx = pl.pos.x + Math.sin(ang) * 1.4; tz = pl.pos.z + Math.cos(ang) * 1.4;
        speed = clamp(d * 1.6, 3.5, this.speedCap);
        stop = 0.6;
      }
    } else if (this.mode === 'goto' && this.goal) {
      const g = this.goal;
      g.t += dt;
      const d = Math.hypot(g.x - this.pos.x, g.z - this.pos.z);
      if (d <= g.stop || g.t > 10) {
        if (g.t > 10) this.teleport(g.x, g.z);
        const r = g.resolve; this.goal = null; this.mode = 'busy'; r();
      } else { tx = g.x; tz = g.z; speed = g.speed; stop = g.stop; }
    }

    let dx = 0, dz = 0;
    if (tx != null) {
      const ex = tx - this.pos.x, ez = tz - this.pos.z, d = Math.hypot(ex, ez);
      if (d > stop) { dx = ex / d; dz = ez / d; }
    }
    const swimming = w.isWater(this.pos.x, this.pos.z) && this.pos.y < w.waterLevel - 0.15;
    const sp = swimming ? Math.min(speed, 3.2) : speed;
    this.vel.x = damp(this.vel.x, dx * sp, 8, dt);
    this.vel.z = damp(this.vel.z, dz * sp, 8, dt);
    this.pos.x += this.vel.x * dt; this.pos.z += this.vel.z * dt;
    w.collide(this.pos, RADIUS, this.pos.y);
    const g = w.groundAt(this.pos.x, this.pos.z, this.pos.y + 0.6);
    if (swimming) this.pos.y = damp(this.pos.y, w.waterLevel - 0.45, 6, dt);
    else this.pos.y = this.pos.y > g + 0.05 ? Math.max(g, this.pos.y - 9 * dt) : g;

    const hs = Math.hypot(this.vel.x, this.vel.z);
    if (hs > 0.4) this.targetYaw = Math.atan2(this.vel.x, this.vel.z);
    else if (this.mode === 'follow' && !this.current?.getClip().name.includes('pick')) this.targetYaw = Math.atan2(pl.pos.x - this.pos.x, pl.pos.z - this.pos.z);
    if (this.targetYaw != null) this.yaw = angleLerp(this.yaw, this.targetYaw, 1 - Math.exp(-8 * dt));
    this.root.rotation.y = this.yaw;

    if (this.mode !== 'busy' || !this.current || this.current === this.actions?.idle || this.current === this.actions?.walk || this.current === this.actions?.run) {
      if (hs > 4.2) { this.play('run'); if (this.actions?.run) this.actions.run.timeScale = clamp(hs / 6, 0.8, 1.3); }
      else if (hs > 0.4) { this.play('walk'); if (this.actions?.walk) this.actions.walk.timeScale = clamp(hs / 2.2, 0.7, 1.6); }
      else this.play('idle');
    }
    this.body.position.y = swimming ? -0.4 : this.body.position.y;
    this.mixer?.update(dt);
    this.blob.position.set(this.pos.x, g + 0.03, this.pos.z);
    this.blob.material.opacity = swimming ? 0 : 0.2;
  }
}
