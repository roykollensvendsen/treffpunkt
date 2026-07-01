# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stack every hold's 3-panel comparison into one labelled montage.

Usage: ``python montage.py <holds_dir> <out.png> [holdNumbers...]``

For each hold N it renders the model ``models/hold-N.json`` against
``<holds_dir>/holdN-2026.png`` as a 3-panel (vector | overlay | original) with a
title bar showing the hold number and its metrics, then stacks the rows. The
output embeds the copyrighted originals — a local sign-off artefact, never
committed.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw

import feltlib as fl

HERE = os.path.dirname(os.path.abspath(__file__))


def row(hold, holds_dir):
    model = json.load(open(os.path.join(HERE, 'models', f'hold-{hold}.json')))
    src_path = os.path.join(holds_dir, f'hold{hold}-2026.png')
    rgb = fl.load_rgb(src_path)
    x, y, w, h = model['artCrop']
    crop = rgb[y:y + h, x:x + w]
    panel = fl.panel(model, crop)
    m = fl.compare(model, crop)
    bar_h = 22
    out = Image.new('RGB', (panel.width, panel.height + bar_h), (245, 245, 245))
    out.paste(panel, (0, bar_h))
    d = ImageDraw.Draw(out)
    d.text((4, 5), f"Hold {hold}  match={m['matchScore']}  "
           f"bdry={m['boundaryPx']['median']}px  colour={m['colour']}  "
           f"(vector | overlay | original)", fill=(0, 0, 0))
    return out


def main():
    holds_dir, out_path = sys.argv[1], sys.argv[2]
    holds = [int(a) for a in sys.argv[3:]] or list(range(1, 9))
    rows = []
    for n in holds:
        try:
            rows.append(row(n, holds_dir))
        except FileNotFoundError:
            continue
    if not rows:
        raise SystemExit('no models found')
    gap = 10
    width = max(r.width for r in rows)
    total = sum(r.height for r in rows) + gap * (len(rows) - 1)
    montage = Image.new('RGB', (width, total), (255, 255, 255))
    yy = 0
    for r in rows:
        montage.paste(r, (0, yy))
        yy += r.height + gap
    montage.save(out_path)
    print(f"wrote {out_path} ({len(rows)} holds)")


if __name__ == '__main__':
    main()
