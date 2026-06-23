# Deploying to GitHub Pages

The web app deploys to GitHub Pages on every push to `main`
(`.github/workflows/deploy.yml`). The site is
<https://roykollensvendsen.github.io/treffpunkt/>.

The deploy job only runs once the Supabase config variables are set, so the
one-time setup below is required before the first real deploy.

## One-time setup

### 1. Hosted Supabase project
Create a project at <https://supabase.com>. From Project Settings → API note the
**Project URL** (`https://<ref>.supabase.co`) and the **publishable**
(`sb_publishable_…`) / anon key.

### 2. Google sign-in for the hosted project
- In **Google Cloud Console**, on the OAuth *Web application* client:
  - Authorized JavaScript origins: `https://roykollensvendsen.github.io`
  - Authorized redirect URI: `https://<ref>.supabase.co/auth/v1/callback`
- In the **Supabase dashboard** → Authentication → Providers → Google: enable it
  and paste the client ID + secret.
- Authentication → URL Configuration: set **Site URL** to
  `https://roykollensvendsen.github.io/treffpunkt/` and add it under
  **Redirect URLs**.

### 3. GitHub Actions variables
Set the two build-time config values (the publishable key is RLS-guarded, so it
is a variable, not a secret — see ADR-0010):

```sh
gh variable set SUPABASE_URL --body "https://<ref>.supabase.co"
gh variable set SUPABASE_PUBLISHABLE_KEY --body "sb_publishable_..."
```

(or repo Settings → Secrets and variables → Actions → Variables).

## How it works
On push to `main`, the workflow builds the web app with `--base-href
/treffpunkt/` and the variables above, then publishes `build/web` to Pages.
`--base-href` matches the repository name; update it if the repo is renamed.

## Build-version stamp (spec 0028)
The "Build web" step also injects the running build's identity so a user can
confirm at a glance which build they are on (and report it when something looks
stale):

```
--dart-define=BUILD_SHA="${GITHUB_SHA::8}"
--dart-define=BUILD_TIME="$(date -u +%Y-%m-%dT%H:%MZ)"
```

`BUILD_SHA` is the **same** 8-character short SHA the cache-bust step stamps into
the `?v=` query (spec 0027), so the SHA shown on screen equals the one in the
asset URLs. The app reads these with `String.fromEnvironment`
(`lib/config/build_info.dart`) and shows a discreet footer — `build <sha> ·
<time>` — at the bottom of the sign-in screen and the program picker. A build
without these defines (a local `flutter run`/`flutter build`, and the CI build)
falls back to `build dev`; the CI build is intentionally left on that fallback.

## Cache-busting the entry (spec 0027)
Pages serves the entry files with a 10-minute `max-age`, and they are referenced
by stable, un-hashed URLs: `index.html` loads `flutter_bootstrap.js`, which loads
`main.dart.js` (the ~3 MB app bundle). Without busting, a refresh in the first
ten minutes after a deploy is served the cached **old** bundle, so the change
appears not to have shipped.

We do **not** use a service worker (`--pwa-strategy=none`). Instead, the workflow
runs `tool/cache_bust_web.sh build/web "${GITHUB_SHA::8}"` **after** the build
and **before** the Pages upload. It appends a per-build version query
`?v=<short commit sha>` to the `flutter_bootstrap.js` reference in `index.html`
and to the `main.dart.js` reference in `flutter_bootstrap.js`. A new build yields
new URLs (a guaranteed cache miss); Pages ignores the query and serves the file,
which still exists under its original name. The script is **fail-loud** — if the
expected references are missing (e.g. a future Flutter output-format change), it
exits non-zero and the deploy fails rather than silently shipping a non-busted
build. It is idempotent, so re-running it is safe.

To run it by hand against a local build:

```sh
flutter build web --release --pwa-strategy=none --base-href /treffpunkt/ \
  --dart-define-from-file=config/env.local.json
sh tool/cache_bust_web.sh build/web "$(git rev-parse --short=8 HEAD)"
```

## Database migrations
The SQL files under `supabase/migrations/` are **not** applied automatically
(ADR-0017). Apply each to the hosted project yourself. In particular,
`20260623120000_sessions.sql` creates the `public.sessions` table with owner-only
Row-Level Security and grants the signed-in role table access; it **must be
applied before personal-session sync works** (spec 0024). Until it is applied,
the best-effort upload logs and returns and the read fails — see *Troubleshooting*
below — so recording and the local list are unharmed.

### Apply via the Supabase CLI (recommended)
From the repo root, with the [Supabase CLI](https://supabase.com/docs/guides/cli)
installed:

```sh
supabase login                                  # one-time: opens a browser for an access token
supabase link --project-ref <your-project-ref>  # one-time: prompts for the DB password
supabase db push                                # applies every pending migration
supabase migration list --linked                # confirm: each shows under both Local and Remote
```

`db push` is idempotent — already-applied migrations are skipped. (A
`failed to cache migrations catalog … pgdelta` warning is cosmetic; the
`Applying migration … Finished` line and a matching `migration list` row are the
real confirmation.)

`20260623140000_competitions.sql` (spec 0010) adds the `profiles`,
`competitions`, `competition_members` and `competition_invitations` tables with
their Row-Level Security, the `SECURITY DEFINER` helper functions, the
owner-auto-membership trigger and the `accept_invitation` RPC. Apply it the same
way; it must be applied before competitions work.

### Apply via the SQL editor (no CLI)
Open the project's **SQL editor**, paste the contents of the migration file, and
**Run**. Expect *"Success. No rows returned."*

### Troubleshooting: sessions don't sync
If saved sessions show but never sync (they keep the *"Ikke synkronisert"* badge,
and "Mine økter" shows the *"Kunne ikke hente økter fra skyen"* banner from spec
0029), the table is almost certainly missing on hosted. Confirm it from the
browser network panel: a `GET …/rest/v1/sessions` returning **`404`** means
`public.sessions` does not exist on the hosted project — apply the migration
above. A `200` means the table is live; an empty list then just means no synced
sessions yet.
