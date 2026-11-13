#!/usr/bin/env bash
# Kabso Live — render the media node's config from media.env (D350).
#
#   bash render-config.sh [--etc DIR] [--generate-keys] [--dry-run]
#
# Reads  DIR/media.env (default DIR=/etc/kabso-media; KEY=value lines, see .env.example).
# Writes DIR/livekit.yaml (644, no secret), DIR/livekit.env (600, LIVEKIT_KEYS), DIR/caddy.yaml (644) and
#        DIR/compose.env (644, values docker compose needs).
# --generate-keys  fills LIVEKIT_API_KEY / LIVEKIT_API_SECRET in media.env when they are empty (generated here with
#                  openssl, never printed).
# --dry-run        validates and prints what would be written, with the secret masked; writes nothing.
# media.env is parsed, never sourced: only the known keys are read, and every value is checked.
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ETC=/etc/kabso-media
GENERATE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --etc) ETC=${2:?--etc needs a directory}; shift 2 ;;
    --generate-keys) GENERATE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=lib.sh
. "$HERE/lib.sh"
load_media_env "$ETC"

if [ "$GENERATE" -eq 1 ] && [ -z "${V[LIVEKIT_API_KEY]}" ] && [ -z "${V[LIVEKIT_API_SECRET]}" ]; then
  V[LIVEKIT_API_KEY]="API$(openssl rand -hex 6)"
  V[LIVEKIT_API_SECRET]=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
  if [ "$DRY" -eq 0 ]; then
    tmp=$(mktemp "$ETC/.media.env.XXXXXX")
    chmod 600 "$tmp"
    sed -e "s|^LIVEKIT_API_KEY=.*|LIVEKIT_API_KEY=${V[LIVEKIT_API_KEY]}|" \
      -e "s|^LIVEKIT_API_SECRET=.*|LIVEKIT_API_SECRET=${V[LIVEKIT_API_SECRET]}|" "$ENV_FILE" >"$tmp"
    grep -q "^LIVEKIT_API_SECRET=${V[LIVEKIT_API_SECRET]}\$" "$tmp" || die "media.env has no LIVEKIT_API_SECRET= line to fill"
    mv "$tmp" "$ENV_FILE"
    echo "Generated a new LiveKit key pair into $ENV_FILE (key ${V[LIVEKIT_API_KEY]}; the secret is not shown)."
  fi
fi

