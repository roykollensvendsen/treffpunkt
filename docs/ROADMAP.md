# Roadmap

Treffpunkt is built spec-by-spec. Each item below becomes a spec in
`docs/specs/`, implemented test-first.

## Increment 0 — walking skeleton (current)
- [x] Spec 0001 — 10 m air-rifle target & scoring
- [x] Pure-Dart scoring domain (integer + decimal), fully unit-tested
- [x] Tap-to-place target canvas with a live score
- [x] CI, licensing and documentation scaffolding

## Next
- [ ] 0002 — Authentication: Google sign-in (Supabase); register / login / logout
- [ ] 0003 — Data & RLS: competitions (public/private), invitations, results
- [ ] 0004 — Competitions: create / invite / join; target sets per competition
- [ ] 0005 — Shooting session: long-press to move a shot, swipe between targets,
      completion & persistence (timestamp, discipline, shooter)
- [ ] 0006 — Per-competition scoreboard (Supabase Realtime)
- [ ] 0007 — Fair cross-competition ranking (public top-score list)
- [ ] 0008 — Browse own & public results
- [ ] 0009 — Responsive/adaptive polish; PWA install; store builds
- [ ] 0010+ — More disciplines (25 m pistol, 50 m, …)
