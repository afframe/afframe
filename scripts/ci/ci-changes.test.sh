#!/usr/bin/env bash
# Runs on a scratch git repository.
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }

script="$(cd "$(dirname "$0")" && pwd)/ci-changes.sh"
repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT
failures=0

git -C "$repo" init -q
git -C "$repo" config user.email test@example.org
git -C "$repo" config user.name test
commit() {
  local path
  for path in "$@"; do mkdir -p "$repo/$(dirname "$path")" && echo "$RANDOM" >> "$repo/$path"; done
  git -C "$repo" add -A && git -C "$repo" commit -q -m change && git -C "$repo" rev-parse HEAD
}
# expect <name> <stdout> <base>   (exit code must be 0)
expect() {
  local name="$1" want="$2" out
  out="$(cd "$repo" && bash "$script" "$3" 2> /dev/null)" || out="exit $?"
  out="$(tr '\n' ' ' <<< "$out")"
  if [[ "$out" == "$want" ]]; then
    echo "ok: $name"
  else
    echo "FAIL: $name (got '$out')"
    failures=$((failures + 1))
  fi
}

a='{"name":"a","dir":"apps/a"}' b='{"name":"b","dir":"apps/b"}'
c0="$(commit apps/a/Dockerfile apps/b/Dockerfile compose.ci.yml README.md)"
c1="$(commit apps/a/src)"
expect "one app changed" "services=[$a] tests=true integration=false deploy_tests=false " "$c0"
c2="$(commit README.md)"
expect "docs only builds nothing" "services=[] tests=false integration=false deploy_tests=false " "$c1"
c3="$(commit compose.ci.yml)"
expect "shared CI file builds everything" "services=[$a,$b] tests=true integration=false deploy_tests=false " "$c2"
c4="$(commit deploy/bin/x)"
expect "deploy/ change runs integration" "services=[] tests=false integration=true deploy_tests=true " "$c3"
c5="$(commit .github/workflows/deploy.yml)"
expect "deploy workflow change runs integration" "services=[] tests=false integration=true deploy_tests=false " "$c4"
c6="$(commit scripts/ci/build-images.sh)"
expect "image build script change builds everything" \
  "services=[$a,$b] tests=true integration=false deploy_tests=true " "$c5"
c7="$(commit scripts/ci/trivy/Dockerfile)"
expect "scanner pin change builds and scans everything" \
  "services=[$a,$b] tests=true integration=false deploy_tests=true " "$c6"
c8="$(commit scripts/ci/image-scan.sh)"
expect "scan script change builds and scans everything" \
  "services=[$a,$b] tests=true integration=false deploy_tests=true " "$c7"
c9="$(commit scripts/ci/repo-lint.sh)"
expect "other scripts/ci change runs the deploy unit tests" \
  "services=[] tests=false integration=false deploy_tests=true " "$c8"
prev="$c9"
# The root inputs of the real .dockerignore: each one must change the result.
inputs="$(sed -n 's/^!//p' "$(dirname "$script")/../../.dockerignore" \
  | grep -vx apps | sed 's|^packages$|packages/ui/src|')"
# shellcheck disable=SC2086 # one path per word
for path in $inputs .dockerignore; do
  next="$(commit "$path")"
  expect "workspace input $path builds everything" \
    "services=[$a,$b] tests=true integration=false deploy_tests=false " "$prev"
  prev="$next"
done
next="$(commit deploy/postgres/Dockerfile)"
expect "Postgres image change builds everything and runs integration" \
  "services=[$a,$b] tests=true integration=true deploy_tests=true " "$prev"
prev="$next"
commit apps/a/package.json docs/packages/x > /dev/null
expect "an app's package.json or a packages/ name elsewhere is not shared" \
  "services=[$a] tests=true integration=false deploy_tests=false " "$prev"
prev="$(git -C "$repo" rev-parse HEAD)"
commit deploy/services/a.conf > /dev/null
expect "conf-only change builds its service" "services=[$a] tests=true integration=true deploy_tests=true " "$prev"
git -C "$repo" rm -q deploy/services/a.conf && git -C "$repo" commit -q -m rm
prev="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" mv apps/a/package.json docs/package.json && git -C "$repo" commit -q -m mv
expect "a rename out of an app changes the app" "services=[$a] tests=true integration=false deploy_tests=false " "$prev"
expect "all builds everything and runs integration" \
  "services=[$a,$b] tests=true integration=true deploy_tests=true " all
expect "empty base means all" "services=[$a,$b] tests=true integration=true deploy_tests=true " ""
expect "base unknown to git means all" \
  "services=[$a,$b] tests=true integration=true deploy_tests=true " "$(printf 'f%.0s' {1..40})"

commit deploy/services/z.conf > /dev/null
if (cd "$repo" && bash "$script" all > /dev/null 2>&1); then
  echo "FAIL: conf without an app fails"
  failures=$((failures + 1))
else
  echo "ok: conf without an app fails"
fi
git -C "$repo" rm -q deploy/services/z.conf && git -C "$repo" commit -q -m rm
git -C "$repo" rm -q compose.ci.yml && git -C "$repo" commit -q -m rm
expect "no compose.ci.yml: no tests" "services=[$a,$b] tests=false integration=true deploy_tests=true " all
commit deploy/services/a.conf > /dev/null
if (cd "$repo" && bash "$script" all > /dev/null 2>&1); then
  echo "FAIL: deployable service without compose.ci.yml fails closed"
  failures=$((failures + 1))
else
  echo "ok: deployable service without compose.ci.yml fails closed"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all ci-changes tests passed"
