#!/usr/bin/env bash
# Runs on a scratch git repository. The fake gh serves page 2 of the list only to --paginate.
set -uo pipefail
command -v jq > /dev/null || { echo "skip: needs jq"; exit 77; }

script="$(cd "$(dirname "$0")" && pwd)/rulesets.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
repo="$work/repo" fake="$work/fake"
failures=0

mkdir -p "$repo/.github/rulesets" "$fake/bin"
git -C "$repo" init -q
printf '%s\n' '{"name": "main", "target": "branch", "enforcement": "active", "rules": [{"type": "deletion"}]}' \
  > "$repo/.github/rulesets/main.json"
printf '%s\n' '{"name": "tags", "target": "tag", "enforcement": "active", "rules": []}' \
  > "$repo/.github/rulesets/tags.json"

cat > "$fake/bin/gh" <<'FAKEGH'
#!/usr/bin/env bash
echo "gh $*" >> "$FAKE/calls"
shift # api
method=GET filter=. paginate=no path=""
while (($#)); do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    --jq) filter="$2"; shift 2 ;;
    --input) shift 2 ;;
    --paginate) paginate=yes; shift ;;
    *) path="$1"; shift ;;
  esac
done
[[ "$method" == GET ]] || exit 0
case "$path" in
  */rulesets\?*)
    jq -r "$filter" "$FAKE/page1.json"
    [[ "$paginate" == no ]] || jq -r "$filter" "$FAKE/page2.json"
    ;;
  */rulesets/*) jq -r "$filter" "$FAKE/ruleset-${path##*/}.json" ;;
esac
FAKEGH
chmod +x "$fake/bin/gh"

# live <id> <ruleset file> [<jq update>]: the API form, with fields the comparison ignores.
live() {
  jq "{id: $1, source: \"o/r\", conditions: null, bypass_actors: null} + . ${3:+| $3}" "$repo/.github/rulesets/$2" \
    > "$fake/ruleset-$1.json"
}
reset_live() {
  printf '%s\n' '[{"id": 1, "name": "main"}]' > "$fake/page1.json"
  printf '%s\n' '[{"id": 2, "name": "tags"}]' > "$fake/page2.json"
  live 1 main.json
  live 2 tags.json
  : > "$fake/calls"
}
# expect <exit code> <output pattern> <name> <args>...
expect() {
  local want_code="$1" pattern="$2" name="$3" out code=0
  shift 3
  out="$(cd "$repo" && FAKE="$fake" GH_REPO=o/r PATH="$fake/bin:$PATH" bash "$script" "$@" 2>&1)" || code=$?
  if [[ "$code" -ne "$want_code" || "$out" != *"$pattern"* ]]; then
    echo "FAIL: ${name} (expected exit ${want_code} with '${pattern}', got ${code}: ${out})"
    failures=$((failures + 1))
  else
    echo "ok: ${name}"
  fi
}
called() {
  if grep -q -- "$2" "$fake/calls"; then echo "ok: $1"; else echo "FAIL: $1"; failures=$((failures + 1)); fi
}

reset_live
expect 0 "no drift: main" "a ruleset equal to the live one has no drift"
expect 0 "no drift: tags" "a ruleset on the second page of the list is found"
called "the list asks for 100 rulesets a page" \
  "--paginate repos/{owner}/{repo}/rulesets?includes_parents=false&per_page=100"

live 2 tags.json '.enforcement = "disabled"'
expect 1 '"disabled"' "a changed live ruleset is drift"

reset_live
printf '%s\n' '[]' > "$fake/page2.json"
expect 1 "missing: tags" "a ruleset absent on GitHub is drift"

expect 0 "applied: tags" "apply" apply
called "apply updates an existing ruleset by its id" \
  "-X PUT repos/{owner}/{repo}/rulesets/1 --input .github/rulesets/main.json"
called "apply creates a missing ruleset" "-X POST repos/{owner}/{repo}/rulesets --input .github/rulesets/tags.json"

out="$(cd "$repo" && env -u GH_REPO PATH="$fake/bin:$PATH" bash "$script" 2>&1)"
code=$?
if [[ "$code" -ne 0 && "$out" == *"set GH_REPO"* ]]; then
  echo "ok: no GH_REPO fails"
else
  echo "FAIL: no GH_REPO fails (got ${code}: ${out})"
  failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all rulesets tests passed"
