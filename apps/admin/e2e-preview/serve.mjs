/**
 * D356 (CONVENTIONS §10.152): a local stand-in for Caddy's admin.<domain> block, for the preview's Playwright tests and
 * the captures — the built panel (apps/admin/dist, SPA fallback) at / and the built event page preview bundle at
 * /event-preview/ with the SAME security headers as infra/deploy/Caddyfile (kept in sync by `headers.test.ts`), the
 * harness page at /__harness.html. /api/* answers 404 (the tests route it themselves). No dependencies.
 *
 *   EVENT_PREVIEW_DIR=/dev/shm/event-preview ADMIN_DIST=apps/admin/dist PORT=5190 node apps/admin/e2e-preview/serve.mjs
 */
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ADMIN_CSP, PREVIEW_CSP } from './headers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT ?? 5190);
const adminDir = resolve(process.env.ADMIN_DIST ?? join(here, '..', 'dist'));
const previewDir = process.env.EVENT_PREVIEW_DIR ? resolve(process.env.EVENT_PREVIEW_DIR) : null;

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.bin': 'application/octet-stream',
  '.frag': 'application/octet-stream',
};

async function file(root, rel) {
  const path = normalize(join(root, rel));
  if (!path.startsWith(root)) return null;
  try {
    const s = await stat(path);
    if (s.isDirectory()) return file(root, join(rel, 'index.html'));
    return { path, body: await readFile(path) };
  } catch {
    return null;
  }
}

createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://local');
  const path = decodeURIComponent(url.pathname);
  const send = (status, body, type, headers) => {
    res.writeHead(status, { 'Content-Type': type, 'X-Content-Type-Options': 'nosniff', ...headers });
    res.end(body);
  };
  if (path.startsWith('/api/')) return send(404, '{"code":"NOT_FOUND"}', 'application/json', {});
  if (path === '/event-preview') return send(308, '', 'text/plain', { Location: '/event-preview/' });
  if (path.startsWith('/event-preview/')) {
    const f = previewDir && (await file(previewDir, path.slice('/event-preview/'.length) || 'index.html'));
    const headers = { 'Content-Security-Policy': PREVIEW_CSP, 'X-Frame-Options': 'SAMEORIGIN', 'Cache-Control': 'no-store' };
    if (!f) return send(404, 'not found', 'text/plain', headers);
    return send(200, f.body, TYPES[extname(f.path)] ?? 'application/octet-stream', headers);
  }
  const headers = { 'Content-Security-Policy': ADMIN_CSP, 'X-Frame-Options': 'DENY' };
  if (path === '/__harness.html' || path === '/__harness.js') {
    return send(200, await readFile(join(here, path.slice(3))), TYPES[extname(path)], headers);
  }
  const f = (await file(adminDir, path.slice(1) || 'index.html')) ?? (await file(adminDir, 'index.html'));
  if (!f) return send(404, 'no admin build', 'text/plain', headers);
  return send(200, f.body, TYPES[extname(f.path)] ?? 'application/octet-stream', headers);
}).listen(port, '127.0.0.1', () => process.stdout.write(`serving on http://127.0.0.1:${port}\n`));
