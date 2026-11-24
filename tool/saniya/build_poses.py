"""Fit Saniya's existing GLB skeleton to the annotated alphabet photographs.

Run from any directory with Python, NumPy and SciPy. Landmark xy are thousandths
of image width/height. The third coordinate is estimated depth in millimetres.
All generated rotations are local glTF xyzw quaternions.
"""

import json
import os
import struct
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares
from scipy.spatial.transform import Rotation

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
with (ROOT / "avatar/likeness/ISL_Avatar_Likeness.glb").open("rb") as stream:
    stream.seek(12)
    length, _ = struct.unpack("<II", stream.read(8))
    gltf = json.loads(stream.read(length))

rest, parent = {}, {}
fingers = ("thumb", "index", "middle", "ring", "pinky")


def visit(index, ancestor=None):
    node = gltf["nodes"][index]
    name = node["name"]
    parent[name] = ancestor
    origin, frame = rest.get(ancestor, (np.zeros(3), Rotation.identity()))
    rest[name] = (
        origin + frame.apply(node.get("translation", [0] * 3)),
        frame * Rotation.from_quat(node.get("rotation", [0, 0, 0, 1])),
    )
    for child in node.get("children", []):
        visit(child, name)


for root in gltf["scenes"][0]["nodes"]:
    visit(root)


def unit(v):
    return v / max(np.linalg.norm(v), 1e-9)


def swing(a, b):
    a, b = unit(a), unit(b)
    axis = np.cross(a, b)
    if np.linalg.norm(axis) < 1e-8:
        if a @ b > 0:
            return Rotation.identity()
        axis = np.cross(a, np.eye(3)[np.argmin(np.abs(a))])
    return Rotation.from_rotvec(unit(axis) * np.arccos(np.clip(a @ b, -1, 1)))


def finger_bones(finger, side):
    return [f"{finger}_0{i}_{side}" for i in (1, 2, 3)]


def finger_rest(finger, side):
    chain = finger_bones(finger, side)
    points = [rest[b][0] for b in chain]
    length = np.linalg.norm(points[2] - points[1]) * (
        0.82 if finger != "thumb" else 0.79
    )
    return np.array([*points, points[2] + rest[chain[-1]][1].apply([0, length, 0])])


def measure(side, points):
    # Recover the scale shared by both hands from the metacarpals and phalanges.
    wrist = rest["hand_" + side][0]

    def residual(scale):
        errors = []
        for i, f in enumerate(fingers):
            p = np.vstack([points[0], points[1 + i * 4 : 5 + i * 4]])
            delta = np.diff(p, axis=0) * [scale[0], scale[0], 1]
            lengths = np.linalg.norm(
                np.diff(np.vstack([wrist, finger_rest(f, side)]), axis=0), axis=1
            )
            errors.extend(np.linalg.norm(delta, axis=1) - lengths)
        return errors

    return least_squares(
        residual, [0.29], bounds=(0.12, 0.58), loss="soft_l1", f_scale=0.008
    ).x[0]


def fit_digit(original, wanted, palm, origin, thumb):
    """Fit flexion on a hinge at each knuckle, allowing opposition at the thumb."""
    direction = unit(original[1] - original[0])
    arc = np.diff(original, axis=0)
    # Reconstruct the radial plane from the neutral finger's existing slight curl.
    bend = unit(unit(arc[-1]) - direction * (unit(arc[-1]) @ direction))
    hinge = unit(np.cross(direction, bend))
    if thumb:
        # The thumb may oppose across the entire palm at its saddle joint.
        bounds = ([-1.25, -1.4, -0.50, -0.45, -0.55], [1.35, 1.55, 1.38, 1.38, 0.55])
    else:
        bounds = ([-0.32, -0.46, -0.13, -0.12, -0.23], [1.65, 0.46, 1.93, 1.45, 0.23])

    def solve(angles):
        a, spread, pip, dip, roll = angles
        start = (
            palm
            * Rotation.from_rotvec(direction * roll)
            * Rotation.from_rotvec(bend * spread)
        )
        rect = [origin]
        frames = []
        for i, flex in enumerate([a, a + pip, a + pip + dip]):
            # Use straight finger segments as the reference for absolute bend angles.
            swung = start * Rotation.from_rotvec(hinge * flex)
            frames.append(swung * swing(arc[i], direction))
            rect.append(rect[-1] + swung.apply(direction) * np.linalg.norm(arc[i]))
        return frames, np.array(rect)

    def residual(angles):
        _, coords = solve(angles)
        delta = (coords[1:] - wanted[1:]) * [1, 1, 0.65]
        return np.r_[delta.flatten(), angles[1] * 0.008, angles[-1] * 0.012]

    fit = least_squares(residual, [0.30, 0, 0.40, 0.25, 0], bounds=bounds, max_nfev=65)
    return solve(fit.x)


