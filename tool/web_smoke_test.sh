#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Web smoke test: build the web app, load it in headless Chrome, and assert the
# Flutter engine boots and renders without fatal JavaScript errors. Catches
# web-only regressions (e.g. a missing JS SDK) that the flutter-tester suite
# cannot, because it never runs in a real browser.
set -eu

port=8087

# Find a Chrome/Chromium binary.
chrome="${CHROME_BIN:-}"
if [ -z "$chrome" ]; then
  for candidate in google-chrome-stable google-chrome chromium chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      chrome="$candidate"
      break
    fi
  done
fi
[ -n "$chrome" ] || { echo "web-smoke: no Chrome/Chromium binary found"; exit 1; }

# Build with dummy config so Supabase.initialize() succeeds without a backend.
flutter build web \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=smoke-test-key

# Serve the build and wait for it to answer.
python3 -m http.server "$port" -d build/web >/dev/null 2>&1 &
server=$!
dom="$(mktemp)"
console="$(mktemp)"
trap 'kill "$server" 2>/dev/null || true; rm -f "$dom" "$console"' EXIT
curl -fsS --retry 40 --retry-delay 1 --retry-connrefused -o /dev/null \
  "http://localhost:$port/" || { echo "web-smoke: server did not start"; exit 1; }

# Load the app headless and capture the rendered DOM and the browser console.
"$chrome" --headless=new --no-sandbox --disable-gpu --enable-unsafe-swiftshader \
  --enable-logging=stderr --v=1 --virtual-time-budget=30000 \
  --dump-dom "http://localhost:$port/" >"$dom" 2>"$console"

fail=0
if ! grep -q 'flutter-view' "$dom"; then
  echo "web-smoke FAIL: Flutter engine did not boot (<flutter-view> missing)."
  fail=1
fi
fatal='Cannot read properties of undefined|Uncaught \(in promise\)'
if grep -aqE "$fatal" "$console"; then
  echo "web-smoke FAIL: fatal JavaScript error in the console:"
  grep -aE "$fatal" "$console" | sed -E 's#^.*CONSOLE[0-9: ]*\] ?##' | head -n 5
  fail=1
fi

[ "$fail" -eq 0 ] && echo "web-smoke PASS: app booted and rendered without fatal errors."
exit "$fail"
