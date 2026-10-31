#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home"
sha="$(printf 'a%.0s' {1..40})"
mkdir -p "$work/src/deploy"
echo content > "$work/src/deploy/file"

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
receive() { sh "$root/deploy/bin/afframe-receive" "$@" > "$work/out" 2>&1; }
good_stream() { tar -cf - -C "$work/src" deploy; }
exit_code_of() { receive "$@" < /dev/null; echo $?; }

check "corrupt tar stream: receive fails" fails receive "$sha" < <(echo not a tar stream)
check "and leaves no release" test ! -e "$AFFRAME_HOME/releases/$sha"

mkdir -p "$AFFRAME_HOME/releases/$sha.tmp"
echo stale > "$AFFRAME_HOME/releases/$sha.tmp/stale"
check "good stream after a stale temporary folder: receive succeeds" receive "$sha" < <(good_stream)
check "and unpacks the release" test -f "$AFFRAME_HOME/releases/$sha/deploy/file"
check "and drops the stale content" test ! -e "$AFFRAME_HOME/releases/$sha/stale"
check "and leaves no temporary folder" test ! -e "$AFFRAME_HOME/releases/$sha.tmp"
check "and reports the release" grep -qx "release $sha received" "$work/out"

check "empty sha exits 2" test "$(exit_code_of "")" -eq 2
check "no sha exits 2" test "$(exit_code_of)" -eq 2
check "sha with dots exits 2" test "$(exit_code_of "..")" -eq 2
check "sha with a path exits 2" test "$(exit_code_of "../x")" -eq 2
check "sha with uppercase exits 2" test "$(exit_code_of "ABC")" -eq 2
check "a refused sha creates nothing outside releases" test ! -e "$AFFRAME_HOME/x"

if ((failures > 0)); then
  echo "${failures} afframe-receive check(s) failed"
  exit 1
fi
echo "all afframe-receive checks passed"
