import {
  DI_DATA,
  GC_DATA,
  IVD_DATA,
  IVD_RELEASE,
  RGI_DATA,
  UI_DATA,
  VARIATION_DATA,
  VS_DATA,
} from './data/text-hygiene.generated.js';

/**
 * Text hygiene for `displayName` and live-room titles (CONVENTIONS §6 "Text hygiene", v1.3.1,
 * SEC-036). Every property comes from the vendored Unicode 17.0.0 data compiled into
 * `data/text-hygiene.generated.ts`; the runtime's own Unicode tables (`\p{…}`) are not used here.
 * Grapheme clusters come from `Intl.Segmenter` (the RGI emoji exception applies to a cluster that
 * is exactly one RGI emoji sequence).
 *
 * Rule 2 rejects a code point whose General_Category is Cc, Cf, Zl, Zp, Co, Cs or Cn, that has
 * Default_Ignorable_Code_Point = Yes, or that is on the blank look-alike list. Rule 3 allows only:
 * any code point inside an RGI emoji cluster; ZWNJ/ZWJ between two non-joiner, non-space
 * characters; a variation selector only as part of a LISTED variation sequence (v1.4, SEC-039):
 * the pair (code point before it, selector) appears in StandardizedVariants.txt,
 * emoji-variation-sequences.txt or the IVD. Rule 2 also rejects every space separator other than
 * U+0020, U+00A0, U+202F and U+3000 inside a value (v1.4, rule 4) and U+16FE4 (blank list).
 *
 * IVD (KL-049): the IVD 2022-09-13 `IVD_Sequences.txt` named by the contract could not be fetched
 * from a verifiable source in the build environment, so it is not vendored yet
 * (`IVD_RELEASE === null`). Until it is, an ideographic variation selector (U+E0100..U+E01EF) is
 * accepted after a Unified_Ideograph base: registered Japanese/Korean names keep working, but an
 * unregistered sequence on an ideograph is not rejected (a documented deviation from §6 rule 3,
 * limited to CJK ideograph bases). Vendoring the file and regenerating switches to the
 * registered-pairs rule with no code change.
 */

/** General_Category groups: L N M S P, Z = Zs only, X = Cc Cf Zl Zp Co Cs Cn. */
export type CategoryGroup = 'L' | 'N' | 'M' | 'S' | 'P' | 'Z' | 'X';

/** Contract §6 rule 2: the blank look-alike list (changes only by contract patch). */
export const BLANK_LOOKALIKES: ReadonlySet<number> = new Set([
  0x115f, 0x1160, 0x3164, 0xffa0, 0x2800, 0xfffc, 0x1d159,
  // v1.4 (SEC-039): KHITAN SMALL SCRIPT FILLER
  0x16fe4,
]);

/** §6 rule 4 (v1.4, SEC-039): the only space separators allowed inside a value. */
export const ALLOWED_INNER_SPACES: ReadonlySet<number> = new Set([0x20, 0xa0, 0x202f, 0x3000]);

const ZWNJ = 0x200c;
const ZWJ = 0x200d;
const BOM = 0xfeff;

const gcStarts: number[] = [];
const gcGroups: CategoryGroup[] = [];
for (const record of GC_DATA.split(';')) {
  const [start = '', group = 'X'] = record.split(':');
  gcStarts.push(parseInt(start, 16));
  gcGroups.push(group as CategoryGroup);
}

function parseRanges(data: string): Uint32Array {
  const parts = data.split(';');
  const out = new Uint32Array(parts.length * 2);
  parts.forEach((part, i) => {
    const [a = '', b = ''] = part.split('-');
    out[i * 2] = parseInt(a, 16);
    out[i * 2 + 1] = parseInt(b, 16);
  });
  return out;
}

const DEFAULT_IGNORABLE = parseRanges(DI_DATA);
const VARIATION_SELECTORS = parseRanges(VS_DATA);
const UNIFIED_IDEOGRAPHS = parseRanges(UI_DATA);

/** "BASE:SEL,SEL;…" → Map<base, Set<selector>>; `offset` is added to each selector. */
function parsePairs(data: string, offset: number): Map<number, Set<number>> {
  const map = new Map<number, Set<number>>();
  if (data === '') return map;
  for (const record of data.split(';')) {
    const [base = '', selectors = ''] = record.split(':');
    map.set(parseInt(base, 16), new Set(selectors.split(',').map((h) => parseInt(h, 16) + offset)));
  }
  return map;
}

