import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { DATA_RETRY_DELAYS_MS, DataRetry, isRoomMissing, isUnavailable } from './data-retry.js';

/** LiveKit's errors as the server SDK throws them (TwirpError: status, code, message). */
const unavailable = Object.assign(new Error('no response from servers'), {
  status: 503,
  code: 'unavailable',
});
const missing = Object.assign(new Error('requested room does not exist'), { status: 404, code: 'not_found' });
const denied = Object.assign(new Error('permission denied'), { status: 403, code: 'permission_denied' });

describe('D319 data messages through a short LiveKit outage', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  const setup = (results: (Error | null)[]) => {
    const calls: number[] = [];
    const send = vi.fn(async () => {
      calls.push(Date.now());
      const next = results.shift();
      if (next) throw next;
    });
    const logger = { warn: vi.fn() };
    const retry = new DataRetry(send, { logger });
    return { send, retry, logger, calls };
  };

  it('classifies LiveKit errors', () => {
    expect(isUnavailable(unavailable)).toBe(true);
    expect(isUnavailable({ status: 503 })).toBe(true);
    expect(isRoomMissing(missing)).toBe(true);
    expect(isUnavailable(denied) || isRoomMissing(denied)).toBe(false);
    // The total wait is bounded (about 10–15 s).
    const total = DATA_RETRY_DELAYS_MS.reduce((a, b) => a + b, 0);
    expect(total).toBeGreaterThanOrEqual(10_000);
    expect(total).toBeLessThanOrEqual(15_000);
  });

  it('503 then 200: delivered on the retry; the caller is answered at once (not held for the retry)', async () => {
    const { send, retry, logger } = setup([unavailable, null]);
    const start = Date.now();
    await retry.deliver('room-1', 'gift', '{"type":"gift"}');
    // Answered without waiting for any timer.
    expect(Date.now() - start).toBe(0);
    expect(send).toHaveBeenCalledTimes(1);
    expect(retry.pending).toBe(1);
    await vi.advanceTimersByTimeAsync(DATA_RETRY_DELAYS_MS[0]!);
    expect(send).toHaveBeenCalledTimes(2);
    expect(send).toHaveBeenLastCalledWith('room-1', 'gift', '{"type":"gift"}');
    expect(retry.pending).toBe(0);
    expect(logger.warn).not.toHaveBeenCalled();
  });

  it('404 every time: retried with backoff, then given up with one warning (≈ 12 s in all)', async () => {
    const { send, retry, logger, calls } = setup(Array.from({ length: 10 }, () => missing));
    await retry.deliver('room-2', 'gift', 'x');
    await vi.advanceTimersByTimeAsync(60_000);
    expect(send).toHaveBeenCalledTimes(1 + DATA_RETRY_DELAYS_MS.length);
    const waits = calls.slice(1).map((t, i) => t - calls[i]!);
    expect(waits).toEqual([...DATA_RETRY_DELAYS_MS]);
    expect(logger.warn).toHaveBeenCalledTimes(1);
    expect(String(logger.warn.mock.calls[0]![0])).toMatch(/room-2.*dropped/);
    expect(retry.pending).toBe(0);
  });

  it('any other error: no retry, the caller gets it as before', async () => {
    const { send, retry } = setup([denied]);
    await expect(retry.deliver('room-3', 'gift', 'x')).rejects.toBe(denied);
    await vi.advanceTimersByTimeAsync(60_000);
    expect(send).toHaveBeenCalledTimes(1);
    expect(retry.pending).toBe(0);
  });

  it('a retry that meets another error stops there (logged), and stop() drops the waiting ones', async () => {
    const a = setup([unavailable, denied]);
    await a.retry.deliver('room-4', 'gift', 'x');
    await vi.advanceTimersByTimeAsync(60_000);
    expect(a.send).toHaveBeenCalledTimes(2);
    expect(a.logger.warn).toHaveBeenCalledTimes(1);
    const b = setup([unavailable, null]);
    await b.retry.deliver('room-5', 'gift', 'x');
    b.retry.stop();
    await vi.advanceTimersByTimeAsync(60_000);
    expect(b.send).toHaveBeenCalledTimes(1);
  });

  it('one room missing does not hold the others (the global strips fan out)', async () => {
    const send = vi.fn(async (room: string) => {
      if (room === 'gone') throw missing;
    });
    const retry = new DataRetry(send, { logger: { warn: vi.fn() } });
    const results = await Promise.allSettled(['a', 'gone', 'b'].map((r) => retry.deliver(r, 'gift', 'x')));
    expect(results.every((r) => r.status === 'fulfilled')).toBe(true);
    expect(send.mock.calls.map((c) => c[0])).toEqual(['a', 'gone', 'b']);
    expect(retry.pending).toBe(1);
    retry.stop();
  });
});
