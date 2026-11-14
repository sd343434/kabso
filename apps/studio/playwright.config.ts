import { defineConfig } from '@playwright/test';

/**
 * The studio end to end (D247): the real page against a local API (apps/api test/smoke/studio.smoke.ts) and, when
 * KABSO_E2E_LIVEKIT is set, a real LiveKit server — Chromium with fake media devices and an auto-picked screen.
 */
export default defineConfig({
  testDir: 'e2e',
  timeout: 240_000,
  workers: 1,
  use: {
    baseURL: process.env.KABSO_STUDIO_URL ?? 'http://localhost:5190',
    locale: 'ar',
    launchOptions: {
      args: [
        '--use-fake-device-for-media-stream',
        '--use-fake-ui-for-media-stream',
        '--auto-select-desktop-capture-source=Entire screen',
        '--auto-accept-this-tab-capture',
      ],
    },
    permissions: ['camera', 'microphone'],
  },
  webServer: process.env.KABSO_STUDIO_URL
    ? undefined
    : { command: 'pnpm exec vite preview', port: 5190, reuseExistingServer: true },
});
