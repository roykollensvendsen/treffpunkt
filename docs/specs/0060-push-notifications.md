# Spec 0060 — Push notifications for new messages and invitations

- **Status:** Accepted — Increment A shipped; Increment B code landed (awaiting
  the hosted VAPID/function/trigger configuration, see `docs/dev/deploy.md`)
- **Related:** spec 0042 (no standalone PWA, for OAuth), spec 0051 (chat),
  spec 0010 (competitions & invitations), ADR-0026 (web push, no iOS).

## Context
A user only learns about a **new chat message** or a **competition invitation**
when the app happens to be open. We add **push notifications** so the browser
alerts them even when Treffpunkt is closed — a system notification that, tapped,
opens the relevant competition.

This is the **web Push API** (a service worker + VAPID). It works on **Android
and desktop** Chrome/Firefox/Edge. It does **not** work on **iOS Safari** unless
the app is installed as a standalone PWA — which we deliberately avoid because
standalone breaks Google sign-in (spec 0042). So iPhone users do not get push
until there is a native build; this is recorded in ADR-0026.

## Requirements
1. A signed-in user can **turn notifications on/off** with one control. Turning
   them on asks the browser for permission and registers a push subscription;
   turning them off removes it.
2. While on, the user receives a system notification for:
   - a **new chat message** in a competition they are in (not their own messages);
   - a **competition invitation** addressed to them.
3. Tapping a notification opens the app (the relevant competition where known).
4. The control is **hidden** where push cannot work (browser without the Push
   API, or no VAPID key configured) — never a dead button.

## Increments
- **A (this spec, shipped):** the subscription lifecycle — opt-in control,
  service worker, `push_subscriptions` table, client subscribe/unsubscribe. No
  notification is sent yet, but subscriptions are captured and the worker is in
  place.
- **B (code landed):** server delivery — the `notify` Supabase Edge Function,
  triggered by inserts on `competition_messages` / `competition_invitations`,
  sends the web push to each recipient's subscriptions (VAPID), pruning dead
  ones. The trigger migration is a **no-op until configured** (it reads the
  function URL/secret from database settings), and the function is inert until
  deployed — so the code is safe to ship ahead of the hosted setup
  (`docs/dev/deploy.md`). Recipients: a message notifies the competition's other
  members (not the sender); an invitation notifies the invited user (by email →
  user; a not-yet-registered invitee has nobody to notify).

## Rationale
**A dedicated, cache-free service worker.** The web build ships
`--pwa-strategy=none` and `index.html` unregisters Flutter's worker so a stale
cache can never serve an old build (spec 0027). Push needs a worker, so we add a
**separate** `web/push_sw.js` that handles only `push` and `notificationclick`
and has **no `fetch` handler** — it caches nothing, so it cannot reintroduce the
stale-build problem. `index.html` is narrowed to unregister only Flutter's
worker, leaving `push_sw.js` alone.

**The platform seam is a conditional import**, like the browser environment
(spec 0042). A pure `WebPush` interface (`isSupported`, `currentSubscription`,
`subscribe`, `unsubscribe`) has a `_web` implementation over `package:web` +
`dart:js_interop` and a `_stub` that reports unsupported off-web and in tests.
A fake drives the widget tests.

**The VAPID public key is build-time config**, injected like the Supabase
values (`--dart-define=VAPID_PUBLIC_KEY`, exposed via a provider). It is a public
key — safe to ship. The private key never leaves the server (Increment B).

**Subscriptions are the user's own rows.** `push_subscriptions(endpoint pk,
user_id, p256dh, auth, …)` with RLS limiting every operation to `auth.uid()`.
The sender (Increment B) reads recipients' subscriptions with the service role,
which bypasses RLS — so clients stay locked to their own rows.

## Design
- Migration `push_subscriptions` (+ RLS + index).
- `PushSubscription{endpoint, p256dh, auth}` (pure domain).
- `PushSubscriptionRepository` (`save`, `remove`) — in-memory fake + Supabase
  (`upsert` on `endpoint`, `delete` by endpoint).
- `WebPush` seam (`web_push.dart` + `_web.dart` + `_stub.dart`); providers
  `webPushProvider`, `pushSubscriptionRepositoryProvider`,
  `vapidPublicKeyProvider`; an `AsyncNotifier` `NotificationsController`
  (`build` = currently subscribed?, `enable`, `disable`).
- `web/push_sw.js`; narrowed `index.html` registration.
- UI: a `NotificationToggleButton` app-bar action (a bell), hidden when
  unsupported or unconfigured, with a snackbar for grant/deny/off.
- `AppConfig.vapidPublicKey`; deploy workflow passes the dart-define.

## Verification
### Unit tests (in-memory repository)
- `save` then the subscription is stored; saving the same endpoint updates it;
  `remove` deletes it.

### Widget tests (fake `WebPush`)
- Turning the toggle on subscribes and **stores** the subscription; the bell
  shows the on state and a confirming snackbar.
- A **denied** permission stores nothing and shows a "allow notifications"
  snackbar.
- Turning it off **removes** the subscription.
- An **unsupported** browser (or empty VAPID key) **hides** the control.

### Manual (Increment B, after deploy)
- On Android/desktop Chrome: enable notifications; from another account, post a
  message / send an invitation; a system notification arrives and opens the app.

## Open questions
- Debouncing chatty competitions (collapse with a per-competition `tag`).
- Per-competition mute, and a global quiet-hours setting.
- Native iOS/Android push (FCM/APNs) once there is a native build (pappa's #5).
