# Testing

Treffpunkt follows the testing pyramid.

| Level  | Where                    | Runs with                                         |
| ------ | ------------------------ | ------------------------------------------------- |
| Unit   | `test/**/domain`         | `flutter test`                                    |
| Widget | `test/**/presentation`   | `flutter test`                                    |
| System | `integration_test/`      | `sh tool/integration_test.sh` (per file, headless) |
| Web smoke | `tool/web_smoke_test.sh` | `sh tool/web_smoke_test.sh` (headless Chrome)   |

## Principles
- Domain logic is pure Dart, tested without a Flutter runtime.
- Each spec's Verification section lists the exact cases; tests implement them
  verbatim (see `test/features/scoring/domain/scoring_service_test.dart`).
- Write the failing test first (red), then the smallest code to pass it (green).
- The web smoke test loads the built app in headless Chrome and asserts the
  Flutter engine boots without fatal JS errors — catching browser-only
  regressions (e.g. a missing JS SDK) that flutter-tester cannot.

## Commands

```sh
flutter test                  # unit + widget
sh tool/integration_test.sh   # system tests (headless, one file at a time)
```
