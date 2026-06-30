# ADR-0026: Web push for notifications, with no iOS coverage for now

- **Status:** Accepted
- **Date:** 2026-06-30

## Context
Users want to be alerted to a new chat message or a competition invitation even
when Treffpunkt is closed (spec 0060). Treffpunkt is a Flutter **web** app served
from GitHub Pages; there is no native build yet (pappa's roadmap item #5).

The browser-native way to alert a closed web app is the **Push API**: a service
worker plus VAPID-signed pushes. It works on Android and desktop Chrome/Firefox/
Edge. On **iOS Safari**, web push only works when the site is installed as a
**standalone PWA** ("Add to Home Screen" with `display: standalone`). But ADR-0024
deliberately set `display: browser` and dropped the standalone meta tags, because
a standalone iOS webview has no Safari user-agent and Google's OAuth blocks it
("disallowed_useragent", spec 0042). So on iOS we must choose between **working
sign-in** and **web push** — we cannot have both from a web app.

The alternatives to web push are email notifications (works everywhere, but needs
an email-sending provider account, a verified domain, and risks being spammy) and
native push via FCM/APNs (needs the native app we have not built).

## Decision
Use the **web Push API** for notifications. Accept that **iOS users get no push**
until there is a native build; do not re-enable standalone for the web app. Keep
the standalone-free configuration (ADR-0024) so sign-in keeps working on iPhone.

Hide the notification control where push cannot work, so iOS (and any browser
without the Push API) sees no dead button rather than a broken promise.

## Consequences
- Android and desktop users get real system notifications; the feature is built
  on web standards with no third-party push vendor.
- iPhone users — including the primary tester — do **not** get notifications for
  now. This is the explicit trade-off; the native build is the path to iOS push.
- A service worker returns to the app. To avoid reopening the stale-cache problem
  ADR-0024/spec 0027 closed, the push worker (`web/push_sw.js`) handles only
  `push`/`notificationclick` and has **no `fetch` handler**, so it caches
  nothing; `index.html` is narrowed to unregister only Flutter's own worker.

## Alternatives considered
- **Email notifications.** Universal (covers iPhone) and works with the app
  closed, but requires standing up an email provider (API key + verified sender
  domain) and careful debouncing to avoid spam. Kept as a possible future
  complement; not chosen now because the user asked for in-app/browser push.
- **Re-enable standalone PWA for iOS push.** Would reintroduce the Google OAuth
  403 on iPhone that spec 0042 fixed — a worse regression than missing push.
- **Native FCM/APNs.** The right long-term answer for iOS, but blocked on the
  native build that does not exist yet.
