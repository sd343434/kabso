#!/usr/bin/env bash
# Kabso Live — one-time server setup (KL-069, docs/DEPLOYMENT.md §11).
#
# Run ONCE as root on a fresh Ubuntu server (tested target: Ubuntu 26.04 LTS), e.g. from the
# hosting provider's browser terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/sd343434/kabso/staging/infra/deploy/install.sh -o install.sh
#   less install.sh        # read it first
#   bash install.sh
#
# What it does:
#   1. installs git, Docker and the compose plugin, and opens the firewall for SSH, HTTP(S) and
#      the LiveKit media ports;
#   2. clones the public repository into /opt/kabso (branch KABSO_BRANCH, default `staging`);
#   3. generates every secret ON this server into /etc/kabso/*.env (root only, mode 600). Nothing
#      secret is typed into chat, stored in git or in GitHub. The SMTP password is asked for here,
#      without echo. Re-running keeps the existing secrets;
#   4. installs the kabso-update timer: every 5 minutes infra/deploy/update.sh pulls the branch and
#      the API image CI published for it, runs the migrations, and restarts what changed. Pushing
#      to the branch is all a release needs.
set -euo pipefail

REPO_URL="${KABSO_REPO_URL:-https://github.com/sd343434/kabso.git}"
BRANCH="${KABSO_BRANCH:-staging}"
IMAGE="${KABSO_API_IMAGE:-ghcr.io/sd343434/kabso-api:${BRANCH}}"
APP_DIR=/opt/kabso
ETC=/etc/kabso

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (sudo bash install.sh)"
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || die "this script targets Ubuntu (found ${ID:-unknown})"

