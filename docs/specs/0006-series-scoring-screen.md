# Spec 0006 — Series scoring screen

- **Status:** Accepted
- **Related:** spec 0004 (series domain), ADR-0012 (session model), ADR-0003
  (Riverpod), spec 0002 (move a placed shot)

## Context

A scorecard shows a series at a glance: the target with its hits, a numbered
shot list and a series total. This spec turns that into the app's main scoring
screen, replacing the single-shot target screen. The screen is
discipline-agnostic (driven by a `Program`) and shipped with 10 m air rifle; the
25 m pistol target (spec 0005) lights up the inner-ten markers.

## Requirements

1. The screen shows the program name, a meta line (discipline · caliber), the
   interactive target, a numbered shots list (two columns), a series-total card
   and a legend.
2. Tapping the target places the next shot, up to the series capacity; the shots
   list and total update live.
3. Long-pressing a placed shot picks it up (it turns blue) and dragging moves it,
   with the score updating — spec 0002's behaviour, now for any shot in the
   series.
4. Each placed shot shows its ring score; pending shots show a dash; inner tens
   show a marker.
5. The total card shows the running sum and the maximum; once the series is
   complete a ✓ action seals it (no further edits) and the card marks it
   complete.
6. The signed-in app opens on this screen for the 10 m air-rifle program.
7. Riverpod state; discipline-agnostic via a `Program`; passes
   `very_good_analysis`; testable headlessly.

## Rationale

One screen that both records and summarises matches the original brief ("see the
score as you place each shot") and the scorecard sketch. Series state lives in a
Riverpod `Notifier` (`seriesProvider`) seeded from the program; `SeriesScreen`
re-hosts it in a scope carrying the program override, so the screen is
self-contained and testable. Keeping the view discipline-agnostic means the 25 m
pistol target is a data change, not a new screen.

## Design

```
lib/features/scoring/presentation/
  series_providers.dart  currentProgramProvider (throws by default),
                         seriesProvider (SeriesNotifier: place / pickUp /
                         dragTo / drop / seal), SeriesRecording state
  series_painter.dart    draws rings, bull and every shot (the dragged one blue)
  series_target.dart     tap to place, long-press to move; px <-> mm mapping
  series_screen.dart     SeriesScreen (scope + program override) wrapping
                         SeriesView (app bar + ✓, meta, target, list, total,
                         legend)
```

The single-shot target screen / canvas / painter / provider are removed.

## Verification

### Widget tests
- `series_target_test`: tapping places shots one after another; a long-press
  picks up a placed shot and dragging moves it.
- `series_screen_test`: starts with the program name, an empty list and a zero
  total with sealing disabled; placing a shot updates the list ("1 / 10") and the
  total ("10"); completing the series enables sealing and marks it complete.

### System tests
- `place_shot_test`: boot signed-in (fake), the empty series shows total 0;
  tapping the centre scores a ten ("1 / 10", total "10").
- `auth_flow_test`: the gate still lands on the air-rifle series screen when
  signed in.

## Open questions
- Weapon and date / place in the meta line arrive with specs 0007 / 0008.
- Several series per stage and advancing to a fresh face (the full "patch and
  reshoot" loop) build on this once the `Session` aggregate lands (0009).
