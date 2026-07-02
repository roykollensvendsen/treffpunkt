# Spec 0084 — Program categories in the picker

- **Status:** Accepted
- **Related:** spec 0008 (session setup flow), spec 0043/0044 (Storluft,
  Sprintluft), spec 0067 (Silhuettpistol), spec 0068 (Feltskyting),
  `docs/reference/program-catalogue.md`

## Context

The "Velg program" page has grown to fourteen ring programs plus a
"Feltskyting" section on one flat page. That is too long to scan — finding a
program means scrolling past everything else. The NSF domain expert sketched
the wanted structure: a front page with **four categories** — **NSF Luft**,
**NSF Fin/Grov**, **MIL** and **Felt** — and the programs inside them.

## Requirements

1. The "Velg program" front page shows **four category cards** — *NSF Luft*,
   *NSF Fin/Grov*, *MIL* and *Felt*, in that order — and **no individual
   program tiles**.
2. Tapping **NSF Luft** or **NSF Fin/Grov** opens a page titled with the
   category name, listing that category's programs; tapping a program opens
   the session setup step (spec 0008) exactly as before.
3. **NSF Luft** holds the five air programs (10 m Luftpistol 60/40 skudd,
   Sprintluft, Storluft ×2). **NSF Fin/Grov** holds the nine cartridge
   programs (25 m Standard Pistol, Finpistol, Grovpistol, Hurtigpistol
   fin/grov, Silhuettpistol, NAIS fin/grov, 50 m Fripistol). Every offered
   program belongs to **exactly one** category, and the categories preserve
   the catalogue's display order.
4. **MIL** has no programs yet (none are seeded); opening it shows an empty
   state — "Ingen programmer i denne kategorien ennå." — rather than a blank
   page.
5. **Felt** opens a page listing the felt courses (today: NorgesFelt-løype
   2026), which opens the course preview (spec 0068) as before.
6. The **"Fortsett økt"** resume card (spec 0009) stays on the front page,
   above the categories.
7. Category cards, program tiles and the felt-course card are announced to
   screen readers as buttons whose label and tap action sit on the same
   semantics node.

Out of scope: the create-competition program dropdown keeps the flat
`ProgramCatalogue.all` list — a dropdown handles fourteen entries fine.

## Rationale

Grouping follows how shooters (and the NSF rulebooks) split the discipline:
air programs, the fin/grov cartridge programs, military programs and field
shooting. A two-level picker keeps each page short — four cards, then at most
nine programs.

MIL is shown from day one even though it is empty: the sketch establishes the
target structure, and an always-visible category tells users where the
military programs will land instead of surprising them with a new front page
later.

Alternatives rejected:
- **Collapsible sections on one page** — the page stays long, and
  expand/collapse state is fiddlier than a plain push navigation.
- **Tabs** — four tabs crowd a phone-width app bar that already carries four
  actions, and the felt tab would duplicate the existing felt entry point.

## Design

- `ProgramCategory` (new, `lib/features/scoring/domain/program_category.dart`)
  — a pure-Dart enum of the four categories with a Norwegian display `label`
  and one-line `description`. Felt and MIL are members even though they carry
  no `ProgramDefinition`s: the enum models the picker taxonomy, not the ring
  catalogue.
- `ProgramCatalogue` gains two partition lists, `nsfLuft` and `nsfFinGrov`,
  and `inCategory(ProgramCategory)` (empty for MIL and Felt — Felt's content
  is the felt feature's courses, not ring programs). `all` becomes the
  concatenation `[...nsfLuft, ...nsfFinGrov]`, so its contents and order are
  unchanged and everything reading `all` (competitions dropdown, `byName`)
  is untouched.
- `ProgramPickerScreen` keeps its app bar, resume card and build-version
  footer, but its list body becomes the four category cards (key
  `category-<label>`, semantics "Velg kategori: …"). It re-reads the session
  store when a category page pops, so a recording started and left
  mid-session anywhere below still surfaces as the resume card.
- `ProgramCategoryScreen` (new, stateless) renders one category: the program
  tiles (unchanged look, semantics and `program-<name>` keys) for NSF Luft /
  NSF Fin/Grov, the felt-course card (unchanged `felt-norgesfelt-2026` key)
  for Felt, and the empty state for MIL.
- `TappableCardTile` (new, `lib/core/presentation/`) is the one navigation
  tile all the picker pages render through — a `Card`-wrapped `ListTile`
  whose semantics label and tap action sit on the same node — so the
  accessibility contract (req 7) lives in one place.

## Verification

### Unit tests
- `program_catalogue_test`: `all` is exactly `[...nsfLuft, ...nsfFinGrov]`
  (partition — same elements, same order, no duplicates, nothing left over);
  `inCategory` returns the partition lists and is empty for MIL and Felt.
- `program_picker_screen_test`:
  - the front page shows the four category cards in order and no
    `program-…` tile;
  - NSF Luft → program list → tapping a program reaches the setup screen
    (`sessionConfirmKey`);
  - NSF Fin/Grov lists a cartridge program scrolled into view;
  - MIL shows the empty state;
  - Felt lists NorgesFelt-løype 2026 and opens `FeltCourseScreen`;
  - category cards and program tiles are semantic buttons with a tap action
    on the labelled node, and a semantic tap navigates;
  - the resume-card behaviours (spec 0009) are unchanged on the front page.

### System tests
- `place_shot_test`: taps *NSF Luft*, then the air-pistol program, and scores
  a shot — proving the two-level navigation end to end.
- `my_sessions_real_flow_test` (widget-level system flow): same added
  category tap on its way to a full session.

## Open questions
- Which military programs go under MIL (and their rules/faces) — to seed with
  the domain expert later.
