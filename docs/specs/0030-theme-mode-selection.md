<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0030 — Theme mode (light / dark)

- **Status:** Accepted
- **Related:** ADR-0018 (theme-mode persistence), ADR-0016 (local store via
  `shared_preferences`), ADR-0003 (Riverpod), spec 0019 (personal weapon
  persistence — the store/notifier pattern this mirrors)

## Context

The app shipped with a single light theme. Shooters on a dark phone or browser —
often at an indoor range or in the evening — want a dark UI, and many simply
want the app to follow whatever their device already does. Until now there was
no way to do either.

This spec adds a theme choice with three options — **follow the system/browser
theme** (the default), **light**, or **dark** — surfaced from the app bar and
**persisted** so it survives a restart. It deliberately reuses the established
store + launch-seed + notifier pattern (spec 0019) so it touches no real storage
in tests and never flashes the wrong theme on the first frame.

## Requirements

1. **System default.** With no saved choice the app follows the system/browser
   theme (`ThemeMode.system`): a dark device shows the dark theme, a light
   device the light theme, with no action from the shooter.
2. **Explicit selection.** The shooter can choose **System**, **Lyst** (light)
   or **Mørkt** (dark) from a theme action in the app bar (and from the sign-in
   screen, so it is reachable before signing in). The current choice is shown.
3. **Both palettes share the brand.** Light and dark `ThemeData` are generated
   from the same teal seed (`ColorScheme.fromSeed`, differing only in
   `Brightness`), so the dark theme matches the light one.
4. **Persistence.** The chosen `ThemeMode` is saved locally (its name —
   `system` / `light` / `dark`) and reloaded at launch, so it survives a
   restart. An absent or unrecognised stored value loads as `system`. Saving is
   best-effort (it never blocks the UI), exactly like the weapons store (spec
   0019). The store is an interface with an in-memory fake and a
   `shared_preferences`-backed implementation; only the real app uses the latter
   (ADR-0016 / ADR-0018).
5. **No first-frame flash.** `main()` loads the saved choice once before
   `runTreffpunkt` and seeds the notifier, so the app starts on the right theme
   without rendering the wrong one first (mirroring spec 0019's eager load).

## Rationale

`ThemeMode` already models exactly the three states wanted (system / light /
dark), and `MaterialApp`'s `theme` + `darkTheme` + `themeMode` already wire it
end to end — so the smallest correct design is to persist a single `ThemeMode`
and feed it to `MaterialApp`, rather than invent a custom toggle or a bespoke
palette. Following the system theme by default is the least-surprising behaviour
(the app matches the rest of the device out of the box) while still allowing an
explicit override. Reusing the spec 0019 store/notifier/seed pattern keeps the
data layer testable without real storage and avoids a first-frame flash, at no
new architectural cost.

## Verification

### Unit / widget tests

- **`theme_mode_store_test.dart`**:
  - `InMemoryThemeModeStore` defaults to `system` and round-trips a saved mode.
  - `SharedPreferencesThemeModeStore` (driven by `setMockInitialValues`):
    defaults to `system` when unset; round-trips every `ThemeMode`; persists
    across a fresh store on the same storage (a simulated restart); an
    unrecognised stored value falls back to `system`.
- **`theme_providers_test.dart`**: the notifier defaults to `system`, seeds its
  initial state from the launch value, and `select` both updates the state and
  persists the choice to the store.
- **`theme_mode_button_test.dart`**: the button defaults to following the system
  theme; it offers System / Lyst / Mørkt; selecting **Mørkt** switches the
  `MaterialApp`'s `themeMode` to dark **and** persists the choice through the
  store.

### Manual

- On a dark-set device/browser, a fresh install shows the dark theme; on a light
  one, the light theme — with no selection.
- Choosing **Mørkt** then fully restarting the app keeps the dark theme;
  choosing **System** returns to following the device.
