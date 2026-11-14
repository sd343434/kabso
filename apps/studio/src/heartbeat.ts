/**
 * D247: the host's heartbeat from a browser tab (CONVENTIONS §10.3). The studio sends `POST …/heartbeat` every
 * `heartbeatIntervalSeconds` while it is live, on a worker's clock (not throttled in a background tab), and falls back
 * to the page's own timer when workers are unavailable. A STREAMER host is never «away» (§10.86), so the studio sends
 * no host-presence: the heartbeat alone keeps the room; a closed tab stops it and the room ends after
 * `heartbeatStaleAfterSeconds` (45 s) — as when the app is killed.
 */
export interface Ticker {
  start(intervalMs: number, onTick: () => void): void;
  stop(): void;
}

export function createTicker(): Ticker {
  let worker: Worker | null = null;
  let fallback: ReturnType<typeof setInterval> | null = null;
  return {
    start(intervalMs, onTick) {
      this.stop();
      try {
        worker = new Worker(new URL('./heartbeat.worker.ts', import.meta.url), { type: 'module' });
        worker.onmessage = () => onTick();
        worker.onerror = () => {
          worker?.terminate();
          worker = null;
          fallback ??= setInterval(onTick, intervalMs);
        };
        worker.postMessage({ type: 'start', intervalMs });
      } catch {
        worker = null;
        fallback = setInterval(onTick, intervalMs);
      }
    },
    stop() {
      worker?.postMessage({ type: 'stop' });
      worker?.terminate();
      worker = null;
      if (fallback) clearInterval(fallback);
      fallback = null;
    },
  };
}
