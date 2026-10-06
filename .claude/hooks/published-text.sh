#!/usr/bin/env bash
# Input: the Claude Code tool call as JSON on stdin.
# Output: PreToolUse additionalContext and no decision, so the call always runs.
set -euo pipefail

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<< "$input")"
if [[ "$tool" == Bash ]]; then
  command="$(jq -r '.tool_input.command // empty' <<< "$input")"
  ws='[[:space:]]+'
  git="git(${ws}-C${ws}[^[:space:]]+)?${ws}commit"
  gh="gh${ws}(pr${ws}(create|edit|comment|review|merge)|issue${ws}(create|edit|comment)|release${ws}(create|edit))"
  publish="(^|[;&|({[:space:]])($git|$gh)([[:space:]]|\$)"
  [[ "$command" =~ $publish ]] || exit 0
else
  # The settings matcher sends every GitHub MCP tool. Only these tools publish text.
  writes='merge_pull_request|push_files|create_or_update_file|delete_file|create_pull_request|update_pull_request'
  writes+='|issue_write|add_issue_comment|update_issue_comment|discussion_comment_write'
  writes+='|add_reply_to_pull_request_comment|add_comment_to_pending_review|pull_request_review_write'
  [[ "$tool" =~ __($writes)$ ]] || exit 0
fi

msg='This text is public. Check it against "All files" and "Published text" in AGENTS.md.'
msg+=' It holds no private facts, no credential names and no banned words.'
msg+=' If it breaks a rule, fix the text before it reaches main.'
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${msg//\"/\\\"}"