# A random key the API accepts in production (secret-strength.ts): 48 random bytes, base64url.
secret() { openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n'; }
# A database password: hex, safe inside a connection URL.
dbpass() { openssl rand -hex 32; }
ask() { # ask VAR "prompt" [default]
  local value
  read -r -p "$2${3:+ [$3]}: " value
  printf -v "$1" '%s' "${value:-${3:-}}"
}

log "Installing packages (git, Docker, compose, firewall)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ca-certificates curl git openssl ufw
if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y -q docker.io docker-compose-v2 ||
    { curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sh /tmp/get-docker.sh; }
fi
docker compose version >/dev/null 2>&1 || apt-get install -y -q docker-compose-v2
systemctl enable --now docker

log "Firewall: SSH, HTTP, HTTPS (TCP+UDP), LiveKit media 7881/tcp and 7882/udp"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw allow 443/udp >/dev/null
ufw allow 7881/tcp >/dev/null
ufw allow 7882/udp >/dev/null
ufw --force enable >/dev/null

log "Repository: $REPO_URL ($BRANCH) -> $APP_DIR"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" fetch -q origin "$BRANCH"
  git -C "$APP_DIR" checkout -q "$BRANCH"
  git -C "$APP_DIR" merge -q --ff-only "origin/$BRANCH"
else
  git clone -q --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

log "API image: $IMAGE"
if ! docker pull -q "$IMAGE"; then
  die "cannot pull $IMAGE. CI publishes it after the first green run on '$BRANCH'. If the
       run is green, make the package public once: GitHub -> your profile -> Packages ->
       kabso-api -> Package settings -> Change visibility -> Public. Then re-run this script."
fi

install -d -m 700 "$ETC"
if [ -f "$ETC/kabso.env" ]; then
  log "Secrets already exist in $ETC: keeping them (delete the directory to start over)"
else
  log "Settings (press Enter for the default)"
  ask DOMAIN "Domain" "kabsolive.com"
  ask ACME_EMAIL "E-mail for the Let's Encrypt certificate notices" ""
  [ -n "$ACME_EMAIL" ] || die "an e-mail address is required for the certificates"
  echo "Outgoing mail (verification codes). Use your mail provider's SMTP settings."
  ask SMTP_HOST "SMTP host" "smtp.hostinger.com"
  ask SMTP_PORT "SMTP port (465 = TLS, 587 = STARTTLS)" "465"
  ask SMTP_USER "SMTP user (the mailbox address)" "no-reply@${DOMAIN}"
  read -r -s -p "SMTP password (not shown): " SMTP_PASSWORD; echo
  [ -n "$SMTP_PASSWORD" ] || die "the SMTP password is required"
  ask MAIL_FROM "Sender shown to users" "Kabso Live <${SMTP_USER}>"
  SMTP_SECURE=true; [ "$SMTP_PORT" = "465" ] || SMTP_SECURE=false

  log "Generating secrets on this server"
  PG_ADMIN_PW=$(dbpass); MIGRATOR_PW=$(dbpass); APP_PW=$(dbpass)
  verifier() { printf '%s' "$1" | docker run --rm -i --entrypoint node "$IMAGE" /app/infra/postgres/scram-verifier.mjs; }
  MIGRATOR_VERIFIER=$(verifier "$MIGRATOR_PW"); APP_VERIFIER=$(verifier "$APP_PW")
  LIVEKIT_KEY="API$(openssl rand -hex 8)"; LIVEKIT_SECRET=$(secret)
  CPUS=$(nproc)

  umask 077
  cat >"$ETC/kabso.env" <<EOF
# Kabso Live server settings (install.sh). Not secret, but root only like the others.
KABSO_DOMAIN='${DOMAIN}'
KABSO_ACME_EMAIL='${ACME_EMAIL}'
KABSO_BRANCH='${BRANCH}'
KABSO_API_IMAGE='${IMAGE}'
EOF
  cat >"$ETC/postgres.env" <<EOF
POSTGRES_DB='kabso'
POSTGRES_USER='kabso_admin'
POSTGRES_PASSWORD='${PG_ADMIN_PW}'
# Read by infra/deploy/initdb on the first start only. Verifiers, never clear text (SEC-011).
KABSO_DB_ENV='production'
KABSO_DB_MIGRATOR_USER='kabso_migrator'
KABSO_DB_MIGRATOR_PASSWORD='${MIGRATOR_VERIFIER}'
KABSO_DB_APP_USER='kabso_app'
KABSO_DB_APP_PASSWORD='${APP_VERIFIER}'
EOF
  cat >"$ETC/migrate.env" <<EOF
MIGRATION_DATABASE_URL='postgresql://kabso_migrator:${MIGRATOR_PW}@postgres:5432/kabso?schema=public'
EOF
  cat >"$ETC/api.env" <<EOF
NODE_ENV='production'
PORT='3000'
LOG_LEVEL='info'
DATABASE_URL='postgresql://kabso_app:${APP_PW}@postgres:5432/kabso?schema=public'
REDIS_URL='redis://redis:6379'
JWT_ACCESS_SECRET='$(secret)'
RATE_LIMIT_KEY_SECRET='$(secret)'
REGISTRATION_CODE_KEY='$(secret)'
LIVE_CURSOR_KEY='$(secret)'
SOCIAL_CURSOR_KEY='$(secret)'
APP_PUBLIC_URL='https://${DOMAIN}'
CORS_ORIGINS='https://${DOMAIN}'
# Caddy is the only proxy in front and appends X-Forwarded-For (docs/DEPLOYMENT.md §3.1).
TRUST_PROXY='1'
MAIL_TRANSPORT='smtp'
MAIL_FROM='${MAIL_FROM}'
SMTP_HOST='${SMTP_HOST}'
SMTP_PORT='${SMTP_PORT}'
SMTP_SECURE='${SMTP_SECURE}'
SMTP_USER='${SMTP_USER}'
SMTP_PASSWORD='${SMTP_PASSWORD}'
LIVE_HOSTING_ENABLED='true'
LIVEKIT_URL='wss://live.${DOMAIN}'
LIVEKIT_API_KEY='${LIVEKIT_KEY}'
LIVEKIT_API_SECRET='${LIVEKIT_SECRET}'
# Photo uploads stay off until the object storage exists (B12): the API answers 503 honestly.
MEDIA_UPLOADS_ENABLED='false'
# docs/DEPLOYMENT.md §3.2: UV_THREADPOOL_SIZE >= ARGON2_MAX_CONCURRENCY + 4.
ARGON2_MAX_CONCURRENCY='${CPUS}'
UV_THREADPOOL_SIZE='$((CPUS + 4))'
EOF
  cat >"$ETC/livekit.yaml" <<EOF
# LiveKit media server (install.sh). Signalling goes through Caddy (wss://live.${DOMAIN});
# media uses 7881/tcp and 7882/udp directly.
port: 7880
rtc:
  tcp_port: 7881
  udp_port: 7882
  use_external_ip: true
keys:
  ${LIVEKIT_KEY}: ${LIVEKIT_SECRET}
webhook:
  api_key: ${LIVEKIT_KEY}
  urls:
    - http://api:3000/internal/livekit/webhook
logging:
  level: info
EOF
  # The LiveKit container reads its config as a non-root user.
  chmod 644 "$ETC/livekit.yaml"
  unset SMTP_PASSWORD PG_ADMIN_PW MIGRATOR_PW APP_PW LIVEKIT_SECRET
fi

log "Automatic updates: kabso-update.timer (every 5 minutes)"
install -m 644 "$APP_DIR/infra/deploy/systemd/kabso-update.service" /etc/systemd/system/
install -m 644 "$APP_DIR/infra/deploy/systemd/kabso-update.timer" /etc/systemd/system/
systemctl daemon-reload

log "First start (database, migrations, API, media server, HTTPS)"
bash "$APP_DIR/infra/deploy/update.sh" --force
systemctl enable --now kabso-update.timer

. "$ETC/kabso.env"
IP=$(curl -fsS -4 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
cat <<EOF

Done. Point these DNS A records at ${IP} (if not already):
  ${KABSO_DOMAIN}        -> ${IP}
  api.${KABSO_DOMAIN}    -> ${IP}
  live.${KABSO_DOMAIN}   -> ${IP}
Caddy gets the HTTPS certificates by itself once they resolve. Then check:
  curl https://api.${KABSO_DOMAIN}/health/ready
Status and logs:
  systemctl list-timers kabso-update.timer
  journalctl -u kabso-update -n 50
  docker compose -f ${APP_DIR}/infra/deploy/docker-compose.yml ps
EOF
