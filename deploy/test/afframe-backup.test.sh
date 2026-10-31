#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" FAKE="$work/fake" AFFRAME_ALLOW_ROOT=1
mkdir -p "$FAKE/bin" "$AFFRAME_HOME/env"
printf 'HEARTBEAT_BACKUP_URL=https://hb.test/ping/bk-key-secret\nALERT_URL=https://alert.test/al-key-secret\n' \
  > "$AFFRAME_HOME/env/infra.env"

# $FAKE/backup-fail: pgbackrest fails. $FAKE/sentinel-fail: the heartbeat sentinel psql fails.
cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls"
if [[ "$*" == *pgbackrest* ]]; then
  echo "backup output"
  [[ ! -e "$FAKE/backup-fail" ]]
  exit
fi
[[ ! -e "$FAKE/sentinel-fail" ]]
FAKEDOCKER
cat > "$FAKE/bin/curl" <<'FAKECURL'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/args"
{ cat; echo ---; } >> "$FAKE/stdin"
FAKECURL
# The weekday number for `date -u +%u`.
cat > "$FAKE/bin/date" <<'FAKEDATE'
#!/usr/bin/env bash
cat "$FAKE/weekday"
FAKEDATE
chmod +x "$FAKE/bin/"*
echo 3 > "$FAKE/weekday"

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
backup() {
  : > "$FAKE/calls"
  : > "$FAKE/args"
  : > "$FAKE/stdin"
  PATH="$FAKE/bin:$PATH" "$root/deploy/bin/afframe-backup" "$@" < /dev/null > /dev/null 2> "$FAKE/err"
}
called() { grep -qF -- "$1" "$FAKE/calls"; }
sent() { grep -qxF -- "$1" "$FAKE/stdin"; }
reported() { grep -qF -- "$1" "$FAKE/err"; }

check "backup succeeds" backup full
check "pgbackrest runs the given type" called "pgbackrest --type=full backup"
check "success ping to the heartbeat URL" sent 'url = "https://hb.test/ping/bk-key-secret"'
check "no failure ping" fails sent 'url = "https://hb.test/ping/bk-key-secret/1"'
check "no alert" fails sent 'url = "https://alert.test/al-key-secret"'
check "no heartbeat or alert URL on curl's command line" fails grep -qE 'bk-key-secret|al-key-secret' "$FAKE/args"

touch "$FAKE/backup-fail"
check "a failed backup fails the job" fails backup full
check "failure ping with the exit code" sent 'url = "https://hb.test/ping/bk-key-secret/1"'
check "alert to ALERT_URL" sent 'url = "https://alert.test/al-key-secret"'
check "the backup output goes in the ping body" grep -q 'backup output' "$FAKE/args"
check "the exit code of pgbackrest is the exit code of the job" test "$(backup full; echo $?)" -eq 1
rm "$FAKE/backup-fail"

check "a bad type fails" fails backup weekly
check "and gives the usage" reported "usage: afframe-backup [full|diff]"
check "and runs no docker command" test ! -s "$FAKE/calls"

touch "$FAKE/sentinel-fail"
check "a failed sentinel write does not fail the job" backup full
check "it only warns" reported "ops.heartbeat sentinel not written"
check "the backup still ran" called "pgbackrest --type=full backup"
rm "$FAKE/sentinel-fail"

check "backup on a weekday" backup
check "defaults to a differential backup" called "pgbackrest --type=diff backup"
echo 7 > "$FAKE/weekday"
check "backup on Sunday" backup
check "defaults to a full backup" called "pgbackrest --type=full backup"
check "an explicit type wins on Sunday" backup diff
check "differential on Sunday when asked" called "pgbackrest --type=diff backup"

if ((failures > 0)); then
  echo "${failures} afframe-backup check(s) failed"
  exit 1
fi
echo "all afframe-backup checks passed"
