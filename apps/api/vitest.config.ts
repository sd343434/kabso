import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';

// SWC (instead of esbuild) so Nest's decorator metadata is emitted in tests.
export default defineConfig({
  plugins: [swc.vite({ module: { type: 'es6' } })],
  test: {
    include: ['src/**/*.spec.ts'],
    environment: 'node',
    pool: 'forks',
  },
});
