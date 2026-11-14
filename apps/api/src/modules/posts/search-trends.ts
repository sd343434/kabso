import { maskBlockedWords } from '../live/live-blocked-words.js';

/**
 * Search trends (v1.29-live, D147, CONVENTIONS §11.11): the pure rules — which submitted searches
 * are counted, how a term is normalized, and its tag.
 */

/** Terms of 2–64 code points are counted. */
export const SEARCH_TERM_MIN_CODE_POINTS = 2;
export const SEARCH_TERM_MAX_CODE_POINTS = 64;
/** `GET /search/trending` lists at most this many terms. */
export const TRENDING_SEARCH_COUNT = 6;
/** A searcher counts once per term in this many days (the Redis dedupe key's lifetime). */
export const SEARCHER_DEDUPE_DAYS = 7;
/** Counts (and unhidden terms without counts) older than this are dropped by the sweeper. */
export const SEARCH_TREND_RETENTION_DAYS = 14;
/** TRENDING: at least this many searchers in the last 24 h … */
export const TRENDING_MIN_DAY_SEARCHERS = 3;
/** … and at least this many times the 24 h before. */
export const TRENDING_RISE_FACTOR = 2;

/** A run of this many digits is never counted (phone, room or account numbers). */
const LONG_DIGIT_RUN = /\p{Nd}{5,}/u;

/**
 * The counted form of a submitted search, or null when it is not counted: NFC, trimmed, one
 * leading `@` or `#` dropped, inner spaces collapsed to one, lower case; 2–64 code points with at
 * least one letter; never with a control or format character, `@` (emails), a link (`://`,
 * `www.`) or a run of 5+ digits (numbers that identify someone).
 */
export function normalizeSearchTerm(raw: string): string | null {
  const term = raw.normalize('NFC').trim().replace(/^[@#]/, '').trim().replace(/\s+/gu, ' ').toLowerCase();
  const length = [...term].length;
  if (length < SEARCH_TERM_MIN_CODE_POINTS || length > SEARCH_TERM_MAX_CODE_POINTS) return null;
  if (!/\p{L}/u.test(term)) return null;
  if (/[\p{Cc}\p{Cf}]/u.test(term)) return null;
  if (term.includes('@') || term.includes('://') || term.includes('www.')) return null;
  if (LONG_DIGIT_RUN.test(term)) return null;
  return term;
}

/** True when [text] contains one of [words] (folded like live blocked words, §10.14). */
export function containsBlockedWord(text: string, words: readonly string[]): boolean {
  return words.length > 0 && maskBlockedWords(text, words) !== text;
}

export type TrendingTag = 'TRENDING' | 'NEW';

/** One term's numbers for the tag. */
export interface TermStats {
  readonly firstSeenAt: Date;
  /** Searchers in the last 24 h. */
  readonly day: number;
  /** Searchers in the 24 h before that. */
  readonly previousDay: number;
}

/**
 * `NEW` when the term was first searched in the last 24 h; else `TRENDING` when at least
 * {@link TRENDING_MIN_DAY_SEARCHERS} people searched it in the last 24 h and that is at least
 * {@link TRENDING_RISE_FACTOR} times the 24 h before; else null.
 */
export function trendingTag(stats: TermStats, now: Date): TrendingTag | null {
  if (now.getTime() - stats.firstSeenAt.getTime() < 24 * 3600_000) return 'NEW';
  if (stats.day >= TRENDING_MIN_DAY_SEARCHERS && stats.day >= TRENDING_RISE_FACTOR * stats.previousDay) {
    return 'TRENDING';
  }
  return null;
}

/** The start of the UTC hour of [at]. */
export function hourOf(at: Date): Date {
  const d = new Date(at.getTime());
  d.setUTCMinutes(0, 0, 0);
  return d;
}
