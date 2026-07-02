# Spec 0089 — Felt rounds: Mine økter parity (delete + result card)

- **Status:** Accepted
- **Related:** spec 0033 (delete a ring session), 0082 (felt rounds in Mine
  økter), 0083 (felt sync), 0085 (points · inner display)

## Context

Felt rounds appear in "Mine økter" (spec 0082) but lack two affordances the
ring sessions have: they **cannot be deleted**, and the felt scorecard shows
its total as a plain list row where the ring scorecard shows a filled
**result card** (the primary-coloured box with the big total). The domain
expert asks for parity on both.

## Requirements

1. A felt round's card in "Mine økter" carries the same overflow menu with
   **Slett** and the same confirmation dialog as a ring session (spec 0033).
2. Deleting removes the round from the **account** (when it is synced) and
   from the **device**; a round that only exists locally needs no network.
3. A failed account delete leaves the card in place and shows the same
   "could not delete" message as the ring flow.
4. The felt scorecard shows the round's total in the same **filled result
   card** as the ring scorecard — the big points number with the group label
   and the ringed-X inner count (spec 0085) — at the end of recording and in
   the Mine økter detail view alike.

## Rationale

Mirroring spec 0033 keeps one mental model: cloud delete first for synced
data (abort on failure so nothing silently diverges), then the local copy.
As with ring sessions, another signed-in device that still holds the round
locally will re-upload it on its next sync — accepted for now, same as spec
0033.

## Design

- `FeltSessionRepository` gains `deleteById(id)`; the Supabase
  implementation deletes the owner's row (RLS-scoped), throwing
  `FeltSyncException` on failure; the in-memory fake mirrors it.
- `deleteFeltRound(ref, id)` in the felt providers removes the round from
  the local `FeltHistoryStore` (load → filter → save) and refreshes
  `feltHistoryProvider`.
- `FeltSessionItem` (spec 0082) gains `synced`, computed from membership in
  the synced list, so the card knows whether a cloud delete is needed —
  exactly the ring card's `entry.synced`.
- `_FeltSessionCard` mirrors `_SessionCard`: the card body is one semantic
  button, the overflow menu sits beside it (`deleteSessionMenuKey`), and the
  confirm dialog reuses `deleteSessionConfirmKey`.
- `FeltScorecard` replaces its total `ListTile` with a `_FeltTotalCard`
  styled as the ring `_GrandTotalCard`: `colorScheme.primary` box, the
  "TOTALT (GRUPPE N)" label, the `Poeng · M Ⓧ` line and the big points
  number.

## Verification

### Unit tests
- `felt_sync_test` (or repository test): `deleteById` removes the uploaded
  round from the in-memory repository.
- `my_sessions_providers` merge: a round present in the synced list yields a
  `FeltSessionItem` with `synced` true; a local-only round false.

### System tests
- `felt_in_my_sessions_test`: the felt card's menu → Slett → confirm removes
  the card and the stored round (local-only case); a synced round's delete
  also removes it from the (fake) repository.
- `felt_record_screen_test` / scorecard: the finished round's total renders
  in the result card (the "TOTALT" label and the big number are present).

## Open questions
- None.
