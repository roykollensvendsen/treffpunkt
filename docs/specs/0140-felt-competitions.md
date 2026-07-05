# Spec 0140 — NorgesFelt-konkurranser, låst til gruppe

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-05 («har vi mulighet
  for å legge inn norgesfelt konkurranser? … lås til gruppe. ja»);
  specs 0011/0012 (competitions), 0080–0083 (felt), 0088 (groups)

## Context

Competitions were ring-only: the create form offered the catalogue
programs, and «Skyt for konkurransen» opened the ring recorder. Felt
rounds already carry exactly the scoreboard's semantics — points with
inner hits as the tiebreak — but had no way into a competition.

## Rationale

- **The group is the program.** The groups shoot different courses
  (Gruppe 1: 6 shots/hold, max 80; Gruppe 2: 5, max 47), so a fair
  competition is per group — the owner's call. Encoding the group in
  the program name («NorgesFelt-løype 2026 (Gruppe 1)») locks it at
  creation with zero schema changes, shows it everywhere the program
  is displayed, and old clients render it as text.
- **Mirror the ring path.** `FeltSessionRecord` gains an optional
  `competitionId`; the felt sync submits a `CompetitionResult`
  (points as total, inner hits as innerTens, the round as payload)
  after upload, exactly where the ring queue does — same offline
  resilience, same idempotent upsert by round id.
- **The recorder obeys the lock**: shooting for a felt competition
  skips the group picker and pins the competition's group.
- **The scoreboard can open a felt result**: the result screen tries
  the ring snapshot first, then the felt round, and renders the felt
  scorecard — instead of «kan ikke vise».

## Requirements

1. The create form offers «NorgesFelt-løype 2026 (Gruppe 1)» and
   «(Gruppe 2)» alongside the ring programs.
2. «Skyt for konkurransen» on a felt competition opens the felt setup
   and a recorder locked to the competition's group (no picker, no
   group switch).
3. Saving the round submits the competition result (points, inner
   hits, max for the group) through the felt sync — offline rounds
   submit when they upload.
4. The scoreboard row opens the felt scorecard for felt results.

## Verification

- Domain: program-name encode/parse round-trip; group max points
  (80/47) asserted against the course data.
- Widget: creating a felt competition stores the encoded program;
  shooting for it opens the recorder with the locked group and no
  picker; saving submits a result with the round's points and inner
  hits; the result screen renders a felt payload as the felt
  scorecard.
- Full suite green; ring competitions unchanged.
