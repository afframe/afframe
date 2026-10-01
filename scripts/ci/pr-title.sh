#!/usr/bin/env bash
# Checks a PR title against Conventional Commits; the squash merge uses it as the commit subject.
# Usage: pr-title.sh "<title>"
set -euo pipefail

title="${1:-}"
pattern='^(feat|fix|chore|docs|refactor|test|ci|perf|build|revert|style)(\([a-z0-9._/-]+\))?!?: [^ ].*$'
if [[ "$title" =~ $pattern ]]; then
  echo "PR title ok: ${title}"
else
  echo "PR title must follow Conventional Commits, e.g. 'feat: add invoices' or 'fix(api): handle empty body'. Got: '${title}'" >&2
  exit 1
fi
