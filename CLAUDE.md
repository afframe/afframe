# Afframe web apps

Public monorepo for the Afframe web apps. Pre-users v0: the delivery pipeline exists, the apps do not yet. Frontend will be React, the database is Postgres, the backend language is not chosen. Keep everything outside `apps/<name>/` language-agnostic.

## Layout

- `apps/<name>/`: one deployable service each, with its own `Dockerfile`. `apps/placeholder/` is a temporary fixture (see `docs/railway.md` to remove it).
- `.railway/railway.ts`: Railway infrastructure (services, Postgres, region, build and deploy settings).
- `.github/workflows/`: `ci.yml` (the gate), `deploy-gate.yml` (no-deploy switch), `railway-config.yml` (applies `.railway/` after merge), `claude.yml` and `claude-code-review.yml` (on demand).
- `.github/rulesets/main.json`: the `main` ruleset as applied to GitHub (keep in sync).
- `scripts/ci/`: shell used by CI and the local gate.

## Commands

- Gate: `npm run preflight` (actionlint, shellcheck, gitleaks, deploy-gate tests; needs a running Docker daemon).
- Railway SDK for `.railway/`: `npm ci` (Node >= 22.6). Preview infra changes: `railway config plan` (read-only, needs `railway login`).
- Deploy-gate tests alone: `bash scripts/ci/deploy-gate.test.sh`.

## Shipping

- Small PRs, one concern each, open for hours not days. Draft until ready.
- `ci` is the only required check. Merge through the queue ("Merge when ready"), squash only. No one can bypass the ruleset.
- Merge to `main` = deploy to live v0 once every Actions workflow on the commit passes (Railway Wait for CI).
- Skip a deploy: label `no-deploy` or `[no deploy]` in the PR title.
- AI review on demand: label `claude-review`, or comment `@claude`. Never required.

## Service contract (what CI and Railway expect from `apps/<name>/`)

- `Dockerfile` in the service folder; the container listens on `$PORT` (IPv4 and IPv6) and answers `GET /health` with 2xx.
- Add the service to `.railway/railway.ts` with `rootDirectory`, `watchPatterns`, `checkSuites: true`, `sleepApplication: true`, `healthcheck: "/health"`.
- Tests run through `compose.ci.yml` at the root: service `test` (exit code = result), optional `migrate`, database `postgres:18`. CI runs it with `docker compose -p ci-<run> ... run --rm`.
- Migrations run as the service's Railway pre-deploy command (`preDeploy`), never in the Docker build: the private network does not exist at build time.

## Gotchas

- Only one open PR at a time should edit `.railway/`: apply fails on a stale plan. Destructive infra changes need the manual "confirm destructive" run of `Railway config`.
- Secrets: sealed Railway variables referenced with `preserve()`. Never in git, `.railway/`, `VITE_*` or other build-time variables (those end up in public bundles).
- PR environments get a fresh, empty Postgres. Seed via pre-deploy, never from production.
- Serverless: a service sleeps after ~10 min without outbound traffic; an open DB pool keeps it awake. First request after sleep can fail once.
- A failed workflow on a `main` commit skips that deploy. `claude.yml` runs attach to `main`'s head, so they are `continue-on-error`.
- Rollback from the Railway dashboard reaches deploys from the last 72 hours (Hobby).

## Database changes

Expand/contract only: add new columns/tables first, backfill, switch reads, remove old parts in a later deploy. `CREATE INDEX CONCURRENTLY`; add constraints `NOT VALID` then `VALIDATE`; set `lock_timeout` in migrations.

See `ARCHITECTURE.md` for the system and `docs/railway.md` for operations.
