#!/usr/bin/env bash
# Kabso Live — media node health probe (D350). Run every minute by kabso-media-health.timer, or by hand.
#
#   bash health.sh [--etc DIR] [--verbose]
#
# Checks, each reported as kabso_media_probe_ok{probe="…"} 0|1 in the node_exporter textfile directory:
#   containers   livekit, caddy and node-exporter are running (livekit "healthy")
#   http         LiveKit answers OK on 127.0.0.1:7880
#   wss          https://MEDIA_DOMAIN/ answers OK through Caddy-L4 with a VALID certificate (curl --resolve 127.0.0.1)
#   cert_days    days until the signalling certificate expires (gauge kabso_media_cert_days; probe fails below 14)
#   turn_tls     TLS with SNI TURN_DOMAIN on 127.0.0.1:443 + STUN Binding (valid certificate, PROXY header reached TURN)
#   turn_udp     STUN Binding on NODE_IP:TURN_UDP_PORT
#   rooms        RoomService ListRooms with the node's own key (gauges kabso_media_rooms, kabso_media_participants)
#   metrics      LiveKit's Prometheus endpoint answers on 127.0.0.1:6789
# Exit code 1 when any probe fails (the systemd unit then shows "failed").
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"
ETC=${KABSO_MEDIA_ETC:-/etc/kabso-media}
VERBOSE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --etc) ETC=${2:?}; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done
export KABSO_MEDIA_ETC=$ETC
load_media_env "$ETC"
OUT_DIR=/var/lib/kabso-media/metrics
METRICS=""
FAILED=0
export no_proxy='*' NO_PROXY='*'

record() { # record PROBE OK DETAIL
  METRICS+="kabso_media_probe_ok{probe=\"$1\"} $2"$'\n'
  if [ "$2" -eq 1 ]; then
    if [ "$VERBOSE" -eq 1 ]; then printf 'ok   %-10s %s\n' "$1" "$3"; fi
  else
    FAILED=1
    printf 'FAIL %-10s %s\n' "$1" "$3"
  fi
}

ps_out=$(media_compose ps --format '{{.Service}} {{.State}} {{.Health}}' 2>&1)
if grep -q '^livekit running healthy' <<<"$ps_out" && grep -q '^caddy running' <<<"$ps_out" &&
  grep -q '^node-exporter running' <<<"$ps_out"; then
  record containers 1 "all running"
else
  record containers 0 "$(tr '\n' ';' <<<"$ps_out")"
fi

body=$(curl -fsS --max-time 5 http://127.0.0.1:7880/ 2>&1)
if [ "$body" = "OK" ]; then record http 1 "127.0.0.1:7880"; else record http 0 "127.0.0.1:7880: $body"; fi

d=${V[MEDIA_DOMAIN]}
body=$(curl -fsS --max-time 5 --resolve "$d:443:127.0.0.1" "https://$d/" 2>&1)
if [ "$body" = "OK" ]; then record wss 1 "https://$d/"; else record wss 0 "https://$d/: $body"; fi

end=$(echo | timeout 5 openssl s_client -connect 127.0.0.1:443 -servername "$d" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$end" ]; then
  days=$((($(date -d "$end" +%s) - $(date +%s)) / 86400))
  METRICS+="kabso_media_cert_days{name=\"$d\"} $days"$'\n'
  if [ "$days" -ge 14 ]; then record cert_days 1 "$days days"; else record cert_days 0 "$d expires in $days days"; fi
else
  record cert_days 0 "no certificate served for $d"
fi

out=$(python3 -I "$HERE/test/probe.py" stun-tls 127.0.0.1 443 "${V[TURN_DOMAIN]}" 2>&1)
if [[ "$out" == "TURN/TLS ok"* ]]; then record turn_tls 1 "$out"; else record turn_tls 0 "$out"; fi

out=$(python3 -I "$HERE/test/probe.py" stun-udp "${V[NODE_IP]}" "${V[TURN_UDP_PORT]}" 2>&1)
if [[ "$out" == "TURN/UDP ok"* ]]; then record turn_udp 1 "$out"; else record turn_udp 0 "$out"; fi

out=$(LIVEKIT_API_KEY=${V[LIVEKIT_API_KEY]} LIVEKIT_API_SECRET=${V[LIVEKIT_API_SECRET]} \
  python3 -I "$HERE/test/probe.py" rooms http://127.0.0.1:7880 2>&1)
if [[ "$out" =~ ^RoomService\ ok,\ ([0-9]+)\ room.*,\ ([0-9]+)\ participant ]]; then
  METRICS+="kabso_media_rooms ${BASH_REMATCH[1]}"$'\n'"kabso_media_participants ${BASH_REMATCH[2]}"$'\n'
  record rooms 1 "$out"
else
  record rooms 0 "$out"
fi

if curl -fsS --max-time 5 -o /dev/null http://127.0.0.1:6789/metrics; then record metrics 1 ":6789/metrics"
else record metrics 0 "127.0.0.1:6789/metrics did not answer"; fi

if [ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR" 2>/dev/null; then
  tmp=$(mktemp "$OUT_DIR/.health.XXXXXX") && printf '%s' "$METRICS" >"$tmp" && chmod 644 "$tmp" && mv "$tmp" "$OUT_DIR/kabso_media.prom"
fi
exit "$FAILED"
