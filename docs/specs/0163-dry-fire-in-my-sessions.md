<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0163 — Tørrtrening i «Mine økter»

- **Status:** Draft
- **Related:** spec 0161 (the dry-fire log), spec 0162 (its sync), spec 0082
  (the unified «Mine økter» list), spec 0089 (deleting a round from the account)

## Summary

Spec 0161/0162 gave the front page a Tørrtrening tally that syncs. This shows
each dry-fire registration as its own row in **«Mine økter»**, interleaved by
date with the ring sessions and felt rounds, so a shooter's practice sits in one
history. A dry-fire row has no score — it shows the discipline and the
trigger-pull count — and can be deleted like any other, removing it from the
device and (when signed in) the account.

Decided with the requester: one card per registration (not grouped), and the
card is deletable.

## Requirements

1. «Mine økter» lists each dry-fire entry as its own row, interleaved with ring
   sessions and felt rounds newest-first by date.
2. A dry-fire row shows the discipline (Presisjon/Duell), the trigger-pull count
   and the date; it carries no score.
3. A dry-fire row can be deleted (with confirmation); the entry is removed from
   the device and, when signed in, from the account.
4. The front-page Tørrtrening card and its totals reflect a deletion.

## Rationale

- **A third `MySessionItem`, not a rewrite.** The list (spec 0082) is already a
  sealed `MySessionItem` hierarchy interleaved by `capturedAt`, rendered by a
  `switch`. Dry-fire becomes `DryFireItem`, exactly as felt was added alongside
  ring — the merge stays a pure, unit-testable function.
- **One row per registration.** A dry-fire registration is one bout of practice;
  mapping it to one card matches how a ring session and a felt round each get a
  card, and keeps the merge trivial (no time-bucketing). If the history ever
  feels dense, grouping can come later without changing the stored data.
- **Delete mirrors the felt card (spec 0089).** Confirm, delete from the account
  first when signed in, then from the device; a failed account delete keeps the
  row and shows a message. The owner-only delete policy already shipped in the
  `dry_fire_entries` table (spec 0162), so no backend change is needed.
- **The log is the single source.** Both the front-page card and the list read
  `dryFireLogProvider`, so a deletion updates both at once (req 4) with no extra
  wiring.

## Design

### Domain / merge (`my_sessions_providers.dart`)

- `DryFireItem extends MySessionItem` wrapping a `DryFireEntry`; `capturedAt` is
  the entry's `recordedAt` (always present, so it never sorts last).
- `mergeSessionItems` gains a `dryFireEntries` parameter and builds a
  `DryFireItem` per entry alongside the ring and felt items before the shared
  date sort.

### Log + repository (delete)

- `DryFireRepository.deleteById(String id)` — removes the account row; the
  Supabase impl is `from('dry_fire_entries').delete().eq('id', id)` wrapped in
  `guardSync` (throws `DryFireSyncException` on failure); the in-memory fake
  drops the id.
- `DryFireLog.delete(String id)` — when signed in, deletes the account row
  first; then removes the entry from state and persists. A thrown account delete
  leaves the log intact (the card handles the message).

### Presentation (`my_sessions_screen.dart`)

- The screen watches `dryFireLogProvider` and passes its entries into
  `mergeSessionItems`.
- `_itemRow`'s `switch` gains `DryFireItem => _DryFireSessionCard(...)`.
- `_DryFireSessionCard` — a `ListTile` with the dry-fire glyph, title
  «Tørrtrening», a «date · discipline · N avtrekk» caption and no score; a
  trailing «Slett» menu that confirms and calls `DryFireLog.delete`, wrapped in
  `guardWithSnackBar` like the felt card. No detail screen (nothing to open).

## Verification

### Unit tests

- `my_sessions_providers_test`: `mergeSessionItems` interleaves a `DryFireItem`
  by date among ring and felt items, newest-first.
- `dry_fire_log_test` / `dry_fire_repository_test`: `deleteById` drops the id
  (and re-listing omits it); `DryFireLog.delete` removes the entry, persists,
  and (signed in) calls the repository; a signed-out delete stays local.

### Widget tests

- `my_sessions_screen_test`: a dry-fire entry renders as a row showing the
  discipline and count; the «Slett» menu removes it from the list.

### System / visual

- Rendered in «Mine økter» beside ring and felt cards, light and dark, signed
  off before merge.

## Open questions

- None. Grouping per day is explicitly deferred (one row per registration was
  chosen).
