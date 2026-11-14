import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';

/**
 * D191: a local API for the admin panel's Playwright smoke (apps/admin/e2e). Not part of `test:e2e`: it boots the
 * real app against the *_test database (reset), seeds an OWNER and data, listens on SMOKE_PORT and runs until
 * SMOKE_STOP_FILE disappears. `pnpm smoke:admin-server`.
 */
export default defineConfig({
  plugins: [swc.vite({ module: { type: 'es6' } })],
  test: {
    include: ['test/smoke/**/*.smoke.ts'],
    environment: 'node',
    pool: 'forks',
    globalSetup: ['test/global-setup.ts'],
    testTimeout: 3_600_000,
    hookTimeout: 120_000,
  },
});
