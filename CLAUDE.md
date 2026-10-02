# Afframe web apps

Public monorepo for the Afframe web apps. Pre-users v0: the CI gate and the production stack for afframe-vps exist; the apps do not yet. Frontend will be React, the database is Postgres, the backend language is not chosen. Keep everything outside `apps/<name>/` language-agnostic.

## Layout

- `apps/<name>/`: one deployable service each, with its own `Dockerfile`. `apps/placeholder/` is a temporary fixture; delete it when the real web app lands.
- `.github/workflows/`: `ci.yml` (the gate), `claude.yml` and `claude-code-review.yml` (on demand).
- `.github/rulesets/main.json`: the `main` ruleset as applied to GitHub (keep in sync).
- `.github/workflows/deploy.yml`: build changed services to GHCR and deploy `main` to afframe-vps. `deploy-integration.yml`: slow end-to-end test of `deploy/` (nightly). `security.yml`: nightly CodeQL (workflows), Trivy (repo and images, `scripts/ci/trivy-scan.sh`) and Scorecard into the Security tab.
- `scripts/ci/`: shell used by CI, the deploy workflow and the local gate (`deploy-gate.sh` no-deploy switch, `deploy-services.sh` what changed).
- `compose.dev.yml`, `scripts/dev/stack.sh`, `.conductor/settings.toml`: the per-workspace dev stack.
- `deploy/`: production on afframe-vps (Traefik, Postgres 18 + pgBackRest, blue/green deploy script, backup, dump, health and restore-drill scripts, systemd units). Runbook: `docs/vps.md`.

## Commands

- Gate: `bash scripts/ci/repo-lint.sh` (actionlint, zizmor, `docker compose config` of the compose files, shellcheck, gitleaks, every `*.test.sh`; needs a running Docker daemon). CI also checks the PR title (Conventional Commits, `scripts/ci/pr-title.sh`): the squash merge uses it as the commit subject.
- One script's tests: `bash <path>.test.sh`, for example `bash deploy/test/afframe-deploy.test.sh`.
- Production stack end to end (slow, needs Docker; nightly in CI, never on afframe-vps): `bash deploy/test/integration.sh`.
- Dev stack: Conductor Run → `dev`, or `CONDUCTOR_PORT=<port> bash scripts/dev/stack.sh up`; archive runs `stack.sh down`. On Hleb's Mac, Docker points at the Dev Docker daemon on oracle-vps (configured outside this repo, don't change it); published ports appear on `localhost`. Web on `$CONDUCTOR_PORT`, Postgres on `+1` (user, password and database `afframe`).

## Shipping

- Small PRs, one concern each, open for hours not days. Draft until ready.
- `ci` is the only required check and must stay fast (about a minute). Squash merge once it is green; no merge queue. No one can bypass the ruleset.
- Merge to `main` = deploy to afframe-vps in about a minute (`deploy.yml`: changed services only, blue/green, `/health` gate). Skip a deploy: label `no-deploy` or `[no deploy]` in the PR title. Rollback: `docs/vps.md`.
- AI review: CodeRabbit reviews every PR when it leaves draft (`.coderabbit.yaml`); Claude on demand with label `claude-review` or `@claude`. Both advisory, never required.

## Service contract (what CI expects from `apps/<name>/`)

- `Dockerfile` in the service folder; the container listens on `$PORT` (IPv4 and IPv6) and answers `GET /health` with 2xx.
- Tests run through `compose.ci.yml` at the root: service `test` (exit code = result), optional `migrate`, database `postgres:18`. CI runs it with `docker compose -p ci-<run> ... run --rm`.
- Migrations run as a separate pre-deploy step, never in the Docker build: `MIGRATE` in `deploy/services/<name>.env`, run in the new image before the switch.
- Deployed to afframe-vps when `deploy/services/<name>.env` exists (`HOST`, `PORT`, `MEMORY`, `MIGRATE`).

## Gotchas

- Secrets never go in git or in `VITE_*` and other build-time variables (those end up in public bundles). Runtime secrets live in Vault on oracle-vps (`secret/afframe/prod/{infra,app}`, see `docs/vps.md`). GitHub holds only the workflow secrets `CLAUDE_CODE_OAUTH_TOKEN` and the three `production` environment secrets for the tailnet.
- Slow checks (integration, scans) never join the required `ci`; they run nightly or on demand.
- No per-PR preview environments: test on the dev stack. CI builds every service image and runs `compose.ci.yml`, which today checks only the placeholder image (`$PORT` on IPv4 and IPv6, `GET /health`). `detect` fails when a service has `deploy/services/<name>.env` but `compose.ci.yml` is missing.

## Database changes

Expand/contract only: add new columns/tables first, backfill, switch reads, remove old parts in a later deploy. `CREATE INDEX CONCURRENTLY`; add constraints `NOT VALID` then `VALIDATE`; set `lock_timeout` in migrations.

See `ARCHITECTURE.md` for the system.
