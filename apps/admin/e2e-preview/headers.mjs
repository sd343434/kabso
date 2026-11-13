/**
 * D356: the Content-Security-Policy of the admin panel and of its event page preview, as infra/deploy/Caddyfile sends
 * them (without the deployment's variables). `test/event-preview-d356.test.ts` checks the Caddyfile still says this.
 */
export const ADMIN_CSP =
  "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: https:; font-src 'self'; media-src 'self' blob:; connect-src 'self'; frame-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'";

/**
 * The preview: CanvasKit is WebAssembly ('wasm-unsafe-eval'); the Flutter engine injects its own <style> elements
 * (style-src 'unsafe-inline' — styles only, scripts stay 'self'); the event's art is on the media host (img-src /
 * connect-src https:, never with credentials — the page holds none); only the panel's own pages may frame it.
 */
export const PREVIEW_CSP =
  "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self'; connect-src 'self' https:; worker-src 'self' blob:; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'self'";
