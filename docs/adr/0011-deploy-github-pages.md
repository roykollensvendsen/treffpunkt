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

**Cache-busting (spec 0027).** Pages serves the entry files with a 10-minute
`max-age` and they are referenced by stable, un-hashed URLs (`index.html` →
`flutter_bootstrap.js` → `main.dart.js`), so for up to ten minutes after a deploy
a normal refresh is served the cached *old* bundle and the change appears not to
have shipped. We fix this **without a service worker**: a build step
(`tool/cache_bust_web.sh`, run after `flutter build web` and before the Pages
upload) appends a per-build version query `?v=<short commit sha>` to the
`flutter_bootstrap.js` reference in `index.html` and to the `main.dart.js`
reference in `flutter_bootstrap.js`. A new build yields new URLs — a guaranteed
cache miss — and `index.html` is revalidated on reload and then points at the new
versioned assets. We chose versioned URLs over a service worker because a worker
would reintroduce the very PWA cache we removed with `--pwa-strategy=none` (and a
worker caching the old entry is itself a classic stale-deploy source); the query
stamps the *built* output, so the checked-in source and the killswitch script
stay clean. The step is **fail-loud**: if the expected references are missing
(e.g. a future Flutter output-format change), the deploy fails rather than
silently shipping a non-busted build.

## Consequences
- A push to `main` publishes the site automatically; no extra hosting service.
- Requires a hosted Supabase project and the Google OAuth redirect URLs to
  include the Pages URL (see `docs/dev/deploy.md`).
- Native Android/iOS distribution is a separate concern (a later spec).
- The web build uses `--pwa-strategy=none` (no service worker). Because the
  entry files are referenced by stable un-hashed URLs that Pages caches for ten
  minutes, each deploy cache-busts them with a per-build `?v=<sha>` query
  (spec 0027) so a refresh always loads the latest build; revisit if PWA install
  is wanted (ROADMAP 0016).

## Alternatives considered
- **Firebase Hosting / Netlify / Vercel:** capable, but add another account and
  service; Pages reuses the existing GitHub + Actions setup.
