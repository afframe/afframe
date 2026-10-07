#!/usr/bin/env bash
# Fakes `docker` and `curl` on PATH: no daemon, Vault or heartbeat monitor needed.
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }
[[ -e /proc/meminfo ]] || { echo "skip: needs /proc/meminfo"; exit 77; }

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" FAKE="$work/fake" AFFRAME_ALLOW_ROOT=1 AFFRAME_MAX_DISK_PERCENT=101 \
  AFFRAME_MIN_MEMORY_PERCENT=0 VAULT_ADDR=http://vault.test VAULT_TOKEN=tok-secret-123
mkdir -p "$FAKE/bin" "$AFFRAME_HOME/env"
printf 'HEARTBEAT_HEALTH_URL=https://hb.test/ping/hb-key-secret\nALERT_URL=https://alert.test/al-key-secret\n' \
  > "$AFFRAME_HOME/env/infra.env"

# A bare `inspect` fails: the Postgres backup checks do not run.
cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
[[ "$1 $2" == "inspect -f" ]] || exit 1
echo "running healthy"
FAKEDOCKER
# $FAKE/vault: the lookup-self response, or "fail".
cat > "$FAKE/bin/curl" <<'FAKECURL'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/args"
{ cat; echo ---; } >> "$FAKE/stdin"
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
# vault <ttl seconds|null|fail>: the shape Vault gives, with nanoseconds and an offset.
vault() {
  case "$1" in
    fail) echo fail ;;
    null) echo '{"data": {"expire_time": null, "ttl": 0}}' ;;
    *) echo "{\"data\": {\"expire_time\": \"2026-10-12T09:15:54.466476215-04:00\", \"ttl\": $1}}" ;;
  esac > "$FAKE/vault"
}
# health [env argument]...
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

rm "$AFFRAME_HOME/host.conf" "$AFFRAME_HOME/vault-token"
check "no credential: health fails" fails health -u VAULT_TOKEN
check "and says so" reported "no Vault credential to check"

# shellcheck source=deploy/bin/common.sh
url_config_of() { (source "$root/deploy/bin/common.sh" && url_config "$1"); }
check "curl config escapes quotes and backslashes" \
  test "$(url_config_of 'https://x.test/a"b\c')" == 'url = "https://x.test/a\"b\\c"'

if ((failures > 0)); then
  echo "${failures} afframe-health check(s) failed"
  exit 1
fi
echo "all afframe-health checks passed"
