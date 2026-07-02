# Spec 0096 — Norwegian throughout, and a consistency sweep

- **Status:** Accepted
- **Related:** the July 2026 UI analysis (bundle 1); specs 0001/0007 (the
  oldest screens carrying English), 0033 (delete confirmations), 0026/0090
  (empty states)

## Context

The UI analysis found the app's voice breaks in its oldest screens: the
shooting screen and the weapon picker are half English, sign-in mixes
languages, and Material's own date/time pickers render in English because no
localization is configured. Around them, per-feature reimplementations have
drifted: three date formats, three empty-state patterns, unconfirmed
destructive actions in the forum and on the resume cards, and small colour /
label / punctuation divergences.

## Requirements

1. **Norwegian everywhere the app speaks**: the shooting screen (Skudd,
   SERIESUM, ØKTSUM, «Økt så langt», «Økt fullført», norsk skive-hint), the
   weapon picker («Legg til våpen», «Navn», «Klasse», «Avbryt», «Lagre»,
   «Ingen våpen for dette programmet ennå.»), and sign-in («Logg på med
   Google», norsk feilmelding).
2. **Material localization**: `flutter_localizations` with `nb` locale, so
   date/time pickers, tooltips and semantics speak Norwegian.
3. **One date format** for meta lines: `dd.MM.yyyy HH:mm` via one shared
   helper (`norDateTime`), used by session/felt cards, detail captions and
   the setup field.
4. **Destructive actions confirm**: deleting a forum thread/post asks the
   same «Slett …?» / «Handlingen kan ikke angres.» dialog the rest of the
   app uses, and discarding an in-progress round («Forkast lagret økt», ring
   and felt) asks before wiping.
5. **One empty-state widget** (icon + title + hint + optional CTA — the Mine
   økter pattern) used by competitions, notifications, statistics and the
   empty category.
6. Small alignments: both resume cards use `secondaryContainer`; the theme
   option reads «Følg systemet» everywhere; snackbars end with a period; a
   shared `kMaxContentWidth` constant replaces the literal 700s; the felt
   card in Mine økter drops its misleading crosshair leading icon so ring
   and felt rows align.

## Rationale

All of this is voice and pattern unification — no behaviour change beyond
the new confirmations. Shared helpers (`norDateTime`, `EmptyState`,
`kMaxContentWidth`) are introduced exactly where three or more copies had
already drifted, per the reuse rule.

## Verification

### System tests
- Updated string expectations across the affected suites (series, weapons,
  sign-in, felt, notifications, statistics).
- New: forum thread/post delete shows the confirm dialog (Avbryt keeps,
  Slett deletes); discarding a resume card asks first (ring and felt).
- The date-picker locale is exercised implicitly by existing setup tests
  under the `nb` localizations.

## Open questions
- None.
