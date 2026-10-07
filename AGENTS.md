# AGENTS.md

The sections from "All files" to "YAML and workflows" are the writing rules. They apply to every file and to published text. `docs/conventions.md` sets the naming rules, the single source of each value and the place of each document. Read it before you name or add a file, or add a value. `ARCHITECTURE.md` describes the system and the deploy: read it before a change to `deploy/`, CI or a service.

@docs/conventions.md

## Layout

| Path | Role |
|---|---|
| `apps/<name>/` | One deployable service with its own `Dockerfile`. `apps/placeholder/` is a stand-in until the first real app. |
| `packages/<name>/` | Shared code that apps use. It deploys only inside an app image. The folder does not exist until the first package. |
| `package.json`, `pnpm-workspace.yaml`, `pnpm-lock.yaml`, `.dockerignore` | The pnpm workspace root, and the files that app image builds get |
| `.github/workflows/` | `ci.yml` and `pr-title.yml` are the PR gates. `deploy.yml` deploys and rolls back. `security.yml` runs the scheduled image scan. |
| `scripts/ci/` | Shell for CI, the deploy workflow, the local gate and the rulesets. A `*.test.sh` is next to each tested script. |
| `deploy/` | The deploy host stack: host commands in `deploy/bin/`, `deploy/compose.prod.yml`, Postgres, Traefik, systemd units and service manifests |
| `deploy/test/` | Tests of `deploy/`. The deploy does not ship this folder. |
| `compose.ci.yml` | The service tests that CI and the deploy run |
| `compose.dev.yml`, `scripts/dev/` | The dev Postgres of a local Conductor workspace |
| `docs/templates/app/` | Starter files for a new app. Nothing runs them until you copy them. |
| `.mcp.json`, `.claude/`, `.conductor/`, `scripts/setup.sh`, `scripts/conductor/`, `favicon.svg` | Agent tooling, with the CodeGraph dependency in the root `package.json`. `favicon.svg` is the Conductor repository icon. |
| `$INTERNAL` | The private documentation repository. It holds the deploy host facts. |

## Commands

| Task | Command | Note |
|---|---|---|
| Local gate before a push | `bash scripts/ci/local-gate.sh` | Its header tells what runs without a Docker daemon |
| Tests of one script | `bash <path>.test.sh` | Example: `bash deploy/test/afframe-deploy.test.sh` |
| Deploy stack end to end | `bash deploy/test/integration.sh` | Takes minutes. See the warning below. |
| Build images | `bash scripts/ci/build-images.sh <tag> <service>...` | Pushes nothing |
| Compare the rulesets with GitHub, or apply them | `GH_REPO=afframe/afframe bash scripts/ci/rulesets.sh [apply]` | `apply` changes live settings |
| Set up an agent session: Node deps and the CodeGraph index | `bash scripts/setup.sh` | Safe to run again |
| CodeGraph index status | `pnpm exec codegraph status .` | |
| Start or remove the dev Postgres of this workspace | `bash scripts/dev/stack.sh up` or `down` | |
| Update `pnpm-lock.yaml` after a dependency change | `pnpm install` | Run it at the repository root |

- `deploy/test/integration.sh` uses the deploy host project name and fixed container names. Run it once per Docker daemon.
- Never run it against the Docker daemon of the deploy host. Its cleanup deletes the volumes.
- On a client that is not Linux, it mounts `/var/run/docker.sock` of the daemon host.
- Run it only on a rootful daemon. On a host with a rootless daemon, `/var/run/docker.sock` is the socket of the rootful daemon.

## Agent sessions

Each runner calls `bash scripts/setup.sh` when it prepares a workspace or session.

| Runner | Where the call is |
|---|---|
| Conductor, local | `scripts.setup` in `.conductor/settings.toml` |
| Conductor, cloud | Conductor cloud skips `scripts.setup`. The repository Setup script in the Conductor settings must run the command. |
| Claude Code, cloud | The `SessionStart` hook in `.claude/settings.json` runs it at every startup and resume. It does nothing outside the cloud. |
| Codex | The setup command of the environment |
| Any other runner | Run it once after the clone |

