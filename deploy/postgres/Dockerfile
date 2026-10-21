FROM postgres:18@sha256:edb0c08dc33befd0262ab3b5cf1c4f3f8cfd8b09e88c05b45adee29d6761ddb6
ENV POSTGRES_USER=afframe \
  POSTGRES_DB=afframe \
  PGBACKREST_STANZA=afframe \
  PGBACKREST_PG1_PATH=$PGDATA \
  PGBACKREST_PG1_USER=afframe \
  PGBACKREST_LOG_PATH=/tmp \
  PGBACKREST_LOCK_PATH=/tmp/pgbackrest
# Runs as postgres from the start, so gosu goes.
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends ca-certificates pgbackrest \
  && rm -rf /var/lib/apt/lists/* /usr/local/bin/gosu \
  && mkdir -p /var/lib/pgbackrest \
  && chown postgres:postgres /var/lib/pgbackrest
USER postgres
