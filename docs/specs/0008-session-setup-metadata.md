# Spec 0008 — Session setup: date, time and place

- **Status:** Accepted
- **Related:** ADR-0012 (session domain model), ADR-0013 (offline-first),
  ADR-0015 (location capture), spec 0006 (series scoring screen), spec 0009
  (persistence, later)

## Context

A recorded session must capture *when* and *where* it happened (ADR-0012). The
shooter sets this up **before** shooting: they pick a program, then a short setup
step records the date and time (defaulting to now) and the place — taken from GPS
when it is available and permitted, or typed in by hand. Manual entry is a full
alternative, not just a fallback: a shooter with location denied, on a desktop,
or who simply prefers to type the range name must be able to proceed
("fra GPS hvis tilgjengelig eller skrive inn selv"). The captured metadata then
travels with the session so it can later be shown and uploaded.

This spec adds the metadata value types, threads one optional field through the
`Session` aggregate, and inserts a setup screen between the program picker and
the shooting screen. It does **not** add persistence (spec 0009) and does not
ship a wired-up native GPS plugin (see Open questions / ADR-0015).

## Requirements

1. A pure-Dart `Place` value type carries a human `label` and optional
   `latitude` / `longitude`, with value equality and `copyWith`.
2. A pure-Dart `SessionMetadata` value type carries a `capturedAt` `DateTime`
   (supplied by the caller — the domain never reads the wall clock) and an
   optional `place`, with value equality and `copyWith`.
3. The `Session` aggregate carries an optional `SessionMetadata? metadata`,
   accepted by `Session.start` and preserved across `sealSeries`, with no change
   to existing scoring or progression behaviour.
4. After a program is picked and before shooting starts, a setup screen lets the
   shooter:
   1. see and edit the date and time (defaulting to now);
   2. fill the place from device location ("Bruk min posisjon") **or** type a
      label by hand;
   3. proceed even when location is unavailable or denied — the manual label
      alone is enough to continue.
5. Confirming builds a `SessionMetadata` from the chosen date/time and place and
   navigates on to the shooting screen, which records the session with that
   metadata attached.
6. Location is reached through a small `LocationService` interface so tests
   inject a fake — no real GPS in unit or widget tests.
7. New domain code is pure Dart; everything passes `very_good_analysis`
   (strict) and is testable headlessly; existing tests stay green.

## Rationale

Metadata is a small **value object** the session merely holds, so it lands as one
optional field on the aggregate (additive, behaviour-preserving) plus two pure
value types — mirroring how `Shot` and the program definition stay pure and
unit-testable. Capture is a presentation concern, so the setup screen lives in
`presentation/` and the only impure input (the clock) is injected as a
`DateTime`, while GPS sits behind a `data`-layer `LocationService` interface
exactly like `AuthRepository`. That keeps the domain deterministic and lets the
widget tests drive the whole flow with a fake service and a fixed clock.

