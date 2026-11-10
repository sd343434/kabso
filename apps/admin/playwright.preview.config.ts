import { defineConfig } from '@playwright/test';

/**
 * D356 (CONVENTIONS §10.152): the event page preview against its built bundle — the real Flutter page in the panel's
 * design step and in a bare harness. Needs the bundle (apps/mobile/tool/build_event_preview.sh OUT) and the panel's
 * build (`pnpm --filter @kabso/admin build`); `e2e-preview/serve.mjs` serves both like Caddy (same headers), the API
 * is answered in the browser (e2e-preview/mock-api.ts).
 *
 *   EVENT_PREVIEW_DIR=/dev/shm/event-preview pnpm --filter @kabso/admin exec playwright test -c playwright.preview.config.ts
 */
const port = Number(process.env.KABSO_PREVIEW_PORT ?? 5190);
export default defineConfig({
  testDir: 'e2e-preview',
  timeout: 120_000,
  workers: 1,
  use: { baseURL: `http://127.0.0.1:${String(port)}`, locale: 'ar' },
  webServer: {
    command: `node e2e-preview/serve.mjs`,
    url: `http://127.0.0.1:${String(port)}/__harness.html`,
    reuseExistingServer: !process.env.CI,
    env: { PORT: String(port), EVENT_PREVIEW_DIR: process.env.EVENT_PREVIEW_DIR ?? '', ADMIN_DIST: process.env.ADMIN_DIST ?? 'dist' },
  },
});
