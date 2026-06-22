# ADR-0010: Secrets and configuration injection

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
The app needs the Supabase URL + publishable (anon) key at runtime, and the
backend needs the Google OAuth client secret — without committing any secret to
git, and without shipping an extractable secret inside the app bundle.

## Decision
Use **two separate channels**:

- **Backend OAuth secret (a true secret):** the Google client id/secret live in
  `supabase/.env` (gitignored), referenced from `supabase/config.toml` via
  `env(...)` and resolved at `supabase start` time. The `service_role` /
  `sb_secret` key never appears in any client file or commit.
- **Flutter client config (per-environment, not a true secret):** `SUPABASE_URL`
  and `SUPABASE_PUBLISHABLE_KEY` are injected via
  `--dart-define-from-file=config/env.local.json` (gitignored) and read with
  `String.fromEnvironment` in `lib/config/app_config.dart`. The publishable/anon
  key is safe to expose because data is guarded by Row-Level Security; it is
  injected only because it is project-specific.

**Committed templates:** `config/env.example.json` (placeholders only) — and,
once the backend is initialised, `supabase/.env.example`. **Gitignored:**
`config/env.local.json`, `config/env.prod.json`, `supabase/.env`,
`supabase/.branches`, `supabase/.temp`.

## Consequences
- No secret is committed; switching environments is a config change, not a code
  change.
- `dart-define` compiles into the binary (and can be obfuscated for releases),
  unlike a bundled asset.
- Running the real app requires the config file; tests run headlessly without it.

## Alternatives considered
- **`flutter_dotenv` (.env asset):** rejected — the `.env` ships in the APK/IPA
  and is extractable.
- **Hardcoding the key:** rejected — ships the wrong per-environment key and
  needs code edits to switch.
