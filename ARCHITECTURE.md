# Architecture Overview

Afframe web apps, pre-users v0. This document covers what exists today: the CI gate. Hosting and application components are added here as they land.

## 1. Project Structure

```
afframe/
├── apps/                      # One folder per deployable service, each with a Dockerfile
│   └── placeholder/           # TEMPORARY nginx fixture that proves the pipeline
├── .github/
│   ├── workflows/             # ci, claude, claude-code-review
│   ├── rulesets/main.json     # Ruleset applied to the default branch
│   └── dependabot.yml         # Updates for pinned actions and base images
├── .conductor/settings.toml   # Conductor: dev stack run button and archive cleanup
├── compose.dev.yml            # Dev stack per workspace
├── scripts/ci/                # repo-lint.sh (gate), deploy-gate.sh (+ tests)
├── scripts/dev/               # stack.sh (+ tests)
└── CLAUDE.md
```

## 2. High-Level System Diagram

```
agents / developer ──PR──► GitHub (afframe/afframe, public)
                              │  ci.yml on pull_request (required check `ci`)
                              │ squash merge
                              ▼
                            main   (deploy to the VPS: not built yet, see section 9)
```

## 3. Core Components

### 3.1. Frontend

Not built yet. Will be React, served as a service under `apps/`. Build-time variables are public.

### 3.2. Backend Services

Not built yet; language not chosen. Each service follows the contract in `CLAUDE.md`: Dockerfile, `$PORT`, `GET /health`, migrations as a pre-deploy step, tests via `compose.ci.yml`.

#### 3.2.1. placeholder (temporary)

nginx serving a static page and `/health`. Exists only to exercise build and deploy before real code. Delete `apps/placeholder/` when the real web app lands.

## 4. Data Stores

Postgres 18. Not provisioned yet; it arrives with the VPS stack (section 9). Schema changes: expand/contract, run as pre-deploy migrations.

## 5. External Integrations / APIs

| Integration | Purpose | Credential |
|---|---|---|
| Claude GitHub App + `anthropics/claude-code-action` | On-demand review and `@claude` | `CLAUDE_CODE_OAUTH_TOKEN` repo secret |
| Dependabot | Keeps pinned versions current | built in |

## 6. Deployment & Infrastructure

- **Hosting:** self-hosted VPS (Hostinger KVM 2), not wired yet.
- **CI:** GitHub-hosted runners only (free for public repos; self-hosted runners are unsafe on public repos). `ci` job aggregates `detect`, `repo-lint`, `build` (Docker Buildx, per-service GHA cache), `test` (`compose.ci.yml`).
- **Branch protection:** ruleset on the default branch: PR required, `ci` required, squash only, linear history, no deletion or force-push, no bypass actors.

## 7. Security Considerations

- Public repo: no secrets in git.
- Workflows default to `contents: read`; third-party actions are pinned to commit SHAs; `persist-credentials: false` on checkouts.
- The review action only runs for same-repo PRs.
- gitleaks runs on every PR over the full history.
- Agents act with the maintainer's GitHub token, so they can enqueue merges; the ruleset guarantees checks, not intent.

## 8. Development & Testing Environment

- Local gate: `bash scripts/ci/repo-lint.sh` (Docker required).
- Dev stack per Conductor workspace: `compose.dev.yml` (placeholder + `postgres:18`) through `scripts/dev/stack.sh`, one compose project `afframe-<workspace>` each. On Hleb's Mac it runs on the Dev Docker daemon on oracle-vps. No per-PR preview environments.
- Service tests: `docker compose -p <name> -f compose.ci.yml run --rm test` once a service defines them.

## 9. Future Considerations / Roadmap

- Production on the VPS: images on GHCR, deploy from `main` with the no-deploy gate, Postgres 18 with off-site backups and point-in-time recovery.
- Replace `apps/placeholder` with the React app; choose the backend language.

## 10. Project Identification

- **Repository:** https://github.com/afframe/afframe
- **Owner:** Hleb Tkachenko
- **Date of last update:** 2026-09-30
