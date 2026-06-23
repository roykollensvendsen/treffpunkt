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

## Database migrations
The SQL files under `supabase/migrations/` are **not** applied automatically.
Apply each to the hosted project with `supabase db push` (or paste it into the
SQL editor). In particular, `20260623120000_sessions.sql` creates the
`public.sessions` table with owner-only Row-Level Security and grants the
signed-in role table access; it **must be applied before personal-session
uploads take effect** (ADR-0017). Until it is applied, the best-effort upload
logs and returns, so the deployed app is unharmed.
