# Spec 0124 — Desimalen er hovedtallet i desimalmodus

- **Status:** Accepted
- **Related:** forum thread «Desimaler» (planned by the owner; the ask:
  «Når jeg velger desimal visning, vil jeg at poengsummen med
  desimaler blir fremhevet»); specs 0107/0114 (decimal entry and
  totals)

## Context

Spec 0107 kept the integer as the headline everywhere and showed the
decimal as a secondary line («Desimal 93,4»). A shooter who chose
decimal mode reads the decimal as THE score — Megalink shows it big —
so the app's emphasis felt backwards.

## Rationale

Flip the prominence, not the model: in a decimal-mode session the
decimal total takes the big-number spot on the series-sum card and the
grand-total card, and leads the running line and the scorecard rows,
with the integer demoted to the parenthesis/secondary line. The domain
is untouched — the integer remains the official score for records,
statistics and scoreboards (spec 0107's rule), and sessions without
decimal mode render exactly as before.

## Requirements

1. Series-sum card: the 40 pt number is the decimal sum; a secondary
   line reads «Heltall N». Non-decimal sessions unchanged.
2. Running session line: «Økt så langt: 109,0 (100) · X …».
3. Scorecard series rows, stage totals and the grand total lead with
   the decimal and parenthesise the integer; the grand-total card's
   big number is the decimal.
4. Records, statistics and scoreboards still use the integer.

## Verification

- Widget: in decimal mode the series-sum big text reads the decimal
  (e.g. «10,4») with «Heltall 10» beneath; the running line reads
  «Økt så langt: 109,0 (100)»; outside decimal mode the big text is
  the integer and no decimal strings appear.
- Existing scorecard tests updated to the flipped leads; the full
  suite stays green.
