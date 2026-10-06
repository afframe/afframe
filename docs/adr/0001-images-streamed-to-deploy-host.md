# ADR 0001: Images streamed to the deploy host

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
- The job streams `docker save` of the tested images to `afframe-deploy` of that release. `afframe-deploy` loads them with `docker load`.

## Consequences

- The images travel from the deploy job to the deploy host. The GitHub Actions cache keeps their build layers for later builds.
- The deploy host runs the images that the service tests passed on.
- Each deploy transfers the full image of every deployable service over the network.
- The deploy host holds the only runnable copy of the current and the previous image of each service.
- The image transfer lives in the deploy job and in `deploy/bin/afframe-deploy`. A change of the transfer reworks both.
