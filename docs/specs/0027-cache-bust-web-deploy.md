# Spec 0027 — Cache-bust the web deploy entry

- **Status:** Accepted
- **Related:** ADR-0011 (deploy to GitHub Pages), spec 0003 (Google sign-in —
  owns the service-worker killswitch in `web/index.html`),
  `.github/workflows/deploy.yml`, `docs/dev/deploy.md`

## Context

The web app is published to GitHub Pages on every push to `main` (ADR-0011).
Pages serves the entry files with `cache-control: max-age=600`, and the app's
JavaScript is referenced by **stable, un-hashed** URLs: `index.html` loads
`flutter_bootstrap.js`, which in turn loads `main.dart.js` (the ~3 MB compiled
app bundle). Because the URLs never change between builds, for up to ten minutes
after a deploy an ordinary browser refresh is served the **cached old**
`main.dart.js` from the previous build — the shooter reloads the page and sees no
change, and bug fixes appear not to have shipped.

We deliberately run **without a service worker** (`--pwa-strategy=none`), and
`web/index.html` carries a killswitch that unregisters any leftover worker and
clears its caches (spec 0003), so the staleness is purely HTTP caching of those
two un-hashed entry files — not a PWA cache.

This spec makes every deploy **cache-bust the app entry** so a normal refresh
always loads the build that was just published, while keeping `--pwa-strategy=none`
and the existing killswitch intact.

## Requirements

1. **Per-build versioned entry URLs.** Each deploy stamps the two un-hashed
   entry references with a per-build version query `?v=<version>`, where
   `<version>` is the short commit SHA (`${GITHUB_SHA::8}`):
   - the `flutter_bootstrap.js` reference in `index.html` becomes
     `flutter_bootstrap.js?v=<version>`;
   - the `main.dart.js` reference(s) in `flutter_bootstrap.js` become
     `main.dart.js?v=<version>`.
   A new build produces new URLs, which a cache cannot have seen, so the browser
   is forced to fetch the new bundle (a guaranteed cache miss). `index.html`
   itself is revalidated on reload and then points at the new versioned assets.
2. **No service worker, killswitch untouched.** The approach adds **no** service
   worker and does **not** change `--pwa-strategy=none`. The existing
   service-worker killswitch script in `web/index.html` (spec 0003) is left
   exactly as-is.
3. **Apply at build time, in the pipeline.** A POSIX-shell script
   `tool/cache_bust_web.sh <build-web-dir> <version>` rewrites the built output
   in place. It runs in `.github/workflows/deploy.yml` **after** "Build web" and
   **before** `actions/upload-pages-artifact`, so only the published artifact is
   stamped — the checked-in `web/index.html` source is never modified.
4. **Fail loud.** The script must **fail the deploy** rather than silently ship a
   non-busted build. After each edit it greps the file to confirm the
   `?v=<version>` reference is present, and exits non-zero with a clear message
   if the expected pattern was not found or not applied. This guards against a
   future Flutter output-format change that would otherwise let an un-busted
   build through unnoticed.
5. **Safe to re-run.** The script is idempotent: running it twice with the same
   version does not append the query twice and does not error.
6. **Assets still resolve.** The versioned references point at files that still
   exist on disk under their original names (`flutter_bootstrap.js`,
   `main.dart.js`); Pages ignores the query string and serves the file, so the
   app still loads.

## Rationale

**Versioned URLs, not a service worker.** The cleanest fix for un-hashed entry
files is to make the URL change every build. We append a query string rather than
rename files because the Flutter loader resolves the entrypoint URL through
`new URL(path, document.baseURI)` (in `flutter_bootstrap.js`) — a query string is
a valid, preserved URL component, the asset on disk keeps its original name, and
Pages serves the file ignoring the query. Renaming `main.dart.js` would instead
require rewriting the loader's hashing logic and risk breaking it. A **service
worker** would also defeat the cache, but it reintroduces exactly the PWA cache
we removed in spec 0003 (and a worker that caches the old entry is itself a
classic stale-deploy source); ADR-0011 keeps `--pwa-strategy=none`, so a
build-time URL stamp is the smaller, more predictable change. Content hashing the
filenames (the usual bundler approach) is not something `flutter build web`
emits for the entry files, so a post-build stamp is the pragmatic equivalent.

