#!/usr/bin/env bash
# Fast tests for afframe-deploy with fake `docker` and `git` on PATH (no daemon needed): argument
# validation, blue/green state, migration order and timeout, failed health check, failed removal of
# the old colour, two-phase multi-service deploy, infrastructure applied only on change, rollback.
# The real end-to-end run is deploy/test/integration.sh. Run: bash deploy/test/afframe-deploy.test.sh
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" AFFRAME_HEALTH_TRIES=2 AFFRAME_MIGRATE_TIMEOUT=1 FAKE="$work/fake"
registry=ghcr.io/afframe/afframe
sha="$(printf 'b%.0s' {1..40})"
digest() { printf '%s/%s@sha256:%s' "$registry" "$1" "$(printf "$2%.0s" {1..64})"; }

# A copy of deploy/ as the host checkout, with vault-env stubbed out: it copies $FAKE/infra.env.
mkdir -p "$AFFRAME_HOME/repo" "$FAKE/bin"
cp -r "$root/deploy" "$AFFRAME_HOME/repo/"
cat > "$AFFRAME_HOME/repo/deploy/bin/vault-env" <<'FAKEVAULT'
#!/usr/bin/env bash
cp "$FAKE/infra.env" "$AFFRAME_HOME/env/infra.env"
FAKEVAULT
printf 'HOST=migrated.test\nPORT=3000\nMEMORY=64m\nMIGRATE=migrate up\n' > "$AFFRAME_HOME/repo/deploy/services/migrated.env"
deploy="$AFFRAME_HOME/repo/deploy/bin/afframe-deploy"

cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls"
# $FAKE/health: ok, fail, or a container name that is the only unhealthy one.
if [[ "$1" == exec && "$2" == afframe-traefik ]]; then
  h="$(cat "$FAKE/health")"
  [[ "$h" == ok || ("$h" != fail && "$*" != *"$h"*) ]]
  exit
fi
# $FAKE/infra: true or false, whether Traefik and Postgres run.
if [[ "$1 $2" == "container inspect" ]]; then printf '%s\n%s\n' "$(cat "$FAKE/infra")" "$(cat "$FAKE/infra")"; fi
# Named containers that exist: one name per line in $FAKE/containers. $FAKE/remove = fail makes
# stop and rm fail; $FAKE/migrate = hang makes the migration outlast its timeout and ignore TERM,
# like a PID 1 without a signal handler.
forget() { grep -vxF -- "$1" "$FAKE/containers" > "$FAKE/containers.tmp"; mv "$FAKE/containers.tmp" "$FAKE/containers"; }
if [[ "$1" == stop || "$1" == rm ]] && [[ "$(cat "$FAKE/remove")" == fail ]]; then exit 1; fi
if [[ "$1" == rm ]]; then forget "${@: -1}"; fi
args="$*"
if [[ "$1" == run && "$args" == *" --name "* ]]; then name="${args#* --name }"; echo "${name%% *}" >> "$FAKE/containers"; fi
if [[ "$1" == run && "$*" == *" migrate up" && "$(cat "$FAKE/migrate")" == hang ]]; then trap '' TERM; exec /bin/sleep 60; fi
if [[ "$1" == run && "$*" == *" --rm "* && "$*" == *" --name "* ]]; then forget "${name%% *}"; fi
# Images present locally: "<reference> <image id>" lines in $FAKE/local; `docker pull` adds one.
# Every pulled reference gets the same image ID, so removing by ID would drop them all.
if [[ "$1 $2" == "image inspect" ]]; then grep -q "^$3 " "$FAKE/local"; exit; fi
if [[ "$1" == pull ]]; then echo "${@: -1} shared-id" >> "$FAKE/local"; fi
if [[ "$1 $2" == "image ls" ]]; then cut -d' ' -f1 "$FAKE/local"; fi
if [[ "$1 $2" == "image rm" ]]; then
  awk -v x="${@: -1}" '$1 != x && $2 != x' "$FAKE/local" > "$FAKE/local.tmp"
  mv "$FAKE/local.tmp" "$FAKE/local"
