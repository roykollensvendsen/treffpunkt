#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later

# One-time developer bootstrap for Treffpunkt.
# Enables the project git hooks and fetches Dart/Flutter packages.
set -eu

root="$(git rev-parse --show-toplevel)"
cd "$root"

echo "Enabling project git hooks (.githooks)..."
git config core.hooksPath .githooks
chmod +x .githooks/* tool/*.sh 2>/dev/null || true

echo "Fetching Dart/Flutter packages..."
flutter pub get

echo
echo "Done."
echo "Optional, for local license/docs checks:"
echo "  pip install reuse mkdocs-material   # then: reuse lint  /  mkdocs build --strict"
