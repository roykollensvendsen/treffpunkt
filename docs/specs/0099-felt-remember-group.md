# Spec 0099 — Felt: the recorder remembers your group

- **Status:** Accepted
- **Related:** spec 0080 (the group picker), 0088 (offered groups), the July
  2026 UI analysis (bundle 2)

## Context

The shooter's group (Gruppe 1 or 2) is a stable property of the shooter,
yet every NorgesFelt round starts with a full-screen group picker asking
the same question again.

## Requirements

1. Picking a group **remembers it** (locally, surviving restarts).
2. Starting the next round **skips the picker** and begins on hold 1 with
   the remembered group.
3. While the round has **no shots**, the recorder's app bar offers **«Bytt
   gruppe»**, returning to the picker; once a shot is placed the action is
   gone (a group change would invalidate the shots-per-hold cap).
4. First-ever round (nothing remembered) shows the picker exactly as
   before; a resumed round keeps its own group (unchanged).

## Rationale

Mirrors the app's persistence idiom (spec 0030's `ThemeModeStore`): an
interface + in-memory fake + `shared_preferences` engine, loaded eagerly in
`main()` so the notifier stays synchronous and tests never touch real I/O.

## Verification

### Unit tests
- `felt_group_store_test`: round-trips a group; empty/unknown loads null.

### System tests
- `felt_record_screen_test`: with a remembered group the recorder starts on
  hold 1 with that group's shots-per-hold; «Bytt gruppe» shows the picker
  while no shots are placed and disappears after the first shot; picking a
  group persists it to the store; with nothing remembered the picker shows
  first, as before.
