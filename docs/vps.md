# afframe-vps runbook

Production for Afframe runs on one Hostinger KVM 2 VPS (`afframe-vps`, Ubuntu 24.04 LTS, amd64). This repo holds everything that runs there; the host itself is set up by hand once (section "Host setup"). Secrets live in Vault on oracle-vps, never in this repo or in GitHub.

## What runs

| Part | How | Defined in |
|---|---|---|
| Traefik v3.7 | compose project `afframe`, ports 80/443, routes from files only (no Docker socket) | `deploy/compose.prod.yml`, `deploy/traefik/` |
| Postgres 18 + pgBackRest | compose project `afframe`, internal network `afframe-db` only, WAL archived to Cloudflare R2 | `deploy/compose.prod.yml`, `deploy/postgres/Dockerfile` |
| App services | blue/green containers `afframe-<service>-<blue|green>` on `afframe-edge` + `afframe-db`, image by digest from GHCR | `deploy/services/<service>.env`, `apps/<service>/` |
| Backups | `afframe-backup.timer` daily 02:30 UTC (full on Sundays, diff otherwise), 4 full backups kept | `deploy/bin/afframe-backup`, `deploy/host/systemd/` |
| Nightly dump | `afframe-dump.timer` 01:30 UTC: `pg_dump` + roles, rclone-crypt encrypted, to `dumps/` in the same bucket, read back and checked with `pg_restore --list`, 30 days kept | `deploy/bin/afframe-dump` |
| Health | `afframe-health.timer` every 5 min: disk, memory, containers, backup age, WAL archiving | `deploy/bin/afframe-health` |
| Restore drill | `afframe-restore-drill.timer` on the 1st of each month: full restore into a throwaway container | `deploy/bin/afframe-restore-drill` |

Better Stack (free plan) receives four heartbeats (backup, dump, health, drill), checks `https://afframe.com/health` from outside and hosts the status page. A missing or failed heartbeat raises the alert.

Host layout, all owned by the `deploy` user:

```
/srv/afframe/
├── repo/                 # checkout of this repo, moved to the deployed commit by afframe-deploy
├── env/infra.env         # rendered from Vault secret/afframe/prod/infra (600)
├── env/app.env           # rendered from Vault secret/afframe/prod/app (600)
├── tls/origin.{crt,key}  # Cloudflare Origin CA certificate, from Vault
├── traefik/dynamic/      # tls.yml + one route file per service, written by afframe-deploy
├── state/<service>       # current image, colour, previous image
└── dumps/                # only with a posix pgBackRest repo (tests); in production dumps go to R2
```

Postgres data lives in the Docker volume `afframe-postgres-data`, pgBackRest's working directory in `afframe-pgbackrest`. Never run `docker compose down -v` on afframe-vps: it deletes both.

## Deploy

Every push to `main` runs `.github/workflows/deploy.yml`: the no-deploy gate, `deploy-services.sh` (services whose `apps/<name>/` or manifest changed; everything on a manual run), a build to `ghcr.io/afframe/afframe/<service>:sha-<sha>` with a provenance attestation, then `afframe-deploy` over Tailscale SSH. Docs-only merges build and deploy nothing.

GitHub configuration (no secrets):

| Where | Name | Value |
|---|---|---|
| Repository variable | `AFFRAME_VPS_ENABLED` | `true` once the host is ready; anything else skips the deploy job |
| Environment `production` (branch `main` only), variables | `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE` | Tailscale federated identity client for `repo:afframe/afframe:environment:production` |
| | `DEPLOY_HOST` | tailnet name of afframe-vps |

The GHCR packages `afframe/<service>` stay private. The deploy job pipes its own short-lived `GITHUB_TOKEN` (`packages: read`) to `afframe-deploy` on stdin, which logs in only for the pulls, in a throwaway Docker config; nothing is stored on the host. The current and previous image of each service stay on the host, so a rollback needs no registry access.

`afframe-deploy deploy <git-sha> [<service>=ghcr.io/afframe/afframe/<service>@sha256:<digest> ...]`, run as `deploy`:

1. Fetches `origin/main` and checks out `<git-sha>` (refused unless it is on `main`).
2. Renders secrets from Vault (`deploy/bin/vault-env`), copies `deploy/traefik/dynamic/`.
3. `docker compose up -d --wait` for Traefik and Postgres; `pgbackrest stanza-create` (idempotent).
4. Per service: pull by digest, run `MIGRATE` from the manifest in the new image (abort on failure), start the idle colour, wait for `GET /health`, point the Traefik route at it, remove the old colour.

A failed migration or health check exits non-zero and traffic stays on the running container. Only images from `ghcr.io/afframe/afframe/<service>` are accepted. One deploy at a time (`flock`).

Rollback to the previous image (no migrations, no checkout):

```
tailscale ssh deploy@afframe-vps /srv/afframe/repo/deploy/bin/afframe-deploy rollback placeholder
```

Add a service: `apps/<name>/Dockerfile` (service contract in `CLAUDE.md`) plus `deploy/services/<name>.env` with `HOST`, `PORT`, `MEMORY` and optional `MIGRATE`; then a Cloudflare DNS record for `HOST`.

## Secrets (Vault on oracle-vps, KV v2 mount `secret`)

`secret/afframe/prod/infra`:

