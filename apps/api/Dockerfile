# Kabso Live API — container image (KL-069, docs/DEPLOYMENT.md §11).
#
# Build from the repository root (the pnpm workspace):
#   docker build -f apps/api/Dockerfile -t kabso-api .
#
# One image runs both jobs of a deploy:
#   migrations  node_modules/.bin/prisma migrate deploy  (MIGRATION_DATABASE_URL, the migration role)
#   API         node dist/main.js                        (DATABASE_URL, the DML-only runtime role)
# The Prisma CLI is a dev dependency, so the image keeps the full install. No secret is baked in:
# every setting comes from the environment at start (docs/DEPLOYMENT.md §4).

# node:22.22.0-bookworm-slim — multi-arch index digest resolved 2026-10-25 (scripts/image-digests.sh)
ARG NODE_IMAGE=node:22.22.0-bookworm-slim@sha256:dd9d21971ec4395903fa6143c2b9267d048ae01ca6d3ea96f16cb30df6187d94

FROM ${NODE_IMAGE} AS build
ENV CI=true PNPM_HOME=/pnpm
RUN corepack enable
WORKDIR /src
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/
RUN corepack install && pnpm install --frozen-lockfile --filter @kabso/api
COPY apps/api apps/api
RUN pnpm --filter @kabso/api build

FROM ${NODE_IMAGE}
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /src/node_modules node_modules
COPY --from=build --chown=node:node /src/apps/api/node_modules apps/api/node_modules
COPY --from=build --chown=node:node /src/apps/api/package.json /src/apps/api/prisma.config.ts apps/api/
COPY --from=build --chown=node:node /src/apps/api/prisma apps/api/prisma
COPY --from=build --chown=node:node /src/apps/api/dist apps/api/dist
COPY --chown=node:node infra/postgres/scram-verifier.mjs infra/postgres/scram-verifier.mjs
WORKDIR /app/apps/api
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health/live').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"
CMD ["node", "dist/main.js"]
