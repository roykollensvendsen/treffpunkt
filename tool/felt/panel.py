# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""3-panel comparison (vector | overlay | original) for one hold.

Usage: panel.py <model.json> <hold_image> <out.png>
Note: the overlay/original panels embed the copyrighted source — the output is
a local verification artefact, never committed.
"""
import json
import sys

import feltlib as fl

model = json.load(open(sys.argv[1]))
rgb = fl.load_rgb(sys.argv[2])
x, y, w, h = model['artCrop']
fl.panel(model, rgb[y:y + h, x:x + w]).save(sys.argv[3])
print(f"wrote {sys.argv[3]}")
