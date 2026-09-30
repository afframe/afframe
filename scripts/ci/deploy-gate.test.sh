#!/usr/bin/env bash
# Tests for deploy-gate.sh with a fake `gh` on PATH. Run: bash scripts/ci/deploy-gate.test.sh
set -uo pipefail

gate="$(cd "$(dirname "$0")" && pwd)/deploy-gate.sh"
fake="$(mktemp -d)"
trap 'rm -rf "$fake"' EXIT
failures=0

# Fake gh: answers `gh api repos/<repo>/commits/<sha>[/pulls] --jq ...` from files in $fake,
# with the jq filter already applied. A <sha>.fail file makes every call for that sha fail.
mkdir -p "$fake/bin"
cat > "$fake/bin/gh" <<'EOF'
#!/usr/bin/env bash
path="$2"
sha="${path#*/commits/}"
sha="${sha%/pulls}"
[[ -e "$FAKE/$sha.fail" ]] && { echo "HTTP 502" >&2; exit 1; }
if [[ "$path" == */pulls ]]; then cat "$FAKE/$sha.pulls"; else cat "$FAKE/$sha.msg"; fi
EOF
chmod +x "$fake/bin/gh"

# commit <sha> <first line of message> [pulls output lines...]
commit() {
  local sha="$1" msg="$2"
  shift 2
  printf '%s\n' "$msg" > "$fake/$sha.msg"
  printf '%s' "" > "$fake/$sha.pulls"
  [[ $# -gt 0 ]] && printf '%s\n' "$@" > "$fake/$sha.pulls"
}

# expect <exit code> <stdout> <name> <sha>...
expect() {
  local want_code="$1" want_out="$2" name="$3" out code=0
  shift 3
  out="$(FAKE="$fake" PATH="$fake/bin:$PATH" GITHUB_REPOSITORY=o/r bash "$gate" "$@" 2> /dev/null)" || code=$?
  if [[ "$code" -ne "$want_code" || "$out" != "$want_out" ]]; then
    echo "FAIL: ${name} (expected exit ${want_code} '${want_out}', got ${code} '${out}')"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}

commit a1 "feat: add invoices (#12)" "title:feat: add invoices" "label:enhancement"
commit a2 "chore: bump deps (#13)" "title:chore: bump deps" "label:No-Deploy"
commit a3 "chore: bump deps (#14)" "title:chore: bump deps" "label:no-deploy-later"
commit a4 "chore: bump deps [no deploy] (#15)" "title:chore: bump deps [no deploy]"
commit a5 "fix: typo [No Deploy] (#16)" "title:fix: typo"
commit a6 "docs: explain no deploy switch (#17)" "title:docs: explain no deploy switch"
commit a7 "chore: direct push without a PR"
commit a8 "feat: b (#18)" "title:feat: b"
touch "$fake/a8.fail"

expect 0 "deploy=true" "ordinary PR deploys" a1
expect 0 "deploy=false" "no-deploy label skips, case-insensitive" a2
expect 0 "deploy=true" "similar label deploys" a3
expect 0 "deploy=false" "tag in PR title skips" a4
expect 0 "deploy=false" "tag in commit message skips" a5
expect 0 "deploy=true" "words without brackets deploy" a6
expect 0 "deploy=false" "one tagged commit in a batch skips" a1 a4
expect 3 "" "commit without a PR fails closed" a7
expect 1 "" "API error fails closed" a8
expect 1 "" "API error in a batch fails closed" a1 a8
expect 2 "" "no commits fails closed"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all deploy-gate tests passed"