/** SEC-039: StandardizedVariants.txt + emoji-variation-sequences.txt (UCD 17.0.0). */
const LISTED_VARIATIONS = parsePairs(VARIATION_DATA, 0);
/** SEC-039: registered ideographic variation sequences (empty while the IVD is not vendored). */
const IVD_SEQUENCES = parsePairs(IVD_DATA, 0xe0100);

/** Whether the IVD is vendored; false means the interim Unified_Ideograph rule is active. */
export const IVD_VENDORED = IVD_RELEASE !== null;

/** Number of bases with a listed (non-IVD) variation sequence. */
export const LISTED_VARIATION_BASES = LISTED_VARIATIONS.size;

/** Every listed (non-IVD) variation sequence as [base, selector] (for tests). */
export function* listedVariationSequences(): Generator<[number, number]> {
  for (const [base, selectors] of LISTED_VARIATIONS) for (const sel of selectors) yield [base, sel];
}

/** Every registered IVD sequence as [base, selector] (empty while the IVD is not vendored). */
export function* ivdSequences(): Generator<[number, number]> {
  for (const [base, selectors] of IVD_SEQUENCES) for (const sel of selectors) yield [base, sel];
}

function inRanges(ranges: Uint32Array, cp: number): boolean {
  let lo = 0;
  let hi = ranges.length / 2 - 1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (cp < ranges[mid * 2]!) hi = mid - 1;
    else if (cp > ranges[mid * 2 + 1]!) lo = mid + 1;
    else return true;
  }
  return false;
}

const RGI_EMOJI: ReadonlySet<string> = (() => {
  const set = new Set<string>();
  for (const record of RGI_DATA.split(';')) {
    if (record.includes('..')) {
      const [a = '', b = ''] = record.split('..');
      for (let c = parseInt(a, 16); c <= parseInt(b, 16); c += 1) set.add(String.fromCodePoint(c));
    } else {
      set.add(String.fromCodePoint(...record.split(' ').map((h) => parseInt(h, 16))));
    }
  }
  return set;
})();

/** Number of distinct RGI emoji sequences in the vendored Emoji 17.0 data. */
export const RGI_EMOJI_COUNT = RGI_EMOJI.size;

/** Every RGI emoji sequence (for tests). */
export function rgiEmojiSequences(): IterableIterator<string> {
  return RGI_EMOJI.values();
}

export function isRgiEmoji(sequence: string): boolean {
  return RGI_EMOJI.has(sequence);
}

/** Vendored General_Category group of a code point (unlisted code points are Cn → X). */
export function categoryGroup(cp: number): CategoryGroup {
  let lo = 0;
  let hi = gcStarts.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (gcStarts[mid]! <= cp) lo = mid;
    else hi = mid - 1;
  }
  return gcGroups[lo] ?? 'X';
}

export function isDefaultIgnorable(cp: number): boolean {
  return inRanges(DEFAULT_IGNORABLE, cp);
}

export function isVariationSelector(cp: number): boolean {
  return inRanges(VARIATION_SELECTORS, cp);
}

export function isUnifiedIdeograph(cp: number): boolean {
  return inRanges(UNIFIED_IDEOGRAPHS, cp);
}

const IVS_FIRST = 0xe0100;
const IVS_LAST = 0xe01ef;

/**
 * §6 rule 3 (v1.4, SEC-039): the pair (base, selector) is a listed variation sequence. With the IVD
 * not vendored, an ideographic variation selector after a Unified_Ideograph is accepted (interim,
 * see the module comment).
 */
export function isListedVariationSequence(base: number, selector: number): boolean {
  if (LISTED_VARIATIONS.get(base)?.has(selector)) return true;
  if (selector < IVS_FIRST || selector > IVS_LAST) return false;
  if (IVD_VENDORED) return IVD_SEQUENCES.get(base)?.has(selector) ?? false;
  return isUnifiedIdeograph(base);
}

/**
 * Rule 2 (before the rule 3 exceptions), including the v1.4 inner-space rule: a space separator
 * other than U+0020, U+00A0, U+202F and U+3000 (edges are trimmed before this runs).
 */
