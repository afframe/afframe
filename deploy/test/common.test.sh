#!/usr/bin/env bash
# Fast tests for deploy/bin/common.sh with a fake `docker` on PATH: the dump remote takes either all
# DUMP_S3_* settings or all pgBackRest ones, never a mix. Run: bash deploy/test/common.test.sh
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home"
mkdir -p "$AFFRAME_HOME/env" "$work/bin"
printf '#!/usr/bin/env bash\necho obscured\n' > "$work/bin/docker"
chmod +x "$work/bin/docker"
# shellcheck source=deploy/bin/common.sh
source "$root/deploy/bin/common.sh"

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
infra() {
  printf '%s\n' DUMP_CRYPT_PASSWORD=pw PGBACKREST_REPO1_TYPE=s3 PGBACKREST_REPO1_S3_BUCKET=pgbr \
    PGBACKREST_REPO1_S3_ENDPOINT=pgbr.test PGBACKREST_REPO1_S3_KEY=pgbr-key \
    PGBACKREST_REPO1_S3_KEY_SECRET=pgbr-secret "$@" > "$AFFRAME_HOME/env/infra.env"
}
remote() { PATH="$work/bin:$PATH" dump_rclone_env "$work/rclone.env" 2> "$work/err"; }
has() { grep -qx -- "$1" "$work/rclone.env"; }

infra
check "pgBackRest settings without DUMP_S3_BUCKET" remote
check "pgBackRest bucket" has "RCLONE_CONFIG_DUMPS_REMOTE=base:pgbr/dumps"
check "pgBackRest token" has "RCLONE_CONFIG_BASE_ACCESS_KEY_ID=pgbr-key"
check "password obscured" has "RCLONE_CONFIG_DUMPS_PASSWORD=obscured"

infra DUMP_S3_BUCKET=dumps DUMP_S3_ENDPOINT=dumps.test DUMP_S3_KEY=dumps-key DUMP_S3_KEY_SECRET=dumps-secret
check "all DUMP_S3_* settings" remote
check "dump bucket" has "RCLONE_CONFIG_DUMPS_REMOTE=base:dumps/dumps"
check "dump token" has "RCLONE_CONFIG_BASE_SECRET_ACCESS_KEY=dumps-secret"
check "dump endpoint" has "RCLONE_CONFIG_BASE_ENDPOINT=https://dumps.test"

infra DUMP_S3_BUCKET=dumps DUMP_S3_ENDPOINT=dumps.test
check "DUMP_S3_BUCKET without its token is refused" fails remote
check "names the missing key" grep -q "DUMP_S3_KEY is required" "$work/err"

if ((failures > 0)); then
  echo "${failures} common.sh check(s) failed"
  exit 1
fi
echo "all common.sh checks passed"