**The short commit SHA as the version.** It is unique per build, already
available in the workflow as `${GITHUB_SHA::8}`, monotonic-enough for cache
purposes, and lets anyone reading the served HTML map the running build back to a
commit. Any per-build-unique token would do; the SHA needs no extra state.

**A post-build rewrite, not an edited source file.** Stamping the *built* output
(rather than templating `web/index.html`) keeps the committed source clean and
diffable, keeps the killswitch script literal and reviewable, and means the
version is injected by the same pipeline that knows the SHA. It also keeps the
local `flutter run` / `flutter build` experience unchanged.

**Fail-loud over silent.** `flutter build web`'s exact output format is not a
stable contract; a future version could rename `flutter_bootstrap.js`, change how
`main.dart.js` is referenced, or inline it. If the patterns the script expects
disappear, shipping a *silently* un-busted build would resurrect this exact bug
and be hard to notice. Asserting the stamped reference is present after each edit
and failing the deploy turns a format change into a loud, immediate CI failure
that a maintainer fixes once, instead of a slow user-visible regression.

## Design

```
tool/cache_bust_web.sh <build-web-dir> <version>
  index.html:
    src="flutter_bootstrap.js"  ->  src="flutter_bootstrap.js?v=<version>"
      (only the real <script src=…> reference; the surrounding comment that
       mentions "flutter_bootstrap.js" without src= is left untouched)
  flutter_bootstrap.js:
    "main.dart.js"  ->  "main.dart.js?v=<version>"
      (every quoted entrypoint-URL string literal: the loader's default
       entrypointUrl and the mainJsPath fallback)
  after each edit: grep the rewritten reference; exit 1 with a clear message
  if it is absent. Idempotent: a reference already carrying ?v=<version> is
  skipped, not double-stamped.

.github/workflows/deploy.yml
  - Build web (unchanged flags: --release --pwa-strategy=none
    --base-href /treffpunkt/ --dart-define=…)
  - NEW: run sh tool/cache_bust_web.sh build/web "${GITHUB_SHA::8}"
  - actions/upload-pages-artifact (path: build/web)
```

The script matches the **real** references precisely: in `index.html` it stamps
only `src="flutter_bootstrap.js"` (so the explanatory comment, which writes
`"flutter_bootstrap.js"` without `src=`, is never rewritten); in
`flutter_bootstrap.js` it stamps the quoted `"main.dart.js"` string literal(s)
the Flutter loader resolves into the bundle URL. It detects an
already-stamped reference (`?v=<version>`) and treats that file as done, so a
re-run is a no-op.

## Verification

This is a build/deploy change with **no Dart logic**, so it is verified by the
script's own fail-loud assertions and a manual local run against a real
`flutter build web` output, not by the Dart unit/widget suites (which stay green
because no Dart changes).

### Script self-checks (run in CI, on every deploy)

- After stamping `index.html`, the script greps for
  `flutter_bootstrap.js?v=<version>` and **exits non-zero** if it is absent.
- After stamping `flutter_bootstrap.js`, the script greps for
  `main.dart.js?v=<version>` and **exits non-zero** if it is absent.
- A missing argument (`<build-web-dir>` or `<version>`), a missing directory, or
  a missing file exits non-zero with a usage/clear message.

### Manual verification (performed once, against a real build)

- Build web locally with the workflow flags
  (`--release --pwa-strategy=none --base-href /treffpunkt/
  --dart-define-from-file=config/env.local.json`), run
  `sh tool/cache_bust_web.sh build/web <sha>`, and confirm:
  - `build/web/index.html` now references `flutter_bootstrap.js?v=<sha>`;
  - `build/web/flutter_bootstrap.js` now references `main.dart.js?v=<sha>`;
  - the comment line in `index.html` is unchanged and the killswitch script is
    byte-for-byte intact;
  - `build/web/flutter_bootstrap.js` and `build/web/main.dart.js` still exist on
    disk under their original names (the query is not part of the filename);
  - a second run is a no-op (idempotent), and pointing the script at a directory
    whose files lack the pattern exits non-zero (fail-loud).

## Open questions

- Content-hashed asset filenames (a true fingerprint instead of a query) would
  also let us drop the killswitch eventually, but `flutter build web` does not
  emit hashed entry filenames today; revisit if it does.
- Pinning a `cache-control: no-cache` header on `index.html` would let it
  revalidate instantly, but GitHub Pages does not expose per-file cache headers,
  which is exactly why the versioned-URL approach is needed.
