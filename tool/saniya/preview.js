// Deterministic renderer used while tuning the animation.
// ?pose=h                     settle into one letter
// ?word=hello&t=1.4           advance a signing run to a moment
// ?sheet=hello&n=12&dt=.25    contact sheet of a signing run
// ?sheet=alphabet             contact sheet of all 26 letters
// ?face=1                     crop to the head
// ?raw=1                      skip the engine (rest pose)
// ?skin=0                     keep the original skin tone
// ?hide=baby hairs            hide meshes whose name contains the text
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import poses from './poses.json';
import { createEngine } from './engine.js';
import { fairSkin } from './skin.js';

const q = new URLSearchParams(location.search);
const face = q.get('face') === '1';
const sheet = q.get('sheet');
const tileW = Number(q.get('tw') || 300);
const tileH = Number(q.get('th') || 520);

// Seeded RNG so blink and gaze are repeatable between captures.
let seed = 1234567;
Math.random = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
};

const size = Number(q.get('size') || 0);
const cw = Number(q.get('w') || 0) || size || innerWidth;
const ch = Number(q.get('h') || 0) || size || innerHeight;
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
if (q.get('tone') === 'aces') {
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
}
if (size) {
  document.body.style.display = 'flex';
  document.body.style.alignItems = 'center';
  document.body.style.justifyContent = 'center';
}
renderer.setClearColor(0, 0);
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera();
camera.position.set(0, 1.29, 3);
camera.lookAt(0, 1.29, 0);
camera.near = 0.05;
camera.far = 10;
scene.add(new THREE.HemisphereLight(0xfff9ef, 0xc1c7d4, 1.65));
for (const [x, y, z, i] of [
  [-2, 3, 4, 1.75],
  [2, 1.5, 2, 0.65],
  [1, 3, -2, 1.15],
]) {
  const light = new THREE.DirectionalLight(0xfff5ea, i);
  light.position.set(x, y, z);
  scene.add(light);
}

function frameCamera(engine, width, height) {
  const aspect = width / height;
  if (face) {
    const span = 0.3;
    camera.position.set(0, 1.56, 3);
    camera.left = (-span * aspect) / 2;
    camera.right = -camera.left;
    camera.top = span / 2;
    camera.bottom = -camera.top;
    camera.updateProjectionMatrix();
    return;
  }
  if (q.get('hands') === '1') {
    const span = Number(q.get('zoom') || 0.62);
    camera.position.set(0, 1.3, 3);
    camera.left = (-span * aspect) / 2;
    camera.right = -camera.left;
    camera.top = span / 2;
    camera.bottom = -camera.top;
    camera.updateProjectionMatrix();
    return;
  }
  const framing = engine ? engine.framing : 0;
  const drift = engine ? engine.camera : { x: 0, y: 0, zoom: 1 };
  const span =
    Math.max(0.86 - 0.18 * framing, (0.72 - 0.14 * framing) / aspect) *
    drift.zoom;
  camera.position.x = drift.x;
  camera.position.y = 1.27 + 0.08 * framing + drift.y;
  camera.left = (-span * aspect) / 2;
  camera.right = -camera.left;
  camera.top = span / 2;
  camera.bottom = -camera.top;
  camera.updateProjectionMatrix();
}

