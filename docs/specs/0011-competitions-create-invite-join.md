<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0011 — Competitions: create, invite & join (UI)

- **Status:** Accepted
- **Related:** spec 0010 (competitions data & RLS — the foundation this builds
  on), ADR-0019 (competitions data model), spec 0026 (My sessions — the list
  screen pattern reused)

## Context

Spec 0010 shipped the competitions **data foundation** — schema, RLS and the
`CompetitionRepository` seam — with no screens. This spec adds the **UI** on top:
the shooter can open a competitions hub, **create** a competition that fixes a
program, **invite** people by email, and **accept** an invitation to join. It
adds no new data concepts; it drives the repository the foundation already
provides.

## Requirements

1. **Entry point.** A "Konkurranser" action in the program-picker app bar opens
   the competitions hub (mirroring the "Mine økter" action). Its background
   reads are refreshed on open.
2. **The hub (`CompetitionsScreen`).** Shows the shooter's **pending
   invitations** (each with a *Godta* button) and the competitions they **own or
   have joined**, with a *Ny konkurranse* action. A foreground read failure
   shows a retry, not a silent empty list; an empty hub shows a friendly empty
   state.
3. **Create (`CreateCompetitionScreen`).** A name, a **program** chosen from the
   catalogue (the competition fixes it), and a public/private switch
   (private by default). Submitting mints a client id and calls
   `createCompetition`; the owner is auto-added as a member (spec 0010). On
   return the hub refreshes so the new competition shows.
4. **Detail (`CompetitionDetailScreen`).** Shows the program and the
   **participants** (names from their profiles). For the **owner**, an
   invite-by-email control calls `invite`.
5. **Accept.** Tapping *Godta* on an invitation calls `acceptInvitation`; the
   invitation disappears and the competition moves into the shooter's list. A
   failure shows a message and leaves the invitation in place.

## Design

All screens live in `lib/features/competitions/presentation/competitions_screen.dart`
(hub + create + detail, like `my_sessions_screen.dart`). Navigation is plain
`Navigator.push`. New providers in `competition_providers.dart`:
`myCompetitionsProvider` / `myInvitationsProvider` (foreground `FutureProvider`s,
surfacing `CompetitionSyncException`), `competitionMembersProvider` (family),
`competitionIdGeneratorProvider` (uuid, overridable in tests) and
`currentUserIdProvider` (stamps the owner / decides who may invite). Actions call
the repository directly and `invalidate` the relevant providers so the lists
refresh.

## Rationale

The foundation already exposes exactly the operations these screens need, so the
UI is a thin, testable layer over `CompetitionRepository` with the same
list-screen shape as "My sessions". Reads are **foreground** here (unlike the
best-effort synced-sessions read) because a shooter opening the hub is waiting on
them and a failure should offer a retry rather than look empty. The program is
fixed at creation (stored as its catalogue name), so every entrant later shoots
the same structure.

## Verification

### Widget tests (`competitions_screen_test.dart`)
- *shows the empty state with no competitions.*
- *creating a competition makes it appear in the list* — name + default program,
  submit, the new card shows on the hub.
- *accepting an invitation moves it into my competitions* — a seeded invitation
  (from another user, via the in-memory `asUser`) is offered, then on *Godta*
  the invite disappears and the competition is listed.
- *the owner can invite someone by email* — on the detail screen the invite
  reaches the store (the invitee then has a pending invitation).

### Manual
Against hosted (after the spec 0010 migration is applied), two signed-in
accounts: A creates a competition and invites B by email; B sees the invitation,
accepts, and both appear as members; B cannot invite on A's competition.

## Known limitations / next increment

No results/scoreboard yet — routing a completed session to a competition is spec
0012, and the per-competition result list (Realtime) is spec 0013. There is no
leave/remove-member UI, no invitation list for the owner, and no public-browse
screen yet (later specs).
