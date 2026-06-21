# Contributing to Treffpunkt

Thanks for helping build Treffpunkt. This project holds itself to a few simple,
strict rules. They keep the history clean and the codebase easy to read.

## 1. Get set up
```sh
sh tool/setup.sh
```
This enables the project git hooks and fetches packages. You also need the
Flutter SDK on your `PATH`. For local license and docs checks, install `reuse`
and `mkdocs-material` (for example in a virtualenv).

## 2. Work spec-first, test-first
- **Spec first.** Before building a feature, add or update a spec in
  `docs/specs/` (copy `docs/specs/TEMPLATE.md`). It must include *Rationale* and
  *Verification* sections; Verification lists the concrete test cases.
- **TDD red/green/refactor.** Write the failing test, then the smallest code to
  pass it, then clean up. Keep domain logic in pure-Dart `domain/` folders so it
  can be tested without a Flutter runtime.

## 3. Code style — readable and modular
- Small, single-responsibility files and functions with descriptive names.
- Public APIs carry doc comments (enforced by the `public_member_api_docs` lint).
- Formatting is `dart format` (no debates). Linting is `very_good_analysis` with
  strict type checks. CI runs `dart format --set-exit-if-changed .` and
  `flutter analyze --fatal-infos --fatal-warnings`.

## 4. Commits — Conventional Commits, plain language, no AI references
Subject line:
```
<type>(<scope>): <imperative description>
```
Types: `feat fix docs test refactor chore ci build perf style revert`.

The **body opens with one paragraph in everyday language** (what changed and
why, understandable to a non-developer), then the technical details. Reference
the spec, e.g. `Refs: spec 0001`.

**Do not** mention AI agents/assistants anywhere in the message (no
`Co-Authored-By: Claude`, no `🤖`). The `commit-msg` hook and CI reject these.

Example:
```
feat(scoring): add decimal scoring for 10m air rifle

In plain terms: the app can now give a precise decimal score (like 10.4) for
each shot, the way an electronic target does, instead of only whole rings.

Computes the decimal value from the shot's distance to centre per spec 0001's
verification table. Pure Dart, fully unit-tested.

Refs: spec 0001
```

## 5. Pull requests
Use the PR template. Lead with **What & why (plain language)**, then technical
details and testing notes. Update the relevant **user and developer docs** in
the same PR — docs are part of "done".

## 6. Definition of done (CI must be green)
- `commitlint` — every commit follows the rules above.
- `license` — `reuse lint` passes (every file has SPDX info).
- `static` — `dart format` clean, `flutter analyze` clean.
- `test` — unit + system tests pass.
- `docs` — `mkdocs build --strict` and `dart doc` succeed.
