// Renderer, lights, sky/fog, and the follow camera. Camera framing comes from
// the Whisker Isle PoC: dist 10.5, pitch 48°, yaw 36°, vfov 46°, look-ahead 1.2.
import * as THREE from 'three';
import { G, damp, clamp, angleLerp } from './core.js';

const DEG = Math.PI / 180;

export function initRender(container) {
  const isMobile = matchMedia('(pointer: coarse)').matches;
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance', alpha: false });
  const maxDpr = G.params.get('dpr') ? Number(G.params.get('dpr')) : (isMobile ? 2 : 1.75);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, maxDpr));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#9fe3ee');
  scene.fog = new THREE.Fog('#9fe3ee', 38, 95);

  const hemi = new THREE.HemisphereLight('#fff4dc', '#5a7a6a', 1.25);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight('#fff1d6', 2.4);
  sun.castShadow = true;
  sun.shadow.mapSize.set(isMobile ? 1024 : 2048, isMobile ? 1024 : 2048);
  const sc = sun.shadow.camera;
  sc.left = -18; sc.right = 18; sc.top = 18; sc.bottom = -18; sc.near = 1; sc.far = 80;
  sun.shadow.bias = -0.0006;
  sun.shadow.normalBias = 0.03;
  scene.add(sun, sun.target);
  const sunOffset = new THREE.Vector3(14, 26, 10);

  const camera = new THREE.PerspectiveCamera(46, 1, 0.3, 260);

  const rig = {
    yaw: 36 * DEG, pitch: 48 * DEG, dist: G.params.get('dist') ? Number(G.params.get('dist')) : 12.5, zoom: 1,
    target: new THREE.Vector3(), look: new THREE.Vector3(),
    lead: 1.2, follow: 1,
    yawTarget: 36 * DEG, zoomTarget: 1,
    // Cutscene override: {pos: Vector3 (look target), dist, pitch, yaw}
    override: null,
    shake: 0,
  };

  function resize() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    // Portrait phones see a narrow slice; widen vertical FOV a touch so the
    // iso frame still shows ~the PoC's playfield width.
    camera.fov = w < h ? 52 : 46;
    camera.updateProjectionMatrix();
  }
  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', () => setTimeout(resize, 120));
  resize();

  const tmp = new THREE.Vector3();
  function updateCamera(dt) {
    const p = G.player;
    let tx, ty, tz, dist = rig.dist * rig.zoom, pitch = rig.pitch, yaw = rig.yaw;
    rig.yaw = angleLerp(rig.yaw, rig.yawTarget, 1 - Math.exp(-8 * dt));
    rig.zoom = damp(rig.zoom, rig.zoomTarget, 8, dt);
    if (rig.override) {
      const o = rig.override;
      tx = o.pos.x; ty = o.pos.y; tz = o.pos.z;
      dist = o.dist ?? dist; pitch = o.pitch ?? pitch; yaw = o.yaw ?? yaw;
      const k = 1 - Math.exp(-(o.speed ?? 3) * dt);
      rig.look.lerp(tmp.set(tx, ty, tz), k);
      rig.curDist = damp(rig.curDist ?? dist, dist, o.speed ?? 3, dt);
      rig.curPitch = damp(rig.curPitch ?? pitch, pitch, o.speed ?? 3, dt);
      rig.curYaw = angleLerp(rig.curYaw ?? yaw, yaw, k);
    } else if (p) {
      const v = p.velocity;
      tx = p.pos.x + v.x * 0.12 * rig.lead;
      ty = p.pos.y + 0.6;
      tz = p.pos.z + v.z * 0.12 * rig.lead;
      rig.look.x = damp(rig.look.x, tx, 6 * rig.follow, dt);
      rig.look.y = damp(rig.look.y, ty, 4 * rig.follow, dt);
      rig.look.z = damp(rig.look.z, tz, 6 * rig.follow, dt);
      rig.curDist = damp(rig.curDist ?? dist, dist, 5, dt);
      rig.curPitch = damp(rig.curPitch ?? pitch, pitch, 5, dt);
      rig.curYaw = angleLerp(rig.curYaw ?? yaw, yaw, 1 - Math.exp(-10 * dt));
    }
    const d = rig.curDist ?? dist, pi = rig.curPitch ?? pitch, ya = rig.curYaw ?? yaw;
    camera.position.set(
      rig.look.x + Math.sin(ya) * Math.cos(pi) * d,
      rig.look.y + Math.sin(pi) * d,
      rig.look.z + Math.cos(ya) * Math.cos(pi) * d,
    );
    if (rig.shake > 0) {
      rig.shake = Math.max(0, rig.shake - dt * 2);
      const s = rig.shake * 0.25;
      camera.position.x += (Math.random() - 0.5) * s;
      camera.position.y += (Math.random() - 0.5) * s;
    }
    camera.lookAt(rig.look);
    // Shadow frustum rides along with the view centre.
    sun.target.position.copy(rig.look);
    sun.position.copy(rig.look).add(sunOffset);
  }

  /** World-space forward/right on the ground plane for camera-relative input. */
  function camBasis() {
    const yaw = rig.curYaw ?? rig.yaw;
    return {
      fx: -Math.sin(yaw), fz: -Math.cos(yaw),
      rx: Math.cos(yaw), rz: -Math.sin(yaw),
    };
  }

  function setAtmosphere(a = {}) {
    const fog = new THREE.Color(a.fog ?? '#9fe3ee');
    scene.background = new THREE.Color(a.sky ?? a.fog ?? '#9fe3ee');
    scene.fog.color.copy(fog);
    scene.fog.near = a.fogNear ?? 38;
    scene.fog.far = a.fogFar ?? 95;
    hemi.color.set(a.skyLight ?? '#fff4dc');
    hemi.groundColor.set(a.groundLight ?? '#5a7a6a');
    hemi.intensity = a.hemi ?? 1.25;
    sun.color.set(a.sun ?? '#fff1d6');
    sun.intensity = a.sunIntensity ?? 2.4;
    if (a.sunDir) sunOffset.set(...a.sunDir).normalize().multiplyScalar(32);
    else sunOffset.set(14, 26, 10);
    renderer.toneMappingExposure = a.exposure ?? 1.05;
    document.body.style.background = scene.background.getStyle();
  }

  G.renderer = renderer; G.scene = scene; G.camera = camera; G.rig = rig;
  G.sun = sun; G.hemi = hemi;
  G.render = { resize, updateCamera, camBasis, setAtmosphere, isMobile };
  return G.render;
}

