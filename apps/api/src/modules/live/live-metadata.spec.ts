import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { roomMetadataJson, SCORE_METADATA_INTERVAL_MS, TrailingThrottle } from './live-metadata.service.js';

describe('CP-012 room metadata (CONVENTIONS §10.9, §10.10)', () => {
  it('carries the seat version and the score together', () => {
    expect(roomMetadataJson(3, 1234)).toBe('{"seatsVersion":3,"score":1234}');
    expect(JSON.parse(roomMetadataJson(0, 0))).toEqual({ seatsVersion: 0, score: 0 });
  });
});

describe('TrailingThrottle (score into the media room, at most once every 2 s per room)', () => {
  let now = 0;
  let runs: { key: string; at: number }[];
  let throttle: TrailingThrottle;

  beforeEach(() => {
    vi.useFakeTimers();
    now = 1_000_000;
    runs = [];
    throttle = new TrailingThrottle(
      SCORE_METADATA_INTERVAL_MS,
      () => now,
      (key) => {
        runs.push({ key, at: now });
        return Promise.resolve();
      },
    );
  });
  afterEach(async () => {
    await throttle.stop();
    vi.useRealTimers();
  });

  /** Moves both the throttle's clock and the timers. */
  const advance = async (ms: number) => {
    now += ms;
    await vi.advanceTimersByTimeAsync(ms);
  };

  it('writes the first change at once and the rest at most every 2 s, with a trailing write', async () => {
    await throttle.touch('a');
    expect(runs).toEqual([{ key: 'a', at: 1_000_000 }]);
    await advance(500);
    await throttle.touch('a');
    await advance(500);
    await throttle.touch('a'); // joins the pending trailing write
    expect(runs).toHaveLength(1);
    expect(throttle.pending()).toEqual(['a']);
    await advance(999);
    expect(runs).toHaveLength(1);
    await advance(1);
    expect(runs).toEqual([
      { key: 'a', at: 1_000_000 },
      { key: 'a', at: 1_002_000 },
    ]);
    expect(throttle.pending()).toEqual([]);
    // 2 s after the trailing write: immediate again.
    await advance(2_000);
    await throttle.touch('a');
    expect(runs.at(-1)).toEqual({ key: 'a', at: 1_004_000 });
  });

  it('keeps rooms independent', async () => {
    await throttle.touch('a');
    await throttle.touch('b');
    await throttle.touch('a');
    expect(runs.map((r) => r.key)).toEqual(['a', 'b']);
    expect(throttle.pending()).toEqual(['a']);
  });

  it('writes at once (cancelling the trailing write) when the clock already passed the interval', async () => {
    await throttle.touch('a');
    await throttle.touch('a');
    expect(throttle.pending()).toEqual(['a']);
    now += SCORE_METADATA_INTERVAL_MS; // the clock moved without the timer firing
    await throttle.touch('a');
    expect(runs).toHaveLength(2);
    expect(throttle.pending()).toEqual([]);
    await vi.advanceTimersByTimeAsync(SCORE_METADATA_INTERVAL_MS);
    expect(runs).toHaveLength(2);
  });

  it('stop() cancels pending trailing writes', async () => {
    await throttle.touch('a');
    await throttle.touch('a');
    await throttle.stop();
    await advance(SCORE_METADATA_INTERVAL_MS);
    expect(runs).toHaveLength(1);
    await throttle.touch('a');
    expect(runs).toHaveLength(1);
  });
});
