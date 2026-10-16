/**
 * Minimal confusable skeleton for reserved-term matching (contract v1.2 §6, KL-017).
 *
 * WHY NOT A PACKAGE / THE FULL TABLE: UTS #39 defines `skeleton()` over the Unicode
 * `confusables.txt` table. No maintained npm implementation was found (2026-10-15):
 * `confusables` 1.1.1 (last release 2022), `unicode-confusables` 0.1.1 (2020),
 * `@moderation-api/unicode-spoofing` 0.4.0 (pre-1.0, five releases within one day, July 2026),
 * `decancer` (native binary, its own mapping, not UTS #39). The table itself could not be vendored
 * because unicode.org is not reachable from the build environment. This module therefore
 * implements the UTS #39 skeleton *algorithm* with a documented minimal mapping for the scripts
 * that matter for Kabso's reserved terms (Latin, Arabic) and their usual spoofs (Cyrillic, Greek,
 * Persian/Urdu letter variants, digits). Replace `CONFUSABLES` with a table generated from
 * `confusables.txt` when it can be fetched; the algorithm does not change.
 *
 * Algorithm (UTS #39 §4 + Kabso additions marked *):
 *  1. NFKC + lowercase (approximation of NFKC_Casefold).
 *  2. NFD.
 *  3. Remove default-ignorable code points (ZWJ, ZWNJ, …) and *Arabic tatweel.
 *  4. Map each code point through `CONFUSABLES`.
 *  5. *Remove combining marks (diacritics/tashkeel), so `الإدارة`, `ádmin` cannot bypass a term.
 *  6. NFD.
 * Both the input and every reserved term go through the same function, so mappings that are not
 * "visually perfect" (e.g. `i`/`l`/`1` → `l`) only make matching stricter, never inconsistent.
 */

/** Source → skeleton target (single code point keys; targets may be multi-character). */
export const CONFUSABLES: Readonly<Record<string, string>> = {
  // Latin look-alike clusters
  i: 'l',
  '1': 'l',
  '|': 'l',
  ı: 'l', // U+0131 dotless i
  ȷ: 'j',
  ɑ: 'a',
  ɡ: 'g',
  '0': 'o',
  m: 'rn', // UTS #39: "m" and "rn" share a skeleton
  w: 'vv',
  // Cyrillic
  а: 'a',
  в: 'b',
  ь: 'b',
  е: 'e',
  һ: 'h',
  і: 'l',
  ӏ: 'l',
  ј: 'j',
  к: 'k',
  о: 'o',
  р: 'p',
  с: 'c',
  ԁ: 'd',
  ԛ: 'q',
  ѕ: 's',
  т: 't',
  у: 'y',
  ԝ: 'vv',
  х: 'x',
  // Greek
  α: 'a',
  ι: 'l',
  κ: 'k',
  ν: 'v',
  ο: 'o',
  ρ: 'p',
  τ: 't',
  υ: 'u',
  χ: 'x',
  ϲ: 'c',
  ϳ: 'j',
  // Arabic-script variants (Persian/Urdu letters, alef wasla, teh marbuta, heh forms)
  ی: 'ي', // U+06CC Farsi yeh
  ى: 'ي', // U+0649 alef maksura
  ې: 'ي',
  ک: 'ك', // U+06A9 keheh
  ڪ: 'ك',
  ٱ: 'ا', // U+0671 alef wasla
  ة: 'ه', // U+0629 teh marbuta
  ہ: 'ه', // U+06C1
  ھ: 'ه', // U+06BE
  ە: 'ه', // U+06D5 (Kurdish)
  // Arabic-Indic and Extended (Persian/Urdu) digits → ASCII, then the digit rules above apply
  '٠': 'o',
  '١': 'l',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
  '۰': 'o',
  '۱': 'l',
  '۲': '2',
  '۳': '3',
  '۴': '4',
  '۵': '5',
  '۶': '6',
  '۷': '7',
  '۸': '8',
  '۹': '9',
};

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

function isIgnorable(ch: string): boolean {
  const code = ch.codePointAt(0) ?? 0;
  return IGNORABLE_RANGES.some(([from, to]) => code >= from && code <= to);
}

export function confusableSkeleton(input: string): string {
  const folded = input.normalize('NFKC').toLowerCase().normalize('NFKC').normalize('NFD');
  let mapped = '';
  for (const ch of folded) if (!isIgnorable(ch)) mapped += CONFUSABLES[ch] ?? ch;
  return mapped.normalize('NFD').replace(/\p{M}/gu, '').normalize('NFD');
}

/** True when the skeleton of `name` contains the skeleton of any reserved term. */
export function containsReservedTerm(name: string, reservedTerms: readonly string[]): boolean {
  const skeleton = confusableSkeleton(name);
  return reservedTerms.some((term) => {
    const termSkeleton = confusableSkeleton(term);
    return termSkeleton.length > 0 && skeleton.includes(termSkeleton);
  });
}