Personal agent configuration comes from the setup of each runner environment, not from this repository.

## CodeGraph

- Query CodeGraph first to find or understand code in `apps/` and `packages/`. Use the `codegraph_explore` tool or `pnpm exec codegraph explore "<question>"`.
- CodeGraph does not index shell scripts or Dockerfiles. For `deploy/`, `scripts/` and workflows, use the layout table.

## All files

- Write in English. Describe the system as it is now. Do not write history, plans, follow-ups or TODO notes. Git history and issues keep them.
- Do not write private facts: host names, addresses, accounts, host paths, hosting plan and usage, vendor account setup and dashboard config, or Vault paths.
- Vendor names are public. You can write Cloudflare, Tailscale or Vault.
- Write private facts in `$INTERNAL`, the private documentation repository. Write `$INTERNAL/<file>` to point to a file there. Do not quote the file.
- Do not write the location or the name of `$INTERNAL`.
- Write each fact and each value (version, port, schedule, limit, name) in one file. Other files name that file.
- Name a credential only in the file that reads it. Documents never list credential names. They describe the credential by its purpose.
- Use one term for one thing: "deploy host", "service", "release", "colour".

## Markdown

- Line 1 is `# <subject>`. Do not write a sentence that only says what the file is for. Start with the first fact.
- GitHub templates under `.github/` start with their first `##` section.
- Use `##` for sections and `###` for subsections. `ARCHITECTURE.md` keeps the 11 numbered sections of its template. Section 9 is Known Limits, because this repository writes no plans.
- Use a table for properties, a numbered list for steps, a bullet list for rules and code spans for paths and commands.
- Write ASD-STE100: active voice, simple tenses, one statement per sentence, 25 words or fewer. Use no semicolons and one parenthesis per sentence at most.
- Give a reason only when it prevents a wrong change. Use one sentence for it.
- Do not use slang, persuasion or marketing words.
- Banned words: `lands`, `gotchas`, `v0`, `safer`, `simply`, `easily`, `seamless`, `seamlessly`, `robust`, `powerful`, `leverage`, `blazing`, `best-in-class`, `cutting-edge`, `magic`, `awesome`, `basically`, `obviously`.
- Do not hard-wrap text. Write one paragraph or one list item per line.
- Write only facts that a reader needs. Do not add a table column that repeats another column, or an index that repeats another index.

## Code comments

- These rules apply to every comment: code, YAML, TOML, Dockerfiles, `.gitignore` and templates.
- A comment states a fact that the names and the code do not show. These facts are a reason, a trap, an external limit and a file that must change too. Delete every other comment.
- Do not write what a file, section, job, step, key or function is or does. Do not write section labels.
- A file header has 3 comment lines at most, after the shebang. It contains only `Usage:` with arguments, an output format or a constraint for the caller.
- Write a function comment only for a fact that the name and the arguments do not show. Use one line: `# name <args>: fact`.
- An inline comment has 1 line, 3 lines at most.
- A test file has no header unless the check names cannot show a fact, such as a scratch repository. The check names describe the coverage.
- Point to another file only when a change here needs a change there, or when "Configuration" in `docs/conventions.md` requires the pointer.
- Keep tool annotations: `# vX.Y.Z` after a SHA pin, `# shellcheck` and `# yaml-language-server`.
- Comment lines have 100 columns at most. Code lines have 120 columns at most, except pin lines.

### Useful and useless comments

| Comment | Verdict | Reason |
|---|---|---|
| `# Deploys the service.` above `deploy()` | Delete | The name says it. |
| `# Enables auto-merge for Dependabot updates.` under `name: Dependabot auto-merge` | Delete | The name and the `if:` say it. |
| `# --- helpers ---` | Delete | A section label. |
| `# Usage: repo-lint.sh` for a script with no arguments | Delete | The file name says it. |
| `# The value goes to curl on stdin, never on its command line, where ps would show it.` | Keep | A security reason. |
| `# macOS bash 3.2 treats an empty array as unset under set -u.` | Keep | A trap. |
| `# The pairing value is in deploy/traefik/traefik.yml.` | Keep | A file that must change too. |
| `# https://www.cloudflare.com/ips/ (checked 2026-10-01)` | Keep | An external source. |

