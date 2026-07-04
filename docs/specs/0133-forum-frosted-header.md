# Spec 0133 — Forum-toppen deler glasset

- **Status:** Accepted
- **Related:** owner feedback in-session 2026-07-04 («seksjonen på
  toppen av forum siden er fortsatt ikke frosset glass»); specs
  0129/0132

## Context

The forum's filter chips and the Robot Hood presence line sat in a
fixed, opaque header between the frosted app bar and the thread list
— an unfrosted stripe in the middle of the glass.

## Rationale

`AppBar` already has the slot for exactly this: `bottom`. The shared
`FrostedAppBar` gains pass-through `bottom` support, and the forum's
header moves into it — one frosted pane from the status bar down
through the filters, with the thread list sliding beneath the whole
block (the `extendBodyBehindAppBar` inset covers toolbar + bottom
automatically).

## Requirements

1. `FrostedAppBar` accepts `bottom` and reports the combined height.
2. The forum's filters + presence line live in the frosted bar; the
   thread list scrolls beneath it and beneath the navigation bar.
3. Filtering, presence and every forum interaction behave as before.

## Verification

- The forum suite passes unchanged (filters, presence, threads,
  mentions — all exercised through the moved header).
- Screenshot: threads visible through the filter block mid-scroll.
