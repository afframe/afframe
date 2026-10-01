#!/usr/bin/env bash
# Tests for deploy-services.sh on a scratch git repository. Run: bash scripts/ci/deploy-services.test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/deploy-services.sh"
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
expect() {
  local name="$1" want="$2" out
  out="$(cd "$repo" && bash "$script" "$3" "$4" | tr '\n' ' ')"
  if [[ "$out" == "$want" ]]; then echo "ok: $name"; else echo "FAIL: $name (got '$out')"; failures=$((failures + 1)); fi
}

c0="$(commit apps/web/Dockerfile deploy/services/web.env apps/api/Dockerfile deploy/services/api.env apps/tool/Dockerfile README.md)"
c1="$(commit apps/web/index.html)"
c2="$(commit README.md)"
c3="$(commit deploy/compose.prod.yml)"
c4="$(commit deploy/services/api.env apps/web/x)"

expect "first push deploys everything" 'services=["api","web"] infra=true ' "$(printf '0%.0s' {1..40})" "$c0"
expect "empty before deploys everything" 'services=["api","web"] infra=true ' "" "$c1"
expect "unknown before deploys everything" 'services=["api","web"] infra=true ' "$(printf 'f%.0s' {1..40})" "$c1"
expect "one app changed" 'services=["web"] infra=false ' "$c0" "$c1"
expect "docs only deploys nothing" 'services=[] infra=false ' "$c1" "$c2"
expect "deploy/ change is infra only" 'services=[] infra=true ' "$c2" "$c3"
expect "manifest change redeploys its service" 'services=["api","web"] infra=true ' "$c3" "$c4"
expect "app without manifest is never deployed" 'services=[] infra=false ' "$c4" "$(commit apps/tool/Dockerfile)"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all deploy-services tests passed"
