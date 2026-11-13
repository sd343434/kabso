#!/usr/bin/env bash
# Kabso Live — drain and delete an EMERGENCY cloud media node after the surge (D350, SURGE_AND_OVERFLOW_PLAN.md).
#
#   bash hcloud-delete.sh --name media-s1 [--drain-timeout 3600] [--run]
#
# 1. SIGTERM-drains LiveKit on the node over SSH (active rooms finish, new rooms go to the other nodes);
# 2. deletes the server with `hcloud server delete` (billing stops; hourly billing, monthly cap);
# 3. reminds you to remove its two DNS records.
# Refuses any server without the label kabso-role=media-surge, so a permanent node cannot be deleted by mistake.
# Default is a DRY RUN; add --run.
set -euo pipefail
NAME="" TIMEOUT=3600 RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME=${2:?}; shift 2 ;;
    --drain-timeout) TIMEOUT=${2:?}; shift 2 ;;
    --run) RUN=1; shift ;;
    -h | --help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$NAME" =~ ^media-[a-z0-9-]{1,30}$ ]] || die "--name media-<id> is required"
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || die "--drain-timeout: seconds"
run() { if [ "$RUN" -eq 1 ]; then "$@"; else printf '+ %s\n' "$*"; fi; }

if [ "$RUN" -eq 1 ]; then
  command -v hcloud >/dev/null || die "the hcloud CLI is not installed"
  role=$(hcloud server describe "$NAME" -o format='{{index .Labels "kabso-role"}}') || die "no server $NAME"
  [ "$role" = media-surge ] || die "$NAME is not labelled kabso-role=media-surge (found '$role'); refusing"
  ip=$(hcloud server ip "$NAME")
else
  ip="<ip of $NAME>"
fi
run ssh -o ConnectTimeout=10 "root@$ip" "bash -c '. /opt/kabso-media/lib.sh && media_compose stop -t $TIMEOUT livekit'"
run hcloud server delete "$NAME"
echo "Remove the node's DNS records (MEDIA_DOMAIN / TURN_DOMAIN of $NAME) at the DNS provider."
[ "$RUN" -eq 1 ] || echo "(dry run: nothing was changed; add --run)"
