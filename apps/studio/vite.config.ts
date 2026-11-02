import { defineConfig } from 'vitest/config';

/**
 * «استوديو البث» (D247). `vite` serves it locally with /api proxied to the local API (same origin, as Caddy does at
 * studio.<domain>); `vite build` writes the static files to dist/ (livekit-client is bundled: no runtime third-party
 * script). JSX is compiled by Vite's own transform (no plugin). Vitest runs the unit tests in Node.
 */
const api = process.env.KABSO_API_URL ?? 'http://127.0.0.1:3000';
export default defineConfig({
  oxc: { jsx: { runtime: 'automatic' } },
  server: { port: 5190, strictPort: true, proxy: { '/api': { target: api, changeOrigin: false } } },
  preview: { port: 5190, strictPort: true, proxy: { '/api': { target: api, changeOrigin: false } } },
  build: { outDir: 'dist', sourcemap: false, assetsInlineLimit: 0, target: 'es2022', chunkSizeWarningLimit: 900 },
  worker: { format: 'es' },
  test: { include: ['test/**/*.test.{ts,tsx}'], environment: 'node' },
});
