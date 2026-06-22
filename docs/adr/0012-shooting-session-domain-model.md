# ADR-0012: The shooting-session domain model

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
Increment 0 modelled a single discipline (10 m air rifle) as one
`TargetGeometry` plus a flat list of shots. The brief and the requirements added
on 2026-06-22 need much more. A recorded session must capture *when* and *where*
it happened, *which weapon* was used, and *which program* (øvelse) was shot;
results are recorded offline and may later be uploaded to a competition. A
program may run in several **stages**, each with its own target — for example NSF
pistol *presisjon* (slow precision) and *duell* (timed), which use different
25 m faces. Within a stage, shooting proceeds in **series** of a fixed number of
shots, after which the face is patched (or replaced) and a fresh series is shot.
The correct target must follow from the chosen program/stage, not be picked by
hand.

Two distinctions are easy to confuse and must be kept apart:

- **Stage** (e.g. *presisjon* vs *duell*): a variation *within* one program that
  may change the target face and the firing sequence — this is what decides
  which target to show.
- **Weapon class** (e.g. *finpistol* vs *grovpistol*): a calibre/class
  distinction carried by the **weapon**, not the target. Grov and fin are
  shot with different weapons (and are usually separate entries), not two stages
  of one session.

## Decision
Model a recorded session as a small, **pure-Dart** aggregate (no Flutter or
Supabase imports), the same discipline as `ScoringService`.

**Definitions vs recordings** — two sides, mirroring the weapon decision (a
seeded catalogue plus a personal instance):

- **Seeded definitions** (shared, referenced by id): a `ProgramDefinition` owns
  one or more `StageDefinition`s and declares the permitted weapon class(es) /
  calibre(s). A `StageDefinition` fixes the `TargetGeometry`, the shots per
  series and the number of series. These are curated/seeded, like the weapon
  reference catalogue.
- **Recorded data** (per session): the actual shots a shooter placed,
  structured to mirror the chosen definition.

**`Session`** — the aggregate root:

- a stable, **client-generated id** (so an offline record and its later upload
  are the same thing — ADR-0013);
- the chosen `ProgramDefinition` (reference) and `Weapon` (a personal weapon
  whose class/calibre must be permitted by the program);
- a **timestamp** and **`Location`** (GPS when available and permitted,
  otherwise entered by the shooter; a place may hold coordinates *and* a human
  label at once);
- an **optional competition reference** — `null` means free training
  (requirement 4); set when recording for, or uploading to, a competition;
- the recorded **stages**, each holding its **series**, each holding its
  **shots**.

**Recorded `Stage` / `Series` / `Shot`:**

- **Stage** — one `StageDefinition`'s worth of shooting; its `TargetGeometry` is
  what the UI renders, so switching stage swaps the target.
- **Series** — a fixed number of shots (the definition's `shotsPerSeries`)
  scored as a unit. How a face is handled *between* series (patch-and-reuse, a
  fresh card, or an electronic target) varies by program and venue; it is a
  recording/UI concern, not a scoring rule.
- **Shot** — an offset on the face (today's `Shot`), scored by `ScoringService`
  against the stage's geometry.

The 10 m air rifle is the **simplest geometry** (evenly spaced rings); the
Increment-0 slice recorded a single face, but the full program is multiple
series. `TargetGeometry` stays the per-stage geometry primitive but is
generalised in spec 0004 — today's `ScoringService.decimalScore` assumes even
ring spacing, which holds only for air rifle.

**Lifecycle** (owned by the pure aggregate): a series is *in-progress* until
**sealed** (its shots fixed); a stage is *complete* when all its series are
sealed; a session is *complete* when all stages are complete. "Complete" is what
makes a session eligible to upload (ADR-0013). The pure aggregate owns the id
and completeness; offline-storage and post-upload immutability flags belong to
the persistence/sync specs (0009/0012).

## Consequences
- The scoring core stays pure and unit-testable; a new program is mostly **data**
  (a `ProgramDefinition` and its geometry), not a new code path.
- "Which target do I show?" is answered by the active stage, so multi-stage
  competitions (presisjon/duell) render the right face; grov/fin is handled by
  **weapon selection**, not by the target.
- Choosing a weapon whose class/calibre the program forbids is rejected at
  session creation — which mechanically keeps grov and fin apart.
- The `Session` aggregate is the natural unit to persist offline and later
  upload; its optional competition reference is where upload reconciliation
  hooks in (ADR-0013).
- **Pinned per program spec, not here** (each with a source, as spec 0001 did for
  air rifle): exact shots-per-series and series counts; the 25 m pistol ring
  table(s) — precision and rapid/duel faces differ; permitted calibres per
  class; and whether a target records an **inner ten (X)**, which pistol
  leaderboards use as a tie-break and the current model does not yet expose.
- Spec 0004 must give `TargetGeometry` a well-formedness contract (ring diameters
  non-empty, positive, monotonically decreasing inward), since integer scoring
  relies on monotonic radii.
- More types than a flat shot list; mitigated by keeping each small, pure and
  independently testable.

## Alternatives considered
- **Keep a flat "target + shots" model and special-case disciplines in the UI:**
  rejected — it pushes domain rules into widgets (untestable) and cannot express
  multi-stage programs or the series cycle.
- **Model grov/fin as two stages of one session:** rejected — they are different
  weapons/calibres (and usually separate entries), not variations of one
  session; conflating them would force a model migration.
- **One backend row per shot with no client aggregate:** rejected for recording
  — offline recording needs a coherent on-device aggregate; the backend schema
  (the data/RLS spec) maps *from* it.
