#!/usr/bin/env bash
# Kabso Live — media node firewall (ufw) from media.env (D350). Idempotent; install.sh runs it.
#
#   bash firewall.sh [--etc DIR] [--dry-run] [--reset]
#
# Open to everyone: 80/tcp (ACME), 443/tcp (Caddy-L4: wss signalling + TURN/TLS), TURN/UDP (443 or 3478),
# ICE/TCP 7881, ICE/UDP mux range (7882-7901). SSH 22 only from SSH_ALLOW_CIDRS (else rate-limited for everyone).
# Only from MONITORING_IPS: 6789 (LiveKit metrics), 9100 (node_exporter), 7880 (RoomService on the private address,
# Phase 2). Never opened: 5349 (TURN behind Caddy, loopback only), 7880 publicly.
# With host networking ufw filters the real sockets (Docker's DNAT for published ports, which bypasses ufw, is not used).
# --reset clears every ufw rule first (ufw is disabled during the reset, so SSH is not cut), then re-adds these.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

ETC=/etc/kabso-media
DRY=0
RESET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --etc) ETC=${2:?}; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --reset) RESET=1; shift ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done
load_media_env "$ETC"

run() { if [ "$DRY" -eq 1 ]; then printf '+ %s\n' "$*"; else "$@" >/dev/null; fi; }

# Refuse to lock the current SSH session out.
if [ -n "${V[SSH_ALLOW_CIDRS]}" ] && [ -n "${SSH_CONNECTION:-}" ]; then
  client=${SSH_CONNECTION%% *}
  # shellcheck disable=SC2086 # the CIDR list is meant to split into arguments
  if ! python3 -I -c 'import ipaddress,sys; ip=ipaddress.ip_address(sys.argv[1]); sys.exit(0 if any(ip in ipaddress.ip_network(c, strict=False) for c in sys.argv[2:]) else 1)' \
    "$client" ${V[SSH_ALLOW_CIDRS]}; then
    die "your SSH client $client is not inside SSH_ALLOW_CIDRS (${V[SSH_ALLOW_CIDRS]}); add it first"
  fi
fi

command -v ufw >/dev/null || [ "$DRY" -eq 1 ] || die "ufw is not installed (install.sh installs it)"
[ "$RESET" -eq 1 ] && run ufw --force reset
run ufw default deny incoming
run ufw default allow outgoing

if [ -n "${V[SSH_ALLOW_CIDRS]}" ]; then
  for c in ${V[SSH_ALLOW_CIDRS]}; do run ufw allow proto tcp from "$c" to any port 22 comment 'ssh (restricted)'; done
else
  echo "WARNING: SSH_ALLOW_CIDRS is empty — SSH stays open to everyone (key-only, ufw rate limit, fail2ban)." >&2
  run ufw limit 22/tcp comment 'ssh (rate-limited)'
fi

run ufw allow 80/tcp comment 'acme http-01'
run ufw allow 443/tcp comment 'wss signalling + turn/tls (caddy-l4)'
run ufw allow "${V[TURN_UDP_PORT]}/udp" comment 'turn/udp'
run ufw allow "${V[RTC_TCP_PORT]}/tcp" comment 'webrtc ice/tcp'
run ufw allow "${V[RTC_UDP_PORT]/-/:}/udp" comment 'webrtc ice/udp mux'

for c in ${V[MONITORING_IPS]}; do
  for p in 6789 9100 7880; do run ufw allow proto tcp from "$c" to any port "$p" comment 'monitoring / control (private)'; done
done

run ufw --force enable
if [ "$DRY" -eq 0 ]; then ufw status verbose; fi
