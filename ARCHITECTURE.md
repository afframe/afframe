# Architecture Overview

Afframe web apps, pre-users v0. This document covers what exists today: the CI gate and the production stack for afframe-vps. Hosting and application components are added here as they land.

## 1. Project Structure

```
afframe/
├── apps/                      # One folder per deployable service, each with a Dockerfile
│   └── placeholder/           # TEMPORARY nginx fixture that proves the pipeline
├── .github/
│   ├── workflows/             # ci, deploy, deploy-integration, security, claude, claude-code-review
│   ├── rulesets/main.json     # Ruleset applied to the default branch
│   └── dependabot.yml         # Updates for pinned actions and base images
├── .conductor/settings.toml   # Conductor: dev stack run button and archive cleanup
├── compose.dev.yml            # Dev stack per workspace
├── scripts/ci/                # repo-lint.sh (gate), pr-title.sh, deploy-gate.sh, deploy-services.sh, trivy-scan.sh (+ tests)
├── scripts/dev/               # stack.sh (+ tests)
├── deploy/                    # Production on afframe-vps: compose, Traefik, Postgres image, host scripts
├── docs/vps.md                # afframe-vps runbook
└── CLAUDE.md
```

## 2. High-Level System Diagram

```
agents / developer ──PR──► GitHub (afframe/afframe, public)
                              │  ci.yml on pull_request (required check `ci`)
                              │ squash merge
                              ▼
                            main ──push──► deploy.yml: no-deploy gate ─► build changed services ─► GHCR (by digest)
                              │                              └─► Tailscale (OIDC) ─► SSH ─► afframe-deploy
                              ▼
        afframe-vps (Hostinger KVM 2, Ubuntu 24.04): Traefik ── blue/green app containers
                                                       └──── Postgres 18 ── pgBackRest WAL ──► Cloudflare R2
        secrets: Vault on oracle-vps (over Tailscale)    monitoring: Better Stack heartbeats + uptime
```

## 3. Core Components

### 3.1. Frontend

Not built yet. Will be React, served as a service under `apps/`. Build-time variables are public.

### 3.2. Backend Services

Not built yet; language not chosen. Each service follows the contract in `CLAUDE.md`: Dockerfile, `$PORT`, `GET /health`, migrations as a pre-deploy step, tests via `compose.ci.yml`.

#### 3.2.1. placeholder (temporary)

nginx serving a static page and `/health`. Exists only to exercise build and deploy before real code. Delete `apps/placeholder/` when the real web app lands.

## 4. Data Stores

Postgres 18 on afframe-vps (`deploy/postgres/Dockerfile`), internal network only. pgBackRest archives WAL continuously and takes a daily backup (full on Sundays) to Cloudflare R2, encrypted, 4 full backups kept: point-in-time recovery over about 4 weeks. A nightly `pg_dump` (rclone-crypt encrypted, 30 days) is a second copy in a different format; by default it goes to the same bucket with the same token, so it is independent of pgBackRest but not of a lost bucket or a leaked token until the `DUMP_S3_*` settings point it at its own locked bucket (`docs/vps.md`). Each dump first upserts a sentinel row (`ops.heartbeat`). A monthly restore drill restores both the latest pgBackRest backup and the latest dump into throwaway containers and fails unless each holds a sentinel under 26 hours old. Schema changes: expand/contract, run as pre-deploy migrations.

## 5. External Integrations / APIs

| Integration | Purpose | Credential |
|---|---|---|
| Claude GitHub App + `anthropics/claude-code-action` | On-demand review and `@claude` | `CLAUDE_CODE_OAUTH_TOKEN` repo secret |
| CodeRabbit GitHub App | Automatic review when a PR is ready (`.coderabbit.yaml`), advisory | app installed on the org |
| Vault on oracle-vps | Runtime secrets of afframe-vps (`secret/afframe/prod/{infra,app}`) | read-only token on the host |
| Cloudflare | DNS and proxy for `afframe.com`, Origin CA certificate, R2 bucket for pgBackRest | in Vault |
| Better Stack | Uptime check, heartbeats, status page | heartbeat URLs in Vault |
| Dependabot | Keeps pinned versions current | built in |

