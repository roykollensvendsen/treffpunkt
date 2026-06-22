# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Project scaffolding: a Flutter app for web, Android and iOS.
- Development process: spec-driven workflow, TDD, Conventional Commits enforced
  by a commit-msg hook, strict lints (very_good_analysis), GPLv3 + REUSE
  licensing, and a MkDocs documentation site.
- CI pipeline: commit lint, license check, static analysis, tests, docs build.
- Spec 0001 and a pure-Dart scoring domain for the 10 m air-rifle target
  (integer and decimal scoring), fully unit-tested.
- A tap-to-place target canvas showing the live decimal score.
- Moving a placed shot by long-pressing it and dragging; the marker turns blue
  while being dragged (spec 0002).
- Google sign-in via Supabase: a sign-in gate with sign-out, behind a fakeable
  `AuthRepository` so the feature is testable without real credentials
  (spec 0003, ADR-0010).
- Planning for richer recording: an expanded roadmap (sessions, weapons,
  location, offline-first) and two decisions — the shooting-session domain model
  Program → Stages → Series → Shots (ADR-0012) and offline-first recording with
  deferred sync (ADR-0013).
- A series scoring screen (replacing the single-shot target screen): place a
  series of shots on the target and watch each shot's score and the running
  total in a numbered list, then seal the series once it is complete
  (specs 0004 + 0006).
- The pure-Dart series core: a `Program`, an immutable `Series`, and series
  scoring (per-shot ring, inner-ten count, running total and maximum), with an
  optional inner-ten ring on the target geometry (spec 0004).

### Fixed
- The web app crashed on launch (`Cannot read properties of undefined (reading
  'init')`) because `supabase_flutter` pulls in the Passkeys plugin whose Web
  SDK was missing. Vendored the SDK (`web/bundle.js`) and load it in
  `web/index.html`.
- Google sign-in on web never reached the app: PKCE's code+verifier exchange is
  unreliable on web. Switched to the implicit OAuth flow (session via the URL
  fragment) and rebuilt the auth state as a single-subscription `Notifier`, so a
  pending exchange no longer loops on a spinner and auth errors fall back to the
  sign-in screen.
