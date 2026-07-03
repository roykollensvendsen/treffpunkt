# Spec 0118 — Local time everywhere

- **Status:** Accepted
- **Related:** forum thread «Klokke» (planned by the owner); specs 0008
  (session metadata), 0028 (build stamp), 0058/0082 («Mine økter»)

## Context

Dates on «Mine økter» sometimes show the wrong day, and the build
stamp on the front page shows a raw UTC minute. The report: «av og til
blir datoen feil på mine økter fordi det blir brukt Zulu tid, kan vi
få lokaltid slik som på telefonen» — plus «også lokaltid på bygg info
på hjemsiden».

## Rationale

The root cause is on the **write** side: uploads serialised a local
`DateTime` with `toIso8601String()`, which carries no offset, so
Postgres read the local wall clock as UTC and stored the wrong
instant. Everything that then correctly converts to local for display
(the month calendar's date grouping) lands an evening session two
hours later — sometimes on the next day. The fix must therefore be
end-to-end, not cosmetic:

1. **Upload the true instant**: serialise with `toUtc()`, so the
   offset is explicit and the database stores the moment, not the
   wall clock.
2. **Read to local**: every wire timestamp is `.toLocal()`-ed at the
   parse boundary (one shared helper), so every `DateTime` in the app
   is phone-local by construction — «slik som på telefonen». Parsing
   an offset-less local string is unaffected (`toLocal` is the
   identity), so stored on-device data reads exactly as before.
3. **Show local**: `norDateTime` (the one shared meta-line format)
   converts before formatting, and the build stamp renders its UTC
   build minute as a local `dd.MM.yyyy HH:mm`.
4. **Repair the stored rows**: every existing `captured_at` was
   written by the offset-less client from Europe/Oslo, so the stored
   value IS the Oslo wall clock. A one-time migration reinterprets
   them (`at time zone 'utc'` → `at time zone 'Europe/Oslo'`,
   DST-aware) into true instants.

## Requirements

1. `parseWireTime` parses a wire timestamp and returns a local-zone
   `DateTime`; all wire/JSON timestamp parsing uses it.
2. Session and felt uploads serialise `captured_at` as UTC with an
   explicit offset.
3. `norDateTime` formats in the phone's local zone whatever it is
   given; the build stamp shows the build time as local
   `dd.MM.yyyy HH:mm`.
4. A migration repairs existing `sessions.captured_at` and
   `felt_sessions.captured_at` from Oslo-wall-clock-as-UTC to true
   instants, applied to the hosted project.

## Verification

- Unit: `parseWireTime` returns non-UTC values for `Z`/offset strings
  and preserves an offset-less local string's wall clock; `norDateTime`
  formats a UTC input as its local conversion; `BuildInfo.formatLabel`
  renders the UTC build minute as the local `dd.MM.yyyy HH:mm`.
- The full suite passes with every `fromJson` on the shared helper.
- Migration applied and verified: hosted `captured_at` values shift by
  the Oslo offset; the app then shows the same wall clock the shooter
  picked, on every device.
