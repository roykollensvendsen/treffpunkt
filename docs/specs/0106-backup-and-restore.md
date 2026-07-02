# Spec 0106 — Backup to a file and restore

- **Status:** Accepted
- **Related:** forum thread «Backup»; specs 0024/0025 (session sync &
  upload queue), 0083 (felt sync), 0019 (weapons), 0102 (records &
  default place)

## Context

Sessions live on the device and — when signed in — in the app's online
database. The domain expert asked for a backup button: a file of his own
(to the phone, or sent wherever he likes) and a way to restore from it.
A file is also the only self-service escape hatch that does not depend
on the app's backend at all.

## Rationale

Everything worth keeping already round-trips as JSON (records, rounds,
weapons, baselines), so one versioned blob composes them. Export goes
through the platform share sheet — a download on web, any target on
mobile — via the existing `Sharer` seam, extended with a file method.
Restore is **additive, never destructive**: sessions and felt rounds
merge by id (the device's copy wins), weapons by name, record baselines
keep the best result, the default place only fills a hole. Restored ring
sessions land in the durable upload queue (spec 0025), so they also
reach the account on the next flush, idempotent by id. `file_picker`
(new dependency) reads the chosen file's bytes on web and mobile alike,
behind a `BackupFileSource` seam so tests never open a dialog.

## Requirements

1. **Export** (Innstillinger → Sikkerhetskopi → «Eksporter til fil»):
   one JSON file `treffpunkt-backup-<dato>.json` with the ring sessions
   (pending + synced merged), felt rounds (local + synced merged),
   weapons, record baselines and the default place, shared through the
   platform share sheet.
2. **Import** («Importer fra fil»): pick a backup file, see what it
   contains, confirm — then merge additively per the rules above, with
   a summary of what was added. A foreign or corrupt file is rejected
   with a clear message; a broken entry inside a valid backup is
   skipped, never fatal.
3. The blob is versioned (`kind: backup, version: 1`) and parsing
   tolerates missing sections, so future fields stay compatible.
4. Everything is testable without the real share sheet or file dialog
   (`Sharer.shareFile`, `BackupFileSource`).

## Verification

- `backup_test` (domain): build/parse round-trip; foreign blob rejected;
  broken entries skipped; merge adds only what is new, existing ids win,
  weapons dedupe by name, records keep the best, default place only
  fills a hole.
- `backup_section_test` (widget): export captures one JSON file through
  a fake sharer and it parses back; import shows the confirmation,
  merges after confirm and reports the counts; a foreign file shows the
  rejection message and writes nothing; cancelling the dialog does
  nothing.
- `settings_screen_test`: the Sikkerhetskopi section is on the page.
