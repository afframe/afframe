# Railway runbook

Hosting for the pre-users phase: Railway, Hobby plan ($5/month, usage included up to $5), region EU West (`europe-west4-drams3a`). Production moves to AWS or similar once there are users.

## What lives where

| In the repo | In Railway only |
|---|---|
| `.railway/railway.ts`: services, Postgres, region, build, healthcheck, pre-deploy, Wait for CI, watch paths, serverless | Sealed secrets (never in git; referenced with `preserve()`) |
| `.github/workflows/railway-config.yml`: applies it after merge | PR environments toggle (Project Settings → Environments) |
| `apps/<name>/Dockerfile` per service | Postgres backup schedule, point-in-time recovery |
| | Usage alert and hard limit, the project token |

The project token for CI is a GitHub **Environment** secret (`railway-production` → `RAILWAY_TOKEN`), usable only from `main`. Agent PRs never see it.

## Ship flow

1. PR from a short-lived branch. `ci` must pass.
2. "Merge when ready" puts it in the merge queue. The queue re-runs `ci` on main + the PRs ahead (`merge_group`) and squash-merges.
3. The push to `main` runs `CI`, `Deploy gate` and, when `.railway/` changed, `Railway config`.
4. Railway waits for every GitHub Actions workflow on that commit (Wait for CI), then deploys. Healthcheck `/health` must return 2xx before traffic switches.
5. Deploy status shows on the commit as a GitHub Deployment.

## Skip a deploy

Add the label `no-deploy` to the PR, or put `[no deploy]` in its title, before it merges. `Deploy gate` fails on purpose and Railway skips that commit. The next merge without the switch deploys everything that accumulated. When several PRs land together, one tagged PR skips the whole batch.

## Change infrastructure

Edit `.railway/railway.ts`, then check it: `railway config plan` (needs `railway login`; read-only). Merge; `Railway config` applies it.
- Only one open PR at a time should touch `.railway/`: apply compares against the live state and a stale plan fails.
- Destructive changes (removing a service, volume or variable) fail the automatic run. Run **Actions → Railway config → Run workflow** with "confirm destructive" checked.

## PR environments

Every PR gets a copy of the production services with its own fresh, empty Postgres and a Railway URL, posted as a comment on the PR. Deleted when the PR closes. Railway does not deploy PRs from people outside the workspace. Seed preview data from a service's pre-deploy command, never from production.

## Secrets

- Add in Railway: service → Variables → New variable → then **Seal** it. Sealed values are never shown again, never copied to PR environments, and never leave Railway.
- In `.railway/railway.ts`, reference them as `NAME: preserve()`.
- Frontend build-time variables (for example `VITE_*`) end up in public JS bundles: never put secrets there.

## Rollback

Railway dashboard → service → Deployments → a previous deployment → **Rollback**. Restores the image and variables without a rebuild. Hobby keeps images for 72 hours; older deployments need **Redeploy** (rebuilds from source).

## Database

- Backups: Postgres service → Backups: daily schedule.
- Point-in-time recovery (about 4 weeks): `railway postgres pitr enable --service postgres`, status with `railway postgres pitr status`, restore with `railway postgres pitr restore --service postgres --at <ISO-8601 time>` (restores into a new service).
- Schema changes go through expand/contract migrations run as the service's pre-deploy command (see CLAUDE.md).
- Exit (to AWS or anywhere): `pg_dump --format=custom` over the public TCP proxy, then `pg_restore`.

## Cost control

- Serverless: services sleep after about 10 minutes without outbound traffic. A held database connection pool keeps a service awake; connect per request or close idle connections.
- Workspace usage limits: `railway usage limit set --target workspace --soft 5 --hard 20`. The hard limit takes everything offline when hit.
- Open PR environments cost like production while awake. Close stale PRs.

## Remove the placeholder

`apps/placeholder` is a temporary fixture that proved the pipeline. When the real web app lands:
1. One PR: delete `apps/placeholder/` and the `placeholder` block in `.railway/railway.ts`.
2. After merge, the automatic `Railway config` run fails on the destructive change by design. Run it manually with "confirm destructive" checked.

## One-time setup

1. Railway account (Hobby), workspace preferred region EU West.
2. Railway GitHub App on the `afframe` org, access to `afframe/afframe`.
3. `railway login`, `railway init` (project `afframe`), `railway config apply` from a checkout.
4. Project Settings → Environments: enable PR environments and Focused PR environments.
5. Postgres: backups daily, PITR enabled. Usage limits set.
6. Project token for `production` → GitHub Environment `railway-production` secret `RAILWAY_TOKEN`.
