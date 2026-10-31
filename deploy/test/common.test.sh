#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home"
mkdir -p "$AFFRAME_HOME/env"
# shellcheck source=deploy/bin/common.sh
source "$root/deploy/bin/common.sh"

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }

conf="$AFFRAME_HOME/test.conf"
printf 'MIGRATE=run --mode=fast\nTRAIL=x=\nHOST=h.test\nOTHER=1\nnoequals\n=empty\nPORT=8080' > "$conf"
MIGRATE='' TRAIL='' OTHER=unset PORT=''
check "read_vars returns 0" read_vars "$conf" MIGRATE TRAIL HOST PORT
check "read_vars keeps an = in a value" test "$MIGRATE" == "run --mode=fast"
check "read_vars keeps a trailing =" test "$TRAIL" == "x="
check "read_vars reads a last line without a newline" test "$PORT" == 8080
check "read_vars sets only the named keys" test "$OTHER" == unset
ignores_bare() { local noequals=unset; read_vars "$conf" noequals && [[ "$noequals" == unset ]]; }
check "read_vars ignores a line without =" ignores_bare
check "read_vars returns 0 for a missing file" read_vars "$AFFRAME_HOME/missing.conf" HOST

if [[ "$(id -u)" != 0 ]]; then
  chmod 000 "$conf"
  unreadable() { (read_vars "$conf" HOST) 2> /dev/null; }
  check "read_vars fails for an unreadable file" fails unreadable
  err="$( (read_vars "$conf" HOST) 2>&1)"
  check "and names the path relative to AFFRAME_HOME" grep -q "cannot read test.conf$" <<< "$err"
  check "and hides the absolute path" fails grep -qF "$AFFRAME_HOME" <<< "$err"
  chmod 600 "$conf"
fi

printf 'KEY=first\nKEY=second\n' > "$AFFRAME_HOME/env/infra.env"
check "env_value returns the first of duplicate keys" test "$(env_value KEY)" == first
check "env_value is empty for an absent key" test -z "$(env_value NONE)"
check "url_config escapes a quote and a backslash" \
  test "$(url_config 'https://h.test/a"b\c')" == 'url = "https://h.test/a\"b\\c"'

if ((failures > 0)); then
  echo "${failures} common check(s) failed"
  exit 1
fi
echo "all common checks passed"
