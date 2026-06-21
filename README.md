# Treffpunkt

Record and score your shots on official Norwegian Shooting Federation
(NSF / ISSF) targets, then compare results across competitions.

You tap the screen where each shot landed; Treffpunkt shows the score live, lets
you nudge a shot with a long-press, and swipes you on to the next target. It runs
on the web, Android and iOS from a single Flutter codebase.

## Status
Early development. Increment 0 is a walking skeleton: the 10 m air-rifle target
with tap-to-place decimal scoring. See [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Quick start
```sh
sh tool/setup.sh        # enable git hooks + fetch packages
flutter run -d chrome   # run in a browser
flutter test            # unit + widget tests
```

## Documentation
- Users: [`docs/user/`](docs/user/)
- Developers / architecture: [`docs/dev/`](docs/dev/)
- Specifications: [`docs/specs/`](docs/specs/) · Decisions: [`docs/adr/`](docs/adr/)

Build the docs site locally with `mkdocs serve` (needs `mkdocs-material`).

## Tooling
- Flutter (pinned in `.fvmrc`), Dart.
- Lints: `very_good_analysis`. Format: `dart format`.
- Licensing: GPLv3, REUSE-compliant (`reuse lint`).

## License
GPL-3.0-or-later. See [`COPYING`](COPYING).
