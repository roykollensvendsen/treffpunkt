# Spec 0134 — Skuddlyd når varsler treffer

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-04 («jeg vil gjerne ha
  en skuddlyd når man får inn varsler i appen»); spec 0094 (varsler)

## Context

A notification arriving while the app is open only changed the bell
badge — easy to miss, and the badge itself only refreshed on
navigation. And in a shooting app there is exactly one right sound
for «treff».

## Rationale

- **The sound**: a synthesized shot (a white-noise crack with a fast
  exponential decay over a low 85 Hz boom, low-passed) bundled as a
  WAV — no third-party audio dependency; the web implementation plays
  it through an audio element behind the app's usual platform seam
  (stub off-web, fake in tests). Best-effort: browsers may refuse
  audio before the first user interaction.
- **The trigger**: the notifications repository gains a live `watch()`
  stream (Realtime on the recipient's rows — the publication existed
  since spec 0094). The home shell listens; a notification id it has
  not seen before fires the shot and refreshes the bell badge — which
  therefore finally updates live, without navigating. The initial
  load is silent by construction.

## Requirements

1. A new, unread notification arriving while the app is open plays
   the shot exactly once and updates the bell badge live.
2. The initial load — however many unread — is silent.
3. Off-web and in tests the sound is a no-op/fake; playback failures
   never surface.

## Verification

- Widget: seeded old notifications load silently; a pushed arrival
  plays once and the badge shows the new count without navigation;
  no re-fire without new arrivals.
- Manually on the deployed app: a forum reply from another account
  fires the shot.
