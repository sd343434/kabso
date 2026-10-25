#!/usr/bin/env bash
# Kabso Live — automatic update (KL-069, docs/DEPLOYMENT.md §11). Run by kabso-update.timer every
# 5 minutes, and once by install.sh with --force.
#
# 1. fast-forwards /opt/kabso to origin/$KABSO_BRANCH (compose file, Caddyfile, initdb);
# 2. pulls the API image CI published for that branch ($KABSO_API_IMAGE, only after CI is green);
# 3. when either changed, or the running API is not on the pulled image yet: runs `prisma migrate
#    deploy` as the migration role, then restarts the services whose image or configuration
#    changed. A failed migration stops here and the running API keeps serving
#    (docs/DEPLOYMENT.md §5); the next run tries again, because the API is still on the old image.
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

# The image the running API container was started from (empty when it is not running).
api_container=$("${C[@]}" ps -q api)
running_image=$( [ -n "$api_container" ] && docker inspect -f '{{.Image}}' "$api_container" 2>/dev/null || true)

if [ "${1:-}" != "--force" ] && [ "$before" = "$after" ] && [ "$old_image" = "$new_image" ] &&
  [ "$running_image" = "$new_image" ]; then
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
