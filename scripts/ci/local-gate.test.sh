#!/usr/bin/env bash
# Tests for local-gate.sh in a throwaway repo with a fake repo-lint.sh and a fake `docker`.
# Run: bash scripts/ci/local-gate.test.sh
set -uo pipefail

gate="$(cd "$(dirname "$0")" && pwd)/local-gate.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

# The fake git reports the current directory as the repo root. The fake docker logs every call,
# lists $SERVICES for `config --services` and exits with $TEST_EXIT for `run --rm test`.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<'FAKE'
#!/usr/bin/env bash
echo "$PWD"
FAKE
cat > "$tmp/bin/docker" <<'FAKE'
#!/usr/bin/env bash
echo "docker $*" >> calls
case "$*" in
  *"config --services") printf '%s\n' $SERVICES ;;
  *"run --rm test") exit "${TEST_EXIT:-0}" ;;
esac
FAKE
chmod +x "$tmp/bin/git" "$tmp/bin/docker"

# run_gate <repo-lint exit> <compose.ci.yml: yes|no> <services> <test exit>: runs the gate in a
# fresh repo, prints its exit code and the calls it made.
run_gate() {
  local repo code=0
  repo="$(mktemp -d "$tmp/repo.XXXXXX")"
  mkdir -p "$repo/scripts/ci"
  printf 'echo "repo-lint" >> calls\nexit %s\n' "$1" > "$repo/scripts/ci/repo-lint.sh"
  if [[ "$2" == yes ]]; then touch "$repo/compose.ci.yml"; fi
  (cd "$repo" && PATH="$tmp/bin:$PATH" SERVICES="$3" TEST_EXIT="$4" bash "$gate" > /dev/null 2>&1) || code=$?
  echo "exit $code"
  cat "$repo/calls"
}

# expect <name> <pattern> <output>: the output contains the pattern (`!pattern`: does not).
expect() {
  local name="$1" pattern="$2" out="$3" ok=no
  if [[ "$pattern" == !* ]]; then
    [[ "$out" != *"${pattern#!}"* ]] && ok=yes
  else
    [[ "$out" == *"$pattern"* ]] && ok=yes
  fi
  if [[ "$ok" == yes ]]; then
    echo "ok: ${name}"
  else
    echo "FAIL: ${name} (expected '${pattern}' in: ${out})"
    failures=$((failures + 1))
  fi
}

out="$(run_gate 0 no "" 0)"
expect "no compose.ci.yml: repo-lint only" $'exit 0\nrepo-lint' "$out"
expect "no compose.ci.yml: no docker compose" "!docker" "$out"

out="$(run_gate 1 yes "postgres test" 0)"
expect "repo-lint failure fails the gate" "exit 1" "$out"
expect "repo-lint failure stops before compose" "!docker" "$out"

out="$(run_gate 0 yes "postgres migrate test" 0)"
expect "migrate runs before test in a gate-<pid> project" \
  "run --rm migrate"$'\n'"docker compose -p gate-" "$out"
expect "test runs" "-f compose.ci.yml run --rm test" "$out"
expect "cleanup removes volumes and local images" $'run --rm test\ndocker compose -p gate-' "$out"
expect "cleanup command" "-f compose.ci.yml down -v --rmi local" "$out"

out="$(run_gate 0 yes "postgres test" 0)"
expect "no migrate service: no migrate run" "!run --rm migrate" "$out"
expect "no migrate service: test runs" "run --rm test" "$out"

out="$(run_gate 0 yes "postgres test" 3)"
expect "test failure fails the gate" "exit 3" "$out"
expect "test failure still cleans up" "down -v --rmi local" "$out"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all local-gate tests passed"
