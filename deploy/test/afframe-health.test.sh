#!/usr/bin/env bash
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }
[[ -e /proc/meminfo ]] || { echo "skip: needs /proc/meminfo"; exit 77; }

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" FAKE="$work/fake" AFFRAME_ALLOW_ROOT=1 AFFRAME_MAX_DISK_PERCENT=101 \
  AFFRAME_MIN_MEMORY_PERCENT=0 VAULT_ADDR=http://vault.test VAULT_TOKEN=tok-secret-123
mkdir -p "$FAKE/bin" "$FAKE/state" "$AFFRAME_HOME/env" "$AFFRAME_HOME/state"
printf 'HEARTBEAT_HEALTH_URL=https://hb.test/ping/hb-key-secret\nALERT_URL=https://alert.test/al-key-secret\n' \
  > "$AFFRAME_HOME/env/infra.env"

# $FAKE/state/<container>: the answer of `inspect -f`, or "fail". Default: running healthy.
# A bare `inspect` of Postgres fails unless $FAKE/pg exists: then the backup checks run.
# $FAKE/pgbackrest: the `pgbackrest info` JSON. $FAKE/archiver: the psql answer, or "fail".
cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
case "$*" in
  "inspect -f"*)
    state="$FAKE/state/${*: -1}"
    [[ -f "$state" ]] || { echo "running healthy"; exit 0; }
    [[ "$(cat "$state")" != fail ]] || exit 1
    cat "$state" ;;
  inspect*) [[ -e "$FAKE/pg" ]] ;;
  *pgbackrest*) cat "$FAKE/pgbackrest" ;;
  *psql*)
    [[ "$(cat "$FAKE/archiver")" != fail ]] || exit 1
    cat "$FAKE/archiver" ;;
  *) exit 1 ;;
esac
FAKEDOCKER
# $FAKE/vault: the lookup-self response, or "fail".
cat > "$FAKE/bin/curl" <<'FAKECURL'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/args"
case " $* " in *" -K - "* | *" -H @- "*) { cat; echo ---; } >> "$FAKE/stdin" ;; esac
[[ "${*: -1}" == */v1/auth/token/lookup-self ]] || exit 0
[[ "$(cat "$FAKE/vault")" != fail ]] || exit 22
cat "$FAKE/vault"
FAKECURL
chmod +x "$FAKE/bin/"*

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
# vault <ttl seconds|null|empty|fail>: the shape Vault gives, with nanoseconds and an offset.
vault() {
  case "$1" in
    fail) echo fail ;;
    empty) echo '{}' ;;
    null) echo '{"data": {"expire_time": null, "ttl": 0}}' ;;
    *) echo "{\"data\": {\"expire_time\": \"2026-10-12T09:15:54.466476215-04:00\", \"ttl\": $1}}" ;;
  esac > "$FAKE/vault"
}
health() {
  : > "$FAKE/args"
  : > "$FAKE/stdin"
  env ${@+"$@"} PATH="$FAKE/bin:$PATH" "$root/deploy/bin/afframe-health" < /dev/null > /dev/null 2> "$FAKE/err"
}
reported() { grep -qF -- "$1" "$FAKE/err"; }
sent() { grep -qxF -- "$1" "$FAKE/stdin"; }
on_argv() { grep -qF -- "$1" "$FAKE/args"; }

vault $((90 * 86400))
check "credential valid for 90 days: health ok" health
check "success ping to the heartbeat URL" sent 'url = "https://hb.test/ping/hb-key-secret"'
check "no alert" fails sent 'url = "https://alert.test/al-key-secret"'
check "no heartbeat URL on curl's command line" fails on_argv hb-key-secret
check "token header on stdin" sent "X-Vault-Token: tok-secret-123"
check "lookup-self of the Vault address" on_argv "http://vault.test/v1/auth/token/lookup-self"

vault null
check "credential without expiry: health ok" health

vault $((5 * 86400))
check "credential expires in 5 days: health fails" fails health
check "and names the days left" reported "Vault credential expires in 5 days"
check "failure ping to the heartbeat URL with the code" sent 'url = "https://hb.test/ping/hb-key-secret/1"'
check "alert to ALERT_URL" sent 'url = "https://alert.test/al-key-secret"'
check "the problem in the ping body" on_argv "expires in 5 days"
check "no heartbeat or alert URL on curl's command line" fails grep -qE 'hb-key-secret|al-key-secret' "$FAKE/args"
check "no token on curl's command line" fails on_argv tok-secret-123

check "threshold from AFFRAME_MIN_VAULT_DAYS" health AFFRAME_MIN_VAULT_DAYS=5

vault $((29 * 86400 + 3600))
check "29 days left: health fails" fails health
check "and names the days left" reported "Vault credential expires in 29 days"
vault $((30 * 86400 + 3600))
check "30 days left: health ok" health

