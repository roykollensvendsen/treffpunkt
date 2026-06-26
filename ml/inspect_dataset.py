# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render every exported sample with its calibration rings + labelled holes.

Lets us eyeball the set: which photos are real targets vs accidental, and
whether the calibration/holes line up. Writes per-sample thumbnails and one
montage to data/inspect/, and prints a table.

Run export_dataset.py first.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
INSPECT = DATA / "inspect"
THUMB = 360


def _rings(label: dict) -> list[float]:
    return label["geometry"]["ringOuterDiametersMm"]


def render(sample: dict) -> Image.Image | None:
    img_path = DATA / "images" / sample["image"]
    if not img_path.exists():
        return None
    im = Image.open(img_path).convert("RGB")
    d = ImageDraw.Draw(im)
    label = sample["label"]
    cal = label["calibration"]
    cx, cy = cal["centrePx"]["x"], cal["centrePx"]["y"]
    ppm = cal["pixelsPerMm"]
    # Ring overlay (red), from the recorded calibration + geometry.
    for diameter in _rings(label):
        r = diameter / 2 * ppm
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 0, 0), width=3)
    # Labelled holes (cyan = manual, lime = auto), at their image pixels.
    for hole in label["holes"]:
        x, y = hole["xPx"], hole["yPx"]
        colour = (0, 255, 255) if hole.get("source") == "manual" else (60, 255, 60)
        d.ellipse([x - 9, y - 9, x + 9, y + 9], outline=colour, width=3)
    return im


def main() -> int:
    INSPECT.mkdir(parents=True, exist_ok=True)
    samples = [
        json.loads(line)
        for line in (DATA / "labels.jsonl").read_text().splitlines()
        if line.strip()
    ]
    thumbs: list[Image.Image] = []
    print(f"{'id':10} {'program':22} {'dims':10} {'holes':6} sources")
    for s in samples:
        im = render(s)
        label = s["label"]
        w = label["image"]["widthPx"]
        h = label["image"]["heightPx"]
        holes = label["holes"]
        src: dict[str, int] = {}
        for hole in holes:
            src[hole.get("source", "?")] = src.get(hole.get("source", "?"), 0) + 1
        print(
            f"{s['id'][:8]:10} {str(s['program'])[:22]:22} "
            f"{w}x{h:<5} {len(holes):<6} {src}"
        )
        if im is None:
            continue
        im.save(INSPECT / f"{s['id']}.png")
        t = im.copy()
        t.thumbnail((THUMB, THUMB))
        thumbs.append(t)

    # Montage grid.
    if thumbs:
        cols = 3
        rows = math.ceil(len(thumbs) / cols)
        mont = Image.new("RGB", (THUMB * cols, THUMB * rows), (20, 20, 20))
        for i, t in enumerate(thumbs):
            mont.paste(t, ((i % cols) * THUMB, (i // cols) * THUMB))
        mont.save(INSPECT / "montage.png")
        print(f"\nmontage -> {INSPECT / 'montage.png'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
