/**
 * D247: the heartbeat's clock. A dedicated worker's timers keep their pace when the studio's tab is in the background
 * (the page's own timers are throttled there), so the host's heartbeat (CONVENTIONS §10.3: every 15 s, 45 s without
 * one ends the live) keeps going while the host plays in another window. The page does the request on each tick.
 */
let timer: ReturnType<typeof setInterval> | null = null;

self.onmessage = (ev: MessageEvent<{ type: 'start'; intervalMs: number } | { type: 'stop' }>) => {
  if (timer) clearInterval(timer);
  timer = null;
  if (ev.data.type === 'start') timer = setInterval(() => self.postMessage('tick'), ev.data.intervalMs);
};