## 6. Deployment & Infrastructure

- **Hosting:** afframe-vps, Hostinger KVM 2 (2 vCPU, 8 GB), Ubuntu 24.04 LTS, Docker. Traefik routes by file (no Docker socket) behind Cloudflare (Full strict, Origin CA certificate). Apps deploy blue/green by image digest with a `/health` gate and one-command rollback (`deploy/bin/afframe-deploy`). Runbook and host setup: `docs/vps.md`.
- **CD:** `deploy.yml` on every push to `main`: `deploy-gate.sh` (label `no-deploy` / `[no deploy]` skips; API errors fail closed), `deploy-services.sh` (changed services), build and push `ghcr.io/afframe/afframe/<service>:sha-<sha>` with a provenance attestation, then `afframe-deploy` over Tailscale SSH. GitHub holds only workflow secrets: `CLAUDE_CODE_OAUTH_TOKEN` (repository) and `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE`, `DEPLOY_HOST` (environment `production`, needed to reach the tailnet). Application and host runtime secrets live in Vault.
- **Monitoring:** Better Stack free plan: uptime check of `/health`, heartbeats from the backup, dump, health and restore-drill timers, status page.
- **CI:** GitHub-hosted runners only (free for public repos; self-hosted runners are unsafe on public repos). `ci` job aggregates `detect`, `pr-title` (Conventional Commits), `repo-lint` (actionlint, zizmor, `docker compose config` of the compose files, shellcheck, gitleaks, script tests), `build` (Docker Buildx, per-service GHA cache), `test` (`compose.ci.yml`). Slow checks run outside `ci`: `Deploy integration` (nightly, and advisory on PRs touching `deploy/`) and `Security scans` (nightly CodeQL for workflows, Trivy for the repo and images, OpenSSF Scorecard; findings in the Security tab).
- **Branch protection:** ruleset on the default branch: PR required, `ci` required, squash only, linear history, no deletion or force-push, no bypass actors.

## 7. Security Considerations

- Public repo: no secrets in git. GitHub holds only workflow secrets: `CLAUDE_CODE_OAUTH_TOKEN` (repository) and `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE`, `DEPLOY_HOST` (environment `production`, needed to reach the tailnet). Application and host runtime secrets live in Vault. The host reads them at deploy time with a read-only token.
- afframe-vps runs only `main`: `afframe-deploy` refuses commits not on `origin/main` and images outside `ghcr.io/afframe/afframe/<service>`.
- Images on GHCR are private: the host pulls with the deploy run's own short-lived token (stdin, throwaway Docker config); no registry credential is stored anywhere.
- Workflows default to `contents: read`; third-party actions are pinned to commit SHAs; `persist-credentials: false` on checkouts.
- The review action only runs for same-repo PRs.
- gitleaks runs on every PR over the full history.
- Agents act with the maintainer's GitHub token, so they can enqueue merges; the ruleset guarantees checks, not intent.

## 8. Development & Testing Environment

- Local gate: `bash scripts/ci/repo-lint.sh` (Docker required).
- Dev stack per Conductor workspace: `compose.dev.yml` (placeholder + `postgres:18`) through `scripts/dev/stack.sh`, one compose project `afframe-<workspace>` each. On Hleb's Mac it runs on the Dev Docker daemon on oracle-vps. No per-PR preview environments.
- Service tests: `docker compose -p <name> -f compose.ci.yml run --rm test` once a service defines them.

## 9. Future Considerations / Roadmap

- Replace `apps/placeholder` with the React app; choose the backend language.

## 10. Project Identification

- **Repository:** https://github.com/afframe/afframe
- **Owner:** Hleb Tkachenko
- **Date of last update:** 2026-10-01
