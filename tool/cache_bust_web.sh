#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Cache-bust the web build's entry references so a browser refresh after a deploy
# always loads the build that was just published (spec 0027).
#
# GitHub Pages serves the entry files with a 10-minute max-age and they are
# referenced by stable, un-hashed URLs: index.html -> flutter_bootstrap.js ->
# main.dart.js (the ~3 MB app bundle). Without busting, a refresh in the first
# ten minutes after a deploy serves the cached OLD bundle and the user sees no
# change. We do NOT use a service worker (--pwa-strategy=none), so the fix is to
# append a per-build version query (?v=<version>) to those two references: a new
# build yields new URLs, a guaranteed cache miss.
#
# This rewrites the BUILT output in place (build/web), not the checked-in source.
# It is fail-loud: if an expected reference is not found, or is not stamped after
# the edit, it exits non-zero so a future Flutter output-format change fails the
# deploy instead of silently shipping a non-busted build. It is idempotent: a
# reference already carrying ?v=<version> is left as-is.
#
# Usage:
#   sh tool/cache_bust_web.sh <build-web-dir> <version>
# Example (in CI, see .github/workflows/deploy.yml):
#   sh tool/cache_bust_web.sh build/web "${GITHUB_SHA::8}"
set -eu

die() {
  printf 'cache-bust: %s\n' "$1" >&2
  exit 1
}

dir="${1:-}"
version="${2:-}"

[ -n "$dir" ] || die "usage: cache_bust_web.sh <build-web-dir> <version>"
[ -n "$version" ] || die "usage: cache_bust_web.sh <build-web-dir> <version>"
[ -d "$dir" ] || die "build dir not found: $dir"

# Stamp a single reference of <bare> with ?v=<version> in <file>.
#   $1 file            the file to rewrite, in place
#   $2 match           the exact literal we expect to find (with surrounding
#                      context so we never touch a comment or a different token)
#   $3 stamped         what that literal becomes once stamped
#   $4 assert          the substring we grep for afterwards to prove success
# Fails loudly if the literal is absent and not already stamped, or if the
# assertion is missing after the edit.
stamp() {
  file="$1"
  match="$2"
  stamped="$3"
  assert="$4"

  [ -f "$file" ] || die "file not found: $file"

  # Already stamped for this version? -> idempotent no-op.
  if grep -qF -- "$assert" "$file"; then
    printf 'cache-bust: %s already references %s (skipped)\n' "$file" "$assert"
    return 0
  fi

  # The un-stamped reference must be present, or the Flutter output format
  # changed and we must NOT ship a silently non-busted build.
  grep -qF -- "$match" "$file" \
    || die "expected reference not found in $file: '$match' (Flutter output format may have changed)"

  # Rewrite in place. Use a literal sed s### with a delimiter absent from the
  # patterns; escape any sed-special characters in the operands.
  esc_match=$(printf '%s' "$match" | sed -e 's/[\\&|]/\\&/g')
  esc_stamped=$(printf '%s' "$stamped" | sed -e 's/[\\&|]/\\&/g')
  tmp="${file}.cbtmp"
  sed "s|${esc_match}|${esc_stamped}|g" "$file" >"$tmp"
  mv "$tmp" "$file"

  # Prove the stamp landed.
  grep -qF -- "$assert" "$file" \
    || die "failed to stamp $file: '$assert' not present after edit"

  printf 'cache-bust: stamped %s -> %s\n' "$file" "$assert"
}

# index.html: the real bootstrap reference is <script src="flutter_bootstrap.js"
# …>. Match on src=" so the explanatory comment (which writes the bare name
# without src=) is never rewritten, and the killswitch script stays untouched.
stamp \
  "$dir/index.html" \
  'src="flutter_bootstrap.js"' \
  "src=\"flutter_bootstrap.js?v=${version}\"" \
  "flutter_bootstrap.js?v=${version}"

# flutter_bootstrap.js: the loader resolves the bundle URL from the quoted
# "main.dart.js" string literal(s) (the default entrypointUrl and the mainJsPath
# fallback). Stamp every occurrence; they all point at the same asset.
stamp \
  "$dir/flutter_bootstrap.js" \
  '"main.dart.js"' \
  "\"main.dart.js?v=${version}\"" \
  "main.dart.js?v=${version}"

printf 'cache-bust: done (version %s)\n' "$version"
