<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0042 — Fix Google sign-in on iOS (webview / PWA 403)

- **Status:** Accepted
- **Related:** spec 0003 (Google sign-in), ADR-0011 (GitHub Pages deploy),
  ADR-0024 (the drop-standalone decision)

## Context

Some shooters hit Google's **"403: disallowed_useragent"** when signing in — on
**iOS**, while **Android works**. Google refuses OAuth from an **embedded or
standalone webview** (it's User-Agent based). Two things in our app caused it on
iOS:

1. The web app shipped `"display": "standalone"` (`web/manifest.json`) and
   `<meta name="mobile-web-app-capable" content="yes">` (`web/index.html`), so
   **"Add to Home Screen" on iOS launched a standalone webview** with no Safari
   user-agent → Google 403. Android opens an installed PWA in a Chrome Custom Tab
   (allowed) → works.
2. Opening the shared link inside an **in-app browser** (Messenger, Instagram …)
   is the same block.

A real Safari tab works (supabase_flutter does a top-level `_self` redirect, so
the request carries Safari's UA) — which is why it worked for the owner and his
father, who type the address in Safari.

## Requirements

1. **Home-screen / installs open in the real browser.** Adding Treffpunkt to the
   iOS home screen must open it in Safari (where Google sign-in works), not a
   standalone webview.
2. **Guidance in blocked contexts.** When the app *is* running in an in-app or
   standalone webview, the sign-in screen shows a clear notice — "open in Safari
   or Chrome" — with a **copy-link** action, instead of letting the user hit
   Google's cryptic 403.
3. **No regression.** A normal Safari / Chrome / iOS-Chrome tab shows no notice
   and signs in exactly as before.

## Design

- **Config (the iOS fix):** `web/manifest.json` `display: standalone` →
  `browser`; `web/index.html` drops the `mobile-web-app-capable` meta. iOS
  home-screen launches now open in full Safari.
- **Pure detection** (`features/auth/domain/embedded_browser.dart`):
  `oauthBlockedHere({required isStandalone, userAgent})` → `true` for a standalone
  launch or a known in-app-browser UA (`FBAN`/`FBAV`/`Instagram`/`MicroMessenger`
  …); normal browsers → `false`. Unit-tested.
- **Browser-environment seam** (`core/platform/browser_environment.dart` +
  `_web.dart`/`_stub.dart`, conditional import): reads `navigator.userAgent`, the
  standalone display mode (`matchMedia('(display-mode: standalone)')` +
  `navigator.standalone`) and the URL through `package:web` on web; an empty
  const off-web and in tests. A `browserEnvironmentProvider` is overridden in
  `main()`.
- **Sign-in notice** (`features/auth/presentation/sign_in_screen.dart`): when
  blocked, a banner above the Google button explains it and offers **Kopier
  lenke** (the fragment-free current URL via `Clipboard`); the Google button
  stays (in case of a false positive).

## Verification

- **Unit (`embedded_browser_test`):** in-app UAs (Messenger/Instagram/WeChat) and
  `isStandalone` → blocked; iOS Safari, iOS Chrome (`CriOS`), desktop Chrome, null
  UA → not blocked.
- **Widget (`sign_in_screen_test`):** the notice + copy-link show only in a
  blocked context; copy puts the fragment-free URL on the clipboard; a normal
  browser shows no notice; existing sign-in tests stay green.
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs --strict`,
  and the **web build compiles** (the interop is behind a conditional import).
- **Manual (the real proof, after deploy):** on an iPhone, **Add to Home Screen**
  → open from the icon → it opens in **Safari** → Google sign-in **succeeds**.
  Open the link inside **Messenger** → the notice appears.

## Known limitations / next increment

Someone who already added the *old* standalone PWA keeps launching standalone
until they remove and re-add the icon — the in-app/standalone notice covers them
meanwhile. A true installed experience with native, Google-approved sign-in is the
later native app (pappa's #5).
