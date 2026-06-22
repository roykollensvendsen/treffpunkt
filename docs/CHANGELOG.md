# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- The app now makes proper use of a wide screen. On a desktop, tablet or
  browser window the content no longer stretches edge-to-edge: it is held to a
  comfortable reading width and centred. On a wide shooting screen the target
  and the shot list / score now sit side by side, so you can see your shots
  next to the face without scrolling. On a phone everything looks exactly as
  before — one tidy column.
- Spec 0018 and the 300 m rifle target: Treffpunkt now knows the official ISSF
  300 m rifle face (the long-range full-bore target) — its ten rings, the inner
  ten ("X"), the black and the centre-fire gauge edge, sourced to the ISSF rules.
  A "300 m Rifle" program (60 shots in six 10-shot series, scored to whole rings
  plus inner tens) joins the catalogue. The geometry is locked behind a vector
  table of shot positions to expected ring, so it can never silently drift. The
  exact NSF course of fire, whether NSF scores it to a decimal, and the black and
  the centre-fire gauge edge are written down as confirm-with-the-father flags.
- Spec 0017 and the 50 m rifle target: Treffpunkt now knows the official ISSF
  50 m rifle face (the .22 smallbore target) — its ten rings, the inner ten
  ("X"), the black and the .22 gauge edge, sourced to the ISSF rules. A "50 m
  Rifle Prone" program (60 shots in six 10-shot series, scored to whole rings
  plus inner tens) joins the catalogue. The geometry is locked behind a vector
  table of shot positions to expected ring, so it can never silently drift. The
  exact NSF course of fire, whether NSF scores it to a decimal, and the black
  and calibre are written down as confirm-with-the-father flags.
- When location permission is turned off for good, the session-setup step now
  offers an "Åpne innstillinger" button that jumps straight to the app's
  location settings — the only place that permission can be switched back on.
  Every other case (a one-off "not now", location switched off, a browser
  without GPS) still quietly falls back to typing the place by hand.
- Your personal weapons now stick around: the guns you add are saved on-device
  and are still there after you close and reopen the app, with no network needed.
  Storage sits behind a `WeaponStore` interface (`shared_preferences`), mirroring
  the session store — the list is loaded once at launch and rewritten whenever you
  add or remove a weapon.
- Spec 0005: the 25 m pistol target and scoring is now written down. It
  documents both faces — the precision face (rings 1–10) and the rapid / duel
  face (rings 5–10) — with their ring sizes, the inner ten ("X"), the black, and
  the .22 vs centre-fire gauge edge, sourced to the ISSF rules. The existing
  geometry is locked behind a vector table of shot positions to expected ring
  for both faces, so it can never silently drift. No app behaviour changes.
- Use your device's location to fill the place in the session-setup step:
  "Bruk min posisjon" now reads a real GPS fix (browser, Android and iOS) via the
  `geolocator` plugin, asking for permission the first time. Typing the place by
  hand stays a full alternative — if location is off, the permission is denied or
  anything goes wrong, the app quietly falls back to manual entry. Browser
  geolocation needs a secure (HTTPS) page, which the deployed app and `localhost`
  both provide.
- Offline session persistence: a whole session — program, weapon, place and time,
  every sealed series and the shots already placed on the series in progress — is
  saved on-device with no network and survives closing the app. Reopening shows a
  "Fortsett økt" card that restores the session to exactly where you left it.
  Storage sits behind a `SessionStore` interface (`shared_preferences`); target
  geometry is rebuilt from the program catalogue, not stored.
- Choose the weapon in the session-setup step: the setup screen now lists the
  weapons permitted for the chosen program, the picked gun travels with the
  session, and its name shows on the scorecard caption.
- A guided multi-stage flow: choosing a program runs the whole thing — you shoot
  each series, the app advances to a fresh face (and switches the target between
  stages, e.g. finpistol presisjon → duell), shows a stage/series counter and the
  running total, and finishes to a session scorecard.
- Zoom in on the target for precise shot placement — with the on-target ＋ / −
  buttons (any device, incl. mouse), a pinch on a touch screen, or a two-finger
  trackpad scroll; pan with two fingers when zoomed. Tapping to place and
  long-pressing to move a shot still work.
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
