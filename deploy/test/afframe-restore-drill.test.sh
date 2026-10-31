#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" FAKE="$work/fake" AFFRAME_ALLOW_ROOT=1
mkdir -p "$FAKE/bin" "$AFFRAME_HOME/env"
printf 'HEARTBEAT_DRILL_URL=https://hb.test/ping/dr-key-secret\nALERT_URL=https://alert.test/al-key-secret\n' \
  > "$AFFRAME_HOME/env/infra.env"

# $FAKE/no-postgres, $FAKE/restore-fail, $FAKE/start-fail: the step fails.
# $FAKE/sentinel: the age in seconds, "empty" for no row or "fail" for a psql error.
cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls"
case "$1 $2" in
  "inspect -f") [[ ! -e "$FAKE/no-postgres" ]] && echo sha256:image ;;
  "run --rm") [[ ! -e "$FAKE/restore-fail" ]] ;;
  "run -d") [[ ! -e "$FAKE/start-fail" ]] ;;
  exec*)
    case "$*" in
      *pg_is_in_recovery*) echo f ;;
      *) [[ "$(cat "$FAKE/sentinel")" != fail ]] || exit 1
         [[ "$(cat "$FAKE/sentinel")" == empty ]] || cat "$FAKE/sentinel" ;;
    esac ;;
  *) exit 0 ;;
esac
FAKEDOCKER
cat > "$FAKE/bin/curl" <<'FAKECURL'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/args"
{ cat; echo ---; } >> "$FAKE/stdin"
FAKECURL
chmod +x "$FAKE/bin/"*

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
drill() {
  : > "$FAKE/calls"
  : > "$FAKE/args"
  : > "$FAKE/stdin"
  PATH="$FAKE/bin:$PATH" "$root/deploy/bin/afframe-restore-drill" < /dev/null > "$FAKE/out" 2>&1
}
called() { grep -qF -- "$1" "$FAKE/calls"; }
printed() { grep -qF -- "$1" "$FAKE/out"; }
sent() { grep -qxF -- "$1" "$FAKE/stdin"; }
# line_has <prefix> <text>: a recorded docker call that starts with <prefix> and holds <text>.
line_has() { grep -F -- "docker $1" "$FAKE/calls" | grep -qF -- "$2"; }

echo 3600 > "$FAKE/sentinel"
check "restore drill succeeds with a fresh sentinel" drill
check "restore run is hardened" line_has "run --rm" "--cap-drop ALL"
check "restore run drops privileges" line_has "run --rm" "--security-opt no-new-privileges"
check "started Postgres is hardened" line_has "run -d" "--cap-drop ALL"
check "started Postgres never archives WAL" line_has "run -d" "-c archive_mode=off"
check "success ping to the drill heartbeat URL" sent 'url = "https://hb.test/ping/dr-key-secret"'
check "no failure ping" fails sent 'url = "https://hb.test/ping/dr-key-secret/1"'
check "no alert" fails sent 'url = "https://alert.test/al-key-secret"'
check "no heartbeat URL on curl's command line" fails grep -qE 'dr-key-secret|al-key-secret' "$FAKE/args"
check "cleanup removes the container and its volumes" called "docker rm -f -v afframe-restore-drill"
check "cleanup removes the data volume" called "docker volume rm afframe-restore-drill"

echo 93600 > "$FAKE/sentinel"
check "sentinel exactly at the recovery point target passes" drill

echo 108000 > "$FAKE/sentinel"
check "sentinel older than the target: drill fails" fails drill
check "and names the age" printed "newest data is 30 h old"
check "failure ping with the exit code" sent 'url = "https://hb.test/ping/dr-key-secret/1"'
check "alert to ALERT_URL" sent 'url = "https://alert.test/al-key-secret"'
check "the message goes in the ping body" grep -q 'newest data is 30 h old' "$FAKE/args"

echo empty > "$FAKE/sentinel"
check "empty sentinel table: drill fails" fails drill
check "and says it is empty" printed "is empty"

echo fail > "$FAKE/sentinel"
check "no sentinel table: drill fails" fails drill
check "and says the sentinel is missing" printed "no ops.heartbeat sentinel"

echo 60 > "$FAKE/sentinel"
touch "$FAKE/no-postgres"
check "no Postgres container: drill fails" fails drill
check "and says it is not there" printed "afframe-postgres is not there"
check "and starts nothing" fails called "docker run"
rm -f "$FAKE/no-postgres"

touch "$FAKE/restore-fail"
check "failed restore: drill fails" fails drill
check "and starts no Postgres" fails called "docker run -d"
check "and removes the volume last" test "$(tail -n 1 "$FAKE/calls")" == "docker volume rm afframe-restore-drill"
rm -f "$FAKE/restore-fail"

touch "$FAKE/start-fail"
check "failed start: drill fails" fails drill
check "and still removes the container after the failure" test \
  "$(tail -n 2 "$FAKE/calls" | head -n 1)" == "docker rm -f -v afframe-restore-drill"
rm -f "$FAKE/start-fail"

if ((failures > 0)); then
  echo "${failures} afframe-restore-drill check(s) failed"
  exit 1
fi
echo "all afframe-restore-drill checks passed"
