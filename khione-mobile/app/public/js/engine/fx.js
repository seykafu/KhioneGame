// Particles (one pooled Points draw call), expanding ripple rings for the
// vocal verbs, sparkles for Whisker Sense, and ambient weather emitters.
import * as THREE from 'three';
import { G } from './core.js';

const MAX = 900;

class FX {
  init() {
    const geo = new THREE.BufferGeometry();
    this.pos = new Float32Array(MAX * 3);
    this.col = new Float32Array(MAX * 3);
    this.size = new Float32Array(MAX);
    this.alpha = new Float32Array(MAX);
    this.shape = new Float32Array(MAX);
    geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    geo.setAttribute('shape', new THREE.BufferAttribute(this.shape, 1));
    geo.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e5);
    const mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false,
      uniforms: { uScale: { value: window.innerHeight * 0.6 } },
      vertexShader: /* glsl */`
        attribute float size; attribute float alpha; attribute vec3 color; attribute float shape;
        varying vec3 vC; varying float vA; varying float vS; uniform float uScale;
        void main(){ vC = color; vA = alpha; vS = shape;
          vec4 mv = modelViewMatrix * vec4(position,1.0);
          gl_PointSize = size * uScale / -mv.z;
          gl_Position = projectionMatrix * mv; }`,
      fragmentShader: /* glsl */`
        varying vec3 vC; varying float vA; varying float vS;
        void main(){
          vec2 p = gl_PointCoord - 0.5;
          float a;
          if (vS > 1.5) { // petal: squashed ellipse
            vec2 q = vec2(p.x*1.0, p.y*1.9); a = smoothstep(0.5, 0.35, length(q));
          } else if (vS > 0.5) { // sparkle: 4-point star
            float s = max(0.0, 0.06 - abs(p.x)*abs(p.y)*1.6) / 0.06;
            a = clamp(s * smoothstep(0.5, 0.0, length(p)) * 1.6, 0.0, 1.0);
          } else { a = smoothstep(0.5, 0.3, length(p)); }
          if (a * vA < 0.01) discard;
          gl_FragColor = vec4(vC, a * vA);
          #include <colorspace_fragment>
        }`,
    });
    this.points = new THREE.Points(geo, mat);
    this.points.frustumCulled = false;
    this.points.renderOrder = 5;
    G.scene.add(this.points);
    this.parts = [];
    for (let i = 0; i < MAX; i++) { this.parts.push({ life: 0 }); this.alpha[i] = 0; }
    this.cursor = 0;
    this.rings = [];
    this.weather = null;
    this.tmpC = new THREE.Color();
    window.addEventListener('resize', () => { mat.uniforms.uScale.value = window.innerHeight * 0.6; });
  }

  spawn(x, y, z, o) {
    const i = this.cursor; this.cursor = (this.cursor + 1) % MAX;
    const p = this.parts[i];
    p.x = x; p.y = y; p.z = z;
    p.vx = o.vx ?? 0; p.vy = o.vy ?? 0; p.vz = o.vz ?? 0;
    p.life = p.max = o.life ?? 1;
    p.g = o.gravity ?? 6; p.drag = o.drag ?? 1.5;
    p.size = o.size ?? 0.2; p.grow = o.grow ?? 0;
    p.sway = o.sway ?? 0; p.phase = Math.random() * 6.28;
    p.floor = o.floor ?? -1e9;
    this.tmpC.set(o.color ?? '#ffffff');
    this.col[i * 3] = this.tmpC.r; this.col[i * 3 + 1] = this.tmpC.g; this.col[i * 3 + 2] = this.tmpC.b;
    this.shape[i] = o.shape ?? 0;
    this.points.geometry.attributes.shape.needsUpdate = true;
    this.points.geometry.attributes.color.needsUpdate = true;
    return p;
  }

  /** Radial burst. */
  burst(at, { color = '#fff', count = 14, speed = 3, up = 3, size = 0.2, life = 0.9, gravity = 8, shape = 0, spread = 1 } = {}) {
    const cols = Array.isArray(color) ? color : [color];
    for (let k = 0; k < count; k++) {
      const a = Math.random() * Math.PI * 2, s = speed * (0.4 + Math.random() * 0.6) * spread;
      this.spawn(at.x, at.y, at.z, { vx: Math.cos(a) * s, vz: Math.sin(a) * s, vy: up * (0.5 + Math.random() * 0.7), color: cols[k % cols.length], size: size * (0.6 + Math.random() * 0.8), life: life * (0.6 + Math.random() * 0.6), gravity, shape });
    }
  }
  dust(at) { this.burst({ x: at.x, y: at.y + 0.05, z: at.z }, { color: '#f0e2c0', count: 8, speed: 1.6, up: 1.2, size: 0.25, life: 0.5, gravity: 2 }); }
  kick(at, color = '#e8d2a0') { this.burst({ x: at.x, y: at.y + 0.03, z: at.z }, { color, count: 2, speed: 0.8, up: 1.0, size: 0.12, life: 0.35, gravity: 6 }); }
  splash(at) { this.burst({ x: at.x, y: (G.island?.waterLevel ?? 0) + 0.05, z: at.z }, { color: ['#ffffff', '#bff3fb'], count: 18, speed: 2.4, up: 4, size: 0.2, life: 0.7, gravity: 12 }); }
  confetti(at, n = 60) { this.burst(at, { color: ['#ff6b4a', '#ffc93c', '#1fb5c9', '#7bd88f', '#ff9ad5', '#ffffff'], count: n, speed: 4, up: 7, size: 0.22, life: 2.2, gravity: 6, shape: 2 }); }
  sparkle(at, color = '#ffe48a', n = 10) { this.burst(at, { color, count: n, speed: 1.2, up: 1.6, size: 0.42, life: 1.0, gravity: -0.5, shape: 1 }); }

  /** Whisker Sense shimmer: cool white, or warm gold on an honest clue. */
  shimmer(at, warm = false) {
    this.sparkle(at, warm ? ['#ffd24a', '#ffb43c', '#fff2b0'] : ['#e9fbff', '#bdf2ff', '#ffffff'], warm ? 16 : 9);
    this.ring(at, warm ? '#ffd24a' : '#e9fbff', 1.4, 0.7, at.y);
    if (warm) G.audio.sfx('whisker_shimmer', { pos: at, vol: 0.45 });
  }

  /** Expanding ground ring (vocal ripple / markers). */
  ripple(at, color = '#e9fbff', radius = 6) { this.ring(at, color, radius, 0.9, at.y + 0.08); }
  ring(at, color, radius, dur = 0.9, y = at.y) {
    const geo = new THREE.RingGeometry(0.86, 1, 48);
    geo.rotateX(-Math.PI / 2);
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.85, depthWrite: false, side: THREE.DoubleSide }));
    m.position.set(at.x, y, at.z);
    m.renderOrder = 4;
    G.scene.add(m);
    this.rings.push({ m, t: 0, dur, radius });
  }
  tapMark(at, onThing) { this.ring(at, onThing ? '#ffc93c' : '#ffffff', 0.7, 0.45, at.y + 0.05); }

  /** Continuous weather around the camera focus: 'snow' | 'petals' | 'fluff' | 'confetti' | null */
  setWeather(kind, opts = {}) { this.weather = kind ? { kind, rate: opts.rate ?? 40, wind: opts.wind ?? [0.6, 0], acc: 0, ...opts } : null; }

  update(dt) {
    const w = this.weather;
    if (w && G.rig) {
      const strength = w.strength ?? 1;
      w.acc += dt * w.rate * strength;
      const c = G.rig.look;
      while (w.acc >= 1) {
        w.acc -= 1;
        const x = c.x + (Math.random() - 0.5) * 34, z = c.z + (Math.random() - 0.5) * 34;
        if (w.kind === 'snow') this.spawn(x, c.y + 10 + Math.random() * 4, z, { vx: w.wind[0], vz: w.wind[1], vy: -1.4, gravity: 0, drag: 0, size: 0.12 + Math.random() * 0.1, life: 9, color: '#ffffff', sway: 0.6, floor: (G.island?.height(x, z) ?? 0) });
        else if (w.kind === 'petals') this.spawn(x, c.y + 6 + Math.random() * 5, z, { vx: w.wind[0] * (1 + Math.random()), vz: w.wind[1], vy: -0.7, gravity: 0, drag: 0, size: 0.16 + Math.random() * 0.08, life: 10, color: Math.random() < 0.5 ? '#ffc2d6' : '#ffd9e6', sway: 1.2, shape: 2, floor: (G.island?.height(x, z) ?? 0) });
        else if (w.kind === 'fluff') this.spawn(x, c.y + 1 + Math.random() * 6, z, { vx: w.wind[0] * (0.6 + Math.random()), vz: w.wind[1], vy: 0.1, gravity: -0.05, drag: 0, size: 0.1 + Math.random() * 0.08, life: 8, color: '#fffdf2', sway: 0.9 });
      }
    }
    const P = this.parts;
    for (let i = 0; i < MAX; i++) {
      const p = P[i];
      if (p.life <= 0) { if (this.alpha[i] !== 0) this.alpha[i] = 0; continue; }
      p.life -= dt;
      const k = Math.exp(-p.drag * dt);
      p.vx *= k; p.vz *= k; p.vy = p.vy * k - p.g * dt;
      p.x += p.vx * dt + (p.sway ? Math.sin(G.time * 2 + p.phase) * p.sway * dt : 0);
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      if (p.y < p.floor) { p.y = p.floor; p.vy = 0; p.vx *= 0.5; p.vz *= 0.5; if (p.life > 1.2) p.life = 1.2; }
      this.pos[i * 3] = p.x; this.pos[i * 3 + 1] = p.y; this.pos[i * 3 + 2] = p.z;
      const t = p.life / p.max;
      this.alpha[i] = Math.min(1, t * 3) * (p.max > 3 ? Math.min(1, (p.max - p.life) * 2) : 1);
      this.size[i] = p.size * (1 + p.grow * (1 - t));
    }
    const a = this.points.geometry.attributes;
    a.position.needsUpdate = true; a.alpha.needsUpdate = true; a.size.needsUpdate = true;

    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i];
      r.t += dt;
      const t = Math.min(1, r.t / r.dur);
      const s = 0.3 + r.radius * (1 - Math.pow(1 - t, 3));
      r.m.scale.set(s, 1, s);
      r.m.material.opacity = 0.85 * (1 - t);
      if (t >= 1) { r.m.removeFromParent(); r.m.geometry.dispose(); r.m.material.dispose(); this.rings.splice(i, 1); }
    }
  }

  clear() {
    for (const p of this.parts) p.life = 0;
    this.weather = null;
  }
}

export const fx = new FX();
G.fx = fx;
