#!/usr/bin/env bash
set -uo pipefail

stack="$(cd "$(dirname "$0")" && pwd)/stack.sh"
fake="$(mktemp -d)"
trap 'rm -rf "$fake"' EXIT
failures=0

cat > "$fake/docker" <<'FAKE'
#!/usr/bin/env bash
echo "DB_PORT=${DB_PORT:-} docker $*"
if [[ "$*" == *" exec -T postgres "* ]]; then
  while [[ "$1" != "postgres" ]]; do shift; done
  shift
  POSTGRES_USER=afframe POSTGRES_DB=afframe "$@"
fi
FAKE
chmod +x "$fake/docker"

# expect <exit code> <output pattern> <name> <env...> -- <args...>
expect() {
  local want_code="$1" pattern="$2" name="$3" out code=0 envs=()
  shift 3
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  out="$(env -u CONDUCTOR_PORT -u CONDUCTOR_WORKSPACE_PATH PATH="$fake:$PATH" ${envs[@]+"${envs[@]}"} \
    bash "$stack" "$@" 2>&1)" || code=$?
  if [[ "$code" -ne "$want_code" || "$out" != *"$pattern"* ]]; then
    echo "FAIL: ${name} (expected exit ${want_code} with '${pattern}', got ${code}: ${out})"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}

lisbon=CONDUCTOR_WORKSPACE_PATH=/work/afframe/lisbon
expect 0 "DB_PORT=55101 docker compose -p afframe-dev-lisbon-2234685759 -f compose.dev.yml up -d --build --wait" \
  "up starts Postgres detached on the port after the workspace port" CONDUCTOR_PORT=55100 "$lisbon" -- up
expect 0 "DATABASE_URL=postgres://afframe@localhost:55101/afframe" \
  "up prints DATABASE_URL from the container environment" CONDUCTOR_PORT=55100 "$lisbon" -- up
expect 0 "-p afframe-dev-sao-paulo-2-880344891 " "project name is lowercase and dash-safe" \
  CONDUCTOR_PORT=55100 "CONDUCTOR_WORKSPACE_PATH=/work/Sao Paulo_2" -- up
expect 0 "docker compose -p afframe-dev-lisbon-2234685759 -f compose.dev.yml down -v --rmi local" \
  "down removes volumes and local images without a port" "$lisbon" -- down
expect 0 "-p afframe-dev-foo-bar-863390146 " "two paths with the same name get two projects" \
  CONDUCTOR_PORT=55100 "CONDUCTOR_WORKSPACE_PATH=/work/foo_bar" -- up
expect 1 "CONDUCTOR_PORT is not set" "up without a port fails" "$lisbon" -- up
expect 2 "usage:" "unknown command fails" -- start

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all stack tests passed"
