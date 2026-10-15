import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';

/**
 * End-to-end tests against real PostgreSQL and Redis.
 * Requires DATABASE_URL (database name must end in `_test`; it is migrated and truncated) and
 * REDIS_URL. See apps/api/README.md.
 */
export default defineConfig({
  plugins: [swc.vite({ module: { type: 'es6' } })],
  test: {
    include: ['test/**/*.e2e-spec.ts'],
    environment: 'node',
    pool: 'forks',
    globalSetup: ['test/global-setup.ts'],
    // One shared database: run files sequentially.
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
  },
});
