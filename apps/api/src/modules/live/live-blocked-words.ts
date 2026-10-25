import { z } from 'zod';
import { normalizeContentText } from '../posts/content-text.js';

/** A host keeps at most 100 blocked words (CP-016 B, CONVENTIONS §10.14). */
export const LIVE_BLOCKED_WORDS_MAX = 100;
/** A blocked word or phrase: 1–30 code points after normalization. */
export const LIVE_BLOCKED_WORD_MAX_CODE_POINTS = 30;
/** What a blocked word becomes in a message. */
const MASK = '*';

/**
 * The matching form of one code point: NFKC, lower case, Arabic diacritics (harakat, superscript
 * alef) and tatweel dropped, alef forms (أ إ آ ٱ) → ا, ى → ي, ة → ه. Empty when it is ignored.
 */
function foldCodePoint(cp: string): string {
  if (/[ً-ٰٟـ]/u.test(cp)) return '';
  return cp
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[أإآٱ]/gu, 'ا')
    .replace(/ى/gu, 'ي')
    .replace(/ة/gu, 'ه');
}

/** The matching form of a whole word (see {@link foldCodePoint}). */
export function foldWord(word: string): string {
  let out = '';
  for (const cp of word) out += foldCodePoint(cp);
  return out;
}

const isWordChar = (ch: string | undefined): boolean => ch !== undefined && /[\p{L}\p{N}]/u.test(ch);
const hasArabic = (s: string): boolean => /\p{Script=Arabic}/u.test(s);

/**
 * Masks every occurrence of [words] in [text] (case and Arabic spelling variants folded): each
 * code point of a match becomes `*`. A word with Arabic letters matches inside a longer word
 * (Arabic attaches prefixes such as ال, و, ب); any other word matches only between non-letters,
 * so "ass" never masks "class". Returns the text unchanged when nothing matches.
 */
export function maskBlockedWords(text: string, words: readonly string[]): string {
  if (words.length === 0 || text.length === 0) return text;
  const cps = [...text];
  // The folded text, one entry per folded character, each pointing at its source code point.
  const folded: string[] = [];
  const origin: number[] = [];
  cps.forEach((cp, i) => {
    for (const ch of foldCodePoint(cp)) {
      folded.push(ch);
      origin.push(i);
    }
  });
  const hay = folded.join('');
  const masked = new Array<boolean>(cps.length).fill(false);
  for (const word of words) {
    const needle = [...foldWord(word)];
    if (needle.length === 0) continue;
    const anywhere = hasArabic(word);
    const n = needle.join('');
    let from = 0;
    for (;;) {
      // `hay` is indexed by UTF-16 units; the folded characters are mapped back below.
      const at = hay.indexOf(n, from);
      if (at < 0) break;
      from = at + 1;
      const start = [...hay.slice(0, at)].length;
      const end = start + needle.length; // exclusive, in folded characters
      if (!anywhere && (isWordChar(folded[start - 1]) || isWordChar(folded[end]))) continue;
      // Every source code point from the first to the last matched one (dropped diacritics too).
      for (let i = origin[start]!; i <= origin[end - 1]!; i++) masked[i] = true;
    }
  }
  if (!masked.includes(true)) return text;
  return cps.map((cp, i) => (masked[i] ? MASK : cp)).join('');
}

/** One blocked word, normalized like chat text (NFC, trimmed, one line, §6 hygiene). */
const blockedWordSchema = z
  .string()
  .max(LIVE_BLOCKED_WORD_MAX_CODE_POINTS * 8)
  .transform((raw, ctx) => {
    const result = normalizeContentText(raw, {
      maxCodePoints: LIVE_BLOCKED_WORD_MAX_CODE_POINTS,
      maxLineBreaks: 0,
      allowEmpty: false,
    });
    if ('issue' in result) {
      const issue = result.issue === 'too_short' ? 'required' : result.issue;
      ctx.addIssue({ code: 'custom', message: issue, params: { issue } });
      return z.NEVER;
    }
    return result.value;
  });

/**
 * `SetLiveBlockedWordsRequest`: the whole list (it replaces the old one). Duplicates by matching
 * form are dropped (the first spelling is kept); more than 100 distinct words → `too_long`.
 */
export const setLiveBlockedWordsSchema = z
  .strictObject({ words: z.array(blockedWordSchema).max(LIVE_BLOCKED_WORDS_MAX * 2) })
  .transform((body, ctx) => {
    const seen = new Set<string>();
    const words: string[] = [];
    for (const w of body.words) {
      const key = foldWord(w);
      if (key.length === 0 || seen.has(key)) continue;
      seen.add(key);
      words.push(w);
    }
    if (words.length > LIVE_BLOCKED_WORDS_MAX) {
      ctx.addIssue({ code: 'custom', path: ['words'], message: 'too_long', params: { issue: 'too_long' } });
      return z.NEVER;
    }
    return { words };
  });
