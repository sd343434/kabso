# shellcheck shell=bash
# Kabso Live — shared helpers for the media node scripts (D350). Sourced, never run.
#
# load_media_env DIR   parses DIR/media.env into the associative array V (KEY=value lines; comments and blank lines
#                      ignored; surrounding quotes stripped; printable ASCII only; unknown keys refused) and applies the
#                      defaults. The file is parsed, never sourced, so it cannot run code.

MEDIA_KEYS=(MEDIA_DOMAIN TURN_DOMAIN ACME_EMAIL NODE_IP PRIVATE_IP LIVEKIT_REGION RTC_TCP_PORT RTC_UDP_PORT TURN_UDP_PORT
  SSH_ALLOW_CIDRS MONITORING_IPS LIVEKIT_API_KEY LIVEKIT_API_SECRET LIVEKIT_WEBHOOK_URL LIVEKIT_LOG_LEVEL
  ROOM_MAX_PARTICIPANTS LIMIT_NUM_TRACKS LIMIT_BYTES_PER_SEC DRAIN_TIMEOUT_SECONDS)
declare -gA V=()

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

load_media_env() {
  local etc=$1 line key val k
  ENV_FILE="$etc/media.env"
  [ -f "$ENV_FILE" ] || die "$ENV_FILE not found (copy .env.example there, mode 600, and fill it)"
  for k in "${MEDIA_KEYS[@]}"; do V[$k]=""; done
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]] || die "media.env: cannot read line: ${line%%=*}=…"
    key=${BASH_REMATCH[1]}
    val=${BASH_REMATCH[2]}
    if [[ "$val" =~ ^\"(.*)\"$ || "$val" =~ ^\'(.*)\'$ ]]; then val=${BASH_REMATCH[1]}; fi
    [ -z "$(printf '%s' "$val" | LC_ALL=C tr -d '\40-\176')" ] || die "media.env: $key has a non-ASCII or control character"
    [ -n "${V[$key]+x}" ] || die "media.env: unknown key $key"
    V[$key]=$val
  done <"$ENV_FILE"
  : "${V[LIVEKIT_REGION]:=eu-central-fsn1}"
  : "${V[RTC_TCP_PORT]:=7881}"
  : "${V[RTC_UDP_PORT]:=7882-7901}"
  : "${V[TURN_UDP_PORT]:=443}"
  : "${V[LIVEKIT_LOG_LEVEL]:=info}"
  : "${V[ROOM_MAX_PARTICIPANTS]:=1000}"
  : "${V[LIMIT_NUM_TRACKS]:=-1}"
  : "${V[LIMIT_BYTES_PER_SEC]:=0}"
  : "${V[DRAIN_TIMEOUT_SECONDS]:=10800}"
}

# The compose command for this node: the bundle's compose file, the rendered compose.env and, when present, the
# image overrides written by update-media.sh (images.env) and a local compose override (compose.override.yml, e.g.
# for a machine whose kernel refuses the default ulimits; not needed on the EX44).
media_compose() {
  local etc=${KABSO_MEDIA_ETC:-/etc/kabso-media} bundle=${KABSO_MEDIA_DIR:-/opt/kabso-media}
  local args=(compose --project-directory "$bundle" -f "$bundle/docker-compose.yml")
  [ -f "$etc/compose.override.yml" ] && args+=(-f "$etc/compose.override.yml")
  args+=(--env-file "$etc/compose.env")
  [ -f "$etc/images.env" ] && args+=(--env-file "$etc/images.env")
  docker "${args[@]}" "$@"
}
