#!/usr/bin/env bash
# Run from the workspace root. Never fails.
set -uo pipefail

# The daemon exits 300 s after its last client disconnects: this only stops it early.
# Both matches end at the workspace path, so a sibling such as `<workspace>-v2` is not hit.
workspace="${CONDUCTOR_WORKSPACE_PATH:-$PWD}"
for pid in $(pgrep -f 'codegraph\.js serve'); do
  case "$(ps -ww -o command= -p "$pid")" in
    *"--path $workspace" | *"--path $workspace "* | *"$workspace/node_modules/"*)
      kill "$pid" && echo "stopped CodeGraph daemon $pid" ;;
  esac
done
[[ ! -f compose.dev.yml ]] || bash scripts/dev/stack.sh down || echo "dev stack not removed"
exit 0
