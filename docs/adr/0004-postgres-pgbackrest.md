# ADR 0004: Postgres with pgBackRest

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |

## Context

- The services keep their data in Postgres on the deploy host, as `docs/adr/0003-single-deploy-host.md` states.
- A loss of data must stay inside the recovery point target.
- A backup has value only when a restore from it works.

## Decision

- Postgres runs from `deploy/postgres/Dockerfile`. The image contains pgBackRest.
- Postgres archives each WAL segment to the backup repository through `archive_command` in `deploy/compose.prod.yml`.
- Vault configures the backup repository.
- `afframe-backup` takes full and differential backups. A systemd timer in `deploy/host/systemd/` starts it.
- `afframe-restore-drill` restores the latest backup with WAL into a throwaway container. Its own systemd timer starts it.
- The drill never touches the live database.
- The drill fails when the newest restored data is older than the recovery point target in `deploy/bin/common.sh`.
- `ARCHITECTURE.md` section 4 describes the data stores. Section 6.3 gives the steps of a restore.

## Consequences

- Point-in-time recovery restores the database to any second inside the retention window.
- `archive_timeout` in `deploy/compose.prod.yml` sets the longest time between two archived WAL segments.
- The restore drill proves on a schedule that the backups restore and contain recent data.
- The heartbeat monitor reports each failed backup and each failed drill.
- `deploy/compose.prod.yml` sets the retention of full backups. Older backups and their WAL expire.
- The backup, the drill and the live database use one image, so they use one pgBackRest version.
