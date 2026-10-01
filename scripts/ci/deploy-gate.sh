#!/usr/bin/env bash
# Decides whether a push to main may deploy.
# Usage: deploy-gate.sh <commit-sha>...   (needs `gh` auth and GITHUB_REPOSITORY)
# Prints `deploy=true` or `deploy=false`. The switch is a `no-deploy` label on the merged PR,
# or `[no deploy]` in its title or the commit message (case-insensitive).
# Fails closed: any lookup error, or a commit without a merged PR, exits non-zero.
set -euo pipefail

repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
[[ $# -gt 0 ]] || { echo "deploy-gate: no commits given" >&2; exit 2; }

reason=""
for sha in "$@"; do
  message="$(gh api "repos/${repo}/commits/${sha}" --jq '.commit.message | split("\n")[0]')"
  prs="$(gh api "repos/${repo}/commits/${sha}/pulls" --jq '.[] | "title:" + .title, (.labels[] | "label:" + .name)')"
  if [[ -z "$prs" ]]; then
    echo "deploy-gate: no pull request found for ${sha}" >&2
    exit 3
  fi

  while IFS= read -r line; do
    kind="${line%%:*}"
    lower="$(printf '%s' "${line#*:}" | tr '[:upper:]' '[:lower:]')"
    if [[ "$kind" == "label" && "$lower" == "no-deploy" ]]; then
      reason="label no-deploy on ${sha}"
    elif [[ "$kind" != "label" && "$lower" == *"[no deploy]"* ]]; then
      reason="[no deploy] in ${kind} of ${sha}"
    fi
  done <<< "message:${message}"$'\n'"${prs}"
done

if [[ -n "$reason" ]]; then
  echo "Deploy skipped on purpose (${reason}). The next merge without the switch deploys everything." >&2
  echo "deploy=false"
else
  echo "deploy=true"
fi
