#!/usr/bin/env bash
# Kabso Live — drain-safe, MANUAL update of one media node (D350). There is no automatic update on media nodes.
#
#   bash update-media.sh [--service livekit|caddy|node-exporter|config] [--image REF] [--drain-timeout SECONDS]
#                        [--yes] [--dry-run]
#
#   --service livekit (default)  pull the new image first, then SIGTERM-drain LiveKit (active rooms keep running and
#                                accept viewers, new rooms are refused, the process exits when the last participant
#                                leaves or the timeout passes), then start it on the new image and wait for health.
#   --service config             re-render livekit.yaml / caddy.yaml from media.env, then drain + restart LiveKit and
#                                reload Caddy (a LiveKit config change always needs a restart).
#   --service caddy              restart Caddy only: open signalling WebSockets and TURN/TLS sessions drop for a few
#                                seconds and the SDKs reconnect (media over UDP keeps flowing). Quiet hours.
#   --service node-exporter      restart the exporter (no user impact).
#   --image REF                  e.g. livekit/livekit-server:v1.13.12@sha256:… — written to images.env (LIVEKIT_IMAGE /
#                                CADDY_IMAGE / NODE_EXPORTER_IMAGE) after a successful pull. Pin by digest.
#   --drain-timeout SECONDS      default DRAIN_TIMEOUT_SECONDS from media.env (10800 = 3 h).
#
# Phase 1 (one node): while this node drains, NO new live can start anywhere — schedule a maintenance window.
# Phase 2: drain one node at a time; the others take the new rooms (node selector).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"
ETC=${KABSO_MEDIA_ETC:-/etc/kabso-media}
SERVICE=livekit
IMAGE=""
TIMEOUT=""
YES=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --service) SERVICE=${2:?}; shift 2 ;;
    --image) IMAGE=${2:?}; shift 2 ;;
    --drain-timeout) TIMEOUT=${2:?}; shift 2 ;;
    --yes) YES=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --etc) ETC=${2:?}; shift 2 ;;
    -h | --help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done
export KABSO_MEDIA_ETC=$ETC
load_media_env "$ETC"
TIMEOUT=${TIMEOUT:-${V[DRAIN_TIMEOUT_SECONDS]}}
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || die "--drain-timeout must be a number of seconds"
case "$SERVICE" in livekit | caddy | node-exporter | config) ;; *) die "unknown --service $SERVICE" ;; esac
[ -z "$IMAGE" ] || [ "$SERVICE" != config ] || die "--image does not apply to --service config"
[ -z "$IMAGE" ] || [[ "$IMAGE" == *@sha256:* ]] || echo "WARNING: $IMAGE is not pinned by digest." >&2

run() { if [ "$DRY" -eq 1 ]; then printf '+ %s\n' "$*"; else "$@"; fi; }
rooms() {
  LIVEKIT_API_KEY=${V[LIVEKIT_API_KEY]} LIVEKIT_API_SECRET=${V[LIVEKIT_API_SECRET]} no_proxy='*' \
    python3 -I "$HERE/test/probe.py" rooms http://127.0.0.1:7880 2>&1 || true
}
confirm() {
  [ "$YES" -eq 1 ] || [ "$DRY" -eq 1 ] && return 0
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[yY] ]] || die "cancelled"
}
set_image() { # set_image VAR REF → images.env
  local f="$ETC/images.env" tmp
  tmp=$(mktemp "$ETC/.images.XXXXXX")
  { [ -f "$f" ] && grep -v "^$1=" "$f"; printf '%s=%s\n' "$1" "$2"; } >"$tmp" || true
  chmod 644 "$tmp"
  mv "$tmp" "$f"
}

log "Now: $(rooms)"
media_compose ps --format '{{.Service}} {{.Image}} {{.State}} {{.Health}}' || true

case "$SERVICE" in
  node-exporter | caddy)
    var=$([ "$SERVICE" = caddy ] && echo CADDY_IMAGE || echo NODE_EXPORTER_IMAGE)
    if [ -n "$IMAGE" ]; then run docker pull "$IMAGE"; [ "$DRY" -eq 1 ] || set_image "$var" "$IMAGE"; fi
    [ "$SERVICE" = caddy ] && confirm "Restarting Caddy drops open signalling/TURN-TLS connections for a few seconds. Continue?"
    run media_compose up -d --no-deps --force-recreate "$SERVICE"
    ;;
  livekit | config)
    if [ "$SERVICE" = config ]; then
      run bash "$HERE/render-config.sh" --etc "$ETC"
    elif [ -n "$IMAGE" ]; then
      log "Pulling $IMAGE before draining (a failed pull changes nothing)"
      run docker pull "$IMAGE"
    else
      run media_compose pull livekit
    fi
    confirm "Drain LiveKit now (new lives refused on this node for up to ${TIMEOUT}s)?"
    log "Draining: SIGTERM, waiting up to ${TIMEOUT}s for the last participant to leave"
    if [ "$DRY" -eq 0 ]; then
      ( while sleep 60; do printf '  draining … %s\n' "$(rooms)"; done ) &
      watcher=$!
      trap 'kill "$watcher" 2>/dev/null || true' EXIT
    fi
    run media_compose stop -t "$TIMEOUT" livekit
    [ "$DRY" -eq 0 ] && kill "$watcher" 2>/dev/null || true
    [ -n "$IMAGE" ] && [ "$DRY" -eq 0 ] && set_image LIVEKIT_IMAGE "$IMAGE"
    log "Starting LiveKit"
    run media_compose up -d --no-deps livekit
    [ "$SERVICE" = config ] && run media_compose up -d --no-deps --force-recreate caddy
    ;;
esac

if [ "$DRY" -eq 0 ]; then
  log "Waiting for health"
  for _ in $(seq 1 30); do bash "$HERE/health.sh" --etc "$ETC" >/dev/null 2>&1 && break; sleep 4; done
  bash "$HERE/health.sh" --etc "$ETC" --verbose || die "health check failed after the update — see journalctl / docker logs"
  log "Done: $(rooms)"
fi
