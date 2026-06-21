# ADR-0007: Code standard — very_good_analysis + dart format

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
We want a strict, consistent, state-of-the-art code standard enforced
automatically rather than by review nitpicking.

## Decision
Use **`very_good_analysis`** lints with strict language modes (`strict-casts`,
`strict-inference`, `strict-raw-types`) and canonical **`dart format`**. CI runs
`dart format --set-exit-if-changed .` and `flutter analyze --fatal-infos
--fatal-warnings`, so every hint is a hard failure.

## Consequences
- A high, uniform quality bar; issues caught early and mechanically.
- Some initial friction adapting code to the strict rules.

## Alternatives considered
- **`flutter_lints`:** the official baseline, but less strict than desired.
