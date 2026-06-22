# ADR-0002: Supabase for backend, auth and data

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
We need Google sign-in, multiple users, public and private competitions,
invitations, per-competition scoreboards and a fair cross-competition
leaderboard — ideally with realtime updates.

## Decision
Use **Supabase**: Postgres, Google OAuth, Realtime and Row-Level Security (RLS).

## Consequences
- SQL fits the analytical, relational nature of fair leaderboards.
- RLS models public/private visibility cleanly and close to the data.
- Open-source and portable. Auth arrives at spec 0003; the data layer and RLS at
  spec 0010.

## Alternatives considered
- **Firebase:** fastest realtime, but NoSQL makes fair ranking harder.
- **Custom backend (FastAPI/NestJS + Postgres):** most control, most work.
