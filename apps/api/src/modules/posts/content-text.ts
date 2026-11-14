import { scanHygiene, trimHygiene } from '../users/text-hygiene.js';

export type ContentTextIssue = 'too_short' | 'too_long' | 'invalid_format';

export interface ContentTextLimits {
  readonly maxCodePoints: number;
  readonly maxLineBreaks: number;
  /** Whether an empty value is allowed (a post with images needs no caption). */
  readonly allowEmpty: boolean;
}

/** Longest allowed run of combining marks (CONVENTIONS §6 zalgo cap, counted on NFD). */
const MAX_MARK_RUN = 3;

/**
 * Normalizes free content text (captions, comments, locations; CONVENTIONS §11.2/§11.5): CRLF and
 * CR become LF, NFC, the whole value is trimmed of spaces and U+FEFF, each line loses trailing
 * spaces. Returns the value or the first rule it breaks. Each line follows the §6 hygiene rules
 * (no control, bidi-override, zero-width or other rejected code points; ZWNJ/ZWJ only between
 * joining characters); line feeds are allowed up to `maxLineBreaks`.
 */
export function normalizeContentText(
  raw: string,
  limits: ContentTextLimits,
): { readonly value: string } | { readonly issue: ContentTextIssue } {
  const unified = raw.replace(/\r\n?/g, '\n').normalize('NFC');
  const lines = trimHygiene(unified)
    .split('\n')
    .map((line) => line.replace(/[\p{Zs}\uFEFF]+$/u, ''));
  // Leading and trailing blank lines go; inner blank lines stay (paragraphs).
  while (lines.length > 0 && lines[0] === '') lines.shift();
  while (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();
  const value = lines.join('\n');
  if (value.length === 0) return limits.allowEmpty ? { value } : { issue: 'too_short' };
  if ([...value].length > limits.maxCodePoints) return { issue: 'too_long' };
  if (lines.length - 1 > limits.maxLineBreaks) return { issue: 'too_long' };
  for (const line of lines) {
    if (line.length === 0) continue;
    const scan = scanHygiene(line);
    if (scan.rejected || scan.misplacedJoiner) return { issue: 'invalid_format' };
  }
  let run = 0;
  for (const ch of value.normalize('NFD')) {
    run = /\p{M}/u.test(ch) ? run + 1 : 0;
    if (run > MAX_MARK_RUN) return { issue: 'invalid_format' };
  }
  return { value };
}