def fit_hand(side, points, scale, constrained):
    wrist = rest["hand_" + side][0]
    # MediaPipe reports depth in image-width fractions; the hand annotation
    # used millimetres. Bring both into the rig's metre scale.
    depth = points[:, 2] - points[0, 2]
    if np.max(np.abs(points[:, 2])) > 1:
        depth = depth / 1000
    else:
        depth = depth * scale
    target = np.column_stack(
        [
            (points[:, 0] - points[0, 0]) * scale,
            -(points[:, 1] - points[0, 1]) * scale,
            -depth,
        ]
    )
    base = np.array([finger_rest(f, side)[0] - wrist for f in fingers])
    # Include the across-palm axis to prevent roll ambiguity in edge-on hands.
    wanted = target[[1, 5, 9, 13, 17]]
    # The palm normal disambiguates roll for edge-on hands, where the
    # metacarpal directions alone leave the palm free to spin.
    source_axes = [*base, base[1] - base[4], np.cross(base[1], base[4])]
    target_axes = [*wanted, wanted[1] - wanted[4], np.cross(wanted[1], wanted[4])]
    palm, _ = Rotation.align_vectors(
        [unit(v) for v in target_axes],
        [unit(v) for v in source_axes],
        weights=[0.25, 1, 1, 0.65, 1, 1.5, 2.2],
    )
    if os.environ.get("SANITY_DEBUG") == letter:
        print("side", side)
        print("source normal", unit(np.cross(base[1], base[4])))
        print("target normal", unit(np.cross(wanted[1], wanted[4])))
        print("palm normal", unit(palm.apply(unit(np.cross(base[1], base[4])))))
        print("source mcp", [np.round(unit(v), 2) for v in base])
        print("target mcp", [np.round(unit(v), 2) for v in wanted])
    frames = {"hand_" + side: palm * rest["hand_" + side][1]}
    fitted = [np.zeros(3)]
    for i, f in enumerate(fingers):
        chain = finger_bones(f, side)
        original = finger_rest(f, side)
        wanted = target[4 * i + 1 : 4 * i + 5]
        point = palm.apply(original[0] - wrist)
        if constrained:
            rotations, knots = fit_digit(original, wanted, palm, point, f == "thumb")
            for bone, delta in zip(chain, rotations):
                frames[bone] = delta * rest[bone][1]
            fitted.extend(knots)
            continue
        fitted.append(point)
        previous = palm
        for j, bone in enumerate(chain):
            segment = original[j + 1] - original[j]
            direction = wanted[j + 1] - wanted[j]
            rotation = swing(previous.apply(segment), direction) * previous
            frames[bone] = rotation * rest[bone][1]
            point = point + rotation.apply(segment)
            fitted.append(point)
            previous = rotation
    return frames, np.array(fitted)


def arm_ik(world, side, wrist):
    upper, lower, hand = [key + "_" + side for key in ("upperarm", "lowerarm", "hand")]
    shoulder, old_elbow, old_wrist = [rest[k][0] for k in (upper, lower, hand)]
    a, b = np.linalg.norm(old_elbow - shoulder), np.linalg.norm(old_wrist - old_elbow)
    ray = unit(wrist - shoulder)
    distance = min(np.linalg.norm(wrist - shoulder), a + b - 0.0001)
    along = (a * a - b * b + distance * distance) / (2 * distance)
    outward = np.array([0.65 if side == "l" else -0.65, -1, -0.35])
    elbow = (
        shoulder
        + ray * along
        + unit(outward - ray * (ray @ outward)) * np.sqrt(max(0, a * a - along * along))
    )
    upper_delta = swing(old_elbow - shoulder, elbow - shoulder)
    lower_delta = (
        swing(upper_delta.apply(old_wrist - old_elbow), wrist - elbow) * upper_delta
    )
    world[upper] = upper_delta * rest[upper][1]
    world[lower] = lower_delta * rest[lower][1]
    # Share pronation with the forearm to avoid all axial twist at the cuff.
    neutral_hand = lower_delta * rest[hand][1]
    twist = (world[hand] * neutral_hand.inv()).as_quat()
    axis = unit(wrist - elbow)
    angle = 2 * np.arctan2(twist[:3] @ axis, twist[3])
    angle = (angle + np.pi) % (2 * np.pi) - np.pi
    world[lower] = Rotation.from_rotvec(axis * angle * 0.65) * world[lower]


