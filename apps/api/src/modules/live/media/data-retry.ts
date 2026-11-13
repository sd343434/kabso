import { Logger } from '@nestjs/common';

/**
 * D319 (staging, a 500 000-coin gift whose strip never showed): LiveKit closed the room for a few seconds («closing
 * idle room … departure timeout», the host's connection had dropped) while the database still had it LIVE; the
 * gift's and the gift-ticker's `SendData` got **503** «no response from servers» and the metadata **404** «requested
 * room does not exist»; a few minutes later the room existed again and sends answered 200.
 *
 * Every server → room data message (gifts, the global strips, lucky wins, the level ticker, chat, bullets, boosts,
 * kicks …) goes through `LiveKitMediaProvider.broadcastData`, which uses this: the **first** attempt is awaited as
 * before (a success or a non-retryable error answers the caller as today); a **503 unavailable** or a **404 not
 * found** is retried **in the background** — the caller is answered at once, so no HTTP response or send waits —
 * after {@link DATA_RETRY_DELAYS_MS} (≈ 12 s in all), then given up with a warning. Other errors are never retried.
 */
export const DATA_RETRY_DELAYS_MS: readonly number[] = [500, 1_000, 2_000, 3_000, 5_000];

type Send = (room: string, topic: string, payload: string) => Promise<void>;

export interface DataRetryOptions {
  /** The waits before each retry (the total bounds how long a message may be late). */
  readonly delaysMs?: readonly number[];
  /** Timers (tests pass fake ones). */
  readonly setTimer?: (fn: () => void, ms: number) => unknown;
  readonly clearTimer?: (handle: unknown) => void;
  readonly logger?: Pick<Logger, 'warn'>;
}

/** LiveKit's 503 «unavailable» (psrpc timeout: the room's node did not answer) — worth another try. */
export function isUnavailable(err: unknown): boolean {
  const e = err as { status?: unknown; code?: unknown; message?: unknown } | null;
  const message = typeof e?.message === 'string' ? e.message : '';
  return e?.status === 503 || e?.code === 'unavailable' || /no response from servers/i.test(message);
}

/** LiveKit's 404 «not found» (the room is not open right now) — worth another try for a data message. */
export function isRoomMissing(err: unknown): boolean {
  const e = err as { status?: unknown; code?: unknown; message?: unknown } | null;
  const message = typeof e?.message === 'string' ? e.message : '';
  return e?.status === 404 || e?.code === 'not_found' || /not.?found|does not exist/i.test(message);
}

export class DataRetry {
  private readonly delays: readonly number[];
  private readonly setTimer: (fn: () => void, ms: number) => unknown;
  private readonly clearTimer: (handle: unknown) => void;
  private readonly logger: Pick<Logger, 'warn'>;
  private readonly timers = new Set<unknown>();
  private stopped = false;

  constructor(
    private readonly send: Send,
    options: DataRetryOptions = {},
  ) {
    this.delays = options.delaysMs ?? DATA_RETRY_DELAYS_MS;
    this.setTimer = options.setTimer ?? ((fn, ms) => setTimeout(fn, ms).unref());
    this.clearTimer = options.clearTimer ?? ((h) => clearTimeout(h as NodeJS.Timeout));
    this.logger = options.logger ?? new Logger('LiveMediaData');
  }

  /** Retries waiting now (tests, metrics). */
  get pending(): number {
    return this.timers.size;
  }

  /**
   * Sends once; a 503 / 404 schedules the retries and resolves (the caller is not held); any other error rejects as
   * before.
   */
  async deliver(room: string, topic: string, payload: string): Promise<void> {
    try {
      await this.send(room, topic, payload);
    } catch (err) {
      if (!retryable(err) || this.delays.length === 0 || this.stopped) throw err;
      this.retry(room, topic, payload, 0);
    }
  }

  /** Drops every waiting retry (shutdown). */
  stop(): void {
    this.stopped = true;
    for (const t of this.timers) this.clearTimer(t);
    this.timers.clear();
  }

  private retry(room: string, topic: string, payload: string, attempt: number): void {
    const handle = this.setTimer(() => {
      this.timers.delete(handle);
      if (this.stopped) return;
      this.send(room, topic, payload).then(
        () => undefined,
        (err: unknown) => {
          if (retryable(err) && attempt + 1 < this.delays.length && !this.stopped) {
            this.retry(room, topic, payload, attempt + 1);
            return;
          }
          this.logger.warn(
            `data message (topic ${topic}) to room ${room} dropped after ${attempt + 1} retr${attempt === 0 ? 'y' : 'ies'}: ${
              err instanceof Error ? err.message : String(err)
            }`,
          );
        },
      );
    }, this.delays[attempt]!);
    this.timers.add(handle);
  }
}

function retryable(err: unknown): boolean {
  return isUnavailable(err) || isRoomMissing(err);
}
