# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Pinch to zoom in on the target (and pan with two fingers when zoomed) for
  precise shot placement; tapping to place and long-pressing to move a shot
  still work.
- A program picker: the signed-in app opens a list of the official programs, and
  choosing one opens its target (the new pistol faces show their inner-ten
  markers). Each program opens its first stage as a series for now.
- The real program catalogue in code: 10 m air pistol, 25 m standard pistol,
  fin- and grovpistol (precision + duell on two faces) and 50 m fripistol, plus
  the air-pistol and 25 m rapid/silhouette (rings 5–10) target geometries.
- A guided-flow session domain: a pure-Dart `Session` aggregate that walks a
  program's stages and series — advancing to a fresh face, then the next stage —
  and rolls up per-stage and total scores (ADR-0012).
- The program-definition model (`ProgramDefinition` / `StageDefinition`) and a
  seeded catalogue, plus the 25 m pistol precision target geometry and its
  scoring vectors (ADR-0012).
- A program catalogue (`docs/reference/program-catalogue.md`): the authoritative,
  ISSF-sourced list of the in-scope concentric-ring shooting programs and their
  target faces, with confirm-with-the-father flags for NSF-specific values.
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
- New web deploys are no longer served stale: the Flutter service worker is
  disabled for the GitHub Pages build (`--pwa-strategy=none`), and a small
  killswitch in `web/index.html` unregisters any worker left from an earlier build
  and clears its caches, so a reload picks up the latest version instead of a
  cached old one.
- The web app crashed on launch (`Cannot read properties of undefined (reading
  'init')`) because `supabase_flutter` pulls in the Passkeys plugin whose Web
  SDK was missing. Vendored the SDK (`web/bundle.js`) and load it in
  `web/index.html`.
- Google sign-in on web never reached the app: PKCE's code+verifier exchange is
  unreliable on web. Switched to the implicit OAuth flow (session via the URL
  fragment) and rebuilt the auth state as a single-subscription `Notifier`, so a
  pending exchange no longer loops on a spinner and auth errors fall back to the
  sign-in screen.
