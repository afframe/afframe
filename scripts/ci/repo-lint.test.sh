#!/usr/bin/env bash
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }
((BASH_VERSINFO[0] >= 4)) || { echo "skip: repo-lint.sh needs bash 4 for mapfile"; exit 77; }

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export FAKE="$work/fake" MARK="$work/marks" CI=1 AFFRAME_TOOLBOX=1
mkdir -p "$FAKE/bin" "$MARK" "$work/repo/scripts/ci" "$work/repo/deploy/test"
cp "$root/scripts/ci/repo-lint.sh" "$work/repo/scripts/ci/repo-lint.sh"
git -C "$work/repo" init -q

# $FAKE/fail-<tool>: the stub of <tool> exits 1.
for tool in actionlint zizmor shellcheck gitleaks; do
  cat > "$FAKE/bin/$tool" <<FAKETOOL
#!/usr/bin/env bash
[[ ! -e "\$FAKE/fail-$tool" ]] || { echo "$tool found a problem"; exit 1; }
FAKETOOL
done
# A compose answer that meets every jq assertion of check_compose.
cat > "$FAKE/bin/docker-compose" <<'FAKECOMPOSE'
#!/usr/bin/env bash
[[ ! -e "$FAKE/fail-compose" ]] || exit 1
[[ "$*" == *"--format json"* ]] || exit 0
cat <<'JSON'
{"networks": {"db": {"internal": true}, "edge": {}},
 "services": {"postgres": {"networks": {"db": null, "edge": null},
  "volumes": [{"source": "postgres-data", "target": "/var/lib/postgresql"}]}}}
JSON
FAKECOMPOSE
chmod +x "$FAKE/bin/"*

# add_test <path> <exit code>: a tracked test that leaves a mark.
add_test() {
  cat > "$work/repo/$1" <<FAKETEST
#!/usr/bin/env bash
touch "\$MARK/${1//\//_}"
exit $2
FAKETEST
  git -C "$work/repo" add "$1"
}
add_test scripts/ci/plain.test.sh 0
add_test deploy/test/x.test.sh 0
git -C "$work/repo" add scripts/ci/repo-lint.sh

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
lint() {
  rm -f "$MARK"/*
  (cd "$work/repo" && env ${@+"$@"} PATH="$FAKE/bin:$PATH" bash scripts/ci/repo-lint.sh) > "$FAKE/out" 2>&1
}
printed() { grep -qF -- "$1" "$FAKE/out"; }
marked() { [[ -e "$MARK/$1" ]]; }

check "all checks pass: exit 0" lint
check "and reports the count" printed "repo-lint: all 8 checks passed"
check "and runs the test scripts" marked scripts_ci_plain.test.sh
check "and runs the deploy tests" marked deploy_test_x.test.sh

touch "$FAKE/fail-shellcheck"
check "one failing tool: exit 1" fails lint
check "and prints one ::error:: line naming it" printed "::error::repo-lint: shellcheck failed"
check "and names no other tool" fails printed "::error::repo-lint: actionlint failed"
check "and still runs the test scripts" marked scripts_ci_plain.test.sh
rm "$FAKE/fail-shellcheck"

touch "$FAKE/fail-actionlint" "$FAKE/fail-gitleaks"
check "two failing tools: exit 1" fails lint
check "and names the first" printed "::error::repo-lint: actionlint failed"
check "and names the second" printed "::error::repo-lint: gitleaks failed"
rm "$FAKE/fail-actionlint" "$FAKE/fail-gitleaks"

touch "$FAKE/fail-compose"
check "a failing compose check: exit 1" fails lint
check "and names it" printed "::error::repo-lint: compose failed"
rm "$FAKE/fail-compose"

check "AFFRAME_DEPLOY_TESTS=false: exit 0" lint AFFRAME_DEPLOY_TESTS=false
check "and skips the deploy tests" fails marked deploy_test_x.test.sh
check "and says so" printed "deploy/test/*.test.sh skipped"
check "and still runs the other test scripts" marked scripts_ci_plain.test.sh
check "AFFRAME_DEPLOY_TESTS=true runs the deploy tests" lint AFFRAME_DEPLOY_TESTS=true
check "and they run" marked deploy_test_x.test.sh

add_test scripts/ci/skipped.test.sh 77
check "a test that exits 77 fails the lint" fails lint
check "and the ::error:: line names the test" printed "::error::repo-lint: scripts/ci/skipped.test.sh failed"

if ((failures > 0)); then
  echo "${failures} repo-lint check(s) failed"
  exit 1
fi
echo "all repo-lint checks passed"
