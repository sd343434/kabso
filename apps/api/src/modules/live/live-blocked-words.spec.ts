import { describe, expect, it } from 'vitest';
import { foldWord, maskBlockedWords, setLiveBlockedWordsSchema } from './live-blocked-words.js';

describe('CP-016 B: masking blocked words', () => {
  it('masks whole Latin words, any case, and leaves longer words alone', () => {
    expect(maskBlockedWords('You are DUMB, dumb!', ['dumb'])).toBe('You are ****, ****!');
    expect(maskBlockedWords('the class is fun', ['ass'])).toBe('the class is fun');
    expect(maskBlockedWords('ass.', ['ass'])).toBe('***.');
  });

  it('matches Arabic inside a word and across spelling variants', () => {
    // A prefix (و، ال) and a diacritic or tatweel do not hide the word.
    expect(maskBlockedWords('والغبي هنا', ['غبي'])).toBe('وال*** هنا');
    expect(maskBlockedWords('غَبِي', ['غبي'])).toBe('*****');
    expect(maskBlockedWords('غـبي', ['غبي'])).toBe('****');
    expect(foldWord('إسلام')).toBe(foldWord('اسلام'));
    expect(foldWord('مدرسة')).toBe(foldWord('مدرسه'));
  });

  it('phrases, several words, nothing to mask', () => {
    expect(maskBlockedWords('go away now', ['go away', 'now'])).toBe('******* ***');
    expect(maskBlockedWords('hello', [])).toBe('hello');
    expect(maskBlockedWords('hello 👋', ['bye'])).toBe('hello 👋');
  });
});

describe('CP-016 B: the blocked words list', () => {
  const parse = (words: unknown) => setLiveBlockedWordsSchema.safeParse({ words });

  it('normalizes, drops duplicates by matching form, keeps the first spelling', () => {
    const r = parse(['  Spam ', 'spam', 'SPAM', 'غبي', 'غَبي']);
    expect(r.success && r.data.words).toEqual(['Spam', 'غبي']);
  });

  it('refuses empty, too long, line breaks, over 100 words, unknown fields', () => {
    expect(parse(['']).success).toBe(false);
    expect(parse(['x'.repeat(31)]).success).toBe(false);
    expect(parse(['a\nb']).success).toBe(false);
    expect(parse(Array.from({ length: 101 }, (_, i) => `w${i}`)).success).toBe(false);
    expect(parse(Array.from({ length: 100 }, (_, i) => `w${i}`)).success).toBe(true);
    expect(setLiveBlockedWordsSchema.safeParse({ words: [], x: 1 }).success).toBe(false);
  });
});
