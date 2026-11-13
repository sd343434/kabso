/**
 * Username rules of D146 (CONVENTIONS §6, §10.32): the stricter rule for new regular usernames
 * and the premium tiers. Pure functions shared by the API, the `premium-admin` CLI and the tests
 * (no Nest or Prisma dependencies).
 */
import { isReservedUsername, USERNAME_MAX_LENGTH } from '../users/username.js';

/**
 * The four tiers of a premium username (`premium_username_tier`), matching the owner's medal art
 * (D146 amendment): LEGEND (rainbow, crowned), RUBY (Kabso red), GOLD, SILVER.
 */
export type PremiumTier = 'LEGEND' | 'RUBY' | 'GOLD' | 'SILVER';
export const PREMIUM_TIERS: readonly PremiumTier[] = ['LEGEND', 'RUBY', 'GOLD', 'SILVER'];

/** A new regular username has at least this many characters (owner D146). */
export const REGULAR_USERNAME_MIN_LENGTH = 6;

/**
 * Why a name cannot be a new regular username (`VALIDATION_FAILED` issues on `username`):
 * `too_short` (under 6, and not premium), `too_long` (over 30), `invalid_format` (a character
 * other than a–z, 0–9 and `_`, or `_` first or last), `letters_and_digits` (no letter or no
 * digit), `premium` (a premium username: it can only be rented, §10.32).
 */
export type RegularUsernameIssue =
  'too_short' | 'too_long' | 'invalid_format' | 'letters_and_digits' | 'premium';

/** a–z, 0–9 and `_`, never `_` first or last (the charset of D146, narrowed from v1.0 `.`/`_`). */
const REGULAR_CHARS = /^[a-z0-9](?:[a-z0-9_]*[a-z0-9])?$/;
/** Premium usernames are letters and digits only (no `_`, no `.`), 1–30. */
const PREMIUM_CHARS = /^[a-z0-9]{1,30}$/;
const LETTERS_ONLY = /^[a-z]+$/;
const DIGITS_ONLY = /^[0-9]+$/;
/** One character repeated: `777777`, `aaaa`. */
const ONE_REPEATED = /^(.)\1+$/;
/** A run of three identical characters anywhere: `ali777`, `aaab12`. */
const TRIPLE_RUN = /(.)\1\1/;

/** Reads the same both ways: `1221`, `abba`, `12321`. */
function isPalindrome(name: string): boolean {
  return name === [...name].reverse().join('');
}

/** The first half repeated: `1212`, `abab`, `123123`. */
function isDoubled(name: string): boolean {
  const half = name.length / 2;
  return name.length % 2 === 0 && name.slice(0, half) === name.slice(half);
}

/** Consecutive digits or letters, up or down: `123456`, `654321`, `abcdef`, `fedcba`. */
function isSequence(name: string): boolean {
  if (!DIGITS_ONLY.test(name) && !LETTERS_ONLY.test(name)) return false;
  for (const step of [1, -1]) {
    let ok = true;
    for (let i = 1; i < name.length && ok; i += 1) ok = name.charCodeAt(i) - name.charCodeAt(i - 1) === step;
    if (ok) return true;
  }
  return false;
}

/**
 * The premium tier of `name`, or null when it is not a premium username (owner D146, adapted from
 * the owner's `specialIdTierFor` to usernames of letters and digits; the server is the source of
 * truth, the apps only show the tier they are given):
 * - LEGEND: 1–3 characters;
 * - RUBY: one character repeated, 4 or more (`7777`, `aaaaaa`);
 * - GOLD: 4–5 characters, or a pattern — a palindrome (`1221`, `abba`), doubled halves (`1212`,
 *   `abab`), a sequence (`123456`, `abcdef`) or a run of three (`ali777`);
 * - SILVER: 6 or more letters only or digits only (names that are not regular).
 * Only lower-case letters and digits qualify (a name with `_` or `.` is never premium).
 */
