#!/usr/bin/env bash
# Usage: image-scan.sh <severities> [<label>=]<image>...
# Pulls an image that is not local.
# Exits 1 on a failed pull or scan, or on a fixable CVE at <severities>.
set -euo pipefail

severity="${1:?usage: image-scan.sh <severities> [<label>=]<image>...}"
shift
trivy="$(sed -n 's/^FROM //p' "$(git rev-parse --show-toplevel)/scripts/ci/trivy/Dockerfile")"
if [[ -z "$trivy" || "$trivy" == *$'\n'* ]]; then
  echo "::error::scripts/ci/trivy/Dockerfile needs one FROM line" >&2
  exit 1
fi
status=0
for arg in "$@"; do
  image="${arg#*=}"
  echo "::group::${arg}"
  if ! docker image inspect "$image" > /dev/null 2>&1 && ! docker pull -q "$image" > /dev/null; then
    status=1; echo "::error::${arg}: pull failed"; echo "::endgroup::"; continue
  fi
  # The image goes in through stdin: the scanner gets no Docker socket.
  docker save "$image" | docker run --rm -i --entrypoint sh "$trivy" -c 'cat > /tmp/image.tar &&
    exec trivy image --quiet --scanners vuln --severity "$1" --ignore-unfixed --exit-code 1 \
      --input /tmp/image.tar' sh "$severity" \
    || { status=1; echo "::error::${arg}: scan failed or found CVEs at ${severity}"; }
  echo "::endgroup::"
done
exit "$status"
