#!/usr/bin/env bash
# Tests for deploy-services.sh on a scratch git repository, with a fake `gh` on PATH that serves
# the deployments API. Run: bash scripts/ci/deploy-services.test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/deploy-services.sh"
repo="$(mktemp -d)"
fake="$(mktemp -d)"
trap 'rm -rf "$repo" "$fake"' EXIT
failures=0

# Fake gh: answers `gh api [--paginate] repos/o/r/<path> --jq <filter>` by applying the filter to
# $FAKE/<path>.json (query string dropped, `/` as `_`). A $FAKE/fail file makes every call fail;
# a $FAKE/flaky file makes the next call fail once. Listing deployments without the production
# environment filter fails.
mkdir -p "$fake/bin"
cat > "$fake/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ -e "$FAKE/fail" ]] && { echo "HTTP 502" >&2; exit 1; }
[[ -e "$FAKE/flaky" ]] && { rm "$FAKE/flaky"; echo "HTTP 502" >&2; exit 1; }
[[ "$2" == --paginate ]] && shift
if [[ "$2" == repos/o/r/deployments\?* && "$2" != *[?\&]environment=production\&* && "$2" != *[?\&]environment=production ]]; then
  echo "fake gh: deployments listed without environment=production" >&2
  exit 1
fi
path="${2#repos/o/r/}"
path="${path%%\?*}"
jq -r "$4" "$FAKE/${path//\//_}.json"
EOF
chmod +x "$fake/bin/gh"

# deployments <id>=<sha>=<state,state,...>...   newest first, statuses newest first
deployments() {
  local entry id sha states json="[]"
  for entry in "$@"; do
    IFS='=' read -r id sha states <<< "$entry"
    json="$(jq -c --arg id "$id" --arg sha "$sha" '. + [{id: ($id | tonumber), sha: $sha}]' <<< "$json")"
    jq -R -c 'split(",") | map({state: .})' <<< "$states" > "$fake/deployments_${id}_statuses.json"
  done
  echo "$json" > "$fake/deployments.json"
}

git -C "$repo" init -q
git -C "$repo" config user.email test@example.org
git -C "$repo" config user.name test
commit() {
  local path
  for path in "$@"; do mkdir -p "$repo/$(dirname "$path")" && echo "$RANDOM" >> "$repo/$path"; done
  git -C "$repo" add -A && git -C "$repo" commit -q -m change && git -C "$repo" rev-parse HEAD
}
# expect <name> <stdout> <sha> [all]   (exit code must be 0)
expect() {
  local name="$1" want="$2" out
  shift 2
  out="$(cd "$repo" && FAKE="$fake" PATH="$fake/bin:$PATH" GITHUB_REPOSITORY=o/r bash "$script" "$@" 2> /dev/null | tr '\n' ' ')"
  if [[ "$out" == "$want" ]]; then echo "ok: $name"; else echo "FAIL: $name (got '$out')"; failures=$((failures + 1)); fi
}

c0="$(commit apps/web/Dockerfile deploy/services/web.env apps/api/Dockerfile deploy/services/api.env apps/tool/Dockerfile README.md)"
c1="$(commit apps/web/index.html)"
c2="$(commit README.md)"
c3="$(commit deploy/compose.prod.yml)"
c4="$(commit deploy/services/api.env apps/web/x)"
c5="$(commit apps/tool/Dockerfile)"

deployments
expect "no deployment yet deploys everything" 'services=["api","web"] infra=true ' "$c1"
deployments "1=$c0=success"
expect "manual run deploys everything" 'services=["api","web"] infra=true ' "$c1" all
expect "one app changed" 'services=["web"] infra=false ' "$c1"
deployments "2=$c1=success"
expect "docs only deploys nothing" 'services=[] infra=false ' "$c2"
deployments "3=$c2=success"
expect "deploy/ change is infra only" 'services=[] infra=true ' "$c3"
deployments "4=$c3=success"
expect "manifest change redeploys its service" 'services=["api","web"] infra=true ' "$c4"
deployments "5=$c4=success"
expect "app without manifest is never deployed" 'services=[] infra=false ' "$c5"

# AF-03: changes of a deploy that failed, was cancelled, or was skipped (no deployment at all)
# reach the next deploy, which plans from the last successful deployment.
c6="$(commit apps/web/y)"          # deploy failed (host not ready)
c7="$(commit deploy/traefik/x.yml)" # deploy cancelled
commit apps/api/z > /dev/null       # deploy skipped with no-deploy: no deployment recorded
c9="$(commit README.md)"
deployments "8=$c7=error,in_progress" "7=$c6=failure,in_progress" "6=$c5=inactive,success"
expect "failed, cancelled and skipped changes are carried into the next deploy" 'services=["api","web"] infra=true ' "$c9"
deployments "9=$c7=failure" "6=$c5=inactive,success"
expect "only changes since the last success are planned" 'services=["web"] infra=true ' "$c7"
deployments "6=$c5=inactive,success" "9=$c6=success"
expect "deployments are scanned newest id first" 'services=[] infra=true ' "$c7"
deployments "9=$c7=failure" "6=$c5=inactive,success"
touch "$fake/flaky"
expect "one API error is retried" 'services=["web"] infra=true ' "$c7"
deployments "10=$(printf 'f%.0s' {1..40})=success"
expect "base unknown to git deploys everything" 'services=["api","web"] infra=true ' "$c9"

touch "$fake/fail"
if (cd "$repo" && FAKE="$fake" PATH="$fake/bin:$PATH" GITHUB_REPOSITORY=o/r bash "$script" "$c9" > /dev/null 2>&1); then
  echo "FAIL: API error fails closed"
  failures=$((failures + 1))
else
  echo "ok: API error fails closed"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all deploy-services tests passed"
