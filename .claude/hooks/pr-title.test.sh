#!/usr/bin/env bash
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }

hook="$(dirname "$0")/pr-title.sh"
failures=0

# expect <name> <exit code> <tool name> <tool input as JSON>
expect() {
  local name="$1" want="$2" got=0
  jq -n --arg tool "$3" --argjson in "$4" '{tool_name: $tool, tool_input: $in}' \
    | "$BASH" "$hook" > /dev/null 2>&1 || got=$?
  if [[ "$got" -ne "$want" ]]; then
    echo "FAIL: ${name} (expected exit ${want}, got ${got})"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}

bash_call() { jq -n --arg c "$1" '{command: $c}'; }

expect "good double-quoted title" 0 Bash "$(bash_call 'gh pr create --title "feat: add invoices" --body x')"
expect "good single-quoted title" 0 Bash "$(bash_call "gh pr create -t 'fix(api): handle empty body'")"
expect "good title after cd" 0 Bash "$(bash_call 'cd repo && gh pr create --title="docs: fix a link"')"
expect "bad title" 2 Bash "$(bash_call 'gh pr create --title "Add invoices" --body x')"
expect "bad title on edit" 2 Bash "$(bash_call 'gh pr edit 5 --title "update stuff"')"
expect "bad bare title" 2 Bash "$(bash_call 'gh pr create --title WIP')"
expect "create without a title" 2 Bash "$(bash_call 'gh pr create --fill')"
expect "edit without a title" 0 Bash "$(bash_call 'gh pr edit 5 --add-label claude-review')"
expect "other gh pr command" 0 Bash "$(bash_call 'gh pr view 5')"
expect "gh pr create inside a commit message" 0 Bash "$(bash_call 'git commit -m "run gh pr create later"')"
expect "MCP good title" 0 mcp__github__create_pull_request '{"title": "feat: add invoices"}'
expect "MCP bad title" 2 mcp__github__create_pull_request '{"title": "Add invoices"}'
expect "MCP update without a title" 0 mcp__github__update_pull_request '{"body": "x"}'
expect "bad title after a newline" 2 Bash "$(bash_call $'git push\ngh pr create --title "Add invoices"')"
expect "bad title in a brace group" 2 Bash "$(bash_call '{ gh pr create --title "Add invoices"; }')"
expect "bad title with an env prefix" 2 Bash "$(bash_call 'GH_REPO=a/b gh pr create --title "Add invoices"')"
expect "bad title after command" 2 Bash "$(bash_call 'command gh pr edit 5 -t "update stuff"')"
expect "title from a variable" 0 Bash "$(bash_call "gh pr create --title \"\$TITLE\" --body x")"
expect "title from a heredoc" 0 Bash \
  "$(bash_call $'gh pr create --title "$(cat <<\'EOF\'\nAdd invoices\nEOF\n)" --body x')"
expect "-t of an earlier command" 0 Bash \
  "$(bash_call 'docker run -t "img" && gh pr create --title "feat: add invoices"')"
expect "-t of a later command" 0 Bash "$(bash_call 'gh pr edit 5 --add-label x && docker run -t "img"')"
expect "-t inside another argument" 0 Bash "$(bash_call 'gh pr edit 5 --body "run docker run -t img"')"
expect "merge bad subject" 2 Bash "$(bash_call 'gh pr merge 5 --squash --subject "Add invoices"')"
expect "merge good subject" 0 Bash "$(bash_call 'gh pr merge 5 --squash -t "feat: add invoices"')"
expect "merge without a subject" 0 Bash "$(bash_call 'gh pr merge 5 --squash')"
expect "MCP merge bad commit_title" 2 mcp__github__merge_pull_request '{"commit_title": "Add invoices"}'
expect "MCP merge without commit_title" 0 mcp__github__merge_pull_request '{"merge_method": "squash"}'

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all pr-title hook tests passed"
