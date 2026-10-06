#!/usr/bin/env bash
# Fake `docker` on a scratch git repository.
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/build-images.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

mkdir -p "$tmp/bin" "$tmp/repo/apps/a" "$tmp/repo/apps/b" "$tmp/repo/deploy"
printf 'name: proj\n' > "$tmp/repo/deploy/compose.prod.yml"
printf '#!/usr/bin/env bash\necho "docker $*" | tee -a "%s/calls"\n' "$tmp" > "$tmp/bin/docker"
chmod +x "$tmp/bin/docker"
git -C "$tmp/repo" init -q
touch "$tmp/repo/apps/a/Dockerfile" "$tmp/repo/apps/b/Dockerfile"
git -C "$tmp/repo" add -A
git -C "$tmp/repo" -c user.email=test@example.org -c user.name=test commit -q -m "test: fixture"

expect() {
  if [[ "$3" == "$2" ]]; then echo "ok: $1"; else echo "FAIL: $1 (got '$3')"; failures=$((failures + 1)); fi
}
# label <service>: the afframe.tree label of a build of HEAD.
label() {
  (cd "$tmp/repo" && PATH="$tmp/bin:$PATH" bash "$script" t2 "$1" > /dev/null 2>&1)
  sed -n 's/.*--label afframe.tree=\([^ ]*\) .*/\1/p' "$tmp/calls" | tail -n 1
}
# change <path>...: commits a change to each path.
change() {
  local path
  for path in "$@"; do mkdir -p "$tmp/repo/$(dirname "$path")" && echo "$RANDOM" >> "$tmp/repo/$path"; done
  git -C "$tmp/repo" add -A && git -C "$tmp/repo" -c user.email=test@example.org -c user.name=test commit -q -m change
}

out="$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" ACTIONS_RUNTIME_TOKEN='' bash "$script" t1 a b 2> /dev/null)"
expect "stdout is one apps/<service>=<image> line per service" $'apps/a=proj/a:t1\napps/b=proj/b:t1' "$out"
calls="$(cat "$tmp/calls")"
expect "root context, the app's Dockerfile and the tag" yes \
  "$([[ "$calls" == *" -t proj/a:t1 -f apps/a/Dockerfile ."* ]] && echo yes)"
expect "no cache flags without the Actions runtime" yes "$([[ "$calls" != *type=gha* ]] && echo yes)"

a0="$(label a)"
expect "label without packages/ or root workspace files is set" yes "$([[ ${#a0} -eq 40 ]] && echo yes)"
expect "apps differ in their label" yes "$([[ "$(label b)" != "$a0" ]] && echo yes)"
change README.md apps/b/src
expect "docs or another app keep the label" "$a0" "$(label a)"
change apps/a/src
a1="$(label a)"
expect "the app's own change gives a new label" yes "$([[ "$a1" != "$a0" ]] && echo yes)"
prev="$a1"
# The root inputs of the real .dockerignore: each one must change the result.
inputs="$(sed -n 's/^!//p' "$(dirname "$script")/../../.dockerignore" \
  | grep -vx apps | sed 's|^packages$|packages/ui/src|')"
# shellcheck disable=SC2086 # one path per word
for path in $inputs .dockerignore; do
  change "$path"
  now="$(label a)"
  expect "a change to $path gives a new label" yes "$([[ "$now" != "$prev" ]] && echo yes)"
  prev="$now"
done
expect "same commit, same label" "$prev" "$(label a)"
(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" bash "$script" t1 c > /dev/null 2>&1)
expect "unknown service fails before a build" "1 no" "$? $(grep -q 'proj/c' "$tmp/calls" && echo yes || echo no)"
(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" bash "$script" t1 > /dev/null 2>&1)
expect "no service is a usage error" 2 "$?"
: > "$tmp/repo/deploy/compose.prod.yml"
(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" bash "$script" t1 a > /dev/null 2>&1)
expect "no compose project name fails" 2 "$?"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all build-images tests passed"
