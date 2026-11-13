#!/usr/bin/env bash
# Kabso Live — mirrors the staging test APK (D330, docs/DEPLOYMENT.md §11.8). Run by update.sh at the end of every
# kabso-update.timer run (best effort: a failure here is logged and never stops or fails the API update); by hand:
# `sudo /opt/kabso/infra/deploy/mirror-apk.sh`.
#
# CI's `staging-apk-release` job publishes the arm64 APK of every green `staging` push as the assets of the rolling
# public prerelease `staging-latest`: kabso-staging.apk and kabso-staging.txt (commit, version, sha256, size, built).
# This script fetches the small manifest each run (no token, no GitHub API: release downloads are not rate-limited
# like the API) and downloads the APK only when the manifest's sha256 differs from the one served. The APK is checked
# (size bounds, size and sha256 against the manifest, the ZIP signature) before anything is replaced, then moved into
# infra/deploy/app/ with renames inside that directory (Caddy mounts it read-only at /srv/app and serves it at
# https://live.<domain>/app/), next to a gzip copy (sent with Content-Encoding: gzip to browsers that accept it: about the size of the old zipped
# artifact on the wire) and a generated /app/ page. Only the latest build is kept.
set -euo pipefail

APP_DIR=${APP_DIR:-/opt/kabso}
OUT_DIR=${KABSO_APK_DIR:-$APP_DIR/infra/deploy/app}
REPO=${KABSO_APK_REPO:-sd343434/kabso}
TAG=${KABSO_APK_TAG:-staging-latest}
BASE=${KABSO_APK_BASE:-https://github.com/$REPO/releases/download/$TAG}
MIN_SIZE=10000000  # 10 MB: anything smaller is not our APK
MAX_SIZE=400000000 # 400 MB

mkdir -p "$OUT_DIR"
# Leftovers of an interrupted run (power loss, timeout).
find "$OUT_DIR" -maxdepth 1 -name '.tmp.*' -mmin +60 -exec rm -rf {} + 2>/dev/null || true
tmp=$(mktemp -d "$OUT_DIR/.tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

CURL=(curl -sSL --proto '=https' --proto-redir '=https' --connect-timeout 15 --retry 2)

code=$("${CURL[@]}" --max-time 60 -o "$tmp/manifest" -w '%{http_code}' "$BASE/kabso-staging.txt" || true)
if [ "$code" = 404 ]; then
  exit 0 # nothing published yet (first CI run on staging after D330 still pending)
fi
[ "$code" = 200 ] || { echo "staging APK manifest: HTTP ${code:-none} from $BASE/kabso-staging.txt" >&2; exit 1; }

field() { sed -n "s/^$1=//p" "$tmp/manifest" | head -n 1 | tr -d '\r'; }
commit=$(field commit)
version=$(field version)
sha=$(field sha256)
size=$(field size)
built=$(field built)
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo "staging APK manifest: bad commit" >&2; exit 1; }
[[ "$version" =~ ^[0-9A-Za-z.+-]{1,64}$ ]] || { echo "staging APK manifest: bad version" >&2; exit 1; }
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "staging APK manifest: bad sha256" >&2; exit 1; }
[[ "$built" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { echo "staging APK manifest: bad date" >&2; exit 1; }
[[ "$size" =~ ^[0-9]{1,10}$ ]] && [ "$size" -ge "$MIN_SIZE" ] && [ "$size" -le "$MAX_SIZE" ] ||
  { echo "staging APK manifest: size ${size:-?} outside $MIN_SIZE…$MAX_SIZE bytes" >&2; exit 1; }

served="$OUT_DIR/kabso-staging.txt"
if [ "${1:-}" != "--force" ] && [ -f "$OUT_DIR/kabso-staging.apk" ] && [ -f "$served" ] &&
  [ "$(sed -n 's/^sha256=//p' "$served" | head -n 1)" = "$sha" ]; then
  exit 0 # already serving this build
fi

# Room for the APK and its gzip copy next to the ones being served.
avail=$(df -P -B1 "$OUT_DIR" | awk 'NR==2 {print $4}')
[ "${avail:-0}" -gt $((size * 2 + 200000000)) ] ||
  { echo "staging APK: not enough disk in $OUT_DIR (${avail:-?} bytes free)" >&2; exit 1; }

echo "staging APK: downloading $version (${commit:0:12}, $size bytes)"
"${CURL[@]}" -f --max-time 540 -o "$tmp/kabso-staging.apk" "$BASE/kabso-staging.apk"
got_size=$(stat -c %s "$tmp/kabso-staging.apk")
[ "$got_size" = "$size" ] || { echo "staging APK: got $got_size bytes, manifest says $size (still uploading?)" >&2; exit 1; }
got_sha=$(sha256sum "$tmp/kabso-staging.apk" | cut -d' ' -f1)
[ "$got_sha" = "$sha" ] || { echo "staging APK: sha256 mismatch (APK and manifest from different runs?)" >&2; exit 1; }
[ "$(head -c 4 "$tmp/kabso-staging.apk" | od -An -tx1 | tr -d ' \n')" = "504b0304" ] ||
  { echo "staging APK: not a ZIP/APK file" >&2; exit 1; }

nice -n 10 gzip -6 -n -c "$tmp/kabso-staging.apk" > "$tmp/kabso-staging.apk.gz"
gz_size=$(stat -c %s "$tmp/kabso-staging.apk.gz")
cp "$tmp/manifest" "$tmp/kabso-staging.txt"

mb=$(awk -v b="$size" 'BEGIN {printf "%.0f", b / 1000000}')
gz_mb=$(awk -v b="$gz_size" 'BEGIN {printf "%.0f", b / 1000000}')
short=${commit:0:7}
# Every value below was validated above (hex, digits, [0-9A-Za-z.+-], an ISO date): nothing needs HTML escaping.
cat > "$tmp/index.html" <<EOF
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Kabso Live — نسخة الاختبار / staging APK</title>
<style>
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#111;color:#eee;line-height:1.6}
main{max-width:30rem;margin:0 auto;padding:1.5rem 1rem}
h1{font-size:1.35rem;margin:0 0 .25rem}
.en{direction:ltr;text-align:left;color:#bbb}
.btn{display:block;text-align:center;background:#e53935;color:#fff;text-decoration:none;font-weight:700;font-size:1.1rem;padding:.9rem 1rem;border-radius:.75rem;margin:1.25rem 0 .5rem}
dl{display:grid;grid-template-columns:auto 1fr;gap:.25rem .75rem;margin:1rem 0;direction:ltr;text-align:left;font-size:.9rem}
dt{color:#999}
dd{margin:0;word-break:break-all;font-family:ui-monospace,monospace}
small,a{color:#bbb}
</style>
</head>
<body>
<main>
<h1>كابسو لايف — نسخة الاختبار (staging)</h1>
<p class="en">Kabso Live — staging test build (Android, arm64)</p>
<a class="btn" href="kabso-staging.apk" download>تحميل التطبيق / Download APK (~${gz_mb} MB)</a>
<p><small>بعد التحميل افتح الملف واسمح بالتثبيت من هذا المصدر إذا طلب الهاتف. هذه نسخة اختبار متصلة بخادم الاختبار، وليست نسخة المتجر.</small></p>
<p class="en"><small>Open the file once downloaded and allow installs from this source if Android asks. Test build for the staging server, not the store version.</small></p>
<dl>
<dt>Version</dt><dd>${version}</dd>
<dt>Commit</dt><dd><a href="https://github.com/${REPO}/commit/${commit}">${short}</a></dd>
<dt>Built</dt><dd>${built}</dd>
<dt>Size</dt><dd>${mb} MB (${gz_mb} MB compressed download)</dd>
<dt>SHA-256</dt><dd>${sha}</dd>
</dl>
<p><small>إذا فشل التحميل أو لم يُفتح الملف: <a href="raw/kabso-staging.apk" download>التحميل بدون ضغط</a> /
<span class="en">Download fails or the file will not open? <a href="raw/kabso-staging.apk" download>Uncompressed download</a></span></small></p>
</main>
</body>
</html>
EOF

chmod 644 "$tmp/kabso-staging.apk" "$tmp/kabso-staging.apk.gz" "$tmp/kabso-staging.txt" "$tmp/index.html"
# Renames within one directory: an open download keeps reading the old file. The gzip copy goes first so the
# compressed and the plain URL never serve an older build than the page states for longer than these four renames.
mv -f "$tmp/kabso-staging.apk.gz" "$OUT_DIR/kabso-staging.apk.gz"
mv -f "$tmp/kabso-staging.apk" "$OUT_DIR/kabso-staging.apk"
mv -f "$tmp/kabso-staging.txt" "$OUT_DIR/kabso-staging.txt"
mv -f "$tmp/index.html" "$OUT_DIR/index.html"
echo "staging APK: serving $version (${commit:0:12}, $size bytes, gzip $gz_size)"
