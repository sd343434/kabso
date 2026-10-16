#!/bin/sh
# Kabso Live — local docker compose only (mounted into /docker-entrypoint-initdb.d).
#
# Runs ONCE, when the postgres container starts with an empty data volume, as POSTGRES_USER (the
# local admin). Creates the least-privilege role layout (SEC-011 / KL-013) in the dev database and
# in a separate *_test database for the e2e suite. Role names and passwords come from the
# KABSO_DB_* environment variables (docker-compose.yml, overridable from .env).
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
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" -f "$BOOTSTRAP_SQL"
done
