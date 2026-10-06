#!/usr/bin/env bash
# Needs bash 3.2 or later.
# Without a Docker daemon it runs the *.test.sh scripts whose tools exist. The rest runs in ci.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! docker info > /dev/null 2>&1; then
  failed=0 skipped=""
  log="$(mktemp)"
  trap 'rm -f "$log"' EXIT
  for test_script in $(git ls-files '*.test.sh'); do
    case "$test_script" in
      deploy/test/afframe-deploy.test.sh) needs="flock cmp sha256sum timeout" ;;
      deploy/test/vault-env.test.sh | scripts/ci/ci-changes.test.sh | scripts/ci/service-tests.test.sh \
        | .claude/hooks/pr-title.test.sh | .claude/hooks/published-text.test.sh) needs="jq" ;;
      *) needs="" ;;
    esac
    missing=""
    for cmd in $needs; do command -v "$cmd" > /dev/null || missing="$missing $cmd"; done
    if [[ -n "$missing" ]]; then
      echo "skip: ${test_script} needs${missing}"
      skipped="$skipped $test_script"
    elif bash "$test_script" > "$log" 2>&1; then
      echo "${test_script}: ok"
    else
      echo "${test_script}: FAILED"
      cat "$log"
      failed=1
    fi
  done
  what="Lint and service tests"
  [[ -z "$skipped" ]] || what="Lint, service tests and${skipped}"
  echo "PARTIAL GATE: no Docker daemon. ${what} run only in ci on the PR."
  exit "$failed"
fi

bash scripts/ci/repo-lint.sh

[[ -f compose.ci.yml ]] || exit 0

echo "== compose.ci.yml"
bash scripts/ci/service-tests.sh "gate-$$"
