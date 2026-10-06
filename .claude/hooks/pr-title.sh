#!/usr/bin/env bash
# Input: the Claude Code tool call as JSON on stdin.
# Exit 2 blocks the call and shows stderr to the agent.
# The pr-title check is the gate, so on doubt exit 0.
set -euo pipefail

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<< "$input")"

if [[ "$tool" == Bash ]]; then
  command="$(jq -r '.tool_input.command // empty' <<< "$input")"
  nl=$'\n'
  q="'"
  start="(^|[;&|({!\`$nl])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*"
  start+="(command[[:space:]]+)?gh[[:space:]]+pr[[:space:]]+(create|edit|merge)([[:space:]]|\$)"
  [[ "$command" =~ $start ]] || exit 0
  action="${BASH_REMATCH[4]}"
  rest="${command#*"${BASH_REMATCH[0]}"}"
  # Keep only this gh call: stop at the first separator outside quotes.
  segment="^([^;&|\"$q$nl]|\"[^\"]*\"|${q}[^${q}]*${q})*"
  [[ "$rest" =~ $segment ]] || exit 0
  rest="${BASH_REMATCH[0]}"
  # gh pr merge --subject sets the squash commit subject.
  if [[ "$action" == merge ]]; then flag='--subject|-t'; else flag='--title|-t'; fi
  value="[[:space:]]($flag)[=[:space:]]+(\"[^\"]*\"|${q}[^${q}]*${q}|[^[:space:]\"$q]+)"
  if [[ " $rest" =~ $value ]]; then
    title="${BASH_REMATCH[2]}"
    # An odd quote count before the flag means it sits inside another argument.
    before="${rest%%"${BASH_REMATCH[0]# }"*}"
    dq="${before//[^\"]/}"
    sq="${before//[^\']/}"
    (( ${#dq} % 2 == 0 && ${#sq} % 2 == 0 )) || exit 0
    [[ "$title" != *[\$\`]* ]] || exit 0
    title="${title#[\"\']}"
    title="${title%[\"\']}"
  elif [[ "$action" == create ]]; then
    echo "Pass the PR title with --title as a quoted string, so scripts/ci/pr-title.sh can check it." >&2
    exit 2
  else
    exit 0
  fi
else
  # GitHub MCP tools: an update without a title keeps the old one.
  # A merge without commit_title uses the PR title.
  title="$(jq -r '.tool_input.title // .tool_input.commit_title // empty' <<< "$input")"
  [[ -n "$title" ]] || exit 0
fi

bash "$(dirname "$0")/../../scripts/ci/pr-title.sh" "$title" > /dev/null || exit 2
