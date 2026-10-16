import { describe, expect, it } from 'vitest';
import { languageFromAcceptLanguage } from './content-language.js';

describe('languageFromAcceptLanguage (CONVENTIONS §10.1)', () => {
  it.each([
    ['ar', 'ar'],
    ['en', 'en'],
    ['EN', 'en'],
    ['en-US', 'en'],
    ['ar-SA,en;q=0.8', 'ar'],
    ['en;q=0.9', 'en'],
    [' ar ', 'ar'],
  ])('%j → %s', (header, expected) => {
    expect(languageFromAcceptLanguage(header)).toBe(expected);
  });

  it.each([undefined, '', '*', 'fr', 'fr, en', 'arabic', 'english-US', 'de-DE,ar;q=0.9'])(
    '%j → null (falls back to the stored locale)',
    (header) => {
      expect(languageFromAcceptLanguage(header)).toBeNull();
    },
  );

  it('uses the first value of a repeated header', () => {
    expect(languageFromAcceptLanguage(['en', 'ar'])).toBe('en');
  });
});
