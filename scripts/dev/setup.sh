#!/usr/bin/env bash
# Conductor setup: installs each app's dependencies on the host, picked by lockfile, so editor and
# Claude Code hooks (typecheck, prettier, ESLint) find them. The dev stack and CI build in Docker
# and never use these. A missing package manager prints one line and is skipped; no apps or no
# lockfiles is a silent no-op.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# install <app dir> <lockfile> <command...>
install() {
  local dir="$1" lockfile="$2"
  shift 2
  [[ -f "$dir/$lockfile" ]] || return 0
  if ! command -v "$1" > /dev/null; then
    echo "setup: ${dir%/}: $1 not found, skipped ($lockfile)"
    return 0
  fi
  echo "setup: ${dir%/}: $*"
  (cd "$dir" && "$@")
}

for dir in apps/*/; do
  [[ -d "$dir" ]] || continue
  install "$dir" pnpm-lock.yaml pnpm install --frozen-lockfile
  install "$dir" package-lock.json npm ci
  install "$dir" bun.lock bun install --frozen-lockfile
  install "$dir" uv.lock uv sync --frozen
  install "$dir" go.sum go mod download
  install "$dir" Cargo.lock cargo fetch --locked
done
