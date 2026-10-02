#!/usr/bin/env bash
# End-to-end test of the production stack on a local Docker daemon: a Vault dev server and a local
# registry stand in for oracle-vps Vault and GHCR. Covers afframe-deploy (deploy, blue/green
# switch, failed health check, rollback, image validation), afframe-backup, afframe-health,
# afframe-dump and afframe-restore-drill. Uses the committed HEAD. Never run it on afframe-vps: it uses the same
# container names. Run: bash deploy/test/integration.sh (nightly in CI).
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
export AFFRAME_HOME="$work/home"
export AFFRAME_REGISTRY=localhost:5055/afframe
export AFFRAME_HTTP_PORT=18080 AFFRAME_HTTPS_PORT=18443
export AFFRAME_HEALTH_TRIES=15 AFFRAME_MAX_DISK_PERCENT=99
export VAULT_ADDR=http://127.0.0.1:18200 VAULT_TOKEN=integration-root
bin="$AFFRAME_HOME/repo/deploy/bin"
failures=0

cleanup() {
  docker rm -f afframe-placeholder-blue afframe-placeholder-green afframe-restore-drill \
    afframe-test-vault afframe-test-registry > /dev/null 2>&1 || true
  [[ -f "$AFFRAME_HOME/repo/deploy/compose.prod.yml" ]] \
    && docker compose -p afframe -f "$AFFRAME_HOME/repo/deploy/compose.prod.yml" down -v --rmi local > /dev/null 2>&1
  docker volume rm afframe-restore-drill > /dev/null 2>&1 || true
  # Postgres wrote files as its own uid; remove them from a container.
  docker run --rm -v "$work:/work" alpine:3 rm -rf /work/home > /dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
state() { sed -n "s/^$1=//p" "$AFFRAME_HOME/state/placeholder"; }
serves() {
  [[ "$(curl -sk -o /dev/null -w '%{http_code}' --resolve "afframe.com:$AFFRAME_HTTPS_PORT:127.0.0.1" \
    "https://afframe.com:$AFFRAME_HTTPS_PORT/health")" == 200 ]]
}
# stdin from /dev/null: no registry token (the local registry needs none).
deploy_cmd() { "$bin/afframe-deploy" "$@" < /dev/null; }
psql_prod() { docker exec -u postgres afframe-postgres psql -U afframe -d afframe -Atc "$1"; }

echo "== fixtures"
git clone -q --bare "$root" "$work/origin.git"
sha="$(git -C "$root" rev-parse HEAD)"
git -C "$work/origin.git" update-ref refs/heads/main "$sha"
mkdir -p "$AFFRAME_HOME"
git clone -q "$work/origin.git" "$AFFRAME_HOME/repo"

docker run -d --name afframe-test-registry -p 127.0.0.1:5055:5000 registry:3 > /dev/null
docker run -d --name afframe-test-vault -p 127.0.0.1:18200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID="$VAULT_TOKEN" hashicorp/vault:2.1.1 > /dev/null
until curl -fs "$VAULT_ADDR/v1/sys/health" > /dev/null; do sleep 1; done

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=afframe.com \
  -keyout "$work/origin.key" -out "$work/origin.crt" 2> /dev/null
jq -n --rawfile cert "$work/origin.crt" --rawfile key "$work/origin.key" '{data: {
  POSTGRES_PASSWORD: "integration",
  PGBACKREST_REPO1_TYPE: "posix", PGBACKREST_REPO1_PATH: "/var/lib/pgbackrest",
  PGBACKREST_REPO1_CIPHER_TYPE: "aes-256-cbc", PGBACKREST_REPO1_CIPHER_PASS: "integration",
  DUMP_CRYPT_PASSWORD: "integration",
  ORIGIN_CERT_PEM: $cert, ORIGIN_KEY_PEM: $key}}' \
  | curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" --data @- "$VAULT_ADDR/v1/secret/data/afframe/prod/infra" > /dev/null
curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" --data '{"data": {"GREETING": "hello"}}' \
  "$VAULT_ADDR/v1/secret/data/afframe/prod/app" > /dev/null

push() {
  docker build -q --label "integration=$1" -t "$AFFRAME_REGISTRY/placeholder:$1" "${2:-$root/apps/placeholder}" > /dev/null
  docker push -q "$AFFRAME_REGISTRY/placeholder:$1" > /dev/null
  docker inspect -f '{{index .RepoDigests 0}}' "$AFFRAME_REGISTRY/placeholder:$1"
}
img1="$(push v1)"
img2="$(push v2)"
mkdir -p "$work/broken"
printf 'FROM nginx:1.30.5-alpine\n' > "$work/broken/Dockerfile" # listens on 80, no /health on $PORT
broken="$(push broken "$work/broken")"

echo "== deploy"
check "first deploy" deploy_cmd deploy "$sha" "placeholder=$img1"
check "served through Traefik" serves
check "state blue v1" test "$(state colour) $(state current)" == "blue $img1"
check "app env from Vault" test "$(docker exec afframe-placeholder-blue printenv GREETING)" == hello

check "second deploy" deploy_cmd deploy "$sha" "placeholder=$img2"
check "switched to green v2" test "$(state colour) $(state current) $(state previous)" == "green $img2 $img1"
check "old colour removed" fails docker inspect afframe-placeholder-blue
check "still served" serves

check "unhealthy image is refused" fails deploy_cmd deploy "$sha" "placeholder=$broken"
check "traffic stays on v2" test "$(state colour) $(state current)" == "green $img2"
check "unhealthy container removed" fails docker inspect afframe-placeholder-blue
check "served after refusal" serves

check "rollback" deploy_cmd rollback placeholder
check "back on v1" test "$(state current) $(state previous)" == "$img1 $img2"
check "served after rollback" serves

check "foreign registry is refused" fails deploy_cmd deploy "$sha" \
  "placeholder=docker.io/library/nginx@sha256:$(printf '0%.0s' {1..64})"
check "unknown commit is refused" fails deploy_cmd deploy "$(printf 'a%.0s' {1..40})"

echo "== backup and restore"
psql_prod "create table drill (x int); insert into drill values (42)" > /dev/null
check "full backup" "$bin/afframe-backup" full
psql_prod "insert into drill values (43); select pg_switch_wal()" > /dev/null
check "diff backup" "$bin/afframe-backup" diff
check "health ok" "$bin/afframe-health"
check "nightly dump" "$bin/afframe-dump"
check "dump stored encrypted" test "$(find "$AFFRAME_HOME/dumps" -type f | wc -l)" -eq 2
check "no plaintext dump" fails grep -rqa PGDMP "$AFFRAME_HOME/dumps"
check "restore drill" "$bin/afframe-restore-drill"

if ((failures > 0)); then
  echo "${failures} integration check(s) failed"
  exit 1
fi
echo "all integration checks passed"