def welcome(side):
    sign = 1 if side == "l" else -1
    hand = "hand_" + side
    # Low relaxed hands angled toward one another, in front of the waist.
    direction = np.array([-sign * 0.76, -0.57, 0.22])
    delta = swing(rest["middle_01_" + side][0] - rest[hand][0], direction)
    world = {hand: delta * rest[hand][1]}
    for f in fingers:
        for b in finger_bones(f, side):
            world[b] = delta * rest[b][1]
    arm_ik(world, side, np.array([sign * 0.105, 1.015, 0.17 + (side == "l") * 0.018]))
    return world


def serialize(world):
    return {
        b: (world.get(parent[b], rest[parent[b]][1]).inv() * r)
        .as_quat()
        .round(6)
        .tolist()
        for b, r in world.items()
    }


neutral = welcome("r") | welcome("l")
poses = {"welcome": serialize(neutral)}
# Front-to-back offsets where the photograph clearly shows one hand in front.
depth_offset = {
    "f": -0.026,
    "h": 0.041,
    "m": 0.020,
    "n": -0.052,
    "p": 0.004,
    "r": -0.030,
    "w": 0.008,
    "x": 0.012,
    "z": 0.016,
}
# Corresponding visible contact landmarks, indexed from wrist through fingertips.
contacts = {
    "a": (4, 4),
    "b": (4, 4),
    "d": (8, 8),
    "e": (10, 8),
    "k": (7, 6),
    "r": (8, 13),
    "p": (8, 8),
    "q": (8, 4),
    "s": (20, 20),
    "t": (7, 8),
    "z": (6, 8),
}
landmarks_file = os.environ.get("SANITY_LANDMARKS", "hand_landmarks_mix.json")
use_hacks = os.environ.get("SANITY_HACKS", "1") == "1"
for letter, hands in json.loads((HERE / landmarks_file).read_text()).items():
    points = {
        side: np.array(coords, dtype=float) / 1000 for side, coords in hands.items()
    }
    # Convert normalized image coordinates into a common image-plane unit.
    with (ROOT / "images" / f"{letter}.png").open("rb") as reference:
        reference.seek(16)
        width, height = struct.unpack(">II", reference.read(8))
    for hand_points in points.values():
        hand_points[:, 1] *= height / width
    # In these images the horizontal hand is shown palm-forward and enters
    # from the opposite edge. The anatomical hands cross in signing space.
    crossed = letter in {"n", "r"}
    if crossed:
        points = {"l" if s == "r" else "r": p for s, p in points.items()}
    scale = np.mean([measure(s, p) for s, p in points.items()])
    all_xy = np.vstack(list(points.values()))[:, :2]
    center = (all_xy.min(axis=0) + all_xy.max(axis=0)) / 2
    world, wrists, offsets = dict(neutral), {}, {}
    for side, p in points.items():
        frames, fitted = fit_hand(
            side, p, scale, False
        )
        world.update(frames)
        # Center the visible handshape on the sternum, including the fingers.
        xy = np.median((p[:, :2] - center) * [scale, -scale] - fitted[:, :2], axis=0)
        z = (
            0.265
            + (0.5 if side == "r" else -0.5) * depth_offset.get(letter, 0)
            - np.median(fitted[:, 2])
        )
        wrists[side] = np.array([xy[0], 1.27 + xy[1], z])
        offsets[side] = fitted
    if use_hacks and letter == "y":
        # The lower index touches the side of the upper palm below its thumb.
        contact = wrists["r"] + .70 * offsets["r"][5] + np.array([.005, -.004, .002])
        wrists["l"] += contact - (wrists["l"] + offsets["l"][8])
    if use_hacks and letter in contacts:
        ir, il = contacts[letter]
        if crossed:
            ir, il = il, ir
        gap = wrists["l"] + offsets["l"][il] - wrists["r"] - offsets["r"][ir]
        # Preserve a fingertip pad's thickness when the markers nearly coincide.
        correction = gap * 0.5 * max(0, 1 - 0.007 / max(np.linalg.norm(gap), 1e-8))
        wrists["r"] += correction
        wrists["l"] -= correction
    for side, wrist in wrists.items():
        arm_ik(world, side, wrist)
    poses[letter] = serialize(world)
(HERE / "poses.json").write_text(json.dumps(poses, separators=(",", ":")) + "\n")
