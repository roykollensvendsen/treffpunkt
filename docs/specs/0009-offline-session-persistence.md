# Spec 0009 — Offline session persistence

- **Status:** Accepted
- **Related:** ADR-0012 (session domain model), ADR-0013 (offline-first),
  ADR-0016 (local store via `shared_preferences`), spec 0006 (series screen),
  spec 0008 (session setup metadata)

## Context

A shooter on the firing line often has no network (ADR-0013). They must be able
to record a whole session — the program, the weapon, when and where it was shot,
every sealed series and the shots placed in the series in progress — entirely
on-device, and find it exactly as they left it after the app is closed and
reopened. This spec adds local persistence and a resume affordance; uploading a
completed session to a competition is a later increment (0012).

Persistence must survive a real restart, including a **partially-filled** series
that has not been sealed yet: the shots already placed on the current face are
part of the recording and must come back. Nothing here may touch the network,
and the storage engine must stay behind an interface so tests use an in-memory
fake and never do real I/O.

## Requirements

1. A pure-Dart, lossless serialization of an in-progress recording: the
   `Session` (its program by unique `name`, the optional weapon and metadata, and
   the sealed series grouped by stage) **plus** the current in-progress series'
   placed shots. The round-trip rebuilds an equal recording field-by-field,
   including a partially-filled current series, with or without a weapon and with
   or without metadata.
2. Target **geometry is not serialized**. On restore the `ProgramDefinition` is
   resolved from `ProgramCatalogue` by name and each series is rebuilt from the
   program's stage geometries and capacities, so a stored recording always scores
   against the canonical, current target tables.
3. A `SessionStore` interface in the data layer — `save`, `load`, `clear` — that
   the rest of the app depends on, mirroring the `LocationService` / repository
   pattern. The default implementation is backed by a cross-platform key-value
   store (`shared_preferences`, web + mobile). Tests inject an in-memory fake; no
   real storage or I/O in any test.
4. The active recording is persisted whenever it changes (placing, moving or
   advancing a series) and the store is cleared when the session completes or is
   discarded, so a finished or abandoned session never resurfaces as a resume.
5. On launch, if a saved active recording exists, the shooter can **resume** it:
   a clear affordance on the program picker reopens the shooting screen restored
   to the exact saved state — same program, weapon, metadata, sealed series and
   the in-progress series' shots.
6. Restoring re-seeds the session notifier's state from the store: a restored
   recording provider the notifier reads in `build`, so a resumed screen starts
   from the saved recording instead of a fresh `Session.start`.
7. New domain code is pure Dart; everything passes `very_good_analysis`
   (strict) and is testable headlessly; existing tests stay green.

## Rationale

The unit to persist is the ADR-0012 aggregate plus the one mutable thing the
aggregate does not yet own — the unsealed series in progress — so serialization
lives on a small pure value type, `SessionSnapshot(session, current)`, that the
presentation `SessionRecording` maps to and from. Keeping it pure (no Flutter,
no storage import) means the round-trip is a fast, deterministic unit test and
the JSON shape is decided in the domain, not smeared across a widget.

Geometry is *derived*, not *recorded*: a face is fixed by the program's stage
definition (ADR-0012), so serializing ring tables would only risk a stored
session drifting from a corrected catalogue. Storing the program `name` and
rebuilding every series from `ProgramCatalogue` keeps recordings small and always
scored against the current tables; it also means an unknown program name fails
loudly on load rather than silently mis-scoring.

Storage sits behind `SessionStore` exactly like `AuthRepository` and
`LocationService`, so the feature is testable with an in-memory fake and the real
engine is swappable. `shared_preferences` is the smallest cross-platform
key-value store that already ships with the app's dependencies (ADR-0016); a
single JSON string under one key is enough for one active recording.

Resuming re-seeds the notifier through a `restoredRecordingProvider` the
notifier reads in `build` — the same override-a-provider pattern the screen
already uses for the program, metadata and weapon — so a resumed `SeriesScreen`
starts from the saved recording with no change to the notifier's shape, and
keeps persisting onward through the same store.

## Design

