# ADR-0001: Flutter for the cross-platform frontend

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
Treffpunkt must run in the browser and on Android and iOS, ideally from one
codebase. Its core interaction is a custom touch canvas: tap to place a shot,
see the score live, long-press to move a shot, swipe between targets. It must
also adapt to different screen sizes.

## Decision
Build the app with **Flutter** (Dart), targeting web, Android and iOS from a
single codebase.

## Consequences
- `CustomPaint` + gesture detectors give precise, performant control of the
  target rendering and hit-testing.
- Strong testing story: unit, widget and `integration_test` (system) tests.
- Building and signing iOS still requires macOS (handled in CI later).

## Alternatives considered
- **React Native + Expo:** strong too, but Flutter's canvas/gesture model fits
  the target interaction more directly.
- **PWA only:** cheapest, but the weakest "native" feel on iOS.
