# ADR-0005: Commit-message policy

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
We want a clean, readable git history with no tool-attribution noise, and
messages that anyone can understand.

## Decision
Commit subjects follow **Conventional Commits**. Bodies **open with a
plain-language explanation**, then the specifics. Messages must contain **no
references to AI agents**. All three are enforced by `tool/commit_lint.sh`,
which runs both in the `commit-msg` git hook and in CI.

## Consequences
- Consistent, human-first history; one validator shared by hook and CI.
- Contributors enable the hook once via `tool/setup.sh`; CI re-checks every PR.

## Alternatives considered
- **Free-form commits:** inconsistent and hard to scan.
- **commitlint (Node):** capable, but adds a Node toolchain to a Dart repo.
