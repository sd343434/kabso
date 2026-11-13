#!/usr/bin/env bash
# D198 (CONVENTIONS §10.61.3, privacy policy §12): kabsolive.com sets NO tracking cookies and loads no analytics,
# advertising or tracking scripts — only the language choice (localStorage) and a 5-minute copy of the site settings
# (sessionStorage), both strictly necessary, so the site needs no consent banner.
#
# Adding analytics, a pixel, a tag manager, a third-party embed or any cookie REQUIRES first: a consent banner that
# blocks it until the visitor opts in (EU/UK ePrivacy + GDPR, CPRA "share" opt-out, LGPD), an update of the privacy
# policy (cookies section and processors) published as a new version (`legal-admin publish privacy`), and the owner's
# approval on the board. This check fails CI until that is done and this list is consciously changed.
set -euo pipefail
cd "$(dirname "$0")/.."
site=infra/deploy/site
pattern='document\.cookie|google-analytics|googletagmanager|gtag\(|\bga\(|fbq\(|connect\.facebook\.net|hotjar|mixpanel|segment\.(io|com)|plausible|matomo|clarity\.ms|amplitude|posthog|tiktok\.com/i18n/pixel|analytics\.tiktok|snap\.licdn|doubleclick|adservice|<iframe'
if grep -rIniE "$pattern" "$site" --include='*.html' --include='*.js' --include='*.css'; then
  echo "::error::kabsolive.com must not load trackers or set cookies without a consent banner (D198, see $0)." >&2
  exit 1
fi
# Third-party origins in the pages: only Stripe is allowed (the top-up hand-off), never scripts from elsewhere.
if grep -rIoE '<script[^>]+src="https?://[^"]+"' "$site" --include='*.html'; then
  echo "::error::kabsolive.com loads a third-party script; add a consent banner and update the policy first (D198)." >&2
  exit 1
fi
echo "kabsolive.com: no trackers, no cookies, no third-party scripts (no consent banner needed)."
