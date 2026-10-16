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
 *  4. Apply {@link SUPPLEMENT} (documented Kabso additions, below). Latin small capitals are
 *     also mapped before step 2 (v1.2.6, SEC-030).
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
 *  - Latin small capitals U+1D00–U+1D22 and ʙ ɢ ʜ ɪ ʟ ɴ ʀ ʏ ꜰ ꜱ → their base letter (v1.2.6,
 *    SEC-030): the table maps none of them to Latin (Cyrillic в even maps TO ʙ), so "ᴋᴀʙꜱᴏ" and
 *    "кавѕо" kept a skeleton different from "kabso". `i`-shaped ones go straight to `l`.
 */
const SMALL_CAPITALS: readonly (readonly [number, string])[] = [
  [0x1d00, 'a'], // ᴀ
  [0x1d01, 'ae'], // ᴁ
  [0x1d02, 'ae'], // ᴂ turned ae
  [0x1d03, 'b'], // ᴃ barred B
  [0x1d04, 'c'], // ᴄ
  [0x1d05, 'd'], // ᴅ
  [0x1d06, 'd'], // ᴆ eth
  [0x1d07, 'e'], // ᴇ
  [0x1d08, 'e'], // ᴈ turned open e
  [0x1d09, 'l'], // ᴉ turned i (i → l, as above)
  [0x1d0a, 'j'], // ᴊ
  [0x1d0b, 'k'], // ᴋ
  [0x1d0c, 'l'], // ᴌ L with stroke
  [0x1d0d, 'm'], // ᴍ
  [0x1d0e, 'n'], // ᴎ reversed N
  [0x1d0f, 'o'], // ᴏ
  [0x1d10, 'o'], // ᴐ open O
  [0x1d11, 'o'], // ᴑ sideways o
  [0x1d12, 'o'], // ᴒ sideways open o
  [0x1d13, 'o'], // ᴓ sideways o with stroke
  [0x1d14, 'oe'], // ᴔ turned oe
  [0x1d15, 'ou'], // ᴕ OU
  [0x1d16, 'o'], // ᴖ top half o
  [0x1d17, 'o'], // ᴗ bottom half o
  [0x1d18, 'p'], // ᴘ
  [0x1d19, 'r'], // ᴙ reversed R
  [0x1d1a, 'r'], // ᴚ turned R
  [0x1d1b, 't'], // ᴛ
  [0x1d1c, 'u'], // ᴜ
  [0x1d1d, 'u'], // ᴝ sideways u
  [0x1d1e, 'u'], // ᴞ sideways diaeresized u
  [0x1d1f, 'm'], // ᴟ sideways turned m
  [0x1d20, 'v'], // ᴠ
  [0x1d21, 'w'], // ᴡ
  [0x1d22, 'z'], // ᴢ
  [0x0299, 'b'], // ʙ
  [0x0262, 'g'], // ɢ
  [0x029c, 'h'], // ʜ
  [0x026a, 'l'], // ɪ (i → l, as above)
  [0x029f, 'l'], // ʟ
  [0x0274, 'n'], // ɴ
  [0x0280, 'r'], // ʀ
  [0x028f, 'y'], // ʏ
  [0xa730, 'f'], // ꜰ
  [0xa731, 's'], // ꜱ
];

const SMALL_CAPITALS_MAP: ReadonlyMap<number, string> = new Map(SMALL_CAPITALS);

const SUPPLEMENT: ReadonlyMap<number, string> = new Map([
  [0x69, 'l'],
  [0x138, 'k'],
  [0x63b, String.fromCodePoint(0x643)],
  [0x63c, String.fromCodePoint(0x643)],
  [0x629, String.fromCodePoint(0x647)],
  ...SMALL_CAPITALS,
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
  // Small capitals first: the table would otherwise send some elsewhere (ᴍ → ʍ) (SEC-030).
  const prepared = mapEach(input.normalize('NFKC').normalize('NFD'), SMALL_CAPITALS_MAP);
  const beforeFold = mapEach(prepared, TABLE).normalize('NFD');
  const folded = mapEach(fold(beforeFold).normalize('NFD'), SUPPLEMENT);
  const afterFold = mapEach(folded, TABLE).normalize('NFD');
  return afterFold.replace(/\p{M}/gu, '').normalize('NFD');
}

const NON_WORD = /[^\p{L}\p{N}]+/u;
const NON_WORD_GLOBAL = /[^\p{L}\p{N}]+/gu;
const SPACES = /[\s\p{Z}]+/u;

/**
 * SEC-031 (v1.2.6) joined words, built on the NFKC name before the skeleton:
 *  - each space-delimited chunk with its inner separators removed ("Kab-so", "K.a.b.s.o",
 *    "Kab·so" → "kabso");
 *  - each run of two or more consecutive single-letter chunks, concatenated ("K a b s o Team",
 *    "ك ا ب س و لايف" → "kabso" / "كابسو").
 * Single-letter is judged on the original chunk (one letter/digit after dropping marks and
 * separators), so a letter whose skeleton expands (m → rn) still counts as one letter.
 */
function joinedWords(name: string): string[] {
  const chunks = name.normalize('NFKC').split(SPACES).filter(Boolean);
  const out: string[] = [];
  let run: string[] = [];
  const flush = () => {
    if (run.length >= 2) out.push(run.join(''));
    run = [];
  };
  for (const chunk of chunks) {
    const joined = confusableSkeleton(chunk).replace(NON_WORD_GLOBAL, '');
    if (!joined) {
      flush();
      continue;
    }
    out.push(joined);
    if ([...chunk.replace(/[^\p{L}\p{N}]/gu, '')].length === 1) run.push(joined);
    else flush();
  }
  flush();
  return out;
}

/**
 * Reserved-term rule (contract v1.2.3 §6) on the confusable skeleton, split into words on any
 * non-letter/digit:
 *  (a) a reserved term equals a WHOLE WORD ("Kabso Live", "kabso_official", "Admin");
 *  (b) any single word CONTAINS a brand term ("TheKabsoTeam", "KabsoFan", "فريقكابسوالرسمي");
 *  (c) the whole name with separators removed EQUALS a reserved term ("K a b s o").
 * Rules (a) and (b) also apply to the SEC-031 {@link joinedWords} (v1.2.6), so "Kab-so Live" and
 * "K a b s o Team" are reserved. Generic terms inside ordinary words ("Badminton", "Supporter")
 * and a brand split across multi-letter words ("Kab Sonia", "Abc Kab Sonite") are allowed.
 */
export function containsReservedTerm(
  name: string,
  reservedTerms: readonly string[],
  brandTerms: readonly string[] = [],
): boolean {
  const skeleton = confusableSkeleton(name);
  const words = [...skeleton.split(NON_WORD).filter(Boolean), ...joinedWords(name)];
  const toWord = (term: string) => confusableSkeleton(term).replace(NON_WORD_GLOBAL, '');
  const terms = new Set(reservedTerms.map(toWord).filter(Boolean));
  const brands = brandTerms.map(toWord).filter(Boolean);

  if (words.some((word) => terms.has(word))) return true; // (a)
  if (words.some((word) => brands.some((brand) => word.includes(brand)))) return true; // (b)
  return terms.has(skeleton.replace(NON_WORD_GLOBAL, '')); // (c)
}
