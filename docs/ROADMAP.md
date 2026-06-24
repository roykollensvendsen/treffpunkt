# Roadmap

Treffpunkt is built spec-by-spec. Each item below becomes a spec in
`docs/specs/`, implemented test-first.

## Increment 0 — walking skeleton (done)
- [x] Spec 0001 — 10 m air-rifle target & scoring
- [x] Pure-Dart scoring domain (integer + decimal), fully unit-tested
- [x] Tap-to-place target canvas with a live score
- [x] Spec 0002 — Move a placed shot (long-press to pick up, drag)
- [x] Spec 0003 — Authentication: Google sign-in (Supabase); login / logout
- [x] CI, licensing and documentation scaffolding

## Increment 1 — record a real session offline
The shooter records a complete session on-device, with no network needed
(ADR-0012 session model, ADR-0013 offline-first).
- [x] 0004 — Series domain core (pure Dart): `Program`, `Series` and series
      scoring with an optional inner ten on the generalised `TargetGeometry`;
      10 m air rifle re-expressed (spec 0001's vectors unchanged). The `Session`
      aggregate root and stages land with persistence (0009).
- [x] 0005 — 25 m pistol target & scoring: the precision (rings 1–10) and rapid
      / duel (rings 5–10) faces formally specified and sourced to ISSF, with a
      vector table mirroring spec 0001's (both faces; inner-ten / X; the gauge
      edge rule). Geometry already in code from 0004; spec 0005 locks it.
- [x] 0006 — Series scoring screen: place one series of N shots on the target,
      see each shot's score and the running total, then seal it when complete.
      Discipline-agnostic; shipped with 10 m air rifle. (Multiple series per
      stage / advancing to a fresh face follows when the `Session` root lands.)
- [x] 0007 — Weapons: a seeded reference catalogue (NSF classes + calibres) plus
      the shooter's own weapons referencing it; pick a weapon per session; a
      program accepts only its permitted weapon classes. (Model, in-memory store,
      the reusable picker and the session-setup wiring done — the chosen weapon
      now travels with the session; persistence follows in 0009.)
- [x] 0008 — Session metadata: date & time, and place captured before shooting —
      a human label plus optional coordinates, from device location or typed by
      hand (manual entry is a full alternative). Real GPS now reads through a
      `geolocator`-backed `LocationService` (web + Android + iOS) behind the
      ADR-0015 interface, degrading to manual entry on any denial or error.
- [x] 0009 — Offline-first persistence: create, complete and store a whole
      session locally with no network; it survives an app restart — the
      in-progress series included — and a "Fortsett økt" card resumes it. Stored
      behind a `SessionStore` interface (`shared_preferences`, ADR-0016); geometry
      is rebuilt from the catalogue, not serialized.
- ~~0017 — 50 m rifle target & scoring~~ **(removed)** and
  ~~0018 — 300 m rifle target & scoring~~ **(removed)**: these two rifle programs
  and their target faces were seeded from ISSF geometry on NSF-unconfirmed
  footing. The NSF domain expert did not recognise them, so they were removed
  entirely (programs, geometries, weapon classes, specs and tests). Revisit only
  if NSF confirms a 50 m / 300 m rifle structure.
- The **10 m air rifle is no longer offered in the program list** (NSF domain
  expert's request): it is dropped from the program picker and its orphaned
  weapon class removed. Its scoring foundation stays — spec 0001, decimal
  scoring, the `TargetGeometry.airRifle10m()` target and the
  `ProgramCatalogue.airRifle10m` reference remain (the latter still resolves by
  name so older saved sessions load); the program is simply not in the offered
  list.
- [x] 0019 — Personal weapon persistence: the shooter's own weapons (spec 0007)
      are saved on-device and survive a restart, behind a `WeaponStore` interface
      mirroring 0009 (`shared_preferences`, ADR-0016). The list is loaded once at
      launch to seed the notifier and rewritten on every add/remove.

## Increment 2 — competitions, sync and scoreboards
- [x] 0010 — Data & RLS: Supabase schema for profiles, competitions
      (public/private) and **explicit invitations** (owner invites by email);
      Row-Level Security with a participant-read policy, recursion broken with
      `SECURITY DEFINER` helpers, and an owner-auto-membership trigger +
      `accept_invitation` RPC. Foundation only (no UI). **Results deferred to
      0012** so the live owner-only `sessions` policy is not broadened.
- [x] 0011 — Competitions: create / invite (by email) / accept; a competition
      fixes its program at creation. The hub, create form and detail screen on
      top of the spec-0010 seam (no results/scoreboard yet — that is 0012/0013).
- [x] 0024 — Personal session sync: the first sync step — when signed in,
      completing a session uploads it to the shooter's own account (owner-only
      RLS), best-effort and idempotent, so results follow the account across a
      reinstall or device. Distinct from the competition sync in 0012 (no
      competition identity yet); the foundation for the pending-upload queue and
      the "My sessions" history (ADR-0017).
