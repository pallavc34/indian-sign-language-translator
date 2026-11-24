"""Detect 21 3D hand landmarks per alphabet image with MediaPipe Tasks.

Runs the original and a mirrored copy, then assigns each detection to the
manual left/right side by wrist proximity. Missing sides fall back to the
hand-annotated landmarks.

Writes tool/saniya/hand_landmarks_mp.json in the same units as
hand_landmarks.json (x/y thousandths of image width, z in image-width units).
"""

import json
from pathlib import Path

import mediapipe as mp
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MODEL = Path("/tmp/hand_landmarker.task")

options = mp.tasks.vision.HandLandmarkerOptions(
    base_options=mp.tasks.BaseOptions(model_asset_path=str(MODEL)),
    running_mode=mp.tasks.vision.RunningMode.IMAGE,
    num_hands=2,
    min_hand_detection_confidence=0.15,
    min_hand_presence_confidence=0.15,
    min_tracking_confidence=0.15,
)
landmarker = mp.tasks.vision.HandLandmarker.create_from_options(options)

manual = json.loads((HERE / "hand_landmarks.json").read_text())


def detect(image):
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image)
    result = landmarker.detect(mp_image)
    found = []
    for landmarks, handed in zip(result.hand_landmarks, result.handedness):
        found.append(
            (
                handed[0].score,
                np.array([[p.x, p.y, p.z] for p in landmarks], dtype=float),
            )
        )
    return found


out = {}
for letter in "abcdefghijklmnopqrstuvwxyz":
    image = np.asarray(Image.open(ROOT / "images" / f"{letter}.png").convert("RGB"))
    height, width = image.shape[:2]
    candidates = detect(image)
    flipped = detect(np.ascontiguousarray(image[:, ::-1]))
    for score, points in flipped:
        points = points.copy()
        points[:, 0] = 1 - points[:, 0]
        candidates.append((score, points))

    sides = manual[letter]
    entry = {}
    used = set()
    # Match the strongest detections to the annotated wrists first.
    for side, points in sides.items():
        wrist = np.array(points[0][:2]) / 1000
        best = None
        for i, (score, candidate) in enumerate(candidates):
            if i in used:
                continue
            distance = np.linalg.norm(candidate[0, :2] - wrist)
            if best is None or distance < best[0]:
                best = (distance, i)
        if best and best[0] < 0.18:
            used.add(best[1])
            points = candidates[best[1]][1]
            entry[side] = [
                [round(p[0] * 1000, 1), round(p[1] * 1000, 1), round(p[2] * 1000, 1)]
                for p in points
            ]
        else:
            entry[side] = sides[side]
    out[letter] = entry
    source = "".join(
        "m" if entry[s] is sides[s] else "d" for s in sorted(entry)
    )
    print(letter, sorted(entry), source)

(HERE / "hand_landmarks_mp.json").write_text(json.dumps(out))
