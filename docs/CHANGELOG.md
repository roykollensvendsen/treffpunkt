# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- You can now see which build of the app you are running. A discreet line at the
  bottom of the sign-in screen and the program picker shows the build version —
  the deploy's short commit and build time (e.g. "build a1b2c3d4 ·
  2026-06-23T17:30Z"), or "build dev" for a local build. So after a deploy you
  can confirm at a glance that you are on the latest build instead of a stale
  cached page, and report the exact build when something looks wrong. The
  version is the same one the cache-bust query uses, so the screen and the
  loaded assets always agree (spec 0028).
- The empty "Mine økter" screen is now welcoming and useful: when you have no
  saved sessions yet it shows a friendly note ("Ingen lagrede økter ennå"), a
  hint ("Fullfør en økt for å se den her.") and a "Velg program" button that
  takes you straight back to pick a program — so a first-time shooter is told
  what to do next instead of facing a bare line of text.
- You can now look back at your saved sessions. A new "Mine økter" screen (open
  it from the history button in the top bar) lists every session you have
  recorded, newest first: the ones already saved to your account and the ones
  still waiting to upload, each marked "Ikke synkronisert" until it syncs. Each
  card shows the program, when and where you shot it, the score and the weapon,
  and tapping one opens its full scorecard — the same per-stage and per-series
  (skive) breakdown you saw when you finished it. A session whose program is no
  longer available shows a friendly "Kan ikke vise denne økta" instead of
  failing (spec 0026).
- Finished sessions are never lost, even offline or signed out. When you
  complete a session it now joins a durable upload queue saved on your device,
  and the queue empties itself by uploading whenever it can: the moment you
  finish, the next time you open the app, and right after you sign in. So a
  session shot with no signal — or before you have signed in — uploads itself
  automatically later instead of vanishing. Uploading stays quiet and
  best-effort (it never blocks finishing, never crashes on a dropped
  connection), and the same session is never uploaded twice (spec 0025).
- When you are signed in, finishing a session now quietly saves it to your
  account in the cloud, so your results survive reinstalling the app or switching
  devices. The save never blocks finishing, never crashes if the connection
  drops, and re-saving the same session never makes a duplicate (spec 0024).
- The session scorecard now lists every target face (skive) on its own line:
  under each stage you see each series' score (ring total over its maximum, and
  the inner-ten count when there is one), kept subordinate to the per-stage
  subtotal and the grand total — so you can read each face's result the way a
  paper scorecard does (spec 0023).
- The shot you just fired now stands out: while shooting a series the most
  recently placed shot is ringed with a coloured halo on the target (at the same
  size as the others), and its row in the shots list is highlighted, so you can
  instantly see where your latest shot landed. As you place each new shot the
  emphasis moves to it. A shot you are dragging keeps its blue "moving" look
  (spec 0020).
- The app now works with a screen reader (TalkBack / VoiceOver). The target
  announces itself and how to use it, the series and session totals are read
  aloud in words ("Serie-sum: 87 av 100, 3 indre tiere") instead of loose
  digits, each shot row says its number and ring, and the stage header, the
  seal-series button, the program tiles and the resume / discard actions all
  carry clear spoken labels in Norwegian.
- The app now makes proper use of a wide screen. On a desktop, tablet or
  browser window the content no longer stretches edge-to-edge: it is held to a
  comfortable reading width and centred. On a wide shooting screen the target
  and the shot list / score now sit side by side, so you can see your shots
  next to the face without scrolling. On a phone everything looks exactly as
  before — one tidy column.
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

### Removed
- The 10 m air rifle is no longer offered in the program list. At the NSF domain
  expert's request, air rifle is dropped from the program picker (and its now
  orphaned air-rifle weapon class is removed). The scoring foundation it
  introduced is kept intact: spec 0001, the decimal-scoring rules, the
  `TargetGeometry.airRifle10m()` target and the `ProgramCatalogue.airRifle10m`
  reference all remain (the reference still resolves by name, so any session
  recorded before the change still loads) — air rifle is simply not in the
  offered list.
- The 50 m rifle and 300 m rifle programs (and their target faces and weapon
  classes) have been taken out. They had been seeded from ISSF geometry, but the
  NSF domain expert did not recognise them as Norwegian programs, so they rested
  on unconfirmed footing. They are removed entirely until NSF confirms a real
  50 m / 300 m rifle structure.

### Fixed
- A session you just finished now shows up in "Mine økter" right away. The list
  used to read your saved sessions once and never refresh, so if you opened the
  (empty) list, went back, completed a session and reopened, the finished
  session was missing until you fully restarted. The list now follows your live
  upload queue, so a just-completed session appears the moment it is recorded,
  and the synced sessions are re-read each time you open the screen. As a
  belt-and-suspenders guard it also reads the durable on-device queue that every
  finished session is saved to, so the just-completed session is shown reliably
  no matter how the recording screen is wired internally (spec 0026).
- The home screen is now fully Norwegian: the title reads "Velg program" and the
  program subtitles count "skudd" instead of "shots".
- Pinch-to-zoom on the target now works on phones in any direction: while a
  finger is on the target the page stops scrolling, so a two-finger pinch (even a
  vertical one) zooms the target instead of being swallowed by the page scroll,
  and a single finger pans it when zoomed (spec 0022).
- Zooming and panning the target now work reliably on web and desktop: while the
  mouse / trackpad pointer is over the target, the wheel zoom and the drag pan
  go to the target instead of scrolling the page, and moving the pointer off it
  restores normal page scrolling (spec 0021).
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
