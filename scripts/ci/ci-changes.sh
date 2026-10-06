#!/usr/bin/env bash
# Prints what ci.yml builds and tests: services=<JSON [{name, dir}]>, tests=, integration=.
# Usage: ci-changes.sh <base-sha|all>   (an empty or unknown base means all)
# Exits 1 for a deploy/services/ entry without compose.ci.yml: a skipped test passes `ci`.
set -euo pipefail

base="${1:-}"
# The root workspace inputs repeat in label_of in scripts/ci/build-images.sh and in .dockerignore.
shared='^(compose\.ci\.yml|\.github/workflows/ci\.yml|package\.json|pnpm-(lock|workspace)\.yaml|\.dockerignore'
shared+='|deploy/postgres/.*'
shared+='|scripts/ci/((ci-changes|build-images|service-tests|image-scan)\.sh|trivy/Dockerfile))$|^packages/'
deploy='^(deploy/|\.github/workflows/deploy\.yml$)'

if [[ ! -f compose.ci.yml ]] && compgen -G 'deploy/services/*.conf' > /dev/null; then
  echo "::error::deploy/services/ has a deployable service but compose.ci.yml is missing." >&2
  exit 1
fi

if [[ -z "$base" || "$base" == all ]] || ! git cat-file -e "$base^{commit}" 2> /dev/null; then
  files="*"
else
  files="$(git diff --name-only "$base" HEAD)"
fi

services="[]"
for dockerfile in apps/*/Dockerfile; do
  [[ -f "$dockerfile" ]] || continue
  dir="$(dirname "$dockerfile")"
  if [[ "$files" == "*" ]] || grep -Eq "$shared|^$dir/" <<< "$files"; then
    services="$(jq -c --arg dir "$dir" '. + [{name: ($dir | split("/") | last), dir: $dir}]' <<< "$services")"
  fi
done

tests=false
[[ -f compose.ci.yml && "$services" != "[]" ]] && tests=true
integration=false
{ [[ "$files" == "*" ]] || grep -Eq "$deploy" <<< "$files"; } && integration=true

echo "services=$services"
echo "tests=$tests"
echo "integration=$integration"
