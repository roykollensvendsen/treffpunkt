# Local setup

## Prerequisites
- Flutter (version pinned in `.fvmrc`), with web enabled.
- For docs and license checks: `mkdocs-material` and `reuse`
  (for example `pip install mkdocs-material reuse`).
- To run the **real** app: copy `config/env.example.json` to
  `config/env.local.json` (gitignored) and fill in your Supabase URL +
  publishable key (see ADR-0010 and spec 0003). Tests run without it.

## First-time setup

```sh
sh tool/setup.sh   # enables git hooks, runs `flutter pub get`
```

## Run and test

```sh
flutter run -d chrome \
  --dart-define-from-file=config/env.local.json  # run the real app (needs config)
flutter test                                     # unit + widget tests
sh tool/integration_test.sh                      # system tests (headless)
dart format .                                    # format
flutter analyze                                  # lints
mkdocs serve                                     # preview docs
reuse lint                                       # license compliance
```
