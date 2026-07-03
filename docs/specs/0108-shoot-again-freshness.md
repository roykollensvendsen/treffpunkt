# Spec 0108 — «Skyt igjen» follows the latest session without a refresh

- **Status:** Accepted
- **Related:** specs 0097 («Skyt igjen» card), 0025 (upload queue), 0082
  (felt rounds in history); user-reported bug

## Context

The «Skyt igjen» card names the shooter's most recent exercise, derived
from the same merged history «Mine økter» shows. But that history is
read through cached background providers, and nothing refreshed them
when the shooter returned to Hjem from a finished session — only a tab
switch to Mine økter or a full app reload did. So the card kept naming
the previous exercise until the app was refreshed.

## Rationale

Two layers, both cheap. First, the just-completed ring session is
already sitting in the **live upload queue** (spec 0025) before any
store or server read — watching that queue makes the card follow the
completion reactively, with no refresh at all. Second, the flows that
leave Hjem (a category, «Skyt igjen» itself, the resume cards) now
refresh the history reads on return — the same set the Mine økter tab
refreshes — which covers what the live queue cannot see: felt rounds
saved during the flow, and sessions that finished uploading while away.
Switching back to the Hjem tab refreshes the same set.

## Requirements

1. The «Skyt igjen» derivation includes the live upload queue, so a
   completed ring session updates the card the moment it is enqueued.
2. Returning to Hjem from any front-page flow (category page, felt
   course, «Skyt igjen», either resume card) refreshes the stored,
   synced and felt history reads along with the resume-card reads.
3. Selecting the Hjem tab refreshes the same set (as Mine økter already
   does for its own reads).

## Verification

- `program_picker_screen_test`: enqueuing a completed session on the
  live queue makes the card appear with the program's name, no refresh;
  a felt round saved while inside the felt flow shows on the card upon
  returning to Hjem.
- Existing picker/home-shell suites unchanged.
