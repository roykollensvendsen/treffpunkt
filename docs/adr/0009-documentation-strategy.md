# ADR-0009: Documentation strategy

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
The project needs first-class documentation for two audiences: users (how the
app behaves) and developers (how it is built and why).

## Decision
Publish a **MkDocs Material** site structured by the **Diátaxis** framework.
Describe the architecture with **C4 diagrams in Mermaid**, and generate the API
reference with **`dart doc`**. CI runs `mkdocs build --strict`, and updating the
relevant docs is part of every feature's Definition of Done.

## Consequences
- Documentation stays current and is built/checked on every PR.
- Authors maintain user and developer docs alongside code.

## Alternatives considered
- **Docusaurus:** great, but adds a Node toolchain to a Dart repo.
- **README-only:** does not scale to two audiences.
