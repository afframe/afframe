FROM postgres:18@sha256:5a5a84b19854a9ffaa54082c166ff4ec27473a361e496e5ea167f298f2da9722
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
  && apt-get install -y --no-install-recommends pgbackrest \
  && rm -rf /var/lib/apt/lists/* /usr/local/bin/gosu \
  && mkdir -p /var/lib/pgbackrest \
  && chown postgres:postgres /var/lib/pgbackrest
USER postgres
