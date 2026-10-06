#!/usr/bin/env bash
# The squash merge uses the PR title as the commit subject.
# Usage: pr-title.sh "<title>"
set -euo pipefail

title="${1:-}"
pattern='^(feat|fix|chore|docs|refactor|test|ci|perf|build|revert|style)(\([a-z0-9._/-]+\))?!?: [^ ].*$'
if [[ "$title" =~ $pattern ]]; then
  echo "PR title ok: ${title}"
else
  echo "PR title must follow Conventional Commits, e.g. 'feat: add invoices' or" \
    "'fix(api): handle empty body'. Got: '${title}'" >&2
  exit 1
fi
