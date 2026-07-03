# Spec 0111 — Decimal entry on the 25/50 m precision-face programs

- **Status:** Accepted
- **Related:** forum thread «Desimal» (planned by the owner); spec 0107
  (decimal entry — extended by this spec), 0110 (repositioning)

## Context

Spec 0107 gated decimal entry to the luft programs. The domain expert,
happy with the feature, asked for it on the finpistol precision face and
standard pistol too — "eller kanskje et valg på alle skiver". The 25 m
precision face is a uniform 1–10 face, so the whole decimal model
already works there; only the program flag said no.

## Rationale

Four more programs carry the precision face: 25 m Standard Pistol and
50 m Fripistol shoot it in every stage; 25 m Finpistol and Grovpistol
mix it with the duel face (5–10), which spec 0107 explicitly deferred.
The mixed programs still get the toggle — the expert asked for exactly
their precision stages — and the existing null-propagation makes the
duel series degrade honestly: integer rows, no series decimal line, no
session decimal sum. One place lied under that rule: the running
session line summed `?? 0` around nulls and would show a partial
decimal on mixed programs — replaced by a domain helper that goes
silent the moment any involved series lacks decimals.

## Requirements

1. `supportsDecimalEntry` on 25 m Standard Pistol, 25 m Finpistol,
   25 m Grovpistol and 50 m Fripistol; the 5–10-face programs
   (hurtigpistol, silhuett, NAIS, sprintluft, storluft-duell) remain
   without it.
2. On a mixed program in decimal mode: precision series behave exactly
   like luft (picker, decimals, series decimal line); duel series stay
   integer with no picker and no decimal lines.
3. `ScoringService.runningDecimalTotal(session, current)`: the sealed +
   current decimal sum in exact tenths, null the moment any involved
   series is on a non-decimal face — the shooting screen's running line
   uses it, so a partial decimal is never shown.

## Verification

- `decimal_entry_test`: the four programs are flagged, the 5–10
  programs are not; `runningDecimalTotal` sums pure-decimal sessions,
  reports a sealed total against an empty current series, and goes
  silent when a duel series is involved.
- `decimal_entry_flow_test`: the setup toggle is offered on Standard
  Pistol and Finpistol.
- Existing 0107/0110 suites unchanged.
