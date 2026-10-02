#!/usr/bin/env bash
# Tests for setup.sh in a throwaway repo with fake package managers on PATH.
# Run: bash scripts/dev/setup.test.sh
set -uo pipefail

setup="$(cd "$(dirname "$0")" && pwd)/setup.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

# Only fakes are on PATH, so a real pnpm or uv on this machine never runs. The fake git reports the
# current directory as the repo root.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<FAKE
#!$(command -v bash)
echo "\$PWD"
FAKE
chmod +x "$tmp/bin/git"
for tool in pnpm npm uv; do
  cat > "$tmp/bin/$tool" <<FAKE
#!$(command -v bash)
echo "ran in \${PWD##*/}: $tool \$*"
FAKE
  chmod +x "$tmp/bin/$tool"
done

# new_repo <app/lockfile...>: a fresh repo folder with those files, prints its path.
new_repo() {
  local repo
  repo="$(mktemp -d "$tmp/repo.XXXXXX")"
  for file in "$@"; do
    mkdir -p "$repo/apps/$(dirname "$file")"
    touch "$repo/apps/$file"
  done
  echo "$repo"
}

# expect <exit code> <stdout pattern> <name> <repo>; an empty pattern means no output at all.
expect() {
  local want_code="$1" pattern="$2" name="$3" repo="$4" out code=0 ok=yes
  out="$(cd "$repo" && PATH="$tmp/bin" "$(command -v bash)" "$setup" 2>&1)" || code=$?
  if [[ "$code" -ne "$want_code" ]]; then ok=no; fi
  if [[ -z "$pattern" && -n "$out" ]] || [[ "$out" != *"$pattern"* ]]; then ok=no; fi
  if [[ "$ok" == yes ]]; then
    echo "ok: ${name}"
  else
    echo "FAIL: ${name} (expected exit ${want_code} with '${pattern}', got ${code}: ${out})"
    failures=$((failures + 1))
  fi
}

expect 0 "" "no apps folder is a silent no-op" "$(new_repo)"
expect 0 "" "apps without lockfiles are a silent no-op" "$(new_repo placeholder/Dockerfile)"
expect 0 "ran in web: pnpm install --frozen-lockfile" "pnpm lockfile runs a frozen install in the app" \
  "$(new_repo web/pnpm-lock.yaml)"
expect 0 "ran in site: npm ci" "npm lockfile runs npm ci" "$(new_repo site/package-lock.json)"
expect 0 "ran in api: uv sync --frozen" "uv lockfile runs uv sync" "$(new_repo api/uv.lock)"
expect 0 "setup: apps/api: cargo not found, skipped (Cargo.lock)" "missing tool prints one line" \
  "$(new_repo api/Cargo.lock)"
expect 0 "ran in web: pnpm install --frozen-lockfile" "missing tool does not stop the next app" \
  "$(new_repo api/Cargo.lock web/pnpm-lock.yaml)"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all setup tests passed"