// ── Water ────────────────────────────────────────────────
// Two-tone blobby sea like the PoC, with a foam band where it meets land.
export function makeWaterMaterial(opts = {}) {
  const uniforms = THREE.UniformsUtils.merge([
    THREE.UniformsLib.fog,
    {
      uTime: { value: 0 },
      uDeep: { value: new THREE.Color(opts.deep ?? '#13a8c8') },
      uLight: { value: new THREE.Color(opts.light ?? '#5fd8e8') },
      uFoam: { value: new THREE.Color(opts.foam ?? '#e9fbff') },
      uOpacity: { value: opts.opacity ?? 0.92 },
      uScale: { value: opts.scale ?? 0.07 },
    },
  ]);
  const mat = new THREE.ShaderMaterial({
    uniforms,
    transparent: true,
    fog: true,
    depthWrite: false,
    vertexShader: /* glsl */`
      varying vec3 vW;
      varying float vShore;
      attribute float shore;
      #include <fog_pars_vertex>
      void main(){
        vec4 wp = modelMatrix * vec4(position,1.0);
        vW = wp.xyz;
        vShore = shore;
        vec4 mvPosition = viewMatrix * wp;
        gl_Position = projectionMatrix * mvPosition;
        #include <fog_vertex>
      }`,
    fragmentShader: /* glsl */`
      uniform float uTime; uniform vec3 uDeep; uniform vec3 uLight; uniform vec3 uFoam;
      uniform float uOpacity; uniform float uScale;
      varying vec3 vW; varying float vShore;
      #include <fog_pars_fragment>
      float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
      float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
        return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
      void main(){
        vec2 p = vW.xz * uScale;
        float a = n(p + vec2(uTime*0.05, uTime*0.03));
        float b = n(p*1.9 - vec2(uTime*0.04, -uTime*0.02));
        float blob = smoothstep(0.52, 0.6, a*0.65 + b*0.45);
        vec3 col = mix(uDeep, uLight, blob*0.75);
        float ripple = smoothstep(0.92, 0.98, n(vW.xz*0.9 + uTime*0.4));
        col = mix(col, uFoam, ripple*0.25);
        float foam = smoothstep(0.55, 1.0, vShore + 0.18*sin(uTime*1.6 + vW.x*0.7 + vW.z*0.5));
        col = mix(col, uFoam, foam*0.85);
        gl_FragColor = vec4(col, mix(uOpacity, 1.0, foam));
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
        #include <fog_fragment>
      }`,
  });
  return mat;
}

