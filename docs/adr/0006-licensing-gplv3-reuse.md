# ADR-0006: GPLv3 licensing, REUSE-compliant

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
The project is released under a copyleft license, and licensing should be
unambiguous and machine-checkable across every file.

## Decision
License the project under **GPL-3.0-or-later** and follow the **REUSE**
specification: license texts live in `LICENSES/`, every file carries SPDX
copyright + license information (inline or via `REUSE.toml`), and `reuse lint`
verifies full coverage in CI.

## Consequences
- Every file's license is explicit and verifiable.
- `reuse lint` becomes a required CI check.

## Alternatives considered
- **Permissive licenses (MIT/Apache-2.0):** not the chosen model for this project.
- **Manual header checking:** more brittle than the REUSE standard.
