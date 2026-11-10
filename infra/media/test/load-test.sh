#!/usr/bin/env bash
# Kabso Live — one load-test STAGE against a media node, from a GENERATOR machine (D350).
# Plan, stages and thresholds: docs/infrastructure/SINGLE_NODE_CAPACITY_RESULTS.md (results template) and
# LIVEKIT_SINGLE_NODE_DEPLOYMENT.md §10.
#
#   LIVEKIT_API_KEY=… LIVEKIT_API_SECRET=… bash load-test.sh --url wss://media1.<domain> --shape SOLO \
#       --rooms 10 --subs 20 [--duration 10m] [--prefix g1] [--out DIR] [--run]
#
# Without --run it only prints the commands (dry run). One `lk load-test` process per room (the tool tests one room per
# run, docs.livekit.io/transport/self-hosting/benchmark), all started together, each with its own log; at the end the
# script prints each room's subscriber summary line.
#
# Room shapes (Kabso's live modes, approximated with lk's simulated participants):
#   SOLO   1 video publisher (720p simulcast)                  + SUBS subscribers  (video live)
#   PK     2 video publishers                                  + SUBS subscribers  (a PK battle seen by one audience;
#                                                                                   lk cannot join two rooms per viewer)
#   MULTI  1 host + 8 seated video publishers (9), 3x3 layout   + SUBS subscribers  (multi-guest live)
#   AUDIO  1 host + 8 seated audio publishers (9), audio only   + SUBS subscribers  (audio room)
# Limits of the simulation: lk subscribers are VISIBLE participants (Kabso viewers are hidden), publish data is not
# simulated, and the codec is lk's choice (vp8 and h264) unless --codec is given — the apps publish VP8.
#
# Safety: refuses to run on the node under test (the generator's own traffic would be measured); needs
# `ulimit -n` >= 65535; uses the `lk` binary if present, else the pinned livekit/livekit-cli image.
set -euo pipefail

URL="" SHAPE="" ROOMS=1 SUBS=10 DURATION=10m PREFIX=g1 OUT="" RUN=0 CODEC="vp8" PER_SECOND=5
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL=${2:?}; shift 2 ;;
    --shape) SHAPE=${2:?}; shift 2 ;;
    --rooms) ROOMS=${2:?}; shift 2 ;;
    --subs) SUBS=${2:?}; shift 2 ;;
    --duration) DURATION=${2:?}; shift 2 ;;
    --prefix) PREFIX=${2:?}; shift 2 ;;
    --out) OUT=${2:?}; shift 2 ;;
    --codec) CODEC=${2:?}; shift 2 ;;
    --num-per-second) PER_SECOND=${2:?}; shift 2 ;;
    --run) RUN=1; shift ;;
    -h | --help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$URL" =~ ^wss?://[A-Za-z0-9.-]+(:[0-9]+)?/?$ ]] || die "--url wss://media1.<domain> is required"
[[ "$ROOMS" =~ ^[0-9]+$ && "$ROOMS" -ge 1 && "$SUBS" =~ ^[0-9]+$ ]] || die "--rooms >= 1 and --subs >= 0 are numbers"
[[ "$PREFIX" =~ ^[a-z0-9-]{1,20}$ ]] || die "--prefix: a-z, 0-9, - (one per generator machine, e.g. g1, g2)"
[[ "$CODEC" =~ ^(vp8|h264|both)$ ]] || die "--codec vp8|h264|both"
case "$SHAPE" in
  SOLO) PUB=(--video-publishers 1) ;;
  PK) PUB=(--video-publishers 2) ;;
  MULTI) PUB=(--video-publishers 9 --layout 3x3) ;;
  AUDIO) PUB=(--audio-publishers 9) ;;
  *) die "--shape SOLO|PK|MULTI|AUDIO" ;;
esac
[ "$CODEC" = both ] || [ "$SHAPE" = AUDIO ] || PUB+=(--video-codec "$CODEC")

host=${URL#*://}
host=${host%%[:/]*}
target_ips=$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u || true)
# KABSO_LT_ALLOW_LOCAL=1 only for a functional smoke test of this script on a laptop/CI, never for measurements.
[ "${KABSO_LT_ALLOW_LOCAL:-0}" = 1 ] && target_ips=""
local_ips=$({ ip -o addr 2>/dev/null | awk '{print $4}' | cut -d/ -f1; hostname -I 2>/dev/null | tr ' ' '\n'
  printf '127.0.0.1\n::1\n'; } | sort -u)
for ip in $target_ips; do
  if grep -qxF "$ip" <<<"$local_ips"; then
    die "$host resolves to this machine ($ip): run generators on OTHER machines, never on the node under test"
  fi
done

if command -v lk >/dev/null; then
  LK=(lk)
else
  LK=(docker run --rm --network host -e LIVEKIT_API_KEY -e LIVEKIT_API_SECRET
    livekit/livekit-cli:v2.19.3@sha256:cb460d18fb001c81fb3b6c9bf8fee487e64fb64124f3495086823ac5cd0b7a81)
fi

if [ "$RUN" -eq 1 ]; then
  [ -n "${LIVEKIT_API_KEY:-}" ] && [ -n "${LIVEKIT_API_SECRET:-}" ] || die "LIVEKIT_API_KEY / LIVEKIT_API_SECRET must be set"
  [ "$(ulimit -n)" -ge 65535 ] || die "ulimit -n is $(ulimit -n); run: ulimit -n 65535"
  OUT=${OUT:-./loadtest-$(date -u +%Y%m%dT%H%M%SZ)-$SHAPE-$PREFIX}
  mkdir -p "$OUT"
  printf 'url=%s shape=%s rooms=%s subs=%s duration=%s codec=%s prefix=%s started=%s\n' \
    "$URL" "$SHAPE" "$ROOMS" "$SUBS" "$DURATION" "$CODEC" "$PREFIX" "$(date -u +%FT%TZ)" >"$OUT/stage.txt"
fi

pids=()
for i in $(seq 1 "$ROOMS"); do
  room="lt-$PREFIX-$(printf '%s' "$SHAPE" | tr '[:upper:]' '[:lower:]')-$i"
  cmd=("${LK[@]}" load-test --url "$URL" --room "$room" "${PUB[@]}" --subscribers "$SUBS"
    --duration "$DURATION" --num-per-second "$PER_SECOND" --identity-prefix "$PREFIX-$i")
  if [ "$RUN" -eq 1 ]; then
    "${cmd[@]}" >"$OUT/$room.log" 2>&1 &
    pids+=($!)
  else
    printf '+ %s\n' "${cmd[*]}"
  fi
done
[ "$RUN" -eq 1 ] || { echo "(dry run: add --run to start ${ROOMS} room(s))"; exit 0; }

echo "Started ${#pids[@]} room(s); logs in $OUT. Waiting for --duration $DURATION …"
fail=0
for p in "${pids[@]}"; do wait "$p" || fail=$((fail + 1)); done
echo "finished=$(date -u +%FT%TZ) failed_processes=$fail" >>"$OUT/stage.txt"
echo "Per-room totals (subscriber 'Total' line: tracks, bitrate, packet loss, errors):"
for f in "$OUT"/lt-*.log; do printf '%s  %s\n' "$(basename "$f" .log)" "$(grep -E '│ Total' "$f" | tail -1 | tr -s ' ')"; done
[ "$fail" -eq 0 ]
