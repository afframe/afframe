#!/usr/bin/env bash
# Language-agnostic repo checks, shared by CI and the local gate (`npm run preflight`).
# Needs Docker. Tool versions are pinned here and nowhere else.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ACTIONLINT_IMAGE="rhysd/actionlint:1.7.12"
SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1"
as_me=(--user "$(id -u):$(id -g)")

echo "== actionlint"
docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$ACTIONLINT_IMAGE" -color

echo "== shellcheck"
mapfile -t shell_scripts < <(git ls-files '*.sh')
if [[ "${#shell_scripts[@]}" -gt 0 ]]; then
  docker run --rm "${as_me[@]}" -v "$PWD:/mnt" -w /mnt "$SHELLCHECK_IMAGE" "${shell_scripts[@]}"
fi

echo "== gitleaks (history)"
docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$GITLEAKS_IMAGE" git --no-banner --redact /repo

if [[ -z "${CI:-}" ]]; then
  echo "== gitleaks (uncommitted changes)"
  docker run --rm "${as_me[@]}" -v "$PWD:/repo" -w /repo "$GITLEAKS_IMAGE" git --pre-commit --no-banner --redact /repo
fi

echo "== deploy-gate tests"
bash scripts/ci/deploy-gate.test.sh