| Key | Value |
|---|---|
| `POSTGRES_PASSWORD` | superuser password of the `afframe` role |
| `PGBACKREST_REPO1_TYPE` | `s3` |
| `PGBACKREST_REPO1_PATH` | `/afframe` |
| `PGBACKREST_REPO1_S3_BUCKET` | the R2 bucket |
| `PGBACKREST_REPO1_S3_ENDPOINT` | `<account id>.r2.cloudflarestorage.com` |
| `PGBACKREST_REPO1_S3_REGION` | `auto` |
| `PGBACKREST_REPO1_S3_URI_STYLE` | `path` |
| `PGBACKREST_REPO1_S3_KEY`, `PGBACKREST_REPO1_S3_KEY_SECRET` | R2 token scoped to the bucket (object read and write) |
| `PGBACKREST_REPO1_CIPHER_TYPE` | `aes-256-cbc` |
| `PGBACKREST_REPO1_CIPHER_PASS` | long random passphrase; also keep a copy outside oracle-vps (Keychain), or a lost oracle-vps makes the backups unreadable |
| `ORIGIN_CERT_PEM`, `ORIGIN_KEY_PEM` | Cloudflare Origin CA certificate and key for `afframe.com` and `*.afframe.com` |
| `DUMP_CRYPT_PASSWORD` | rclone crypt password for the nightly dumps; keep a copy outside oracle-vps too |
| `BETTERSTACK_BACKUP_HEARTBEAT`, `BETTERSTACK_DUMP_HEARTBEAT`, `BETTERSTACK_HEALTH_HEARTBEAT`, `BETTERSTACK_DRILL_HEARTBEAT` | heartbeat URLs |

`secret/afframe/prod/app`: the runtime environment of the app containers (for example `DATABASE_URL`). Values are single-line; `*_PEM` keys are not passed to containers. Nothing secret goes into image builds.

The host reads Vault with a read-only token for `secret/data/afframe/prod/*`, stored in `/etc/afframe/vault.env` (`VAULT_ADDR`, `VAULT_TOKEN`).

## Backups and point-in-time recovery

- Manual backup: `/srv/afframe/repo/deploy/bin/afframe-backup full`; manual dump: `/srv/afframe/repo/deploy/bin/afframe-dump`.
- A dump is the fallback when pgBackRest itself is unusable, and the way to copy data elsewhere: fetch it with rclone using the same `dumps` crypt remote as the script (settings in `afframe-dump`), then `pg_restore -d <database> afframe-<stamp>.dump` after `psql -f globals-<stamp>.sql`.
- State: `docker exec -u postgres afframe-postgres pgbackrest info`.
- Restore production to a point in time (stops the database; take a Hostinger snapshot first):

```
docker stop afframe-postgres
docker run --rm -u postgres --env-file /srv/afframe/env/infra.env \
  -e PGBACKREST_STANZA=afframe -e PGBACKREST_PG1_PATH=/var/lib/postgresql/18/docker -e PGBACKREST_PG1_USER=afframe \
  -e PGBACKREST_LOG_PATH=/tmp -e PGBACKREST_LOCK_PATH=/tmp/pgbackrest \
  -v afframe-postgres-data:/var/lib/postgresql afframe-postgres:local \
  pgbackrest restore --delta --type=time --target="2026-10-01 12:00:00+00" --target-action=promote
docker start afframe-postgres
```

Hostinger's weekly VM backups and its single snapshot are not a database backup; pgBackRest is.

## Host setup (one time, by hand)

1. Hostinger: reinstall with plain **Ubuntu 24.04 LTS**; hPanel firewall: allow 80 and 443, UDP 41641 (Tailscale); nothing else.
2. Base: automatic security updates (`unattended-upgrades`), time sync, a 2 to 4 GB swap file with `vm.swappiness=10`; remove Monarx if Hostinger installed it.
3. SSH: keys only, `PermitRootLogin no`, `PasswordAuthentication no`. Tailscale with `tailscale set --ssh`; close public port 22 once Tailscale SSH works.
4. Docker Engine and the compose plugin (2.30 or newer) from Docker's apt repository. `/etc/docker/daemon.json`: `{"log-driver": "local", "live-restore": true}`.
5. Firewall: Docker bypasses UFW, so restrict 80/443 to Cloudflare's ranges in the `DOCKER-USER` chain (iptables-nft).
6. `apt install git curl jq`; user `deploy` in group `docker`; `/srv/afframe` owned by `deploy`; `git clone https://github.com/afframe/afframe /srv/afframe/repo` as `deploy`.
7. `/etc/afframe/vault.env` (`root:deploy`, mode 640) with `VAULT_ADDR` (oracle-vps over the tailnet) and the read-only `VAULT_TOKEN`.
8. Systemd: copy `deploy/host/systemd/*` to `/etc/systemd/system/`, `systemctl daemon-reload`, `systemctl enable --now afframe-backup.timer afframe-dump.timer afframe-health.timer afframe-restore-drill.timer`.
9. Tailscale ACL: tag `tag:ci-afframe` may SSH to `afframe-vps` as `deploy` only; a federated identity (OIDC) client for GitHub limited to `repo:afframe/afframe:environment:production` that can mint `tag:ci-afframe` keys.
10. Cloudflare: `afframe.com` proxied to the VPS, SSL mode Full (strict), Origin CA certificate into Vault; R2 bucket for pgBackRest with a bucket-scoped token.
11. Better Stack: monitor `https://afframe.com/health`, four heartbeats (backup and dump: 1 day + 2 h grace; health: 5 min + 5 min grace; drill: 31 days + 1 day grace), status page.

## Tests

- `bash deploy/test/afframe-deploy.test.sh`: fast, fake `docker` and `git`; part of the gate.
- `bash deploy/test/integration.sh`: the whole stack on a local Docker daemon (Vault dev server, local registry, deploy, failed health check, rollback, backup, health, dump, restore drill). Nightly and on PRs that touch `deploy/` (`Deploy integration` workflow, advisory). Never on afframe-vps.