Place keeps coordinates **and** a label together (ADR-0012: "a place may hold
coordinates and a human label at once"), so a GPS fix can still be named, and a
typed label needs no coordinates. The metadata flows into the session through a
new `currentSessionMetadataProvider` overridden per screen — the same scope
pattern `SeriesScreen` already uses for the program — so threading it through
needs no change to the notifier's shape beyond reading one more provider.

Wiring a real cross-platform GPS plugin (e.g. `geolocator`) needs native
manifest / Info.plist permission entries and per-platform setup that this slice's
file ownership and quality gates deliberately keep out of scope. The abstraction
plus a default "location unavailable" implementation delivers the full manual
path now and leaves a clean seam to drop the plugin in later; ADR-0015 records
that decision.

## Design

```
lib/features/scoring/
  domain/
    place.dart             Place(label, latitude?, longitude?) + copyWith + ==
    session_metadata.dart  SessionMetadata(capturedAt, place?) + copyWith + ==
    session.dart           + optional `SessionMetadata? metadata` (start/seal)
  data/
    location_service.dart  LocationService interface + DeviceLocation value;
                           UnavailableLocationService (default: degrades)
  presentation/
    session_setup_screen.dart  SessionSetupScreen(program): date/time + place,
                               confirm -> SeriesScreen(program, metadata)
    session_providers.dart     + currentSessionMetadataProvider (Provider, null);
                               SessionNotifier.build reads it into Session.start
    series_screen.dart         + `metadata` param overriding the provider
    program_picker_screen.dart tap -> SessionSetupScreen (not SeriesScreen)
```

Flow: picker → `SessionSetupScreen` (clock seeds the date/time; the shooter taps
"Bruk min posisjon" to ask the injected `LocationService`, or types a label) →
on confirm, build `SessionMetadata(capturedAt, place)` and push
`SeriesScreen(program, metadata: metadata)`. `SeriesScreen` overrides
`currentSessionMetadataProvider`; `SessionNotifier.build` reads it and calls
`Session.start(program, metadata: metadata)`. The session scorecard shows the
captured place/date as a small caption.

`LocationService.currentLocation()` returns a nullable `DeviceLocation`
(lat/lng): `null` means "no fix / denied / unsupported", which the screen treats
as graceful degradation (it keeps the manual label). The default binding is
`UnavailableLocationService`, which always returns `null`; the real geolocator
implementation is the follow-up in ADR-0015.

## Verification

### Unit tests

- `place_test`: equal `Place`s compare equal and share a hash; `copyWith`
  replaces only the named fields (label, latitude, longitude) and leaves the
  rest; a label-only place has null coordinates.
- `session_metadata_test`: equal metadata compare equal and share a hash;
  `copyWith` replaces only `capturedAt` / `place`; the type holds the supplied
  `DateTime` verbatim (no clock reads).
- `session_test` (extended): `Session.start` defaults `metadata` to `null`;
  `Session.start(program, metadata: m)` exposes `m`; `sealSeries` preserves the
  metadata onto the returned session.
- `session_providers_test` (extended): with `currentSessionMetadataProvider`
  overridden, the recording's session carries that metadata; with no override it
  is `null`.
- `date_time_merge_test`: the pure `mergeDateTime` helper combines a picked date
  and a picked time onto a base moment — a new date and time replace both;
  changing only the time keeps the date; changing only the date keeps the time;
  passing neither returns the base unchanged; the base's UTC/local mode is kept.

### Widget tests

- `session_setup_screen_test`: the screen shows the program name and a confirm
  action; the date/time defaults from the injected clock; tapping "Bruk min
  posisjon" with a fake service that returns a fix fills the place field with the
  formatted coordinates (`'59.9000, 10.7000'`) and, after confirming, threads a
  place carrying that exact latitude/longitude into the recorded session; a GPS
  fix does **not** overwrite an already-typed label — the label is preserved in
  the field and the resulting `Place` keeps the label *and* the fix's
  coordinates; with a fake that returns `null` the shooter can still type a label
  and confirm; confirming navigates to the series target.
- `series_screen_test` (extended): after completing a one-series program to the
  scorecard, the caption under `sessionMetadataKey` reads
  `'YYYY-MM-DD HH:MM · <label>'` when a place is present, shows the timestamp
  only (no `·`) when the place is empty, and is absent entirely when the session
  has no metadata.
- `program_picker_screen_test` (extended): tapping a program opens the setup
  screen (not the series screen directly).

### System tests

- `place_shot_test` / `auth_flow_test` keep passing: the signed-in gate still
  reaches the air-rifle flow (now via the setup step) and a centre shot scores a
  ten.

## Open questions

- Real GPS is deferred: this ships the `LocationService` abstraction, the manual
  path in full, and a default "unavailable" implementation. Dropping in
  `geolocator` (web + mobile) with its native permission setup is the follow-up
  recorded in ADR-0015; until then "Bruk min posisjon" reports no fix and the
  shooter types the place.
- Persisting the metadata with the session and surfacing it on upload is spec
  0009 (offline-first persistence); this spec only attaches it in memory.
- A place picker / map and saved favourite ranges are later polish.
