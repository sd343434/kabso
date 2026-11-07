import { describe, expect, it } from 'vitest';
import { interleaveMixed, MIXED_PATTERN, spreadAuthors } from './feed.service.js';
import { feedQuerySchema, reelsFeedQuerySchema } from './posts.schemas.js';

const ranked = (authors: string) => [...authors].map((authorId, i) => ({ id: `${i}`, authorId }));

/** At most 2 posts by one author in any 10 consecutive entries (CONVENTIONS §11.3). */
function respectsSpread(list: readonly { authorId: string }[]): boolean {
  for (let start = 0; start < list.length; start += 1) {
    const counts = new Map<string, number>();
    for (const e of list.slice(start, start + 10)) counts.set(e.authorId, (counts.get(e.authorId) ?? 0) + 1);
    if ([...counts.values()].some((c) => c > 2)) return false;
  }
  return true;
}

describe('spreadAuthors', () => {
  it('keeps the ranked order when the rule already holds', () => {
    const input = ranked('abcdefghij');
    expect(spreadAuthors(input, 10)).toEqual(input);
  });

  it('defers a third post by one author until 10 entries have passed', () => {
    const out = spreadAuthors(ranked('aaabcdefghijk'), 13);
    expect(out.map((e) => e.authorId).join('')).toBe('aabcdefghiajk');
    expect(respectsSpread(out)).toBe(true);
  });

  it('drops what cannot fit and honours the limit', () => {
    expect(spreadAuthors(ranked('aaaa'), 10).map((e) => e.id)).toEqual(['0', '1']);
    const many = ranked('abcabcabcabcabcabcabc');
    const out = spreadAuthors(many, 5);
    expect(out).toHaveLength(5);
    expect(respectsSpread(spreadAuthors(many, 100))).toBe(true);
  });
});

const ids = (prefix: string, n: number) => Array.from({ length: n }, (_, i) => ({ id: `${prefix}${i}` }));
const order = (list: readonly { id: string }[]) => list.map((e) => e.id).join(' ');

/** v1.76-social (D218, CONVENTIONS §10.73): the home feed's 1 Following : 2 Trending. */
describe('interleaveMixed', () => {
  it('is 1 : 2, Following first', () => {
    expect(MIXED_PATTERN).toEqual({ following: 1, trending: 2 });
    expect(order(interleaveMixed(ids('f', 3), ids('t', 6), 100))).toBe('f0 t0 t1 f1 t2 t3 f2 t4 t5');
  });

  it('continues with the other source when one runs out', () => {
    expect(order(interleaveMixed(ids('f', 1), ids('t', 4), 100))).toBe('f0 t0 t1 t2 t3');
    expect(order(interleaveMixed(ids('f', 4), ids('t', 2), 100))).toBe('f0 t0 t1 f1 f2 f3');
    expect(order(interleaveMixed([], ids('t', 3), 100))).toBe('t0 t1 t2');
    expect(order(interleaveMixed(ids('f', 2), [], 100))).toBe('f0 f1');
    expect(interleaveMixed([], [], 100)).toEqual([]);
  });

  it('lists a post once (its Following entry wins) and keeps each source in order', () => {
    const following = [{ id: 'a' }, { id: 'b' }];
    const trending = [{ id: 'b' }, { id: 'x' }, { id: 'a' }, { id: 'y' }, { id: 'z' }];
    const out = interleaveMixed(following, trending, 100);
    expect(order(out)).toBe('a x y b z');
    expect(new Set(out.map((e) => e.id)).size).toBe(out.length);
  });

  it('keeps the entry it took (with its reposter) and honours the limit', () => {
    const out = interleaveMixed(
      [{ id: 'p', by: 'r' }],
      [
        { id: 'p', by: null },
        { id: 'q', by: null },
      ],
      2,
    );
    expect(out).toEqual([
      { id: 'p', by: 'r' },
      { id: 'q', by: null },
    ]);
  });
});

/** v1.92-social (D294, CONVENTIONS §10.107): the reels page's `tab=mixed`. */
describe('reelsFeedQuerySchema', () => {
  it('takes mixed next to following, trending and nearby; anything else is refused', () => {
    for (const tab of ['following', 'trending', 'nearby', 'mixed'])
      expect(reelsFeedQuerySchema.safeParse({ tab }).success).toBe(true);
    expect(reelsFeedQuerySchema.safeParse({ tab: 'foryou' }).success).toBe(false);
    expect(feedQuerySchema.safeParse({ tab: 'nearby' }).success).toBe(false);
  });
});
