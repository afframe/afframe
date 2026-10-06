# Built without a context: no COPY from the repository.
FROM rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667 AS actionlint
FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck
FROM ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f AS gitleaks
FROM ghcr.io/zizmorcore/zizmor:1.30.1@sha256:a2eb396d886c053073405c7a980f2139ba2248ec172243cfa3841e57196e8101 AS zizmor
FROM ghcr.io/jqlang/jq:1.8.2@sha256:b9c68867e5766576263a222e91db3de422d802069c7af70440e667a95344e486 AS jq
FROM docker/compose-bin:v5.5.1@sha256:14162382692aae43977f79effa64a499d61de19d4645461881daaf88773f7e74 AS compose

# The base gives repo-lint.sh bash 5, git and Linux coreutils.
FROM buildpack-deps:resolute-scm@sha256:48d8a278de4e64c536a1d376c9f7a3058e349122bd5ec650dff711219b57282b
COPY --from=actionlint /usr/local/bin/actionlint /usr/local/bin/
COPY --from=shellcheck /bin/shellcheck /usr/local/bin/
COPY --from=gitleaks /usr/bin/gitleaks /usr/local/bin/
COPY --from=zizmor /usr/bin/zizmor /usr/local/bin/
COPY --from=jq /jq /usr/local/bin/
COPY --from=compose /docker-compose /usr/local/bin/
ENV AFFRAME_TOOLBOX=1
USER ubuntu
