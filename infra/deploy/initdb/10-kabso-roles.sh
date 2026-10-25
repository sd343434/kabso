#!/bin/sh
# Kabso Live — server deployment only (infra/deploy, KL-069). Mounted into
# /docker-entrypoint-initdb.d, so it runs ONCE, on the first start with an empty data volume, as
# POSTGRES_USER (the local admin). Creates the least-privilege role layout (SEC-011, KL-013b) in
# the one application database with infra/postgres/bootstrap-roles.sql. KABSO_DB_ENV=production:
# the passwords in /etc/kabso/postgres.env are SCRAM-SHA-256 verifiers, never clear text
# (install.sh computes them with infra/postgres/scram-verifier.mjs).
set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -f "${KABSO_BOOTSTRAP_SQL:-/kabso/bootstrap-roles.sql}"
