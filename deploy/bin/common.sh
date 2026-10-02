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
# /backup, `dumps` the crypt layer on top of it. DUMP_S3_* point the dumps at their own bucket and
# token; each one falls back to the pgBackRest setting.
dump_rclone_env() {
  local password
  password="$(env_value DUMP_CRYPT_PASSWORD)"
  [[ -n "$password" ]] || { echo "DUMP_CRYPT_PASSWORD missing in Vault infra" >&2; return 1; }
  mkdir -p "$AFFRAME_HOME/dumps"
  (
    umask 077
    if [[ "$(env_value PGBACKREST_REPO1_TYPE)" == s3 ]]; then
      printf '%s\n' "RCLONE_CONFIG_BASE_TYPE=s3" "RCLONE_CONFIG_BASE_PROVIDER=Cloudflare" \
        "RCLONE_CONFIG_BASE_ACCESS_KEY_ID=$(dump_setting KEY)" \
        "RCLONE_CONFIG_BASE_SECRET_ACCESS_KEY=$(dump_setting KEY_SECRET)" \
        "RCLONE_CONFIG_BASE_ENDPOINT=https://$(dump_setting ENDPOINT)" \
        "RCLONE_CONFIG_BASE_NO_CHECK_BUCKET=true" \
        "RCLONE_CONFIG_DUMPS_REMOTE=base:$(dump_setting BUCKET)/dumps"
    else
      printf '%s\n' "RCLONE_CONFIG_BASE_TYPE=local" "RCLONE_CONFIG_DUMPS_REMOTE=base:/backup"
    fi > "$1"
    echo "RCLONE_CONFIG_DUMPS_TYPE=crypt" >> "$1"
    printf '%s' "$password" | docker run --rm -i "$RCLONE_IMAGE" obscure - \
      | sed 's/^/RCLONE_CONFIG_DUMPS_PASSWORD=/' >> "$1"
  )
}

# dump_setting <BUCKET|ENDPOINT|KEY|KEY_SECRET>: DUMP_S3_<name>, else PGBACKREST_REPO1_S3_<name>.
dump_setting() {
  local value
  value="$(env_value "DUMP_S3_$1")"
  [[ -n "$value" ]] || value="$(env_value "PGBACKREST_REPO1_S3_$1")"
  printf '%s' "$value"
}
