# Spec 0090 — Statistikk: progress curves per exercise

- **Status:** Accepted
- **Related:** spec 0026 (Mine økter), 0082/0083 (felt rounds local + synced),
  0085 (points · inner display)

## Context

A shooter wants to see whether they are improving at a specific exercise.
The scores exist (ring sessions and NorgesFelt rounds, local and synced) but
there is no view across sessions. The domain expert asks for **curves**:
points and inner hits per completed session of one exercise, in one
coordinate system, different colours, with a legend — no time axis, the
x-axis is simply the sessions in chronological order.

## Requirements

1. "Mine økter" gets a **Statistikk** action that opens a statistics screen.
2. The screen offers the shooter's **exercises** — every program (and the
   NorgesFelt course) with at least one completed, dated session — and shows
   the selected exercise's curves.
3. The chart plots **two series in one coordinate system**: the session's
   **poengsum** and its **innertreff** count, in different colours with a
   **legend** naming both.
4. The x-axis is the shooter's sessions of that exercise **in chronological
   order** (1, 2, 3 …) — no time axis. Sessions without a recorded date are
   left out (their position in the order is unknowable).
5. Both local (pending) and synced sessions count, deduplicated by id — the
   same union "Mine økter" shows.
6. Tapping (or dragging on) the chart inspects the nearest session, showing
   its number, points and inner count; the last value of each series is
   directly labelled so the values are readable without interaction.
7. The chart is announced to screen readers with a text summary (exercise,
   session count, first/last/best points).
8. An exercise with no dated sessions shows an empty state, not an empty
   chart.

## Rationale

- **One shared y-axis** (0 up to the largest value in view, nice ticks) —
  never a dual-axis chart; the inner curve sits low on ring programs' scale,
  which is faithful: the two numbers share a unit magnitude the shooter
  knows.
- **Colours are computed, not eyeballed** (dataviz method): series colours
  were validated with the palette validator against the app's real surfaces
  (light `#F4FBF8`, dark `#0E1513`): Poengsum blue `#2A78D6` light /
  `#3987E5` dark; Innertreff aqua `#1BAF7A` light / `#199E70` dark. All
  checks pass; aqua-on-light sits below 3:1 contrast, so the **relief rule**
  applies — met by the direct value labels (req 6) drawn in text ink.
- Legend and labels wear **text colours**, never the series colour; the
  coloured chip beside the label carries identity.
- Mark specs: 2 px lines, 8 px markers, recessive gridlines.

## Design

- Domain (`exercise_progress.dart`, pure Dart): `ProgressSample`
  (`capturedAt`, `points`, `inner`) and `progressSeries(samples)` — sorts
  dated samples ascending and drops undated ones. The screen maps ring
  `SessionRecord`s (total / innerTens) and felt `FeltSessionRecord`s
  (tally points / inner) to samples and groups them by exercise name.
- `StatisticsScreen` (scoring/presentation): exercise dropdown (catalogue
  order, NorgesFelt last, only exercises with data), legend row, and a
  `ProgressChart` widget — a `CustomPaint` with a `GestureDetector` for the
  tap/drag inspector. Series colours resolve on `Theme.brightness`.
- Entry: an app-bar `IconButton` (chart icon, tooltip "Statistikk") on
  "Mine økter".

## Verification

### Unit tests
- `exercise_progress_test`: samples sort by date ascending; undated samples
  are dropped; values map through unchanged.

### System tests
- `statistics_screen_test`:
  - the Mine økter action opens the screen (key `statisticsButton`);
  - with ring sessions of two programs and a felt round, the dropdown offers
    exactly those exercises and switching updates the chart;
  - the legend shows "Poengsum" and "Innertreff";
  - the chart paints one `CustomPaint` (two series) and tapping it shows the
    nearest session's values ("Økt N · P poeng · M Ⓧ");
  - an exercise-less state shows the empty message;
  - the chart carries the text summary in its semantics.

## Open questions
- None.
