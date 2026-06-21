# Roadmap

Treffpunkt is built spec-by-spec. Each item below becomes a spec in
`docs/specs/`, implemented test-first.

## Increment 0 — walking skeleton (current)
- [x] Spec 0001 — 10 m air-rifle target & scoring
- [x] Pure-Dart scoring domain (integer + decimal), fully unit-tested
- [x] Tap-to-place target canvas with a live score
- [x] CI, licensing and documentation scaffolding

## Next
- [x] 0002 — Move a placed shot: long-press to pick it up (colour change) and drag
- [ ] 0003 — Authentication: Google sign-in (Supabase); register / login / logout
- [ ] 0004 — Data & RLS: competitions (public/private), invitations, results
- [ ] 0005 — Competitions: create / invite / join; target sets per competition
- [ ] 0006 — Shooting session: swipe between targets, completion & persistence
      (timestamp, discipline, shooter)
- [ ] 0007 — Per-competition scoreboard (Supabase Realtime)
- [ ] 0008 — Fair cross-competition ranking (public top-score list)
- [ ] 0009 — Browse own & public results
- [ ] 0010 — Responsive/adaptive polish; PWA install; store builds
- [ ] 0011+ — More disciplines (25 m pistol, 50 m, …)
