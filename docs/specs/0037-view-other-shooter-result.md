<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0037 — View another shooter's full scorecard

- **Status:** Accepted
- **Related:** spec 0012 (shoot for a competition), spec 0013 (live scoreboard),
  spec 0023 (per-series results), spec 0026 (My sessions scorecard), spec 0010
  (RLS)

## Context

The competition scoreboard (spec 0013) shows one ranked row per shooter with
their total. The NSF domain expert asked to **see the full result — every stage
and series — for the other shooters too**, not just the total. The full detail is
already on the client: each `CompetitionResult` carries the complete session
`payload` (the `SessionSnapshot` JSON), which `resultsOf`/`watchResults` already
read and every participant may read (spec 0010 `can_read_competition`). So this is
pure presentation — no backend, no extra fetch, no migration.

## Requirements

1. **Tap a shooter.** A scoreboard row is tappable.
2. **Their full scorecard.** Tapping opens that shooter's scorecard — the same
   per-stage / per-series breakdown a shooter sees for their own session (spec
   0026) — rebuilt from the result payload, titled with the shooter's name.
3. **Graceful on bad data.** A payload that cannot be rebuilt shows a message
   instead of crashing.

## Design

- **`SessionScorecard` gains an optional `title`**
  (`lib/features/scoring/presentation/series_screen.dart`):
  `AppBar(title: Text(title ?? program.name))` — backward-safe, so the
  live-completion and "Mine økter" cards are unchanged, and the new screen titles
  the card with the shooter's name.
- **`CompetitionResultScreen`** (`competition_result_screen.dart`): takes a
  `CompetitionResult`, rebuilds `SessionSnapshot.fromJson(result.payload)`, scores
  it with `ScoringService`, and renders `SessionScorecard` — the same trio
  `SessionDetailScreen` uses (spec 0026). The title is
  `result.profile?.displayName ?? 'Ukjent skytter'`; an unrebuildable payload
  shows `unreadableResultKey`.
- **The row opens it.** `_ResultRow` in `competitions_screen.dart` gets an
  `onTap` pushing `CompetitionResultScreen(result)`; the row already has
  `resultRowKey(id)`.

## Rationale

The result payload already travels with the scoreboard, so the detail needs no
new query and reuses the exact scorecard widget and rebuild path the personal
"My sessions" detail uses — consistent rendering, minimal new surface. RLS already
authorises a participant to read every result in a competition they can read, so
no policy change is involved.

## Verification

### Widget (`competitions_screen_test.dart`)
- *tapping a shooter opens their full scorecard* — submit a result built from a
  **real** session (valid payload); tap the shooter's `resultRowKey` →
  `CompetitionResultScreen` shows the scorecard (`sessionCompleteKey`) titled with
  the shooter's name.
- *an unreadable payload shows a message* (`unreadableResultKey`), not a crash.
- existing scoreboard / ranking tests stay green.

### Manual (local Supabase, two users)
User B shoots for a competition; as user A, open the competition, tap B on the
scoreboard, and see B's full scorecard (every stage/series) rebuilt from the
payload.

## Known limitations / next increment

Shows the same numeric per-stage/per-series scorecard as a shooter's own session;
a visual replay of each target face with the shot positions is a later
enhancement. The scoreboard still ranks best-per-shooter, so the opened card is
that shooter's best result.
