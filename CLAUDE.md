# Afframe web apps

Public monorepo for the Afframe web apps. Pre-users v0: the CI gate and merge queue exist; the apps and the deploy to the VPS do not yet. Frontend will be React, the database is Postgres, the backend language is not chosen. Keep everything outside `apps/<name>/` language-agnostic.

## Layout

- `apps/<name>/`: one deployable service each, with its own `Dockerfile`. `apps/placeholder/` is a temporary fixture; delete it when the real web app lands.
- `.github/workflows/`: `ci.yml` (the gate), `claude.yml` and `claude-code-review.yml` (on demand).
- `.github/rulesets/main.json`: the `main` ruleset as applied to GitHub (keep in sync).
- `scripts/ci/`: shell used by CI and the local gate. `deploy-gate.sh` holds the no-deploy rule for the upcoming VPS deploy workflow.

## Commands

- Gate: `bash scripts/ci/repo-lint.sh` (actionlint, shellcheck, gitleaks, deploy-gate tests; needs a running Docker daemon).
- Deploy-gate tests alone: `bash scripts/ci/deploy-gate.test.sh`.

## Shipping

- Small PRs, one concern each, open for hours not days. Draft until ready.
- `ci` is the only required check. Merge through the queue ("Merge when ready"), squash only. No one can bypass the ruleset.
- No deploy yet: production moves to the self-hosted VPS (see `ARCHITECTURE.md`, section 9).
- AI review on demand: label `claude-review`, or comment `@claude`. Never required.

## Service contract (what CI expects from `apps/<name>/`)

- `Dockerfile` in the service folder; the container listens on `$PORT` (IPv4 and IPv6) and answers `GET /health` with 2xx.
- Tests run through `compose.ci.yml` at the root: service `test` (exit code = result), optional `migrate`, database `postgres:18`. CI runs it with `docker compose -p ci-<run> ... run --rm`.
- Migrations run as a separate pre-deploy step, never in the Docker build.

## Gotchas

- Secrets never go in git or in `VITE_*` or other build-time variables (those end up in public bundles).
- Preview environments get a fresh, empty Postgres. Seed from the service, never from production.

## Database changes

Expand/contract only: add new columns/tables first, backfill, switch reads, remove old parts in a later deploy. `CREATE INDEX CONCURRENTLY`; add constraints `NOT VALID` then `VALIDATE`; set `lock_timeout` in migrations.

See `ARCHITECTURE.md` for the system.
