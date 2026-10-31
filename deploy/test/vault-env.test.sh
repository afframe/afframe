#!/usr/bin/env bash
# Fake `curl` on PATH: no Vault needed.
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }

root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export AFFRAME_HOME="$work/home" FAKE="$work/fake" VAULT_ADDR=http://vault.test VAULT_TOKEN=tok-secret-123 \
  AFFRAME_VAULT_KV_PREFIX=kv/data/test
mkdir -p "$FAKE/bin"

cat > "$FAKE/bin/curl" <<'FAKECURL'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/args"
case " $* " in *" -H @- "*) cat >> "$FAKE/stdin" ;; esac
case "${*: -1}" in
  */infra) [[ ! -e "$FAKE/fail-infra" ]] || exit 22; cat "$FAKE/infra.json" ;;
  */app) [[ ! -e "$FAKE/fail-app" ]] || exit 22; cat "$FAKE/app.json" ;;
  *) exit 22 ;;
esac
FAKECURL
chmod +x "$FAKE/bin/curl"
infra='{"SAMPLE_KEY": "pw", "APP_DB_PASSWORD": "p@ss/w%rd", "ORIGIN_CERT_PEM": "cert", "ORIGIN_KEY_PEM": "key"}'
kv() { echo "{\"data\": {\"data\": $1}}"; }
kv "$infra" > "$FAKE/infra.json"
kv '{"GREETING": "hello"}' > "$FAKE/app.json"

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }

# stdin from /dev/null: anything vault-env sends to curl must come from the script itself.
render() { PATH="$FAKE/bin:$PATH" "$root/deploy/bin/vault-env" < /dev/null > /dev/null; }

check "renders the secrets" render
check "token not on curl's command line" fails grep -q tok-secret-123 "$FAKE/args"
check "token header on stdin" test "$(grep -c '^X-Vault-Token: tok-secret-123$' "$FAKE/stdin")" -eq 2
check "infra env" grep -qx SAMPLE_KEY=pw "$AFFRAME_HOME/env/infra.env"
check "app env" grep -qx GREETING=hello "$AFFRAME_HOME/env/app.env"
check "origin key" grep -qx key "$AFFRAME_HOME/tls/origin.key"
check "KV path from AFFRAME_VAULT_KV_PREFIX" grep -q " http://vault.test/v1/kv/data/test/app$" "$FAKE/args"
url='DATABASE_URL=postgres://afframe_app:p%40ss%2Fw%25rd@afframe-postgres:5432/afframe'
check "database URL for the app role, password encoded" grep -qxF "$url" "$AFFRAME_HOME/env/app.env"
check "app password in the infra env only" fails grep -q APP_DB_PASSWORD "$AFFRAME_HOME/env/app.env"
check "no PEM key in the infra env" fails grep -q _PEM "$AFFRAME_HOME/env/infra.env"
check "no PEM key in the app env" fails grep -q _PEM "$AFFRAME_HOME/env/app.env"
mode() { test "$(stat -c %a "$1")" == 600; }
if stat -c %a / > /dev/null 2>&1; then
  check "infra env readable by the deploy user only" mode "$AFFRAME_HOME/env/infra.env"
  check "app env readable by the deploy user only" mode "$AFFRAME_HOME/env/app.env"
  check "origin key readable by the deploy user only" mode "$AFFRAME_HOME/tls/origin.key"
fi

render_err() { PATH="$FAKE/bin:$PATH" "$root/deploy/bin/vault-env" < /dev/null 2>&1 > /dev/null; }
kv '{"GREETING": "hello", "DATABASE_URL": "postgres://other"}' > "$FAKE/app.json"
check "a DATABASE_URL in the app secret fails" fails render
check "and names the key" grep -q "DATABASE_URL in the app secret is not allowed" <<< "$(render_err)"
check "the derived one stays" test "$(grep '^DATABASE_URL=' "$AFFRAME_HOME/env/app.env")" == "$url"
kv '{"GREETING": "hello"}' > "$FAKE/app.json"

kv "$(jq 'del(.APP_DB_PASSWORD)' <<< "$infra")" > "$FAKE/infra.json"
check "missing APP_DB_PASSWORD fails" fails render
check "and names the key" grep -q "APP_DB_PASSWORD missing in infra" <<< "$(render_err)"
kv '{"APP_DB_PASSWORD": "", "ORIGIN_CERT_PEM": "cert", "ORIGIN_KEY_PEM": "key"}' > "$FAKE/infra.json"
check "empty APP_DB_PASSWORD fails" fails render
kv "$infra" > "$FAKE/infra.json"

kv "$(jq '.SAMPLE_KEY = "line1\nline2"' <<< "$infra")" > "$FAKE/infra.json"
check "a multi-line infra value fails" fails render
check "and names the key" grep -q "multi-line value for SAMPLE_KEY" <<< "$(render_err)"
kv "$infra" > "$FAKE/infra.json"
kv '{"GREETING": "line1\nline2"}' > "$FAKE/app.json"
check "a multi-line app value fails" fails render
check "and names the key" grep -q "multi-line value for GREETING" <<< "$(render_err)"
kv '{"GREETING": "hello"}' > "$FAKE/app.json"

for key in $'EVIL\nPATH' $'TRAIL\n' lower_key DASH-KEY; do
  kv "$(jq --arg k "$key" '.[$k] = "x"' <<< '{"GREETING": "hello"}')" > "$FAKE/app.json"
  check "a bad key fails: ${key//$'\n'/\\n}" fails render
  check "and names the key" grep -qF "bad key ${key%%$'\n'*}" <<< "$(render_err)"
done
kv '{"GREETING": "hello", "lower_PEM": "pem"}' > "$FAKE/app.json"
check "a PEM key skips the key check" render
kv '{"GREETING": "hello"}' > "$FAKE/app.json"

touch "$FAKE/fail-infra"
check "a failing read of the infra secret fails" fails render
check "and says so" grep -q "cannot read the infra secret" <<< "$(render_err)"
rm "$FAKE/fail-infra"
touch "$FAKE/fail-app"
check "a failing read of the app secret fails" fails render
check "and says so" grep -q "cannot read the app secret" <<< "$(render_err)"
rm "$FAKE/fail-app"
check "renders again once the reads work" render

printf 'VAULT_ADDR=http://vault.test\nAFFRAME_VAULT_KV_PREFIX=kv/data/host\n' > "$AFFRAME_HOME/host.conf"
echo tok-file-456 > "$AFFRAME_HOME/vault-token"
: > "$FAKE/stdin"
host_render() {
  env -u VAULT_ADDR -u VAULT_TOKEN -u AFFRAME_VAULT_KV_PREFIX PATH="$FAKE/bin:$PATH" "$root/deploy/bin/vault-env" \
    < /dev/null > /dev/null
}
check "renders from host config" host_render
check "token from the token file" test "$(grep -c '^X-Vault-Token: tok-file-456$' "$FAKE/stdin")" -eq 2
check "prefix from host.conf" grep -q "/v1/kv/data/host/infra$" "$FAKE/args"

if ((failures > 0)); then
  echo "${failures} vault-env check(s) failed"
  exit 1
fi
echo "all vault-env checks passed"
