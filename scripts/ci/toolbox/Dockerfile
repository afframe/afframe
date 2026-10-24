# Built without a context: no COPY from the repository.
FROM rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667 AS actionlint
FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck
FROM ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f AS gitleaks
FROM ghcr.io/zizmorcore/zizmor:1.31.1@sha256:42d409dbb851d4c5d35a058cf042b828bea1e3f2884378c526eb0974780e18d9 AS zizmor
FROM ghcr.io/jqlang/jq:1.8.2@sha256:b9c68867e5766576263a222e91db3de422d802069c7af70440e667a95344e486 AS jq
FROM docker/compose-bin:v5.6.1@sha256:2aeaeedd4f2d8e2dcb399b2b9723bfaeb6714140cb0657897f5865960f1624ae AS compose

# The base gives repo-lint.sh bash 5, git and Linux coreutils.
FROM buildpack-deps:resolute-scm@sha256:29b1b636c37d7fa0e97bb4ff90357a9fc7ca5d5cc903d9982f73ac104c0e9fa0
COPY --from=actionlint /usr/local/bin/actionlint /usr/local/bin/
COPY --from=shellcheck /bin/shellcheck /usr/local/bin/
COPY --from=gitleaks /usr/bin/gitleaks /usr/local/bin/
COPY --from=zizmor /usr/bin/zizmor /usr/local/bin/
COPY --from=jq /jq /usr/local/bin/
COPY --from=compose /docker-compose /usr/local/bin/
ENV AFFRAME_TOOLBOX=1
USER ubuntu
