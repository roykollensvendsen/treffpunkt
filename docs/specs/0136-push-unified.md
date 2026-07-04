# Spec 0136 — Én push per varsel

- **Status:** Accepted
- **Related:** spec 0060 (web push; Increment B's sender and triggers
  shipped 2026-06-30), spec 0094 (the notifications fan-out), spec
  0120 (mentions); owner go-ahead in-session 2026-07-04

## Context

Everything in Increment B existed — sender function, VAPID keys,
service worker, source-table triggers — but no push ever arrived: the
database settings the triggers read (`app.notify_url` /
`app.notify_secret`) were never configured, so every trigger was a
silent no-op. And the sender listened to the four source tables,
which the spec-0094 notifications fan-out has since superseded:
mentions (and any directly inserted notification) would never have
pushed, while messages would eventually have pushed twice.

## Rationale

The notifications table IS the fan-out: recipients, dedup and wording
are decided once, by the same database triggers the in-app varsler
rely on. Pointing the push sender at it — one push per inserted row,
to that row's recipient, with that row's title and body — makes OS
pushes and in-app varsler incapable of disagreeing, and covers every
kind, mentions included. New forum threads keep their own trigger:
moderator alerts have no notifications-row equivalent. The missing
database settings are operational (they carry the shared secret) and
are configured by the owner, not committed.

## Requirements

1. An inserted `notifications` row fires exactly one push to its
   recipient with the row's title/body; the redundant source triggers
   (messages, invitations, forum posts) are gone.
2. New forum threads still push to the moderators.
3. The webhook settings are configured on the hosted database (owner
   operation; documented in `docs/dev/deploy.md`).

## Verification

- Hosted trigger listing shows exactly `notifications_notify` and
  `forum_threads_notify`.
- End-to-end after configuration: an inserted notification row
  produces a 2xx from the function (pg_net response log) and an OS
  notification on a subscribed device with the app closed.