/**
 * Water plane covering `size`, with a per-vertex `shore` attribute computed
 * from the island height function so foam hugs the coastline.
 */
export function makeWater({ size = 220, res = 110, level = 0, heightFn = null, colors = {} } = {}) {
  const geo = new THREE.PlaneGeometry(size, size, res, res);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const shore = new Float32Array(pos.count);
  if (heightFn) {
    for (let i = 0; i < pos.count; i++) {
      const hgt = heightFn(pos.getX(i), pos.getZ(i));
      // 1 at the waterline, fading to 0 by 1.4m below.
      const d = level - hgt;
      shore[i] = d < 0 ? 1 : Math.max(0, 1 - d / 1.4);
    }
  }
  geo.setAttribute('shore', new THREE.BufferAttribute(shore, 1));
  const mat = makeWaterMaterial(colors);
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.y = level;
  mesh.renderOrder = 1;
  mesh.userData.update = (t) => { mat.uniforms.uTime.value = t; };
  return mesh;
}

// ── Terrain material: three tiling textures splatted by vertex weights ──
export function makeTerrainMaterial({ texA, texB, texC, repeat = 0.25, tintA, tintB, tintC } = {}) {
  const mat = new THREE.MeshLambertMaterial({ vertexColors: true });
  mat.onBeforeCompile = (shader) => {
    shader.uniforms.tA = { value: texA };
    shader.uniforms.tB = { value: texB ?? texA };
    shader.uniforms.tC = { value: texC ?? texA };
    shader.uniforms.uRep = { value: repeat };
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nattribute vec3 splat;\nvarying vec3 vSplat;\nvarying vec2 vWxz;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvSplat = splat;\nvWxz = (modelMatrix * vec4(position,1.0)).xz;');
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform sampler2D tA; uniform sampler2D tB; uniform sampler2D tC; uniform float uRep;\nvarying vec3 vSplat; varying vec2 vWxz;')
      .replace('#include <map_fragment>', `
        vec2 tuv = vWxz * uRep;
        vec3 ca = texture2D(tA, tuv).rgb;
        vec3 cb = texture2D(tB, tuv * 1.1).rgb;
        vec3 cc = texture2D(tC, tuv * 0.9).rgb;
        vec3 w = vSplat / max(0.0001, vSplat.x + vSplat.y + vSplat.z);
        vec3 tex = ca * w.x + cb * w.y + cc * w.z;
        diffuseColor.rgb *= tex;
      `);
  };
  mat.customProgramCacheKey = () => 'terrain3';
  return mat;
}
