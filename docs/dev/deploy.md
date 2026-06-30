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

#### Optional: push notifications (spec 0060)

For Web Push notifications, also set the **VAPID public key** as a variable (it
is a public key — safe to ship; the private key never goes here):

```sh
gh variable set VAPID_PUBLIC_KEY --body "B<base64url-public-key>"
```

Without it the build still works — the notifications bell simply stays hidden.
Generating the keypair, storing the **private** key as a Supabase secret, and
deploying the sender are part of the notification-delivery step (Increment B);
see spec 0060.

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

`20260623160000_competition_results.sql` (spec 0012) adds the
`competition_results` table (the scoreboard) and its Row-Level Security, reusing
the spec-0010 helpers. Apply it before "Skyt nå" can submit results.

`20260623180000_competition_results_realtime.sql` (spec 0013) adds
`competition_results` to the `supabase_realtime` publication so the scoreboard
updates live. Apply it for live updates; RLS still scopes what each subscriber
receives.

`20260624100000_invite_registered_shooter.sql` (spec 0032) adds the
`invite_user_to_competition(cid, target_user_id)` `SECURITY DEFINER` RPC: it
verifies the caller owns the competition, resolves the chosen shooter's email
from `auth.users` server-side, and writes the same email-keyed invitation (so no
email reaches the client). No table changes. Apply it before the "Velg skytter"
invite picker can invite a registered shooter; the existing accept flow is
unchanged.

`20260624140000_training_samples.sql` (spec 0041) adds the consented
training-image dataset: a **private** `training-images` Storage bucket with
owner-prefix RLS (`<uid>/<id>.jpg`), and a `training_samples` table with
owner-only select/insert/delete RLS. Apply it before scans can be contributed.
**Erasing a user:** account deletion cascades the table rows but **not** the
Storage objects, so when deleting a user also purge their prefix — e.g. in the
SQL editor `delete from storage.objects where bucket_id = 'training-images' and
(storage.foldername(name))[1] = '<uid>';` (or `supabase storage rm --recursive
ss:///training-images/<uid>`). A self-serve "Slett mine bidrag" in the app is a
planned fast-follow.

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

## Push notifications (spec 0060)

The notification **delivery** (Increment B) is inert until the steps below are
done. The trigger migration is a no-op until configured, and the `notify`
function is not called until deployed — so the code is safe to ship first; these
are the one-time hosted steps that switch it on. They are **not** automated (they
involve secrets and a function deploy).

### 1. Generate a VAPID key pair
A VAPID key pair signs the pushes. Generate one (the public key is safe to ship;
the **private key is a secret** — keep it out of the repo and out of chat):

```sh
npx web-push generate-vapid-keys
# → Public Key:  B....   Private Key:  ....
```

### 2. Ship the public key to the web build
```sh
gh variable set VAPID_PUBLIC_KEY --body "B<public-key>"
```
Re-deploy (push to `main` or run the workflow) so the bell appears for users.

### 3. Configure and deploy the function
Pick any long random string for `NOTIFY_SECRET` (the trigger and the function
must share it). Then set the function's secrets and deploy it:

```sh
supabase secrets set \
  VAPID_PUBLIC_KEY="B<public-key>" \
  VAPID_PRIVATE_KEY="<private-key>" \
  VAPID_SUBJECT="mailto:you@example.com" \
  NOTIFY_SECRET="<random-shared-secret>"
supabase functions deploy notify   # deployed with verify_jwt = false (config.toml)
```

### 4. Apply the migrations and point the trigger at the function
Apply the push migrations (`supabase db push`, or the SQL editor). The trigger
reads its URL + shared secret from the `app_settings` table; set them with the
**same** `NOTIFY_SECRET` as step 3 (a plain INSERT, so it works over the CLI /
Management API — unlike `alter database ... set`, which the API forbids):

```sql
insert into public.app_settings (key, value) values
  ('notify_url',    'https://<ref>.supabase.co/functions/v1/notify'),
  ('notify_secret', '<random-shared-secret>')
on conflict (key) do update set value = excluded.value, updated_at = now();
```

(`supabase db query --linked -f settings.sql` applies it without handling the DB
password.) To verify: from one account post a message (or send an invitation) to
a competition another account is in, with that other account's browser subscribed
(the bell on) — a system notification should arrive. The function logs
(`supabase functions logs notify`) show each send; subscriptions the push service
has dropped are pruned automatically.
