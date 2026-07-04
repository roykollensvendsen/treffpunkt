# Spec 0137 — Synlige treffpunkter på de store skivene

- **Status:** Accepted
- **Related:** forum thread «Treffpunkt» (planned by the owner; the
  domain expert's ask: «kan du på denne skiven øke ringen for
  Treffpunkt slik det ble gjort med tallene»); spec 0127 (the digit
  floor)

## Context

Shot markers are calibre-true (a 4,5 mm hole on the luft face, 5,6 mm
on fin) — right in principle, but on the 500 mm 25 m faces a
calibre-true hole is ~2 px on a phone: effectively invisible, as the
domain expert reported.

## Rationale

The marker counterpart of spec 0127's digit rule: draw calibre-true
where that is visible, floored at a 5 px radius (a 10 px hole) where
the big faces would shrink the bullet to nothing. The luft faces are
untouched (their calibre-true markers are already ~10 px radius);
scoring, placement and pickup are in millimetres and unaffected.

## Requirements

1. `shotMarkerRadiusPx` floors the on-screen marker radius at 5 px;
   above the floor the marker stays calibre-true.
2. Applies to every ring face (recorder and scorecard minis alike);
   felt markers already have a fixed visible size and are untouched.

## Verification

- Unit: the floor and the calibre-true passthrough.
- Painter: a centre shot on the 25 m duel face at phone size paints a
  5 px-radius marker (previously ~2 px).
- Screenshot on the 25 m face with clearly visible markers.
