#!/usr/bin/env bash
# Tests for deploy-gate.sh. Run: bash scripts/ci/deploy-gate.test.sh
set -uo pipefail

gate="$(dirname "$0")/deploy-gate.sh"
failures=0

expect() {
  local want="$1" name="$2" input="$3" got=0
  printf '%b' "$input" | bash "$gate" > /dev/null || got=$?
  if [[ "$got" -ne "$want" ]]; then
    echo "FAIL: ${name} (expected exit ${want}, got ${got})"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}

expect 0 "no input deploys" ""
expect 0 "ordinary PR deploys" "title:feat: add invoices\nlabel:enhancement\nmessage:feat: add invoices (#12)\n"
expect 1 "no-deploy label skips" "label:no-deploy\n"
expect 1 "label match is case-insensitive" "label:No-Deploy\n"
expect 0 "similar label deploys" "label:no-deploy-later\n"
expect 1 "tag in PR title skips" "title:chore: bump deps [no deploy]\n"
expect 1 "tag in commit message skips" "message:fix: typo [No Deploy] (#7)\n"
expect 0 "words without brackets deploy" "title:docs: explain no deploy switch\n"
expect 1 "one tagged commit in a batch skips" "message:feat: a (#1)\nmessage:feat: b [no deploy] (#2)\n"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all deploy-gate tests passed"
