#!/usr/bin/env bash
# Kabso Live — start an EMERGENCY LiveKit media node on Hetzner Cloud for a short surge (D350).
# Plan and costs: docs/infrastructure/SURGE_AND_OVERFLOW_PLAN.md. Run on the OWNER's (or operator's) machine with the
# official `hcloud` CLI and an active context (`hcloud context create kabso` asks for the API token there; it never
# goes into this repository or chat).
#
#   bash hcloud-create.sh --name media-s1 --env ./media-s1.env [--type ccx33] [--location nbg1] [--ssh-key NAME]
#                         [--network NAME] [--image ubuntu-24.04|<snapshot id>] [--ref staging] [--run]
#
#   --env FILE   a filled media.env for THIS node (copy of infra/media/.env.example; MEDIA_DOMAIN/TURN_DOMAIN e.g.
#                media-s1.<domain>/turn-s1.<domain>; in Phase 2 the cluster's LiveKit key pair and the redis block).
#                NODE_IP may be left as 0.0.0.0: it is replaced by the new server's address before the copy.
#   --run        actually create (default: DRY RUN, prints every command and the DNS records).
#
# Steps: render user-data (no secret) → hcloud server create (labels kabso-role=media-surge) → read its IPv4 →
# print the two DNS A records to add → wait for cloud-init → copy the env file over SSH (scp, mode 600) → run
# install.sh again → health.sh. The node serves new rooms only once it is in the cluster (Phase 2: Redis); in Phase 1
# a second node cannot take load (the API knows one LIVEKIT_URL) — see the plan.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NAME="" ENV_FILE="" TYPE=ccx33 LOCATION=nbg1 SSH_KEY="" NETWORK="" IMAGE=ubuntu-24.04 REF=staging RUN=0
REPO=${KABSO_REPO_URL:-https://github.com/sd343434/kabso.git}
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME=${2:?}; shift 2 ;;
    --env) ENV_FILE=${2:?}; shift 2 ;;
    --type) TYPE=${2:?}; shift 2 ;;
    --location) LOCATION=${2:?}; shift 2 ;;
    --ssh-key) SSH_KEY=${2:?}; shift 2 ;;
    --network) NETWORK=${2:?}; shift 2 ;;
    --image) IMAGE=${2:?}; shift 2 ;;
    --ref) REF=${2:?}; shift 2 ;;
    --run) RUN=1; shift ;;
    -h | --help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$NAME" =~ ^media-[a-z0-9-]{1,30}$ ]] || die "--name media-<id> is required (e.g. media-s1)"
[ -f "$ENV_FILE" ] || die "--env FILE (a filled media.env for this node) is required"
[ "$(stat -c %a "$ENV_FILE" 2>/dev/null || stat -f %Lp "$ENV_FILE")" = 600 ] || die "$ENV_FILE must be mode 600"
[[ "$REF" =~ ^[A-Za-z0-9._/-]+$ ]] || die "--ref: a branch or tag name"
grep -q '^LIVEKIT_API_SECRET=.\{32,\}' "$ENV_FILE" || die "$ENV_FILE has no LIVEKIT_API_SECRET (32+ chars)"
media_domain=$(sed -n 's/^MEDIA_DOMAIN=//p' "$ENV_FILE")
turn_domain=$(sed -n 's/^TURN_DOMAIN=//p' "$ENV_FILE")
[ -n "$media_domain" ] && [ -n "$turn_domain" ] || die "$ENV_FILE needs MEDIA_DOMAIN and TURN_DOMAIN"

run() { if [ "$RUN" -eq 1 ]; then "$@"; else printf '+ %s\n' "$*"; fi; }
[ "$RUN" -eq 0 ] || command -v hcloud >/dev/null || die "the hcloud CLI is not installed (https://github.com/hetznercloud/cli)"
[ "$RUN" -eq 0 ] || hcloud context active >/dev/null || die "no active hcloud context (hcloud context create kabso)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
userdata=$(<"$HERE/cloud-init.yaml.tmpl")
userdata=${userdata//\$\{KABSO_REF\}/$REF}
userdata=${userdata//\$\{KABSO_REPO_URL\}/$REPO}
printf '%s\n' "$userdata" >"$work/user-data.yaml"
grep -qiE 'secret|password|token' <(grep -v '^#' "$work/user-data.yaml") && die "user-data must not carry a secret"

create=(hcloud server create --name "$NAME" --type "$TYPE" --location "$LOCATION" --image "$IMAGE"
  --user-data-from-file "$work/user-data.yaml" --label kabso-role=media-surge --label kabso-node="$NAME")
[ -n "$SSH_KEY" ] && create+=(--ssh-key "$SSH_KEY")
[ -n "$NETWORK" ] && create+=(--network "$NETWORK")
echo "Hourly cost while it exists: see SURGE_AND_OVERFLOW_PLAN.md §5.3 (e.g. CCX33 €0.2227/h, 20 TB traffic included)."
run "${create[@]}"

if [ "$RUN" -eq 1 ]; then ip=$(hcloud server ip "$NAME"); else ip="<new IPv4>"; fi
cat <<EOF

DNS — add these two records at the domain's DNS provider now (TTL 60), then continue:
  ${media_domain}.  A  ${ip}
  ${turn_domain}.   A  ${ip}
EOF
[ "$RUN" -eq 1 ] || { echo; echo "(dry run: nothing was created; add --run)"; exit 0; }

ssh_opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
echo "Waiting for cloud-init on $ip …"
for _ in $(seq 1 90); do
  ssh "${ssh_opts[@]}" "root@$ip" test -f /var/lib/kabso-media-bootstrap.done 2>/dev/null && break
  sleep 10
done
ssh "${ssh_opts[@]}" "root@$ip" test -f /var/lib/kabso-media-bootstrap.done || die "cloud-init did not finish; see /var/log/kabso-media-install.log on the node"
sed "s/^NODE_IP=.*/NODE_IP=$ip/" "$ENV_FILE" >"$work/media.env"
chmod 600 "$work/media.env"
scp "${ssh_opts[@]}" -p "$work/media.env" "root@$ip:/etc/kabso-media/media.env"
ssh "${ssh_opts[@]}" "root@$ip" 'chmod 600 /etc/kabso-media/media.env && bash /opt/kabso-media/install.sh'
echo "Waiting for DNS + certificates, then health …"
for _ in $(seq 1 30); do
  ssh "${ssh_opts[@]}" "root@$ip" 'bash /opt/kabso-media/health.sh' >/dev/null 2>&1 && break
  sleep 20
done
ssh "${ssh_opts[@]}" "root@$ip" 'bash /opt/kabso-media/health.sh --verbose'
echo "Node $NAME is up at $ip. Remove it after the surge: bash $HERE/hcloud-delete.sh --name $NAME --run"
