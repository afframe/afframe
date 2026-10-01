#!/usr/bin/env bash
# Starts or removes this Conductor workspace's dev stack (compose.dev.yml).
# Usage: stack.sh up | down
# Each workspace gets its own compose project and ports: web on $CONDUCTOR_PORT, Postgres on +1.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

name="${CONDUCTOR_WORKSPACE_NAME:-$(basename "$PWD")}"
project="afframe-$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-')"
compose=(docker compose -p "$project" -f compose.dev.yml)

case "${1:-}" in
  up)
    port="${CONDUCTOR_PORT:?CONDUCTOR_PORT is not set (local Conductor workspaces only)}"
    export WEB_PORT="$port" DB_PORT="$((port + 1))"
    echo "web: http://localhost:${WEB_PORT}  postgres: postgres://afframe:afframe@localhost:${DB_PORT}/afframe"
    exec "${compose[@]}" up --build
    ;;
  down)
    # down needs no ports, but compose still interpolates the file.
    WEB_PORT=0 DB_PORT=0 exec "${compose[@]}" down -v --rmi local
    ;;
  *)
    echo "usage: $0 up | down" >&2
    exit 2
    ;;
esac
