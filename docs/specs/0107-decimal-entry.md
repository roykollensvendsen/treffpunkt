# Spec 0107 — Decimal scores on the air-pistol faces (Megalink transfer)

- **Status:** Accepted
- **Related:** forum thread «Desimaler»; specs 0001 (the decimal model),
  0002 (move a shot), 0009 (snapshot persistence), 0099 (remember-last
  idiom), 0096 (Norwegian conventions)

## Context

The domain expert shoots on Megalink electronic targets, which read every
shot as a decimal (9,0–10,9). He asked to transfer those readings into
the app: plot the shot in its ring as today, then pick the tenth from a
dropdown, with values shown the Megalink way. The domain has carried a
position-derived decimal model since spec 0001 — unused by any UI until
now.

## Rationale

The tap already fixes the ring; only the tenth is uncertain. So the
dropdown *defaults* to the position-derived tenth (`decimalScore`) and
lets the shooter correct it to the Megalink reading — one optional tap
per shot instead of one mandatory one. The pick is stored on the shot
(`Shot.tenth`, 0–9 within the plotted ring), so it survives save/resume
and rides the sync payload unchanged; everything else derives. Integer
scoring stays canonical everywhere — records, statistics, scoreboards —
so nothing built on ints moves; the decimal is a labelled extra. Decimal
entry is opt-in per session, offered only on programs explicitly flagged
(`supportsDecimalEntry`: the luft programs on the uniform 1–10 face — a
pure geometry gate would surprisingly offer the 25 m programs too), and
the choice is remembered like the felt group (spec 0099).

## Requirements

1. **Setup toggle** «Desimalpoeng (elektronisk skive)» on decimal-capable
   programs only ('10 m Luftpistol 60/40 skudd', 'Storluft (5,5 m)');
   remembered across restarts; off by default.
2. **The tenth picker**: in decimal mode the last-placed shot's row swaps
   its value for a compact dropdown x,0–x,9 within the plotted ring,
   preselected on the position-derived tenth. Earlier rows show their
   decimal as text; a miss is 0,0 with nothing to pick. Norwegian comma.
3. **The rule**: effective decimal = ring + tenth/10, position-derived
   when no tenth is picked (spec 0001 guarantees floor(decimal) = ring).
   Undo drops the pick with the shot; moving a shot keeps the pick within
   the same ring and re-derives across a ring boundary (spec 0002).
4. **Display**: integers stay the headline everywhere. Decimal-mode
   sessions add: the decimal per shot row, a «Desimal …» line on the
   series card, the running decimal on the session line, and decimals on
   the scorecard (per series/stage in parentheses, a «Desimalsum» line on
   the total card) — live, in «Mine økter» and on competition results.
5. **Persistence/compat**: the shot JSON gains an optional `tenth`, the
   snapshot a `decimalEntry` flag; old snapshots load unchanged and old
   apps ignore the new keys. No backend schema change (the payload rides
   opaque); scoreboards rank by the int columns exactly as before.
6. **Out of scope** (deferred): the 5–10 duel faces (Sprintluft/Storluft
   luftduell), decimals in statistics/records, editing earlier shots'
   tenths, decimal scoreboard columns, tenths for scanned shots.

## Verification

- `decimal_entry_test` (domain): geometry gate per face; set/replace/
  clear the tenth; derived tenths floor to the ring (spec 0001 vectors);
  manual pick overrides within the ring; a miss stays 0; exact tenths
  summation on series/stage/session; the session flag survives
  sealSeries; snapshot round-trip incl. equality and old-JSON defaults.
- `decimal_entry_flow_test` (widget + notifier): toggle offered only on
  capable programs, off by default, remembered through the store and
  seeded back; the picker sits on the last shot with the derived value;
  picking updates the decimal sum but never the int; the picker moves
  with the last shot while earlier picks hold; drag keeps/re-derives the
  pick by the ring rule; non-decimal sessions are pixel-identical.
- `program_catalogue_test`/existing suites: unchanged behaviour outside
  decimal mode (all gates green).
