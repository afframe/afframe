# Postgres 18 with pgBackRest for WAL archiving and point-in-time recovery (repo settings come
# from PGBACKREST_* environment variables). The official image already has the PGDG apt repository.
FROM postgres:18
RUN apt-get update \
  && apt-get install -y --no-install-recommends pgbackrest \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /var/lib/pgbackrest \
  && chown postgres:postgres /var/lib/pgbackrest
