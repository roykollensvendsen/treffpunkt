# ADR-0015: Capture place behind a LocationService interface

- **Status:** Accepted — concrete `geolocator` implementation now wired
- **Date:** 2026-06-22

## Context
A recorded session must hold *where* it was shot (ADR-0012): GPS coordinates when
available and permitted, otherwise a place the shooter types in. Manual entry is
a full alternative, not just a fallback — a shooter on the range with location
denied, on a desktop browser, or who simply prefers to name the range must be
able to set up and shoot a session.

Reading a real device location means a cross-platform plugin (e.g. `geolocator`,
which supports web, Android and iOS). Such a plugin needs native permission
wiring — an Android manifest entry, an iOS `Info.plist` usage string, web
geolocation prompts — and platform setup that sits outside this slice's file
ownership and could destabilise the strict quality gates (analyze, build, test)
that must stay green, especially with a second feature merging in parallel.

## Decision
- Reach location through a small **`LocationService`** interface in the data
  layer — the same pattern as `AuthRepository` — so the presentation and domain
  layers never depend on a GPS plugin or platform APIs and tests inject a fake.
  Its `currentLocation()` reports a sealed **`LocationResult`** — `LocationFix`
  (coordinates) · `LocationDenied` · `LocationDeniedForever` ·
  `LocationUnavailable` — so callers `switch` exhaustively and the
  permanently-denied case cannot be forgotten. A second method,
  `openLocationSettings()`, opens the OS app settings; it is the only fix once a
  permission is permanently denied. Every non-fix outcome still degrades to
  manual entry — the sealed result only distinguishes them so the UI can offer
  the right affordance.
- The captured place is a pure-Dart **`Place`** value (a human `label` plus
  optional `latitude` / `longitude`), so a GPS fix can still be named and a typed
  label needs no coordinates — coordinates and label coexist (ADR-0012).
- **Graceful degradation is the contract:** a `null` location is normal, and the
  setup screen always offers manual entry, so the manual path is complete on its
  own.
- Provide a real **`GeolocatorLocationService`** backed by the cross-platform
  `geolocator` plugin (web + Android + iOS). It checks that location services
  are enabled, checks/requests permission, and only on a usable grant
  (`whileInUse` / `always`) fetches the current position with a high accuracy
  and a finite timeout; **every other outcome maps to a non-fix `LocationResult`
  (never an exception)** — services off / an unsupported platform / an
  indeterminate `unableToDetermine` / a timeout / any thrown error →
  `LocationUnavailable`; a fresh `denied` → `LocationDenied`;
  `deniedForever` → `LocationDeniedForever` — so graceful degradation to manual
  entry holds throughout. The static `Geolocator.*` API sits behind a tiny
  **`GeolocatorGateway`** seam (the real binding by default, now also forwarding
  `openAppSettings()` to `Geolocator.openAppSettings()`) so the permission /
  fallback and `deniedForever` mapping are unit-tested with a fake gateway; the
  wrapper itself is plugin glue and is not unit-tested.
- Wire it as the real default through `runTreffpunkt(..., locationService:)`,
  which overrides `locationServiceProvider`; `main()` passes the
  `GeolocatorLocationService`. When the parameter is omitted (widget tests, the
  integration harness) the `UnavailableLocationService` default stays, so no
  test reaches real GPS.

## Consequences
- The whole setup-and-capture flow is unit- and widget-testable with a fake
  service and a fixed clock — no real GPS, no platform channels in tests.
- The manual place path works on every platform today; "Bruk min posisjon" now
  reads a real fix where granted and still reports no fix (degrading to manual)
  for every denial or error, which the UI already handles.
- `geolocator` is the one new runtime dependency, confined to the data layer;
  the domain stays pure Dart and the presentation layer keeps depending only on
  the `LocationService` interface.
- **Platform permission setup** lands with the implementation:
  - Android (`android/app/src/main/AndroidManifest.xml`): `ACCESS_FINE_LOCATION`
    and `ACCESS_COARSE_LOCATION`.
  - iOS (`ios/Runner/Info.plist`): `NSLocationWhenInUseUsageDescription` with a
    short Norwegian rationale.
  - Web: no manifest entry — `geolocator_web` uses the browser Geolocation API,
    which only works in a **secure context (HTTPS)**; GitHub Pages and
    `localhost` qualify, so the deployed app and local dev both get a prompt.
- Permanently-denied permission (`deniedForever`) degrades to manual entry like
  any other non-fix, **and** the setup screen now offers an "Åpne innstillinger"
  (open settings) action — a SnackBar action calling
  `LocationService.openLocationSettings()` — since the OS settings are the only
  place that grant can be restored. The affordance is shown for
  `LocationDeniedForever` only; a fresh denial, no-fix or a successful fix never
  shows it. The `UnavailableLocationService` default is never permanently denied
  and its `openLocationSettings()` is a no-op, so tests and unsupported
  platforms see no settings prompt.

## Alternatives considered
- **Add `geolocator` in spec 0008's first slice:** deferred at the time — it
  pulls manifest / Info.plist / web setup in and risked the quality gates while
  a second feature merged in parallel; the interface let it land cleanly here as
  a localised follow-up, exactly as planned.
- **Call platform geolocation APIs directly from the widget:** rejected — it
  makes the screen untestable without real GPS and couples presentation to the
  platform, against the clean-layering and TDD process.
- **GPS-only, no manual entry:** rejected — it fails the core requirement that a
  shooter can record a place by hand when location is unavailable or denied.
