#!/bin/sh
# Kabso Live — local docker compose only (mounted into /docker-entrypoint-initdb.d).
#
# Runs ONCE, when the postgres container starts with an empty data volume, as POSTGRES_USER (the
# local admin). Creates the least-privilege role layout (SEC-011 / KL-013, KL-013b) in the dev
# database and in a separate *_test database for the e2e suite. Role names and passwords come from
# the KABSO_DB_* environment variables (docker-compose.yml, overridable from .env). Each database
# gets its own runtime login (KABSO_DB_APP_USER for the dev database, KABSO_DB_APP_TEST_USER for
# the test database); the migration role is shared, which KABSO_DB_ENV=development allows.
#
# An existing volume is not touched; recreate it (`docker compose down -v`) or run
# infra/postgres/bootstrap-roles.sql by hand (docs/DEPLOYMENT.md §5.1).
set -eu

BOOTSTRAP_SQL="${KABSO_BOOTSTRAP_SQL:-/kabso/bootstrap-roles.sql}"
TEST_DB="${KABSO_TEST_DB:-kabso_test}"

for db in "$POSTGRES_DB" "$TEST_DB"; do
  if [ "$db" != "$POSTGRES_DB" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
      --set=db="$db" <<'SQL'
SELECT format('CREATE DATABASE %I', :'db')
 WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db') \gexec
SQL
  fi
  if [ "$db" = "$POSTGRES_DB" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" -f "$BOOTSTRAP_SQL"
  else
    KABSO_DB_APP_USER="${KABSO_DB_APP_TEST_USER:-${KABSO_DB_APP_USER}_test}" \
    KABSO_DB_APP_PASSWORD="${KABSO_DB_APP_TEST_PASSWORD:-$KABSO_DB_APP_PASSWORD}" \
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" -f "$BOOTSTRAP_SQL"
  fi
done
