#!/usr/bin/env bash
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/image-scan.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
export FAKE="$tmp/fake"
mkdir -p "$FAKE/bin"

# Scratch repository: image-scan.sh reads scripts/ci/trivy/Dockerfile of the repository it runs in.
repo="$tmp/repo"
mkdir -p "$repo/scripts/ci/trivy"
git -C "$repo" init -q
printf '# comment\nFROM aquasec/trivy:test@sha256:abc\n' > "$repo/scripts/ci/trivy/Dockerfile"

# The fake docker logs every call. $FAKE/local lists the images that exist, $FAKE/pull-fail the
# images that cannot be pulled. `save` writes the image name. `run` fails for a stream with "bad".
cat > "$FAKE/bin/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls"
case "$1" in
  image) grep -qxF -- "$3" "$FAKE/local" ;;
  pull) ! grep -qxF -- "$3" "$FAKE/pull-fail" ;;
  save) echo "$2" ;;
  run) ! grep -q bad ;;
esac
FAKEDOCKER
chmod +x "$FAKE/bin/docker"

# scan <script argument>...: output in $FAKE/out, calls in $FAKE/calls.
scan() {
  : > "$FAKE/calls"
  (cd "$repo" && PATH="$FAKE/bin:$PATH" bash "$script" "$@" > "$FAKE/out" 2>&1)
}
check() {
  local name="$1"
  shift
  if "$@"; then echo "ok: $name"; else echo "FAIL: $name"; failures=$((failures + 1)); fi
}
fails() { ! "$@"; }
called() { grep -qE -- "$1" "$FAKE/calls"; }
printed() { grep -qF -- "$1" "$FAKE/out"; }
runs() { grep -c '^docker run ' "$FAKE/calls"; }

printf '%s\n' bad:1 good:1 > "$FAKE/local"
: > "$FAKE/pull-fail"
check "a failing scan fails the job" fails scan HIGH,CRITICAL web=bad:1 good:1
check "the next image is still scanned" test "$(runs)" -eq 2
check "the job log names the failed scan" printed "web=bad:1: scan failed or found CVEs at HIGH,CRITICAL"
check "the Trivy image is the FROM line of its Dockerfile" called "docker run .* aquasec/trivy:test@sha256:abc -c "
check "the scan ignores unfixed CVEs" called "--ignore-unfixed"
check "the scan gets the given severities" called " sh HIGH,CRITICAL$"
check "the scanner gets the image on stdin" called "docker run --rm -i "
check "the scanner gets no Docker socket" fails called "docker\.sock| -v |--volume|--mount"
check "a local image is not pulled" fails called "docker pull"

printf '%s\n' nope:1 > "$FAKE/pull-fail"
check "an image that cannot be pulled fails the job" fails scan HIGH web=nope:1
check "the job log says the pull failed" printed "web=nope:1: pull failed"
check "the pull targets the image, not the label" called "docker pull -q nope:1"
check "nothing is scanned for it" test "$(runs)" -eq 0
: > "$FAKE/pull-fail"

check "a scan of good images passes" scan HIGH good:1
check "a missing severity is a usage error" fails scan
check "and the usage names the arguments" printed "usage: image-scan.sh <severities>"
check "and ran no docker command" test ! -s "$FAKE/calls"

printf '# no base image\n' > "$repo/scripts/ci/trivy/Dockerfile"
check "a Trivy Dockerfile without a FROM line fails" fails scan HIGH good:1
check "and says it needs one" printed "needs one FROM line"
check "and ran no docker command" test ! -s "$FAKE/calls"
printf 'FROM a:1\nFROM b:2\n' > "$repo/scripts/ci/trivy/Dockerfile"
check "a Trivy Dockerfile with two FROM lines fails" fails scan HIGH good:1
check "and says it needs one" printed "needs one FROM line"

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} test(s) failed"
  exit 1
fi
echo "all image-scan tests passed"
