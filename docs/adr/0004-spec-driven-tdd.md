# ADR-0004: Spec-driven development with strict TDD

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
The project should hold itself to a high engineering bar from the first commit,
with traceable requirements and low regression risk.

## Decision
Every feature starts with a **spec** in `docs/specs/` containing *Rationale* and
*Verification* sections. Code is written **test-first (red/green/refactor)**, and
the Verification section enumerates the exact unit and system tests.

## Consequences
- Requirements are explicit and traceable to tests.
- A slightly slower start, repaid by fewer regressions and clearer intent.
- Specs and tests must be kept in sync as features evolve.

## Alternatives considered
- **Code-first / tests-after:** faster initially, weaker guarantees and traceability.
