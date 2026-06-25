<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0024: Drop PWA standalone display so Google sign-in works on iOS

- **Status:** Accepted
- **Date:** 2026-06-25

## Context

Google blocks OAuth from embedded/standalone webviews ("403:
disallowed_useragent", User-Agent based). Our web app shipped `display:
standalone` + `mobile-web-app-capable`, so an iOS **"Add to Home Screen"** launch
ran as a standalone webview without Safari's UA → Google 403. Android opens
installed PWAs in a Chrome Custom Tab (allowed), so it worked there — an
iOS-only failure that broke sign-in for users who "saved the app" to the home
screen (spec 0042). A normal Safari tab works (supabase does a top-level
redirect carrying Safari's UA).

## Decision

- **Serve the web app as a normal browser document**, not an installable
  standalone PWA: `web/manifest.json` `display: browser` and remove the
  `mobile-web-app-capable` meta from `web/index.html`. iOS home-screen launches
  then open in **real Safari**, where Google sign-in succeeds.
- **Detect the residual blocked contexts and guide the user.** A pure
  `oauthBlockedHere(userAgent, isStandalone)` check, fed by a small
  `BrowserEnvironment` web-interop seam (confined to one `_web.dart` behind a
  conditional import), drives a sign-in-screen notice ("open in Safari/Chrome" +
  copy-link) for in-app browsers (Messenger/Instagram …) and any
  already-installed standalone icons.

## Consequences

- Adding Treffpunkt to the iOS home screen now opens Safari → Google sign-in
  works; the recurring iOS 403 is fixed at the source.
- The home-screen icon loses the "fullscreen installed-app feel" — an acceptable
  trade, since in that mode sign-in was *broken*. A genuine installed app with a
  native, Google-approved sign-in (ASWebAuthenticationSession / Custom Tabs) is
  the later native build.
- One new direct dependency, `package:web` (already transitive), used only in the
  single web-interop file; mobile/test builds use the stub.
- Users who already added the old standalone PWA must remove and re-add the icon
  to get the Safari-launch behaviour; until then the in-app/standalone notice
  guides them.

## Alternatives considered

- **Keep standalone + only show the notice:** rejected — it leaves the home-screen
  sign-in broken and merely explains the failure; dropping standalone *fixes* it.
- **A different web sign-in (Google Identity Services / FedCM / One Tap):**
  rejected for now — a larger auth change; the manifest fix + notice resolves the
  reported problem with far less risk.
- **Native app immediately:** deferred — it's the real long-term answer (pappa's
  #5) but out of scope for an urgent sign-in fix.