```
lib/features/scoring/
  domain/
    session_snapshot.dart   SessionSnapshot(session, current) + toJson/fromJson;
                            resolves the program from ProgramCatalogue by name,
                            rebuilds each series from the stage geometries.
    program_catalogue.dart  + byName(String): ProgramDefinition? lookup.
  data/
    session_store.dart      SessionStore interface (save / load / clear);
                            SharedPreferencesSessionStore (one JSON string under
                            one key); InMemorySessionStore for tests/default.
  presentation/
    session_providers.dart  + sessionStoreProvider; restoredRecordingProvider;
                            SessionNotifier.build seeds from the restored
                            recording when present, persists on every change and
                            clears the store on completion;
                            SessionRecording.toSnapshot / fromSnapshot.
    series_screen.dart      + `restored` recording override.
    program_picker_screen.dart  a "Fortsett økt" resume card when the store
                            holds a recording, reopening SeriesScreen restored.
```

JSON shape (one active recording):

```json
{
  "program": "10 m Air Rifle",
  "weapon": { "id": "...", "name": "...", "discipline": "rifle",
              "caliberLabel": "...", "classLabel": "...",
              "make": null, "model": null, "notes": null },
  "metadata": { "capturedAt": "2026-06-21T14:30:00.000",
                "place": { "label": "...", "latitude": 59.9,
                           "longitude": 10.7 } },
  "sealedSeriesByStage": [ [ [ {"dxMm": 0.0, "dyMm": 0.0} ] ] ],
  "current": [ {"dxMm": 1.0, "dyMm": -2.0} ]
}
```

`weapon` and `metadata` are `null` when absent; `current` is `null` once the
session is complete. On load, `program` is resolved by name (an unknown name is
a `FormatException`), each sealed series and the current series are rebuilt from
the stage's geometry and `shotsPerSeries`, and the shots are placed back.

## Verification

### Unit tests

- `session_snapshot_test`: a full round-trip (`fromJson(toJson(s))`) rebuilds an
  equal recording — same program, sealed series and shots — for a multi-stage
  program with several sealed series; a partially-filled current series round-
  trips with the exact placed shots and capacity; the weapon round-trips when
  present and is `null` when absent; the metadata (date + place with coordinates)
  round-trips when present and is `null` when absent; a completed session
  (`current == null`) round-trips with no current series; geometry is rebuilt
  from the catalogue (the restored series' geometry equals the program's stage
  geometry, never read from JSON); an unknown program name throws a
  `FormatException`.
- `program_catalogue_test` (extended): `byName` returns the program for a known
  name and `null` for an unknown one; every catalogue program is found by its
  own name.
- `session_store_test`: the in-memory fake saves then loads an equal snapshot,
  `load` is `null` before any save and after `clear`, and `save` overwrites a
  previous snapshot; the `shared_preferences`-backed store, driven by
  `SharedPreferences.setMockInitialValues` (no real I/O), saves, loads an equal
  snapshot and clears it.

### Widget tests

- `session_persistence_test`: mounting the shooting screen and placing shots in
  the in-progress series writes a snapshot to an injected fake store; mounting a
  fresh screen with that fake store and the resume override restores the same
  shots, weapon and metadata (the in-progress series included); completing the
  session clears the store.
- `program_picker_screen_test` (extended): the resume card appears only when the
  store holds a recording and reopens the shooting screen restored to the saved
  shots; with an empty store no resume card is shown; the card refreshes against
  the store every time the picker is reshown — after a newly-saved recording it
  appears on a fresh mount, and after a resumed session is completed it is gone
  on return and the store is empty (req 4); discarding a saved recording from the
  card clears the store and removes the card (req 4).

### System tests

- `place_shot_test` / `auth_flow_test` keep passing: the signed-in gate still
  reaches the air-rifle flow through the setup step and a centre shot scores a
  ten, now with a store wired in.

## Open questions

- Several concurrent saved recordings (a list of past unfinished sessions) is a
  later option; this stores exactly one active recording under one key.
- Uploading a completed session to a competition, and locking it as immutable
  after upload, is spec 0012 (ADR-0013); this spec only stores locally and clears
  on completion.
