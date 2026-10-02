#!/usr/bin/env bash
# Fast tests for afframe-deploy with fake `docker` and `git` on PATH (no daemon needed): argument
# validation, blue/green state, migration order, failed health check, rollback.
# The real end-to-end run is deploy/test/integration.sh. Run: bash deploy/test/afframe-deploy.test.sh
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" AFFRAME_HEALTH_TRIES=2 FAKE="$work/fake"
registry=ghcr.io/afframe/afframe
sha="$(printf 'b%.0s' {1..40})"
digest() { printf '%s/%s@sha256:%s' "$registry" "$1" "$(printf "$2%.0s" {1..64})"; }

# A copy of deploy/ as the host checkout, with vault-env stubbed out.
mkdir -p "$AFFRAME_HOME/repo" "$FAKE/bin"
cp -r "$root/deploy" "$AFFRAME_HOME/repo/"
printf '#!/usr/bin/env bash\n' > "$AFFRAME_HOME/repo/deploy/bin/vault-env"
printf 'HOST=migrated.test\nPORT=3000\nMEMORY=64m\nMIGRATE=migrate up\n' > "$AFFRAME_HOME/repo/deploy/services/migrated.env"
deploy="$AFFRAME_HOME/repo/deploy/bin/afframe-deploy"

cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls"
if [[ "$1" == exec && "$2" == afframe-traefik ]]; then [[ "$(cat "$FAKE/health")" == ok ]]; exit; fi
# Images present locally: listed in $FAKE/local; `docker pull` adds to it.
if [[ "$1 $2" == "image inspect" ]]; then grep -qxF "$3" "$FAKE/local"; exit; fi
if [[ "$1" == pull ]]; then echo "${@: -1}" >> "$FAKE/local"; fi
if [[ "$1 $2" == "image ls" ]]; then sed 's/.*/& id-&/' "$FAKE/local"; fi
if [[ "$1 $2 $3" == "image rm -f" ]]; then grep -vxF "${4#id-}" "$FAKE/local" > "$FAKE/local.tmp"; mv "$FAKE/local.tmp" "$FAKE/local"; fi
if [[ "$1" == login ]]; then cat > "$FAKE/login-password"; fi
exit 0
FAKEDOCKER
cat > "$FAKE/bin/git" <<'FAKEGIT'
#!/usr/bin/env bash
[[ "$*" == *merge-base* ]] && { [[ "$*" == *"$(cat "$FAKE/known")"* ]]; exit; }
exit 0
FAKEGIT
cat > "$FAKE/bin/sleep" <<'FAKESLEEP'
#!/usr/bin/env bash
FAKESLEEP
chmod +x "$FAKE/bin/"*
echo "$sha" > "$FAKE/known"
: > "$FAKE/local"

run() { : > "$FAKE/calls"; PATH="$FAKE/bin:$PATH" "$deploy" "$@" < /dev/null > /dev/null 2>&1; }
run_with_token() { : > "$FAKE/calls"; printf 'tok123' | PATH="$FAKE/bin:$PATH" "$deploy" "$@" > /dev/null 2>&1; }
state() { sed -n "s/^$2=//p" "$AFFRAME_HOME/state/$1" 2> /dev/null; }
route() { cat "$AFFRAME_HOME/traefik/dynamic/$1.yml" 2> /dev/null; }
called() { grep -q -- "$1" "$FAKE/calls"; }
check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
before() { [[ "$(grep -n -- "$1" "$FAKE/calls" | head -n 1 | cut -d: -f1)" -lt "$(grep -n -- "$2" "$FAKE/calls" | head -n 1 | cut -d: -f1)" ]]; }

v1="$(digest placeholder 1)"
v2="$(digest placeholder 2)"
echo ok > "$FAKE/health"

check "short sha is refused" fails run deploy abc "placeholder=$v1"
check "foreign registry is refused" fails run deploy "$sha" "placeholder=docker.io/library/nginx@sha256:$(printf '1%.0s' {1..64})"
check "image of another service is refused" fails run deploy "$sha" "placeholder=$(digest api 1)"
check "nothing ran for refused arguments" test ! -s "$FAKE/calls"
check "commit not on main is refused" fails run deploy "$(printf 'c%.0s' {1..40})" "placeholder=$v1"
check "no container started for it" fails called "run -d"

check "first deploy" run deploy "$sha" "placeholder=$v1"
check "infrastructure brought up" called "compose -p afframe"
check "state is blue v1" test "$(state placeholder colour) $(state placeholder current)" == "blue $v1"
check "route points at blue" grep -q "url: http://afframe-placeholder-blue:8080" <<< "$(route placeholder)"
check "no migration without MIGRATE" fails called "run --rm --network afframe-db"

check "second deploy" run deploy "$sha" "placeholder=$v2"
check "state is green v2, previous v1" test "$(state placeholder colour) $(state placeholder current) $(state placeholder previous)" == "green $v2 $v1"
check "route points at green" grep -q "afframe-placeholder-green:8080" <<< "$(route placeholder)"
check "old blue removed" called "rm -f afframe-placeholder-blue"

check "deploy with migration" run deploy "$sha" "migrated=$(digest migrated 1)"
check "migration ran in the new image" called "run --rm --network afframe-db --env-file $AFFRAME_HOME/env/app.env $(digest migrated 1) migrate up"
check "migration before the new container" before "migrate up" "run -d --name afframe-migrated-blue"

echo fail > "$FAKE/health"
check "unhealthy deploy fails" fails run deploy "$sha" "placeholder=$(digest placeholder 3)"
check "state unchanged" test "$(state placeholder current)" == "$v2"
check "route unchanged" grep -q "afframe-placeholder-green:8080" <<< "$(route placeholder)"
check "unhealthy container removed" called "rm -f afframe-placeholder-blue"
echo ok > "$FAKE/health"

check "previous image kept for rollback" grep -qxF "$v1" "$FAKE/local"
check "rollback" run rollback placeholder
check "back on v1" test "$(state placeholder current) $(state placeholder previous)" == "$v1 $v2"
check "rollback uses the local image, no pull" fails called "pull"
check "rollback skips migrations and checkout" fails called "fetch"
check "rollback of a service without history fails" fails run rollback unknown

check "deploy with a token logs in to the registry" run_with_token deploy "$sha" "placeholder=$(digest placeholder 4)"
check "login to ghcr.io from stdin" called "login ghcr.io -u token --password-stdin"
check "token passed on stdin, not argv" test "$(cat "$FAKE/login-password")" == tok123
check "token never on a command line" fails grep -q tok123 "$FAKE/calls"
check "images that are neither current nor previous are removed" fails grep -qxF "$(digest placeholder 2)" "$FAKE/local"
check "current and previous images stay" grep -qxF "$v1" "$FAKE/local"
check "deploy without a token" run deploy "$sha" "placeholder=$(digest placeholder 4)"
check "no login without a token" fails called "login"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all afframe-deploy tests passed"
