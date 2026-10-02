# shellcheck shell=bash disable=SC2034
# Shared by the afframe-* host scripts (sourced, not executed).
AFFRAME_HOME="${AFFRAME_HOME:-/srv/afframe}"
REPO="$AFFRAME_HOME/repo"

die() { echo "${0##*/}: $*" >&2; exit 1; }
log() { echo "==> $*"; }

# env_value <KEY>: value of KEY in the rendered infra env file, empty when absent.
env_value() {
  local file="$AFFRAME_HOME/env/infra.env"
  [[ -f "$file" ]] || return 0
  sed -n "s/^$1=//p" "$file" | head -n 1
}

# read_vars <file> <NAME>...: sets each NAME from NAME=value lines in file. Values are taken
# literally (never evaluated); comments and other keys are ignored. A missing file sets nothing.
read_vars() {
  local file="$1" key value name
  shift
  [[ -f "$file" ]] || return 0
  while IFS='=' read -r key value; do
    for name in "$@"; do
      [[ "$key" == "$name" ]] && printf -v "$name" '%s' "$value"
    done
  done < "$file"
  return 0
}

# heartbeat <KEY> <exit code> [message]: reports to the Better Stack heartbeat URL stored under KEY
# (success on 0, /<code> otherwise). Silent no-op when the URL is not configured.
heartbeat() {
  local url
  url="$(env_value "$1")"
  [[ -n "$url" ]] || return 0
  if [[ "$2" -eq 0 ]]; then
    curl -fsS -m 10 --retry 3 -o /dev/null "$url" || echo "heartbeat $1 failed" >&2
  else
    curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "${3:-}" "$url/$2" || echo "heartbeat $1 failed" >&2
  fi
}

RCLONE_IMAGE="rclone/rclone:1.75.1"

# dump_rclone_env <file>: rclone remotes for the nightly dumps as environment variables, written to
# <file> (mode 600, never on a command line). `base` is the bucket or a local directory mounted at
# /backup, `dumps` the crypt layer on top of it. With DUMP_S3_BUCKET set, all four DUMP_S3_*
# settings point the dumps at their own bucket and token; without it, the pgBackRest ones are used.
dump_rclone_env() {
  local password s3=PGBACKREST_REPO1_S3_ key
  password="$(env_value DUMP_CRYPT_PASSWORD)"
  [[ -n "$password" ]] || { echo "DUMP_CRYPT_PASSWORD missing in Vault infra" >&2; return 1; }
  if [[ -n "$(env_value DUMP_S3_BUCKET)" ]]; then
    s3=DUMP_S3_
    for key in ENDPOINT KEY KEY_SECRET; do
      [[ -n "$(env_value "DUMP_S3_$key")" ]] \
        || { echo "DUMP_S3_BUCKET is set, so DUMP_S3_$key is required in Vault infra" >&2; return 1; }
    done
  fi
  mkdir -p "$AFFRAME_HOME/dumps"
  (
    umask 077
    if [[ "$(env_value PGBACKREST_REPO1_TYPE)" == s3 ]]; then
      printf '%s\n' "RCLONE_CONFIG_BASE_TYPE=s3" "RCLONE_CONFIG_BASE_PROVIDER=Cloudflare" \
        "RCLONE_CONFIG_BASE_ACCESS_KEY_ID=$(env_value "${s3}KEY")" \
        "RCLONE_CONFIG_BASE_SECRET_ACCESS_KEY=$(env_value "${s3}KEY_SECRET")" \
        "RCLONE_CONFIG_BASE_ENDPOINT=https://$(env_value "${s3}ENDPOINT")" \
        "RCLONE_CONFIG_BASE_NO_CHECK_BUCKET=true" \
        "RCLONE_CONFIG_DUMPS_REMOTE=base:$(env_value "${s3}BUCKET")/dumps"
    else
      printf '%s\n' "RCLONE_CONFIG_BASE_TYPE=local" "RCLONE_CONFIG_DUMPS_REMOTE=base:/backup"
    fi > "$1"
    echo "RCLONE_CONFIG_DUMPS_TYPE=crypt" >> "$1"
    printf '%s' "$password" | docker run --rm -i "$RCLONE_IMAGE" obscure - \
      | sed 's/^/RCLONE_CONFIG_DUMPS_PASSWORD=/' >> "$1"
  )
}

# write_sentinel: upserts the ops.heartbeat row that afframe-restore-drill checks in every restore.
# afframe-dump and afframe-backup both call it, so either job alone keeps it fresh. A failure
# (read-only or locked database) only warns: the backup or dump itself matters more.
write_sentinel() {
  log "heartbeat sentinel"
  docker exec afframe-postgres psql -U afframe -d afframe -q -v ON_ERROR_STOP=1 -c "
    create schema if not exists ops;
    create table if not exists ops.heartbeat (id int primary key, at timestamptz not null);
    insert into ops.heartbeat values (1, now()) on conflict (id) do update set at = excluded.at" \
    || echo "warning: ops.heartbeat sentinel not written; the restore drill will report stale data" >&2
}
