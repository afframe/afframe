#!/usr/bin/env bash
# Usage: GH_REPO=<owner>/<repo> rulesets.sh [apply]
# Without `apply`: diffs each .github/rulesets/*.json against the live ruleset of the same name.
set -euo pipefail
: "${GH_REPO:?set GH_REPO, or gh resolves owner and repo from the origin remote}"

cd "$(git rev-parse --show-toplevel)"

api="repos/{owner}/{repo}/rulesets"
keys='{name, target, enforcement, conditions, bypass_actors, rules}'
drift=0
for file in .github/rulesets/*.json; do
  name="$(jq -r .name "$file")"
  id="$(gh api --paginate "$api?includes_parents=false&per_page=100" --jq ".[] | select(.name == \"$name\") | .id")"
  if [[ "${1:-}" == apply ]]; then
    if [[ -n "$id" ]]; then gh api -X PUT "$api/$id" --input "$file" > /dev/null
    else gh api -X POST "$api" --input "$file" > /dev/null; fi
    echo "applied: $name"
  elif [[ -z "$id" ]]; then
    echo "missing: $name"
    drift=1
  elif diff <(gh api "$api/$id" | jq -S "$keys") <(jq -S "$keys" "$file"); then
    echo "no drift: $name"
  else
    drift=1
  fi
done
exit "$drift"
