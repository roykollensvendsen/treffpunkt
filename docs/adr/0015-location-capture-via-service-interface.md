# ADR-0015: Capture place behind a LocationService interface

- **Status:** Accepted
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
  layer — the same pattern as `AuthRepository`. It exposes one method that
  returns the current location or `null` (no fix / denied / unsupported), so the
  presentation and domain layers never depend on a GPS plugin or platform APIs
  and tests inject a fake.
- The captured place is a pure-Dart **`Place`** value (a human `label` plus
  optional `latitude` / `longitude`), so a GPS fix can still be named and a typed
  label needs no coordinates — coordinates and label coexist (ADR-0012).
- **Graceful degradation is the contract:** a `null` location is normal, and the
  setup screen always offers manual entry, so the manual path is complete on its
  own.
- For now bind the default to an **`UnavailableLocationService`** that always
  returns `null`. The real `geolocator`-backed implementation, with its native
  permission setup, is a **follow-up** (spec 0008, Open questions) so this slice
  ships fully green without native churn or a new runtime dependency.

## Consequences
- The whole setup-and-capture flow is unit- and widget-testable with a fake
  service and a fixed clock — no real GPS, no platform channels in tests.
- The manual place path works on every platform today; "Bruk min posisjon"
  reports no fix until the plugin is wired, which the UI already handles.
- Adding `geolocator` later is a localised change: one new `LocationService`
  implementation plus its manifest / Info.plist permission strings, swapped in at
  the provider override — no domain or screen changes.
- No new dependency enters `pubspec.yaml` in this slice, so the gates and the
  parallel merge stay simple.

## Alternatives considered
- **Add `geolocator` now and wire native permissions:** deferred — it pulls
  manifest / Info.plist / web setup into this slice, risks the quality gates, and
  touches files outside this feature's ownership; the interface lets it land
  cleanly later.
- **Call platform geolocation APIs directly from the widget:** rejected — it
  makes the screen untestable without real GPS and couples presentation to the
  platform, against the clean-layering and TDD process.
- **GPS-only, no manual entry:** rejected — it fails the core requirement that a
  shooter can record a place by hand when location is unavailable or denied.
