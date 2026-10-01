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
