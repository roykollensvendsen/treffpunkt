<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Hole-detection model pipeline

Off-device tooling (Python) for the auto-detect model (spec 0048-adjacent; the
in-app detector is spec 0040). The model is a **candidate classifier**: the
existing heuristic proposes candidate hole locations, and a small learned model
decides hole vs not-hole (a printed numeral / texture), which is where the
heuristic alone fails.

The training images are **private user data** (contributed under spec 0041,
consent per the privacy doc): `ml/data/` is git-ignored and never committed.

## Steps

1. `python export_dataset.py` — pull `training_samples` + images from the linked
   Supabase project into `data/` (`images/*.jpg` + `labels.jsonl`). Needs the
   `supabase` CLI logged in + linked.
2. *(more steps land here: clean, baseline, patches, train, eval)*
