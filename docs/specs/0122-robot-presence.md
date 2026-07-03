# Spec 0122 — Er Robot Hood her? (presence)

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-03 («en funksjon i
  brukergrensesnittet som indikerer om du er tilgjengelig eller
  ikke»); specs 0112/0119 (Robot Hood), 0120 (summons)

## Context

Robot Hood answers questions, reacts to new threads and handles
summonses — but only while the owner's machine and its forum watch are
running. When the machine is off, a question sits unanswered with no
hint of why. The owners want the app to show whether the robot is
listening right now.

## Rationale

Presence must be **honest**, so it is derived from the one signal that
actually means "listening": the forum watch's poll loop. Every poll
(~90 s) upserts a heartbeat row; the app calls it present while the
heartbeat is fresher than five minutes (three missed polls), and
absent otherwise — machine off, session dead or watch crashed all look
the same, which is exactly right. A single-row table keeps the write
trivially idempotent; authenticated users may only read it. The
indicator lives at the top of the forum (where Robot Hood lives): a
green dot and «Robot Hood er på vakt», or a grey dot and «Robot Hood
er ikke her nå — svar kommer når roboten våkner».

## Requirements

1. A `robot_presence` heartbeat table (single row, `seen_at`),
   readable by authenticated users, written only by the owner's
   tooling; the forum watch upserts it every poll.
2. The forum screen shows the presence line: green/«på vakt» when
   `seen_at` is within 5 minutes, grey/«ikke her nå» when older or
   missing. It refreshes with the forum list.
3. No heartbeat row at all reads as absent, never as an error.

## Verification

- Widget: a fresh heartbeat renders the green «på vakt» line; a stale
  or missing one renders the grey «ikke her nå» line.
- Unit: the 5-minute freshness rule.
- Migration applied to hosted; the live watch's first poll after
  deploy writes the row (verified by SELECT).
