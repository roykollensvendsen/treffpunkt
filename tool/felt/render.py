# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render a hold vector model to a PNG. Usage: render.py <model.json> <out.png>."""
import json
import sys

import feltlib as fl

model = json.load(open(sys.argv[1]))
scale = int(sys.argv[3]) if len(sys.argv) > 3 else 1
fl.render_model(model, scale=scale).save(sys.argv[2])
print(f"wrote {sys.argv[2]}")
