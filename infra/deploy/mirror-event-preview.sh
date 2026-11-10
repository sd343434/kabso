#!/usr/bin/env bash
# Kabso Live — mirrors the event page preview bundle (D356, CONVENTIONS §10.152, docs/DEPLOYMENT.md §11.14): the app's
# real Flutter event page built for the web, which the admin panel's design step embeds at
# https://admin.<domain>/event-preview/. Run by update.sh on every kabso-update.timer run (best effort: a failure here
# is logged and never stops the API update); by hand: `sudo /opt/kabso/infra/deploy/mirror-event-preview.sh [--force]`.
#
# CI's `event-preview` job builds the bundle (apps/mobile/tool/build_event_preview.sh, the pinned Flutter) and smoke-
# tests it in Chromium; on a green push to `staging` the `event-preview-release` job publishes it as the assets
# kabso-event-preview.tar.gz + kabso-event-preview.txt (commit, protocol, sha256, size, built) of the rolling
# prerelease `staging-latest` (the same release as the staging APK, D330). No Flutter on the server: this script
# fetches the small manifest (no token, no GitHub API), downloads the archive only when its sha256 differs from the
# one served, checks it (size bounds, sha256, safe paths, the files the page needs, protocol 1), and swaps it into
# infra/deploy/event-preview/current with renames (Caddy mounts the folder read-only at /srv/event-preview). Only the
# latest bundle is kept. Without one, the panel shows its sketch preview with a notice.
set -euo pipefail

APP_DIR=${APP_DIR:-/opt/kabso}
OUT_DIR=${KABSO_PREVIEW_DIR:-$APP_DIR/infra/deploy/event-preview}
REPO=${KABSO_PREVIEW_REPO:-${KABSO_APK_REPO:-sd343434/kabso}}
TAG=${KABSO_PREVIEW_TAG:-staging-latest}
BASE=${KABSO_PREVIEW_BASE:-https://github.com/$REPO/releases/download/$TAG}
MIN_SIZE=3000000   # 3 MB: anything smaller is not the bundle (CanvasKit alone is ~7 MB)
MAX_SIZE=120000000 # 120 MB

mkdir -p "$OUT_DIR"
find "$OUT_DIR" -maxdepth 1 -name '.tmp.*' -mmin +60 -exec rm -rf {} + 2>/dev/null || true
tmp=$(mktemp -d "$OUT_DIR/.tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

CURL=(curl -sSL --proto '=https' --proto-redir '=https' --connect-timeout 15 --retry 2)

code=$("${CURL[@]}" --max-time 60 -o "$tmp/manifest" -w '%{http_code}' "$BASE/kabso-event-preview.txt" || true)
if [ "$code" = 404 ]; then
  exit 0 # nothing published yet
fi
[ "$code" = 200 ] || { echo "event preview manifest: HTTP ${code:-none} from $BASE/kabso-event-preview.txt" >&2; exit 1; }

field() { sed -n "s/^$1=//p" "$tmp/manifest" | head -n 1 | tr -d '\r'; }
commit=$(field commit)
protocol=$(field protocol)
sha=$(field sha256)
size=$(field size)
built=$(field built)
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo "event preview manifest: bad commit" >&2; exit 1; }
[ "$protocol" = 1 ] || { echo "event preview manifest: protocol ${protocol:-?}, this panel speaks 1" >&2; exit 1; }
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "event preview manifest: bad sha256" >&2; exit 1; }
[[ "$built" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { echo "event preview manifest: bad date" >&2; exit 1; }
[[ "$size" =~ ^[0-9]{1,10}$ ]] && [ "$size" -ge "$MIN_SIZE" ] && [ "$size" -le "$MAX_SIZE" ] ||
  { echo "event preview manifest: size ${size:-?} outside $MIN_SIZE…$MAX_SIZE bytes" >&2; exit 1; }

served="$OUT_DIR/current/kabso-event-preview.txt"
if [ "${1:-}" != "--force" ] && [ -f "$OUT_DIR/current/index.html" ] && [ -f "$served" ] &&
  [ "$(sed -n 's/^sha256=//p' "$served" | head -n 1)" = "$sha" ]; then
  exit 0 # already serving this bundle
fi

avail=$(df -P -B1 "$OUT_DIR" | awk 'NR==2 {print $4}')
[ "${avail:-0}" -gt $((size * 4 + 100000000)) ] ||
  { echo "event preview: not enough disk in $OUT_DIR (${avail:-?} bytes free)" >&2; exit 1; }

"${CURL[@]}" --max-time 600 --max-filesize "$MAX_SIZE" -o "$tmp/bundle.tar.gz" "$BASE/kabso-event-preview.tar.gz"
[ "$(stat -c %s "$tmp/bundle.tar.gz")" = "$size" ] || { echo "event preview: size differs from the manifest" >&2; exit 1; }
[ "$(sha256sum "$tmp/bundle.tar.gz" | cut -d' ' -f1)" = "$sha" ] || { echo "event preview: sha256 mismatch" >&2; exit 1; }

# Only plain relative paths (no absolute path, no "..", no links or devices).
if tar -tzvf "$tmp/bundle.tar.gz" | awk '{print substr($1,1,1)}' | grep -qv '^[-d]$'; then
  echo "event preview: the archive holds something other than files and folders" >&2; exit 1
fi
if tar -tzf "$tmp/bundle.tar.gz" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo "event preview: unsafe path in the archive" >&2; exit 1
fi
mkdir "$tmp/next"
tar -xzf "$tmp/bundle.tar.gz" -C "$tmp/next" --no-same-owner --no-same-permissions
for f in index.html flutter_bootstrap.js main.dart.js canvaskit/canvaskit.wasm assets/AssetManifest.bin; do
  [ -f "$tmp/next/$f" ] || { echo "event preview: $f missing from the bundle" >&2; exit 1; }
done
cp "$tmp/manifest" "$tmp/next/kabso-event-preview.txt"
chmod -R a+rX "$tmp/next"

next="$OUT_DIR/.next"
rm -rf "$next" "$OUT_DIR/.old"
mv "$tmp/next" "$next"
if [ -d "$OUT_DIR/current" ]; then mv "$OUT_DIR/current" "$OUT_DIR/.old"; fi
mv "$next" "$OUT_DIR/current"
rm -rf "$OUT_DIR/.old"
echo "event preview: serving ${commit:0:12} (built $built)"
