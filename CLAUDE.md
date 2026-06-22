# Treffpunkt — project guide for contributors and AI pair-programmers

Treffpunkt lets shooters record their hits on official Norwegian Shooting
Federation (NSF / ISSF) targets, see the score update live as they place each
shot, and compare results on per-competition and cross-competition
leaderboards.

This file is the durable "north star": read it at the start of every working
session.

## Stack
- **Flutter** — one codebase for web, Android and iOS (and desktop).
- **Supabase** — Postgres, Google sign-in, Realtime and Row-Level Security.
- **Riverpod** — state management (see `docs/adr/0003-state-management-riverpod.md`).
- Feature-first, clean layering. The **domain layer is pure Dart** (no Flutter
  imports) so the scoring rules are unit-testable in isolation.

## Non-negotiable process (state of the art from commit #1)
1. **Spec first.** No feature without a spec in `docs/specs/` that has
   *Rationale* and *Verification* sections. Verification lists the exact unit +
   system test cases.
2. **TDD red/green.** Write the failing test first, then the smallest code that
   passes, then refactor.
3. **Conventional Commits**, atomic, one logical change each. Enforced by a
   `commit-msg` hook and in CI. **No AI-agent references in commit messages.**
4. **Plain language first.** Every commit body and PR description opens with a
   one-paragraph everyday explanation of *what and why*, then the specifics.
5. **Decisions are ADRs** in `docs/adr/`.
6. **Docs are part of done.** Update the user and developer docs in the same PR.
7. **Quality gates** must be green: `dart format`, `flutter analyze`
   (very_good_analysis, strict), unit + system tests, `reuse lint`,
   `mkdocs build --strict`.

## Repository map
- `lib/features/<feature>/{domain,data,presentation}/` — feature code.
  - `domain/` — pure Dart entities + rules (no Flutter imports).
  - `data/` — repositories, Supabase access.
  - `presentation/` — widgets, painters, Riverpod providers.
- `lib/core/`, `lib/config/` — shared building blocks.
- `test/` — unit + widget tests (mirrors `lib/`).
- `integration_test/` — system tests (run headless in CI).
- `docs/specs/` — specifications. `docs/adr/` — architecture decisions.
- `docs/user/` — user guide. `docs/dev/` — architecture & design.
- `tool/` — dev scripts (`commit_lint.sh`, `setup.sh`).
- `.githooks/` — git hooks (enable with `tool/setup.sh`).

## First-time setup
```sh
sh tool/setup.sh   # enables hooks, runs `flutter pub get`
```

## Everyday commands
```sh
flutter test                    # unit + widget tests
flutter test integration_test   # system tests
dart format .                   # format
flutter analyze                 # lints (fatal in CI)
mkdocs serve                    # preview docs (needs mkdocs-material)
```

## Current milestone
Increment 1 core is complete: a shooter can record a full official-program
session offline — picking the program, the weapon and the place/time, shooting it
through its stages and series to a scorecard — and the recording survives an app
restart (the in-progress series included), resumable from a "Fortsett økt" card.
This covers specs 0001 (air-rifle scoring), 0003 (auth), 0004/0006 (series
domain + scorecard), 0007 (weapons), 0008 (session metadata) and 0009 (offline
persistence, `SessionStore` over `shared_preferences`). Still open in Increment 1:
the dedicated 25 m pistol target/scoring spec (0005).

Next is Increment 2: competitions, deferred sync of completed sessions, and
shared scoreboards (specs 0010–0015). See `docs/ROADMAP.md` and
`docs/reference/program-catalogue.md`.