export function premiumTierOf(name: string): PremiumTier | null {
  if (!PREMIUM_CHARS.test(name)) return null;
  if (name.length <= 3) return 'LEGEND';
  if (ONE_REPEATED.test(name)) return 'RUBY';
  if (name.length <= 5) return 'GOLD';
  if (isPalindrome(name) || isDoubled(name) || isSequence(name) || TRIPLE_RUN.test(name)) return 'GOLD';
  if (LETTERS_ONLY.test(name) || DIGITS_ONLY.test(name)) return 'SILVER';
  return null;
}

/**
 * The first problem that keeps `name` (already lower case and trimmed) from being a new regular
 * username, or null when it is one. Checked in this order: premium → length → characters → a
 * letter and a digit. Existing usernames that break the rule are kept (grandfathered); this
 * applies to registration and to `PUT /me/username` only.
 */
export function regularUsernameIssue(name: string): RegularUsernameIssue | null {
  if (premiumTierOf(name) !== null) return 'premium';
  if (name.length < REGULAR_USERNAME_MIN_LENGTH) return 'too_short';
  if (name.length > USERNAME_MAX_LENGTH) return 'too_long';
  if (!REGULAR_CHARS.test(name)) return 'invalid_format';
  if (!/[a-z]/.test(name) || !/[0-9]/.test(name)) return 'letters_and_digits';
  return null;
}

/** Terms that make a premium username reserved wherever they appear in it (brand). */
const RESERVED_INFIXES = ['kabso'];

/**
 * Reserved by the code (never rented; an admin may still grant one, §10.32): the v1.0 reserved
 * names (`admin`, `support`, `official`, `staff`, `moderator`, …) and any name containing
 * `kabso`. The owner's list in `premium_username_reserved` (brand and offensive words, managed with
 * `premium-admin reserve`) is checked by the callers.
 */
export function isCodeReservedPremium(name: string): boolean {
  return isReservedUsername(name) || RESERVED_INFIXES.some((t) => name.includes(t));
}

/**
 * Names the store suggests (`GET /premium-usernames`), most attractive first within each tier:
 * repeated digits, ascending and descending digit runs, digit palindromes, repeated and running
 * letters. The store shows the ones that are free and on sale; the list is generated, never stored.
 */
export function suggestionCandidates(): string[] {
  const out = new Set<string>();
  const digits = '0123456789';
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  // One repeated digit, 1–8 long, 7 / 8 / 9 first (popular), then the rest.
  const order = ['7', '8', '9', '1', '6', '5', '3', '2', '4', '0'];
  for (let len = 1; len <= 8; len += 1) for (const d of order) out.add(d.repeat(len));
  // Ascending and descending runs of digits, 3–9 long.
  for (let len = 3; len <= 9; len += 1) {
    for (let start = 0; start + len <= 10; start += 1) {
      const run = digits.slice(start, start + len);
      out.add(run);
      out.add([...run].reverse().join(''));
    }
  }
  // Digit palindromes: abba, abcba, abccba with a ≠ 0.
  for (const a of order.filter((d) => d !== '0')) {
    for (const b of digits) {
      if (a === b) continue;
      out.add(`${a}${b}${b}${a}`);
      out.add(`${a}${b}${a}${b}${a}`.slice(0, 5));
      out.add(`${a}${b}${b}${b}${a}`);
      out.add(`${a}${a}${b}${b}${a}${a}`);
    }
  }
  // Letters: one letter, a letter twice / three times, and short alphabet runs.
  for (const l of letters) {
    out.add(l);
    out.add(l.repeat(2));
    out.add(l.repeat(3));
    out.add(l.repeat(4));
  }
  for (let len = 3; len <= 6; len += 1) {
    for (let start = 0; start + len <= letters.length; start += 1) out.add(letters.slice(start, start + len));
  }
  return [...out].filter((n) => premiumTierOf(n) !== null && !isCodeReservedPremium(n));
}
