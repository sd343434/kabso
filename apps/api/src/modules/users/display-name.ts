import { containsReservedTerm } from './confusables.js';

/**
 * `displayName` rules (contract v1.2 §6, KL-017 / QA-008).
 *
 * Value: NFC-normalized, trimmed. Limits: 1–50 grapheme clusters and ≤ 100 code points.
 * `invalid_format`:
 *  - C0/C1 controls and DEL, bidi override/isolate (U+202A–U+202E, U+2066–U+2069), U+200B,
 *    U+2060, U+FEFF;
 *  - ZWNJ (U+200C) / ZWJ (U+200D) not placed between two non-joiner, non-space characters;
 *  - more than 3 consecutive combining marks ("zalgo"), counted on the NFD form;
 *  - no letter, digit or emoji at all (only whitespace, joiners, marks, symbols/punctuation).
 * U+FEFF at either end is removed by trimming; inside the name it is rejected (v1.2.1).
 * `reserved_term`: whole-word reserved term or brand prefix/suffix on the confusable skeleton.
 */
export const DISPLAY_NAME_MAX_GRAPHEMES = 50;
export const DISPLAY_NAME_MAX_CODE_POINTS = 100;
export const MAX_CONSECUTIVE_COMBINING_MARKS = 3;

export type DisplayNameIssue = 'too_short' | 'too_long' | 'invalid_format' | 'reserved_term';

// eslint-disable-next-line no-control-regex -- intentionally matching control characters
const BANNED = /[\u0000-\u001f\u007f-\u009f\u200b\u2060\u202a-\u202e\u2066-\u2069\ufeff]/u;
const JOINER = /[\u200c\u200d]/u;
const SPACE = /[\s\p{Z}]/u;
const MARK = /\p{M}/u;
const LETTER_OR_DIGIT = /[\p{L}\p{N}]/u;
/**
 * Emoji grapheme (contract v1.2.1: "letter, digit or emoji"). `RGI_Emoji` (the Unicode
 * recommended emoji set, incl. ZWJ, flag, keycap and skin-tone sequences) is used rather than raw
 * `Extended_Pictographic`, which also contains text-presentation symbols such as ★ © ™ that the
 * contract wants rejected as symbol-only names. Built at runtime: the `v` flag needs ES2024.
 */
const EMOJI = new RegExp('\\p{RGI_Emoji}', 'v');

const segmenter = new Intl.Segmenter('und', { granularity: 'grapheme' });

export function normalizeDisplayName(raw: string): string {
  return raw.normalize('NFC').trim();
}

export function graphemeCount(value: string): number {
  let count = 0;
  for (const _ of segmenter.segment(value)) count += 1;
  return count;
}

function joinersWellPlaced(chars: readonly string[]): boolean {
  for (let i = 0; i < chars.length; i += 1) {
    if (!JOINER.test(chars[i]!)) continue;
    const before = chars[i - 1];
    const after = chars[i + 1];
    if (before === undefined || after === undefined) return false;
    if (JOINER.test(before) || JOINER.test(after) || SPACE.test(before) || SPACE.test(after)) return false;
  }
  return true;
}

function longestMarkRun(chars: readonly string[]): number {
  let longest = 0;
  let run = 0;
  for (const ch of chars) {
    run = MARK.test(ch) ? run + 1 : 0;
    longest = Math.max(longest, run);
  }
  return longest;
}

/** Returns the first rule violated by an already-normalized display name, or null. */
export function displayNameIssue(
  value: string,
  reservedTerms: readonly string[],
  brandTerms: readonly string[] = [],
): DisplayNameIssue | null {
  if (value.length === 0) return 'too_short';
  if (BANNED.test(value)) return 'invalid_format';
  const chars = [...value];
  if (chars.length > DISPLAY_NAME_MAX_CODE_POINTS || graphemeCount(value) > DISPLAY_NAME_MAX_GRAPHEMES) {
    return 'too_long';
  }
  if (!joinersWellPlaced(chars)) return 'invalid_format';
  // Counted on the decomposed form so precomposition (NFC) cannot hide a stacked mark.
  if (longestMarkRun([...value.normalize('NFD')]) > MAX_CONSECUTIVE_COMBINING_MARKS) return 'invalid_format';
  if (!LETTER_OR_DIGIT.test(value) && !EMOJI.test(value)) return 'invalid_format';
  if (containsReservedTerm(value, reservedTerms, brandTerms)) return 'reserved_term';
  return null;
}
