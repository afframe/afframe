# shellcheck shell=bash disable=SC2034
AFFRAME_HOME="${AFFRAME_HOME:-$HOME/afframe}"
REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() { echo "${0##*/}: $*" >&2; exit 1; }
log() { echo "==> $*"; }

PROJECT="$(sed -n 's/^name: *//p' "$REPO/deploy/compose.prod.yml")"
[[ -n "$PROJECT" ]] || die "no project name in deploy/compose.prod.yml"
TRAEFIK="$PROJECT-traefik"
POSTGRES="$PROJECT-postgres"
EDGE_NETWORK="$PROJECT-edge"
DB_NETWORK="$PROJECT-db"
PGBACKREST_VOLUME=afframe-pgbackrest # literal, like its name: in deploy/compose.prod.yml
RPO_HOURS=26 # recovery point target: above the interval of deploy/host/systemd/afframe-backup.timer

# refuse_root: a root run means a unit without its User= drop-in. AFFRAME_ALLOW_ROOT=1 is for tests.
refuse_root() {
  [[ "$(id -u)" != 0 || "${AFFRAME_ALLOW_ROOT:-}" == 1 ]] || die "refusing to run as root"
}

# env_value <KEY>: empty when absent.
env_value() {
  local file="$AFFRAME_HOME/env/infra.env"
  [[ -f "$file" ]] || return 0
  sed -n "s/^$1=//p" "$file" | head -n 1
}

# read_vars <file> <NAME>...: sets each NAME from NAME=value lines, literally, never evaluated.
read_vars() {
  local file="$1" key value name
  shift
  [[ -f "$file" ]] || return 0
  # A relative name: Actions logs are public.
  [[ -r "$file" ]] || { file="${file#"$REPO/"}"; die "cannot read ${file#"$AFFRAME_HOME/"}"; }
  while IFS='=' read -r key value; do
    for name in "$@"; do
      [[ "$key" == "$name" ]] && printf -v "$name" '%s' "$value"
    done
  done < "$file"
  return 0
}

psql_exec() {
  local container="$1"
  shift
  # shellcheck disable=SC2016 # expanded by the container's shell
  docker exec "$container" sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' psql "$@"
}

# wait_recovered <container> <seconds>: fails with the log tail while Postgres is still in recovery.
wait_recovered() {
  local i
  for ((i = 0; i < $2; i++)); do
    [[ "$(psql_exec "$1" -Atc 'select pg_is_in_recovery()' 2> /dev/null)" != f ]] || return 0
    sleep 1
  done
  docker logs --tail 20 "$1" >&2
  echo "$1: still in recovery after $2 s" >&2
  return 1
}

# heartbeat <KEY> <exit code> [message]: ALERT_URL as well on a failure.
heartbeat() {
  local url alert
  url="$(env_value "$1")"
  alert="$(env_value ALERT_URL)"
  if [[ "$2" -eq 0 ]]; then
    [[ -z "$url" ]] || curl -fsS -m 10 --retry 3 -o /dev/null "$url" || echo "heartbeat $1 failed" >&2
    return 0
  fi
  [[ -z "$url" ]] || curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "${3:-}" "$url/$2" \
    || echo "heartbeat $1 failed" >&2
  [[ -z "$alert" ]] || curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "${0##*/}: ${3:-failed}" "$alert" \
    || echo "alert failed" >&2
}

# write_sentinel: upserts the ops.heartbeat row that afframe-restore-drill checks; only warns.
write_sentinel() {
  log "heartbeat sentinel"
  psql_exec "$POSTGRES" -q -v ON_ERROR_STOP=1 -c "
    create schema if not exists ops;
    create table if not exists ops.heartbeat (id int primary key, at timestamptz not null);
    insert into ops.heartbeat values (1, now()) on conflict (id) do update set at = excluded.at" \
    || echo "warning: ops.heartbeat sentinel not written; the restore drill will report stale data" >&2
}
