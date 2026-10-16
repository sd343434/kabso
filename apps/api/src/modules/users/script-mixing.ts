/**
 * Mixed-script words (contract v1.2.3 §6, SEC-024; UTS #39 §5 "single script" per word).
 *
 * A word (split on anything that is not a letter, digit or combining mark) is rejected when its
 * characters share no script. Each character counts with its Script_Extensions, and
 * Common/Inherited characters (digits, punctuation, emoji, most combining marks) are ignored.
 * Han, Hiragana, Katakana, Hangul and Bopomofo are augmented as in UTS #39 (Japanese, Korean
 * and Han-with-Bopomofo writing mixes them legitimately). Names that mix scripts across
 * DIFFERENT words ("Sara سارة") are allowed.
 *
 * v1.2.6 (SEC-032): decimal digits of every script (`\p{Nd}`, e.g. ٣ ۲) are script-neutral, and
 * Latin is augmented like UTS #39 "Highly Restrictive" (Latin + Han + Hiragana + Katakana,
 * Latin + Han + Hangul, Latin + Han + Bopomofo), so "TOKYO東京" and "Kim김" pass while Latin
 * mixed with Cyrillic or Greek is still rejected.
 */

/** Unicode 16 scripts supported by the JS engine (Node 22), most common first. */
const SCRIPTS: readonly string[] = [
  'Latin',
  'Arabic',
  'Cyrillic',
  'Greek',
  'Armenian',
  'Hebrew',
  'Han',
  'Hiragana',
  'Katakana',
  'Hangul',
  'Devanagari',
  'Thai',
  'Syriac',
  'Thaana',
  'Adlam',
  'Ahom',
  'Anatolian_Hieroglyphs',
  'Avestan',
  'Balinese',
  'Bamum',
  'Bassa_Vah',
  'Batak',
  'Bengali',
  'Bhaiksuki',
  'Bopomofo',
  'Brahmi',
  'Braille',
  'Buginese',
  'Buhid',
  'Canadian_Aboriginal',
  'Carian',
  'Caucasian_Albanian',
  'Chakma',
  'Cham',
  'Cherokee',
  'Chorasmian',
  'Coptic',
  'Cuneiform',
  'Cypriot',
  'Cypro_Minoan',
  'Deseret',
  'Dives_Akuru',
  'Dogra',
  'Duployan',
  'Egyptian_Hieroglyphs',
  'Elbasan',
  'Elymaic',
  'Ethiopic',
  'Garay',
  'Georgian',
  'Glagolitic',
  'Gothic',
  'Grantha',
  'Gujarati',
  'Gunjala_Gondi',
  'Gurmukhi',
  'Gurung_Khema',
  'Hanifi_Rohingya',
  'Hanunoo',
  'Hatran',
  'Imperial_Aramaic',
  'Inscriptional_Pahlavi',
  'Inscriptional_Parthian',
  'Javanese',
  'Kaithi',
  'Kannada',
  'Kawi',
  'Kayah_Li',
  'Kharoshthi',
  'Khitan_Small_Script',
  'Khmer',
  'Khojki',
  'Khudawadi',
  'Kirat_Rai',
  'Lao',
  'Lepcha',
  'Limbu',
  'Linear_A',
  'Linear_B',
  'Lisu',
  'Lycian',
  'Lydian',
  'Mahajani',
  'Makasar',
  'Malayalam',
  'Mandaic',
  'Manichaean',
  'Marchen',
  'Masaram_Gondi',
  'Medefaidrin',
  'Meetei_Mayek',
  'Mende_Kikakui',
  'Meroitic_Cursive',
  'Meroitic_Hieroglyphs',
  'Miao',
  'Modi',
  'Mongolian',
  'Mro',
  'Multani',
  'Myanmar',
  'Nabataean',
  'Nag_Mundari',
  'Nandinagari',
  'New_Tai_Lue',
  'Newa',
  'Nko',
  'Nushu',
  'Nyiakeng_Puachue_Hmong',
  'Ogham',
  'Ol_Chiki',
  'Ol_Onal',
  'Old_Hungarian',
  'Old_Italic',
  'Old_North_Arabian',
  'Old_Permic',
  'Old_Persian',
  'Old_Sogdian',
  'Old_South_Arabian',
  'Old_Turkic',
  'Old_Uyghur',
  'Oriya',
  'Osage',
  'Osmanya',
  'Pahawh_Hmong',
  'Palmyrene',
  'Pau_Cin_Hau',
  'Phags_Pa',
  'Phoenician',
  'Psalter_Pahlavi',
  'Rejang',
  'Runic',
  'Samaritan',
  'Saurashtra',
  'Sharada',
  'Shavian',
  'Siddham',
  'SignWriting',
  'Sinhala',
  'Sogdian',
  'Sora_Sompeng',
  'Soyombo',
  'Sundanese',
  'Sunuwar',
  'Syloti_Nagri',
  'Tagalog',
  'Tagbanwa',
  'Tai_Le',
  'Tai_Tham',
  'Tai_Viet',
  'Takri',
  'Tamil',
  'Tangsa',
  'Tangut',
  'Telugu',
  'Tibetan',
  'Tifinagh',
  'Tirhuta',
  'Todhri',
  'Toto',
  'Tulu_Tigalari',
  'Ugaritic',
  'Vai',
  'Vithkuqi',
  'Wancho',
  'Warang_Citi',
  'Yezidi',
  'Yi',
  'Zanabazar_Square',
];

