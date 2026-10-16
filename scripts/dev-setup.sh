#!/usr/bin/env bash
# Kabso Live — idempotent local bootstrap. Safe to run any number of times.
#
#   scripts/dev-setup.sh             # Postgres + Redis
#   scripts/dev-setup.sh --storage   # + MinIO (S3-compatible) and bucket init
#
# What it does:
#   1. Checks prerequisites (node 22, corepack/pnpm, flutter, docker) and reports what is missing.
#   2. Creates .env from .env.example if .env does not exist (never overwrites an existing .env).
#   3. Replaces the JWT_ACCESS_SECRET, RATE_LIMIT_KEY_SECRET and LIVE_CURSOR_KEY placeholders with
#      random values (openssl rand -base64 48) if openssl is available.
#   4. Starts docker compose services if a Docker daemon is reachable, and waits for health.
#   5. Prints the next steps.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WITH_STORAGE=false
for arg in "$@"; do
  case "$arg" in
    --storage) WITH_STORAGE=true ;;
    -h | --help)
      sed -n '2,13p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

REQUIRED_NODE_MAJOR=22
REQUIRED_FLUTTER="3.47.7"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok() { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- 1. Prerequisites --------------------------------------------------------------------------
info "Checking prerequisites"
missing=0

if have node; then
  node_major="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$node_major" = "$REQUIRED_NODE_MAJOR" ]; then
    ok "node $(node --version)"
  else
    warn "node $(node --version) found; Node ${REQUIRED_NODE_MAJOR}.x is required for apps/api"
    missing=1
  fi
else
  warn "node not found (install Node ${REQUIRED_NODE_MAJOR}.x)"
  missing=1
fi

if have pnpm; then
  ok "pnpm $(pnpm --version)"
elif have corepack; then
  warn "pnpm not on PATH; run 'corepack enable' (version comes from package.json packageManager)"
  missing=1
else
  warn "neither pnpm nor corepack found"
  missing=1
fi

if have flutter; then
  flutter_version="$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n1)"
  if [ "$flutter_version" = "$REQUIRED_FLUTTER" ]; then
    ok "flutter $flutter_version"
  else
    warn "flutter ${flutter_version:-unknown} found; ${REQUIRED_FLUTTER} (stable) is pinned for apps/mobile"
  fi
else
  warn "flutter not found (needed only for apps/mobile; pinned ${REQUIRED_FLUTTER} stable)"
fi

docker_ready=false
if have docker; then
  if docker compose version >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      docker_ready=true
      ok "docker daemon reachable ($(docker compose version --short 2>/dev/null || echo 'compose v2'))"
    else
      warn "docker CLI found but the daemon is not reachable; services will not be started"
    fi
  else
    warn "docker found but the 'docker compose' v2 plugin is missing"
  fi
else
  warn "docker not found; install Docker to run Postgres/Redis/MinIO locally"
fi

# --- 2. .env -----------------------------------------------------------------------------------
info "Environment file"
if [ -f .env ]; then
  ok ".env already exists (not overwritten)"
else
  cp .env.example .env
  chmod 600 .env
  ok "created .env from .env.example"
fi
if ! grep -q '^MIGRATION_DATABASE_URL=' .env; then
  # .env from before KL-013 (single DB role). Not rewritten automatically: the DB volume needs
  # the new roles too.
  warn ".env predates the least-privilege DB roles (SEC-011): copy the PostgreSQL block from"
  warn ".env.example (DATABASE_URL, MIGRATION_DATABASE_URL, KABSO_DB_*) and recreate the volume"
  warn "with 'docker compose down -v' (deletes local data); see docs/DEPLOYMENT.md §5.1"
fi

# --- 3. Local secrets --------------------------------------------------------------------------
# Each variable gets its own random value (never shared between purposes).
for var in JWT_ACCESS_SECRET RATE_LIMIT_KEY_SECRET LIVE_CURSOR_KEY; do
  if ! grep -q "^${var}=" .env; then
    # .env created before this variable existed: append a placeholder, filled in below.
    printf '%s=change-me-generate-with-openssl-rand-base64-48\n' "$var" >>.env
  fi
  if grep -q "^${var}=change-me-" .env; then
    if have openssl; then
      secret="$(openssl rand -base64 48 | tr -d '\n')"
      tmp="$(mktemp)"
      sed "s|^${var}=change-me-.*|${var}=${secret}|" .env >"$tmp"
      cat "$tmp" >.env
      rm -f "$tmp"
      ok "generated a random ${var} in .env"
    else
      warn "${var} is still the placeholder; set it with: openssl rand -base64 48"
    fi
  else
    ok "${var} already set"
  fi
done

# --- 4. Infrastructure -------------------------------------------------------------------------
info "Local infrastructure"
if [ "$docker_ready" = true ]; then
  compose_args=()
  if [ "$WITH_STORAGE" = true ]; then
    compose_args+=(--profile storage)
  fi
  docker compose ${compose_args[@]+"${compose_args[@]}"} up -d --wait
  ok "services healthy:"
  docker compose ${compose_args[@]+"${compose_args[@]}"} ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
else
  warn "skipped (no Docker daemon). Start later with: docker compose up -d --wait"
fi

# --- 5. Next steps -----------------------------------------------------------------------------
info "Next steps"
cat <<'EOF'
  API (apps/api):
    corepack enable
    pnpm install
    pnpm --filter ./apps/api prisma:migrate:deploy   # applies migrations as MIGRATION_DATABASE_URL
    pnpm --filter ./apps/api start:dev               # check apps/api/README for the exact script
    curl -s localhost:3000/health/ready

  The API reads configuration from its process environment. Export the root .env first, e.g.
    set -a; . ./.env; set +a

  Mobile (apps/mobile):
    cd apps/mobile && flutter pub get
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # Android emulator → host

  Docs: docs/DEPLOYMENT.md
EOF

if [ "$missing" -ne 0 ]; then
  warn "some prerequisites are missing (see above)"
fi
