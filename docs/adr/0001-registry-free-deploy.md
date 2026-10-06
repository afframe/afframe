# ADR 0001: Registry-free deploy

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-05 |

## Context

- The deploy must not depend on paid storage or on the visibility of the repository.
- The deploy must ship the same image that the service tests passed on.
- The deploy host must not pull from GitHub. It needs no git and gets no GitHub credential.

## Decision

- The deploy job builds every deployable service image and runs the service tests on those images.
- The job connects to the deploy host over Tailscale SSH.
- The job streams `git archive <sha> deploy` without `deploy/test` to the host. The host unpacks it as a new release.
- The job streams `docker save` of the tested images into that release. The host loads them with no registry.

## Consequences

- The images travel only from the deploy job to the deploy host. No other host stores them.
- The project runs, patches and protects no image store.
- The deploy host builds no service image. It runs the images that the service tests passed on.
- Each deploy transfers the full image of every deployable service over the network.
- No copy of old images exists outside the deploy host.
- The image transfer lives in the deploy job and in `deploy/bin/afframe-deploy`. A change of the transfer reworks both.