fi
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
echo "sleep $*" >> "$FAKE/calls"
FAKESLEEP
chmod +x "$FAKE/bin/"*
echo "$sha" > "$FAKE/known"
: > "$FAKE/local"
: > "$FAKE/containers"
echo ok > "$FAKE/remove"
echo ok > "$FAKE/migrate"
echo true > "$FAKE/infra"
echo A=1 > "$FAKE/infra.env"

run() { : > "$FAKE/calls"; PATH="$FAKE/bin:$PATH" "$deploy" "$@" < /dev/null > /dev/null 2>&1; }
run_with_token() { : > "$FAKE/calls"; printf 'tok123' | PATH="$FAKE/bin:$PATH" "$deploy" "$@" > /dev/null 2>&1; }
state() { sed -n "s/^$2=//p" "$AFFRAME_HOME/state/$1" 2> /dev/null; }
route() { cat "$AFFRAME_HOME/traefik/dynamic/$1.yml" 2> /dev/null; }
called() { grep -q -- "$1" "$FAKE/calls"; }
exists() { grep -qxF -- "$1" "$FAKE/containers"; }
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
check "service listed twice is refused" fails run deploy "$sha" "placeholder=$v1" "placeholder=$v2"
check "nothing ran for refused arguments" test ! -s "$FAKE/calls"
check "commit not on main is refused" fails run deploy "$(printf 'c%.0s' {1..40})" "placeholder=$v1"
check "no container started for it" fails called "run -d"

check "first deploy" run deploy "$sha" "placeholder=$v1"
check "infrastructure brought up" called "compose -p afframe"
check "waits for Traefik to pick up the first route" called "sleep 2"
check "state is blue v1" test "$(state placeholder colour) $(state placeholder current)" == "blue $v1"
check "route points at blue" grep -q "url: http://afframe-placeholder-blue:8080" <<< "$(route placeholder)"
check "no migration without MIGRATE" fails called "run --rm --network afframe-db"

check "second deploy" run deploy "$sha" "placeholder=$v2"
check "state is green v2, previous v1" test "$(state placeholder colour) $(state placeholder current) $(state placeholder previous)" == "green $v2 $v1"
check "route points at green" grep -q "afframe-placeholder-green:8080" <<< "$(route placeholder)"
check "unchanged infrastructure left alone" fails called "compose -p afframe"
check "old blue stopped gracefully" called "stop -t 30 afframe-placeholder-blue"
check "then removed" before "stop -t 30 afframe-placeholder-blue" "rm -f afframe-placeholder-blue"
check "old blue gone" fails exists afframe-placeholder-blue

check "deploy with migration" run deploy "$sha" "migrated=$(digest migrated 1)"
check "migration ran in the new image" called "run --rm --name afframe-migrated-migrate --network afframe-db --env-file $AFFRAME_HOME/env/app.env $(digest migrated 1) migrate up"
check "migration before the new container" before "migrate up" "run -d --name afframe-migrated-blue"
check "migration container gone" fails exists afframe-migrated-migrate

echo hang > "$FAKE/migrate"
echo afframe-migrated-migrate >> "$FAKE/containers"
started=$SECONDS
check "migration past its timeout fails the deploy" fails run deploy "$sha" "migrated=$(digest migrated 2)"
check "a migration ignoring TERM is killed after the grace period" test $((SECONDS - started)) -lt 30
check "leftover migration container removed first" called "rm -f afframe-migrated-migrate"
check "before the migration" before "rm -f afframe-migrated-migrate" "migrate up"
check "no migration container left" fails exists afframe-migrated-migrate
check "no new container after a failed migration" fails called "run -d"
check "state unchanged after a failed migration" test "$(state migrated current)" == "$(digest migrated 1)"
echo ok > "$FAKE/migrate"
echo true > "$FAKE/infra"
echo A=1 > "$FAKE/infra.env"

echo fail > "$FAKE/remove"
check "deploy succeeds when the old colour cannot be removed" run deploy "$sha" "migrated=$(digest migrated 3)"
check "state follows the route" grep -q "afframe-migrated-$(state migrated colour):3000" <<< "$(route migrated)"
check "state is green v3" test "$(state migrated colour) $(state migrated current)" == "green $(digest migrated 3)"
echo ok > "$FAKE/remove"