export function isRejectedCodePoint(cp: number): boolean {
  const group = categoryGroup(cp);
  return (
    group === 'X' ||
    (group === 'Z' && !ALLOWED_INNER_SPACES.has(cp)) ||
    isDefaultIgnorable(cp) ||
    BLANK_LOOKALIKES.has(cp)
  );
}

/** Space separator (Zs), rule 4. */
export function isSpace(cp: number): boolean {
  return categoryGroup(cp) === 'Z';
}

export function isMark(cp: number): boolean {
  return categoryGroup(cp) === 'M';
}

function isJoiner(cp: number | undefined): boolean {
  return cp === ZWNJ || cp === ZWJ;
}

/** A base for a variation selector: L*, N*, S*, P* and not rejected by rule 2. */
function isBase(cp: number | undefined): boolean {
  if (cp === undefined) return false;
  const group = categoryGroup(cp);
  return (group === 'L' || group === 'N' || group === 'S' || group === 'P') && !isRejectedCodePoint(cp);
}

/** Rule 5: a letter or digit that passes rule 2 (fillers and blank look-alikes never count). */
function isLetterOrDigit(cp: number): boolean {
  const group = categoryGroup(cp);
  return (group === 'L' || group === 'N') && !isRejectedCodePoint(cp);
}

/**
 * Trims space separators (Zs, rule 4) and U+FEFF (v1.2.1) at either end. Line/paragraph
 * separators and controls are not spaces: they stay and are rejected by rule 2.
 */
export function trimHygiene(value: string): string {
  const cps = [...value];
  const trimmable = (ch: string) => {
    const cp = ch.codePointAt(0)!;
    return cp === BOM || isSpace(cp);
  };
  let start = 0;
  let end = cps.length;
  while (start < end && trimmable(cps[start]!)) start += 1;
  while (end > start && trimmable(cps[end - 1]!)) end -= 1;
  return start === 0 && end === cps.length ? value : cps.slice(start, end).join('');
}

const segmenter = new Intl.Segmenter('und', { granularity: 'grapheme' });

export interface HygieneScan {
  /** A code point rejected by rule 2 that no rule 3 exception allows (joiners excluded). */
  readonly rejected: boolean;
  /** A ZWNJ/ZWJ outside an RGI emoji that is not between two non-joiner, non-space characters. */
  readonly misplacedJoiner: boolean;
  /** Rule 5: at least one letter, digit (passing rule 2) or RGI emoji cluster. */
  readonly hasLetterDigitOrEmoji: boolean;
}

/** Scans an already NFC-normalized, trimmed value. */
export function scanHygiene(value: string): HygieneScan {
  const cps: number[] = [];
  const inRgi: boolean[] = [];
  let hasEmoji = false;
  for (const { segment } of segmenter.segment(value)) {
    const rgi = RGI_EMOJI.has(segment);
    if (rgi) hasEmoji = true;
    for (const ch of segment) {
      cps.push(ch.codePointAt(0)!);
      inRgi.push(rgi);
    }
  }

  let rejected = false;
  let misplacedJoiner = false;
  let hasLetter = false;
  for (let k = 0; k < cps.length; k += 1) {
    const cp = cps[k]!;
    if (!hasLetter && isLetterOrDigit(cp)) hasLetter = true;
    if (inRgi[k] || !isRejectedCodePoint(cp)) continue;
    if (isJoiner(cp)) {
      const before = cps[k - 1];
      const after = cps[k + 1];
      if (
        before === undefined ||
        after === undefined ||
        isJoiner(before) ||
        isJoiner(after) ||
        isSpace(before) ||
        isSpace(after)
      ) {
        misplacedJoiner = true;
      }
      continue;
    }
    if (isVariationSelector(cp)) {
      const before = cps[k - 1];
      // SEC-039: only a listed sequence; never at the start, after a space or after a selector
      // (no listed sequence has one of those as its base). After a mark only when that exact pair
      // is listed: the single case in UCD 17.0.0 is U+1031 U+FE00 (Myanmar vowel sign E, Mc).
      if (
        before !== undefined &&
        (isBase(before) || (isMark(before) && !isRejectedCodePoint(before))) &&
        isListedVariationSequence(before, cp)
      ) {
        continue;
      }
    }
    rejected = true;
  }
  return { rejected, misplacedJoiner, hasLetterDigitOrEmoji: hasLetter || hasEmoji };
}
