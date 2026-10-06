#!/usr/bin/env bash
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }

script="$(cd "$(dirname "$0")" && pwd)/service-tests.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

# The fake docker logs every call, lists $SERVICES for `config --services`, prints $CONFIG for
# `config --format json` and exits with $TEST_EXIT for `run --rm test`.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/docker" <<'FAKE'
#!/usr/bin/env bash
echo "docker $*" >> calls
case "$*" in
  *"config --services") printf '%s\n' $SERVICES ;;
  *"config --format json") printf '%s' "$CONFIG" ;;
  *"run --rm test") exit "${TEST_EXIT:-0}" ;;
esac
FAKE
chmod +x "$tmp/bin/docker"

# run_tests <services> <test exit> [SERVICE_IMAGES]: prints the exit code and the calls made.
run_tests() {
  local dir code=0 config
  dir="$(mktemp -d "$tmp/repo.XXXXXX")"
  config="$(jq -n --arg root "$dir" '{services: {
    app: {build: {context: $root, dockerfile: "apps/app/Dockerfile"}},
    test: {build: {context: $root, dockerfile: "apps/app/Dockerfile"}, image: "custom/test"},
    staged: {build: {context: $root, dockerfile: "apps/app/Dockerfile", target: "test"}},
    other: {build: {context: $root, dockerfile: "apps/other/Dockerfile"}},
    root: {build: {context: $root}},
    own: {build: {context: ($root + "/apps/app")}},
    absolute: {build: {context: ($root + "/deploy"), dockerfile: ($root + "/apps/app/Dockerfile")}},
    postgres: {image: "postgres:18"}}}')"
  (cd "$dir" && PATH="$tmp/bin:$PATH" SERVICES="$1" TEST_EXIT="$2" CONFIG="$config" SERVICE_IMAGES="${3:-}" \
    bash "$script" ci-1 > /dev/null 2>&1) || code=$?
  echo "exit $code"
  cat "$dir/calls"
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

out="$(run_tests "postgres migrate test" 0)"
expect "migrate runs before test" $'run --rm migrate\ndocker compose -p ci-1 -f compose.ci.yml run --rm test' "$out"
expect "cleanup after test" $'run --rm test\ndocker compose -p ci-1 -f compose.ci.yml down -v --rmi local' "$out"
expect "no prebuilt images: nothing tagged" "!docker tag" "$out"
expect "success prints no service logs" "!logs --no-color" "$out"

out="$(run_tests "postgres test" 4)"
expect "test failure fails" "exit 4" "$out"
expect "no migrate service: no migrate run" "!run --rm migrate" "$out"
expect "test failure still cleans up" "down -v --rmi local" "$out"
expect "test failure prints the service logs" \
  $'run --rm test\ndocker compose -p ci-1 -f compose.ci.yml logs --no-color' "$out"
expect "and cleans up after them" $'logs --no-color\ndocker compose -p ci-1 -f compose.ci.yml down' "$out"

out="$(run_tests "app test" 0 "apps/app=afframe/app:ci-1")"
expect "prebuilt image under compose's default name" "docker tag afframe/app:ci-1 ci-1-app" "$out"
expect "prebuilt image under the service's own image name" "docker tag afframe/app:ci-1 custom/test" "$out"
expect "service of another Dockerfile folder is left to compose" "!ci-1-other" "$out"
expect "root context without a Dockerfile path is left to compose" "!ci-1-root" "$out"
expect "app folder as the context with the default Dockerfile" "docker tag afframe/app:ci-1 ci-1-own" "$out"
expect "absolute Dockerfile path" "docker tag afframe/app:ci-1 ci-1-absolute" "$out"
expect "service building another target is left to compose" "!ci-1-staged" "$out"
expect "tagged before test" $'ci-1-absolute\ndocker compose -p ci-1 -f compose.ci.yml config --services' "$out"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all service-tests tests passed"
