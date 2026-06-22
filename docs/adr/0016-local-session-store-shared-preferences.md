# ADR-0016: Store the active session locally with shared_preferences

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
Recording is offline-first (ADR-0013): a session is created, edited and
completed on-device and must survive an app restart with no network, including
the shots placed in the series still in progress. ADR-0013 deferred the concrete
storage engine to the persistence spec (0009) and fixed only that it sits behind
a repository-style interface. We need to pick that engine for the one piece of
state to persist now — a single *active* recording — across web, Android and iOS.

## Decision
- Persist a **single active recording** as one JSON string under one key,
  behind a `SessionStore` interface (`save` / `load` / `clear`) in the data
  layer, like `AuthRepository` and `LocationService`.
- Back the default implementation with **`shared_preferences`**. It is a simple
  cross-platform key-value store that already ships transitively with
  `supabase_flutter`, so promoting it to a direct dependency adds no new package
  to the resolved set. Its `SharedPreferences.setMockInitialValues` lets widget
  and unit tests drive the real implementation with no platform I/O.
- Serialization is a **pure-Dart** concern (spec 0009): a `SessionSnapshot`
  value type owns `toJson` / `fromJson`; the store only reads and writes the
  resulting string. Tests inject an `InMemorySessionStore` and never touch the
  platform.

## Consequences
- One active session round-trips through a restart with no network and no
  database setup; the engine is swappable behind the interface.
- A single key holds one recording; a list of past unfinished sessions would
  need a keyed collection or a different engine — a later option, not this slice.
- `shared_preferences` stores a single string well but is not a query engine;
  when sync and a results history land (0012+), a structured store (e.g.
  Drift/SQLite) may sit behind the same or a sibling interface.
- Because geometry is rebuilt from `ProgramCatalogue` on load (spec 0009), a
  corrected target table applies to old recordings automatically; an unknown
  program name fails loudly instead of mis-scoring.

## Alternatives considered
- **Drift/SQLite or Hive now:** rejected for this slice — heavier setup and a new
  dependency for a single active record; warranted once we persist a history and
  a sync queue (0012+).
- **A JSON file via `path_provider` + `dart:io`:** rejected — needs per-platform
  paths and does not work on web, whereas `shared_preferences` is uniform across
  web and mobile and is already present.
- **Serialize the target geometry too:** rejected — geometry follows from the
  program (ADR-0012); storing it risks drift from a corrected catalogue. We store
  the program name and rebuild.
