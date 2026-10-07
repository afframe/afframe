#!/usr/bin/env bash
# Never run on the deploy host: it uses the same names.
set -euo pipefail

unset AFFRAME_HOME # the deploy-host check below uses the default; the run exports its own later
# shellcheck source=deploy/bin/common.sh
source "$(dirname "$0")/../bin/common.sh"
if [[ -e "$AFFRAME_HOME/current" || -L "$AFFRAME_HOME/current" ]]; then
  echo "integration.sh: AFFRAME_HOME/current exists: this is a deploy host; refusing to run" >&2
  exit 1
fi
# A remote daemon can be the deploy host's: its data volume exists before any run starts.
if docker volume inspect afframe-postgres-data > /dev/null 2>&1; then
  echo "integration.sh: the daemon has the Postgres data volume: it may be a deploy host; refusing to run" >&2
  exit 1
fi

root="$REPO"
# test_image <name>: tag of deploy/test/images/<name>, built tagged as the deploy prunes untagged.
test_image() {
  docker build -q -t "afframe-test/$1:local" "$root/deploy/test/images/$1" > /dev/null
  echo "afframe-test/$1:local"
}
alpine="$(test_image alpine)"

if [[ "$(uname -s)" != Linux && -z "${AFFRAME_INTEGRATION_WORK:-}" ]]; then
  # Reruns itself in Linux with the work directory at the same path on the daemon, for bind mounts.
  outer="/tmp/afframe-integration-$$"
  image="$(test_image runner)"
  code=0
  COPYFILE_DISABLE=1 tar --no-xattrs -C "$root" -cf - deploy \
    | docker run --rm -i --network host -v /var/run/docker.sock:/var/run/docker.sock -v "$outer:$outer" \
      -e AFFRAME_INTEGRATION_WORK="$outer" "$image" bash -c \
      'mkdir -p "$AFFRAME_INTEGRATION_WORK/src" && tar -xf - -C "$AFFRAME_INTEGRATION_WORK/src" 2> /dev/null &&
        exec bash "$AFFRAME_INTEGRATION_WORK/src/deploy/test/integration.sh"' || code=$?
  # The rerun's cleanup removed the alpine tag: build it again (cached).
  docker run --rm -v /tmp:/t "$(test_image alpine)" rm -rf "/t/${outer#/tmp/}"
  docker image rm "$alpine" "$image" > /dev/null || true
  exit "$code"
fi

if [[ -n "${AFFRAME_INTEGRATION_WORK:-}" ]]; then
  work="$AFFRAME_INTEGRATION_WORK/run"
  mkdir -p "$work"
else
  work="$(mktemp -d)"
fi
export AFFRAME_HOME="$work/home"
export AFFRAME_HTTP_PORT=18080 AFFRAME_HTTPS_PORT=18443
export AFFRAME_HEALTH_TRIES=15 AFFRAME_MAX_DISK_PERCENT=99
export AFFRAME_ALLOW_ROOT=1 # the rerun container on a machine that is not Linux runs as root
export VAULT_ADDR=http://127.0.0.1:18200 VAULT_TOKEN=integration-root AFFRAME_VAULT_KV_PREFIX=secret/data/integration
# One commit per deploy: s1 and s2 the good builds, s3 the broken one, s4 infrastructure only, s5 a
# rebuild of s2's tree with another image ID.
s1="$(printf '1%.0s' {1..40})" s2="$(printf '2%.0s' {1..40})" s3="$(printf '3%.0s' {1..40})"
s4="$(printf '4%.0s' {1..40})" s5="$(printf '5%.0s' {1..40})"
current="$AFFRAME_HOME/current/deploy/bin"
failures=0
service=fixture

