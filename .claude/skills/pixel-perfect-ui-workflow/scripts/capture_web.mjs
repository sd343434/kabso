#!/usr/bin/env node
// Capture the REAL Kabso Live Flutter app (web --profile build) in headless Chromium at a fixed
// logical viewport and device pixel ratio. This is the project's verified way to screenshot the
// running app in this environment (used for KL-035a/b/c). It does not alter the screenshot.
//
// Prerequisites (see ../SKILL.md "Capture"):
//   1. A web build made from a SCRATCH COPY of apps/mobile (never add a web platform to the repo):
//        flutter create --platforms=web --project-name kabso_live .
//        flutter build web --profile --dart-define=API_BASE_URL=http://localhost:<apiPort>
//      (--profile because release builds refuse http API URLs.)
//   2. A static server for build/web (e.g. `python3 -m http.server 8135 -d build/web`).
//   3. If the app talks to a local API, CORS_ORIGINS on the API must include the static origin.
//
// Usage:
//   node capture_web.mjs --url http://localhost:8135/#/live --out out.png \
//     [--width 393 --height 852 --dpr 3] [--locale ar] [--wait 4000] [--web-dir path/to/build/web] \
//     [--profile-dir dir] [--offline] [--hold "<url substring>"] [--full-page] [--nav-timeout 30000]
//     [--color-scheme light|dark] [--storage 'key=value;key2=value2']
//
// --web-dir lets the script serve CanvasKit from the build instead of the gstatic CDN (blocked here).
// --profile-dir reuses a persistent browser profile (keeps the app's login between captures).
// --hold delays matching requests forever to capture a loading state (label it SIMULATED).
// --offline switches the browser offline after load (label it SIMULATED).
// --color-scheme sets prefers-color-scheme. --storage seeds localStorage before the app starts, e.g.
//   a Flutter app's saved theme: --storage 'flutter.pref.themeMode="light"' (shared_preferences keys
//   carry the `flutter.` prefix and JSON-encoded values).
// Prints a JSON line with the exact capture parameters; record it in the report.
// Exit codes: 0 = captured, 1 = capture failed (JSON error on stderr), 2 = usage error.
import { createRequire } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const require = createRequire('/opt/node-tools/node_modules/');
const { chromium } = require('playwright');

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, cur, i, arr) => {
    if (cur.startsWith('--')) {
      const next = arr[i + 1];
      acc.push([cur.slice(2), next && !next.startsWith('--') ? next : true]);
    }
    return acc;
  }, []),
);
if (!args.url || !args.out) {
  console.error('usage: capture_web.mjs --url URL --out file.png [--width 393 --height 852 --dpr 3 --locale ar ...]');
  process.exit(2);
}
const width = Number(args.width ?? 393);
const height = Number(args.height ?? 852);
const dpr = Number(args.dpr ?? 3);
const locale = String(args.locale ?? 'en');
const wait = Number(args.wait ?? 4000);
const webDir = args['web-dir'] ? String(args['web-dir']) : null;
const colorScheme = args['color-scheme'] ? String(args['color-scheme']) : null;
const storage = args.storage
  ? Object.fromEntries(
      String(args.storage)
        .split(';')
        .filter(Boolean)
        .map((kv) => [kv.slice(0, kv.indexOf('=')), kv.slice(kv.indexOf('=') + 1)]),
    )
  : {};
if (Object.keys(storage).some((k) => !k)) {
  console.error('--storage expects key=value pairs separated by ";"');
  process.exit(2);
}

const opts = {
  headless: true,
  locale,
  viewport: { width, height },
  deviceScaleFactor: dpr,
  ...(colorScheme ? { colorScheme } : {}),
  args: ['--no-proxy-server'],
};
// Resources are released in `finally` on success and on failure (D6): the persistent context, or
// the context and the browser it was launched from. A capture failure exits 1 with a JSON error;
// SIGINT/SIGTERM also close the browser before exiting.
let browser = null;
let ctx = null;
let exitCode = 0;
const closeAll = async () => {
  const c = ctx;
  const b = browser;
  ctx = null;
  browser = null;
  await c?.close().catch(() => {});
  await b?.close().catch(() => {});
};
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.once(sig, () => {
    closeAll().finally(() => process.exit(130));
  });
}

try {
  if (args['profile-dir']) {
    ctx = await chromium.launchPersistentContext(String(args['profile-dir']), opts);
  } else {
    browser = await chromium.launch({ headless: true, args: opts.args });
    ctx = await browser.newContext(opts);
  }

  if (Object.keys(storage).length) {
    await ctx.addInitScript((entries) => {
      for (const [k, v] of Object.entries(entries)) window.localStorage.setItem(k, v);
    }, storage);
  }

  const blocked = [];
  await ctx.route(/.*/, async (route) => {
    const url = route.request().url();
    if (args.hold && url.includes(String(args.hold))) return; // never fulfil -> loading state
    const u = new URL(url);
    if (u.hostname === 'localhost' || u.hostname === '127.0.0.1') return route.continue();
    if (webDir && u.host === 'www.gstatic.com' && u.pathname.startsWith('/flutter-canvaskit/')) {
      const f = join(webDir, 'canvaskit', u.pathname.split('/').slice(3).join('/'));
      if (existsSync(f)) {
        return route.fulfill({ body: readFileSync(f), contentType: f.endsWith('.wasm') ? 'application/wasm' : 'text/javascript' });
      }
    }
    blocked.push(url);
    return route.abort();
  });

  const page = ctx.pages?.()[0] ?? (await ctx.newPage());
  const consoleErrors = [];
  page.on('console', (m) => m.type() === 'error' && consoleErrors.push(m.text().slice(0, 300)));
  await page.goto(String(args.url), { timeout: Number(args['nav-timeout'] ?? 30000) });
  await page.waitForTimeout(wait);
  if (args.offline) {
    await ctx.setOffline(true);
    await page.waitForTimeout(1500);
  }
  await page.screenshot({ path: String(args.out), fullPage: Boolean(args['full-page']) });
  console.log(
    JSON.stringify({
      out: args.out,
      url: args.url,
      viewport: { width, height },
      dpr,
      pixels: { width: width * dpr, height: height * dpr },
      locale,
      colorScheme,
      storage,
      simulated: { offline: Boolean(args.offline), hold: args.hold ?? null },
      blockedExternal: blocked.length,
      consoleErrors,
    }),
  );
} catch (e) {
  exitCode = 1;
  console.error(JSON.stringify({ error: String(e?.message ?? e).split('\n')[0], url: args.url, out: args.out }));
} finally {
  await closeAll();
}
process.exit(exitCode);
