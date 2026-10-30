// Touch-first input. One finger: floating joystick (drag) or tap (quick touch
// → interact with / walk to what was tapped). Two fingers: twist to orbit the
// camera, pinch to zoom. Keyboard + mouse mirror everything for desktop.
import { G, events, clamp } from './core.js';

const JOY_R = 55;          // joystick radius in px (PoC ring)
const TAP_MS = 320;
const TAP_PX = 14;

class Input {
  constructor() {
    this.move = { x: 0, y: 0, mag: 0 }; // screen-space: x right, y down
    this.run = false;
    this.jumpHeld = false;
    this._jumpEdge = false;
    this._actionEdge = false;
    this.enabled = true;
    this.keys = new Set();
    this.pointers = new Map();
    this.joyId = null;
    this.gesture = null;
    this.lastMoveAt = 0;
  }

  init(el, joyEl) {
    this.el = el; this.joyEl = joyEl;
    this.knob = joyEl.querySelector('.knob');
    const opts = { passive: false };
    el.addEventListener('pointerdown', (e) => this.down(e), opts);
    window.addEventListener('pointermove', (e) => this.moveP(e), opts);
    window.addEventListener('pointerup', (e) => this.up(e), opts);
    window.addEventListener('pointercancel', (e) => this.up(e, true), opts);
    el.addEventListener('wheel', (e) => { e.preventDefault(); G.rig.zoomTarget = clamp(G.rig.zoomTarget * (1 + e.deltaY * 0.001), 0.65, 1.7); }, opts);
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    // iOS: stop the page from rubber-banding / double-tap zooming.
    document.addEventListener('gesturestart', (e) => e.preventDefault());
    document.addEventListener('dblclick', (e) => e.preventDefault());
    window.addEventListener('keydown', (e) => this.key(e, true));
    window.addEventListener('keyup', (e) => this.key(e, false));
    window.addEventListener('blur', () => { this.keys.clear(); this.release(); });
    const unlock = () => { G.audio.unlock(); };
    window.addEventListener('pointerdown', unlock, { capture: true });
    window.addEventListener('keydown', unlock, { capture: true });
  }

