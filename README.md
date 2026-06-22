# Treffpunkt

Record and score your shots on official Norwegian Shooting Federation
(NSF / ISSF) targets, then compare results across competitions.

You tap the screen where each shot landed; Treffpunkt builds up the series shot
by shot — each shot's score and the running total — and lets you nudge a shot
with a long-press. It runs on the web, Android and iOS from a single Flutter
codebase.

## Status
Early development. The app records a 10 m air-rifle series on a tap-to-place
target with live whole-ring scoring and a series total, behind Google sign-in.
See [`docs/ROADMAP.md`](docs/ROADMAP.md).

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
