// Procedural animation for Saniya.
//
// The GLB has no clips, so every motion is generated here: a critically damped
// quaternion spring per joint, a continuous idle layer (breath, weight shift,
// head drift, gaze, blink) and a signing layer that cascades from the torso
// out to the fingertips. Nothing ever freezes, which is what separates a live
// signer from a posed mannequin.

const TAU = Math.PI * 2;
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const smooth = (t) => t * t * (3 - 2 * t);
const wave = (t, hz, phase = 0) => Math.sin(t * hz * TAU + phase);

function boneParams(name) {
  if (/^(thumb|index|middle|ring|pinky)_/.test(name)) {
    const seg = name.slice(-2);
    return {
      k: 330,
      zeta: 0.8,
      delay: seg === '01' ? 0.12 : seg === '02' ? 0.14 : 0.16,
    };
  }
  if (name.startsWith('hand_')) return { k: 205, zeta: 0.72, delay: 0.09 };
  if (name.startsWith('lowerarm')) return { k: 175, zeta: 0.74, delay: 0.06 };
  if (name.startsWith('upperarm')) return { k: 150, zeta: 0.76, delay: 0.03 };
  if (name.startsWith('clavicle')) return { k: 120, zeta: 0.85, delay: 0.01 };
  if (name === 'head') return { k: 95, zeta: 0.82, delay: 0.08 };
  if (name === 'neck_01') return { k: 85, zeta: 0.86, delay: 0.05 };
  if (name.startsWith('spine')) return { k: 60, zeta: 0.92, delay: 0 };
  if (name === 'pelvis') return { k: 45, zeta: 0.95, delay: 0 };
  if (name.startsWith('eye')) return { k: 420, zeta: 1, delay: 0 };
  return { k: 120, zeta: 0.9, delay: 0.02 };
}

