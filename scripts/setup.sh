#!/usr/bin/env bash
# Usage: bash scripts/setup.sh [--hook]   (--hook: Claude Code SessionStart, acts only in cloud)
# Exits 1 on a failed install, except with --hook or in a Conductor or Claude Code cloud session.
set -uo pipefail

hook=false cloud=false
if [[ "${1:-}" == "--hook" ]]; then
  [[ "${CLAUDE_CODE_REMOTE:-}" == "true" ]] || exit 0
  hook=true
  log="${TMPDIR:-/tmp}"
  log="${log%/}/afframe-setup.log"
  # Hook stdout goes into the model context: keep it for the one summary line.
  exec 3>&1
  exec > "$log" 2>&1 || { log=/dev/null; exec > /dev/null 2>&1; }
fi
[[ "${CONDUCTOR_IS_LOCAL:-}" == "0" || "${CLAUDE_CODE_REMOTE:-}" == "true" ]] && cloud=true

finish() {
  if $hook; then echo "setup: $1 (log: $log)" >&3; fi
  exit "$2"
}

fail() {
  echo "ERROR: $1" >&2
  if $hook || $cloud; then finish "$1" 0; fi
  finish "$1" 1
}

cd "$(dirname "$0")" || fail "no repository root"
cd "$(git rev-parse --show-toplevel 2> /dev/null || echo ..)" || fail "no repository root"
command -v node > /dev/null || fail "node is not installed"
version="$(node -p 'require("./package.json").packageManager.replace(/^pnpm@/, "").replace(/\+.*/, "")')" \
  || fail "no pnpm version in package.json"

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0 CODEGRAPH_TELEMETRY=0
as_root() { if [[ "$(id -u)" == 0 ]]; then "$@"; else sudo -n "$@"; fi; }

# Best effort: minimal cloud images can lack the tools that scripts/ci/local-gate.sh needs.
missing=()
command -v cmp > /dev/null || missing+=(diffutils)
command -v flock > /dev/null || missing+=(util-linux)
command -v jq > /dev/null || missing+=(jq)
if $cloud && [[ "${#missing[@]}" -gt 0 ]]; then
  if command -v dnf > /dev/null; then
    as_root dnf install -y -q "${missing[@]}"
  elif command -v apt-get > /dev/null; then
    as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq \
      && as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
  else
    false
  fi || echo "WARN: could not install ${missing[*]}. The local gate skips the tests that need them." >&2
fi

pinned() { [[ "$(pnpm --version 2> /dev/null)" == "$version" ]]; }
# The codegraph MCP server in .mcp.json calls a bare pnpm.
if $cloud && ! pinned; then
  if command -v corepack > /dev/null; then
    as_root env PATH="$PATH" corepack enable pnpm
  else
    as_root env PATH="$PATH" npm install -g "pnpm@$version"
  fi
  hash -r
  pinned || echo "WARN: pnpm $version is not on PATH. The codegraph MCP server cannot start." >&2
fi
if pinned; then
  pnpm=(pnpm)
elif [[ "$(corepack pnpm --version 2> /dev/null)" == "$version" ]]; then
  pnpm=(corepack pnpm)
else
  pnpm=(npx --yes "pnpm@$version")
fi

"${pnpm[@]}" install --frozen-lockfile || fail "pnpm install failed"
# init exits 0 on a built index and rebuilds an index that an interrupted run left without a schema.
if "${pnpm[@]}" exec codegraph init --yes . && "${pnpm[@]}" exec codegraph sync .; then
  finish ok 0
fi
echo "WARN: CodeGraph index not synced. Run 'bash scripts/setup.sh' again." >&2
finish "CodeGraph index not synced" 0
