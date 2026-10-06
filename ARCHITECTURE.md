# Architecture Overview

## 1. Project Structure

The Layout table in `AGENTS.md` gives the role of each folder that its name does not show.

## 2. High-Level System Diagram

```
PR ──► required checks (ci, pr-title) ──squash merge──► main ──► deploy.yml ──Tailscale SSH──► deploy host

deploy host:  Cloudflare proxy ──► Traefik ──► blue/green service containers
              Postgres + pgBackRest ──► backup repository
              systemd host jobs ──► heartbeat monitor
              Vault ──► runtime credentials and config
```

## 3. Core Components

- Traefik routes from files only, with no Docker socket. `afframe-deploy` writes one route file per service.

## 4. Data Stores

- Postgres runs on the deploy host from `deploy/postgres/Dockerfile`, on an internal network only.
- pgBackRest archives WAL and takes scheduled backups to the backup repository that Vault configures.
- Each backup writes a sentinel row to `ops.heartbeat`. A failed sentinel write only warns.
- The restore drill restores the latest backup with WAL into a throwaway container and never touches the live database.
- The drill fails when the restored sentinel is older than the recovery point target.
- `docs/conventions.md` section Naming sets the rule for the volume names.

## 5. External Integrations / APIs

| Integration | Configured in |
|---|---|
| Tailscale | `.github/workflows/deploy.yml` |
| Vault | `deploy/bin/vault-env` |
| Cloudflare proxy and origin certificate | `deploy/traefik/` |
| Backup repository | Vault |
| Heartbeat monitor | Vault |
| CodeRabbit | `.coderabbit.yaml` |
| Claude Code action | `.github/workflows/claude-code-review.yml` |
| Dependabot | `.github/dependabot.yml` |

## 6. Deployment & Infrastructure

### 6.1 Deploy

1. A push to `main` runs `.github/workflows/deploy.yml`. A push that changes only `**.md` or `docs/**` files does not deploy. This includes Markdown files in `apps/`.
2. The job runs only when the repository variable `DEPLOY_ENABLED` is `true`.
3. The job stops unless the commit is the merge commit of a PR into the default branch.
4. It joins the tailnet with OIDC and ships the release and the tested images as the Decision in `docs/adr/0001-registry-free-deploy.md` states. `afframe-receive` unpacks the release.
5. `afframe-deploy` refuses a run number lower than the deployed one. It renders the credentials and starts Traefik and Postgres when their inputs changed.
6. For each changed service, it runs `MIGRATE` in the new image, starts the idle colour and waits for consecutive `/health` passes.
7. It removes the services whose manifest is gone, switches Traefik, confirms the switch through Traefik and stops the old colours.
8. A failure before the switch switches nothing. An unconfirmed switch routes back.

### 6.2 Rollback

1. Run the Deploy workflow manually with `rollback: <service>`. A manual run with an empty input deploys `main` again.
2. The host runs the rollback from `current` with no build, so it works when `main` is broken.
3. It starts the previous image without migrations and switches to it.
4. The host holds the service on that image until a different image arrives.

### 6.3 Facts that prevent wrong changes

- Do not add `environment:` to the deploy job. It changes the OIDC subject, and the Tailscale trust then refuses the deploy.
- The `github.ref` check is not a security control, because a dispatch from a branch runs that branch's copy of the workflow.
- One run waits per concurrency group. A newer push replaces a waiting run, and also a waiting rollback.
- An image with the same non-empty `afframe.tree` label as the live image does not deploy. An image without the label always deploys.
- A change to `packages/` or a root workspace file gives every app a new label, so every app deploys. `label_of` in `scripts/ci/build-images.sh` lists these inputs.
- Dependabot base-image updates change the tree, so they deploy. An unpinned upgrade inside a Dockerfile ships only with a source change.
- `afframe-deploy` refuses a service name that has a file in `deploy/traefik/dynamic/`, because route files share that folder.
- Host jobs refuse to run as root. A host drop-in sets the systemd user, and `$INTERNAL` documents it.
- Some values repeat with a pointer comment and a test. Change every copy of the confirm port, the `afframe.tree` label, the root build inputs and the `AFFRAME_HOME` default.
- `AFFRAME_HOME` holds the releases, `current`, the rendered env, TLS, state and the Traefik config. Nothing mounts from a release.
- `log/` in `AFFRAME_HOME` holds the output of infrastructure updates, migrations and failed health checks.
- The host keeps the current and the previous release, and the current and the previous image of each service.

### 6.4 CI and rulesets

- `ci` runs the deploy integration test only when deploy files changed.
- `ci` builds and tests every app when `packages/` or a root workspace file changed.
- `docs/adr/0001-registry-free-deploy.md` records why CI uses no registry.
- `.github/workflows/security.yml` scans the pinned Traefik image and fresh builds of the Postgres image and each deployable service on a schedule.
- `.github/rulesets/main.json` requires PRs, the checks `ci` and `pr-title`, squash merge, linear history and signed commits. `.github/rulesets/README.md` tells how to apply a file.
- `.github/rulesets/tags.json` protects `v*` tags from deletion and force-push, and requires linear history and signed commits.

### 6.5 Values and their source files

`docs/conventions.md` section Configuration lists the configuration sources, the Postgres identity and the schedules.

| Property | Source file |
|---|---|
| Postgres version | `FROM` in `deploy/postgres/Dockerfile` |
| Backup retention | `deploy/compose.prod.yml` |
| Recovery point target | `RPO_HOURS` in `deploy/bin/common.sh` |
| Health thresholds | `deploy/bin/afframe-health` |
| Health passes and timeouts of a deploy | `deploy/bin/afframe-deploy` |
| Runner label | `runs-on` in each workflow, and `scripts/ci/actionlint.yaml` |
| Lint tool versions | `scripts/ci/toolbox/Dockerfile` |
| CVE scanner version | `scripts/ci/trivy/Dockerfile` |
| CodeGraph and pnpm versions | `package.json` |

## 7. Security Considerations

- `scripts/ci/repo-lint.sh` runs gitleaks over the full history.
- GitHub holds only the credentials that the workflows read.
- Workflows use least-privilege `permissions`, actions pinned to a commit SHA and `persist-credentials: false`. actionlint and zizmor check them.
- The Claude review runs only for PRs from this repository.
- The public routers remove the `Server` header.

## 8. Development & Testing Environment

- The local gate works with a remote Docker daemon. The header of `scripts/ci/repo-lint.sh` tells how.
- On a client that is not Linux, `deploy/test/integration.sh` reruns itself in a Linux container on the Docker daemon.
- Each local Conductor workspace runs its own Postgres from `compose.dev.yml`. `scripts/dev/stack.sh` starts and removes it. Cloud workspaces have no dev stack. Archive and merge delete the dev data.
- The repository has no per-PR preview environments.

## 9. Known Limits

- Detection limits of the image scans: `$INTERNAL/security-limits.md`.

## 10. Project Identification

- Repository: https://github.com/afframe/afframe
- License: All Rights Reserved, in `LICENSES/LicenseRef-AllRightsReserved.txt`.

## 11. Glossary

| Term | Meaning |
|---|---|
| deploy host | The one server that the Deploy workflow ships to |
| release | The `deploy/` tree of one commit, unpacked on the deploy host |
| `current` | The release that runs now |
| colour | Blue or green. One container of a service serves, and the idle one takes the next image. |
| `afframe.tree` | An image label with a hash of the git trees of `apps/<name>`, `packages/` and the root workspace files, set by `scripts/ci/build-images.sh` |
