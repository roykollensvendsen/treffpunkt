# Local setup

## Prerequisites
- Flutter (version pinned in `.fvmrc`), with web enabled.
- For docs and license checks: `mkdocs-material` and `reuse`
  (for example `pip install mkdocs-material reuse`).

## First-time setup

```sh
sh tool/setup.sh   # enables git hooks, runs `flutter pub get`
```

## Run and test

```sh
flutter run -d chrome                            # run in a browser
flutter test                                     # unit + widget tests
flutter test integration_test -d flutter-tester  # system tests (headless)
dart format .                                    # format
flutter analyze                                  # lints
mkdocs serve                                     # preview docs
reuse lint                                       # license compliance
```
