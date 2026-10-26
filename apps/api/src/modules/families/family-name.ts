import { containsReservedTerm } from '../users/confusables.js';
import { graphemeCount, normalizeDisplayName, textHygieneIssue } from '../users/display-name.js';
import { hasMixedScriptWord } from '../users/script-mixing.js';
import {
  FAMILY_NAME_MAX_CODE_POINTS,
  FAMILY_NAME_MAX_GRAPHEMES,
  FAMILY_NAME_MIN_GRAPHEMES,
} from './families.constants.js';

export type FamilyNameIssue = 'too_short' | 'too_long' | 'invalid_format' | 'reserved_term';

/**
 * A family name (CP-018, §10.21) follows the display-name text rules (CONVENTIONS §6: NFC, trimmed,
 * text hygiene, joiners, zalgo, at least one letter, digit or emoji, no mixed-script word, no
 * reserved term) with 2–20 grapheme clusters and at most 40 code points. Returns the first problem
 * of the RAW value, or null; {@link normalizeFamilyName} gives the stored form.
 */
export function familyNameIssue(
  raw: string,
  reservedTerms: readonly string[],
  brandTerms: readonly string[],
): FamilyNameIssue | null {
  const value = normalizeDisplayName(raw);
  if (raw.length > 0 && value.length === 0) return 'invalid_format';
  const hygiene = textHygieneIssue(value, {
    maxGraphemes: FAMILY_NAME_MAX_GRAPHEMES,
    maxCodePoints: FAMILY_NAME_MAX_CODE_POINTS,
  });
  if (hygiene) return hygiene;
  if (graphemeCount(value) < FAMILY_NAME_MIN_GRAPHEMES) return 'too_short';
  if (containsReservedTerm(value, reservedTerms, brandTerms)) return 'reserved_term';
  if (hasMixedScriptWord(value)) return 'invalid_format';
  return null;
}

/** The stored name: NFC and trimmed (display-name normalization). */
export function normalizeFamilyName(raw: string): string {
  return normalizeDisplayName(raw);
}

/**
 * The uniqueness key: NFKC, then lower case (so "Lions" and "LIONS", or full-width letters, are
 * the same name). Unique among families that are not disbanded.
 */
export function familyNameKey(name: string): string {
  return name.normalize('NFKC').toLowerCase();
}
