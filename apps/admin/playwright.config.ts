import { defineConfig } from '@playwright/test';

/**
 * One smoke run of the real panel against a local API with a seeded OWNER (D191). Start the API (port 3000) and
 * `vite preview` (port 5180) first, or let `webServer` start the preview; the test seeds the admin through the
 * database (KABSO_E2E_MIGRATION_URL) and generates the authenticator codes itself.
 */
export default defineConfig({
  testDir: 'e2e',
  timeout: 180_000,
  workers: 1,
  use: { baseURL: process.env.KABSO_ADMIN_URL ?? 'http://localhost:5180', locale: 'ar' },
  webServer: process.env.KABSO_ADMIN_URL
    ? undefined
    : { command: 'pnpm exec vite preview', port: 5180, reuseExistingServer: true },
});
