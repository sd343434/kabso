import { defineConfig } from 'vitest/config';

/**
 * The admin panel (D191). `vite` serves it locally with /api proxied to the local API (same origin, as Caddy does
 * at admin.<domain>); `vite build` writes the static files to dist/. JSX is compiled by Vite's own transform (no
 * plugin). Vitest runs the unit tests in Node (no DOM library).
 */
export default defineConfig({
  oxc: { jsx: { runtime: 'automatic' } },
  server: {
    port: 5180,
    strictPort: true,
    proxy: { '/api': { target: process.env.KABSO_API_URL ?? 'http://127.0.0.1:3000', changeOrigin: false } },
  },
  preview: {
    port: 5180,
    strictPort: true,
    proxy: { '/api': { target: process.env.KABSO_API_URL ?? 'http://127.0.0.1:3000', changeOrigin: false } },
  },
  build: { outDir: 'dist', sourcemap: false, assetsInlineLimit: 0, target: 'es2022' },
  test: { include: ['test/**/*.test.{ts,tsx}'], environment: 'node' },
});
