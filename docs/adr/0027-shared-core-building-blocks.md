# ADR-0027: Delte byggeklosser i lib/core — dedup-konvensjoner

- **Status:** Accepted
- **Date:** 2026-07-06

## Context
The same small rules — score comparison, time formatting, sync plumbing —
have been written more than once inside different features. Duplicates drift
apart, and each copy must be tested and reviewed on its own.

## Decision
The codebase deduplicates via **small shared primitives** in
`lib/core/{domain,data,presentation,sync}` (e.g. `lib/core/domain/lexi_score.dart`
for the lexicographic points-then-inner score comparison).

The discipline:

- **Introduce-primitive PRs** add the shared building block as *new files
  only*, with their own unit tests.
- **Call-site migration PRs** then rewire one screen group at a time onto
  the primitive.
- Extractions must **preserve observable behavior** — user-visible strings
  stay byte-identical, and the existing tests of the call sites are the net.
- `InMemory*` test fakes and SQL policies are deliberately **not**
  genericized: each copy stays plain and self-contained so it can be read
  and audited on its own.

## Consequences
- One tested implementation per rule; features share it instead of
  re-deriving it.
- Refactors land as small, reviewable, behavior-neutral PRs.
- A little duplication remains where clarity and auditability outweigh
  dedup (fakes, SQL).

## Alternatives considered
- **Big-bang refactor PRs:** touch primitives and every call site at once —
  harder to review and to bisect when behavior shifts.
- **Genericizing everything (fakes, SQL included):** less code, but the
  indirection hides what a test or policy actually does.
