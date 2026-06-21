#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate a commit message against the Treffpunkt commit policy:
#   1) Conventional Commits format on the subject line.
#   2) No references to AI agents anywhere in the message.
#
# This single script is the source of truth used by both the local
# `.githooks/commit-msg` hook and the CI `commitlint` job.
#
# Usage:
#   commit_lint.sh <path-to-commit-msg-file>
#   commit_lint.sh --message "<message>"
set -eu

die() {
  printf 'commit-lint: %s\n' "$1" >&2
  printf '%s\n' "$2" >&2
  exit 1
}

if [ "${1:-}" = "--message" ]; then
  msg="${2:-}"
else
  file="${1:?usage: commit_lint.sh <commit-msg-file>}"
  msg="$(cat "$file")"
fi

# Subject = first non-empty, non-comment line.
subject="$(printf '%s\n' "$msg" | grep -vE '^[[:space:]]*#' | grep -vE '^[[:space:]]*$' | head -n1)"

# Auto-generated commits (merges, reverts, fixup/squash) skip format & length.
if printf '%s' "$subject" | grep -qE '^(Merge |Revert |fixup!|squash!)'; then
  special=1
else
  special=0
fi

# Rule 1: Conventional Commits format.
conv='^(feat|fix|docs|test|refactor|chore|ci|build|perf|style|revert)(\([a-z0-9._/-]+\))?!?: .+'
if [ "$special" -eq 0 ] && ! printf '%s' "$subject" | grep -qE "$conv"; then
  die "subject is not a Conventional Commit" \
"  got:      $subject
  expected: <type>(<scope>): <description>
  types:    feat fix docs test refactor chore ci build perf style revert
  example:  feat(scoring): add decimal scoring for 10m air rifle
  see https://www.conventionalcommits.org/"
fi

# Keep the subject readable in `git log` (auto-generated commits exempt).
if [ "$special" -eq 0 ] && [ "${#subject}" -gt 72 ]; then
  die "subject line is ${#subject} characters (max 72)" "  $subject"
fi

# Rule 2: no AI-agent references anywhere in the message.
ai='claude|anthropic|chatgpt|openai|copilot|codeium|🤖'
if printf '%s' "$msg" | grep -qiE "$ai"; then
  die "commit message references an AI agent (not allowed in this repo)" \
"  remove any mention of: Claude, Anthropic, ChatGPT, OpenAI, Copilot, Codeium, 🤖
  and any Co-Authored-By / generated-with trailers that name a bot."
fi
if printf '%s' "$msg" | grep -qiE '^co-authored-by:.*(bot|\[bot\]|gpt)'; then
  die "commit message has an AI/bot Co-Authored-By trailer (not allowed)" \
"  remove the trailer."
fi

exit 0
