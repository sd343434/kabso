/**
 * KL-007e security regression tests (A7) for contract v1.2.6 / v1.2.7 (SEC-030/031/032).
 * Residual bypasses found in KL-007e are described in docs/security/KL-007_PHASE1_REVIEW.md §9.
 */
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../src/config/app-config.js';
import { rawDisplayNameIssue } from '../../src/modules/users/display-name.js';

const config = loadConfig({
  NODE_ENV: 'test',
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(48),
  APP_PUBLIC_URL: 'http://localhost:3000',
});
const issue = (raw: string) =>
  rawDisplayNameIssue(raw, config.reservedDisplayNameTerms, config.reservedDisplayNameBrandTerms);

describe('KL-007e displayName v1.2.6/v1.2.7', () => {
  it.each([
    ['SEC-030 Latin small capitals', 'ᴋᴀʙꜱᴏ'],
    ['SEC-030 all-Cyrillic lowercase', 'кавѕо'],
    ['SEC-030 small-capital ADMIN', 'ᴀᴅᴍɪɴ'],
    ['SEC-031 single letters + word', 'K a b s o Team'],
    ['SEC-031 hyphen', 'Kab-so Live'],
    ['SEC-031 dots', 'K.a.b.s.o Fan'],
    ['SEC-031 middle dot', 'Kab·so Live'],
    ['SEC-031 Arabic single letters', 'ك ا ب س و لايف'],
    ['SEC-031 NBSP spacing', 'K a b s o Team'],
    ['SEC-031 ideographic space', 'K　a　b　s　o Team'],
    ['SEC-031 slash', 'Kab/so Live'],
    ['SEC-031 apostrophes', "K'a'b's'o Fan"],
    ['v1.2.7 generic term split', 'Ad-min Ali'],
    ['v1.2.7 spaced generic term', 'A D M I N Ali'],
  ])('rejects %s', (_label, raw) => {
    expect(issue(raw)).toBe('reserved_term');
  });

  it.each([
    'Ali٣',
    'Ahmed۲۰۲۴',
    'TOKYO東京',
    'Kim김',
    'Ｊ太郎',
    'iPhone大好き',
    'رسمي',
    'Kab Sonia',
    'J R R Tolkien',
    'محمد و علي',
    'Sup-Porter',
    'Ad-Minh Tran',
  ])('accepts %s (SEC-032 / no new false positive)', (raw) => {
    expect(issue(raw)).toBeNull();
  });

  it('keeps Latin mixed with Cyrillic or Greek in one word invalid', () => {
    expect(issue('Aliа')).not.toBeNull();
    expect(issue('Samα')).not.toBeNull();
  });
});
