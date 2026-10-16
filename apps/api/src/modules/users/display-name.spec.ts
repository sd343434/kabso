import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { confusableSkeleton, containsReservedTerm } from './confusables.js';
import { displayNameIssue, graphemeCount, normalizeDisplayName } from './display-name.js';

// Invisible characters are built from code points so the source stays readable.
const cp = (...points: number[]) => String.fromCodePoint(...points);
const ZWNJ = cp(0x200c);
const ZWJ = cp(0x200d);
const RLO = cp(0x202e);
const LRI = cp(0x2066);
const ZWSP = cp(0x200b);
const WJ = cp(0x2060);
const BOM = cp(0xfeff);
const COMBINING_ACUTE = cp(0x0301);

const CONFIG = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'http://localhost:3000',
});
const TERMS = CONFIG.reservedDisplayNameTerms;
const BRANDS = CONFIG.reservedDisplayNameBrandTerms;

const check = (raw: string) => displayNameIssue(normalizeDisplayName(raw), TERMS, BRANDS);

describe('displayName (contract v1.2 §6, KL-017)', () => {
  it('uses the CONVENTIONS §6 reserved terms by default', () => {
    expect(TERMS).toEqual([
      'kabso',
      'admin',
      'administrator',
      'support',
      'official',
      'moderator',
      'staff',
      'كابسو',
      'الدعم',
      'رسمي',
      'مشرف',
      'الإدارة',
    ]);
  });

  it.each([
    ['Persian with ZWNJ', `می${ZWNJ}خواهم`],
    ['Persian name with ZWNJ', `مهر${ZWNJ}آرا`],
    ['Urdu', 'عائشہ خان'],
    ['Urdu with ZWNJ', `پاک${ZWNJ}ستان`],
    ['Kurdish Sorani', 'ڕۆژان ئەحمەد'],
    [
      'family emoji (ZWJ sequence) after a name',
      `Sara ${cp(0x1f468)}${ZWJ}${cp(0x1f469)}${ZWJ}${cp(0x1f467)}`,
    ],
    ['flag sequence', `Lina ${cp(0x1f1f8, 0x1f1e6)}`],
    ['skin-tone modifier', `Omar ${cp(0x1f44b, 0x1f3fd)}`],
    ['ZWJ profession emoji', `Dr. Ali ${cp(0x1f469, 0x1f3fd)}${ZWJ}${cp(0x2695, 0xfe0f)}`],
    ['Arabic with tashkeel', 'مُحَمَّد'],
    ['accented Latin', 'Zoë Ünïcødé'],
    ['digits only', '2026'],
  ])('accepts %s', (_label, name) => {
    expect(check(name)).toBeNull();
  });

  it('normalizes to NFC and trims', () => {
    expect(normalizeDisplayName(`  Zoe${cp(0x0308)}  `)).toBe('Zoë');
  });

  it('counts grapheme clusters, not code points', () => {
    expect(graphemeCount(`${cp(0x1f468)}${ZWJ}${cp(0x1f469)}${ZWJ}${cp(0x1f467)}`)).toBe(1);
    expect(graphemeCount(`می${ZWNJ}خواهم`)).toBe(7);
  });

  it('allows 50 grapheme clusters and rejects 51 (too_long)', () => {
    expect(check('ب'.repeat(50))).toBeNull();
    expect(check('ب'.repeat(51))).toBe('too_long');
    // 50 graphemes made of 2 code points each = 100 code points: still allowed.
    expect(check(`e${COMBINING_ACUTE}`.repeat(25).normalize('NFD') + 'x'.repeat(25))).toBeNull();
  });

  it('allows 100 code points and rejects 101 (too_long), even under 50 graphemes', () => {
    const family = `${cp(0x1f468)}${ZWJ}${cp(0x1f469)}${ZWJ}${cp(0x1f467)}`; // 5 code points, 1 grapheme
    const hundred = `a${family.repeat(19)}${'b'.repeat(4)}`; // 1 + 95 + 4 = 100 code points
    expect([...hundred]).toHaveLength(100);
    expect(graphemeCount(hundred)).toBeLessThanOrEqual(50);
    expect(check(hundred)).toBeNull();
    expect(check(`${hundred}c`)).toBe('too_long');
  });

  it('rejects empty and whitespace-only names as too_short', () => {
    expect(check('')).toBe('too_short');
    expect(check('   ')).toBe('too_short');
  });

  it.each([
    ['leading ZWNJ', `${ZWNJ}مهر`],
    ['trailing ZWJ', `Sara${ZWJ}`],
    ['double joiner', `می${ZWNJ}${ZWNJ}خواهم`],
    ['ZWNJ + ZWJ', `a${ZWNJ}${ZWJ}b`],
    ['joiner next to a space', `می ${ZWNJ}خواهم`],
    ['joiner before a space', `می${ZWNJ} خواهم`],
    ['joiner only', ZWJ],
  ])('rejects badly placed joiners: %s', (_label, name) => {
    expect(check(name)).toBe('invalid_format');
  });

  it.each([
    ['zalgo (4 marks)', `Za${cp(0x0301, 0x0302, 0x0303, 0x0304)}lgo`],
    ['heavy zalgo', `H${cp(0x0334, 0x0335, 0x0336, 0x0337, 0x0338, 0x0339)}i`],
  ])('rejects more than 3 consecutive combining marks: %s', (_label, name) => {
    expect(check(name)).toBe('invalid_format');
  });

  it('allows up to 3 consecutive combining marks', () => {
    expect(check(`Za${cp(0x0301, 0x0302, 0x0303)}lgo`)).toBeNull();
  });

  it.each([
    ['bidi override spoof', `admin${RLO}gnp.exe`],
    ['bidi isolate', `a${LRI}b`],
    ['zero-width space', `Kab${ZWSP}so`],
    ['word joiner', `a${WJ}b`],
    ['BOM inside', `a${BOM}b`],
    ['C0 control', 'a\u0007b'],
    ['C1 control', `a${cp(0x0085)}b`],
  ])('rejects banned characters: %s', (_label, name) => {
    expect(check(name)).toBe('invalid_format');
  });

  // Contract v1.2.1: a name needs at least one letter, digit or emoji grapheme.
  it.each([
    ['symbols only', '★★★'],
    ['two stars', '★★'],
    ['em dash', '—'],
    ['punctuation only', '...'],
    ['marks only', cp(0x0301, 0x0302)],
    ['text-presentation symbols', '©™'],
  ])('rejects names without any letter, digit or emoji: %s', (_label, name) => {
    expect(check(name)).toBe('invalid_format');
  });

  it.each([
    ['single emoji', cp(0x1f600)],
    ['two emoji', `${cp(0x1f600)}${cp(0x1f600)}`],
    ['family ZWJ sequence', `${cp(0x1f468)}${ZWJ}${cp(0x1f469)}${ZWJ}${cp(0x1f467)}`],
    ['flag', cp(0x1f1f8, 0x1f1e6)],
    ['skin tone', cp(0x1f44b, 0x1f3fd)],
    ['heart with VS16', `${cp(0x2665)}${cp(0xfe0f)}`],
  ])('accepts emoji-only names (v1.2.1): %s', (_label, name) => {
    expect(check(name)).toBeNull();
  });

  it('trims U+FEFF at either end but rejects it inside the name (v1.2.1)', () => {
    expect(normalizeDisplayName(`${BOM}Sara${BOM}`)).toBe('Sara');
    expect(check(`${BOM}Sara${BOM}`)).toBeNull();
    expect(check(`Sa${BOM}ra`)).toBe('invalid_format');
  });

  it.each([
    ['plain', 'Kabso Live'],
    ['case', 'KABSO'],
    ['Cyrillic а (confusable)', 'Kаbso'],
    ['Greek ο', 'Kabsο fan'],
    ['digit spoof', 'Adm1n'],
    ['rn for m', 'Adrnin team'],
    ['fullwidth (NFKC)', 'ｋａｂｓｏ'],
    ['accent', 'Ádmin'],
    ['ZWNJ inside a term', `sup${ZWNJ}port`],
    ['official', 'The Official One'],
    ['Arabic support + official', 'الدعم الرسمي'],
    ['Arabic Kabso', 'كابسو'],
    ['Arabic with Persian yeh', 'رسمی'],
    ['Arabic with tashkeel', 'الدَّعم'],
    ['Arabic administration with hamza', 'فريق الإدارة'],
    ['Arabic with tatweel', 'مشـــرف'],
  ])('rejects reserved terms (NFKC casefold + confusable skeleton): %s', (_label, name) => {
    expect(check(name)).toBe('reserved_term');
  });

  // Contract v1.2.1: whole words of the skeleton, plus brand prefix/suffix without separators.
  it.each([
    'Badminton Club',
    'Supporter',
    'Staffordshire',
    'Officially',
    'Administrated',
    // v1.2.2: a brand split across words is not reserved.
    'Kab Sonia',
    'Abc Kab Sonite',
  ])('accepts reserved terms inside ordinary words: %s', (name) => {
    expect(check(name)).toBeNull();
  });

  it.each([
    ['Kabso Live', 'Kabso Live'],
    ['underscore separated', 'kabso_official'],
    ['Cyrillic а, spaced', 'K а b s o'],
    ['Admin', 'Admin'],
    ['Arabic support', 'الدعم الفني'],
    ['Arabic moderator', 'مشرف'],
    ['brand suffix (b)', 'TheKabso'],
    ['brand prefix (b)', 'KabsoFan'],
    ['Arabic brand suffix (b)', 'فريقكابسو'],
    // v1.2.2 rule (b) applied literally: one word starting with the brand is reserved.
    ['brand prefix inside an ordinary-looking word (b)', 'Abc Kabsonite'],
    ['spaced brand, whole name equals a term (c)', 'K a b s o'],
    ['spaced non-brand term, whole name equals a term (c)', 'A d m i n'],
    ['dotted term (c)', 'S.T.A.F.F'],
  ])('rejects whole-word reserved terms and brand prefix/suffix: %s', (_label, name) => {
    expect(check(name)).toBe('reserved_term');
  });

  it('defaults the brand terms to kabso and كابسو', () => {
    expect(BRANDS).toEqual(['kabso', 'كابسو']);
  });

  it('computes the same skeleton for confusable spellings', () => {
    expect(confusableSkeleton('Kаbso')).toBe(confusableSkeleton('kabso'));
    expect(confusableSkeleton('ADMlN')).toBe(confusableSkeleton('admin'));
    expect(containsReservedTerm('Sara', TERMS, BRANDS)).toBe(false);
  });
});
