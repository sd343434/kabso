import { DI_DATA, GC_DATA, RGI_DATA, VS_DATA } from './data/text-hygiene.generated.js';

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
 * characters; one variation selector directly after a base character (L*, N*, S*, P* not rejected
 * by rule 2).
 */

/** General_Category groups: L N M S P, Z = Zs only, X = Cc Cf Zl Zp Co Cs Cn. */
export type CategoryGroup = 'L' | 'N' | 'M' | 'S' | 'P' | 'Z' | 'X';

/** Contract §6 rule 2: the blank look-alike list (changes only by contract patch). */
export const BLANK_LOOKALIKES: ReadonlySet<number> = new Set([
  0x115f, 0x1160, 0x3164, 0xffa0, 0x2800, 0xfffc, 0x1d159,
]);

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

/** Rule 2 (before the rule 3 exceptions). */
export function isRejectedCodePoint(cp: number): boolean {
  return categoryGroup(cp) === 'X' || isDefaultIgnorable(cp) || BLANK_LOOKALIKES.has(cp);
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
    if (isVariationSelector(cp) && isBase(cps[k - 1])) continue;
    rejected = true;
  }
  return { rejected, misplacedJoiner, hasLetterDigitOrEmoji: hasLetter || hasEmoji };
}
