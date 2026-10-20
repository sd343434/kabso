import { describe, expect, it } from 'vitest';
import { spreadAuthors } from './feed.service.js';

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
