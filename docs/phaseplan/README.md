# Saniya speech-to-fingerspelling

Status: the alphabet, continuous playback, the lifelike performance layer and
the fair-skin presentation are implemented. What remains is signer review and
device sign-off (phase 5).

The [simulator recording](hello-simulator.mp4) shows the microphone path
signing HELLO end to end, and the [alphabet review sheet](alphabet-review.jpg)
pairs every reference photograph with the runtime pose.

## Phase 1 — Fit the alphabet to the existing avatar

The app uses the likeness GLB and its original skeleton. The welcome pose and
26 letter poses are stored separately in `tool/saniya/poses.json`.

Hand landmarks come from MediaPipe's 3D hand landmarker run over the 26
reference photographs (`tool/saniya/detect_hands.py`). The original
hand-annotated landmarks are kept as a fallback for the letters where a finger
is occluded (G, K, M, P, Q, R, T, X, Z). Depth is converted into the rig's
metre scale before fitting, which is what made the handshapes read correctly.

`tool/saniya/build_poses.py` fits the palms and fingers to Saniya's proportions
and solves the arms so the hands meet in front of the chest. Compare the source
image and the runtime pose for each letter in the
[alphabet review sheet](alphabet-review.jpg).

To revise a pose, edit the relevant row of `tool/saniya/hand_landmarks.json`
or `hand_landmarks_mp.json`, run `python tool/saniya/build_poses.py` with
NumPy and SciPy installed, then run `npm ci` and `npm run build` from
`tool/saniya`. The Flutter app ships the resulting viewer bundle and GLB.

## Phase 2 — Play arbitrary words continuously

The Speech to Signs tab opens on Saniya with relaxed hands in front of her
waist. The microphone, text field and quick phrases share one playback path.
Partial recognition updates the transcript; the final result starts signing
automatically. A–Z letters are processed in order with punctuation and
whitespace acting as boundaries. A new phrase replaces playback. Stop returns
Saniya to rest. The Signs to Speech tab retains its image keyboard.

## Phase 3 — Lifelike performance layer

The GLB has no animation clips, so every motion is generated at runtime in
`tool/saniya/engine.js`:

- A critically damped quaternion spring per joint, with per-bone stiffness and
  a cascade of delays from shoulder to fingertip. The arm leads, the fingers
  follow, and the settle overshoots slightly.
- A continuous idle layer: breathing through the spine and clavicles, a slow
  weight shift through the pelvis, head drift, gaze saccades, and blinks with
  occasional double blinks. Nothing ever freezes, including the welcome pose.
- A signing layer: torso lean and twist, head nods and turns toward the hands,
  shoulder lift, brow raises and a smile on word starts. Each letter gets a
  stable per-letter jitter so repeated letters do not look cloned.
- Variable letter timing, a release-and-reform beat for repeated letters, a
  small drop at word boundaries, and a final settle back to the welcome pose.
- A camera that eases in for signing and keeps a subtle breathing drift.

## Phase 4 — Presentation

The dermal material is re-toned in the fragment shader so Saniya reads as
fair-skinned without a 2K canvas readback at load. The baby-hair cards that
read as scratches on the forehead are hidden. ACES tone mapping softens the
highlights and gives the skin more natural contrast.

Sharpness is the priority. The WebView renders at the display's native density
(up to 3x), with antialiasing, maximum texture anisotropy and a light unsharp
mask on the dermal atlas. The WebView uses Android hybrid composition so the
Flutter controls above it stay interactive.

The interface is deliberately bare: no title, no status line, no bottom
navigation. A custom two-state switch in the top bar carries the mode icon
(a microphone for speech-to-signs, a raised-index hand for signs-to-speech),
and an info button opens a short about dialog with the open-source repository
link. The text field is a transparent pill and the quick phrases are outlined
chips.

## Phase 5 — Verify on mobile

The simulator integration test taps the microphone, injects a partial
transcript and the final transcript "Hello hello!", and waits for the live 3D
viewer to start and finish playback. It checks the stop-button lifecycle,
replay and stop. It supplies the recognition result at the speech plugin
boundary so that timings and text are repeatable.

Run `flutter test integration_test/saniya_test.dart -d DEVICE_ID` with a booted
mobile simulator or emulator. Run `flutter test test` to check the existing
image keyboard.

For sign-off, ask a signer to identify each letter without its caption and
check transitions in words such as HELLO, BOOK and WATER. Check voice capture,
permission denial, interruption and retry on the target phones. Record any
corrections by letter, hand, joint and viewing angle so the corresponding pose
can be revised independently.

Known limitations:

- R and T are the least convincing letters; both involve occluded fingers that
  the landmark model cannot see. They need a signer's correction.
- The emulator's software GPU runs the WebView at roughly 10–15 fps. A physical
  phone is needed to judge the true motion smoothness.
- The 19 MB GLB is streamed into the WebView in 512 KB chunks; first load takes
  a few seconds on the emulator.
