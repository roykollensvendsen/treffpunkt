# ADR-0008: Readable, modular code and plain-language history

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
Humans — not just tools — must be able to read and understand the codebase and
the project history quickly.

## Decision
Favour a **modular, human-readable** codebase: small single-responsibility
modules with descriptive names, doc comments on public APIs (enforced by the
`public_member_api_docs` lint), short functions, and a feature-first layout with
a pure-Dart domain layer. Every commit body and PR description **leads with an
everyday-language explanation** before the technical detail.

## Consequences
- Easier onboarding and review; one file is understandable on its own.
- Requires ongoing discipline in naming, structure and writing.

## Alternatives considered
- **Layer-first structure / terse commits:** harder to navigate and understand.