## Published text

- Commit messages, PR titles and bodies, issue, review and comment text and release notes are public. "All files" applies to them.
- After a `git commit`, a `gh` PR, issue or release call or a GitHub MCP write, `.claude/hooks/published-text.sh` reminds Claude Code of these rules. It does not block. Fix the text if it breaks a rule.
- Before you open or update a PR or publish other text, run `/rules-review` with the draft title and body. Fix each finding before you publish.

## YAML and workflows

- A workflow starts with `name:`. Its header comment has 2 lines at most.
- A multi-line `run:` step has a `name:` in the imperative. A `run:` of more than 10 lines goes into `scripts/ci/`.
- Pin each image and action where Dependabot reads it: a `FROM` line, a compose `image:` or a `uses:` line.

## Rules

- This repository is public: see "All files".
- Build-time variables such as `VITE_*` go into public bundles. Do not put credentials in them.
- CI and the deploy use only Docker, Compose and shell. Language-specific files go in `apps/<name>/`, `packages/<name>/`, the root workspace files or the agent tooling of the layout table.
- A merge to `main` deploys to the deploy host when deploys are on (`ARCHITECTURE.md` section 6.1). Treat each merge as a production change.
- The PR title is a Conventional Commit. `scripts/ci/pr-title.sh` checks it in a Claude Code hook and in the `pr-title` check. The squash merge uses it as the commit subject.
- Fill in `.github/pull_request_template.md` for each PR.
- Record a feature idea as an issue from `.github/ISSUE_TEMPLATE/feature.yml`.
- Record a choice that a future contributor could reverse for a wrong reason as an ADR in `docs/adr/`. Use the next number and the shape of the newest ADR.
- Never merge with `gh pr merge --admin`. Admins can bypass the rulesets, but agents must not.
- `ci` and `pr-title` are the only merge gates. Merge when both pass.
- AI reviews are advisory. Do not wait for them before a merge. The owner starts a Claude review with the `claude-review` label or a manual run of `claude-code-review.yml`.
- CodeRabbit reviews a PR only on request: a comment `@coderabbitai review`.
- Keep `ci` near one minute. A slow check runs only when its inputs change, and `scripts/ci/ci-changes.sh` decides that.
- Delete `apps/placeholder/` and `deploy/services/placeholder.conf` in the PR that adds the first real app. Replace its test in `compose.ci.yml` with the `probe-<name>` service of `docs/templates/app/compose.ci.yml.example` in the same PR. The deploy tests do not use the placeholder.

## Service contract

- A service is a folder `apps/<name>/` with a `Dockerfile`. The container listens on `$PORT` over IPv4 and IPv6.
- The build context of an app image is the repository root, so `COPY` paths start at the root.
- `GET /health` returns 2xx.
- `compose.ci.yml` defines the services `test` and an optional `migrate`. For a real app, each one depends on the per-app services in `docs/templates/app/compose.ci.yml.example`. The exit code of `test` is the result. Start from `docs/templates/app/`.
- CI and the deploy test the image that they ship. The header of `scripts/ci/service-tests.sh` tells how.
- `deploy/services/<name>.conf` makes a service deployable. Its keys are `HOST`, `PORT`, `MEMORY` and `MIGRATE`.
- `HOST` is the public host name. The container gets `PORT` as `$PORT`. `MIGRATE` is the migration command, or empty.
- `scripts/ci/ci-changes.sh` fails when a deployable service exists and `compose.ci.yml` is missing.
- To remove a service, delete its `.conf` file. The next deploy removes its route, containers and deployment metadata. The shared database volumes remain.

## Database changes

- `MIGRATE` runs in the new image before the switch, while the old colour still serves traffic. Each migration must work with the old code.
- Use expand and contract: add new columns and tables, backfill, switch reads. Remove the old parts in a later deploy.
- Use `CREATE INDEX CONCURRENTLY`. Add constraints as `NOT VALID`, then `VALIDATE`. Set `lock_timeout` in each migration.
