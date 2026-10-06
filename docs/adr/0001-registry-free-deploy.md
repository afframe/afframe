# ADR 0001: Registry-free deploy

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-05 |

## Context

- The deploy must not depend on paid storage or on the visibility of the repository.
- So the project uses no package registry and no Actions artifact storage.
- The deploy must ship the same image that the service tests passed on.
- The deploy host must not pull from GitHub. It needs no git and gets no GitHub credential.

## Decision

- The deploy job builds every deployable service image and runs the service tests on those images.
- The job connects to the deploy host over Tailscale SSH.
- The job streams `git archive <sha> deploy` without `deploy/test` to the host. The host unpacks it as a new release.
- The job streams `docker save` of the tested images into that release. The host loads them with no registry.

## Rejected options

| Option | Reason |
|---|---|
| GitHub Container Registry or Actions artifacts | The project uses neither (Context). |
| A registry on another host | It adds infrastructure to run, patch and protect. |
| Build on the deploy host | The shipped image is then not the image that the tests passed on. |

## Consequences

- Each deploy transfers the full image of every deployable service over the network.
- No copy of old images exists outside the deploy host.
- A move to a registry needs a rework of the deploy job and of `deploy/bin/afframe-deploy`.
