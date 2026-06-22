#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Runs each integration test file on the headless flutter-tester device.
#
# Running several integration files in a single `flutter test` invocation fails
# to start the app for the second file, so we run them one at a time.
set -eu

for file in integration_test/*_test.dart; do
  echo "== $file =="
  flutter test "$file" -d flutter-tester
done
