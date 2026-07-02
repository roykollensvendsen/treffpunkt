# Spec 0105 — Show the placed shots on the felt hold pictures in review

- **Status:** Accepted
- **Related:** forum thread «Norgesfelt» (idea, approved by the owner);
  specs 0080 (hit recording), 0082 (rounds in Mine økter), 0091 (explicit
  save), 0058 (ring review targets)

## Context

While recording a felt round the shooter sees every shot marked on the
hold picture — but the moment the round is finished, the review (the
end-of-round scorecard and the "Mine økter" detail) collapses to numbers
per hold. The positions are already stored: every saved round's snapshot
carries each shot's hold-space coordinates, figure and inner flag. The
domain expert asked for the review to show the targets with the hits, the
way the ring programs' scorecards show their series targets (spec 0058).

## Rationale

Pure reuse: the snapshot has the data, the recorder has the drawing. The
recorder's private marker is lifted to a shared `FeltShotMarker` and a
read-only `FeltHoldShotsView` (hold art + positioned markers, the same
scale mapping the recorder uses), so the recording and the review can
never disagree about what a shot looks like. `FeltScorecard` — already
shared by both review entry points — gains one optional parameter.

## Requirements

1. A shared `FeltShotMarker` (red = miss, green = inner, amber = hit) used
   by the recorder and the review alike.
2. `FeltHoldShotsView`: a read-only hold picture with a round's shots
   marked where they landed, in the hold's own pixel space.
3. `FeltScorecard` takes an optional `holds` (the snapshot's per-hold
   placed shots); when given, every hold row is followed by its picture
   with the shots. When omitted, the scorecard renders as before.
4. Both review entry points pass the shots: the end-of-round screen (from
   the live recording) and the "Mine økter" detail (from the stored
   snapshot) — synced rounds included, since the snapshot rides the sync.

## Verification

- `felt_record_screen_test`: finishing a round shows 8 hold pictures with
  the single hare hit marked.
- `felt_in_my_sessions_test`: opening a stored round's card shows the 8
  pictures and the stored inner hit's marker.
- Visual review by screenshot.
