#!/usr/bin/env bash
# Lists what a push to main has to deploy. Usage: deploy-services.sh <sha> [all]
# (needs `gh` auth with deployments: read and GITHUB_REPOSITORY)
# Prints `services=<JSON array>` (deployable services whose apps/<name>/ or manifest changed) and
# `infra=true|false` (deploy/ changed). Deployable = apps/<name>/Dockerfile plus
# deploy/services/<name>.env. The base is the commit of the last successful deployment to the
# `production` environment, so changes of a skipped, cancelled or failed deploy are carried into
# the next one. `all`, no successful deployment yet, or a base unknown to git means everything.
# Fails closed: an API error exits non-zero.
set -euo pipefail

sha="${1:?usage: deploy-services.sh <sha> [all]}" mode="${2:-}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
mapfile -t deployable < <(
  for manifest in deploy/services/*.env; do
    name="$(basename "$manifest" .env)"
    [[ -f "apps/$name/Dockerfile" ]] && echo "$name"
  done
)

base=""
if [[ "$mode" != all ]]; then
  deployments="$(gh api --paginate "repos/${repo}/deployments?environment=production&per_page=100" --jq '.[] | "\(.id) \(.sha)"')"
  while read -r id deployed_sha; do
    [[ -n "$id" ]] || break
    states="$(gh api --paginate "repos/${repo}/deployments/${id}/statuses?per_page=100" --jq '.[].state')"
    if grep -qx success <<< "$states"; then
      base="$deployed_sha"
      break
    fi
  done <<< "$deployments"
fi

if [[ -z "$base" ]] || ! git cat-file -e "$base^{commit}" 2> /dev/null; then
  changed=("${deployable[@]}")
  infra=true
else
  echo "deploy-services: changes since the last successful deployment ${base}" >&2
  mapfile -t files < <(git diff --name-only "$base" "$sha")
  changed=()
  for name in "${deployable[@]}"; do
    printf '%s\n' "${files[@]}" | grep -q -e "^apps/$name/" -e "^deploy/services/$name.env$" && changed+=("$name")
  done
  infra=false
  printf '%s\n' "${files[@]}" | grep -q '^deploy/' && infra=true
fi

echo "services=$(printf '%s\n' "${changed[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
echo "infra=$infra"
