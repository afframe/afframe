#!/usr/bin/env bash
# Images are <project>/<service>:<tag> in the Compose project namespace, which afframe-deploy reads.
# Usage: build-images.sh <tag> <service>...
# Stdout is one `apps/<service>=<image>` line per service. Build output goes to stderr.
set -euo pipefail

tag="${1:?usage: build-images.sh <tag> <service>...}"
shift
[[ $# -gt 0 ]] || { echo "usage: build-images.sh <tag> <service>..." >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"
project="$(sed -n 's/^name: *//p' deploy/compose.prod.yml 2> /dev/null || true)"
[[ -n "$project" ]] || { echo "build-images.sh: no project name in deploy/compose.prod.yml" >&2; exit 2; }

# label_of <service>: a hash of the git trees an image of <service> builds from.
label_of() {
  # The root inputs repeat in the shared pattern of scripts/ci/ci-changes.sh and in .dockerignore.
  local path id
  git rev-parse --verify -q "HEAD:apps/$1" > /dev/null || { echo "build-images.sh: no apps/$1 in HEAD" >&2; return 1; }
  for path in "apps/$1" packages package.json pnpm-lock.yaml pnpm-workspace.yaml .dockerignore; do
    id="$(git rev-parse --verify -q "HEAD:$path")" || continue
    printf '%s %s\n' "$path" "$id"
  done | git hash-object --stdin
}

for service in "$@"; do
  tree="$(label_of "$service")"
  cache=()
  # ghaction-github-runtime sets ACTIONS_RUNTIME_TOKEN. The GHA cache needs a container builder.
  if [[ -n "${ACTIONS_RUNTIME_TOKEN:-}" ]]; then
    cache=(--cache-from "type=gha,scope=$service" --cache-to "type=gha,mode=max,scope=$service")
  fi
  # macOS bash 3.2 treats an empty array as unset under set -u: expand it only when set.
  # afframe-deploy compares the afframe.tree label to skip a deploy of the same tree.
  docker buildx build --load --platform linux/amd64 --provenance=false ${cache[@]+"${cache[@]}"} \
    --label "afframe.tree=$tree" -t "$project/$service:$tag" -f "apps/$service/Dockerfile" . >&2
  echo "apps/$service=$project/$service:$tag"
done
