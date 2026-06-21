# ADR-0003: Riverpod for state management

- **Status:** Accepted
- **Date:** 2026-06-21

## Context
We want state management that is easy to test (without a `BuildContext`), keeps
boilerplate low, and works well with realtime streams later.

## Decision
Use **Riverpod** (`flutter_riverpod`) for application state.

## Consequences
- Providers can be read and overridden in tests without a widget tree.
- Streams (e.g. Supabase Realtime) map naturally to providers later.
- Contributors must learn Riverpod's provider model.

## Alternatives considered
- **Bloc:** robust but more ceremony than this app needs today.
- **Provider / setState:** simpler, but less testable and structured.
