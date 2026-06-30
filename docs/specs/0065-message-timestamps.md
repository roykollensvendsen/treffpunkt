# Spec 0065 — Timestamps on chat and forum messages

- **Status:** Accepted
- **Related:** spec 0051 (chat), spec 0054 (forum).

## Context
Chat messages and forum threads/replies don't show **when** they were posted, so
you can't tell a fresh message from an old one. Every message already stores a
`created_at`; we surface it as a small timestamp on each.

## Requirements
1. Each competition chat message, forum thread (opening post) and forum reply
   shows a small, unobtrusive **timestamp**.
2. It is shown in the viewer's **local time**, compactly: just the time today,
   the day and month earlier this year, and the full date in an earlier year.

## Rationale
**Display-only — the data is already there.** `CompetitionMessage`, `ForumThread`
and `ForumPost` all carry `createdAt` (parsed from `created_at`). A pure
`formatMessageTime(DateTime, {now})` helper formats it; the bubbles render it in
`labelSmall` muted text. No data, repository or migration change.

**No new dependency.** The format is built by hand (no `intl`): `HH:mm`,
`dd.MM HH:mm`, or `dd.MM.yyyy HH:mm`. `now` is injectable so the logic is unit-
tested without a clock.

## Verification
### Unit tests
- Today → `HH:mm`; earlier this year → `dd.MM HH:mm`; earlier year →
  `dd.MM.yyyy HH:mm`.

### Widget tests
- A chat message shows its timestamp; a forum thread and reply show theirs.

## Open questions
- A "just now / 5 min ago" relative style for very recent messages.
- Showing the full timestamp on hover/long-press.
