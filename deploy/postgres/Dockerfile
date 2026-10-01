# Postgres 18 with pgBackRest for WAL archiving and point-in-time recovery (repo settings come
# from PGBACKREST_* environment variables). The official image already has the PGDG apt repository.
# Runs as the postgres user from the start (data in a named volume it owns), so gosu, the image's
# root-to-postgres switcher, is removed; Debian packages are upgraded for current security fixes.
FROM postgres:18@sha256:5a5a84b19854a9ffaa54082c166ff4ec27473a361e496e5ea167f298f2da9722
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends pgbackrest \
  && rm -rf /var/lib/apt/lists/* /usr/local/bin/gosu \
  && mkdir -p /var/lib/pgbackrest \
  && chown postgres:postgres /var/lib/pgbackrest
USER postgres
