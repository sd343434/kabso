import { describe, expect, it } from 'vitest';
import { normalizeContentText } from './content-text.js';

const POST = { maxCodePoints: 2200, maxLineBreaks: 30, allowEmpty: true };
const COMMENT = { maxCodePoints: 500, maxLineBreaks: 5, allowEmpty: false };

describe('normalizeContentText (CONVENTIONS §11.2, §11.5)', () => {
  it('normalizes line endings, NFC and outer spaces, keeping inner paragraphs', () => {
    expect(normalizeContentText('  \r\nمرحبا  \r\n\r\nworld  \n\n', POST)).toEqual({
      value: 'مرحبا\n\nworld',
    });
    expect(normalizeContentText('Café', POST)).toEqual({ value: 'Café' });
  });

  it('allows emoji, Arabic diacritics and joiners between letters', () => {
    expect('value' in normalizeContentText('👨‍👩‍👧 كتاب مُشَدَّد', POST)).toBe(true);
    expect('value' in normalizeContentText('می‌خواهم', POST)).toBe(true);
  });

  it('refuses control, bidi-override, zero-width and misplaced joiner characters', () => {
    for (const bad of ['a\u0000b', 'a‮b', 'a​b', '‌start', 'tab\there']) {
      expect(normalizeContentText(bad, POST), JSON.stringify(bad)).toEqual({ issue: 'invalid_format' });
    }
  });

  it('caps code points, line breaks and stacked marks', () => {
    expect(normalizeContentText('x'.repeat(2201), POST)).toEqual({ issue: 'too_long' });
    expect('value' in normalizeContentText('x'.repeat(2200), POST)).toBe(true);
    expect(normalizeContentText('a\nb\nc\nd\ne\nf\ng', COMMENT)).toEqual({ issue: 'too_long' });
    expect(normalizeContentText('é̂̃̄', POST)).toEqual({ issue: 'invalid_format' });
  });

  it('empty is allowed only where the limits say so', () => {
    expect(normalizeContentText('   ', POST)).toEqual({ value: '' });
    expect(normalizeContentText(' \n ', COMMENT)).toEqual({ issue: 'too_short' });
  });
});
