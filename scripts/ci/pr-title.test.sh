#!/usr/bin/env bash
set -uo pipefail

check="$(dirname "$0")/pr-title.sh"
failures=0

expect() {
  local want="$1" title="$2" got=0
  bash "$check" "$title" > /dev/null 2>&1 || got=$?
  if [[ "$got" -ne "$want" ]]; then
    echo "FAIL: '${title}' (expected exit ${want}, got ${got})"
    failures=$((failures + 1))
  else
    echo "ok: '${title}'"
  fi
}

expect 0 "feat: add invoices"
expect 0 "fix(api): handle empty body"
expect 0 "chore(deps): bump nginx from 1.30.5-alpine to 1.31.0-alpine in /apps/placeholder"
expect 0 "refactor!: drop the v0 schema"
expect 1 "Add invoices"
expect 1 "feat:add invoices"
expect 1 "feat: "
expect 1 "feature: add invoices"
expect 1 "Feat: add invoices"
expect 1 ""

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all pr-title tests passed"
