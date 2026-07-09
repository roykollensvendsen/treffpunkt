#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Tests for tool/commit_lint.sh — run `sh tool/commit_lint_test.sh`.
# Each case asserts the linter accepts (exit 0) or rejects (exit non-zero) a
# message. Wired into CI alongside the linter itself.
set -u

here="$(dirname "$0")"
lint="$here/commit_lint.sh"
fails=0

# ok "<label>" "<message>" — expect the linter to ACCEPT the message.
ok() {
  if sh "$lint" --message "$2" >/dev/null 2>&1; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s (expected accept, got reject)\n' "$1"
    fails=$((fails + 1))
  fi
}

# no "<label>" "<message>" — expect the linter to REJECT the message.
no() {
  if sh "$lint" --message "$2" >/dev/null 2>&1; then
    printf 'FAIL  %s (expected reject, got accept)\n' "$1"
    fails=$((fails + 1))
  else
    printf 'ok    %s\n' "$1"
  fi
}

# --- Accepted -------------------------------------------------------------
ok 'plain conventional commit' \
  'feat(scoring): add decimal scoring for 10m air rifle'
ok 'dotfile path in subject' \
  'chore(config): tweak .claude/settings.json'
ok 'dotfile path in body' \
  "$(printf 'feat(agents): add the design reviewer\n\nLives under .claude/agents/ so it is versioned with the app.')"
ok 'skills dotpath' \
  "$(printf 'chore(skills): note the render step\n\nSee .claude/skills/reference-to-pictogram.')"

# --- Rejected: attribution still caught -----------------------------------
no 'co-authored-by trailer' \
  "$(printf 'feat: add a thing\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
no 'session URL (claude.ai)' \
  "$(printf 'feat: add a thing\n\nClaude-Session: https://claude.ai/code/session_x')"
no 'generated-with line' \
  "$(printf 'feat: rework the parser\n\nGenerated with Claude Code.')"
no 'robot emoji' \
  'feat: ship it 🤖'
no 'bare ChatGPT mention' \
  'feat: ask ChatGPT to explain the regex'
no 'openai domain' \
  "$(printf 'feat: add a thing\n\nsee https://openai.com/x')"

# --- Rejected: existing format rules unchanged ----------------------------
no 'non-conventional subject' 'add a thing'

if [ "$fails" -eq 0 ]; then
  printf '\nAll commit-lint tests passed.\n'
  exit 0
fi
printf '\n%d commit-lint test(s) failed.\n' "$fails"
exit 1