async function main() {
  const glb = q.get('glb') || '/avatar/likeness/ISL_Avatar_Likeness.glb';
  const buffer = await fetch(glb).then((r) => r.arrayBuffer());
  const { scene: avatar } = await new GLTFLoader().parseAsync(buffer, '');
  scene.add(avatar);
  if (q.get('skin') !== '0') {
    fairSkin(THREE, avatar, {
      gamma: Number(q.get('gamma') || 0.56),
      desat: Number(q.get('desat') || 0.12),
      warm: Number(q.get('warm') || 0.03),
    });
  }
  const hide = q.get('hide');
  if (hide) {
    avatar.traverse((o) => {
      if (o.isMesh && hide.split(',').some((h) => (o.name || '').includes(h))) {
        o.visible = false;
      }
    });
  }
  const names = Object.keys(poses.welcome);
  const bones = names.map((name) => avatar.getObjectByName(name));
  const library = Object.fromEntries(
    Object.entries(poses).map(([name, q]) => [
      name,
      names.map((b) => new THREE.Quaternion().fromArray(q[b])),
    ]),
  );
  let faceMesh = null;
  avatar.traverse((mesh) => {
    if (mesh.isSkinnedMesh) mesh.frustumCulled = false;
    if (mesh.isMesh && mesh.morphTargetDictionary && !faceMesh) faceMesh = mesh;
  });
  const engine = createEngine({
    THREE,
    bones,
    names,
    library,
    face: faceMesh,
  });

  if (q.get('raw') === '1') {
    const ey = Number(q.get('eyeYaw') || 0);
    const ep = Number(q.get('eyePitch') || 0);
    if (ey || ep) {
      for (const side of ['l', 'r']) {
        const bone = avatar.getObjectByName('eye_' + side);
        const e = new THREE.Euler(ep, ey, 0, 'YXZ');
        bone.quaternion.multiply(new THREE.Quaternion().setFromEuler(e));
      }
    }
    renderer.setSize(cw, ch);
    frameCamera(null, cw, ch);
    renderer.render(scene, camera);
    document.title = 'READY';
    window.__ready = true;
    return;
  }

  if (sheet) {
    const cols = Number(q.get('cols') || 4);
    const rows = Number(q.get('rows') || 3);
    const n = Number(q.get('n') || cols * rows);
    const dt = Number(q.get('dt') || 0.25);
    const t0 = Number(q.get('t0') || 0.1);
    renderer.setSize(tileW, tileH);
    const out = document.createElement('canvas');
    out.width = cols * tileW;
    out.height = rows * tileH;
    const ctx = out.getContext('2d');
    ctx.fillStyle = '#e7ece9';
    ctx.fillRect(0, 0, out.width, out.height);
    const rawLetters = q.get('letters');
    const letters = rawLetters
      ? rawLetters.split(',')
      : 'abcdefghijklmnopqrstuvwxyz'.split('');
    const compare = q.get('compare') === '1';
    const sources = {};
    if (compare) {
      await Promise.all(
        letters.map(
          (letter) =>
            new Promise((resolve) => {
              const img = new Image();
              img.onload = () => {
                sources[letter] = img;
                resolve();
              };
              img.onerror = resolve;
              img.src = '/images/' + letter + '.png';
            }),
        ),
      );
    }
    for (let i = 0; i < n; i++) {
      if (sheet === 'alphabet') {
        engine.setPose(letters[i % 26]);
        for (let k = 0; k < 150; k++) engine.update(1 / 60);
      } else {
        if (i === 0) engine.play(Array.from(sheet), 1);
        const target = t0 + i * dt;
        while (engine.time < target) engine.update(1 / 60);
      }
      const rw = compare ? tileW / 2 : tileW;
      renderer.setSize(rw, tileH);
      frameCamera(engine, rw, tileH);
      renderer.render(scene, camera);
      const ox = (i % cols) * tileW;
      const oy = Math.floor(i / cols) * tileH;
      if (compare && sources[letters[i % letters.length]]) {
        const img = sources[letters[i % letters.length]];
        const scale = Math.min(tileW / 2 / img.width, tileH / img.height);
        ctx.drawImage(
          img,
          ox + (tileW / 2 - img.width * scale) / 2,
          oy + (tileH - img.height * scale) / 2,
          img.width * scale,
          img.height * scale,
        );
        ctx.drawImage(renderer.domElement, ox + tileW / 2, oy, rw, tileH);
      } else {
        ctx.drawImage(renderer.domElement, ox, oy);
      }
      ctx.fillStyle = 'rgba(0,0,0,.55)';
      ctx.font = '16px sans-serif';
      const label =
        sheet === 'alphabet'
          ? letters[i % 26].toUpperCase()
          : (t0 + i * dt).toFixed(2) + 's';
      ctx.fillText(label, (i % cols) * tileW + 8, Math.floor(i / cols) * tileH + 22);
    }
    renderer.domElement.style.display = 'none';
    out.style.maxWidth = '100vw';
    out.style.maxHeight = '100vh';
    out.style.width = 'auto';
    out.style.height = 'auto';
    out.style.objectFit = 'contain';
    document.body.appendChild(out);
    document.title = 'READY';
    window.__ready = true;
    return;
  }

  const record = q.get('record');
  if (record) {
    const fps = Number(q.get('fps') || 30);
    const seconds = Number(q.get('seconds') || 8);
    const dir = q.get('dir') || '/tmp/saniya_frames';
    renderer.setSize(cw, ch);
    if (record !== 'idle') engine.play(Array.from(record), 1);
    const total = Math.round(fps * seconds);
    for (let i = 0; i < total; i++) {
      engine.update(1 / fps);
      frameCamera(engine, cw, ch);
      renderer.render(scene, camera);
      const data = renderer.domElement.toDataURL('image/jpeg', 0.88);
      await fetch('http://127.0.0.1:8766/', {
        method: 'POST',
        body: JSON.stringify({
          data,
          path: dir + '/f_' + String(i).padStart(4, '0') + '.png',
        }),
      });
    }
    document.title = 'READY';
    window.__ready = true;
    return;
  }
  const pose = q.get('pose');
  const word = q.get('word');
  const t = Number(q.get('t') || 0);
  renderer.setSize(cw, ch);
  if (word) {
    engine.play(Array.from(word), 1);
    const steps = Math.round(t * 60);
    for (let i = 0; i < steps; i++) engine.update(1 / 60);
  } else if (pose) {
    engine.setPose(pose);
    for (let i = 0; i < 180; i++) engine.update(1 / 60);
  } else {
    for (let i = 0; i < 120; i++) engine.update(1 / 60);
  }
  frameCamera(engine, cw, ch);
  renderer.render(scene, camera);
  document.title = 'READY';
  window.__ready = true;
}

main().catch((e) => {
  document.title = 'ERROR ' + e;
  console.error(e);
});
