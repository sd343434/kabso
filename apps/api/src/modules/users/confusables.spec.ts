import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
// @ts-expect-error -- plain ESM build script without type declarations
import { buildConfusablesModule } from '../../../scripts/generate-confusables.mjs';
import { loadConfig } from '../../config/app-config.js';
import { confusableSkeleton, CONFUSABLES_MAPPING_COUNT, containsReservedTerm } from './confusables.js';
import { CONFUSABLES_SOURCE_SHA256, CONFUSABLES_VERSION } from './data/confusables.generated.js';
import { displayNameIssue, normalizeDisplayName } from './display-name.js';
import { hasMixedScriptWord } from './script-mixing.js';

/** Pinned in data/README.md: unicode-org/unicodetools@4fd8eca9, security/17.0.0/confusables.txt. */
const PINNED_SHA256 = '091c7f82fc39ef208faf8f94d29c244de99254675e09de163160c810d13ef22a';

const dataPath = (name: string) => fileURLToPath(new URL(`./data/${name}`, import.meta.url));
const cp = (...points: number[]) => String.fromCodePoint(...points);

const CONFIG = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'http://localhost:3000',
});
const check = (raw: string) =>
  displayNameIssue(
    normalizeDisplayName(raw),
    CONFIG.reservedDisplayNameTerms,
    CONFIG.reservedDisplayNameBrandTerms,
  );
const schemaCheck = (raw: string) => displayNameIssue(normalizeDisplayName(raw), []);

describe('vendored confusables.txt (SEC-024)', () => {
  const text = readFileSync(dataPath('confusables.txt'), 'utf8');

  it('matches the pinned sha256 and Unicode version', () => {
    expect(createHash('sha256').update(text).digest('hex')).toBe(PINNED_SHA256);
    expect(text).toMatch(/^# Version: 17\.0\.0$/m);
    expect(CONFUSABLES_SOURCE_SHA256).toBe(PINNED_SHA256);
    expect(CONFUSABLES_VERSION).toBe('17.0.0');
  });

  it('the committed generated module equals a fresh generation', () => {
    const committed = readFileSync(dataPath('confusables.generated.ts'), 'utf8');
    expect(buildConfusablesModule(text)).toBe(committed);
    expect(CONFUSABLES_MAPPING_COUNT).toBe(6565);
  });
});

describe('confusable skeleton (UTS #39 both sides of case-folding)', () => {
  it('maps uppercase homoglyphs before folding and lowercase ones after', () => {
    const admin = confusableSkeleton('admin');
    expect(confusableSkeleton('ADMIN')).toBe(admin);
    expect(confusableSkeleton(`AD${cp(0x39c)}IN`)).toBe(admin); // Greek capital Mu
    expect(confusableSkeleton(`AD${cp(0x41c)}IN`)).toBe(admin); // Cyrillic capital Em
    const kabso = confusableSkeleton('kabso');
    expect(confusableSkeleton(`KA${cp(0x392)}SO`)).toBe(kabso); // Greek capital Beta
    expect(confusableSkeleton(`kabs${cp(0x3c3)}`)).toBe(kabso); // Greek sigma
    expect(confusableSkeleton(`${cp(0x1d0b)}abso`)).toBe(kabso); // small capital K
    expect(confusableSkeleton(`kab${cp(0xa731)}o`)).toBe(kabso); // small capital S
  });
});

describe('A7 KL-007c bypass strings are all refused (SEC-024)', () => {
  it.each([
    ['Greek capital Mu', `AD${cp(0x39c)}IN`],
    ['Cyrillic capital Em', `AD${cp(0x41c)}IN`],
    ['Greek capital Beta', `KA${cp(0x392)}SO`],
    ['Greek capital Nu', `ADMI${cp(0x39d)}`],
    ['Greek sigma', `kabs${cp(0x3c3)}`],
    ['Armenian oh', `kabs${cp(0x585)}`],
    ['Coptic o', `kabs${cp(0x2c9f)}`],
    ['Lao zero', `kabs${cp(0xed0)}`],
    ['Latin small capital K', `${cp(0x1d0b)}abso`],
    ['Latin small capital S', `kab${cp(0xa731)}o`],
    ['Cherokee tso', `${cp(0x13e6)}ABSO`],
    ['Lisu ka', `${cp(0xa4d7)}ABSO`],
    ['Arabic oe for waw', `كابس${cp(0x6c6)}`],
    ['Arabic keheh with two dots', `${cp(0x63b)}ابسو`],
  ])('%s', (_label, raw) => {
    expect(['reserved_term', 'invalid_format']).toContain(check(raw));
    // With reserved terms configured, every one of them is identified as the term itself.
    expect(check(raw)).toBe('reserved_term');
  });

  it('the HTTP schema stage (no terms) already rejects the mixed-script ones', () => {
    expect(schemaCheck(`AD${cp(0x39c)}IN`)).toBe('invalid_format');
    expect(schemaCheck(`${cp(0x13e6)}ABSO`)).toBe('invalid_format');
  });
});

describe('brand terms match inside a word (v1.2.3)', () => {
  it.each(['TheKabsoTeam', 'فريقكابسوالرسمي', 'KabsoFan', 'TheKabso', 'xxkabsoxx'])('%s', (raw) => {
    expect(check(raw)).toBe('reserved_term');
  });

  it('generic terms stay whole-word; brands split across words pass', () => {
    for (const raw of ['Badminton Club', 'Supporter', 'Staffordshire', 'Officially', 'Kab Sonia']) {
      expect(check(raw)).toBeNull();
    }
    expect(
      containsReservedTerm('Admins', CONFIG.reservedDisplayNameTerms, CONFIG.reservedDisplayNameBrandTerms),
    ).toBe(false);
  });
});

describe('mixed-script words (v1.2.3)', () => {
  it.each([
    ['Latin + Cyrillic', `S${cp(0x430)}ra`],
    ['Latin + Greek', `Ni${cp(0x3ba)}o`],
    ['Latin + Arabic in one word', 'Saraسارة'],
    ['Latin + Cherokee', `${cp(0x13a0)}lex`],
  ])('rejects %s with invalid_format', (_label, raw) => {
    expect(hasMixedScriptWord(normalizeDisplayName(raw))).toBe(true);
    expect(check(raw)).toBe('invalid_format');
  });

  it.each([
    ['Persian with ZWNJ', `می${cp(0x200c)}خواهم`],
    ['Persian name', 'مهرآرا'],
    ['Urdu', 'عائشہ خان'],
    ['Kurdish Sorani', 'ڕۆژان ئەحمەد'],
    ['Arabic with harakat', 'مُحَمَّد'],
    ['Latin with accents', 'Zoë Ünïcødé'],
    ['Vietnamese', 'Nguyễn Thị Ánh'],
    ['scripts in different words', 'Sara سارة'],
    ['Cyrillic only', 'Наталья'],
    ['Greek only', 'Νίκος'],
    ['Japanese (Han + Kana)', '山田たろう'],
    ['Korean', '김민지'],
    ['digits with Arabic', 'علي 2026'],
    ['emoji with Latin', `Sara${cp(0x1f600)}`],
  ])('accepts %s', (_label, raw) => {
    expect(check(raw)).toBeNull();
  });
});

describe('bidi marks (v1.2.3)', () => {
  it.each([
    ['LRM', 0x200e],
    ['RLM', 0x200f],
    ['ALM', 0x61c],
  ])('rejects %s', (_label, point) => {
    expect(check(`Sara${cp(point)} Ali`)).toBe('invalid_format');
  });
});
