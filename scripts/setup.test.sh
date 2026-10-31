#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0
export FAKE="$work/fake" TMPDIR="$work/tmp"
mkdir -p "$FAKE/bin" "$TMPDIR" "$work/repo/scripts"
cp "$root/scripts/setup.sh" "$work/repo/scripts/setup.sh"
git -C "$work/repo" init -q
printf '{"packageManager": "pnpm@10.4.1+sha512.abcdef"}\n' > "$work/repo/package.json"

# $FAKE/pnpm-version and $FAKE/corepack-version: what `--version` prints, or no answer.
# $FAKE/install-fail: `install` fails.
# The CI toolbox has no node. The fake answers only the packageManager parse of setup.sh, with sed,
# so the real parse is checked only where node exists.
if ! command -v node > /dev/null; then
  cat > "$FAKE/bin/node" <<'FAKENODE'
#!/usr/bin/env bash
sed -n 's/.*"packageManager": *"pnpm@\([^+"]*\).*/\1/p' package.json
FAKENODE
  chmod +x "$FAKE/bin/node"
fi
cat > "$FAKE/bin/pnpm" <<'FAKEPNPM'
#!/usr/bin/env bash
if [[ "$1" == --version ]]; then cat "$FAKE/pnpm-version"; exit; fi
echo "pnpm $*" >> "$FAKE/calls"
[[ "$1" != install || ! -e "$FAKE/install-fail" ]]
FAKEPNPM
cat > "$FAKE/bin/corepack" <<'FAKECOREPACK'
#!/usr/bin/env bash
if [[ "$*" == "pnpm --version" ]]; then cat "$FAKE/corepack-version"; exit; fi
echo "corepack $*" >> "$FAKE/calls"
[[ "$2" != install || ! -e "$FAKE/install-fail" ]]
FAKECOREPACK
cat > "$FAKE/bin/npx" <<'FAKENPX'
#!/usr/bin/env bash
echo "npx $*" >> "$FAKE/calls"
[[ "$4" != install || ! -e "$FAKE/install-fail" ]]
FAKENPX
cat > "$FAKE/bin/sudo" <<'FAKESUDO'
#!/usr/bin/env bash
shift
exec "$@"
FAKESUDO
chmod +x "$FAKE/bin/"*

check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
# setup <env VAR=value>... -- <setup.sh argument>...: stdout in $FAKE/out, the exit code in $code.
setup() {
  local envs=()
  while [[ "$1" != -- ]]; do envs+=("$1"); shift; done
  shift
  : > "$FAKE/calls"
  code=0
  env -u CLAUDE_CODE_REMOTE -u CONDUCTOR_IS_LOCAL ${envs[@]+"${envs[@]}"} PATH="$FAKE/bin:$PATH" \
    bash "$work/repo/scripts/setup.sh" "$@" > "$FAKE/out" 2> "$FAKE/err" < /dev/null || code=$?
}
called() { grep -qxF -- "$1" "$FAKE/calls"; }
no_calls() { [[ ! -s "$FAKE/calls" ]]; }
no_output() { [[ ! -s "$FAKE/out" && ! -s "$FAKE/err" ]]; }
one_line() { [[ "$(wc -l < "$FAKE/out")" -eq 1 ]]; }
printed() { grep -qF -- "$1" "$FAKE/out"; }
exit_is() { [[ "$code" -eq "$1" ]]; }

echo 10.4.1 > "$FAKE/pnpm-version"
echo 9.0.0 > "$FAKE/corepack-version"

setup -- --hook
check "--hook outside the cloud exits 0" exit_is 0
check "and prints nothing" no_output
check "and runs no install" no_calls

setup CLAUDE_CODE_REMOTE=true -- --hook
check "--hook in the cloud exits 0" exit_is 0
check "and prints one summary line" one_line
check "and the line says ok with the log path" printed "setup: ok (log: $TMPDIR/afframe-setup.log)"
check "pnpm installs with the frozen lockfile" called "pnpm install --frozen-lockfile"
check "CodeGraph is initialised and synced" called "pnpm exec codegraph sync ."

touch "$FAKE/install-fail"
setup CLAUDE_CODE_REMOTE=true -- --hook
check "--hook in the cloud with a failing install exits 0" exit_is 0
check "and prints one line" one_line
check "and the line names the failure" printed "setup: pnpm install failed (log: "
check "and the log holds the error" grep -qF "ERROR: pnpm install failed" "$TMPDIR/afframe-setup.log"

setup CONDUCTOR_IS_LOCAL=0 --
check "a Conductor cloud workspace with a failing install exits 0" exit_is 0
setup --
check "a local run with a failing install exits 1" exit_is 1
check "and prints the error on stderr" grep -qF "ERROR: pnpm install failed" "$FAKE/err"
check "and prints nothing on stdout" fails test -s "$FAKE/out"
rm "$FAKE/install-fail"

setup --
check "a local run succeeds" exit_is 0
check "and strips the sha512 suffix: the pinned pnpm is used" called "pnpm install --frozen-lockfile"
check "and does not fall back to corepack" fails grep -q '^corepack' "$FAKE/calls"
check "and does not fall back to npx" fails grep -q '^npx' "$FAKE/calls"

echo 9.0.0 > "$FAKE/pnpm-version"
echo 10.4.1 > "$FAKE/corepack-version"
setup --
check "other pnpm version, matching corepack: corepack installs" called "corepack pnpm install --frozen-lockfile"
check "and pnpm does not run" fails grep -q '^pnpm' "$FAKE/calls"

echo 9.0.0 > "$FAKE/corepack-version"
setup --
check "no matching pnpm or corepack: npx installs the pinned version" \
  called "npx --yes pnpm@10.4.1 install --frozen-lockfile"
check "and exits 0" exit_is 0

rm "$FAKE/pnpm-version"
echo 10.4.1 > "$FAKE/corepack-version"
setup --
check "no pnpm on PATH: corepack installs" called "corepack pnpm install --frozen-lockfile"

if ((failures > 0)); then
  echo "${failures} setup check(s) failed"
  exit 1
fi
echo "all setup checks passed"
