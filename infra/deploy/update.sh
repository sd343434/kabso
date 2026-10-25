#!/usr/bin/env bash
# Kabso Live — automatic update (KL-069, docs/DEPLOYMENT.md §11). Run by kabso-update.timer every
# 5 minutes, and once by install.sh with --force.
#
# 1. fast-forwards /opt/kabso to origin/$KABSO_BRANCH (compose file, Caddyfile, initdb);
# 2. pulls the API image CI published for that branch ($KABSO_API_IMAGE, only after CI is green);
# 3. when either changed: runs `prisma migrate deploy` as the migration role, then restarts the
#    services whose image or configuration changed. A failed migration stops here and the running
#    API keeps serving (docs/DEPLOYMENT.md §5).
set -euo pipefail

APP_DIR=/opt/kabso
cd "$APP_DIR"
set -a; . /etc/kabso/kabso.env; set +a

# Lets `docker compose -f infra/deploy/docker-compose.yml ...` work by hand too (compose reads
# .env from the project directory; git ignores it).
ln -sfn /etc/kabso/kabso.env infra/deploy/.env

exec 9>/run/kabso-update.lock
flock -n 9 || { echo "another update is running"; exit 0; }

C=(docker compose -f infra/deploy/docker-compose.yml)

before=$(git rev-parse HEAD)
git fetch -q origin "$KABSO_BRANCH"
git merge -q --ff-only "origin/$KABSO_BRANCH"
after=$(git rev-parse HEAD)

old_image=$(docker image inspect -f '{{.Id}}' "$KABSO_API_IMAGE" 2>/dev/null || true)
docker pull -q "$KABSO_API_IMAGE" >/dev/null
new_image=$(docker image inspect -f '{{.Id}}' "$KABSO_API_IMAGE")

if [ "${1:-}" != "--force" ] && [ "$before" = "$after" ] && [ "$old_image" = "$new_image" ] &&
  [ -n "$("${C[@]}" ps -q api)" ]; then
  exit 0
fi

echo "deploying commit ${after:0:12}, API image ${new_image#sha256:}"
"${C[@]}" up -d --wait postgres redis
"${C[@]}" --profile jobs run --rm migrate
"${C[@]}" up -d --remove-orphans

for _ in $(seq 1 30); do
  if "${C[@]}" exec -T api node -e "fetch('http://127.0.0.1:3000/health/ready').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))" 2>/dev/null; then
    echo "API ready"
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 2
done
echo "API did not become ready; recent logs:" >&2
"${C[@]}" logs --tail 50 api >&2
exit 1
