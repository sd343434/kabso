import { describe, expect, it } from 'vitest';
import { isValidHashtag, normalizeHashtag, parseHashtags, parseMentions } from './text-entities.js';

describe('parseHashtags (CONVENTIONS §11.6)', () => {
  it('finds Arabic and Latin tags, lower-cased, distinct, in order', () => {
    expect(parseHashtags('#Kabso لايف #سفر_جميل و #kabso #2026')).toEqual(['kabso', 'سفر_جميل', '2026']);
  });
  it('ignores tags glued to a word, URL fragments and HTML entities', () => {
    expect(parseHashtags('a#b https://x.test/page#top &#123; ##double')).toEqual([]);
  });
  it('needs a letter or digit and caps at 30', () => {
    expect(parseHashtags('#___')).toEqual([]);
    expect(parseHashtags(Array.from({ length: 40 }, (_, i) => `#t${i}`).join(' '))).toHaveLength(30);
  });
  it('validates path tags', () => {
    expect(normalizeHashtag('#Kabso')).toBe('kabso');
    expect(isValidHashtag('سفر')).toBe(true);
    expect(isValidHashtag('a b')).toBe(false);
    expect(isValidHashtag('x'.repeat(101))).toBe(false);
  });
});

describe('parseMentions (CONVENTIONS §11.6)', () => {
  it('finds well-formed usernames, not e-mail addresses', () => {
    expect(parseMentions('hi @Layla.Test and @omar_1, mail me at a@b.com @ab @layla.test.')).toEqual([
      'layla.test',
      'omar_1',
    ]);
  });
  it('caps at 20', () => {
    expect(parseMentions(Array.from({ length: 25 }, (_, i) => `@user${i}x`).join(' '))).toHaveLength(20);
  });
});
