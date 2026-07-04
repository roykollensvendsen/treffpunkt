# Spec 0135 — Treffpunkt-jingelen

- **Status:** Accepted
- **Related:** owner feedback in-session 2026-07-04 («det var en
  veldig svak smell. kan du legge inn en jingle som er unik for appen
  og lett å kjenne igjen med god lyd»); spec 0134 (the trigger)

## Context

Spec 0134's synthesized shot crack was too weak to register as a
notification — mostly noise, over in a quarter second.

## Rationale

A signature jingle instead: a bright, bell-timbred ascending major
arpeggio (C5–E5–G5) landing on a long C6 «ding» — the hit — over a
soft low thump, 1.6 s, peak-normalised to 97 %. Melodic, unique to
the app and unmistakable at phone volume. Same synthesis-in-repo
approach (a documented Python recipe, no third-party audio or asset
licensing), same seam and trigger — only the WAV and its URL change.

## Requirements

1. The notification sound is the bundled `jingle.wav`; the shot WAV
   is gone.
2. Trigger, seam and tests are unchanged (the fake counts plays).

## Verification

- The spec-0134 widget test passes unchanged.
- The WAV sent to the owners for a listen.
