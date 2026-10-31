#!/usr/bin/env bash
# Kabso Live — builds the admin panel (apps/admin, D191, CONVENTIONS §10.54.7) into infra/deploy/admin/current, which
# Caddy serves at admin.$KABSO_DOMAIN. Run by update.sh when apps/admin, the lockfile or the fonts changed (or the
# build is missing); by hand: `sudo /opt/kabso/infra/deploy/build-admin.sh`.
#
# The build runs in the same pinned Node image as the API (apps/api/Dockerfile NODE_IMAGE) on a copy of only what it
# needs; the checkout stays untouched (no node_modules on the server). The new build replaces the old one with two
# renames inside the directory Caddy mounts, so the panel is never half-written.
set -euo pipefail

APP_DIR=${APP_DIR:-/opt/kabso}
OUT_DIR="$APP_DIR/infra/deploy/admin"
cd "$APP_DIR"

stamp=$(git rev-parse HEAD:apps/admin HEAD:pnpm-lock.yaml HEAD:apps/mobile/assets/fonts | sha256sum | cut -c1-16)
if [ "${1:-}" != "--force" ] && [ -f "$OUT_DIR/current/.build-stamp" ] &&
  [ "$(cat "$OUT_DIR/current/.build-stamp")" = "$stamp" ]; then
  exit 0
fi

node_image=$(sed -n 's/^ARG NODE_IMAGE=//p' apps/api/Dockerfile)
[ -n "$node_image" ] || { echo "NODE_IMAGE not found in apps/api/Dockerfile" >&2; exit 1; }

mkdir -p "$OUT_DIR"
next="$OUT_DIR/.next"
rm -rf "$next" && mkdir -p "$next"
echo "building the admin panel ($stamp) with $node_image"
docker run --rm \
  -v "$APP_DIR":/repo:ro -v "$next":/out \
  -e CI=true \
  "$node_image" sh -euc '
    mkdir -p /w/apps/api /w/apps/mobile/assets && cd /w
    cp /repo/package.json /repo/pnpm-lock.yaml /repo/pnpm-workspace.yaml .
    cp /repo/apps/api/package.json apps/api/
    cp -r /repo/apps/admin apps/
    cp -r /repo/apps/mobile/assets/fonts apps/mobile/assets/
    rm -rf apps/admin/node_modules apps/admin/dist
    corepack enable >/dev/null && corepack install >/dev/null
    pnpm install --frozen-lockfile --ignore-scripts --filter @kabso/admin >/dev/null
    pnpm --filter @kabso/admin build
    cp -r apps/admin/dist/. /out/
    chmod -R a+rX /out'
echo "$stamp" > "$next/.build-stamp"
[ -f "$next/index.html" ] || { echo "the build has no index.html" >&2; exit 1; }
if [ -d "$OUT_DIR/current" ]; then mv "$OUT_DIR/current" "$OUT_DIR/.old"; fi
mv "$next" "$OUT_DIR/current"
rm -rf "$OUT_DIR/.old"
echo "admin panel built"
