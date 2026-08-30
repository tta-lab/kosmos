# PostgreSQL 18 with the exact extensions required by the Hindsight migration.
#
# The PGroonga image supplies PostgreSQL and the PGDG apt repository. Keep the
# digest and package version together: changing either one is a stack-version
# change in scripts/build-hindsight-images and in the rendered manifests.
FROM docker.io/groonga/pgroonga:4.0.8-debian-18@sha256:882e6921e9b1e44a8d477dc1e6c4e005ff4c2655c06ef5581a0bd0e92d746770

ARG PGVECTOR_PACKAGE_VERSION=0.8.6-1.pgdg13+1

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      "postgresql-18-pgvector=${PGVECTOR_PACKAGE_VERSION}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# PGroonga's WAL resource manager keeps its WAL stream available to PostgreSQL
# recovery. pgroonga_crash_safer is the documented single-node crash-safer
# preload; both are intentionally enabled in this retained database image.
RUN printf '%s\n' \
      "shared_preload_libraries = 'pgroonga_wal_resource_manager,pgroonga_crash_safer'" \
      'pgroonga.enable_wal = on' \
    >> /usr/share/postgresql/18/postgresql.conf.sample

COPY 10-hindsight-extensions.sql /docker-entrypoint-initdb.d/10-hindsight-extensions.sql

LABEL org.opencontainers.image.title="kosmos-hindsight-postgres" \
      org.opencontainers.image.version="0.1.1" \
      org.opencontainers.image.description="PostgreSQL 18 with PGroonga 4.0.8 and pgvector 0.8.6 for Hindsight 0.9.2" \
      org.opencontainers.image.source="https://github.com/tta-lab/kosmos"
