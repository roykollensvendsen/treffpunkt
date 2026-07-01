# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""IoU/colour diff of a model vs its source hold art crop.

Usage: compare.py <model.json> <hold_image>
The model's ``artCrop`` [x, y, w, h] selects the region of the source to diff.
"""
import json
import sys

import feltlib as fl

model = json.load(open(sys.argv[1]))
rgb = fl.load_rgb(sys.argv[2])
x, y, w, h = model['artCrop']
metrics = fl.compare(model, rgb[y:y + h, x:x + w])
print(json.dumps(metrics))
