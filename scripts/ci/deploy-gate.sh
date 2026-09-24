#!/usr/bin/env bash
# Decides whether a push to main may deploy. Reads lines on stdin:
#   label:<name>   title:<pr title>   message:<commit message>
# Exits 1 when any label is `no-deploy` or any title/message contains `[no deploy]`
# (case-insensitive). Railway's Wait for CI skips a deploy when a workflow fails.
set -euo pipefail

reason=""
while IFS= read -r line; do
  kind="${line%%:*}"
  value="${line#*:}"
  lower="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  case "$kind" in
    label)
      [[ "$lower" == "no-deploy" ]] && reason="label no-deploy"
      ;;
    title | message)
      [[ "$lower" == *"[no deploy]"* ]] && reason="[no deploy] in $kind: $value"
      ;;
  esac
done

if [[ -n "$reason" ]]; then
  echo "Deploy skipped on purpose (${reason}). The next merge without the switch deploys everything."
  exit 1
fi
echo "Deploy allowed."