cleanup() {
  docker rm -f -v "$PROJECT-$service-blue" "$PROJECT-$service-green" afframe-restore-drill \
    afframe-test-vault > /dev/null 2>&1 || true
  [[ ! -f "$current/../compose.prod.yml" ]] \
    || docker compose -p "$PROJECT" -f "$current/../compose.prod.yml" down -v --rmi local > /dev/null 2>&1
  docker volume rm afframe-restore-drill > /dev/null 2>&1 || true
  docker image rm -f "$PROJECT/$service":{"$s1","$s2","$s3","$s5",current,previous} > /dev/null 2>&1 || true
  # Postgres wrote files as its own uid; remove them from a container.
  docker run --rm -v "$work:/work" "$alpine" rm -rf /work/home > /dev/null 2>&1 || true
  rm -rf "$work"
  docker image rm afframe-test/{alpine,vault}:local > /dev/null 2>&1 || true
}
trap cleanup EXIT

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
state() { sed -n "s/^$1=//p" "$AFFRAME_HOME/state/$service"; }
HOST=""
read_vars "$root/deploy/test/services/$service.conf" HOST
serves() {
  [[ "$(curl -sk -o /dev/null -w '%{http_code}' --resolve "$HOST:$AFFRAME_HTTPS_PORT:127.0.0.1" \
    "https://$HOST:$AFFRAME_HTTPS_PORT/health")" == 200 ]]
}
# ship <git-sha> <run> [<service>]: like deploy.yml.
ship() {
  local sha="$1" run="$2" images=/dev/null
  shift 2
  tar -C "$root" -cf - deploy | sh -c "set -- $sha"$'\n'"$(< "$root/deploy/bin/afframe-receive")" > /dev/null
  cp "$root/deploy/test/services/$service.conf" "$AFFRAME_HOME/releases/$sha/deploy/services/"
  (($# == 0)) || images="$work/$sha.tar"
  "$AFFRAME_HOME/releases/$sha/deploy/bin/afframe-deploy" deploy "$sha" "$run" "$@" < "$images"
}
# The deliberately broken image never gets healthy: give up sooner than for real images.
ship_broken() { AFFRAME_HEALTH_TRIES="${INTEGRATION_BROKEN_HEALTH_TRIES:-3}" ship "$@"; }
psql_prod() { psql_exec "$POSTGRES" -Atc "$1"; }
drill_fails() {
  local output
  if output="$("$current/afframe-restore-drill" 2>&1)"; then return 1; fi
  grep -qF -- "$1" <<< "$output" || { echo "$output" | tail -n 5; return 1; }
}
# restore <pgbackrest restore option>...: step 4 of ARCHITECTURE.md section 6.3.
restore() {
  # shellcheck disable=SC2016 # expanded by the container's shell
  docker run --rm --env-file "$AFFRAME_HOME/env/infra.env" -v afframe-postgres-data:/var/lib/postgresql \
    -v "$PGBACKREST_VOLUME:/var/lib/pgbackrest" "$POSTGRES:local" \
    sh -c 'mkdir -m 700 -p "$PGBACKREST_PG1_PATH" && exec pgbackrest restore "$@"' sh "$@"
}
# wait_paused <seconds>: step 5 of ARCHITECTURE.md section 6.3, until Postgres pauses at the target.
wait_paused() {
  local i
  for ((i = 0; i < $1; i++)); do
    [[ "$(psql_prod 'select pg_get_wal_replay_pause_state()' 2> /dev/null)" != paused ]] || return 0
    sleep 1
  done
  docker logs --tail 20 "$POSTGRES" >&2
  return 1
}
releases() { find "$AFFRAME_HOME/releases" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' '; }

# public_response <path>: with SNI HOST.
public_response() {
  curl -sk -i --resolve "$HOST:$AFFRAME_HTTPS_PORT:127.0.0.1" "https://$HOST:$AFFRAME_HTTPS_PORT$1"
}
no_stack_headers() {
  local response
  response="$(public_response /health)"
  grep -q '^HTTP/' <<< "$response" || return 1
  ! grep -qiE '^(x-backend|server|x-powered-by):' <<< "$response"
}
error_page_neutral() {
  local response
  response="$(public_response /no-such-page)"
  grep -q '^HTTP/[0-9.]* 404' <<< "$response" || return 1
  grep -qi '</html>' <<< "$response" || return 1
  ! grep -qiE 'nginx|server:' <<< "$response"
}
direct_ip_refused() { fails curl -sk -o /dev/null "https://127.0.0.1:$AFFRAME_HTTPS_PORT/health"; }
unknown_sni_refused() {
  fails curl -sk -o /dev/null --resolve "other.test:$AFFRAME_HTTPS_PORT:127.0.0.1" \
    "https://other.test:$AFFRAME_HTTPS_PORT/health"
}

echo "== fixtures"
docker run -d --name afframe-test-vault -p "127.0.0.1:${VAULT_ADDR##*:}:8200" \
  -e VAULT_DEV_ROOT_TOKEN_ID="$VAULT_TOKEN" "$(test_image vault)" > /dev/null
# build <git-sha> <tree> <context>: the runner side.
build() {
  # A label per build gives each its own ID (s5: s2's tree).
  docker build -q --label "integration=$1" --label "afframe.tree=$2" -t "$PROJECT/$service:$1" "$3" > /dev/null
  docker image inspect -f '{{.Id}}' "$PROJECT/$service:$1" > "$work/$1.id"
  docker save "$PROJECT/$service:$1" > "$work/$1.tar"
  docker image rm "$PROJECT/$service:$1" > /dev/null
}
build "$s1" tree1 "$root/deploy/test/images/fixture" & pid1=$!
build "$s2" tree2 "$root/deploy/test/images/fixture" & pid2=$!
build "$s3" tree3 "$root/deploy/test/images/broken" & pid3=$!
build "$s5" tree2 "$root/deploy/test/images/fixture" & pid5=$!
wait "$pid1" && wait "$pid2" && wait "$pid3" && wait "$pid5"
id1="$(cat "$work/$s1.id")" id2="$(cat "$work/$s2.id")" id5="$(cat "$work/$s5.id")"
curl -fsS --retry 30 --retry-all-errors --retry-delay 1 "$VAULT_ADDR/v1/sys/health" > /dev/null

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$HOST" \
  -addext "subjectAltName=DNS:$HOST,DNS:*.$HOST" -keyout "$work/origin.key" -out "$work/origin.crt" 2> /dev/null
jq -n --rawfile cert "$work/origin.crt" --rawfile key "$work/origin.key" '{data: {
  POSTGRES_PASSWORD: "integration",
  PGBACKREST_REPO1_TYPE: "posix", PGBACKREST_REPO1_PATH: "/var/lib/pgbackrest",
  PGBACKREST_REPO1_CIPHER_TYPE: "aes-256-cbc", PGBACKREST_REPO1_CIPHER_PASS: "integration",
  ORIGIN_CERT_PEM: $cert, ORIGIN_KEY_PEM: $key}}' \
  | curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" --data @- "$VAULT_ADDR/v1/$AFFRAME_VAULT_KV_PREFIX/infra" > /dev/null
curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" --data '{"data": {"GREETING": "hello"}}' \
  "$VAULT_ADDR/v1/$AFFRAME_VAULT_KV_PREFIX/app" > /dev/null

echo "== deploy"
check "first deploy" ship "$s1" 1 "$service"
check "served through Traefik" serves
check "public response carries no stack headers" no_stack_headers
check "public error page names no server software" error_page_neutral
check "request to the IP itself gets no certificate" direct_ip_refused
check "unknown host name gets no certificate" unknown_sni_refused
check "loaded image keeps its ID (state blue, v1)" test "$(state colour) $(state current)" == "blue $id1"
check "app env from Vault" test "$(docker exec "$PROJECT-$service-blue" printenv GREETING)" == hello
check "current is the release" test "$(readlink "$AFFRAME_HOME/current")" == "$AFFRAME_HOME/releases/$s1"
# The local backup repository needs no TLS. An S3 repository fails without this bundle.
check "Postgres trusts public certificate authorities" \
  docker exec "$POSTGRES" test -s /etc/ssl/certs/ca-certificates.crt

check "second deploy" ship "$s2" 2 "$service"
check "switched to green v2" test "$(state colour) $(state current) $(state previous)" == "green $id2 $id1"
check "old colour removed" fails docker inspect "$PROJECT-$service-blue"
check "still served" serves

check "unhealthy image is refused" fails ship_broken "$s3" 3 "$service"
check "traffic stays on v2" test "$(state colour) $(state current)" == "green $id2"
check "unhealthy container removed" fails docker inspect "$PROJECT-$service-blue"
check "served after refusal" serves
check "current still the last good release" test "$(readlink "$AFFRAME_HOME/current")" == "$AFFRAME_HOME/releases/$s2"

check "an older run is refused" fails ship "$s1" 1
check "previous image survives pruning" docker image inspect "$id1" > /dev/null

check "rollback" "$current/afframe-deploy" rollback "$service"
check "back on v1, v2 held" test "$(state current) $(state previous) $(state held)" == "$id1 $id2 $id2"
check "served after rollback" serves
check "deploy offering the held image" ship "$s2" 4 "$service"
check "keeps the rollback" test "$(state current) $(state colour)" == "$id1 blue"
check "rebuild of the held tree has another image ID" test "$id5" != "$id2"
check "deploy offering it" ship "$s5" 4 "$service"
check "still keeps the rollback" test "$(state current) $(state colour)" == "$id1 blue"

echo "== backup and restore"
check "infrastructure-only deploy" ship "$s4" 5
check "releases pruned to current and previous" test "$(releases)" == "$s4 $s5 "
psql_prod "create table drill (x int); insert into drill values (42)" > /dev/null
check "full backup" "$current/afframe-backup" full
check "sentinel written" \
  test "$(psql_prod "select count(*) from ops.heartbeat where at > now() - interval '1 hour'")" -eq 1
psql_prod "insert into drill values (43); select pg_switch_wal()" > /dev/null
check "diff backup" "$current/afframe-backup" diff
check "health ok" "$current/afframe-health"
check "restore drill" "$current/afframe-restore-drill"

# No backup here: it would refresh the sentinel. `pgbackrest check` archives the current WAL.
psql_prod "update ops.heartbeat set at = now() - interval '30 hours'" > /dev/null
check "stale data archived" docker exec -u postgres "$POSTGRES" pgbackrest check
check "drill refuses stale data" drill_fails "pgBackRest restore: newest data is 30 h old"

echo "== restore to a point in time (ARCHITECTURE.md section 6.3)"
psql_prod "insert into drill values (44)" > /dev/null
check "backup before the target" "$current/afframe-backup" diff
sleep 1
target="$(psql_prod "select now()")"
sleep 1
psql_prod "insert into drill values (45)" > /dev/null
check "WAL after the target archived" docker exec "$POSTGRES" pgbackrest check
check "postgres stopped" docker stop --time 120 "$POSTGRES"
check "restored to the target" restore --delta --type=time --target-action=pause "--target=$target"
check "postgres started" docker start "$POSTGRES"
check "paused at the target" wait_paused 120
check "rows up to the target only, while paused" \
  test "$(psql_prod "select string_agg(x::text, ' ' order by x) from drill")" == "42 43 44"
check "read-only while paused" fails psql_prod "insert into drill values (46)"
check "resumed" psql_prod "select pg_wal_replay_resume()"
check "recovery ended" wait_recovered "$POSTGRES" 120
check "rows up to the target only, after the recovery" \
  test "$(psql_prod "select string_agg(x::text, ' ' order by x) from drill")" == "42 43 44"
check "stanza-create accepts the restored database" docker exec "$POSTGRES" pgbackrest stanza-create
check "full backup after the restore" "$current/afframe-backup" full
check "restore drill after the restore" "$current/afframe-restore-drill"

if ((failures > 0)); then
  echo "${failures} integration check(s) failed"
  exit 1
fi
echo "all integration checks passed"
