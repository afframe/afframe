#!/usr/bin/env bash
# Local gate: what CI runs, before you push. repo-lint.sh, then, once compose.ci.yml exists, the
# same compose run as the CI `test` job (migrate if defined, then test) in a throwaway project.
# Needs Docker.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

bash scripts/ci/repo-lint.sh

[[ -f compose.ci.yml ]] || exit 0

echo "== compose.ci.yml"
compose=(docker compose -p "gate-$$" -f compose.ci.yml)
trap '"${compose[@]}" down -v --rmi local' EXIT
if "${compose[@]}" config --services | grep -qx migrate; then
  "${compose[@]}" run --rm migrate
fi
"${compose[@]}" run --rm test
