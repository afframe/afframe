#!/usr/bin/env bash
# Usage: [SERVICE_IMAGES="apps/<name>=<image> ..."] service-tests.sh <project>
# A service whose Dockerfile is in apps/<name> and that sets no build target runs the given image.
set -euo pipefail

project="${1:?usage: service-tests.sh <project>}"
compose=(docker compose -p "$project" -f compose.ci.yml)
# `run --rm test` shows only its own output: a failure prints the logs of the services it started.
cleanup() {
  [[ "$1" -eq 0 ]] || "${compose[@]}" logs --no-color || true
  "${compose[@]}" down -v --rmi local
}
trap 'cleanup "$?"' EXIT

# The tag is the image name compose would build, so compose skips the build.
if [[ -n "${SERVICE_IMAGES:-}" ]]; then
  while IFS=$'\t' read -r service dir image; do
    for pair in $SERVICE_IMAGES; do
      if [[ "${pair%%=*}" == "${dir#"$PWD"/}" ]]; then
        echo "service-tests: ${service} uses ${pair#*=}"
        docker tag "${pair#*=}" "${image:-$project-$service}"
      fi
    done
  done < <("${compose[@]}" config --format json \
    | jq -r '.services | to_entries[] | select(.value.build and (.value.build.target // "") == "")
      | (.value.build.dockerfile // "Dockerfile") as $file
      | (if ($file | startswith("/")) then $file else .value.build.context + "/" + $file end) as $path
      | [.key, ($path | sub("/[^/]*$"; "")), (.value.image // "")] | @tsv')
fi

# Read the list first: `| grep -q` can exit early and fail the pipeline with SIGPIPE under pipefail.
services="$("${compose[@]}" config --services)"
if grep -qx migrate <<< "$services"; then
  "${compose[@]}" run --rm migrate
fi
"${compose[@]}" run --rm test
