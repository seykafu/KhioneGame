import { game } from './engine/game.js';

game.boot().catch((e) => {
  console.error(e);
  const el = document.createElement('div');
  el.style.cssText = 'position:fixed;inset:0;display:flex;align-items:center;justify-content:center;padding:24px;text-align:center;font:700 18px system-ui;color:#173b44;background:#9fe3ee;z-index:99';
  el.textContent = 'Khione could not start on this device. Please reload, or try Safari on iOS 16.4+.';
  document.body.append(el);
});
