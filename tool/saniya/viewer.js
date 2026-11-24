import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import poses from './poses.json';
import { createEngine } from './engine.js';
import { fairSkin } from './skin.js';

const send = (type, info = {}) =>
  window.SaniyaBridge.postMessage(JSON.stringify({ type, ...info }));
const renderer = new THREE.WebGLRenderer({
  antialias: true,
  alpha: true,
  powerPreference: 'high-performance',
});
// Render at the display's native density so the avatar stays crisp.
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 3));
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.setClearColor(0, 0);
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera();
camera.position.set(0, 1.29, 3);
camera.lookAt(0, 1.29, 0);
camera.near = 0.05;
camera.far = 10;
scene.add(new THREE.HemisphereLight(0xfff9ef, 0xc1c7d4, 1.65));
function softLight(x, y, z, intensity) {
  const light = new THREE.DirectionalLight(0xfff5ea, intensity);
  light.position.set(x, y, z);
  scene.add(light);
}
softLight(-2, 3, 4, 1.75);
softLight(2, 1.5, 2, 0.65);
softLight(1, 3, -2, 1.15);

let bones;
let engine;
let parts = [];
let last = 0;

function frameCamera() {
  const aspect = innerWidth / Math.max(innerHeight, 1);
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

function resize() {
  const width = innerWidth;
  const height = innerHeight;
  if (!width || !height) return;
  frameCamera();
  renderer.setSize(width, height);
  if (bones) renderer.render(scene, camera);
}
window.addEventListener('resize', resize);
resize();

function animate(now) {
  requestAnimationFrame(animate);
  if (!engine) return;
  const dt = last ? Math.min((now - last) / 1000, 0.05) : 1 / 60;
  last = now;
  engine.update(dt);
  frameCamera();
  renderer.render(scene, camera);
}

window.Saniya = {
  chunk(base64) {
    parts.push(Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)));
  },
  async load() {
    try {
      const buffer = await new Blob(parts).arrayBuffer();
      parts = [];
      const { scene: avatar } = await new GLTFLoader().parseAsync(buffer, '');
      scene.add(avatar);
      const names = Object.keys(poses.welcome);
      bones = names.map((name) => avatar.getObjectByName(name));
      if (bones.some((b) => !b)) throw Error('Missing skeleton joint');
      const library = Object.fromEntries(
        Object.entries(poses).map(([name, q]) => [
          name,
          names.map((b) => new THREE.Quaternion().fromArray(q[b])),
        ]),
      );
      fairSkin(THREE, avatar);
      const anisotropy = renderer.capabilities.getMaxAnisotropy();
      let face = null;
      avatar.traverse((mesh) => {
        if (mesh.isSkinnedMesh) mesh.frustumCulled = false;
        if (mesh.isMesh && mesh.morphTargetDictionary && !face) face = mesh;
        // The baby-hair cards read as scratches on the forehead at phone size.
        if (mesh.isMesh && /baby hairs/i.test(mesh.name || '')) mesh.visible = false;
        if (mesh.isMesh) {
          const materials = Array.isArray(mesh.material)
            ? mesh.material
            : [mesh.material];
          for (const material of materials) {
            for (const key of ['map', 'normalMap', 'roughnessMap', 'metalnessMap']) {
              if (material[key]) material[key].anisotropy = anisotropy;
            }
          }
        }
      });
      engine = createEngine({
        THREE,
        bones,
        names,
        library,
        face,
        onLetter: (id, word, index) => send('letter', { id, word, index }),
        onDone: (id) => send('done', { id }),
      });
      resize();
      requestAnimationFrame(animate);
      send('ready');
    } catch (e) {
      send('error', { message: String(e) });
    }
  },
  play(words, id) {
    engine?.play(words, id);
  },
};
renderer.domElement.addEventListener('webglcontextlost', (event) => {
  event.preventDefault();
  send('error', { message: 'Graphics context lost' });
});
send('boot');