export function createEngine({
  THREE,
  bones,
  names,
  library,
  face,
  onLetter,
  onDone,
}) {
  const N = names.length;
  const index = new Map(names.map((n, i) => [n, i]));
  const params = names.map(boneParams);

  const current = names.map((n, i) => library.welcome[i].clone());
  const base = names.map((n, i) => library.welcome[i].clone());
  const pending = names.map((n, i) => library.welcome[i].clone());
  const omega = names.map(() => new THREE.Vector3());
  const delayLeft = new Float32Array(N);
  const idleQ = names.map(() => new THREE.Quaternion());
  const targetQ = names.map(() => new THREE.Quaternion());
  const tmpQ = new THREE.Quaternion();
  const tmpQ2 = new THREE.Quaternion();
  const tmpV = new THREE.Vector3();
  const tmpE = new THREE.Euler();

  // A repeated letter releases part-way to rest before re-forming.
  const poses = { ...library };
  for (const name of Object.keys(library)) {
    if (name === 'welcome') continue;
    poses['release:' + name] = library[name].map((q, i) =>
      q.clone().slerp(library.welcome[i], 0.55),
    );
  }

  const morph = face?.morphTargetDictionary ?? {};
  const setMorph = (name, value) => {
    const i = morph[name];
    if (i !== undefined) face.morphTargetInfluences[i] = clamp(value, 0, 1);
  };

  let time = 0;
  let run = null;
  let framing = 0;
  let framingTarget = 0;
  let accentHead = 0;
  let accentTorso = 0;
  let accentShoulder = 0;
  let accentBrow = 0;
  let accentSmile = 0;
  let accentLean = 0;
  let signingBlend = 0;
  let blinkValue = 0;
  let blinkAt = -1;
  let blinkNext = 1.4 + Math.random() * 2.2;
  let gazeYaw = 0;
  let gazePitch = 0;
  let gazeTargetYaw = 0;
  let gazeTargetPitch = 0;
  let gazeNext = 0.4;
  let headYaw = 0;
  let headPitch = 0;
  let headTargetYaw = 0;
  let headTargetPitch = 0;
  let headNext = 2.5;
  const camera = { x: 0, y: 0, zoom: 1 };

  function setTarget(poseName, amount = 1) {
    const pose = poses[poseName] ?? poses.welcome;
    for (let i = 0; i < N; i++) {
      if (amount >= 1) pending[i].copy(pose[i]);
      else pending[i].copy(base[i]).slerp(pose[i], amount);
      delayLeft[i] = params[i].delay + (names[i].endsWith('_l') ? 0.012 : 0);
    }
  }

  function spring(i, dt) {
    const { k, zeta } = params[i];
    const q = current[i];
    // Error in the parent frame: target * current^-1.
    tmpQ.copy(targetQ[i]).multiply(tmpQ2.copy(q).invert());
    if (tmpQ.w < 0) {
      tmpQ.x = -tmpQ.x;
      tmpQ.y = -tmpQ.y;
      tmpQ.z = -tmpQ.z;
      tmpQ.w = -tmpQ.w;
    }
    const w = clamp(tmpQ.w, -1, 1);
    const angle = 2 * Math.acos(w);
    const s = Math.sqrt(Math.max(0, 1 - w * w));
    let ax = 0;
    let ay = 0;
    let az = 0;
    if (s > 1e-6) {
      ax = tmpQ.x / s;
      ay = tmpQ.y / s;
      az = tmpQ.z / s;
    }
    const c = 2 * Math.sqrt(k) * zeta;
    const o = omega[i];
    o.x += (k * angle * ax - c * o.x) * dt;
    o.y += (k * angle * ay - c * o.y) * dt;
    o.z += (k * angle * az - c * o.z) * dt;
    const speed = o.length();
    if (speed > 16) o.multiplyScalar(16 / speed);
    const step = o.length() * dt;
    if (step > 1e-7) {
      tmpQ2.setFromAxisAngle(tmpV.copy(o).normalize(), step);
      q.premultiply(tmpQ2).normalize();
    }
  }

  function idleFor(name, out) {
    let x = 0;
    let y = 0;
    let z = 0;
    const side = name.endsWith('_l') ? 1 : name.endsWith('_r') ? -1 : 0;
    if (name === 'pelvis') {
      y = 0.009 * wave(time, 0.043, 1.1);
      z = 0.016 * wave(time, 0.061, 0.3);
    } else if (name === 'spine_01') {
      z = -0.01 * wave(time, 0.061, 0.3);
      x = 0.004 * wave(time, 0.23, 0);
    } else if (name === 'spine_02') {
      x = -0.014 * wave(time, 0.23, 0) + 0.02 * signingBlend + accentLean;
      z = -0.006 * wave(time, 0.061, 0.3);
    } else if (name === 'spine_03') {
      x = -0.01 * wave(time, 0.23, 0) + 0.014 * signingBlend;
      y =
        0.006 * wave(time, 0.043, 1.1) +
        accentTorso +
        signingBlend * 0.055 * wave(time, 0.19, 0.9);
    } else if (name === 'neck_01') {
      x =
        0.006 * wave(time, 0.23, 0) +
        0.009 * wave(time, 0.17, 0.7) +
        0.04 * signingBlend;
      y = 0.018 * wave(time, 0.11, 0);
      z = 0.006 * wave(time, 0.09, 2.1);
    } else if (name === 'head') {
      x =
        0.022 * wave(time, 0.17, 0.7) +
        0.008 * wave(time, 0.53, 0) +
        accentHead +
        headPitch * (1 - signingBlend) +
        signingBlend * (0.085 + 0.03 * wave(time, 0.31, 0.4));
      y =
        0.04 * wave(time, 0.11, 0) +
        0.014 * wave(time, 0.37, 1.3) +
        headYaw * (1 - signingBlend) +
        signingBlend * (0.05 * wave(time, 0.21, 1.7) - 0.045);
      z =
        0.012 * wave(time, 0.09, 2.1) +
        signingBlend * 0.022 * wave(time, 0.17, 2.4);
    } else if (name.startsWith('clavicle')) {
      z = side * (0.008 * wave(time, 0.23, 0) + accentShoulder);
    } else if (name.startsWith('upperarm')) {
      z = side * 0.009 * wave(time, 0.13, side);
      x = 0.006 * wave(time, 0.19, side);
    } else if (name.startsWith('lowerarm')) {
      x = 0.006 * wave(time, 0.21, side);
    } else if (name.startsWith('hand_')) {
      x = 0.011 * wave(time, 0.27, side);
      z = 0.009 * wave(time, 0.31, side);
    } else if (/^(thumb|index|middle|ring|pinky)_/.test(name)) {
      x = 0.014 * wave(time, 0.4, side * 1.7);
    } else if (name.startsWith('eye')) {
      // The sculpted irises sit slightly inward; a small shared outward
      // rotation makes the gaze read as parallel instead of cross-eyed.
      x = gazePitch;
      y = gazeYaw + 0.18;
    }
    out.setFromEuler(tmpE.set(x, y, z, 'YXZ'));
  }

  function updateBlink(dt) {
    if (blinkAt < 0) {
      blinkNext -= dt;
      if (blinkNext <= 0) {
        blinkAt = 0;
        blinkNext = 2.2 + Math.random() * 3.6;
      }
    } else {
      blinkAt += dt;
      const t = blinkAt;
      if (t < 0.075) blinkValue = smooth(t / 0.075);
      else if (t < 0.115) blinkValue = 1;
      else if (t < 0.26) blinkValue = 1 - smooth((t - 0.115) / 0.145);
      else {
        blinkValue = 0;
        blinkAt = -1;
        if (Math.random() < 0.16) blinkNext = 0.11;
      }
    }
    setMorph('Blink', blinkValue);
  }

  function updateHead(dt) {
    headNext -= dt;
    if (headNext <= 0) {
      headNext = 4 + Math.random() * 6;
      headTargetYaw = (Math.random() - 0.5) * 0.14;
      headTargetPitch = (Math.random() - 0.5) * 0.05;
    }
    const k = 1 - Math.exp(-dt * 1.6);
    headYaw += (headTargetYaw - headYaw) * k;
    headPitch += (headTargetPitch - headPitch) * k;
  }

  function updateGaze(dt) {
    gazeNext -= dt;
    if (gazeNext <= 0) {
      gazeNext = 0.45 + Math.random() * 1.4;
      if (run && Math.random() < 0.62) {
        // Check her own hands, the way a signer monitors their signing space.
        gazeTargetPitch = -0.11 - Math.random() * 0.03;
        gazeTargetYaw = 0.04 + (Math.random() - 0.5) * 0.05;
      } else {
        gazeTargetYaw = (Math.random() - 0.5) * 0.09;
        gazeTargetPitch = (Math.random() - 0.5) * 0.05;
      }
    }
    const k = 1 - Math.exp(-dt * 15);
    gazeYaw += (gazeTargetYaw - gazeYaw) * k;
    gazePitch += (gazeTargetPitch - gazePitch) * k;
  }

  function buildSteps(words) {
    const steps = [];
    words.forEach((word, wordIndex) => {
      if (wordIndex) steps.push({ pose: 'welcome', amount: 0.55, duration: 0.22 });
      const letters = Array.from(word);
      letters.forEach((letter, i) => {
        if (i && letter === letters[i - 1]) {
          steps.push({ pose: 'release:' + letter, amount: 1, duration: 0.14 });
        }
        const jitter = ((letter.charCodeAt(0) * 53 + i * 17) % 100) / 100;
        steps.push({
          pose: letter,
          amount: 1,
          duration: 0.46 + jitter * 0.12,
          wordIndex,
          index: i,
        });
      });
    });
    steps.push({ pose: 'welcome', amount: 1, duration: 0.6 });
    return steps;
  }

  function beginStep() {
    const step = run.steps[run.cursor];
    setTarget(step.pose, step.amount);
    if (step.index !== undefined) {
      onLetter?.(run.id, step.wordIndex, step.index);
      // A stable per-letter jitter keeps repeated letters from looking cloned.
      const seed = (step.pose.charCodeAt(0) * 37 + step.index * 11) % 100 / 100;
      accentHead += 0.03 + seed * 0.018;
      accentTorso += (0.022 + seed * 0.016) * (seed > 0.5 ? 1 : -1);
      accentShoulder += 0.024 + seed * 0.01;
      accentLean += 0.012 + seed * 0.008;
      accentBrow += 0.14 + seed * 0.08;
      if (step.index === 0) {
        accentHead += 0.022;
        accentBrow += 0.08;
        accentSmile += 0.1;
        if (Math.random() < 0.5) blinkNext = 0.02;
      }
    }
    run.stepStart = time;
  }

  function update(dt) {
    dt = clamp(dt, 0, 1 / 30);
    time += dt;

    // Delayed targets give the arm a head start over the fingers.
    for (let i = 0; i < N; i++) {
      if (delayLeft[i] > 0) {
        delayLeft[i] -= dt;
        if (delayLeft[i] <= 0) base[i].copy(pending[i]);
      }
    }

    updateHead(dt);
    updateGaze(dt);
    updateBlink(dt);

    const decay = Math.exp(-dt * 5);
    accentHead *= decay;
    accentTorso *= decay;
    accentShoulder *= decay;
    accentBrow *= decay;
    accentSmile *= decay;
    accentLean *= decay;

    for (let i = 0; i < N; i++) {
      idleFor(names[i], idleQ[i]);
      targetQ[i].copy(base[i]).multiply(idleQ[i]);
      spring(i, dt);
      bones[i].quaternion.copy(current[i]);
    }

    const signing = run ? 1 : 0;
    signingBlend += (signing - signingBlend) * (1 - Math.exp(-dt * 4));
    framingTarget = signing;
    framing += (framingTarget - framing) * (1 - Math.exp(-dt * 3.2));
    camera.x = 0.004 * wave(time, 0.07, 1) + 0.0015 * wave(time, 0.31, 2);
    camera.y = 0.003 * wave(time, 0.19, 0.5);
    camera.zoom = 1 + 0.0035 * wave(time, 0.23, 0);

    setMorph('Smile', 0.1 + accentSmile + (run ? 0.06 : 0));
    setMorph('JawOpen', 0.012 + 0.008 * wave(time, 0.13, 0.2));
    setMorph('BrowRaise', accentBrow);
    setMorph('BrowInnerUp_L', 0.04 + accentBrow * 0.3);
    setMorph('BrowInnerUp_R', 0.04 + accentBrow * 0.3);
    setMorph('LipPress', 0.04);
    setMorph('LidNarrow_L', 0.06);
    setMorph('LidNarrow_R', 0.06);

    if (run) {
      const step = run.steps[run.cursor];
      if (time - run.stepStart >= step.duration) {
        run.cursor++;
        if (run.cursor >= run.steps.length) {
          const id = run.id;
          run = null;
          setTarget('welcome', 1);
          onDone?.(id);
        } else {
          beginStep();
        }
      }
    }
  }

  return {
    get time() {
      return time;
    },
    get framing() {
      return framing;
    },
    get camera() {
      return camera;
    },
    get playing() {
      return run !== null;
    },
    update,
    play(words, id) {
      if (!words.length) {
        run = null;
        setTarget('welcome', 1);
        onDone?.(id);
        return;
      }
      run = { id, steps: buildSteps(words), cursor: 0, stepStart: time };
      beginStep();
    },
    setPose(name) {
      run = null;
      setTarget(name, 1);
    },
  };
}
