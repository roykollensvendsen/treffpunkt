# ADR-0011: Deploy the web app to GitHub Pages

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
We want the web build hosted somewhere public so it can be tried in a browser,
with as little new infrastructure as possible.

## Decision
Deploy the Flutter web build to **GitHub Pages** via a GitHub Actions workflow
(`.github/workflows/deploy.yml`) on every push to `main`. The build uses
`--base-href /treffpunkt/` (the project-site path) and injects the Supabase URL +
publishable key from GitHub Actions **variables** (per-environment config, not
secrets — see ADR-0010). The deploy job is skipped until those variables are set.

The app talks to a **hosted Supabase project** in production (the local CLI stack
is dev-only). Pages is free for public repositories, so the repository is public.

## Consequences
- A push to `main` publishes the site automatically; no extra hosting service.
- Requires a hosted Supabase project and the Google OAuth redirect URLs to
  include the Pages URL (see `docs/dev/deploy.md`).
- Native Android/iOS distribution is a separate concern (a later spec).
- The web build uses `--pwa-strategy=none` (no service worker), so a new deploy
  is not served from a stale cache; revisit if PWA install is wanted
  (ROADMAP 0016).

## Alternatives considered
- **Firebase Hosting / Netlify / Vercel:** capable, but add another account and
  service; Pages reuses the existing GitHub + Actions setup.