- [x] 0025 — Upload queue: a completed session is enqueued in a durable on-device
      outbox (`PendingUploadsStore`, `shared_preferences`) and flushed — uploaded
      then removed — on completion, on app start and when the user signs in, so a
      session finished offline or signed out is never lost and uploads itself
      later. Deduplicated by the client-generated id (an idempotent upsert);
      best-effort, so a throwing repository never breaks completion (ADR-0013,
      ADR-0017). The "My sessions" read-back screen is the next increment.
- [x] 0026 — My sessions list: a "Mine økter" screen lists the shooter's saved
      sessions — the ones synced to the account (0024) and the ones still waiting
      in the upload queue (0025) — most recent first, each with its key result
      and a clear "not synced yet" marker on the pending ones. Tapping one opens
      its read-only scorecard, rebuilt from the stored payload and re-scored, with
      the same per-stage + per-series breakdown (0023); an unresolvable program
      shows a graceful message. Best-effort read-back (server `list()` returns
      empty on any error), unioned and deduplicated by id (synced wins, ADR-0017).
- [x] 0012 — Shoot for a competition: "Skyt nå" launches the competition's fixed
      program; on completion the result is submitted (idempotent, via the durable
      upload queue) to a `competition_results` scoreboard every participant reads.
      Program always matches (no needs-attention needed). A basic scoreboard read
      ships here; Realtime + ranking is 0013.
- [x] 0013 — Live scoreboard: the per-competition result list updates live via
      Supabase Realtime (RLS-scoped), ranked best-per-shooter. Original line:
      Per-competition result list, visible to every participant
      (Supabase Realtime).
- [x] 0032 — Invite a registered shooter from a list: the owner picks a
      registered shooter (name + avatar) instead of typing an email; a
      `SECURITY DEFINER` RPC resolves their email server-side and writes the same
      email-keyed invitation, so no email reaches the client and the accept flow
      is unchanged (ADR-0020). The type-an-email control stays for people not yet
      registered.
- [ ] 0014 — Fair cross-competition ranking (public top-score list).
- [ ] 0015 — Browse own & published results.

## Increment 3 — polish & breadth
- [ ] 0016 — Responsive/adaptive polish; PWA install; store builds.
- [ ] 0020+ — More programs/disciplines (further pistol programs, field, …).

## Requirements added 2026-06-22 → where each lives
- Date, time and place (GPS or manual) per session → **0008** (ADR-0012).
- Weapon database (personal weapons + seeded reference catalogue) → **0007**.
- Target chosen from the selected program → **0004** (model) + **0006** (the UI
  renders the active stage's target) + **0011** (a competition fixes the
  program).
- Save locally without a network → **0009** (ADR-0013).
- Upload results later to a competition → **0012** (anchored to a competition
  identity from **0010** / **0011**).
- All participants can see the result list → **0010** (RLS read policy) +
  **0013** (the list / Realtime).
- Several targets per competition/training → for **presisjon / duell** these are
  *stages* → **0004** + **0006**; **grov vs fin** is a *weapon class* → **0007**;
  a competition fixes which set is shot → **0011**.
- Show e.g. 5 shots per face, then patch and reshoot → **0004** (series) +
  **0006** (UI).