const SCRIPT_TESTS: readonly (readonly [string, RegExp])[] = SCRIPTS.map((name) => [
  name,
  new RegExp(`\\p{Script_Extensions=${name}}`, 'u'),
]);
const COMMON_OR_INHERITED = /[\p{Script=Common}\p{Script=Inherited}]/u;
const DECIMAL_DIGIT = /\p{Nd}/u;
const WORD_SEPARATOR = /[^\p{L}\p{N}\p{M}]+/u;

const AUGMENT: Readonly<Record<string, readonly string[]>> = {
  Latin: ['Jpan', 'Kore', 'Hanb'],
  Han: ['Jpan', 'Kore', 'Hanb'],
  Hiragana: ['Jpan'],
  Katakana: ['Jpan'],
  Hangul: ['Kore'],
  Bopomofo: ['Hanb'],
};

const cache = new Map<number, ReadonlySet<string> | null>();

/** Augmented Script_Extensions of a character; null for Common/Inherited (ignored). */
export function scriptSet(ch: string): ReadonlySet<string> | null {
  const code = ch.codePointAt(0) ?? 0;
  const cached = cache.get(code);
  if (cached !== undefined) return cached;
  if (DECIMAL_DIGIT.test(ch)) {
    if (cache.size < 10_000) cache.set(code, null);
    return null;
  }
  const scripts = new Set<string>();
  for (const [name, test] of SCRIPT_TESTS) {
    if (test.test(ch)) {
      scripts.add(name);
      for (const extra of AUGMENT[name] ?? []) scripts.add(extra);
    }
  }
  let result: ReadonlySet<string> | null = scripts;
  if (scripts.size === 0) result = COMMON_OR_INHERITED.test(ch) ? null : new Set([`Unknown:${code}`]);
  if (cache.size < 10_000) cache.set(code, result);
  return result;
}

/** True when some word of `value` mixes characters that share no script. */
export function hasMixedScriptWord(value: string): boolean {
  for (const word of value.split(WORD_SEPARATOR)) {
    let common: Set<string> | null = null;
    for (const ch of word) {
      const scripts = scriptSet(ch);
      if (scripts === null) continue;
      if (common === null) {
        common = new Set(scripts);
        continue;
      }
      for (const script of common) if (!scripts.has(script)) common.delete(script);
      if (common.size === 0) return true;
    }
  }
  return false;
}
