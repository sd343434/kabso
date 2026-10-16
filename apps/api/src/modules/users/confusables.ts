import { CONFUSABLES_DATA } from './data/confusables.generated.js';

/**
 * Confusable skeleton and reserved-term matching for display names (contract v1.2.3 §6,
 * SEC-024). The mapping table is generated from the vendored, checksummed Unicode
 * `confusables.txt` (UTS #39, see `data/README.md`).
 *
 * Skeleton algorithm (UTS #39 §4, applied on both sides of case-folding):
 *  1. NFKC, then NFD; remove default-ignorable code points and Arabic tatweel.
 *  2. Map every code point through the confusables table on the ORIGINAL case, so uppercase
 *     homoglyphs (Greek Μ, Cyrillic М, Greek Β, …) reach their Latin prototypes. NFD.
 *  3. Case-fold (lowercase + NFKC), NFD, remove ignorables again.
 *  4. Apply {@link SUPPLEMENT} (documented Kabso additions, below).
 *  5. Map through the table again (catches look-alikes that only exist in lowercase). NFD.
 *  6. Remove combining marks (diacritics/tashkeel) so accents cannot bypass a term.
 * The same function is applied to names and to reserved terms.
 */

const TABLE: ReadonlyMap<number, string> = (() => {
  const map = new Map<number, string>();
  for (const record of CONFUSABLES_DATA.split(';')) {
    const [source, target] = record.split('>');
    if (!source || !target) continue;
    map.set(
      parseInt(source, 16),
      target
        .split(' ')
        .map((hex) => String.fromCodePoint(parseInt(hex, 16)))
        .join(''),
    );
  }
  return map;
})();

export const CONFUSABLES_MAPPING_COUNT = TABLE.size;

/**
 * Kabso additions applied after case-folding (both sides, so they only make matching stricter):
 *  - `i` → `l`: the table maps `I` (capital) and `1` to `l` but not `i`; unifying makes
 *    "ADMIN" and "admin" share a skeleton.
 *  - `ĸ` → `k`: the table maps κ, к and ᴋ to kra (`ĸ`), but plain `k` to itself.
 *  - ػ U+063B, ؼ U+063C → ك: keheh variants missing from the table (A7 PoC "ػابسو").
 *  - ة U+0629 → ه: teh marbuta/heh spelling variants ("الإدارة" vs "الاداره").
 */
const SUPPLEMENT: ReadonlyMap<number, string> = new Map([
  [0x69, 'l'],
  [0x138, 'k'],
  [0x63b, String.fromCodePoint(0x643)],
  [0x63c, String.fromCodePoint(0x643)],
  [0x629, String.fromCodePoint(0x647)],
]);

/** Default_Ignorable_Code_Point subset relevant to names, plus Arabic tatweel (U+0640). */
const IGNORABLE_RANGES: readonly (readonly [number, number])[] = [
  [0x00ad, 0x00ad],
  [0x034f, 0x034f],
  [0x0640, 0x0640],
  [0x061c, 0x061c],
  [0x115f, 0x1160],
  [0x17b4, 0x17b5],
  [0x180b, 0x180f],
  [0x200b, 0x200f],
  [0x202a, 0x202e],
  [0x2060, 0x206f],
  [0x3164, 0x3164],
  [0xfe00, 0xfe0f],
  [0xfeff, 0xfeff],
  [0xffa0, 0xffa0],
];

function isIgnorable(code: number): boolean {
  return IGNORABLE_RANGES.some(([from, to]) => code >= from && code <= to);
}

function mapEach(input: string, table: ReadonlyMap<number, string>): string {
  let out = '';
  for (const ch of input) {
    const code = ch.codePointAt(0) ?? 0;
    if (isIgnorable(code)) continue;
    out += table.get(code) ?? ch;
  }
  return out;
}

function fold(input: string): string {
  return input.toLowerCase().normalize('NFKC');
}

export function confusableSkeleton(input: string): string {
  const prepared = input.normalize('NFKC').normalize('NFD');
  const beforeFold = mapEach(prepared, TABLE).normalize('NFD');
  const folded = mapEach(fold(beforeFold).normalize('NFD'), SUPPLEMENT);
  const afterFold = mapEach(folded, TABLE).normalize('NFD');
  return afterFold.replace(/\p{M}/gu, '').normalize('NFD');
}

const NON_WORD = /[^\p{L}\p{N}]+/u;
const NON_WORD_GLOBAL = /[^\p{L}\p{N}]+/gu;

/**
 * Reserved-term rule (contract v1.2.3 §6) on the confusable skeleton, split into words on any
 * non-letter/digit:
 *  (a) a reserved term equals a WHOLE WORD ("Kabso Live", "kabso_official", "Admin");
 *  (b) any single word CONTAINS a brand term ("TheKabsoTeam", "KabsoFan", "فريقكابسوالرسمي");
 *  (c) the whole name with separators removed EQUALS a reserved term ("K a b s o").
 * Generic terms inside ordinary words ("Badminton", "Supporter") and a brand split across words
 * ("Kab Sonia") are allowed.
 */
export function containsReservedTerm(
  name: string,
  reservedTerms: readonly string[],
  brandTerms: readonly string[] = [],
): boolean {
  const skeleton = confusableSkeleton(name);
  const words = skeleton.split(NON_WORD).filter(Boolean);
  const toWord = (term: string) => confusableSkeleton(term).replace(NON_WORD_GLOBAL, '');
  const terms = new Set(reservedTerms.map(toWord).filter(Boolean));
  const brands = brandTerms.map(toWord).filter(Boolean);

  if (words.some((word) => terms.has(word))) return true; // (a)
  if (words.some((word) => brands.some((brand) => word.includes(brand)))) return true; // (b)
  return terms.has(words.join('')); // (c)
}
