<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0146 — «Spander en kaffe»: Vipps-støttekort på forsiden

## Summary

The front page (the program picker) gets a small, unobtrusive card at the
bottom of its list: **«Spander en kaffe ☕»** — tapping it opens the
developer's personal Vipps payment link
(`https://qr.vipps.no/box/aabe6bd3-f162-4abb-869a-b5b6a504486d/pay-in`).
On a phone the link opens straight into Vipps with the recipient set; in a
desktop browser it shows the Vipps QR page, which can be scanned with the
phone.

## Rationale

- Family and club members who enjoy the app have asked how they can chip
  in; a Vipps link is the zero-friction Norwegian answer. It sits **last**
  on the front page so it never competes with the shooting flows.
- The app has never opened external links; that ability arrives behind a
  seam (`LinkOpener`, default unavailable, `main()` binds the
  `url_launcher` implementation) exactly like the camera and scanner seams
  (specs 0039/0040) — so widget tests assert the launched URL without any
  platform plumbing, and a platform without a handler degrades to a
  snackbar hint instead of a crash.
- The link itself lives in `lib/config/` — one obvious place to change if
  the Vipps box is ever rotated.

## Design

- `lib/config/support_links.dart`: `vippsCoffeeUri` (the URL above).
- `lib/core/data/link_opener.dart`: `LinkOpener` seam +
  `UnavailableLinkOpener` (always `false`); `url_launcher_link_opener.dart`
  is the only file importing `url_launcher` (external-application mode).
  Riverpod: `linkOpenerProvider` defaults unavailable; `main()` overrides.
- The card: `Card` + `ListTile` (coffee icon, title «Spander en kaffe»,
  subtitle «Liker du Treffpunkt? Vipps en kaffe til utviklerne.»), keyed
  for tests, placed after the category cards in the picker's list. A
  failed open shows «Kunne ikke åpne Vipps-lenken.» via the guarded
  snackbar helper.

## Verification

Widget tests (`program_picker_screen_test.dart`):

1. The front page shows the coffee card, below the category cards.
2. Tapping the card opens exactly `vippsCoffeeUri` through the
   `LinkOpener` seam (recording fake).
3. When the opener reports failure, the snackbar hint shows and nothing
   crashes.

System tests: none — `integration_test/` does not exercise the front-page
cards beyond navigation, which is untouched.
