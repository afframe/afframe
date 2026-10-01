#!/usr/bin/env bash
# Language-agnostic repo checks, shared by CI and the local gate.
# Needs Docker. Tool versions are pinned here and nowhere else.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ACTIONLINT_IMAGE="rhysd/actionlint:1.7.12"
SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1"
ZIZMOR_IMAGE="ghcr.io/zizmorcore/zizmor:1.30.1"
as_me=(--user "$(id -u):$(id -g)")

echo "== actionlint"
docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$ACTIONLINT_IMAGE" -color

echo "== zizmor"
docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$ZIZMOR_IMAGE" --offline --no-progress .github/workflows

echo "== compose files"
compose_home="$(mktemp -d)"
mkdir -p "$compose_home/env" && touch "$compose_home/env/infra.env"
AFFRAME_HOME="$compose_home" docker compose -f deploy/compose.prod.yml config --format json \
  | jq -e '.services.postgres.volumes[] | select(.source == "postgres-data" and .target == "/var/lib/postgresql")' > /dev/null \
  || { echo "postgres must keep its data in the postgres-data volume" >&2; exit 1; }
WEB_PORT=1 DB_PORT=2 docker compose -f compose.dev.yml config -q
rm -rf "$compose_home"

echo "== shellcheck"
mapfile -t shell_scripts < <(git ls-files '*.sh' 'deploy/bin/*')
if [[ "${#shell_scripts[@]}" -gt 0 ]]; then
  docker run --rm "${as_me[@]}" -v "$PWD:/mnt" -w /mnt "$SHELLCHECK_IMAGE" "${shell_scripts[@]}"
fi

echo "== gitleaks (history)"
docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$GITLEAKS_IMAGE" git --no-banner --redact /repo

if [[ -z "${CI:-}" ]]; then
  echo "== gitleaks (uncommitted changes)"
  docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$GITLEAKS_IMAGE" git --pre-commit --no-banner --redact /repo
fi

echo "== script tests"
while IFS= read -r test_script; do
  bash "$test_script"
done < <(git ls-files '*.test.sh')
