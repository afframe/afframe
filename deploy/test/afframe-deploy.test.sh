#!/usr/bin/env bash
# Fakes `docker`, `sleep` and `id` on PATH: no daemon needed.
set -uo pipefail
for cmd in flock cmp sha256sum timeout; do command -v "$cmd" > /dev/null || { echo "skip: needs $cmd"; exit 77; }; done

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" AFFRAME_HEALTH_TRIES=2 AFFRAME_HEALTH_PASSES=1 AFFRAME_MIGRATE_TIMEOUT=1 \
  AFFRAME_MIGRATE_KILL_AFTER=1 AFFRAME_SWITCH_TIMEOUT=2 FAKE="$work/fake"
sha="$(printf 'b%.0s' {1..40})"
# img <service> <version>: the image ID the host's store gives that build.
img() { printf 'sha256:%s' "$(printf '%s-%s' "$1" "$2" | sha256sum | cut -c1-64)"; }

release="$AFFRAME_HOME/releases/$sha"
mkdir -p "$FAKE/bin"
(cd "$root" && tar -cf - deploy) | sh "$root/deploy/bin/afframe-receive" "$sha" > /dev/null
cat > "$release/deploy/bin/vault-env" <<'FAKEVAULT'
#!/usr/bin/env bash
cp "$FAKE/infra.env" "$AFFRAME_HOME/env/infra.env"
echo "vault-secret"
FAKEVAULT
printf 'HOST=migrated.test\nPORT=3000\nMEMORY=64m\nMIGRATE=migrate up\n' > "$release/deploy/services/migrated.conf"
cp "$root/deploy/test/services/fixture.conf" "$release/deploy/services/"
deploy="$release/deploy/bin/afframe-deploy"

cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls"
[[ "$1" != compose ]] || echo "traefik-hash ${AFFRAME_TRAEFIK_HASH:-}" >> "$FAKE/calls"
# Output that must stay on the host: <kind>-secret.
[[ "$1" != compose ]] || echo "compose-secret"
if [[ "$1" == logs ]]; then echo "app-log-secret"; exit 0; fi
# barrier <kind>: when $FAKE/barrier names <kind>, fails unless two such calls overlap in 3 s.
barrier() {
  [[ "$(cat "$FAKE/barrier")" == "$1" ]] || return 0
  touch "$FAKE/barrier.$1.$$"
  for _ in {1..60}; do
    (($(find "$FAKE" -name "barrier.$1.*" | wc -l) >= 2)) && return 0
    /bin/sleep 0.05
  done
  return 1
}
# Confirm probe: X-Backend of the route for that Host, "stale" unless $FAKE/switch is ok.
if [[ "$1" == exec && "$2" == afframe-traefik && "$*" == *"http://127.0.0.1:8081/health"* ]]; then
  [[ "$(cat "$FAKE/switch")" == ok ]] || { echo "  X-Backend: stale" >&2; exit 0; }
  host="$*"
  host="${host#*--header Host: }"
  host="${host%% *}"
  backend="$(grep -l "Host(\`$host\`)" "$AFFRAME_HOME"/traefik/dynamic/*.yml | head -n 1 \
    | xargs sed -n 's/^ *X-Backend: //p')"
  echo "  X-Backend: $backend" >&2
  exit 0
fi
# $FAKE/health: ok, fail, flaky (only the second probe fails), or the one unhealthy container name.
if [[ "$1" == exec && "$2" == afframe-traefik ]]; then
  h="$(cat "$FAKE/health")"
  if [[ "$h" == flaky ]]; then
    echo x >> "$FAKE/probes"
    [[ "$(wc -l < "$FAKE/probes")" -ne 2 ]]
    exit
  fi
  barrier health || exit 1
  [[ "$h" == ok || ("$h" != fail && "$*" != *"$h"*) ]]
  exit
fi
if [[ "$1" == ps ]]; then cat "$FAKE/containers"; exit 0; fi
if [[ "$1 $2" == "container inspect" ]]; then printf '%s\n%s\n' "$(cat "$FAKE/infra")" "$(cat "$FAKE/infra")"; fi
# $FAKE/remove=fail: stop and rm fail. $FAKE/migrate=hang: ignores TERM.
forget() {
  grep -vxF -- "$1" "$FAKE/containers" > "$FAKE/containers.tmp"
  mv "$FAKE/containers.tmp" "$FAKE/containers"
}
if [[ "$1" == stop || "$1" == rm ]] && [[ "$(cat "$FAKE/remove")" == fail ]]; then exit 1; fi
# $FAKE/create=fail: create fails and, like docker, names its arguments (the env file path).
if [[ "$1" == create && "$(cat "$FAKE/create")" == fail ]]; then echo "docker: $*" >&2; exit 125; fi
if [[ "$1" == rm ]]; then forget "${@: -1}"; fi
args="$*"
if [[ ("$1" == run || "$1" == create) && "$args" == *" --name "* ]]; then
  name="${args#* --name }"
  echo "${name%% *}" >> "$FAKE/containers"
fi
[[ "$1" != run || "$*" != *" migrate up" ]] || echo "migration-secret"
if [[ "$1" == run && "$*" == *" migrate up" && "$(cat "$FAKE/migrate")" == hang ]]; then
  trap '' TERM
  exec /bin/sleep 60
fi
if [[ "$1" == run && "$*" == *" --rm "* && "$*" == *" --name "* ]]; then forget "${name%% *}"; fi
# Image store: "<ref> <ID>" in local, "<ID> <tree>" in labels; load reads "<ref> <ID> [<tree>]".
drop() { awk -v x="$1" '$1 != x && $2 != x' "$FAKE/local" > "$FAKE/local.tmp"; mv "$FAKE/local.tmp" "$FAKE/local"; }
if [[ "$1" == load ]]; then
  while read -r ref id tree; do
    drop "$ref"
    echo "$ref $id" >> "$FAKE/local"
    [[ -z "$tree" ]] || echo "$id $tree" >> "$FAKE/labels"
  done
  exit 0
fi
if [[ "$1 $2" == "image inspect" ]]; then
  line="$(awk -v x="${@: -1}" '$1 == x || $2 == x' "$FAKE/local" | tail -n 1)"
  [[ -n "$line" ]] || exit 1
  id="${line#* }"
  if [[ "$*" == *afframe.tree* ]]; then awk -v x="$id" '$1 == x {t = $2} END {print t}' "$FAKE/labels"; exit 0; fi
  [[ "$3" != -f ]] || echo "$id"
  exit 0
fi
if [[ "$1 $2" == "image ls" ]]; then cat "$FAKE/local"; fi
if [[ "$1 $2" == "image rm" ]]; then drop "${@: -1}"; fi
if [[ "$1" == tag ]]; then
  awk -v x="$3" '$1 != x' "$FAKE/local" > "$FAKE/local.tmp"
  mv "$FAKE/local.tmp" "$FAKE/local"
  echo "$3 $2" >> "$FAKE/local"
fi
exit 0
FAKEDOCKER
cat > "$FAKE/bin/sleep" <<'FAKESLEEP'
#!/usr/bin/env bash
echo "sleep $*" >> "$FAKE/calls"
FAKESLEEP
chmod +x "$FAKE/bin/"*
: > "$FAKE/local"
: > "$FAKE/labels"
: > "$FAKE/containers"
echo ok > "$FAKE/remove"
echo ok > "$FAKE/create"
echo ok > "$FAKE/migrate"
echo ok > "$FAKE/switch"
echo none > "$FAKE/barrier"
echo true > "$FAKE/infra"
echo A=1 > "$FAKE/infra.env"

n=0 # the workflow run number, one up per deploy
# stream <service>=<version>[@<tree>]...: the fake `docker save` stream; tree defaults to version.
stream() {
  local s v
  for s in "$@"; do v="${s#*=}"; echo "afframe/${s%%=*}:$sha $(img "${s%%=*}" "${v%@*}") ${v#*@}"; done
}
# dep <service>=<version>[@<tree>]...  dep_env <env>... -- <same>
dep() { dep_env -- "$@"; }
dep_env() {
  local envs=()
  while [[ "$1" != -- ]]; do envs+=("$1"); shift; done
  shift
  n=$((n + 1))
  : > "$FAKE/calls"
  stream "$@" | env ${envs[@]+"${envs[@]}"} PATH="$FAKE/bin:$PATH" "$deploy" deploy "$sha" "$n" "${@%%=*}" \
    > "$FAKE/out" 2>&1
}
run() { : > "$FAKE/calls"; PATH="$FAKE/bin:$PATH" "$deploy" "$@" < /dev/null > /dev/null 2>&1; }
state() { sed -n "s/^$2=//p" "$AFFRAME_HOME/state/$1" 2> /dev/null; }
route() { cat "$AFFRAME_HOME/traefik/dynamic/$1.yml" 2> /dev/null; }
router() { route "$1" | awk -v r="    $2:" '$0 == r {f = 1; next} f && /^    [^ ]/ {f = 0} f && /^  [^ ]/ {f = 0} f'; }
called() { grep -q -- "$1" "$FAKE/calls"; }
printed() { grep -q -- "$1" "$FAKE/out"; }
kept() { grep -q -- "$1" "$AFFRAME_HOME/log/$2"; }
mode() { test "$(stat -c %a "$AFFRAME_HOME/log/$1")" == "$2"; }
exists() { grep -qxF -- "$1" "$FAKE/containers"; }
check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
# fails_naming <check name> <text> <command>...: Actions logs are public, so paths are relative.
fails_naming() {
  local name="$1" text="$2"
  shift 2
  check "$name" fails "$@"
  check "the job log names $text" printed "$text"
  check "and never the absolute host path" fails printed "$AFFRAME_HOME"
}
traefik_hash() { sed -n 's/^traefik-hash //p' "$FAKE/calls" | head -n 1; }
line_of() { grep -n -- "$1" "$FAKE/calls" | head -n 1 | cut -d: -f1; }
before() { [[ "$(line_of "$1")" -lt "$(line_of "$2")" ]]; }
other() { if [[ "$1" == blue ]]; then echo green; else echo blue; fi; }

v1="$(img fixture 1)"
v2="$(img fixture 2)"
echo ok > "$FAKE/health"

receive_again() { echo junk | sh "$root/deploy/bin/afframe-receive" "$sha" > /dev/null; }
check "release unpacked" test -x "$release/deploy/bin/afframe-deploy"
check "receive of a known release" receive_again
check "keeps it as it is" test -f "$release/deploy/services/migrated.conf"
check "receive refuses a bad sha" fails sh "$root/deploy/bin/afframe-receive" "../x" < /dev/null 2> /dev/null
# receive_to <AFFRAME_HOME> <sha>: output in $FAKE/out.
receive_to() {
  (cd "$root" && tar -cf - deploy) | AFFRAME_HOME="$1" sh "$root/deploy/bin/afframe-receive" "$2" > "$FAKE/out" 2>&1
}
touch "$work/file"
check "receive into an AFFRAME_HOME that is a file fails" fails receive_to "$work/file" "$sha"
check "and never prints the absolute host path" fails printed "$work"
sha3="$(printf 'd%.0s' {1..40})"
touch "$AFFRAME_HOME/releases/$sha3" # a file where the release folder goes
fails_naming "receive that cannot move the release in place fails" "releases/$sha3" receive_to "$AFFRAME_HOME" "$sha3"
rm -rf "$AFFRAME_HOME/releases/$sha3" "$AFFRAME_HOME/releases/$sha3.tmp"

check "postgres data volume name is literal" grep -qx '    name: afframe-postgres-data' "$root/deploy/compose.prod.yml"
check "pgbackrest volume name is literal" grep -qx '    name: afframe-pgbackrest' "$root/deploy/compose.prod.yml"
check "confirm entrypoint address matches the probe" \
  grep -qx '    address: "127.0.0.1:8081"' "$root/deploy/traefik/traefik.yml"
check "build-images.sh sets the afframe.tree label" grep -q 'afframe\.tree=' "$root/scripts/ci/build-images.sh"
check "compose project name is afframe" grep -qx 'name: afframe' "$root/deploy/compose.prod.yml"
check "build-images.sh reads the namespace from the compose name:" \
  grep -qF "'s/^name: *//p' deploy/compose.prod.yml" "$root/scripts/ci/build-images.sh"
check "common.sh has the AFFRAME_HOME default" grep -qF "AFFRAME_HOME:-\$HOME/afframe}" "$root/deploy/bin/common.sh"
check "afframe-receive has the AFFRAME_HOME default" \
  grep -qF "AFFRAME_HOME:-\$HOME/afframe}" "$root/deploy/bin/afframe-receive"
check "the systemd unit runs from the AFFRAME_HOME default" \
  grep -qF "\"\$\$HOME/afframe/current/deploy/bin/afframe-%i\"" "$root/deploy/host/systemd/afframe@.service"

mkdir -p "$FAKE/root"
printf '#!/bin/sh\necho 0\n' > "$FAKE/root/id"
chmod +x "$FAKE/root/id"
as_root() {
  : > "$FAKE/calls"
  local output
  ! output="$(PATH="$FAKE/root:$FAKE/bin:$PATH" "$release/deploy/bin/$1" 2>&1 < /dev/null)" \
    && grep -q "refusing to run as root" <<< "$output"
}
for job in afframe-backup afframe-health afframe-restore-drill; do
  check "$job refuses to run as root" as_root "$job"
  check "$job ran no docker command as root" test ! -s "$FAKE/calls"
done

check "short sha is refused" fails run deploy abc 1 fixture
check "missing run number is refused" fails run deploy "$sha" fixture
check "service without a manifest is refused" fails run deploy "$sha" 1 no-such-service
check "service named like a static Traefik file is refused" fails run deploy "$sha" 1 tls
check "service listed twice is refused" fails run deploy "$sha" 1 fixture fixture
check "nothing ran for refused arguments" test ! -s "$FAKE/calls"
check "service missing from the image stream is refused" fails run deploy "$sha" 1 fixture
check "no container started for the missing service" fails called "create --name"

check "first deploy" dep fixture=1
check "images loaded from stdin" called "docker load"
check "infrastructure brought up" called "compose -p afframe"
check "compose output kept out of the job log" fails printed compose-secret
check "kept on the host" kept compose-secret compose-up.log
check "host log readable by the deploy user only" mode compose-up.log 600
check "host log folder too" mode . 700
check "vault-env output kept out of the job log" fails printed vault-secret
check "kept on the host" kept vault-secret vault-env.log
check "Traefik static config copied to AFFRAME_HOME" \
  cmp -s "$AFFRAME_HOME/traefik/traefik.yml" "$root/deploy/traefik/traefik.yml"
check "confirm router names its backend in a response header" \
  grep -q "X-Backend: afframe-fixture-blue" <<< "$(route fixture)"
check "confirm router on the internal entrypoint, with that header" \
  test "$(router fixture fixture-confirm \
    | grep -c 'entryPoints: \[confirm\]\|middlewares: \[fixture-backend\]')" -eq 2
check "confirm router shares the public service" \
  grep -q "service: fixture$" <<< "$(router fixture fixture-confirm)"
check "public router strips stack headers" \
  grep -q "middlewares: \[public-headers\]" <<< "$(router fixture fixture)"
check "public router adds no backend header" fails grep -q "backend" <<< "$(router fixture fixture)"
check "public router on websecure only" grep -q "entryPoints: \[websecure\]" <<< "$(router fixture fixture)"
check "switch confirmed through the internal entrypoint" called "http://127.0.0.1:8081/health"
check "public-headers middleware installed" \
  cmp -s "$AFFRAME_HOME/traefik/dynamic/public-headers.yml" "$root/deploy/traefik/dynamic/public-headers.yml"
check "new container on the db network before it starts" \
  before "network connect afframe-db afframe-fixture-blue" "start afframe-fixture-blue"
check "new container created before it joins the db network" \
  before "create --name afframe-fixture-blue" "network connect afframe-db afframe-fixture-blue"
check "container created from the host's image ID" called "create --name afframe-fixture-blue .* $v1$"
check "unused images and old build cache pruned" called "image prune -f"
check "build cache older than a week only" called "builder prune -f --filter until=168h"
check "state is blue v1" test "$(state fixture colour) $(state fixture current)" == "blue $v1"
check "route points at blue" grep -q "url: http://afframe-fixture-blue:8080" <<< "$(route fixture)"
check "no migration without MIGRATE" fails called "run --rm --network afframe-db"
check "current points at the release" test "$(readlink "$AFFRAME_HOME/current")" == "$release"
check "deployed run recorded" test "$(sed -n 's/^run=//p' "$AFFRAME_HOME/state/.deployed")" == "$n"

rm "$AFFRAME_HOME/deploy.lock"
mkdir "$AFFRAME_HOME/deploy.lock"
fails_naming "a lock that cannot be opened fails the deploy" "deploy.lock" dep
rmdir "$AFFRAME_HOME/deploy.lock"
mv "$AFFRAME_HOME/tls" "$work/tls"
touch "$AFFRAME_HOME/tls"
fails_naming "a host folder that cannot be created fails the deploy" "cannot create" dep
rm "$AFFRAME_HOME/tls"
mv "$work/tls" "$AFFRAME_HOME/tls"
rm "$AFFRAME_HOME/log/vault-env.log"
mkdir "$AFFRAME_HOME/log/vault-env.log"
fails_naming "a host log that cannot be written fails the deploy" "log/vault-env.log" dep
rmdir "$AFFRAME_HOME/log/vault-env.log"
if [[ $EUID -ne 0 ]]; then # root reads a file without read permission
  chmod 000 "$AFFRAME_HOME/state/.infra"
  fails_naming "an unreadable state file fails the deploy" "cannot read state/.infra" dep
  chmod 644 "$AFFRAME_HOME/state/.infra"
  chmod 000 "$AFFRAME_HOME/state/.deployed"
  fails_naming "an unreadable deployed run fails the deploy" "cannot read state/.deployed" dep
  chmod 644 "$AFFRAME_HOME/state/.deployed"
fi

check "same image again" dep fixture=1
check "unchanged image left alone" fails called "create --name"
check "state unchanged, previous kept" test "$(state fixture current) $(state fixture previous)" == "$v1 "
check "a rebuild of the same tree (another image ID)" dep fixture=1b@1
check "same-tree rebuild left alone" fails called "create --name"

check "second deploy" dep fixture=2
check "state is green v2, previous v1" \
  test "$(state fixture colour) $(state fixture current) $(state fixture previous)" == "green $v2 $v1"
check "route points at green" grep -q "afframe-fixture-green:8080" <<< "$(route fixture)"
check "unchanged infrastructure left alone" fails called "compose -p afframe"
check "old blue stopped gracefully" called "stop -t 30 afframe-fixture-blue"
check "old blue removed after the stop" before "stop -t 30 afframe-fixture-blue" "rm -f afframe-fixture-blue"
check "old blue gone" fails exists afframe-fixture-blue

check "an older run is refused" fails run deploy "$sha" "$((n - 1))"
check "nothing loaded for the older run" fails called "docker load"
check "the same run again deploys (re-run)" run deploy "$sha" "$n"

check "deploy with migration" dep migrated=1
check "migration ran in the new image" \
  called "run --rm --name afframe-migrated-migrate --network afframe-db --env-file $AFFRAME_HOME/env/app.env \
$(img migrated 1) migrate up"
check "migration before the new container" before "migrate up" "create --name afframe-migrated-blue"
check "migration container gone" fails exists afframe-migrated-migrate
check "migration output kept out of the job log" fails printed migration-secret
check "kept on the host" kept migration-secret afframe-migrated-migrate.log

rm -f "$AFFRAME_HOME/log/afframe-migrated-migrate.log" # the successful migration's log
echo hang > "$FAKE/migrate"
echo afframe-migrated-migrate >> "$FAKE/containers"
started=$SECONDS
check "migration past its timeout fails the deploy" fails dep migrated=2
check "a migration ignoring TERM is killed after the grace period" test $((SECONDS - started)) -lt 30
check "leftover migration container removed first" called "rm -f afframe-migrated-migrate"
check "before the migration" before "rm -f afframe-migrated-migrate" "migrate up"
check "no migration container left" fails exists afframe-migrated-migrate
check "no new container after a failed migration" fails called "create --name"
check "state unchanged after a failed migration" test "$(state migrated current)" == "$(img migrated 1)"
check "failed migration output kept out of the job log" fails printed migration-secret
check "kept on the host" kept migration-secret afframe-migrated-migrate.log
check "the job log names the host log" printed "log/afframe-migrated-migrate.log"
echo ok > "$FAKE/migrate"
rm "$AFFRAME_HOME/log/afframe-migrated-migrate.log"
mkdir "$AFFRAME_HOME/log/afframe-migrated-migrate.log"
check "a migration log that cannot be written fails the deploy" fails dep migrated=2
check "the job log names the host log" printed "cannot write log/afframe-migrated-migrate.log"
check "and does not claim the migration failed" fails printed "migration failed"
rmdir "$AFFRAME_HOME/log/afframe-migrated-migrate.log"

echo fail > "$FAKE/remove"
check "deploy succeeds when the old colour cannot be removed" dep migrated=3
check "state follows the route" grep -q "afframe-migrated-$(state migrated colour):3000" <<< "$(route migrated)"
check "state is green v3" test "$(state migrated colour) $(state migrated current)" == "green $(img migrated 3)"
echo ok > "$FAKE/remove"

echo fail > "$FAKE/health"
check "unhealthy deploy fails" fails dep fixture=3
check "state unchanged" test "$(state fixture current)" == "$v2"
check "route unchanged" grep -q "afframe-fixture-green:8080" <<< "$(route fixture)"
check "unhealthy container removed" called "rm -f afframe-fixture-blue"
check "container logs kept out of the job log" fails printed app-log-secret
check "kept on the host" kept app-log-secret afframe-fixture-blue.log
check "host log readable by the deploy user only" mode afframe-fixture-blue.log 600
check "the job log names the host log" printed "log/afframe-fixture-blue.log"
check "and never the absolute host path" fails printed "$AFFRAME_HOME"
check "nothing pruned after a failure" fails called "image prune"
echo ok > "$FAKE/health"

live="$(state fixture colour)"
idle="$(other "$live")"
echo stale > "$FAKE/switch"
check "switch Traefik does not confirm fails" fails dep fixture=3
check "routed back to the live colour" grep -q "afframe-fixture-$live:8080" <<< "$(route fixture)"
check "state back on the live image" test "$(state fixture colour) $(state fixture current)" == "$live $v2"
check "old colour not stopped" fails called "stop -t 30"
check "live colour kept" exists "afframe-fixture-$live"
check "new colour left running too (Traefik may serve it)" exists "afframe-fixture-$idle"
echo ok > "$FAKE/switch"

check "previous image kept for rollback" grep -q " $v1$" "$FAKE/local"
printf '%s\n' "afframe/fixture:old sha256:stale" "afframe-postgres:local sha256:pg" >> "$FAKE/local"
check "deploy that prunes" dep migrated=4
check "images that are neither current nor previous are removed" fails grep -q " sha256:stale$" "$FAKE/local"
check "other images left alone" grep -q "^afframe-postgres:local " "$FAKE/local"
check "rollback" run rollback fixture
check "back on v1" test "$(state fixture current) $(state fixture previous)" == "$v1 $v2"
check "the image rolled away from is held" test "$(state fixture held)" == "$v2"
check "rollback skips migrations and loads nothing" fails called "load\|migrate"
check "rollback of a service without history fails" fails run rollback unknown

check "deploy offering the held image" dep fixture=2
check "held image skipped" fails called "create --name"
check "deploy offering a rebuild of the held tree" dep fixture=2b@2
check "rebuild of the held tree skipped" fails called "create --name"
check "still on the rollback image" test "$(state fixture current) $(state fixture held)" == "$v1 $v2"
check "held image never pruned while previous" grep -q " $v2$" "$FAKE/local"
check "a different image ends the hold" dep fixture=4
check "on the new image, hold cleared" \
  test "$(state fixture current) $(state fixture held)" == "$(img fixture 4) "
printf 'current=a\ncolour=blue\nprevious=sha256:gone\n' > "$AFFRAME_HOME/state/ghost"
check "rollback with its previous image gone fails" fails run rollback ghost
rm -f "$AFFRAME_HOME/state/ghost"
printf 'HOST=held.test\nPORT=8080\nMEMORY=64m\nMIGRATE=\n' > "$release/deploy/services/held.conf"
check "deploy of a service named held" dep held=1
check "it switches" test "$(state held current)" == "$(img held 1)"
check "its route points at it" grep -q "afframe-held-$(state held colour):8080" <<< "$(route held)"
rm "$release/deploy/services/held.conf"
check "deploy that retires it" dep
check "its state removed" test ! -e "$AFFRAME_HOME/state/held"

echo A=2 > "$FAKE/infra.env"
check "deploy after an infra secret change" dep
check "infrastructure applied again" called "compose -p afframe"
hash1="$(traefik_hash)"
check "Traefik config hash exported to compose" test -n "$hash1"
echo "# changed" >> "$release/deploy/compose.prod.yml"
check "deploy after a compose file change" dep
check "infrastructure applied for it" called "compose -p afframe"
check "Traefik hash unchanged by a compose-only change" test "$(traefik_hash)" == "$hash1"
echo cert-2 > "$AFFRAME_HOME/tls/origin.crt"
check "deploy after a certificate change" dep
check "infrastructure applied for the certificate" called "compose -p afframe"
check "a new certificate recreates Traefik" test "$(traefik_hash)" != "$hash1"
hash2="$(traefik_hash)"
echo "# changed" >> "$release/deploy/traefik/traefik.yml"
check "deploy after a Traefik static config change" dep
check "it recreates Traefik" test "$(traefik_hash)" != "$hash2"
check "with the new static config in AFFRAME_HOME" \
  cmp -s "$AFFRAME_HOME/traefik/traefik.yml" "$release/deploy/traefik/traefik.yml"
echo false > "$FAKE/infra"
check "deploy with infrastructure down" dep
check "infrastructure brought up again" called "compose -p afframe"
echo true > "$FAKE/infra"
check "next deploy" dep
check "infrastructure left alone again" fails called "compose -p afframe"
tls="$AFFRAME_HOME/traefik/dynamic/tls.yml"
inode="$(stat -c %i "$tls")"
check "deploy with tls.yml unchanged" dep
check "tls.yml not rewritten" test "$(stat -c %i "$tls")" == "$inode"
echo "# changed" >> "$release/deploy/traefik/dynamic/tls.yml"
check "deploy with tls.yml changed" dep
check "tls.yml replaced" cmp -s "$tls" "$release/deploy/traefik/dynamic/tls.yml"

live="$(state fixture colour)"
rm "$AFFRAME_HOME/state/fixture"
check "deploy with the state file lost" dep fixture=5
check "live colour taken from the route, not recreated" fails called "create --name afframe-fixture-$live"
check "new colour is the idle one" test "$(state fixture colour)" == "$(other "$live")"
check "old colour retired gracefully" called "stop -t 30 afframe-fixture-$live"
live="$(state fixture colour)"
rm "$AFFRAME_HOME/state/fixture" "$AFFRAME_HOME/traefik/dynamic/fixture.yml"
check "deploy with state and route lost" dep fixture=6
check "live colour taken from the running containers" fails called "create --name afframe-fixture-$live"
check "switched to the other colour" grep -q "afframe-fixture-$(other "$live"):8080" <<< "$(route fixture)"
live="$(state fixture colour)"
echo afframe-fixture-blue >> "$FAKE/containers"
echo afframe-fixture-green >> "$FAKE/containers"
rm "$AFFRAME_HOME/state/fixture" "$AFFRAME_HOME/traefik/dynamic/fixture.yml"
check "both colours running and nothing says which is live: refused" fails dep fixture=7
check "neither colour removed" test "$(grep -c '^afframe-fixture-' "$FAKE/containers")" -ge 2
check "nothing switched" test ! -f "$AFFRAME_HOME/traefik/dynamic/fixture.yml"
printf 'current=%s\ncolour=%s\nprevious=\n' "$(img fixture 6)" "$live" > "$AFFRAME_HOME/state/fixture"
check "deploy once the state is back" dep fixture=7

echo flaky > "$FAKE/health"
: > "$FAKE/probes"
check "health needs consecutive passes" dep_env AFFRAME_HEALTH_PASSES=3 AFFRAME_HEALTH_TRIES=10 -- fixture=8
check "a failed probe restarts the count (pass, fail, 3 passes)" test "$(wc -l < "$FAKE/probes")" -eq 5
echo ok > "$FAKE/health"
p_live="$(state fixture colour)"
m_live="$(state migrated colour)"
p_new="afframe-fixture-$(other "$p_live")"
m_new="afframe-migrated-$(other "$m_live")"
echo "$m_new" > "$FAKE/health"
check "two services, the second unhealthy: deploy fails" fails dep fixture=9 migrated=9
check "first service healthy" called "$p_new:8080/health"
check "first service not switched" \
  test "$(state fixture colour) $(state fixture current)" == "$p_live $(img fixture 8)"
check "its route unchanged" grep -q "afframe-fixture-$p_live:8080" <<< "$(route fixture)"
check "its new colour removed" fails exists "$p_new"
check "its live colour still there" exists "afframe-fixture-$p_live"
check "the unhealthy new colour removed" fails exists "$m_new"
check "no old colour stopped" fails called "stop -t 30"
echo ok > "$FAKE/health"
check "two services, both healthy" dep fixture=9 migrated=9
check "both switched" \
  test "$(state fixture current) $(state migrated current)" == "$(img fixture 9) $(img migrated 9)"
check "both routes moved" grep -q "$m_new:3000" <<< "$(route migrated)"
check "every health check before the first switch" before "$m_new:3000/health" "stop -t 30 afframe-fixture-$p_live"
check "old colours stopped together after both switches" \
  called "stop -t 30 afframe-fixture-$p_live afframe-migrated-$m_live"
check "one service unchanged, the other deployed" dep fixture=9 migrated=10
check "only the changed one restarted" test "$(grep -c 'create --name' "$FAKE/calls")" -eq 1
echo health > "$FAKE/barrier"
check "two services waited for in parallel" dep fixture=11 migrated=11
echo none > "$FAKE/barrier"

p_new="afframe-fixture-$(other "$(state fixture colour)")"
mkdir "$AFFRAME_HOME/traefik/dynamic/migrated.yml.tmp" # the second route write fails
check "a failure after the first switch fails the deploy" fails dep fixture=12 migrated=12
check "the switched service keeps its new colour" exists "$p_new"
check "and its route" grep -q "$p_new:8080" <<< "$(route fixture)"
check "the job log names the route file" printed "traefik/dynamic/migrated.yml"
check "and never the absolute host path" fails printed "$AFFRAME_HOME"
rmdir "$AFFRAME_HOME/traefik/dynamic/migrated.yml.tmp"

echo fail > "$FAKE/create"
fails_naming "a container that cannot be created fails the deploy" "log/afframe-fixture-[a-z]*-create.log" \
  dep fixture=12b
echo ok > "$FAKE/create"

# legacy has a route for the same Host as fixture: it would shadow the new route.
printf 'current=x\ncolour=blue\n' > "$AFFRAME_HOME/state/legacy"
route fixture | sed 's/afframe-fixture-[a-z]*/afframe-legacy-blue/' > "$AFFRAME_HOME/traefik/dynamic/legacy.yml"
printf '%s\n' afframe-legacy-blue afframe-legacy-green >> "$FAKE/containers"
echo fail > "$FAKE/health"
check "a failed deploy retires nothing" fails dep fixture=13
check "the removed service is still there" \
  test -f "$AFFRAME_HOME/state/legacy" -a -f "$AFFRAME_HOME/traefik/dynamic/legacy.yml"
echo ok > "$FAKE/health"
mv "$AFFRAME_HOME/traefik/dynamic/legacy.yml" "$work/legacy.yml"
mkdir "$AFFRAME_HOME/traefik/dynamic/legacy.yml"
fails_naming "a route that cannot be removed fails the deploy" "cannot remove traefik/dynamic/legacy.yml" dep fixture=13
rmdir "$AFFRAME_HOME/traefik/dynamic/legacy.yml"
mv "$work/legacy.yml" "$AFFRAME_HOME/traefik/dynamic/legacy.yml"
check "deploy with a service removed from deploy/services" dep fixture=13
check "its route removed" test ! -e "$AFFRAME_HOME/traefik/dynamic/legacy.yml"
check "its state removed" test ! -e "$AFFRAME_HOME/state/legacy"
check "both its colours removed" fails grep -q '^afframe-legacy-' "$FAKE/containers"
check "after the health checks" before ":8080/health" "rm -f afframe-legacy-blue"
check "before the switch" before "rm -f afframe-legacy-green" "127.0.0.1:8081/health"

check "an unlabelled image deploys" dep fixture=14@
check "unlabelled image is started" called "create --name"
check "the same unlabelled image again" dep fixture=14@
check "same unlabelled image is started again" called "create --name"

old_release="$AFFRAME_HOME/releases/$(printf 'a%.0s' {1..40})"
mkdir -p "$old_release"
sha2="$(printf 'c%.0s' {1..40})"
cp -R "$release" "$AFFRAME_HOME/releases/$sha2"
ln -s "$AFFRAME_HOME" "$work/home-link"
check "deploy of a newer release (AFFRAME_HOME through a symlink)" \
  env AFFRAME_HOME="$work/home-link" PATH="$FAKE/bin:$PATH" \
  "$work/home-link/releases/$sha2/deploy/bin/afframe-deploy" deploy "$sha2" "$((n + 1))" < /dev/null > /dev/null 2>&1
check "current points at the newer release" test "$(readlink "$AFFRAME_HOME/current")" == "$AFFRAME_HOME/releases/$sha2"
check "which pruning keeps" test -d "$AFFRAME_HOME/releases/$sha2"
check "the release before it kept" test -d "$release"
check "older releases removed" test ! -e "$old_release"
check "the same release again" env PATH="$FAKE/bin:$PATH" "$AFFRAME_HOME/releases/$sha2/deploy/bin/afframe-deploy" \
  deploy "$sha2" "$((n + 1))" < /dev/null > /dev/null 2>&1
check "still keeps the release before it" test -d "$release"

check "deploy with no services (infrastructure only)" dep
check "no app container for it" fails called "create --name"
check "nothing to confirm for it" fails called "127.0.0.1:8081"
rm -f "$AFFRAME_HOME"/state/[!.]*
check "infrastructure only with no service deployed yet" dep

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all afframe-deploy tests passed"