  down(e) {
    e.preventDefault();
    G.audio.unlock();
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, t: performance.now(), button: e.button });
    try { this.el.setPointerCapture(e.pointerId); } catch {}
    if (this.pointers.size === 2) {
      // Second finger: switch to camera gesture, drop the joystick.
      this.release();
      const [a, b] = [...this.pointers.values()];
      this.gesture = { ang: Math.atan2(b.y - a.y, b.x - a.x), dist: Math.hypot(b.x - a.x, b.y - a.y), yaw: G.rig.yawTarget, zoom: G.rig.zoomTarget };
    }
    if (e.button === 2) this.gesture = { mouse: true, x: e.clientX, yaw: G.rig.yawTarget };
  }

  moveP(e) {
    const p = this.pointers.get(e.pointerId);
    if (!p) return;
    e.preventDefault();
    p.x = e.clientX; p.y = e.clientY;
    if (this.gesture) {
      if (this.gesture.mouse) {
        G.rig.yawTarget = this.gesture.yaw - (p.x - this.gesture.x) * 0.008;
        return;
      }
      if (this.pointers.size >= 2) {
        const [a, b] = [...this.pointers.values()];
        const ang = Math.atan2(b.y - a.y, b.x - a.x);
        const dist = Math.hypot(b.x - a.x, b.y - a.y);
        G.rig.yawTarget = this.gesture.yaw - (ang - this.gesture.ang);
        G.rig.zoomTarget = clamp(this.gesture.zoom * (this.gesture.dist / Math.max(20, dist)), 0.65, 1.7);
      }
      return;
    }
    if (!this.enabled) return;
    const dx = p.x - p.sx, dy = p.y - p.sy;
    if (this.joyId === null && Math.hypot(dx, dy) > 10) {
      this.joyId = e.pointerId;
      this.joyEl.style.display = 'block';
      this.joyEl.style.left = p.sx + 'px';
      this.joyEl.style.top = p.sy + 'px';
      events.emit('joystick');
    }
    if (this.joyId === e.pointerId) {
      const len = Math.hypot(dx, dy);
      const k = len > JOY_R ? JOY_R / len : 1;
      // Let the anchor trail the finger so long drags never "run out of stick".
      if (len > JOY_R * 1.6) { p.sx = p.x - dx * (JOY_R * 1.6) / len; p.sy = p.y - dy * (JOY_R * 1.6) / len; this.joyEl.style.left = p.sx + 'px'; this.joyEl.style.top = p.sy + 'px'; }
      this.knob.style.transform = `translate(${dx * k}px, ${dy * k}px)`;
      const mag = Math.min(1, len / JOY_R);
      this.move.x = (dx / (len || 1)) * mag; this.move.y = (dy / (len || 1)) * mag; this.move.mag = mag;
      this.run = mag > 0.92;
      this.joyEl.classList.toggle('run', this.run);
      this.lastMoveAt = G.time;
    }
  }

  up(e, cancelled = false) {
    const p = this.pointers.get(e.pointerId);
    if (!p) return;
    this.pointers.delete(e.pointerId);
    if (this.gesture) {
      if (this.pointers.size === 0) this.gesture = null;
      return;
    }
    if (this.joyId === e.pointerId) { this.release(); return; }
    const quick = performance.now() - p.t < TAP_MS && Math.hypot(p.x - p.sx, p.y - p.sy) < TAP_PX;
    if (quick && !cancelled && this.enabled) events.emit('tap', { x: p.x, y: p.y });
  }

  release() {
    this.joyId = null;
    this.move.x = this.move.y = this.move.mag = 0;
    this.run = false;
    if (this.joyEl) { this.joyEl.style.display = 'none'; this.knob.style.transform = ''; }
  }

  key(e, down) {
    if (e.target?.tagName === 'INPUT' || e.target?.tagName === 'TEXTAREA') return;
    const c = e.code;
    if (down) this.keys.add(c); else this.keys.delete(c);
    if (!down || e.repeat) {
      if (c === 'Space') this.jumpHeld = down;
      return;
    }
    if (G.ui?.modalOpen && c !== 'Escape') return;
    switch (c) {
      case 'Space': this._jumpEdge = true; this.jumpHeld = true; e.preventDefault(); break;
      case 'KeyE': case 'Enter': this._actionEdge = true; break;
      case 'KeyM': case 'Digit1': events.emit('vocal_btn', 'meow'); break;
      case 'KeyH': case 'Digit2': events.emit('vocal_btn', 'hiss'); break;
      case 'KeyG': case 'Digit3': events.emit('vocal_btn', 'growl'); break;
      case 'KeyO': case 'Digit4': events.emit('oreo_btn'); break;
      case 'KeyJ': case 'Tab': e.preventDefault(); events.emit('open', 'journal'); break;
      case 'KeyI': case 'KeyB': events.emit('open', 'satchel'); break;
      case 'KeyQ': G.rig.yawTarget += Math.PI / 4; break;
      case 'KeyR': G.rig.yawTarget -= Math.PI / 4; break;
      case 'Escape': events.emit('escape'); break;
    }
  }

  /** Called once per frame: merges keyboard into the move vector. */
  poll() {
    if (this.joyId === null) {
      let x = 0, y = 0;
      const k = this.keys;
      if (k.has('KeyA') || k.has('ArrowLeft')) x -= 1;
      if (k.has('KeyD') || k.has('ArrowRight')) x += 1;
      if (k.has('KeyW') || k.has('ArrowUp')) y -= 1;
      if (k.has('KeyS') || k.has('ArrowDown')) y += 1;
      const len = Math.hypot(x, y);
      if (len > 0 && this.enabled) {
        this.move.x = x / len; this.move.y = y / len;
        this.run = k.has('ShiftLeft') || k.has('ShiftRight');
        this.move.mag = this.run ? 1 : 0.7;
        this.lastMoveAt = G.time;
      } else if (this.joyId === null) { this.move.x = this.move.y = this.move.mag = 0; this.run = false; }
    }
    if (!this.enabled) { this.move.x = this.move.y = this.move.mag = 0; }
  }

  pressJump() { this._jumpEdge = true; }
  pressAction() { this._actionEdge = true; }
  takeJump() { const j = this._jumpEdge; this._jumpEdge = false; return j && this.enabled; }
  takeAction() { const a = this._actionEdge; this._actionEdge = false; return a && this.enabled; }
  setEnabled(v) { this.enabled = v; if (!v) this.release(); }
}

export const input = new Input();
G.input = input;
