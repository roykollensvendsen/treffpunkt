# Spec 0100 — Visual identity, part 1: theme, target icon, score figures

- **Status:** Accepted
- **Related:** the July 2026 UI analysis (bundle 3); specs 0030 (themes),
  0090 (chart palette), 0023 (inner-ten motif)

## Context

The app's look was default Material with a teal seed — nothing on screen
said shooting except the targets, four unrelated hue families competed
(teal chrome, amber markers, blue/green chart, felt orange), and two map
icons meant "shoot".

## Requirements

1. **Theme**: both themes reseed from a deep blue-graphite; a `TreffColors`
   `ThemeExtension` carries the semantic sport colours — the **latest shot
   in signal red**, older shots neutral steel-blue, the dragged shot amber,
   and a slightly warm target paper — with a light and a dark set.
2. **Markers follow the range-monitor convention** (what Megalink/SIUS
   monitors taught every shooter): the newest shot pops in signal red with
   its halo, older shots recede; colours come from the theme, not
   hard-coded Material constants. The marker pair passes the palette
   validator on the paper colour, and the spec-0090 chart palette is
   revalidated against the new surfaces.
3. **One shoot glyph**: a drawn `TargetIcon` (rings + bull) replaces the
   map icons on «Skyt løypa», «Skyt nå» and the «Skyt igjen» hero;
   `my_location` means geolocation and nothing else.
4. **Score figures are tabular**: every score line through
   `innerTenScoreText` and the fontSize-40 hero totals render with tabular
   figures, so digits align in lists and totals never shift width.
5. **Podium tints**: ranks 1–3 on the competition scoreboard wear gold,
   silver and bronze avatar tints.

## Verification

- `series_painter_test`: the halo and drag colours come from
  `TreffColors.light`; existing marker rules unchanged.
- Palette validator: chart colours pass on the new light/dark surfaces;
  the marker pair passes on the paper colour (recorded in this spec's PR).
- Existing suites cover the icon/typography swaps (no behavioural change);
  visual review by screenshot.
