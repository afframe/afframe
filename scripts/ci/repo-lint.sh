#!/usr/bin/env bash
# Runs in the toolbox image.
# Needs a Docker daemon, local or remote: the checkout goes into the container through stdin.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ -z "${AFFRAME_TOOLBOX:-}" ]]; then
  # Host side, also macOS bash 3.2: no mapfile, no empty arrays.
  image="$(docker build -q -t afframe-toolbox - < scripts/ci/toolbox/Dockerfile)"
  # .git as the checkout sees it: shared objects and refs, its own HEAD and index (in a worktree
  # those live apart), as symlinks that tar -h follows.
  links="$(mktemp -d)"
  trap 'rm -rf "$links"' EXIT
  mkdir "$links/.git"
  common="$(git rev-parse --path-format=absolute --git-common-dir)" own="$(git rev-parse --absolute-git-dir)"
  for path in "$common"/{objects,refs,packed-refs,shallow} "$own"/{HEAD,index}; do
    [[ ! -e "$path" ]] || ln -s "$path" "$links/.git/"
  done
  # No macOS metadata (._ files, xattrs).
  export COPYFILE_DISABLE=1
  {
    git ls-files -z --cached --others --exclude-standard | while IFS= read -r -d '' file; do
      [[ ! -e "$file" && ! -L "$file" ]] || printf '%s\0' "$file"
    done | tar --no-xattrs --null -T - -cf -
    tar --no-xattrs -C "$links" -chf - .git
  } | docker run --rm -i -e CI "$image" bash -c \
    'cd "$(mktemp -d)" && git init -q && tar -xif - && exec bash scripts/ci/repo-lint.sh'
  exit 0
fi

check_actionlint() {
  # actionlint does not know the ubuntu-26.04 runner label yet.
  actionlint -color -ignore 'label "ubuntu-26.04" is unknown'
}

check_zizmor() {
  zizmor --offline --no-progress .github/workflows
}

# Standalone docker-compose: the toolbox has no docker CLI.
check_compose() {
  local compose_home prod_config rc=0
  compose_home="$(mktemp -d)"
  mkdir -p "$compose_home/env" && touch "$compose_home/env/infra.env"
  prod_config="$(AFFRAME_HOME="$compose_home" docker-compose -f deploy/compose.prod.yml config --format json)" \
    || prod_config='{}'
  jq -e '.services.postgres.volumes[]
      | select(.source == "postgres-data" and .target == "/var/lib/postgresql")' > /dev/null <<< "$prod_config" \
    || { echo "postgres must keep its data in the postgres-data volume" >&2; rc=1; }
  jq -e '.networks as $n | any(.services.postgres.networks | keys[]; $n[.].internal != true)' \
    > /dev/null <<< "$prod_config" \
    || { echo "postgres needs a network that is not internal, to reach the backup repository" >&2; rc=1; }
  jq -e '(.services.postgres.ports // []) == [] and .networks.db.internal == true' > /dev/null <<< "$prod_config" \
    || { echo "postgres must publish no ports, and the network db must stay internal" >&2; rc=1; }
  if [[ -f compose.ci.yml ]]; then docker-compose -f compose.ci.yml config -q || rc=1; fi
  DB_PORT=1 docker-compose -f compose.dev.yml config --format json \
    | jq -e --argjson prod "$(jq -c '[.volumes[]?.name]' <<< "$prod_config")" \
      '[.volumes[]?.name] as $dev | ($dev - $prod) == $dev' > /dev/null \
    || { echo "compose.dev.yml must not use a volume name of deploy/compose.prod.yml" >&2; rc=1; }
  rm -rf "$compose_home"
  return "$rc"
}

check_shellcheck() {
  local shell_scripts
  mapfile -t shell_scripts < <(git ls-files '*.sh' 'deploy/bin/*')
  [[ "${#shell_scripts[@]}" -eq 0 ]] && return 0
  shellcheck "${shell_scripts[@]}"
}

check_gitleaks() {
  gitleaks git --config .gitleaks.toml --no-banner --redact .
  if [[ -z "${CI:-}" ]]; then
    echo "uncommitted changes:"
    gitleaks git --config .gitleaks.toml --pre-commit --no-banner --redact .
  fi
}

# Markdown has no hard wraps and lockfiles are generated. A pin line (`@` and a SHA) may be longer.
check_line_length() {
  git ls-files -z '*.sh' 'deploy/bin/*' '*.yml' '*.yaml' '*Dockerfile*' ':!:*-lock.yaml' \
    | xargs -0 awk '/@(sha256:)?[0-9a-f]{40}/ {next}
      {max = /^[[:space:]]*#/ ? 100 : 120}
      length > max {printf "%s:%d: %d columns, at most %d\n", FILENAME, FNR, length, max; bad = 1}
      END {exit bad}'
}

checks=(actionlint zizmor compose shellcheck gitleaks line_length)

logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT

names=() pids=()
for name in "${checks[@]}"; do
  "check_$name" > "$logs/${#names[@]}.log" 2>&1 &
  names+=("$name") pids+=("$!")
done
while IFS= read -r test_script; do
  bash "$test_script" > "$logs/${#names[@]}.log" 2>&1 &
  names+=("$test_script") pids+=("$!")
done < <(git ls-files '*.test.sh')

failed=()
for i in "${!names[@]}"; do
  status=ok
  wait "${pids[$i]}" || { status=FAILED; failed+=("${names[$i]}"); }
  echo "::group::${names[$i]}: ${status}"
  cat "$logs/$i.log"
  echo "::endgroup::"
done

if [[ "${#failed[@]}" -gt 0 ]]; then
  for name in "${failed[@]}"; do echo "::error::repo-lint: ${name} failed"; done
  exit 1
fi
echo "repo-lint: all ${#names[@]} checks passed"
