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

- Postgres runs on the deploy host from `deploy/postgres/Dockerfile`. The services reach it on the internal network `db`.
- Postgres also joins the network `egress` to reach the backup repository. It publishes no ports.
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

### 6.3 Restore the database

- Run the host commands on the deploy host as the user of the host jobs. `$INTERNAL/afframe-deploy.md` describes the host.
- Export `AFFRAME_HOME` in the shell with the value that the host jobs use.
- Run the `gh` commands on a workstation.
- `deploy/test/integration.sh` runs the first procedure on its test stack.

#### Restore the running host to a point in time

1. Wait until no Deploy run is in progress. Note the value of `DEPLOY_ENABLED`. Then stop the deploys and the host jobs:

   ```sh
   gh variable get DEPLOY_ENABLED --repo afframe/afframe
   gh variable set DEPLOY_ENABLED --body false --repo afframe/afframe
   sudo systemctl stop afframe-backup.timer afframe-health.timer afframe-restore-drill.timer
   ```

2. Archive the current WAL and list the backups. The target time must be after the end of the oldest backup.

   ```sh
   docker exec afframe-postgres pgbackrest check
   docker exec afframe-postgres pgbackrest info
   ```

3. Stop Postgres. The services get database errors until step 5 ends. A shorter timeout can kill Postgres, and the restore then refuses the data.

   ```sh
   docker stop --time 120 afframe-postgres
   ```

4. Restore to the target time. Give the time with its UTC offset. pgBackRest selects the newest backup before the target.

   ```sh
   docker run --rm --env-file "$AFFRAME_HOME/env/infra.env" \
     -v afframe-postgres-data:/var/lib/postgresql -v afframe-pgbackrest:/var/lib/pgbackrest \
     afframe-postgres:local sh -c 'mkdir -m 700 -p "$PGBACKREST_PG1_PATH" && exec pgbackrest restore "$@"' sh \
     --delta --type=time --target-action=promote --target='2026-10-06 09:30:00+00'
   ```

5. Start Postgres and wait until the recovery ends. `docker logs afframe-postgres` shows the progress. If the loop does not end, stop it and read the log.

   ```sh
   docker start afframe-postgres
   until [ "$(docker exec afframe-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select pg_is_in_recovery()"' 2> /dev/null)" = f ]; do sleep 5; done
   ```

6. If Postgres stops with "recovery ended before configured recovery target was reached", the archive has no WAL after the target. Do steps 3 to 5 again with an earlier target.
7. Examine the data. Then take a full backup on the new timeline:

   ```sh
   "$AFFRAME_HOME/current/deploy/bin/afframe-backup" full
   ```

8. Start the host jobs. Set `DEPLOY_ENABLED` to the value from step 1:

   ```sh
   sudo systemctl start afframe-backup.timer afframe-health.timer afframe-restore-drill.timer
   gh variable set DEPLOY_ENABLED --body '<value from step 1>' --repo afframe/afframe
   ```

#### Restore onto a rebuilt host

The first release starts Postgres and creates the stanza. `stanza-create` needs a primary, and it must find the restored database. Thus the restore runs before the first deploy, and the recovery ends before it.

1. Do the host setup in `$INTERNAL/afframe-deploy.md`. Do not run a deploy. If the host setup started the timers, stop them as in step 1 of the first procedure.
2. Copy the `deploy/` folder of `main` to the host. On a workstation, in a checkout of `main`:

   ```sh
   git archive HEAD deploy | ssh <deploy host> 'mkdir -p afframe-restore && tar -x -C afframe-restore'
   ```

3. On the host, render the credentials. Then build the Postgres image and create its container and volumes. Compose does not start Postgres.

   ```sh
   ~/afframe-restore/deploy/bin/vault-env
   docker compose -p afframe -f ~/afframe-restore/deploy/compose.prod.yml up --no-start --build postgres
   ```

4. Do step 4 of the first procedure without the options `--type`, `--target` and `--target-action`. pgBackRest then restores the newest backup and all archived WAL.
5. Do step 5 of the first procedure.
6. Turn on the deploys and run the Deploy workflow. The first release takes over the restored Postgres, and `stanza-create` accepts it.
7. Take a full backup and start the timers, as in steps 7 and 8 of the first procedure.

### 6.4 Facts that prevent wrong changes

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

### 6.5 CI and rulesets

- `ci` runs the deploy integration test only when deploy files changed.
- `ci` builds and tests every app when `packages/` or a root workspace file changed.
- `docs/adr/0001-registry-free-deploy.md` records why CI uses no registry.
- `.github/workflows/security.yml` scans the pinned Traefik image and fresh builds of the Postgres image and each deployable service on a schedule.
- `.github/rulesets/main.json` requires PRs, the checks `ci` and `pr-title`, squash merge, linear history and signed commits. `scripts/ci/rulesets.sh` compares them with GitHub or applies them. A merge does not apply them. The squash commit title setting stays `PR_TITLE`, because the `pr-title` check validates the PR title.
- `.github/rulesets/tags.json` protects `v*` tags from deletion and force-push, and requires linear history and signed commits.

### 6.6 Values and their source files

`docs/conventions.md` section Configuration lists the configuration sources, the Postgres identity and the schedules.

| Property | Source file |
|---|---|
| Postgres version | `FROM` in `deploy/postgres/Dockerfile` |
| Backup retention | `deploy/compose.prod.yml` |
| Recovery point target | `RPO_HOURS` in `deploy/bin/common.sh` |
| Health thresholds | `deploy/bin/afframe-health` |
| Health passes and timeouts of a deploy | `deploy/bin/afframe-deploy` |
| Runner label | `runs-on` in each workflow, and the actionlint `-ignore` in `scripts/ci/repo-lint.sh` |
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
- License: All Rights Reserved, in `LICENSE`.

## 11. Glossary

| Term | Meaning |
|---|---|
| deploy host | The one server that the Deploy workflow ships to |
| release | The `deploy/` tree of one commit, unpacked on the deploy host |
| `current` | The release that runs now |
| colour | Blue or green. One container of a service serves, and the idle one takes the next image. |
| `afframe.tree` | An image label with a hash of the git trees of `apps/<name>`, `packages/` and the root workspace files, set by `scripts/ci/build-images.sh` |
