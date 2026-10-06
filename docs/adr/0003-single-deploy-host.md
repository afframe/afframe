# ADR 0003: Single deploy host

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |

## Context

- The current load fits on one server.
- The deploy ships the tested images as `docs/adr/0001-registry-free-deploy.md` states.
- A deploy must not interrupt a service. A failed deploy must leave the live version in place.
- The deploy job must reach the deploy host without a public SSH port.

## Decision

- All services, Traefik and Postgres run on one deploy host with Docker Compose from `deploy/compose.prod.yml`.
- Each service has two colours. A deploy starts the idle colour and switches traffic only after its health checks pass.
- Traefik reads its routes from files in `deploy/traefik/dynamic/`. `afframe-deploy` writes the route file of each service.
- Cloudflare proxies all public traffic to Traefik. `deploy/traefik/traefik.yml` trusts forwarded headers only from Cloudflare.
- The deploy job reaches the deploy host over Tailscale SSH. A GitHub OIDC login gives the job access to the tailnet.
- `ARCHITECTURE.md` sections 6.1 and 6.2 give the steps of a deploy and of a rollback.

## Consequences

- One server, one Compose project and one set of host commands hold the full production system.
- The deploy host is a single point of failure. A host outage stops every service.
- One server limits the capacity. A service cannot scale out to a second host without a rework of `deploy/`.
- A deploy causes no downtime. The old colour serves traffic until Traefik confirms the switch.
- A failed deploy changes nothing that users see. A rollback switches back to the previous image with no build.
- During a deploy, both colours of a changed service run. The deploy host needs memory for both, as `MEMORY` in `deploy/services/<name>.conf` sets.
- Each migration must work with the old colour. `AGENTS.md` section Database changes gives the rules.
- Traefik has no Docker socket, so a compromised Traefik cannot control the containers.
