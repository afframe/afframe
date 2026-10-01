#!/usr/bin/env bash
# Trivy scans of the repo (misconfigurations, secrets, dependencies) and of every image we build
# (apps/*/Dockerfile, deploy/postgres). Writes one SARIF file per target into the given directory
# for the Security tab (HIGH and CRITICAL only; image findings only when a fix exists). It never fails
# on findings: alerts live in code scanning. Nightly (.github/workflows/security.yml).
# Usage: trivy-scan.sh <sarif-dir>
set -euo pipefail

TRIVY_IMAGE="aquasec/trivy:0.74.0"
out="$(realpath -m "${1:?usage: trivy-scan.sh <sarif-dir>}")"
cd "$(git rev-parse --show-toplevel)"
mkdir -p "$out" "${TRIVY_CACHE:=$HOME/.cache/trivy}"
images="$(mktemp -d)"
trap 'rm -rf "$images"' EXIT

trivy() {
  docker run --rm --user "$(id -u):$(id -g)" -e TRIVY_CACHE_DIR=/cache -v "$TRIVY_CACHE:/cache" \
    -v "$PWD:/repo:ro" -v "$out:/out" -v "$images:/images:ro" -w /repo "$TRIVY_IMAGE" --quiet "$@"
}

echo "== repo"
trivy fs --scanners vuln,misconfig,secret --severity HIGH,CRITICAL --format sarif --output /out/repo.sarif .

targets=(deploy/postgres)
for dockerfile in apps/*/Dockerfile; do targets+=("$(dirname "$dockerfile")"); done
for dir in "${targets[@]}"; do
  name="$(basename "$dir")"
  echo "== image $name"
  docker build -q -t "scan/$name" "$dir" > /dev/null
  docker save "scan/$name" -o "$images/$name.tar"
  trivy image --input "/images/$name.tar" --severity HIGH,CRITICAL --ignore-unfixed \
    --format sarif --output "/out/image-$name.sarif"
done

# Code scanning needs one category per SARIF run: name each after its file.
for sarif in "$out"/*.sarif; do
  category="trivy-$(basename "$sarif" .sarif)/"
  jq --arg id "$category" '.runs[0].automationDetails.id = $id' "$sarif" > "$images/sarif.tmp"
  cat "$images/sarif.tmp" > "$sarif"
done
