import { describe, expect, it, vi } from 'vitest';
import {
  FOUNDER_FEEDBACK_COUNT_CACHE_KEY,
  FOUNDER_FEEDBACK_COUNT_CACHE_SECONDS,
  founderFeedbackCountOf,
  parseFeedbackCount,
  type FeedbackCountCache,
} from './owner-core.js';

/** v1.118-social (D357, CONVENTIONS §10.153): the founder's public «الاقتراحات والشكاوى» count. */
describe('D357 founderFeedbackCount', () => {
  const dbWith = (n: number) => {
    const count = vi.fn(async () => n);
    return { db: { ownerFeedback: { count } } as never, count };
  };
  const cacheWith = (stored: string | null, opts: { failGet?: boolean; failSet?: boolean } = {}) => {
    const get = vi.fn(async () => {
      if (opts.failGet) throw new Error('redis down');
      return stored;
    });
    const set = vi.fn(async () => {
      if (opts.failSet) throw new Error('redis down');
      return 'OK' as const;
    });
    return { cache: { get, set } as unknown as FeedbackCountCache, get, set };
  };

  it('parses only a stored whole number', () => {
    expect(parseFeedbackCount('0')).toBe(0);
    expect(parseFeedbackCount('128')).toBe(128);
    for (const bad of [null, '', '-1', '1.5', 'abc', '1e3', '9'.repeat(13)]) {
      expect(parseFeedbackCount(bad)).toBeNull();
    }
  });

  it('counts every kept submission and caches it for 60 s', async () => {
    const { db, count } = dbWith(42);
    const { cache, set } = cacheWith(null);
    expect(await founderFeedbackCountOf(db, cache)).toBe(42);
    expect(count).toHaveBeenCalledWith();
    expect(set).toHaveBeenCalledWith(
      FOUNDER_FEEDBACK_COUNT_CACHE_KEY,
      '42',
      'EX',
      FOUNDER_FEEDBACK_COUNT_CACHE_SECONDS,
    );
    expect(FOUNDER_FEEDBACK_COUNT_CACHE_SECONDS).toBe(60);
  });

  it('answers from the cache without counting', async () => {
    const { db, count } = dbWith(42);
    const { cache } = cacheWith('7');
    expect(await founderFeedbackCountOf(db, cache)).toBe(7);
    expect(count).not.toHaveBeenCalled();
  });

  it('a failing or corrupt cache only means a fresh count', async () => {
    for (const c of [cacheWith(null, { failGet: true, failSet: true }), cacheWith('garbage')]) {
      const { db, count } = dbWith(3);
      expect(await founderFeedbackCountOf(db, c.cache)).toBe(3);
      expect(count).toHaveBeenCalledTimes(1);
    }
    const { db } = dbWith(5);
    expect(await founderFeedbackCountOf(db)).toBe(5);
    expect(await founderFeedbackCountOf(db, null)).toBe(5);
  });
});
