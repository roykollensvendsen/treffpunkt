# Spec 0028 — Build-version stamp in the app

- **Status:** Accepted
- **Related:** spec 0027 (cache-bust the web deploy entry), ADR-0010 (secrets &
  config injection via `--dart-define`), ADR-0011 (deploy to GitHub Pages),
  `.github/workflows/deploy.yml`, `docs/dev/deploy.md`

## Context

Spec 0027 makes a browser refresh after a deploy fetch the build that was just
published (versioned `?v=<sha>` entry URLs, a guaranteed cache miss). What it
does **not** do is let a human *confirm* which build is actually running. After
recurring cache/staleness confusion — "did my fix ship? am I looking at the new
build or a stale one?" — a shooter has no way to read the running build back to a
commit, so a stale page and a fresh one look identical.

This spec makes the running build **human-readable**: the app shows, discreetly,
the deploy's short commit SHA and build time, so anyone can glance at the screen
and confirm they are on the latest build (and report the exact build when
something looks wrong). It complements spec 0027 — that makes refreshes load the
latest build; this makes the loaded build legible.

## Requirements

1. **The build version is injected at build time.** The deploy passes the short
   commit SHA and a build timestamp into the app via `--dart-define`
   (`BUILD_SHA`, `BUILD_TIME`), read with `String.fromEnvironment` exactly as
   the Supabase config is (ADR-0010). The SHA is the same `${GITHUB_SHA::8}`
   8-character short SHA that spec 0027 stamps into the `?v=` cache-bust query,
   so the displayed SHA **equals** the cache-bust version.
2. **A `dev` fallback for local/unstamped builds.** When `BUILD_SHA` is not
   provided (a local `flutter run`/`flutter build`, and the CI `ci.yml` build),
   the SHA reads `dev` and the build time is empty, so the app still shows a
   sensible label without any define.
3. **A pure, testable label.** A pure function `BuildInfo.formatLabel(sha, time)`
   composes the human label: `build <sha>` when no time is given, and
   `build <sha> · <time>` when a time is given. It is pure (no environment reads)
   so it is unit-testable; the `const` `String.fromEnvironment` values cannot be
   overridden from a test, so the function — not the constants — carries the
   logic.
4. **The stamp is shown, discreetly, on the always-reachable screens.** A small,
   muted, centred `BuildVersionLabel` widget (keyed `buildVersionKey`, with a
   `Semantics` label) shows `BuildInfo.label`. It appears at the bottom of the
   pre-sign-in **sign-in screen** and at the bottom of the signed-in **program
   picker** (the home screen), as a discreet footer that does not disturb the
   existing layout, keys or tests.

## Rationale

**Reuse the `--dart-define` channel (ADR-0010).** The app already reads
compile-time configuration through `String.fromEnvironment` in
`lib/config/app_config.dart`; the build version is the same kind of
build-time-known value, so it rides the same channel rather than introducing a
generated file or a runtime fetch. No new dependency, no extra build step beyond
two more defines.

**The same short SHA as spec 0027.** Using `${GITHUB_SHA::8}` — the exact token
spec 0027 stamps into `?v=` — means the SHA a shooter reads on screen is the same
SHA in the asset URLs the browser fetched. One value, two surfaces: the URL
forces the fresh build, the on-screen stamp confirms it. Any per-build-unique
token would identify a build, but matching 0027 lets the two line up by eye.

**A pure `formatLabel`, tested directly.** `String.fromEnvironment` is a `const`
read resolved at compile time and cannot be injected in a unit test, so testing
`BuildInfo.sha`/`time` end-to-end would only ever exercise the defaults. Pulling
the formatting into a pure function makes the *logic* (the `·` separator, the
no-time case) testable in isolation, while a widget test covers that the label
actually renders on each screen (where it reads the `dev` default).

