#!/usr/bin/env bash
# Tests for stack.sh with a fake `docker` on PATH. Run: bash scripts/dev/stack.test.sh
set -uo pipefail

stack="$(cd "$(dirname "$0")" && pwd)/stack.sh"
fake="$(mktemp -d)"
trap 'rm -rf "$fake"' EXIT
failures=0

cat > "$fake/docker" <<'FAKE'
#!/usr/bin/env bash
echo "WEB_PORT=${WEB_PORT:-} DB_PORT=${DB_PORT:-} docker $*"
FAKE
chmod +x "$fake/docker"

# expect <exit code> <stdout pattern> <name> <env...> -- <args...>
expect() {
  local want_code="$1" pattern="$2" name="$3" out code=0 envs=()
  shift 3
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  out="$(env -u CONDUCTOR_PORT -u CONDUCTOR_WORKSPACE_NAME PATH="$fake:$PATH" "${envs[@]}" bash "$stack" "$@" 2>&1)" || code=$?
  if [[ "$code" -ne "$want_code" || "$out" != *"$pattern"* ]]; then
    echo "FAIL: ${name} (expected exit ${want_code} with '${pattern}', got ${code}: ${out})"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}

expect 0 "WEB_PORT=55100 DB_PORT=55101 docker compose -p afframe-lisbon -f compose.dev.yml up --build" \
  "up uses the workspace ports and project" CONDUCTOR_PORT=55100 CONDUCTOR_WORKSPACE_NAME=lisbon -- up
expect 0 "-p afframe-sao-paulo-2 " "project name is lowercase and dash-safe" \
  CONDUCTOR_PORT=55100 "CONDUCTOR_WORKSPACE_NAME=Sao Paulo_2" -- up
expect 0 "docker compose -p afframe-lisbon -f compose.dev.yml down -v --rmi local" \
  "down removes volumes and local images without a port" CONDUCTOR_WORKSPACE_NAME=lisbon -- down
expect 1 "CONDUCTOR_PORT is not set" "up without a port fails" CONDUCTOR_WORKSPACE_NAME=lisbon -- up
expect 2 "usage:" "unknown command fails" -- start

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all stack tests passed"
