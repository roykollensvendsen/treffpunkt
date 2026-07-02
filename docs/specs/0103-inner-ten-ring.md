# Spec 0103 — Draw the inner-ten ring on the target faces

- **Status:** Accepted
- **Related:** forum thread «Innertier» (bug); specs 0004 (inner ten on
  `TargetGeometry`), 0023 (inner-ten motif), 0100 (marker colours)

## Context

The domain has always known the inner ten: `TargetGeometry` carries
`innerTenDiameterMm` per face, scoring counts inner tens and every score
line shows the ringed-X count. But the drawn target never showed the ring
itself — a shooter placing a shot could not see where the inner ten is,
though it is printed on every real NSF/ISSF face. Reported by the domain
expert on the forum.

## Rationale

The dimensions are already in the geometry (air pistol 5 mm, 25 m
precision 25 mm, 25 m duel/rapid 50 mm, luftduell 11.5 mm — ISSF-sourced
in spec 0004), and the painter already has the mm→px scale and the
on-the-black colour rule for the scoring rings. Drawing one more circle is
the whole change; every screen that renders a target through
`SeriesPainter` (live recording, silhouette banks, scorecard review
targets) inherits it. The 10 m air-rifle face deliberately has no inner
ten (its tiebreak is the decimal score) and keeps drawing without one.

## Requirements

1. `SeriesPainter` draws the inner-ten ring for any geometry with
   `innerTenDiameterMm` set: radius `innerTenDiameterMm / 2` at target
   scale, stroked like the scoring rings — white on the black bull, black
   outside it.
2. Faces without an inner ten (`airRifle10m`) are unchanged.

## Verification

- `series_painter_test`: on `airPistol10m` a stroked centre circle at the
  inner-ten radius is drawn in white70 (5 mm sits on the black); on
  `airRifle10m` the centre circles are exactly the bull + one per scoring
  ring, nothing more.
- Visual review by screenshot of the air-pistol face.