echo fail > "$FAKE/health"
check "unhealthy deploy fails" fails run deploy "$sha" "placeholder=$(digest placeholder 3)"
check "state unchanged" test "$(state placeholder current)" == "$v2"
check "route unchanged" grep -q "afframe-placeholder-green:8080" <<< "$(route placeholder)"
check "unhealthy container removed" called "rm -f afframe-placeholder-blue"
echo ok > "$FAKE/health"

check "previous image kept for rollback" grep -q "^$v1 " "$FAKE/local"
check "rollback" run rollback placeholder
check "back on v1" test "$(state placeholder current) $(state placeholder previous)" == "$v1 $v2"
check "rollback uses the local image, no pull" fails called "pull"
check "rollback skips migrations and checkout" fails called "fetch"
check "rollback of a service without history fails" fails run rollback unknown

check "deploy with a token logs in to the registry" run_with_token deploy "$sha" "placeholder=$(digest placeholder 4)"
check "login to ghcr.io from stdin" called "login ghcr.io -u token --password-stdin"
check "token passed on stdin, not argv" test "$(cat "$FAKE/login-password")" == tok123
check "token never on a command line" fails grep -q tok123 "$FAKE/calls"
check "images that are neither current nor previous are removed" fails grep -q "^$(digest placeholder 2) " "$FAKE/local"
check "current and previous images stay, even sharing an image ID" grep -q "^$v1 " "$FAKE/local"
check "deploy without a token" run deploy "$sha" "placeholder=$(digest placeholder 4)"
check "no login without a token" fails called "login"

v4="$(digest placeholder 4)"
echo A=2 > "$FAKE/infra.env"
check "deploy after an infra secret change" run deploy "$sha" "placeholder=$v4"
check "infrastructure applied again" called "compose -p afframe"
echo "# changed" >> "$AFFRAME_HOME/repo/deploy/compose.prod.yml"
check "deploy after a compose file change" run deploy "$sha" "placeholder=$v4"
check "infrastructure applied for it" called "compose -p afframe"
echo cert-2 > "$AFFRAME_HOME/tls/origin.crt"
check "deploy after a certificate change" run deploy "$sha" "placeholder=$v4"
check "infrastructure applied for the certificate" called "compose -p afframe"
echo false > "$FAKE/infra"
check "deploy with infrastructure down" run deploy "$sha" "placeholder=$v4"
check "infrastructure brought up again" called "compose -p afframe"
echo true > "$FAKE/infra"
check "next deploy" run deploy "$sha" "placeholder=$v4"
check "infrastructure left alone again" fails called "compose -p afframe"

other() { if [[ "$1" == blue ]]; then echo green; else echo blue; fi; }
p_live="$(state placeholder colour)"
m_live="$(state migrated colour)"
p_new="afframe-placeholder-$(other "$p_live")"
m_new="afframe-migrated-$(other "$m_live")"
echo "$m_new" > "$FAKE/health"
check "two services, the second unhealthy: deploy fails" fails run deploy "$sha" "placeholder=$(digest placeholder 5)" "migrated=$(digest migrated 5)"
check "first service healthy" called "$p_new:8080/health"
check "first service not switched" test "$(state placeholder colour) $(state placeholder current)" == "$p_live $v4"
check "its route unchanged" grep -q "afframe-placeholder-$p_live:8080" <<< "$(route placeholder)"
check "its new colour removed" fails exists "$p_new"
check "its live colour still there" exists "afframe-placeholder-$p_live"
check "the unhealthy new colour removed" fails exists "$m_new"
check "no old colour stopped" fails called "stop -t 30"
echo ok > "$FAKE/health"
check "two services, both healthy" run deploy "$sha" "placeholder=$(digest placeholder 5)" "migrated=$(digest migrated 5)"
check "both switched" test "$(state placeholder current) $(state migrated current)" == "$(digest placeholder 5) $(digest migrated 5)"
check "both routes moved" grep -q "$m_new:3000" <<< "$(route migrated)"
check "every health check before the first switch" before "$m_new:3000/health" "stop -t 30 afframe-placeholder-$p_live"
check "old colours stopped together after both switches" called "stop -t 30 afframe-placeholder-$p_live afframe-migrated-$m_live"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all afframe-deploy tests passed"
