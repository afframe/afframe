# ADR 0003: Single deploy host

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |

## Context

- The current load fits on one server.
- The deploy ships the tested images as `docs/adr/0001-images-streamed-to-deploy-host.md` states.
- A service deploy must not interrupt the service. A failed service deploy must leave the live colour in place.
- The deploy job holds no SSH key for the deploy host.

## Decision

- All services, Traefik and Postgres run on one deploy host. `deploy/compose.prod.yml` defines Traefik and Postgres. `afframe-deploy` starts the service containers.
- Each service has two colours. A deploy starts the idle colour and switches traffic only after its health checks pass.
- Traefik reads its routes only from files. `afframe-deploy` writes one route file per service next to the files of `deploy/traefik/dynamic/`.
- Cloudflare proxies the public host names to Traefik. `deploy/traefik/traefik.yml` trusts forwarded headers only from Cloudflare.
- The deploy job reaches the deploy host over Tailscale SSH. A GitHub OIDC login gives the job access to the tailnet.
- `ARCHITECTURE.md` sections 6.1 and 6.2 give the steps of a deploy and of a rollback.

## Consequences

- One server runs every production container.
- The deploy host is a single point of failure. A host outage stops every service.
- One server limits the capacity. A service cannot scale out to a second host without a rework of `deploy/`.
- A service deploy keeps the service reachable. The old colour runs until Traefik confirms the switch.
- A change to the Traefik or Postgres inputs runs `compose up --build`. It can restart Traefik, Postgres or both. A restart interrupts every service.
- A failure before the switch leaves the old colour live. A migration that ran stays in place.
- A rollback switches back to the previous image with no build.
- During a deploy, both colours of a changed service run. The deploy host needs memory for both, as `MEMORY` in `deploy/services/<name>.conf` sets.
- Each migration must work with the old colour. `AGENTS.md` section Database changes gives the rules.
- Traefik has no Docker socket, so a compromised Traefik cannot control the containers.
