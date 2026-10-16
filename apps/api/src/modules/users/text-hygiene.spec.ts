import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
// @ts-expect-error -- plain ESM build script without type declarations
import { buildTextHygieneModule, HYGIENE_SOURCE_FILES } from '../../../scripts/generate-text-hygiene.mjs';
import { loadConfig } from '../../config/app-config.js';
import { liveTitleIssue } from '../live/live.schemas.js';
import { HYGIENE_SOURCE_SHA256, HYGIENE_UNICODE_VERSION } from './data/text-hygiene.generated.js';
import { normalizeDisplayName, rawDisplayNameIssue } from './display-name.js';
import {
  categoryGroup,
  isDefaultIgnorable,
  isVariationSelector,
  RGI_EMOJI_COUNT,
  rgiEmojiSequences,
  trimHygiene,
} from './text-hygiene.js';

/**
 * CONVENTIONS §6 "Text hygiene" (v1.3.1, SEC-036). The pinned hashes are recorded in
 * data/README.md (source: unicode-org/unicodetools@4fd8eca9, Unicode 17.0.0 / Emoji 17.0).
 */
const PINNED_SHA256: Record<string, string> = {
  'DerivedCoreProperties.txt': '24c7fed1195c482faaefd5c1e7eb821c5ee1fb6de07ecdbaa64b56a99da22c08',
  'DerivedGeneralCategory.txt': 'd62e5bab70ca74f099343f71224fa051cb1fdd61a1ab45c0488c44cfc0b6102e',
  'PropList.txt': '130dcddcaadaf071008bdfce1e7743e04fdfbc910886f017d9f9ac931d8c64dd',
  'emoji-sequences.txt': '12cc8267dc33cbd11ed32bcf6fc5dc2ad9c7a77bae1bdfba2f41b1b9b3ead8dd',
  'emoji-zwj-sequences.txt': '5b25441daed2322b068c5e70cda522946a4f0274df864445a1965a92e5fc5cad',
};

const dataPath = (name: string) => fileURLToPath(new URL(`./data/unicode-17/${name}`, import.meta.url));
const cp = (...points: number[]) => String.fromCodePoint(...points);
const hexName = (s: string) =>
  [...s].map((c) => `U+${c.codePointAt(0)!.toString(16).toUpperCase()}`).join(' ');

const CONFIG = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'http://localhost:3000',
});
/** displayName as registration validates it (schema stage + reserved terms). */
const displayName = (raw: string) =>
  rawDisplayNameIssue(raw, CONFIG.reservedDisplayNameTerms, CONFIG.reservedDisplayNameBrandTerms) ??
  rawDisplayNameIssue(raw, []);
const title = (raw: string) => liveTitleIssue(raw);

const ZWNJ = cp(0x200c);
const ZWJ = cp(0x200d);