**A reusable, muted footer widget.** Wrapping the label in one small
`BuildVersionLabel` (its own key + `Semantics`) keeps the two screens identical,
keeps the styling in one place (`bodySmall` in `onSurfaceVariant`), and makes it
trivial to drop onto a third screen later. "Discreet" is deliberate: it is a
diagnostic aid, not chrome, so it is muted and out of the way.

**Stamp only the deploy, not CI.** The `deploy.yml` "Build web" step gains the
two defines; the `ci.yml` build is left on the `dev` fallback. CI builds are not
shipped to users, so they need no real SHA, and leaving CI untouched keeps its
build command minimal and its meaning ("does it compile") unchanged.

## Design

```
lib/config/build_info.dart
  abstract final class BuildInfo
    static const String sha  = String.fromEnvironment('BUILD_SHA',
                                                       defaultValue: 'dev');
    static const String time = String.fromEnvironment('BUILD_TIME'); // '' if unset
    static String get label  => formatLabel(sha, time);
    static String formatLabel(String sha, String time) =>
        time.isEmpty ? 'build $sha' : 'build $sha · $time';   // PURE

lib/features/<…>/presentation/build_version_label.dart  (or core)
  const Key buildVersionKey = ValueKey<String>('buildVersion');
  class BuildVersionLabel extends StatelessWidget        // muted, centred
    Semantics(label: 'Bygg: ${BuildInfo.label}',
      Text(BuildInfo.label,
        style: bodySmall.copyWith(color: onSurfaceVariant), …))

sign_in_screen.dart       — BuildVersionLabel pinned at the bottom (footer)
program_picker_screen.dart — BuildVersionLabel below the program list (footer)

.github/workflows/deploy.yml  ("Build web" step, same run: | block)
  flutter build web --release --pwa-strategy=none --base-href /treffpunkt/ \
    --dart-define=SUPABASE_URL=…  --dart-define=SUPABASE_PUBLISHABLE_KEY=… \
    --dart-define=BUILD_SHA="${GITHUB_SHA::8}" \
    --dart-define=BUILD_TIME="$(date -u +%Y-%m-%dT%H:%MZ)"
  (then the unchanged cache-bust step, which uses the same ${GITHUB_SHA::8})
```

The displayed `BUILD_SHA` is `${GITHUB_SHA::8}` — byte-for-byte the version
spec 0027's `tool/cache_bust_web.sh build/web "${GITHUB_SHA::8}"` stamps into the
`?v=` query — so the on-screen stamp and the asset URLs always agree. `BUILD_TIME`
is the deploy's UTC build minute (`date -u +%Y-%m-%dT%H:%MZ`).

## Verification

### Unit tests (`test/config/build_info_test.dart`)

- `BuildInfo.formatLabel('abc1234', '')` returns `'build abc1234'` (no time → no
  separator).
- `BuildInfo.formatLabel('abc1234', '2026-06-23T17:30Z')` returns
  `'build abc1234 · 2026-06-23T17:30Z'` (time → `·`-joined).
- `BuildInfo.sha` defaults to `'dev'` in a test build (no define), and
  `BuildInfo.label` is `'build dev'` — the local/unstamped fallback.

### Widget tests

- The **sign-in screen** renders exactly one `buildVersionKey`, and its text
  contains `'build '` (it reads `'build dev'` in tests).
- The **program picker** renders exactly one `buildVersionKey` (same `'build '`
  assertion), without disturbing the existing program tiles, resume card or
  "My sessions" action.

### Unchanged

The existing ~302 unit, widget and system tests stay green: the footer adds a
keyed leaf and changes no existing key, finder or navigation. The `deploy.yml`
change is a build-flag addition verified by YAML validity and by the SHA
matching spec 0027's cache-bust version (no Dart logic to test).

## Open questions

- A dedicated "About" screen could later show the full SHA, the build time and a
  link to the commit on GitHub; for now a one-line footer is enough to defuse the
  staleness confusion.
- If `flutter build web` ever emits a build identifier of its own, the
  `BUILD_TIME` define could be dropped in favour of it; today there is none.
