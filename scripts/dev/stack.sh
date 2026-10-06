#!/usr/bin/env bash
# Usage: stack.sh up | down
# up prints DATABASE_URL=<url>. Postgres takes $CONDUCTOR_PORT + 1.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# The workspace path, not CONDUCTOR_WORKSPACE_NAME: a renamed workspace keeps its project.
# The checksum keeps two paths apart that map to the same name, such as foo_bar and foo-bar.
path="${CONDUCTOR_WORKSPACE_PATH:-$PWD}"
workspace="$(basename "$path" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-')"
project="afframe-dev-$workspace-$(printf '%s' "$path" | cksum | cut -d' ' -f1)"
compose=(docker compose -p "$project" -f compose.dev.yml)

case "${1:-}" in
  up)
    # $CONDUCTOR_PORT itself stays free for the app dev server on the Mac.
    export DB_PORT="$((${CONDUCTOR_PORT:?CONDUCTOR_PORT is not set (local Conductor workspaces only)} + 1))"
    "${compose[@]}" up -d --build --wait
    # shellcheck disable=SC2016 # The container shell expands them.
    "${compose[@]}" exec -T postgres sh -c \
      'echo "DATABASE_URL=postgres://$POSTGRES_USER@localhost:$1/$POSTGRES_DB"' sh "$DB_PORT"
    ;;
  down)
    # Compose interpolates the file before down.
    DB_PORT=0 exec "${compose[@]}" down -v --rmi local
    ;;
  *)
    echo "usage: $0 up | down" >&2
    exit 2
    ;;
esac