# ---- Validation ------------------------------------------------------------------------------------------------------
fqdn='^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$'
ipv4='^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$'
port='^[0-9]{1,5}$'
err=0
bad() { printf 'invalid %s: %s\n' "$1" "$2" >&2; err=1; }
for k in MEDIA_DOMAIN TURN_DOMAIN; do [[ "${V[$k]}" =~ $fqdn ]] || bad "$k" "a lower-case host name is required"; done
[ "${V[MEDIA_DOMAIN]}" != "${V[TURN_DOMAIN]}" ] || bad TURN_DOMAIN "must differ from MEDIA_DOMAIN (own name and certificate)"
[[ "${V[ACME_EMAIL]}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$ ]] || bad ACME_EMAIL "an e-mail address is required"
[[ "${V[NODE_IP]}" =~ $ipv4 ]] || bad NODE_IP "the public IPv4 is required"
[ -z "${V[PRIVATE_IP]}" ] || [[ "${V[PRIVATE_IP]}" =~ $ipv4 ]] || bad PRIVATE_IP "must be an IPv4 or empty"
[[ "${V[LIVEKIT_REGION]}" =~ ^[a-z0-9-]{1,64}$ ]] || bad LIVEKIT_REGION "letters, digits and - only"
[[ "${V[RTC_TCP_PORT]}" =~ $port ]] || bad RTC_TCP_PORT "a port number"
[[ "${V[RTC_UDP_PORT]}" =~ ^[0-9]{1,5}(-[0-9]{1,5})?$ ]] || bad RTC_UDP_PORT "a port or a range like 7882-7901"
[[ "${V[TURN_UDP_PORT]}" =~ ^(443|3478)$ ]] || bad TURN_UDP_PORT "443 or 3478"
[[ "${V[LIVEKIT_API_KEY]}" =~ ^[A-Za-z0-9_-]{3,64}$ ]] || bad LIVEKIT_API_KEY "required (or run with --generate-keys)"
[ "${#V[LIVEKIT_API_SECRET]}" -ge 32 ] || bad LIVEKIT_API_SECRET "at least 32 characters (or --generate-keys)"
[[ "${V[LIVEKIT_API_SECRET]}" =~ ^[A-Za-z0-9_.~+/=-]+$ ]] || bad LIVEKIT_API_SECRET "no spaces, quotes or ':'"
[ -z "${V[LIVEKIT_WEBHOOK_URL]}" ] || [[ "${V[LIVEKIT_WEBHOOK_URL]}" =~ ^https://[a-z0-9.-]+(:[0-9]+)?/[A-Za-z0-9/_.-]*$ ]] ||
  bad LIVEKIT_WEBHOOK_URL "an https:// URL or empty"
[[ "${V[LIVEKIT_LOG_LEVEL]}" =~ ^(debug|info|warn|error)$ ]] || bad LIVEKIT_LOG_LEVEL "debug|info|warn|error"
[[ "${V[ROOM_MAX_PARTICIPANTS]}" =~ ^[0-9]+$ ]] || bad ROOM_MAX_PARTICIPANTS "a number"
[[ "${V[LIMIT_NUM_TRACKS]}" =~ ^-?[0-9]+$ ]] || bad LIMIT_NUM_TRACKS "a number (-1 = off)"
[[ "${V[LIMIT_BYTES_PER_SEC]}" =~ ^[0-9]+$ ]] || bad LIMIT_BYTES_PER_SEC "a number (0 = off)"
[[ "${V[DRAIN_TIMEOUT_SECONDS]}" =~ ^[0-9]+$ ]] || bad DRAIN_TIMEOUT_SECONDS "a number of seconds"
for c in ${V[SSH_ALLOW_CIDRS]} ${V[MONITORING_IPS]}; do
  [[ "$c" =~ ^[0-9a-fA-F:.]+(/[0-9]{1,3})?$ ]] || bad "CIDR" "$c"
done
[ "$err" -eq 0 ] || die "fix $ENV_FILE and run again"

# ---- Render ----------------------------------------------------------------------------------------------------------
BIND="  - 127.0.0.1"
[ -n "${V[PRIVATE_IP]}" ] && BIND+=$'\n'"  - ${V[PRIVATE_IP]}"
if [ -n "${V[LIVEKIT_WEBHOOK_URL]}" ]; then
  WEBHOOK=$'webhook:\n'"  api_key: ${V[LIVEKIT_API_KEY]}"$'\n  urls:\n'"    - ${V[LIVEKIT_WEBHOOK_URL]}"
else
  WEBHOOK="# webhook: (none — LIVEKIT_WEBHOOK_URL is empty)"
fi

render() { # render TEMPLATE → stdout, replacing ${NAME} for the known names only
  local text name
  text=$(<"$1")
  for name in "${MEDIA_KEYS[@]}"; do text=${text//\$\{$name\}/${V[$name]}}; done
  text=${text//\$\{BIND_ADDRESSES_YAML\}/$BIND}
  text=${text//\$\{WEBHOOK_YAML\}/$WEBHOOK}
  if [[ "$text" =~ \$\{[A-Z_]+\} ]]; then die "$1: unfilled placeholder ${BASH_REMATCH[0]}"; fi
  printf '%s\n' "$text"
}
LIVEKIT_YAML=$(render "$HERE/livekit.yaml.tmpl")
CADDY_YAML=$(render "$HERE/caddy.yaml.tmpl")
NODE_EXPORTER_LISTEN="127.0.0.1:9100"
[ -n "${V[PRIVATE_IP]}" ] && NODE_EXPORTER_LISTEN="${V[PRIVATE_IP]}:9100"
COMPOSE_ENV="KABSO_MEDIA_ETC=$ETC
NODE_EXPORTER_LISTEN=$NODE_EXPORTER_LISTEN"
# LiveKit's --keys format: "<key>: <secret>" (livekit-server --help).
LIVEKIT_ENV="LIVEKIT_KEYS=${V[LIVEKIT_API_KEY]}: ${V[LIVEKIT_API_SECRET]}"

if [ "$DRY" -eq 1 ]; then
  printf '# --- %s/livekit.yaml\n%s\n# --- %s/caddy.yaml\n%s\n# --- %s/compose.env\n%s\n# --- %s/livekit.env (600)\nLIVEKIT_KEYS=%s: ****\n' \
    "$ETC" "$LIVEKIT_YAML" "$ETC" "$CADDY_YAML" "$ETC" "$COMPOSE_ENV" "$ETC" "${V[LIVEKIT_API_KEY]}"
  exit 0
fi

umask 077
write() { # write FILE MODE CONTENT (atomic)
  local tmp
  tmp=$(mktemp "$ETC/.render.XXXXXX")
  printf '%s\n' "$3" >"$tmp"
  chmod "$2" "$tmp"
  mv "$tmp" "$1"
}
write "$ETC/livekit.yaml" 644 "$LIVEKIT_YAML"
write "$ETC/caddy.yaml" 644 "$CADDY_YAML"
write "$ETC/compose.env" 644 "$COMPOSE_ENV"
write "$ETC/livekit.env" 600 "$LIVEKIT_ENV"
echo "Rendered $ETC/livekit.yaml, caddy.yaml, compose.env and livekit.env (600)."
