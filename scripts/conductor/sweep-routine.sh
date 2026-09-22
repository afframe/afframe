#!/usr/bin/env bash
# Archives earlier "Session update #N" routine workspaces older than 10 minutes.
# Runs inside a Conductor cloud workspace. Needs CONDUCTOR_API_KEY in the environment.
set -euo pipefail

API="https://api.conductor.build/v0"
AUTH="Authorization: Bearer ${CONDUCTOR_API_KEY:?CONDUCTOR_API_KEY not set}"
CUTOFF="$(date -u -d '-10 min' +%FT%TZ)"

curl -fsS "$API/workspaces?state=ready,sleeping&limit=100" -H "$AUTH" \
  | jq -r --arg c "$CUTOFF" '.data[] | select(.name | startswith("Session update #")) | select(.createdAt < $c) | .id' \
  | while read -r id; do
      curl -fsS -o /dev/null -X POST "$API/workspaces/$id/archive" -H "$AUTH"
    done
