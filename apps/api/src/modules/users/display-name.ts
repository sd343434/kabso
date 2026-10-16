import { containsReservedTerm } from './confusables.js';
import { hasMixedScriptWord } from './script-mixing.js';
import { isMark, scanHygiene, trimHygiene } from './text-hygiene.js';

/**
 * `displayName` rules (contract v1.2 §6, KL-017 / QA-008; text hygiene v1.3.1, SEC-036).
 *
 * Value: NFC-normalized, trimmed (space separators and U+FEFF at either end). Limits: 1–50
 * grapheme clusters and ≤ 100 code points.
 * `invalid_format`:
 *  - a code point rejected by the text-hygiene rules (CONVENTIONS §6 v1.3.1; `text-hygiene.ts`):
 *    General_Category Cc/Cf/Zl/Zp/Co/Cs/Cn, Default_Ignorable_Code_Point, the blank look-alikes,
 *    except inside an RGI emoji, a well-placed ZWNJ/ZWJ, or a listed variation sequence (v1.4,
 *    SEC-039: StandardizedVariants, emoji-variation-sequences, IVD); inner spaces other than
 *    U+0020, U+00A0, U+202F and U+3000 and the filler U+16FE4 are rejected too.
 *    This covers every character banned before v1.3.1 (controls, bidi controls, LRM/RLM/ALM,
 *    U+200B, U+2060, an inner U+FEFF);
 *  - ZWNJ (U+200C) / ZWJ (U+200D) not placed between two non-joiner, non-space characters;
 *  - more than 3 consecutive combining marks ("zalgo"), counted on the NFD form;
 *  - no letter, digit or RGI emoji at all (only spaces, joiners, marks, symbols/punctuation);
 *  - a single word mixing scripts (Script_Extensions, Common/Inherited ignored; v1.2.3).
 * `reserved_term`: whole-word reserved term or brand prefix/suffix on the confusable skeleton.
 */
export const DISPLAY_NAME_MAX_GRAPHEMES = 50;
export const DISPLAY_NAME_MAX_CODE_POINTS = 100;
export const MAX_CONSECUTIVE_COMBINING_MARKS = 3;

export type DisplayNameIssue = 'too_short' | 'too_long' | 'invalid_format' | 'reserved_term';

const segmenter = new Intl.Segmenter('und', { granularity: 'grapheme' });

/** NFC, then trims space separators (Zs) and U+FEFF at either end (§6 text hygiene, rule 4). */
export function normalizeDisplayName(raw: string): string {
  return trimHygiene(raw.normalize('NFC'));
}

/**
 * Validates a RAW (un-normalized) display name: a non-empty value that is only whitespace is
 * `invalid_format` (contract v1.2.4, QA-010); otherwise the normalized value is checked with
 * {@link displayNameIssue}. The empty string stays `too_short`.
 */
export function rawDisplayNameIssue(
  raw: string,
  reservedTerms: readonly string[],
  brandTerms: readonly string[] = [],
): DisplayNameIssue | null {
  const value = normalizeDisplayName(raw);
  if (raw.length > 0 && value.length === 0) return 'invalid_format';
  return displayNameIssue(value, reservedTerms, brandTerms);
}

export function graphemeCount(value: string): number {
  let count = 0;
  for (const _ of segmenter.segment(value)) count += 1;
  return count;
}

function longestMarkRun(value: string): number {
  let longest = 0;
  let run = 0;
  for (const ch of value) {
    run = isMark(ch.codePointAt(0)!) ? run + 1 : 0;
    longest = Math.max(longest, run);
  }
  return longest;
}

export type TextHygieneIssue = 'too_short' | 'too_long' | 'invalid_format';

/**
 * The character-hygiene part of the displayName rules, shared with live-room titles
 * (CONVENTIONS §6 text hygiene, §10.3): emptiness, rejected code points, length in graphemes and
 * code points, joiner placement, zalgo cap and "at least one letter, digit or RGI emoji". Expects
 * a normalized value ({@link normalizeDisplayName}).
 * It deliberately excludes the identity rules (reserved terms, confusables, mixed scripts).
 */
export function textHygieneIssue(
  value: string,
  limits: { readonly maxGraphemes: number; readonly maxCodePoints: number },
): TextHygieneIssue | null {
  if (value.length === 0) return 'too_short';
  const scan = scanHygiene(value);
  if (scan.rejected) return 'invalid_format';
  if ([...value].length > limits.maxCodePoints || graphemeCount(value) > limits.maxGraphemes) {
    return 'too_long';
  }
  if (scan.misplacedJoiner) return 'invalid_format';
  // Counted on the decomposed form so precomposition (NFC) cannot hide a stacked mark. Variation
  // selectors are marks (Mn) and count too (§6 rule 6).
  if (longestMarkRun(value.normalize('NFD')) > MAX_CONSECUTIVE_COMBINING_MARKS) return 'invalid_format';
  if (!scan.hasLetterDigitOrEmoji) return 'invalid_format';
  return null;
}

/** Returns the first rule violated by an already-normalized display name, or null. */
export function displayNameIssue(
  value: string,
  reservedTerms: readonly string[],
  brandTerms: readonly string[] = [],
): DisplayNameIssue | null {
  const hygiene = textHygieneIssue(value, {
    maxGraphemes: DISPLAY_NAME_MAX_GRAPHEMES,
    maxCodePoints: DISPLAY_NAME_MAX_CODE_POINTS,
  });
  if (hygiene) return hygiene;
  // Reserved terms first (when configured), so a homoglyph spoof reports `reserved_term`; the
  // schema stage (no terms) reports the same spoof as a mixed-script `invalid_format`.
  if (containsReservedTerm(value, reservedTerms, brandTerms)) return 'reserved_term';
  if (hasMixedScriptWord(value)) return 'invalid_format';
  return null;
}