vault empty
check "lookup answer without data: health fails" fails health
check "and says the lookup failed" reported "Vault credential lookup failed"

vault fail
check "lookup failure: health fails" fails health
check "and says so" reported "Vault credential lookup failed"
check "and never prints the token" fails reported tok-secret-123

printf 'VAULT_ADDR=http://vault.test\n' > "$AFFRAME_HOME/host.conf"
echo tok-file-456 > "$AFFRAME_HOME/vault-token"
vault $((90 * 86400))
check "token and address from the host files: health ok" health -u VAULT_ADDR -u VAULT_TOKEN
check "token from the token file" sent "X-Vault-Token: tok-file-456"
check "no token from the file on curl's command line" fails on_argv tok-file-456

chmod 000 "$AFFRAME_HOME/vault-token"
# Root reads the file anyway.
if [[ "$(id -u)" != 0 ]]; then
  check "unreadable token file: health fails" fails health -u VAULT_TOKEN
  check "and says so" reported "cannot read the Vault credential"
  check "and still sends the alert" sent 'url = "https://alert.test/al-key-secret"'
fi
rm -f "$AFFRAME_HOME/host.conf" "$AFFRAME_HOME/vault-token"
check "no credential: health fails" fails health -u VAULT_TOKEN
check "and says so" reported "no Vault credential to check"

vault $((90 * 86400))
state_of() { echo "$2" > "$FAKE/state/$1"; }
rm -f "$FAKE/state/"*
state_of afframe-postgres "exited "
check "an exited container: health fails" fails health
check "and names the container and its state" reported "afframe-postgres: exited"
check "and sends the alert" sent 'url = "https://alert.test/al-key-secret"'
state_of afframe-postgres "running unhealthy"
check "an unhealthy container: health fails" fails health
check "and names the health state" reported "afframe-postgres: running unhealthy"
state_of afframe-postgres fail
check "a container that inspect cannot find: health fails" fails health
check "and reports it as missing" reported "afframe-postgres: missing"
rm -f "$FAKE/state/"*
state_of afframe-traefik "running "
check "a running container without a health check: health ok" health
printf 'colour=blue\n' > "$AFFRAME_HOME/state/app"
state_of afframe-app-blue "restarting "
check "a service colour from the state folder is checked: health fails" fails health
check "and names the service container" reported "afframe-app-blue: restarting"
rm -f "$FAKE/state/"* "$AFFRAME_HOME/state/app"

check "disk at the limit: health fails" fails health AFFRAME_MAX_DISK_PERCENT=0
check "and names the disk" reported "disk / at "
check "memory under the minimum: health fails" fails health AFFRAME_MIN_MEMORY_PERCENT=101
check "and names the memory" reported "% memory available"

touch "$FAKE/pg"
now="$(date +%s)"
backup_json() { echo "[{\"backup\": [{\"timestamp\": {\"stop\": $1}}]}]" > "$FAKE/pgbackrest"; }
backup_json $((now - 3600))
echo f > "$FAKE/archiver"
check "recent backup and archiving fine: health ok" health
backup_json $((now - 27 * 3600))
check "last backup 27 h old: health fails" fails health
check "and names the age" reported "last backup 27 h ago"
backup_json $((now - 25 * 3600))
check "last backup 25 h old: health ok" health
echo '[]' > "$FAKE/pgbackrest"
check "no backup at all: health fails" fails health
check "and reports the epoch age" reported "h ago"
backup_json $((now - 3600))
echo t > "$FAKE/archiver"
check "WAL archiving failing: health fails" fails health
check "and says so" reported "WAL archiving failing (t)"
echo fail > "$FAKE/archiver"
check "archiver query failing: health fails" fails health
check "and reports it as unknown" reported "WAL archiving failing (unknown)"
check "the alert carries the problem" on_argv "WAL archiving failing"
rm -f "$FAKE/pg"
check "Postgres absent: the backup checks are skipped" health

# shellcheck source=deploy/bin/common.sh
url_config_of() { (source "$root/deploy/bin/common.sh" && url_config "$1"); }
check "curl config escapes quotes and backslashes" \
  test "$(url_config_of 'https://x.test/a"b\c')" == 'url = "https://x.test/a\"b\\c"'
# %{url} needs curl 7.75 or later.
if [[ "$(curl -s -o /dev/null -w '%{url}' file:///dev/null)" == file:///dev/null ]]; then
  odd='http://127.0.0.1:1/a"b\c'
  check "curl reads the URL back from the config" \
    test "$(url_config_of "$odd" | curl -s -o /dev/null -w '%{url}' -K -)" == "$odd"
fi

if ((failures > 0)); then
  echo "${failures} afframe-health check(s) failed"
  exit 1
fi
echo "all afframe-health checks passed"
