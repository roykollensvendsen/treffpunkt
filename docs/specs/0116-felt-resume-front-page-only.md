# Spec 0116 — One «Fortsett felt-økt» card, on the front page

- **Status:** Accepted
- **Related:** forum thread «Duplisert fortsett felt økt» (planned by
  the owner, resolution confirmed on the thread); spec 0081 (the
  original course-page resume card), 0097 (the front-page card), 0096
  (destructive actions confirm first)

## Context

An in-progress felt round is offered for resuming in two places: the
front page (spec 0097) and the NorgesFelt course preview (spec 0081,
the original placement). The owner reads that as the same card twice
and asked to keep only the front page's — with the discard button,
which today only the course-page card has.

## Rationale

The front page is where the shooter lands, so its card is the one that
earns its place; the course-page card no longer adds reachability, only
repetition. The discard affordance must move with it: without a trash
button the only way off a stale round would be resuming and backing
out. The front-page ring card already has exactly this trailing
trash-plus-confirmation (specs 0009/0096) — the felt card gets the
same, sharing the confirmation dialog.

## Requirements

1. The course preview no longer shows a resume card; «Skyt løypa» and
   the hold previews are unchanged.
2. The front page's «Fortsett felt-økt» card gains a trailing discard
   button: confirm (spec 0096), clear the felt in-progress store,
   refresh the card away.
3. Resuming from the front page is unchanged (spec 0097).

## Verification

- Course preview with a saved round in the store: no resume card.
- Front page: the felt card shows the discard button; confirming
  clears the store and removes the card; cancelling keeps both.
- Existing front-page resume test (spec 0097) passes unchanged.