describe('vendored Unicode 17.0.0 data (SEC-036)', () => {
  const files = Object.fromEntries(
    (HYGIENE_SOURCE_FILES as string[]).map((name) => [name, readFileSync(dataPath(name), 'utf8')]),
  );

  it.each(Object.keys(PINNED_SHA256))('%s matches the pinned sha256', (name) => {
    expect(createHash('sha256').update(files[name]!).digest('hex')).toBe(PINNED_SHA256[name]);
    expect(HYGIENE_SOURCE_SHA256[name]).toBe(PINNED_SHA256[name]);
  });

  it('is Unicode 17.0.0 / Emoji 17.0', () => {
    expect(HYGIENE_UNICODE_VERSION).toBe('17.0.0');
    expect(files['DerivedCoreProperties.txt']).toMatch(/^# DerivedCoreProperties-17\.0\.0\.txt$/m);
    expect(files['PropList.txt']).toMatch(/^# PropList-17\.0\.0\.txt$/m);
    expect(files['emoji-sequences.txt']).toMatch(/^# Version: +17\.0$/m);
    expect(files['emoji-zwj-sequences.txt']).toMatch(/^# Version: +17\.0$/m);
  });

  it('the generated tables equal a fresh generation from the vendored files', () => {
    const generated = readFileSync(
      fileURLToPath(new URL('./data/text-hygiene.generated.ts', import.meta.url)),
      'utf8',
    );
    expect(buildTextHygieneModule(files)).toBe(generated);
  });

  it('reads properties from the vendored data, not from the runtime', () => {
    expect(categoryGroup(0x41)).toBe('L');
    expect(categoryGroup(0x3000)).toBe('Z');
    expect(categoryGroup(0x2028)).toBe('X'); // Zl
    expect(categoryGroup(0x0378)).toBe('X'); // unassigned
    expect(categoryGroup(0x10ffff)).toBe('X');
    expect(categoryGroup(0xfe0f)).toBe('M');
    expect(isDefaultIgnorable(0x3164)).toBe(true);
    expect(isDefaultIgnorable(0x41)).toBe(false);
    expect(isVariationSelector(0xe0100)).toBe(true);
    expect(isVariationSelector(0x180e)).toBe(false);
    expect(RGI_EMOJI_COUNT).toBe(3953);
  });

  it('trims only space separators and U+FEFF', () => {
    expect(trimHygiene(`${cp(0x3000, 0xa0, 0xfeff)} Ali ${cp(0x202f)}`)).toBe('Ali');
    expect(trimHygiene(`Ali${cp(0x2028)}`)).toBe(`Ali${cp(0x2028)}`);
    expect(trimHygiene('\tAli\n')).toBe('\tAli\n');
    expect(normalizeDisplayName(`  Zoe${cp(0x308)}  `)).toBe('Zoë');
  });
});

/** §6 rule 7: must keep passing (displayName and title). */
const MUST_PASS: [string, string][] = [
  ['Arabic', 'محمد علي'],
  ['Arabic with tashkeel', 'مُحَمَّد'],
  ['Arabic with tatweel', 'ليـلى'],
  ['Persian with ZWNJ', `مهر${ZWNJ}آرا`],
  ['Urdu with ZWNJ', `پاک${ZWNJ}ستان`],
  ['Urdu', 'عائشہ خان'],
  ['Kurdish Sorani', 'ڕۆژان ئەحمەد'],
  ['Kurdish Kurmanji', 'Rojîn Şêxo'],
  ['Hebrew', 'נועה כהן'],
  ['Devanagari with a ZWJ conjunct', `क${cp(0x94d)}${ZWJ}ष`],
  ['Chinese', '李小龙'],
  ['Japanese with U+3000', `山田${cp(0x3000)}太郎`],
  ['Japanese ideographic variation sequence', `${cp(0x845b, 0xe0100)}城`],
  ['Korean', '김민준'],
  ['Thai', 'สมชาย ใจดี'],
  ['family ZWJ sequence', `Sara ${cp(0x1f468)}${ZWJ}${cp(0x1f469)}${ZWJ}${cp(0x1f467)}`],
  ['rainbow flag', `Noor ${cp(0x1f3f3, 0xfe0f, 0x200d, 0x1f308)}`],
  ['health worker with skin tone', `Dr. Ali ${cp(0x1f469, 0x1f3fd)}${ZWJ}${cp(0x2695, 0xfe0f)}`],
  ['U+2764 U+FE0F', cp(0x2764, 0xfe0f)],
  ['U+2764 U+FE0F after a name', `Lina ${cp(0x2764, 0xfe0f)}`],
  ['U+2665 U+FE0E after a name', `Ali ${cp(0x2665, 0xfe0e)}`],
  ['keycap', cp(0x31, 0xfe0f, 0x20e3)],
  ['keycap after a name', `Team ${cp(0x31, 0xfe0f, 0x20e3)}`],
  ['regional-indicator flag', `Lina ${cp(0x1f1f8, 0x1f1e6)}`],
  ['Scotland tag-sequence flag', `Ali ${cp(0x1f3f4, 0xe0067, 0xe0062, 0xe0073, 0xe0063, 0xe0074, 0xe007f)}`],
  ['England tag-sequence flag', cp(0x1f3f4, 0xe0067, 0xe0062, 0xe0065, 0xe006e, 0xe0067, 0xe007f)],
  ['skin-tone modifier', `Omar ${cp(0x1f44b, 0x1f3fd)}`],
  ['accented Latin', 'Zoë Ünïcødé'],
  ['digits only', '2026'],
  ['U+00A0 inside a name', `Ali${cp(0xa0)}Hassan`],
  ['non-blank braille pattern', `Ali ${cp(0x283f)}`],
  ['U+3000 inside a name (CJK separator)', `李${cp(0x3000)}小龙`],
];

/** §6 rule 8: must be rejected, each alone and inside a name. */
const REJECTED_CODE_POINTS: [string, number[]][] = [
  ['Hangul fillers', [0x3164, 0x115f, 0x1160, 0xffa0]],
  ['soft hyphen', [0xad]],
  ['combining grapheme joiner', [0x34f]],
  ['invisible operators', [0x2061, 0x2062, 0x2063, 0x2064]],
  ['Mongolian vowel separator', [0x180e]],
  ['tag characters and U+E0001', [0xe0001, 0xe0020, 0xe0041, 0xe0067, 0xe007f]],
  ['line and paragraph separators', [0x2028, 0x2029]],
  ['interlinear annotations', [0xfff9, 0xfffa, 0xfffb]],
  ['musical formatting', [0x1d173, 0x1d174, 0x1d175, 0x1d176, 0x1d177, 0x1d178, 0x1d179, 0x1d17a]],
  ['braille blank', [0x2800]],
  ['object replacement character', [0xfffc]],
  ['musical symbol null notehead', [0x1d159]],
  ['private use', [0xe000, 0xf8ff, 0xf0000, 0x10fffd]],
  ['unassigned', [0x0378, 0x0e3b, 0x2fffd, 0x10ffff]],
  ['Khmer inherent vowels', [0x17b4, 0x17b5]],
  ['shorthand format controls', [0x1bca0, 0x1bca1, 0x1bca2, 0x1bca3]],
  ['Arabic number signs', [0x600, 0x601, 0x602, 0x603, 0x604, 0x605]],
  ['Arabic end of ayah (accepted side effect, D43)', [0x6dd]],
  // Everything rejected before v1.3.1:
  ['C0 controls', [0x0, 0x7, 0x9, 0xa, 0xd, 0x1f]],
  ['DEL and C1 controls', [0x7f, 0x80, 0x85, 0x9f]],
  ['bidi overrides and isolates', [0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2066, 0x2067, 0x2068, 0x2069]],
  ['LRM, RLM, ALM', [0x200e, 0x200f, 0x61c]],
  ['ZWSP, WJ', [0x200b, 0x2060]],
];

const REJECTED_STRINGS: [string, string][] = [
  ['lone high surrogate alone', '\ud800'],
  ['lone high surrogate inside', 'Ali\ud800Hassan'],
  ['lone low surrogate inside', 'Ali\udc00Hassan'],
  ['black flag followed by non-RGI tags', `Ali ${cp(0x1f3f4, 0xe0061, 0xe0062, 0xe007f)}`],
  ['tag sequence without the black flag', `Ali ${cp(0xe0067, 0xe0062, 0xe0073, 0xe0063, 0xe0074, 0xe007f)}`],
  ['variation selector at the start', `${cp(0xfe0f)}Ali`],
  ['variation selector after a space', `Ali ${cp(0xfe0f)}x`],
  ['ideographic variation selector after a space', `Ali ${cp(0xe0100)}`],
  ['variation selector after another selector', `Ali ${cp(0x2665, 0xfe0e, 0xfe0e)}`],
  ['emoji presentation selector twice', `Ali ${cp(0x2764, 0xfe0f, 0xfe0f)}`],
  ['variation selector after a mark', `Zx${cp(0x301, 0xfe0e)}`],
  ['Mongolian FVS after a space', `Ali ${cp(0x180b)}`],
  ['inner BOM', `Sa${cp(0xfeff)}ra`],
  ['only Hangul fillers', cp(0x3164, 0x3164, 0x3164)],
  ['only braille blanks', cp(0x2800, 0x2800)],
  ['only U+3000', cp(0x3000)],
  ['line separator at the end', `Sara${cp(0x2028)}`],
  ['newline at the end', 'Sara\n'],
];

describe.each([
  ['displayName', displayName],
  ['title', title],
])('%s text hygiene (CONVENTIONS §6 v1.3.1)', (_field, check) => {
  it.each(MUST_PASS)('accepts %s', (_label, value) => {
    expect(check(value)).toBeNull();
  });

  describe.each(REJECTED_CODE_POINTS)('rejects %s', (_label, points) => {
    it.each(points.map((p) => [`U+${p.toString(16).toUpperCase().padStart(4, '0')}`, p]))(
      '%s alone, inside and at the end of a name',
      (_name, point) => {
        const c = cp(point);
        expect(check(c)).toBe('invalid_format');
        expect(check(`Ali${c}Hassan`)).toBe('invalid_format');
        expect(check(`محمد ${c}علي`)).toBe('invalid_format');
        expect(check(`Sara${c}`)).toBe('invalid_format');
      },
    );
  });

  it.each(REJECTED_STRINGS)('rejects %s', (_label, value) => {
    expect(check(value)).toBe('invalid_format');
  });

  it('accepts every RGI emoji sequence of Emoji 17.0 after a name (3,953 sequences)', () => {
    const rejected: string[] = [];
    let count = 0;
    for (const emoji of rgiEmojiSequences()) {
      count += 1;
      if (check(`Ali ${emoji}`) !== null) rejected.push(hexName(emoji));
    }
    expect(count).toBe(3953);
    expect(rejected).toEqual([]);
  });

  it('never counts fillers or blank look-alikes as letters', () => {
    expect(check(`${cp(0x3164)}${ZWNJ}${cp(0x3164)}`)).toBe('invalid_format');
    expect(check(cp(0x115f, 0x1160))).toBe('invalid_format');
  });
});
