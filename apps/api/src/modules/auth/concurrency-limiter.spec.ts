import { describe, expect, it } from 'vitest';
import { ConcurrencyLimiter } from './concurrency-limiter.js';

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((r) => (resolve = r));
  return { promise, resolve };
}

describe('ConcurrencyLimiter', () => {
  it('runs up to the cap, queues up to the queue size and sheds the rest', async () => {
    const limiter = new ConcurrencyLimiter(2, 1);
    const gates = [deferred(), deferred(), deferred()];
    const maybeRuns = gates.map((g) => limiter.run(() => g.promise.then(() => 'done')));
    const runs = maybeRuns.filter((r): r is Promise<string> => r !== null);
    expect(runs).toHaveLength(3);
    expect(limiter.active).toBe(2);
    expect(limiter.queued).toBe(1);
    expect(limiter.run(() => Promise.resolve('x'))).toBeNull();

    gates.forEach((g) => g.resolve());
    await expect(Promise.all(runs)).resolves.toEqual(['done', 'done', 'done']);
    expect(limiter.active).toBe(0);
    expect(limiter.queued).toBe(0);
  });

  it('never exceeds the cap when a newcomer arrives while a queued task is being handed a slot', async () => {
    const limiter = new ConcurrencyLimiter(1, 5);
    let concurrent = 0;
    let peak = 0;
    const task = async () => {
      concurrent += 1;
      peak = Math.max(peak, concurrent);
      await new Promise((r) => setTimeout(r, 5));
      concurrent -= 1;
    };
    const first = limiter.run(task);
    const queued = limiter.run(task);
    await first;
    const late = limiter.run(task); // must queue, not overtake
    await Promise.all([queued, late]);
    expect(peak).toBe(1);
  });

  it('releases the slot when a task fails', async () => {
    const limiter = new ConcurrencyLimiter(1, 0);
    await expect(limiter.run(() => Promise.reject(new Error('boom')))).rejects.toThrow('boom');
    expect(limiter.active).toBe(0);
    await expect(limiter.run(() => Promise.resolve(1))).resolves.toBe(1);
  });

  it('validates its bounds', () => {
    expect(() => new ConcurrencyLimiter(0, 0)).toThrow(RangeError);
    expect(() => new ConcurrencyLimiter(1, -1)).toThrow(RangeError);
  });
});
