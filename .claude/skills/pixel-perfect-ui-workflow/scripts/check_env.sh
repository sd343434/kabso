#!/usr/bin/env bash
# Report which capture / comparison tools are ACTUALLY available. Never assume; run this first.
set -u
ok() { printf '  [ok]      %s\n' "$*"; }
miss() { printf '  [missing] %s\n' "$*"; }
echo "Pixel-perfect UI workflow: environment check"
command -v python3 >/dev/null && ok "python3 $(python3 -V 2>&1 | cut -d' ' -f2)" || miss python3
python3 -c 'import PIL; print(PIL.__version__)' >/dev/null 2>&1 && ok "Pillow $(python3 -c 'import PIL; print(PIL.__version__)')" || miss "Pillow (pip install pillow)"
python3 -c 'import numpy' >/dev/null 2>&1 && ok "numpy $(python3 -c 'import numpy; print(numpy.__version__)')" || miss "numpy (pip install numpy)"
python3 -c 'import skimage' >/dev/null 2>&1 && ok "scikit-image (optional; visual_diff.py has its own SSIM)" || miss "scikit-image (optional; not required)"
command -v compare >/dev/null && ok "ImageMagick $(convert -version | head -1 | awk '{print $3}') compare (no SSIM metric in IM6)" || miss "ImageMagick (optional)"
command -v node >/dev/null && ok "node $(node -v)" || miss node
if [ -d /opt/node-tools/node_modules/playwright ]; then ok "Playwright at /opt/node-tools/node_modules/playwright"; else miss "Playwright (/opt/node-tools/node_modules/playwright)"; fi
if [ -d "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}" ]; then ok "Chromium for Playwright in ${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} (do NOT run playwright install)"; else miss "Playwright browsers"; fi
FLUTTER="$(command -v flutter || echo /opt/sdk/flutter/bin/flutter)"
if [ -x "$FLUTTER" ]; then ok "flutter at $FLUTTER ($("$FLUTTER" --version 2>/dev/null | head -1 | awk '{print $2}'))"; else miss "flutter"; fi
[ -f apps/mobile/tool/ui_audit/capture_test.dart ] && ok "headless app render harness: apps/mobile/tool/ui_audit/capture_test.dart (NOT a device screenshot)" || miss "tool/ui_audit harness (run from repo root)"
echo "Not available here (do not claim otherwise): Android emulator, iOS simulator, physical devices."
