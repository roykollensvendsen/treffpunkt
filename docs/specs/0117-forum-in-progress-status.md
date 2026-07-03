# Spec 0117 — «Jobber med»: a thread status for work in progress

- **Status:** Accepted
- **Related:** spec 0066 (thread statuses), 0112 (robot posts); the
  owner's request that threads show when a planned task is being
  worked on

## Context

A planned thread that the robot (or anyone) has started implementing
looks exactly like one still waiting. The start is announced as a
«Robot: Setter i gang …» reply, but the thread list gives no hint —
you have to open the thread to know.

## Rationale

The status lifecycle already carries triage state end to end (badge in
the list and the thread, moderator menu, tolerant wire decoding), so
work-in-progress belongs there rather than in a parallel mechanism: one
new value between planned and done, one badge colour, one widened
check constraint. Old clients decode the unknown wire value as open
and simply show no badge — degraded, never broken (spec 0066's
forward-compatibility rule). The robot sets it when it posts its
start-notice and moves on to done when the fix is deployed, so the
list mirrors the actual pipeline: Planlagt → Jobber med → Ferdig.

## Requirements

1. `ForumThreadStatus` gains `inProgress` (wire `in_progress`, label
   «Jobber med»), selectable in the moderator status menu and shown as
   an amber badge in the thread list and header.
2. The database accepts the new value (check constraint and
   `set_thread_status` RPC), applied to the hosted project.
3. The autonomous workflow sets `in_progress` together with its
   start-notice and `done` with its deploy-notice.

## Verification

- Unit: `in_progress` round-trips through wire/fromWire; an unknown
  wire value still falls back to open.
- Widget: a moderator picks «Jobber med» from the status menu and the
  badge appears with the label.
- Migration applied and verified against the hosted project.
