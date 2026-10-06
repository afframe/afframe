#!/usr/bin/env bash
# Needs bash 3.2 or later.
# Without a Docker daemon it runs only *.test.sh. A test exits 77 to skip when a tool is missing.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if docker info > /dev/null 2>&1; then
  bash scripts/ci/repo-lint.sh
  [[ ! -f compose.ci.yml ]] || bash scripts/ci/service-tests.sh "gate-$$"
  exit 0
fi

failed=0
for test_script in $(git ls-files '*.test.sh'); do
  if out="$(bash "$test_script" 2>&1)"; then
    echo "${test_script}: ok"
  elif (($? == 77)); then
    echo "${test_script}: ${out}"
  else
    echo "${test_script}: FAILED"
    echo "$out"
    failed=1
  fi
done
echo "PARTIAL GATE: no Docker daemon. Lint and service tests run only in ci on the PR."
exit "$failed"
