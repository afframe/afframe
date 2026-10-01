#!/usr/bin/env bash
# Lists what a push to main has to deploy. Usage: deploy-services.sh <before-sha> <sha>
# Prints `services=<JSON array>` (deployable services whose apps/<name>/ changed) and
# `infra=true|false` (deploy/ changed). Deployable = apps/<name>/Dockerfile plus
# deploy/services/<name>.env. An empty, all-zero or unknown <before-sha> (first push,
# manual run) means everything.
set -euo pipefail

before="${1:-}" sha="${2:?usage: deploy-services.sh <before-sha> <sha>}"
mapfile -t deployable < <(
  for manifest in deploy/services/*.env; do
    name="$(basename "$manifest" .env)"
    [[ -f "apps/$name/Dockerfile" ]] && echo "$name"
  done
)

if [[ -z "$before" || "$before" =~ ^0+$ ]] || ! git cat-file -e "$before^{commit}" 2> /dev/null; then
  changed=("${deployable[@]}")
  infra=true
else
  mapfile -t files < <(git diff --name-only "$before" "$sha")
  changed=()
  for name in "${deployable[@]}"; do
    printf '%s\n' "${files[@]}" | grep -q -e "^apps/$name/" -e "^deploy/services/$name.env$" && changed+=("$name")
  done
  infra=false
  printf '%s\n' "${files[@]}" | grep -q '^deploy/' && infra=true
fi

echo "services=$(printf '%s\n' "${changed[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
echo "infra=$infra"
