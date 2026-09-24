# Architecture Overview

Afframe web apps, pre-users v0. This document covers what exists today: the delivery pipeline and the hosting. Application components are added here as they land.

## 1. Project Structure

```
afframe/
├── apps/                      # One folder per deployable service, each with a Dockerfile
│   └── placeholder/           # TEMPORARY nginx fixture that proves the pipeline
├── .railway/railway.ts        # Railway infrastructure as code (TypeScript SDK `railway`)
├── .github/
│   ├── workflows/             # ci, deploy-gate, railway-config, claude, claude-code-review
│   ├── rulesets/main.json     # Ruleset applied to the default branch
│   └── dependabot.yml         # Updates for pinned actions, the SDK, base images
├── scripts/ci/                # repo-lint.sh (gate), deploy-gate.sh (+ tests)
├── docs/railway.md            # Operations runbook
├── package.json               # Repo tooling only (Railway SDK, `npm run preflight`)
└── CLAUDE.md
```

## 2. High-Level System Diagram

```
agents / developer ──PR──► GitHub (afframe/afframe, public)
                              │  ci.yml on pull_request (required check `ci`)
                              ▼
                         merge queue ──merge_group──► ci.yml on the exact merge commit
                              │ squash
                              ▼
                            main ──push──► ci.yml, deploy-gate.yml, railway-config.yml (.railway/ changes)
                              │
          Railway (Wait for CI: waits for every Actions workflow on the commit)
                              ▼
        Railway project `afframe`, EU West ── production: services + Postgres
                                           └─ PR environments: copy of services + empty Postgres, per open PR
```

## 3. Core Components

### 3.1. Frontend

Not built yet. Will be React, served as a service under `apps/`. Build-time variables are public.

### 3.2. Backend Services

Not built yet; language not chosen. Each service follows the contract in `CLAUDE.md`: Dockerfile, `$PORT`, `GET /health`, migrations as Railway pre-deploy command, tests via `compose.ci.yml`.

#### 3.2.1. placeholder (temporary)

nginx serving a static page and `/health`. Exists only to exercise build, deploy, preview and rollback before real code. Removal steps: `docs/railway.md`.

## 4. Data Stores

### 4.1. Postgres (Railway)

- Railway-managed Postgres service in EU West, declared as `postgres("postgres")` in `.railway/railway.ts`; services reach it over the private network (`postgres.railway.internal`) via `${{postgres.DATABASE_URL}}`.
- Daily volume backups and point-in-time recovery (about 4 weeks, pgBackRest WAL archiving).
- Each PR environment gets its own empty Postgres.
- Schema changes: expand/contract, run as pre-deploy migrations.

## 5. External Integrations / APIs

| Integration | Purpose | Credential |
|---|---|---|
| Railway GitHub App | Builds and deploys on push to `main`, PR environments, GitHub Deployments | installed on the org |
| Railway API (CLI) | `railway-config.yml` applies `.railway/` | `RAILWAY_TOKEN` project token, GitHub Environment `railway-production` (main only) |
| Claude GitHub App + `anthropics/claude-code-action` | On-demand review and `@claude` | `CLAUDE_CODE_OAUTH_TOKEN` repo secret |
| Dependabot | Keeps pinned versions current | built in |

## 6. Deployment & Infrastructure

- **Hosting:** Railway, Hobby plan, region `europe-west4-drams3a` (EU West, Amsterdam). Chosen for the pre-users phase for price and zero operations; production with users is planned on AWS or similar.
- **Environments:** `production` (live v0) and ephemeral PR environments. No staging.
- **CI:** GitHub-hosted runners only (free for public repos; self-hosted runners are unsafe on public repos). `ci` job aggregates `detect`, `repo-lint`, `build` (Docker Buildx, per-service GHA cache), `test` (`compose.ci.yml`). On `push` to main only the cheap jobs run, because the merge queue already tested the same SHA.
- **CD:** Railway autodeploy from `main` with Wait for CI. `deploy-gate.yml` fails on purpose for `no-deploy` / `[no deploy]` to skip a deploy. Zero-downtime switch after `/health` returns 2xx. Rollback from the dashboard (72 h image retention on Hobby).
- **Branch protection:** ruleset on the default branch: PR required, `ci` required, squash only, merge queue (ALLGREEN, 5 builds), linear history, no deletion or force-push, no bypass actors.
- **Cost:** about $2 to $4 of usage per month inside the $5 Hobby fee; services sleep when idle. Usage alert $5, hard limit $20.

## 7. Security Considerations

- Public repo: no secrets in git. Railway secrets are sealed variables; `.railway/railway.ts` references them with `preserve()`.
- The Railway project token is only reachable from `main` through a GitHub Environment; PR workflows never receive it.
- Workflows default to `contents: read`; third-party actions are pinned to commit SHAs; `persist-credentials: false` on checkouts.
- Railway only deploys PR environments for workspace members; the review action only runs for same-repo PRs.
- gitleaks runs on every PR over the full history.
- Agents act with the maintainer's GitHub token, so they can enqueue merges; the ruleset guarantees checks, not intent.

## 8. Development & Testing Environment

- Local gate: `npm run preflight` (Docker required).
- Railway CLI: `railway login`, then `railway config plan`, `railway logs`, `railway status`. The Railway MCP server is configured in `.mcp.json` and reuses the CLI login.
- Service tests: `docker compose -p <name> -f compose.ci.yml run --rm test` once a service defines them.

## 9. Future Considerations / Roadmap

- Replace `apps/placeholder` with the React app; choose the backend language.
- Custom domain.
- Move production to AWS or similar before real customer data; off-platform `pg_dump` backups before then.

## 10. Project Identification

- **Repository:** https://github.com/afframe/afframe
- **Owner:** Hleb Tkachenko
- **Date of last update:** 2026-09-24

## 11. Glossary / Acronyms

- **Wait for CI:** Railway setting that holds a deploy until every GitHub Actions workflow on the commit finishes; a failed one skips the deploy.
- **PR environment:** temporary Railway copy of production for one pull request.
- **Merge queue:** GitHub feature that tests each PR on top of the latest `main` before merging.
- **PITR:** point-in-time recovery of Postgres.
