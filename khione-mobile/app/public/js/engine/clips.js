// Shared animation clips. Khione (from the PoC) and Oreo (rigged on
// Higgsfield) share the same auto-rig bone names, so every clip plays on both.
// Hip translation is rescaled per rig so a clip authored on a taller skeleton
// does not float or sink a shorter one.
import * as THREE from 'three';

let promise = null;

export function sharedClips() {
  if (!promise) {
    promise = fetch('./assets/models/clips.json')
      .then((r) => r.json())
      .then((json) => {
        const clips = {};
        for (const [key, c] of Object.entries(json.clips)) clips[key] = { clip: THREE.AnimationClip.parse(c), hipsY: c.hipsY ?? null };
        return {
          names: Object.keys(clips),
          /** Clips adapted to the given rig root (hip height measured from its bones). */
          forRig(root) {
            let hips = null;
            root.traverse((o) => { if (!hips && o.isBone && /hips/i.test(o.name)) hips = o; });
            const restY = hips ? hips.position.y : null;
            const out = {};
            for (const [key, { clip, hipsY }] of Object.entries(clips)) {
              const c = clip.clone();
              c.tracks = c.tracks.filter((t) => !t.name.endsWith('.scale'));
              for (const t of c.tracks) {
                if (!t.name.endsWith('.position')) continue;
                if (!/hips/i.test(t.name) || restY == null || !hipsY) { t.values = t.values.slice(); continue; }
                const k = restY / hipsY;
                const v = t.values.slice();
                for (let i = 0; i < v.length; i++) v[i] *= k;
                t.values = v;
              }
              // Non-hip bone translations come from the source rig's proportions; drop them.
              c.tracks = c.tracks.filter((t) => !t.name.endsWith('.position') || /hips/i.test(t.name));
              out[key] = c;
            }
            return out;
          },
        };
      });
  }
  return promise;
}
