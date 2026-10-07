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
  */infra) echo '{"data": {"data": {"SAMPLE_KEY": "pw", "ORIGIN_CERT_PEM": "cert", "ORIGIN_KEY_PEM": "key"}}}' ;;
  */app) echo '{"data": {"data": {"GREETING": "hello"}}}' ;;
  *) exit 22 ;;
esac
FAKECURL
chmod +x "$FAKE/bin/curl"

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
