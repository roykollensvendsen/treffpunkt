# Spec 0114 — Decimal entry on every ring face

- **Status:** Accepted
- **Related:** forum thread «Desimal poeng på alle ringskiver» (planned
  by the owner); specs 0107/0111 (decimal entry — completed by this
  spec), 0110 (repositioning), 0001 (the original decimal model)

## Context

Specs 0107/0111 offered decimal entry on the uniform 1–10 faces and
deferred the 5–10 duel faces. The users asked for the option on all
ring faces.

## Rationale

Working out the 5–10 generalisation exposed a subtler truth: the
spec-0001 model (fixed steps of one tenth of a ring width, measured
from the centre) silently assumes the innermost band is exactly one
step wide. That holds on the 10 m air faces but not on the 25 m faces,
where the gauge rule makes ring 10's band wider than the rest — so the
derived tenth could disagree with the plotted ring near band edges.
The fix is also the generalisation: **the tenth subdivides the shot's
own scoring band** into ten equal parts. That is exactly the spec-0001
model where the bands are uniform (the air faces), it is correct by
construction everywhere else, it needs no assumption about ring
spacing at all — and its inverse (spec 0110's repositioning) is the
sub-band midpoint. With the model face-agnostic, every ring program
gets the setup toggle, and a mixed program (Fin-/Grovpistol) now sums
decimals across both its faces, so the running line and the
«Desimalsum» work everywhere.

## Requirements

1. `decimalScore` derives the tenth from the shot's position within its
   own scoring band; `floor(decimal) == integerScore` on every face.
   `shotAtDecimalTenth` inverts it (sub-band midpoint). On the 10 m air
   faces the values equal the spec-0001 model's exactly.
2. Every ring program carries `supportsDecimalEntry` — the 5–10-face
   programs (Sprintluft, Storluft luftduell, Hurtigpistol fin/grov,
   Silhuettpistol, NAIS fin/grov) included.
3. Mixed programs sum decimals across all their series (running line,
   series/stage/grand totals).

## Verification

- `decimal_entry_test`: the duel faces derive decimals with
  floor==ring across the face and read 5,0 at ring 5's outer edge;
  duel series carry decimal totals; a mixed program's running total
  sums across both faces; all ring programs are flagged.
- Spec 0001's vectors (`scoring_service_test`) unchanged — the band
  model reproduces them exactly.
- Existing 0107/0110/0111 suites pass against the new model.
