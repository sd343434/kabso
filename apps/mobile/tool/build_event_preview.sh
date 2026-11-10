#!/usr/bin/env bash
# D356 (CONVENTIONS §10.152, docs/DEPLOYMENT.md §11.14): builds the event page preview bundle — the real Flutter event
# page as a static web app the admin panel embeds at /event-preview/ — into OUT_DIR, then trims it and writes its
# manifest. Used by CI (`event-preview` job) and by hand:
#
#   apps/mobile/tool/build_event_preview.sh /dev/shm/event-preview [--dart-define=PREVIEW_PARENT_ORIGINS=http://localhost:5180]
#
# Run from anywhere (it cds into apps/mobile); needs the pinned Flutter (3.47.7) on PATH and `flutter pub get` done.
# The phone app is not involved: the entry is lib/preview_main.dart, which lib/main.dart never imports.
#
# Trimming (the bundle is served, not installed, so only what the page can load is kept):
#   - canvaskit: the CanvasKit renderer only (canvaskit.{js,wasm} and the Chromium variant); the skwasm / wimp /
#     webparagraph renderers are for --wasm or experimental builds, the .symbols files for debugging;
#   - assets: the asset folders the event page never draws (live rooms, PK, sounds, splash, …). A folder dropped by
#     mistake shows as a missing picture in the preview, never as a crash; the smoke test fails on "Unable to load
#     asset".
set -euo pipefail

out=${1:?usage: build_event_preview.sh OUT_DIR [flutter build args…]}
shift
cd "$(dirname "$0")/.."

rm -rf "$out"
flutter build web --release --no-pub \
  -t lib/preview_main.dart \
  --no-web-resources-cdn \
  --base-href /event-preview/ \
  --no-wasm-dry-run \
  -o "$out" "$@"

# The renderer.
find "$out/canvaskit" -name '*.symbols' -delete
rm -rf "$out/canvaskit/skwasm"* "$out/canvaskit/wimp"* "$out/canvaskit/webparagraph"
# No offline cache: the panel always loads the current bundle (Caddy sends no-store for the page).
rm -f "$out/flutter_service_worker.js"

# Asset folders the event page does not use.
for dir in sounds splash pk battle emojis staff live_themes cp_space live_cp_seats live_bar live_room_icons \
  live_cinema live_rank_frames live_top_frames families flags special_id global_strips category_icons taps charm \
  win_frames host_frames host_agent recharge_agent recharge_badges profile_card card_boxes host_targets profile; do
  rm -rf "$out/assets/assets/$dir"
done

[ -f "$out/index.html" ] && [ -f "$out/main.dart.js" ] && [ -f "$out/canvaskit/canvaskit.wasm" ] ||
  { echo "the preview build is incomplete" >&2; exit 1; }

commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)
{
  echo "commit=$commit"
  echo "flutter=$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n 1)"
  echo "protocol=1"
  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$out/preview-build.txt"
echo "event preview built in $out ($(du -sh "$out" | cut -f1))"
