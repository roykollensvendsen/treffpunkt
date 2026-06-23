<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0018: Theme mode — system default, persisted locally

- **Status:** Accepted
- **Date:** 2026-06-23

## Context

The app shipped with one light theme. Shooters want a dark UI and, just as
often, want the app to follow whatever their device/browser already uses. We
need a theme choice (system / light / dark) that is remembered across restarts,
without adding architecture the app does not already have (spec 0030).

## Decision

- **Model the choice as Flutter's `ThemeMode`** (`system` / `light` / `dark`)
  and feed it to `MaterialApp.themeMode`, with `theme` and `darkTheme` generated
  from the same teal seed at the two brightnesses. No custom toggle or bespoke
  palette — the framework already models exactly these three states.
- **Default to `ThemeMode.system`**, so a fresh install follows the device with
  no action and an explicit choice is an override, not a prerequisite.
- **Persist via a `ThemeModeStore` seam**, mirroring `WeaponStore` (ADR-0016 /
  spec 0019): an interface with an `InMemoryThemeModeStore` default (tests, fresh
  app) and a `SharedPreferencesThemeModeStore` that `main()` wires in. The
  `ThemeMode.name` is stored under a single key; an absent or unrecognised value
  loads as `system`.
- **Seed at launch, not in `build`.** `main()` reads the saved choice once
  (prefs is already awaited there) and overrides `initialThemeModeProvider`, so
  the notifier stays synchronous and there is no first-frame flash of the wrong
  theme. Saving is best-effort (it never blocks the UI), like the weapons store.

## Consequences

- The theme survives a restart and a reinstall-free device theme change is
  honoured automatically while `system` is selected.
- The data layer is testable with no real storage; only the real app touches
  `shared_preferences`, consistent with every other store.
- Adding more app-wide preferences later can follow the same `settings` feature
  and store/notifier/seed shape.

## Alternatives considered

- **A two-state light/dark toggle (no "system"):** rejected — it forces a choice
  and ignores the device default, the most common expectation on web and mobile.
- **A custom `enum` and palette instead of `ThemeMode`/`ColorScheme.fromSeed`:**
  rejected — `ThemeMode` + `MaterialApp` already wire this end to end; a bespoke
  model would be more code for less framework support.
- **Loading the saved theme inside `build` (async):** rejected — it flashes the
  wrong theme on the first frame; eager loading in `main()` (as spec 0019 does
  for weapons) avoids it.
