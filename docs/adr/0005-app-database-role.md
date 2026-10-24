# ADR 0005: Services connect as a limited database role

| Property | Value |
|---|---|
| Date | 2026-10-24 |

## Context

- The services and their migrations share one Postgres on the deploy host, as `docs/adr/0004-postgres-pgbackrest.md` states.
- The `POSTGRES_USER` of `deploy/postgres/Dockerfile` is a superuser. The backups, the restore drill and the heartbeat sentinel depend on it.
- A service that connects as a superuser can read and change every schema, the roles and the server settings.

## Decision

- Services and migrations connect as the role `afframe_app`. It is a login role with no superuser, `CREATEDB` or `CREATEROLE` attribute.
- `afframe_app` has `CONNECT` and `TEMP` on the database, and `USAGE` and `CREATE` on the schema `public`. It owns the objects that migrations create.
- The schema `ops` stays with the superuser. `afframe_app` has no grant on it.
- The password of `afframe_app` has one source: a key in the infra secret in Vault.
- `deploy/bin/vault-env` derives `DATABASE_URL` from that password, the Postgres container name and the database name. It renders the URL into the app env.
- `afframe-deploy` creates the role on each deploy and sets the password again. It does this before the migrations run.

## Consequences

- A compromised service cannot read the backup sentinel, change roles or read files through the server.
- A password rotation needs one Vault change and one deploy. The deploy recreates Postgres, because the infra env changed.
- A missing password stops the deploy before it renders the env files.
- A migration that needs a superuser fails in the deploy. CI connects as the superuser, so it does not find this.
- The app secret in Vault cannot set `DATABASE_URL`. The derived URL replaces it.
