// Asset loading: GLB models (meshopt-compressed, from Higgsfield), tiling
// textures, and animation clips. Models are normalized on load so islands
// can ask for "a palm 6m tall" without knowing source units.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/meshopt_decoder.module.js';
import * as SkeletonUtils from 'three/addons/SkeletonUtils.js';
import { G } from './core.js';

const BASE = './assets/';
const loader = new GLTFLoader();
loader.setMeshoptDecoder(MeshoptDecoder);
const texLoader = new THREE.TextureLoader();

const gltfCache = new Map();   // name → Promise<gltf>
const texCache = new Map();

/** Catalog: model name → default facing correction (radians) and notes. */
export const MODELS = {
  khione: { file: 'khione.glb', skinned: true },
  oreo: { file: 'oreo.glb', skinned: true },
  horse: { skinned: true },
  bottle: {}, raft: {}, goose: {}, robot: {}, icecart: {}, canoe: {}, toboggan: {},
  snowman: {}, raccoon: {}, pigeon: {}, gopher: {},
  pole_raven: {}, pole_bear: {}, pole_orca: {}, palm: {}, tree_leafy: {}, tree_pine: {},
  tree_cherry: {}, house_snow: {}, house_westend: {}, crab: {}, mailbox: {}, car: {},
  gull: {}, chest: {}, coconut: {}, shovel: {}, tiki: {},
};

function fileFor(name) {
  return BASE + 'models/' + (MODELS[name]?.file ?? `${name}.glb`);
}

export function loadGLTF(name) {
  if (!gltfCache.has(name)) {
    const p = new Promise((resolve, reject) => {
      loader.load(fileFor(name), resolve, undefined, (e) => reject(new Error(`model ${name}: ${e?.message ?? e}`)));
    }).then((gltf) => {
      gltf.scene.traverse((o) => {
        if (o.isMesh) {
          o.castShadow = true;
          o.receiveShadow = true;
          const m = o.material;
          if (m) {
            m.side = THREE.FrontSide;
            if (m.map) m.map.anisotropy = 4;
            // Generated props come out a little glossy; matte suits the style.
            if ('roughness' in m) { m.roughness = Math.max(m.roughness ?? 1, 0.85); m.metalness = 0; }
          }
        }
      });
      return gltf;
    });
    p.then((g) => { p.__resolved = g; }, () => gltfCache.delete(name));
    gltfCache.set(name, p);
  }
  return gltfCache.get(name);
}

/** Preload a list of model names; reports progress 0..1. Failures are logged, not fatal. */
export async function preload(names, onProgress) {
  let done = 0;
  await Promise.all(names.map((n) =>
    loadGLTF(n).catch((e) => console.warn(e.message)).finally(() => { done++; onProgress?.(done / names.length); })));
}

const box = new THREE.Box3();
const size = new THREE.Vector3();
const center = new THREE.Vector3();

/**
 * A fresh instance of a model, scaled so its largest (or `axis`) extent equals
 * `height` (or `size`), centred on x/z and resting on y=0. Returns a Group;
 * `.userData.inner` is the actual scene clone.
 * Missing models fall back to a soft placeholder so a failed download never
 * breaks a riddle.
 */
export function model(name, { height, size: sz, axis = 'y', rotY = 0, shadow = true, receive = true } = {}) {
  const g = new THREE.Group();
  g.name = name;
  const entry = gltfCache.get(name);
  const settle = (gltf) => {
    const inner = MODELS[name]?.skinned ? SkeletonUtils.clone(gltf.scene) : gltf.scene.clone(true);
    inner.rotation.y = rotY;
    inner.updateMatrixWorld(true);
    box.setFromObject(inner);
    box.getSize(size); box.getCenter(center);
    let s = 1;
    if (height) s = height / (axis === 'x' ? size.x : axis === 'z' ? size.z : size.y);
    else if (sz) s = sz / Math.max(size.x, size.y, size.z);
    inner.scale.multiplyScalar(s);
    inner.position.set(-center.x * s, -box.min.y * s, -center.z * s);
    inner.traverse((o) => { if (o.isMesh) { o.castShadow = shadow; o.receiveShadow = receive; o.userData.shared = true; } });
    g.add(inner);
    g.userData.inner = inner;
    g.userData.size = size.clone().multiplyScalar(s);
    g.userData.gltf = gltf;
  };
  if (entry?.__resolved) {
    // Synchronous when already loaded (islands preload their list first).
    settle(entry.__resolved);
  } else {
    loadGLTF(name).then(settle).catch(() => g.add(placeholder(height ?? sz ?? 1)));
  }
  return g;
}

/** Waits for the given models so model() can build them synchronously. */
export async function ready(names) {
  await Promise.all(names.map((n) => loadGLTF(n).catch((e) => console.warn(e.message))));
}

function placeholder(h) {
  const m = new THREE.Mesh(new THREE.CapsuleGeometry(h * 0.3, h * 0.4, 4, 8), new THREE.MeshLambertMaterial({ color: '#d9c9a8' }));
  m.position.y = h * 0.5;
  return m;
}

/**
 * Instanced copies of a (static) model: one draw call per sub-mesh no matter
 * how many palms. `items` = [{x,y,z, rotY, scale}]; base size via opts.
 */
export function instanced(name, items, opts = {}) {
  const group = new THREE.Group();
  const build = (gltf) => {
    const proto = model(name, opts); // normalized group
    proto.updateMatrixWorld(true);
    const meshes = [];
    proto.traverse((o) => { if (o.isMesh) meshes.push(o); });
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), p = new THREE.Vector3();
    const up = new THREE.Vector3(0, 1, 0);
    for (const mesh of meshes) {
      const im = new THREE.InstancedMesh(mesh.geometry, mesh.material, items.length);
      im.castShadow = opts.shadow ?? true;
      im.receiveShadow = true;
      im.userData.shared = true;
      const local = mesh.matrixWorld.clone();
      items.forEach((it, i) => {
        q.setFromAxisAngle(up, it.rotY ?? 0);
        const sc = it.scale ?? 1;
        s.set(sc, sc * (it.stretch ?? 1), sc);
        p.set(it.x, it.y ?? 0, it.z);
        m4.compose(p, q, s).multiply(local);
        im.setMatrixAt(i, m4);
      });
      im.instanceMatrix.needsUpdate = true;
      im.computeBoundingSphere();
      group.add(im);
    }
  };
  loadGLTF(name).then(build).catch((e) => console.warn(e.message));
  return group;
}

export function texture(name, { repeat = 1, srgb = true } = {}) {
  const key = name;
  if (!texCache.has(key)) {
    const t = texLoader.load(BASE + 'tex/' + name);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.anisotropy = 4;
    if (srgb) t.colorSpace = THREE.SRGBColorSpace;
    texCache.set(key, t);
  }
  const t = texCache.get(key);
  if (repeat !== 1) { const c = t.clone(); c.repeat.set(repeat, repeat); c.needsUpdate = true; return c; }
  return t;
}

let khioneClips = null;
export async function loadKhioneClips() {
  if (khioneClips) return khioneClips;
  const res = await fetch(BASE + 'models/khione_clips.json');
  const json = await res.json();
  khioneClips = json.map((c) => THREE.AnimationClip.parse(c));
  return khioneClips;
}

export const assets = { loadGLTF, preload, model, ready, instanced, texture, loadKhioneClips, MODELS };
G.assets = assets;
