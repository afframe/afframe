#!/usr/bin/env bash
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }

hook="$(dirname "$0")/published-text.sh"
failures=0

# expect <name> <reminds|silent> <tool name> <tool input as JSON>
expect() {
  local name="$1" want="$2" out code=0 got=silent
  out="$(jq -n --arg tool "$3" --argjson in "$4" '{tool_name: $tool, tool_input: $in}' | "$BASH" "$hook")" || code=$?
  if [[ -n "$out" ]]; then
    jq -e '.hookSpecificOutput.additionalContext and (.hookSpecificOutput | has("permissionDecision") | not)' \
      <<< "$out" > /dev/null 2>&1 && got=reminds || got=bad-json
  fi
  if [[ "$code" -ne 0 || "$got" != "$want" ]]; then
    echo "FAIL: ${name} (expected ${want}, got ${got}, exit ${code})"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}

bash_call() { jq -n --arg c "$1" '{command: $c}'; }

expect "git commit" reminds Bash "$(bash_call 'git commit -m "docs: fix a link"')"
expect "git -C commit after cd" reminds Bash "$(bash_call 'cd x && git -C repo commit -m x -- a')"
expect "gh pr create" reminds Bash "$(bash_call 'gh pr create --title "feat: x" --body y')"
expect "gh pr merge" reminds Bash "$(bash_call 'gh pr merge 5 --squash')"
expect "gh issue comment" reminds Bash "$(bash_call 'gh issue comment 3 --body x')"
expect "gh release create" reminds Bash "$(bash_call 'gh release create v1 --notes x')"
expect "git status" silent Bash "$(bash_call 'git status --porcelain')"
expect "gh pr view" silent Bash "$(bash_call 'gh pr view 5')"
expect "commit inside a word" silent Bash "$(bash_call 'echo legit commit')"
expect "GitHub MCP write" reminds mcp__github__create_pull_request '{"title": "feat: x"}'
expect "GitHub MCP comment" reminds mcp__claude_ai_github__add_issue_comment '{"body": "x"}'
expect "GitHub MCP push" reminds mcp__github__push_files '{"message": "fix: x"}'
expect "GitHub MCP merge" reminds mcp__github__merge_pull_request '{"pullNumber": 5}'
expect "GitHub MCP delete" reminds mcp__github__delete_file '{"message": "chore: x"}'
expect "GitHub MCP comment edit" reminds mcp__github__update_issue_comment '{"body": "x"}'
expect "GitHub MCP discussion" reminds mcp__github__discussion_comment_write '{"body": "x"}'
expect "GitHub MCP read" silent mcp__github__get_pull_request '{"pullNumber": 5}'
expect "GitHub MCP search" silent mcp__claude_ai_github__search_issues '{"query": "x"}'

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all published-text hook tests passed"
